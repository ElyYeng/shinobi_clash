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
@export var water_alpha := 0.85

var _floor_y := INF
var _lo := Vector2(INF, INF)
var _hi := Vector2(-INF, -INF)
var _spot := Vector3.INF

## A standing place on the ground: the PlayerSpawn marker's x/z if there is ground under it, else
## the first solid flat ground found on a grid over the map (so a re-imported / moved map never
## drops you through the floor).
func _safe_spot() -> Vector3:
	var space := get_world_3d().direct_space_state
	var cands: Array[Vector2] = []
	var marker := get_parent().get_node_or_null("Markers/PlayerSpawn") as Node3D if get_parent() != null else null
	if marker != null:
		cands.append(Vector2(marker.global_position.x, marker.global_position.z))
	if _lo.x < INF:
		cands.append((_lo + _hi) * 0.5)
		for i in 15:
			for j in 15:
				cands.append(Vector2(lerpf(_lo.x, _hi.x, (i + 0.5) / 15.0), lerpf(_lo.y, _hi.y, (j + 0.5) / 15.0)))
	for c in cands:
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, _floor_y + 2000.0, c.y), Vector3(c.x, _floor_y - 50.0, c.y), 1)
		var h := space.intersect_ray(q)
		if not h.is_empty() and (h["normal"] as Vector3).y > 0.9:
			return (h["position"] as Vector3) + Vector3.UP * 1.5
	return Vector3.INF

func _physics_process(_delta: float) -> void:
	if _floor_y == INF:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null and pl.global_position.y < _floor_y - 25.0:   # fell through: back onto the ground
		if _spot == Vector3.INF:
			_spot = _safe_spot()
		if _spot != Vector3.INF:
			pl.global_position = _spot
			if pl is CharacterBody3D:
				(pl as CharacterBody3D).velocity = Vector3.ZERO

var _noise_tex: NoiseTexture2D
var dirt_tex: Texture2D

## Tiling-free ground (shaders/akatsuki_ground.gdshader) from a surface's own texture.
func _ground_material(src: BaseMaterial3D, dirt: Texture2D) -> ShaderMaterial:
	if _noise_tex == null:
		var fn := FastNoiseLite.new()
		fn.frequency = 0.01
		fn.fractal_octaves = 3
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.width = 512
		_noise_tex.height = 512
		_noise_tex.seamless = true
		_noise_tex.noise = fn
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/akatsuki_ground.gdshader")
	m.set_shader_parameter("tex_a", src.albedo_texture)
	m.set_shader_parameter("tex_b", dirt if dirt != null else src.albedo_texture)
	m.set_shader_parameter("use_b", 1.0 if dirt != null else 0.0)
	m.set_shader_parameter("noise", _noise_tex)
	m.set_shader_parameter("tint", src.albedo_color)
	m.set_shader_parameter("uv_scale", Vector2(src.uv1_scale.x, src.uv1_scale.y))
	return m

func _ready() -> void:
	_dress.call_deferred()
	if get_parent() != null:   # the minimap photographs the canyon, not the empty square round the origin
		get_parent().set_meta("minimap_center", Vector2(-76, 155))
		get_parent().set_meta("minimap_half", 500.0)
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
	for mi0: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):   # PatchGrass' texture = the dirt mixed into Grass
		if mi0.mesh != null:
			for s0 in mi0.mesh.get_surface_count():
				var m0 := mi0.mesh.surface_get_material(s0)
				if m0 is BaseMaterial3D and m0.resource_name.to_lower() == "patchgrass":
					dirt_tex = (m0 as BaseMaterial3D).albedo_texture
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
			if mat is BaseMaterial3D and (nm.contains("grass") or nm.contains("sand") or nm.contains("path")):
				mi.set_surface_override_material(s, _ground_material(mat as BaseMaterial3D, dirt_tex if nm == "grass" else null))
			if nm.contains("foliage") and mat is BaseMaterial3D:   # trees: no shiny highlights
				(mat as BaseMaterial3D).metallic_specular = 0.0
				(mat as BaseMaterial3D).roughness = 1.0
			if nm.contains("water") or not (nm.contains("foliage") or nm.contains("leaf") or nm.contains("tree")):   # everything but cut-out plants is solid (rock, path, sand...)
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
		for v3 in faces:   # the ground's extent (for the fall rescue below)
			_floor_y = minf(_floor_y, v3.y)
			_lo.x = minf(_lo.x, v3.x); _lo.y = minf(_lo.y, v3.z)
			_hi.x = maxf(_hi.x, v3.x); _hi.y = maxf(_hi.y, v3.z)
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

