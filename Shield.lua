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
-- A spell id that does not exist on this client gives no name at all, and the
-- only Water Shield seed used to be a later expansion's, so Water Shield never
-- made the list. Every id it has had is tried now, and the English names catch
-- whatever id this client gave it.
local SHIELD_SEED_IDS = {
    324,                            -- Lightning Shield
    24398, 33736, 52127, 408510,    -- Water Shield
    974, 32593, 32594,              -- Earth Shield
}
local SHIELD_ENGLISH_NAMES = { "Lightning Shield", "Water Shield", "Earth Shield" }

local state = { active = false, expires = 0, charges = 0, warned = false, blocked = false }

--------------------------------------------------------------------------------
-- Which shields does this shaman know
--------------------------------------------------------------------------------
function Shield:Scan()
    local wanted, list, seen = {}, {}, {}
    for _, name in ipairs(SHIELD_ENGLISH_NAMES) do wanted[name] = true end
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
-- Any single field of an aura can come through secret, and reading one of
-- those is an error, not a nil.
local function Field(aura, key, default)
    local value = aura[key]
    if value == nil or ns.AnySecret(value) then return default end
    return value
end

-- Someone else's shield on you is not your shield. A resto shaman in the group
-- putting Earth Shield on you is the common case, and it used to be the one
-- the button picked up, which is why a second shaman appeared to break it.
-- Returns true, false, or nil when the client does not say.
local function CastByYou(aura)
    local mine = Field(aura, "isFromPlayerOrPlayerPet")
    if mine ~= nil then return mine and true or false end
    local source = Field(aura, "sourceUnit")
    if source ~= nil then return source == "player" end
    return nil
end

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

    local chosen = self:GetChosen()
    local wanted, other

    for _, aura in ipairs(auras) do
        if not ns.AnySecret(aura) then
            local name = Field(aura, "name")
            if name and names[name] and CastByYou(aura) ~= false then
                -- The one on the button wins; any other shield of yours is
                -- better than nothing
                if chosen and name == chosen.name then
                    wanted = wanted or aura
                else
                    other = other or aura
                end
            end
        end
    end

    local aura = wanted or other
    if aura then
        state.active = true
        state.name = Field(aura, "name")
        state.expires = Field(aura, "expirationTime", 0)
        -- Charges matter more than the clock on a shield
        state.charges = Field(aura, "applications") or Field(aura, "charges", 0)
        state.warned = false
    else
        state.active, state.charges, state.expires = false, 0, 0
    end

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
-- UNIT_AURA fires constantly in a group, so anything that goes wrong in here
-- goes wrong hundreds of times. It is reported once and counted after that.
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    ns.Safely("the shield", function()
        if event == "PLAYER_REGEN_DISABLED" then
            Shield:CheckForFight()
        elseif event == "UNIT_AURA" then
            if unit == "player" then Shield:Refresh() end
        elseif event == "SPELLS_CHANGED" then
            Shield.spells = nil
            Shield:Refresh()
        end
    end)
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
