extends Node3D
class_name SharinganEffect
## A small, continuously rotating Sharingan decal attached to the character's head bone.

const TEXTURE_PATH := "res://assets/effects/sharingan.png"
const PIXEL_SIZE := 0.0008 # 200 px -> 0.16 m across
const ROTATION_SPEED := 3.2 # radians per second
const FACE_OFFSET := Vector3(0.055, 0.035, 0.12)

var _sprite: Sprite3D
var _attachment: BoneAttachment3D


static func attach_to(model: Node3D) -> SharinganEffect:
	if model == null or not is_instance_valid(model):
		return null

	var texture := load(TEXTURE_PATH) as Texture2D
	if texture == null:
		push_warning("[SharinganEffect] Missing texture: %s" % TEXTURE_PATH)
		return null

	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("[SharinganEffect] Character model has no Skeleton3D; cannot attach the Sharingan.")
		return null

	var skeleton := skeletons[0] as Skeleton3D
	var head_bone := _find_head_bone(skeleton)
	if head_bone == "":
		push_warning("[SharinganEffect] No Head bone found on character model.")
		return null

	var attachment := BoneAttachment3D.new()
	attachment.name = "SharinganHeadAttachment"
	attachment.bone_name = head_bone
	skeleton.add_child(attachment)

	var effect := SharinganEffect.new()
	effect.name = "SpinningSharingan"
	effect._attachment = attachment
	attachment.add_child(effect)
	effect._build_sprite(texture)
	return effect


static func _find_head_bone(skeleton: Skeleton3D) -> String:
	var fallback := ""
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		var key := bone_name.to_lower()
		if key == "head" or key.ends_with(":head") or key.ends_with("_head"):
			return bone_name
		if fallback == "" and key.contains("head") and not key.contains("top") and not key.contains("end"):
			fallback = bone_name
	return fallback


func _build_sprite(texture: Texture2D) -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "SharinganSprite"
	_sprite.texture = texture
	_sprite.centered = true
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.position = FACE_OFFSET
	_sprite.no_depth_test = true
	_sprite.double_sided = true
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)


func _process(delta: float) -> void:
	if is_instance_valid(_sprite):
		_sprite.rotation.z = fposmod(_sprite.rotation.z + ROTATION_SPEED * delta, TAU)


## Frees the BoneAttachment3D as well as this effect node.
func detach() -> void:
	if is_instance_valid(_attachment):
		_attachment.queue_free()
	else:
		queue_free()
