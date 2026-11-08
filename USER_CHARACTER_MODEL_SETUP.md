# Main Character Model Setup

The main character is the custom Mixamo rig at:

```
res://assets/character/character_main.glb
```

Everything that shows the hero uses it: the player, shadow clones, the spin-menu preview,
multiplayer avatars and the Character Creator. All of them go through `Hero.create()` in `hero.gd`.

## Customizable meshes (inside the GLB)

| Creator option | Mesh name in the GLB |
|---|---|
| Hairstyle 1 / 2 | `hair1` / `hair2` |
| Shirt 1 / 2 | `shirt1` / `shirt2` |
| Pants 1 / 2 | `pants1` / `pants2` |
| (always shown) | `shoes`, `face`, `backhead` |

The creator **discovers these by mesh name** (`hair<number>`, `shirt<number>`, `pants<number>`).
To add more: add a mesh called `hair3` (or `shirt3`, `pants3`, ...) to the GLB, re-export, and a
new button appears in the creator. No code change is needed. Skinned parts (shirt/pants) must be
weighted to the same Mixamo skeleton; hair is parented to the head bone.

## Hair colour

Hair colour is applied to every hair mesh, the scalp (`backhead`) and the eyebrows (the face
surface whose material is called "Eyebrow Color"), so the head never shows a white patch.
Pick a swatch or use CUSTOM COLOR for any colour. The colour is stored as `#RRGGBB`.
Each model gets its own copy of the material, so one player's colour never leaks onto another.

## Saved data

`GameData.character_appearance`:

```
{"hair_style": "hair1", "hair_color": "#E6B52E", "shirt_style": "shirt1", "pants_style": "pants1"}
```

Old saves (`"spiky"`, `"shirt_2"`, ...) are converted automatically by `Hero.sanitize_appearance()`.
Multiplayer uses the same function, so other players see your real outfit and hair colour.

## Size

This GLB is authored about 5 m tall. `Hero` measures the skeleton (head-top bone to toe bones)
and scales the model to `Hero.TARGET_HEIGHT` (1.75 m) with the feet on the ground. Change
`TARGET_HEIGHT` in `hero.gd` to make the hero taller or shorter.

## Animations

This GLB has the skeleton and meshes but **no animation clips**, so the character stays in its
T-pose until idle/run/attack clips for this skeleton are added. The `Hero.KEYWORDS` table maps
clip names to game states once an AnimationPlayer exists on the model.
