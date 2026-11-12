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
	var locked := false:
		set(v):
			locked = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 3.0
		if locked:
			var red := Color(0.78, 0.18, 0.15)
			var dark := Color(0.45, 0.06, 0.05)
			draw_arc(c + Vector2(0, -r * 0.18), r * 0.42, PI, TAU, 24, dark, r * 0.18)
			draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 0.2), Vector2(r * 1.32, r * 1.05)), red)
			draw_circle(c + Vector2(0, r * 0.3), r * 0.22, dark)
			return
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
var sus_swatch: ColorRect
var sus_name: Label
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
var el_slot_ui: Array = []       # one Dictionary per element slot
var el_title: Label
var el_rows: VBoxContainer
var el_auto_pick: OptionButton
var el_auto_btn: Button
# appearance page
var look_box: VBoxContainer
var face_box: VBoxContainer
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
var _turntable := false          # SPIN button: slowly turn the character
var spin_toggle: Button
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
	left.custom_minimum_size = Vector2(960, 0)
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
	# keep the page clear of the frame's posts and rope
	scroll_box.add_theme_constant_override("margin_left", 84)
	scroll_box.add_theme_constant_override("margin_right", 58)
	scroll_box.add_theme_constant_override("margin_top", 52)
	scroll_box.add_theme_constant_override("margin_bottom", 60)
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
	plate.add_theme_stylebox_override("panel", UiStyle.tex_box("plate_dark", [22, 10, 22, 10], [30, 8, 26, 10]))
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
	spin_toggle = UiStyle.text_button(bottom, "SPIN: OFF", 15)
	spin_toggle.pressed.connect(func():
		_turntable = not _turntable
		spin_toggle.text = "SPIN: ON" if _turntable else "SPIN: OFF")
	UiStyle.label(bottom, "or drag to rotate", 13, Color(0.7, 0.68, 0.64), 4)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(fill)
	done_btn = UiStyle.green_button(bottom, "DONE", 20)
	done_btn.custom_minimum_size = Vector2(170, 46)
	done_btn.pressed.connect(toggle)

	_build_odds_panel()
	_build_bag()
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
	# Susanoo colour (Uchiha form 2) - free reroll for now
	var sus_row := HBoxContainer.new()
	sus_row.add_theme_constant_override("separation", 10)
	page.add_child(sus_row)
	UiStyle.label(sus_row, "SUSANOO COLOR  (Uchiha  C + 2)", 16, INK)
	sus_swatch = ColorRect.new()
	sus_swatch.custom_minimum_size = Vector2(44, 28)
	sus_row.add_child(sus_swatch)
	sus_name = UiStyle.label(sus_row, "", 16, INK)
	sus_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var roll := UiStyle.ribbon_button(sus_row, "ROLL  (FREE)", 15)
	roll.custom_minimum_size = Vector2(150, 34)
	roll.alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll.pressed.connect(_roll_susanoo)
	_show_susanoo()
	UiStyle.divider(page)
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 8)
	page.add_child(auto_row)
	auto_pick = _dropdown(auto_row)
	for t in AUTO_TARGETS:
		auto_pick.add_item("Stop at %s%s" % [t, "" if t == "Mythic" else "+"])
	auto_pick.select(AUTO_TARGETS.find("Legendary"))
	auto_pick.add_theme_font_size_override("font_size", 14)
	auto_pick.custom_minimum_size = Vector2(170, 36)
	auto_btn = UiStyle.ribbon_button(auto_row, "", 15)
	auto_btn.custom_minimum_size = Vector2(0, 36)
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_btn.pressed.connect(_on_auto)
	pity_label = UiStyle.label(page, "", 13, Color(0.38, 0.3, 0.18))

func _show_susanoo() -> void:
	var i := Susanoo.my_color_index()
	sus_swatch.color = Susanoo.palette_color(i)
	sus_name.text = Susanoo.NAMES[i]

