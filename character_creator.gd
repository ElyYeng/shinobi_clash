extends CanvasLayer
## Character creator for the main character (the Mixamo rig in res://assets/character).
##
## The option buttons are built from the meshes that exist INSIDE the model
## (hair1 / hair2, shirt1 / shirt2, pants1 / pants2 ...), so a new mesh named "hair3"
## in the GLB shows up here without touching this script. Hair colour = swatches + a
## custom colour picker. Everything updates the 3D preview live; SAVE OUTFIT stores it.

const PANEL_BG := Color(0.83, 0.79, 0.65)
const INK := Color(0.13, 0.09, 0.06)
const HAIR_PRESETS := [
	"#14141A", "#3B2417", "#6B4226", "#A86B32", "#E6B52E", "#F2E7B8", "#F4F4F4", "#8A8F99",
	"#C8372D", "#E8702A", "#E85DA8", "#8B4DD6", "#2F6FD6", "#3FB6D8", "#35A55B", "#A6D63B",
]
const CAM_BODY_POS := Vector3(0.0, 1.1, 4.3)
const CAM_BODY_LOOK := Vector3(0.0, 0.9, 0.0)
const CAM_HEAD_POS := Vector3(0.0, 1.62, 1.55)
const CAM_HEAD_LOOK := Vector3(0.0, 1.6, 0.0)

var _working: Dictionary = {}
var _preview_world: Node3D
var _preview_model: Node3D
var _preview_camera: Camera3D
var _preview_panel: Panel
var _preview_status: Label
var _options_box: VBoxContainer
var _color_swatch: ColorRect
var _color_picker: ColorPickerButton
var _part_buttons := {}          # category -> {id: Button}
var _yaw := PI                   # PI = facing the camera
var _dragging := false
var _zoom_head := false
var _cam_blend := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_working = Hero.sanitize_appearance(GameData.character_appearance)
	_build_ui()
	_spawn_preview()
	_build_option_rows()
	_sync_controls()


