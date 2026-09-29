--------------------------------------------------------------------------------
-- Forever Totems - Weapon.lua
-- Weapon imbues: which one is on, how long it has left, and a shout when you
-- walk into a fight without one.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Weapon = {}
ns.Weapon = Weapon

-- Seeds only: the names come from the client, and every rank shares a name,
-- so this works in any language and for ranks we never heard of.
local IMBUE_SEED_IDS = { 8017, 8024, 8033, 8232 }

local state = { hasMain = false, expires = 0, warned = false }

--------------------------------------------------------------------------------
-- Which imbues does this shaman know
--------------------------------------------------------------------------------
function Weapon:Scan()
    local wanted, list, seen = {}, {}, {}

    for _, id in ipairs(IMBUE_SEED_IDS) do
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

function Weapon:GetSpells()
    return self.spells or self:Scan()
end

function Weapon:GetChosen()
    local list = self:GetSpells()
    if #list == 0 then return nil end
    local chosen = ns.db.weapon.spell
    if chosen then
        for _, spell in ipairs(list) do
            if spell.name == chosen then return spell end
        end
    end
    return list[1]
end

function Weapon:SetChosen(spell)
    ns.db.weapon.spell = spell and spell.name or nil
    if ns.Bar then
        ns.Bar:ApplyAttributes()
        ns.Bar:UpdateAll()
    end
end

