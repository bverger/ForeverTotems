--------------------------------------------------------------------------------
-- Forever Totems - Flyout.lua
-- A small arrow on top of each slot. Hover it and every totem of that element
-- pops up; click one to put it in the active set.
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

    -- Close once the mouse is off both the panel and the arrow that opened it.
    -- IsMouseOver is the widget method; the old MouseIsOver global is gone.
    local function IsOver(frame)
        return frame and frame.IsMouseOver and frame:IsMouseOver()
    end

    panel:SetScript("OnUpdate", function(self, elapsed)
        local over = IsOver(self) or IsOver(self.arrow)
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
function Flyout:OpenEntries(entries, arrow, chosenName, onSelect)
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
    p:SetPoint("BOTTOM", arrow, "TOP", 0, 2)
    p.arrow = arrow
    p.away = 0
    p:Show()
    return true
end

function Flyout:Open(slot, arrow)
    local setIndex = ns.Sets:GetActiveIndex()
    local current = ns.Sets:GetSpellForSlot(slot)
    return self:OpenEntries(self:Entries(slot), arrow, current and current.name, function(entry)
        ns.Sets:AssignSpell(setIndex, slot, entry)
        ns:RefreshTotemSpells()
    end)
end

-- An arrow for any button, not just a totem slot
function Flyout:AttachArrowTo(button, color, getEntries, getChosen, onSelect)
    if button.arrow then return button.arrow end

    local arrow = CreateFrame("Button", nil, button)
    arrow:SetSize(16, 10)
    arrow:SetPoint("BOTTOM", button, "TOP", 0, 1)
    arrow:SetFrameStrata("HIGH")

    arrow.bg = arrow:CreateTexture(nil, "BACKGROUND")
    arrow.bg:SetAllPoints()
    arrow.bg:SetColorTexture(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.9)

    arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
    arrow.tex:SetTexture("Interface\\Buttons\\ActionBarFlyoutButton")
    arrow.tex:SetTexCoord(0.625, 0.984, 0.7421875, 0.828125)
    arrow.tex:SetPoint("CENTER")
    arrow.tex:SetSize(16, 10)

    local function open(self)
        Flyout:OpenEntries(getEntries(), self, getChosen(), onSelect)
    end

    arrow:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(color[1], color[2], color[3], 1)
        open(self)
    end)
    arrow:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.9)
    end)
    arrow:SetScript("OnClick", open)

    button.arrow = arrow
    return arrow
end

function Flyout:Close()
    if panel then panel:Hide() end
end

--------------------------------------------------------------------------------
-- The arrow on each slot
--------------------------------------------------------------------------------
function Flyout:AttachArrow(button, slot)
    if button.arrow then return button.arrow end

    local arrow = CreateFrame("Button", nil, button)
    arrow:SetSize(16, 10)
    arrow:SetPoint("BOTTOM", button, "TOP", 0, 1)
    arrow:SetFrameStrata("HIGH")

    local element = ns.ELEMENTS[slot]
    arrow.bg = arrow:CreateTexture(nil, "BACKGROUND")
    arrow.bg:SetAllPoints()
    arrow.bg:SetColorTexture(element.color[1] * 0.5, element.color[2] * 0.5, element.color[3] * 0.5, 0.9)

    -- Blizzard's own flyout arrow; the coloured tab behind it keeps the arrow
    -- findable even if this texture is missing on some client.
    arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
    arrow.tex:SetTexture("Interface\\Buttons\\ActionBarFlyoutButton")
    arrow.tex:SetTexCoord(0.625, 0.984, 0.7421875, 0.828125)
    arrow.tex:SetPoint("CENTER")
    arrow.tex:SetSize(16, 10)

    arrow:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(element.color[1], element.color[2], element.color[3], 1)
        Flyout:Open(slot, self)
    end)
    arrow:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(element.color[1] * 0.5, element.color[2] * 0.5, element.color[3] * 0.5, 0.9)
    end)
    arrow:SetScript("OnClick", function(self) Flyout:Open(slot, self) end)

    button.arrow = arrow
    return arrow
end

function Flyout:UpdateArrows()
    if not (ns.Bar and ns.Bar.buttons) then return end
    local show = ns.db.bar.showArrows
    for slot = 1, ns.MAX_SLOTS do
        local button = ns.Bar.buttons[slot]
        if button then
            local arrow = self:AttachArrow(button, slot)
            arrow:SetShown(show and button:IsShown() and #self:Entries(slot) > 0)
        end
    end
end
