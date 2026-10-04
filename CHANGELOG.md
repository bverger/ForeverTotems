# Changelog

## 1.0.2

Fixed:

- Totemic Recall and Totemic Projection were showing up as totems. The word
  "totem" was being matched inside longer words, so anything "totemic" counted.
- The little arrows above each slot drew on top of the world map. They are gone
  entirely, and the bar now fades out while the map is open.

New:

- **Shield button.** Casts Lightning Shield, or Water or Earth Shield if you
  know them, and shows the charges left rather than a clock, because charges
  are what run out. It warns you once if you enter a fight without one.
- **Cooldown watch.** A sound and a quick icon flash above the bar the moment a
  watched ability comes back. Stormstrike is watched by default; `/ft watch
  <spell>` adds or removes any other. Only speaks up in combat. If the client
  stops reporting cooldowns mid-fight, the duration learned earlier keeps the
  count going.
- **Pick a spell by hovering its icon.** The totem slots, the shield and the
  imbue all open their list on hover now. The call button does too, and offers
  Totemic Recall and Totemic Projection alongside Call of the Elements.

Removed:

- The Purge button. It was a plain cast button with nothing to show, since this
  client does not let addons read enemy auras.

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
