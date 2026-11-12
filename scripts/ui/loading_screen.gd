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
	# the UI kit's big framed parchment in the middle, ribbon title on top
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.tex_box("frame_big", [70, 60, 70, 64], [90, 80, 90, 70]))
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -360
	frame.offset_right = 360
	frame.offset_top = -130
	frame.offset_bottom = 150
	_root.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(v)
	_stage = _box_label(v, "Gathering chakra...", 22, Color(0.16, 0.1, 0.06))
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 26)
	_bar.add_theme_stylebox_override("background", UiStyle.tex_box("bar_track", [18, 11, 24, 12]))
	var fill := StyleBoxTexture.new()
	fill.texture = load(UiStyle.UI + "bar_fill.png")
	fill.modulate_color = Color(1.0, 0.62, 0.18)
	fill.content_margin_left = 17
	_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(_bar)
	_pct = _box_label(v, "0%", 15, Color(0.35, 0.22, 0.12))
	var tip := _box_label(v, "TIP:  " + str(TIPS[randi() % TIPS.size()]), 16, Color(0.3, 0.2, 0.12))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 500
	var ribbon := PanelContainer.new()   # title on the red leaf ribbon, over the frame's top edge
	ribbon.add_theme_stylebox_override("panel", UiStyle.tex_box("ribbon_leaf_red", [96, 0, 70, 0], [100, 6, 60, 6]))
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.anchor_top = 0.5
	ribbon.anchor_bottom = 0.5
	ribbon.offset_left = -250
	ribbon.offset_right = 250
	ribbon.offset_top = -190
	ribbon.offset_bottom = -126
	_root.add_child(ribbon)
	var title := Label.new()
	title.text = "SHINOBI CLASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", GameMenu.font())
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	title.add_theme_constant_override("outline_size", 8)
	ribbon.add_child(title)
	var spin := Shuriken.new()
	spin.anchor_left = 0.5
	spin.anchor_right = 0.5
	spin.anchor_top = 0.5
	spin.anchor_bottom = 0.5
	spin.offset_left = -36
	spin.offset_right = 36
	spin.offset_top = -300
	spin.offset_bottom = -228
	spin.pivot_offset = Vector2(36, 36)
	_root.add_child(spin)
	_shuriken = spin
	ResourceLoader.load_threaded_request(_path)

func _box_label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameMenu.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

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
