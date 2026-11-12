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
	"Travel", "Mastery", "Cheats", "Customs", "Controls", "Party"]
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

## Clickable octagon for a bloodline ability on the Bloodline page (Shindo Life style).
class AbilityIcon extends Control:
	signal pressed
	var fill := Color(0.3, 0.3, 0.3)
	var letter := ""
	var locked := false
	var lvl_text := ""
	var selected := false
	var is_mode := false
	var hover := false
	var tex: Texture2D = null        # ability image (drawn instead of the letter)
	var key_text := ""               # hotbar key it is bound to
	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			hover = what == NOTIFICATION_MOUSE_ENTER
			queue_redraw()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
	func _oct(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 8:
			var a := deg_to_rad(22.5 + 45.0 * i)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts
	func _draw() -> void:
		var f := GameMenu.font()
		var c := size / 2.0
		var r := size.x / 2.0 - 2.0
		var outer := _oct(c, r)
		var body := fill.darkened(0.45) if locked else fill
		if hover and not selected:
			body = body.lightened(0.12)
		draw_colored_polygon(outer, Color(0.05, 0.05, 0.08))
		draw_colored_polygon(_oct(c, r - 4.0), body)
		var loop := outer.duplicate()
		loop.append(outer[0])
		var ring := Color(1.0, 0.82, 0.25) if is_mode else fill.lightened(0.35)
		draw_polyline(loop, ring, 3.0)
		if selected:
			draw_polyline(loop, Color(0.85, 0.06, 0.06), 4.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(c - Vector2(22, 22), Vector2(44, 44)), false, Color(0.5, 0.5, 0.5) if locked else Color.WHITE)
		else:
			var fs := 30
			var ty := c.y + fs * 0.36 - (6.0 if locked else 0.0)
			draw_string_outline(f, Vector2(0, ty), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 6, Color.BLACK)
			draw_string(f, Vector2(0, ty), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 1, 1, 0.45 if locked else 1.0))
		if key_text != "" and not locked:   # key badge
			draw_rect(Rect2(size.x - 20, 0, 20, 18), Color(0.05, 0.05, 0.05))
			draw_string(f, Vector2(size.x - 20, 14), key_text, HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color(1.0, 0.85, 0.3))
		if locked:
			var red := Color(0.75, 0.05, 0.05)
			draw_rect(Rect2(c.x - 9.0, c.y - 8.0, 18.0, 14.0), red)
			draw_arc(Vector2(c.x, c.y - 8.0), 6.0, PI, TAU, 12, red, 3.0)
			var lf := 12 if lvl_text.length() <= 9 else 10
			draw_string_outline(f, Vector2(-6, size.y - 8.0), lvl_text, HORIZONTAL_ALIGNMENT_CENTER, size.x + 12.0, lf, 4, Color.BLACK)
			draw_string(f, Vector2(-6, size.y - 8.0), lvl_text, HORIZONTAL_ALIGNMENT_CENTER, size.x + 12.0, lf, Color.WHITE)

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
var sep_right: ColorRect                # divider between list and detail (hidden on the Bloodline page)
var bl_page: Control                    # custom Shindo-style Bloodline page
var tree_kind := "bloodline"            # which ability page is shown: "bloodline" | "element"
var tree_page := 0                      # which pair of columns
var tree_sel_col := ""                  # selected column (slot index or element); "" = pick the equipped one
var tree_sel_idx := 0                   # selected ability in that column (bloodline: 3 = power-up)
var party_hud: Panel
var party_hud_list: VBoxContainer
var party_hud_signature := ""
var party_hud_timer := 0.0

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
		t.setup(TABS[i], 205.0, 31.0, 0.0 if i % 2 == 0 else 26.0)
		t.position = Vector2(34, 158 + i * 32)
		t.pressed.connect(_select_tab.bind(i))
		scroll.add_child(t)
		tab_nodes.append(t)
	_rect(Rect2(248, 154, 4, 396), INK)
	sep_right = _rect(Rect2(566, 154, 4, 396), INK)
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
	bl_page = Control.new()
	bl_page.position = Vector2(258, 150)
	bl_page.size = Vector2(610, 404)
	bl_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(bl_page)
	bl_page.visible = false
	root.visible = false
	_build_party_hud()
	if not NetworkSession.party_updated.is_connected(_refresh_party_hud):
		NetworkSession.party_updated.connect(_refresh_party_hud)
	if NetworkSession.is_active() and not NetworkSession.party_invite_received.is_connected(_show_party_invite):
		NetworkSession.party_invite_received.connect(_show_party_invite)

func _build_party_hud() -> void:
	party_hud = Panel.new()
	party_hud.name = "PartyHUD"
	party_hud.position = Vector2(16, 16)
	party_hud.size = Vector2(226, 150)
	party_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	party_hud.position = Vector2(16, -166)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PARCH.r, PARCH.g, PARCH.b, 0.94)
	sb.set_border_width_all(3)
	sb.border_color = GOLD_DK
	party_hud.add_theme_stylebox_override("panel", sb)
	party_hud.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(party_hud)
	var title := Label.new()
	title.text = "YOUR PARTY"
	title.position = Vector2(10, 5)
	title.size = Vector2(202, 24)
	_style_label(title, 19, INK, 3)
	party_hud.add_child(title)
	var line := ColorRect.new()
	line.position = Vector2(8, 30)
	line.size = Vector2(206, 3)
	line.color = INK
	party_hud.add_child(line)
	var sc := ScrollContainer.new()
	sc.position = Vector2(8, 36)
	sc.size = Vector2(206, 105)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	party_hud.add_child(sc)
	party_hud_list = VBoxContainer.new()
	party_hud_list.add_theme_constant_override("separation", 2)
	sc.add_child(party_hud_list)
	party_hud.visible = false
	_refresh_party_hud()

