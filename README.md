# Shinobi Clash (Godot 4 prototype)

## Run
1. Open project.godot in Godot 4.x and WAIT for the first import to finish (assets/naruto and assets/kurama).
2. Press F5 - you start at the main menu. The Output panel prints the model's measured height and which animations were matched.

The character is assets/naruto/scene.gltf (auto-detected). To use another .glb/.gltf, replace it or add a model
to assets/ . Tweak size/orientation/animation names at the top of scripts/player/hero.gd.

## Project layout
```
scenes/            main.tscn (gameplay), menu.tscn (start scene), multiplayer_lobby.tscn, small UI / prefab scenes
scripts/core/      GameData (save + progression), Fx (input map, small effects), Sfx (procedural sounds)
scripts/player/    Player, Hero (character model / looks / animation), bloodlines, elements, moves,
                   Susanoo, shadow clones, projectiles, ragdoll, head look
scripts/world/     Main (mode setup), maps (GameMap, MapBuilder, KonohaGreybox, StaticBatcher),
                   enemies, Kurama, NPCs, villagers, terrain / grass
scripts/quests/    quest system + objectives/ (one file per objective type)
scripts/ui/        HUD, M menu, Customize (spin_menu), main menu + parallax, lobby, dialog, UiStyle
scripts/fx/        Vfx (procedural effects), VfxKit (imported VFX scenes), cutscenes, anime outline post
scripts/net/       NetworkSession (autoload), remote avatars, ragdoll sync
maps/              map scenes (konoha_greybox.tscn = main game, village.tscn = arena, kurama_arena.tscn)
data/              quests / NPCs as .tres resources
shaders/           shared shaders      assets/  models, textures, sounds, imported VFX packs
tools/             editor-time generators (merge_hidden_leaf, build_konoha, bake_maps)
docs/              notes, credits and setup guides
```
`.godot/` (Godot's import cache) is not in git - Godot rebuilds it the first time you open the project.

## Controls
WASD move | Shift sprint (stamina) | Space jump x2 | Q dash | LMB combo | RMB kunai | RMB+E kunai volley
**Hotbar R T Y F G H V B N**: each key runs the move you put on it (M > Bloodline / M > Element: click an ability, then a key).
Defaults: R Fireball, T Phoenix Flowers, Y Flame Wave, F Shadow Clones, G Dragon Flame, H Element Armor, V Substitution, B / N empty.
C tap = bloodline power-up on/off, C hold = charge chakra | Z Kurama Mode | E talk | M menu | L quest tracker | Tab / MMB lock-on | Esc mouse

## Spins and elements
Bloodline spins: start with 3; earn 1 per 8 kills, per quest and for beating Kurama. A Legendary is guaranteed within 20 spins.

Bloodline slots (main menu > 4 CUSTOMIZE): 4 slots, Shinobi Life style. Slots 1-2 are open; slot 3 costs 10 spins and slot 4 costs 25 to open.
- [CLICK TO SPIN] rolls that slot only and REPLACES its bloodline. Epic/Legendary slots ask for a second click first.
- EQUIP picks which slot's bloodline you fight with (also in the M menu, Bloodline tab).
- Spins are only on the main menu now. "Open spin" in the M menu takes you there.
- AUTO SPIN rerolls the active slot until it hits the rarity you pick (Rare+, Epic+ or Legendary), or press STOP.
- [ODDS] shows the chance of every rarity and bloodline. Pity is shared by all slots.
- Old saves are migrated: your equipped bloodline goes to slot 1 and your best other one to slot 2.
Slot unlock costs: SLOT_UNLOCK_COST in scripts/core/gamedata.gd.

## Bloodlines (17)
Common: Inuzuka (speed), Akimichi (health), Sarutobi (C: Staff Sweep)
Rare: Nara (Shadow Bind), Hyuga (Gentle Burst), Aburame (Insect Swarm), Yamanaka (Mind Burst), Hozuki (Hydrification)
Epic: Senju (Regeneration), Kaguya (Bone Spikes), Hoshigaki (Shark Bombs), Yuki (Ice Prison)
Legendary: Uzumaki (Chakra Surge), Uchiha (Sharingan), Hatake (Lightning Blade), Chinoike (Blood Rage)
Mythic: Otsutsuki (Truth-Seeking Orbs)
Odds: Common 45% / Rare 30% / Epic 15% / Legendary 8.5% / Mythic 1.5% (weights in bloodline.gd; powers in player.gd _use_ability).
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

## Levels, stats and bloodline mastery (Shindo Life style)
- **Shinobi level** (max 500): XP from kills (100), bosses (1000) and quests (300). Each level gives 3 stat points.
  Spend them in M > Stats on Health (+3 HP), Chakra (+3), MD (+1.5% MD gain), Stamina (+2) or Bloodline (+1% ability damage).
  Max 200 points per stat; Reset Stats gives them all back. The HUD strip shows your level and XP bar.
- **Bloodline mastery** (max LV 1000): each bloodline levels on its own while equipped (100 per kill, 1000 per boss, 3 per ability hit).
- **3 abilities per bloodline**, unlocked at bloodline LV 0 / 250 / 600 (per-ability "lvl" in bloodline.gd). Put them on any hotbar key
  in M > Bloodline. Only the equipped bloodline's moves work (others show a lock on the hotbar).
- **Power-up mode** at bloodline LV 1000 (Uchiha = Sharingan, Uzumaki = Kurama Ink Mode, ...). Tap C to turn it on and again to
  turn it off. No timer: it drains MD (a full bar lasts 30 s) and ends when MD runs out. Needs at least 10 MD to start.
- **M > Bloodline** shows two slots at a time like Shindo Life: bloodline LV, the 3 abilities + power-up with their unlock levels,
  EQUIP and the mastery EXP bar. Click an icon for its details. M > Sub-Ability lists the equipped bloodline's moves.
- Cheats tab: +100 / MAX bloodline LV and +5 shinobi levels for testing.
- Tuning: abilities and modes in bloodline.gd (format documented at the top), XP / stat values in gamedata.gd,
  MD drain (POWER_DRAIN_TIME) in player.gd.

## Elements
Each element (Fire, Earth, Lightning, Water, Wind) has 4 jutsu that unlock at element LV 0 / 20 / 60 / 120 (element_data.gd).
Element LV goes up from kills (your equipped element) and from hits with that element's jutsu. M > Element looks like the
Bloodline tab (no power-up): click a jutsu, then a key. You can use the jutsu of every element you own. Roll new elements
with Element Spins in Customize on the main menu.

## Ability images
Every move shows a picture on the hotbar and in the menus: `assets/icons/<move>.png`, e.g. `bl_uchiha_2.png` (Uchiha ability 3),
`el_fire_0.png`, `base_clones.png`, and `mode_uchiha.png` for a power-up. To use your own art, replace the PNG with the same
name (square, transparent corners look best), or set `"icon": "res://path/to/image.png"` on an ability in bloodline.gd /
element_data.gd. Godot imports new images when you open the project.

## Quests and NPCs (modular)
Every quest and every NPC is its own resource file, loaded automatically when the game starts:
- `data/quests/<id>.tres` (QuestDef, fields documented in `quest_def.gd`)
- `data/npcs/<id>.tres` (NpcDef, fields documented in `npc_def.gd`; the file name is the NPC id)

**To add a quest:** duplicate a file in `data/quests`, give it a new `id`, set the `giver` (an NPC file name) and edit it in
the Inspector. Nothing else to register. Objective types: `goto`, `deliver`, `kill`, `hunt` (named enemies that spawn at
`pos`, with their own health, damage, speed and colours), `kurama`. Rewards: `reward_spins`, `reward_levels` (whole levels with
their stat points; your XP progress is kept) and `reward_xp`. `requires` chains quests, `order` sorts several quests from one NPC.

**To add an NPC:** add a file in `data/npcs`. Leave `model` empty for the placeholder ninja or point it at a .glb / .gltf / .tscn;
it is scaled to `model_height` and plays its first animation as idle. If a model turns black, set `outline = false`.

**Kakashi** (open world, next to the Elder) gives *Rough Ninjas*: defeat 3 Rough Ninjas in the south-west fields, then return
to him for +2 levels. His model is `assets/kakashi/kakashiwithidle.glb`.

## Kurama Mode (Z)
Unlocked by beating Kurama. Press Z to turn it on (needs 50 MD) and Z again to turn it off. No timer: it drains MD
(a full bar lasts 25 s) and ends when MD runs out. It stacks with your bloodline power-up (C): with both on you get both
bonuses, and MD drains at both rates combined x1.25. Kills still add MD while a mode is on.
Tuning in player.gd: MODE_TIME, KURAMA_MIN_MD, BOTH_DRAIN_MULT, POWER_DRAIN_TIME.

## Maps (editable in the Godot editor)
The three maps are normal scene files now. Open one and edit it in the 3D viewport like any level:
- `maps/village.tscn` - Fight mode village
- `maps/open_world.tscn` - Main Game (open world)
- `maps/kurama_arena.tscn` - Kurama Boss Fight

Everything is grouped in the Scene dock: Environment (sky, sun), Ground, Bounds (invisible walls), Walls, Cliffs,
Buildings, Props, Trees, Lanterns, Bushes, Rocks, Grass, Decor (particles) and Markers. Move, duplicate (Ctrl+D) or delete
anything, or drop in your own models. Things that should block enemy spawns and grass must be a StaticBody3D with a box or
cylinder collision shape, in any group except Ground / Bounds / Markers / Grass / Environment.
- **Markers/PlayerSpawn** sets where you start; **Markers/BossSpawn** where Kurama appears. Drag them.
- **Grass** is a GrassPatch node: count, area, colours, and areas to keep clear (circles / rectangles for roads) are in the
  Inspector, and it updates live. It automatically keeps off solid objects.
- The map root (GameMap) has `play_half` (play area) and `spawn_area` (where Fight-mode enemies appear).

The old generator lives in `map_builder.gd`. If a map file is missing, the game generates it instead; to recreate a missing
file, open `tools/bake_maps.gd` and use File > Run (existing maps are skipped, so your edits are safe).

### NPCs on the map
In `maps/open_world.tscn` every NPC is an **NpcSpawn** under the **NPCs** group, with a live preview of the character.
- **Move / turn an NPC:** select it and drag it in the 3D view (rotating it turns the NPC). Quest arrows and Travel follow.
- **Add an NPC:** drag `prefabs/npc_spawn.tscn` from the FileSystem dock into the 3D view (or Ctrl+D an existing spawn),
  then drag an NPC file from `data/npcs` onto its **Npc** field in the Inspector. New NPC = a new file in `data/npcs` first.
- NPCs that have no spawn on the map stand at the `pos` written in their NPC file.
