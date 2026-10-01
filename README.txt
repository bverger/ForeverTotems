Forever Totems v1.0.0
=====================
Shaman totem management for WoW: Forever (Interface 16001).

Commands
--------
/ft            opens the configuration window
/ft unlock     unlocks the bar so it can be moved (drag the blue box)
/ft lock       locks it again
/ft show|hide  shows or hides the bar
/ft reset      puts the bar back in the center
/ft set <n>    switches set by number or by name
/ft sound      cycles the warning sound and plays it
/ft macro      shows the active set's macro so you can copy it
/ft scan       lists the detected totems and their element
/ft debug      debug messages

Diagnostics (output goes to chat, so /chatlog captures it to a file)
/ft check      per-button state: visible, mouse, size, type and macrotext
/ft clicktest  toggles click tracing, to see if a click reaches a button
/ft selftest   in-client checks: cvars, secure click path, frames covering
               the bar, whether the spell is usable

Spanish aliases also work: opciones, bloquear, desbloquear, mostrar, ocultar,
sonido.

The bar
-------
One slot per element (fire, earth, water, air) with the active totem's icon,
a countdown swipe and the remaining seconds. It flashes red when only a few
seconds are left.

  Left click   casts or recasts that element's totem from the active set
  Right click  destroys the totem (can be turned off in the options)

If a slot has no totem assigned in the set, it uses the last one you cast for
that element.

Sets
----
A set is a combination of up to four totems. In the configuration window each
column is an element: click the icon of the totem you want to assign.

The bar's "SET" button uses /castsequence: each press casts the next totem in
the set. There is no way to cast all four with a single press (the client
requires a real keypress per spell, and there is a global cooldown between
totems), so four presses of the same key is as fast as it gets.

The game's totem bar (Call of the Elements)
-------------------------------------------
Forever's own "Call of ..." spells place four totems with a single 3 second
cast, taking them from the game's totem bar. The addon puts that spell on the
bar as its last button (keybind "Call spell") and, with "Keep the game totem
bar in sync with the set" enabled, writes the active set into the totem bar
whenever the set changes, so the call spell casts exactly the totems you
configured here. "Sync" in the set editor, or /ft sync, does it on demand and
reports what went in.

A totem the client does not accept for that element is skipped instead of
overwriting the slot, and nothing is written while in combat. Layout used
(verified on build 70009): totem bar actions 133-144, three pages of four
(page 1 Call of the Elements, 2 Ancestors, 3 Spirits), slots in fire, earth,
water, air order.

Weapon imbues
-------------
A button on the bar casts your chosen imbue and shows how long the one on your
weapon has left, with its own arrow to switch between the imbues you know.

Walking into a fight without an imbue gets you a warning, once per fight, and
it also fires if the imbue runs out mid-combat. If the client refuses to report
the imbue the addon stays quiet instead of crying wolf.

How it finds the imbue: this client reports no temporary weapon enchant
through GetWeaponEnchantInfo and puts nothing in your buffs, so the addon reads
the weapon tooltip, where the line looks like "Rockbiter 3 (60 min)". Note that
the enchant is named after the short form plus its rank, not after the spell
("Rockbiter Weapon"), so the addon works out which word is generic by comparing
your imbue names against each other and matches on the distinctive part. The
tooltip rounds to whole minutes, so the countdown steps by the minute.

"Imbue the off hand instead" adds /use 17 to the button, which is what puts the
imbue on the off hand rather than the main one.

Warnings
--------
- Expiry: configurable warning N seconds before a totem drops.
- Destroyed: tells you when a totem disappears before its time.
- Out of range: remembers where you dropped each totem and warns once when you
  move further away than the configured yards. In zones without map
  coordinates (some instances) this warning disables itself.

The warning sound can be chosen in the options (Soft, Paper, Whisper, Ready
check, Raid warning) and plays on the sound effects channel, so it follows the
game's volume settings.

Totem elements
--------------
Classic totems are recognised out of the box. New Forever totems show up as
"unclassified" until you cast them once: the addon watches which slot they
land in and remembers it. Assigning one by hand in the configuration teaches
it too.

Keybinds
--------
Set in the configuration window. They are override bindings: they do not touch
your saved key bindings and are applied on every login.

Hidden data in combat (secret values)
-------------------------------------
Since 12.0 the client hides totem data from addons during combat, encounters,
dungeons or PvP restrictions. To keep the bar useful, the addon learns each
totem's duration the first time it sees it with visible data and, once the
client stops reporting it, keeps counting with its own clock based on the
spell you cast. That estimated countdown is drawn in blue.

While the data is hidden there is no way to know whether a totem was
destroyed, so that particular warning pauses. Everything else (countdown,
expiry and out of range) keeps working.

A note about combat
-------------------
Switching sets, moving the bar or changing keybinds cannot be done in the
middle of combat (the client blocks it for security). The addon queues those
changes and applies them as soon as you leave combat.
