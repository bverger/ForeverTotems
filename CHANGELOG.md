# Changelog

## 1.0.1

Swing timer, rewritten around what this client actually reports:

- It no longer starts when you right click a target from out of range. Auto
  attack being on is not evidence of a swing, so the bar now waits for a hit to
  land and anchors the cycle there.
- Hits are matched by cadence instead of by where they fall in the window. Your
  swings arrive one weapon speed apart; a Searing Totem ticking on the same
  target does not, and no longer steals the rhythm. A bad anchor used to lock
  the timer into a wrong phase forever, because every real swing landed in the
  half that was being rejected.
- Taking a hit no longer reset your swing. The unit filter included
  "targettarget", which in a melee fight is you.
- The cycle chains into the next swing instead of freezing at 0.0s, and keeps
  running when the client stops reporting your attack speed mid-fight.
- One colour throughout, with "~" marking a predicted cycle.

Weapon imbues:

- Detected from the weapon tooltip. This client reports no temporary enchant
  through GetWeaponEnchantInfo and puts nothing in your buffs.
- The enchant is named after the short form plus its rank ("Rockbiter 3"), not
  after the spell ("Rockbiter Weapon"), so matching now works out which word is
  generic by comparing your known imbues against each other.
- Time left shown in minutes, green while it is up and orange in the last
  minute.

## 1.0.0

First release.

- Totem bar with countdowns, quick recast and per-slot flyouts
- Totem sets, castsequence button, generated macro and sync with the game's
  totem bar
- Expiry, destroyed and out-of-range warnings with a selectable sound
- Weapon imbue button, remaining time and a warning when entering combat
  without one
- Swing timer
- Keybinds for every button, configurable bar order, scale and layout
