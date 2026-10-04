--------------------------------------------------------------------------------
-- Forever Totems - Warnings.lua
-- Expiry, destroyed-totem and out-of-range warnings.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local W = {}
ns.Warnings = W

local FONT = "Fonts\\FRIZQT__.TTF"
local RANGE_CHECK_INTERVAL = 0.3
local rangeAccum = 0

--------------------------------------------------------------------------------
-- On-screen warning
--------------------------------------------------------------------------------
local alertFrame
local ALERT_HOLD, ALERT_FADE = 1.4, 1.0

local function GetAlertFrame()
    if alertFrame then return alertFrame end
    local f = CreateFrame("Frame", "ForeverTotemsAlert", UIParent)
    f:SetSize(500, 40)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetAlpha(0)
    f:Hide()

    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFont(FONT, 24, "OUTLINE")
    f.text:SetPoint("CENTER")

    -- Hand-rolled fade: an animation adds nothing here and ties the addon to
    -- one more API that can change between client versions.
    f:SetScript("OnUpdate", function(self)
        local left = (self.expiresAt or 0) - GetTime()
        if left <= 0 then
            self:SetAlpha(0)
            self:Hide()
        elseif left < ALERT_FADE then
            self:SetAlpha(left / ALERT_FADE)
        else
            self:SetAlpha(1)
        end
    end)

    alertFrame = f
    return f
end

-- Available sounds. Each one lists several constants because not all of them
-- exist on every client: the first one present is used.
ns.SOUND_CHOICES = {
    { key = "soft",   label = "Soft",          kits = { "MAP_PING", "IG_MINIMAP_ZOOM_OUT" } },
    { key = "paper",   label = "Paper",          kits = { "IG_QUEST_LIST_OPEN", "IG_QUEST_LOG_OPEN", "IG_CHARACTER_INFO_OPEN" } },
    { key = "whisper", label = "Whisper",        kits = { "TELL_MESSAGE" } },
    { key = "ready",   label = "Ready check",   kits = { "READY_CHECK" } },
    { key = "raid",   label = "Raid warning", kits = { "RAID_WARNING" } },
}

local function ResolveSound(key)
    local kit = _G.SOUNDKIT
    if not kit then return nil end
    for _, choice in ipairs(ns.SOUND_CHOICES) do
        if choice.key == key then
            for _, name in ipairs(choice.kits) do
                if kit[name] then return kit[name], choice end
            end
        end
    end
    return nil
end

-- Only the options this client actually has
function W:AvailableSounds()
    local list = {}
    for _, choice in ipairs(ns.SOUND_CHOICES) do
        if ResolveSound(choice.key) then list[#list + 1] = choice end
    end
    return list
end

function W:GetSoundChoice()
    local key = ns.db.warnings.soundChoice
    local _, choice = ResolveSound(key)
    if choice then return choice end
    local available = self:AvailableSounds()
    return available[1]
end

function W:GetSoundLabel()
    local choice = self:GetSoundChoice()
    return choice and choice.label or "none"
end

function W:CycleSound()
    local available = self:AvailableSounds()
    if #available == 0 then return end
    local current = self:GetSoundChoice()
    local index = 1
    for i, choice in ipairs(available) do
        if current and choice.key == current.key then index = i end
    end
    local nextChoice = available[(index % #available) + 1]
    ns.db.warnings.soundChoice = nextChoice.key
    self:TestSound()
    return nextChoice
end

-- SFX channel, not Master: this way the warning respects the game's sound
-- effects volume instead of blasting over everything.
local function PlayAlertSound()
    if not ns.db.warnings.sound then return end
    local choice = W:GetSoundChoice()
    local id = choice and ResolveSound(choice.key)
    if id then PlaySound(id, "SFX") end
end

-- A bare sound with no text, for things that do not deserve a banner. It takes
-- its own choice and channel: a cooldown coming back should cut through, while
-- a totem expiring should not startle you.
function W:PlayKey(key, channel)
    local kit = _G.SOUNDKIT
    if not kit then return end
    for _, choice in ipairs(ns.SOUND_CHOICES) do
        if choice.key == key then
            for _, name in ipairs(choice.kits) do
                if kit[name] then
                    PlaySound(kit[name], channel or "SFX")
                    return true
                end
            end
        end
    end
    return false
end

function W:PlayCue()
    PlayAlertSound()
end

function W:TestSound()
    local choice = self:GetSoundChoice()
    local id = choice and ResolveSound(choice.key)
    if id then PlaySound(id, "SFX") end
end

function W:Alert(text, r, g, b, withSound)
    local cfg = ns.db.warnings
    if cfg.chat then
        ns:Print(text)
    end
    if cfg.screen then
        local f = GetAlertFrame()
        f.text:SetText(text)
        f.text:SetTextColor(r or 1, g or 0.82, b or 0)
        f.expiresAt = GetTime() + ALERT_HOLD + ALERT_FADE
        f:SetAlpha(1)
        f:Show()
    end
    if withSound then PlayAlertSound() end
end

--------------------------------------------------------------------------------
-- Hooks from the totem scan
--------------------------------------------------------------------------------
function W:OnTotemPlaced(slot, totem)
    if not totem.wx and ns.db.warnings.range then
        ns:Debug("no map coordinates in this zone: range warning disabled here")
    end
end

function W:OnTotemLost(slot, totem, remaining)
    local cfg = ns.db.warnings
    if not cfg.death then return end
    -- If it still had time left it did not expire: something killed it
    if remaining and remaining > 1.5 then
        local element = ns.ELEMENTS[slot]
        self:Alert(string.format("%s destroyed (%s)", totem.name or element.label, element.label), 1, 0.3, 0.3, true)
    end
end

--------------------------------------------------------------------------------
-- Periodic checks (called from the bar's OnUpdate)
--------------------------------------------------------------------------------
function W:Update(elapsed)
    local cfg = ns.db.warnings
    local now = GetTime()

    -- Expiry
    if cfg.expire then
        for slot = 1, ns.MAX_SLOTS do
            local totem = ns:GetTotem(slot)
            if totem and totem.have and not totem.warnedExpire then
                local remaining = ns:TotemRemaining(slot)
                if remaining > 0 and remaining <= (cfg.expireAt or 4) then
                    totem.warnedExpire = true
                    local element = ns.ELEMENTS[slot]
                    self:Alert(string.format("%s is expiring", totem.name or element.label), 1, 0.8, 0.2, true)
                end
            end
        end
    end

    -- Range
    if not cfg.range then return end
    rangeAccum = rangeAccum + elapsed
    if rangeAccum < RANGE_CHECK_INTERVAL then return end
    rangeAccum = 0

    local px, py, pc = ns.GetWorldPos()
    if not px then return end

    local limit = cfg.rangeYards or 22

    for slot = 1, ns.MAX_SLOTS do
        local totem = ns:GetTotem(slot)
        -- A single warning per totem: it re-arms when you drop it again
        if totem and totem.have and totem.wx and totem.wc == pc and not totem.warnedRange then
            local dx, dy = px - totem.wx, py - totem.wy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > limit then
                totem.warnedRange = true
                totem.lastRangeWarn = now
                local element = ns.ELEMENTS[slot]
                self:Alert(string.format("Out of range of %s (%d yd)", totem.name or element.label, math.floor(dist)), 0.6, 0.8, 1, true)
            end
        end
    end
end
