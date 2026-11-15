class_name AkatsukiMap
extends Node3D
## The Akatsuki canyon (assets/akatsuki/akatsuki.glb, the "Ground" node of maps/akatsuki.tscn).
## At load: solid colliders from the Rock + Path surfaces only (foliage cards and water never
## collide), marked `no_wall_walk` so chakra wall-walking can't stick to the cliffs, and the
## river gets the animated water shader. Tweak the water in the Inspector.

@export var water_tint := Color(0.55, 0.8, 1.0)
@export var water_flow := Vector2(0.05, 0.02)
@export var water_wave_height := 0.35
@export var water_wave_speed := 1.2
@export var water_alpha := 1.0
@export var spawn_point := Vector3(-74.3, -7.0, 126.0)   ## moves Markers/PlayerSpawn at load; edit the marker instead if you prefer

func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.set_meta("no_wall_walk", true)
	add_child(body)
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/akatsuki_water.gdshader")
	water.set_shader_parameter("tint", water_tint)
	water.set_shader_parameter("flow", water_flow)
	water.set_shader_parameter("wave_height", water_wave_height)
	water.set_shader_parameter("wave_speed", water_wave_speed)
	water.set_shader_parameter("alpha", water_alpha)
	var faces := PackedVector3Array()
	var wfaces := PackedVector3Array()
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := body.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var nm := (mat.resource_name if mat != null else "").to_lower()
			if nm.contains("water"):
				if mat is BaseMaterial3D:
					water.set_shader_parameter("base_tex", (mat as BaseMaterial3D).albedo_texture)
				mi.set_surface_override_material(s, water)
			if nm.contains("water") or nm.contains("rock") or nm.contains("path"):
				var out := wfaces if nm.contains("water") else faces
				var arr := mi.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx = arr[Mesh.ARRAY_INDEX]
				if idx == null or (idx as PackedInt32Array).is_empty():
					for i in v.size():
						out.append(xf * v[i])
				else:
					for i in (idx as PackedInt32Array):
						out.append(xf * v[i])
	if faces.size() >= 3:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	if wfaces.size() >= 3:   # the river surface: solid only while a player has chakra (layer 10)
		var wb := StaticBody3D.new()
		wb.name = "WaterSurface"
		wb.collision_layer = 512
		wb.collision_mask = 0
		wb.set_meta("water_walk", true)
		wb.set_meta("no_wall_walk", true)
		add_child(wb)
		var ws := ConcavePolygonShape3D.new()
		ws.set_faces(wfaces)
		var wc := CollisionShape3D.new()
		wc.shape = ws
		wb.add_child(wc)
	var marker := get_parent().get_node_or_null("Markers/PlayerSpawn") as Node3D if get_parent() != null else null
	if marker != null:
		marker.position = spawn_point
