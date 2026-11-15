class_name AkatsukiCrowd
extends Node3D
## Akatsuki members for the Akatsuki canyon: a few stand guard (decorative, no dialogue yet)
## and a few patrol on foot, following the ground. Cosmetic walkers (no collision). Built by
## main.gd for mode "akatsuki"; edit GUARDS / WALKERS to move or add people (x, z in map space).

const GUARDS := [   # [name, x, z, facing (deg), hair, hair colour, line]
	["Kisame", -52.0, 138.0, 200.0, "hair6", "#3A4A6B", "Water makes you strong. Walk on it, little leaf."],
	["Deidara", -75.0, 160.0, 150.0, "hair1", "#E6B52E", "Art is an explosion! ...Don't touch anything, hm."],
	["Hidan", -40.0, 165.0, 235.0, "hair2", "#C9C9D4", "Keep walking. Jashin-sama is watching."],
	["Sasori", -95.0, 140.0, 120.0, "hair3", "#8A2F25", "Waiting is a dull business. Make it quick."],
]
const WALKERS := [  # patrol loops: a list of [x, z] points
	[[-120.0, 150.0], [-20.0, 150.0], [-20.0, 175.0], [-120.0, 175.0]],
	[[-63.0, 120.0], [-63.0, 190.0]],
	[[-150.0, 130.0], [-90.0, 100.0], [-30.0, 120.0], [-90.0, 160.0]],
	[[0.0, 140.0], [60.0, 160.0], [30.0, 190.0]],
	[[-200.0, 160.0], [-140.0, 190.0], [-170.0, 120.0]],
]
const LOOK_NAMES := ["Akatsuki Member", "Akatsuki Scout", "Akatsuki Guard", "Akatsuki Courier", "Akatsuki Spy"]

static func look(hair: String, hair_color: String) -> Dictionary:
	var l: Dictionary = Hero.DEFAULT_APPEARANCE.duplicate()
	l["shirt_style"] = "shirt3"
	l["hair_style"] = hair
	l["hair_color"] = hair_color
	l["headband_state"] = "scratched"
	return l

## Adds the guards (as Npc) and the walkers under `map`.
static func populate(map: Node3D) -> void:   # (async: waits one physics frame so the ground exists)
	var crowd := AkatsukiCrowd.new()
	crowd.name = "AkatsukiCrowd"
	map.add_child(crowd)
	for g in GUARDS:
		var n := Npc.new()
		n.npc_id = "akatsuki_" + str(g[0]).to_lower()
		n.display_name = str(g[0])
		n.greeting = str(g[6])
		n.goodbye_label = "..."
		n.appearance = look(str(g[4]), str(g[5]))
		n.position = Vector3(float(g[1]), 30.0, float(g[2]))
		crowd.add_child(n)
		n.rotation.y = deg_to_rad(float(g[3]))
	var guards: Array[Node3D] = []
	for c in crowd.get_children():
		guards.append(c)
	for i in WALKERS.size():
		var w := Walker.new()
		w.route = WALKERS[i]
		w.seed_i = i
		w.position = Vector3(WALKERS[i][0][0], 30.0, WALKERS[i][0][1])
		crowd.add_child(w)
	await map.get_tree().physics_frame
	for n in guards:
		n.position.y = ground_y(n, n.position.x, n.position.z, 17.0)

## Drops a point onto the ground (ray from high above; solid terrain only).
static func ground_y(node: Node3D, x: float, z: float, fallback: float) -> float:
	var space := node.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -100.0, z), 1)
	var h := space.intersect_ray(q)
	return float(h["position"].y) if not h.is_empty() else fallback

class Walker extends Node3D:
	var route: Array = []
	var seed_i := 0
	var model: Node3D
	var _i := 1
	var _speed := 1.5
	var _pause := 0.0
	var _settled := false

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + seed_i
		_speed = rng.randf_range(1.2, 1.7)
		model = Npc.character_look(AkatsukiCrowd.look(["hair1", "hair2", "hair3", "hair6"][seed_i % 4], ["#1C1B24", "#E6B52E", "#6B4423", "#C9C9D4", "#8A2F25"][seed_i % 5]), "akatsuki_walker_%d" % seed_i)
		if model == null:
			model = Fx.make_ninja(Color(0.1, 0.1, 0.14), Color(0.8, 0.1, 0.1))
		add_child(model)
		var nl := Label3D.new()
		nl.text = AkatsukiCrowd.LOOK_NAMES[seed_i % AkatsukiCrowd.LOOK_NAMES.size()]
		nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nl.no_depth_test = true
		nl.font_size = 40
		nl.outline_size = 10
		nl.pixel_size = 0.005
		nl.position.y = 2.3
		add_child(nl)

	func _physics_process(delta: float) -> void:
		if model == null or route.is_empty():
			return
		if not _settled:   # first frame with physics: stand on the ground
			position.y = AkatsukiCrowd.ground_y(self, position.x, position.z, position.y)
			_settled = true
		if _pause > 0.0:
			_pause -= delta
			if _pause <= 0.0:
				Hero.play_move(model, Hero.move_state(_speed), _speed)
			return
		var goal := Vector3(float(route[_i][0]), position.y, float(route[_i][1]))
		var d := goal - position
		d.y = 0.0
		if d.length() < 0.5:
			_i = (_i + 1) % route.size()
			if randf() < 0.35:
				_pause = randf_range(1.5, 4.0)
				Hero.play_move(model, "idle", 0.0)
			return
		var dir := d.normalized()
		position += dir * _speed * delta
		position.y = lerpf(position.y, AkatsukiCrowd.ground_y(self, position.x, position.z, position.y), clampf(delta * 8.0, 0.0, 1.0))
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), clampf(delta * 6.0, 0.0, 1.0))
		Hero.play_move(model, Hero.move_state(_speed), _speed)