func _roll_susanoo() -> void:
	Susanoo.reroll_color()
	_show_susanoo()
	var tw := sus_swatch.create_tween()
	sus_swatch.scale = Vector2(1.3, 1.3)
	sus_swatch.pivot_offset = sus_swatch.size * 0.5
	tw.tween_property(sus_swatch, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_slot(parent: Node, i: int) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	card.add_child(hb)
	var em := Emblem.new()
	em.custom_minimum_size = Vector2(58, 58)
	em.pivot_offset = Vector2(29, 29)
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
	spin.add_theme_constant_override("h_separation", 0)
	spin.custom_minimum_size = Vector2(0, 28)
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.pressed.connect(_on_slot_pressed.bind(i))
	var eq := UiStyle.green_button(row, "", 12)
	eq.custom_minimum_size = Vector2(54, 28)
	eq.pressed.connect(_on_equip.bind(i))
	var bag := UiStyle.green_button(row, "BAG", 12)
	bag.custom_minimum_size = Vector2(42, 28)
	bag.tooltip_text = "Bloodline Bag: put a bloodline you already have in this slot"
	bag.pressed.connect(_open_bag.bind("bloodline", i))
	return {"card": card, "emblem": em, "name": nm, "rarity": rar, "spin": spin, "equip": eq, "bag": bag}

func _build_element_page(page: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	el_slot_ui.resize(GameData.SLOT_COUNT)
	for i in GameData.SLOT_COUNT:
		el_slot_ui[i] = _build_el_slot(grid, i)
	UiStyle.label(page, "Jutsu of every element in your slots can go on your hotbar (M > Element).", 12, Color(0.42, 0.36, 0.26))
	UiStyle.divider(page)
	el_title = UiStyle.label(page, "", 22, INK)
	el_rows = VBoxContainer.new()
	el_rows.add_theme_constant_override("separation", 4)
	page.add_child(el_rows)
	UiStyle.divider(page)
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 8)
	page.add_child(auto_row)
	el_auto_pick = _dropdown(auto_row)
	for e in GameData.ELEMENTS:
		el_auto_pick.add_item("Stop at %s" % e)
	el_auto_pick.add_theme_font_size_override("font_size", 14)
	el_auto_pick.custom_minimum_size = Vector2(170, 36)
	el_auto_btn = UiStyle.ribbon_button(auto_row, "", 15)
	el_auto_btn.custom_minimum_size = Vector2(0, 36)
	el_auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	el_auto_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	el_auto_btn.pressed.connect(_on_el_auto)

func _build_el_slot(parent: Node, i: int) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	var badge := ElementBadge.new()
	badge.custom_minimum_size = Vector2(70, 70)
	badge.pivot_offset = Vector2(35, 35)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(badge)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	UiStyle.label(vb, "ELEMENT SLOT %d" % (i + 1), 11, Color(0.42, 0.36, 0.26))
	var nm := UiStyle.label(vb, "", 18, INK)
	var sub := UiStyle.label(vb, "", 12, INK)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	var spin := UiStyle.ribbon_button(row, "", 13)
	spin.custom_minimum_size = Vector2(0, 28)
	spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.pressed.connect(_on_el_slot_pressed.bind(i))
	var eq := UiStyle.green_button(row, "", 12)
	eq.custom_minimum_size = Vector2(54, 28)
	eq.pressed.connect(_on_el_equip.bind(i))
	var bag := UiStyle.green_button(row, "BAG", 12)
	bag.custom_minimum_size = Vector2(42, 28)
	bag.tooltip_text = "Element Bag: put an element you already have in this slot"
	bag.pressed.connect(_open_bag.bind("element", i))
	return {"card": card, "badge": badge, "name": nm, "sub": sub, "spin": spin, "equip": eq, "bag": bag}

func _build_look_page(page: VBoxContainer) -> void:
	look_box = VBoxContainer.new()   # one row of choices per model part (filled in _build_look_options)
	look_box.add_theme_constant_override("separation", 6)
	page.add_child(look_box)
	UiStyle.divider(page)
	UiStyle.label(page, "FACE", 16, INK)
	face_box = VBoxContainer.new()   # body type + one slider per face shape key (_build_face)
	face_box.add_theme_constant_override("separation", 4)
	page.add_child(face_box)
	UiStyle.divider(page)
	UiStyle.label(page, "COLOUR  -  pick what to colour", 16, INK)
	color_targets = HFlowContainer.new()
	color_targets.add_theme_constant_override("h_separation", 5)
	page.add_child(color_targets)
	var grid := GridContainer.new()
	grid.columns = 16
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	page.add_child(grid)
	swatch_buttons.clear()
	for hex in HAIR_PRESETS:
		var sw := _swatch(Color.html(str(hex)))
		grid.add_child(sw)
		swatch_buttons.append(sw)
	for ch in [["h", "Hue"], ["s", "Saturation"], ["v", "Brightness"]]:
		var r := HBoxContainer.new()
		page.add_child(r)
		var l := UiStyle.label(r, ch[1], 13, UiStyle.BODY_TEXT)
		l.custom_minimum_size = Vector2(110, 0)
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

# ================================================================== bags
var bag_panel: Control
var bag_title: Label
var bag_list: VBoxContainer
var bag_kind := "bloodline"
var bag_slot := 0

## Bloodline / Element Bag (Shindo Life style): a scroll on the right listing everything you've
## ever rolled. Click one to put it in the slot you opened the bag from.
func _build_bag() -> void:
	bag_panel = Control.new()
	root.add_child(bag_panel)
	bag_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	bag_panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_bag())
	var holder := VBoxContainer.new()
	bag_panel.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	holder.offset_left = -420
	holder.offset_right = -60
	holder.offset_top = 70
	holder.offset_bottom = -60
	var box := UiStyle.scroll(holder, Vector2(360, 0))
	box.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("margin_left", 14)
	box.add_theme_constant_override("margin_right", 10)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	box.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var tl := Label.new()   # brush-stroke title like the reference
	tl.add_theme_font_override("font", GameMenu.font())
	tl.add_theme_font_size_override("font_size", 20)
	tl.add_theme_color_override("font_color", INK)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.98, 0.97, 0.93)
	tsb.skew = Vector2(0.1, 0)
	tsb.content_margin_left = 14
	tsb.content_margin_right = 14
	tl.add_theme_stylebox_override("normal", tsb)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	bag_title = tl
	var x := UiStyle.text_button(top, "X", 18)
	x.pressed.connect(_close_bag)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_list = VBoxContainer.new()
	bag_list.add_theme_constant_override("separation", 0)
	bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(bag_list)
	bag_panel.visible = false

