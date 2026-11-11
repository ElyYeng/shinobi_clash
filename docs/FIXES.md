# Fixes in this build

- Added persistent element-spin data, owned elements, equipped element state, element rolling, and element colour lookup to `gamedata.gd`.
- Kept existing save files compatible: older saves receive the default Fire element and three element spins.
- Fixed the `String.join` call in `spin_menu.gd` by converting the owned-element list to `PackedStringArray`.
- Created the missing scrollable bloodline collection grid and clear/rebuild it on refresh to prevent duplicate buttons.
- Repaired normalized vertical anchors and moved the element/bloodline spin buttons so they no longer overlap.
- Updated the spin menu preview after the player is bound, so it can show the current player model.
- Updated the in-game Element tab and header to show owned/equipped elements and provide an Equip action.
- Applied the equipped element's colour to elemental jutsu effects. The underlying move behaviour remains shared across elements.

## Validation

The edited scripts passed delimiter and `GameData`-reference consistency checks, and the ZIP archive was checked for integrity. A Godot runtime/editor was not available in the build environment, so this package has not been launched in-engine here. Open `project.godot` in Godot 4.7 and allow the asset import to finish before pressing F5.
