extends Node3D
## One scene, three modes (chosen in the menu through GameData.mode). Each mode loads its map scene
## from res://maps (edit those in Godot's 3D editor; see game_map.gd):
##   "kurama" - boss arena with Kurama      "fight" - village arena, endless trickle of shinobi
##   "world"  - empty open world with NPCs that hand out quests

const FIGHT_ENEMIES := 6      # how many shinobi are kept alive in "fight" mode
const WORLD_TERRAIN_SCRIPT := preload("res://scripts/world/world_terrain.gd")

var player: Player
var hud: HUD
var spin: SpinMenu = null   # spins are on the main menu now (Customize)
var gmenu: GameMenu
var play_half := 246.0     # half-size of the playable area, used to keep teleports in bounds
var dialog: DialogBox
var quests: Quests
var kurama: Kurama
var mode := "fight"
var rng := RandomNumberGenerator.new()
var awarded_kills := 0
var respawn_timer := 1.0
var npcs := {}
var map: GameMap              # the loaded map scene (res://maps/*.tscn)

func _ready() -> void:
	rng.seed = 1234
	Fx.setup_inputs()
	GameData.load_data()
	Enemy.time_scale = 1.0
	mode = GameData.mode
	if not MapBuilder.MAP_FILES.has(mode):
		mode = "fight"
	_load_map()
	# looping ambience: village life in Konoha, forest everywhere else
	Sfx.ambient(self, "village" if mode == "world" else "forest_1")
	if mode == "world":
		Sfx.ambient(self, "slight_breeze", -22.0)
	play_half = map.play_half
	player = Player.new()
	player.position = map.spawn("PlayerSpawn", Vector3(0, 1, 30) if _boss_mode() else Vector3(0, 1, 0))
	if mode == "world":
		var terrain := map.get_node_or_null("WorldTerrain")
		if terrain != null:
			# Player origin is at the feet; leave a little clearance above the ground.
			player.position.y = terrain.height_at(player.position.x, player.position.z) + 3.0
			# The first collision mesh must exist before CharacterBody3D starts physics.
			terrain.prepare_spawn(player.position)
	add_child(player)
	if NetworkSession.is_active():
		NetworkSession.bind_local_player(player, self)
	hud = HUD.new()
	hud.mode = mode
	add_child(hud)
	hud.bind(player)
	gmenu = GameMenu.new()
	add_child(gmenu)
	gmenu.bind(player, self)
	if mode == "kurama":
		_start_kurama()
	elif mode == "uchiha":
		_start_uchiha()
	elif mode == "world":
		_start_world()
	elif _is_pvp_arena():
		_start_arena()

func _process(delta: float) -> void:
	var over := player.is_dead or (_boss_mode() and hud.victory)
	if over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if player.is_dead:
		return
	if not _boss_mode():
		while player.kills - awarded_kills >= 8:
			awarded_kills += 8
			_give_spins(1, "8 kills")
	# Fight mode spawns AI ninjas. In a PvP arena only the host spawns them; they are shared
	# with every player (see NetworkSession "PvP arena ninjas").
	if mode == "fight" and (not _is_pvp_arena() or multiplayer.is_server()):
		_fight_spawner(delta)
	if mode == "world" or _is_pvp_arena():
		_world_interact()

func _give_spins(n: int, why: String) -> void:
	GameData.spins += n
	GameData.save()
	hud.toast("+%d Spin (%s) - spin at the main menu (Customize)" % [n, why])

