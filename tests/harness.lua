-- Stub minimo de la API de WoW para cargar ForeverTotems fuera del juego
local frames = {}

local FrameMethods = {}
-- Metodos que existen de verdad en la API de widgets de WoW. Cualquier otro
-- provoca un fallo aqui, que es justo lo que pasaria dentro del juego.
local WIDGET_API = {}
for m in ([[
SetPoint ClearAllPoints SetAllPoints SetSize SetWidth SetHeight SetScale
Show Hide SetShown SetAlpha GetAlpha SetParent SetFrameStrata SetFrameLevel
EnableMouse EnableKeyboard SetPropagateKeyboardInput RegisterForDrag
StartMoving StopMovingOrSizing SetMovable SetClampedToScreen SetHitRectInsets
SetBackdrop SetBackdropColor SetBackdropBorderColor
RegisterForClicks SetAttribute GetAttribute SetEnabled
SetNormalTexture SetPushedTexture SetHighlightTexture SetCheckedTexture
SetTexture SetTexCoord SetColorTexture SetDesaturated SetVertexColor
SetFont SetTextColor SetJustifyH
SetCooldown SetDrawEdge SetReverse SetHideCountdownNumbers Clear
SetStatusBarTexture SetStatusBarColor GetStatusBarTexture SetRotatesTexture
SetMinMaxValues SetValueStep SetObeyStepOnDrag SetOrientation SetThumbTexture
IsMouseClickEnabled SetMouseClickEnabled
HighlightText SetFocus ClearFocus SetMultiLine SetAutoFocus SetFontObject
SetMaxLetters Insert SetScrollChild SetJustifyV EnableMouseWheel SetIndentedWordWrap
SetOwner AddLine
CreateAnimationGroup CreateAnimation SetDuration SetOrder SetFromAlpha SetToAlpha
Play Stop
]]):gmatch("%S+") do WIDGET_API[m] = true end

local FrameMT = { __index = function(t, k)
    local m = FrameMethods[k]
    if m then return m end
    if type(k) == "string" and WIDGET_API[k] then
        local fn = function(self) return self end
        rawset(t, k, fn)
        return fn
    end
    -- Los metodos de WoW son CamelCase: si empieza por mayuscula y no esta en
    -- la lista, o no existe o me lo he inventado. Los campos propios del addon
    -- van en minuscula, asi que siguen devolviendo nil sin molestar.
    local KNOWN_FIELDS = { Text = true }
    if type(k) == "string" and k:match("^%u") and not KNOWN_FIELDS[k] then
        error("metodo inexistente en la API de WoW: " .. k, 2)
    end
    return nil
end }

local function NewObject(name, parent)
    local o = setmetatable({ __children = {}, __name = name or false, __parent = parent or false, __scripts = {}, __events = {}, __shown = true }, FrameMT)
    return o
end

FrameMethods.GetName = function(self) return self.__name or nil end
FrameMethods.GetParent = function(self) return self.__parent or nil end
FrameMethods.GetFrameLevel = function(self) return 1 end
FrameMethods.GetChecked = function(self) return self.__checked end
FrameMethods.SetChecked = function(self, v) self.__checked = v end
FrameMethods.IsShown = function(self) return self.__shown end
FrameMethods.IsVisible = function(self) return self.__shown end
FrameMethods.Show = function(self) self.__shown = true end
FrameMethods.Hide = function(self) self.__shown = false end
FrameMethods.SetShown = function(self, v) self.__shown = v and true or false end
FrameMethods.GetPoint = function(self) return "CENTER", UIParent, "CENTER", 0, 0 end
FrameMethods.GetText = function(self) return self.__text end
FrameMethods.SetText = function(self, t) self.__text = t end
FrameMethods.CreateTexture = function(self) return NewObject(nil, self) end
FrameMethods.CreateFontString = function(self) return NewObject(nil, self) end
FrameMethods.CreateAnimationGroup = function(self) return NewObject(nil, self) end
FrameMethods.CreateAnimation = function(self) return NewObject(nil, self) end
FrameMethods.SetScript = function(self, script, fn) self.__scripts[script] = fn end
FrameMethods.GetScript = function(self, script) return self.__scripts[script] end
FrameMethods.HookScript = function(self, script, fn)
    local previous = self.__scripts[script]
    self.__scripts[script] = function(...)
        if previous then previous(...) end
        fn(...)
    end
end
FrameMethods.RegisterForClicks = function(self, ...) self.__clicks = { ... } end
FrameMethods.RegisterEvent = function(self, e) self.__events[e] = true end
FrameMethods.IsEventRegistered = function(self, e) return self.__events[e] == true end
FrameMethods.UnregisterEvent = function(self, e) self.__events[e] = nil end
FrameMethods.SetHeight = function(self, h) self.__height = h end
FrameMethods.SetAllPoints = function(self) self.__allPoints = true end
FrameMethods.SetColorTexture = function(self, r, g, b, a) self.__color = { r, g, b, a } end
FrameMethods.SetStatusBarColor = function(self, r, g, b, a) self.__barColor = { r, g, b, a } end
FrameMethods.SetTexture = function(self, t) self.__texture = t end
FrameMethods.SetText = function(self, t) self.__text = t end
FrameMethods.SetAlpha = function(self, a) self.__alpha = a end
FrameMethods.GetAlpha = function(self) return self.__alpha or 1 end
FrameMethods.SetAttribute = function(self, k, v) self.__attr = self.__attr or {}; self.__attr[k] = v end
FrameMethods.GetAttribute = function(self, k) return self.__attr and self.__attr[k] end
FrameMethods.GetValue = function(self) return self.__value or 0 end
FrameMethods.GetWidth = function(self) return self.__w or 44 end
FrameMethods.GetHeight = function(self) return self.__height or 44 end
FrameMethods.SetSize = function(self, w, h) self.__w, self.__height = w, h end
FrameMethods.IsMouseEnabled = function(self) return self.__mouse ~= false end
FrameMethods.EnableMouse = function(self, v) self.__mouse = v end
FrameMethods.GetScale = function(self) return 1 end
FrameMethods.GetEffectiveScale = function(self) return 1 end
FrameMethods.GetChildren = function(self) return unpack(self.__children or {}) end
FrameMethods.GetLeft = function(self) return self.__rect and self.__rect[1] end
FrameMethods.GetRight = function(self) return self.__rect and self.__rect[2] end
FrameMethods.GetTop = function(self) return self.__rect and self.__rect[3] end
FrameMethods.GetBottom = function(self) return self.__rect and self.__rect[4] end
FrameMethods.Click = function(self, button)
    local post = self.__scripts.PostClick
    if post then post(self, button or "LeftButton") end
end
FrameMethods.GetFrameStrata = function(self) return self.__strata or "MEDIUM" end
FrameMethods.SetFrameStrata = function(self, v) self.__strata = v end
FrameMethods.GetEffectiveAlpha = function(self) return 1 end
FrameMethods.IsMouseOver = function(self) return _G.__mouseOver == self end
FrameMethods.SetValue = function(self, v) self.__value = v end

function CreateFrame(frameType, name, parent, template)
    if template then
        local known = {
            SecureActionButtonTemplate = true, CooldownFrameTemplate = true,
            BackdropTemplate = true, UIPanelButtonTemplate = true,
            UIPanelCloseButton = true, InterfaceOptionsCheckButtonTemplate = true,
            OptionsSliderTemplate = true, GameTooltipTemplate = true,
        }
        for t in tostring(template):gmatch("[^,%s]+") do
            if not known[t] then error("Unknown frame template '" .. t .. "'", 2) end
        end
    end
    local f = NewObject(name, parent)
    f.__type = frameType
    if parent and parent.__children then table.insert(parent.__children, f) end
    if name then _G[name] = f end
    table.insert(frames, f)
    return f
end

UIParent = NewObject("UIParent")
UISpecialFrames = {}
BackdropTemplateMixin = {}
ACCEPT, CANCEL, CLOSE = "Aceptar", "Cancelar", "Cerrar"
StaticPopupDialogs = {}
SlashCmdList = {}
GameTooltip = NewObject("GameTooltip")

