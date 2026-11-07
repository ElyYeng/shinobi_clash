# Shinobi Clash (Godot 4 prototype)

## Run
1. Open project.godot in Godot 4.x and WAIT for the first import to finish (assets/naruto and assets/kurama).
2. Press F5 - you start at the main menu. The Output panel prints the model's measured height and which animations were matched.

The character is assets/naruto/scene.gltf (auto-detected). To use another .glb/.gltf, replace it or add a model
to assets/ . Tweak size/orientation/animation names at the top of hero.gd.

## Controls
WASD move | Shift sprint (stamina) | Space jump x2 | Q dash | LMB combo | RMB kunai | RMB+E kunai volley | V substitution
Fire jutsu: R fireball | T phoenix flowers | Y flame wave | F clones | G dragon flame | H flame armor
C tap = bloodline power-up (Sharingan etc.), C hold = charge chakra | Z Kurama Mode (after beating Kurama, MD bar full)
E talk | M menu | B spin menu | L quest tracker | Tab / N / MMB lock-on | Esc mouse

## Spins and elements
Bloodline spins: start with 3; earn 1 per 8 kills, per quest and for beating Kurama. A Legendary is guaranteed within 20 spins.
Element spins: start with 3; use the B menu to unlock and equip Fire, Earth, Lightning, Water or Wind. Equipped elements recolour elemental jutsu effects; the current jutsu behaviour is shared across elements.
Progress is saved in user://save.json. Edit bloodline stats/abilities in bloodline.gd.

## Credits
See CREDITS.md (model is CC-BY-4.0 - credit required).

## New in this version
- Village map (main.gd `_build_world`): walled leaf village, gate, council tower, cliffs, houses you can jump onto.
- Ragdoll on death (ragdoll.gd) - works with Mixamo-rigged models.
- Procedural sounds (sfx.gd) - no audio files; tweak the SPEC table.
- Cel shading + outlines (fx.gd `toon_mat` / `outline_mat`); change outline `width` there.

## Menu / game modes (menu.gd, main.gd)
- **Kurama Boss Fight** - boss arena. Kurama (kurama.gd) uses all 9 animations: stand/wait/atstand (idle), run, attack01 (claw),
  skill01_1 (roar shockwave - JUMP), skill02 (Tailed Beast Bomb), skill03 (ground smash - leave the red circle), hurt01.
  He has 3 phases (66% / 33% HP) and gets faster + angrier. Edit ANIM / constants at the top of kurama.gd to retune.
  The model has no death animation, so he flinches in slow-mo, bursts into smoke and sinks away.
- **Fight** - the village arena; shinobi keep trickling in (no waves). FIGHT_ENEMIES in main.gd.
- **Main Game** - empty open world, only NPCs. Walk up and press **T** to talk. Quests are defined in quests.gd (NPCS / DEFS tables).
  Types: goto, deliver, kill, kurama. Progress is saved in user://save.json. Rewards are bloodline spins.
- **M** returns to the menu at any time. Enter = retry after dying / winning.

## Credits
See CREDITS.md (both models are CC-BY-4.0 - credit required).

## Visual overhaul (vfx.gd)
- **vfx.gd** is the new effects toolbox (all procedural, no new art files): cloud/sun sky shader, ACES tonemapping, bloom glow, SSAO,
  volumetric light shafts + fog, colour grading, soft 4-split sun shadows and a cool fill light.
- Village is now a golden-hour scene: lanterns + stone lanterns with real lights, torii gate, bushes, swaying grass, glowing flowers,
  cherry-blossom trees, falling petals and fireflies, noise-textured ground and dirt roads.
- Kurama arena: infernal sky, glowing lava cracks, rising embers, chakra flames around Kurama, glowing Tailed Beast Bomb with shockwave.
- Combat juice: spark bursts + light flashes on every hit, floating damage numbers, camera shake, dust when sprinting, FOV kick, projectile trails.
- UI: animated menu (blood moon, Kurama's eyes, ridges, embers), styled buttons, glass HUD panel, trailing "damage ghost" bars, damage vignette.
- Too heavy for your GPU? In `Vfx.build_environment` turn off `ssao_enabled` / `volumetric_fog_enabled`, or lower the counts passed to `Vfx.grass`.

## In-game menu (game_menu.gd) - press M
Scroll-style menu: header (element slots, bloodline slots, spins, kills), brush-stroke tabs on the left, entries in the middle,
details + buttons on the right. Tabs: Stats, Ninja Tools, Element, Bloodline (equip / open spin), Sub-Ability, Companions (summon clones),
Travel (teleport to places, Main-Menu, Switch Mode, Quest Target), Mastery, Cheats (god mode, infinite chakra, spins...), Customs (sensitivity,
camera distance, FOV, volume), Controls. Add a tab: put its name in `TABS` and a branch in `_build_items`. Esc or M closes it.

## Bottom HUD (ability_bar.gd)
Shindo-Life style: octagon key slots with cooldown pies, HP / MD / CHI / STM bars and a MENU strip. Each slot reads Player.slot_info(key).
MD = mode meter (fills 1/s and +10 per kill, +25 for Kurama); Kurama Mode (Z) needs it full. STM = stamina, used by sprinting.
New jutsu live in player.gd (_phoenix, _flame_wave, _dragon_flame, _flame_armor, _substitute, _kunai_volley, _kurama_mode).