--------------------------------------------------------------------------------
-- Current state
--
-- GetWeaponEnchantInfo is about your own weapons, not an enemy's auras, but
-- everything here is still guarded: this client answers some queries with an
-- error rather than a value.
--------------------------------------------------------------------------------
-- Enumerating buffs by index misses auras on this client (the buff bar showed
-- two, the index loop found one), so the bulk API goes first.
-- Returns a plain array of auras, plus whether the client refused.
function Weapon:EnumerateBuffs(unit)
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok, result = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
        if ok and type(result) == "table" then
            -- Either an array of auras or a wrapper holding one
            local list = result.auras or result
            if type(list) == "table" then return list, false end
        end
        -- If the bulk call fails, fall through to the index loop rather than
        -- giving up: they are two different doors to the same data.
    end

    local list = {}
    if not (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex) then return list, false end
    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, unit, index)
        if not ok then return list, true end
        if not aura then break end
        list[#list + 1] = aura
    end
    return list, false
end

-- The enchant on the weapon is not called like the spell: the spell is
-- "Rockbiter Weapon" and the tooltip line reads "Rockbiter 3 (60 min)". So we
-- work out which word is the generic one (it is the word every imbue name
-- shares) and match on the distinctive part. Same trick as the totem keyword,
-- and it needs no translation.
function Weapon:GetImbueBases()
    if self.bases then return self.bases end

    local spells = self:GetSpells()
    local bases = {}

    local common
    if #spells >= 2 then
        for _, spell in ipairs(spells) do
            local words = {}
            for word in spell.name:gmatch("[^%s]+") do words[word:lower()] = true end
            if not common then
                common = words
            else
                for word in pairs(common) do
                    if not words[word] then common[word] = nil end
                end
            end
        end
    end

    for _, spell in ipairs(spells) do
        local parts = {}
        for word in spell.name:gmatch("[^%s]+") do
            if not (common and common[word:lower()]) then parts[#parts + 1] = word end
        end
        local base = table.concat(parts, " ")
        if base == "" then
            base = spell.name:match("^(%S+)") or spell.name   -- single imbue known
        end
        bases[#bases + 1] = { spell = spell, base = base, full = spell.name }
    end

    self.bases = bases
    return bases
end

-- Third route: read the weapon's own tooltip. This is how Classic addons have
-- always found temporary enchants, and it does not depend on either the enchant
-- API or the aura list.
local scanner

local function GetScanner()
    if scanner then return scanner end
    local ok, frame = pcall(CreateFrame, "GameTooltip", "ForeverTotemsTooltipScanner", nil, "GameTooltipTemplate")
    if not ok or not frame then return nil end
    frame:SetOwner(UIParent, "ANCHOR_NONE")
    scanner = frame
    return scanner
end

-- Returns the lines of the tooltip for an inventory slot
function Weapon:TooltipLines(slot)
    local tip = GetScanner()
    if not tip then return {} end

    tip:ClearLines()
    local ok = pcall(tip.SetInventoryItem, tip, "player", slot)
    if not ok then return {}, true end

    local lines = {}
    for index = 1, (tip:NumLines() or 0) do
        local fs = _G["ForeverTotemsTooltipScannerTextLeft" .. index]
        local text = fs and fs:GetText()
        if text and text ~= "" then lines[#lines + 1] = text end
    end
    return lines, false
end

-- slot 16 main hand, 17 off hand
function Weapon:ScanWeaponTooltip(slot)
    local bases = self:GetImbueBases()
    if #bases == 0 then return nil end

    local lines, blocked = self:TooltipLines(slot or 16)
    if blocked then return nil, true end

    for _, line in ipairs(lines) do
        for _, entry in ipairs(bases) do
            if line:find(entry.full, 1, true) or line:find(entry.base, 1, true) then
                -- Durations show up as "(60 min)" or "(45 sec)"
                local minutes = line:match("(%d+)%s*min")
                local seconds = line:match("(%d+)%s*sec")
                local remaining = (minutes and tonumber(minutes) * 60) or (seconds and tonumber(seconds)) or nil
                return { name = entry.spell.name, spell = entry.spell, remaining = remaining, line = line }
            end
        end
    end
    return nil
end

-- Second route: some versions apply the imbue as a buff on the player instead
-- of a temporary weapon enchant. Whichever one answers, we use.
function Weapon:ScanPlayerAura()
    local names = {}
    for _, spell in ipairs(self:GetSpells()) do names[spell.name] = true end
    if not next(names) then return nil end

    local auras, blocked = self:EnumerateBuffs("player")
    if blocked then return nil, true end

    for _, aura in ipairs(auras) do
        if not ns.AnySecret(aura) and aura.name and names[aura.name] then
            return { name = aura.name, expires = aura.expirationTime or 0, icon = aura.icon }
        end
    end
    return nil
end

function Weapon:Refresh()
    local hasMain, mainExpiration, hasOff, offExpiration

    if type(_G.GetWeaponEnchantInfo) == "function" then
        local ok, packed = pcall(function() return { GetWeaponEnchantInfo() } end)
        if ok then
            local values = packed
            if ns.AnySecret(values[1], values[2], values[5], values[6]) then
                state.blocked = true
                return
            end
            hasMain, mainExpiration = values[1], values[2]
            hasOff, offExpiration = values[5], values[6]
        else
            state.blocked = true
        end
    end

    if hasMain then
        state.blocked = false
        state.hasMain = true
        state.expires = GetTime() + (mainExpiration or 0) / 1000
        state.hasOff = hasOff and true or false
        state.offExpires = state.hasOff and (GetTime() + (offExpiration or 0) / 1000) or 0
    else
        -- No temporary enchant: maybe this version imbues you, not the weapon
        local tooltip, tipBlocked = self:ScanWeaponTooltip(ns.db.weapon.offHand and 17 or 16)
        local aura, blocked = self:ScanPlayerAura()
        if tooltip then
            state.blocked = false
            state.hasMain = true
            state.fromTooltip = true
            state.appliedName = tooltip.name
            state.fromAura = false
            -- The tooltip rounds to whole minutes, so it only refreshes the
            -- countdown when the minute actually changes
            local remaining = tooltip.remaining
            if remaining then
                local current = state.expires - GetTime()
                if math.abs(current - remaining) > 45 or current <= 0 then
                    state.expires = GetTime() + remaining
                end
            elseif state.expires <= GetTime() then
                state.expires = GetTime() + 3600
            end
        elseif blocked or tipBlocked then
            state.blocked = true
        elseif aura then
            state.blocked = false
            state.hasMain = true
            state.expires = (aura.expires and aura.expires > 0) and aura.expires or (GetTime() + 3600)
            state.fromAura = true
            state.fromTooltip = false
        else
            state.blocked = false
            state.hasMain = false
            state.expires = 0
            state.fromAura = false
            state.fromTooltip = false
        end
    end

    if state.hasMain then state.warned = false end
    if ns.Bar then ns.Bar:UpdateWeaponButton() end
end

function Weapon:HasEnchant()
    return state.hasMain
end

function Weapon:Remaining()
    if not state.hasMain then return 0 end
    return math.max(0, state.expires - GetTime())
end

function Weapon:IsBlocked()
    return state.blocked and true or false
end

--------------------------------------------------------------------------------
-- The warning
--------------------------------------------------------------------------------
function Weapon:CheckForFight()
    local cfg = ns.db.weapon
    if not cfg.warn then return end
    if state.blocked then return end     -- never warn on data we could not read
    if #self:GetSpells() == 0 then return end

    self:Refresh()
    if state.hasMain and self:Remaining() > (cfg.warnBelow or 0) then return end
    if state.warned then return end
    state.warned = true

    local chosen = self:GetChosen()
    local text = state.hasMain
        and ("Weapon imbue about to run out (%ds)"):format(math.floor(self:Remaining()))
        or ("No weapon imbue! (%s)"):format(chosen and chosen.name or "none chosen")
    ns.Warnings:Alert(text, 1, 0.5, 0.2, cfg.sound)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        Weapon:CheckForFight()
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        Weapon:Refresh()
    elseif event == "SPELLS_CHANGED" then
        Weapon.spells, Weapon.bases = nil, nil
        Weapon:Refresh()
    end
end)

function Weapon:Enable()
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("UNIT_INVENTORY_CHANGED")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("SPELLS_CHANGED")
    self:Refresh()
end

-- Called from the bar's OnUpdate: catches the imbue running out mid-fight
function Weapon:Update()
    if not ns.db.weapon.warn then return end
    if not state.hasMain then return end
    if self:Remaining() > (ns.db.weapon.warnBelow or 0) then return end
    self:CheckForFight()
end

--------------------------------------------------------------------------------
-- The macro for the button
--------------------------------------------------------------------------------
function Weapon:GetMacro()
    local spell = self:GetChosen()
    if not spell then return nil end
    if ns.db.weapon.offHand then
        -- Off hand needs the second line: the imbue lands on the main hand
        -- otherwise. Slot 17 is the off hand.
        return ("/cast %s\n/use 17"):format(spell.name)
    end
    return "/cast " .. spell.name
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------
function Weapon:Report()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
        ns:Print(text)
    end

    add("Weapon imbue diagnostics:")
    add(("  GetWeaponEnchantInfo: %s"):format(type(_G.GetWeaponEnchantInfo)))

    if type(_G.GetWeaponEnchantInfo) == "function" then
        local ok, packed = pcall(function() return { GetWeaponEnchantInfo() } end)
        if not ok then
            add(("  call errored: %s"):format(tostring(packed)))
        else
            add(("  returned %d values"):format(#packed))
            for index = 1, 8 do
                local value = packed[index]
                add(("    [%d] %s (%s)%s"):format(index, tostring(value), type(value),
                    ns.AnySecret(value) and "  SECRET" or ""))
            end
        end
    end

    add(("  C_UnitAuras.GetUnitAuras: %s"):format(type(C_UnitAuras and C_UnitAuras.GetUnitAuras)))
    local auras, blocked = self:EnumerateBuffs("player")
    add(("  player buffs found: %d%s"):format(#auras, blocked and " (blocked)" or ""))
    for index, aura in ipairs(auras) do
        if ns.AnySecret(aura) then
            add(("    %d: secret"):format(index))
        else
            add(("    %d: %s  expires=%s  duration=%s  spellId=%s"):format(index,
                tostring(aura.name), tostring(aura.expirationTime),
                tostring(aura.duration), tostring(aura.spellId)))
        end
    end

    for _, slot in ipairs({ 16, 17 }) do
        local lines, blocked = self:TooltipLines(slot)
        add(("  tooltip of slot %d: %d lines%s"):format(slot, #lines, blocked and " (blocked)" or ""))
        for index, line in ipairs(lines) do
            add(("    %d: %s"):format(index, line))
        end
    end

    add(("  known imbues: %d"):format(#self:GetSpells()))
    for _, entry in ipairs(self:GetImbueBases()) do
        add(("    matching on \"%s\" (from %s)"):format(entry.base, entry.full))
    end
    for _, spell in ipairs(self:GetSpells()) do
        add(("    %s (id %d)"):format(spell.name, spell.id))
    end
    local chosen = self:GetChosen()
    add(("  chosen: %s"):format(chosen and chosen.name or "none"))
    add(("  state: hasMain=%s remaining=%.0fs blocked=%s fromAura=%s fromTooltip=%s"):format(
        tostring(state.hasMain), self:Remaining(), tostring(state.blocked),
        tostring(state.fromAura), tostring(state.fromTooltip)))
    add(("  button: %s"):format(ns.Bar and ns.Bar.weaponButton and "exists" or "missing"))
    add(("  main hand equipped: %s"):format(
        GetInventoryItemLink and tostring(GetInventoryItemLink("player", 16)) or "?"))

    return table.concat(lines, "\n")
end
