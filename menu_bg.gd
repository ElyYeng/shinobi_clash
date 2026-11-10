class_name MenuBG
extends Control
## Parallax menu backdrop (main menu, multiplayer lobby, Customize). Five painted layers from
## res://assets/menu/ move with the mouse - far layers barely, near layers more - plus a slow
## idle sway and falling petals. Replace a PNG to change a layer; tune LAYERS below.

## file, depth (how much it follows the mouse), where it sits: "top" = its top edge at `y`,
## "bottom" = its bottom edge at `y` (fractions of the screen height), and fill = colour that
## continues below the layer down to the next one (so no gaps show between layers).
const LAYERS := [
	{"file": "res://assets/menu/parallax_1_sky.png", "depth": 0.012, "anchor": "top", "y": 0.02},
	{"file": "res://assets/menu/parallax_2_mountains.png", "depth": 0.022, "anchor": "bottom", "y": 0.67,
		"fill": Color(0.584, 0.427, 0.467)},
	{"file": "res://assets/menu/parallax_3_village.png", "depth": 0.036, "anchor": "bottom", "y": 0.8,
		"fill": Color(0.506, 0.388, 0.431)},
	{"file": "res://assets/menu/parallax_5_foreground.png", "depth": 0.075, "anchor": "bottom", "y": 1.0},
	{"file": "res://assets/menu/parallax_4_tree.png", "depth": 0.06, "anchor": "top", "y": -0.02},
]
const OVERSCAN := 1.12          # layers are a bit wider than the screen so they can slide
const SKY_TOP := Color(0.05, 0.02, 0.04)
const SKY_HORIZON := Color(0.36, 0.13, 0.15)
const PETAL_COLOR := Color(0.86, 0.45, 0.55)

var t := 0.0
var _tex: Array[Texture2D] = []
var _mouse := Vector2.ZERO       # smoothed, -0.5..0.5
var _petals: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in LAYERS:
		_tex.append(Moves.tex(str(l["file"])))
	rng.seed = 11
	for i in 46:
		_petals.append(_new_petal(true))

func _new_petal(anywhere: bool) -> Dictionary:
	return {"x": rng.randf_range(-0.1, 1.0), "y": rng.randf_range(-0.1, 1.0) if anywhere else rng.randf_range(-0.15, -0.02),
		"vx": rng.randf_range(0.015, 0.05), "vy": rng.randf_range(0.03, 0.08), "s": rng.randf_range(3.0, 7.5),
		"rot": rng.randf() * TAU, "spin": rng.randf_range(-2.5, 2.5), "ph": rng.randf() * TAU,
		"depth": rng.randf_range(0.03, 0.1)}

func _process(delta: float) -> void:
	t += delta
	if is_inside_tree() and size.x > 2.0:
		var m := get_local_mouse_position() / size - Vector2(0.5, 0.5)
		_mouse = _mouse.lerp(m.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)), 1.0 - exp(-delta * 4.0))
	for p in _petals:
		p["x"] = float(p["x"]) + float(p["vx"]) * delta + sin(t * 1.3 + float(p["ph"])) * 0.0006
		p["y"] = float(p["y"]) + float(p["vy"]) * delta
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		if float(p["y"]) > 1.08 or float(p["x"]) > 1.1:
			p.merge(_new_petal(false), true)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	# sky gradient behind everything
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.7), Vector2(0, h * 0.7)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON]))
	draw_rect(Rect2(0, h * 0.7 - 1.0, w, h * 0.3 + 1.0), SKY_HORIZON)
	for i in LAYERS.size():
		var tex := _tex[i]
		if tex == null:
			continue
		var l: Dictionary = LAYERS[i]
		var depth := float(l["depth"])
		var lw := w * OVERSCAN
		var lh := lw * float(tex.get_height()) / float(tex.get_width())
		var sway := Vector2(sin(t * 0.21 + i) * 0.004, cos(t * 0.17 + i * 1.7) * 0.002) * w * depth * 20.0
		var off := Vector2(-_mouse.x * w * depth, -_mouse.y * h * depth * 0.5) + sway
		var x := (w - lw) * 0.5 + off.x
		var y := (h * float(l["y"]) - (lh if l["anchor"] == "bottom" else 0.0)) + off.y
		draw_texture_rect(tex, Rect2(x, y, lw, lh), false)
		if l.has("fill"):   # carry the layer's colour down (fading darker) so no gap shows
			var fc: Color = l["fill"]
			var top := y + lh - 2.0
			var dark := fc.darkened(0.55)
			draw_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + lw, top), Vector2(x + lw, h), Vector2(x, h)]),
				PackedColorArray([fc, fc, dark, dark]))
		if i == 3:          # petals between the village and the near layers
			_draw_petals(w, h)

func _draw_petals(w: float, h: float) -> void:
	for p in _petals:
		var d := float(p["depth"])
		var c := Vector2(float(p["x"]) * w - _mouse.x * w * d, float(p["y"]) * h - _mouse.y * h * d * 0.5)
		var s := float(p["s"])
		var r := float(p["rot"])
		var flip := 0.35 + 0.65 * absf(sin(t * 2.0 + float(p["ph"])))   # tumbling
		var pts := PackedVector2Array([
			c + Vector2(-s, 0).rotated(r), c + Vector2(0, -s * 0.45 * flip).rotated(r),
			c + Vector2(s, 0).rotated(r), c + Vector2(0, s * 0.45 * flip).rotated(r)])
		draw_colored_polygon(pts, Color(PETAL_COLOR.r, PETAL_COLOR.g, PETAL_COLOR.b, 0.85))
