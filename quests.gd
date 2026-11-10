class_name Quests
extends Node
## Quest tracking for the open world. One quest can be active at a time; progress is saved through GameData.
##
## Quests and NPCs are MODULAR: each one is its own resource file, loaded automatically:
##   res://data/quests/<id>.tres   (QuestDef - see quest_def.gd for every field and objective type)
##   res://data/npcs/<id>.tres     (NpcDef  - see npc_def.gd; the file name is the NPC id)
## To add a quest, duplicate a .tres in data/quests, give it a new id and edit it in the Inspector.
## A quest has one objective or a list of steps (QuestStep). Each objective TYPE is a script in
##   res://quest_objectives/<type>.gd  (extends QuestObjective)
## so a new kind of objective is a new file there. Rewards: spins, element spins, levels, XP.
##
## Progress is one saved number: step * STEP + progress within the step (so old saves, which only
## had the count, are step 0). Co-op parties share it through NetworkSession.

signal changed

const QUEST_DIR := "res://data/quests"
const NPC_DIR := "res://data/npcs"
const OBJECTIVE_DIR := "res://quest_objectives"
const STEP := 1000   # progress = step * STEP + count

static var NPCS := {}    # npc id -> dict (NpcDef.to_dict)
static var DEFS := {}    # quest id -> dict (QuestDef.to_dict), sorted by giver order
static var OBJECTIVES := {}   # type -> Script (res://quest_objectives/<type>.gd)
static var _loaded := false

## Loads every quest / NPC file once.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	NPCS.clear()
	DEFS.clear()
	OBJECTIVES.clear()
	var da := DirAccess.open(OBJECTIVE_DIR)
	if da != null:
		for f in da.get_files():
			var n := f.trim_suffix(".remap").trim_suffix(".uid")
			if n.get_extension() in ["gd", "gdc"] and not OBJECTIVES.has(n.get_basename()):
				var sc := load(OBJECTIVE_DIR.path_join(n.get_basename() + ".gd")) as Script
				if sc != null:
					OBJECTIVES[n.get_basename()] = sc
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
	if int(d.get("el_spins", 0)) > 0:
		parts.append("+%d element spin%s" % [int(d["el_spins"]), "" if int(d["el_spins"]) == 1 else "s"])
	if int(d["xp"]) > 0:
		parts.append("+%d XP" % int(d["xp"]))
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "no reward"

## Next (state, progress) after the current step of `quest_id` is done: the next step, or
## "ready" (go back to the giver) after the last one. Used locally and by the co-op host.
static func advance(quest_id: String, progress: int) -> Array:
	var d: Dictionary = DEFS.get(quest_id, {})
	var n := (d.get("steps", []) as Array).size()
	var step := progress / STEP
	if step + 1 < n:
		return ["active", (step + 1) * STEP]
	return ["ready", progress]

## Co-op host: a quest enemy of this party died. Returns the new [state, progress], or [] if the
## current step doesn't count kills.
static func after_enemy_kill(quest_id: String, progress: int) -> Array:
	var d: Dictionary = DEFS.get(quest_id, {})
	var steps: Array = d.get("steps", [])
	var step := progress / STEP
	if step >= steps.size():
		return []
	var st: Dictionary = steps[step]
	var sc: Script = OBJECTIVES.get(str(st["type"]))
	if sc == null:
		return []
	var probe: QuestObjective = sc.new()
	if not probe.counts_enemy_kills():
		return []
	var n := mini(progress % STEP + 1, int(st["count"]))
	if n >= int(st["count"]):
		return advance(quest_id, step * STEP + n)
	return ["active", step * STEP + n]

var player: Player
var hud: HUD
var world: Node3D
var beacon: Node3D = null
var beacon_label: Label3D = null
var objective: QuestObjective = null
var _objective_step := -1

func setup(p: Player, h: HUD, w: Node3D) -> void:
	ensure_loaded()
	player = p
	hud = h
	world = w
	if GameData.quest_active != "" and not DEFS.has(GameData.quest_active):
		GameData.quest_active = ""   # save from a version with different quests
		GameData.quest_state = ""
	var shared_loaded := false
	if NetworkSession.is_active():
		shared_loaded = NetworkSession.register_quest_manager(self)
	if GameData.quest_active != "" and not shared_loaded:
		_activate_objective()
	_refresh_hud()

