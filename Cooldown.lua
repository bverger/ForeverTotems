--------------------------------------------------------------------------------
-- Forever Totems - Cooldown.lua
-- A sound the moment a watched ability comes back up. Stormstrike by default.
--
-- Cooldown data can be withheld in combat the same way totem and aura data is,
-- so the duration of each watched spell is learned while it is readable and
-- counted locally when it is not.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Cooldown = {}
ns.Cooldown = Cooldown

-- Seed: Stormstrike. Only used to learn the localised name.
local DEFAULT_SEED_IDS = { 17364 }
local GCD_LIMIT = 1.6   -- anything this short is the global cooldown, not a real one

-- A talent can hand a cooldown back early. Improved Stormstrike resets it every
-- time you dodge or parry, so counting down from the cast is wrong for half the
-- fight. Avoiding a blow is treated as a candidate reset.
local AVOID_ACTIONS = { DODGE = true, PARRY = true }
local EVIDENCE = 1.0    -- cooldown still to run for an early return to mean anything

local watched = {}      -- [name] = { id, onCooldown, readyAt, duration }
local avoids = { count = 0, resets = 0, last = nil, action = nil }

--------------------------------------------------------------------------------
-- Which spells are we watching
--------------------------------------------------------------------------------
function Cooldown:DefaultNames()
    local names = {}
    for _, id in ipairs(DEFAULT_SEED_IDS) do
        local name = ns.SpellInfo(id)
        if name then names[#names + 1] = name end
    end
    return names
end

function Cooldown:Watch(name)
    if not name or name == "" then return false end
    for _, existing in ipairs(ns.db.cooldowns.watch) do
        if existing:lower() == name:lower() then return false end
    end
    table.insert(ns.db.cooldowns.watch, name)
    self:Rebuild()
    return true
end

function Cooldown:Unwatch(name)
    for index, existing in ipairs(ns.db.cooldowns.watch) do
        if existing:lower() == name:lower() then
            table.remove(ns.db.cooldowns.watch, index)
            self:Rebuild()
            return true
        end
    end
    return false
end

-- Resolve the watched names to spell ids from your spellbook
function Cooldown:Rebuild()
    watched = {}
    local wanted = {}
    for _, name in ipairs(ns.db.cooldowns.watch) do wanted[name:lower()] = name end

    if ns.IterateSpellbook then
        ns.IterateSpellbook(function(id)
            local name, icon = ns.SpellInfo(id)
            if name and wanted[name:lower()] then
                -- Keep the highest rank: later entries win
                watched[name] = watched[name] or { name = name }
                watched[name].id, watched[name].icon = id, icon
            end
        end)
    end
    return watched
end

function Cooldown:Watched()
    return watched
end

--------------------------------------------------------------------------------
-- Reading a cooldown, when the client allows it
--------------------------------------------------------------------------------
-- Returns start, duration, readable
local function ReadCooldown(spellID)
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if not ok then return nil, nil, false end
        if info then start, duration = info.startTime, info.duration end
    elseif _G.GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, spellID)
        if not ok then return nil, nil, false end
        start, duration = s, d
    end
    if start == nil or ns.AnySecret(start, duration) then return nil, nil, false end
    return start, duration, true
end

--------------------------------------------------------------------------------
-- The alert
--------------------------------------------------------------------------------
-- cause is "reset" when a dodge or a parry gave it back, nil when it simply ran out
function Cooldown:Ready(entry, cause)
    local cfg = ns.db.cooldowns
    entry.onCooldown, entry.readyAt = false, nil
    if not cfg.enabled then return end
    -- Nobody needs to know Stormstrike is up while standing in a city
    if cfg.combatOnly and not InCombatLockdown() then return end

    if ns.Bar then ns.Bar:FlashIcon(entry.icon) end

    if cfg.screen then
        ns.Warnings:Alert(
            (cause == "reset" and "%s reset" or "%s is up"):format(entry.name),
            0.5, 0.9, 1, cfg.sound)
    elseif cfg.sound then
        -- Master rather than SFX: this one is meant to cut through
        if not ns.Warnings:PlayKey(cfg.soundChoice, cfg.channel) then
            ns.Warnings:PlayCue()
        end
    end
end

--------------------------------------------------------------------------------
-- Called from the bar's ticker
--------------------------------------------------------------------------------
function Cooldown:Update()
    if not ns.db.cooldowns.enabled then return end
    local now = GetTime()

    for _, entry in pairs(watched) do
        local start, duration, readable = ReadCooldown(entry.id)

        if readable then
            local onCooldown = duration and duration > GCD_LIMIT and (start + duration) > now
            if onCooldown then
                entry.onCooldown = true
                entry.readyAt = start + duration
                ns.db.cooldowns.durations[entry.name] = duration   -- learn it
            elseif entry.onCooldown then
                self:Ready(entry)
            end
        elseif entry.readyAt and now >= entry.readyAt then
            -- Counting blind: the client stopped telling us
            self:Ready(entry)
        end
    end
end

