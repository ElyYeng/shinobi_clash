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
var _shuriken: Label
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

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var band := ColorRect.new()   # a red brush band across the middle
	band.color = Color(0.55, 0.08, 0.06, 0.85)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.42
	band.anchor_bottom = 0.58
	_root.add_child(band)
	var title := _label("SHINOBI CLASH", 56, Color(0.98, 0.92, 0.8))
	title.anchor_top = 0.42
	title.anchor_bottom = 0.58
	_shuriken = _label("✦", 64, Color(0.85, 0.85, 0.9))
	_shuriken.anchor_top = 0.2
	_shuriken.anchor_bottom = 0.36
	_shuriken.pivot_offset = Vector2.ZERO
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_left = 0.3
	_bar.anchor_right = 0.7
	_bar.anchor_top = 0.72
	_bar.anchor_bottom = 0.72
	_bar.offset_bottom = 10
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.6, 0.15)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.2, 0.16, 0.14)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	_root.add_child(_bar)
	var loading := _label("LOADING...", 20, Color(0.9, 0.8, 0.6))
	loading.anchor_top = 0.65
	loading.anchor_bottom = 0.7
	var tip := _label("TIP: " + str(TIPS[randi() % TIPS.size()]), 17, Color(0.75, 0.72, 0.68))
	tip.anchor_top = 0.8
	tip.anchor_bottom = 0.9
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
	_shuriken.pivot_offset = _shuriken.size * 0.5
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
