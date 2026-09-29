--------------------------------------------------------------------------------
-- Forever Totems - Options.lua
-- Configuration window, set editor, keybinds and chat commands.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local FONT = "Fonts\\FRIZQT__.TTF"
local MAX_SLOTS = ns.MAX_SLOTS
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local window, refreshers
local sliderCount = 0

--------------------------------------------------------------------------------
-- Widget helpers (with fallbacks in case a template does not exist)
--------------------------------------------------------------------------------
local function TryCreate(frameType, name, parent, templates)
    for _, template in ipairs(templates) do
        local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
        if ok and frame then return frame, template end
    end
    return nil
end

local function MakeLabel(parent, text, x, y, size, r, g, b)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont(FONT, size or 12, "")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(r or 1, g or 0.82, b or 0)
    return fs
end

-- A template may or may not come with its own label: only reuse it if it
-- really is a FontString.
local function AsFontString(v)
    if type(v) == "table" and type(v.SetText) == "function" and type(v.SetFont) == "function" then
        return v
    end
    return nil
end

local function MakeCheck(parent, label, x, y, get, set)
    local cb = TryCreate("CheckButton", nil, parent,
        { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate", "OptionsBaseCheckButtonTemplate" })
    if not cb then
        cb = CreateFrame("CheckButton", nil, parent)
        cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(24, 24)

    local text = AsFontString(cb.Text) or AsFontString(cb.text)
        or (cb:GetName() and AsFontString(_G[cb:GetName() .. "Text"]))
    if not text then
        text = cb:CreateFontString(nil, "ARTWORK")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cb.text = text
    end
    text:SetFont(FONT, 12, "")
    text:SetText(label)
    text:SetTextColor(1, 1, 1)

    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(get()) end
    return cb
end

local function MakeSlider(parent, label, x, y, minV, maxV, step, get, set, format)
    sliderCount = sliderCount + 1
    local s = TryCreate("Slider", "ForeverTotemsSlider" .. sliderCount, parent,
        { "OptionsSliderTemplate", "UISliderTemplateWithLabels" })
    if not s then
        s = CreateFrame("Slider", "ForeverTotemsSlider" .. sliderCount, parent)
        s:SetOrientation("HORIZONTAL")
        s:SetHeight(17)
        s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    s:SetPoint("TOPLEFT", x + 6, y)
    s:SetWidth(210)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    local name = s:GetName()
    if name then
        if _G[name .. "Low"] then _G[name .. "Low"]:SetText(tostring(minV)) end
        if _G[name .. "High"] then _G[name .. "High"]:SetText(tostring(maxV)) end
        if _G[name .. "Text"] then _G[name .. "Text"]:SetText("") end
    end

    local title = s:CreateFontString(nil, "ARTWORK")
    title:SetFont(FONT, 12, "")
    title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
    title:SetTextColor(1, 1, 1)

    local function updateTitle(v) title:SetText(string.format(format or "%s: %d", label, v)) end

    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        updateTitle(value)
        set(value)
    end)
    refreshers[#refreshers + 1] = function()
        local v = get()
        s:SetValue(v)
        updateTitle(v)
    end
    return s
end

local function MakeButton(parent, text, x, y, w, onClick)
    local b = TryCreate("Button", nil, parent, { "UIPanelButtonTemplate" }) or CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w or 90, 22)
    if b.SetText then b:SetText(text) end
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

--------------------------------------------------------------------------------
-- Key capture
--------------------------------------------------------------------------------
local capturing

local IGNORED_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, UNKNOWN = true,
}

local function StopCapture(button)
    if not button then return end
    button:EnableKeyboard(false)
    if button.SetPropagateKeyboardInput then button:SetPropagateKeyboardInput(true) end
    if capturing == button then capturing = nil end
end

