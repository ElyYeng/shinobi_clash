@tool
extends Node3D
## Infinite, deterministic chunked terrain for the open-world map.
## Chunks are generated around the local player and discarded when they are far away.

@export_group("World Generation")
@export var chunk_size: float = 64.0
@export_range(1, 6, 1) var view_distance: int = 2
@export_range(8, 64, 1) var resolution: int = 24
@export var world_seed: int = 48127:
	set(value):
		world_seed = value
		if is_inside_tree():
			_configure_noise()

@export_group("Terrain Shape")
@export_range(0.0005, 0.02, 0.0001) var noise_frequency: float = 0.0032
@export_range(1, 8, 1) var noise_octaves: int = 4
@export_range(1.0, 30.0, 0.5) var hill_height: float = 11.0
@export_range(0.0, 8.0, 0.1) var detail_height: float = 1.6
@export_range(0.0, 10.0, 0.1) var ridge_height: float = 2.2
@export_range(-10.0, 10.0, 0.1) var base_height: float = 0.0

@export_group("Grass Appearance")
@export_range(4.0, 32.0, 0.5) var grass_tile_size: float = 11.0
@export_range(0.0, 1.0, 0.05) var grass_detail_strength: float = 0.65

@export_group("Editor Preview")
@export var show_editor_preview: bool = true
@export_range(0, 5, 1) var preview_radius: int = 1
@export_tool_button("Generate Editor Preview", "World") var generate_preview_action = generate_editor_preview
@export_tool_button("Clear Editor Preview", "Clear") var clear_preview_action = clear_editor_preview

var _noise := FastNoiseLite.new()
var _chunks: Dictionary = {}
var _queued: Array[Vector2i] = []
var _queued_lookup: Dictionary = {}
var _last_center := Vector2i(2147483647, 2147483647)
var _player: Node3D
var _material := StandardMaterial3D.new()
const TREE_SCENE: PackedScene = preload("res://maps/tree1.glb")
const GRASS_TEXTURE_DATA = preload("res://grass_texture_data.gd")

func _ready() -> void:
	_configure_noise()
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color.WHITE
	_material.roughness = 1.0
	_material.albedo_texture = _make_grass_texture()
	_material.uv1_scale = Vector3.ONE
	# Prevent the generated terrain from disappearing because of triangle winding.
	_material.cull_mode = BaseMaterial3D.CULL_BACK
	if Engine.is_editor_hint():
		if show_editor_preview:
			generate_editor_preview()
	else:
		# Editor preview chunks are saved with the scene so they remain visible
		# after reopening it. Remove those baked preview nodes before runtime streaming.
		for child in get_children():
			if child.has_meta("editor_terrain_preview"):
				child.free()
		_chunks.clear()

func _configure_noise() -> void:
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = noise_octaves
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.48

func _make_grass_texture() -> Texture2D:
	# Decode the painterly seamless tile, then create mipmaps for a clean view
	# at distance. The texture repeats in world space across streamed chunks.
	var image := Image.new()
	var png_bytes := Marshalls.base64_to_raw(GRASS_TEXTURE_DATA.PNG_BASE64)
	var error := image.load_png_from_buffer(png_bytes)
	if error != OK:
		push_error("[WorldTerrain] Could not load the embedded grass texture: %s" % error)
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func height_at(world_x: float, world_z: float) -> float:
	var broad := _noise.get_noise_2d(world_x, world_z)
	var detail := _noise.get_noise_2d(world_x * 2.15 + 913.0, world_z * 2.15 - 427.0)
	var ridge := 1.0 - absf(_noise.get_noise_2d(world_x * 0.72 - 180.0, world_z * 0.72 + 290.0))
	return broad * hill_height + detail * detail_height + pow(ridge, 3.0) * ridge_height + base_height

func generate_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	clear_editor_preview()
	_configure_noise()
	var root := get_tree().edited_scene_root
	for z in range(-preview_radius, preview_radius + 1):
		for x in range(-preview_radius, preview_radius + 1):
			var coord := Vector2i(x, z)
			_create_chunk(coord)
			var chunk: Node3D = _chunks[coord]
			_mark_editor_owned(chunk, root)
			chunk.set_meta("editor_terrain_preview", true)
	notify_property_list_changed()

func clear_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	for child in get_children():
		if child.has_meta("editor_terrain_preview"):
			remove_child(child)
			child.free()
	_chunks.clear()
	_queued.clear()
	_queued_lookup.clear()

func _mark_editor_owned(node: Node, owner_node: Node) -> void:
	if owner_node == null:
		return
	node.owner = owner_node
	for child in node.get_children():
		_mark_editor_owned(child, owner_node)