## Loads the editable map scene for this mode (falls back to generating it if the file is missing).
func _load_map() -> void:
	var path: String = MapBuilder.MAP_FILES[mode]
	var ps := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if ps != null:
		map = ps.instantiate() as GameMap
	if map == null:
		push_warning("[Main] %s missing - generating the map instead (open tools/bake_maps.gd and run it to create it)" % path)
		map = KonohaGreybox.build() if mode == "world" else MapBuilder.build(mode)
	if mode == "world" and map.get_node_or_null("Village") == null and map.get_node_or_null("HokageRock") == null:
		# Old procedural open world (maps/stash/open_world_procedural.tscn): replace the bounded
		# flat test field with streamed terrain. The Hidden Leaf map has its own ground and walls.
		var old_floor := map.get_node_or_null("Ground/Floor")
		if old_floor != null:
			old_floor.free()
		var old_bounds := map.get_node_or_null("Bounds")
		if old_bounds != null:
			old_bounds.free()
		var old_grass := map.get_node_or_null("Grass")
		if old_grass != null:
			old_grass.free()
		var terrain := map.get_node_or_null("WorldTerrain")
		if terrain == null:
			terrain = WORLD_TERRAIN_SCRIPT.new()
			terrain.name = "WorldTerrain"
			map.add_child(terrain)
	add_child(map)
	AnimePost.add_to(map)   # anime ink outlines (Forward+ only)
	if map.get_node_or_null("Village") == null:   # (the Hidden Leaf map is pre-merged by its bake tool)
		StaticBatcher.batch(map)   # merge static meshes per material -> far fewer draw calls
	CharToon.apply(map)   # Ultimate Toon Source stylized shader on the map too

# ---------------------------------------------------------------- Mode: FIGHT
func _fight_spawner(delta: float) -> void:
	if _is_pvp_arena() and NetworkSession.arena_ninja.is_empty():
		respawn_timer = 1.5   # nobody joined Ninja Battle: no new ninjas
		return
	if get_tree().get_nodes_in_group("enemies").size() >= FIGHT_ENEMIES:
		respawn_timer = 1.5
		return
	respawn_timer -= delta
	if respawn_timer <= 0.0:
		respawn_timer = 1.5
		_spawn_enemy()

func _spawn_enemy() -> void:
	var e := Enemy.new()
	e.health = 60.0
	e.speed = 4.8
	e.damage = 8.0
	var arena := NetworkSession.is_active() and NetworkSession.session_mode == "pvp"
	var center := _arena_spawn_center() if arena else player.global_position
	var pos := Vector3.ZERO
	for _t in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(18.0, 28.0)
		pos = center + Vector3(cos(a), 0, sin(a)) * r
		pos.x = clampf(pos.x, map.spawn_area.position.x, map.spawn_area.end.x)
		pos.z = clampf(pos.z, map.spawn_area.position.y, map.spawn_area.end.y)
		if not _blocked(pos, 1.0):
			break
	pos.y = 0.5
	e.position = pos
	if arena:
		NetworkSession.register_arena_enemy(e)
	add_child(e)
	if arena:
		NetworkSession.announce_arena_enemy(e)

## PvP host: spawn ninjas around a random living Ninja Battle player.
func _arena_spawn_center() -> Vector3:
	var spots: Array[Vector3] = []
	if not player.is_dead and NetworkSession.arena_flag(1, "ninja"):
		spots.append(player.global_position)
	for id in NetworkSession._avatars:
		var avatar = NetworkSession._avatars[id]
		if is_instance_valid(avatar) and not bool(avatar.get("network_ragdoll_started")) and NetworkSession.arena_flag(int(id), "ninja"):
			spots.append((avatar as Node3D).global_position)
	return spots[rng.randi() % spots.size()] if not spots.is_empty() else player.global_position

## PvP client: a copy of one of the host's arena ninjas. It follows the host and sends hits to it.
func spawn_arena_mirror(enemy_id: String, pos: Vector3) -> void:
	var e := Enemy.new()
	e.network_quest_id = enemy_id
	e.network_quest_party_leader = NetworkSession.ARENA_ENEMY
	e.network_quest_mirror = true
	e.position = pos
	e.add_to_group("quest_enemies")
	add_child(e)
	e.apply_quest_network_state(pos, 0.0, -1.0)

# ---------------------------------------------------------------- Mode: KURAMA
func _start_kurama() -> void:
	kurama = Kurama.new()
	kurama.position = map.spawn("BossSpawn", Vector3(0, 0, -34))
	add_child(kurama)
	if NetworkSession.is_active() and NetworkSession.session_mode == "raid":
		NetworkSession.register_raid_boss(kurama)
	hud.boss = kurama
	kurama.defeated.connect(_on_kurama_defeated)
	kurama.enraged.connect(_on_kurama_enraged)
	player.cam_zoom = 12.0      # pull the camera back for the giant
	hud.toast("KURAMA, THE NINE-TAILED BEAST")

