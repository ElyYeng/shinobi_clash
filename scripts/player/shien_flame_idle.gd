class_name ShienFlameIdle
extends Node
## Re-targets the imported Flame Idle glTF animation onto a character's Mixamo Skeleton3D.
## The source GLB is stored gzip-compressed to keep the repository asset small.

const SOURCE_PARTS := [
	"res://assets/character/FlameIdleParts/part_00.txt",
	"res://assets/character/FlameIdleParts/part_01.txt",
	"res://assets/character/FlameIdleParts/part_02.txt",
	"res://assets/character/FlameIdleParts/part_03.txt",
	"res://assets/character/FlameIdleParts/part_04.txt",
	"res://assets/character/FlameIdleParts/part_05.txt",
	"res://assets/character/FlameIdleParts/part_06.txt",
	"res://assets/character/FlameIdleParts/part_07.txt",
	"res://assets/character/FlameIdleParts/part_08.txt",
	"res://assets/character/FlameIdleParts/part_09.txt",
	"res://assets/character/FlameIdleParts/part_10.txt",
	"res://assets/character/FlameIdleParts/part_11.txt"
]

var _target: Skeleton3D
var _source_root: Node3D
var _source_player: AnimationPlayer
var _animation_name: StringName = &""
var _bone_tracks: Array[Dictionary] = []
var _active := false

static func attach(model: Node3D) -> ShienFlameIdle:
	if not is_instance_valid(model):
		return null
	var existing := model.get_node_or_null("ShienFlameIdle") as ShienFlameIdle
	if is_instance_valid(existing):
		return existing
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("[ShienFlameIdle] Character model has no Skeleton3D.")
		return null
	var driver := ShienFlameIdle.new()
	driver.name = "ShienFlameIdle"
	driver._target = skeletons[0] as Skeleton3D
	model.add_child(driver)
	if not driver._load_source():
		driver.queue_free()
		return null
	return driver

func _ready() -> void:
	process_priority = 100
	set_process(false)

func _load_source() -> bool:
	var encoded := ""
	for part_path in SOURCE_PARTS:
		if not FileAccess.file_exists(part_path):
			push_warning("[ShienFlameIdle] Missing animation data part: %s" % part_path)
			return false
		encoded += FileAccess.get_file_as_string(part_path).strip_edges()
	if encoded.is_empty():
		push_warning("[ShienFlameIdle] Compressed animation asset is empty.")
		return false
	var compressed := Marshalls.base64_to_raw(encoded)
	if compressed.is_empty():
		push_warning("[ShienFlameIdle] Could not decode the compressed animation asset.")
		return false
	# Read the uncompressed byte count from the final 4-byte GZIP trailer.
	# Use PackedByteArray.decompress() with FileAccess's GZIP compression mode.
	if compressed.size() < 18:
		push_warning("[ShienFlameIdle] Compressed animation data is too short to be a valid GZIP stream.")
		return false
	var uncompressed_size := int(compressed.decode_u32(compressed.size() - 4))
	if uncompressed_size <= 0:
		push_warning("[ShienFlameIdle] GZIP animation reports an invalid uncompressed size.")
		return false
	var bytes := compressed.decompress(uncompressed_size, FileAccess.COMPRESSION_GZIP)
	if bytes.is_empty():
		push_warning("[ShienFlameIdle] Could not decompress the animation asset.")
		return false

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var import_error := document.append_from_buffer(bytes, "", state)
	if import_error != OK:
		push_warning("[ShienFlameIdle] Could not import Flame Idle glTF (%d)." % import_error)
		return false
	var scene := document.generate_scene(state)
	if scene == null or not (scene is Node3D):
		push_warning("[ShienFlameIdle] Flame Idle glTF did not generate a Node3D scene.")
		return false
	_source_root = scene as Node3D
	_source_root.name = "FlameIdleSource"
	add_child(_source_root)

	var players := _source_root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("[ShienFlameIdle] Imported Flame Idle has no AnimationPlayer.")
		return false
	_source_player = players[0] as AnimationPlayer
	for candidate in _source_player.get_animation_list():
		var lower := String(candidate).to_lower()
		if lower.contains("flame idle") or lower.contains("flame_idle"):
			_animation_name = StringName(candidate)
			break
	if _animation_name == &"":
		push_warning("[ShienFlameIdle] Could not find the 'Flame Idle' animation clip.")
		return false
	var clip := _source_player.get_animation(_animation_name)
	if clip == null:
		return false
	clip.loop_mode = Animation.LOOP_LINEAR
	_source_player.stop()

	var source_nodes: Dictionary = {}
	if _source_root is Node3D:
		source_nodes[_bone_key(_source_root.name)] = _source_root
	for child in _source_root.find_children("*", "Node3D", true, false):
		var source_node := child as Node3D
		var key := _bone_key(source_node.name)
		if key != "":
			source_nodes[key] = source_node

	_bone_tracks.clear()
	for bone_index in _target.get_bone_count():
		var key := _bone_key(str(_target.get_bone_name(bone_index)))
		if not source_nodes.has(key):
			continue
		var source_node := source_nodes[key] as Node3D
		_bone_tracks.append({
			"index": bone_index,
			"node": source_node,
			"source_rest": source_node.transform
		})
	if _bone_tracks.is_empty():
		push_warning("[ShienFlameIdle] No matching Mixamo bones were found in the imported animation.")
		return false
	print("[ShienFlameIdle] Flame Idle mapped to %d skeleton bones." % _bone_tracks.size())
	return true

static func _bone_key(value: String) -> String:
	var key := value.to_lower()
	key = key.replace("mixamorig1:", "").replace("mixamorig1_", "")
	key = key.replace("mixamorig:", "").replace("mixamorig_", "")
	key = key.replace(":", "").replace("_", "").replace(" ", "")
	return key

func set_active(enabled: bool) -> void:
	if enabled == _active:
		return
	_active = enabled
	if _active:
		if is_instance_valid(_source_player):
			_source_player.play(_animation_name, 0.12)
		set_process(true)
	else:
		set_process(false)
		if is_instance_valid(_source_player):
			_source_player.stop()
		_restore_target_pose()

func _process(_delta: float) -> void:
	if not _active or not is_instance_valid(_target) or not is_instance_valid(_source_player):
		return
	for track in _bone_tracks:
		var source_node := track["node"] as Node3D
		if not is_instance_valid(source_node):
			continue
		var source_rest: Transform3D = track["source_rest"]
		# bone pose = the character's own rest pose turned by how far the clip moved this bone from
		# its rest (rotation only: the clip's units / proportions differ from the character's)
		var idx := int(track["index"])
		var rest := _target.get_bone_rest(idx)
		var turn := source_rest.basis.get_rotation_quaternion().inverse() * source_node.transform.basis.get_rotation_quaternion()
		_target.set_bone_pose_rotation(idx, rest.basis.get_rotation_quaternion() * turn)
		_target.set_bone_pose_position(idx, rest.origin)

func _restore_target_pose() -> void:
	if not is_instance_valid(_target):
		return
	for track in _bone_tracks:
		_target.reset_bone_pose(int(track["index"]))

func _exit_tree() -> void:
	_active = false
	if is_instance_valid(_source_player):
		_source_player.stop()
	_restore_target_pose()
