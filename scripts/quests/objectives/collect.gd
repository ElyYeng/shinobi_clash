extends QuestObjective
## Pick up `count` `item_name`s scattered within `radius` of `pos`. Each one is a glowing scroll
## on the ground; walk over it to take it. Already-collected ones don't come back after a reload.

const PICK_RANGE := 1.6
var _items: Array[Node3D] = []

func start() -> void:
	quests.make_beacon(step["pos"], str(step["place"]) if str(step["place"]) != "" else str(step["item_name"]))
	var n := int(step["count"])
	var center: Vector3 = step["pos"]
	var spread := maxf(float(step["radius"]), 6.0)
	for i in range(progress(), n):   # fixed spots, so every party member sees the same ones
		var a := TAU * float(i) / float(n) + 0.7 * float(i % 3)
		var r := spread * (0.45 + 0.5 * float((i * 7) % 5) / 4.0)
		var item := _make_item()
		item.position = Vector3(center.x + cos(a) * r, 0.0, center.z + sin(a) * r)
		quests.world.add_child(item)
		_snap(item)
		_items.append(item)

func update(delta: float) -> void:
	for item in _items.duplicate():
		if not is_instance_valid(item):
			_items.erase(item)
			continue
		item.rotate_y(delta * 1.6)
		if flat_distance(item.global_position) < PICK_RANGE and absf(player().global_position.y - item.global_position.y) < 3.0:
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
func _snap(item: Node3D) -> void:
	var space := quests.world.get_world_3d().direct_space_state
	var from := item.global_position + Vector3.UP * 60.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 140.0))
	if not hit.is_empty():
		item.global_position.y = (hit["position"] as Vector3).y