func _refresh_party_hud() -> void:
	if party_hud_list == null:
		return
	var signature := ""
	if NetworkSession.is_active():
		var my_id := multiplayer.get_unique_id()
		var leader := int(NetworkSession._party_leader.get(my_id, my_id))
		if NetworkSession._party_size(leader) > 1:
			for id in NetworkSession._known_players:
				if NetworkSession._same_party(my_id, int(id)):
					signature += "%d:%s:%d;" % [int(id), str(NetworkSession._known_players[id]), int(NetworkSession._known_levels.get(id, 1))]
	if signature == party_hud_signature:
		return
	party_hud_signature = signature
	for child in party_hud_list.get_children():
		party_hud_list.remove_child(child)
		child.queue_free()
	if not NetworkSession.is_active() or signature.is_empty():
		party_hud.visible = false
		return
	party_hud.visible = true
	var ids: Array[int] = []
	var my_id := multiplayer.get_unique_id()
	for id in NetworkSession._known_players:
		if NetworkSession._same_party(my_id, int(id)):
			ids.append(int(id))
	ids.sort()
	for id in ids:
		var nm := NetworkSession.name_with_clan(int(id))
		var lv := int(NetworkSession._known_levels.get(id, 1))
		var row := Label.new()
		row.text = "%s  •  Lv. %d%s" % [nm, lv, " (YOU)" if id == my_id else ""]
		row.custom_minimum_size = Vector2(194, 22)
		row.add_theme_font_override("font", font())
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override("font_color", GREEN_DK)
		row.add_theme_color_override("font_outline_color", Color.WHITE)
		row.add_theme_constant_override("outline_size", 2)
		party_hud_list.add_child(row)

func _process(delta: float) -> void:
	party_hud_timer += delta
	if party_hud_timer >= 0.5:
		party_hud_timer = 0.0
		if party_hud != null and is_instance_valid(party_hud):
			_refresh_party_hud()

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
	title_label.text = "SHINOBI   LV %d   [%s-Rank]   -   %s" % [GameData.level, rank(), mname]
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
	# row 2: bloodline slots | kills
	for i in GameData.SLOT_COUNT:
		var o2 := Octagon.new()
		o2.position = Vector2(46 + i * 50, 100)
		var sid := str(GameData.slots[i])
		if not GameData.slot_unlocked[i]:
			o2.kind = "lock"
		elif sid == "none":
			o2.kind = "empty"
			o2.ring = i == GameData.active_slot
		else:
			var bd := Bloodline.get_def(sid)
			o2.kind = "letter"
			o2.letter = str(bd["name"]).substr(0, 1)
			o2.fill = bd["color"].darkened(0.25)
			o2.ring = i == GameData.active_slot
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
	var custom: bool = (TABS[tab] == "Bloodline" or TABS[tab] == "Element") and p != null
	bl_page.visible = custom
	list_scroll.visible = not custom
	detail.visible = not custom
	sep_right.visible = not custom
	if custom:
		var kind := "element" if TABS[tab] == "Element" else "bloodline"
		if kind != tree_kind:
			tree_kind = kind
			tree_sel_col = ""
		_build_tree_page()
		return
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
		"Party": return _page_party()
	return []

const STAT_INFO := {
	"health": ["Health", "+%d max HP per point", Color(0.85, 0.2, 0.2), "H"],
	"chakra": ["Chakra", "+%d max chakra per point", Color(0.2, 0.45, 1.0), "C"],
	"md": ["MD", "+%d%% MD gain per point (MD powers bloodline modes and Kurama Mode)", Color(0.55, 0.15, 0.85), "M"],
	"stamina": ["Stamina", "+%d max stamina per point", Color(0.95, 0.5, 0.1), "S"],
	"bloodline": ["Bloodline", "+%d%% bloodline ability damage per point", Color(0.9, 0.1, 0.15), "B"],
}

func _page_party() -> Array:
	if not NetworkSession.is_active():
		return [_item("Not connected", "Join a multiplayer session first", Color(0.6, 0.55, 0.45), "!", "Host or join from the Multiplayer option on the main menu.")]
	var out: Array = []
	var my_id := multiplayer.get_unique_id()
	var leader := int(NetworkSession._party_leader.get(my_id, my_id))
	var party_count := NetworkSession._party_size(leader)
	var party_actions: Array = []
	if party_count > 1:
		party_actions.append(_act("LEAVE PARTY", NetworkSession.leave_party, "", false))
	out.append(_item("Your Party", "%d / 4 members" % party_count, Color(0.8, 0.65, 0.2), "P", "Invite connected players below. Party members cannot damage each other.", {"actions": party_actions}))
	for id in NetworkSession._known_players:
		var peer_id := int(id)
		if peer_id == my_id:
			continue
		var in_party := NetworkSession._same_party(my_id, peer_id)
		var nm := NetworkSession.name_with_clan(peer_id)
		var lv := int(NetworkSession._known_levels.get(id, 1))
		var acts: Array = []
		if in_party:
			acts.append(_act("IN PARTY", func() -> void: pass, "", true))
		else:
			acts.append(_act("INVITE", NetworkSession.invite_to_party.bind(peer_id), "", NetworkSession._party_size(leader) >= 4))
		out.append(_item(nm, "Level %d  •  %s" % [lv, "PARTY MEMBER" if in_party else "CONNECTED"], Color(0.25, 0.7, 0.35) if in_party else Color(0.35, 0.55, 0.8), "N", "Player ID: %d\n%s" % [peer_id, "You are already in the same party." if in_party else "Send this player a party invitation."], {"actions": acts}))
	return out

