class_name EndScreen
extends Control
## Defeat / victory screen (UI kit): a big ribbon title that drops in, a row of stat plates and
## RETRY / CUSTOMIZE / MAIN MENU buttons. Enter still retries (main.gd).

signal retry
signal spectate

var _title: Label
var _ribbon: Panel
var _stats: HBoxContainer
var _sub: Label
var _box: VBoxContainer
var _shown := false
var _spec_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.custom_minimum_size = Vector2(760, 0)

	# title on a torn red ribbon
	_ribbon = Panel.new()
	_ribbon.custom_minimum_size = Vector2(760, 128)
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_ribbon)
	_title = UiStyle.label(_ribbon, "", 86, Color.WHITE, 16)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("shadow_offset_x", 5)
	_title.add_theme_constant_override("shadow_offset_y", 6)
	_sub = UiStyle.label(_box, "", 22, Color(0.95, 0.88, 0.78), 6)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_stats = HBoxContainer.new()
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats.add_theme_constant_override("separation", 14)
	_box.add_child(_stats)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_box.add_child(gap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_box.add_child(row)
	var again := UiStyle.green_button(row, "RETRY  [Enter]", 22)
	again.custom_minimum_size = Vector2(230, 54)
	again.pressed.connect(func() -> void: retry.emit())
	_spec_btn = UiStyle.green_button(row, "SPECTATE", 22)
	_spec_btn.custom_minimum_size = Vector2(190, 54)
	_dark(_spec_btn)
	_spec_btn.visible = false
	_spec_btn.pressed.connect(func() -> void: spectate.emit())
	var spin := UiStyle.green_button(row, "CUSTOMIZE", 22)
	spin.custom_minimum_size = Vector2(200, 54)
	_dark(spin)
	spin.pressed.connect(func() -> void:
		GameData.open_customize = true
		_to_title())
	var menu := UiStyle.green_button(row, "MAIN MENU", 22)
	menu.custom_minimum_size = Vector2(200, 54)
	_dark(menu)
	menu.pressed.connect(_to_title)

## Secondary buttons: the dark riveted plate, red on hover.
func _dark(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UiStyle.tex_box("btn_dark", [24, 0, 24, 0], [14, 4, 14, 4]))
	b.add_theme_stylebox_override("focus", UiStyle.tex_box("btn_red", [24, 0, 24, 0], [14, 4, 14, 4]))
	b.add_theme_stylebox_override("hover", UiStyle.tex_box("btn_red", [24, 0, 24, 0], [14, 4, 14, 4]))

## Shows the screen (once). `stats` = [[label, value], ...]
func show_end(title: String, victory: bool, sub: String, stats: Array, can_spectate := false) -> void:
	if _shown:
		return
	_shown = true
	_spec_btn.visible = can_spectate
	_title.text = title
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35) if victory else Color(1.0, 0.95, 0.9))
	_ribbon.add_theme_stylebox_override("panel", UiStyle.tex_box("banner_red", [80, 0, 80, 0], [0, 0, 0, 0],
		Color(1.0, 0.85, 0.5) if victory else Color.WHITE))
	_sub.text = sub
	for c in _stats.get_children():
		c.queue_free()
	for s in stats:
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", UiStyle.tex_box("plate_dark", [22, 10, 22, 10], [26, 8, 26, 10]))
		plate.custom_minimum_size = Vector2(170, 0)
		_stats.add_child(plate)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		plate.add_child(v)
		var k := UiStyle.label(v, str(s[0]), 15, Color(0.75, 0.7, 0.62), 4)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var val := UiStyle.label(v, str(s[1]), 32, Color.WHITE, 8)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = true
	# drop in: title slams down, the rest fades up
	_box.modulate.a = 0.0
	_ribbon.pivot_offset = _ribbon.custom_minimum_size * 0.5
	_ribbon.scale = Vector2(1.6, 1.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_box, "modulate:a", 1.0, 0.35)
	tw.tween_property(_ribbon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "thud", 2.0)

func is_shown() -> bool:
	return _shown

func hide_end() -> void:
	_shown = false
	visible = false

func _to_title() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if NetworkSession.is_active():
		NetworkSession.disconnect_session()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
