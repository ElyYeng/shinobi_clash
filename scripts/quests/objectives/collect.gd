extends QuestObjective
## Pick up `count` `item_name`s scattered within `radius` of `pos`. Each one is a glowing scroll
## on the ground; walk over it to take it. Already-collected ones don't come back after a reload.
## Harder than it sounds: they're spread wide, thieves guard the area, and each item jumps away
## (twice) when you get close - catch it on the third try.

const PICK_RANGE := 1.6
const SPOOK_RANGE := 4.5   # this close and an item still able to dodge jumps away
const DODGES := 2
var _items: Array[Node3D] = []
var _center := Vector3.ZERO
var _spread := 14.0

func start() -> void:
	quests.make_beacon(step["pos"], str(step["place"]) if str(step["place"]) != "" else str(step["item_name"]))
	var n := int(step["count"])
	var center: Vector3 = step["pos"]
	var spread := maxf(float(step["radius"]) * 2.0, 14.0)
	_center = center
	_spread = spread
	_guards(n)
	for i in range(progress(), n):   # fixed spots, so every party member sees the same ones
		var a := TAU * float(i) / float(n) + 0.7 * float(i % 3)
		var r := spread * (0.45 + 0.5 * float((i * 7) % 5) / 4.0)
		var item := _make_item()
		item.position = _open_spot(center, a, r)
		quests.world.add_child(item)
		_snap(item)
		item.set_meta("dodges", DODGES)
		item.set_meta("i", i)
		_items.append(item)

func update(delta: float) -> void:
	for item in _items.duplicate():
		if not is_instance_valid(item):
			_items.erase(item)
			continue
		item.rotate_y(delta * 1.6)
		var dodges := int(item.get_meta("dodges", 0))
		if dodges > 0 and not item.has_meta("hopping") and flat_distance(item.global_position) < SPOOK_RANGE:
			_hop(item, dodges)
			continue
		if not item.has_meta("hopping") and flat_distance(item.global_position) < PICK_RANGE and absf(player().global_position.y - item.global_position.y) < 3.0:
			_items.erase(item)
			Fx.puff(quests.world, item.global_position + Vector3.UP * 0.6, Color(1.0, 0.9, 0.5, 0.8), 1.2)
			Sfx.play(player(), "poof", -6.0)
			item.queue_free()
			set_progress(progress() + 1)
			quests.hud.toast("%s  %d / %d" % [step["item_name"], progress(), int(step["count"])])
			if progress() >= int(step["count"]):
				complete()
				return

func stop() -> void:
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()

func hud_text() -> String:
	return text_or("Collect %ss: %d / %d" % [step["item_name"], progress(), int(step["count"])])

## Thieves guarding the area (a few, tougher with your level). They don't count for anything -
## they just make the gathering a fight.
func _guards(n: int) -> void:
	if progress() >= n:
		return
	var st := step.duplicate()
	var g := clampi(n / 2, 2, 5)
	st["count"] = g
	st["enemy_health"] = 45.0 + GameData.level * 14.0
	st["enemy_damage"] = 6.0 + GameData.level * 0.5
	st["enemy_speed"] = minf(6.0, 4.2 + GameData.level * 0.03)
	st["enemy_color"] = Color(0.2, 0.22, 0.28)
	st["enemy_band"] = Color(0.3, 0.3, 0.35)
	quests.spawn_enemies(g, st, false, 500)

## The item leaps away to another spot (same spots for everyone: picked from its index).
func _hop(item: Node3D, dodges: int) -> void:
	item.set_meta("dodges", dodges - 1)
	item.set_meta("hopping", true)
	var i := int(item.get_meta("i", 0))
	var to := _open_spot(_center, 1.3 + i * 2.1 + dodges * 2.4, _spread * (0.5 + 0.12 * dodges))
	var from := item.global_position
	Fx.puff(quests.world, from + Vector3.UP * 0.5, Color(1.0, 0.9, 0.5, 0.7), 0.8)
	Sfx.play(player(), "dash", -10.0)
	var tw := item.create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(item):
			item.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 4.0, 0.0, 1.0, 0.7)
	tw.tween_callback(func() -> void:
		if is_instance_valid(item):
			_snap(item)
			item.remove_meta("hopping"))

## A small rolled scroll with a soft glow and a light beam so it's easy to spot.
func _make_item() -> Node3D:
	var root := Node3D.new()
	var roll := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.6
	roll.mesh = cyl
	roll.rotation.z = PI * 0.5
	roll.position.y = 0.45
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.88, 0.66)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 0.6
	roll.material_override = mat
	root.add_child(roll)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.13
	bm.bottom_radius = 0.13
	bm.height = 0.12
	band.mesh = bm
	band.rotation.z = PI * 0.5
	band.position.y = 0.45
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.75, 0.12, 0.08)
	band.material_override = bmat
	root.add_child(band)
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.05
	bc.bottom_radius = 0.25
	bc.height = 3.0
	beam.mesh = bc
	beam.position.y = 1.5
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(1.0, 0.9, 0.45, 0.22)
	beam.material_override = beam_mat
	root.add_child(beam)
	return root

## Puts the item on the ground (terrain or floor) under it.
## A spot on open ground near (angle a, radius r) around `center` - never inside a building's
## footprint (else the item ends up on a roof or a wall). Deterministic, so a party agrees.
func _open_spot(center: Vector3, a: float, r: float) -> Vector3:
	var gm = quests.world.get("map")
	for k in 16:
		var aa := a + float(k) * 0.9
		var rr := r * (1.0 - 0.06 * float(k))
		var p := Vector3(center.x + cos(aa) * rr, 0.0, center.z + sin(aa) * rr)
		if not (gm is GameMap) or not (gm as GameMap).blocked(p, 1.2):
			return p
	return center

func _snap(item: Node3D) -> void:
	var space := quests.world.get_world_3d().direct_space_state
	var from := item.global_position + Vector3.UP * 2.5   # from just above the ground, not the rooftops
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0))
	if not hit.is_empty():
		item.global_position.y = (hit["position"] as Vector3).y
