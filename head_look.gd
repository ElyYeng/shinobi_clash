class_name HeadLook
extends SkeletonModifier3D
## Turns the upper spine, neck and head toward a look direction on top of whatever animation is
## playing (the head follows the camera). Angles are relative to the body: yaw > 0 = turn left,
## pitch > 0 = look up. Use HeadLook.drive(model, yaw, pitch, delta) every frame - it adds the
## modifier to the model's skeleton the first time.

const MAX_YAW := deg_to_rad(75.0)
const MAX_UP := deg_to_rad(40.0)
const MAX_DOWN := deg_to_rad(45.0)
## share of the turn each bone takes (they stack: upper chest -> neck -> head)
const SHARES := {"spine2": 0.2, "neck": 0.35, "head": 0.45}

var target_yaw := 0.0
var target_pitch := 0.0
var yaw := 0.0
var pitch := 0.0
var enabled := true
var _bones: Array = []    # [[bone index, share], ...] parent first
var _found := false
var body: Node3D           # the model root - its -Z is the way the character faces

static func drive(model: Node3D, look_yaw: float, look_pitch: float, delta: float, on := true) -> void:
	if model == null or not is_instance_valid(model):
		return
	var hl: HeadLook = model.get_meta("head_look", null) if model.has_meta("head_look") else null
	if hl == null or not is_instance_valid(hl):
		var sks := model.find_children("*", "Skeleton3D", true, false)
		if sks.is_empty():
			return
		hl = HeadLook.new()
		hl.name = "HeadLook"
		(sks[0] as Skeleton3D).add_child(hl)
		model.set_meta("head_look", hl)
	hl.body = model
	hl.enabled = on
	hl.target_yaw = clampf(look_yaw, -MAX_YAW, MAX_YAW) if on else 0.0
	hl.target_pitch = clampf(look_pitch, -MAX_DOWN, MAX_UP) if on else 0.0
	var k := 1.0 - exp(-12.0 * delta)
	hl.yaw = lerpf(hl.yaw, hl.target_yaw, k)
	hl.pitch = lerpf(hl.pitch, hl.target_pitch, k)

## Body-relative look angles for a camera (yaw, pitch) and a body facing yaw. Fades the turn out
## when the camera looks back at the character's face, so the head doesn't twist backwards.
static func angles_from_camera(cam_yaw: float, cam_pitch: float, body_yaw: float, pitch_rest := 0.0) -> Vector2:
	var d := wrapf(cam_yaw - body_yaw, -PI, PI)
	var fade := 1.0 - smoothstep(deg_to_rad(100.0), deg_to_rad(150.0), absf(d))
	return Vector2(clampf(d, -MAX_YAW, MAX_YAW) * fade, (cam_pitch - pitch_rest) * fade)

func _find_bones(sk: Skeleton3D) -> void:
	_found = true
	_bones.clear()
	# The character rig has two copies of these bones (mixamorig_* and Ctrl_*) and different
	# meshes (face vs. some hairs) are skinned to each - turn every copy the same way.
	for key in SHARES:
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i).to_lower().replace("mixamorig:", "").replace("mixamorig_", "")
			if bn == key or bn.ends_with(":" + key) or bn.ends_with("_" + key):
				_bones.append([i, float(SHARES[key])])

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not enabled:
		return
	if not _found:
		_find_bones(sk)
	if _bones.is_empty() or (absf(yaw) < 0.001 and absf(pitch) < 0.001):
		return
	# Rotation in world space (around world up, and the body's right axis), then in skeleton space.
	var sb := sk.global_basis.orthonormalized()
	# the model faces -Z (player.gd: rotation.y = atan2(-f.x, -f.z))
	var fwd := -(body.global_basis.z if body != null and is_instance_valid(body) else sb.z)
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var to_skel := sb.inverse()
	for e in _bones:
		var bone: int = e[0]
		var share: float = e[1]
		var rw := Basis(Vector3.UP, yaw * share) * Basis(right, pitch * share)
		var rs := to_skel * rw * sb
		var g := sk.get_bone_global_pose(bone)
		var ng := Basis(rs * g.basis)
		var parent := sk.get_bone_parent(bone)
		var pb := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var local := pb.inverse() * ng
		sk.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
