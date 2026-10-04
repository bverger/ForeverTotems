--------------------------------------------------------------------------------
-- Forever Totems - Bar.lua
-- Four-slot bar with icons, countdown and quick recast.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Bar = {}
ns.Bar = Bar
Bar.buttons = {}

local MAX_SLOTS = ns.MAX_SLOTS
local FONT = "Fonts\\FRIZQT__.TTF"
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Blizzard's own action buttons register both edges and let the engine pick
-- according to the ActionButtonUseKeyDown cvar. Registering only "AnyUp" can
-- leave the button inert on a client set to cast on key down.
local function RegisterClicks(button)
    button:RegisterForClicks("AnyUp", "AnyDown")
end

local function SetEdgeColor(button, r, g, b, a)
    for _, edge in ipairs(button.edges) do
        edge:SetColorTexture(r, g, b, a)
    end
end

-- Weapon imbues last minutes, not seconds: "28m" reads better than "27:43"
local function FormatMinutes(t)
    if t >= 60 then
        return ("%dm"):format(math.floor(t / 60 + 0.5))
    end
    return ("%ds"):format(math.floor(t))
end

local function FormatTime(t)
    if t >= 60 then
        return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
    elseif t >= 10 then
        return string.format("%d", math.floor(t))
    end
    return string.format("%.1f", t)
end

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------
local function ButtonOnEnter(self)
    local slot = self.slot
    local element = ns.ELEMENTS[slot]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local totem = ns:GetTotem(slot)
    if totem and totem.have then
        GameTooltip:AddLine(totem.name or element.label, 1, 1, 1)
        GameTooltip:AddLine(string.format("%s left", FormatTime(ns:TotemRemaining(slot))), 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine(element.label, element.color[1], element.color[2], element.color[3])
        local spell = ns.Sets:GetSpellForSlot(slot)
        if spell then
            GameTooltip:AddLine(spell.name, 1, 1, 1)
        else
            GameTooltip:AddLine("No totem assigned", 1, 1, 1)
            GameTooltip:AddLine("Pick one in /ft, or cast one of this element once.", 0.8, 0.8, 0.8, true)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left click: cast / recast", 0.4, 0.8, 0.4)
    if ns.db.rightClickDestroy then
        GameTooltip:AddLine("Right click: destroy the totem", 0.9, 0.4, 0.4)
    end
    local key = ns.db.binds.slots[slot]
    if key and key ~= "" then
        GameTooltip:AddLine("Key: " .. key, 0.6, 0.6, 0.9)
    end
    GameTooltip:Show()
end

local function ButtonOnLeave()
    GameTooltip:Hide()
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------
local function CreateSlotButton(parent, slot, name)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b.slot = slot
    RegisterClicks(b)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.04, 0.04, 0.05, 0.85)

    -- A thin frame reads as an empty slot; a solid colour block reads as a
    -- random smear, which is what the filled backdrop looked like.
    b.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = b:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetHeight(1)
            edge:SetPoint(side .. "LEFT")
            edge:SetPoint(side .. "RIGHT")
        else
            edge:SetWidth(1)
            edge:SetPoint("TOP" .. side)
            edge:SetPoint("BOTTOM" .. side)
        end
        b.edges[#b.edges + 1] = edge
    end

    b.emptyLabel = b:CreateFontString(nil, "ARTWORK")
    b.emptyLabel:SetFont(FONT, 10, "OUTLINE")
    b.emptyLabel:SetPoint("CENTER")

    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetAllPoints()
    b.glow:SetColorTexture(1, 1, 1, 0)

    b.cd = CreateFrame("Cooldown", name .. "Cooldown", b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.cd:SetDrawEdge(true)
    b.cd:SetReverse(true)
    b.cd:SetHideCountdownNumbers(true)
    b.cd.noCooldownCount = true   -- keep OmniCC and friends from drawing over it
    b.cd:EnableMouse(false)       -- a cooldown that eats clicks kills the button
    b.cd:SetFrameLevel(b:GetFrameLevel())

    b.timer = b:CreateFontString(nil, "OVERLAY")
    b.timer:SetFont(FONT, 14, "OUTLINE")
    b.timer:SetPoint("BOTTOM", 0, 2)

    b.keybind = b:CreateFontString(nil, "OVERLAY")
    b.keybind:SetFont(FONT, 10, "OUTLINE")
    b.keybind:SetPoint("TOPRIGHT", -2, -3)
    b.keybind:SetTextColor(0.8, 0.8, 0.8)

    b:SetScript("OnEnter", ButtonOnEnter)
    b:SetScript("OnLeave", ButtonOnLeave)
    return b
end

-- A grab strip above the bar, not a sheet over it: an overlay covering the
-- buttons swallows their clicks and makes the whole bar look dead.
local function CreateDragOverlay(frame)
    local o = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
    o:SetHeight(14)
    o:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -2, 3)
    o:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 2, 3)
    o:SetFrameLevel(frame:GetFrameLevel() + 10)
    o:EnableMouse(true)
    o:RegisterForDrag("LeftButton")
    if o.SetBackdrop then
        o:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        o:SetBackdropColor(0.1, 0.5, 0.9, 0.55)
        o:SetBackdropBorderColor(0.3, 0.8, 1, 0.9)
    end

    o.label = o:CreateFontString(nil, "OVERLAY")
    o.label:SetFont(FONT, 10, "OUTLINE")
    o.label:SetPoint("CENTER")
    o.label:SetText("drag here to move - /ft lock when done")

    o:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Drag to move the bar")
        GameTooltip:AddLine("The buttons below stay clickable.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    o:SetScript("OnLeave", ButtonOnLeave)

    o:SetScript("OnDragStart", function()
        if InCombatLockdown() then
            ns:Print("The bar cannot be moved in combat.")
            return
        end
        frame:StartMoving()
    end)
    o:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint()
        ns.db.bar.point, ns.db.bar.x, ns.db.bar.y = point, x, y
    end)
    return o
