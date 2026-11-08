# Main Character Model Setup

The current main character is the custom Mixamo GLB supplied by the project owner.

## Install the exact latest upload

Extract the supplied ZIP into the project's `assets` folder. The required path is:

```
res://assets/character/character_main.glb
```

The filename `character_main.glb` is deliberately unique so an older test export cannot override this model.

## Actual mesh resources used by Character Creator

| Creator option | GLB mesh resource |
|---|---|
| Hair 1 | `hair1` |
| Hair 2 | `hair2` |
| Shirt 1 | `shirt1` |
| Shirt 2 | `shirt2` |
| Pants 1 | `pants1` |
| Pants 2 | `pants2` |
| Shoes | `shoes` |

Hair color is applied to the selected hairstyle's material. Shirt and pants options toggle the original skinned meshes; they are not replaced by primitive meshes.

All clothing and hair are authored for the same 78-joint Mixamo skeleton included in the GLB.

## Animations

This GLB contains the skeleton and meshes but no embedded animation clips. Character movement states therefore need Mixamo animation clips imported for this skeleton before the character can perform animated idle/run/jump/attack motions.
