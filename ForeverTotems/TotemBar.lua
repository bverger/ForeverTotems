--------------------------------------------------------------------------------
-- Forever Totems - TotemBar.lua
-- Integration with Forever's native totem bar: the "Call of ..." spells place
-- four totems with a single cast.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local TB = {}
ns.TotemBar = TB

-- Detected by name (the hint below) and, as a fallback, by the spell IDs
-- Wrath used for these, in case Forever reuses them. On build 70009 it does:
-- Call of the Elements is still 66842.
local LEGACY_CALL_IDS = { 66842, 66843, 66844 }
local NAME_HINT = "call of"

-- Captures every return value of a call, without letting it blow up
local function TryCall(fn, ...)
    local packed = { pcall(fn, ...) }
    local ok = table.remove(packed, 1)
    return ok, packed
end

local function SpellList(values)
    local names = {}
    for _, v in ipairs(values) do
        if type(v) == "number" then
            local name = ns.SpellInfo(v)
            names[#names + 1] = name and ("%s (%d)"):format(name, v) or tostring(v)
        elseif v ~= nil then
            names[#names + 1] = tostring(v)
        end
    end
    return table.concat(names, ", ")
end

--------------------------------------------------------------------------------
-- The "Call of ..." spells
--------------------------------------------------------------------------------
function TB:Scan()
    local found, seen = {}, {}

    local function consider(id)
        local name, icon = ns.SpellInfo(id)
        if not name or seen[name] then return end

        local matches = name:lower():find(NAME_HINT, 1, true) ~= nil
        if not matches then
            for _, legacy in ipairs(LEGACY_CALL_IDS) do
                if id == legacy then matches = true end
            end
        end
        if matches then
            seen[name] = true
            found[#found + 1] = { name = name, icon = icon, id = id }
        end
    end

    if ns.IterateSpellbook then ns.IterateSpellbook(consider) end
    self.spells = found
    return found
end

function TB:GetSpells()
    return self.spells or self:Scan()
end

function TB:GetActiveCall()
    local list = self:GetSpells()
    if #list == 0 then return nil end
    local chosen = ns.db.callSpell
    if chosen then
        for _, spell in ipairs(list) do
            if spell.name == chosen then return spell end
        end
    end
    return list[1]
end

function TB:CycleCall()
    local list = self:GetSpells()
    if #list == 0 then return nil end
    local current, index = self:GetActiveCall(), 1
    for i, spell in ipairs(list) do
        if current and spell.name == current.name then index = i end
    end
    local nextSpell = list[(index % #list) + 1]
    ns.db.callSpell = nextSpell.name
    if ns.Bar then
        ns.Bar:ApplyAttributes()
        ns.Bar:UpdateAll()
    end
    return nextSpell
end

function TB:HasAPI()
    return type(_G.SetMultiCastSpell) == "function"
        and type(_G.GetMultiCastTotemSpells) == "function"
end

--------------------------------------------------------------------------------
-- Writing the addon's set into the game's totem bar
--
-- Layout confirmed on build 70009: GetMultiCastTotemSpells(1..4) lists the
-- valid spells for fire, earth, water and air, and the action slots run
-- 133..144 in three pages of four (page 1 Call of the Elements, page 2
-- Ancestors, page 3 Spirits).
--------------------------------------------------------------------------------
local FIRST_MULTICAST_ACTION = 133
local CALL_PAGE_BY_ID = { [66842] = 1, [66843] = 2, [66844] = 3 }

local function ButtonsPerPage() return _G.NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4 end
local function NumPages() return _G.NUM_MULTI_CAST_PAGES or 3 end

function TB:GetPageForCall(spell)
    spell = spell or self:GetActiveCall()
    if not spell then return 1 end
    if CALL_PAGE_BY_ID[spell.id] then return CALL_PAGE_BY_ID[spell.id] end
    for index, candidate in ipairs(self:GetSpells()) do
        if candidate.name == spell.name then return math.min(index, NumPages()) end
    end
    return 1
end

function TB:GetActionID(page, slot)
    return FIRST_MULTICAST_ACTION + (page - 1) * ButtonsPerPage() + (slot - 1)
end

-- The totem bar wants a spell ID it considers valid for that element, so take
-- it from the client's own list instead of guessing a rank.
function TB:FindSpellID(slot, spellName)
    if type(_G.GetMultiCastTotemSpells) ~= "function" or not spellName then return nil end
    local ok, values = TryCall(GetMultiCastTotemSpells, slot)
    if not ok then return nil end
    for _, id in ipairs(values) do
        if type(id) == "number" and ns.SpellInfo(id) == spellName then return id end
    end
    return nil
end

-- Returns written, skipped, reason
function TB:SyncActiveSet(page)
    if not self:HasAPI() then return 0, 0, "this client has no totem bar API" end
    if InCombatLockdown() then return 0, 0, "not in combat" end

    page = page or self:GetPageForCall()
    local written, skipped = 0, 0

    for slot = 1, ns.MAX_SLOTS do
        local spell = ns.Sets:GetSpellForSlot(slot)
        if spell and spell.name then
            local spellID = self:FindSpellID(slot, spell.name)
            if spellID then
                local ok = pcall(SetMultiCastSpell, self:GetActionID(page, slot), spellID)
                if ok then written = written + 1 else skipped = skipped + 1 end
            else
                -- The client does not accept that totem in this element slot
                skipped = skipped + 1
            end
        end
    end

    return written, skipped
end

-- What the game's totem bar holds right now on the page we would write to
function TB:ReadPage(page)
    page = page or self:GetPageForCall()
    local contents = {}
    if type(_G.GetActionInfo) ~= "function" then return contents end
    for slot = 1, ns.MAX_SLOTS do
        local ok, values = TryCall(GetActionInfo, self:GetActionID(page, slot))
        if ok and values[1] == "spell" and type(values[2]) == "number" then
            contents[slot] = ns.SpellInfo(values[2])
        end
    end
    return contents
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------
function TB:Report()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
        ns:Print(text)
    end

    add("Totem bar diagnostics:")
    add(("  build %s / interface %s"):format(
        tostring((select(2, GetBuildInfo()))), tostring((select(4, GetBuildInfo())))))
    add(("  SetMultiCastSpell: %s   GetMultiCastTotemSpells: %s"):format(
        type(_G.SetMultiCastSpell), type(_G.GetMultiCastTotemSpells)))

    if type(_G.GetMultiCastTotemSpells) == "function" then
        add("  GetMultiCastTotemSpells:")
        for index = 1, 8 do
            local ok, values = TryCall(GetMultiCastTotemSpells, index)
            if ok and #values > 0 then
                add(("    [%d] %s"):format(index, SpellList(values)))
            elseif not ok then
                add(("    [%d] error"):format(index))
            end
        end
    end

    local page = self:GetPageForCall()
    add(("  page %d (slots %d-%d):"):format(page, self:GetActionID(page, 1), self:GetActionID(page, ns.MAX_SLOTS)))
    local contents = self:ReadPage(page)
    for slot = 1, ns.MAX_SLOTS do
        add(("    %s: %s"):format(ns.ELEMENTS[slot].label, contents[slot] or "-"))
    end

    local calls = self:Scan()
    add(("  Call spells known: %d"):format(#calls))
    for _, spell in ipairs(calls) do
        add(("    %s (id %s, page %d)"):format(spell.name, tostring(spell.id), self:GetPageForCall(spell)))
    end

    return table.concat(lines, "\n")
end