## After Claudiu (main game): everyone back to Konoha, next to the gate.
func _back_to_world() -> void:
	GameData.boss_from_world = false
	GameData.world_return_pos = UCHIHA_GATE + Vector3(0, 1, 5)
	if NetworkSession.is_active():
		NetworkSession.return_party_to_world()   # host moves the party; clients wait for it
		return
	GameData.mode = "world"
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _boss_mode() -> bool:
	return mode == "kurama" or mode == "uchiha"

# ---------------------------------------------------------------- Mode: UCHIHA BOSS
var uchiha: UchihaBoss
func _start_uchiha() -> void:
	uchiha = UchihaBoss.new()
	uchiha.position = map.spawn("BossSpawn", Vector3(0, 0, -34)) + Vector3(0, 0.5, 30)   # closer: he's human-sized
	add_child(uchiha)
	hud.boss = uchiha
	uchiha.phase_changed.connect(func(ph: int) -> void:
		hud.toast("SUSANOO!  The Uchiha's chakra takes form" if ph == 2 else "The Uchiha is enraged!"))
	uchiha.defeated.connect(func() -> void:
		GameData.spins += 5
		GameData.save()
		hud.victory_text = "Claudiu Uchiha has fallen   -   +5 spins"
		hud.victory = true
		hud.toast("Claudiu Uchiha defeated!  +5 spins")
		if GameData.boss_from_world:   # came through the gate: back to Konoha
			hud.victory_text = "Claudiu Uchiha has fallen   -   +5 spins   -   back to Konoha..."
			get_tree().create_timer(6.0).timeout.connect(_back_to_world))
	hud.toast("CLAUDIU UCHIHA BLOCKS YOUR PATH")

func _on_kurama_enraged(phase: int) -> void:
	hud.toast("KURAMA IS ENRAGED!" if phase == 3 else "Kurama is getting serious...")

func _on_kurama_defeated() -> void:
	GameData.kurama_defeated = true
	GameData.spins += 5
	GameData.save()
	hud.victory = true
	hud.toast("Kurama defeated!  +5 spins")
	# Only the host starts the transition; the reliable RPC moves the entire
	# raid party together and keeps NetworkSession/party membership alive.
	if NetworkSession.is_active() and NetworkSession.session_mode == "raid" and multiplayer.is_server():
		NetworkSession.complete_kurama_raid()

# ---------------------------------------------------------------- Mode: OPEN WORLD
func _start_world() -> void:
	dialog = DialogBox.new()
	add_child(dialog)
	dialog.bind(player)
	quests = Quests.new()
	add_child(quests)
	Quests.ensure_loaded()
	# NPC spawns placed in the map (maps/open_world.tscn > NPCs) override the pos in the NPC files
	var placed := {}
	for s in map.find_children("*", "NpcSpawn", true, false):
		var sp := s as NpcSpawn
		if sp.npc_id() != "" and Quests.NPCS.has(sp.npc_id()):
			placed[sp.npc_id()] = sp
			Quests.NPCS[sp.npc_id()]["pos"] = sp.global_position   # quest arrows / Travel use it too
	for id in Quests.NPCS:
		var d: Dictionary = Quests.NPCS[id]
		var n := Npc.new()
		n.npc_id = id
		n.display_name = d["name"]
		n.body_color = d["color"]
		n.band_color = d["band"]
		n.greeting = d["greet"]
		n.position = d["pos"]
		var terrain := map.get_node_or_null("WorldTerrain")
		if terrain != null:
			n.position.y = terrain.height_at(n.position.x, n.position.z)
			Quests.NPCS[id]["pos"] = n.position
		n.model_path = d["model"]
		n.model_height = d["model_height"]
		n.model_yaw_deg = d["model_yaw"]
		n.outline = d["outline"]
		n.appearance = d.get("appearance", {})
		if placed.has(id):
			n.rotation.y = (placed[id] as Node3D).global_rotation.y
		add_child(n)
		npcs[id] = n
	quests.setup(player, hud, self)
	quests.changed.connect(_refresh_markers)
	if map.get_node_or_null("HokageRock") != null:   # Konoha greybox: villagers stroll the streets
		var crowd := Node3D.new()
		crowd.name = "Villagers"
		map.add_child(crowd)
		Villager.populate(crowd, 28)
	_refresh_markers()
	_build_uchiha_gate()
	_spawn_sparrers.call_deferred()
	if GameData.world_return_pos != Vector3.ZERO:   # back from the boss arena
		player.global_position = GameData.world_return_pos
		GameData.world_return_pos = Vector3.ZERO
	if TEST_NINJA:
		_spawn_test_ninja()

