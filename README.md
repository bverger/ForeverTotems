# Forever Totems

Shaman totem management for **World of Warcraft: Forever**.

A bar with live totem timers, saved totem sets, one-click recasting, weapon
imbue tracking and a swing timer. Built and tested on the Forever beta
(interface 16001).

## Features

**Totem bar** - one slot per element with the active totem's icon, a countdown
and the seconds remaining. Left click casts or recasts that element, right
click destroys the totem. An arrow on each slot pops up every totem of that
element so you can swap it without opening any window.

**Totem sets** - save combinations of up to four totems and switch between
them. The set drives the bar, a `/castsequence` button, an optional real macro
you can drop on your action bar, and the game's own totem bar, so Call of the
Elements places exactly the totems you configured.

**Warnings** - before a totem expires, when one is destroyed early, and when
you walk out of its range. Choice of alert sound, on the effects channel so it
follows your volume settings.

**Weapon imbues** - a button that casts your chosen imbue and shows how long
the current one has left, plus a warning if you enter a fight without one.

**Swing timer** - a bar tracking your melee swing, coloured differently when it
is measured from a landed hit versus predicted from your weapon speed.

## Slash commands

    /ft              open the configuration
    /ft lock         lock the bar in place
    /ft set <name>   switch to another set
    /ft makemacro    create a macro for the active set and put it on your cursor
    /ft sync         write the active set into the game's totem bar
    /ft sound        cycle the warning sound
    /ft check        diagnostics for the bar
    /ft selftest     in-client checks

## Notes on this client

Forever hides some data from addons ("secret values"). Where that happens the
addon says so instead of guessing:

- Totem data is hidden in combat, encounters and PvP. The addon learns each
  totem's duration when it can see it, then keeps its own clock and draws the
  estimated countdown in blue.
- Enemy auras cannot be read at all in combat, so there is no purge alert.
- The combat log is not available to this addon, so the swing timer falls back
  to prediction when no hit event reaches it.

## Testing

`tests/` holds a stub of the WoW API that loads the addon outside the game,
plus a linter that flags any global function the addon calls that has not been
verified to exist on the target client.

## License

MIT
