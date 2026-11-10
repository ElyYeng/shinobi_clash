class_name SpinMenu
extends CanvasLayer

signal closed
## The one Customize screen (main menu: CUSTOMIZE / CHARACTER). Your shinobi stands on the right;
## three tabs on the left:
##   BLOODLINE   4 slots (Shindo Life style). SPIN rolls that slot, EQUIP picks the one you fight
##               with, slots 3-4 cost spins to open. Shows the equipped bloodline's 3 jutsu and
##               its power-up, plus auto-spin and pity.
##   ELEMENT     spin for elements, pick which one is equipped, see its 4 jutsu.
##   APPEARANCE  hair / shirt / pants (the meshes inside the character model), colours, textures.
## The look is saved when you close the screen. Odds/stats live in bloodline.gd, slots and pity in
## gamedata.gd, element jutsu in element_data.gd, the model parts in hero.gd.

const INK := Color(0.12, 0.1, 0.07)
const PAPER := Color(0.86, 0.82, 0.66)
const PAPER_DK := Color(0.76, 0.71, 0.55)
const GOLD := Color(1.0, 0.82, 0.3)
const AUTO_TARGETS := ["Rare", "Epic", "Legendary", "Mythic"]
const TABS := [["bloodline", "BLOODLINE"], ["element", "ELEMENT"], ["look", "APPEARANCE"]]
const HAIR_PRESETS := [
	"#14141A", "#3B2417", "#6B4226", "#A86B32", "#E6B52E", "#F2E7B8", "#F4F4F4", "#8A8F99",
	"#C8372D", "#E8702A", "#E85DA8", "#8B4DD6", "#2F6FD6", "#3FB6D8", "#35A55B", "#A6D63B",
]
const CAM_BODY := [Vector3(0.0, 1.05, 4.2), Vector3(0.0, 0.92, 0.0)]
const CAM_FACE := [Vector3(0.0, 1.62, 1.5), Vector3(0.0, 1.58, 0.0)]

## Octagon badge for a bloodline (or a red padlock for a locked slot).
class Emblem extends Control:
	const RARITY_COLORS := {
		"Common": Color(0.78, 0.78, 0.78), "Rare": Color(0.35, 0.62, 1.0),
		"Epic": Color(0.72, 0.4, 1.0), "Legendary": Color(1.0, 0.8, 0.2),
		"Mythic": Color(1.0, 0.3, 0.45)}
	var id := "none":
		set(v):
			id = v
			queue_redraw()
	var locked := false:
		set(v):
			locked = v
			queue_redraw()
	var active := false:
		set(v):
			active = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _oct(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 8:
			var a := deg_to_rad(22.5 + 45.0 * k)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 4.0
		if locked:
			var red := Color(0.78, 0.18, 0.15)
			var dark := Color(0.45, 0.06, 0.05)
			draw_arc(c + Vector2(0, -r * 0.18), r * 0.42, PI, TAU, 24, dark, r * 0.18)
			draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 0.2), Vector2(r * 1.32, r * 1.05)), red)
			draw_colored_polygon(_oct(c + Vector2(0, r * 0.3), r * 0.3), dark)
			return
		var rc: Color = RARITY_COLORS.get(str(Bloodline.get_def(id)["rarity"]), Color.GRAY) if id != "none" else Color(0.4, 0.4, 0.4)
		var fill: Color = Bloodline.get_def(id)["color"] if id != "none" else Color(0.25, 0.24, 0.22)
		if active:
			var glow := _oct(c, r + 3.0)
			glow.append(glow[0])
			draw_polyline(glow, Color(1.0, 0.92, 0.4), 4.0)
		draw_colored_polygon(_oct(c, r), Color(0.07, 0.06, 0.05))
		draw_colored_polygon(_oct(c, r * 0.8), fill.darkened(0.2))
		var ring := _oct(c, r * 0.9)
		ring.append(ring[0])
		draw_polyline(ring, rc, 3.0)
		var letter := "?" if id == "none" else str(Bloodline.get_def(id)["name"]).substr(0, 1)
		var f := GameMenu.font()
		var fs := int(r * 0.95)
		var pos := Vector2(0, c.y + fs * 0.36)
		draw_string_outline(f, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 6, Color.BLACK)
		draw_string(f, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)

## Round element badge (or a grey "?" for one you don't own yet).
class ElementBadge extends Control:
	var element := "Fire":
		set(v):
			element = v
			queue_redraw()
	var owned := true:
		set(v):
			owned = v
			queue_redraw()
	var active := false:
		set(v):
			active = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 3.0
		var col := GameData.get_element_color(element) if owned else Color(0.35, 0.33, 0.3)
		if active:
			draw_circle(c, r + 2.0, Color(1.0, 0.92, 0.4))
		draw_circle(c, r, Color(0.07, 0.06, 0.05))
		draw_circle(c, r * 0.8, col.darkened(0.15))
		draw_arc(c, r * 0.9, 0, TAU, 40, col.lightened(0.3), 2.5)
		var letter := element.substr(0, 1) if owned else "?"
		var f := GameMenu.font()
		var fs := int(r * 0.95)
		var pos := Vector2(0, c.y + fs * 0.36)
		draw_string_outline(f, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 6, Color.BLACK)
		draw_string(f, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)

