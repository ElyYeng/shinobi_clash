class_name MenuBG
extends Control
## Parallax menu backdrop (main menu, multiplayer lobby, Customize). Five painted layers from
## res://assets/menu/ move with the mouse - far layers barely, near layers more - plus a slow
## idle sway and falling petals. Replace a PNG to change a layer; tune LAYERS below.

## The five painted layers stack into one scene, each overlapping the one behind it: the mountains
## cover the bottom of the sky (the moon sets behind the Hokage cliffs), the village covers the
## mountains' base, the grass sits on the bottom edge and the cherry branch frames the top-left.
## `top` = where the layer's top edge sits (fraction of the screen height), "bottom" = bottom edge
## on the screen's bottom. depth = how much it follows the mouse (far small, near big).
const LAYER_W := 1.5            # every layer is drawn this many screen-widths wide (same scale)
const LAYERS := [
	{"file": "res://assets/menu/parallax_1_sky.png", "depth": 0.010, "top": 0.0},
	{"file": "res://assets/menu/parallax_2_mountains.png", "depth": 0.018, "top": 0.27},
	{"file": "res://assets/menu/parallax_3_village.png", "depth": 0.030, "top": 0.47},
	{"file": "res://assets/menu/parallax_5_foreground.png", "depth": 0.060, "bottom": true},
	{"file": "res://assets/menu/parallax_4_tree.png", "depth": 0.050, "top": -0.04},
]
const SKY_TOP := Color(0.06, 0.025, 0.04)
const SKY_HORIZON := Color(0.33, 0.15, 0.19)
const GROUND_DARK := Color(0.13, 0.06, 0.08)
const MOON := Vector2(1155.0, 109.0)   # moon centre inside the sky layer
const MOON_R := 145.0
const PETAL_COLOR := Color(0.86, 0.45, 0.55)

var t := 0.0
var _tex: Array[Texture2D] = []
var _base_col: Array[Color] = []   # average colour of each layer's bottom rows (for seams)
var _top_col: Array[Color] = []
var _mouse := Vector2.ZERO       # smoothed, -0.5..0.5
var _petals: Array = []
var _mists: Array = []
var _soft: Texture2D             # radial white->clear blob (glow / mist)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for l in LAYERS:
		var tex := Moves.tex(str(l["file"]))
		_tex.append(tex)
		_base_col.append(_row_colour(tex, true))
		_top_col.append(_row_colour(tex, false))
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_soft = gt
	rng.seed = 11
	for i in 46:
		_petals.append(_new_petal(true))
	for i in 9:
		_mists.append({"x": rng.randf_range(-0.2, 1.1), "y": rng.randf_range(430.0, 640.0), "w": rng.randf_range(260.0, 520.0),
			"v": rng.randf_range(0.004, 0.012) * (1.0 if rng.randf() < 0.5 else -1.0), "a": rng.randf_range(0.06, 0.13)})

## Average colour of the opaque pixels in a layer's bottom (or top) rows.
func _row_colour(tex: Texture2D, bottom: bool) -> Color:
	if tex == null:
		return SKY_HORIZON
	var img := tex.get_image()
	if img == null:
		return SKY_HORIZON
	if img.is_compressed():
		img.decompress()
	var acc := Vector3.ZERO
	var n := 0.0
	var h := img.get_height()
	for k in 6:
		var yy := h - 2 - k * 2 if bottom else 2 + k * 2
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, clampi(yy, 0, h - 1))
			if c.a > 0.8:
				acc += Vector3(c.r, c.g, c.b)
				n += 1.0
	return Color(acc.x / n, acc.y / n, acc.z / n) if n > 0.0 else SKY_HORIZON

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
	for m in _mists:
		m["x"] = wrapf(float(m["x"]) + float(m["v"]) * delta, -0.4, 1.3)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	var lw := w * LAYER_W
	var s := lw / 1624.0            # art pixels -> screen pixels (all layers share it)
	var ox := (w - lw) * 0.5
	# where each layer lands (before parallax), so the seams can be filled between them
	var rects: Array[Rect2] = []
	for l in LAYERS:
		var i := rects.size()
		var th := float(_tex[i].get_height()) * s if _tex[i] != null else 0.0
		var y := h - th if l.has("bottom") else h * float(l["top"])
		rects.append(Rect2(ox, y, lw, th))

	# sky gradient behind everything
	var hz := rects[1].end.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hz), Vector2(0, hz)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON]))
	draw_rect(Rect2(0, hz - 1.0, w, h - hz + 1.0), SKY_HORIZON)

	for i in LAYERS.size():
		var tex := _tex[i]
		if tex == null:
			continue
		var depth := float(LAYERS[i]["depth"])
		var sway := Vector2(sin(t * 0.21 + i) * 0.004, cos(t * 0.17 + i * 1.7) * 0.002) * w * depth * 20.0
		var off := Vector2(-_mouse.x * w * depth, -_mouse.y * h * depth * 0.5) + sway
		var rc := rects[i]
		var pos := rc.position + off
		if i == 0:   # moon glow behind the sky layer (slow pulse)
			var mc := pos + MOON * s
			var gr := MOON_R * s * (2.3 + sin(t * 0.8) * 0.08)
			draw_texture_rect(_soft, Rect2(mc - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.36, 0.26, 0.32))
		if i == 2:   # mountain base continues down behind the village (hidden by it)
			var mb := _base_col[1]
			var y0 := rects[1].end.y - 4.0
			var y1 := rc.end.y - 4.0
			draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
				PackedColorArray([mb, mb, _base_col[2], _base_col[2]]))
		if i == 3:   # ground below the village: its mist fading into dark earth, then drifting mist
			var vb := _base_col[2]
			var g0 := rects[2].end.y - 3.0
			var g1 := g0 + 120.0 * s
			draw_polygon(PackedVector2Array([Vector2(0, g0), Vector2(w, g0), Vector2(w, g1), Vector2(0, g1)]),
				PackedColorArray([vb, vb, GROUND_DARK, GROUND_DARK]))
			draw_rect(Rect2(0, g1 - 1.0, w, h - g1 + 1.0), GROUND_DARK)
			_draw_mist(s, rects[2].position.y, w)
		draw_texture_rect(tex, Rect2(pos, rc.size), false)
		if i == 3:          # petals between the ground and the cherry branch
			_draw_petals(w, h)
	_draw_shade(w, h)

func _draw_mist(s: float, village_top: float, w: float) -> void:
	for m in _mists:
		var mw := float(m["w"]) * s * 0.8
		var c := Vector2(float(m["x"]) * w - _mouse.x * w * 0.035, village_top + (float(m["y"]) - 418.0) * s)
		draw_texture_rect(_soft, Rect2(c - Vector2(mw, mw * 0.16), Vector2(mw * 2.0, mw * 0.32)), false,
			Color(0.85, 0.7, 0.75, float(m["a"])))

## Darkens the left side (behind the buttons) and the edges, so the menu reads clearly.
func _draw_shade(w: float, h: float) -> void:
	var dark := Color(0.03, 0.01, 0.02, 0.62)
	var clear := Color(0.03, 0.01, 0.02, 0.0)
	var x1 := w * 0.55
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	var vt := Color(0, 0, 0, 0.35)
	var vc := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.18), Vector2(0, h * 0.18)]),
		PackedColorArray([vt, vt, vc, vc]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.8), Vector2(w, h * 0.8), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([vc, vc, vt, vt]))

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