func _open_bag(kind: String, slot: int) -> void:
	if spinning or auto_running:
		return
	bag_kind = kind
	bag_slot = slot
	bag_title.text = ("BLOODLINE BAG" if kind == "bloodline" else "ELEMENT BAG") + "  ·  SLOT %d" % (slot + 1)
	_fill_bag()
	bag_panel.visible = true

func _close_bag() -> void:
	bag_panel.visible = false

func _fill_bag() -> void:
	_clear(bag_list)
	var ids: Array = []
	if bag_kind == "bloodline":
		for id in GameData.owned:
			if str(id) != "none" and Bloodline.DEFS.has(str(id)):
				ids.append(str(id))
		ids.sort_custom(func(a, b) -> bool:   # best rarity first, then name
			var ra := GameData.rarity_rank(a)
			var rb := GameData.rarity_rank(b)
			return ra > rb if ra != rb else str(a) < str(b))
	else:
		for e in GameData.ELEMENTS:
			if GameData.el_bag.has(e):
				ids.append(e)
	if ids.is_empty():
		UiStyle.label(bag_list, "Nothing yet - spin to fill your bag!", 15, UiStyle.BODY_TEXT)
		return
	for id in ids:
		_bag_row(str(id))

func _bag_row(id: String) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 74)
	btn.focus_mode = Control.FOCUS_NONE
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(1, 1, 1, 0.25)
	btn.add_theme_stylebox_override("hover", hsb)
	bag_list.add_child(btn)
	var in_slot := -1
	var name := ""
	var tag := ""
	var lv := 0
	if bag_kind == "bloodline":
		var em := Emblem.new()
		em.id = id
		em.position = Vector2(4, 8)
		em.size = Vector2(58, 58)
		btn.add_child(em)
		var d := Bloodline.get_def(id)
		name = str(d["name"])
		tag = str(d["rarity"])
		lv = GameData.mastery_level(id)
		in_slot = GameData.slots.find(id)
	else:
		var bd := ElementBadge.new()
		bd.element = id
		bd.position = Vector2(4, 8)
		bd.size = Vector2(58, 58)
		btn.add_child(bd)
		name = id
		tag = "Element"
		lv = GameData.mastery_level("el:" + id)
		in_slot = GameData.el_slots.find(id)
	var t := UiStyle.label(btn, "[%s][%s]" % [name, tag], 16, INK)
	t.position = Vector2(70, 10)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = INK
	line.position = Vector2(70, 34)
	line.size = Vector2(240, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(line)
	var sub := UiStyle.label(btn, "[Lvl. %d]%s" % [lv, "" if in_slot < 0 else "   in slot %d" % (in_slot + 1)], 15,
		Color(0.55, 0.5, 0.42) if in_slot < 0 else Color(0.1, 0.45, 0.12))
	sub.position = Vector2(72, 40)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep := ColorRect.new()
	sep.color = INK
	sep.custom_minimum_size = Vector2(0, 2)
	bag_list.add_child(sep)
	if in_slot == bag_slot:
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.55)
	btn.pressed.connect(_bag_pick.bind(id))

