--------------------------------------------------------------------------------
-- Forever Totems - Windfury.lua
-- A cue when Windfury goes off.
--
-- The combat log is forbidden to this addon, so the proc is caught where it
-- still shows: the weapon's extra attack is a spell cast by you, and casts do
-- reach us. The imbue is "Windfury Weapon" and the proc is "Windfury Attack",
-- so what they have in common is the word the imbue tracker already works out
-- for itself, in whatever language the client is in.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Windfury = {}
ns.Windfury = Windfury

-- Rank 1 of the imbue. A seed to learn the name from, nothing else.
local SEED_ID = 8232
-- One proc, two extra swings, and the client may well announce both
local THROTTLE = 0.25
local LOG_MAX = 12

-- Second route: the extra attack itself. This client announces no cast for the
-- proc, but the blow lands, and it lands on top of the swing that caused it.
-- Two hits inside this window are one swing plus an extra attack.
local PAIR_WINDOW = 0.15
-- An instant attack of yours lands its own blow next to the swing, so a pair
-- this soon after a cast is Stormstrike or a shock, not Windfury
local CAST_GUARD = 0.25
local SAMPLE = 24       -- hits kept to work out what a swing of yours is worth
local SHARE = 0.35      -- of a typical swing: anything smaller is a tick, not a blow

local state = { count = 0, last = 0, suppressed = 0, log = {},
                hits = {}, lastCast = 0, pairs = {} }

--------------------------------------------------------------------------------
-- The word to look for
--------------------------------------------------------------------------------
function Windfury:ImbueName()
    return ns.SpellInfo(SEED_ID)
end

-- "Windfury Weapon" -> "Windfury": the imbue tracker already strips the word
-- that every imbue shares, which is exactly the part the proc keeps.
function Windfury:GetBase()
    if self.base ~= nil then return self.base end

    local seedName = self:ImbueName()
    if not seedName then return nil end

    local base
    for _, entry in ipairs(ns.Weapon:GetImbueBases()) do
        if entry.full == seedName then base = entry.base end
    end
    -- Not in the spellbook, or the only imbue known: the first word will do
    if not base or base == "" then base = seedName:match("^(%S+)") or seedName end

    self.base = base:lower()
    ns:Debug("windfury keyword:", self.base)
    return self.base
end

function Windfury:Forget()
    self.base = nil
end

--------------------------------------------------------------------------------
-- Catching the proc
--------------------------------------------------------------------------------
-- Every cast of yours is offered here; almost none of them are the proc.
function Windfury:OnCast(spellName, spellID, icon)
    if not spellName then return false end
    local base = self:GetBase()
    if not base then return false end
    if not spellName:lower():find(base, 1, true) then return false end

    -- Putting the imbue on, and the totem of the same name, are not procs
    if spellName == self:ImbueName() then return false end
    if ns.HasWord(spellName, ns:GetTotemKeyword()) then return false end

    self:Proc(spellName, icon)
    return true
end

