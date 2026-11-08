extends CanvasLayer
## Prototype creator using the project's credited Naruto Rigged test skeleton.
## Clothing is currently primitive bone-attached overlay geometry, not final art.

const PALETTE := ["#20202A", "#38313A", "#75452F", "#B87843", "#E5B94F", "#D65A24",
	"#A83232", "#315C91", "#356B42", "#6C4C91", "#D5D0C6", "#171719"]
const SLOT_LABELS := {"hair_color":"HAIR", "top_color":"TOP", "pants_color":"PANTS",
	"shoes_color":"SHOES", "headband_color":"HEADBAND"}

var _working: Dictionary = {}
var _selected_color := "hair_color"
var _preview_world: Node3D
var _preview_model: Node3D
var _hair_style: OptionButton
var _headband_toggle: CheckButton
var _palette_grid: GridContainer
var _slot_title: Label

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_working = GameData.character_appearance.duplicate(true)
	_build_ui()
	_refresh_preview()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.018, 0.025, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var view_size := get_viewport().get_visible_rect().size
	var panel_size := Vector2(minf(1120.0, view_size.x - 36.0), minf(630.0, view_size.y - 36.0))
	var panel := Panel.new()
	panel.position = (view_size - panel_size) * 0.5
	panel.size = panel_size
	var parchment := StyleBoxFlat.new()
	parchment.bg_color = Color(0.83, 0.79, 0.65)
	parchment.border_color = Color(0.12, 0.09, 0.07)
	parchment.set_border_width_all(5)
	panel.add_theme_stylebox_override("panel", parchment)
	root.add_child(panel)

	var title := Label.new()
	title.text = "ORIGINAL SHINOBI  /  CHARACTER CREATOR"
	title.position = Vector2(22, 10)
	title.size = Vector2(panel_size.x - 44, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.10, 0.075, 0.06))
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.91, 0.68))
	title.add_theme_constant_override("outline_size", 2)
	panel.add_child(title)

	var left := Panel.new()
	left.position = Vector2(22, 58)
	left.size = Vector2(430, panel_size.y - 140)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.76, 0.71, 0.56)
	left_style.border_color = Color(0.12, 0.09, 0.07)
	left_style.set_border_width_all(3)
	left.add_theme_stylebox_override("panel", left_style)
	panel.add_child(left)

	var content := VBoxContainer.new()
	content.position = Vector2(16, 14)
	content.size = left.size - Vector2(32, 28)
	content.add_theme_constant_override("separation", 8)
	left.add_child(content)
	_add_label(content, "BUILD YOUR SHINOBI", 22, Color(0.13, 0.09, 0.06))
	_add_label(content, "Select a part, then choose its color.", 14, Color(0.26, 0.20, 0.13))

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 4)
	content.add_child(slots)
	for key in SLOT_LABELS:
		_add_slot_button(slots, str(SLOT_LABELS[key]), str(key))

	_slot_title = _add_label(content, "HAIR COLOR", 18, Color(0.13, 0.09, 0.06))
	_palette_grid = GridContainer.new()
	_palette_grid.columns = 6
	_palette_grid.add_theme_constant_override("h_separation", 6)
	_palette_grid.add_theme_constant_override("v_separation", 5)
	content.add_child(_palette_grid)
	_build_palette()

	_add_label(content, "HAIRSTYLE", 17, Color(0.13, 0.09, 0.06))
	_hair_style = OptionButton.new()
	_hair_style.add_item("Spiky")
	_hair_style.add_item("Short")
	_hair_style.add_item("Ponytail")
	_hair_style.custom_minimum_size = Vector2(0, 36)
	_hair_style.item_selected.connect(_on_hair_style_changed)
	content.add_child(_hair_style)
	match str(_working.get("hair_style", "spiky")):
		"short": _hair_style.select(1)
		"ponytail": _hair_style.select(2)
		_: _hair_style.select(0)

	_add_label(content, "SHIRT STYLE", 15, Color(0.13, 0.09, 0.06))
	var shirt_style := OptionButton.new()
	shirt_style.add_item("Shirt 1")
	shirt_style.add_item("Shirt 2")
	shirt_style.select(1 if str(_working.get("shirt_style", "shirt_a")) == "shirt_b" else 0)
	shirt_style.item_selected.connect(func(index: int) -> void:
		_working["shirt_style"] = "shirt_b" if index == 1 else "shirt_a"
		_refresh_preview()
	)
	content.add_child(shirt_style)
	_add_label(content, "PANTS STYLE", 15, Color(0.13, 0.09, 0.06))
	var pants_style := OptionButton.new()
	pants_style.add_item("Pants 1")
	pants_style.add_item("Pants 2")
	pants_style.select(1 if str(_working.get("pants_style", "pants_a")) == "pants_b" else 0)
	pants_style.item_selected.connect(func(index: int) -> void:
		_working["pants_style"] = "pants_b" if index == 1 else "pants_a"
		_refresh_preview()
	)
	content.add_child(pants_style)

	_headband_toggle = CheckButton.new()
	_headband_toggle.text = "Wear forehead protector"
	_headband_toggle.button_pressed = bool(_working.get("show_headband", true))
	_headband_toggle.toggled.connect(func(value: bool) -> void:
		_working["show_headband"] = value
		_refresh_preview()
	)
	content.add_child(_headband_toggle)

	var note := Label.new()
	note.text = "CUSTOM MIXAMO RIG.\nChoose between the included hair, shirt and pants meshes."
	note.custom_minimum_size = Vector2(0, 44)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.25, 0.20, 0.14))
	content.add_child(note)

	var preview_panel := Panel.new()
	preview_panel.position = Vector2(472, 58)
	preview_panel.size = Vector2(panel_size.x - 496, panel_size.y - 140)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.18, 0.17, 0.19)
	preview_style.border_color = Color(0.12, 0.09, 0.07)
	preview_style.set_border_width_all(3)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	panel.add_child(preview_panel)

	var preview_title := Label.new()
	preview_title.text = "LIVE PREVIEW"
	preview_title.position = Vector2(10, 7)
	preview_title.size = Vector2(preview_panel.size.x - 20, 28)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 18)
	preview_title.add_theme_color_override("font_color", Color(0.94, 0.83, 0.56))
	preview_panel.add_child(preview_title)

	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.position = Vector2(8, 36)
	viewport_container.size = preview_panel.size - Vector2(16, 44)
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
	env.background_color = Color(0.20, 0.19, 0.21)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.69, 0.64)
	env.ambient_light_energy = 0.75
	environment.environment = env
	_preview_world.add_child(environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28, -25, 0)
	key_light.light_energy = 1.35
	_preview_world.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2, 2, 2)
	fill_light.light_energy = 0.8
	fill_light.omni_range = 8.0
	_preview_world.add_child(fill_light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.18, 4.2)
	camera.fov = 38.0
	_preview_world.add_child(camera)
	camera.look_at(Vector3(0, 0.92, 0), Vector3.UP)
	camera.make_current()

	var actions := HBoxContainer.new()
	actions.position = Vector2(22, panel_size.y - 68)
	actions.size = Vector2(panel_size.x - 44, 46)
	actions.add_theme_constant_override("separation", 9)
	panel.add_child(actions)
	var randomize := Button.new()
	randomize.text = "RANDOMIZE"
	randomize.custom_minimum_size = Vector2(145, 40)
	randomize.pressed.connect(_randomize)
	_style_action(randomize, Color(0.28, 0.38, 0.34))
	actions.add_child(randomize)
	var reset := Button.new()
	reset.text = "RESET"
	reset.custom_minimum_size = Vector2(100, 40)
	reset.pressed.connect(_reset)
	_style_action(reset, Color(0.42, 0.35, 0.27))
	actions.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(110, 40)
	close.pressed.connect(queue_free)
	_style_action(close, Color(0.45, 0.25, 0.22))
	actions.add_child(close)
	var save := Button.new()
	save.text = "SAVE APPEARANCE"
	save.custom_minimum_size = Vector2(190, 40)
	save.pressed.connect(_save)
	_style_action(save, Color(0.18, 0.43, 0.26))
	actions.add_child(save)