func _bag_pick(id: String) -> void:
	var ok := GameData.place_bloodline(bag_slot, id) if bag_kind == "bloodline" else GameData.place_element(bag_slot, id)
	if not ok:
		return
	if bag_kind == "bloodline" and p:
		p.apply_bloodline()
	Sfx.play(self, "poof", -6.0)
	_close_bag()
	_refresh()
	var badge: Control = (slot_ui if bag_kind == "bloodline" else el_slot_ui)[bag_slot]["emblem" if bag_kind == "bloodline" else "badge"]
	badge.pivot_offset = badge.size / 2.0
	badge.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	l.add_theme_stylebox_override("normal", UiStyle.tex_box("plate_dark", [22, 10, 22, 10], [22, 6, 22, 6]))
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

## Parchment dropdown (hair / shirt / pants lists grow as meshes are added to the model).
func _dropdown(parent: Node) -> OptionButton:
	var dd := OptionButton.new()
	dd.custom_minimum_size = Vector2(0, 38)
	dd.focus_mode = Control.FOCUS_NONE
	dd.fit_to_longest_item = false
	dd.add_theme_font_override("font", GameMenu.font())
	dd.add_theme_font_size_override("font_size", 16)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAPER_DK.lightened(0.1) if st.begins_with("hover") else PAPER_DK
		sb.set_border_width_all(2)
		sb.border_color = UiStyle.RED if st.begins_with("hover") or st == "pressed" else Color(0.5, 0.42, 0.28)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		dd.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		dd.add_theme_color_override(c, INK)
	dd.add_theme_color_override("arrow_color", INK)   # (ignored on older Godot)
	var pop := dd.get_popup()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.05, 0.04, 0.97)
	psb.set_border_width_all(2)
	psb.border_color = Color(0.75, 0.62, 0.3)
	psb.set_content_margin_all(6)
	pop.add_theme_stylebox_override("panel", psb)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.45, 0.07, 0.05)
	pop.add_theme_stylebox_override("hover", hsb)
	pop.add_theme_font_override("font", GameMenu.font())
	pop.add_theme_font_size_override("font_size", 16)
	pop.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	pop.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.45))
	parent.add_child(dd)
	return dd

