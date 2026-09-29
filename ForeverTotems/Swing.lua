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

-- A short trace of what the timer does, so a fight can be examined afterwards
-- instead of guessed at.
local trace, TRACE_MAX = {}, 40

local function Trace(format_, ...)
    local ok, text = pcall(string.format, format_, ...)
    trace[#trace + 1] = ("%7.2f  %s"):format(GetTime() % 10000, ok and text or tostring(format_))
    if #trace > TRACE_MAX then table.remove(trace, 1) end
end


local state = {
    attacking = false,
    start = 0,
    duration = 0,
    lastAccepted = 0,
    measured = false,
}

--------------------------------------------------------------------------------
-- Weapon speed
--------------------------------------------------------------------------------
-- The live value can stop being readable mid-fight (this client withholds data
-- in combat), and a zero here froze the bar at 0.0s because the next swing
-- could not be scheduled. So the last good reading is kept and reused.
function Swing:GetSpeed()
    local live = 0
    if type(_G.UnitAttackSpeed) == "function" then
        local ok, main = pcall(UnitAttackSpeed, "player")
        if ok and main and not ns.AnySecret(main) and main > 0 then
            live = main
        end
    end

    if live > 0 then
        if state.lastGoodSpeed ~= live then
            Trace("weapon speed %.2f", live)
        end
        state.lastGoodSpeed = live
        return live
    end

    if state.lastGoodSpeed and state.lastGoodSpeed > 0 then
        Trace("speed unavailable, reusing %.2f", state.lastGoodSpeed)
        return state.lastGoodSpeed
    end
    return 0
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
    if speed <= 0 then
        Trace("start refused: weapon speed is %s", tostring(speed))
        return
    end
    Trace("start (%s) duration %.2f", measured and "measured" or "predicted", speed)
    state.start = GetTime()
    state.duration = speed
    state.attacking = true
    state.measured = measured and true or false
end

function Swing:Stop()
    if state.attacking then Trace("stop") end
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

-- Auto attack being on is not evidence of anything: right clicking a mob from
-- thirty yards away turns it on while you walk over. The bar only exists once
-- a hit has actually landed and anchored the cycle.
function Swing:IsActive()
    return state.attacking and state.anchored and state.duration > 0
end

function Swing:IsMeasured()
    return state.measured
end

-- The swing landed: restart the clock from now. Guarded by a minimum gap so a
-- spell hit landing at the same moment does not restart it twice.
function Swing:OnHit()
    -- Damage on your target can come from a totem or a periodic effect, so a
    -- hit only counts while you are actually swinging.
    if not state.attacking and self:IsAutoAttacking() ~= true then
        Trace("hit ignored: not swinging")
        return
    end

    local now = GetTime()
    local speed = self:GetSpeed()
    if speed <= 0 then return end

    -- Telling your swing from your Searing Totem ticking on the same target is
    -- the whole problem, and where a hit falls inside the window turned out to
    -- be a bad criterion: one bad anchor and every real swing lands in the
    -- rejected half forever. The cadence is far more telling. Your swings
    -- arrive one weapon speed apart; a totem does not.
    local delta = now - (state.lastAccepted or 0)

    if state.anchored then
        if math.abs(delta - speed) <= speed * 0.25 then
            Trace("hit accepted: %.2fs since the last, matches a %.2fs swing", delta, speed)
        elseif delta > speed * 1.5 then
            Trace("hit accepted: %.2fs since the last, we had lost the cadence", delta)
        else
            Trace("hit ignored: %.2fs since the last, no swing is that quick", delta)
            return
        end
    end

    state.lastAccepted = now
    Trace(state.anchored and "hit landed" or "first hit: anchoring the cycle here")
    state.anchored = true
    state.missedCycles = 0
    self:Start(true)
end

-- Auto attack keeps swinging whether or not we hear about it, so when the
-- window runs out we roll straight into the next one. Any hit event that does
-- reach us then re-syncs the clock instead of starting it.
function Swing:Update()
    -- Follow the auto attack state directly: it starts and stops the bar
    local auto = self:IsAutoAttacking()
    if auto ~= state.lastAuto then
        Trace("auto attack -> %s", tostring(auto))
        state.lastAuto = auto
    end
    if auto == false then
        if state.attacking then self:Stop() end
        return
    elseif auto == true and not state.attacking then
        -- Armed, but waiting for the first hit before showing anything
        state.attacking = true
        state.anchored = false
        state.missedCycles = 0
        state.duration = 0
        Trace("auto attack on: waiting for the first hit to land")
    end

    if not state.attacking then return end
    if not state.anchored then return end      -- nothing to roll over yet
    if state.duration <= 0 then return end

    local elapsed = GetTime() - state.start
    if elapsed < state.duration then return end

    local speed = self:GetSpeed()
    if speed <= 0 then
        Trace("rollover refused: weapon speed is %s", tostring(speed))
        return
    end

    state.missedCycles = (state.missedCycles or 0) + 1
    if state.missedCycles >= 2 and state.anchored then
        state.anchored = false
        Trace("two cycles with no hit: dropping the anchor, next hit re-anchors")
    end
    Trace("rollover after %.2fs", elapsed)
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
        -- Only damage on the unit you are hitting. Never "targettarget": in a
        -- melee fight that is you, so every hit you took reset your swing.
        if unit == "target" then
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

--------------------------------------------------------------------------------
-- State report
--------------------------------------------------------------------------------
function Swing:StateReport()
    local lines = { "Swing timer state:" }
    local function add(text) lines[#lines + 1] = text end

    add(("  UnitAttackSpeed: %s -> %.2fs"):format(type(_G.UnitAttackSpeed), self:GetSpeed()))
    add(("  IsCurrentSpell: %s   auto attacking: %s"):format(
        type(_G.IsCurrentSpell), tostring(self:IsAutoAttacking())))
    add(("  attacking=%s duration=%.2f remaining=%.2f measured=%s anchored=%s"):format(
        tostring(state.attacking), state.duration, self:Remaining(),
        tostring(state.measured), tostring(state.anchored)))
    add(("  in combat: %s"):format(tostring(InCombatLockdown())))
    add("  trace (most recent last):")
    for _, entry in ipairs(trace) do add("    " .. entry) end
    if #trace == 0 then add("    empty") end

    for _, line in ipairs(lines) do ns:Print(line) end
    return table.concat(lines, "\n")
end
