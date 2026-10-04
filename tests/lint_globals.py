#!/usr/bin/env python3
"""Lista las funciones globales que llama un addon y avisa de las no verificadas.

Un stub de pruebas puede inventarse cualquier funcion; esto compara contra una
lista de APIs que se han confirmado existentes en el cliente objetivo.
"""
import re, sys, os

KNOWN = set("""
CreateFrame GetTime InCombatLockdown UnitName UnitClass GetRealmName GetBuildInfo
print pairs ipairs select type tostring tonumber unpack setmetatable getmetatable
table string math error pcall assert rawset rawget next format strjoin tostringall
tinsert StaticPopup_Show PlaySound PlaySoundFile GetCVar GetCVarBool
ClearOverrideBindings SetOverrideBindingClick IsShiftKeyDown IsControlKeyDown
IsAltKeyDown GetTotemInfo GetActionInfo GetMultiCastTotemSpells SetMultiCastSpell
IsUsableSpell GetNumSpellTabs GetSpellTabInfo GetSpellBookItemInfo
issecretvalue hasanysecretvalues loadstring
GetMacroIndexByName CreateMacro EditMacro PickupMacro
GetCursorPosition
UnitExists UnitCanAttack UnitIsDeadOrGhost IsSpellKnown GetSpellCooldown
CombatLogGetCurrentEventInfo GetWeaponEnchantInfo GetInventoryItemLink UnitAttackSpeed IsCurrentSpell
""".split())

KNOWN_TABLES = set("""
C_Spell C_SpellBook C_Timer C_Map C_UnitAuras C_AddOns C_Secrets Settings Enum
GameTooltip UIParent SOUNDKIT StaticPopupDialogs SlashCmdList UISpecialFrames
BackdropTemplateMixin ChatFontNormal GameFontHighlight
""".split())

# Globales que pueden no existir: el addon SOLO puede usarlas tras comprobarlas
OPTIONAL = set("""
GetMouseFocus GetMouseFoci InterfaceOptions_AddCategory
InterfaceOptionsFrame_OpenToCategory DestroyTotem
""".split())

LUA_KEYWORDS = set("""
if then else elseif end for while do function local return break not and or
nil true false repeat until in
""".split())

def strip_noise(src):
    """Fuera comentarios y cadenas: ahi no hay llamadas, solo falsos positivos."""
    src = re.sub(r"--\[\[.*?\]\]", " ", src, flags=re.S)
    src = re.sub(r"--[^\n]*", " ", src)
    src = re.sub(r"\[\[.*?\]\]", '""', src, flags=re.S)
    src = re.sub(r'"(\\.|[^"\\])*"', '""', src)
    src = re.sub(r"'(\\.|[^'\\])*'", "''", src)
    return src


def locals_of(src):
    names = set(re.findall(r"\blocal\s+function\s+([A-Za-z_]\w*)", src))
    for match in re.findall(r"\blocal\s+([A-Za-z_][\w,\s]*)=", src):
        for name in match.split(","):
            names.add(name.strip())
    names |= set(re.findall(r"\bfunction\s+[\w.:]*[.:]([A-Za-z_]\w*)\s*\(", src))
    names |= set(re.findall(r"\bfunction\s+([A-Za-z_]\w*)\s*\(", src))
    for vars_ in re.findall(r"\bfor\s+([A-Za-z_][\w,\s]*?)\s*(?:=|\bin\b)", src):
        for name in vars_.split(","):
            names.add(name.strip())
    # parametros de funcion
    for params in re.findall(r"function\s*[\w.:]*\s*\(([^)]*)\)", src):
        for name in params.split(","):
            names.add(name.strip().strip("."))
    return {n for n in names if n}

def main(folder):
    unknown = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".lua"):
            continue
        src = strip_noise(open(os.path.join(folder, name), encoding="utf-8").read())
        skip = locals_of(src) | LUA_KEYWORDS | KNOWN | KNOWN_TABLES
        for optional in OPTIONAL:
            # solo vale si esta detras de una comprobacion en el mismo fichero
            guard = r"(_G\.%s|if\s+%s\b|and\s+%s\b|type\(_G\.%s\))" % ((optional,) * 4)
            if re.search(guard, src):
                skip.add(optional)
        for call in re.findall(r"(?<![\w.:\"'])([A-Za-z_]\w*)\s*\(", src):
            if call not in skip:
                unknown.setdefault(call, set()).add(name)
    if unknown:
        print("Globales sin verificar (confirma que existen en el cliente):")
        for call, files in sorted(unknown.items()):
            print("  %-28s %s" % (call, ", ".join(sorted(files))))
        return 1
    print("lint de globales OK")
    return 0

sys.exit(main(sys.argv[1]))
