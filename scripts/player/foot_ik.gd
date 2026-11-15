class_name FootIK
extends SkeletonModifier3D
## Ground IK for the legs: each foot is raycast down and the leg is bent (analytic two-bone IK) so
## the foot sits on the real ground (slopes, steps, rocks) instead of floating or sinking. The
## pelvis drops to the lowest foot so the legs don't overstretch. The animation still drives the
## stepping - this only adds the height difference between the ground under each foot and the
## ground under the character, and fades out when off the floor.
## Use FootIK.drive(model, on) every physics frame - it adds the modifier the first time.

const MAX_STEP := 0.4        # metres of ground difference the legs will follow (world units)
const RAY_UP := 0.5
const RAY_DOWN := 0.7
const FOLLOW := 16.0         # how fast feet settle onto new ground

var enabled := true
var body: Node3D             # model root: its origin is at the feet
var mask := 1
var _w := 0.0                # fade 0..1
var _chains: Array = []      # [{hips, legs: [[up, leg, foot, side_off] x2], off: [0.0, 0.0]}]
var _found := false
var _exclude: Array[RID] = []

static func drive(model: Node3D, on: bool) -> void:
	if model == null or not is_instance_valid(model):
		return
	var fk: FootIK = model.get_meta("foot_ik", null) if model.has_meta("foot_ik") else null
	if fk == null or not is_instance_valid(fk):
		if not on:
			return
		var sks := model.find_children("*", "Skeleton3D", true, false)
		if sks.is_empty():
			return
		fk = FootIK.new()
		fk.name = "FootIK"
		(sks[0] as Skeleton3D).add_child(fk)
		model.set_meta("foot_ik", fk)
		var n := model.get_parent()
		while n != null:
			if n is CollisionObject3D:
				fk._exclude.append((n as CollisionObject3D).get_rid())
			n = n.get_parent()
	fk.body = model
	fk.enabled = on

func _find(sk: Skeleton3D) -> void:
	_found = true
	_chains.clear()
	# The rig has two copies of the skeleton (mixamorig_* and Ctrl_*); rig each copy the same way.
	var groups := {}   # prefix -> {hips, up0, leg0, foot0, up1, ...}
	for i in sk.get_bone_count():
		var ln := sk.get_bone_name(i).to_lower().replace("_", "").replace(":", "")
		if ln.ends_with("hips"):
			var pf := ln.substr(0, ln.length() - 4)
			groups.get_or_add(pf, {})["hips"] = i
		for side in 2:
			var sn := "left" if side == 0 else "right"
			for key in ["upleg", "leg", "foot"]:
				var suf: String = sn + key
				if ln.ends_with(suf):
					var pf2 := ln.substr(0, ln.length() - suf.length())
					groups.get_or_add(pf2, {})["%s%d" % [key, side]] = i
	for pf in groups:
		var g: Dictionary = groups[pf]
		if not g.has("hips"):
			continue
		var legs: Array = []
		for side in 2:
			if g.has("upleg%d" % side) and g.has("leg%d" % side) and g.has("foot%d" % side):
				legs.append([g["upleg%d" % side], g["leg%d" % side], g["foot%d" % side]])
		if not legs.is_empty():
			_chains.append({"hips": g["hips"], "legs": legs, "off": [0.0, 0.0]})

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or body == null or not is_instance_valid(body):
		return
	if not _found:
		_find(sk)
	var dt := get_process_delta_time()
	_w = move_toward(_w, 1.0 if enabled else 0.0, dt * 6.0)
	if _w <= 0.001 or _chains.is_empty():
		for c in _chains:
			c["off"] = [0.0, 0.0]
		return
	var space := sk.get_world_3d().direct_space_state
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var base_y := body.global_position.y
	var k := 1.0 - exp(-FOLLOW * dt)
	for c in _chains:
		var legs: Array = c["legs"]
		# 1. how far the ground under each (animated) foot is from the ground under the character
		var offs: Array = c["off"]
		for li in legs.size():
			var fw: Vector3 = xf * sk.get_bone_global_pose(legs[li][2]).origin
			var q := PhysicsRayQueryParameters3D.create(Vector3(fw.x, base_y + RAY_UP, fw.z), Vector3(fw.x, base_y - RAY_DOWN, fw.z), mask, _exclude)
			var h := space.intersect_ray(q)
			var want := 0.0
			if not h.is_empty() and float(h["normal"].y) > 0.5:
				want = clampf(float(h["position"].y) - base_y, -MAX_STEP, MAX_STEP)
			offs[li] = lerpf(float(offs[li]), want, k)
		# 2. pelvis drops to the lowest foot so the legs don't overstretch
		var low := 0.0
		for li in legs.size():
			low = minf(low, float(offs[li]) * _w)
		if low < -0.001:
			var hb: int = c["hips"]
			var hp := sk.get_bone_parent(hb)
			var pbasis := sk.get_bone_global_pose(hp).basis if hp >= 0 else Basis.IDENTITY
			var d_skel := xf.basis.inverse() * Vector3(0, low, 0)
			sk.set_bone_pose_position(hb, sk.get_bone_pose_position(hb) + pbasis.inverse() * d_skel)
		# 3. two-bone IK per leg onto the ground
		for li in legs.size():
			var o := float(offs[li]) * _w
			if absf(o) < 0.002 and low > -0.001:
				continue
			_solve(sk, legs[li][0], legs[li][1], legs[li][2], xf, o, low)

