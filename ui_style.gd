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

## A parchment scroll panel (gold edge + green bands top and bottom). Put content in the
## returned MarginContainer.
static func scroll(parent: Node, min_size: Vector2) -> MarginContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCH
	sb.set_border_width_all(4)
	sb.border_color = GOLD_DK
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var bands := Control.new()   # green bands drawn over the parchment, like the in-game scroll
	bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bands.draw.connect(func() -> void:
		var w := bands.size.x
		bands.draw_rect(Rect2(0, 0, w, 14), GREEN)
		bands.draw_rect(Rect2(0, 14, w, 3), GREEN_DK)
		bands.draw_rect(Rect2(0, bands.size.y - 14, w, 14), GREEN)
		bands.draw_rect(Rect2(0, bands.size.y - 17, w, 3), GREEN_DK))
	panel.add_child(bands)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 26)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", 30)
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
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.skew = Vector2(0.18, 0)
		sb.content_margin_left = 22
		sb.content_margin_right = 16
		match st:
			"normal":
				sb.bg_color = Color(0.03, 0.03, 0.03, 0.95)
			"hover", "focus":
				sb.bg_color = Color(0.36, 0.05, 0.04, 0.97)
				sb.border_width_left = 8
				sb.border_color = Color(1.0, 0.55, 0.15)
			"pressed":
				sb.bg_color = Color(0.55, 0.08, 0.06, 0.97)
			"disabled":
				sb.bg_color = Color(0.2, 0.2, 0.2, 0.85)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.45))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	parent.add_child(b)
	return b

## Green in-game button (same as the M menu's action buttons).
static func green_button(parent: Node, text: String, size := 17) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 42)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var col := GameMenu.BTN
		if st == "hover" or st == "focus":
			col = GameMenu.BTN.lightened(0.15)
		elif st == "pressed":
			col = GameMenu.BTN.darkened(0.2)
		elif st == "disabled":
			col = Color(0.35, 0.4, 0.33)
		sb.bg_color = col
		sb.set_border_width_all(3)
		sb.border_color = Color(0.06, 0.25, 0.05) if st != "focus" else Color(1.0, 0.86, 0.45)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", GameMenu.font())
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
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
