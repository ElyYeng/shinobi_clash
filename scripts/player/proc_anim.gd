class_name ProcAnim
extends RefCounted
## Animations built in code on the character's own Mixamo skeleton (no clip file needed).
## A pose is a set of target directions for limb bones in "body space" (F = forward, U = up,
## S = the bone's own side, + = outward); every bone is keyed, the rest stay in their rest pose.

const SIT := "proc_sit"

## Ninja sit: right knee up with the forearm draped over it, left leg folded flat in front,
## leaning back on the left hand with the palm flat on the ground. Keys can be generic ("Arm",
## both sides) or per side ("LeftArm"); for centre bones S means "towards the left".
const SIT_POSE := {
	"Spine": [0.05, 1.0, 0.12], "Spine1": [0.08, 1.0, 0.05], "Spine2": [0.1, 1.0, 0.0],
	"Neck": [0.12, 1.0, -0.08], "Head": [0.0, 1.0, -0.05],
	"RightUpLeg": [0.55, 0.8, 0.25], "RightLeg": [-0.3, -1.0, 0.05], "RightFoot": [1.0, -0.35, 0.05],
	"LeftUpLeg": [0.8, -0.05, 0.6], "LeftLeg": [0.35, -0.12, -1.0], "LeftFoot": [0.35, -0.35, -0.8],
	"RightArm": [0.5, -0.55, 0.3], "RightForeArm": [0.7, -0.45, -0.4],
	"LeftArm": [-0.45, -0.85, 0.4], "LeftForeArm": [-0.3, -1.0, 0.2], "LeftHand": [-0.45, -0.12, 0.55],
}
## Hands whose palm is turned to face the ground (rest pose has palms down, as in Mixamo's T-pose).
const PALM_DOWN := ["LeftHand"]
## Child bone each limb bone points at.
const CHILD := {"Hips": "Spine", "Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head",
	"Head": "HeadTop_End", "UpLeg": "Leg", "Leg": "Foot", "Foot": "ToeBase", "Arm": "ForeArm", "ForeArm": "Hand", "Hand": "HandMiddle1"}
## Pelvis height when sitting, as a fraction of standing height.
const SIT_HIP := 0.11

static func add_sit(ap: AnimationPlayer, sk: Skeleton3D) -> String:
	if ap.has_animation(SIT):
		return SIT
	var a := _pose_anim(ap, sk, SIT_POSE, SIT_HIP)
	if a == null:
		return ""
	var lib: AnimationLibrary
	if ap.has_animation_library(""):
		lib = ap.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)
	lib.add_animation(SIT, a)
	return SIT