function Windfury:Proc(spellName, icon)
    local now = GetTime()
    state.log[#state.log + 1] = ("%7.2f  %s"):format(now % 10000, spellName)
    if #state.log > LOG_MAX then table.remove(state.log, 1) end

    if (now - state.last) < THROTTLE then
        state.suppressed = state.suppressed + 1
        return false
    end
    state.last = now
    state.count = state.count + 1

    local cfg = ns.db.windfury
    if not cfg.enabled then return false end

    self:Show(icon)
    if cfg.sound then
        if not ns.Warnings:PlayKey(cfg.soundChoice, cfg.channel) then
            ns.Warnings:PlayCue()
        end
    end
    if cfg.screen then
        ns.Warnings:Alert(spellName, 0.55, 0.8, 1, false)
    end
    return true
end

-- Same flash as the cooldown cue, in the colour of the imbue so the two are
-- not mistaken for each other at a glance.
function Windfury:Show(icon)
    if not ns.Bar then return end
    local cfg = ns.db.windfury
    local spell
    for _, entry in ipairs(ns.Weapon:GetSpells()) do
        if entry.name == self:ImbueName() then spell = entry end
    end
    ns.Bar:FlashIcon(icon or (spell and spell.icon) or "Interface\\Icons\\Spell_Nature_Cyclone", {
        gate = cfg.flash,
        time = cfg.flashTime,
        size = cfg.flashSize,
        color = { 0.45, 0.75, 1, 0.5 },
    })
end

--------------------------------------------------------------------------------
-- Second route: the extra attack
--
-- The probe on this client says it plainly: no cast is announced for the proc,
-- but the extra blow arrives through UNIT_COMBAT within a few hundredths of a
-- second of the swing that spawned it. Searing Totem ticking and a shock
-- burning away land close to a swing too, so size decides: a tick is a
-- fraction of what your weapon hits for, and what your weapon hits for is
-- learned from the fight rather than guessed at.
--------------------------------------------------------------------------------
function Windfury:Record(damage)
    local hits = state.hits
    hits[#hits + 1] = damage
    if #hits > SAMPLE then table.remove(hits, 1) end
end

-- A typical swing: the mean of the five biggest recent hits. The mean of all
-- of them would be dragged down by every totem tick.
function Windfury:TypicalSwing()
    local hits = state.hits
    if #hits < 5 then return nil end
    local sorted = {}
    for index, value in ipairs(hits) do sorted[index] = value end
    table.sort(sorted, function(a, b) return a > b end)
    local total = 0
    for index = 1, 5 do total = total + sorted[index] end
    return total / 5
end

function Windfury:Threshold()
    local typical = self:TypicalSwing()
    return typical and (typical * SHARE) or nil
end

-- A miss or a parry can only be a weapon swing: nothing else is announced that
-- way. Damage has to earn it.
function Windfury:LooksLikeABlow(action, damage)
    if action ~= "WOUND" then return true end
    if damage <= 0 then return false end
    local threshold = self:Threshold()
    if not threshold then return false end      -- not calibrated yet
    return damage >= threshold
end

function Windfury:OnMelee(action, damage)
    if not ns.db.windfury.melee then return false end
    damage = tonumber(damage) or 0
    if action == "WOUND" and damage > 0 then self:Record(damage) end

    local now = GetTime()
    local previous = state.lastBlow
    local blow = { time = now, damage = damage, action = action,
                   real = self:LooksLikeABlow(action, damage) }
    state.lastBlow = blow

    if not previous or not previous.real or not blow.real then return false end
    if (now - previous.time) > PAIR_WINDOW then return false end
    -- Three blows at once is still one proc
    if previous.paired then return false end
    -- Your own instant attack landing beside the swing is not an extra attack
    if (now - state.lastCast) < CAST_GUARD then return false end

    blow.paired = true
    state.pairs[#state.pairs + 1] = ("%7.2f  %s %d + %s %d  (%.0fms apart)"):format(
        now % 10000, previous.action, previous.damage, action, damage,
        (now - previous.time) * 1000)
    if #state.pairs > LOG_MAX then table.remove(state.pairs, 1) end

    return self:Proc(self:ImbueName() or "Windfury", nil)
end

-- Every cast of yours passes through here, named or not
function Windfury:SeeCast(spellID, spellName)
    state.lastCast = GetTime()
    self:Probe(spellID, spellName)
end

-- A two hander hits for three times what a one hander does, so everything
-- learned about the size of your swings is thrown away when you change weapon.
function Windfury:Recalibrate()
    state.hits, state.lastBlow = {}, nil
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, action, descriptor, damage)
    if event == "UNIT_COMBAT" then
        if unit == "target" then Windfury:OnMelee(action, damage) end
        return
    end
    Windfury:Recalibrate()
end)

function Windfury:Enable()
    events:RegisterEvent("UNIT_COMBAT")
    -- An event this client does not know errors on registration rather than
    -- being ignored, so it goes in on its own
    pcall(events.RegisterEvent, events, "PLAYER_EQUIPMENT_CHANGED")
end

function Windfury:Stats()
    return state
end

