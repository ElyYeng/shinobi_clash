class_name GameMenu
extends CanvasLayer
## Scroll-style in-game menu. Press M to open / close it.
## Left: tabs (brush-stroke buttons). Middle: list of entries for the tab.
## Right: details + action buttons for the selected entry.
## To add a tab: add its name to TABS and a branch in _build_items().
## To change the look: the colour constants below and the draw code in the inner classes.

const INK := Color(0.04, 0.03, 0.03)
const PARCH := Color(0.87, 0.83, 0.66)
const GOLD := Color(0.84, 0.73, 0.36)
const GOLD_DK := Color(0.62, 0.5, 0.2)
const GREEN := Color(0.04, 0.55, 0.3)
const GREEN_DK := Color(0.02, 0.3, 0.16)
const BTN := Color(0.22, 0.62, 0.12)
const BODY_TEXT := Color(0.16, 0.1, 0.05)
const SCROLL_SIZE := Vector2(900, 580)
const TABS := ["Stats", "Ninja Tools", "Element", "Bloodline", "Sub-Ability", "Companions",
	"Travel", "Mastery", "Cheats", "Customs", "Controls"]
const MODE_NAMES := {"fight": "Arena", "world": "Open World", "kurama": "Kurama Boss Fight"}
const MODE_ORDER := ["fight", "world", "kurama"]

static var _font: Font

## Bold ink-style font (falls back to the default font if none of these exist on the machine).
static func font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Impact", "Arial Black", "Haettenschweiler", "Bangers", "Sans-Serif"])
		sf.font_weight = 800
		_font = sf
	return _font

# ------------------------------------------------------------------ inner widgets
class Octagon extends Control:
	var fill := Color(0.04, 0.03, 0.03)
	var kind := "empty"      # empty | lock | letter
	var letter := ""
	var ring := false
	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size / 2.0
		var r := size.x / 2.0 - 2.0
		var pts := PackedVector2Array()
		for i in 8:
			var a := deg_to_rad(22.5 + 45.0 * i)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, fill)
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Color.BLACK, 3.0)
		if ring:
			draw_polyline(loop, Color(1.0, 0.92, 0.4), 2.0)
		if kind == "lock":
			var red := Color(0.85, 0.08, 0.08)
			draw_rect(Rect2(c.x - 9.0, c.y - 2.0, 18.0, 13.0), red)
			draw_arc(Vector2(c.x, c.y - 2.0), 6.0, PI, TAU, 12, red, 3.0)
		elif kind == "letter":
			var f := GameMenu.font()
			var s := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
			var pos := Vector2(c.x - s.x / 2.0, c.y + 8.0)
			draw_string_outline(f, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color.BLACK)
			draw_string(f, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

class Coin extends Control:
	var color := Color(0.9, 0.2, 0.1)
	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 21.0, Color.BLACK)
		draw_circle(c, 17.0, color)
		draw_circle(c, 11.0, color.darkened(0.45))
		draw_circle(c, 6.0, color.lightened(0.2))

class BrushTab extends Control:
	signal pressed
	var text := ""
	var selected := false
	var hover := false
	var indent := 0.0
	var poly := PackedVector2Array()
	func setup(t: String, w: float, h: float, ind: float) -> void:
		text = t
		indent = ind
		custom_minimum_size = Vector2(w, h)
		size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(t)
		var x := ind + 2.0
		poly.append(Vector2(ind + rng.randf_range(0.0, 4.0), h * 0.5))
		while x < w - 10.0:      # jagged top edge like a brush stroke
			poly.append(Vector2(x, rng.randf_range(1.0, 7.0)))
			x += rng.randf_range(6.0, 12.0)
		poly.append(Vector2(w - rng.randf_range(0.0, 5.0), h * 0.35))
		poly.append(Vector2(w - rng.randf_range(0.0, 5.0), h * 0.7))
		x = w - 10.0
		while x > ind + 6.0:     # jagged bottom edge
			poly.append(Vector2(x, h - rng.randf_range(1.0, 7.0)))
			x -= rng.randf_range(6.0, 12.0)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			hover = true
			queue_redraw()
		elif what == NOTIFICATION_MOUSE_EXIT:
			hover = false
			queue_redraw()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
	func _draw() -> void:
		var col := Color(0.04, 0.03, 0.03)
		if selected:
			col = Color(0.55, 0.05, 0.05)
		elif hover:
			col = Color(0.22, 0.1, 0.08)
		draw_colored_polygon(poly, col)
		var f := GameMenu.font()
		var pos := Vector2(indent + 18.0, size.y * 0.5 + 8.0)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color.BLACK)
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

