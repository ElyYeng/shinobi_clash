extends Node
## Small attachable picker for binding Shadow Clone Jutsu to any hotbar key.
## Add shadow_clone_equip_ui.tscn as a child of main.tscn, then press J in-game.

const MOVE_ID: String = "base:clones"
const HOTBAR_KEYS: Array[String] = ["R", "T", "Y", "F", "G", "H", "V", "B", "N"]

var _canvas: CanvasLayer
var _root: Control
var _current_label: Label
var _is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_picker()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_J:
		if _is_open:
			_close_picker()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_open_picker()
		get_viewport().set_input_as_handled()
	elif _is_open and key_event.keycode == KEY_ESCAPE:
		_close_picker()
		get_viewport().set_input_as_handled()

func _build_picker() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "ShadowCloneEquipLayer"
	_canvas.layer = 30
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	_root = Control.new()
	_root.name = "PickerRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470.0, 350.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.87, 0.83, 0.66, 0.98)
	panel_style.border_color = Color(0.28, 0.20, 0.10)
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 22)
	margins.add_theme_constant_override("margin_right", 22)
	margins.add_theme_constant_override("margin_top", 18)
	margins.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)

	var title := Label.new()
	title.text = "SHADOW CLONE JUTSU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.12, 0.07, 0.04))
	column.add_child(title)

	var hint := Label.new()
	hint.text = "Choose the hotbar key you want to use. The selected key's current move will be replaced."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.22, 0.16, 0.10))
	column.add_child(hint)

	_current_label = Label.new()
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_label.add_theme_font_size_override("font_size", 18)
	_current_label.add_theme_color_override("font_color", Color(0.45, 0.05, 0.04))
	column.add_child(_current_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)

	for hotkey in HOTBAR_KEYS:
		var button := Button.new()
		button.text = hotkey
		button.custom_minimum_size = Vector2(120.0, 42.0)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_assign_key.bind(hotkey))
		grid.add_child(button)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)

	var unbind_button := Button.new()
	unbind_button.text = "UNBIND"
	unbind_button.custom_minimum_size = Vector2(130.0, 36.0)
	unbind_button.pressed.connect(_unbind_move)
	footer.add_child(unbind_button)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(130.0, 36.0)
	close_button.pressed.connect(_close_picker)
	footer.add_child(close_button)

	_root.visible = false

func _open_picker() -> void:
	_refresh_current_binding()
	_root.visible = true
	_is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_picker() -> void:
	if not _is_open:
		return
	_root.visible = false
	_is_open = false
	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_current_binding() -> void:
	var current_key: String = GameData.key_of(MOVE_ID)
	_current_label.text = "CURRENT KEY: %s" % (current_key if current_key != "" else "NOT EQUIPPED")

func _assign_key(hotkey: String) -> void:
	GameData.bind_move(hotkey, MOVE_ID)
	_refresh_current_binding()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player._toast("Shadow Clone Jutsu equipped to [%s]" % hotkey)
	_close_picker()

func _unbind_move() -> void:
	GameData.unbind_move(MOVE_ID)
	_refresh_current_binding()