func _show_party_invite(inviter_id: int, inviter_name: String) -> void:
	var old := get_node_or_null("PartyInvitePopup")
	if old != null:
		old.queue_free()
	var panel := Panel.new()
	panel.name = "PartyInvitePopup"
	panel.position = (get_viewport().get_visible_rect().size - Vector2(340, 170)) / 2.0
	panel.size = Vector2(340, 170)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCH
	sb.set_border_width_all(5)
	sb.border_color = INK
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var title := Label.new()
	title.text = "PARTY INVITATION"
	title.position = Vector2(12, 12)
	title.size = Vector2(316, 32)
	_style_label(title, 23, INK, 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var msg := Label.new()
	msg.text = "%s invited you to their party." % inviter_name
	msg.position = Vector2(12, 52)
	msg.size = Vector2(316, 35)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", BODY_TEXT)
	msg.add_theme_font_size_override("font_size", 16)
	panel.add_child(msg)
	var accept := Button.new()
	accept.text = "ACCEPT"
	accept.position = Vector2(24, 108)
	accept.size = Vector2(132, 42)
	_style_green(accept)
	accept.pressed.connect(func() -> void:
		NetworkSession.accept_party_invite(inviter_id)
		panel.queue_free()
		_reload_page())
	panel.add_child(accept)
	var decline := Button.new()
	decline.text = "DECLINE"
	decline.position = Vector2(184, 108)
	decline.size = Vector2(132, 42)
	_style_green(decline)
	decline.pressed.connect(func() -> void:
		NetworkSession.decline_party_invite(inviter_id)
		panel.queue_free())
	panel.add_child(decline)

func _page_stats() -> Array:
	var q := GameData.quests_done.size()
	var need := GameData.xp_needed()
	var maxed := GameData.level >= GameData.MAX_LEVEL
	var out: Array = [
		_item("Shinobi Level %d" % GameData.level, "%d stat point%s to spend" % [GameData.stat_points, "" if GameData.stat_points == 1 else "s"],
			Color(0.95, 0.75, 0.2), str(GameData.level),
			"%s\n\nEvery level gives %d stat points. Earn XP from kills (%d), bosses (%d) and quests (%d).\nMax level: %d." % [
				"MAX LEVEL" if maxed else "XP: %d / %d" % [GameData.xp, need], GameData.POINTS_PER_LEVEL,
				GameData.XP_KILL, GameData.XP_BOSS, GameData.XP_QUEST, GameData.MAX_LEVEL],
			{"progress": 1.0 if maxed else float(GameData.xp) / float(need)}),
	]
	for k in GameData.STAT_KEYS:
		var info: Array = STAT_INFO[k]
		var per: float = GameData.STAT_PER_POINT[k]
		var shown := per * 100.0 if k == "md" or k == "bloodline" else per
		var pts := int(GameData.stats[k])
		var full := pts >= GameData.STAT_CAP
		var none := GameData.stat_points <= 0
		var bonus := GameData.stat_bonus(k)
		var bonus_txt := "+%d%%" % int(round(bonus * 100.0)) if k == "md" or k == "bloodline" else "+%d" % int(bonus)
		out.append(_item(info[0], "%d / %d points   (%s)" % [pts, GameData.STAT_CAP, bonus_txt], info[2], info[3],
			("%s.\n\nNow: %s.\nPoints left: %d." % [info[1] % int(shown), bonus_txt, GameData.stat_points]),
			{"progress": float(pts) / float(GameData.STAT_CAP),
			"actions": [_act("+1", _add_stat.bind(k, 1), "", full or none), _act("+10", _add_stat.bind(k, 10), "", full or none)]}))
	out.append(_item("Reset Stats", "Get every point back", Color(0.45, 0.4, 0.35), "R",
		"Returns all spent points so you can place them again.", {"actions": [_act("RESET", _reset_stats)]}))
	out.append(_item("Vitals", "Health and chakra", Color(0.85, 0.2, 0.2), "V",
		"Health: %d / %d\nChakra: %d / %d\nStamina: %d / %d\nHealth regen: %.1f per second\nChakra regen: x%.2f" % [
			int(ceil(p.health)), int(p.max_health), int(p.chakra), int(p.max_chakra), int(p.stamina), int(p.max_stamina),
			p.hp_regen, p.regen_mult]))
	out.append(_item("Combat", "Damage and speed", Color(0.9, 0.5, 0.15), "C",
		"Damage: x%.2f\nBloodline abilities: x%.2f\nMove speed: x%.2f\nFireball cost: %d chakra\nDash cost: %d chakra" % [
			p.dmg_mult, 1.0 + GameData.stat_bonus("bloodline"), p.speed_mult, int(p.fire_cost), int(p.dash_cost)]))
	out.append(_item("Progress", "Kills, quests, spins", Color(0.3, 0.6, 0.9), "P",
		"Rank: %s\nKills this run: %d\nBloodline spins: %d\nQuests done: %d / %d\nKurama: %s" % [
			rank(), p.kills, GameData.spins, q, Quests.DEFS.size(),
			"defeated" if GameData.kurama_defeated else "undefeated"]))
	return out

func _add_stat(key: String, n: int) -> void:
	if GameData.add_stat(key, n) > 0:
		p.refresh_stats()
		_refresh_header()
		_reload_page()

func _reset_stats() -> void:
	GameData.reset_stats()
	p.refresh_stats()
	_refresh_header()
	_reload_page()

func _page_tools() -> Array:
	var m := Bloodline.mode(GameData.equipped)
	var pu := "no bloodline equipped"
	if not m.is_empty():
		var lv := GameData.mastery_level(GameData.equipped)
		pu = "%s - %s" % [m["name"], "ON" if p.powered else ("ready" if lv >= Bloodline.MODE_LEVEL else "unlocks at bloodline LV %d, now %d" % [Bloodline.MODE_LEVEL, lv])]
	return [
		_item("Melee Combo", "LMB - free", Color(0.75, 0.75, 0.8), "M",
			"Three-hit combo, the last hit knocks enemies back.\nBase damage 14 / 18 / 22, multiplied by x%.2f from your bloodline." % p.dmg_mult),
		_item("Kunai", "RMB - 3 chakra", Color(0.6, 0.65, 0.8), "K",
			"Hold RMB to throw kunai. 9 damage, homes in on your lock-on target."),
		_item("Kunai Volley", "RMB + E - 15 chakra", Color(0.7, 0.72, 0.85), "V",
			"Hold RMB and press E: throws 5 kunai in a fan.\nStatus: %s" % _cd(p.volley_cd)),
		_item("Hotbar Keys", "R T Y F G H V B N", Color(0.9, 0.75, 0.2), "K",
			"These keys run whatever move you put on them.\nAssign moves in the Bloodline and Element tabs: click an ability, then click a key.\nNow: %s" % _binds_text()),
		_item("Dash", "Q - %d chakra" % int(p.dash_cost), Color(0.5, 0.85, 0.95), "Q",
			"A short burst of speed with brief invulnerability. Sprinting uses stamina (STM)."),
		_item("Chakra / Power-up", "C", Color(0.3, 0.45, 1.0), "C",
			"Tap C: bloodline power-up on / off (%s). No timer - it drains MD and ends when MD runs out.\nHold C while standing still: charge chakra, 40 per second (x%.2f).\nBloodline and element moves go on the hotbar keys you choose (Bloodline / Element tabs)." % [pu, p.regen_mult]),
		_item("Kurama Mode", "Z", Color(1.0, 0.5, 0.1), "Z",
			"Unlocks when you defeat Kurama. Press Z to turn it on (needs %d MD) and again to turn it off. No timer: it drains MD (a full bar lasts %d s).\nx2 damage, x1.3 speed, half damage taken, health regen.\nWorks together with your bloodline power-up (C); with both on, MD drains faster.\nStatus: %s" % [
				int(Player.KURAMA_MIN_MD), int(Player.MODE_TIME), "ACTIVE" if p.kurama else ("LOCKED" if not GameData.kurama_defeated else "MD %d / %d" % [int(p.mode_meter), int(Player.MODE_MAX)])]),
	]

func _binds_text() -> String:
	var parts: Array[String] = []
	for k in Moves.BIND_KEYS:
		var a := Moves.spec(str(GameData.keybinds.get(k, "")))
		parts.append("%s %s" % [k, "-" if a.is_empty() else a["name"]])
	return ",  ".join(PackedStringArray(parts))

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

## Shindo Life style Bloodline page: two slot columns (bloodline LV, 3 ability icons + power-up,
## EQUIP, mastery EXP bar) and an info panel for the clicked icon.
func _k(n: int) -> String:
	return "%.1fK" % (n / 1000.0) if n >= 1000 else str(n)

func _bl_rect(r: Rect2, col: Color, parent: Control) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

func _bl_label(text: String, r: Rect2, size: int, col: Color, parent: Control, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0, wrap := false) -> Label:
	var l := Label.new()
	if wrap:   # must be set before the size, or the label grows to fit one long line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.clip_text = true
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	if not wrap:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(l, size, col, outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## Shindo Life style ability pages (Bloodline and Element tabs): two columns (level, ability icons with
## their unlock levels, EQUIP, mastery EXP bar) and an info panel where you assign the clicked move to a key.
func _tree_pages() -> Array:
	if tree_kind == "element":
		return [["Fire", "Earth"], ["Lightning", "Water"], ["Wind", "basic"]]
	return [["0", "1"], ["2", "3"]]

func _tree_page_names() -> Array:
	return ["F / E", "L / W", "W / BASIC"] if tree_kind == "element" else ["SLOTS 1-2", "SLOTS 3-4"]

## Everything a column needs. cid = slot index ("0".."3") or element name.
func _col_data(cid: String) -> Dictionary:
	var d := {"locked": false, "msg": "", "name": "", "color": Color.GRAY, "letter": "?", "lv": 0, "moves": [],
		"mode": "", "equipped": false, "mkey": "", "can_equip": true}
	if cid == "basic":   # Shadow Clones, Substitution, Element Armor: always available
		d.merge({"name": "Basic Jutsu", "color": Color(0.3, 0.55, 0.9), "letter": "B", "basic": true,
			"moves": Moves.BASE.keys().map(func(k): return "base:" + str(k))}, true)
		return d
	if tree_kind == "element":
		d["name"] = cid
		d["color"] = GameData.get_element_color(cid)
		d["letter"] = cid.substr(0, 1)
		if not GameData.owned_elements.has(cid):
			d["locked"] = true
			d["msg"] = "%s\nnot owned\n\nRoll it with an\nElement Spin at the\nmain menu" % cid
			return d
		d["mkey"] = "el:" + cid
		d["lv"] = GameData.mastery_level(d["mkey"])
		d["equipped"] = GameData.equipped_element == cid
		for i in ElementData.count(cid):
			d["moves"].append("el:%s:%d" % [cid, i])
		return d
	var slot := int(cid)
	d["name"] = "SLOT #%d" % (slot + 1)
	if not GameData.slot_unlocked[slot]:
		d["locked"] = true
		d["msg"] = "Slot #%d locked\n\nOpen it in\nCustomize at the\nmain menu (%d spins)" % [slot + 1, GameData.SLOT_UNLOCK_COST[slot]]
		return d
	var id := str(GameData.slots[slot])
	if id == "none":
		d["locked"] = true
		d["msg"] = "Slot #%d empty\n\nSpin it in\nCustomize at the\nmain menu" % (slot + 1)
		return d
	var bd := Bloodline.get_def(id)
	d.merge({"name": bd["name"], "color": bd["color"], "letter": str(bd["name"]).substr(0, 1), "mkey": id,
		"lv": GameData.mastery_level(id), "mode": id, "equipped": slot == GameData.active_slot}, true)
	for i in 3:
		d["moves"].append("bl:%s:%d" % [id, i])
	return d

func _equip_col(cid: String) -> void:
	if tree_kind == "element":
		_equip_element(cid)
	else:
		_equip_slot(int(cid))

func _build_tree_page() -> void:
	_clear(bl_page)
	var pages := _tree_pages()
	if tree_sel_col == "":   # start on the equipped column
		var want := GameData.equipped_element if tree_kind == "element" else str(GameData.active_slot)
		for i in pages.size():
			if (pages[i] as Array).has(want):
				tree_page = i
		tree_sel_col = want
		tree_sel_idx = 0
	tree_page = clampi(tree_page, 0, pages.size() - 1)
	var cols: Array = pages[tree_page]
	for c in cols.size():
		_build_tree_column(str(cols[c]), c * 200.0)
	_bl_rect(Rect2(402, 0, 4, 404), INK, bl_page)
	var names := _tree_page_names()
	var bw := 190.0 / names.size()
	for k in names.size():
		var b := Button.new()
		b.text = names[k]
		b.position = Vector2(412 + k * (bw + 2.0), 0)
		b.size = Vector2(bw, 24)
		_style_green(b)
		b.add_theme_font_size_override("font_size", 11 if names.size() < 3 else 13)
		b.disabled = tree_page == k or (tree_kind == "bloodline" and k == 1 and not (GameData.slot_unlocked[2] or GameData.slot_unlocked[3]))
		b.pressed.connect(func() -> void:
			tree_page = k
			tree_sel_col = str(pages[k][0])
			tree_sel_idx = 0
			_build_tree_page())
		bl_page.add_child(b)
	_build_tree_info()

func _build_tree_column(cid: String, x: float) -> void:
	var d := _col_data(cid)
	var col := Control.new()
	col.position = Vector2(x, 0)
	col.size = Vector2(200, 404)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl_page.add_child(col)
	var badge := Octagon.new()
	badge.position = Vector2(4, 0)
	col.add_child(badge)
	_bl_rect(Rect2(52, 8, 144, 30), Color(0.03, 0.03, 0.03), col)
	if d["locked"]:
		badge.kind = "lock"
		_bl_label(str(d["name"]).to_upper(), Rect2(52, 8, 140, 30), 15, Color.WHITE, col, HORIZONTAL_ALIGNMENT_RIGHT)
		_bl_label(d["msg"], Rect2(0, 110, 200, 140), 16, BODY_TEXT, col)
		return
	var lv: int = d["lv"]
	badge.kind = "letter"
	badge.letter = d["letter"]
	badge.fill = (d["color"] as Color).darkened(0.25)
	badge.ring = d["equipped"]
	_bl_label("ANY TIME" if d.get("basic", false) else "LV.%d" % lv, Rect2(52, 8, 140, 30), 19, Color.WHITE, col, HORIZONTAL_ALIGNMENT_RIGHT)
	_bl_label(d["name"], Rect2(0, 40, 200, 18), 14, BODY_TEXT, col)
	var moves: Array = d["moves"]
	var n := moves.size() + (1 if d["mode"] != "" else 0)
	for k in n:
		var ic := AbilityIcon.new()
		ic.position = Vector2(68, 62 + k * 70)
		if k < moves.size():
			var a := Moves.spec(moves[k])
			ic.fill = a["col"] if (a["col"] as Color).get_luminance() > 0.12 else d["color"]
			ic.letter = str(a["name"]).substr(0, 1)
			ic.tex = Moves.icon(moves[k])
			ic.locked = lv < int(a["lvl"])
			ic.lvl_text = "LVL [%d]" % int(a["lvl"])
			ic.key_text = GameData.key_of(moves[k])
		else:
			var m := Bloodline.mode(d["mode"])
			ic.fill = m["col"]
			ic.letter = "C"
			ic.tex = Moves.mode_icon(d["mode"])
			ic.is_mode = true
			ic.key_text = "C"
			ic.locked = lv < Bloodline.MODE_LEVEL
			ic.lvl_text = "LVL [%d]" % Bloodline.MODE_LEVEL
		ic.selected = tree_sel_col == cid and tree_sel_idx == k
		ic.pressed.connect(func() -> void:
			tree_sel_col = cid
			tree_sel_idx = k
			_build_tree_page())
		col.add_child(ic)
	if d.get("basic", false):
		return   # nothing to equip or level up
	var eq := Button.new()
	eq.flat = true
	eq.text = "[EQUIPPED]" if d["equipped"] else "[EQUIP]"
	eq.position = Vector2(30, 344)
	eq.size = Vector2(140, 28)
	eq.add_theme_font_override("font", font())
	eq.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		eq.add_theme_color_override(c, Color(0.85, 0.08, 0.06) if c != "font_hover_color" else Color(1.0, 0.3, 0.2))
	eq.add_theme_color_override("font_disabled_color", Color(0.15, 0.45, 0.15))
	eq.add_theme_color_override("font_outline_color", Color.BLACK)
	eq.add_theme_constant_override("outline_size", 4)
	eq.disabled = d["equipped"]
	eq.pressed.connect(func() -> void:
		_equip_col(cid))
	col.add_child(eq)
	var pr := GameData.mastery_progress(d["mkey"])
	var bar := Rect2(10, 378, 180, 20)
	_bl_rect(bar, Color(0.05, 0.05, 0.05), col)
	if lv < GameData.MASTERY_MAX:
		_bl_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * float(pr[0]) / maxf(float(pr[1]), 1.0), bar.size.y - 4)),
			Color(0.75, 0.6, 0.15), col)
	_bl_label("EXP: %s/%s" % [_k(pr[0]), _k(pr[1])] if lv < GameData.MASTERY_MAX else "MAX MASTERY", bar, 12, Color.WHITE, col, HORIZONTAL_ALIGNMENT_CENTER, 4)

