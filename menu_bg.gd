class_name MenuBG
extends Control
## Animated menu backdrop drawn entirely in code: blood moon, glowing Kurama eyes, mountain ridges, drifting embers.

var t := 0.0
var embers: Array = []
var stars: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = 7
	for i in 110:
		embers.append({"x": rng.randf(), "y": rng.randf(), "v": rng.randf_range(0.03, 0.13), "s": rng.randf_range(1.2, 4.2), "ph": rng.randf() * TAU})
	for i in 140:
		stars.append(Vector3(rng.randf(), rng.randf() * 0.62, rng.randf() * TAU))

func _process(delta: float) -> void:
	t += delta
	for e in embers:
		e["y"] = float(e["y"]) - float(e["v"]) * delta
		if float(e["y"]) < -0.05:
			e["y"] = 1.05
			e["x"] = rng.randf()
	queue_redraw()

func _ridge(w: float, h: float, base: float, amp: float, f1: float, f2: float, ph: float, off: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		var x := -80.0 + (w + 160.0) * float(i) / float(steps)
		var n := 0.5 + 0.5 * sin(x * f1 + ph) * 0.65 + 0.5 * sin(x * f2 + ph * 2.3) * 0.35
		pts.append(Vector2(x + off, h * base - amp * n))
	pts.append(Vector2(w + 80.0 + off, h + 4.0))
	pts.append(Vector2(-80.0 + off, h + 4.0))
	return pts

func _almond(c: Vector2, rx: float, ry: float, rot: float, up: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var u := -1.0 + 2.0 * float(i) / float(steps)
		var y := sqrt(maxf(0.0, 1.0 - u * u)) * ry * (-1.0 if up else 1.0)
		pts.append(c + Vector2(u * rx, y).rotated(rot))
	return pts

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	var m := Vector2.ZERO
	if is_inside_tree():
		m = get_local_mouse_position() / size - Vector2(0.5, 0.5)
		m = m.clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
	# sky: indigo -> blood red at the horizon
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.6), Vector2(0, h * 0.6)]),
		PackedColorArray([Color(0.015, 0.015, 0.06), Color(0.015, 0.015, 0.06), Color(0.2, 0.05, 0.1), Color(0.2, 0.05, 0.1)]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.6), Vector2(w, h * 0.6), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(0.2, 0.05, 0.1), Color(0.2, 0.05, 0.1), Color(0.75, 0.22, 0.06), Color(0.75, 0.22, 0.06)]))
	# stars
	for s in stars:
		var sv: Vector3 = s
		var a := 0.25 + 0.5 * (0.5 + 0.5 * sin(t * 1.6 + sv.z))
		draw_circle(Vector2(sv.x * w, sv.y * h) + m * -6.0, 1.2, Color(1, 0.9, 0.9, a))
	# moon with glow
	var mc := Vector2(w * 0.74, h * 0.3) + m * -14.0
	var mr := minf(w, h) * 0.13
	for i in 8:
		draw_circle(mc, mr * (1.0 + float(i) * 0.35), Color(1.0, 0.25, 0.12, 0.035))
	draw_circle(mc, mr, Color(0.98, 0.5, 0.35))
	draw_circle(mc + Vector2(-mr * 0.25, -mr * 0.2), mr * 0.28, Color(0.9, 0.38, 0.28, 0.5))
	draw_circle(mc + Vector2(mr * 0.3, mr * 0.25), mr * 0.2, Color(0.9, 0.38, 0.28, 0.45))
	draw_circle(mc + Vector2(mr * 0.15, -mr * 0.45), mr * 0.12, Color(0.9, 0.38, 0.28, 0.4))
	# Kurama's eyes watching from the clouds
	var pulse := 0.16 + 0.07 * sin(t * 1.3)
	var ec := Vector2(w * 0.27, h * 0.27) + m * -10.0
	var ew := minf(w, h) * 0.09
	for side in [-1.0, 1.0]:
		var c: Vector2 = ec + Vector2(side * ew * 1.9, 0)
		var rot: float = -0.38 * side
		var top := _almond(c, ew, ew * 0.5, rot, true)
		var bot := _almond(c, ew, ew * 0.5, rot, false)
		var poly := PackedVector2Array()
		poly.append_array(top)
		bot.reverse()
		poly.append_array(bot)
		draw_colored_polygon(poly, Color(1.0, 0.22, 0.08, pulse))
		draw_line(c + Vector2(0, -ew * 0.42).rotated(rot), c + Vector2(0, ew * 0.42).rotated(rot), Color(0.05, 0.0, 0.02, pulse * 3.0), 5.0)
	# mountain ridges (parallax)
	draw_colored_polygon(_ridge(w, h, 0.72, h * 0.16, 0.004, 0.011, 1.0, m.x * -18.0), Color(0.28, 0.07, 0.09))
	draw_colored_polygon(_ridge(w, h, 0.8, h * 0.17, 0.0055, 0.014, 3.4, m.x * -34.0), Color(0.13, 0.04, 0.06))
	draw_colored_polygon(_ridge(w, h, 0.9, h * 0.15, 0.007, 0.02, 5.1, m.x * -56.0), Color(0.04, 0.015, 0.03))
	# drifting embers
	for e in embers:
		var ex := float(e["x"]) * w + sin(t * 0.8 + float(e["ph"])) * 18.0 + m.x * -30.0
		var ey := float(e["y"]) * h
		var s := float(e["s"])
		var fl := 0.55 + 0.45 * sin(t * 4.0 + float(e["ph"]))
		draw_circle(Vector2(ex, ey), s * 2.6, Color(1.0, 0.4, 0.1, 0.07 * fl))
		draw_circle(Vector2(ex, ey), s, Color(1.0, 0.7, 0.25, 0.85 * fl))