func _add_label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_slot_button(parent: Node, text: String, slot: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(func() -> void:
		_selected_color = slot
		_slot_title.text = str(SLOT_LABELS[slot]) + " COLOR"
		_build_palette()
	)
	_style_action(button, Color(0.43, 0.32, 0.23))
	parent.add_child(button)

func _build_palette() -> void:
	for child in _palette_grid.get_children():
		child.queue_free()
	for hex in PALETTE:
		var color := Color.from_string(hex, Color.WHITE)
		var swatch := Button.new()
		swatch.text = ""
		swatch.custom_minimum_size = Vector2(50, 32)
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = color
			box.border_color = Color.WHITE if str(_working.get(_selected_color, "")) == hex else Color(0.08, 0.07, 0.06)
			box.set_border_width_all(3 if str(_working.get(_selected_color, "")) == hex else 1)
			box.set_corner_radius_all(4)
			swatch.add_theme_stylebox_override(state, box)
		swatch.pressed.connect(_set_selected_color.bind(hex))
		_palette_grid.add_child(swatch)

func _set_selected_color(hex: String) -> void:
	_working[_selected_color] = hex
	_build_palette()
	_refresh_preview()

func _on_hair_style_changed(index: int) -> void:
	_working["hair_style"] = ["spiky", "short", "ponytail"][clampi(index, 0, 2)]
	_refresh_preview()

func _refresh_preview() -> void:
	if _preview_world == null or not is_instance_valid(_preview_world):
		return
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	_preview_model = Hero.create(_working)
	if _preview_model == null:
		return
	_preview_world.add_child(_preview_model)
	Hero.play(_preview_model, "idle", true)

func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for key in SLOT_LABELS:
		_working[key] = PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
	_working["hair_style"] = ["spiky", "short"][rng.randi_range(0, 1)]\n\t_working["shirt_style"] = "shirt_b" if rng.randf() > 0.5 else "shirt_a"\n\t_working["pants_style"] = "pants_b" if rng.randf() > 0.5 else "pants_a"
	_working["show_headband"] = rng.randf() > 0.2
	_headband_toggle.button_pressed = bool(_working["show_headband"])
	_hair_style.select(["spiky", "short", "ponytail"].find(_working["hair_style"]))
	_build_palette()
	_refresh_preview()

func _reset() -> void:
	_working = {
		"hair_style":"spiky", "shirt_style":"shirt_a", "pants_style":"pants_a",\n\t\t"hair_color":"#20202A", "top_color":"#D65A24",
		"pants_color":"#343C52", "shoes_color":"#20202A",
		"headband_color":"#343C52", "show_headband":true,\n\t\t"shirt_style":"shirt_a", "pants_style":"pants_a"
	}
	_selected_color = "hair_color"
	_slot_title.text = "HAIR COLOR"
	_hair_style.select(0)
	_headband_toggle.button_pressed = true
	_build_palette()
	_refresh_preview()

func _save() -> void:
	GameData.character_appearance = _working.duplicate(true)
	GameData.save()
	queue_free()

func _style_action(button: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.15, 0.10, 0.08) if state == "normal" else Color(0.24, 0.16, 0.11)
		box.border_color = accent
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		box.content_margin_left = 7
		box.content_margin_right = 7
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	button.add_theme_color_override("font_hover_color", Color.WHITE)

func _process(delta: float) -> void:
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.rotate_y(delta * 0.22)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		queue_free()
