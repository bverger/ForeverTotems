--------------------------------------------------------------------------------
-- Forever Totems - Core.lua
-- Totem state, element learning and shared helpers.
--------------------------------------------------------------------------------
local ADDON, ns = ...

ns.version = "1.0.0"

--------------------------------------------------------------------------------
-- Totem slots (the client defines them, but we take nothing for granted)
--------------------------------------------------------------------------------
local FIRE  = _G.FIRE_TOTEM_SLOT  or 1
local EARTH = _G.EARTH_TOTEM_SLOT or 2
local WATER = _G.WATER_TOTEM_SLOT or 3
local AIR   = _G.AIR_TOTEM_SLOT   or 4
local MAX_SLOTS = _G.MAX_TOTEMS or 4

ns.FIRE, ns.EARTH, ns.WATER, ns.AIR = FIRE, EARTH, WATER, AIR
ns.MAX_SLOTS = MAX_SLOTS

ns.ELEMENTS = {
    [FIRE]  = { key = "FIRE",  label = "Fire",  color = { 0.98, 0.42, 0.16 } },
    [EARTH] = { key = "EARTH", label = "Earth", color = { 0.76, 0.55, 0.28 } },
    [WATER] = { key = "WATER", label = "Water",   color = { 0.25, 0.60, 0.98 } },
    [AIR]   = { key = "AIR",   label = "Air",   color = { 0.55, 0.88, 0.92 } },
}
ns.DEFAULT_ORDER = { FIRE, EARTH, WATER, AIR }

--------------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------------
local defaults = {
    dbVersion = 4,
    bar = {
        point = "CENTER", x = 0, y = -180,
        scale = 1.0, size = 44, spacing = 6,
        orientation = "HORIZONTAL",
        locked = false,
        hidden = false,
        showTimerText = true,
        showKeybindText = true,
        showSequenceButton = true,
        showCallButton = true,
        showPurgeButton = true,
        showArrows = true,
        hideEmptySlots = false,
        order = { FIRE, EARTH, WATER, AIR },
    },
    warnings = {
        expire = true, expireAt = 4,
        death = true,
        range = true, rangeYards = 22,
        sound = true, chat = true, screen = true,
        soundChoice = "soft",
    },
    sequence = { reset = "12" },
    swing = { enabled = true, height = 12, showText = true },
    weapon = {
        spell = nil, warn = true, warnBelow = 0, sound = true,
        offHand = false, button = true,
    },
    binds = { sequence = nil, slots = {} },
    rightClickDestroy = true,
    callSpell = nil,     -- which "Call of ..." the bar button uses
    syncTotemBar = true, -- mirror the active set into the game's totem bar
    fallbackLastCast = true,
    skipActiveTotems = false, -- opt-in: out of combat, aim the set button at what is missing
    sets = {},
    learned = {},   -- [spell name] = slot
    durations = {}, -- [spell name] = duration in seconds (learned)
    chars = {},     -- [nombre-reino] = { activeSet = n }
    debug = false,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local PREFIX = "|cff4fc3f7Forever Totems|r: "

function ns:Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

function ns:Debug(...)
    if self.db and self.db.debug then
        print("|cff888888FT dbg|r " .. strjoin(" ", tostringall(...)))
    end
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Internal callbacks (bar / warnings / options subscribe here)
local callbacks = {}
function ns:On(event, fn)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], fn)
end
function ns:Fire(event, ...)
    local list = callbacks[event]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

--------------------------------------------------------------------------------
-- Secret values (12.0+)
--
-- In combat, encounters, dungeons or PvP the client returns totem data as
-- "secret": it can be handed to engine APIs, but looking at it from Lua
-- (comparing it, testing it, doing arithmetic on it) is an error. Here we only
-- detect it; the addon never stores one.
--------------------------------------------------------------------------------
local function AnySecret(...)
    if _G.hasanysecretvalues then return hasanysecretvalues(...) end
    if not _G.issecretvalue then return false end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return true end
    end
    return false
end
ns.AnySecret = AnySecret

function ns:IsSecret()
    return self.state.secret and true or false
end

