# Hatake Sharingan activation

Hatake's existing C-hold power-up now plays a 2.95-second local cinematic.
Its level, full-chakra and MD requirements are unchanged. X activation uses
the same sequence; switching the power off does not replay it.

- 0.00–1.05 s: letterbox and cool vignette ease in; an angled portrait moves
  towards the character's closed left eye.
- 1.05 s: the Sharingan texture appears, the left eyelid opens over 180 ms,
  and the existing activation sound accompanies a soft red pulse.
- 1.05–2.25 s: the camera settles on the awakened eye.
- 2.25–2.95 s: camera transform and FOV blend back to the previous camera.

Escape skips and applies the powered appearance. Normal completion, skipping,
player removal and scene teardown all restore the camera, HUD, processing and
temporary effects. Offline play pauses the world; online play only holds the
local player, following the existing cutscenes' temporary invulnerability
convention. No global time-scale changes or new art assets are required.

## Manual playtest

1. In Godot, equip Hatake, reach bloodline mastery 1000, fill chakra and have
   enough MD; hold C. Check the left-eye reveal on several face/hair choices.
2. Release C during the shot. Verify movement, mouse look, HUD and power drain
   resume after the return. Hold C again to deactivate; the left eye closes.
3. Activate using X; press Escape before and after the reveal. The mode should
   remain on and the gameplay camera should return immediately.
4. Try activation while airborne and beside a wall, at wide and narrow window
   sizes. Check portrait framing and world-geometry occlusion.
5. In a two-player session, activate as host and client. The other player and
   network simulation must keep running. Exit the scene during the shot and
   check for orphan cameras, lights, audio, or a stuck pause.
6. Activate Uchiha and a body-transformation bloodline to check their existing
   sequences are unchanged.

Timing and framing live in scripts/fx/hatake_cutscene.gd. This source change
still requires an in-engine visual playtest with the full imported project.