--------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------
function Windfury:CycleSound()
    local available = ns.Warnings:AvailableSounds()
    if #available == 0 then return nil end
    local index = 0
    for i, choice in ipairs(available) do
        if choice.key == ns.db.windfury.soundChoice then index = i end
    end
    local nextChoice = available[(index % #available) + 1]
    ns.db.windfury.soundChoice = nextChoice.key
    ns.Warnings:PlayKey(nextChoice.key, ns.db.windfury.channel)
    return nextChoice
end

function Windfury:ToggleChannel()
    ns.db.windfury.channel = (ns.db.windfury.channel == "Master") and "SFX" or "Master"
    ns.Warnings:PlayKey(ns.db.windfury.soundChoice, ns.db.windfury.channel)
    return ns.db.windfury.channel
end

--------------------------------------------------------------------------------
-- Probe: what does the client actually say when Windfury goes off
--
-- Everything that reaches us is written down for a few seconds: every spell of
-- yours that succeeds, named or not, and every blow landed on you or on your
-- target. If the proc is announced at all, it is in here.
--------------------------------------------------------------------------------
local probe = CreateFrame("Frame")
local probeLog, probeOn = {}, false
local PROBE_MAX = 80

local function ProbeAdd(text)
    if not probeOn then return end
    probeLog[#probeLog + 1] = ("%8.2f  %s"):format(GetTime() % 10000, text)
    if #probeLog >= PROBE_MAX then
        probeOn = false
        pcall(probe.UnregisterAllEvents, probe)
    end
end

probe:SetScript("OnEvent", function(_, event, unit, action, descriptor, damage)
    if unit ~= "player" and unit ~= "target" then return end
    ProbeAdd(("%-12s %-7s %-7s %s"):format(event, tostring(unit), tostring(action),
        tostring(damage or descriptor or "")))
end)

-- Called for every successful cast of yours, before anything is matched
function Windfury:Probe(spellID, spellName)
    ProbeAdd(("cast         id=%-8s %s"):format(tostring(spellID), tostring(spellName)))
end

function Windfury:ToggleProbe()
    probeOn = not probeOn
    if probeOn then
        probeLog = {}
        pcall(probe.RegisterEvent, probe, "UNIT_COMBAT")
    else
        pcall(probe.UnregisterAllEvents, probe)
    end
    return probeOn
end

function Windfury:ProbeReport()
    local lines = { "Windfury probe:" }
    lines[#lines + 1] = ("  imbue: %s   word looked for: %s"):format(
        tostring(self:ImbueName()), tostring(self:GetBase()))
    lines[#lines + 1] = ("  on your weapon right now: %s"):format(
        tostring(ns.Weapon and ns.Weapon:AppliedName() or "?"))
    lines[#lines + 1] = ("  lines captured: %d"):format(#probeLog)
    for _, entry in ipairs(probeLog) do lines[#lines + 1] = "  " .. entry end
    if #probeLog == 0 then
        lines[#lines + 1] = "  Nothing. Run /ft wfprobe, melee something, run it again."
    end
    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------
function Windfury:Report()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
        ns:Print(text)
    end

    local cfg = ns.db.windfury
    add("Windfury proc diagnostics:")
    add(("  enabled: %s   sound: %s (%s on %s)   flash: %s"):format(
        tostring(cfg.enabled), tostring(cfg.sound), tostring(cfg.soundChoice),
        tostring(cfg.channel), tostring(cfg.flash)))
    add(("  imbue spell: %s   word looked for: %s"):format(
        tostring(self:ImbueName()), tostring(self:GetBase())))
    add(("  procs seen: %d (%d more arrived inside %.2fs and were folded in)"):format(
        state.count, state.suppressed, THROTTLE))
    add(("  reading the extra attacks: %s"):format(tostring(cfg.melee)))
    local typical, threshold = self:TypicalSwing(), self:Threshold()
    add(("  a swing of yours is worth about %s, so anything under %s is a tick"):format(
        typical and ("%.0f"):format(typical) or "unknown yet",
        threshold and ("%.0f"):format(threshold) or "?"))
    add(("  hits measured: %d of %d needed"):format(math.min(#state.hits, SAMPLE), 5))
    add("  pairs taken for a proc, most recent last:")
    for _, entry in ipairs(state.pairs) do add("    " .. entry) end
    if #state.pairs == 0 then
        add("    none yet. Melee something with Windfury on and look again.")
    end
    if #state.log > 0 then
        add("  and these arrived announced as a cast:")
        for _, entry in ipairs(state.log) do add("    " .. entry) end
    end

    add("  playing it now, you should hear it and see the icon")
    self:Show(nil)
    ns.Warnings:PlayKey(cfg.soundChoice, cfg.channel)
    return table.concat(lines, "\n")
end