--------------------------------------------------------------------------------
-- API compatibility (the Forever client uses C_Spell / C_SpellBook)
--------------------------------------------------------------------------------
function ns.SpellInfo(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID or info.originalIconID, info.spellID or id end
    elseif _G.GetSpellInfo then
        local name, _, icon = _G.GetSpellInfo(id)
        if name then return name, icon, id end
    end
    return nil
end

function ns.SpellTextureByName(name)
    if not name then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(name) end
    if _G.GetSpellTexture then return _G.GetSpellTexture(name) end
    return nil
end

-- Walks the spellbook with either the new or the old API
local function IterateSpellbook(callback)
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank then
        local bank = Enum.SpellBookSpellBank.Player
        local lines = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for i = 1, lines do
            local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if line and line.itemIndexOffset and line.numSpellBookItems then
                for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local info = C_SpellBook.GetSpellBookItemInfo(j, bank)
                    if info and info.spellID and not info.isPassive then
                        callback(info.spellID)
                    end
                end
            end
        end
        return true
    elseif _G.GetNumSpellTabs and _G.GetSpellBookItemInfo and _G.GetSpellTabInfo then
        for i = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(i)
            if offset and numSpells then
                for j = offset + 1, offset + numSpells do
                    local itemType, id = GetSpellBookItemInfo(j, "spell")
                    if itemType == "SPELL" and id then callback(id) end
                end
            end
        end
        return true
    end
    return false
end
ns.IterateSpellbook = IterateSpellbook

--------------------------------------------------------------------------------
-- Totem spell detection
--
-- The word "Totem" is derived from the client itself (intersection of several
-- known totem names), so it works in any language without translation.
--------------------------------------------------------------------------------
local KEYWORD_SEEDS = { 2484, 8071, 3599, 5394, 8512 }

-- Element hints by English name. Only a seed: as soon as you cast a totem the
-- addon learns its real slot and remembers it.
local ENGLISH_HINTS = {
    [FIRE]  = { "searing", "fire nova", "magma", "flametongue", "frost resistance" },
    [EARTH] = { "earthbind", "stoneclaw", "stoneskin", "strength of earth", "tremor", "earth elemental" },
    [WATER] = { "healing stream", "mana spring", "mana tide", "poison cleansing", "disease cleansing", "fire resistance" },
    [AIR]   = { "grounding", "nature resistance", "windfury totem", "windwall", "grace of air", "tranquil air", "sentry", "air elemental" },
}

local totemKeyword

local function DeriveTotemKeyword()
    local wordSets, resolved = {}, 0
    for _, id in ipairs(KEYWORD_SEEDS) do
        local name = ns.SpellInfo(id)
        if name then
            resolved = resolved + 1
            local words = {}
            for w in name:gmatch("[^%s]+") do words[w:lower()] = true end
            wordSets[#wordSets + 1] = words
        end
    end
    if resolved < 2 then return nil end

    local common
    for _, words in ipairs(wordSets) do
        if not common then
            common = words
        else
            for w in pairs(common) do
                if not words[w] then common[w] = nil end
            end
        end
    end
    local best
    for w in pairs(common or {}) do
        if not best or #w > #best then best = w end
    end
    return best
end

function ns:GetTotemKeyword()
    if totemKeyword == nil then
        totemKeyword = DeriveTotemKeyword() or "totem"
        self:Debug("totem keyword:", totemKeyword)
    end
    return totemKeyword
end

-- A spell's element: what we learned beats the English hint
function ns:GetSpellSlot(spellName)
    if not spellName then return nil end
    local learned = self.db and self.db.learned[spellName]
    if learned then return learned end
    local lower = spellName:lower()
    for slot, hints in pairs(ENGLISH_HINTS) do
        for _, hint in ipairs(hints) do
            if lower:find(hint, 1, true) then return slot end
        end
    end
    return nil
end

-- ns.totemSpells        -> flat list { name, icon, slot }
-- ns.totemSpellsBySlot  -> [slot] = { entries }  (slot 0 = unclassified)
function ns:RefreshTotemSpells()
    local keyword = self:GetTotemKeyword()
    local seen, list = {}, {}

    local function consider(id)
        local name, icon = self.SpellInfo(id)
        if not name or seen[name] then return end
        local isTotem = name:lower():find(keyword, 1, true) ~= nil
        if not isTotem and self.db.learned[name] then isTotem = true end
        if not isTotem then return end
        seen[name] = true
        list[#list + 1] = { name = name, icon = icon, slot = self:GetSpellSlot(name) or 0 }
    end

    if not IterateSpellbook(consider) then
        self:Debug("no spellbook API available")
    end

    -- Totems already learned are included even if the spellbook cannot be read
    for name, slot in pairs(self.db.learned) do
        if not seen[name] then
            seen[name] = true
            list[#list + 1] = { name = name, icon = self.SpellTextureByName(name), slot = slot }
        end
    end

    table.sort(list, function(a, b)
        if a.slot ~= b.slot then return a.slot < b.slot end
        return a.name < b.name
    end)

    local bySlot = { [0] = {} }
    for slot = 1, MAX_SLOTS do bySlot[slot] = {} end
    for _, entry in ipairs(list) do
        local bucket = bySlot[entry.slot] or bySlot[0]
        bucket[#bucket + 1] = entry
    end

    self.totemSpells, self.totemSpellsBySlot = list, bySlot
    self:Fire("SPELLS_REFRESHED")
    return list
end

--------------------------------------------------------------------------------
-- World position (in yards) for the range warning
--------------------------------------------------------------------------------
function ns.GetWorldPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetWorldPosFromMapPos) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return nil end
    local px, py = pos:GetXY()
    if not px or (px == 0 and py == 0) then return nil end
    local continent, world = C_Map.GetWorldPosFromMapPos(map, pos)
    if not world then return nil end
    local wx, wy = world:GetXY()
    if not wx then return nil end
    return wx, wy, continent
end

--------------------------------------------------------------------------------
-- Totem state
--------------------------------------------------------------------------------
local state = { totems = {}, lastBySlot = {}, pending = nil, combat = false }
ns.state = state
for slot = 1, MAX_SLOTS do state.totems[slot] = { have = false } end

function ns:ScanTotems()
    if not _G.GetTotemInfo then return end
    local now = GetTime()
    local changed = false
    local anySecret = false

    for slot = 1, MAX_SLOTS do
        local cur = state.totems[slot]
        local have, name, start, duration, icon = GetTotemInfo(slot)

        if AnySecret(have, name, start, duration, icon) then
            -- The client hides this slot from us. Keep the last thing we knew
            -- and expire it with our own clock.
            anySecret = true
            if cur.have and (cur.start + cur.duration) - now <= 0 then
                cur.have = false
                changed = true
            end
        elseif have and duration and duration > 0 then
            if (not cur.have) or cur.start ~= start or cur.name ~= name or cur.synthetic then
                local pending, spellName = state.pending, nil
                if pending and (now - pending.time) <= 2.5 then
                    local sameName = pending.name == name
                    local sameIcon = icon and pending.icon and icon == pending.icon
                    local looksTotem = pending.name and pending.name:lower():find(self:GetTotemKeyword(), 1, true)
                    if sameName or sameIcon or looksTotem then
                        spellName = pending.name
                        self.db.learned[spellName] = slot
                        state.lastBySlot[slot] = { name = spellName, icon = pending.icon or icon }
                    end
                end

                cur.have, cur.name, cur.start, cur.duration, cur.icon = true, name, start, duration, icon
                cur.spellName = spellName or cur.spellName
                cur.synthetic = false
                cur.warnedExpire, cur.warnedRange, cur.lastRangeWarn = false, false, 0
                cur.wx, cur.wy, cur.wc = self.GetWorldPos()
                changed = true

                -- Learning the duration is what lets us keep counting in
                -- combat, once the client stops telling us.
                if cur.spellName then self.db.durations[cur.spellName] = duration end

                if self.Warnings then self.Warnings:OnTotemPlaced(slot, cur) end
            else
                cur.duration = duration
            end
        elseif cur.have then
            local remaining = (cur.start + cur.duration) - now
            cur.have = false
            changed = true
            -- If we were estimating blind, we cannot know if it was killed
            if self.Warnings and not cur.synthetic then
                self.Warnings:OnTotemLost(slot, cur, remaining)
            end
        end
    end

    state.secret = anySecret
    if changed then self:Fire("TOTEMS_CHANGED") end
end

-- Totem cast while the client hides the data: rebuild it from the element and
-- duration we already learned for that same spell.
function ns:PlaceSyntheticTotem(spellName, icon)
    local slot = self.db.learned[spellName] or self:GetSpellSlot(spellName)
    if not slot then return false end
    local duration = self.db.durations[spellName]
    if not duration then return false end

    local cur = state.totems[slot]
    cur.have, cur.name, cur.start, cur.duration = true, spellName, GetTime(), duration
    cur.icon = icon or cur.icon
    cur.spellName, cur.synthetic = spellName, true
    cur.warnedExpire, cur.warnedRange, cur.lastRangeWarn = false, false, 0
    cur.wx, cur.wy, cur.wc = self.GetWorldPos()
    state.lastBySlot[slot] = { name = spellName, icon = cur.icon }
    self:Fire("TOTEMS_CHANGED")
    return true
end

function ns:GetTotem(slot)
    return state.totems[slot]
end

function ns:TotemRemaining(slot)
    local t = state.totems[slot]
    if not (t and t.have) then return 0 end
    return math.max(0, (t.start + t.duration) - GetTime())
end

--------------------------------------------------------------------------------
-- Queue for actions blocked by combat
--------------------------------------------------------------------------------
local pendingOutOfCombat = {}

function ns:RunWhenPossible(key, fn)
    if InCombatLockdown() then
        pendingOutOfCombat[key] = fn
        return false
    end
    fn()
    return true
end

local function FlushPending()
    for key, fn in pairs(pendingOutOfCombat) do
        pendingOutOfCombat[key] = nil
        fn()
    end
end

--------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then return end
        ForeverTotemsDB = CopyDefaults(ForeverTotemsDB or {}, defaults)
        ns.db = ForeverTotemsDB

        -- Off by default: it only ever worked out of combat, so it is opt-in
        if (ns.db.dbVersion or 1) < 2 then
            ns.db.skipActiveTotems = false
            ns.db.dbVersion = 2
        end
        -- The purge module is gone: the client will not let any addon read
        -- enemy auras in combat nor hook the combat log.
        ns.db.purge = nil

        -- Back on by request: the cycle now anchors itself on the first hit
        -- that lands, which is what made it drift before.
        if (ns.db.dbVersion or 1) < 4 then
            ns.db.swing.enabled = true
            ns.db.dbVersion = 4
        end

        local charName = UnitName("player") or "?"
        local realm = GetRealmName() or "?"
        ns.charKey = charName .. "-" .. realm
        ns.db.chars[ns.charKey] = ns.db.chars[ns.charKey] or {}
        ns.charDB = ns.db.chars[ns.charKey]

        local _, classToken = UnitClass("player")
        ns.isShaman = (classToken == "SHAMAN")

        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_TOTEM_UPDATE")
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        ns:Fire("DB_READY")

    elseif event == "PLAYER_LOGIN" then
        if not ns.isShaman then
            ns:Debug("not a shaman, addon stays idle")
            return
        end
        ns:RefreshTotemSpells()
        ns.Sets:EnsureDefaultSet()
        ns.Bar:Create()
        ns.Sets:CreateSequenceButton()
        ns.Sets:Apply()
        ns.Weapon:Enable()
        ns.Swing:Enable()
        ns:ApplyBindings()
        ns:ScanTotems()
        ns:Fire("READY")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if ns.isShaman then ns:ScanTotems() end

    elseif event == "PLAYER_TOTEM_UPDATE" then
        if ns.isShaman then ns:ScanTotems() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not ns.isShaman then return end
        local unit, _, spellID = ...
        if unit ~= "player" or not spellID then return end
        local spellName, icon = ns.SpellInfo(spellID)
        if spellName then
            state.pending = { id = spellID, name = spellName, icon = icon, time = GetTime() }
            if state.secret then ns:PlaceSyntheticTotem(spellName, icon) end
        end

    elseif event == "SPELLS_CHANGED" then
        if not ns.isShaman or not ns.db then return end
        if ns.spellRefreshTimer then return end
        ns.spellRefreshTimer = true
        C_Timer.After(1, function()
            ns.spellRefreshTimer = nil
            ns:RefreshTotemSpells()
            ns.Sets:EnsureDefaultSet()
            ns.Sets:Apply()
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        state.combat = true

    elseif event == "PLAYER_REGEN_ENABLED" then
        state.combat = false
        FlushPending()
        ns:ScanTotems()   -- out of combat the real data comes back
        ns:Fire("COMBAT_ENDED")
    end
end)