var p: Player
var root: Control
var spins_label: Label
var el_spins_label: Label
var tab_buttons := {}            # tab id -> Button
var pages := {}                  # tab id -> Control
var current_tab := "bloodline"
var odds_panel: PanelContainer
var banner: Label
var flash: ColorRect
var done_btn: Button
var plate_name: Label            # name plate under the character
var plate_info: Label

# bloodline page
var slot_ui: Array = []          # one Dictionary per slot
var bl_title: Label
var bl_desc: Label
var bl_rows: VBoxContainer
var auto_pick: OptionButton
var auto_btn: Button
var pity_label: Label
# element page
var el_badges := {}              # element -> {badge, button}
var el_title: Label
var el_rows: VBoxContainer
var el_spin_btn: Button
# appearance page
var look_box: VBoxContainer
var color_targets: HFlowContainer
var texture_row: HFlowContainer
var swatch_buttons: Array[Button] = []
var hex_edit: LineEdit
var hsv := {}                    # "h"/"s"/"v" -> HSlider
var _working: Dictionary = {}
var _color_target := "hair_color"

# preview
var preview_box: SubViewportContainer
var preview_viewport: SubViewport
var preview_model: Node3D
var preview_cam: Camera3D
var floor_glow: MeshInstance3D
var floor_light: OmniLight3D
var _yaw := PI
var _dragging := false
var _face_view := false
var _cam_blend := 0.0

var spinning := false            # a reel is animating
var auto_running := false
var auto_stop := false
var confirm_slot := -1           # slot waiting for a second click before replacing an Epic+
var confirm_token := 0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := MenuBG.new()
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.02, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	margin.add_child(body)

	# ---- left: title, tabs, the parchment page
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	UiStyle.title(left, "CUSTOMIZE", 40)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	left.add_child(tabs)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := UiStyle.ribbon_button(tabs, t[1], 19)
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(t[0]))
		tab_buttons[t[0]] = b
	var scroll_box := UiStyle.scroll(left, Vector2(0, 0))
	scroll_box.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_box.add_theme_constant_override("margin_left", 18)
	scroll_box.add_theme_constant_override("margin_right", 10)
	scroll_box.add_theme_constant_override("margin_top", 24)
	scroll_box.add_theme_constant_override("margin_bottom", 24)
	var page_holder := Control.new()
	scroll_box.add_child(page_holder)
	for t in TABS:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		page_holder.add_child(sc)
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(page)
		pages[t[0]] = sc
		match t[0]:
			"bloodline":
				_build_bloodline_page(page)
			"element":
				_build_element_page(page)
			"look":
				_build_look_page(page)

	# ---- right: currencies, the character, name plate, done
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(top)
	spins_label = _chip_label(top)
	el_spins_label = _chip_label(top)
	var odds_btn := UiStyle.text_button(top, "ODDS", 16)
	odds_btn.pressed.connect(func(): odds_panel.visible = not odds_panel.visible)

	preview_box = SubViewportContainer.new()
	preview_box.stretch = true
	preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.mouse_filter = Control.MOUSE_FILTER_PASS
	right.add_child(preview_box)
	preview_viewport = SubViewport.new()
	preview_viewport.transparent_bg = true
	preview_viewport.own_world_3d = true
	preview_viewport.msaa_3d = Viewport.MSAA_4X
	preview_box.add_child(preview_viewport)
	_setup_preview()

	var plate := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.03, 0.03, 0.03, 0.88)
	psb.skew = Vector2(0.12, 0)
	psb.border_width_left = 6
	psb.border_color = Color(0.78, 0.1, 0.06)
	psb.content_margin_left = 20
	psb.content_margin_right = 16
	psb.content_margin_top = 6
	psb.content_margin_bottom = 8
	plate.add_theme_stylebox_override("panel", psb)
	right.add_child(plate)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	plate.add_child(pv)
	plate_name = UiStyle.label(pv, "", 24, Color.WHITE, 6)
	plate_info = UiStyle.label(pv, "", 14, Color(0.85, 0.82, 0.76), 4)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	var view_btn := UiStyle.text_button(bottom, "FACE / BODY", 15)
	view_btn.pressed.connect(func(): _face_view = not _face_view)
	UiStyle.label(bottom, "drag to rotate", 13, Color(0.7, 0.68, 0.64), 4)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(fill)
	done_btn = UiStyle.green_button(bottom, "DONE", 20)
	done_btn.custom_minimum_size = Vector2(170, 46)
	done_btn.pressed.connect(toggle)

	_build_odds_panel()
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner = UiStyle.label(root, "", 40, Color.WHITE, 12)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -450
	banner.offset_right = 450
	banner.offset_top = -60
	banner.offset_bottom = 60
	banner.pivot_offset = Vector2(450, 60)
	banner.modulate.a = 0.0

	root.visible = false

