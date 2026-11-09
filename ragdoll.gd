class_name Ragdoll
extends Node3D
## Lightweight ragdoll: 11 capsule rigid bodies joined with cone-twist joints that
## drive the model's Skeleton3D. Bodies live in world space (unscaled) so the
## physics stays stable whatever scale the model was imported at.
##
## Network clients use set_network_driven(true) and apply_network_state() so
## every machine displays the owning player's physics result instead of running
## an independent simulation.

const LAYER := 16  # physics layer 5: collides with the world, not with itself
# [bone, segment end bone, radius (m), parent part]
const PARTS := [
	["Hips", "Spine1", 0.14, ""],
	["Spine1", "Neck", 0.15, "Hips"],
	["Head", "HeadTop_End", 0.12, "Spine1"],
	["LeftArm", "LeftForeArm", 0.055, "Spine1"],
	["LeftForeArm", "LeftHand", 0.05, "LeftArm"],
	["RightArm", "RightForeArm", 0.055, "Spine1"],
	["RightForeArm", "RightHand", 0.05, "RightArm"],
	["LeftUpLeg", "LeftLeg", 0.08, "Hips"],
	["LeftLeg", "LeftFoot", 0.065, "LeftUpLeg"],
	["RightUpLeg", "RightLeg", 0.08, "Hips"],
	["RightLeg", "RightFoot", 0.065, "RightUpLeg"],
]

# Each part contributes seven floats: position XYZ followed by quaternion XYZW.
const NETWORK_FLOATS_PER_PART := 7
const NETWORK_STATE_SIZE := 77  # 11 ragdoll parts * 7 floats per transform

var sk: Skeleton3D
var parts: Array = []  # [bone_idx, body, offset]
var life := 0.0
var network_driven := false

## Turns `model` limp. Returns null if it has no compatible skeleton.
static func start(model: Node3D, parent: Node, vel: Vector3) -> Ragdoll:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var sk: Skeleton3D = sks[0]
	var idx := {}
	var re := RegEx.create_from_string("([A-Za-z]+[0-9]?)_[0-9]+$")
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i)
		var m := re.search(nm)
		if m:
			idx[m.get_string(1)] = i
		elif nm.contains(":"):
			idx[nm.get_slice(":", 1)] = i
		elif nm.begins_with("mixamorig_"):   # Godot's import turns "mixamorig:Hips" into "mixamorig_Hips"
			idx[nm.trim_prefix("mixamorig_")] = i
		else:
			idx[nm] = i
	for p in PARTS:
		if not idx.has(p[0]) or not idx.has(p[1]):
			return null
	if model.has_meta("anim_player"):
		var ap := model.get_meta("anim_player") as AnimationPlayer
		if is_instance_valid(ap):
			ap.active = false
	var r := Ragdoll.new()
	r.sk = sk
	parent.add_child(r)
	var g := sk.global_transform
	var bodies := {}
	for p in PARTS:
		var bi: int = idx[p[0]]
		var wa := g * sk.get_bone_global_pose(bi)
		var wb := g * sk.get_bone_global_pose(idx[p[1]])
		var seg := wb.origin - wa.origin
		var len := maxf(seg.length(), 0.05)
		var bt := Transform3D(_basis_y(seg), wa.origin + seg * 0.5)
		var body := RigidBody3D.new()
		body.collision_layer = LAYER
		body.collision_mask = 1
		body.mass = 3.0 if p[3] == "" or p[0] == "Spine1" else 1.2
		body.linear_damp = 0.4
		body.angular_damp = 3.0
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = p[2]
		cap.height = maxf(len, p[2] * 2.0 + 0.01)
		cs.shape = cap
		body.add_child(cs)
		r.add_child(body)
		body.global_transform = bt
		body.linear_velocity = vel
		body.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		bodies[p[0]] = body
		r.parts.append([bi, body, bt.affine_inverse() * wa])
		if p[3] != "":
			var j := ConeTwistJoint3D.new()
			r.add_child(j)
			var jb := _basis_y(seg)
			j.global_transform = Transform3D(Basis(jb.y, -jb.x, jb.z), wa.origin)  # twist axis (X) along the limb
			j.node_a = bodies[p[3]].get_path()
			j.node_b = body.get_path()
			j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(40.0 if p[0] == "Head" else 70.0))
			j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(25.0))
	return r

static func _basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized()).orthonormalized()

## Switches a remote ragdoll to kinematic/network-controlled bodies.
func set_network_driven(enabled: bool) -> void:
	network_driven = enabled
	for part in parts:
		var body := part[1] as RigidBody3D
		body.freeze = enabled
		if enabled:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO

## Captures the authoritative body transforms in a compact RPC-safe array.
func get_network_state() -> PackedFloat32Array:
	var state := PackedFloat32Array()
	state.resize(NETWORK_STATE_SIZE)
	var offset := 0
	for part in parts:
		var body := part[1] as RigidBody3D
		var transform := body.global_transform
		var q := transform.basis.orthonormalized().get_rotation_quaternion().normalized()
		state[offset] = transform.origin.x
		state[offset + 1] = transform.origin.y
		state[offset + 2] = transform.origin.z
		state[offset + 3] = q.x
		state[offset + 4] = q.y
		state[offset + 5] = q.z
		state[offset + 6] = q.w
		offset += NETWORK_FLOATS_PER_PART
	return state

## Applies a state received from the owning peer. Remote bodies remain frozen
## so local physics cannot drift away from the replicated pose.
func apply_network_state(state: PackedFloat32Array) -> void:
	if state.size() != NETWORK_STATE_SIZE:
		return
	if not network_driven:
		set_network_driven(true)
	var offset := 0
	for part in parts:
		var body := part[1] as RigidBody3D
		var position := Vector3(state[offset], state[offset + 1], state[offset + 2])
		var rotation := Quaternion(
			state[offset + 3],
			state[offset + 4],
			state[offset + 5],
			state[offset + 6]
		).normalized()
		body.global_transform = Transform3D(Basis(rotation), position)
		offset += NETWORK_FLOATS_PER_PART

func _process(delta: float) -> void:
	if not is_instance_valid(sk):
		return
	life += delta
	var inv := sk.global_transform.affine_inverse()
	for p in parts:
		sk.set_bone_global_pose(p[0], inv * (p[1] as RigidBody3D).global_transform * p[2])
	# Freeze once settled to save CPU.
	if life > 6.0:
		for p in parts:
			(p[1] as RigidBody3D).freeze = true
		set_process(false)

func hips() -> Vector3:
	return (parts[0][1] as RigidBody3D).global_position if not parts.is_empty() else global_position