-- A cast starts the local clock, which is what keeps this working in combat
function Cooldown:OnCast(spellName)
    local entry = watched[spellName]
    if not entry then return end
    local duration = ns.db.cooldowns.durations[spellName]
    if not duration then return end
    entry.onCooldown = true
    entry.readyAt = GetTime() + duration
end

--------------------------------------------------------------------------------
-- Cooldowns that come back early
--
-- "Improved Stormstrike: Stormstrike's cooldown has a 100% chance to reset each
-- time you Dodge or Parry." Nothing in the cooldown itself announces this, so
-- the dodges and parries are watched instead: while the client still reports
-- the cooldown we ask it and believe the answer, and while it does not we go on
-- what was learned when it did.
--------------------------------------------------------------------------------
function Cooldown:ResetsOnAvoid(name)
    return ns.db.cooldowns.resets[name] == true
end

function Cooldown:SetReset(name, value)
    ns.db.cooldowns.resets[name] = value and true or false
    ns.db.cooldowns.resetsManual[name] = true   -- a talent scan must not undo this
    return ns.db.cooldowns.resets[name]
end

-- Learned from the client rather than from a tooltip: it was on cooldown, you
-- avoided a blow, it is up. Only worth recording while there was a real stretch
-- of cooldown left, otherwise it was going to come back anyway.
local function LearnReset(entry, remaining)
    if remaining < EVIDENCE then return false end
    if ns.db.cooldowns.resets[entry.name] then return false end
    ns.db.cooldowns.resets[entry.name] = true
    ns:Debug(("%s came back on a dodge or parry with %.1fs left: tracking resets"):format(
        entry.name, remaining))
    return true
end

function Cooldown:OnAvoid(action)
    avoids.count = avoids.count + 1
    avoids.last, avoids.action = GetTime(), action
    if not ns.db.cooldowns.enabled then return end

    local now = GetTime()
    for _, entry in pairs(watched) do
        if entry.onCooldown then
            local remaining = (entry.readyAt or now) - now
            local start, duration, readable = ReadCooldown(entry.id)
            if readable then
                local stillOn = duration and duration > GCD_LIMIT and (start + duration) > now
                if not stillOn then
                    LearnReset(entry, remaining)
                    avoids.resets = avoids.resets + 1
                    self:Ready(entry, "reset")
                end
            elseif self:ResetsOnAvoid(entry.name) then
                -- Counting blind, but this one is known to reset: it is up now
                avoids.resets = avoids.resets + 1
                self:Ready(entry, "reset")
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Reading it off the talent rather than waiting to be shown
--------------------------------------------------------------------------------
local scanner
local function GetScanner()
    if scanner then return scanner end
    local ok, frame = pcall(CreateFrame, "GameTooltip", "ForeverTotemsTalentScanner",
        nil, "GameTooltipTemplate")
    if not ok or not frame then return nil end
    frame:SetOwner(UIParent, "ANCHOR_NONE")
    scanner = frame
    return scanner
end

local function TalentText(tab, index)
    local tip = GetScanner()
    if not tip or type(tip.SetTalent) ~= "function" then return nil end
    tip:ClearLines()
    if not pcall(tip.SetTalent, tip, tab, index) then return nil end

    local parts = {}
    for line = 1, (tip:NumLines() or 0) do
        local fs = _G["ForeverTotemsTalentScannerTextLeft" .. line]
        local text = fs and fs:GetText()
        if text and text ~= "" then parts[#parts + 1] = text end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " "):lower()
end

-- Does this talent say the spell comes back on a dodge or a parry? The words
-- are English, so on another client this finds nothing and the watch falls back
-- to learning it from the fight.
local function MentionsReset(text, spellName)
    if not text:find(spellName:lower(), 1, true) then return false end
    if not text:find("reset", 1, true) then return false end
    return text:find("dodge", 1, true) ~= nil or text:find("parry", 1, true) ~= nil
end

function Cooldown:ScanTalents()
    if type(_G.GetNumTalentTabs) ~= "function" or type(_G.GetTalentInfo) ~= "function" then
        return nil, "this client does not hand the talent tree to addons"
    end
    local okTabs, tabs = pcall(GetNumTalentTabs)
    if not okTabs or type(tabs) ~= "number" then return nil, "no talent tabs" end

    local found, read = {}, 0
    for tab = 1, tabs do
        local okCount, count = pcall(GetNumTalents, tab)
        if okCount and type(count) == "number" then
            for index = 1, count do
                local ok, name, _, _, _, rank = pcall(GetTalentInfo, tab, index)
                -- Only a talent you actually took, and only if this client
                -- answers in the classic shape: another one would be nonsense
                if ok and type(name) == "string" and type(rank) == "number" and rank > 0 then
                    local text = TalentText(tab, index)
                    if text then
                        read = read + 1
                        for watchName in pairs(watched) do
                            if MentionsReset(text, watchName) then found[watchName] = true end
                        end
                    end
                end
            end
        end
    end

    if read == 0 then return nil, "no talent tooltip could be read" end

    for name in pairs(watched) do
        if not ns.db.cooldowns.resetsManual[name] then
            ns.db.cooldowns.resets[name] = found[name] or false
        end
    end
    self.talentScan = { read = read, found = found }
    return found
end

--------------------------------------------------------------------------------
-- Events
--
-- UNIT_COMBAT is the one that reaches us: the combat log is forbidden to this
-- addon, and UNIT_COMBAT on "player" is where your own dodges and parries show
-- up. The swing timer already proves it fires on this client.
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, action)
    if event == "UNIT_COMBAT" then
        if unit == "player" and AVOID_ACTIONS[action] then Cooldown:OnAvoid(action) end
        return
    end
    -- Talents moved: what was read off them is stale
    if Cooldown.rescanning then return end
    Cooldown.rescanning = true
    C_Timer.After(1, function()
        Cooldown.rescanning = nil
        Cooldown:ScanTalents()
    end)