# ------------------------------------------------------------------ queries
func available_for(npc_id: String) -> String:
	if GameData.quest_active != "":
		return ""
	for id in DEFS:
		var d: Dictionary = DEFS[id]
		if d["giver"] != npc_id or (GameData.quests_done.has(id) and not bool(d.get("repeatable", false))):
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

func step_index() -> int:
	return GameData.quest_progress / STEP

func step_progress() -> int:
	return GameData.quest_progress % STEP

## The current step's fields ({} if no quest or it's ready to turn in).
func current_step() -> Dictionary:
	var d := active_def()
	if d.is_empty():
		return {}
	var steps: Array = d["steps"]
	return steps[mini(step_index(), steps.size() - 1)]

## NPC to talk to for the current step ("" = none): the deliver target, for example.
func talk_target() -> String:
	if GameData.quest_state != "active" or objective == null:
		return ""
	return objective.talk_target()

## The current step's text for the talk_target() NPC.
func talk_text() -> String:
	return str(current_step().get("deliver_text", ""))

## Where the quest wants you to go (Vector3.INF = nowhere).
func target_position() -> Vector3:
	var d := active_def()
	if d.is_empty():
		return Vector3.INF
	if GameData.quest_state == "ready":
		return NPCS[d["giver"]]["pos"]
	if objective != null:
		return objective.target_position()
	return Vector3.INF

func party_coop() -> bool:
	return NetworkSession.is_active() and NetworkSession.session_mode == "coop"

# ------------------------------------------------------------------ actions
func accept(id: String) -> void:
	if party_coop():
		NetworkSession.request_party_quest_accept(id)
		return
	GameData.quest_active = id
	GameData.quest_state = "active"
	GameData.quest_progress = 0
	GameData.save()
	_activate_objective()
	var d: Dictionary = DEFS[id]
	hud.toast("Quest accepted: %s" % d["title"])
	_refresh_hud()
	changed.emit()

## The player talked to talk_target() (e.g. delivered the message).
func talk_done() -> void:
	if objective != null:
		objective.on_talk()

func deliver_done() -> void:   # older name
	talk_done()

func turn_in() -> void:
	if party_coop():
		NetworkSession.request_party_quest_turn_in(GameData.quest_active)
		return
	var d := active_def()
	if d.is_empty():
		return
	var reward := int(d["reward"])
	GameData.spins += reward
	GameData.element_spins += int(d.get("el_spins", 0))
	if player != null:
		var xp := int(d["xp"])
		for i in int(d["levels"]):   # whole levels; your progress into the current level is kept
			xp += GameData.xp_needed(GameData.level + i)
		if xp > 0:
			player.gain_xp(xp)
	if not bool(d.get("repeatable", false)) and not GameData.quests_done.has(GameData.quest_active):
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
	if party_coop():
		NetworkSession.request_party_quest_abandon(GameData.quest_active)
		return
	GameData.quest_active = ""
	GameData.quest_state = ""
	GameData.quest_progress = 0
	GameData.save()
	_clear_objective()
	hud.toast("Quest abandoned")
	_refresh_hud()
	changed.emit()

## Progress within the current step (objectives call this through QuestObjective.set_progress).
func set_step_progress(n: int) -> void:
	var v := step_index() * STEP + clampi(n, 0, STEP - 1)
	if v == GameData.quest_progress:
		return
	GameData.quest_progress = v
	GameData.save()

## The current step is done: start the next one, or go back to the giver after the last.
func complete_step() -> void:
	if party_coop():
		NetworkSession.request_party_quest_ready(GameData.quest_active)   # the host advances the party
		return
	if GameData.quest_state != "active":
		return
	var next := advance(GameData.quest_active, GameData.quest_progress)
	if str(next[0]) == "ready":
		_set_ready()
		return
	GameData.quest_progress = int(next[1])
	GameData.save()
	_activate_objective()
	hud.toast("Next: %s" % (objective.hud_text().split("\n")[0] if objective != null else ""))
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
	var st := current_step()
	var sc: Script = OBJECTIVES.get(str(st.get("type", "")))
	if sc == null:
		return
	objective = sc.new()
	objective.quests = self
	objective.step = st
	objective.step_index = step_index()
	_objective_step = step_index()
	objective.start()