# ================================================================== pages
func _build_bloodline_page(page: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	slot_ui.resize(GameData.SLOT_COUNT)
	for i in GameData.SLOT_COUNT:
		slot_ui[i] = _build_slot(grid, i)
	UiStyle.divider(page)
	bl_title = UiStyle.label(page, "", 22, INK)
	bl_desc = UiStyle.label(page, "", 14, UiStyle.BODY_TEXT)
	bl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl_rows = VBoxContainer.new()
	bl_rows.add_theme_constant_override("separation", 4)
	page.add_child(bl_rows)
	UiStyle.divider(page)
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 8)
	page.add_child(auto_row)
	auto_pick = OptionButton.new()
	for t in AUTO_TARGETS:
		auto_pick.add_item("Stop at %s%s" % [t, "" if t == "Mythic" else "+"])
	auto_pick.select(AUTO_TARGETS.find("Legendary"))
	auto_pick.add_theme_font_override("font", GameMenu.font())
	auto_pick.add_theme_font_size_override("font_size", 14)
	auto_pick.custom_minimum_size = Vector2(170, 36)
	auto_row.add_child(auto_pick)
	auto_btn = UiStyle.ribbon_button(auto_row, "", 15)
	auto_btn.custom_minimum_size = Vector2(0, 36)
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_btn.pressed.connect(_on_auto)
	pity_label = UiStyle.label(page, "", 13, Color(0.38, 0.3, 0.18))

func _build_slot(parent: Node, i: int) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	var em := Emblem.new()
	em.custom_minimum_size = Vector2(70, 70)
	em.pivot_offset = Vector2(35, 35)
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(em)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	UiStyle.label(vb, "SLOT %d" % (i + 1), 11, Color(0.42, 0.36, 0.26))
	var nm := UiStyle.label(vb, "", 18, INK)
	nm.clip_text = true
	var rar := UiStyle.label(vb, "", 12, INK)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	var spin := UiStyle.ribbon_button(row, "", 13)
	spin.custom_minimum_size = Vector2(0, 28)
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.pressed.connect(_on_slot_pressed.bind(i))
	var eq := UiStyle.green_button(row, "", 12)
	eq.custom_minimum_size = Vector2(66, 28)
	eq.pressed.connect(_on_equip.bind(i))
	return {"card": card, "emblem": em, "name": nm, "rarity": rar, "spin": spin, "equip": eq}

