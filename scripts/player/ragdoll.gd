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
var model_ref: Node3D
var _hair: Array = []      # rigid hair moved onto the head body: [node, old parent, local transform, skeleton path]
var _bones: Array[int] = []
var _from: Array = []      # world pose of each part's bone when getting up
var _blend := -1.0
var _blend_t := 0.45

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
	r.model_ref = model
	r.process_priority = 100   # after the AnimationPlayer, so the get-up blend sits on top of it
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

	# Transfer the selected non-skinned hairstyle to the physics Head body.
	# Hair 1/2 in the original GLB are skin-deformed, but newer hair options can
	# be rigid MeshInstances that merely sit under a BoneAttachment3D or carry a
	# Skeleton3D path without a Skin resource. Those meshes keep their last pose
	# when Ragdoll._process() starts driving the skeleton, so they must follow
	# the Head RigidBody3D directly.
	var head_body := bodies.get("Head") as RigidBody3D
	if head_body != null and model.has_meta("hero_parts"):
		var hero_parts: Dictionary = model.get_meta("hero_parts")
		var hair_entries: Array = hero_parts.get("hair", [])
		var moved_hair_count := 0
		for entry_variant in hair_entries:
			var entry: Dictionary = entry_variant
			var hair := entry.get("node") as MeshInstance3D
			if hair == null or hair.mesh == null or not hair.is_inside_tree():
				continue
			# The active hairstyle only. Hidden alternatives stay in the model tree.
			if not hair.is_visible_in_tree():
				continue
			# A Skin resource means vertices are actually deformed by Skeleton3D;
			# leave those meshes alone because the ragdoll updates the Head bone.
			if hair.skin != null:
				continue
			r._hair.append([hair, hair.get_parent(), hair.transform, hair.skeleton])
			# With no Skin, MeshInstance3D.skeleton is only a stale/imported path.
			# Clear it before changing parents so it cannot point outside the model.
			hair.skeleton = NodePath("")
			# Preserve the exact world pose at death, then inherit the Head body's
			# translation and rotation for every subsequent ragdoll physics frame.
			hair.reparent(head_body, true)
			hair.set_meta("ragdoll_attached_to_head_body", true)
			moved_hair_count += 1
		if moved_hair_count > 0:
			print("[Ragdoll] Moved %d rigid hairstyle mesh(es) onto the physics Head body." % moved_hair_count)
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
		queue_free()
		return
	if _blend >= 0.0:
		_blend_step(delta)
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

# ---------------------------------------------------------------- knockdown / getting up
## Knock `model` down: limp for `down` seconds, then it gets up - its body blends from where it
## landed into the sit pose (palm on the ground) and then stands back up to idle.
## `on_rise(hips: Vector3, yaw: float)` is called right before, so the owner can move its root
## under the body (yaw is NAN if unknown). Returns null if the model can't ragdoll.
static func knockdown(model: Node3D, parent: Node, vel: Vector3, down := 2.0, on_rise := Callable(), owner_body: PhysicsBody3D = null) -> Ragdoll:
	var r := start(model, parent, vel)
	if r == null:
		return null
	if owner_body != null:   # the limbs start inside the owner's capsule: don't get shoved out of it
		for p in r.parts:
			(p[1] as RigidBody3D).add_collision_exception_with(owner_body)
	r.get_tree().create_timer(down).timeout.connect(r._rise.bind(on_rise))
	return r

const RISE_SIT := 0.75   # seconds in the sit pose before standing up

func _rise(on_rise: Callable) -> void:
	if not is_instance_valid(sk) or parts.is_empty() or not is_instance_valid(model_ref):
		queue_free()
		return
	var hp := hips()
	var head := (parts[2][1] as RigidBody3D).global_position
	var feet := hp - head   # sitting up: legs point away from the head
	feet.y = 0.0
	var yaw := atan2(-feet.x, -feet.z) if feet.length() > 0.05 else NAN
	_from.clear()
	_bones.clear()
	for p in parts:
		_bones.append(p[0])
		_from.append((p[1] as RigidBody3D).global_transform * p[2])
	if on_rise.is_valid():
		on_rise.call(hp, yaw)
	# physics off, hair back on the head, animation back on
	for c in get_children():
		c.queue_free()
	parts.clear()
	for h in _hair:
		var node := h[0] as Node3D
		if is_instance_valid(node) and is_instance_valid(h[1]):
			node.reparent(h[1], false)
			node.transform = h[2]
			(node as MeshInstance3D).skeleton = h[3]
	_hair.clear()
	if model_ref.has_meta("anim_player"):
		var ap := model_ref.get_meta("anim_player") as AnimationPlayer
		if is_instance_valid(ap):
			ap.active = true
	Hero.play(model_ref, "sit", true, 0, 0.0, 0.0)
	var m := model_ref
	get_tree().create_timer(RISE_SIT).timeout.connect(func() -> void:
		if is_instance_valid(m):
			Hero.play(m, "idle", true, 0, 0.0, 0.45))
	_blend = 0.0
	set_process(true)

## Blends the skeleton from the pose it landed in to whatever the animation plays now.
func _blend_step(delta: float) -> void:
	_blend += delta
	var t := clampf(_blend / _blend_t, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	if t >= 1.0:
		queue_free()
		return
	var inv := sk.global_transform.affine_inverse()
	var anim: Array[Transform3D] = []
	for bi in _bones:
		anim.append(sk.get_bone_global_pose(bi))
	for i in _bones.size():   # parents first (PARTS order)
		var from: Transform3D = inv * (_from[i] as Transform3D)
		sk.set_bone_global_pose(_bones[i], from.interpolate_with(anim[i], t))
