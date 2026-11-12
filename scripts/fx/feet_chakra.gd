class_name FeetChakra
## Chakra gathered in the soles while walking on walls / ceilings: small blue chakra flames on
## both feet (fire flipbook, follows the foot bones). attach / detach on a Hero model.

const COL := Color(0.35, 0.7, 1.0)

static func attach(model: Node3D) -> void:
	if model == null or not is_instance_valid(model) or model.has_meta("feet_chakra"):
		return
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk := sks[0] as Skeleton3D
	var made: Array = []
	for bn in ["mixamorig_LeftFoot", "mixamorig_RightFoot"]:
		if sk.find_bone(bn) < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = bn
		at.name = "FeetChakra"
		sk.add_child(at)
		Vfx.aura_flames(at, Vector3.ZERO, 0.12, COL, 14, true)
		made.append(at)
	model.set_meta("feet_chakra", made)

static func detach(model: Node3D) -> void:
	if model == null or not is_instance_valid(model) or not model.has_meta("feet_chakra"):
		return
	for at in model.get_meta("feet_chakra"):
		if is_instance_valid(at):
			for c in (at as Node).find_children("*", "CPUParticles3D", true, false):
				(c as CPUParticles3D).emitting = false
			(at as Node).get_tree().create_timer(0.8).timeout.connect((at as Node).queue_free)
	model.remove_meta("feet_chakra")
