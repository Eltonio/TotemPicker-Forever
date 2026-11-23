# Changelog

## 0.3.2 (beta)
- Totem lists: left and right clicks are swapped, as suggested by players. **Left click now drops the totem** (active totem unchanged), **right click makes it the active totem** (and sets it in the game's totem bar for Call of the Elements). Middle click is unchanged: drop it and make it active.
- Element buttons, Call button and handle: no change.

## 0.3.1 (beta)
- New name: TotemPicker Forever (was TotemBar Forever during the private tests). New folder, command `/tpk`; settings and key bindings from the test versions are not carried over.
- Options window: its width now follows the longest text, so labels never overflow (French texts were cut).
- New option: language (game language, English or Français), applied after a reload.
- English README.

## 0.3.0 (beta)
- Cooldowns: totems with a real cooldown show a dark sweep and the remaining time (centre, yellow) on their icon in the lists and on the element button when they are the active totem. The global cooldown is ignored.
- Totem duration on the element button is now a thin bar that empties plus the time (white), on the edge opposite to the colour strip, so it never hides the cooldown.
- New option: show totem cooldowns.

## 0.2.0 (beta)
- Call button: no more list. Left click casts the current Call; right click switches to the next known Call and its totem set (useful once Call of the Ancestors is learned).
- Drag handle: always visible, blue when unlocked, translucent black when locked. Left drag moves (unlocked only), Shift + right click locks/unlocks, Shift + middle click opens the options. Matching tooltips.

## 0.1.0 (beta)
- First version: element bar, per-element lists (left = set active, right = drop, middle = both), Call button with set switching, Totemic Recall.
- Options: icon size, spacing, list spacing, bar orientation, list direction, element colours, timers, tooltips, lock, hide Blizzard bar.
- Key bindings and /tpk diag.
