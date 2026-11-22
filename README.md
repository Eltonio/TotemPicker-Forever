<p align="center"><img src="media/logo.png" alt="TotemPicker Forever" width="160"></p>

# TotemPicker Forever

English | [Français](README.fr.md)

Shaman totem bar for **World of Warcraft: Forever** (interface 16001). It replaces the tiny arrow of Blizzard's totem bar with direct clicks.

**Author: Doel**

## Installation

Copy the `TotemPickerForever` folder into the AddOns folder of your WoW Forever client. The folder name must match the `.toc` file name.

## The clicks

**On an element button (Earth, Fire, Water, Air)**
- Left click: drop the active totem of that element.
- Right click: open or close the list of that element.

**In the totem list**
- Left click: make it the active totem, without dropping it. It is also written into the game's totem bar, so Call of the Elements will drop it.
- Right click: drop it, without changing the active totem.
- Middle click: drop it and make it the active totem.

**Call button (Call of the Elements / Ancestors / Spirits)**
- Left click: cast the Call shown.
- Right click: switch to the next Call (once you know several) and show its totem set on the bar.

**Totemic Recall**: left click.

Everything works in combat.

## Durations and cooldowns

- The time left on the placed totem is shown on the element button: white time and a thin bar that empties.
- Totems with a real cooldown show the dark sweep and the seconds left (yellow, centred) on their icon in the list, and on the element button when they are the active totem. The global cooldown is ignored.

## Settings (/tpk)

Icon size, spacing between icons, spacing in the lists, bar orientation (horizontal or vertical), direction the lists open (automatic, up, down, left, right), Call and Recall buttons, colour strip per element, totem durations and cooldowns, close the list after a click, tooltips, hide Blizzard's totem bar, lock, language (game language, English or Français, applied after a reload).

**Handle at the end of the bar** (blue when unlocked, translucent black when locked):
- Left click and drag: move the bar (when unlocked).
- Shift + right click: lock / unlock.
- Shift + middle click: open the options.

## Commands

- `/tpk`: options (alias `/totempicker`)
- `/tpk lock` / `/tpk unlock`: lock / unlock the bar
- `/tpk reset`: put the bar back in the centre
- `/tpk diag`: diagnostic to send when reporting a problem

## Key bindings

Esc > Options > Key Bindings > AddOns > TotemPicker Forever: one binding per element, the current Call and Totemic Recall.

## Languages

English and French. By default the addon follows the game language; the Language option forces English or French.

## Good to know

In combat the game hides some data from addons. The totem duration may then disappear, and cooldowns are drawn by the game itself (numbers shown if the game option to show cooldown numbers is enabled). Clicks keep working.
