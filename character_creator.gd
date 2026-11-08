extends CanvasLayer
## Character creator for the supplied Mixamo character: real hair, shirt and pants meshes.

var _working: Dictionary = {}
var _preview_world: Node3D
var _preview_model: Node3D
var _preview_status: Label
var _hair_color_slider: HSlider
var _hair_color_swatch: ColorRect
var _hair_style: OptionButton
var _shirt_style: OptionButton
var _pants_style: OptionButton
var _hue := 0.0

const PANEL_BG := Color(0.83, 0.79, 0.65)
const INK := Color(0.13, 0.09, 0.06)

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_working = GameData.character_appearance.duplicate(true)
	var saved := Color.from_string(str(_working.get("hair_color", "#20202A")), Color(0.12, 0.12, 0.16))
	_hue = float(_working.get("hair_hue", saved.h)) * 360.0
	_build_ui()
	_update_hair_color()
	_refresh_preview()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.018, 0.025, 0.90)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := Vector2(minf(980.0, viewport_size.x - 32.0), minf(610.0, viewport_size.y - 32.0))
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

	var controls := VBoxContainer.new()
	controls.position = Vector2(24, 68)
	controls.size = Vector2(340, panel_size.y - 150)
	controls.add_theme_constant_override("separation", 10)
	panel.add_child(controls)

	_add_label(controls, "HAIRSTYLE", 17)
	_hair_style = OptionButton.new()
	_hair_style.add_item("Hair 1")
	_hair_style.add_item("Hair 2")
	_hair_style.custom_minimum_size.y = 38
	_hair_style.select(1 if str(_working.get("hair_style", "spiky")) == "spiky" else 0)
	_hair_style.item_selected.connect(_on_hair_style_changed)
	controls.add_child(_hair_style)

	_add_label(controls, "HAIR COLOR", 17)
	_hair_color_swatch = ColorRect.new()
	_hair_color_swatch.custom_minimum_size = Vector2(0, 34)
	controls.add_child(_hair_color_swatch)
	_hair_color_slider = HSlider.new()
	_hair_color_slider.min_value = 0.0
	_hair_color_slider.max_value = 360.0
	_hair_color_slider.step = 1.0
	_hair_color_slider.value = _hue
	_hair_color_slider.custom_minimum_size.y = 30
	_hair_color_slider.value_changed.connect(_on_hair_hue_changed)
	controls.add_child(_hair_color_slider)
	var hue_hint := Label.new()
	hue_hint.text = "Drag to change hair color"
	hue_hint.add_theme_font_size_override("font_size", 12)
	hue_hint.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16))
	controls.add_child(hue_hint)

	_add_label(controls, "SHIRT", 17)
	_shirt_style = OptionButton.new()
	_shirt_style.add_item("Shirt 1")
	_shirt_style.add_item("Shirt 2")
	_shirt_style.custom_minimum_size.y = 38
	_shirt_style.select(1 if str(_working.get("shirt_style", "shirt_1")) == "shirt_2" else 0)
	_shirt_style.item_selected.connect(_on_shirt_changed)
	controls.add_child(_shirt_style)

	_add_label(controls, "PANTS", 17)
	_pants_style = OptionButton.new()
	_pants_style.add_item("Pants 1")
	_pants_style.add_item("Pants 2")
	_pants_style.custom_minimum_size.y = 38
	_pants_style.select(1 if str(_working.get("pants_style", "pants_1")) == "pants_2" else 0)
	_pants_style.item_selected.connect(_on_pants_changed)
	controls.add_child(_pants_style)

	var note := Label.new()
	note.text = "Changes use the original skinned meshes from your model."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16))
	controls.add_child(note)

	var preview_panel := Panel.new()
	preview_panel.position = Vector2(390, 62)
	preview_panel.size = Vector2(panel_size.x - 414, panel_size.y - 140)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.16, 0.17, 0.20)
	preview_style.border_color = Color(0.12, 0.09, 0.07)
	preview_style.set_border_width_all(3)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	panel.add_child(preview_panel)

	var viewport_container := SubViewportContainer.new()
	viewport_container.position = Vector2(8, 8)
	viewport_container.size = preview_panel.size - Vector2(16, 16)
	viewport_container.stretch = true
	preview_panel.add_child(viewport_container)
	var sub_view := SubViewport.new()
	sub_view.size = Vector2i(620, 560)
	sub_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(sub_view)
	_preview_world = Node3D.new()
	sub_view.add_child(_preview_world)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.72)
	env.ambient_light_energy = 0.8
	environment.environment = env
	_preview_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -25, 0)
	light.light_energy = 1.4
	_preview_world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.15, 4.2)
	camera.fov = 38.0
	_preview_world.add_child(camera)
	camera.look_at(Vector3(0, 0.92, 0), Vector3.UP)
	camera.make_current()

	_preview_status = Label.new()
	_preview_status.position = Vector2(20, preview_panel.size.y * 0.5 - 52)
	_preview_status.size = Vector2(preview_panel.size.x - 40, 104)
	_preview_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status.add_theme_font_size_override("font_size", 17)
	_preview_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.72))
	_preview_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_preview_status.add_theme_constant_override("outline_size", 6)
	preview_panel.add_child(_preview_status)

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