func _build_tree_info() -> void:
	var box := Control.new()
	box.position = Vector2(412, 30)
	box.size = Vector2(196, 374)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl_page.add_child(box)
	var d := _col_data(tree_sel_col)
	if d["locked"]:
		_bl_label("Click an ability, then\nclick a key to put it\non your hotbar.\n\nAbilities unlock as\nthis %s levels up." % ("element" if tree_kind == "element" else "bloodline"),
			Rect2(0, 10, 196, 200), 15, BODY_TEXT, box)
		return
	var moves: Array = d["moves"]
	var lv: int = d["lv"]
	if tree_sel_idx >= moves.size():   # bloodline power-up
		var m := Bloodline.mode(d["mode"])
		_bl_label(m["name"], Rect2(0, 0, 196, 30), 21, INK, box)
		_bl_label("POWER-UP  -  tap [C]", Rect2(0, 30, 196, 20), 13, Color(0.4, 0.15, 0.1), box)
		var ok := lv >= Bloodline.MODE_LEVEL
		_bl_label("UNLOCKED" if ok else "Needs LV %d  (now %d)" % [Bloodline.MODE_LEVEL, lv], Rect2(0, 52, 196, 20), 14,
			Color(0.1, 0.45, 0.12) if ok else Color(0.7, 0.08, 0.06), box)
		_bl_label("%s\n\nAlways on C. No timer: drains MD while on. Tap C again to release; it ends when MD runs out." % m["desc"],
			Rect2(2, 78, 192, 200), 14, BODY_TEXT, box, HORIZONTAL_ALIGNMENT_LEFT, 0, true)
		return
	var mv: String = moves[tree_sel_idx]
	var a := Moves.spec(mv)
	var cur_key := GameData.key_of(mv)
	_bl_label(a["name"], Rect2(0, 0, 196, 28), 20, INK, box)
	_bl_label("%d chakra   %ds cooldown" % [int(a["cost"]), int(a["cd"])], Rect2(0, 28, 196, 18), 13, Color(0.4, 0.15, 0.1), box)
	var ok2 := lv >= int(a["lvl"])
	_bl_label("UNLOCKED" if ok2 else "Needs LV %d  (now %d)" % [int(a["lvl"]), lv], Rect2(0, 47, 196, 18), 14,
		Color(0.1, 0.45, 0.12) if ok2 else Color(0.7, 0.08, 0.06), box)
	_bl_label(a["desc"], Rect2(2, 68, 192, 74), 13, BODY_TEXT, box, HORIZONTAL_ALIGNMENT_LEFT, 0, true)
	_bl_rect(Rect2(0, 146, 196, 3), INK, box)
	_bl_label("KEYBIND:  [%s]" % (cur_key if cur_key != "" else " - "), Rect2(0, 152, 196, 22), 16, INK, box)
	for i in Moves.BIND_KEYS.size():
		var k: String = Moves.BIND_KEYS[i]
		var b := Button.new()
		b.text = k
		b.position = Vector2((i % 3) * 66, 178 + (i / 3) * 34)
		b.size = Vector2(62, 30)
		_style_green(b)
		b.add_theme_font_size_override("font_size", 17)
		var holder := Moves.spec(str(GameData.keybinds.get(k, "")))
		b.tooltip_text = "Empty" if holder.is_empty() else "Now: %s" % holder["name"]
		if k == cur_key:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.8, 0.1, 0.06)
			sb.set_border_width_all(3)
			sb.border_color = Color(0.3, 0.02, 0.02)
			b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(func() -> void:
			GameData.bind_move(k, mv)
			_build_tree_page())
		box.add_child(b)
	var ub := Button.new()
	ub.text = "UNBIND"
	ub.position = Vector2(0, 284)
	ub.size = Vector2(196, 26)
	_style_green(ub)
	ub.add_theme_font_size_override("font_size", 14)
	ub.disabled = cur_key == ""
	ub.pressed.connect(func() -> void:
		GameData.unbind_move(mv)
		_build_tree_page())
	box.add_child(ub)
	var tip := "Abilities still need their level to work." if not ok2 else "Press [%s] in a fight to use it." % cur_key if cur_key != "" else "Pick a key to use it in fights."
	if tree_kind == "bloodline":
		tip += " Jutsu from every bloodline in your slots work - mix and match. EQUIP picks your transformation (C)."
	_bl_label(tip, Rect2(0, 314, 196, 60), 12, Color(0.35, 0.25, 0.15), box, HORIZONTAL_ALIGNMENT_LEFT, 0, true)

