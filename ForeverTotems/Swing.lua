--------------------------------------------------------------------------------
-- Forever Totems - Swing.lua
-- Melee swing timer.
--
-- The usual way to time swings is the combat log, and this client forbids this
-- addon from registering it. So the timer runs on weapon speed plus the events
-- that do reach us, and it says plainly when it is predicting rather than
-- measuring.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local Swing = {}
ns.Swing = Swing

local state = {
    attacking = false,
    start = 0,
    duration = 0,
    lastHit = 0,
    measured = false,
}

--------------------------------------------------------------------------------
-- Weapon speed
--------------------------------------------------------------------------------
function Swing:GetSpeed()
    if type(_G.UnitAttackSpeed) ~= "function" then return 0 end
    local ok, main = pcall(UnitAttackSpeed, "player")
    if not ok or not main or ns.AnySecret(main) then return 0 end
    return main
end

-- Spell 6603 is plain "Attack": while it is the current spell you are swinging.
-- Asking this every tick beats relying on PLAYER_ENTER_COMBAT, which does not
-- reach us on this client.
local AUTO_ATTACK_SPELL = 6603

-- true, false, or nil when the client will not tell us
function Swing:IsAutoAttacking()
    if type(_G.IsCurrentSpell) ~= "function" then return nil end
    local ok, current = pcall(IsCurrentSpell, AUTO_ATTACK_SPELL)
    if not ok or ns.AnySecret(current) then return nil end
    return current and true or false
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
function Swing:Start(measured)
    local speed = self:GetSpeed()
    if speed <= 0 then return end
    state.start = GetTime()
    state.duration = speed
    state.attacking = true
    state.measured = measured and true or false
end

function Swing:Stop()
    state.attacking = false
    state.start, state.duration = 0, 0
end

function Swing:Remaining()
    if not state.attacking or state.duration <= 0 then return 0 end
    return math.max(0, (state.start + state.duration) - GetTime())
end

function Swing:Progress()
    if not state.attacking or state.duration <= 0 then return 0 end
    return 1 - (self:Remaining() / state.duration)
end

function Swing:IsActive()
    return state.attacking and state.duration > 0
end

function Swing:IsMeasured()
    return state.measured
end

-- The swing landed: restart the clock from now. Guarded by a minimum gap so a
-- spell hit landing at the same moment does not restart it twice.
function Swing:OnHit()
    -- Damage on your target can come from a totem or a periodic effect, so a
    -- hit only counts while you are actually swinging.
    if not state.attacking and self:IsAutoAttacking() ~= true then return end

    local now = GetTime()
    local speed = self:GetSpeed()
    if speed <= 0 then return end
    if (now - state.lastHit) < (speed * 0.4) then return end
    state.lastHit = now
    self:Start(true)
end

-- Auto attack keeps swinging whether or not we hear about it, so when the
-- window runs out we roll straight into the next one. Any hit event that does
-- reach us then re-syncs the clock instead of starting it.
function Swing:Update()
    -- Follow the auto attack state directly: it starts and stops the bar
    local auto = self:IsAutoAttacking()
    if auto == false then
        if state.attacking then self:Stop() end
        return
    elseif auto == true and not state.attacking then
        self:Start(false)
    end

    if not state.attacking then return end
    if state.duration <= 0 then
        local speed = self:GetSpeed()
        if speed > 0 then
            state.duration = speed
            state.start = GetTime()
        end
        return
    end

    local elapsed = GetTime() - state.start
    if elapsed < state.duration then return end

    local speed = self:GetSpeed()
    if speed <= 0 then return end

    -- Carry the overshoot over so the bar does not drift forwards
    local overshoot = elapsed - state.duration
    if overshoot > speed then overshoot = 0 end
    state.duration = speed
    state.start = GetTime() - overshoot
    state.measured = false          -- from here on we are predicting again
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTER_COMBAT" then
        Swing:Start(false)          -- auto attack started: predicted from here
    elseif event == "PLAYER_LEAVE_COMBAT" or event == "PLAYER_REGEN_ENABLED" then
        Swing:Stop()
    elseif event == "UNIT_ATTACK_SPEED" then
        local unit = ...
        if unit == "player" and state.attacking then
            -- Keep the current swing but retime the rest of it
            state.duration = Swing:GetSpeed()
        end
    elseif event == "UNIT_COMBAT" then
        local unit, action = ...
        if unit == "target" or unit == "targettarget" then
            if action == "WOUND" or action == "MISS" or action == "DODGE"
                or action == "PARRY" or action == "BLOCK" then
                Swing:OnHit()
            end
        end
    end
end)

function Swing:Enable()
    events:RegisterEvent("PLAYER_ENTER_COMBAT")
    events:RegisterEvent("PLAYER_LEAVE_COMBAT")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("UNIT_ATTACK_SPEED")
    events:RegisterEvent("UNIT_COMBAT")
end

--------------------------------------------------------------------------------
-- Probe: which of these actually fire, and how often
--------------------------------------------------------------------------------
local probe, probeLog, probeOn = CreateFrame("Frame"), {}, false
local CANDIDATES = {
    "UNIT_COMBAT", "UNIT_ATTACK", "UNIT_ATTACK_SPEED", "PLAYER_ENTER_COMBAT",
    "PLAYER_LEAVE_COMBAT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_TARGET",
}

probe:SetScript("OnEvent", function(_, event, ...)
    if not probeOn then return end
    local first, second = ...
    probeLog[#probeLog + 1] = ("%.2f  %s  %s %s"):format(
        GetTime() % 1000, event, tostring(first), tostring(second))
    if #probeLog >= 40 then probeOn = false end
end)

function Swing:ToggleProbe()
    probeOn = not probeOn
    if probeOn then
        probeLog = {}
        for _, event in ipairs(CANDIDATES) do
            pcall(probe.RegisterEvent, probe, event)
        end
    else
        pcall(probe.UnregisterAllEvents, probe)
    end
    return probeOn
end

function Swing:ProbeReport()
    local lines = { "Swing probe:" }
    lines[#lines + 1] = ("  weapon speed: %.2fs"):format(self:GetSpeed())
    lines[#lines + 1] = ("  IsCurrentSpell: %s   auto attacking: %s"):format(
        type(_G.IsCurrentSpell), tostring(self:IsAutoAttacking()))
    lines[#lines + 1] = ("  events captured: %d"):format(#probeLog)
    for _, entry in ipairs(probeLog) do lines[#lines + 1] = "  " .. entry end
    if #probeLog == 0 then
        lines[#lines + 1] = "  Nothing captured. Run /ft swingprobe, melee something, run it again."
    end
    return table.concat(lines, "\n")
end