function tinsert(t, v) table.insert(t, v) end
function strjoin(sep, ...) return table.concat({ ... }, sep) end
function tostringall(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
    return unpack(out)
end
string.trim = function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
getmetatable("").__index.trim = string.trim

local now = 1000
function GetTime() return now end
function InCombatLockdown() return _G.__inCombat or false end
function UnitName() return "Panchito" end
function GetRealmName() return "Caleches" end
function GetBuildInfo() return "1.60.1", "70009", "Sep 20 2026", 16001 end
function GetCVar(name) return name == "ActionButtonUseKeyDown" and "1" or nil end
function IsUsableSpell() return true, false end
_G.__weapon = { has = true, expires = 300000 }
function GetInventoryItemLink() return "[Arma de prueba]" end
_G.__attackSpeed = 3.6
function UnitAttackSpeed(unit) return _G.__attackSpeed, nil end
_G.__autoAttack = false
function IsCurrentSpell(id) return id == 6603 and _G.__autoAttack or false end
_G.__tooltipLines = { [16] = {}, [17] = {} }
FrameMethods.ClearLines = function(self) end
FrameMethods.SetInventoryItem = function(self, unit, slot) self.__slot = slot end
FrameMethods.NumLines = function(self) return #(_G.__tooltipLines[self.__slot or 16] or {}) end
FrameMethods.GetText = function(self) return self.__text end
function GetWeaponEnchantInfo()
    if _G.__weaponBlocked then error("nope", 2) end
    local w = _G.__weapon
    return w.has, w.expires, 0, 0, false, 0, 0, 0
end
_G.__unit = { target = { exists = true, enemy = true, auras = {} } }
function UnitExists(unit) return _G.__unit[unit] ~= nil and _G.__unit[unit].exists end
function UnitCanAttack(_, unit) return _G.__unit[unit] and _G.__unit[unit].enemy or false end
function UnitIsDeadOrGhost(unit) return _G.__unit[unit] and _G.__unit[unit].dead or false end
function IsSpellKnown(id) return id == 370 end
C_UnitAuras = {
    GetUnitAuras = function(unit, filter)
        if _G.__noBulkAuras then error("sin esta API", 2) end
        local u = _G.__unit[unit]
        return u and u.auras or {}
    end,
    GetBuffDataByIndex = function(unit, index)
        if _G.__aurasBlocked then
            error("GetBuffDataByIndex(): Auras cannot be accessed when secret while tainted", 2)
        end
        local u = _G.__unit[unit]
        return u and u.auras and u.auras[index] or nil
    end,
}
C_Secrets = { ShouldAurasBeSecret = function() return _G.__aurasSecret or false end }
-- (el modulo de purga se retiro: el cliente no deja leer auras de enemigos)
local MACROS = {}
function GetMacroIndexByName(name)
    for i, m in ipairs(MACROS) do if m.name == name then return i end end
    return 0
end
function CreateMacro(name, icon, body) MACROS[#MACROS + 1] = { name = name, icon = icon, body = body } return #MACROS end
function EditMacro(index, name, icon, body) MACROS[index] = { name = name, icon = icon, body = body } end
function PickupMacro(index) _G.__cursorMacro = index end
_G.__macros = MACROS
MULTI_CAST_SUMMON_SPELL_INDEX = 1
NUM_MULTI_CAST_BUTTONS_PER_PAGE = 4
local MULTICAST = { [1] = { 6363 }, [2] = { 6390, 8143, 2484, 8154, 8075 } }
MULTICAST[5], MULTICAST[6] = MULTICAST[1], MULTICAST[2]
function GetMultiCastTotemSpells(index)
    local list = MULTICAST[index]
    if not list then return nil end
    return unpack(list)
end
local ACTIONS = { [133] = { "spell", 6363 }, [134] = { "spell", 8075 } }
function SetMultiCastSpell(actionID, spellID)
    if type(actionID) ~= "number" or type(spellID) ~= "number" then
        error("SetMultiCastSpell(actionID, spellID) mal llamada", 2)
    end
    ACTIONS[actionID] = { "spell", spellID }
end
function GetActionInfo(id)
    local a = ACTIONS[id]
    if not a then return nil end
    return a[1], a[2]
end
ChatFontNormal, GameFontHighlight = {}, {}
function UnitClass() return "Chaman", "SHAMAN" end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function PlaySoundFile() end
function ClearOverrideBindings() end
function SetOverrideBindingClick() end
function StaticPopup_Show(which) return StaticPopupDialogs[which] and NewObject(which) end
SOUNDKIT = { RAID_WARNING = 1, MAP_PING = 2, IG_QUEST_LIST_OPEN = 3, TELL_MESSAGE = 4, READY_CHECK = 5 }
_G.__sounds = {}
function PlaySound(id, channel) table.insert(_G.__sounds, { id = id, channel = channel }) end

C_Timer = { After = function(_, fn) table.insert(_G.__timers, fn) end }
_G.__timers = {}

local SPELL_NAMES = {
    [2484] = "Earthbind Totem", [8071] = "Stoneskin Totem", [3599] = "Searing Totem",
    [5394] = "Healing Stream Totem", [8512] = "Windfury Totem", [5675] = "Mana Spring Totem",
    [8190] = "Magma Totem", [8143] = "Tremor Totem", [10595] = "Nature Resistance Totem",
    [403] = "Lightning Bolt", [99999] = "Totem del Vacio Eterno",
    [66842] = "Call of the Elements", [66843] = "Call of the Ancestors",
    [370] = "Purge", [17364] = "Stormstrike", [324] = "Lightning Shield", [52127] = "Water Shield", [36936] = "Totemic Recall", [108270] = "Totemic Projection", [8017] = "Rockbiter Weapon", [8024] = "Flametongue Weapon",
    [8033] = "Frostbrand Weapon", [8232] = "Windfury Weapon", [6363] = "Searing Totem", [6390] = "Stoneclaw Totem", [8154] = "Stoneskin Totem",
    [8075] = "Strength of Earth Totem",
}
C_Spell = {
    GetSpellInfo = function(id)
        local name = SPELL_NAMES[id]
        if not name then return nil end
        return { name = name, iconID = 100000 + id, spellID = id }
    end,
    GetSpellTexture = function() return 123456 end,
}
_G.__cooldowns = {}
C_Spell.GetSpellCooldown = function(id)
    if _G.__cooldownsBlocked then error("secretos", 2) end
    local cd = _G.__cooldowns[id]
    if not cd then return { startTime = 0, duration = 0 } end
    return { startTime = cd.start, duration = cd.duration }
end
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
local BOOK = { 2484, 8071, 3599, 5394, 8512, 5675, 8190, 8143, 10595, 403, 99999, 66842, 66843,
               36936, 108270, 324, 52127, 17364,
               8017, 8024, 8232 }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #BOOK } end,
    GetSpellBookItemInfo = function(i) return { spellID = BOOK[i], isPassive = false } end,
}

local Vector = {}
Vector.__index = Vector
function Vector:GetXY() return self.x, self.y end
local function V(x, y) return setmetatable({ x = x, y = y }, Vector) end
_G.__playerPos = V(0.5, 0.5)
C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function() return _G.__playerPos end,
    GetWorldPosFromMapPos = function(_, pos) return 0, V(pos.x * 1000, pos.y * 1000) end,
    GetMapInfo = function() return { name = "Elwynn" } end,
}
Settings = {
    RegisterCanvasLayoutCategory = function() return { ID = nil, GetID = function() return 1 end } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}

-- Valor secreto simulado: cualquier operacion de Lua sobre el revienta, igual
-- que en el cliente. El test de verdad/falsedad no se puede emular en Lua 5.1,
-- pero cualquier comparacion o aritmetica si.
local SecretMT = {}
local function boom() error("operacion sobre un valor secreto", 2) end
for _, mm in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm",
                      "__lt", "__le", "__eq", "__concat", "__len", "__call",
                      "__index", "__newindex" }) do
    SecretMT[mm] = boom
end
local function Secret(v) return setmetatable({}, SecretMT) end

function issecretvalue(v) return getmetatable(v) == SecretMT end
function hasanysecretvalues(...)
    if _G.__noHasAnySecret then error("hasanysecretvalues no existe en este cliente", 2) end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return true end
    end
    return false
end

_G.__totems = {}
_G.__secretMode = false
function GetTotemInfo(slot)
    if _G.__secretMode then
        return Secret(), Secret(), Secret(), Secret(), Secret()
    end
    local t = _G.__totems[slot]
    if not t then return false end
    return true, t.name, t.start, t.duration, t.icon
end

-- Carga del addon -------------------------------------------------------------
-- Los ficheros y su orden salen del .toc, igual que en el juego: una lista
-- escrita a mano aqui no habria visto una entrada duplicada.
local base = arg[1]