func _page_bloodlines() -> Array:
	var out: Array = []
	for i in GameData.SLOT_COUNT:
		if not GameData.slot_unlocked[i]:
			out.append(_locked("Slot #%d" % (i + 1),
				"Locked. Open it in the spin menu (B) for %d spins." % GameData.SLOT_UNLOCK_COST[i]))
			continue
		var id := str(GameData.slots[i])
		var d := Bloodline.get_def(id)
		var is_eq: bool = GameData.active_slot == i
		var acts: Array = []
		if not is_eq:
			acts.append(_act("EQUIP", _equip_slot.bind(i)))
		var title := "Slot #%d: %s" % [i + 1, "Empty" if id == "none" else str(d["name"])]
		var sub := "%s%s" % ["Spin to awaken" if id == "none" else str(d["rarity"]), "  -  EQUIPPED" if is_eq else ""]
		out.append(_item(title, sub, d["color"], "?" if id == "none" else str(d["name"]).substr(0, 1),
			d["desc"], {"actions": acts}))
	extras = [_act("OPEN SPIN", _open_spin, "[Awakening - %d spins]" % GameData.spins)]
	return out

func _page_sub() -> Array:
	var id := GameData.equipped
	var d := Bloodline.get_def(id)
	if id == "none":
		return [_item("No Bloodline", "Press B to spin", Color(0.5, 0.5, 0.5), "-",
			"Equip a bloodline to get 3 abilities (keys 1 / 2 / 3) and a power-up (C) at bloodline LV 1000.")]
	var lv := GameData.mastery_level(id)
	var out: Array = []
	for i in 3:
		var a := Bloodline.ability(id, i)
		var locked := lv < int(a["lvl"])
		var st := "LOCKED - unlocks at LV %d" % int(a["lvl"]) if locked else _cd(float(p.move_cd.get("bl:%s:%d" % [id, i], 0.0)))
		var key := GameData.key_of("bl:%s:%d" % [id, i])
		out.append(_item(a["name"], "[%s]  %d chakra, %ds cooldown" % [key if key != "" else "no key", int(a["cost"]), int(a["cd"])], a["col"],
			key if key != "" else str(i + 1), "%s\n\nStatus: %s" % [a["desc"], st], {"locked": locked}))
	var m := Bloodline.mode(id)
	var ml := lv < Bloodline.MODE_LEVEL
	out.append(_item(m["name"], "[C]  power-up  -  drains MD", m["col"], "C",
		"%s\n\nNo timer: lasts while you have MD, tap C again to release.\nStatus: %s" % [m["desc"],
			"ON" if p.powered else ("LOCKED - unlocks at LV %d" % Bloodline.MODE_LEVEL if ml else "READY (MD %d)" % int(p.mode_meter))],
		{"locked": ml}))
	return out

