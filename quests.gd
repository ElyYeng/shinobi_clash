class_name Quests
extends Node
## Quest tracking for the open world. One quest can be active at a time; progress is saved through GameData.
##
## Quests and NPCs are MODULAR: each one is its own resource file, loaded automatically:
##   res://data/quests/<id>.tres   (QuestDef - see quest_def.gd for every field and objective type)
##   res://data/npcs/<id>.tres     (NpcDef  - see npc_def.gd; the file name is the NPC id)
## To add a quest, duplicate a .tres in data/quests, give it a new id and edit it in the Inspector.
## Objective types: goto | deliver | kill | hunt | kurama.   Rewards: spins, levels, XP.

signal changed

const QUEST_DIR := "res://data/quests"
const NPC_DIR := "res://data/npcs"

static var NPCS := {}    # npc id -> dict (NpcDef.to_dict)
static var DEFS := {}    # quest id -> dict (QuestDef.to_dict), sorted by giver order
static var _loaded := false

## Loads every quest / NPC file once.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	NPCS.clear()
	DEFS.clear()
	for path in _files(NPC_DIR):
		var n := load(path) as NpcDef
		if n != null:
			var nid := path.get_file().get_basename()
			NPCS[nid] = n.to_dict(nid)
	var list: Array = []
	for path in _files(QUEST_DIR):
		var q := load(path) as QuestDef
		if q == null:
			continue
		if q.id == "":
			q.id = path.get_file().get_basename()
		if not NPCS.has(q.giver):
			push_warning("[Quests] %s: giver '%s' has no file in %s" % [path, q.giver, NPC_DIR])
			continue
		list.append(q.to_dict())
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["order"] < b["order"] if a["order"] != b["order"] else str(a["id"]) < str(b["id"]))
	for d in list:
		DEFS[d["id"]] = d

## .tres files in a folder (also finds them in exported games, where they get a .remap suffix).
static func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres") or n.ends_with(".res"):
			out.append(dir.path_join(n))
	out.sort()
	return out

## "+2 levels, +1 spin" for dialog buttons.
static func reward_text(d: Dictionary) -> String:
	var parts: Array[String] = []
	if int(d["levels"]) > 0:
		parts.append("+%d level%s" % [int(d["levels"]), "" if int(d["levels"]) == 1 else "s"])
	if int(d["reward"]) > 0:
		parts.append("+%d spin%s" % [int(d["reward"]), "" if int(d["reward"]) == 1 else "s"])
	if int(d["xp"]) > 0:
		parts.append("+%d XP" % int(d["xp"]))
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "no reward"

var player: Player
var hud: HUD
var world: Node3D
var beacon: Node3D = null
var beacon_label: Label3D = null
var _last_kills := 0
var _hunt_base := 0      # hunt: progress when the targets were spawned
var _hunt_spawned := 0   # hunt: how many targets were spawned

func setup(p: Player, h: HUD, w: Node3D) -> void:
	ensure_loaded()
	player = p
	hud = h
	world = w
	_last_kills = p.kills
	if GameData.quest_active != "" and not DEFS.has(GameData.quest_active):
		GameData.quest_active = ""   # save from a version with different quests
		GameData.quest_state = ""
	if GameData.quest_active != "":
		_activate_objective()
	_refresh_hud()

# ------------------------------------------------------------------ queries
func available_for(npc_id: String) -> String:
	if GameData.quest_active != "":
		return ""
	for id in DEFS:
		var d: Dictionary = DEFS[id]
		if d["giver"] != npc_id or GameData.quests_done.has(id):
			continue
		var req: String = d["req"]
		if req != "" and not GameData.quests_done.has(req):
			continue
		return id
	return ""

func active_def() -> Dictionary:
	if GameData.quest_active == "":
		return {}
	return DEFS[GameData.quest_active]

# ------------------------------------------------------------------ actions
func accept(id: String) -> void:
	GameData.quest_active = id
	GameData.quest_state = "active"
	GameData.quest_progress = 0
	GameData.save()
	_last_kills = player.kills
	_activate_objective()
	var d: Dictionary = DEFS[id]
	hud.toast("Quest accepted: %s" % d["title"])
	_refresh_hud()
	changed.emit()

func deliver_done() -> void:
	_set_ready()

func turn_in() -> void:
	var d := active_def()
	if d.is_empty():
		return
	var reward := int(d["reward"])
	GameData.spins += reward
	if player != null:
		var xp := int(d["xp"])
		for i in int(d["levels"]):   # whole levels; your progress into the current level is kept
			xp += GameData.xp_needed(GameData.level + i)
		if xp > 0:
			player.gain_xp(xp)
	GameData.quests_done.append(GameData.quest_active)
	GameData.quest_active = ""
	GameData.quest_state = ""
	GameData.quest_progress = 0
	GameData.save()
	_clear_objective()
	hud.toast("Quest complete: %s   %s" % [d["title"], reward_text(d)])
	_refresh_hud()
	changed.emit()

func abandon() -> void:
	GameData.quest_active = ""
	GameData.quest_state = ""
	GameData.quest_progress = 0
	GameData.save()
	_clear_objective()
	hud.toast("Quest abandoned")
	_refresh_hud()
	changed.emit()

func _set_ready() -> void:
	if GameData.quest_state == "ready":
		return
	GameData.quest_state = "ready"
	GameData.save()
	_clear_objective()
	var d := active_def()
	var giver: Dictionary = NPCS[d["giver"]]
	hud.toast("Objective complete! Return to %s" % giver["name"])
	_refresh_hud()
	changed.emit()