## Builds the spawn chunk before the player enters its first physics frame.
func prepare_spawn(world_position: Vector3) -> void:
	var center := Vector2i(
		floori(world_position.x / chunk_size),
		floori(world_position.z / chunk_size)
	)
	if not _chunks.has(center):
		_create_chunk(center)
	_last_center = center
	for ring in range(1, view_distance + 1):
		for z in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(z)) != ring:
					continue
				var coord := center + Vector2i(x, z)
				if not _chunks.has(coord) and not _queued_lookup.has(coord):
					_queued.append(coord)
					_queued_lookup[coord] = true

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return

	var center := Vector2i(
		floori(_player.global_position.x / chunk_size),
		floori(_player.global_position.z / chunk_size)
	)
	if center != _last_center:
		_last_center = center
		if not _chunks.has(center):
			_create_chunk(center)
		for ring in range(0, view_distance + 1):
			for z in range(-ring, ring + 1):
				for x in range(-ring, ring + 1):
					if maxi(absi(x), absi(z)) != ring:
						continue
					var coord := center + Vector2i(x, z)
					if not _chunks.has(coord) and not _queued_lookup.has(coord):
						_queued.append(coord)
						_queued_lookup[coord] = true

	# Build only a couple of chunks per frame to avoid a large generation hitch.
	var built := 0
	while not _queued.is_empty() and built < 2:
		var coord: Vector2i = _queued.pop_front()
		_queued_lookup.erase(coord)
		if maxi(absi(coord.x - center.x), absi(coord.y - center.y)) <= view_distance and not _chunks.has(coord):
			_create_chunk(coord)
			built += 1

	# Keep a small buffer around the active view; terrain is regenerated deterministically.
	for key in _chunks.keys():
		var coord: Vector2i = key
		if maxi(absi(coord.x - center.x), absi(coord.y - center.y)) > view_distance + 1:
			var old: Node = _chunks[coord]
			_chunks.erase(coord)
			old.queue_free()

func _create_chunk(coord: Vector2i) -> void:
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk.position = Vector3(coord.x * chunk_size, 0.0, coord.y * chunk_size)
	add_child(chunk)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var side := resolution + 1
	var origin_x := float(coord.x) * chunk_size
	var origin_z := float(coord.y) * chunk_size

	for z in range(side):
		for x in range(side):
			var lx := float(x) / float(resolution) * chunk_size
			var lz := float(z) / float(resolution) * chunk_size
			var wx := origin_x + lx
			var wz := origin_z + lz
			var h := height_at(wx, wz)
			verts.append(Vector3(lx, h, lz))
			# World-aligned UVs keep the grass pattern continuous across chunk borders.
			uvs.append(Vector2(wx / grass_tile_size, wz / grass_tile_size))

			var sample := 0.8
			var normal := Vector3(
				height_at(wx - sample, wz) - height_at(wx + sample, wz),
				sample * 2.0,
				height_at(wx, wz - sample) - height_at(wx, wz + sample)
			).normalized()
			normals.append(normal)

			var slope := 1.0 - normal.y
			var grass := Color(1.0, 1.0, 0.96).lerp(Color(0.88, 0.98, 0.82), grass_detail_strength * 0.45)
			grass = grass.lerp(Color(0.96, 1.0, 0.88), clampf((h + 5.0) / 14.0, 0.0, 1.0) * 0.12)
			var rock := Color(0.76, 0.80, 0.74)
			var color := grass.lerp(rock, smoothstep(0.28, 0.62, slope))
			if h > 10.0:
				color = color.lerp(Color(0.62, 0.63, 0.55), smoothstep(10.0, 15.0, h) * 0.65)
			colors.append(color)

	for z in range(resolution):
		for x in range(resolution):
			var a := z * side + x
			var b := a + 1
			var c := a + side
			var d := c + 1
			# Clockwise from above so the visible face points upward.
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var visual := MeshInstance3D.new()
	visual.name = "TerrainMesh"
	visual.mesh = mesh
	visual.material_override = _material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk.add_child(visual)

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var collision := CollisionShape3D.new()
	var terrain_shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	# Generated terrain is a thin, single surface. Accept collision from either
	# side so triangle winding can never let the player fall through it.
	terrain_shape.backface_collision = true
	collision.shape = terrain_shape
	body.add_child(collision)
	chunk.add_child(body)

	_scatter_trees(chunk, coord)
	_chunks[coord] = chunk

func _scatter_trees(chunk: Node3D, coord: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_seed) + coord.x * 73856093 + coord.y * 19349663
	var npc_clearance := [Vector2(-30.0, -95.0), Vector2(0.0, -14.0), Vector2(115.0, -105.0), Vector2(9.0, -9.0), Vector2(75.0, 45.0), Vector2(-65.0, 35.0)]
	for i in range(7):
		var lx := rng.randf_range(5.0, chunk_size - 5.0)
		var lz := rng.randf_range(5.0, chunk_size - 5.0)
		var wx := float(coord.x) * chunk_size + lx
		var wz := float(coord.y) * chunk_size + lz
		# Keep the spawn clearing and quest-giver locations open and readable.
		if Vector2(wx, wz).length() < 27.0:
			continue
		var near_npc := false
		for npc_pos in npc_clearance:
			if Vector2(wx - npc_pos.x, wz - npc_pos.y).length() < 9.0:
				near_npc = true
				break
		if near_npc:
			continue
		var tree := StaticBody3D.new()
		tree.name = "Tree_%02d" % i
		tree.position = Vector3(lx, height_at(wx, wz), lz)
		tree.rotation.y = rng.randf_range(0.0, TAU)
		var scale_value := rng.randf_range(7.0, 10.0)
		var model := TREE_SCENE.instantiate() as Node3D
		if model == null:
			continue
		model.scale = Vector3.ONE * scale_value
		tree.add_child(model)
		var trunk := CollisionShape3D.new()
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = 0.55
		trunk_shape.height = 3.2
		trunk.shape = trunk_shape
		trunk.position.y = 1.6
		tree.add_child(trunk)
		chunk.add_child(tree)