func _page_companions() -> Array:
	var ccd := float(p.move_cd.get("base:clones", 0.0))
	var can := not p.is_dead and ccd <= 0.0 and p.chakra >= 40.0
	return [
		_item("Shadow Clones", "%d clones, %ds" % [p.clone_count, int(p.clone_time)], Color(0.3, 0.6, 1.0), "S",
			"Clones chase and fight enemies for you. Costs 40 chakra, cooldown 6 seconds.\nStatus: %s" % _cd(ccd),
			{"actions": [_act("SUMMON", _summon_clones, "", not can)]}),
		_locked("More companions", "No other companions exist yet."),
	]

func _page_travel() -> Array:
	var out: Array = []
	var mode: String = GameData.mode
	var spots: Array = []     # [name, glyph, colour, position, blurb]
	match mode:
		"world":
			spots.append(["Main Gate", "G", Color(0.78, 0.62, 0.55), Vector3(0, 1, 150), "Just inside the A-Un gate."])
			spots.append(["Crossroads", "X", Color(0.6, 0.6, 0.6), Vector3(0, 1, 40), "Middle of the village, by Ichiraku."])
			spots.append(["Hokage Tower", "H", Color(0.78, 0.62, 0.55), Vector3(0, 1, -75), "In front of the tower."])
			spots.append(["Hokage Rock", "R", Color(0.5, 0.48, 0.46), Vector3(0, 63, -178), "On top of the Hokage faces."])
			spots.append(["Academy", "A", Color(0.78, 0.62, 0.55), Vector3(-55, 1, -52), "The Academy yard and its swing."])
			spots.append(["Training Ground 3", "T", Color(0.45, 0.56, 0.45), Vector3(-108, 1, 90), "Three posts and the memorial stone."])
			spots.append(["Uchiha District", "U", Color(0.6, 0.6, 0.61), Vector3(112, 1, 106), "Outside the Uchiha compound gate."])
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
			"Spin for new bloodlines. A Legendary or Mythic is guaranteed within %d spins." % maxi(GameData.PITY_LIMIT - GameData.pity, 0),
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
		_item("Unlock Slots", "Instant", Color(0.9, 0.5, 0.2), "U",
			"Opens all 4 bloodline slots and marks every bloodline as discovered." + note, {"actions": [_act("UNLOCK", _unlock_all)]}),
		_item("+100 Bloodline LV", "%s LV %d" % [Bloodline.get_def(GameData.equipped)["name"], GameData.mastery_level(GameData.equipped)],
			Color(0.9, 0.1, 0.15), "L", "Adds 100 mastery levels to your equipped bloodline (max %d unlocks the power-up)." % GameData.MASTERY_MAX + note,
			{"actions": [_act("+100", _cheat_mastery.bind(100), "", GameData.equipped == "none"),
				_act("MAX (1000)", _cheat_mastery.bind(1000), "", GameData.equipped == "none")]}),
		_item("+5 Shinobi Levels", "LV %d" % GameData.level, Color(0.95, 0.75, 0.2), "+",
			"Gives 5 levels (and their stat points)." + note, {"actions": [_act("+5 LEVELS", _cheat_levels)]}),
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
			{"slider": {"min": 0.0, "max": 18.0, "step": 0.5, "value": p.cam_zoom, "fmt": "%.1f m",
				"cb": func(v: float) -> void: p.cam_zoom = 0.0 if v < 0.75 else maxf(v, Player.ZOOM_MIN)}}),
		_item("Field of View", "Camera angle", Color(0.9, 0.7, 0.4), "F",
			"A wider angle shows more of the world.",
			{"slider": {"min": 55.0, "max": 100.0, "step": 1.0, "value": p.fov_base, "fmt": "%d deg",
				"cb": func(v: float) -> void: p.fov_base = v}}),
		_item("Cel Shading", "ON" if GameData.toon_shading else "OFF", Color(0.95, 0.55, 0.3), "T",
			"Anime cel shading on the maps: crisp light / shadow tones, cool shadows, rim light.\nApplies to the next map you load.",
			{"actions": [_act("TURN OFF" if GameData.toon_shading else "TURN ON", _toggle_toon)]}),
		_item("Master Volume", "Sound effects", Color(0.8, 0.5, 0.8), "V",
			"Overall volume.",
			{"slider": {"min": 0.0, "max": 100.0, "step": 1.0, "value": vol, "fmt": "%d%%",
				"cb": func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001) / 100.0))}}),
	]