# ------------------------------------------------------------------ objectives
func _activate_objective() -> void:
	_clear_objective()
	if GameData.quest_state != "active":
		return
	var d := active_def()
	match str(d["type"]):
		"goto":
			_make_beacon(d["pos"], str(d["place"]))
		"kill":
			_make_beacon(d["pos"], "Enemy camp")
			_spawn_bandits(int(d["count"]) - GameData.quest_progress, d["pos"], d)
		"hunt":
			_make_beacon(d["pos"], str(d["enemy_name"]) if str(d["enemy_name"]) != "" else "Targets")
			_hunt_base = GameData.quest_progress
			_hunt_spawned = maxi(int(d["count"]) - GameData.quest_progress, 0)
			_spawn_bandits(_hunt_spawned, d["pos"], d, true)

func _clear_objective() -> void:
	if beacon != null and is_instance_valid(beacon):
		beacon.queue_free()
	beacon = null
	beacon_label = null
	for e in get_tree().get_nodes_in_group("quest_enemies"):
		e.queue_free()

func _make_beacon(pos: Vector3, text: String) -> void:
	beacon = Node3D.new()
	beacon.position = Vector3(pos.x, 0.0, pos.z)
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.2
	c.bottom_radius = 1.2
	c.height = 70.0
	c.radial_segments = 12
	m.mesh = c
	m.position.y = 35.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.28)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	beacon.add_child(m)
	beacon_label = Label3D.new()
	beacon_label.text = text
	beacon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon_label.no_depth_test = true
	beacon_label.font_size = 48
	beacon_label.outline_size = 12
	beacon_label.pixel_size = 0.03
	beacon_label.position.y = 74.0
	beacon_label.set_meta("base", text)
	beacon.add_child(beacon_label)
	world.add_child(beacon)

func _spawn_bandits(n: int, center: Vector3, d: Dictionary, named := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in maxi(n, 0):
		var e := Enemy.new()
		e.health = float(d["enemy_health"])
		e.speed = float(d["enemy_speed"])
		e.damage = float(d["enemy_damage"])
		e.aggro_range = 20.0
		e.body_color = d["enemy_color"]
		e.band_color = d["enemy_band"]
		if named:
			e.display_name = str(d["enemy_name"])
			e.add_to_group("hunt_targets")
		var a := TAU * float(i) / float(maxi(n, 1)) + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(4.0, 10.0)
		e.position = Vector3(center.x + cos(a) * r, 0.5, center.z + sin(a) * r)
		e.add_to_group("quest_enemies")
		world.add_child(e)

# ------------------------------------------------------------------ per-frame
func _process(_delta: float) -> void:
	if player == null or GameData.quest_active == "":
		return
	var d := active_def()
	var kd := player.kills - _last_kills
	_last_kills = player.kills
	if GameData.quest_state == "active":
		match str(d["type"]):
			"goto":
				var tp: Vector3 = d["pos"]
				var flat := Vector2(player.global_position.x - tp.x, player.global_position.z - tp.z)
				if flat.length() < float(d["radius"]):
					_set_ready()
			"kill":
				if kd > 0:
					GameData.quest_progress += kd
					GameData.save()
					if GameData.quest_progress >= int(d["count"]):
						_set_ready()
			"hunt":   # progress = targets that are no longer alive
				var alive := 0
				for e in get_tree().get_nodes_in_group("hunt_targets"):
					if e.is_in_group("enemies"):
						alive += 1
				var prog := _hunt_base + _hunt_spawned - alive
				if prog != GameData.quest_progress:
					GameData.quest_progress = prog
					GameData.save()
				if GameData.quest_progress >= int(d["count"]):
					_set_ready()
			"kurama":
				if GameData.kurama_defeated:
					_set_ready()
	if beacon_label != null and is_instance_valid(beacon_label) and beacon != null:
		var dist := Vector2(player.global_position.x - beacon.position.x, player.global_position.z - beacon.position.z).length()
		beacon_label.text = "%s\n%d m" % [beacon_label.get_meta("base"), int(dist)]
	_refresh_hud()

func _refresh_hud() -> void:
	if hud == null:
		return
	var d := active_def()
	if d.is_empty():
		hud.quest_text = "No active quest\nTalk to villagers with a  !"
		return
	var t := "QUEST: %s\n" % d["title"]
	if GameData.quest_state == "ready":
		var giver: Dictionary = NPCS[d["giver"]]
		hud.quest_text = t + "Return to %s" % giver["name"]
		return
	match str(d["type"]):
		"goto":
			var tp: Vector3 = d["pos"]
			var dist := Vector2(player.global_position.x - tp.x, player.global_position.z - tp.z).length()
			hud.quest_text = t + "Reach the %s (%d m)" % [d["place"], int(dist)]
		"kill":
			hud.quest_text = t + "Defeat enemies: %d / %d" % [GameData.quest_progress, int(d["count"])]
		"hunt":
			hud.quest_text = t + "Defeat %ss: %d / %d" % [d["enemy_name"], GameData.quest_progress, int(d["count"])]
		"deliver":
			var target: Dictionary = NPCS[d["target"]]
			hud.quest_text = t + "Speak to %s" % target["name"]
		"kurama":
			hud.quest_text = t + "Defeat Kurama\n(Menu > Kurama Boss Fight)"