# ---------------------------------------------------------------- dressing: rocks + grass
@export_group("Dressing")
@export var dress_seed := 7
@export var rock_count := 90
@export var grass_count := 2500
@export var dress_min := Vector2(-560, -90)    ## scatter area (x, z) ...
@export var dress_max := Vector2(410, 400)     ## ... the canyon floor is picked by ray casts

func _dress() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var marker := get_parent().get_node_or_null("Markers/PlayerSpawn") as Node3D if get_parent() != null else null
	var spot := _safe_spot()   # keep the spawn marker on the ground for next time
	if marker != null and spot != Vector3.INF and absf(marker.global_position.y - spot.y) > 4.0:
		marker.global_position = spot
	var rng := RandomNumberGenerator.new()
	rng.seed = dress_seed
	var space := get_world_3d().direct_space_state
	var rocks: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var tries := 0
	while (rocks.size() < rock_count or grass.size() < grass_count) and tries < 12000:
		tries += 1
		var x := rng.randf_range(dress_min.x, dress_max.x)
		var z := rng.randf_range(dress_min.y, dress_max.y)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -50, z), 1)
		var h := space.intersect_ray(q)
		if h.is_empty() or (h["normal"] as Vector3).y < 0.9:
			continue
		var p: Vector3 = h["position"]
		if p.y > 40.0:   # only the canyon floor; the plateaus already have trees
			continue
		var wq := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -50, z), 512)
		var wh := space.intersect_ray(wq)
		if not wh.is_empty() and float(wh["position"].y) > p.y - 0.2:
			continue   # under water
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		if rocks.size() < rock_count and rng.randf() < 0.05:
			var s := rng.randf_range(0.6, 2.6)
			var b := yaw * Basis.from_scale(Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 1.0), s * rng.randf_range(0.8, 1.4)))
			rocks.append(Transform3D(b, p + Vector3.UP * s * 0.1))
		elif grass.size() < grass_count:
			var g := rng.randf_range(0.7, 1.5)
			grass.append(Transform3D(yaw * Basis.from_scale(Vector3(g, g * rng.randf_range(0.8, 1.6), g)), p))
	_multimesh("Rocks", _rock_mesh(), rocks, Color("#8b7a68"), 0.95)
	_multimesh("Grass", _grass_mesh(), grass, Color("#9aa65a"), 0.8)

func _multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D], col: Color, rough: float) -> void:
	if xforms.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if node_name == "Grass" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)

static func _rock_mesh() -> ArrayMesh:
	var m := CylinderMesh.new()   # a chunky low-poly boulder
	m.top_radius = 0.45
	m.bottom_radius = 0.9
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 1
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.set_smooth_group(-1)   # flat shaded
	st.generate_normals()
	return st.commit()

static func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 7:   # a tuft: a handful of leaning blades
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		var side := d.cross(Vector3.UP) * 0.05
		var base := d * rng.randf_range(0.0, 0.25)
		var tip := base + d * rng.randf_range(0.05, 0.2) + Vector3.UP * rng.randf_range(0.4, 0.8)
		st.set_color(Color(0.55, 0.5, 0.3))
		st.add_vertex(base - side)
		st.add_vertex(base + side)
		st.set_color(Color(1.0, 1.0, 0.8))
		st.add_vertex(tip)
	st.generate_normals()
	return st.commit()
