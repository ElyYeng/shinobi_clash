class_name Quests
extends Node
## Quest data + tracking for the open world. One quest can be active at a time.
## Progress is saved through GameData. Add NPCs / quests by editing the two tables below.
## Quest types:  goto (walk to a beacon) | deliver (talk to another NPC) |
##               kill (defeat bandits at a camp) | kurama (beat the Kurama boss fight from the menu)

signal changed

const NPCS := {
	"elder": {"name": "Elder Hayate", "pos": Vector3(0, 0, -14), "color": Color(0.4, 0.25, 0.55), "band": Color(0.9, 0.85, 0.65),
		"greet": "Peace has held for many years. Walk freely, shinobi."},
	"scout": {"name": "Scout Mika", "pos": Vector3(75, 0, 45), "color": Color(0.2, 0.5, 0.35), "band": Color(0.8, 0.8, 0.9),
		"greet": "I keep watch over the eastern fields. Nothing gets past me."},
	"trainer": {"name": "Instructor Daichi", "pos": Vector3(-65, 0, 35), "color": Color(0.8, 0.45, 0.1), "band": Color(0.2, 0.2, 0.25),
		"greet": "Strength is built one rep at a time."},
	"courier": {"name": "Courier Rin", "pos": Vector3(-30, 0, -95), "color": Color(0.25, 0.45, 0.8), "band": Color(0.95, 0.95, 0.95),
		"greet": "Fast feet, light bag. That is the courier's way."},
	"hermit": {"name": "Hermit Sora", "pos": Vector3(115, 0, -105), "color": Color(0.55, 0.15, 0.15), "band": Color(0.9, 0.7, 0.2),
		"greet": "The wind carries old stories. Some of them still growl."},
}

const DEFS := {
	"first_steps": {"title": "First Steps", "giver": "elder", "req": "", "type": "goto",
		"pos": Vector3(70, 0, -60), "place": "Old Training Stone", "radius": 5.0, "reward": 1,
		"offer": "Young one, there is an old training stone to the north-east. Visit it and feel the chakra of those who trained before you.",
		"remind": "The Old Training Stone is north-east of here. Follow the golden beam of light.",
		"turn": "You made it! The old ways live on in you. Take this - a bloodline spin."},
	"letter": {"title": "A Letter for Mika", "giver": "elder", "req": "first_steps", "type": "deliver",
		"target": "scout", "reward": 1,
		"offer": "Scout Mika waits in the east with a letter that needs her answer. Deliver my message to her and come back.",
		"remind": "Scout Mika is out in the eastern fields. Find her and speak to her.",
		"deliver_text": "A message from the Elder? ...Hm. Tell him I understand. The bandits are a bigger problem than he thinks.",
		"turn": "She understood? Good. Here is something for your trouble."},
	"bandits": {"title": "Bandit Trouble", "giver": "scout", "req": "letter", "type": "kill",
		"count": 5, "pos": Vector3(-120, 0, -70), "reward": 2,
		"offer": "Bandits set up camp far to the north-west. Drive off five of them and the roads will be safe again.",
		"remind": "The bandit camp is marked by the golden beam, far to the north-west. Defeat five of them.",
		"turn": "Five less to worry about. The roads are safe again - thank you!"},
	"drills": {"title": "Chakra Drills", "giver": "trainer", "req": "letter", "type": "kill",
		"count": 8, "pos": Vector3(120, 0, 100), "reward": 2,
		"offer": "Talk is cheap. Prove yourself against eight sparring shinobi waiting in the south-east.",
		"remind": "The sparring shinobi wait in the south-east. Defeat eight of them.",
		"turn": "Eight down. Your footwork improved already. Take another spin."},
	"parcel": {"title": "Lost Parcel", "giver": "courier", "req": "", "type": "goto",
		"pos": Vector3(170, 0, 140), "place": "Dropped Parcel", "radius": 5.0, "reward": 1,
		"offer": "I dropped a parcel somewhere far to the south-east and I cannot leave my post. Could you find it?",
		"remind": "Follow the beam to the south-east. The parcel should be right under it.",
		"turn": "You found it?! You are a lifesaver. A spin for your trouble!"},
	"nine_tails": {"title": "Legend of the Nine Tails", "giver": "hermit", "req": "bandits", "type": "kurama",
		"reward": 5,
		"offer": "Long ago a great fox with nine tails was sealed away. If you are brave enough, go and face it - pick the Kurama Boss Fight (menu M > Travel > Switch Mode, or the main menu) - then come tell me how it ended.",
		"remind": "Open the menu (M), go to Travel and use Switch Mode (or Main-Menu) to reach the Kurama Boss Fight. Defeat the beast, then come back to me.",
		"turn": "You defeated the Nine-Tailed Beast?! Then the legends were true. This is yours."},
}

var player: Player
var hud: HUD
var world: Node3D
var beacon: Node3D = null
var beacon_label: Label3D = null
var _last_kills := 0

func setup(p: Player, h: HUD, w: Node3D) -> void:
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
		player.gain_xp(GameData.XP_QUEST)
	GameData.quests_done.append(GameData.quest_active)
	GameData.quest_active = ""
	GameData.quest_state = ""
	GameData.quest_progress = 0
	GameData.save()
	_clear_objective()
	hud.toast("Quest complete: %s   +%d spin%s  (spin at the main menu)" % [d["title"], reward, "" if reward == 1 else "s"])
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
			_spawn_bandits(int(d["count"]) - GameData.quest_progress, d["pos"])

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

func _spawn_bandits(n: int, center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in maxi(n, 0):
		var e := Enemy.new()
		e.health = 45.0
		e.speed = 4.2
		e.damage = 6.0
		e.aggro_range = 20.0
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
		"deliver":
			var target: Dictionary = NPCS[d["target"]]
			hud.quest_text = t + "Speak to %s" % target["name"]
		"kurama":
			hud.quest_text = t + "Defeat Kurama\n(Menu > Kurama Boss Fight)"