class Card extends Control:
	signal pressed
	var title := ""
	var sub := ""
	var glyph := ""
	var color := Color.WHITE
	var locked := false
	var selected := false
	var hover := false
	var progress := -1.0
	func setup(w: float) -> void:
		custom_minimum_size = Vector2(w, 66)
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			hover = true
			queue_redraw()
		elif what == NOTIFICATION_MOUSE_EXIT:
			hover = false
			queue_redraw()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
	func _draw() -> void:
		var f := GameMenu.font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18 if hover else 0.08))
		var thumb := Rect2(4, 4, 58, 58)
		draw_rect(thumb, Color.BLACK)
		var i := thumb.grow(-3.0)
		var top := color.lightened(0.15) if not locked else Color(0.45, 0.45, 0.45)
		var bot := color.darkened(0.45) if not locked else Color(0.2, 0.2, 0.2)
		draw_polygon(PackedVector2Array([i.position, Vector2(i.end.x, i.position.y), i.end, Vector2(i.position.x, i.end.y)]),
			PackedColorArray([top, top, bot, bot]))
		var gs := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var gp := Vector2(thumb.get_center().x - gs.x / 2.0, thumb.get_center().y + 11.0)
		draw_string_outline(f, gp, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 6, Color.BLACK)
		draw_string(f, gp, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		draw_string(f, Vector2(72, 28), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 80.0, 20, GameMenu.INK)
		draw_string(f, Vector2(72, 47), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 80.0, 14, Color(0.3, 0.2, 0.1))
		if progress >= 0.0:
			var bar := Rect2(72, 53, size.x - 84.0, 7)
			draw_rect(bar, Color.BLACK)
			draw_rect(bar.grow(-1.0), Color(0.25, 0.2, 0.15))
			var fill := bar.grow(-1.0)
			fill.size.x *= clampf(progress, 0.0, 1.0)
			draw_rect(fill, Color(0.85, 0.65, 0.15))
		if selected:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.08, 0.08), false, 3.0)

# ------------------------------------------------------------------ state
var p: Player
var main: Node
var is_open := false
var root: Control
var scroll: Control
var header: Control
var title_label: Label
var list_scroll: ScrollContainer
var list_box: VBoxContainer
var detail: Control
var tab := 0
var sel := 0
var items: Array = []
var extras: Array = []      # buttons shown under every entry of the current tab (e.g. Travel)
var tab_nodes: Array = []
var card_nodes: Array = []

func bind(player: Player, main_node: Node) -> void:
	p = player
	main = main_node

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll = Control.new()
	scroll.custom_minimum_size = SCROLL_SIZE
	scroll.size = SCROLL_SIZE
	scroll.pivot_offset = SCROLL_SIZE / 2.0
	root.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	_build_scroll_frame()
	header = Control.new()
	header.size = SCROLL_SIZE
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(header)
	# tabs
	for i in TABS.size():
		var t := BrushTab.new()
		t.setup(TABS[i], 205.0, 34.0, 0.0 if i % 2 == 0 else 26.0)
		t.position = Vector2(34, 158 + i * 35)
		t.pressed.connect(_select_tab.bind(i))
		scroll.add_child(t)
		tab_nodes.append(t)
	_rect(Rect2(248, 154, 4, 396), INK)
	_rect(Rect2(566, 154, 4, 396), INK)
	# middle list
	list_scroll = ScrollContainer.new()
	list_scroll.position = Vector2(258, 154)
	list_scroll.size = Vector2(304, 396)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	list_scroll.add_child(list_box)
	# right panel
	detail = Control.new()
	detail.position = Vector2(580, 152)
	detail.size = Vector2(282, 396)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(detail)
	root.visible = false