func _swatch(color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(34, 26)
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
	if color_targets != null:
		_rebuild_color_targets()   # some targets depend on the model (e.g. the colourable cloak)

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
		if _turntable and not _dragging:
			_yaw += delta * 0.5
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
		if bag_panel != null and bag_panel.visible:
			_close_bag()
		elif odds_panel.visible:
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

static var _cards := {}
## Torn-paper slot card: bright when it's the selected slot, dimmer otherwise, grey when locked.
func _card_style(active: bool, locked: bool) -> StyleBoxTexture:
	var key := 2 if locked else (1 if active else 0)
	if not _cards.has(key):
		var tint := Color(0.62, 0.6, 0.58) if locked else (Color(1.08, 1.04, 0.92) if active else Color(0.86, 0.82, 0.76))
		_cards[key] = UiStyle.tex_box("paper_card", [24, 18, 24, 18], [16, 12, 16, 12], tint)
	return _cards[key]

func _refresh() -> void:
	var busy := spinning or auto_running
	spins_label.text = "%d SPIN%s" % [GameData.spins, "" if GameData.spins == 1 else "S"]
	el_spins_label.visible = false   # one spin currency now
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
			(ui["bag"] as Button).visible = false
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
		eq.text = "MAIN" if active else "EQUIP"
		eq.disabled = busy or active
		eq.tooltip_text = "Use this bloodline's transformation (C) and stats. Jutsu from all your slots work anyway."
		(ui["bag"] as Button).visible = true
		(ui["bag"] as Button).disabled = busy
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
	# Mix & match: the jutsu of your other slotted bloodlines work too (bind them in M > Bloodline).
	var shown := [a]
	for i in GameData.SLOT_COUNT:
		var b := str(GameData.slots[i])
		if not GameData.slot_unlocked[i] or b == "none" or shown.has(b):
			continue
		shown.append(b)
		var lv2 := GameData.mastery_level(b)
		UiStyle.label(bl_rows, "+ %s JUTSU   ·   LV %d   (slot %d)" % [str(Bloodline.get_def(b)["name"]).to_upper(), lv2, i + 1], 16, Color(0.15, 0.35, 0.7))
		for k in 3:
			var ab2 := Bloodline.ability(b, k)
			var mid2 := "bl:%s:%d" % [b, k]
			_move_row(bl_rows, mid2, str(ab2["name"]), int(ab2["lvl"]), lv2, str(ab2.get("desc", "")), ab2["col"], Moves.icon(mid2))
	if shown.size() > 1:
		UiStyle.label(bl_rows, "Mix & match: bind any of these in M > Bloodline. EQUIP picks your transformation (C).", 12, Color(0.42, 0.36, 0.26)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _refresh_elements() -> void:
	var busy := spinning or auto_running
	for i in GameData.SLOT_COUNT:
		var ui: Dictionary = el_slot_ui[i]
		var badge: ElementBadge = ui["badge"]
		var nm: Label = ui["name"]
		var sub: Label = ui["sub"]
		var spin: Button = ui["spin"]
		var eq: Button = ui["equip"]
		if not GameData.el_slot_unlocked[i]:
			var cost: int = GameData.EL_SLOT_UNLOCK_COST[i]
			(ui["card"] as PanelContainer).add_theme_stylebox_override("panel", _card_style(false, true))
			badge.locked = true
			badge.active = false
			nm.text = "LOCKED"
			sub.text = "Costs %d spins" % cost
			sub.add_theme_color_override("font_color", Color(0.65, 0.15, 0.1))
			spin.text = "UNLOCK (%d)" % cost
			spin.disabled = busy or GameData.spins < cost
			eq.visible = false
			(ui["bag"] as Button).visible = false
			continue
		var e := str(GameData.el_slots[i])
		var empty := e == "none"
		var active: bool = i == GameData.active_el_slot
		(ui["card"] as PanelContainer).add_theme_stylebox_override("panel", _card_style(active, false))
		badge.locked = false
		badge.owned = not empty
		badge.element = e if not empty else "?"
		badge.active = active
		nm.text = "EMPTY" if empty else "%s Style" % e
		sub.text = "Spin to awaken" if empty else "LV %d" % GameData.mastery_level("el:" + e)
		sub.add_theme_color_override("font_color", INK if empty else GameData.get_element_color(e).darkened(0.45))
		spin.text = "SPIN"
		spin.disabled = busy or GameData.spins <= 0
		eq.visible = not empty
		eq.text = "ACTIVE" if active else "EQUIP"
		eq.disabled = busy or active
		(ui["bag"] as Button).visible = true
		(ui["bag"] as Button).disabled = busy
	var e := GameData.equipped_element
	var elv := GameData.mastery_level("el:" + e)
	el_title.text = "%s STYLE   ·   LV %d" % [e.to_upper(), elv]
	el_title.add_theme_color_override("font_color", GameData.get_element_color(e).darkened(0.35))
	_clear(el_rows)
	for k in ElementData.count(e):
		var ab := ElementData.ability(e, k)
		var mid := "el:%s:%d" % [e, k]
		_move_row(el_rows, mid, str(ab["name"]), int(ab["lvl"]), elv, str(ab.get("desc", "")), ab["col"], Moves.icon(mid))
	el_auto_pick.disabled = busy
	if auto_running and current_tab == "element":
		el_auto_btn.text = "STOP AUTO"
		el_auto_btn.disabled = false
	else:
		el_auto_btn.text = "AUTO SPIN ELEMENT SLOT %d" % (GameData.active_el_slot + 1)
		el_auto_btn.disabled = busy or GameData.spins <= 0

# ================================================================== appearance
func _build_look_options() -> void:
	_clear(look_box)
	var options := Hero.get_options(preview_model) if preview_model != null and preview_model.has_meta("anim_player") else {}
	for cat in Hero.CATEGORIES:
		var ids: Array = options.get(cat, [])
		if ids.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		look_box.add_child(row)
		# no side label: the choices already read "Hair 1", "Shirt 5", "Pants 1"
		var key: String = Hero.CATEGORIES[cat]["key"]
		var dd := _dropdown(row)
		dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for n in ids.size():
			var colourable := Hero.color_copy_for(preview_model, str(ids[n])) != ""
			dd.add_item(Hero.display_name(str(ids[n])) + ("  (C)" if colourable else ""), n)   # (C) = colourable
			dd.set_item_metadata(n, str(ids[n]))
			if str(_working.get(key, "")) == str(ids[n]):
				dd.select(n)
		dd.item_selected.connect(func(n: int): _on_part_chosen(str(cat), str(dd.get_item_metadata(n))))
	if options.is_empty():
		UiStyle.label(look_box, "Character model not found - put it in res://assets/character/", 14, Color(0.6, 0.15, 0.1))
	_build_face()
	_rebuild_color_targets()

## Face customisation: Male / Female, then a slider for every shape key on the face model.
## (Placeholder sliders until the face model with shape keys is in.)
func _build_face() -> void:
	if face_box == null:
		return
	_clear(face_box)
	var sex_row := HBoxContainer.new()
	sex_row.add_theme_constant_override("separation", 6)
	face_box.add_child(sex_row)
	var group := ButtonGroup.new()
	for sx in [["male", "Male"], ["female", "Female"]]:
		var b := _chip(sex_row, str(sx[1]))
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(str(_working.get("sex", "male")) == sx[0])
		b.pressed.connect(func():
			_working["sex"] = str(sx[0])
			_apply_look())
	var names: Array = Hero.face_shape_names(preview_model)
	var placeholder := names.is_empty()
	if placeholder:
		names = Hero.FACE_PLACEHOLDER
		UiStyle.label(face_box, "Preview - the face model with shape keys isn't in yet", 12, Color(0.55, 0.4, 0.25))
	if not (_working.get("face") is Dictionary):
		_working["face"] = {}
	var face: Dictionary = _working["face"]
	# each shape key is either fully on or off (0 / 1): a toggle per key
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	face_box.add_child(flow)
	var groups := Hero.face_groups(names)   # _L / _R keys share one toggle (symmetric face)
	for g in groups:
		var keys: Array = groups[g]
		var b := _chip(flow, str(g).replace("_", " ").replace(".", " ").capitalize())
		b.set_pressed_no_signal(keys.any(func(k): return float(face.get(k, 0.0)) >= 0.5))
		b.disabled = placeholder
		b.toggled.connect(func(on: bool):
			for k in keys:
				(_working["face"] as Dictionary)[str(k)] = 1.0 if on else 0.0
			_apply_look())
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	face_box.add_child(acts)
	var rnd := _chip(acts, "Random face")
	rnd.toggle_mode = false
	rnd.disabled = placeholder
	rnd.pressed.connect(func():
		var f := {}
		var gr := Hero.face_groups(Hero.face_shape_names(preview_model))
		for g in gr:
			var on := 1.0 if randf() < 0.35 else 0.0
			for k in gr[g]:
				f[k] = on
		_working["face"] = f
		_apply_look()
		_build_face())
	var rst := _chip(acts, "Reset face")
	rst.toggle_mode = false
	rst.pressed.connect(func():
		_working["face"] = {}
		_apply_look()
		_build_face())

func _rebuild_color_targets() -> void:
	_clear(color_targets)
	var targets: Array = [["hair_color", "Hair"]]
	if preview_model != null and Hero.has_skin(preview_model):
		targets.append(["skin_color", "Skin"])
	if preview_model != null and Hero._eye_base_texture(preview_model) != null:
		targets.append(["eye_color", "Eyes"])
	if preview_model != null and preview_model.has_meta("anim_player"):
		for slot in Hero.get_color_slots(preview_model, str(_working.get("hair_style", ""))):
			targets.append([Hero.COLOR_SLOTS[slot]["key"], Hero.COLOR_SLOTS[slot]["label"]])
		var opts := Hero.get_options(preview_model)
		for cat in Hero.CLOTH_COLORS:
			if (opts.get(cat, []) as Array).is_empty():
				continue
			var key: String = Hero.CATEGORIES[cat]["key"]
			var copy := Hero.color_copy_for(preview_model, str(_working.get(key, "")))
			if copy != "":   # colourable copy: its own two colours
				var d: Dictionary = Hero.COLOR_COPIES[copy]
				targets.append([d["keys"][0], d["labels"][0]])
				targets.append([d["keys"][1], d["labels"][1]])
			# other clothes aren't colourable: no colour button for them
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
	if _color_target == "skin_color" or _color_target == "eye_color":   # presets + back to the model's own
		texture_row.visible = true
		var key := _color_target
		var orig_skin := _chip(texture_row, "Original")
		orig_skin.toggle_mode = false
		orig_skin.pressed.connect(func():
			_working[key] = ""
			_update_color_controls(_current_color())
			_apply_look())
		for tone in (Hero.SKIN_TONES if key == "skin_color" else Hero.EYE_TONES):
			var sw := _swatch(Color.html(tone))
			sw.custom_minimum_size = Vector2(34, 28)
			texture_row.add_child(sw)
		return
	if Hero.CLOTH_COLORS.values().has(_color_target):   # clothes: a way back to the model's own colours
		texture_row.visible = true
		var orig := _chip(texture_row, "Original colours")
		orig.toggle_mode = false
		orig.pressed.connect(func(): _apply_color(Color.WHITE))
		return
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
	if _color_target == "skin_color" and str(_working.get("skin_color", "")) == "":
		return Hero.skin_original(preview_model)
	if _color_target == "eye_color" and str(_working.get("eye_color", "")) == "":
		return Color(0.8, 0.8, 0.8)   # the painted grey iris
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
	if cat == "hair" or cat == "shirt" or cat == "pants":   # headband / colourable copy targets come and go
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
func _on_el_equip(i: int) -> void:
	if spinning or auto_running:
		return
	if GameData.set_active_el_slot(i):
		Sfx.play(self, "poof", -6.0)
		_refresh()

func _on_el_slot_pressed(i: int) -> void:
	if spinning or auto_running:
		return
	if not GameData.el_slot_unlocked[i]:
		if GameData.unlock_el_slot(i):
			Sfx.play(self, "power")
			_show_banner("ELEMENT SLOT %d UNLOCKED!" % (i + 1), Color(1.0, 0.9, 0.5), false)
		_refresh()
		return
	if GameData.spins <= 0:
		_show_banner("NO SPINS LEFT", Color(0.9, 0.3, 0.25), false)
		return
	await _spin_el_slot(i, false)

## Rolls element slot i with a short reel. Returns the element won ("" if nothing was spun).
func _spin_el_slot(i: int, fast: bool) -> String:
	var result := GameData.roll_el_slot(i)
	if result == "":
		return ""
	var is_new := GameData.last_el_new
	spinning = true
	_refresh()
	var ui: Dictionary = el_slot_ui[i]
	var badge: ElementBadge = ui["badge"]
	var nm: Label = ui["name"]
	badge.owned = true
	var steps := 8 if fast else 18
	for k in steps:
		var e: String = GameData.ELEMENTS[(k + randi() % 2) % GameData.ELEMENTS.size()]
		badge.element = e
		nm.text = "%s Style" % e
		if k % 2 == 0:
			Sfx.play(self, "throw", -16.0)
		var t := (0.03 + k * 0.004) if fast else (0.035 + k * k * 0.0011)
		await get_tree().create_timer(t, true, false, true).timeout
	spinning = false
	_refresh()
	badge.scale = Vector2(1.35, 1.35)
	create_tween().tween_property(badge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "fire", -4.0)
	if not fast:
		_show_banner("%s STYLE!%s" % [result.to_upper(), "\n(NEW)" if is_new else ""], GameData.get_element_color(result), false)
	return result

func _on_el_auto() -> void:
	if auto_running:
		auto_stop = true
		return
	if spinning:
		return
	var slot := GameData.active_el_slot
	var want: String = GameData.ELEMENTS[el_auto_pick.selected]
	if str(GameData.el_slots[slot]) == want:
		_show_banner("Slot %d already has %s" % [slot + 1, want], Color(1.0, 0.85, 0.5), false)
		return
	auto_running = true
	auto_stop = false
	_refresh()
	var got := ""
	while not auto_stop and GameData.spins > 0:
		got = await _spin_el_slot(slot, true)
		if got == "" or got == want:
			break
		await get_tree().create_timer(0.18, true, false, true).timeout
	auto_running = false
	_refresh()
	if got == want:
		_show_banner("%s STYLE!" % want.to_upper(), GameData.get_element_color(want), true)
	elif GameData.spins <= 0:
		_show_banner("OUT OF SPINS", Color(0.9, 0.3, 0.25), false)
