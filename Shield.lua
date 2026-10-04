--------------------------------------------------------------------------------
-- Forever Totems - Shield.lua
-- Lightning Shield and friends: how many charges are left, and a shout when you
-- walk into a fight without one.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Shield = {}
ns.Shield = Shield

-- Seeds only, to learn the localised names. Lightning, Water and Earth Shield:
-- whichever ones this shaman knows show up in the flyout.
local SHIELD_SEED_IDS = { 324, 52127, 974 }

local state = { active = false, expires = 0, charges = 0, warned = false, blocked = false }

--------------------------------------------------------------------------------
-- Which shields does this shaman know
--------------------------------------------------------------------------------
function Shield:Scan()
    local wanted, list, seen = {}, {}, {}
    for _, id in ipairs(SHIELD_SEED_IDS) do
        local name = ns.SpellInfo(id)
        if name then wanted[name] = true end
    end

    local function consider(id)
        local name, icon = ns.SpellInfo(id)
        if name and wanted[name] and not seen[name] then
            seen[name] = true
            list[#list + 1] = { name = name, icon = icon, id = id }
        end
    end

    if ns.IterateSpellbook then ns.IterateSpellbook(consider) end
    self.spells = list
    return list
end

function Shield:GetSpells()
    return self.spells or self:Scan()
end

function Shield:GetChosen()
    local list = self:GetSpells()
    if #list == 0 then return nil end
    local chosen = ns.db.shield.spell
    if chosen then
        for _, spell in ipairs(list) do
            if spell.name == chosen then return spell end
        end
    end
    return list[1]
end

function Shield:SetChosen(spell)
    ns.db.shield.spell = spell and spell.name or nil
    if ns.Bar then
        ns.Bar:ApplyAttributes()
        ns.Bar:UpdateAll()
    end
end

--------------------------------------------------------------------------------
-- Is one up, and with how many charges
--------------------------------------------------------------------------------
function Shield:Refresh()
    local names = {}
    for _, spell in ipairs(self:GetSpells()) do names[spell.name] = true end
    if not next(names) then return end

    local auras, blocked = ns.Weapon:EnumerateBuffs("player")
    if blocked then
        state.blocked = true          -- never warn on data we could not read
        return
    end
    state.blocked = false

    for _, aura in ipairs(auras) do
        if not ns.AnySecret(aura) and aura.name and names[aura.name] then
            state.active = true
            state.name = aura.name
            state.expires = aura.expirationTime or 0
            -- Charges matter more than the clock on a shield
            state.charges = aura.applications or aura.charges or 0
            state.warned = false
            if ns.Bar then ns.Bar:UpdateShieldButton() end
            return
        end
    end

    state.active, state.charges, state.expires = false, 0, 0
    if ns.Bar then ns.Bar:UpdateShieldButton() end
end

function Shield:IsUp() return state.active end
function Shield:Charges() return state.charges or 0 end
function Shield:IsBlocked() return state.blocked and true or false end

function Shield:Remaining()
    if not state.active or not state.expires or state.expires <= 0 then return 0 end
    return math.max(0, state.expires - GetTime())
end

--------------------------------------------------------------------------------
-- The warning
--------------------------------------------------------------------------------
function Shield:CheckForFight()
    local cfg = ns.db.shield
    if not cfg.warn or state.blocked then return end
    if #self:GetSpells() == 0 then return end

    self:Refresh()
    if state.active and self:Charges() > (cfg.warnBelow or 0) then return end
    if state.warned then return end
    state.warned = true

    local chosen = self:GetChosen()
    local text = state.active
        and ("%s down to %d charges"):format(state.name or "Shield", self:Charges())
        or ("No shield up! (%s)"):format(chosen and chosen.name or "none known")
    ns.Warnings:Alert(text, 0.4, 0.7, 1, cfg.sound)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        Shield:CheckForFight()
    elseif event == "UNIT_AURA" then
        if unit == "player" then Shield:Refresh() end
    elseif event == "SPELLS_CHANGED" then
        Shield.spells = nil
        Shield:Refresh()
    end
end)

function Shield:Enable()
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("UNIT_AURA")
    events:RegisterEvent("SPELLS_CHANGED")
    self:Refresh()
end

function Shield:GetMacro()
    local spell = self:GetChosen()
    return spell and ("/cast " .. spell.name) or nil
end
