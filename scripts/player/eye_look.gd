class_name EyeLook
extends Node
## Moves the irises by sliding the eye texture (the rig has no eye bones). mode "camera": the
## eyes follow the camera (your character, other players, the Customize preview) - only when the
## camera is in front of the face; "aim": toward where the camera points. Added to a Hero model.

const MAX_OFFSET := 0.17    # how far the iris can slide (UV units)
const GAIN := 1.8           # how strongly the eyes react to the camera's angle

var _glance := Vector2.ZERO   # a look-around: eyes dart somewhere for a moment
var _glance_t := 0.0          # > 0 = glancing
var _next_glance := randf_range(2.0, 5.0)

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

const NEAR := 22.0          # further than this from the camera: nobody can see the eyes - skip


func _process(delta: float) -> void:
	var model := get_parent() as Node3D
	var cam := get_viewport().get_camera_3d()
	if model == null or cam == null or not model.is_visible_in_tree():
		return
	if cam.global_position.distance_to(model.global_position) > NEAR:
		return
	var eye := Hero.eyes_position(model)
	var target := cam.global_position if mode == "camera" else cam.global_position - cam.global_basis.z * 40.0
	var head := Hero.head_basis(model)
	var d := head.inverse() * (target - eye).normalized()   # in the head's space: +Z = forward
	var want := Vector2.ZERO
	if d.z > 0.05:   # in front of the face (behind: look straight ahead)
		want = Vector2(clampf(d.x / d.z * GAIN, -1.0, 1.0), clampf(-d.y / d.z * GAIN, -1.0, 1.0)) * MAX_OFFSET
	# every few seconds the character looks around: a quick glance left / right / down, then back
	_next_glance -= delta
	if _next_glance <= 0.0:
		_next_glance = randf_range(2.5, 6.0)
		_glance_t = randf_range(0.5, 1.3)
		var a := randf() * TAU
		_glance = Vector2(cos(a), sin(a) * 0.5) * MAX_OFFSET * randf_range(0.7, 1.0)
	if _glance_t > 0.0:
		_glance_t -= delta
		want = _glance
	# eyes move in quick darts (saccades), not slow drifts
	_off = _off.lerp(want, 1.0 - exp(-22.0 * delta))
	Hero.set_eye_offset(model, _off)
