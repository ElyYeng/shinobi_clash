extends Node3D
## One scene, three modes (chosen in the menu through GameData.mode). Each mode loads its map scene
## from res://maps (edit those in Godot's 3D editor; see game_map.gd):
##   "kurama" - boss arena with Kurama      "fight" - village arena, endless trickle of shinobi
##   "world"  - empty open world with NPCs that hand out quests

const FIGHT_ENEMIES := 6      # how many shinobi are kept alive in "fight" mode
const WORLD_TERRAIN_SCRIPT := preload("res://world_terrain.gd")

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
			player.position.y = terrain.height_at(player.position.x, player.position.z) + 0.2
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
	if mode == "fight" and (not NetworkSession.is_active() or NetworkSession.session_mode != "pvp"):
		_fight_spawner(delta)
	elif mode == "world":
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
		map = MapBuilder.build(mode)
	if mode == "world":
		# Replace the old bounded flat test field with streamed procedural terrain.
		var old_floor := map.get_node_or_null("Ground/Floor")
		if old_floor != null:
			old_floor.free()
		var old_bounds := map.get_node_or_null("Bounds")
		if old_bounds != null:
			old_bounds.free()
		var old_grass := map.get_node_or_null("Grass")
		if old_grass != null:
			old_grass.free()
		var terrain := WORLD_TERRAIN_SCRIPT.new()
		terrain.name = "WorldTerrain"
		map.add_child(terrain)
	add_child(map)

# ---------------------------------------------------------------- Mode: FIGHT
func _fight_spawner(delta: float) -> void:
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
	var pos := Vector3.ZERO
	for _t in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(18.0, 28.0)
		pos = player.global_position + Vector3(cos(a), 0, sin(a)) * r
		pos.x = clampf(pos.x, map.spawn_area.position.x, map.spawn_area.end.x)
		pos.z = clampf(pos.z, map.spawn_area.position.y, map.spawn_area.end.y)
		if not _blocked(pos, 1.0):
			break
	pos.y = 0.5
	e.position = pos
	add_child(e)

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
	player.spring.spring_length = 12.0      # pull the camera back for the giant
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
		if placed.has(id):
			n.rotation.y = (placed[id] as Node3D).global_rotation.y
		add_child(n)
		npcs[id] = n
	quests.setup(player, hud, self)
	quests.changed.connect(_refresh_markers)
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
			elif GameData.quest_state == "active" and act["type"] == "deliver" and act["target"] == id:
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
	var id := npc.npc_id
	var act := quests.active_def()
	var none := Callable()
	if not act.is_empty():
		var is_ready := GameData.quest_state == "ready"
		if is_ready and act["giver"] == id:
			dialog.open(npc.display_name, str(act["turn"]),
				[["Complete quest  (%s)" % Quests.reward_text(act), quests.turn_in]])
		elif not is_ready and act["type"] == "deliver" and act["target"] == id:
			dialog.open(npc.display_name, str(act["deliver_text"]), [["Deliver the message", quests.deliver_done]])
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

# ---------------------------------------------------------------- Shared world helpers
## Is this x/z point inside (or within `pad` of) something solid on the map?
func _blocked(p: Vector3, pad: float) -> bool:
	return map != null and map.blocked(p, pad)