## mixamo name ("LeftUpLeg") -> bone index, ignoring the Ctrl_/IK copies some rigs carry.
static func _bones(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		for pre in ["mixamorig_", "mixamorig:", "mixamorig1_", "mixamorig1:"]:
			if n.begins_with(pre):
				out[n.trim_prefix(pre)] = i
	return out

static func _track_prefix(ap: AnimationPlayer, sk: Skeleton3D) -> String:
	var root := ap.get_node_or_null(ap.root_node)
	return str(root.get_path_to(sk)) if root != null else ""

static func _pose_anim(ap: AnimationPlayer, sk: Skeleton3D, pose: Dictionary, hip_frac: float) -> Animation:
	var b := _bones(sk)
	for need in ["Hips", "LeftUpLeg", "RightUpLeg", "LeftFoot", "LeftToeBase", "Head"]:
		if not b.has(need):
			return null
	var g := func(n: String) -> Transform3D: return sk.get_bone_global_rest(b[n])
	var hips: Vector3 = g.call("Hips").origin
	var foot: Vector3 = g.call("LeftFoot").origin
	var up := Vector3.UP
	var fwd: Vector3 = (g.call("LeftToeBase").origin - foot)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var left_dir: Vector3 = (g.call("LeftUpLeg").origin - hips)
	left_dir = (left_dir - fwd * left_dir.dot(fwd) - up * left_dir.dot(up)).normalized()
	var ground := minf(foot.y, g.call("RightUpLeg").origin.y)
	for n in ["LeftToeBase", "RightToeBase", "LeftToe_End", "RightToe_End"]:
		if b.has(n):
			ground = minf(ground, g.call(n).origin.y)
	var height: float = g.call("Head").origin.y - ground

	# world-space rotation delta per bone, parents first (bone indices are parent-ordered)
	var delta := {}
	var posed := {}
	var hips_i := b["Hips"] as int
	var anim := Animation.new()
	anim.length = 0.6
	var prefix := _track_prefix(ap, sk)
	for i in sk.get_bone_count():
		var full := sk.get_bone_name(i)
		var name := ""
		for k in b:
			if b[k] == i:
				name = k
		if name == "":
			continue
		var par := sk.get_bone_parent(i)
		var wp: Quaternion = delta.get(par, Quaternion.IDENTITY)
		var w := wp
		var side := 1.0 if name.begins_with("Left") else (-1.0 if name.begins_with("Right") else 0.0)
		var key := name.trim_prefix("Left").trim_prefix("Right")
		var pkey := name if pose.has(name) else key
		if pose.has(pkey) and CHILD.has(key):
			var child := ("Left" if side > 0 else "Right" if side < 0 else "") + str(CHILD[key])
			if b.has(child):
				var rest_dir: Vector3 = (g.call(child).origin - g.call(name).origin).normalized()
				var t: Array = pose[pkey]
				var sm := side if side != 0.0 else 1.0
				var want: Vector3 = (fwd * float(t[0]) + up * float(t[1]) + left_dir * sm * float(t[2])).normalized()
				var cur := wp * rest_dir
				if cur.cross(want).length() > 0.0001:
					w = Quaternion(cur, want) * wp
				if name in PALM_DOWN:   # twist about the hand so the palm faces the floor
					var n := w * Vector3.DOWN
					var target := Vector3.DOWN - want * want.dot(Vector3.DOWN)
					n = n - want * want.dot(n)
					if n.length() > 0.001 and target.length() > 0.001:
						w = Quaternion(n.normalized(), target.normalized()) * w
		delta[i] = w
		var grp: Quaternion = sk.get_bone_global_rest(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
		var grb: Quaternion = sk.get_bone_global_rest(i).basis.get_rotation_quaternion()
		var local := (grp.inverse() * wp.inverse() * w * grb).normalized()
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(prefix + ":" + full))
		anim.rotation_track_insert_key(tr, 0.0, local)
		anim.rotation_track_insert_key(tr, anim.length, local)
		if name == "Hips":
			hips_i = i
		# posed position (hips at rest height) to find where the feet end up
		var rest_o: Vector3 = sk.get_bone_global_rest(i).origin
		if par >= 0 and posed.has(par):
			var wpar: Quaternion = delta.get(par, Quaternion.IDENTITY)
			posed[i] = posed[par] + wpar * (rest_o - sk.get_bone_global_rest(par).origin)
		else:
			posed[i] = rest_o
	# Hips height: the sitting height, but never so low that a foot/toe goes under the floor.
	var lowest := INF
	for n in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "LeftToe_End", "RightToe_End"]:
		if b.has(n) and posed.has(b[n]):
			lowest = minf(lowest, (posed[b[n]] as Vector3).y)
	var target_y := ground + height * hip_frac
	if lowest < INF:
		target_y = maxf(target_y, hips.y + (ground + height * 0.03 - lowest))   # 0.03: ankle/sole thickness
	var world_pos := Vector3(hips.x, target_y, hips.z)
	var hpar := sk.get_bone_parent(hips_i)
	var pos := world_pos if hpar < 0 else sk.get_bone_global_rest(hpar).affine_inverse() * world_pos
	var pt := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pt, NodePath(prefix + ":" + sk.get_bone_name(hips_i)))
	anim.position_track_insert_key(pt, 0.0, pos)
	anim.position_track_insert_key(pt, anim.length, pos)
	anim.loop_mode = Animation.LOOP_NONE
	return anim