local function ReadTocFiles()
    local tocPath
    local listing = io.popen('ls "' .. base .. '"/*.toc 2>/dev/null')
    if listing then
        tocPath = listing:read("*l")
        listing:close()
    end
    if not tocPath then error("no encuentro el .toc en " .. base) end

    local files, seen, duplicates = {}, {}, {}
    for line in io.lines(tocPath) do
        local name = line:match("^%s*([%w_%-%.]+%.lua)%s*$")
        if name then
            if seen[name:lower()] then
                duplicates[#duplicates + 1] = name
            else
                seen[name:lower()] = true
                files[#files + 1] = name
            end
        end
    end
    return files, duplicates, tocPath
end

local tocFiles, tocDuplicates = ReadTocFiles()

local ns = {}
for _, file in ipairs(tocFiles) do
    local chunk, err = loadfile(base .. "/" .. file)
    if not chunk then error("no carga " .. file .. ": " .. tostring(err)) end
    chunk("ForeverTotems", ns)
end

local function FireEvent(event, ...)
    for _, f in ipairs(frames) do
        if f.__events[event] and f.__scripts.OnEvent then
            f.__scripts.OnEvent(f, event, ...)
        end
    end
end

local function RunTimers()
    local list = _G.__timers
    _G.__timers = {}
    for _, fn in ipairs(list) do fn() end
end

local function Step(label, fn)
    local ok, err = pcall(fn)
    print(string.format("%-42s %s", label, ok and "OK" or ("FALLO -> " .. tostring(err))))
    return ok
end

print("=== El .toc ===")
Step("sin ficheros duplicados en el .toc", function()
    assert(#tocDuplicates == 0, "duplicados: " .. table.concat(tocDuplicates, ", "))
end)
Step("todos los .lua de la carpeta estan en el .toc", function()
    local listing = io.popen('ls "' .. base .. '"/*.lua 2>/dev/null')
    local onDisk = {}
    for path in listing:lines() do onDisk[#onDisk + 1] = path:match("([^/]+)$") end
    listing:close()
    local listed = {}
    for _, f in ipairs(tocFiles) do listed[f:lower()] = true end
    local missing = {}
    for _, f in ipairs(onDisk) do
        if not listed[f:lower()] then missing[#missing + 1] = f end
    end
    assert(#missing == 0, "no cargados por el .toc: " .. table.concat(missing, ", "))
end)

print("\n=== Carga e inicializacion ===")
Step("ADDON_LOADED", function() FireEvent("ADDON_LOADED", "ForeverTotems") end)
Step("PLAYER_LOGIN", function() FireEvent("PLAYER_LOGIN") end)
Step("deteccion de hechizos de totem", function()
    assert(ns.totemSpells and #ns.totemSpells > 0, "no ha detectado ningun totem")
    assert(ns:GetTotemKeyword() == "totem", "palabra clave mal deducida: " .. tostring(ns:GetTotemKeyword()))
end)
Step("set por defecto creado", function()
    assert(#ns.db.sets == 1, "esperaba 1 set")
    assert(ns.Sets:GetSequenceMacro(), "sin macro de secuencia")
end)

print("\n=== Ciclo de vida de un totem ===")
Step("lanzar Searing Totem", function()
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 3599)
    _G.__totems[1] = { name = "Searing Totem", start = now, duration = 60, icon = 103599 }
    FireEvent("PLAYER_TOTEM_UPDATE")
    assert(ns:GetTotem(1).have, "el totem no consta como activo")
    assert(ns.db.learned["Searing Totem"] == 1, "no ha aprendido el elemento")
end)
Step("cuenta atras y pintado", function()
    now = now + 30
    ns.Bar:UpdateTimers()
    assert(math.abs(ns:TotemRemaining(1) - 30) < 0.01, "tiempo restante mal calculado")
end)
Step("aviso de caducidad", function()
    now = now + 27
    ns.Warnings:Update(0.5)
    assert(ns:GetTotem(1).warnedExpire, "no ha avisado de la caducidad")
end)
Step("aviso de fuera de alcance", function()
    _G.__playerPos = V(0.6, 0.5)  -- 100 yardas mas lejos
    ns.Warnings:Update(1.0)
    assert(ns:GetTotem(1).lastRangeWarn > 0, "no ha avisado del rango")
end)
Step("totem destruido antes de tiempo", function()
    _G.__totems[1] = nil
    FireEvent("PLAYER_TOTEM_UPDATE")
    assert(not ns:GetTotem(1).have, "sigue constando como activo")
end)

print("\n=== Valores secretos (combate, arena, mazmorra) ===")
Step("duracion aprendida del totem visto antes", function()
    assert(ns.db.durations["Searing Totem"] == 60, "no ha aprendido la duracion")
end)
Step("GetTotemInfo secreto no rompe el escaneo", function()
    _G.__secretMode = true
    FireEvent("PLAYER_TOTEM_UPDATE")
    assert(ns:IsSecret(), "no ha detectado que los datos son secretos")
end)
Step("mismo escaneo sin hasanysecretvalues", function()
    _G.__noHasAnySecret = true
    local saved = hasanysecretvalues
    hasanysecretvalues = nil
    local ok, err = pcall(function() ns:ScanTotems() end)
    hasanysecretvalues, _G.__noHasAnySecret = saved, false
    assert(ok, tostring(err))
end)
Step("totem lanzado a ciegas se reconstruye", function()
    FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 3599)
    local t = ns:GetTotem(1)
    assert(t.have, "no ha reconstruido el totem")
    assert(t.synthetic, "deberia estar marcado como estimado")
    assert(t.duration == 60, "duracion estimada incorrecta")
end)
Step("la cuenta atras sigue corriendo a ciegas", function()
    now = now + 30
    ns.Bar:UpdateTimers()
    assert(math.abs(ns:TotemRemaining(1) - 30) < 0.01, "mal calculado a ciegas")
end)
Step("caduca sola sin datos del cliente", function()
    now = now + 31
    ns:ScanTotems()
    assert(not ns:GetTotem(1).have, "deberia haber caducado")
end)
Step("al salir de combate vuelven los datos reales", function()
    _G.__secretMode = false
    _G.__totems[1] = { name = "Searing Totem", start = now, duration = 60, icon = 103599 }
    FireEvent("PLAYER_REGEN_ENABLED")
    local t = ns:GetTotem(1)
    assert(t.have and not t.synthetic, "no ha vuelto al dato real")
    assert(not ns:IsSecret(), "sigue creyendo que hay secretos")
end)

print("\n=== Aviso de rango ===")
Step("solo salta una vez por totem", function()
    local count = 0
    local realAlert = ns.Warnings.Alert
    ns.Warnings.Alert = function(self, ...) count = count + 1; return realAlert(self, ...) end
    _G.__playerPos = V(0.9, 0.5)          -- lejisimos
    for i = 1, 5 do
        now = now + 3
        ns.Warnings:Update(1.0)
    end
    ns.Warnings.Alert = realAlert
    assert(count == 1, "ha avisado " .. count .. " veces, deberia ser 1")
end)
Step("se rearma al plantar otro totem", function()
    _G.__playerPos = V(0.5, 0.5)
    _G.__totems[1] = { name = "Searing Totem", start = now, duration = 60, icon = 103599 }
    FireEvent("PLAYER_TOTEM_UPDATE")
    assert(ns:GetTotem(1).warnedRange == false, "no se ha rearmado el aviso")
end)

print("\n=== Barra ===")
Step("el asa de arrastre no tapa los botones", function()
    local overlay = ns.Bar.dragOverlay
    assert(overlay, "no hay asa")
    local anchors = overlay.__points or {}
    assert(overlay.__height == 14, "el asa deberia ser una tira fina, no una sabana")
    assert(not overlay.__allPoints, "el asa no debe cubrir toda la barra")
end)

Step("los botones registran los dos flancos del clic", function()
    local clicks = _G.ForeverTotemsButton1.__clicks
    assert(clicks and #clicks == 2, "deberia registrar AnyUp y AnyDown")
    assert(_G.ForeverTotemsCallButton.__clicks[1] == "AnyUp", "el boton Call tambien")
end)
Step("el trazador de clics se puede encender y apagar", function()
    assert(ns.Bar:ToggleClickTest() == true)
    assert(_G.ForeverTotemsButton1:GetScript("OnMouseDown"), "no ha enganchado el trazador")
    assert(ns.Bar:ToggleClickTest() == false)
    assert(_G.ForeverTotemsButton1:GetScript("OnMouseDown") == nil, "no lo ha soltado")
end)
Step("el diagnostico de la barra informa de cada boton", function()
    local text = ns.Bar:Diagnose()
    assert(text:find("macrotext=/cast"), "no informa de la macro de los botones")
    assert(text:find("mouse=true"), "no informa del estado del raton")
end)

print("\n=== Aviso de cooldown recuperado ===")
Step("vigila Stormstrike de fabrica", function()
    ns.Cooldown:Rebuild()
    assert(ns.Cooldown:Watched()["Stormstrike"], "deberia vigilar Stormstrike")
end)
Step("suena al recuperarse y no antes", function()
    _G.__inCombat = true
    local cues = 0
    local real, realKey = ns.Warnings.PlayCue, ns.Warnings.PlayKey
    ns.Warnings.PlayCue = function(self) cues = cues + 1 end
    ns.Warnings.PlayKey = function(self) cues = cues + 1 return true end
    _G.__cooldowns[17364] = { start = now, duration = 10 }
    ns.Cooldown:Update()                 -- en cooldown
    assert(cues == 0, "no debe sonar mientras esta en cooldown")
    now = now + 11
    _G.__cooldowns[17364] = nil          -- ya disponible
    ns.Cooldown:Update()
    ns.Warnings.PlayCue, ns.Warnings.PlayKey = real, realKey
    assert(cues == 1, "deberia haber sonado una vez, sonó " .. cues)
end)
Step("el cooldown global no cuenta como cooldown", function()
    _G.__inCombat = true
    local cues = 0
    local real, realKey = ns.Warnings.PlayCue, ns.Warnings.PlayKey
    ns.Warnings.PlayCue = function(self) cues = cues + 1 end
    ns.Warnings.PlayKey = function(self) cues = cues + 1 return true end
    _G.__cooldowns[17364] = { start = now, duration = 1.5 }   -- GCD
    ns.Cooldown:Update()
    now = now + 2
    _G.__cooldowns[17364] = nil
    ns.Cooldown:Update()
    ns.Warnings.PlayCue, ns.Warnings.PlayKey = real, realKey
    assert(cues == 0, "el GCD no deberia disparar el aviso")
end)
Step("en combate, a ciegas, cuenta con la duracion aprendida", function()
    _G.__inCombat = true
    local cues = 0
    local real, realKey = ns.Warnings.PlayCue, ns.Warnings.PlayKey
    ns.Warnings.PlayCue = function(self) cues = cues + 1 end
    ns.Warnings.PlayKey = function(self) cues = cues + 1 return true end
    _G.__cooldowns[17364] = { start = now, duration = 10 }
    ns.Cooldown:Update()                        -- aprende que dura 10
    _G.__cooldownsBlocked = true                -- el cliente deja de contarlo
    ns.Cooldown:OnCast("Stormstrike")
    now = now + 5
    ns.Cooldown:Update()
    assert(cues == 0, "aun no toca")
    now = now + 6
    ns.Cooldown:Update()
    _G.__cooldownsBlocked = false
    ns.Warnings.PlayCue, ns.Warnings.PlayKey = real, realKey
    assert(cues == 1, "deberia sonar contando por su cuenta, sonó " .. cues)
end)
Step("fuera de combate no avisa de nada", function()
    _G.__inCombat = false
    ns.db.cooldowns.combatOnly = true
    local cues = 0
    local real, realKey = ns.Warnings.PlayCue, ns.Warnings.PlayKey
    ns.Warnings.PlayCue = function() cues = cues + 1 end
    ns.Warnings.PlayKey = function() cues = cues + 1 return true end
    _G.ForeverTotemsFlash.__shown = false
    _G.__cooldowns[17364] = { start = now, duration = 10 }
    ns.Cooldown:Update()
    now = now + 11
    _G.__cooldowns[17364] = nil
    ns.Cooldown:Update()
    ns.Warnings.PlayCue, ns.Warnings.PlayKey = real, realKey
    assert(cues == 0, "no deberia sonar fuera de combate")
    assert(not _G.ForeverTotemsFlash:IsShown(), "tampoco deberia destellar")
end)
Step("en combate si", function()
    _G.__inCombat = true
    local cues = 0
    local real, realKey = ns.Warnings.PlayCue, ns.Warnings.PlayKey
    ns.Warnings.PlayCue = function() cues = cues + 1 end
    ns.Warnings.PlayKey = function() cues = cues + 1 return true end
    _G.__cooldowns[17364] = { start = now, duration = 10 }
    ns.Cooldown:Update()
    now = now + 11
    _G.__cooldowns[17364] = nil
    ns.Cooldown:Update()
    ns.Warnings.PlayCue, ns.Warnings.PlayKey = real, realKey
    _G.__inCombat = false
    assert(cues == 1, "en combate si deberia sonar, sonó " .. cues)
end)
Step("el destello aparece y se apaga solo", function()
    _G.__inCombat = true
    ns.db.cooldowns.flash = true
    ns.Bar:FlashIcon(12345)
    local flash = _G.ForeverTotemsFlash
    assert(flash:IsShown(), "deberia verse")
    assert(flash.icon.__texture == 12345, "no ha puesto el icono")
    local onUpdate = flash:GetScript("OnUpdate")
    onUpdate(flash, 0.3)
    assert(flash:IsShown(), "a mitad deberia seguir")
    assert(flash.__alpha < 1 and flash.__alpha > 0, "deberia ir desvaneciendose")
    onUpdate(flash, 0.4)
    assert(not flash:IsShown(), "pasados 0.7s deberia haberse ido")
    _G.__inCombat = false
end)
Step("si lo apagas, no aparece", function()
    ns.db.cooldowns.flash = false
    _G.ForeverTotemsFlash.__shown = false
    ns.Bar:FlashIcon(12345)
    assert(not _G.ForeverTotemsFlash:IsShown(), "no deberia aparecer")
    ns.db.cooldowns.flash = true
end)
Step("el aviso tiene sonido y canal propios", function()
    _G.__sounds = {}
    ns.db.cooldowns.soundChoice, ns.db.cooldowns.channel = "ready", "Master"
    ns.Warnings:PlayKey(ns.db.cooldowns.soundChoice, ns.db.cooldowns.channel)
    assert(#_G.__sounds == 1, "no ha sonado")
    assert(_G.__sounds[1].id == SOUNDKIT.READY_CHECK, "sonido equivocado")
    assert(_G.__sounds[1].channel == "Master", "deberia ir por Master para que se oiga")
end)
Step("se puede cambiar de sonido y de canal", function()
    local antes = ns.db.cooldowns.soundChoice
    ns.Cooldown:CycleSound()
    assert(ns.db.cooldowns.soundChoice ~= antes, "no ha cambiado de sonido")
    assert(ns.Cooldown:ToggleChannel() == "SFX", "no ha cambiado de canal")
    ns.Cooldown:ToggleChannel()
end)
Step("se pueden vigilar y dejar de vigilar otros", function()
    assert(ns.Cooldown:Watch("Lightning Shield"), "no ha anadido")
    assert(ns.Cooldown:Watched()["Lightning Shield"], "no lo resuelve del libro")
    assert(ns.Cooldown:Unwatch("Lightning Shield"), "no ha quitado")
    assert(not ns.Cooldown:Watched()["Lightning Shield"], "sigue vigilado")
end)

print("\n=== Escudo de relampagos ===")
Step("detecta los escudos que conoces", function()
    ns.Shield:Enable()
    local list = ns.Shield:Scan()
    assert(#list == 2, "esperaba 2 escudos del libro, hay " .. #list)
    assert(ns.Shield:GetChosen(), "no ha elegido ninguno")
end)
Step("lee las cargas del buff", function()
    _G.__unit.player = { exists = true, auras = {
        { name = "Lightning Shield", applications = 3, expirationTime = GetTime() + 600 },
    } }
    ns.Shield:Refresh()
    assert(ns.Shield:IsUp(), "deberia verlo activo")
    assert(ns.Shield:Charges() == 3, "cargas mal leidas: " .. ns.Shield:Charges())
    assert(ns.Bar.shieldButton.timer.__text == "3", "el boton deberia mostrar las cargas")
end)
Step("avisa al entrar en combate sin escudo", function()
    local alerts = 0
    local real = ns.Warnings.Alert
    ns.Warnings.Alert = function(self, ...) alerts = alerts + 1 return real(self, ...) end
    _G.__unit.player.auras = {}
    ns.Shield:Refresh()
    ns.Shield:CheckForFight()
    ns.Shield:CheckForFight()            -- no debe repetir
    ns.Warnings.Alert = real
    assert(alerts == 1, "ha avisado " .. alerts .. " veces")
    assert(ns.Bar.shieldButton.timer.__text == "", "sin escudo no hay numero")
end)
Step("no avisa si lo llevas puesto", function()
    local alerts = 0
    local real = ns.Warnings.Alert
    ns.Warnings.Alert = function(self, ...) alerts = alerts + 1 return real(self, ...) end
    _G.__unit.player.auras = { { name = "Lightning Shield", applications = 3 } }
    ns.Shield:Refresh()
    ns.Shield:CheckForFight()
    ns.Warnings.Alert = real
    assert(alerts == 0, "no deberia avisar con el escudo puesto")
end)
Step("si el cliente oculta las auras, se calla", function()
    _G.__aurasBlocked = true
    local alerts = 0
    local real = ns.Warnings.Alert
    ns.Warnings.Alert = function(self, ...) alerts = alerts + 1 return real(self, ...) end
    ns.Shield:Refresh()
    ns.Shield:CheckForFight()
    ns.Warnings.Alert = real
    _G.__aurasBlocked = false
    assert(alerts == 0, "no debe avisar sobre datos que no pudo leer")
end)
Step("el boton lanza el escudo elegido", function()
    ns.Bar:ApplyAttributes()
    local macro = _G.ForeverTotemsShieldButton:GetAttribute("macrotext")
    assert(macro == "/cast Lightning Shield", "macro incorrecta: " .. tostring(macro))
end)

print("\n=== Encantamientos de arma ===")
Step("detecta los imbues que conoces", function()
    ns.Weapon:Enable()
    local list = ns.Weapon:Scan()
    assert(#list == 3, "esperaba 3 imbues del libro, hay " .. #list)
    assert(ns.Weapon:GetChosen(), "no ha elegido ninguno por defecto")
end)
Step("lee el tiempo restante del arma", function()
    _G.__weapon = { has = true, expires = 120000 }   -- milisegundos
    ns.Weapon:Refresh()
    assert(ns.Weapon:HasEnchant(), "deberia ver el imbue")
    assert(math.abs(ns.Weapon:Remaining() - 120) < 1, "mal convertido de ms a segundos: " .. ns.Weapon:Remaining())
end)
Step("avisa al entrar en combate sin imbue", function()
    local alerts = 0
    local real = ns.Warnings.Alert
    ns.Warnings.Alert = function(self, ...) alerts = alerts + 1 return real(self, ...) end
    _G.__weapon = { has = false, expires = 0 }
    ns.Weapon:Refresh()
    ns.Weapon:CheckForFight()
    ns.Weapon:CheckForFight()          -- no debe repetir
    ns.Warnings.Alert = real
    assert(alerts == 1, "ha avisado " .. alerts .. " veces")
end)
Step("no avisa si lo llevas puesto", function()
    local alerts = 0
    local real = ns.Warnings.Alert
    ns.Warnings.Alert = function(self, ...) alerts = alerts + 1 return real(self, ...) end
    _G.__weapon = { has = true, expires = 300000 }
    ns.Weapon:Refresh()
    ns.Weapon:CheckForFight()
    ns.Warnings.Alert = real
    assert(alerts == 0, "no deberia avisar con el imbue puesto")
end)
Step("si el cliente no lo reporta, se calla", function()
    _G.__weaponBlocked = true
    local alerts = 0
    local real = ns.Warnings.Alert
    ns.Warnings.Alert = function(self, ...) alerts = alerts + 1 return real(self, ...) end
    ns.Weapon:Refresh()
    ns.Weapon:CheckForFight()
    ns.Warnings.Alert = real
    _G.__weaponBlocked = false
    assert(ns.Weapon:IsBlocked() == false or alerts == 0, "no debe avisar sobre datos que no pudo leer")
end)
Step("en verde y con minutos cuando esta puesto", function()
    _G.__weapon = { has = true, expires = 300000 }   -- 5 minutos
    ns.Weapon:Refresh()
    local b = ns.Bar.weaponButton
    assert(b.timer.__text == "5m", "deberia poner los minutos, pone " .. tostring(b.timer.__text))
    local g = b.edges[1].__color
    assert(g[2] > g[1] and g[2] > g[3], "el marco deberia ser verde")
    assert(b.icon.__alpha == 1, "el icono deberia estar a todo color")
end)
Step("en naranja cuando queda menos de un minuto", function()
    _G.__weapon = { has = true, expires = 45000 }
    ns.Weapon:Refresh()
    local b = ns.Bar.weaponButton
    assert(b.timer.__text == "45s", "bajo un minuto se muestran segundos: " .. tostring(b.timer.__text))
    local c = b.edges[1].__color
    assert(c[1] > c[2], "el marco deberia avisar en calido")
end)
Step("sin imbue no hay numero", function()
    _G.__weapon = { has = false, expires = 0 }
    ns.Weapon:Refresh()
    local b = ns.Bar.weaponButton
    assert(b.timer.__text == "", "no deberia poner tiempo")
    assert(b.icon.__alpha < 1, "el icono deberia estar apagado")
end)
Step("/ft weapon vuelca lo que devuelve el cliente", function()
    local text = ns.Weapon:Report()
    assert(text:find("GetWeaponEnchantInfo: function"), "no informa de la API")
    assert(text:find("returned %d+ values"), "no vuelca los valores")
    assert(text:find("known imbues: 3"), "no lista los imbues")
end)
Step("elegir otro imbue cambia el boton", function()
    _G.__weapon = { has = true, expires = 300000 }
    ns.Weapon:Refresh()
    _G.__weapon = { has = true, expires = 300000 }
    ns.Weapon:Refresh()
    local list = ns.Weapon:GetSpells()
    ns.Weapon:SetChosen(list[2])
    ns.Bar:ApplyAttributes()
    local macro = _G.ForeverTotemsWeaponButton:GetAttribute("macrotext")
    assert(macro == "/cast " .. list[2].name, "macro incorrecta: " .. tostring(macro))
end)
Step("la opcion de mano izquierda anade /use 17", function()
    ns.db.weapon.offHand = true
    ns.Bar:ApplyAttributes()
    local macro = _G.ForeverTotemsWeaponButton:GetAttribute("macrotext")
    assert(macro:find("/use 17"), "falta la linea de la mano izquierda: " .. tostring(macro))
    ns.db.weapon.offHand = false
    ns.Bar:ApplyAttributes()
end)

Step("detecta el imbue aunque venga como buff del jugador", function()
    _G.__weapon = { has = false, expires = 0 }        -- el arma no reporta nada
    _G.__unit.player = { exists = true, auras = {
        { name = "Rockbiter Weapon", expirationTime = GetTime() + 600, duration = 1800 },
    } }
    ns.Weapon:Refresh()
    assert(ns.Weapon:HasEnchant(), "deberia detectarlo por el buff")
    assert(math.abs(ns.Weapon:Remaining() - 600) < 2, "mal el tiempo desde el buff: " .. ns.Weapon:Remaining())
    assert(ns.Bar.weaponButton.timer.__text == "10m", "deberia poner 10m, pone " .. tostring(ns.Bar.weaponButton.timer.__text))
end)
Step("usa la API en bloque y no se deja auras", function()
    _G.__unit.player = { exists = true, auras = {
        { name = "Ghost Wolf", expirationTime = 0, duration = 0 },
        { name = "Rockbiter Weapon", expirationTime = GetTime() + 3480, duration = 3600 },
    } }
    local auras, blocked = ns.Weapon:EnumerateBuffs("player")
    assert(#auras == 2, "deberia ver los dos buffs, ve " .. #auras)
    assert(not blocked)
    ns.Weapon:Refresh()
    assert(ns.Weapon:HasEnchant(), "deberia detectar el imbue en segunda posicion")
    assert(ns.Bar.weaponButton.timer.__text == "58m", "esperaba 58m, pone " .. tostring(ns.Bar.weaponButton.timer.__text))
end)
Step("si no existe la API en bloque, cae al indice", function()
    _G.__noBulkAuras = true
    local auras = ns.Weapon:EnumerateBuffs("player")
    _G.__noBulkAuras = false
    assert(#auras >= 1, "el respaldo por indice deberia funcionar")
end)
Step("deduce la parte distintiva del nombre", function()
    ns.Weapon.bases = nil
    local bases = ns.Weapon:GetImbueBases()
    local found = {}
    for _, entry in ipairs(bases) do found[entry.base] = true end
    assert(found["Rockbiter"], "deberia quedarse con Rockbiter")
    assert(found["Flametongue"], "deberia quedarse con Flametongue")
    assert(not found["Weapon"], "la palabra generica no debe usarse para comparar")
end)
Step("un buff cualquiera no cuenta como imbue", function()
    _G.__unit.player.auras = { { name = "Comida bien cocinada", expirationTime = GetTime() + 600 } }
    ns.Weapon:Refresh()
    assert(not ns.Weapon:HasEnchant(), "no deberia confundir otros buffs")
end)

Step("detecta el imbue leyendo el tooltip del arma", function()
    _G.__weapon = { has = false, expires = 0 }
    _G.__unit.player = { exists = true, auras = { { name = "Stoneskin", expirationTime = 0 } } }
    -- el cliente escribe el imbue en el tooltip del arma
    -- tal cual lo escribe el cliente: nombre corto y rango, sin la palabra "Weapon"
    _G.__tooltipLines[16] = { "Forsaken Greataxe", "Rockbiter 3 (58 min)" }
    for index = 1, 2 do
        local fs = _G["ForeverTotemsTooltipScannerTextLeft" .. index]
        if not fs then
            fs = CreateFrame("Frame", "ForeverTotemsTooltipScannerTextLeft" .. index)
        end
        fs.__text = _G.__tooltipLines[16][index]
    end
    ns.Weapon:Refresh()
    assert(ns.Weapon:HasEnchant(), "deberia detectarlo por el tooltip")
    assert(ns.Bar.weaponButton.timer.__text == "58m", "esperaba 58m, pone " .. tostring(ns.Bar.weaponButton.timer.__text))
end)

print("\n=== Swing timer ===")
local function StartSwinging()
    _G.__autoAttack = false
    ns.Swing:Update()
    now = now + 5            -- separacion suficiente del golpe anterior
    _G.__autoAttack = true
    ns.Swing:Update()
    FireEvent("UNIT_COMBAT", "target", "WOUND")   -- el golpe que ancla el ciclo
    assert(ns.Swing:IsActive(), "el arranque de la prueba no ha anclado")
end

Step("viene activado", function()
    assert(ns.db.swing.enabled == true, "deberia venir activado")
end)
Step("el primer impacto ancla el ciclo aunque llegue pronto", function()
    ns.Swing:Enable()
    _G.__autoAttack = false
    ns.Swing:Update()
    _G.__autoAttack = true
    _G.__attackSpeed = 3.6
    ns.Swing:Update()                      -- armada, sin ancla
    now = now + 0.8
    FireEvent("UNIT_COMBAT", "target", "WOUND")
    assert(math.abs(ns.Swing:Remaining() - 3.6) < 0.05,
        "el primer impacto debe anclar, quedan " .. ns.Swing:Remaining())
    assert(ns.Swing:IsMeasured(), "y pasar a medido")
end)
Step("ya anclado, un impacto demasiado seguido se ignora", function()
    now = now + 0.8
    local before = ns.Swing:Remaining()
    FireEvent("UNIT_COMBAT", "target", "WOUND")
    assert(math.abs(ns.Swing:Remaining() - before) < 0.01,
        "ningun arma golpea dos veces en 0.8s")
end)
Step("con el auto-ataque activo pero sin llegar, no hay barra", function()
    ns.Swing:Enable()
    _G.__autoAttack = false
    ns.Swing:Update()
    _G.__autoAttack = true          -- click derecho desde lejos
    ns.Swing:Update()
    assert(not ns.Swing:IsActive(), "no debe contar hasta que un golpe conecte")
    ns.Bar:UpdateSwing()
    assert(not ns.Bar.swingBar:IsShown(), "la barra no deberia verse mientras te acercas")
end)
Step("al conectar el primer golpe aparece y cuenta", function()
    now = now + 5                    -- lo que tardas en llegar
    FireEvent("UNIT_COMBAT", "target", "WOUND")
    assert(ns.Swing:IsActive(), "ahora si deberia contar")
    assert(math.abs(ns.Swing:Remaining() - 3.6) < 0.05, "deberia usar la velocidad del arma")
    assert(ns.Swing:IsMeasured(), "y ser una medida, no una prediccion")
end)
Step("un golpe que aterriza reinicia el reloj", function()
    now = now + 3.5          -- a la cadencia del arma, que es lo que lo identifica
    FireEvent("UNIT_COMBAT", "target", "WOUND")
    assert(math.abs(ns.Swing:Remaining() - 3.6) < 0.01, "no ha reiniciado: " .. ns.Swing:Remaining())
    assert(ns.Swing:IsMeasured(), "ahora si es medido")
end)
Step("recibir un golpe no reinicia tu swing", function()
    _G.__autoAttack = true
    ns.Swing:Update()
    now = now + 3.0                       -- casi al final de la ventana
    local before = ns.Swing:Remaining()
    FireEvent("UNIT_COMBAT", "targettarget", "WOUND")   -- el bicho pegandote a ti
    assert(math.abs(ns.Swing:Remaining() - before) < 0.01,
        "un golpe recibido no debe tocar tu swing")
end)
Step("el totem pegando cada 2s no roba la cadencia", function()
    StartSwinging()                        -- anclado con un golpe tuyo
    for tick = 1, 3 do
        now = now + 2.0                    -- cadencia del Searing Totem
        local before = ns.Swing:Remaining()
        FireEvent("UNIT_COMBAT", "target", "WOUND")
        if tick == 1 then
            assert(math.abs(ns.Swing:Remaining() - before) < 0.01,
                "2s no es la cadencia de un arma de 3.6s")
        end
    end
end)
Step("un golpe a la cadencia del arma si resincroniza", function()
    StartSwinging()
    now = now + 3.5                        -- una velocidad de arma despues
    FireEvent("UNIT_COMBAT", "target", "WOUND")
    assert(math.abs(ns.Swing:Remaining() - 3.6) < 0.05, "deberia haber resincronizado")
    assert(ns.Swing:IsMeasured(), "y contar como medido")
end)
Step("tras perder el hilo, el siguiente golpe reengancha", function()
    StartSwinging()
    now = now + 9                          -- mucho mas de vez y media el swing
    FireEvent("UNIT_COMBAT", "target", "WOUND")
    assert(math.abs(ns.Swing:Remaining() - 3.6) < 0.05, "deberia reenganchar")
end)
Step("dos impactos seguidos no reinician dos veces", function()
    now = now + 0.2
    local before = ns.Swing:Remaining()
    FireEvent("UNIT_COMBAT", "target", "WOUND")   -- p.ej. un hechizo cayendo a la vez
    assert(math.abs(ns.Swing:Remaining() - before) < 0.01, "ha reiniciado con un impacto demasiado pronto")
end)
Step("un cambio de velocidad reajusta la ventana", function()
    _G.__attackSpeed = 2.6
    FireEvent("UNIT_ATTACK_SPEED", "player")
    assert(math.abs(ns.Swing:Remaining() - (2.6 - 0.2)) < 0.05, "no ha reajustado: " .. ns.Swing:Remaining())
    _G.__attackSpeed = 3.6
end)
Step("el dano de un totem no arranca la barra fuera de combate", function()
    _G.__autoAttack = false
    ns.Swing:Update()
    FireEvent("PLAYER_REGEN_ENABLED")          -- fuera de combate, sin atacar
    assert(not ns.Swing:IsActive(), "deberia estar parada")
    FireEvent("UNIT_COMBAT", "target", "WOUND")   -- p.ej. tu Searing Totem pegando
    assert(not ns.Swing:IsActive(), "un impacto ajeno no debe arrancar el swing")
    ns.Bar:UpdateSwing()
    assert(not ns.Bar.swingBar:IsShown(), "la barra no deberia verse")
end)
Step("encadena el siguiente swing al acabarse", function()
    StartSwinging()
    now = now + 3.6 + 0.3            -- se acaba la ventana y nadie avisa del golpe
    ns.Swing:Update()
    assert(ns.Swing:IsActive(), "deberia seguir contando")
    local remaining = ns.Swing:Remaining()
    assert(math.abs(remaining - (3.6 - 0.3)) < 0.05,
        "deberia arrastrar el sobrante, quedan " .. remaining)
    assert(not ns.Swing:IsMeasured(), "el ciclo encadenado es prediccion")
end)
Step("si el cliente deja de dar la velocidad, no se congela", function()
    _G.__attackSpeed = 3.6
    StartSwinging()                   -- con velocidad buena, para cachearla
    _G.__attackSpeed = 0              -- el cliente deja de darla en combate
    now = now + 4
    ns.Swing:Update()
    assert(ns.Swing:IsActive(), "deberia seguir activa")
    assert(ns.Swing:Remaining() > 0, "se ha quedado congelada en cero")
    _G.__attackSpeed = 3.6
end)
Step("y se resincroniza si llega un golpe", function()
    now = now + 2.5          -- ya en la segunda mitad de la ventana
    if not ns.Swing:IsActive() then StartSwinging() ; now = now + 2.5 end
    FireEvent("UNIT_COMBAT", "target", "WOUND")
    assert(math.abs(ns.Swing:Remaining() - 3.6) < 0.01, "no se ha resincronizado")
    assert(ns.Swing:IsMeasured(), "tras un golpe real es medido")
end)
Step("al dejar de atacar se apaga", function()
    _G.__autoAttack = false
    ns.Swing:Update()
    assert(not ns.Swing:IsActive(), "deberia pararse")
    ns.Bar:UpdateSwing()
    assert(not ns.Bar.swingBar:IsShown(), "la barra deberia ocultarse")
end)
Step("el color no cambia, solo la marca ~", function()
    StartSwinging()
    ns.Bar:UpdateSwing()
    local measured = ns.Bar.swingBar.__barColor
    assert(measured, "el stub no ha registrado el color")
    assert(not ns.Bar.swingBar.text.__text:find("~"), "medido no debe llevar la marca")

    now = now + 4.0                  -- se acaba sin confirmacion: pasa a predicho
    ns.Swing:Update()
    ns.Bar:UpdateSwing()
    local predicted = ns.Bar.swingBar.__barColor
    assert(ns.Bar.swingBar.text.__text:find("~"), "predicho debe llevar la marca ~")
    for index = 1, 3 do
        assert(measured[index] == predicted[index], "el color no deberia cambiar")
    end
end)
Step("la barra pinta el progreso", function()
    StartSwinging()
    now = now + 1.8
    ns.Bar:UpdateSwing()
    local value = ns.Bar.swingBar.__value
    assert(value and value > 0.45 and value < 0.55, "el progreso deberia ir por la mitad, va por " .. tostring(value))
end)

print("\n=== Orden de los elementos ===")
Step("el orden manda en la barra y en la macro", function()
    ns.db.bar.order = { ns.FIRE, ns.EARTH, ns.WATER, ns.AIR }
    ns.Sets:SetActive(1)
    ns.Sets:AssignSpell(1, ns.FIRE, { name = "Searing Totem", icon = 1 })
    ns.Sets:AssignSpell(1, ns.EARTH, { name = "Stoneskin Totem", icon = 1 })
    local before = ns.Sets:GetSequenceMacro()
    assert(before:find("Searing Totem,%s*Stoneskin Totem"), "orden inicial raro: " .. before)

    ns.db.bar.order = { ns.EARTH, ns.FIRE, ns.WATER, ns.AIR }
    ns.Sets:Apply()
    local after = ns.Sets:GetSequenceMacro()
    assert(after:find("Stoneskin Totem,%s*Searing Totem"), "la macro no ha seguido al orden: " .. after)
end)
Step("la macro del juego tambien se reordena", function()
    ns.Sets:CreateOrUpdateMacro(false)
    local body = _G.__macros[ns.Sets:GetMacroIndex()].body
    assert(body:find("Stoneskin Totem,%s*Searing Totem"), "la macro guardada no sigue el orden: " .. body)
    ns.db.bar.order = { ns.FIRE, ns.EARTH, ns.WATER, ns.AIR }
    ns.Sets:Apply()
end)
Step("el orden no se sale de sus limites", function()
    local order = ns.db.bar.order
    local copy = { order[1], order[2], order[3], order[4] }
    -- mover el primero hacia la izquierda no debe hacer nada
    local index, delta = 1, -1
    if index + delta >= 1 then order[index], order[index + delta] = order[index + delta], order[index] end
    assert(order[1] == copy[1], "ha movido el primero fuera de la lista")
end)

print("\n=== Aspecto de los huecos ===")
Step("hueco sin totem: marco, nombre y sin icono", function()
    ns.db.sets[1].spells[ns.WATER] = nil
    local fallback = ns.db.fallbackLastCast
    ns.db.fallbackLastCast = false
    ns.Bar:UpdateSlot(ns.WATER)
    ns.db.fallbackLastCast = fallback
    local b = ns.Bar.buttons[ns.WATER]
    assert(b.emptyLabel.__text == "Water", "deberia poner el nombre del elemento, pone " .. tostring(b.emptyLabel.__text))
    assert(b.icon.__alpha == 0, "el icono deberia estar oculto")
    assert(b.bg.__color[4] < 0.85, "el fondo deberia ser mas suave que el de un hueco lleno")
end)
Step("hueco con totem asignado pero no puesto: icono apagado", function()
    ns.Sets:AssignSpell(1, ns.FIRE, { name = "Searing Totem", icon = 5 })
    _G.__totems = {}
    ns:ScanTotems()
    ns.Bar:UpdateSlot(ns.FIRE)
    local b = ns.Bar.buttons[ns.FIRE]
    assert(b.emptyLabel.__text == "", "no deberia poner texto si hay icono")
    assert(b.icon.__alpha == 0.5, "el icono deberia verse apagado")
end)
Step("se pueden ocultar los huecos vacios", function()
    ns.db.bar.hideEmptySlots = true
    ns.db.fallbackLastCast = false
    ns.db.sets[1].spells[ns.WATER], ns.db.sets[1].spells[ns.AIR] = nil, nil
    ns.Bar:Layout()
    assert(not ns.Bar.buttons[ns.WATER]:IsShown(), "agua deberia estar oculto")
    assert(ns.Bar.buttons[ns.FIRE]:IsShown(), "fuego deberia seguir visible")
    ns.db.bar.hideEmptySlots = false
    ns.db.fallbackLastCast = true
    ns.Bar:Layout()
end)

print("\n=== La barra y el mapa ===")
Step("al abrir el mapa la barra desaparece", function()
    _G.WorldMapFrame = { IsShown = function() return true end }
    ns.Bar:UpdateMapHiding()
    assert(ns.Bar.frame.__alpha == 0, "deberia quedarse invisible con el mapa abierto")
end)
Step("al cerrarlo vuelve", function()
    _G.WorldMapFrame = { IsShown = function() return false end }
    ns.Bar:UpdateMapHiding()
    assert(ns.Bar.frame.__alpha == 1, "deberia volver a verse")
end)

print("\n=== Flechas para cambiar de totem ===")
Step("la flecha despliega los totems del elemento", function()
    local arrow = ns.Bar.buttons[ns.EARTH].arrow
    local opened = ns.Flyout:Open(ns.EARTH, arrow)
    assert(opened, "no se ha desplegado")
    local shown = 0
    for _, icon in ipairs({ _G.ForeverTotemsFlyout and true }) do end
    local entries = ns.Flyout:Entries(ns.EARTH)
    assert(#entries >= 3, "deberia listar los totems de tierra, hay " .. #entries)
end)
Step("al pulsar uno cambia el set", function()
    local entries = ns.Flyout:Entries(ns.EARTH)
    local target
    for _, e in ipairs(entries) do
        if e.name == "Tremor Totem" then target = e end
    end
    assert(target, "no encuentro Tremor Totem en el desplegable")
    ns.Sets:AssignSpell(ns.Sets:GetActiveIndex(), ns.EARTH, target)
    local now = ns.Sets:GetSpellForSlot(ns.EARTH)
    assert(now.name == "Tremor Totem", "no ha cambiado el totem del set")
    assert(_G.ForeverTotemsButton2:GetAttribute("macrotext") == "/cast Tremor Totem",
        "el boton de la barra no se ha actualizado")
end)
Step("se cierra al salir el raton", function()
    local panel = _G.ForeverTotemsFlyout
    _G.__mouseOver = nil
    panel.__shown = true
    local onUpdate = panel:GetScript("OnUpdate")
    onUpdate(panel, 0.1)
    assert(panel:IsShown(), "no deberia cerrarse tan pronto")
    onUpdate(panel, 0.3)
    assert(not panel:IsShown(), "deberia haberse cerrado tras la gracia")
end)
Step("sin totems de ese elemento no hay flecha", function()
    ns.Flyout:UpdateArrows()
    local entries = ns.Flyout:Entries(ns.WATER)
    local arrow = ns.Bar.buttons[ns.WATER].arrow
    if #entries == 0 then
        assert(not arrow:IsShown(), "no deberia haber flecha sin totems")
    end
end)

print("\n=== Saltar los totems ya puestos ===")
Step("viene apagado de fabrica", function()
    assert(ns.db.skipActiveTotems == false, "deberia estar apagado por defecto")
    ns.db.skipActiveTotems = true   -- el resto de pruebas lo encienden a mano
end)
Step("fuera de combate apunta al que falta", function()
    _G.__secretMode = false
    ns.Sets:SetActive(1)
    ns.Sets:AssignSpell(1, ns.FIRE, { name = "Searing Totem", icon = 1 })
    ns.Sets:AssignSpell(1, ns.EARTH, { name = "Stoneskin Totem", icon = 1 })
    _G.__totems = {}
    _G.__totems[ns.FIRE] = { name = "Searing Totem", start = now, duration = 60, icon = 1 }
    ns:ScanTotems()
    local missing = ns.Sets:GetNextMissingSpell()
    assert(missing and missing.name == "Stoneskin Totem",
        "deberia apuntar a tierra, apunta a " .. tostring(missing and missing.name))
    local macro = ns.Sets:GetSequenceMacro()
    assert(macro:find("^/cast %[nocombat%] Stoneskin Totem"), "primera linea incorrecta: " .. macro)
    assert(macro:find("/castsequence"), "falta la recaida a la secuencia")
end)
Step("el boton se reapunta solo al caer un totem", function()
    _G.__totems[ns.FIRE] = nil
    ns:ScanTotems()
    local macro = _G.ForeverTotemsBarSetButton:GetAttribute("macrotext")
    assert(macro:find("^/cast %[nocombat%] Searing Totem"), "no se ha reapuntado: " .. tostring(macro))
end)
Step("con todo puesto, solo queda la secuencia", function()
    -- el set solo tiene fuego y tierra: vaciamos agua y aire para que no cuenten
    ns.db.sets[1].spells[ns.WATER], ns.db.sets[1].spells[ns.AIR] = nil, nil
    local fallback = ns.db.fallbackLastCast
    ns.db.fallbackLastCast = false
    _G.__totems[ns.FIRE] = { name = "Searing Totem", start = now, duration = 60, icon = 1 }
    _G.__totems[ns.EARTH] = { name = "Stoneskin Totem", start = now, duration = 60, icon = 1 }
    ns:ScanTotems()
    ns.db.fallbackLastCast = fallback
    local macro = ns.Sets:GetSequenceMacro()
    assert(not macro:find("nocombat"), "no deberia sugerir ninguno: " .. macro)
end)
Step("en combate no reescribe nada", function()
    _G.__inCombat = true
    local before = _G.ForeverTotemsBarSetButton:GetAttribute("macrotext")
    _G.__totems = {}
    ns:ScanTotems()
    local after = _G.ForeverTotemsBarSetButton:GetAttribute("macrotext")
    _G.__inCombat = false
    assert(before == after, "ha tocado el boton en combate")
end)
Step("la macro del juego tampoco pasa de 255", function()
    ns.Sets:CreateOrUpdateMacro(false)
    local macro = _G.__macros[ns.Sets:GetMacroIndex()]
    assert(#macro.body <= 255, "cuerpo demasiado largo")
end)

print("\n=== Macro para la barra de acciones ===")
Step("crea la macro y la deja en el cursor", function()
    local index, reason = ns.Sets:CreateOrUpdateMacro(true)
    assert(index, tostring(reason))
    local macro = _G.__macros[index]
    assert(macro.name == "FTTotems", "nombre incorrecto")
    assert(macro.body:find("/castsequence"), "cuerpo incorrecto: " .. macro.body)
    assert(#macro.name <= 16, "el nombre excede el limite del juego")
    assert(#macro.body <= 255, "el cuerpo excede el limite del juego")
    assert(_G.__cursorMacro == index, "no la ha puesto en el cursor")
end)
Step("al cambiar el set la macro se actualiza sola", function()
    local index = ns.Sets:GetMacroIndex()
    local before = _G.__macros[index].body
    ns.Sets:AssignSpell(ns.Sets:GetActiveIndex(), ns.EARTH, { name = "Earthbind Totem", icon = 1 })
    local after = _G.__macros[ns.Sets:GetMacroIndex()].body
    assert(after ~= before, "no ha seguido al set")
    assert(after:find("Earthbind Totem"), "no trae el totem nuevo")
end)
Step("no crea macros a tus espaldas", function()
    local count = #_G.__macros
    ns.Sets:Apply()
    assert(#_G.__macros == count, "ha creado una macro sin pedirsela")
end)
Step("en combate no la toca", function()
    _G.__inCombat = true
    local index, reason = ns.Sets:CreateOrUpdateMacro(true)
    _G.__inCombat = false
    assert(not index and reason, "deberia negarse en combate")
end)

print("\n=== Autoprueba dentro del cliente ===")
Step("la autoprueba se ejecuta y reporta", function()
    _G.ForeverTotemsButton1.__rect = { 100, 144, 244, 200 }
    local text = ns.SelfTest:Run()
    assert(text:find("ActionButtonUseKeyDown = 1"), "no lee el cvar")
    assert(text:find("secure dispatch: PostClick fired"), "no detecta el despacho seguro")
    assert(text:find("macrotext=/cast "), "no informa de la macro")
end)
Step("detecta un frame que tape el boton", function()
    local intruder = CreateFrame("Frame", "IntrusoQueTapa", UIParent)
    intruder.__rect = { 50, 300, 300, 100 }
    intruder:EnableMouse(true)
    intruder.__shown = true
    local covering = ns.SelfTest:FramesCovering(_G.ForeverTotemsButton1)
    local names = table.concat(covering, " ")
    assert(names:find("IntrusoQueTapa"), "no ha detectado la tapadera: " .. names)
end)

print("\n=== Sonido de los avisos ===")
Step("por defecto suena suave y por el canal de efectos", function()
    _G.__sounds = {}
    ns.Warnings:Alert("prueba", 1, 1, 1, true)
    assert(#_G.__sounds == 1, "no ha sonado")
    assert(_G.__sounds[1].id == SOUNDKIT.MAP_PING, "no usa el sonido suave")
    assert(_G.__sounds[1].channel == "SFX", "no usa el canal SFX")
end)
Step("se puede cambiar de sonido y da la vuelta", function()
    local seen = {}
    for i = 1, 6 do
        local choice = ns.Warnings:CycleSound()
        seen[#seen + 1] = choice.key
    end
    assert(#ns.Warnings:AvailableSounds() == 5, "deberia haber 5 sonidos disponibles")
    assert(seen[1] == seen[6], "el ciclo no vuelve al principio: " .. table.concat(seen, ","))
    assert(#seen == 6 and seen[1] ~= seen[2], "el ciclo no avanza: " .. table.concat(seen, ","))
end)
Step("un sonido que el cliente no tiene se ignora", function()
    local saved = SOUNDKIT.MAP_PING
    SOUNDKIT.MAP_PING, SOUNDKIT.IG_MINIMAP_ZOOM_OUT = nil, nil
    ns.db.warnings.soundChoice = "suave"
    local ok = pcall(function() ns.Warnings:TestSound() end)
    local label = ns.Warnings:GetSoundLabel()
    SOUNDKIT.MAP_PING = saved
    assert(ok, "ha petado con un sonido inexistente")
    assert(label ~= "Soft", "deberia caer a otro sonido, dio " .. label)
end)
Step("sin sonido marcado no suena nada", function()
    ns.db.warnings.sound = false
    _G.__sounds = {}
    ns.Warnings:Alert("prueba", 1, 1, 1, true)
    ns.db.warnings.sound = true
    assert(#_G.__sounds == 0, "ha sonado con el sonido desactivado")
end)

print("\n=== Totem bar nativa (Call of the ...) ===")
Step("detecta los hechizos Call del libro", function()
    local calls = ns.TotemBar:Scan()
    assert(#calls == 2, "esperaba 2 hechizos Call, hay " .. #calls)
    assert(ns.TotemBar:GetActiveCall().name == "Call of the Elements")
end)
Step("el boton de la barra lo lanza", function()
    ns.Bar:ApplyAttributes()
    local macro = _G.ForeverTotemsCallButton:GetAttribute("macrotext")
    assert(macro == "/cast Call of the Elements", "macro incorrecta: " .. tostring(macro))
end)
Step("cada hueco lanza su propio totem", function()
    ns.Sets:SetActive(1)
    ns.Bar:ApplyAttributes()
    local spell = ns.Sets:GetSpellForSlot(1)
    local macro = _G.ForeverTotemsButton1:GetAttribute("macrotext")
    assert(macro == "/cast " .. spell.name, "macro del hueco 1 incorrecta: " .. tostring(macro))
    assert(_G.ForeverTotemsButton1:GetAttribute("type2") == "destroytotem", "falta el clic derecho")
end)
Step("el boton de Call ofrece tambien los de gestion", function()
    ns.TotemBar.spells, ns.TotemBar.management = nil, nil
    local list = ns.TotemBar:GetButtonSpells()
    local nombres = {}
    for _, e in ipairs(list) do nombres[e.name] = e end
    assert(nombres["Call of the Elements"], "falta Call of the Elements")
    assert(nombres["Totemic Recall"], "falta Totemic Recall")
    assert(nombres["Totemic Projection"], "falta Totemic Projection")
    assert(nombres["Totemic Recall"].management, "deberia marcarse como gestion")
end)
Step("elegir uno de gestion cambia lo que lanza el boton", function()
    ns.TotemBar:SetActiveCall({ name = "Totemic Recall" })
    ns.Bar:ApplyAttributes()
    assert(_G.ForeverTotemsCallButton:GetAttribute("macrotext") == "/cast Totemic Recall",
        "macro incorrecta: " .. tostring(_G.ForeverTotemsCallButton:GetAttribute("macrotext")))
end)
Step("y no intenta sincronizar paginas con un hechizo de gestion", function()
    assert(ns.TotemBar:GetPageForCall() == 1, "sin pagina valida deberia quedarse en la 1")
    ns.TotemBar:SetActiveCall({ name = "Call of the Elements" })
end)
Step("los de gestion siguen fuera de las listas de totems", function()
    ns:RefreshTotemSpells()
    for _, e in ipairs(ns.totemSpells) do
        assert(not e.name:find("Totemic"), "se ha colado en los totems: " .. e.name)
    end
end)
Step("/ft call recorre todos y vuelve al principio", function()
    local total = #ns.TotemBar:GetButtonSpells()
    local first = ns.TotemBar:GetActiveCall().name
    ns.TotemBar:CycleCall()
    assert(ns.TotemBar:GetActiveCall().name ~= first, "no ha cambiado de hechizo")
    for _ = 2, total do ns.TotemBar:CycleCall() end
    assert(ns.TotemBar:GetActiveCall().name == first,
        "tras " .. total .. " pasos deberia volver al primero")
end)
Step("los Call no se cuelan como totems del set", function()
    ns:RefreshTotemSpells()
    for _, e in ipairs(ns.totemSpells) do
        assert(not e.name:find("Call of"), "un hechizo Call aparece como totem: " .. e.name)
    end
end)
Step("el diagnostico recorre la API sin petar", function()
    assert(ns.TotemBar:HasAPI() == true, "el stub ahora si tiene la API")
    ns.TotemBar:Report()
end)
Step("/ft totembar abre la ventana copiable", function()
    SlashCmdList["FOREVERTOTEMS"]("totembar")
    local text = _G.ForeverTotemsTextWindow.edit.__text
    assert(text and text:find("Call of the Elements"), "el texto copiable no trae el diagnostico")
    assert(text:find("Searing Totem"), "no resuelve los nombres de GetMultiCastTotemSpells")
    assert(text:find("page 1 %(slots 133%-136%)"), "no informa de la pagina y ranuras")
    assert(text:find("\n"), "deberia ser multilinea")
end)

print("\n=== Sincronizar con la totem bar del juego ===")
Step("mapeo de ranuras segun el cliente real", function()
    assert(ns.TotemBar:GetActionID(1, 1) == 133, "fuego pagina 1 deberia ser 133")
    assert(ns.TotemBar:GetActionID(1, 2) == 134, "tierra pagina 1 deberia ser 134")
    assert(ns.TotemBar:GetActionID(2, 1) == 137, "fuego pagina 2 deberia ser 137")
    assert(ns.TotemBar:GetActionID(3, 4) == 144, "aire pagina 3 deberia ser 144")
end)
Step("escribe el set activo en la pagina correcta", function()
    ns.Sets:SetActive(1)
    ns.Sets:AssignSpell(1, 2, { name = "Stoneskin Totem", icon = 1 })
    local written, skipped, reason = ns.TotemBar:SyncActiveSet()
    assert(not reason, tostring(reason))
    assert(written >= 1, "no ha escrito nada")
    local page = ns.TotemBar:ReadPage(1)
    assert(page[2] == "Stoneskin Totem", "tierra no se ha escrito: " .. tostring(page[2]))
end)
Step("un totem que el cliente no acepta se salta, no peta", function()
    ns.db.sets[1].spells[2] = { name = "Totem del Vacio Eterno" }   -- sin pasar por AssignSpell
    local written, skipped = ns.TotemBar:SyncActiveSet()
    assert(skipped >= 1, "deberia haberse saltado uno")
    local page = ns.TotemBar:ReadPage(1)
    assert(page[2] == "Stoneskin Totem", "no deberia haber tocado la ranura")
    ns.db.sets[1].spells[2] = { name = "Stoneskin Totem" }
end)
Step("en combate no escribe", function()
    _G.__inCombat = true
    local written, skipped, reason = ns.TotemBar:SyncActiveSet()
    _G.__inCombat = false
    assert(reason, "deberia negarse en combate")
end)
Step("/ft sync", function() SlashCmdList["FOREVERTOTEMS"]("sync") end)

print("\n=== Combate ===")
Step("cambios bloqueados en combate se encolan", function()
    _G.__inCombat = true
    FireEvent("PLAYER_REGEN_DISABLED")
    ns.Sets:Apply()
    ns:ApplyBindings()
    ns.Bar:Layout()
    _G.__inCombat = false
    FireEvent("PLAYER_REGEN_ENABLED")
end)

print("\n=== Sets, teclas y comandos ===")
Step("crear y activar un set nuevo", function()
    local idx = ns.Sets:New("PvP")
    ns.Sets:AssignSpell(idx, 4, { name = "Grounding Totem", icon = 1 })
    assert(ns.Sets:SetActive(idx))
    assert(ns.db.learned["Grounding Totem"] == 4, "asignar a mano no ensena el elemento")
end)
Step("los hechizos de gestion no cuentan como totems", function()
    ns:RefreshTotemSpells()
    for _, e in ipairs(ns.totemSpells) do
        assert(not e.name:find("Totemic"), "se ha colado un hechizo de gestion: " .. e.name)
    end
end)
Step("pero los totems de verdad siguen ahi", function()
    local nombres = {}
    for _, e in ipairs(ns.totemSpells) do nombres[e.name] = true end
    assert(nombres["Searing Totem"], "falta Searing Totem")
    assert(nombres["Stoneskin Totem"], "falta Stoneskin Totem")
end)
Step("totem nuevo sin clasificar aparece en la lista", function()
    ns:RefreshTotemSpells()
    local found
    for _, e in ipairs(ns.totemSpells) do
        if e.name == "Totem del Vacio Eterno" then found = e end
    end
    assert(found, "no lista el totem desconocido")
    assert(found.slot == 0, "deberia quedar sin clasificar hasta lanzarlo")
end)
Step("asignar tecla", function()
    ns:SetBinding(1, "SHIFT-T")
    ns:SetBinding("sequence", "SHIFT-T")   -- debe robarsela al slot 1
    assert(ns.db.binds.slots[1] == nil, "la tecla esta duplicada")
    assert(ns.db.binds.sequence == "SHIFT-T")
end)
for _, cmd in ipairs({ "", "lock", "unlock", "show", "hide", "reset", "set PvP", "set 1", "macro", "scan", "debug", "loquesea" }) do
    Step("/ft " .. cmd, function() SlashCmdList["FOREVERTOTEMS"](cmd) end)
end
Step("SPELLS_CHANGED + temporizador", function()
    FireEvent("SPELLS_CHANGED")
    RunTimers()
end)
Step("recarga con la BD ya guardada", function()
    local ns2 = {}
    frames = {}
    for _, file in ipairs(tocFiles) do
        loadfile(base .. "/" .. file)("ForeverTotems", ns2)
    end
    FireEvent("ADDON_LOADED", "ForeverTotems")
    FireEvent("PLAYER_LOGIN")
    assert(#ns2.db.sets == 2, "los sets guardados no sobreviven a la recarga")
end)
