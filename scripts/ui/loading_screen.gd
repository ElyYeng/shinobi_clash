class_name LoadingScreen
extends CanvasLayer
## Loading screen between scenes: ink-dark backdrop, a spinning shuriken, a progress bar and a
## random tip. Loads the next scene on a background thread, switches to it, then waits a moment
## for the world to finish setting up before fading away. Use LoadingScreen.go(tree, path).

const TIPS := [
	"Hold C to charge chakra - keep holding to power up your bloodline.",
	"Middle mouse locks on. Scroll to switch targets, Alt + scroll to zoom.",
	"Run at a wall to walk up it with chakra on your feet.",
	"Substitution leaves a log behind and puts you behind your enemy.",
	"Villagers with a ! have errands for you.",
	"Press Tab to see who's online and their levels.",
	"F2 opens photo mode - Enter takes a picture.",
	"Spins can roll rare bloodlines - Mythics are the rarest.",
	"Every 10th level quest gives a bonus level.",
	"K mutes your mic in multiplayer voice chat.",
	"Gather quest items run away - catch them on the third try.",
	"Your Susanoo comes in your own colour - Kakashi's is blue, Shisui's green.",
]

var _path := ""
var _bar: ProgressBar
var _shuriken: Control
var _root: Control
var _done := false
var _settle := 0.0

static func go(tree: SceneTree, path: String) -> void:
	if tree.root.get_node_or_null("LoadingScreen") != null:
		return
	var ls := LoadingScreen.new()
	ls.name = "LoadingScreen"
	ls._path = path
	ls.layer = 120
	ls.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(ls)   # (deferred: safe even while a scene is still setting up)

## A spinning four-point shuriken (drawn, so it never depends on a font glyph).
class Shuriken extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var pts := PackedVector2Array()
		for i in 8:
			var a := TAU * i / 8.0 - PI * 0.5
			var rr := r if i % 2 == 0 else r * 0.3
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, Color(0.78, 0.8, 0.86))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.15, 0.15, 0.18), 3.0)
		draw_circle(c, r * 0.13, Color(0.07, 0.05, 0.05))

var _stage: Label
var _pct: Label

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()   # ink backdrop with a soft red glow in the middle
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 p = UV - 0.5; p.x *= 1.6; float g = 1.0 - smoothstep(0.0, 0.75, length(p));\n COLOR = vec4(mix(vec3(0.04, 0.03, 0.03), vec3(0.32, 0.06, 0.05), g * 0.8), 1.0); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	bg.material = sm
	_root.add_child(bg)
	var band := TextureRect.new()   # red brush stroke behind the title
	band.texture = load(UiStyle.UI + "brush_red.png") if ResourceLoader.exists(UiStyle.UI + "brush_red.png") else null
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.anchor_left = 0.18
	band.anchor_right = 0.82
	band.anchor_top = 0.4
	band.anchor_bottom = 0.58
	band.modulate = Color(1, 1, 1, 0.9)
	_root.add_child(band)
	var title := _label("SHINOBI CLASH", 60, Color(0.98, 0.94, 0.84))
	title.anchor_top = 0.4
	title.anchor_bottom = 0.58
	var spin := Shuriken.new()
	spin.anchor_left = 0.5
	spin.anchor_right = 0.5
	spin.anchor_top = 0.24
	spin.anchor_bottom = 0.24
	spin.offset_left = -40
	spin.offset_right = 40
	spin.offset_top = -40
	spin.offset_bottom = 40
	spin.pivot_offset = Vector2(40, 40)
	_root.add_child(spin)
	_shuriken = spin
	# progress: the HUD's iron bar frame + fill
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_left = 0.3
	_bar.anchor_right = 0.7
	_bar.anchor_top = 0.7
	_bar.anchor_bottom = 0.7
	_bar.offset_bottom = 16
	if ResourceLoader.exists(UiStyle.UI + "bar_track.png"):
		_bar.add_theme_stylebox_override("background", UiStyle.tex_box("bar_track", [18, 11, 24, 12]))
		var fill := StyleBoxTexture.new()
		fill.texture = load(UiStyle.UI + "bar_fill.png")
		fill.modulate_color = Color(1.0, 0.65, 0.2)
		_bar.add_theme_stylebox_override("fill", fill)
	else:
		var f2 := StyleBoxFlat.new()
		f2.bg_color = Color(0.95, 0.6, 0.15)
		_bar.add_theme_stylebox_override("fill", f2)
	_root.add_child(_bar)
	_stage = _label("Gathering chakra...", 19, Color(0.92, 0.82, 0.6))
	_stage.anchor_top = 0.63
	_stage.anchor_bottom = 0.68
	_pct = _label("0%", 15, Color(0.85, 0.8, 0.72))
	_pct.anchor_top = 0.75
	_pct.anchor_bottom = 0.79
	var tip := _label("TIP:  " + str(TIPS[randi() % TIPS.size()]), 17, Color(0.78, 0.75, 0.7))
	tip.anchor_top = 0.83
	tip.anchor_bottom = 0.93
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ResourceLoader.load_threaded_request(_path)

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.anchor_left = 0.1
	l.anchor_right = 0.9
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameMenu.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	_root.add_child(l)
	return l

func _process(delta: float) -> void:
	_shuriken.rotation += delta * 6.0
	_pct.text = "%d%%" % int(_bar.value)
	_stage.text = "Gathering chakra..." if _bar.value < 30.0 else ("Opening the village gates..." if _bar.value < 85.0 else ("Waking the villagers..." if not _done else "Ready!"))
	if _done:
		_settle -= delta   # the new world is building itself: keep covering it for a moment
		_bar.value = lerpf(_bar.value, 100.0, minf(1.0, 6.0 * delta))
		if _settle <= 0.0 and not has_meta("fading"):
			set_meta("fading", true)
			var tw := create_tween()
			tw.tween_property(_root, "modulate:a", 0.0, 0.4)
			tw.tween_callback(queue_free)
		return
	var prog := []
	var st := ResourceLoader.load_threaded_get_status(_path, prog)
	if not prog.is_empty():
		_bar.value = maxf(_bar.value, float(prog[0]) * 90.0)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		var ps := ResourceLoader.load_threaded_get(_path) as PackedScene
		_done = true
		_settle = 1.0
		get_tree().change_scene_to_packed(ps)
	elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		_settle = 0.3
		get_tree().change_scene_to_file(_path)   # (fallback: plain load)