func _page_controls() -> Array:
	return [
		_item("Movement", "WASD, Shift, Space, Q", Color(0.4, 0.7, 0.4), "W",
			"WASD: move\nShift: sprint (uses stamina)\nSpace: jump, press again to double jump\nQ: dash"),
		_item("Hotbar", "R T Y F G H V B N", Color(0.85, 0.3, 0.2), "R",
			"Each key runs the move you put on it. Assign moves in the Bloodline and Element tabs (click an ability, then a key).\nNow: %s" % _binds_text()),
		_item("Combat", "Mouse, E, Tab", Color(0.6, 0.65, 0.8), "C",
			"Left mouse: melee combo\nRight mouse: kunai\nRight mouse + E: kunai volley\nTab / middle mouse: lock on"),
		_item("Power", "C and Z", Color(1.0, 0.5, 0.1), "Z",
			"Tap C: bloodline power-up on / off (bloodline LV 1000, drains MD; X also works)\nHold C: charge chakra\nZ: Kurama Mode on / off (after beating Kurama, drains MD; can stack with C)"),
		_item("Menus", "M, E, L, Esc", Color(0.9, 0.75, 0.2), "M",
			"M: this menu\nE: talk to villagers (open world)\nL: show / hide the quest tracker\nEsc: free the mouse / close menus\nEnter: retry after dying"),
	]

