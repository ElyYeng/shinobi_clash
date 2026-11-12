class_name EyeLook
extends Node
## Moves the irises by sliding the eye texture (the rig has no eye bones). mode "camera": the
## eyes follow the camera (your character, other players, the Customize preview) - only when the
## camera is in front of the face; "aim": toward where the camera points. Added to a Hero model.

const MAX_OFFSET := 0.11    # how far the iris can slide (UV units)

var mode := "aim"
var _off := Vector2.ZERO

static func attach(model: Node3D, look_mode := "aim") -> EyeLook:
	if model == null:
		return null
	var old := model.get_node_or_null("EyeLook") as EyeLook
	if old != null:
		old.mode = look_mode
		return old
	var e := EyeLook.new()
	e.name = "EyeLook"
	e.mode = look_mode
	model.add_child(e)
	return e

func _process(delta: float) -> void:
	var model := get_parent() as Node3D
	var cam := get_viewport().get_camera_3d()
	if model == null or cam == null or not model.is_visible_in_tree():
		return
	var eye := Hero.eyes_position(model)
	var target := cam.global_position if mode == "camera" else cam.global_position - cam.global_basis.z * 40.0
	var head := Hero.head_basis(model)
	var d := head.inverse() * (target - eye).normalized()   # in the head's space: +Z = forward
	var want := Vector2.ZERO
	if d.z > 0.05:   # in front of the face (behind: look straight ahead)
		want = Vector2(clampf(d.x / d.z, -1.0, 1.0), clampf(-d.y / d.z, -1.0, 1.0)) * MAX_OFFSET
	_off = _off.lerp(want, 1.0 - exp(-10.0 * delta))
	Hero.set_eye_offset(model, _off)