## Main-game boss: at the Uchiha District gate, [E] takes you (and your co-op party) to the
## arena to fight Claudiu Uchiha.
const UCHIHA_GATE := Vector3(112, 0, 106)
var _gate: Node3D
func _build_uchiha_gate() -> void:
	_gate = Node3D.new()
	_gate.name = "UchihaBossGate"
	add_child(_gate)
	var pos := UCHIHA_GATE
	var terrain := map.get_node_or_null("WorldTerrain")
	if terrain != null:
		pos.y = terrain.height_at(pos.x, pos.z)
	_gate.global_position = pos
	Vfx.aura_flames(_gate, Vector3(0, 0.2, 0), 1.1, Color(0.7, 0.05, 0.08, 0.8), 30, true)
	Vfx.glow_light(_gate, Color(0.9, 0.1, 0.1), 2.5, 9.0, Vector3(0, 1.5, 0))
	var l := Label3D.new()
	l.text = "CLAUDIU UCHIHA\nBoss  -  [E] Challenge"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 14
	l.modulate = Color(1.0, 0.35, 0.3)
	l.position = Vector3(0, 3.0, 0)
	_gate.add_child(l)

## Shinobi sparring in pairs outside the village (forest and meadow past the main gate).
const SPAR_SPOTS := [Vector3(-45, 0, 205), Vector3(-62, 0, 228), Vector3(45, 0, 205), Vector3(62, 0, 228)]   # clearings in the Outskirts forest
func _spawn_sparrers() -> void:
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for i in SPAR_SPOTS.size():
		var at: Vector3 = SPAR_SPOTS[i]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 120.0, at + Vector3.DOWN * 50.0))
		if not hit.is_empty():
			at = hit["position"]
		SparPair.spawn(self, at, 1000 + i)

func _near_gate() -> bool:
	return _gate != null and player.global_position.distance_to(_gate.global_position) < 4.0

func _enter_uchiha_arena() -> void:
	if NetworkSession.is_active():
		NetworkSession.request_uchiha_arena()
		return
	GameData.boss_from_world = true
	GameData.mode = "uchiha"
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## TEST: a 1000 HP ninja near the spawn to try combos / knockdowns on. It only fights back once
## you hit it, and comes back 5 s after it's beaten.
const TEST_NINJA := false   # stashed - set true to spawn it again
const TEST_NINJA_HP := 1000.0
func _spawn_test_ninja() -> void:
	if not is_inside_tree() or player == null:
		return
	var e := Enemy.new()
	e.health = TEST_NINJA_HP
	e.speed = 3.5
	e.damage = 3.0
	e.aggro_range = 3.0
	e.display_name = "Test Ninja (1K HP)"
	var pos := player.global_position + Vector3(0, 0.5, -6)
	e.position = pos
	add_child(e)
	e.tree_exited.connect(func() -> void:
		if is_inside_tree():
			get_tree().create_timer(5.0).timeout.connect(_spawn_test_ninja))

func _refresh_markers() -> void:
	var act := quests.active_def()
	for id in npcs:
		var n: Npc = npcs[id]
		var m := ""
		var col := Color(1.0, 0.9, 0.2)
		if not act.is_empty():
			if GameData.quest_state == "ready" and act["giver"] == id:
				m = "?"
			elif quests.talk_target() == id:
				m = "!"
				col = Color(0.4, 0.9, 1.0)
		elif quests.available_for(id) != "":
			m = "!"
		n.set_marker(m, col)