func _solve(sk: Skeleton3D, up: int, mid: int, foot: int, xf: Transform3D, o: float, low: float) -> void:
	# Pelvis already moved by `low` (world Y); the foot animation position moved with it, so the
	# target is where the foot would be without the pelvis shift, plus the ground offset.
	var inv := xf.affine_inverse()
	var a := sk.get_bone_global_pose(up).origin
	var b := sk.get_bone_global_pose(mid).origin
	var cpos := sk.get_bone_global_pose(foot).origin
	var foot_basis := sk.get_bone_global_pose(foot).basis
	var target: Vector3 = inv * (xf * cpos + Vector3(0, o - low, 0))
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(cpos)
	if l1 < 0.001 or l2 < 0.001:
		return
	var to_t := target - a
	var d := clampf(to_t.length(), 0.01, (l1 + l2) * 0.999)
	var dir_t := to_t.normalized()
	# keep the knee bending the way the animation bends it
	var ac := (cpos - a).normalized()
	var pole := (b - a) - ac * (b - a).dot(ac)
	if pole.length_squared() < 0.000001:
		pole = xf.basis.inverse() * (-xf.basis.z)
	pole = (pole - dir_t * pole.dot(dir_t)).normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var height := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var knee := a + dir_t * along + pole * height
	_aim(sk, up, (b - a).normalized(), (knee - a).normalized())
	var b2 := sk.get_bone_global_pose(mid).origin
	var c2 := sk.get_bone_global_pose(foot).origin
	var tgt := a + dir_t * d
	_aim(sk, mid, (c2 - b2).normalized(), (tgt - b2).normalized())
	# keep the foot's own orientation from the animation (no twisting with the shin)
	var fp := sk.get_bone_parent(foot)
	var pb := sk.get_bone_global_pose(fp).basis
	sk.set_bone_pose_rotation(foot, Quaternion((pb.inverse() * foot_basis).orthonormalized()))

## Rotate a bone (in skeleton space) so a direction `from` becomes `to`.
func _aim(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	var dot := clampf(from.dot(to), -1.0, 1.0)
	if dot > 0.99999:
		return
	var axis := from.cross(to)
	if axis.length_squared() < 0.0000001:
		return
	var rot := Basis(axis.normalized(), acos(dot))
	var g := sk.get_bone_global_pose(bone)
	var parent := sk.get_bone_parent(bone)
	var pb := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, Quaternion((pb.inverse() * rot * g.basis).orthonormalized()))
