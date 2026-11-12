class_name FaceBlink
extends Node
## Blinks the character every few seconds using the chosen eyes' blink shape keys
## (eyes_<variant>L_blink / R_blink). Added by Hero.apply_face to any model with a face.

var _t := randf_range(1.0, 4.0)
var _closing := 0.0

func _process(delta: float) -> void:
	_t -= delta
	if _closing > 0.0:
		_closing -= delta
		if _closing <= 0.0:
			_eyes(0.0)
		return
	if _t <= 0.0:
		_t = randf_range(2.0, 5.5)
		_closing = 0.12
		_eyes(1.0)

## Re-apply the eyes now (e.g. the swollen eye from battle damage changed).
func refresh() -> void:
	_eyes(0.0)

func _eyes(v: float) -> void:
	var model := get_parent()
	if model == null or not model.has_meta("face_choice"):
		return
	var eyes := str((model.get_meta("face_choice") as Dictionary).get("eyes", ""))
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_blend_shape_count() == 0:
			continue
		for i in mi.mesh.get_blend_shape_count():
			var k := Hero.face_key(str(mi.mesh.get_blend_shape_name(i)))
			if k[0] == "eyes" and k[1] == eyes:
				# glTF keys are relative to the basis, so the blink key is the whole closed eye:
				# swap open -> closed rather than stacking them. Battle damage keeps one eye
				# (the left) swollen almost shut.
				var c := v
				if k[2] == "L":
					c = maxf(v, float(model.get_meta("eye_hurt", 0.0)))
				mi.set_blend_shape_value(i, c if k[3] == "blink" else 1.0 - c)