func _on_hair_style_changed(index: int) -> void:
	_working["hair_style"] = "short" if index == 0 else "spiky"
	_refresh_preview()

func _on_shirt_changed(index: int) -> void:
	_working["shirt_style"] = "shirt_1" if index == 0 else "shirt_2"
	_refresh_preview()

func _on_pants_changed(index: int) -> void:
	_working["pants_style"] = "pants_1" if index == 0 else "pants_2"
	_refresh_preview()

func _on_hair_hue_changed(value: float) -> void:
	_hue = value
	_update_hair_color()
	_refresh_preview()

func _update_hair_color() -> void:
	var color := Color.from_hsv(fposmod(_hue, 360.0) / 360.0, 0.86, 0.96)
	_working["hair_color"] = color.to_html(false)
	_working["hair_hue"] = _hue / 360.0
	if _hair_color_swatch != null:
		_hair_color_swatch.color = color

func _refresh_preview() -> void:
	if _preview_world == null or not is_instance_valid(_preview_world):
		return
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	_preview_model = Hero.create(_working)
	if _preview_model == null:
		if _preview_status != null:
			_preview_status.text = "CUSTOM CHARACTER MODEL NOT FOUND\\n\\nInstall your GLB here:\\nres://assets/character/character_main.glb"
			_preview_status.visible = true
		return
	if _preview_status != null:
		_preview_status.visible = false
	_preview_world.add_child(_preview_model)
	Hero.play(_preview_model, "idle", true)

func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_hair_style.select(rng.randi_range(0, 1))
	_shirt_style.select(rng.randi_range(0, 1))
	_pants_style.select(rng.randi_range(0, 1))
	_working["hair_style"] = "short" if _hair_style.selected == 0 else "spiky"
	_working["shirt_style"] = "shirt_1" if _shirt_style.selected == 0 else "shirt_2"
	_working["pants_style"] = "pants_1" if _pants_style.selected == 0 else "pants_2"
	_hair_color_slider.value = rng.randf_range(0.0, 360.0)
	_on_hair_hue_changed(_hair_color_slider.value)
	_refresh_preview()

func _reset() -> void:
	_working = {"hair_style":"short", "hair_color":"#E6B52E", "hair_hue":0.12, "shirt_style":"shirt_1", "pants_style":"pants_1"}
	_hair_style.select(0)
	_shirt_style.select(0)
	_pants_style.select(0)
	_hair_color_slider.value = 43.0
	_on_hair_hue_changed(43.0)
	_refresh_preview()

func _save() -> void:
	GameData.character_appearance = _working.duplicate(true)
	GameData.save()
	queue_free()

func _process(delta: float) -> void:
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.rotate_y(delta * 0.22)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		queue_free()
