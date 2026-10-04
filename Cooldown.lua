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

local watched = {}      -- [name] = { id, onCooldown, readyAt, duration }

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
function Cooldown:Ready(entry)
    local cfg = ns.db.cooldowns
    entry.onCooldown, entry.readyAt = false, nil
    if not cfg.enabled then return end
    -- Nobody needs to know Stormstrike is up while standing in a city
    if cfg.combatOnly and not InCombatLockdown() then return end

    if ns.Bar then ns.Bar:FlashIcon(entry.icon) end

    if cfg.screen then
        ns.Warnings:Alert(("%s is up"):format(entry.name), 0.5, 0.9, 1, cfg.sound)
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
        end
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
