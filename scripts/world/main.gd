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
	play_half = map.play_half
	player = Player.new()
	player.position = map.spawn("PlayerSpawn", Vector3(0, 1, 30) if mode == "kurama" else Vector3(0, 1, 0))
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
	elif mode == "world":
		_start_world()
	elif _is_pvp_arena():
		_start_arena()

func _process(delta: float) -> void:
	var over := player.is_dead or (mode == "kurama" and hud.victory)
	if over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if player.is_dead:
		return
	if mode != "kurama":
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
		Villager.populate(crowd, 16)
	_refresh_markers()

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

func _world_interact() -> void:
	if dialog.is_open:
		return
	var near: Npc = null
	var best := 4.5
	for id in npcs:
		var n: Npc = npcs[id]
		var d := player.global_position.distance_to(n.global_position)
		if d < best:
			best = d
			near = n
	hud.prompt_text = "[E]  Talk to %s" % near.display_name if near != null else ""
	if near != null and Input.is_action_just_pressed("interact") and not Input.is_action_pressed("kunai"):
		hud.prompt_text = ""
		_talk(near)

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
