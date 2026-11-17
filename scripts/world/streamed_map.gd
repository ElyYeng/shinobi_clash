class_name StreamedMap
extends GameMap
## A big map cut into chunks by tools/map_chunks (chunks.json + c_<x>_<z>.gltf + backdrop.gltf + tex/),
## streamed around the player: the backdrop is always loaded, chunks within LOAD_RADIUS load on a
## background thread, chunks past UNLOAD_RADIUS are freed. Collision is built one mesh per frame
## so a chunk arriving doesn't hitch. Used for the main map when DIR exists (local test map,
## kept out of git - see .gitignore).

const DIR := "res://maps/_test_map/"
const LOAD_RADIUS := 800.0     # (covers the whole village from anywhere inside it)
const UNLOAD_RADIUS := 1000.0
const LIGHTING_FROM := "res://maps/konoha_greybox.tscn"   # sky, sun, fog, shadows: same as Konoha
const CHECK_EVERY := 0.25

var cell := 150.0
var spawn_point := Vector3.ZERO
var _chunks: Array = []            # entries from chunks.json
var _loaded := {}                  # file -> Node3D (instanced chunk)
var _pending := {}                 # file -> true (threaded load in flight)
var _collision_queue: Array = []   # MeshInstance3D waiting for collision
var _check_t := 0.0
var _focus: Node3D
static var toon := true   # (tests can turn the toon pass off)

## Is the test map on this PC? (chunks.json present)
static func available() -> bool:
	return FileAccess.file_exists(DIR + "chunks.json")

func _init() -> void:
	name = "StreamedMap"
	play_half = 3000.0
	spawn_area = Rect2(-60, -60, 120, 120)
	var f := FileAccess.open(DIR + "chunks.json", FileAccess.READ)
	if f == null:
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	cell = float(d.get("cell", 150.0))
	_chunks = d.get("chunks", [])
	var sp: Array = d.get("spawn", [0.0, 0.0, 0.0])
	spawn_point = Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	var heights := Node3D.new()   # answers height_at / prepare_spawn like the old WorldTerrain did
	heights.name = "WorldTerrain"
	heights.set_script(_HeightProbe)
	add_child(heights)
	if d.has("backdrop"):
		_instance_chunk(str(d["backdrop"]["file"]), load(DIR + str(d["backdrop"]["file"])) as PackedScene)

func _ready() -> void:
	super._ready()
	_take_lighting()
	var markers := Node3D.new()
	markers.name = "Markers"
	add_child(markers)
	var m := Marker3D.new()
	m.name = "PlayerSpawn"
	markers.add_child(m)
	m.position = spawn_point + Vector3(0, 2.0, 0)

## The map has no lighting of its own: borrow Konoha's Environment group (WorldEnvironment +
## Sun), so both maps look the same and editing Konoha's lighting changes this one too.
func _take_lighting() -> void:
	var ps := load(LIGHTING_FROM) as PackedScene if ResourceLoader.exists(LIGHTING_FROM) else null
	if ps == null:
		return
	var konoha := ps.instantiate()
	var env := konoha.get_node_or_null("Environment")
	if env != null:
		konoha.remove_child(env)
		env.owner = null
		for c in env.find_children("*", "", true, false):
			c.owner = null
		add_child(env)
		var we := env.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if we != null and we.environment != null:   # Konoha's fog is tuned for a small map: thinner here
			var e := we.environment.duplicate() as Environment
			e.fog_density *= 0.3
			e.fog_aerial_perspective = 0.2
			e.volumetric_fog_density *= 0.4
			we.environment = e
	konoha.free()

## Stream around this node (the player). Without one, the spawn point is the centre.
func set_focus(node: Node3D) -> void:
	_focus = node

func _process(delta: float) -> void:
	if not _collision_queue.is_empty():   # one mesh's collision per frame
		_add_collision(_collision_queue.pop_front())
	for file in _pending.keys():
		var st := ResourceLoader.load_threaded_get_status(DIR + file)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_pending.erase(file)
			_instance_chunk(file, ResourceLoader.load_threaded_get(DIR + file) as PackedScene)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending.erase(file)
			push_warning("[StreamedMap] could not load " + file)
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY
	var p := _focus.global_position if is_instance_valid(_focus) else spawn_point
	for c in _chunks:
		var file := str(c["file"])
		var d := _dist_to(c, p)
		if d < LOAD_RADIUS and not _loaded.has(file) and not _pending.has(file):
			if ResourceLoader.load_threaded_request(DIR + file) == OK:
				_pending[file] = true
		elif d > UNLOAD_RADIUS and _loaded.has(file):
			(_loaded[file] as Node).queue_free()
			_loaded.erase(file)

## Loads every chunk near `pos` right now, with collision (so the player doesn't fall through).
func load_around_now(pos: Vector3, radius := 200.0) -> void:
	for c in _chunks:
		var file := str(c["file"])
		if _dist_to(c, pos) < radius and not _loaded.has(file):
			_instance_chunk(file, load(DIR + file) as PackedScene, true)

func _dist_to(c: Dictionary, p: Vector3) -> float:   # horizontal distance from p to the chunk's box
	var mn: Array = c["min"]
	var mx: Array = c["max"]
	var dx := maxf(maxf(float(mn[0]) - p.x, 0.0), p.x - float(mx[0]))
	var dz := maxf(maxf(float(mn[2]) - p.z, 0.0), p.z - float(mx[2]))
	return Vector2(dx, dz).length()

func _instance_chunk(file: String, ps: PackedScene, collide_now := false) -> void:
	if ps == null or _loaded.has(file):
		return
	var inst := ps.instantiate() as Node3D
	inst.name = file.get_basename()
	add_child(inst)
	_loaded[file] = inst
	if toon:
		CharToon.apply(inst)   # the game's toon look on the chunk too
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		if collide_now:
			_add_collision(n)
		else:
			_collision_queue.append(n)

func _add_collision(n: Variant) -> void:
	if not is_instance_valid(n):
		return
	var mi := n as MeshInstance3D
	if mi.mesh == null:
		return
	var shape := mi.mesh.create_trimesh_shape()
	if shape == null:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)

## Ground height under a point (raycast against what's loaded; the spawn height if nothing is).
func height_at(x: float, z: float) -> float:
	if not is_inside_tree():
		return spawn_point.y
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 2000.0, z), Vector3(x, -2000.0, z))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else spawn_point.y

const _HeightProbe := preload("res://scripts/world/streamed_map_heights.gd")
