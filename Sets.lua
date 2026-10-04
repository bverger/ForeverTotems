--------------------------------------------------------------------------------
-- Forever Totems - Sets.lua
-- Totem sets, whole-set button and keybinds.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Sets = {}
ns.Sets = Sets

local MAX_SLOTS = ns.MAX_SLOTS

--------------------------------------------------------------------------------
-- Set access
--------------------------------------------------------------------------------
function Sets:GetActiveIndex()
    local idx = ns.charDB and ns.charDB.activeSet or 1
    if not ns.db.sets[idx] then idx = 1 end
    return idx
end

function Sets:GetActive()
    return ns.db.sets[self:GetActiveIndex()]
end

function Sets:SetActive(index)
    if not ns.db.sets[index] then return false end
    ns.charDB.activeSet = index
    self:Apply()
    ns:Fire("SET_CHANGED")
    return true
end

function Sets:FindByName(name)
    if not name then return nil end
    local lower = name:lower()
    for i, set in ipairs(ns.db.sets) do
        if set.name:lower() == lower then return i end
    end
    for i, set in ipairs(ns.db.sets) do
        if set.name:lower():find(lower, 1, true) then return i end
    end
    return nil
end

function Sets:New(name)
    local set = { name = name or ("Set " .. (#ns.db.sets + 1)), spells = {} }
    table.insert(ns.db.sets, set)
    ns:Fire("SETS_CHANGED")
    return #ns.db.sets, set
end

function Sets:Delete(index)
    if #ns.db.sets <= 1 then return false end
    table.remove(ns.db.sets, index)
    for _, char in pairs(ns.db.chars) do
        if char.activeSet and char.activeSet >= index then
            char.activeSet = math.max(1, char.activeSet - 1)
        end
    end
    self:Apply()
    ns:Fire("SETS_CHANGED")
    return true
end

function Sets:Rename(index, name)
    local set = ns.db.sets[index]
    if not set or not name or name == "" then return false end
    set.name = name
    ns:Fire("SETS_CHANGED")
    return true
end

-- spell = { name = ..., icon = ... } or nil to clear the slot
function Sets:AssignSpell(index, slot, spell)
    local set = ns.db.sets[index]
    if not set then return false end
    set.spells[slot] = spell and { name = spell.name, icon = spell.icon } or nil
    if spell and spell.name then
        -- assigning by hand also teaches the totem's element
        ns.db.learned[spell.name] = slot
    end
    self:Apply()
    ns:Fire("SETS_CHANGED")
    return true
end

--------------------------------------------------------------------------------
-- What each slot casts
--------------------------------------------------------------------------------
function Sets:GetSpellForSlot(slot)
    local set = self:GetActive()
    local spell = set and set.spells[slot]
    if spell and spell.name then return spell end
    -- Nothing configured: the last totem you cast for that element
    if ns.db.fallbackLastCast then return ns.state.lastBySlot[slot] end
    return nil
end

function Sets:EnsureDefaultSet()
    if #ns.db.sets == 0 then
        local _, set = self:New("Default")
        -- First known totem of each element as a starting point
        for slot = 1, MAX_SLOTS do
            local bucket = ns.totemSpellsBySlot and ns.totemSpellsBySlot[slot]
            local first = bucket and bucket[1]
            if first then set.spells[slot] = { name = first.name, icon = first.icon } end
        end
    end
    ns.charDB.activeSet = ns.charDB.activeSet or 1
end

--------------------------------------------------------------------------------
-- Sequence button: one press casts the next totem in the set
--
-- Done with /castsequence because it is the only thing that can advance on its
-- own in combat without the client blocking it for security.
--------------------------------------------------------------------------------
-- The first totem of the set that is not currently out
function Sets:GetNextMissingSpell()
    for _, slot in ipairs(ns.db.bar.order or ns.DEFAULT_ORDER) do
        local spell = self:GetSpellForSlot(slot)
        if spell and spell.name then
            local totem = ns:GetTotem(slot)
            if not (totem and totem.have) then return spell, slot end
        end
    end
    return nil
end

-- Macro conditionals have nothing for totems, so "skip what is already out"
-- cannot live in the macro itself: the addon rewrites the first line whenever
-- the totems change. [nocombat] guards it because in combat the attributes are
-- frozen and the client hides totem state anyway, so the sequence takes over.
function Sets:GetSequenceMacro()
    local names, order = {}, (ns.db.bar.order or ns.DEFAULT_ORDER)
    for _, slot in ipairs(order) do
        local spell = self:GetSpellForSlot(slot)
        if spell and spell.name then names[#names + 1] = spell.name end
    end
    if #names == 0 then return nil end
    local reset = ns.db.sequence.reset
    local prefix = (reset and reset ~= "" and reset ~= "0") and ("reset=" .. reset .. " ") or ""
    local body = "/castsequence " .. prefix .. table.concat(names, ", ")

    if ns.db.skipActiveTotems then
        local missing = self:GetNextMissingSpell()
        if missing then
            body = ("/cast [nocombat] %s\n%s"):format(missing.name, body)
        end
    end

    return body
end

function Sets:CreateSequenceButton()
    if self.seqButton then return self.seqButton end
    local b = CreateFrame("Button", "ForeverTotemsSequenceButton", UIParent, "SecureActionButtonTemplate")
    b:Hide()
    b:RegisterForClicks("AnyUp")
    self.seqButton = b
    return b
end

--------------------------------------------------------------------------------
-- A real game macro, so the set can live on a normal action bar
--
-- Macro names are capped at 16 characters and the body at 255, which four
-- totem names fit into comfortably.
--------------------------------------------------------------------------------
local MACRO_NAME = "FTTotems"

function Sets:GetMacroIndex()
    if type(_G.GetMacroIndexByName) ~= "function" then return nil end
    local index = GetMacroIndexByName(MACRO_NAME)
    return (index and index > 0) and index or nil
end

-- pickup: put it on the cursor so the player just clicks an action slot
-- Returns index, reason
function Sets:CreateOrUpdateMacro(pickup)
    if type(_G.CreateMacro) ~= "function" then return nil, "this client has no macro API" end
    if InCombatLockdown() then return nil, "not in combat" end

    local body = self:GetSequenceMacro()
    if not body then return nil, "the active set has no totems assigned" end
    if #body > 255 then body = body:sub(1, 255) end

    local icon
    for _, slot in ipairs(ns.db.bar.order or ns.DEFAULT_ORDER) do
        local spell = self:GetSpellForSlot(slot)
        if spell and spell.icon then icon = spell.icon break end
    end
    icon = icon or "INV_Misc_QuestionMark"

    local index = self:GetMacroIndex()
    local ok, result
    if index then
        ok, result = pcall(EditMacro, index, MACRO_NAME, icon, body)
        if not ok then return nil, "could not update the macro" end
    else
        ok, result = pcall(CreateMacro, MACRO_NAME, icon, body, false)
        if not ok or not result then return nil, "could not create the macro (are all 120 slots used?)" end
        index = result
    end

    if pickup and type(_G.PickupMacro) == "function" then
        pcall(PickupMacro, index)
    end
    return index
end

--------------------------------------------------------------------------------
-- Push the set onto the secure buttons (out of combat only)
--------------------------------------------------------------------------------
function Sets:Apply()
    ns:RunWhenPossible("sets-apply", function()
        local macro = self:GetSequenceMacro()

        local b = self.seqButton
        if b then
            b:SetAttribute("type", macro and "macro" or nil)
            b:SetAttribute("macrotext", macro or "")
        end

        if ns.Bar and ns.Bar.frame then
            ns.Bar:ApplyAttributes()
            ns.Bar:UpdateAll()
        end

        -- Keep the game's totem bar in step, so the call spell drops this set
        if ns.db.syncTotemBar and ns.TotemBar then
            ns.TotemBar:SyncActiveSet()
        end

        -- If the player made the macro, keep it matching the set. Never
        -- creates one on its own.
        if self:GetMacroIndex() then self:CreateOrUpdateMacro(false) end
    end)
end

-- Cheap refresh for the cast buttons alone: called on every totem change, so
-- it must not touch the game's totem bar or the secure slot buttons.
function Sets:RefreshCastButtons()
    if not ns.db.skipActiveTotems then return end
    if InCombatLockdown() then return end

    local macro = self:GetSequenceMacro()
    if ns.Bar and ns.Bar.seqButton then
        ns.Bar.seqButton:SetAttribute("type", macro and "macro" or nil)
        ns.Bar.seqButton:SetAttribute("macrotext", macro or "")
    end
    if self.seqButton then
        self.seqButton:SetAttribute("type", macro and "macro" or nil)
        self.seqButton:SetAttribute("macrotext", macro or "")
    end
    if self:GetMacroIndex() then self:CreateOrUpdateMacro(false) end
end

--------------------------------------------------------------------------------
-- Keybinds (overrides: they do not touch the player's saved bindings)
--------------------------------------------------------------------------------
function ns:ApplyBindings()
    self:RunWhenPossible("bindings", function()
        local owner = ns.Bar and ns.Bar.frame
        if not owner then return end
        ClearOverrideBindings(owner)

        for slot = 1, MAX_SLOTS do
            local key = ns.db.binds.slots[slot]
            local button = _G["ForeverTotemsButton" .. slot]
            if key and key ~= "" and button then
                SetOverrideBindingClick(owner, true, key, button:GetName(), "LeftButton")
            end
        end

        local seqKey = ns.db.binds.sequence
        if seqKey and seqKey ~= "" and ns.Sets.seqButton then
            SetOverrideBindingClick(owner, true, seqKey, "ForeverTotemsSequenceButton", "LeftButton")
        end

        local shieldKey = ns.db.binds.shield
        if shieldKey and shieldKey ~= "" and _G.ForeverTotemsShieldButton then
            SetOverrideBindingClick(owner, true, shieldKey, "ForeverTotemsShieldButton", "LeftButton")
        end

        local weaponKey = ns.db.binds.weapon
        if weaponKey and weaponKey ~= "" and _G.ForeverTotemsWeaponButton then
            SetOverrideBindingClick(owner, true, weaponKey, "ForeverTotemsWeaponButton", "LeftButton")
        end

        local callKey = ns.db.binds.call
        if callKey and callKey ~= "" and _G.ForeverTotemsCallButton then
            SetOverrideBindingClick(owner, true, callKey, "ForeverTotemsCallButton", "LeftButton")
        end

        if ns.Bar and ns.Bar.UpdateKeybindText then ns.Bar:UpdateKeybindText() end
    end)
end

function ns:SetBinding(target, key)
    -- target: slot number or "sequence"; key nil or "" to clear
    if key and key ~= "" then
        -- a key cannot be bound in two places at once
        if ns.db.binds.sequence == key then ns.db.binds.sequence = nil end
        if ns.db.binds.call == key then ns.db.binds.call = nil end
        if ns.db.binds.weapon == key then ns.db.binds.weapon = nil end
        if ns.db.binds.shield == key then ns.db.binds.shield = nil end
        for slot = 1, MAX_SLOTS do
            if ns.db.binds.slots[slot] == key then ns.db.binds.slots[slot] = nil end
        end
    end
    if target == "sequence" then
        ns.db.binds.sequence = key
    elseif target == "call" then
        ns.db.binds.call = key
    elseif target == "weapon" then
        ns.db.binds.weapon = key
    elseif target == "shield" then
        ns.db.binds.shield = key
    else
        ns.db.binds.slots[target] = key
    end
    self:ApplyBindings()
    self:Fire("BINDS_CHANGED")
end