# ------------------------------------------------------------------------- UI

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.018, 0.025, 0.90)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := Vector2(minf(980.0, viewport_size.x - 32.0), minf(640.0, viewport_size.y - 32.0))
	var panel := Panel.new()
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = Color(0.12, 0.09, 0.07)
	panel_style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var title := Label.new()
	title.text = "CHARACTER CUSTOMIZATION"
	title.position = Vector2(20, 12)
	title.size = Vector2(panel_size.x - 40, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", INK)
	panel.add_child(title)

	# ---- left column (scrolls if the model has many options)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 62)
	scroll.size = Vector2(350, panel_size.y - 138)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 330
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	column.add_child(_options_box)

	_add_label(column, "HAIR COLOR", 17)
	_color_swatch = ColorRect.new()
	_color_swatch.custom_minimum_size = Vector2(0, 26)
	column.add_child(_color_swatch)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for hex in HAIR_PRESETS:
		grid.add_child(_make_swatch(Color.html(str(hex))))
	_color_picker = ColorPickerButton.new()
	_color_picker.text = "CUSTOM COLOR..."
	_color_picker.edit_alpha = false
	_color_picker.custom_minimum_size = Vector2(0, 36)
	_color_picker.color_changed.connect(_on_custom_color)
	column.add_child(_color_picker)

	var note := Label.new()
	note.text = "Drag the preview to rotate. Hair, shirt and pants are the real meshes inside your model."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16))
	column.add_child(note)

	# ---- right: 3D preview
	_preview_panel = Panel.new()
	_preview_panel.position = Vector2(394, 62)
	_preview_panel.size = Vector2(panel_size.x - 418, panel_size.y - 138)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.16, 0.17, 0.20)
	preview_style.border_color = Color(0.12, 0.09, 0.07)
	preview_style.set_border_width_all(3)
	_preview_panel.add_theme_stylebox_override("panel", preview_style)
	panel.add_child(_preview_panel)

	var viewport_container := SubViewportContainer.new()
	viewport_container.position = Vector2(8, 8)
	viewport_container.size = _preview_panel.size - Vector2(16, 16)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_panel.add_child(viewport_container)
	var sub_view := SubViewport.new()
	sub_view.size = Vector2i(viewport_container.size)
	sub_view.own_world_3d = true     # keep the menu's 3D background out of the preview
	sub_view.msaa_3d = Viewport.MSAA_4X
	sub_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(sub_view)
	_preview_world = Node3D.new()
	sub_view.add_child(_preview_world)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.72)
	env.ambient_light_energy = 0.8
	world_env.environment = env
	_preview_world.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -25, 0)
	light.light_energy = 1.4
	_preview_world.add_child(light)
	_preview_camera = Camera3D.new()
	_preview_camera.fov = 38.0
	_preview_world.add_child(_preview_camera)
	_preview_camera.make_current()
	_update_camera(0.0)

	_preview_status = Label.new()
	_preview_status.position = Vector2(20, _preview_panel.size.y * 0.5 - 52)
	_preview_status.size = Vector2(_preview_panel.size.x - 40, 104)
	_preview_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status.add_theme_font_size_override("font_size", 17)
	_preview_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.72))
	_preview_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_preview_status.add_theme_constant_override("outline_size", 6)
	_preview_status.visible = false
	_preview_panel.add_child(_preview_status)

	var view_button := Button.new()
	view_button.text = "FACE / BODY"
	view_button.position = Vector2(_preview_panel.size.x - 130, 12)
	view_button.size = Vector2(118, 32)
	view_button.pressed.connect(func(): _zoom_head = not _zoom_head)
	_preview_panel.add_child(view_button)

	# ---- bottom buttons
	var actions := HBoxContainer.new()
	actions.position = Vector2(24, panel_size.y - 62)
	actions.size = Vector2(panel_size.x - 48, 42)
	actions.add_theme_constant_override("separation", 10)
	panel.add_child(actions)
	var randomize_button := Button.new()
	randomize_button.text = "RANDOMIZE"
	randomize_button.pressed.connect(_randomize)
	actions.add_child(randomize_button)
	var reset_button := Button.new()
	reset_button.text = "RESET"
	reset_button.pressed.connect(_reset)
	actions.add_child(reset_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(queue_free)
	actions.add_child(close_button)
	var save_button := Button.new()
	save_button.text = "SAVE OUTFIT"
	save_button.pressed.connect(_save)
	actions.add_child(save_button)


func _add_label(parent: Node, value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	parent.add_child(label)


func _make_swatch(color: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(36, 28)
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.12) if state == "hover" else color
		box.set_border_width_all(3 if state == "hover" else 2)
		box.border_color = Color.WHITE if state == "hover" else INK
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(_set_hair_color.bind(color))
	return button


## One row of toggle buttons per category, built from what the model actually contains.
func _build_option_rows() -> void:
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	_part_buttons.clear()
	var options := Hero.get_options(_preview_model)
	for cat in Hero.CATEGORIES:
		var ids: Array = options.get(cat, [])
		if ids.size() < 2:
			continue      # nothing to choose between
		_add_label(_options_box, str(Hero.CATEGORIES[cat]["label"]), 17)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_options_box.add_child(flow)
		var group := ButtonGroup.new()
		_part_buttons[cat] = {}
		for id in ids:
			var button := Button.new()
			button.text = Hero.display_name(str(id))
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size = Vector2(98, 38)
			button.pressed.connect(_on_part_chosen.bind(str(cat), str(id)))
			flow.add_child(button)
			_part_buttons[cat][str(id)] = button


## Makes the buttons / swatch show what _working currently holds.
func _sync_controls() -> void:
	for cat in _part_buttons:
		var key: String = Hero.CATEGORIES[cat]["key"]
		var chosen := str(_working.get(key, ""))
		var buttons: Dictionary = _part_buttons[cat]
		if not buttons.has(chosen) and not buttons.is_empty():
			chosen = str(buttons.keys()[0])
			_working[key] = chosen
		for id in buttons:
			(buttons[id] as Button).set_pressed_no_signal(id == chosen)
	var color := Color.html(str(_working["hair_color"]))
	_color_swatch.color = color
	_color_picker.color = color


# --------------------------------------------------------------------- preview

func _spawn_preview() -> void:
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	_preview_model = Hero.create(_working)
	if _preview_model == null:
		_preview_status.text = "CHARACTER MODEL NOT FOUND\n\nPut your GLB at:\nres://assets/character/character_main.glb"
		_preview_status.visible = true
		return
	_preview_status.visible = false
	_preview_model.rotation.y = _yaw
	_preview_world.add_child(_preview_model)
	Hero.play(_preview_model, "idle", true)


func _refresh_preview() -> void:
	if _preview_model != null and is_instance_valid(_preview_model):
		Hero.apply_appearance(_preview_model, _working)


func _update_camera(delta: float) -> void:
	if _preview_camera == null:
		return
	var target := 1.0 if _zoom_head else 0.0
	if delta > 0.0:
		_cam_blend = lerpf(_cam_blend, target, 1.0 - exp(-delta * 7.0))
	else:
		_cam_blend = target
	var cam_pos := CAM_BODY_POS.lerp(CAM_HEAD_POS, _cam_blend)
	var look := CAM_BODY_LOOK.lerp(CAM_HEAD_LOOK, _cam_blend)
	_preview_camera.position = cam_pos
	_preview_camera.look_at(look, Vector3.UP)


func _process(delta: float) -> void:
	_update_camera(delta)
	if _preview_model != null and is_instance_valid(_preview_model):
		if not _dragging:
			_yaw += delta * 0.35
		_preview_model.rotation.y = _yaw


func _input(event: InputEvent) -> void:
	if _preview_panel == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and _preview_panel.get_global_rect().has_point(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * 0.012


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		queue_free()


# --------------------------------------------------------------------- actions

func _on_part_chosen(category: String, id: String) -> void:
	_working[Hero.CATEGORIES[category]["key"]] = id
	_refresh_preview()


func _set_hair_color(color: Color) -> void:
	_working["hair_color"] = "#" + color.to_html(false)
	_color_swatch.color = color
	_color_picker.color = color
	_refresh_preview()


func _on_custom_color(color: Color) -> void:
	_working["hair_color"] = "#" + color.to_html(false)
	_color_swatch.color = color
	_refresh_preview()


func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var options := Hero.get_options(_preview_model)
	for cat in Hero.CATEGORIES:
		var ids: Array = options.get(cat, [])
		if not ids.is_empty():
			_working[Hero.CATEGORIES[cat]["key"]] = str(ids[rng.randi() % ids.size()])
	var color := Color.html(str(HAIR_PRESETS[rng.randi() % HAIR_PRESETS.size()]))
	_working["hair_color"] = "#" + color.to_html(false)
	_sync_controls()
	_refresh_preview()


func _reset() -> void:
	_working = Hero.DEFAULT_APPEARANCE.duplicate()
	_sync_controls()
	_refresh_preview()


func _save() -> void:
	GameData.character_appearance = Hero.sanitize_appearance(_working)
	GameData.save()
	queue_free()
