class_name UiStyle
extends RefCounted
## Shared look for the out-of-game screens (main menu, multiplayer lobby) so they match the
## in-game UI: parchment scrolls with a gold edge and green bands (M menu), black brush-stroke
## ribbons (spin menu) and the same bold ink font (GameMenu.font()).

const INK := GameMenu.INK
const PARCH := GameMenu.PARCH
const GOLD := GameMenu.GOLD
const GOLD_DK := GameMenu.GOLD_DK
const GREEN := GameMenu.GREEN
const GREEN_DK := GameMenu.GREEN_DK
const BODY_TEXT := GameMenu.BODY_TEXT
const RED := Color(0.78, 0.1, 0.06)
const UI := "res://assets/ui/"

## A 9-slice box from one of the UI kit pieces (assets/ui, cut from ui_sheet_source.png).
## m = texture margins [left, top, right, bottom] (kept unstretched), c = content margins.
static func tex_box(name: String, m: Array, c: Array = [], tint := Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(UI + name + ".png")
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	if c.is_empty():
		c = m
	sb.content_margin_left = c[0]
	sb.content_margin_top = c[1]
	sb.content_margin_right = c[2]
	sb.content_margin_bottom = c[3]
	sb.modulate_color = tint
	return sb

## A parchment scroll panel (gold edge + green bands top and bottom). Put content in the
## returned MarginContainer.
static func scroll(parent: Node, min_size: Vector2) -> MarginContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	# parchment in a wooden frame with rope and a red swirl (UI kit: frame_tall)
	panel.add_theme_stylebox_override("panel", tex_box("frame_tall", [60, 56, 56, 60], [0, 0, 0, 0]))
	parent.add_child(panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 58)
	m.add_theme_constant_override("margin_right", 54)
	m.add_theme_constant_override("margin_top", 46)
	m.add_theme_constant_override("margin_bottom", 50)
	panel.add_child(m)
	return m

static func label(parent: Node, text: String, size: int, color := BODY_TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", GameMenu.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", outline)
	parent.add_child(l)
	return l

## Big game title with a red brush stroke under it.
static func title(parent: Node, text: String, size := 66) -> Label:
	var l := label(parent, text, size, Color(1.0, 0.93, 0.8), 18)
	l.add_theme_color_override("font_shadow_color", Color(0.75, 0.08, 0.04, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 4)
	l.add_theme_constant_override("shadow_offset_y", 5)
	var stroke := Control.new()
	stroke.custom_minimum_size = Vector2(0, 12)
	stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stroke.draw.connect(func() -> void:
		var w := minf(stroke.size.x, 470.0)
		stroke.draw_colored_polygon(PackedVector2Array([Vector2(4, 3), Vector2(w, 0), Vector2(w - 26, 10), Vector2(0, 12)]), RED))
	parent.add_child(stroke)
	return l

## Black skewed ribbon button (the spin menu's "[ CLICK TO SPIN ]" look). One line of text.
static func ribbon_button(parent: Node, text: String, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", GameMenu.font())
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 56)
	# ink brush stroke; hover / focus = the red ribbon with the Leaf emblem (UI kit)
	var calm := tex_box("brush_black", [60, 0, 60, 0], [96, 4, 40, 4])
	var hot := tex_box("ribbon_leaf_red", [96, 0, 70, 0], [96, 4, 40, 4])
	var down := tex_box("ribbon_leaf_red", [96, 0, 70, 0], [96, 4, 40, 4], Color(0.8, 0.8, 0.8))
	var off := tex_box("brush_black", [60, 0, 60, 0], [96, 4, 40, 4], Color(0.6, 0.6, 0.6, 0.8))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb: StyleBox = {"normal": calm, "hover": hot, "focus": hot, "pressed": down, "hover_pressed": down, "disabled": off}[st]
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	parent.add_child(b)
	return b

## Green in-game button (same as the M menu's action buttons).
static func green_button(parent: Node, text: String, size := 17) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 42)
	# riveted red plate (UI kit: btn_red / btn_dark)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb: StyleBoxTexture
		match st:
			"hover", "focus":
				sb = tex_box("btn_red", [24, 0, 24, 0], [14, 4, 14, 4], Color(1.25, 1.1, 1.0))
			"pressed", "hover_pressed":
				sb = tex_box("btn_dark", [24, 0, 24, 0], [14, 4, 14, 4])
			"disabled":
				sb = tex_box("btn_dark", [24, 0, 24, 0], [14, 4, 14, 4], Color(0.7, 0.7, 0.7))
			_:
				sb = tex_box("btn_red", [24, 0, 24, 0], [14, 4, 14, 4])
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", GameMenu.font())
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color.WHITE if c != "font_disabled_color" else Color(0.8, 0.8, 0.8))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 5)
	parent.add_child(b)
	return b

## Small borderless ink text button (Quit, Back).
static func text_button(parent: Node, text: String, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", GameMenu.font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 6)
	parent.add_child(b)
	return b

## Labelled text field on parchment ("NAME  [ Shinobi ]").
static func field(parent: Node, caption: String, value: String, hint := "") -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := label(row, caption, 17, BODY_TEXT)
	l.custom_minimum_size = Vector2(120, 0)
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = hint
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(0, 38)
	e.add_theme_font_override("font", GameMenu.font())
	e.add_theme_font_size_override("font_size", 17)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.94, 0.82)
	sb.set_border_width_all(2)
	sb.border_color = GOLD_DK
	sb.content_margin_left = 10
	e.add_theme_stylebox_override("normal", sb)
	var sbf := sb.duplicate() as StyleBoxFlat
	sbf.border_color = RED
	e.add_theme_stylebox_override("focus", sbf)
	e.add_theme_color_override("font_color", BODY_TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(0.5, 0.45, 0.35))
	e.add_theme_color_override("caret_color", RED)
	row.add_child(e)
	return e

## Thin ink divider line.
static func divider(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = Color(0.45, 0.35, 0.2, 0.6)
	r.custom_minimum_size = Vector2(0, 2)
	parent.add_child(r)

static func spacer(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)
