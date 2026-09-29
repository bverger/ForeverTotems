--------------------------------------------------------------------------------
-- Forever Totems - SelfTest.lua
-- Checks that only make sense inside the running client: real API presence,
-- cvars, whether the secure click path fires, and what is covering the bar.
-- Output goes to chat, so /chatlog captures it into Logs/WoWChatLog.txt.
--------------------------------------------------------------------------------
local ADDON, ns = ...

local ST = {}
ns.SelfTest = ST

local function Rect(frame)
    if not frame or not frame.GetLeft then return nil end
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (l and r and t and b) then return nil end
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    return l * scale, r * scale, t * scale, b * scale
end

-- Anything visible, mouse-enabled and sitting on top of the button's centre is
-- a candidate for swallowing the click.
function ST:FramesCovering(target, maxDepth)
    local l, r, t, b = Rect(target)
    if not l then return {} end
    local cx, cy = (l + r) / 2, (t + b) / 2
    local targetLevel = target:GetFrameLevel() or 0
    local found = {}

    local function scan(parent, depth)
        if depth > (maxDepth or 3) then return end
        for _, child in ipairs({ parent:GetChildren() }) do
            if child ~= target and child ~= ns.Bar.frame then
                local ok = child.IsVisible and child:IsVisible()
                    and child.IsMouseEnabled and child:IsMouseEnabled()
                if ok then
                    local cl, cr, ct, cb = Rect(child)
                    if cl and cx >= cl and cx <= cr and cy >= cb and cy <= ct then
                        local level = child:GetFrameLevel() or 0
                        found[#found + 1] = ("%s (strata %s, level %d%s)"):format(
                            tostring(child:GetName() or "unnamed"),
                            tostring(child:GetFrameStrata()), level,
                            level > targetLevel and ", ABOVE the button" or "")
                    end
                end
                scan(child, depth + 1)
            end
        end
    end

    scan(UIParent, 1)
    return found
end

-- Does the secure click path run at all? A programmatic Click() will not cast
-- (that needs a hardware event) but PostClick still fires if the wiring is ok.
function ST:TestSecureDispatch(button)
    if not button then return "missing button" end
    if InCombatLockdown() then return "skipped, in combat" end

    local fired = false
    local previous = button:GetScript("PostClick")
    button:SetScript("PostClick", function() fired = true end)
    local ok, err = pcall(button.Click, button)
    button:SetScript("PostClick", previous)

    if not ok then return "Click() errored: " .. tostring(err) end
    return fired and "PostClick fired (secure wiring ok)" or "PostClick did NOT fire"
end

function ST:Run()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
        ns:Print(text)
    end

    add("== Forever Totems self test ==")
    add(("build %s / interface %s / combat %s"):format(
        tostring((select(2, GetBuildInfo()))), tostring((select(4, GetBuildInfo()))),
        tostring(InCombatLockdown())))

    local cvar = GetCVar and GetCVar("ActionButtonUseKeyDown")
    add(("cvar ActionButtonUseKeyDown = %s"):format(tostring(cvar)))
    add(("GetMouseFocus: %s   GetMouseFoci: %s"):format(
        type(_G.GetMouseFocus), type(_G.GetMouseFoci)))

    local button = ns.Bar and ns.Bar.buttons[ns.FIRE]
    if not button then
        add("no fire button, bar was never built")
        return table.concat(lines, "\n")
    end

    add(("fire button: type=%s macrotext=%s"):format(
        tostring(button:GetAttribute("type")), tostring(button:GetAttribute("macrotext"))))
    local clickEnabled = button.IsMouseClickEnabled and button:IsMouseClickEnabled()
    add(("  mouse enabled: %s   click enabled: %s"):format(
        tostring(button:IsMouseEnabled()), tostring(clickEnabled)))
    add(("  effective scale %.2f, effective alpha %.2f"):format(
        button:GetEffectiveScale() or 0, button:GetEffectiveAlpha() or 0))

    local l, r, t, b = Rect(button)
    add(("  screen rect: %s"):format(l and ("%.0f,%.0f to %.0f,%.0f"):format(l, b, r, t) or "off screen"))

    add("secure dispatch: " .. tostring(self:TestSecureDispatch(button)))

    local covering = self:FramesCovering(button)
    add(("frames over the fire button: %d"):format(#covering))
    for _, entry in ipairs(covering) do add("  " .. entry) end

    local spellName = button:GetAttribute("macrotext")
    if spellName then
        spellName = spellName:match("^/cast%s+(.+)$")
    end
    if spellName then
        local usable, noMana = IsUsableSpell and IsUsableSpell(spellName)
        add(("spell '%s': usable=%s noMana=%s known=%s"):format(
            spellName, tostring(usable), tostring(noMana),
            tostring(C_Spell and C_Spell.DoesSpellExist and C_Spell.DoesSpellExist(spellName))))
    end

    add("== end of self test ==")
    return table.concat(lines, "\n")
end