var _held_villager: Villager

func _world_interact() -> void:
	if dialog.is_open:
		return
	if _held_villager != null:   # dialog closed: let them walk on
		if is_instance_valid(_held_villager):
			_held_villager.held = false
		_held_villager = null
	if _near_gate():
		hud.prompt_text = "[E]  Challenge Claudiu Uchiha  (boss)"
		if Input.is_action_just_pressed("interact") and not Input.is_action_pressed("kunai"):
			hud.prompt_text = ""
			_enter_uchiha_arena()
		return
	var near: Npc = null
	var best := 4.5
	for id in npcs:
		var n: Npc = npcs[id]
		var d := player.global_position.distance_to(n.global_position)
		if d < best:
			best = d
			near = n
	var vil: Villager = null
	if near == null:   # walking villagers (some have errands)
		vil = Villager.near(player.global_position, 3.5)
	if near != null:
		hud.prompt_text = "[E]  Talk to %s" % near.display_name
	elif vil != null:
		hud.prompt_text = "[E]  Talk to %s" % Villager.name_for(vil.index)
	else:
		hud.prompt_text = ""
	if (near != null or vil != null) and Input.is_action_just_pressed("interact") and not Input.is_action_pressed("kunai"):
		hud.prompt_text = ""
		if near != null:
			_talk(near)
		else:
			_talk_villager(vil.index)

const VILLAGER_LINES := ["Nice weather today.", "Have you tried Ichiraku's ramen?", "The Hokage works so hard...",
	"Stay safe out there, shinobi.", "My kids want to join the Academy!", "Busy day at the market."]

## Walking villagers: their errand (Errands) if they have one, otherwise small talk.
func _talk_villager(i: int) -> void:
	var nm := Villager.name_for(i)
	var v := Villager.by_index(i)
	if v != null:   # stand still while we talk
		v.held = true
		_held_villager = v
	var none := Callable()
	var act := quests.active_def()
	if not act.is_empty():
		if Errands.is_errand(GameData.quest_active) and Errands.villager_of(GameData.quest_active) == i:
			if GameData.quest_state == "ready":
				dialog.open(nm, str(act["turn"]), [["Complete quest  (%s)" % Quests.reward_text(act), quests.turn_in]])
			else:
				dialog.open(nm, str(act["remind"]), [["Okay, I'm on it", none], ["Abandon quest", quests.abandon]])
			return
		dialog.open(nm, VILLAGER_LINES[(i + GameData.errands_done) % VILLAGER_LINES.size()], [["Goodbye", none]])
		return
	if Errands.offers(i):
		var qid := Errands.id_for(i)
		var q := Quests.def(qid)
		var txt := "%s\n\n[Quest: %s   Reward: %s]" % [q["offer"], q["title"], Quests.reward_text(q)]
		dialog.open(nm, txt, [["Accept quest", quests.accept.bind(qid)], ["Not now", none]])
	else:
		dialog.open(nm, VILLAGER_LINES[(i + GameData.errands_done) % VILLAGER_LINES.size()], [["Goodbye", none]])

func _talk(npc: Npc) -> void:
	if ARENA_NPCS.has(npc.npc_id):
		_talk_arena(npc)
		return
	var id := npc.npc_id
	var act := quests.active_def()
	var none := Callable()
	if not act.is_empty():
		var is_ready := GameData.quest_state == "ready"
		if is_ready and act["giver"] == id:
			dialog.open(npc.display_name, str(act["turn"]),
				[["Complete quest  (%s)" % Quests.reward_text(act), quests.turn_in]])
		elif not is_ready and quests.talk_target() == id:
			var said := quests.talk_text()
			dialog.open(npc.display_name, said if said != "" else npc.greeting, [["Continue", quests.talk_done]])
		elif act["giver"] == id:
			dialog.open(npc.display_name, str(act["remind"]), [["Okay, I'm on it", none], ["Abandon quest", quests.abandon]])
		else:
			dialog.open(npc.display_name, npc.greeting, [["Goodbye", none]])
		return
	var qid := quests.available_for(id)
	if qid != "":
		var q: Dictionary = Quests.DEFS[qid]
		var txt := "%s\n\n[Quest: %s   Reward: %s]" % [q["offer"], q["title"], Quests.reward_text(q)]
		dialog.open(npc.display_name, txt, [["Accept quest", quests.accept.bind(qid)], ["Not now", none]])
	else:
		dialog.open(npc.display_name, npc.greeting + "\n\n(I have no more work for you right now.)", [["Goodbye", none]])