# ------------------------------------------------------------------ actions
func _toggle_toon() -> void:
	GameData.toon_shading = not GameData.toon_shading
	GameData.save()
	_reload_page()

func _equip_slot(i: int) -> void:
	if not GameData.set_active_slot(i):
		return
	p.apply_bloodline()
	_refresh_header()
	_reload_page()

func _equip_element(element: String) -> void:
	if not GameData.owned_elements.has(element):
		return
	GameData.equip_element(element)
	_refresh_header()
	_reload_page()

## Spins live on the main menu now: go there and open Customize straight away.
func _open_spin() -> void:
	GameData.open_customize = true
	_to_title()

func _summon_clones() -> void:
	close()
	p._use_move("base:clones")

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
	var pos: Vector3 = qs.target_position()
	if pos == Vector3.INF:
		pos = Quests.NPCS[act["giver"]]["pos"]
	return pos + Vector3(0, 1, 3)

func _to_title() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if NetworkSession.is_active():
		NetworkSession.disconnect_session()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

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
	for i in GameData.SLOT_COUNT:
		GameData.slot_unlocked[i] = true
	GameData.save()
	_refresh_header()

func _cheat_mastery(n: int) -> void:
	var id := GameData.equipped
	if id == "none":
		return
	GameData.set_mastery_level(id, GameData.mastery_level(id) + n)
	_refresh_header()
	_reload_page()

func _cheat_levels() -> void:
	for i in 5:
		GameData.add_xp(GameData.xp_needed() - GameData.xp)
	GameData.save()
	_refresh_header()
	_reload_page()

func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.take_damage(999999.0, Vector3.ZERO)
	_refresh_header()