func _rect(r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(c)
	return c

func _panel(r: Rect2, col: Color, border := Color.BLACK, bw := 3, radius := 0) -> Panel:
	var pn := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	pn.add_theme_stylebox_override("panel", sb)
	pn.position = r.position
	pn.size = r.size
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(pn)
	return pn

func _build_scroll_frame() -> void:
	_panel(Rect2(26, 12, 848, 556), PARCH, GOLD_DK, 3)
	_rect(Rect2(26, 12, 848, 28), GOLD)           # top bar
	_rect(Rect2(26, 40, 848, 3), GOLD_DK)
	_rect(Rect2(26, 552, 848, 16), GOLD)          # bottom bar
	_rect(Rect2(26, 550, 848, 3), GOLD_DK)
	title_label = Label.new()
	title_label.position = Vector2(26, 12)
	title_label.size = Vector2(848, 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(title_label, 19, Color.WHITE, 6)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(title_label)
	for side in [0, 1]:       # green rollers with gold caps + wooden pegs
		var x := 0.0 if side == 0 else 868.0
		_panel(Rect2(x + 2, 6, 30, 568), GREEN, INK, 3, 3)
		_rect(Rect2(x + 10, 12, 6, 556), GREEN.lightened(0.18))
		_rect(Rect2(x - 1 if side == 0 else x + 1, 6, 34, 20), GOLD)
		_rect(Rect2(x - 1 if side == 0 else x + 1, 554, 34, 20), GOLD)
		_rect(Rect2(x + 10, 0, 14, 8), Color(0.45, 0.25, 0.2))
		_rect(Rect2(x + 10, 572, 14, 8), Color(0.45, 0.25, 0.2))

func _style_label(l: Label, size: int, col: Color, outline := 0) -> void:
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", outline)

# ------------------------------------------------------------------ open / close
func can_open() -> bool:
	if main != null:
		var dlg = main.get("dialog")
		if dlg != null and dlg.is_open:
			return false
		var sp = main.get("spin")
		if sp != null and sp.root.visible:
			return false
	return true

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open or not can_open():
		return
	is_open = true
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vp := get_viewport().get_visible_rect().size
	var s := minf(1.0, minf(vp.x / (SCROLL_SIZE.x + 20.0), vp.y / (SCROLL_SIZE.y + 20.0)))
	scroll.scale = Vector2(s, s)
	_refresh_header()
	_select_tab(tab)

func close() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	get_tree().paused = false
	if p != null and not p.is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("to_menu"):
		if is_open or can_open():
			toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("spin_menu"):
		_open_spin()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ header
func rank() -> String:
	var done := GameData.quests_done.size()
	if done >= Quests.DEFS.size():
		return "S"
	if done >= 5:
		return "A"
	if done >= 3:
		return "B"
	if done >= 2:
		return "C"
	return "D"

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _hlabel(text: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	_style_label(l, size, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(l)
	return l

func _refresh_header() -> void:
	_clear(header)
	var def := Bloodline.get_def(GameData.equipped)
	var mname: String = MODE_NAMES.get(GameData.mode, "Arena")
	title_label.text = "SHINOBI   [%s-Rank]   -   %s" % [rank(), mname]
	# row 1: owned elements | spins
	for i in GameData.ELEMENTS.size():
		var element: String = GameData.ELEMENTS[i]
		var o := Octagon.new()
		o.position = Vector2(46 + i * 50, 52)
		if GameData.owned_elements.has(element):
			o.kind = "letter"
			o.letter = element.substr(0, 1)
			o.fill = GameData.get_element_color(element).darkened(0.12)
			o.ring = element == GameData.equipped_element
		else:
			o.kind = "lock"
		header.add_child(o)
	_hlabel("%s Style" % GameData.equipped_element, Vector2(304, 50), 34, INK)
	_rect_h(Rect2(304, 92, 330, 3))
	var c1 := Coin.new()
	c1.position = Vector2(656, 52)
	c1.color = GameData.get_element_color()
	header.add_child(c1)
	_hlabel(str(GameData.spins), Vector2(712, 50), 34, Color(0.85, 0.12, 0.05))
	_rect_h(Rect2(650, 92, 210, 3))
	# row 2: owned bloodlines | kills
	var owned_ids: Array = []
	for id in Bloodline.DEFS:
		if id != "none" and GameData.owned.has(id):
			owned_ids.append(id)
	for i in 5:
		var o2 := Octagon.new()
		o2.position = Vector2(46 + i * 50, 100)
		if i < owned_ids.size():
			var bd := Bloodline.get_def(owned_ids[i])
			o2.kind = "letter"
			o2.letter = str(bd["name"]).substr(0, 1)
			o2.fill = bd["color"].darkened(0.25)
			o2.ring = owned_ids[i] == GameData.equipped
		else:
			o2.kind = "lock"
		header.add_child(o2)
	_hlabel(def["name"] if GameData.equipped != "none" else "N/A", Vector2(304, 98), 34, INK)
	_rect_h(Rect2(304, 140, 330, 3))
	var c2 := Coin.new()
	c2.position = Vector2(656, 100)
	c2.color = Color(0.85, 0.62, 0.1)
	header.add_child(c2)
	_hlabel(str(p.kills if p != null else 0), Vector2(712, 98), 34, Color(0.8, 0.55, 0.05))
	_rect_h(Rect2(650, 140, 210, 3))

func _rect_h(r: Rect2) -> void:
	var c := ColorRect.new()
	c.color = INK
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(c)

# ------------------------------------------------------------------ tabs / list / detail
func _select_tab(i: int) -> void:
	tab = i
	sel = 0
	for n in tab_nodes.size():
		tab_nodes[n].selected = n == i
		tab_nodes[n].queue_redraw()
	_reload_page(false)

func _reload_page(keep_scroll := true) -> void:
	var keep := list_scroll.scroll_vertical
	extras = []
	items = _build_items(tab)
	sel = clampi(sel, 0, maxi(items.size() - 1, 0))
	_clear(list_box)
	card_nodes.clear()
	for i in items.size():
		var it: Dictionary = items[i]
		var c := Card.new()
		c.setup(286.0)
		c.title = it["title"]
		c.sub = it["sub"]
		c.glyph = it["glyph"]
		c.color = it["color"]
		c.locked = it["locked"]
		c.progress = it["progress"]
		c.selected = i == sel
		c.pressed.connect(_select_item.bind(i))
		list_box.add_child(c)
		card_nodes.append(c)
	if keep_scroll:
		list_scroll.set_deferred("scroll_vertical", keep)
	else:
		list_scroll.scroll_vertical = 0
	_show_detail()

func _select_item(i: int) -> void:
	sel = i
	for n in card_nodes.size():
		card_nodes[n].selected = n == i
		card_nodes[n].queue_redraw()
	_show_detail()

func _dlabel(text: String, r: Rect2, size: int, col: Color, stylized := true, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if stylized:
		_style_label(l, size, col, outline)
	else:
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(l)
	return l

func _show_detail() -> void:
	_clear(detail)
	if items.is_empty():
		return
	var it: Dictionary = items[sel]
	var w := detail.size.x
	var h := detail.size.y
	# preview square (white frame like the original)
	var pv := Panel.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = it["color"] if not it["locked"] else Color(0.3, 0.3, 0.3)
	psb.set_border_width_all(4)
	psb.border_color = Color.WHITE
	psb.shadow_color = Color.BLACK
	psb.shadow_size = 3
	pv.add_theme_stylebox_override("panel", psb)
	pv.position = Vector2((w - 84.0) / 2.0, 2)
	pv.size = Vector2(84, 84)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(pv)
	var gl := Label.new()
	gl.text = it["glyph"]
	gl.size = pv.size
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(gl, 52, Color.WHITE, 8)
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(gl)
	_dlabel(it["title"], Rect2(0, 90, w, 30), 24, INK)
	_dlabel(it["sub"], Rect2(0, 120, w, 22), 14, Color(0.4, 0.15, 0.1), false)
	# buttons (item actions + tab extras), laid out from the bottom up
	var acts: Array = it["actions"] + extras
	var slider: Dictionary = it["slider"]
	var block := 52.0
	var top := h - acts.size() * block
	if not slider.is_empty():
		top = h - 70.0
	top = maxf(top, 150.0)
	var d := _dlabel(it["desc"], Rect2(6, 146, w - 12, top - 150), 15, BODY_TEXT, false)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = maxi(1, int((top - 150.0) / 20.0))
	if not slider.is_empty():
		_build_slider(slider, top + 6.0, w)
	for i in acts.size():
		var a: Dictionary = acts[i]
		var y := top + i * block
		if str(a.get("caption", "")) != "":
			var cap := _dlabel(str(a["caption"]), Rect2(0, y, w, 20), 17, Color.WHITE, true, 6)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var b := Button.new()
		b.text = str(a["label"])
		b.position = Vector2(0, y + 20)
		b.size = Vector2(w, 30)
		_style_green(b)
		b.disabled = bool(a.get("disabled", false))
		b.pressed.connect(a["cb"])
		detail.add_child(b)

func _style_green(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var col := BTN
		if st == "hover":
			col = BTN.lightened(0.15)
		elif st == "pressed":
			col = BTN.darkened(0.2)
		elif st == "disabled":
			col = Color(0.35, 0.4, 0.33)
		sb.bg_color = col
		sb.set_border_width_all(3)
		sb.border_color = Color(0.06, 0.25, 0.05)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", 19)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color.WHITE if c != "font_disabled_color" else Color(0.75, 0.75, 0.75))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 5)

func _build_slider(sd: Dictionary, y: float, w: float) -> void:
	var vl := _dlabel(str(sd["fmt"]) % float(sd["value"]), Rect2(0, y - 4, w, 22), 18, INK)
	var s := HSlider.new()
	s.min_value = sd["min"]
	s.max_value = sd["max"]
	s.step = sd["step"]
	s.value = sd["value"]
	s.position = Vector2(8, y + 24)
	s.size = Vector2(w - 16, 24)
	detail.add_child(s)
	var fmt: String = sd["fmt"]
	var cb: Callable = sd["cb"]
	s.value_changed.connect(func(v: float) -> void:
		sd["value"] = v
		vl.text = fmt % v
		cb.call(v))

# ------------------------------------------------------------------ page content
func _item(title: String, sub: String, color: Color, glyph: String, desc: String, extra := {}) -> Dictionary:
	var d := {"title": title, "sub": sub, "color": color, "glyph": glyph, "desc": desc,
		"locked": false, "progress": -1.0, "actions": [], "slider": {}}
	d.merge(extra, true)
	return d

func _locked(title: String, desc: String) -> Dictionary:
	return _item(title, "Locked", Color(0.4, 0.4, 0.4), "?", desc, {"locked": true})

func _act(label: String, cb: Callable, caption := "", disabled := false) -> Dictionary:
	return {"label": label, "cb": cb, "caption": caption, "disabled": disabled}

func _cd(v: float) -> String:
	return "READY" if v <= 0.0 else "%.1fs" % v

func _build_items(i: int) -> Array:
	if p == null:
		return []
	match TABS[i]:
		"Stats": return _page_stats()
		"Ninja Tools": return _page_tools()
		"Element": return _page_elements()
		"Bloodline": return _page_bloodlines()
		"Sub-Ability": return _page_sub()
		"Companions": return _page_companions()
		"Travel": return _page_travel()
		"Mastery": return _page_mastery()
		"Cheats": return _page_cheats()
		"Customs": return _page_customs()
		"Controls": return _page_controls()
	return []

func _page_stats() -> Array:
	var q := GameData.quests_done.size()
	return [
		_item("Vitals", "Health and chakra", Color(0.85, 0.2, 0.2), "V",
			"Health: %d / %d\nChakra: %d / %d\nHealth regen: %.1f per second\nChakra regen: x%.2f" % [
				int(ceil(p.health)), int(p.max_health), int(p.chakra), int(p.max_chakra), p.hp_regen, p.regen_mult]),
		_item("Combat", "Damage and speed", Color(0.9, 0.5, 0.15), "C",
			"Damage: x%.2f\nMove speed: x%.2f\nFireball cost: %d chakra\nDash cost: %d chakra\nClones: %d for %ds" % [
				p.dmg_mult, p.speed_mult, int(p.fire_cost), int(p.dash_cost), p.clone_count, int(p.clone_time)]),
		_item("Progress", "Kills, quests, spins", Color(0.3, 0.6, 0.9), "P",
			"Rank: %s\nKills this run: %d\nBloodline spins: %d\nQuests done: %d / %d\nKurama: %s" % [
				rank(), p.kills, GameData.spins, q, Quests.DEFS.size(),
				"defeated" if GameData.kurama_defeated else "undefeated"]),
	]

func _page_tools() -> Array:
	var def := Bloodline.get_def(GameData.equipped)
	var pu := "No bloodline power-up yet." if def["ability"] == "" else "%s - %s" % [def["ability_name"], _cd(p.ability_cd)]
	return [
		_item("Melee Combo", "LMB - free", Color(0.75, 0.75, 0.8), "M",
			"Three-hit combo, the last hit knocks enemies back.\nBase damage 14 / 18 / 22, multiplied by x%.2f from your bloodline." % p.dmg_mult),
		_item("Kunai", "RMB - 3 chakra", Color(0.6, 0.65, 0.8), "K",
			"Hold RMB to throw kunai. 9 damage, homes in on your lock-on target."),
		_item("Kunai Volley", "RMB + E - 15 chakra", Color(0.7, 0.72, 0.85), "V",
			"Hold RMB and press E: throws 5 kunai in a fan.\nStatus: %s" % _cd(p.volley_cd)),
		_item("Fireball", "R - %d chakra" % int(p.fire_cost), Color(1.0, 0.45, 0.1), "R",
			"Explodes on impact: 45 damage in a 5 m radius.\nStatus: %s" % _cd(p.fire_cd)),
		_item("Phoenix Flowers", "T - 35 chakra", Color(1.0, 0.55, 0.2), "T",
			"Fires 5 small fireballs in a fan.\nStatus: %s" % _cd(p.t_cd)),
		_item("Flame Wave", "Y - 45 chakra", Color(1.0, 0.4, 0.1), "Y",
			"A burst of fire around you: 40 damage and knockback.\nStatus: %s" % _cd(p.y_cd)),
		_item("Shadow Clones", "F - 40 chakra", Color(0.3, 0.6, 1.0), "F",
			"Summons %d clones that fight for %d seconds.\nStatus: %s" % [p.clone_count, int(p.clone_time), _cd(p.clone_cd)]),
		_item("Dragon Flame", "G - 60 chakra", Color(0.95, 0.25, 0.05), "G",
			"A huge homing fire dragon: 90 damage in an 8 m blast.\nStatus: %s" % _cd(p.g_cd)),
		_item("Flame Armor", "H - 40 chakra", Color(0.95, 0.5, 0.15), "H",
			"Take 60%% less damage for 6 seconds.\nStatus: %s" % _cd(p.h_cd)),
		_item("Substitution", "V - 25 chakra", Color(0.7, 0.6, 0.4), "V",
			"Swap with a log: you land behind the nearest enemy, or back off if none are near. Short invulnerability.\nStatus: %s" % _cd(p.v_cd)),
		_item("Dash", "Q - %d chakra" % int(p.dash_cost), Color(0.5, 0.85, 0.95), "Q",
			"A short burst of speed with brief invulnerability. Sprinting uses stamina (STM)."),
		_item("Chakra / Power-up", "C", Color(0.3, 0.45, 1.0), "C",
			"Tap C: bloodline power-up (%s).\nHold C while standing still: charge chakra, 40 per second (x%.2f)." % [pu, p.regen_mult]),
		_item("Kurama Mode", "Z", Color(1.0, 0.5, 0.1), "Z",
			"Unlocks when you defeat Kurama. Needs the MD bar full (fills with time and kills).\nFor %d seconds: x2 damage, x1.3 speed, half damage taken, health regen. Status: %s" % [
				int(Player.MODE_TIME), "ACTIVE" if p.mode_time > 0.0 else ("LOCKED" if not GameData.kurama_defeated else "MD %d / %d" % [int(p.mode_meter), int(Player.MODE_MAX)])]),
	]

func _page_elements() -> Array:
	var out: Array = []
	for element in GameData.ELEMENTS:
		if not GameData.owned_elements.has(element):
			out.append(_locked("%s Style" % element, "Not owned. Use an Element Spin in the B menu to unlock it."))
			continue
		var equipped_now: bool = GameData.equipped_element == element
		var actions: Array = []
		if not equipped_now:
			actions.append(_act("EQUIP", _equip_element.bind(element)))
		var subtitle := "EQUIPPED" if equipped_now else "OWNED"
		out.append(_item("%s Style" % element, subtitle, GameData.get_element_color(element), element.substr(0, 1),
			"Element style unlocked. It changes the colour of your elemental jutsu effects; move behaviour is currently shared across styles.",
			{"actions": actions}))
	return out

func _page_bloodlines() -> Array:
	var out: Array = []
	for id in Bloodline.DEFS:
		var d := Bloodline.get_def(id)
		var owned: bool = GameData.owned.has(id)
		var is_eq: bool = GameData.equipped == id
		if not owned:
			out.append(_locked("???", "Spin to discover this bloodline."))
			continue
		var acts: Array = []
		if not is_eq:
			acts.append(_act("EQUIP", _equip.bind(id)))
		out.append(_item(d["name"], "%s%s" % [d["rarity"], "  -  EQUIPPED" if is_eq else ""], d["color"],
			str(d["name"]).substr(0, 1), d["desc"], {"actions": acts}))
	extras = [_act("OPEN SPIN", _open_spin, "[Awakening - %d spins]" % GameData.spins)]
	return out

func _page_sub() -> Array:
	var d := Bloodline.get_def(GameData.equipped)
	var out: Array = []
	if d["ability"] == "":
		out.append(_item("No Sub-Ability", "Equip a Rare+ bloodline", Color(0.5, 0.5, 0.5), "-",
			"Your current bloodline has no active ability. Rare, Epic and Legendary bloodlines unlock one on [C] (tap)."))
	else:
		var st := "ACTIVE %.0fs" % p.ability_time if p.active_ability != "" else _cd(p.ability_cd)
		out.append(_item(d["ability_name"], "[C] - %d chakra, %ds cooldown" % [int(d["ability_cost"]), int(d["ability_cd"])],
			d["color"], str(d["ability_name"]).substr(0, 1), "%s\n\nStatus: %s" % [d["desc"], st]))
	var pool := ""
	for id in Bloodline.DEFS:
		var bd := Bloodline.get_def(id)
		if bd["ability"] != "":
			pool += "%s  (%s)\n" % [bd["ability_name"], bd["name"]]
	out.append(_item("Ability Pool", "All sub-abilities", Color(0.6, 0.4, 0.8), "A", pool))
	return out

func _page_companions() -> Array:
	var can := not p.is_dead and p.clone_cd <= 0.0 and p.chakra >= 40.0
	return [
		_item("Shadow Clones", "%d clones, %ds" % [p.clone_count, int(p.clone_time)], Color(0.3, 0.6, 1.0), "S",
			"Clones chase and fight enemies for you. Costs 40 chakra, cooldown 6 seconds.\nStatus: %s" % _cd(p.clone_cd),
			{"actions": [_act("SUMMON", _summon_clones, "", not can)]}),
		_locked("More companions", "No other companions exist yet."),
	]

func _page_travel() -> Array:
	var out: Array = []
	var mode: String = GameData.mode
	var spots: Array = []     # [name, glyph, colour, position, blurb]
	match mode:
		"world":
			spots.append(["Spawn", "S", Color(0.4, 0.7, 0.3), Vector3(0, 1, 0), "Where the open world starts."])
			for id in Quests.NPCS:
				var n: Dictionary = Quests.NPCS[id]
				spots.append([n["name"], str(n["name"]).substr(0, 1), n["color"].lightened(0.2), n["pos"] + Vector3(0, 1, 4), "Teleport next to this villager."])
		"kurama":
			spots.append(["Arena Edge", "E", Color(0.6, 0.3, 0.2), Vector3(0, 1, 30), "Where the fight begins."])
			spots.append(["Arena Center", "C", Color(0.8, 0.3, 0.1), Vector3(0, 1, 0), "The middle of the scorched arena."])
			spots.append(["Near Kurama", "K", Color(0.9, 0.2, 0.1), Vector3(0, 1, -18), "Right in front of the beast. Brave."])
		_:
			spots.append(["Plaza", "P", Color(0.7, 0.65, 0.55), Vector3(0, 1, 0), "The village plaza, centre of the arena."])
			spots.append(["Main Gate", "G", Color(0.3, 0.45, 0.3), Vector3(0, 1, 44), "The south gate of the village."])
			spots.append(["Council Tower", "T", Color(0.78, 0.2, 0.14), Vector3(0, 1, -13), "The red tower, north of the plaza."])
			spots.append(["Water Tower", "W", Color(0.4, 0.6, 0.8), Vector3(-24, 1, -12), "The water tower in the north-west."])
			spots.append(["Cliffs", "C", Color(0.55, 0.5, 0.45), Vector3(0, 1, -36), "The cliffs behind the village."])
	for s in spots:
		out.append(_item(s[0], "Teleport", s[2], s[1], s[4],
			{"actions": [_act("TELEPORT", _teleport.bind(s[3]), "[Select Location]")]}))
	var next_mode: String = MODE_ORDER[(MODE_ORDER.find(mode) + 1) % MODE_ORDER.size()]
	var qpos := _quest_target()
	extras = [
		_act("TELEPORT", _to_title, "[Main-Menu]"),
		_act("GO", _switch_mode.bind(next_mode), "[Switch Mode: %s]" % MODE_NAMES[next_mode]),
		_act("TELEPORT", _teleport.bind(qpos), "[Quest Target]", qpos == Vector3.INF),
	]
	return out

func _page_mastery() -> Array:
	var q := GameData.quests_done.size()
	var qt := Quests.DEFS.size()
	var bl := maxi(GameData.owned.size() - 1, 0)
	var bt := Bloodline.DEFS.size() - 1
	var next_k := (p.kills / 25 + 1) * 25
	return [
		_item("Slayer", "Kills this run: %d" % p.kills, Color(0.85, 0.25, 0.2), "S",
			"Next milestone: %d kills.\nEvery 8 kills earns a bloodline spin." % next_k,
			{"progress": float(p.kills % 25) / 25.0}),
		_item("Quest Master", "%d / %d quests" % [q, qt], Color(0.9, 0.75, 0.2), "Q",
			"Finish every quest in the open world to reach S-Rank.\nCurrent rank: %s" % rank(),
			{"progress": float(q) / float(qt)}),
		_item("Beast Slayer", "Kurama: %s" % ("defeated" if GameData.kurama_defeated else "undefeated"), Color(1.0, 0.45, 0.1), "K",
			"Defeat the Nine-Tailed Beast for 5 spins.", {"progress": 1.0 if GameData.kurama_defeated else 0.0}),
		_item("Bloodline Collector", "%d / %d bloodlines" % [bl, bt], Color(0.6, 0.4, 0.9), "B",
			"Spin for new bloodlines. A Legendary is guaranteed within %d spins." % maxi(GameData.PITY_LIMIT - GameData.pity, 0),
			{"progress": float(bl) / float(bt)}),
	]

func _page_cheats() -> Array:
	var note := "\n\nTesting tool for your single-player build."
	return [
		_item("God Mode", "ON" if p.god_mode else "OFF", Color(0.95, 0.8, 0.2), "G",
			"You cannot take damage." + note,
			{"actions": [_act("DISABLE" if p.god_mode else "ENABLE", _toggle_god)]}),
		_item("Infinite Chakra", "ON" if p.inf_chakra else "OFF", Color(0.3, 0.55, 1.0), "I",
			"Chakra stays full." + note,
			{"actions": [_act("DISABLE" if p.inf_chakra else "ENABLE", _toggle_chakra)]}),
		_item("Heal and Refill", "Instant", Color(0.3, 0.8, 0.4), "H",
			"Restores health, chakra, stamina and the MD bar." + note, {"actions": [_act("REFILL", _refill)]}),
		_item("Unlock Kurama Mode", "ON" if GameData.kurama_defeated else "OFF", Color(1.0, 0.5, 0.1), "Z",
			"Marks Kurama as defeated so Z works without the boss fight." + note,
			{"actions": [_act("UNLOCK", _unlock_kurama, "", GameData.kurama_defeated)]}),
		_item("Add 5 Spins", "Instant", Color(0.8, 0.3, 0.9), "+",
			"Gives 5 bloodline spins." + note, {"actions": [_act("ADD", _add_spins)]}),
		_item("Unlock Bloodlines", "Instant", Color(0.9, 0.5, 0.2), "U",
			"Adds every bloodline to your collection." + note, {"actions": [_act("UNLOCK", _unlock_all)]}),
		_item("Defeat Enemies", "Instant", Color(0.85, 0.2, 0.2), "X",
			"Knocks out every enemy on the map, bosses too." + note, {"actions": [_act("DEFEAT", _kill_all)]}),
	]

func _page_customs() -> Array:
	var vol := db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	return [
		_item("Mouse Sensitivity", "Camera turn speed", Color(0.5, 0.7, 0.9), "M",
			"How fast the camera turns with the mouse.",
			{"slider": {"min": 0.2, "max": 3.0, "step": 0.05, "value": p.sens_mult, "fmt": "x%.2f",
				"cb": func(v: float) -> void: p.sens_mult = v}}),
		_item("Camera Distance", "Third-person zoom", Color(0.6, 0.8, 0.5), "D",
			"How far the camera sits behind you.",
			{"slider": {"min": 3.0, "max": 16.0, "step": 0.5, "value": p.spring.spring_length, "fmt": "%.1f m",
				"cb": func(v: float) -> void: p.spring.spring_length = v}}),
		_item("Field of View", "Camera angle", Color(0.9, 0.7, 0.4), "F",
			"A wider angle shows more of the world.",
			{"slider": {"min": 55.0, "max": 100.0, "step": 1.0, "value": p.fov_base, "fmt": "%d deg",
				"cb": func(v: float) -> void: p.fov_base = v}}),
		_item("Master Volume", "Sound effects", Color(0.8, 0.5, 0.8), "V",
			"Overall volume.",
			{"slider": {"min": 0.0, "max": 100.0, "step": 1.0, "value": vol, "fmt": "%d%%",
				"cb": func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001) / 100.0))}}),
	]

func _page_controls() -> Array:
	return [
		_item("Movement", "WASD, Shift, Space, Q", Color(0.4, 0.7, 0.4), "W",
			"WASD: move\nShift: sprint (uses stamina)\nSpace: jump, press again to double jump\nQ: dash"),
		_item("Fire Jutsu", "R T Y G H", Color(0.85, 0.3, 0.2), "R",
			"R: Fireball\nT: Phoenix Flowers\nY: Flame Wave\nF: Shadow Clones\nG: Dragon Flame\nH: Flame Armor"),
		_item("Combat", "Mouse, V, E", Color(0.6, 0.65, 0.8), "C",
			"Left mouse: melee combo\nRight mouse: kunai\nRight mouse + E: kunai volley\nV: substitution\nTab / N / middle mouse: lock on"),
		_item("Power", "C and Z", Color(1.0, 0.5, 0.1), "Z",
			"Tap C: bloodline power-up (X also works)\nHold C: charge chakra\nZ: Kurama Mode (after beating Kurama, MD bar full)"),
		_item("Menus", "M, B, E, L, Esc", Color(0.9, 0.75, 0.2), "M",
			"M: this menu\nB: bloodline spin\nE: talk to villagers (open world)\nL: show / hide the quest tracker\nEsc: free the mouse / close menus\nEnter: retry after dying"),
	]

# ------------------------------------------------------------------ actions
func _equip(id: String) -> void:
	GameData.equipped = id
	GameData.save()
	p.apply_bloodline()
	_refresh_header()
	_reload_page()

func _equip_element(element: String) -> void:
	if not GameData.owned_elements.has(element):
		return
	GameData.equipped_element = element
	GameData.save()
	_refresh_header()
	_reload_page()

func _open_spin() -> void:
	close()
	var sp = main.get("spin") if main != null else null
	if sp != null:
		sp.toggle()

func _summon_clones() -> void:
	close()
	p._clones()

func _teleport(pos: Vector3) -> void:
	if p == null or p.is_dead or pos == Vector3.INF:
		return
	close()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	Fx.puff(p.get_parent(), pos + Vector3.UP, Color(0.9, 0.9, 0.9, 0.7), 2.0)

## Where the active open-world quest wants you to go (Vector3.INF = none).
func _quest_target() -> Vector3:
	if main == null or GameData.mode != "world":
		return Vector3.INF
	var qs = main.get("quests")
	if qs == null:
		return Vector3.INF
	var act: Dictionary = qs.active_def()
	if act.is_empty():
		return Vector3.INF
	var pos := Vector3.INF
	if GameData.quest_state == "ready":
		pos = Quests.NPCS[act["giver"]]["pos"]
	elif act.has("pos"):
		pos = act["pos"]
	elif act["type"] == "deliver":
		pos = Quests.NPCS[act["target"]]["pos"]
	else:
		pos = Quests.NPCS[act["giver"]]["pos"]
	return pos + Vector3(0, 1, 3)

func _to_title() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://menu.tscn")

func _switch_mode(mode: String) -> void:
	GameData.mode = mode
	get_tree().paused = false
	get_tree().reload_current_scene()

func _toggle_god() -> void:
	p.god_mode = not p.god_mode
	_reload_page()

func _toggle_chakra() -> void:
	p.inf_chakra = not p.inf_chakra
	_reload_page()

func _refill() -> void:
	p.health = p.max_health
	p.chakra = p.max_chakra
	p.stamina = p.max_stamina
	p.mode_meter = Player.MODE_MAX
	_reload_page()

func _unlock_kurama() -> void:
	GameData.kurama_defeated = true
	GameData.save()
	_reload_page()

func _add_spins() -> void:
	GameData.spins += 5
	GameData.save()
	_refresh_header()

func _unlock_all() -> void:
	for id in Bloodline.DEFS:
		if not GameData.owned.has(id):
			GameData.owned.append(id)
	GameData.save()
	_refresh_header()

func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(999999.0, Vector3.ZERO)
	_refresh_header()