end

function Bar:Create()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "ForeverTotemsBar", UIParent)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetPoint(ns.db.bar.point, UIParent, ns.db.bar.point, ns.db.bar.x, ns.db.bar.y)
    self.frame = f

    for slot = 1, MAX_SLOTS do
        self.buttons[slot] = CreateSlotButton(f, slot, "ForeverTotemsButton" .. slot)
    end

    -- Whole-set button (castsequence)
    local seq = CreateFrame("Button", "ForeverTotemsBarSetButton", f, "SecureActionButtonTemplate")
    RegisterClicks(seq)
    seq.icon = seq:CreateTexture(nil, "ARTWORK")
    seq.icon:SetPoint("TOPLEFT", 2, -2)
    seq.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    seq.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    seq.icon:SetTexture("Interface\\Icons\\Spell_Nature_ManaRegenTotem")
    seq.bg = seq:CreateTexture(nil, "BACKGROUND")
    seq.bg:SetAllPoints()
    seq.bg:SetColorTexture(0, 0, 0, 1)
    seq.label = seq:CreateFontString(nil, "OVERLAY")
    seq.label:SetFont(FONT, 10, "OUTLINE")
    seq.label:SetPoint("BOTTOM", 0, 2)
    seq.keybind = seq:CreateFontString(nil, "OVERLAY")
    seq.keybind:SetFont(FONT, 10, "OUTLINE")
    seq.keybind:SetPoint("TOPRIGHT", -2, -3)
    seq.keybind:SetTextColor(0.8, 0.8, 0.8)
    seq:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local set = ns.Sets:GetActive()
        GameTooltip:AddLine("Set: " .. (set and set.name or "-"), 1, 1, 1)
        GameTooltip:AddLine("Each press casts the next totem in the set.", 0.8, 0.8, 0.8, true)
        local macro = ns.Sets:GetSequenceMacro()
        if macro then GameTooltip:AddLine(macro, 0.5, 0.7, 1, true) end
        GameTooltip:Show()
    end)
    seq:SetScript("OnLeave", ButtonOnLeave)
    self.seqButton = seq

    -- Native "Call of ..." button: one cast, four totems
    local call = CreateFrame("Button", "ForeverTotemsCallButton", f, "SecureActionButtonTemplate")
    RegisterClicks(call)
    call.icon = call:CreateTexture(nil, "ARTWORK")
    call.icon:SetPoint("TOPLEFT", 2, -2)
    call.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    call.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    call.bg = call:CreateTexture(nil, "BACKGROUND")
    call.bg:SetAllPoints()
    call.bg:SetColorTexture(0, 0, 0, 1)
    call.keybind = call:CreateFontString(nil, "OVERLAY")
    call.keybind:SetFont(FONT, 10, "OUTLINE")
    call.keybind:SetPoint("TOPRIGHT", -2, -3)
    call.keybind:SetTextColor(0.8, 0.8, 0.8)
    call:SetScript("OnEnter", function(self)
        local spell = ns.TotemBar:GetActiveCall()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(spell and spell.name or "No call spell known", 1, 1, 1)
        if spell and spell.management then
            GameTooltip:AddLine("A totem management spell.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("Places the totems saved in the game's totem bar.", 0.8, 0.8, 0.8, true)
        end
        if #ns.TotemBar:GetButtonSpells() > 1 then
            GameTooltip:AddLine("Hover to pick another, or /ft call.", 0.5, 0.7, 1)
        end
        GameTooltip:Show()
    end)
    call:SetScript("OnLeave", ButtonOnLeave)
    self.callButton = call

    -- Weapon imbue: icon, time left, and its own flyout to pick which one
    local weapon = CreateFrame("Button", "ForeverTotemsWeaponButton", f, "SecureActionButtonTemplate")
    RegisterClicks(weapon)
    weapon.icon = weapon:CreateTexture(nil, "ARTWORK")
    weapon.icon:SetPoint("TOPLEFT", 2, -2)
    weapon.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    weapon.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    weapon.bg = weapon:CreateTexture(nil, "BACKGROUND")
    weapon.bg:SetAllPoints()
    weapon.bg:SetColorTexture(0, 0, 0, 1)
    weapon.glow = weapon:CreateTexture(nil, "OVERLAY")
    weapon.glow:SetAllPoints()
    weapon.glow:SetColorTexture(1, 0.4, 0.1, 0)
    weapon.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = weapon:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetHeight(2)
            edge:SetPoint(side .. "LEFT")
            edge:SetPoint(side .. "RIGHT")
        else
            edge:SetWidth(2)
            edge:SetPoint("TOP" .. side)
            edge:SetPoint("BOTTOM" .. side)
        end
        weapon.edges[#weapon.edges + 1] = edge
    end
    weapon.cd = CreateFrame("Cooldown", "ForeverTotemsWeaponCooldown", weapon, "CooldownFrameTemplate")
    weapon.cd:SetAllPoints(weapon.icon)
    weapon.cd:SetReverse(true)
    weapon.cd:SetHideCountdownNumbers(true)
    weapon.cd.noCooldownCount = true
    weapon.cd:EnableMouse(false)
    weapon.timer = weapon:CreateFontString(nil, "OVERLAY")
    weapon.timer:SetFont(FONT, 12, "OUTLINE")
    weapon.timer:SetPoint("BOTTOM", 0, 2)
    weapon.keybind = weapon:CreateFontString(nil, "OVERLAY")
    weapon.keybind:SetFont(FONT, 10, "OUTLINE")
    weapon.keybind:SetPoint("TOPRIGHT", -2, -3)
    weapon.keybind:SetTextColor(0.8, 0.8, 0.8)
    weapon:SetScript("OnEnter", function(self)
        local spell = ns.Weapon:GetChosen()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(spell and spell.name or "Weapon imbue", 1, 1, 1)
        if ns.Weapon:IsBlocked() then
            GameTooltip:AddLine("The client is not reporting the imbue right now.", 0.9, 0.6, 0.3, true)
        elseif ns.Weapon:HasEnchant() then
            GameTooltip:AddLine(("%s left"):format(FormatTime(ns.Weapon:Remaining())), 0.4, 0.8, 0.4)
        else
            GameTooltip:AddLine("No imbue on your weapon.", 1, 0.4, 0.4)
        end
        if ns.db.weapon.offHand then
            GameTooltip:AddLine("Set to imbue the off hand.", 0.6, 0.6, 0.9)
        end
        GameTooltip:Show()
    end)
    weapon:SetScript("OnLeave", ButtonOnLeave)
    self.weaponButton = weapon

    -- Swing bar, hanging under the buttons
    local swing = CreateFrame("StatusBar", "ForeverTotemsSwingBar", f)
    swing:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    swing:SetStatusBarColor(0.9, 0.7, 0.2)
    swing:SetMinMaxValues(0, 1)
    swing:SetValue(0)
    swing.bg = swing:CreateTexture(nil, "BACKGROUND")
    swing.bg:SetAllPoints()
    swing.bg:SetColorTexture(0, 0, 0, 0.7)
    swing.text = swing:CreateFontString(nil, "OVERLAY")
    swing.text:SetFont(FONT, 10, "OUTLINE")
    swing.text:SetPoint("CENTER")
    swing:Hide()
    self.swingBar = swing

    -- Shield button: charges front and centre, since that is what runs out
    local shield = CreateFrame("Button", "ForeverTotemsShieldButton", f, "SecureActionButtonTemplate")
    RegisterClicks(shield)
    shield.icon = shield:CreateTexture(nil, "ARTWORK")
    shield.icon:SetPoint("TOPLEFT", 2, -2)
    shield.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    shield.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    shield.bg = shield:CreateTexture(nil, "BACKGROUND")
    shield.bg:SetAllPoints()
    shield.bg:SetColorTexture(0, 0, 0, 1)
    shield.glow = shield:CreateTexture(nil, "OVERLAY")
    shield.glow:SetAllPoints()
    shield.glow:SetColorTexture(0.3, 0.6, 1, 0)
    shield.edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local edge = shield:CreateTexture(nil, "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            edge:SetHeight(2)
            edge:SetPoint(side .. "LEFT")
            edge:SetPoint(side .. "RIGHT")
        else
            edge:SetWidth(2)
            edge:SetPoint("TOP" .. side)
            edge:SetPoint("BOTTOM" .. side)
        end
        shield.edges[#shield.edges + 1] = edge
    end
    shield.timer = shield:CreateFontString(nil, "OVERLAY")
    shield.timer:SetFont(FONT, 14, "OUTLINE")
    shield.timer:SetPoint("BOTTOM", 0, 2)
    shield.keybind = shield:CreateFontString(nil, "OVERLAY")
    shield.keybind:SetFont(FONT, 10, "OUTLINE")
    shield.keybind:SetPoint("TOPRIGHT", -2, -3)
    shield.keybind:SetTextColor(0.8, 0.8, 0.8)
    shield:SetScript("OnEnter", function(self)
        local spell = ns.Shield:GetChosen()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(spell and spell.name or "Shield", 1, 1, 1)
        if ns.Shield:IsBlocked() then
            GameTooltip:AddLine("The client is not reporting your buffs right now.", 0.9, 0.6, 0.3, true)
        elseif ns.Shield:IsUp() then
            GameTooltip:AddLine(("%d charges left"):format(ns.Shield:Charges()), 0.4, 0.8, 0.4)
        else
            GameTooltip:AddLine("No shield up.", 1, 0.4, 0.4)
        end
        GameTooltip:Show()
    end)
    shield:SetScript("OnLeave", ButtonOnLeave)
    self.shieldButton = shield

    -- Proc flash: the icon pops above the bar and shrinks away. Hand animated
    -- rather than with an AnimationGroup, which is one API less to depend on.
    local flash = CreateFrame("Frame", "ForeverTotemsFlash", UIParent)
    flash:SetPoint("BOTTOM", f, "TOP", 0, 14)
    flash:SetFrameStrata("HIGH")
    flash:Hide()
    flash.icon = flash:CreateTexture(nil, "ARTWORK")
    flash.icon:SetAllPoints()
    flash.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    flash.glow = flash:CreateTexture(nil, "BACKGROUND")
    flash.glow:SetPoint("TOPLEFT", -6, 6)
    flash.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    flash.glow:SetColorTexture(1, 0.9, 0.4, 0.35)
    flash:SetScript("OnUpdate", function(self, elapsed)
        self.left = (self.left or 0) - elapsed
        local total = ns.db.cooldowns.flashTime or 0.6
        if self.left <= 0 then
            self:Hide()
            return
        end
        local progress = 1 - (self.left / total)      -- 0 at the start, 1 at the end
        local size = ns.db.cooldowns.flashSize or 64
        self:SetAlpha(1 - progress)
        self:SetSize(size * (1.5 - 0.5 * progress), size * (1.5 - 0.5 * progress))
    end)
    self.flash = flash

    self.dragOverlay = CreateDragOverlay(f)

    f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.05 then return end
        local delta = self.elapsed
        self.elapsed = 0
        Bar:UpdateTimers()
        if ns.Warnings then ns.Warnings:Update(delta) end
        Bar:UpdateMapHiding()
        if ns.Swing then ns.Swing:Update() end
        if ns.Cooldown then ns.Cooldown:Update() end
        Bar:UpdateSwing()
        if ns.Weapon then
            Bar.weaponAccum = (Bar.weaponAccum or 0) + delta
            if Bar.weaponAccum > 1 then
                Bar.weaponAccum = 0
                ns.Weapon:Refresh()
                ns.Weapon:Update()
            end
        end
    end)

    ns:On("TOTEMS_CHANGED", function()
        Bar:UpdateAll()
        ns.Sets:RefreshCastButtons()
    end)
    ns:On("SET_CHANGED", function() Bar:UpdateAll() end)
    ns:On("SPELLS_REFRESHED", function()
        Bar:Layout()
        Bar:ApplyAttributes()
        Bar:UpdateAll()
    end)
    ns:On("SETS_CHANGED", function() Bar:UpdateAll() end)

    self:Layout()
    self:ApplyAttributes()
    self:UpdateAll()
    self:UpdateLock()
    ns.Flyout:UpdateArrows()
    return f
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------
function Bar:Layout()
    local f = self.frame
    if not f then return end
    if InCombatLockdown() then
        ns:RunWhenPossible("bar-layout", function() Bar:Layout() end)
        return
    end

    local cfg = ns.db.bar
    local size, gap = cfg.size, cfg.spacing
    local horizontal = cfg.orientation ~= "VERTICAL"
    local order = cfg.order or ns.DEFAULT_ORDER

    local widgets = {}
    for _, slot in ipairs(order) do
        local button = self.buttons[slot]
        local spell = ns.Sets:GetSpellForSlot(slot)
        local totem = ns:GetTotem(slot)
        local empty = not spell and not (totem and totem.have)
        if cfg.hideEmptySlots and empty then
            button:Hide()
        else
            widgets[#widgets + 1] = button
            button:Show()
        end
    end
    if cfg.showSequenceButton then
        widgets[#widgets + 1] = self.seqButton
        self.seqButton:Show()
    else
        self.seqButton:Hide()
    end
    if ns.db.shield.button and #ns.Shield:GetSpells() > 0 then
        widgets[#widgets + 1] = self.shieldButton
        self.shieldButton:Show()
        ns.Flyout:AttachHover(self.shieldButton,
            function() return ns.Shield:GetSpells() end,
            function() local s = ns.Shield:GetChosen() return s and s.name end,
            function(entry) ns.Shield:SetChosen(entry) end)
    else
        self.shieldButton:Hide()
    end
    if ns.db.weapon.button and #ns.Weapon:GetSpells() > 0 then
        widgets[#widgets + 1] = self.weaponButton
        self.weaponButton:Show()
        ns.Flyout:AttachHover(self.weaponButton,
            function() return ns.Weapon:GetSpells() end,
            function() local s = ns.Weapon:GetChosen() return s and s.name end,
            function(entry) ns.Weapon:SetChosen(entry) end)
    else
        self.weaponButton:Hide()
    end
    if cfg.showCallButton and ns.TotemBar:GetActiveCall() then
        widgets[#widgets + 1] = self.callButton
        self.callButton:Show()
        ns.Flyout:AttachHover(self.callButton,
            function() return ns.TotemBar:GetButtonSpells() end,
            function() local s = ns.TotemBar:GetActiveCall() return s and s.name end,
            function(entry) ns.TotemBar:SetActiveCall(entry) end)
    else
        self.callButton:Hide()
    end

    local offset = 0
    for _, w in ipairs(widgets) do
        w:SetSize(size, size)
        w:ClearAllPoints()
        if horizontal then
            w:SetPoint("LEFT", f, "LEFT", offset, 0)
        else
            w:SetPoint("TOP", f, "TOP", 0, -offset)
        end
        offset = offset + size + gap
    end

    if self.swingBar then
        self.swingBar:ClearAllPoints()
        self.swingBar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
        self.swingBar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -2)
        self.swingBar:SetHeight(ns.db.swing.height or 12)
    end

    local total = math.max(0, offset - gap)
    if horizontal then
        f:SetSize(total, size)
    else
        f:SetSize(size, total)
    end
    f:SetScale(cfg.scale)
    f:SetShown(not cfg.hidden)
end

function Bar:UpdateLock()
    local cfg = ns.db.bar
    if not self.dragOverlay then return end
    self.dragOverlay:SetShown(not cfg.locked and not cfg.hidden)
end

function Bar:Reposition()
    local f = self.frame
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint(ns.db.bar.point, UIParent, ns.db.bar.point, ns.db.bar.x, ns.db.bar.y)
end

--------------------------------------------------------------------------------
-- Secure attributes (cast / destroy). Never in combat.
--------------------------------------------------------------------------------
function Bar:ApplyAttributes()
    if not self.frame then return end
    if InCombatLockdown() then
        ns:RunWhenPossible("bar-attributes", function() Bar:ApplyAttributes() end)
        return
    end

    for slot = 1, MAX_SLOTS do
        local b = self.buttons[slot]
        local spell = ns.Sets:GetSpellForSlot(slot)

        b:SetAttribute("type", spell and "macro" or nil)
        b:SetAttribute("macrotext", spell and ("/cast " .. spell.name) or "")

        if ns.db.rightClickDestroy then
            b:SetAttribute("type2", "destroytotem")
            b:SetAttribute("totem-slot", slot)
            b:SetAttribute("totem-slot2", slot)
            b:SetAttribute("*totem-slot2", slot)
        else
            b:SetAttribute("type2", nil)
        end
    end

    local macro = ns.Sets:GetSequenceMacro()
    if self.seqButton then
        self.seqButton:SetAttribute("type", macro and "macro" or nil)
        self.seqButton:SetAttribute("macrotext", macro or "")
    end

    local shieldMacro = ns.Shield:GetMacro()
    if self.shieldButton then
        self.shieldButton:SetAttribute("type", shieldMacro and "macro" or nil)
        self.shieldButton:SetAttribute("macrotext", shieldMacro or "")
    end

    local weaponMacro = ns.Weapon:GetMacro()
    if self.weaponButton then
        self.weaponButton:SetAttribute("type", weaponMacro and "macro" or nil)
        self.weaponButton:SetAttribute("macrotext", weaponMacro or "")
    end

    local call = ns.TotemBar:GetActiveCall()
    if self.callButton then
        self.callButton:SetAttribute("type", call and "macro" or nil)
        self.callButton:SetAttribute("macrotext", call and ("/cast " .. call.name) or "")
    end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
function Bar:UpdateSlot(slot)
    local b = self.buttons[slot]
    if not b then return end
    local element = ns.ELEMENTS[slot]
    local color = element.color
    local totem = ns:GetTotem(slot)
    local spell = ns.Sets:GetSpellForSlot(slot)

    if totem and totem.have then
        b.icon:SetTexture(totem.icon or (spell and spell.icon))
        b.icon:SetDesaturated(false)
        b.icon:SetAlpha(1)
        b.cd:SetCooldown(totem.start, totem.duration)
        SetEdgeColor(b, color[1], color[2], color[3], 1)
        b.bg:SetColorTexture(0, 0, 0, 0.9)
        b.emptyLabel:SetText("")
        b:SetAlpha(1)
        return
    end

    b.cd:SetCooldown(0, 0)
    b.timer:SetText("")
    b.glow:SetAlpha(0)

    local texture = spell and (spell.icon or ns.SpellTextureByName(spell.name))
    if texture then
        -- Assigned but not out: dimmed icon, so you still recognise it
        b.icon:SetTexture(texture)
        b.icon:SetDesaturated(true)
        b.icon:SetAlpha(0.5)
        b.emptyLabel:SetText("")
        SetEdgeColor(b, color[1] * 0.55, color[2] * 0.55, color[3] * 0.55, 0.9)
        b.bg:SetColorTexture(0.04, 0.04, 0.05, 0.85)
        b:SetAlpha(1)
    else
        -- Nothing assigned: an empty frame with the element name inside
        b.icon:SetAlpha(0)
        b.emptyLabel:SetText(element.label)
        b.emptyLabel:SetTextColor(color[1], color[2], color[3], 0.75)
        SetEdgeColor(b, color[1] * 0.45, color[2] * 0.45, color[3] * 0.45, 0.7)
        b.bg:SetColorTexture(0.04, 0.04, 0.05, 0.55)
        -- Nothing to put in it either: fade the whole slot back
        local candidates = ns.Flyout and #ns.Flyout:Entries(slot) or 0
        b:SetAlpha(candidates > 0 and 0.9 or 0.45)
    end
end

function Bar:UpdateSwing()
    local bar = self.swingBar
    if not bar then return end

    if not ns.db.swing.enabled or not ns.Swing:IsActive() then
        bar:Hide()
        return
    end

    bar:Show()
    bar:SetValue(ns.Swing:Progress())

    if ns.db.swing.showText then
        local remaining = ns.Swing:Remaining()
        -- A hollow marker means the timer is predicted, not measured from a
        -- landed hit: worth knowing before you trust it to weave around
        bar.text:SetText(("%.1fs%s"):format(remaining, ns.Swing:IsMeasured() and "" or " ~"))
    else
        bar.text:SetText("")
    end

    -- One colour throughout: the "~" already says when the cycle is predicted,
    -- and a bar that changes colour under you is harder to read at a glance.
    bar:SetStatusBarColor(0.9, 0.7, 0.2)
end

-- Pop an icon above the bar for a moment
function Bar:FlashIcon(texture)
    local flash = self.flash
    if not flash or not ns.db.cooldowns.flash then return end
    flash.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    flash.left = ns.db.cooldowns.flashTime or 0.6
    flash:SetAlpha(1)
    flash:Show()
end

-- The world map covers the bar, but anything the addon draws above its own
-- buttons would still show through. Fading out while the map is open settles
-- it for good, and alpha is safe to change in combat where hiding is not.
function Bar:UpdateMapHiding()
    local f = self.frame
    if not f then return end

    local mapOpen = _G.WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
    local wanted = mapOpen and 0 or 1
    if self.mapAlpha ~= wanted then
        self.mapAlpha = wanted
        f:SetAlpha(wanted)
        if self.flash then self.flash:SetAlpha(wanted) end
    end
end

function Bar:UpdateShieldButton()
    local b = self.shieldButton
    if not b then return end

    local spell = ns.Shield:GetChosen()
    b.icon:SetTexture((spell and spell.icon) or "Interface\\Icons\\Spell_Nature_LightningShield")

    local key = ns.db.binds.shield
    b.keybind:SetText(ns.db.bar.showKeybindText and key
        and key:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a") or "")

    if ns.Shield:IsUp() then
        local charges = ns.Shield:Charges()
        b.icon:SetDesaturated(false)
        b.icon:SetAlpha(1)
        b.glow:SetAlpha(0)
        -- The charge count is the number that matters, not the clock
        b.timer:SetText(charges > 0 and tostring(charges) or "")
        if charges > 0 and charges <= 1 then
            b.timer:SetTextColor(1, 0.45, 0.2)
            SetEdgeColor(b, 1, 0.45, 0.2, 1)
        else
            b.timer:SetTextColor(0.45, 0.8, 1)
            SetEdgeColor(b, 0.3, 0.6, 1, 1)
        end
    else
        b.icon:SetDesaturated(true)
        b.icon:SetAlpha(0.45)
        b.timer:SetText("")
        b.glow:SetAlpha(ns.Shield:IsBlocked() and 0 or 0.25)
        SetEdgeColor(b, 0.15, 0.3, 0.5, 0.9)
    end
end

function Bar:UpdateWeaponButton()
    local b = self.weaponButton
    if not b then return end

    local spell = ns.Weapon:GetChosen()
    b.icon:SetTexture((spell and spell.icon) or "Interface\\Icons\\Spell_Fire_FlameTounge")

    local key = ns.db.binds.weapon
    b.keybind:SetText(ns.db.bar.showKeybindText and key
        and key:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a") or "")

    if ns.Weapon:HasEnchant() then
        local remaining = ns.Weapon:Remaining()
        local low = remaining <= 60

        b.icon:SetDesaturated(false)
        b.icon:SetAlpha(1)
        b.timer:SetText(FormatMinutes(remaining))
        b.glow:SetAlpha(0)

        if low then
            b.timer:SetTextColor(1, 0.45, 0.2)
            SetEdgeColor(b, 1, 0.45, 0.2, 1)
        else
            -- Green frame and green number: imbue on, nothing to think about
            b.timer:SetTextColor(0.35, 1, 0.45)
            SetEdgeColor(b, 0.25, 0.85, 0.35, 1)
        end
    else
        b.icon:SetDesaturated(true)
        b.icon:SetAlpha(0.45)
        b.timer:SetText("")
        b.glow:SetAlpha(ns.Weapon:IsBlocked() and 0 or 0.25)
        SetEdgeColor(b, 0.45, 0.2, 0.1, 0.9)
    end
end

function Bar:UpdateKeybindText()
    if not self.frame then return end
    local show = ns.db.bar.showKeybindText
    for slot = 1, MAX_SLOTS do
        local key = ns.db.binds.slots[slot]
        self.buttons[slot].keybind:SetText(show and key and key:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a") or "")
    end
    if self.seqButton then
        local key = ns.db.binds.sequence
        self.seqButton.keybind:SetText(show and key and key:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a") or "")
    end
    if self.callButton then
        local key = ns.db.binds.call
        self.callButton.keybind:SetText(show and key and key:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a") or "")
    end
end

function Bar:UpdateAll()
    if not self.frame then return end
    for slot = 1, MAX_SLOTS do self:UpdateSlot(slot) end
    if self.seqButton then
        local set = ns.Sets:GetActive()
        self.seqButton.label:SetText(set and set.name:sub(1, 8) or "SET")
    end
    if self.callButton then
        local call = ns.TotemBar:GetActiveCall()
        self.callButton.icon:SetTexture((call and call.icon) or "Interface\\Icons\\Spell_Nature_EarthBindTotem")
    end
    self:UpdateWeaponButton()
    self:UpdateShieldButton()
    self:UpdateKeybindText()
end

-- Why is a button not responding? This answers it without guessing.
function Bar:Diagnose()
    local lines = {}
    local function add(text) lines[#lines + 1] = text end

    add("Bar diagnostics:")
    add(("  in combat: %s"):format(tostring(InCombatLockdown())))
    add(("  bar shown: %s  scale: %.2f  strata: %s  level: %d"):format(
        tostring(self.frame:IsShown()), self.frame:GetScale() or 0,
        tostring(self.frame:GetFrameStrata()), self.frame:GetFrameLevel() or 0))
    add(("  drag strip shown: %s (it must NOT cover the buttons)"):format(
        tostring(self.dragOverlay and self.dragOverlay:IsShown())))

    local function describe(label, button)
        if not button then add(("  %s: missing"):format(label)) return end
        add(("  %s: shown=%s mouse=%s size=%dx%d level=%d alpha=%.2f"):format(
            label, tostring(button:IsShown()), tostring(button:IsMouseEnabled()),
            button:GetWidth() or 0, button:GetHeight() or 0,
            button:GetFrameLevel() or 0, button:GetEffectiveAlpha() or 0))
        add(("      type=%s  macrotext=%s"):format(
            tostring(button:GetAttribute("type")),
            tostring(button:GetAttribute("macrotext"))))
    end

    for slot = 1, MAX_SLOTS do
        describe(ns.ELEMENTS[slot].label, self.buttons[slot])
    end
    describe("Set", self.seqButton)
    describe("Call", self.callButton)

    -- GetMouseFocus is gone on this client; GetMouseFoci returns a list
    local focus
    if type(_G.GetMouseFoci) == "function" then
        focus = (GetMouseFoci() or {})[1]
    elseif type(_G.GetMouseFocus) == "function" then
        focus = GetMouseFocus()
    end
    if focus then
        add(("  frame under the mouse: %s"):format(tostring(focus:GetName() or focus)))
    end

    for _, line in ipairs(lines) do ns:Print(line) end
    return table.concat(lines, "\n")
end

-- Toggleable click tracing: tells us whether the click even reaches the button
function Bar:ToggleClickTest()
    self.clickTest = not self.clickTest
    local function attach(button, label)
        if not button then return end
        if self.clickTest then
            button:SetScript("OnMouseDown", function() ns:Print(label .. ": mouse down received") end)
            button:SetScript("PostClick", function(_, mouseButton)
                ns:Print(("%s: secure click ran (%s)"):format(label, tostring(mouseButton)))
            end)
        else
            button:SetScript("OnMouseDown", nil)
            button:SetScript("PostClick", nil)
        end
    end
    for slot = 1, MAX_SLOTS do attach(self.buttons[slot], ns.ELEMENTS[slot].label) end
    attach(self.seqButton, "Set")
    attach(self.callButton, "Call")
    return self.clickTest
end

function Bar:UpdateTimers()
    if not self.frame or ns.db.bar.hidden then return end
    local showText = ns.db.bar.showTimerText
    local expireAt = ns.db.warnings.expireAt or 4
    local needsRescan = false

    for slot = 1, MAX_SLOTS do
        local totem = ns:GetTotem(slot)
        local b = self.buttons[slot]
        if totem and totem.have then
            local remaining = ns:TotemRemaining(slot)
            if remaining <= 0.05 then
                needsRescan = true
            end
            if showText then
                b.timer:SetText(FormatTime(remaining))
                if remaining <= expireAt then
                    b.timer:SetTextColor(1, 0.25, 0.25)
                elseif remaining <= 10 then
                    b.timer:SetTextColor(1, 0.85, 0.2)
                elseif totem.synthetic then
                    -- Estimated count: the client hides the real data
                    b.timer:SetTextColor(0.55, 0.85, 1)
                else
                    b.timer:SetTextColor(1, 1, 1)
                end
            else
                b.timer:SetText("")
            end
            -- flash when it is about to drop
            if remaining <= expireAt then
                b.glow:SetColorTexture(1, 0.2, 0.2, 1)
                b.glow:SetAlpha(0.15 + 0.2 * math.abs(math.sin(GetTime() * 3)))
            else
                b.glow:SetAlpha(0)
            end
        end
    end

    if needsRescan then ns:ScanTotems() end
end