end)

function Cooldown:Enable()
    events:RegisterEvent("UNIT_COMBAT")
    -- An event this client does not know raises an error on registration
    -- instead of being ignored, so these go in one at a time
    for _, event in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
        pcall(events.RegisterEvent, events, event)
    end
    -- Talent tooltips are not worth reading in the first moments after login
    C_Timer.After(3, function() Cooldown:ScanTalents() end)
end

function Cooldown:AvoidStats()
    return avoids
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------
function Cooldown:Report()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
        ns:Print(text)
    end

    add("Cooldown watch diagnostics:")
    add(("  enabled: %s   sound: %s   combat only: %s (in combat now: %s)"):format(
        tostring(ns.db.cooldowns.enabled), tostring(ns.db.cooldowns.sound),
        tostring(ns.db.cooldowns.combatOnly), tostring(InCombatLockdown())))
    add(("  warning sound setting: %s"):format(tostring(ns.db.warnings.sound)))
    add(("  C_Spell.GetSpellCooldown: %s"):format(type(C_Spell and C_Spell.GetSpellCooldown)))
    add(("  watch list: %d entries"):format(#ns.db.cooldowns.watch))

    for _, name in ipairs(ns.db.cooldowns.watch) do
        local entry = watched[name]
        if not entry then
            add(("    %s -> NOT FOUND in your spellbook"):format(name))
        else
            local start, duration, readable = ReadCooldown(entry.id)
            add(("    %s (id %d): %s"):format(name, entry.id,
                readable and ("start=%.1f duration=%.1f"):format(start or 0, duration or 0)
                or "the client will not report it"))
            add(("      tracked: onCooldown=%s readyAt=%s learned=%s"):format(
                tostring(entry.onCooldown), tostring(entry.readyAt),
                tostring(ns.db.cooldowns.durations[name])))
            add(("      resets on dodge or parry: %s (%s)"):format(
                tostring(ns.db.cooldowns.resets[name] == true),
                ns.db.cooldowns.resetsManual[name] and "set by hand"
                    or (self.talentScan and "from the talent tooltip" or "not read from a talent yet")))
        end
    end

    local avoids = self:AvoidStats()
    add(("  dodges and parries seen: %d, of which gave a watched spell back: %d"):format(
        avoids.count, avoids.resets))
    if self.talentScan then
        add(("  talent scan: %d talent tooltips read"):format(self.talentScan.read))
    else
        local _, reason = self:ScanTalents()
        add(("  talent scan: %s"):format(tostring(reason or "nothing found")))
    end

    add(("  cue sound: %s on the %s channel"):format(
        tostring(ns.db.cooldowns.soundChoice), tostring(ns.db.cooldowns.channel)))
    add(("  flash: %s, %dpx for %.1fs"):format(
        tostring(ns.db.cooldowns.flash), ns.db.cooldowns.flashSize or 0, ns.db.cooldowns.flashTime or 0))
    for _, entry in pairs(watched) do
        if ns.Bar then ns.Bar:FlashIcon(entry.icon) end
        break
    end
    add("  playing it now, you should hear it")
    ns.Warnings:PlayKey(ns.db.cooldowns.soundChoice, ns.db.cooldowns.channel)
    return table.concat(lines, "\n")
end

-- Walk through the available sounds for the cue
function Cooldown:CycleSound()
    local available = ns.Warnings:AvailableSounds()
    if #available == 0 then return nil end
    local index = 0
    for i, choice in ipairs(available) do
        if choice.key == ns.db.cooldowns.soundChoice then index = i end
    end
    local nextChoice = available[(index % #available) + 1]
    ns.db.cooldowns.soundChoice = nextChoice.key
    ns.Warnings:PlayKey(nextChoice.key, ns.db.cooldowns.channel)
    return nextChoice
end

function Cooldown:ToggleChannel()
    ns.db.cooldowns.channel = (ns.db.cooldowns.channel == "Master") and "SFX" or "Master"
    ns.Warnings:PlayKey(ns.db.cooldowns.soundChoice, ns.db.cooldowns.channel)
    return ns.db.cooldowns.channel
end
