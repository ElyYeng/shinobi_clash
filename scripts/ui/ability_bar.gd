class_name AbilityBar
extends Control
## Shindo-Life style bottom HUD: octagon key slots (R T Y F G H | Z / C | Q RMB+E E V B N),
## HP / MD / CHI / STM bars and a MENU / QUEST strip. HUD creates it and calls update_from(player) every frame.
## What each key shows comes from Player.slot_info(key).

## R T Y F G H and V B N show whatever move is bound to them (Moves / GameData.keybinds).
const LEFT := ["R", "T", "Y", "F", "G", "H"]
const RIGHT := ["Q", "RMB+E", "E", "V", "B", "N"]
const PITCH := 52.0
const HUD_SCALE := 0.85   # size of the bottom HUD (1.0 = original)

var slots := {}
var hp: StatBar
var md: StatBar
var ck: StatBar
var st: StatBar
var strip_mid: Label
var strip_right: Label
var xp_bar: StatBar
var world_mode := false

# ------------------------------------------------------------------ inner widgets
class KeySlot extends Control:
	var key := ""
	var title := ""
	var cd := 0.0
	var cd_max := 1.0
	var cost := 0.0
	var chakra := 100.0
	var locked := false
	var active := false
	var timer := 0.0
	var not_ready := false
	var icon: Texture2D = null
	var empty := false
	static var _frame: Texture2D
	static var _frame_glow: Texture2D

	func _init() -> void:
		custom_minimum_size = Vector2(50, 58)
		size = Vector2(50, 58)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := GameMenu.font()
		var c := Vector2(25, 35)
		var pts := PackedVector2Array()
		for i in 8:
			var a := deg_to_rad(22.5 + 45.0 * i)
			pts.append(c + Vector2(cos(a), sin(a)) * 21.0)
		var short := cost > chakra + 0.01 and cd <= 0.0
		var dim := short or not_ready
		var fill := Color(0.06, 0.12, 0.08)
		var edge := Color(0.16, 0.38, 0.2)
		if locked:
			fill = Color(0.05, 0.05, 0.05)
			edge = Color(0.22, 0.22, 0.22)
		elif dim:
			fill = Color(0.17, 0.06, 0.06)
			edge = Color(0.45, 0.12, 0.12)
		if active:
			edge = Color(1.0, 0.85, 0.25)
		# UI kit slot: iron-cornered square frame (glowing orange when the move is active)
		draw_rect(Rect2(c - Vector2(19, 19), Vector2(38, 38)), fill)
		if icon != null:
			draw_texture_rect(icon, Rect2(c - Vector2(17, 17), Vector2(34, 34)), false,
				Color(0.45, 0.45, 0.45) if locked or dim else Color.WHITE)
		if _frame == null:   # kept in static vars - a texture nothing holds is freed before it's drawn
			_frame = load(UiStyle.UI + "slot.png")
			_frame_glow = load(UiStyle.UI + "slot_glow.png")
		var frame_tex: Texture2D = _frame_glow if active else _frame
		var fr := Rect2(c - Vector2(25, 25), Vector2(50, 50))
		draw_texture_rect(frame_tex, fr, false, Color(1.0, 0.55, 0.5) if dim and not locked else (Color(0.6, 0.6, 0.6) if locked else Color.WHITE))
		if cd > 0.0 and not locked:      # cooldown pie
			var frac := clampf(cd / maxf(cd_max, 0.01), 0.0, 1.0)
			if frac > 0.03:
				var arc := PackedVector2Array([c])
				for i in 25:
					var a2 := -PI / 2.0 + TAU * frac * float(i) / 24.0
					arc.append(c + Vector2(cos(a2), sin(a2)) * 18.0)
				draw_colored_polygon(arc, Color(0, 0, 0, 0.65))
		# small ability name above the slot
		draw_string_outline(f, Vector2(0, 11), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, 4, Color.BLACK)
		draw_string(f, Vector2(0, 11), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(1, 1, 1, 0.85))
		if locked:
			var red := Color(0.85, 0.08, 0.08)
			draw_rect(Rect2(c.x - 8.0, c.y - 2.0, 16.0, 12.0), red)
			draw_arc(Vector2(c.x, c.y - 2.0), 5.5, PI, TAU, 12, red, 3.0)
			draw_string_outline(f, Vector2(31, 54), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
			draw_string(f, Vector2(31, 54), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
			return
		var text := key
		var col := Color(0.7, 0.55, 0.55) if dim else Color.WHITE
		if empty:
			col = Color(1, 1, 1, 0.35)
		var fs := 17 if key.length() <= 1 else 11
		if icon != null and timer <= 0.0 and cd <= 0.0:   # key letter in the corner over the image
			draw_string_outline(f, Vector2(31, 54), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
			draw_string(f, Vector2(31, 54), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			return
		if timer > 0.0:
			text = str(int(ceil(timer)))
			col = Color(1.0, 0.88, 0.3)
			fs = 18
		elif cd > 0.0:
			text = str(int(ceil(cd)))
			col = Color(1, 1, 1)
			fs = 18
		var ty := c.y + fs * 0.36
		draw_string_outline(f, Vector2(0, ty), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 5, Color.BLACK)
		draw_string(f, Vector2(0, ty), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, col)

class StatBar extends Control:
	var value := 0.0
	var max_value := 1.0
	var ghost := 0.0
	var color := Color(0.25, 0.8, 0.2)
	var label := ""
	var use_ghost := true

	func _init(w := 300.0, h := 22.0) -> void:
		custom_minimum_size = Vector2(w, h)
		size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		var m := maxf(max_value, 0.001)
		if use_ghost:
			ghost = maxf(value, move_toward(ghost, value, m * 0.25 * delta))
		else:
			ghost = value
		queue_redraw()

	static var _track: StyleBoxTexture
	static var _fill: Texture2D

	func _draw() -> void:
		var m := maxf(max_value, 0.001)
		var r := Rect2(Vector2.ZERO, size)
		if _track == null:   # UI kit bar: iron frame + bevelled fill tinted with the bar's colour
			_track = UiStyle.tex_box("bar_track", [18, 11, 24, 12])
			_fill = load(UiStyle.UI + "bar_fill.png")
		var frame := r.grow_individual(10, 6, 14, 6)
		draw_style_box(_track, frame)
		var inner := r.grow_individual(-1, -2, -1, -2)
		var gw := inner
		gw.size.x *= clampf(ghost / m, 0.0, 1.0)
		if gw.size.x > 0.5:
			draw_texture_rect(_fill, gw, false, Color(color.lightened(0.55), 0.7))
		var fw := inner
		fw.size.x *= clampf(value / m, 0.0, 1.0)
		if fw.size.x > 0.5:
			draw_texture_rect(_fill, fw, false, color.lightened(0.15))
		var f := GameMenu.font()
		var fs := 15
		var pos := Vector2(0, size.y * 0.5 + fs * 0.36)
		draw_string_outline(f, pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 5, Color.BLACK)
		draw_string(f, pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)

# ------------------------------------------------------------------ build
func _ready() -> void:
	# zero-size anchor at the bottom centre; everything is placed relative to it
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale = Vector2.ONE * HUD_SCALE   # everything hangs off this bottom-centre anchor
	for i in LEFT.size():
		_slot(LEFT[i], Vector2(-362.0 + i * PITCH, -160.0))
	for i in RIGHT.size():
		_slot(RIGHT[i], Vector2(50.0 + i * PITCH, -160.0))
	_slot("Z", Vector2(-25.0, -176.0))
	_slot("C", Vector2(-25.0, -118.0))
	hp = _bar(Vector2(-352, -90), 306.0, 22.0, Color(0.25, 0.8, 0.2))
	md = _bar(Vector2(-330, -64), 290.0, 20.0, Color(0.55, 0.15, 0.85))
	ck = _bar(Vector2(46, -90), 306.0, 22.0, Color(0.2, 0.5, 1.0))
	st = _bar(Vector2(40, -64), 290.0, 20.0, Color(0.95, 0.5, 0.1))
	md.use_ghost = false
	st.use_ghost = false
	# bottom strip: MENU [M] | counters | [L] QUEST
	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel", UiStyle.tex_box("plate_dark", [22, 10, 22, 10]))
	strip.position = Vector2(-352, -36)
	strip.size = Vector2(704, 30)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var left := _strip_label("MENU [ M ]", Vector2(-352, -36), 704.0, HORIZONTAL_ALIGNMENT_LEFT)
	left.offset_left += 14.0
	strip_mid = _strip_label("", Vector2(-352, -36), 704.0, HORIZONTAL_ALIGNMENT_CENTER)
	strip_right = _strip_label("", Vector2(-352, -36), 704.0, HORIZONTAL_ALIGNMENT_RIGHT)
	strip_right.offset_right -= 14.0
	xp_bar = _bar(Vector2(-352, -7), 704.0, 7.0, Color(0.95, 0.75, 0.2))
	xp_bar.use_ghost = false

func _slot(key: String, pos: Vector2) -> void:
	var s := KeySlot.new()
	s.key = key
	s.position = pos
	add_child(s)
	slots[key] = s

func _bar(pos: Vector2, w: float, h: float, col: Color) -> StatBar:
	var b := StatBar.new(w, h)
	b.position = pos
	b.color = col
	add_child(b)
	return b

func _strip_label(text: String, pos: Vector2, w: float, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, 30)
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameMenu.font())
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

# ------------------------------------------------------------------ per-frame update
func update_from(p: Player) -> void:
	hp.max_value = p.max_health
	hp.value = p.health
	hp.label = "HP: %d" % int(ceil(p.health))
	ck.max_value = p.max_chakra
	ck.value = p.chakra
	ck.label = "CHI: %d" % int(p.chakra)
	md.max_value = Player.MODE_MAX
	md.value = p.mode_meter
	md.label = "MD: %d" % int(p.mode_meter)
	st.max_value = p.max_stamina
	st.value = p.stamina
	st.label = "STM: %d" % int(p.stamina)
	for k in slots:
		var s: KeySlot = slots[k]
		var info := p.slot_info(k)
		s.title = info["name"]
		s.cd = info["cd"]
		s.cd_max = info["max"]
		s.cost = info["cost"]
		s.locked = info["locked"]
		s.active = info["active"]
		s.timer = info["timer"]
		s.not_ready = info["not_ready"]
		s.icon = info.get("icon", null)
		s.empty = bool(info.get("empty", false))
		s.chakra = p.chakra
		s.queue_redraw()
	var pts := "  (+%d pts)" % GameData.stat_points if GameData.stat_points > 0 else ""
	strip_mid.text = "LV %d%s     SPINS %d     KILLS %d" % [GameData.level, pts, GameData.spins, p.kills]
	xp_bar.max_value = float(GameData.xp_needed())
	xp_bar.value = float(GameData.xp)
	strip_right.text = "[ L ] QUEST" if world_mode else ""