func _build_element_page(page: VBoxContainer) -> void:
	UiStyle.label(page, "YOUR ELEMENTS  -  click one to equip it", 13, Color(0.42, 0.36, 0.26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	for e in GameData.ELEMENTS:
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(96, 104)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		var badge := ElementBadge.new()
		badge.element = e
		badge.position = Vector2(14, 0)
		badge.size = Vector2(68, 68)
		b.add_child(badge)
		var l := UiStyle.label(b, e.to_upper(), 14, INK)
		l.position = Vector2(0, 72)
		l.size = Vector2(96, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(_equip_element.bind(e))
		el_badges[e] = {"badge": badge, "button": b, "label": l}
	el_spin_btn = UiStyle.ribbon_button(page, "", 20)
	el_spin_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	el_spin_btn.pressed.connect(_on_element_spin)
	UiStyle.label(page, "A spin always gives an element you don't own yet, until you have them all.", 12, Color(0.42, 0.36, 0.26))
	UiStyle.divider(page)
	el_title = UiStyle.label(page, "", 22, INK)
	el_rows = VBoxContainer.new()
	el_rows.add_theme_constant_override("separation", 4)
	page.add_child(el_rows)

func _build_look_page(page: VBoxContainer) -> void:
	look_box = VBoxContainer.new()   # one row of choices per model part (filled in _build_look_options)
	look_box.add_theme_constant_override("separation", 6)
	page.add_child(look_box)
	UiStyle.divider(page)
	UiStyle.label(page, "COLOUR", 16, INK)
	color_targets = HFlowContainer.new()
	color_targets.add_theme_constant_override("h_separation", 5)
	page.add_child(color_targets)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	page.add_child(grid)
	swatch_buttons.clear()
	for hex in HAIR_PRESETS:
		var sw := _swatch(Color.html(str(hex)))
		grid.add_child(sw)
		swatch_buttons.append(sw)
	for ch in [["h", "HUE"], ["s", "SATURATION"], ["v", "BRIGHTNESS"]]:
		var r := HBoxContainer.new()
		page.add_child(r)
		var l := UiStyle.label(r, ch[1], 12, UiStyle.BODY_TEXT)
		l.custom_minimum_size = Vector2(96, 0)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.005
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(_on_hsv_changed)
		r.add_child(s)
		hsv[ch[0]] = s
	hex_edit = UiStyle.field(page, "HEX", "", "#RRGGBB")
	hex_edit.max_length = 7
	hex_edit.text_submitted.connect(_on_hex_submitted)
	hex_edit.focus_exited.connect(func(): _on_hex_submitted(hex_edit.text))
	texture_row = HFlowContainer.new()
	texture_row.add_theme_constant_override("h_separation", 5)
	page.add_child(texture_row)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	page.add_child(acts)
	var rnd := UiStyle.green_button(acts, "RANDOMIZE", 15)
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rnd.pressed.connect(_randomize_look)
	var rst := UiStyle.green_button(acts, "RESET", 15)
	rst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rst.pressed.connect(_reset_look)

func _build_odds_panel() -> void:
	odds_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.03, 0.96)
	sb.border_color = Color(0.75, 0.62, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	odds_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(odds_panel)
	odds_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	odds_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	odds_panel.position += Vector2(-28, 60)
	var total := 0.0
	var by_rarity := {}
	for id in Bloodline.DEFS:
		var w := float(Bloodline.DEFS[id]["weight"])
		total += w
		var r: String = Bloodline.DEFS[id]["rarity"]
		by_rarity[r] = float(by_rarity.get(r, 0.0)) + w
	var lines: Array[String] = ["BLOODLINE ODDS", ""]
	for r in GameData.RARITY_ORDER:
		lines.append("%s  -  %.1f%%" % [r, 100.0 * float(by_rarity.get(r, 0.0)) / total])
	lines.append("")
	for id in Bloodline.DEFS:
		var w2 := float(Bloodline.DEFS[id]["weight"])
		if w2 > 0.0:
			lines.append("%s  (%s)  %.1f%%" % [Bloodline.DEFS[id]["name"], Bloodline.DEFS[id]["rarity"], 100.0 * w2 / total])
	lines.append("")
	lines.append("Guaranteed Legendary or Mythic within %d spins." % GameData.PITY_LIMIT)
	lines.append("Pity is shared by all slots.")
	UiStyle.label(odds_panel, "\n".join(PackedStringArray(lines)), 13, Color(0.95, 0.9, 0.78))
	odds_panel.visible = false

# ================================================================== small widgets
func _chip_label(parent: Node) -> Label:
	var l := UiStyle.label(parent, "", 16, Color.WHITE, 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.03, 0.9)
	sb.skew = Vector2(0.15, 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	return l

## Small toggle chip on parchment (part choices, colour targets, textures).
func _chip(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 32)
	b.add_theme_font_override("font", GameMenu.font())
	b.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		var on: bool = st == "pressed" or st == "hover_pressed"
		sb.bg_color = Color(0.06, 0.05, 0.04) if on else (PAPER_DK.lightened(0.08) if st == "hover" else PAPER_DK)
		sb.set_border_width_all(2)
		sb.border_color = UiStyle.RED if on else Color(0.5, 0.42, 0.28)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	parent.add_child(b)
	return b

func _swatch(color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("color", color)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color.lightened(0.12) if st == "hover" else color
		sb.set_border_width_all(2)
		sb.border_color = INK
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(_apply_color.bind(color))
	return b

## One jutsu line: icon, name, unlock level (greyed out while locked), description.
func _move_row(parent: Node, move_id: String, title: String, lvl: int, have: int, desc: String, col: Color, icon: Texture2D) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var unlocked := have >= lvl
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = icon
	if icon == null:
		var cr := ColorRect.new()
		cr.color = col.darkened(0.2)
		cr.custom_minimum_size = Vector2(40, 40)
		row.add_child(cr)
	else:
		row.add_child(ic)
	if not unlocked:
		row.modulate = Color(1, 1, 1, 0.45)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vb)
	var key := GameData.key_of(move_id) if move_id != "" else ""
	var head := title
	if key != "":
		head += "   [%s]" % key
	UiStyle.label(vb, head, 15, INK)
	var d := UiStyle.label(vb, desc, 12, UiStyle.BODY_TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lv := UiStyle.label(row, "READY" if unlocked else "LV %d" % lvl, 13, UiStyle.GREEN_DK if unlocked else Color(0.6, 0.15, 0.1))
	lv.custom_minimum_size = Vector2(64, 0)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

# ================================================================== preview
func _setup_preview() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.74, 0.7)
	environment.ambient_light_energy = 0.9
	env.environment = environment
	preview_viewport.add_child(env)
	preview_cam = Camera3D.new()
	preview_cam.fov = 40.0
	preview_viewport.add_child(preview_cam)
	preview_cam.current = true
	_update_camera(0.0)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_energy = 1.5
	preview_viewport.add_child(key)
	# glowing ring on the floor in the bloodline's colour
	floor_glow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.02
	floor_glow.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_glow.material_override = mat
	preview_viewport.add_child(floor_glow)
	floor_light = OmniLight3D.new()
	floor_light.position = Vector3(0, 0.4, 0.6)
	floor_light.omni_range = 3.0
	preview_viewport.add_child(floor_light)
	_working = Hero.sanitize_appearance(GameData.character_appearance)
	_replace_preview_model()

func _replace_preview_model() -> void:
	if preview_model != null and is_instance_valid(preview_model):
		if preview_model.get_parent() == preview_viewport:
			preview_viewport.remove_child(preview_model)
		preview_model.queue_free()
	preview_model = Hero.create(_working)
	if preview_model == null:
		preview_model = Fx.make_ninja(Color(0.9, 0.75, 0.55), Color(0.1, 0.1, 0.16))
	preview_model.position = Vector3.ZERO
	preview_model.rotation.y = _yaw
	preview_viewport.add_child(preview_model)
	if preview_model.has_meta("anim_player"):
		Hero.play(preview_model, "idle", true)

func _update_camera(delta: float) -> void:
	var want := 1.0 if _face_view else 0.0
	_cam_blend = want if delta <= 0.0 else lerpf(_cam_blend, want, 1.0 - exp(-delta * 7.0))
	var pos: Vector3 = (CAM_BODY[0] as Vector3).lerp(CAM_FACE[0], _cam_blend)
	var look: Vector3 = (CAM_BODY[1] as Vector3).lerp(CAM_FACE[1], _cam_blend)
	preview_cam.position = pos
	preview_cam.look_at(look, Vector3.UP)

func _update_floor() -> void:
	var a := GameData.equipped
	var col: Color = Bloodline.get_def(a)["color"] if a != "none" else GameData.get_element_color()
	var mat := floor_glow.material_override as StandardMaterial3D
	mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
	floor_light.light_color = col
	floor_light.light_energy = 1.2 if a != "none" else 0.5

func _process(delta: float) -> void:
	if not root.visible:
		return
	_update_camera(delta)
	if preview_model != null and is_instance_valid(preview_model):
		if not _dragging:
			_yaw += delta * 0.3
		preview_model.rotation.y = _yaw

func _input(event: InputEvent) -> void:
	if not root.visible or preview_box == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and preview_box.get_global_rect().has_point(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * 0.012

# ================================================================== open / close
func bind(player: Player) -> void:
	p = player

func _unhandled_input(event: InputEvent) -> void:
	var gm = get_parent().get("gmenu")
	if gm != null and gm.is_open:
		return
	if root.visible and event.is_action_pressed("pause"):
		if odds_panel.visible:
			odds_panel.visible = false
		else:
			toggle()
		get_viewport().set_input_as_handled()

## Opens straight on a tab ("bloodline", "element" or "look").
func open(tab := "bloodline") -> void:
	if not root.visible:
		toggle()
	show_tab(tab)

func toggle() -> void:
	if spinning or auto_running:
		return
	root.visible = not root.visible
	get_tree().paused = root.visible
	odds_panel.visible = false
	confirm_slot = -1
	if root.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_working = Hero.sanitize_appearance(GameData.character_appearance)
		if preview_model != null and is_instance_valid(preview_model):
			Hero.apply_appearance(preview_model, _working)
		_build_look_options()
		show_tab(current_tab)
		_refresh()
	else:
		_save_look()
		if p and not p.is_dead:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		closed.emit()

func show_tab(tab: String) -> void:
	if not pages.has(tab):
		tab = "bloodline"
	current_tab = tab
	for t in pages:
		pages[t].visible = t == tab
		(tab_buttons[t] as Button).set_pressed_no_signal(t == tab)
	_face_view = false

func _save_look() -> void:
	var look := Hero.sanitize_appearance(_working)
	if look != Hero.sanitize_appearance(GameData.character_appearance):
		GameData.character_appearance = look
		GameData.save()

# ================================================================== refresh
func _rarity_color(id: String) -> Color:
	if id == "none":
		return INK
	return Emblem.RARITY_COLORS.get(str(Bloodline.get_def(id)["rarity"]), INK)

## Darker rarity tints that stay readable on the paper.
func _paper_color(id: String) -> Color:
	match str(Bloodline.get_def(id)["rarity"]) if id != "none" else "":
		"Common": return Color(0.32, 0.3, 0.27)
		"Rare": return Color(0.1, 0.3, 0.78)
		"Epic": return Color(0.45, 0.14, 0.72)
		"Legendary": return Color(0.72, 0.48, 0.0)
		"Mythic": return Color(0.78, 0.06, 0.22)
	return INK

func _card_style(active: bool, locked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.7, 0.66, 0.52) if locked else (Color(0.95, 0.9, 0.72) if active else PAPER_DK)
	sb.set_border_width_all(3 if active else 2)
	sb.border_color = Color(0.85, 0.6, 0.1) if active else Color(0.5, 0.42, 0.28)
	sb.set_content_margin_all(8)
	return sb

func _refresh() -> void:
	var busy := spinning or auto_running
	spins_label.text = "%d SPIN%s" % [GameData.spins, "" if GameData.spins == 1 else "S"]
	el_spins_label.text = "%d ELEMENT SPIN%s" % [GameData.element_spins, "" if GameData.element_spins == 1 else "S"]
	for i in GameData.SLOT_COUNT:
		var ui: Dictionary = slot_ui[i]
		var em: Emblem = ui["emblem"]
		var nm: Label = ui["name"]
		var rar: Label = ui["rarity"]
		var spin: Button = ui["spin"]
		var eq: Button = ui["equip"]
		if not GameData.slot_unlocked[i]:
			var cost: int = GameData.SLOT_UNLOCK_COST[i]
			(ui["card"] as PanelContainer).add_theme_stylebox_override("panel", _card_style(false, true))
			em.locked = true
			em.active = false
			nm.text = "LOCKED"
			rar.text = "Costs %d spins" % cost
			rar.add_theme_color_override("font_color", Color(0.65, 0.15, 0.1))
			spin.text = "UNLOCK (%d)" % cost
			spin.disabled = busy or GameData.spins < cost
			eq.visible = false
			continue
		var id := str(GameData.slots[i])
		var d := Bloodline.get_def(id)
		var active: bool = i == GameData.active_slot
		(ui["card"] as PanelContainer).add_theme_stylebox_override("panel", _card_style(active, false))
		em.locked = false
		em.id = id
		em.active = active
		nm.text = "EMPTY" if id == "none" else str(d["name"])
		rar.text = "Spin to awaken" if id == "none" else str(d["rarity"]).to_upper()
		rar.add_theme_color_override("font_color", _paper_color(id))
		spin.text = "SPIN" if confirm_slot != i else "REPLACE?"
		spin.disabled = busy or GameData.spins <= 0
		eq.visible = true
		eq.text = "ACTIVE" if active else "EQUIP"
		eq.disabled = busy or active
	_refresh_bloodline_info()
	auto_pick.disabled = busy
	if auto_running:
		auto_btn.text = "STOP AUTO"
		auto_btn.disabled = false
	else:
		auto_btn.text = "AUTO SPIN SLOT %d" % (GameData.active_slot + 1)
		auto_btn.disabled = spinning or GameData.spins <= 0
	pity_label.text = "Legendary pity %d / %d   ·   lifetime spins %d" % [GameData.pity, GameData.PITY_LIMIT, GameData.total_spins_used]
	_refresh_elements()
	for t in tab_buttons:
		(tab_buttons[t] as Button).disabled = busy and t != current_tab
	done_btn.disabled = busy
	# name plate + floor glow
	var a := GameData.equipped
	plate_name.text = "No Bloodline" if a == "none" else str(Bloodline.get_def(a)["name"]).to_upper()
	plate_name.add_theme_color_override("font_color", Color.WHITE if a == "none" else _rarity_color(a))
	plate_info.text = "%s   ·   %s Style   ·   Shinobi LV %d" % [
		"spin a bloodline" if a == "none" else "%s  ·  LV %d" % [Bloodline.get_def(a)["rarity"], GameData.mastery_level(a)],
		GameData.equipped_element, GameData.level]
	_update_floor()

func _refresh_bloodline_info() -> void:
	var a := GameData.equipped
	var ad := Bloodline.get_def(a)
	_clear(bl_rows)
	if a == "none":
		bl_title.text = "SLOT %d  -  NO BLOODLINE" % (GameData.active_slot + 1)
		bl_title.add_theme_color_override("font_color", INK)
		bl_desc.text = str(ad["desc"]) + "\nEvery bloodline has 3 jutsu and a power-up (C) at LV %d." % Bloodline.MODE_LEVEL
		return
	var lv := GameData.mastery_level(a)
	bl_title.text = "%s   ·   LV %d" % [str(ad["name"]).to_upper(), lv]
	bl_title.add_theme_color_override("font_color", _paper_color(a))
	bl_desc.text = "%s  ·  %s" % [ad["rarity"], ad["desc"]]
	for k in 3:
		var ab := Bloodline.ability(a, k)
		var mid := "bl:%s:%d" % [a, k]
		_move_row(bl_rows, mid, str(ab["name"]), int(ab["lvl"]), lv, str(ab.get("desc", "")), ab["col"], Moves.icon(mid))
	var m := Bloodline.mode(a)
	if not m.is_empty():
		_move_row(bl_rows, "", "POWER-UP: %s   [C]" % m["name"], Bloodline.MODE_LEVEL, lv, str(m.get("desc", "")), m["col"], Moves.mode_icon(a))

func _refresh_elements() -> void:
	var busy := spinning or auto_running
	for e in el_badges:
		var owned := GameData.owned_elements.has(e)
		var ui: Dictionary = el_badges[e]
		(ui["badge"] as ElementBadge).owned = owned
		(ui["badge"] as ElementBadge).active = e == GameData.equipped_element
		(ui["label"] as Label).text = e.to_upper() if owned else "???"
		(ui["button"] as Button).disabled = busy or not owned
		(ui["button"] as Button).tooltip_text = "Equip %s Style" % e if owned else "Not owned yet - spin for it"
	el_spin_btn.text = "SPIN ELEMENT  (%d left)" % GameData.element_spins
	el_spin_btn.disabled = busy or GameData.element_spins <= 0
	var e := GameData.equipped_element
	var elv := GameData.mastery_level("el:" + e)
	el_title.text = "%s STYLE   ·   LV %d" % [e.to_upper(), elv]
	el_title.add_theme_color_override("font_color", GameData.get_element_color(e).darkened(0.35))
	_clear(el_rows)
	for k in ElementData.count(e):
		var ab := ElementData.ability(e, k)
		var mid := "el:%s:%d" % [e, k]
		_move_row(el_rows, mid, str(ab["name"]), int(ab["lvl"]), elv, str(ab.get("desc", "")), ab["col"], Moves.icon(mid))

# ================================================================== appearance
func _build_look_options() -> void:
	_clear(look_box)
	var options := Hero.get_options(preview_model) if preview_model != null and preview_model.has_meta("anim_player") else {}
	for cat in Hero.CATEGORIES:
		var ids: Array = options.get(cat, [])
		if ids.is_empty():
			continue
		UiStyle.label(look_box, str(Hero.CATEGORIES[cat]["label"]), 16, INK)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		look_box.add_child(flow)
		var group := ButtonGroup.new()
		var key: String = Hero.CATEGORIES[cat]["key"]
		for id in ids:
			var b := _chip(flow, Hero.display_name(str(id)))
			b.button_group = group
			b.set_pressed_no_signal(str(_working.get(key, "")) == str(id))
			b.pressed.connect(_on_part_chosen.bind(str(cat), str(id)))
	if options.is_empty():
		UiStyle.label(look_box, "Character model not found - put it in res://assets/character/", 14, Color(0.6, 0.15, 0.1))
	_rebuild_color_targets()

func _rebuild_color_targets() -> void:
	_clear(color_targets)
	var targets: Array = [["hair_color", "Hair"]]
	if preview_model != null and preview_model.has_meta("anim_player"):
		for slot in Hero.get_color_slots(preview_model, str(_working.get("hair_style", ""))):
			targets.append([Hero.COLOR_SLOTS[slot]["key"], Hero.COLOR_SLOTS[slot]["label"]])
	if not targets.any(func(t): return t[0] == _color_target):
		_color_target = "hair_color"
	var group := ButtonGroup.new()
	for t in targets:
		var b := _chip(color_targets, str(t[1]))
		b.button_group = group
		b.set_pressed_no_signal(t[0] == _color_target)
		b.pressed.connect(func():
			_color_target = str(t[0])
			_rebuild_textures()
			_update_color_controls(_current_color()))
	color_targets.visible = targets.size() > 1
	_rebuild_textures()
	_update_color_controls(_current_color())

func _rebuild_textures() -> void:
	_clear(texture_row)
	var slot := Hero.slot_for_key(_color_target)
	var files: Array = Hero.list_slot_textures(slot) if slot != "" else []
	var tkey := str(Hero.COLOR_SLOTS[slot].get("texture_key", "")) if slot != "" else ""
	texture_row.visible = tkey != "" and not files.is_empty()
	if not texture_row.visible:
		return
	var group := ButtonGroup.new()
	var choices: Array = [""]
	choices.append_array(files)
	for f in choices:
		var b := _chip(texture_row, "Default" if f == "" else str(f).get_basename().replace("_", " ").capitalize())
		b.button_group = group
		b.set_pressed_no_signal(str(_working.get(tkey, "")) == str(f))
		b.pressed.connect(func():
			_working[tkey] = str(f)
			_apply_look())

func _current_color() -> Color:
	return Color.html(str(_working.get(_color_target, _working.get("hair_color", "#E6B52E"))))

func _update_color_controls(color: Color) -> void:
	if not hex_edit.has_focus():
		hex_edit.text = "#" + color.to_html(false).to_upper()
	hsv["h"].set_value_no_signal(color.h)
	hsv["s"].set_value_no_signal(color.s)
	hsv["v"].set_value_no_signal(color.v)
	for b in swatch_buttons:
		var on: bool = (b.get_meta("color") as Color).is_equal_approx(color)
		for st in ["normal", "hover", "pressed"]:
			var sb := b.get_theme_stylebox(st) as StyleBoxFlat
			sb.border_color = Color.WHITE if on else INK
			sb.set_border_width_all(4 if on else 2)

func _apply_look() -> void:
	if preview_model != null and is_instance_valid(preview_model) and preview_model.has_meta("anim_player"):
		Hero.apply_appearance(preview_model, _working)

func _on_part_chosen(cat: String, id: String) -> void:
	_working[Hero.CATEGORIES[cat]["key"]] = id
	_apply_look()
	if cat == "hair":
		_rebuild_color_targets()

func _apply_color(color: Color) -> void:
	_working[_color_target] = "#" + color.to_html(false)
	_update_color_controls(color)
	_apply_look()

func _on_hsv_changed(_v: float) -> void:
	_apply_color(Color.from_hsv(hsv["h"].value, hsv["s"].value, hsv["v"].value))

func _on_hex_submitted(text: String) -> void:
	var hex := text.strip_edges()
	if not hex.begins_with("#"):
		hex = "#" + hex
	if Color.html_is_valid(hex):
		_apply_color(Color.html(hex))
	else:
		_update_color_controls(_current_color())

func _randomize_look() -> void:
	if preview_model == null or not preview_model.has_meta("anim_player"):
		return
	_working = Hero.sanitize_appearance(Hero.randomize_look(preview_model))
	_apply_look()
	_build_look_options()

func _reset_look() -> void:
	_working = Hero.DEFAULT_APPEARANCE.duplicate()
	_apply_look()
	_build_look_options()

# ================================================================== bloodline actions
func _on_equip(i: int) -> void:
	if spinning or auto_running:
		return
	if GameData.set_active_slot(i):
		confirm_slot = -1
		if p:
			p.apply_bloodline()
		Sfx.play(self, "poof", -6.0)
		_refresh()

func _on_slot_pressed(i: int) -> void:
	if spinning or auto_running:
		return
	if not GameData.slot_unlocked[i]:
		if GameData.unlock_slot(i):
			Sfx.play(self, "power")
			_show_banner("SLOT %d UNLOCKED!" % (i + 1), Color(1.0, 0.9, 0.5), false)
		_refresh()
		return
	if GameData.spins <= 0:
		_show_banner("NO SPINS LEFT", Color(0.9, 0.3, 0.25), false)
		return
	# Protect good rolls: Epic+ needs a second click within 2.5s.
	if GameData.rarity_rank(str(GameData.slots[i])) >= 2 and confirm_slot != i:
		confirm_slot = i
		confirm_token += 1
		var token := confirm_token
		_refresh()
		await get_tree().create_timer(2.5, true, false, true).timeout
		if confirm_token == token and confirm_slot == i:
			confirm_slot = -1
			_refresh()
		return
	confirm_slot = -1
	await _spin_slot(i, false)

## Rolls slot i with the reel animation. Returns the id won ("" if nothing was spun).
func _spin_slot(i: int, fast: bool) -> String:
	var id := GameData.roll_slot(i)
	if id == "":
		return ""
	var is_new := GameData.last_new
	spinning = true
	_refresh()
	var ui: Dictionary = slot_ui[i]
	var em: Emblem = ui["emblem"]
	var nm: Label = ui["name"]
	var rar: Label = ui["rarity"]
	var pool: Array = Bloodline.DEFS.keys()
	pool.erase("none")
	var steps := 9 if fast else 24
	var last := ""
	for k in steps:
		var rid: String = pool[randi() % pool.size()]
		if rid == last:
			rid = pool[(pool.find(rid) + 1) % pool.size()]
		last = rid
		em.id = rid
		nm.text = str(Bloodline.get_def(rid)["name"])
		rar.text = "..."
		rar.add_theme_color_override("font_color", INK)
		if k % 2 == 0:
			Sfx.play(self, "throw", -16.0)
		var t := (0.025 + k * 0.004) if fast else (0.035 + k * k * 0.0007)
		await get_tree().create_timer(t, true, false, true).timeout
	spinning = false
	if i == GameData.active_slot and p:
		p.apply_bloodline()
	_refresh()
	_reveal(i, id, is_new, fast)
	return id

func _reveal(i: int, id: String, is_new: bool, fast: bool) -> void:
	var ui: Dictionary = slot_ui[i]
	var em: Emblem = ui["emblem"]
	var rar: Label = ui["rarity"]
	var d := Bloodline.get_def(id)
	var rank := GameData.rarity_rank(id)
	var col := _rarity_color(id)
	if is_new:
		rar.text += "  ·  NEW!"
	em.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(em, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "power" if rank >= 2 else "poof", 0.0 if rank >= 2 else -6.0)
	if rank >= 2:
		flash.color = Color(col.r, col.g, col.b, 0.7 if rank >= 4 else (0.55 if rank == 3 else 0.35))
		var ft := create_tween()
		ft.tween_property(flash, "color:a", 0.0, 0.9 if rank >= 4 else (0.6 if rank == 3 else 0.4))
	if rank >= 1 and not fast:
		var head := "MYTHIC!!" if rank >= 4 else ("LEGENDARY!" if rank == 3 else ("EPIC!" if rank == 2 else "RARE"))
		_show_banner("%s\n%s%s" % [head, d["name"], "  (NEW)" if is_new else ""], col, rank >= 3)

func _show_banner(text: String, col: Color, big: bool) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.add_theme_font_size_override("font_size", 50 if big else 36)
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4 if big else 0.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)

func _on_auto() -> void:
	if auto_running:
		auto_stop = true
		return
	if spinning:
		return
	var slot := GameData.active_slot
	var target := GameData.RARITY_ORDER.find(AUTO_TARGETS[auto_pick.selected])
	var current := str(GameData.slots[slot])
	if GameData.rarity_rank(current) >= target:
		_show_banner("Slot %d already has %s\nspin it by hand to replace it" % [slot + 1, Bloodline.get_def(current)["name"]],
			Color(1.0, 0.85, 0.5), false)
		return
	auto_running = true
	auto_stop = false
	confirm_slot = -1
	_refresh()
	var got := ""
	while not auto_stop and GameData.spins > 0:
		got = await _spin_slot(slot, true)
		if got == "" or GameData.rarity_rank(got) >= target:
			break
		await get_tree().create_timer(0.18, true, false, true).timeout
	auto_running = false
	_refresh()
	if got != "" and GameData.rarity_rank(got) >= target:
		var d := Bloodline.get_def(got)
		_show_banner("%s!\n%s" % [str(d["rarity"]).to_upper(), d["name"]], _rarity_color(got), GameData.rarity_rank(got) >= 3)
	elif GameData.spins <= 0:
		_show_banner("OUT OF SPINS", Color(0.9, 0.3, 0.25), false)

# ================================================================== element actions
func _equip_element(e: String) -> void:
	if spinning or auto_running or not GameData.owned_elements.has(e) or GameData.equipped_element == e:
		return
	GameData.equipped_element = e
	GameData.save()
	Sfx.play(self, "poof", -6.0)
	_refresh()

func _on_element_spin() -> void:
	if spinning or auto_running or GameData.element_spins <= 0:
		return
	spinning = true
	_refresh()
	var result := GameData.roll_element()
	for k in 14:
		var e: String = GameData.ELEMENTS[k % GameData.ELEMENTS.size()]
		for x in el_badges:
			(el_badges[x]["badge"] as ElementBadge).active = x == e
		await get_tree().create_timer(0.04 + k * 0.012, true, false, true).timeout
	spinning = false
	_refresh()
	var badge: ElementBadge = el_badges[result]["badge"]
	badge.pivot_offset = badge.size / 2.0
	badge.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(badge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "fire", -4.0)
	_show_banner("%s STYLE!" % result.to_upper(), GameData.get_element_color(result), false)