local function MakeBindButton(parent, target, label, x, y)
    local b = MakeButton(parent, "", x, y, 110)
    b.target = target

    local caption = b:CreateFontString(nil, "ARTWORK")
    caption:SetFont(FONT, 11, "")
    caption:SetPoint("RIGHT", b, "LEFT", -6, 0)
    caption:SetText(label)
    caption:SetTextColor(0.9, 0.9, 0.9)

    local function currentKey()
        if target == "sequence" then return ns.db.binds.sequence end
        if target == "call" then return ns.db.binds.call end
        if target == "purge" then return ns.db.binds.purge end
        if target == "weapon" then return ns.db.binds.weapon end
        return ns.db.binds.slots[target]
    end

    local function refresh()
        if capturing == b then return end
        b:SetText(currentKey() or "no key")
    end

    b:SetScript("OnClick", function(self)
        if capturing and capturing ~= self then StopCapture(capturing) end
        capturing = self
        self:SetText("press a key")
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    end)

    b:SetScript("OnKeyDown", function(self, key)
        if capturing ~= self then return end
        if IGNORED_KEYS[key] then return end
        if key == "ESCAPE" then
            ns:SetBinding(self.target, nil)
        else
            local combo = key
            if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
            if IsControlKeyDown() then combo = "CTRL-" .. combo end
            if IsAltKeyDown() then combo = "ALT-" .. combo end
            ns:SetBinding(self.target, combo)
        end
        StopCapture(self)
        refresh()
    end)

    b:SetScript("OnHide", function(self) StopCapture(self); refresh() end)
    refreshers[#refreshers + 1] = refresh
    return b
end

--------------------------------------------------------------------------------
-- Set editor
--------------------------------------------------------------------------------
local editor = { columns = {}, pool = {} }
local RefreshEditor

local function AcquireIcon()
    for _, icon in ipairs(editor.pool) do
        if not icon:IsShown() then return icon end
    end
    local b = CreateFrame("Button", nil, window)
    b:SetSize(26, 26)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.hl = b:CreateTexture(nil, "OVERLAY")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.spellName or "", 1, 1, 1)
        GameTooltip:AddLine("Click: assign to this element", 0.4, 0.8, 0.4)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    editor.pool[#editor.pool + 1] = b
    return b
end

function RefreshEditor()
    for _, icon in ipairs(editor.pool) do icon:Hide() end

    local setIndex = ns.Sets:GetActiveIndex()
    local set = ns.Sets:GetActive()
    if editor.setName then editor.setName:SetText(set and set.name or "-") end

    local unassigned = (ns.totemSpellsBySlot and ns.totemSpellsBySlot[0]) or {}

    for i, slot in ipairs(ns.db.bar.order or ns.DEFAULT_ORDER) do
        local column = editor.columns[i]
        if column then
            local element = ns.ELEMENTS[slot]
            column.header:SetText(element.label)
            column.header:SetTextColor(element.color[1], element.color[2], element.color[3])

            local chosen = set and set.spells[slot]
            column.current:SetText(chosen and chosen.name or "empty")

            local entries = {}
            for _, e in ipairs((ns.totemSpellsBySlot and ns.totemSpellsBySlot[slot]) or {}) do
                entries[#entries + 1] = e
            end
            for _, e in ipairs(unassigned) do entries[#entries + 1] = e end

            for index, entry in ipairs(entries) do
                local icon = AcquireIcon()
                icon:SetParent(column)
                icon:ClearAllPoints()
                local row, col = math.floor((index - 1) / 4), (index - 1) % 4
                icon:SetPoint("TOPLEFT", column, "TOPLEFT", col * 30, -32 - row * 30)
                icon.tex:SetTexture(entry.icon or ns.SpellTextureByName(entry.name) or "Interface\\Icons\\INV_Misc_QuestionMark")
                icon.spellName = entry.name
                icon.hl:SetAlpha((chosen and chosen.name == entry.name) and 0.4 or 0)
                icon:SetScript("OnClick", function()
                    ns.Sets:AssignSpell(setIndex, slot, entry)
                    ns:RefreshTotemSpells()
                    RefreshEditor()
                end)
                icon:Show()
            end
        end
    end
end

local function BuildEditor(parent, x, y)
    MakeLabel(parent, "Totem sets", x, y, 14)

    editor.setName = parent:CreateFontString(nil, "ARTWORK")
    editor.setName:SetFont(FONT, 12, "")
    editor.setName:SetPoint("TOPLEFT", x + 120, y)
    editor.setName:SetTextColor(1, 1, 1)

    MakeButton(parent, "<", x, y - 20, 24, function()
        local idx = ns.Sets:GetActiveIndex() - 1
        if idx < 1 then idx = #ns.db.sets end
        ns.Sets:SetActive(idx); RefreshEditor()
    end)
    MakeButton(parent, ">", x + 26, y - 20, 24, function()
        local idx = ns.Sets:GetActiveIndex() + 1
        if idx > #ns.db.sets then idx = 1 end
        ns.Sets:SetActive(idx); RefreshEditor()
    end)
    MakeButton(parent, "New", x + 56, y - 20, 60, function() StaticPopup_Show("FOREVERTOTEMS_NEWSET") end)
    MakeButton(parent, "Rename", x + 120, y - 20, 80, function() StaticPopup_Show("FOREVERTOTEMS_RENAMESET") end)
    MakeButton(parent, "Sync", x + 268, y - 20, 56, function()
        local written, skipped, reason = ns.TotemBar:SyncActiveSet()
        if reason then
            ns:Print("Cannot sync: " .. reason)
        else
            ns:Print(("Totem bar updated: %d slots written, %d skipped."):format(written, skipped))
        end
    end)
    MakeButton(parent, "Delete", x + 204, y - 20, 60, function()
        if ns.Sets:Delete(ns.Sets:GetActiveIndex()) then
            RefreshEditor()
        else
            ns:Print("You cannot delete the last set.")
        end
    end)

    for i = 1, MAX_SLOTS do
        local column = CreateFrame("Frame", nil, parent)
        column:SetSize(126, 126)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        column:SetPoint("TOPLEFT", parent, "TOPLEFT", x + col * 136, y - 54 - row * 132)

        column.header = column:CreateFontString(nil, "ARTWORK")
        column.header:SetFont(FONT, 12, "OUTLINE")
        column.header:SetPoint("TOPLEFT")

        column.current = column:CreateFontString(nil, "ARTWORK")
        column.current:SetFont(FONT, 10, "")
        column.current:SetPoint("TOPLEFT", 0, -14)
        column.current:SetWidth(122)
        column.current:SetJustifyH("LEFT")
        column.current:SetTextColor(0.75, 0.75, 0.75)

        local clear = CreateFrame("Button", nil, column)
        clear:SetSize(14, 14)
        clear:SetPoint("TOPRIGHT")
        local cross = clear:CreateFontString(nil, "ARTWORK")
        cross:SetFont(FONT, 13, "OUTLINE")
        cross:SetPoint("CENTER")
        cross:SetText("x")
        cross:SetTextColor(1, 0.4, 0.4)
        clear:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Clear this element from the set")
            GameTooltip:Show()
        end)
        clear:SetScript("OnLeave", function() GameTooltip:Hide() end)
        clear:SetScript("OnClick", function()
            local slot = (ns.db.bar.order or ns.DEFAULT_ORDER)[i]
            ns.Sets:AssignSpell(ns.Sets:GetActiveIndex(), slot, nil)
            RefreshEditor()
        end)

        editor.columns[i] = column
    end

    refreshers[#refreshers + 1] = RefreshEditor
end

--------------------------------------------------------------------------------
-- Popups
--------------------------------------------------------------------------------
local function PopupEditBox(dialog)
    return dialog.editBox or (dialog.GetEditBox and dialog:GetEditBox())
end

StaticPopupDialogs["FOREVERTOTEMS_NEWSET"] = {
    text = "Name for the new totem set:",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(self)
        local box = PopupEditBox(self)
        local name = box and box:GetText()
        if name and name ~= "" then
            local idx = ns.Sets:New(name)
            ns.Sets:SetActive(idx)
            RefreshEditor()
        end
    end,
}

StaticPopupDialogs["FOREVERTOTEMS_RENAMESET"] = {
    text = "New name for the set:",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(self)
        local box = PopupEditBox(self)
        local name = box and box:GetText()
        if name and name ~= "" then
            ns.Sets:Rename(ns.Sets:GetActiveIndex(), name)
            RefreshEditor()
        end
    end,
}

StaticPopupDialogs["FOREVERTOTEMS_MACRO"] = {
    text = "Copy this into a macro to cast the active set:",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 350,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnShow = function(self)
        local box = PopupEditBox(self)
        if box then
            box:SetText(ns.Sets:GetSequenceMacro() or "")
            box:HighlightText()
            box:SetFocus()
        end
    end,
}

--------------------------------------------------------------------------------
-- Configuration window
--------------------------------------------------------------------------------
local function BuildWindow()
    refreshers = {}

    local f = CreateFrame("Frame", "ForeverTotemsConfig", UIParent, BACKDROP_TEMPLATE)
    window = f
    f:SetSize(690, 600)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    tinsert(UISpecialFrames, "ForeverTotemsConfig")

    local close = TryCreate("Button", nil, f, { "UIPanelCloseButton" })
    if close then close:SetPoint("TOPRIGHT", -6, -6) end

    MakeLabel(f, "Forever Totems", 20, -18, 18)
    MakeLabel(f, "Shaman totem manager - v" .. ns.version, 20, -40, 11, 0.7, 0.7, 0.7)

    -- Everything lives in a scroll area: the settings grew past what fits on a
    -- 768 unit tall UIParent, and the bottom rows were being cut off.
    local scroll = TryCreate("ScrollFrame", "ForeverTotemsConfigScroll", f, { "UIPanelScrollFrameTemplate" })
        or CreateFrame("ScrollFrame", "ForeverTotemsConfigScroll", f)
    scroll:SetPoint("TOPLEFT", 14, -58)
    scroll:SetPoint("BOTTOMRIGHT", -34, 14)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(630, 780)
    scroll:SetScrollChild(content)

    local db = ns.db

    ------------------------------------------------------------- left column
    local x, y = 20, -62
    MakeLabel(content, "Bar", x, y, 14)
    y = y - 22
    MakeCheck(content, "Lock the bar", x, y,
        function() return db.bar.locked end,
        function(v) db.bar.locked = v; ns.Bar:UpdateLock() end)
    y = y - 24
    MakeCheck(content, "Hide the bar", x, y,
        function() return db.bar.hidden end,
        function(v) db.bar.hidden = v; ns.Bar:Layout(); ns.Bar:UpdateLock() end)
    y = y - 24
    MakeCheck(content, "Show time remaining", x, y,
        function() return db.bar.showTimerText end,
        function(v) db.bar.showTimerText = v end)
    y = y - 24
    MakeCheck(content, "Show assigned keys", x, y,
        function() return db.bar.showKeybindText end,
        function(v) db.bar.showKeybindText = v; ns.Bar:UpdateKeybindText() end)
    y = y - 24
    MakeCheck(content, "Show whole-set button", x, y,
        function() return db.bar.showSequenceButton end,
        function(v) db.bar.showSequenceButton = v; ns.Bar:Layout() end)
    y = y - 24
    MakeCheck(content, "Set button skips totems already out (out of combat)", x, y,
        function() return db.skipActiveTotems end,
        function(v) db.skipActiveTotems = v; ns.Sets:Apply() end)
    y = y - 24
    MakeCheck(content, "Hide slots with no totem assigned", x, y,
        function() return db.bar.hideEmptySlots end,
        function(v) db.bar.hideEmptySlots = v; ns.Bar:Layout(); ns.Bar:UpdateAll() end)
    y = y - 24
    MakeCheck(content, "Arrow on each slot to swap totems", x, y,
        function() return db.bar.showArrows end,
        function(v) db.bar.showArrows = v; ns.Flyout:UpdateArrows() end)
    y = y - 24
    MakeCheck(content, "Keep the game totem bar in sync with the set", x, y,
        function() return db.syncTotemBar end,
        function(v)
            db.syncTotemBar = v
            if v then ns.TotemBar:SyncActiveSet() end
        end)
    y = y - 24
    MakeCheck(content, "Swing timer bar", x, y,
        function() return db.swing.enabled end,
        function(v) db.swing.enabled = v; ns.Bar:UpdateSwing() end)
    y = y - 24
    MakeCheck(content, "Weapon imbue button on the bar", x, y,
        function() return db.weapon.button end,
        function(v) db.weapon.button = v; ns.Bar:Layout() end)
    y = y - 24
    MakeCheck(content, "Warn if you enter combat with no weapon imbue", x, y,
        function() return db.weapon.warn end,
        function(v) db.weapon.warn = v end)
    y = y - 24
    MakeCheck(content, "Imbue the off hand instead", x, y,
        function() return db.weapon.offHand end,
        function(v) db.weapon.offHand = v; ns.Bar:ApplyAttributes() end)
    y = y - 24
    MakeCheck(content, "Purge button on the bar", x, y,
        function() return db.bar.showPurgeButton end,
        function(v) db.bar.showPurgeButton = v; ns.Bar:Layout() end)
    y = y - 24
    MakeCheck(content, "Show call-of-the-elements button", x, y,
        function() return db.bar.showCallButton end,
        function(v) db.bar.showCallButton = v; ns.Bar:Layout() end)
    y = y - 24
    MakeCheck(content, "Vertical bar", x, y,
        function() return db.bar.orientation == "VERTICAL" end,
        function(v) db.bar.orientation = v and "VERTICAL" or "HORIZONTAL"; ns.Bar:Layout() end)
    y = y - 24
    MakeCheck(content, "Right click destroys the totem", x, y,
        function() return db.rightClickDestroy end,
        function(v) db.rightClickDestroy = v; ns.Bar:ApplyAttributes() end)
    y = y - 24
    MakeCheck(content, "If a slot is empty, use the last totem cast", x, y,
        function() return db.fallbackLastCast end,
        function(v) db.fallbackLastCast = v; ns.Sets:Apply() end)

    y = y - 44
    MakeSlider(content, "Scale", x, y, 50, 200, 5,
        function() return math.floor(db.bar.scale * 100 + 0.5) end,
        function(v) db.bar.scale = v / 100; ns.Bar:Layout() end,
        "%s: %d%%")
    y = y - 44
    MakeSlider(content, "Icon size", x, y, 24, 72, 2,
        function() return db.bar.size end,
        function(v) db.bar.size = v; ns.Bar:Layout() end)

    y = y - 54
    MakeLabel(content, "Warnings", x, y, 14)
    y = y - 22
    MakeCheck(content, "Warn before it expires", x, y,
        function() return db.warnings.expire end,
        function(v) db.warnings.expire = v end)
    y = y - 38
    MakeSlider(content, "Seconds of warning", x, y, 1, 15, 1,
        function() return db.warnings.expireAt end,
        function(v) db.warnings.expireAt = v end)
    y = y - 40
    MakeCheck(content, "Warn if a totem is destroyed", x, y,
        function() return db.warnings.death end,
        function(v) db.warnings.death = v end)
    y = y - 24
    MakeCheck(content, "Warn when leaving the totem range", x, y,
        function() return db.warnings.range end,
        function(v) db.warnings.range = v end)
    y = y - 38
    MakeSlider(content, "Range in yards", x, y, 10, 45, 1,
        function() return db.warnings.rangeYards end,
        function(v) db.warnings.rangeYards = v end)
    y = y - 42
    MakeLabel(content, "Warn via:", x, y + 4, 12, 1, 1, 1)
    MakeCheck(content, "Sound", x + 70, y,
        function() return db.warnings.sound end,
        function(v) db.warnings.sound = v end)
    MakeCheck(content, "Chat", x + 150, y,
        function() return db.warnings.chat end,
        function(v) db.warnings.chat = v end)
    MakeCheck(content, "Screen", x + 215, y,
        function() return db.warnings.screen end,
        function(v) db.warnings.screen = v end)

    y = y - 30
    local soundButton = MakeButton(content, "", x, y, 170, function(self)
        ns.Warnings:CycleSound()
        self:SetText("Sound: " .. ns.Warnings:GetSoundLabel())
    end)
    refreshers[#refreshers + 1] = function()
        soundButton:SetText("Sound: " .. ns.Warnings:GetSoundLabel())
    end
    MakeButton(content, "Test", x + 178, y, 80, function() ns.Warnings:TestSound() end)

    ------------------------------------------------------------ right column
    local rx, ry = 350, -62
    BuildEditor(content, rx, ry)

    local by = ry - 330
    MakeLabel(content, "Keybinds", rx, by, 14)
    MakeLabel(content, "(click, then press a key; Escape clears it)", rx, by - 16, 10, 0.7, 0.7, 0.7)
    by = by - 38
    for _, slot in ipairs(ns.DEFAULT_ORDER) do
        MakeBindButton(content, slot, ns.ELEMENTS[slot].label, rx + 70, by)
        by = by - 26
    end
    MakeBindButton(content, "sequence", "Whole set", rx + 70, by)
    by = by - 26
    MakeBindButton(content, "call", "Call spell", rx + 70, by)
    by = by - 26
    MakeBindButton(content, "purge", "Purge", rx + 70, by)
    by = by - 26
    MakeBindButton(content, "weapon", "Weapon imbue", rx + 70, by)

    by = by - 34

    MakeButton(content, "Show set macro", rx, by, 150, function()
        if ns.Sets:GetSequenceMacro() then
            StaticPopup_Show("FOREVERTOTEMS_MACRO")
        else
            ns:Print("The active set has no totems assigned.")
        end
    end)
    local orderY = by - 62
    MakeLabel(content, "Order on the bar and in the macro", rx, orderY, 12)

    local orderRows = {}
    local function RefreshOrder()
        local order = ns.db.bar.order or ns.DEFAULT_ORDER
        for index, row in ipairs(orderRows) do
            local slot = order[index]
            local element = ns.ELEMENTS[slot]
            row:SetText(("%d.  %s"):format(index, element.label))
            row:SetTextColor(element.color[1], element.color[2], element.color[3])
        end
    end

    local function MoveSlot(index, delta)
        local order = ns.db.bar.order
        local target = index + delta
        if target < 1 or target > #order then return end
        order[index], order[target] = order[target], order[index]
        ns.Bar:Layout()
        ns.Bar:UpdateAll()
        ns.Sets:Apply()        -- the castsequence follows this order
        RefreshOrder()
        RefreshEditor()
    end

    for index = 1, MAX_SLOTS do
        local rowY = orderY - 20 - (index - 1) * 22
        orderRows[index] = MakeLabel(content, "", rx + 6, rowY, 12)
        MakeButton(content, "<", rx + 120, rowY + 4, 24, function() MoveSlot(index, -1) end)
        MakeButton(content, ">", rx + 146, rowY + 4, 24, function() MoveSlot(index, 1) end)
    end
    refreshers[#refreshers + 1] = RefreshOrder

    MakeButton(content, "Macro to action bar", rx, by - 28, 150, function()
        local index, reason = ns.Sets:CreateOrUpdateMacro(true)
        if index then
            ns:Print("Macro 'FTTotems' ready and on your cursor: click an action bar slot.")
        else
            ns:Print("Could not make the macro: " .. tostring(reason))
        end
    end)
    MakeButton(content, "Rescan spells", rx + 158, by, 130, function()
        ns:RefreshTotemSpells()
        RefreshEditor()
        ns:Print(("Totems detected: %d"):format(#(ns.totemSpells or {})))
    end)

    f:SetScript("OnShow", function()
        for _, fn in ipairs(refreshers) do fn() end
    end)

    -- Entry point from the game's options window
    local stub = CreateFrame("Frame", "ForeverTotemsOptionsStub", UIParent)
    stub.name = "Forever Totems"
    MakeLabel(stub, "Forever Totems", 16, -16, 18)
    local open = TryCreate("Button", nil, stub, { "UIPanelButtonTemplate" })
    if open then
        open:SetPoint("TOPLEFT", 16, -48)
        open:SetSize(180, 24)
        open:SetText("Open configuration")
        open:SetScript("OnClick", function() ns:OpenOptions() end)
    end
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(stub, "Forever Totems")
        category.ID = "ForeverTotems"
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(stub)
    end
end

function ns:OpenOptions()
    if not window then return end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

--------------------------------------------------------------------------------
-- Copyable text window (diagnostics, macros: anything worth pasting out)
--------------------------------------------------------------------------------
local textWindow

function ns:ShowText(title, text)
    if not textWindow then
        local f = CreateFrame("Frame", "ForeverTotemsTextWindow", UIParent, BACKDROP_TEMPLATE)
        f:SetSize(560, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
        end
        tinsert(UISpecialFrames, "ForeverTotemsTextWindow")

        local close = TryCreate("Button", nil, f, { "UIPanelCloseButton" })
        if close then close:SetPoint("TOPRIGHT", -6, -6) end

        f.title = f:CreateFontString(nil, "ARTWORK")
        f.title:SetFont(FONT, 14, "")
        f.title:SetPoint("TOPLEFT", 20, -18)
        f.title:SetTextColor(1, 0.82, 0)

        local scroll = TryCreate("ScrollFrame", "ForeverTotemsTextScroll", f, { "UIPanelScrollFrameTemplate" })
            or CreateFrame("ScrollFrame", "ForeverTotemsTextScroll", f)
        scroll:SetPoint("TOPLEFT", 20, -44)
        scroll:SetPoint("BOTTOMRIGHT", -34, 44)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal or GameFontHighlight)
        edit:SetWidth(490)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.edit = edit

        local hint = f:CreateFontString(nil, "ARTWORK")
        hint:SetFont(FONT, 11, "")
        hint:SetPoint("BOTTOMLEFT", 20, 20)
        hint:SetTextColor(0.7, 0.7, 0.7)
        hint:SetText("Everything is selected: press Ctrl+C to copy.")

        textWindow = f
    end

    textWindow.title:SetText(title or "Forever Totems")
    textWindow.edit:SetText(text or "")
    textWindow:Show()
    textWindow.edit:HighlightText()
    textWindow.edit:SetFocus()
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------
local function HandleSlash(input)
    if not ns.db then return end
    if not ns.isShaman then
        ns:Print("This addon only does something on a shaman.")
        return
    end

    input = (input or ""):trim()
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "config" or cmd == "opciones" then
        ns:OpenOptions()
    elseif cmd == "lock" or cmd == "bloquear" then
        ns.db.bar.locked = true; ns.Bar:UpdateLock(); ns:Print("Bar locked.")
    elseif cmd == "unlock" or cmd == "desbloquear" then
        ns.db.bar.locked = false; ns.Bar:UpdateLock(); ns:Print("Bar unlocked: drag the blue box.")
    elseif cmd == "show" or cmd == "mostrar" then
        ns.db.bar.hidden = false; ns.Bar:Layout(); ns.Bar:UpdateLock()
    elseif cmd == "hide" or cmd == "ocultar" then
        ns.db.bar.hidden = true; ns.Bar:Layout(); ns.Bar:UpdateLock()
    elseif cmd == "reset" then
        ns.db.bar.point, ns.db.bar.x, ns.db.bar.y = "CENTER", 0, -180
        ns.Bar:Reposition(); ns:Print("Bar moved back to the center.")
    elseif cmd == "set" then
        local index = tonumber(rest) or ns.Sets:FindByName(rest)
        if index and ns.Sets:SetActive(index) then
            ns:Print("Set activo: " .. ns.Sets:GetActive().name)
        else
            ns:Print("No such set. Available ones:")
            for i, s in ipairs(ns.db.sets) do ns:Print(("  %d. %s"):format(i, s.name)) end
        end
    elseif cmd == "selftest" then
        ns:ShowText("Self test", ns.SelfTest:Run())
    elseif cmd == "clicktest" then
        local on = ns.Bar:ToggleClickTest()
        ns:Print("Click tracing: " .. (on and "ON, now click a bar button" or "OFF"))
    elseif cmd == "swingprobe" then
        local on = ns.Swing:ToggleProbe()
        if on then
            ns:Print("Swing probe ON. Melee something for a few seconds, then /ft swingprobe again.")
        else
            ns:ShowText("Swing probe", ns.Swing:ProbeReport())
        end
    elseif cmd == "weapon" then
        ns:ShowText("Weapon imbue diagnostics", ns.Weapon:Report())
    elseif cmd == "check" then
        ns:ShowText("Bar diagnostics", ns.Bar:Diagnose())
    elseif cmd == "sync" then
        local written, skipped, reason = ns.TotemBar:SyncActiveSet()
        if reason then
            ns:Print("Cannot sync: " .. reason)
        else
            ns:Print(("Totem bar updated: %d written, %d skipped."):format(written, skipped))
            local contents = ns.TotemBar:ReadPage()
            for slot = 1, ns.MAX_SLOTS do
                ns:Print(("  %s: %s"):format(ns.ELEMENTS[slot].label, contents[slot] or "-"))
            end
        end
    elseif cmd == "totembar" then
        ns:ShowText("Totem bar diagnostics", ns.TotemBar:Report())
    elseif cmd == "call" then
        local spell = ns.TotemBar:CycleCall()
        ns:Print(spell and ("Call spell: " .. spell.name) or "No call-of-the-elements spell found.")
    elseif cmd == "sonido" or cmd == "sound" then
        local choice = ns.Warnings:CycleSound()
        ns:Print("Warning sound: " .. (choice and choice.label or "none"))
    elseif cmd == "makemacro" then
        local index, reason = ns.Sets:CreateOrUpdateMacro(true)
        if index then
            ns:Print("Macro 'FTTotems' is on your cursor: click an empty action bar slot.")
        else
            ns:Print("Could not make the macro: " .. tostring(reason))
        end
    elseif cmd == "macro" then
        if ns.Sets:GetSequenceMacro() then StaticPopup_Show("FOREVERTOTEMS_MACRO") end
    elseif cmd == "scan" then
        ns:RefreshTotemSpells()
        ns:Print(("Totems detected: %d"):format(#(ns.totemSpells or {})))
        for _, e in ipairs(ns.totemSpells or {}) do
            local el = ns.ELEMENTS[e.slot]
            ns:Print(("  %s - %s"):format(e.name, el and el.label or "unclassified"))
        end
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns:Print("Debug: " .. (ns.db.debug and "ON" or "OFF"))
    else
        ns:Print("Commands: /ft (options), lock, unlock, show, hide, reset, set <name|n>, sound, call, makemacro, sync, check, weapon, swingprobe, clicktest, selftest, totembar, macro, scan, debug")
    end
end

SLASH_FOREVERTOTEMS1 = "/ft"
SLASH_FOREVERTOTEMS2 = "/forevertotems"
SlashCmdList["FOREVERTOTEMS"] = HandleSlash

ns:On("READY", function()
    BuildWindow()
    ns:Print("loaded. Type |cffffd100/ft|r to configure it.")
end)

ns:On("BINDS_CHANGED", function()
    if window and window:IsShown() then
        for _, fn in ipairs(refreshers) do fn() end
    end
end)