## Called only by NetworkSession after the host has accepted a party quest update.
func apply_shared_quest_state(id: String, state: String, progress: int) -> void:
	var previous_id := GameData.quest_active
	var changed_id := previous_id != id
	var changed_state := GameData.quest_state != state
	var changed_step := progress / STEP != GameData.quest_progress / STEP
	if not changed_id and not changed_state and GameData.quest_progress == progress:
		# A manager can be recreated during a scene change while the shared
		# quest state stays the same; rebuild its local objective nodes once.
		if id != "" and state == "active" and objective == null:
			_activate_objective()
		return
	if changed_id or state != "active" or changed_step:
		_clear_objective()
	GameData.quest_active = id
	GameData.quest_state = state
	GameData.quest_progress = progress
	if id != "" and state == "active" and (changed_id or changed_state or changed_step or objective == null):
		_activate_objective()
	GameData.save()
	_refresh_hud()
	changed.emit()

## Applies the shared party turn-in reward locally on each participating machine.
func apply_party_quest_reward(id: String, xp: int, spins: int) -> void:
	var d: Dictionary = DEFS.get(id, {})
	if d.is_empty():
		return
	GameData.spins += spins
	GameData.element_spins += int(d.get("el_spins", 0))
	if player != null and xp > 0:
		player.gain_xp(xp)
	if not bool(d.get("repeatable", false)) and not GameData.quests_done.has(id):
		GameData.quests_done.append(id)
	GameData.quest_active = ""
	GameData.quest_state = ""
	GameData.quest_progress = 0
	GameData.save()
	_clear_objective()
	hud.toast("Party quest complete: %s   +%d XP" % [d["title"], xp])
	_refresh_hud()
	changed.emit()

func _clear_objective() -> void:
	if objective != null:
		objective.stop()
	objective = null
	_objective_step = -1
	if beacon != null and is_instance_valid(beacon):
		beacon.queue_free()
	beacon = null
	beacon_label = null
	for e in get_tree().get_nodes_in_group("quest_enemies"):
		e.queue_free()

## Golden beam with a name + distance label (objectives call this from start()).
func make_beacon(pos: Vector3, text: String) -> void:
	if beacon != null and is_instance_valid(beacon):
		beacon.queue_free()
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

## Spawns `n` quest enemies around the step's `pos` (stats from its enemy_* fields). Positions
## and network ids come from `first_index` + i, so every co-op party member builds the same ones.
func spawn_enemies(n: int, st: Dictionary, named := false, first_index := -1) -> void:
	var d := active_def()
	var center: Vector3 = st["pos"]
	var base := step_progress() if first_index < 0 else first_index
	for i in maxi(n, 0):
		var e := Enemy.new()
		e.health = float(st["enemy_health"])
		e.speed = float(st["enemy_speed"])
		e.damage = float(st["enemy_damage"])
		e.aggro_range = 20.0
		e.body_color = st["enemy_color"]
		e.band_color = st["enemy_band"]
		if named:
			e.display_name = str(st["enemy_name"])
			e.add_to_group("hunt_targets")
		var spawn_index := base + i
		var angle := TAU * float(spawn_index) / float(maxi(int(st["count"]), 1)) + 0.18
		var radius := 5.5 + float(spawn_index % 2) * 2.4
		e.position = Vector3(center.x + cos(angle) * radius, 0.5, center.z + sin(angle) * radius)
		e.add_to_group("quest_enemies")
		if party_coop():
			e.network_quest_id = "%d:%s:%d:%d" % [NetworkSession.local_party_leader(), str(d["id"]), step_index(), spawn_index]
			e.network_quest_party_leader = NetworkSession.local_party_leader()
			e.network_quest_mirror = not multiplayer.is_server()
		world.add_child(e)

# ------------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	if player == null or GameData.quest_active == "":
		return
	if GameData.quest_state == "active" and objective != null:
		objective.update(delta)
	if beacon_label != null and is_instance_valid(beacon_label) and beacon != null and is_instance_valid(beacon):
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
	var steps: Array = d["steps"]
	var t := "QUEST: %s" % d["title"]
	if steps.size() > 1 and GameData.quest_state == "active":
		t += "  (%d/%d)" % [step_index() + 1, steps.size()]
	t += "\n"
	if GameData.quest_state == "ready":
		var giver: Dictionary = NPCS[d["giver"]]
		hud.quest_text = t + "Return to %s" % giver["name"]
		return
	hud.quest_text = t + (objective.hud_text() if objective != null else "")
