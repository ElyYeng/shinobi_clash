class_name ShienFlameIdle
extends Node
## Re-targets the imported Flame Idle glTF animation onto a character's Mixamo Skeleton3D.
## The source GLB is stored gzip-compressed to keep the repository asset small.

const PARTS_DIR := "res://assets/character/FlameIdleParts/"   # part_00.txt, part_01.txt ... read until one is missing

var _target: Skeleton3D
var _source_root: Node3D
var _source_skel: Skeleton3D
var _claw: BoneAttachment3D
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
	var part := 0
	while FileAccess.file_exists("%spart_%02d.txt" % [PARTS_DIR, part]):
		encoded += FileAccess.get_file_as_string("%spart_%02d.txt" % [PARTS_DIR, part]).strip_edges()
		part += 1
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

	# The clip rig (with the claw mesh skinned to it) is a Skeleton3D now. It sits exactly on the
	# character's skeleton, hidden until the idle plays, so the claw follows the retargeted pose.
	var skels := _source_root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_warning("[ShienFlameIdle] Imported Flame Idle has no Skeleton3D.")
		return false
	_source_skel = skels[0] as Skeleton3D
	_source_root.global_transform = _target.global_transform
	_source_root.visible = false   # only its bones are used; the claw mesh is copied onto the hand below
	_build_claw()
	var source_bones: Dictionary = {}
	for si in _source_skel.get_bone_count():
		source_bones[_bone_key(str(_source_skel.get_bone_name(si)))] = si
	_bone_tracks.clear()
	for bone_index in _target.get_bone_count():
		var key := _bone_key(str(_target.get_bone_name(bone_index)))
		if not source_bones.has(key):
			continue
		var sidx: int = source_bones[key]
		var rest := _source_skel.get_bone_global_rest(sidx)
		_bone_tracks.append({
			"index": bone_index,
			"src": sidx,
			"key": key,
			"rest_q": rest.basis.orthonormalized().get_rotation_quaternion(),
			"rest_pos": rest.origin
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
	if not _active or not is_instance_valid(_target) or not is_instance_valid(_source_skel):
		return
	for track in _bone_tracks:
		var idx := int(track["index"])
		# model-space retarget: how far the clip turned this bone from its rest, on the character's rest
		var cur := _source_skel.get_bone_global_pose(int(track["src"]))
		var turn := cur.basis.orthonormalized().get_rotation_quaternion() * (track["rest_q"] as Quaternion).inverse()
		var want := turn * _target.get_bone_global_rest(idx).basis.get_rotation_quaternion()
		var parent := _target.get_bone_parent(idx)
		var parent_q := Quaternion.IDENTITY
		if parent >= 0:
			parent_q = _target.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		_target.set_bone_pose_rotation(idx, parent_q.inverse() * want)
		if track["key"] == "hips":   # the clip's hip sway, scaled to this character's size
			var rest_pos: Vector3 = track["rest_pos"]
			var s := 1.0
			if absf(rest_pos.y) > 0.001:
				s = _target.get_bone_global_rest(idx).origin.y / rest_pos.y
			_target.set_bone_pose_position(idx, _target.get_bone_rest(idx).origin + (cur.origin - rest_pos) * s)

func _restore_target_pose() -> void:
	if not is_instance_valid(_target):
		return
	for track in _bone_tracks:
		_target.reset_bone_pose(int(track["index"]))

func _exit_tree() -> void:
	if is_instance_valid(_claw):
		_claw.queue_free()
	_active = false
	if is_instance_valid(_source_player):
		_source_player.stop()
	_restore_target_pose()


## The claw mesh from the clip, copied rigidly onto the character's hand (aura material), hidden
## until set_claw(true). It sits where the clip put it relative to the nearer hand bone.
func _build_claw() -> void:
	var src: MeshInstance3D = null
	for n in _source_root.find_children("*", "MeshInstance3D", true, false):
		src = n as MeshInstance3D
		break
	if src == null or src.mesh == null:
		return
	var rel := _source_skel.global_transform.affine_inverse() * src.global_transform
	var centre := rel * src.get_aabb().get_center()
	var best_name := ""
	var best_d := INF
	for side in ["lefthand", "righthand"]:
		for si in _source_skel.get_bone_count():
			if _bone_key(str(_source_skel.get_bone_name(si))) == side:
				var d := _source_skel.get_bone_global_rest(si).origin.distance_to(centre)
				if d < best_d:
					best_d = d
					best_name = side
	if best_name == "":
		return
	var hand := -1
	for ti in _target.get_bone_count():
		if _bone_key(str(_target.get_bone_name(ti))) == best_name:
			hand = ti
	if hand < 0:
		return
	_claw = BoneAttachment3D.new()
	_claw.name = "ShienClawMesh"
	_target.add_child(_claw)
	_claw.bone_name = str(_target.get_bone_name(hand))
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	# solid glowing core (so it reads clearly) with a bigger flickering aura shell over it
	mi.material_override = ShienClaw._aura_material(ShienClaw.VIOLET, ShienClaw.HOT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base_t := _target.get_bone_global_rest(hand).affine_inverse() * rel
	mi.transform = base_t
	_claw.add_child(mi)
	var shell := MeshInstance3D.new()
	shell.mesh = src.mesh
	var am := ShienClaw._aura_material(ShienClaw.VIOLET, ShienClaw.HOT)
	am.set_shader_parameter("_Brightness", 1.6)
	shell.material_override = am
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.transform = base_t.scaled_local(Vector3.ONE * 1.06)
	_claw.add_child(shell)
	_claw.visible = false

func set_claw(on: bool) -> void:
	if is_instance_valid(_claw):
		_claw.visible = on