# ---------------------------------------------------------------- PvP arena NPCs
## Two NPCs in the PvP arena let each player opt into fights. Their files are in
## data/arena_npcs; place them with the NpcSpawn markers under ArenaNPCs in maps/village.tscn.
const ARENA_NPC_DIR := "res://data/arena_npcs"
const ARENA_NPCS := {"ninja_battle": "ninja", "pvp_battle": "pvp"}

func _is_pvp_arena() -> bool:
	return mode == "fight" and NetworkSession.is_active() and NetworkSession.session_mode == "pvp"

func _start_arena() -> void:
	dialog = DialogBox.new()
	add_child(dialog)
	dialog.bind(player)
	var placed := {}
	for s in map.find_children("*", "NpcSpawn", true, false):
		var sp := s as NpcSpawn
		if ARENA_NPCS.has(sp.npc_id()):
			placed[sp.npc_id()] = sp
	for id in ARENA_NPCS:
		var def := load(ARENA_NPC_DIR.path_join(id + ".tres")) as NpcDef
		if def == null:
			continue
		var d := def.to_dict(id)
		var n := Npc.new()
		n.npc_id = id
		n.display_name = d["name"]
		n.body_color = d["color"]
		n.band_color = d["band"]
		n.greeting = d["greet"]
		n.appearance = d["appearance"]
		n.model_path = d["model"]
		n.model_height = d["model_height"]
		n.model_yaw_deg = d["model_yaw"]
		n.outline = d["outline"]
		n.position = d["pos"]
		if placed.has(id):
			n.position = (placed[id] as Node3D).global_position
			n.rotation.y = (placed[id] as Node3D).global_rotation.y
		add_child(n)
		npcs[id] = n
	NetworkSession.arena_flags_changed.connect(_on_arena_flags_changed)
	_on_arena_flags_changed()

func _talk_arena(npc: Npc) -> void:
	var kind: String = ARENA_NPCS[npc.npc_id]
	var on := NetworkSession.arena_flag(multiplayer.get_unique_id(), kind)
	var who := 0
	for id in (NetworkSession.arena_pvp if kind == "pvp" else NetworkSession.arena_ninja):
		who += 1
	var status := "\n\n[You are %s.  Players in it: %d]" % ["IN" if on else "not in it", who]
	var action := ("Leave the %s" if on else "Join the %s") % npc.display_name
	dialog.open(npc.display_name, npc.greeting + status,
		[[action, NetworkSession.request_arena_toggle.bind(kind)], ["Not now", Callable()]])

## Updates the NPC markers ("ON" when you're in that battle) and tells you when your status changes.
var _arena_mine := {}
func _on_arena_flags_changed() -> void:
	var me := multiplayer.get_unique_id()
	for id in ARENA_NPCS:
		if not npcs.has(id):
			continue
		var kind: String = ARENA_NPCS[id]
		var on := NetworkSession.arena_flag(me, kind)
		(npcs[id] as Npc).set_marker("ON" if on else "!", Color(0.35, 1.0, 0.4) if on else Color(1.0, 0.9, 0.2))
		if _arena_mine.has(kind) and bool(_arena_mine[kind]) != on:
			var what := "Ninja Battle: the arena ninjas will fight you" if kind == "ninja" else "PvP Battle: you can fight other PvP players"
			hud.toast(("Joined %s" % what) if on else ("Left the %s" % ("Ninja Battle" if kind == "ninja" else "PvP Battle")))
		_arena_mine[kind] = on

# ---------------------------------------------------------------- Shared world helpers
## Is this x/z point inside (or within `pad` of) something solid on the map?
func _blocked(p: Vector3, pad: float) -> bool:
	return map != null and map.blocked(p, pad)
