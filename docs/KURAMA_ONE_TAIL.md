# Kurama form 1 — one-tail cloak

The boss-unlocked Z mode now uses the existing AuraShell effect with a thin,
vermilion body outline, two translucent chakra ears and one tapered, curling
tail. The clothes and character remain visible. Tail sway and flowing chakra
run in the shader; geometry is built once per activation. Ears follow the
head bone. The same effect is used for local players and remote avatars.

The previous 1.3x model-scale assignment and the reset-to-one assignment have
both been removed from local and remote mode toggles. Activating and ending
the form preserve the model's existing scale. Unlocks, Z input, MD drain,
healing and combat bonuses are unchanged.

This changes the cloak visuals, not the underlying movement animation set.

## Godot playtest checklist

- Defeat Kurama (or use an existing unlocked save), fill MD, then press Z.
  Confirm one tail, two ears, visible clothes, and unchanged character height.
- Walk, sprint, jump, wall-walk and turn. Check tail attachment, ear alignment
  and translucent rendering from front, side and rear.
- Toggle Z repeatedly and let MD empty. Verify all cloak meshes disappear
  and the model's scale remains identical before, during and after activation.
- Stack with a C bloodline mode; deactivate each independently.
- Test host/client activation, joining an already transformed player,
  death and respawn. Check there are no duplicate or orphaned cloak meshes.
- Compare light and dark maps and characters with different hair/face options.

GDScript syntax and procedural-geometry checks were run during implementation.
Final shader compilation, model alignment and visual approval require Godot
with the project's imported assets.
