--------------------------------------------------------------------------------
-- Forever Totems - Flyout.lua
-- Hover an icon on the bar and every totem of that element pops up; click one
-- to put it in the active set.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Flyout = {}
ns.Flyout = Flyout

local FONT = "Fonts\\FRIZQT__.TTF"
local ICON = 30
local GAP = 2
local PER_COLUMN = 6
local GRACE = 0.25   -- seconds of slack before it closes on mouse-out

local panel, pool = nil, {}

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------
local function EnsurePanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "ForeverTotemsFlyout", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:Hide()
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        panel:SetBackdropColor(0, 0, 0, 0.85)
    end

    -- Close once the mouse is off both the panel and the icon that opened it.
    -- IsMouseOver is the widget method; the old MouseIsOver global is gone.
    local function IsOver(frame)
        return frame and frame.IsMouseOver and frame:IsMouseOver()
    end

    panel:SetScript("OnUpdate", function(self, elapsed)
        local over = IsOver(self) or IsOver(self.anchor)
        if over then
            self.away = 0
        else
            self.away = (self.away or 0) + elapsed
            if self.away > GRACE then self:Hide() end
        end
    end)

    return panel
end

local function AcquireIcon()
    for _, icon in ipairs(pool) do
        if not icon:IsShown() then return icon end
    end
    local b = CreateFrame("Button", nil, EnsurePanel())
    b:SetSize(ICON, ICON)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0, 0, 0, 1)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 1, -1)
    b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.hl = b:CreateTexture(nil, "OVERLAY")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0)
    b:SetScript("OnEnter", function(self)
        self.hl:SetAlpha(0.3)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.spellName or "", 1, 1, 1)
        GameTooltip:AddLine("Click to use this one in the set", 0.4, 0.8, 0.4)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.hl:SetAlpha(self.chosen and 0.35 or 0)
        GameTooltip:Hide()
    end)
    pool[#pool + 1] = b
    return b
end

--------------------------------------------------------------------------------
-- Opening
--------------------------------------------------------------------------------
function Flyout:Entries(slot)
    local entries = {}
    for _, entry in ipairs((ns.totemSpellsBySlot and ns.totemSpellsBySlot[slot]) or {}) do
        entries[#entries + 1] = entry
    end
    for _, entry in ipairs((ns.totemSpellsBySlot and ns.totemSpellsBySlot[0]) or {}) do
        entries[#entries + 1] = entry
    end
    return entries
end

-- Generic opener: a list of { name, icon }, who is currently chosen, and what
-- to do when one is clicked. The totem slots and the weapon imbue both use it.
function Flyout:OpenEntries(entries, anchor, chosenName, onSelect)
    if not entries or #entries == 0 then return false end

    local p = EnsurePanel()
    for _, icon in ipairs(pool) do icon:Hide() end

    local rows = math.min(#entries, PER_COLUMN)
    local columns = math.ceil(#entries / PER_COLUMN)

    for index, entry in ipairs(entries) do
        local icon = AcquireIcon()
        local column = math.floor((index - 1) / PER_COLUMN)
        local row = (index - 1) % PER_COLUMN
        icon:SetParent(p)
        icon:ClearAllPoints()
        -- Grows upwards from the bottom-left corner of the panel
        icon:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT",
            3 + column * (ICON + GAP), 3 + row * (ICON + GAP))
        icon.tex:SetTexture(entry.icon or ns.SpellTextureByName(entry.name) or "Interface\\Icons\\INV_Misc_QuestionMark")
        icon.spellName = entry.name
        icon.chosen = (chosenName == entry.name) or false
        icon.hl:SetAlpha(icon.chosen and 0.35 or 0)
        icon:SetScript("OnClick", function()
            onSelect(entry)
            p:Hide()
        end)
        icon:Show()
    end

    p:SetSize(columns * (ICON + GAP) + 4, rows * (ICON + GAP) + 4)
    p:ClearAllPoints()
    p:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    p.anchor = anchor
    p.away = 0
    p:Show()
    return true
end

function Flyout:Open(slot, anchor)
    local setIndex = ns.Sets:GetActiveIndex()
    local current = ns.Sets:GetSpellForSlot(slot)
    return self:OpenEntries(self:Entries(slot), anchor, current and current.name, function(entry)
        ns.Sets:AssignSpell(setIndex, slot, entry)
        ns:RefreshTotemSpells()
    end)
end

function Flyout:Close()
    if panel then panel:Hide() end
end

--------------------------------------------------------------------------------
-- Opening on hover
--
-- There used to be a little arrow on top of each icon. Hovering the icon
-- itself is less furniture on screen, and a short delay keeps the panel from
-- popping up every time the mouse crosses the bar on its way somewhere else.
--------------------------------------------------------------------------------
local HOVER_DELAY = 0.35
local watcher = CreateFrame("Frame")
local hovering

local function Pending(button)
    hovering = button and { button = button, since = GetTime() } or nil
    watcher:SetScript("OnUpdate", hovering and function()
        if not hovering then return end
        local b = hovering.button
        if not (b.IsMouseOver and b:IsMouseOver()) then
            hovering = nil
            watcher:SetScript("OnUpdate", nil)
            return
        end
        if (GetTime() - hovering.since) >= HOVER_DELAY then
            local open = b.flyoutOpen
            hovering = nil
            watcher:SetScript("OnUpdate", nil)
            if open then open(b) end
        end
    end or nil)
end

function Flyout:AttachHover(button, getEntries, getChosen, onSelect)
    button.flyoutOpen = function(self)
        Flyout:OpenEntries(getEntries(), self, getChosen(), onSelect)
    end
    if button.flyoutHooked then return end
    button.flyoutHooked = true

    button:HookScript("OnEnter", function(self)
        if not ns.db.bar.showArrows then return end
        Pending(self)
    end)
    button:HookScript("OnLeave", function()
        Pending(nil)
    end)
end

function Flyout:AttachSlot(button, slot)
    self:AttachHover(button,
        function() return self:Entries(slot) end,
        function()
            local current = ns.Sets:GetSpellForSlot(slot)
            return current and current.name
        end,
        function(entry)
            ns.Sets:AssignSpell(ns.Sets:GetActiveIndex(), slot, entry)
            ns:RefreshTotemSpells()
        end)
end

function Flyout:UpdateArrows()
    if not (ns.Bar and ns.Bar.buttons) then return end
    for slot = 1, ns.MAX_SLOTS do
        local button = ns.Bar.buttons[slot]
        if button then self:AttachSlot(button, slot) end
    end
end
