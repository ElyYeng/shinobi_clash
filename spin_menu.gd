class_name SpinMenu
extends CanvasLayer

const RARITY_COLORS := {
	"Common": Color(0.8, 0.8, 0.8), "Rare": Color(0.35, 0.6, 1.0),
	"Epic": Color(0.7, 0.4, 1.0), "Legendary": Color(1.0, 0.8, 0.2)}

var p: Player
var root: Control
var spins_label: Label
var result_label: Label
var desc_label: Label
var pity_label: Label
var spin_btn: Button
var element_btn: Button
var element_label: Label
var grid: GridContainer
var spinning := false
var slot_labels: Array[Label] = []
var preview_viewport: SubViewport
var preview_model: Node3D

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.055, 0.98)
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Backdrop grid/window motif.
	var header := _label(root, "SHINOBI CLASH  •  CHARACTER CUSTOMIZATION", 24, Color(1.0, 0.88, 0.55))
	header.anchor_left = 0.5
	header.anchor_right = 0.5
	header.offset_left = -310
	header.offset_right = 310
	header.offset_top = 18
	header.offset_bottom = 54
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	spins_label = _label(root, "", 19, Color.WHITE)
	spins_label.position = Vector2(24, 66)
	spins_label.size = Vector2(250, 32)

	# Four visible spin slots, like the reference image.
	_build_slot_panel(Vector2(18, 112), "BLOODLINE SLOT #1", 0)
	_build_slot_panel(Vector2(-278, 112), "BLOODLINE SLOT #2", 1, true)
	_build_slot_panel(Vector2(18, 318), "BLOODLINE SLOT #3", 2)
	_build_slot_panel(Vector2(-278, 318), "BLOODLINE SLOT #4", 3, true)

	# Bloodline collection: the list is scrollable so every definition remains reachable.
	var inventory_panel := Panel.new()
	inventory_panel.position = Vector2(18, 512)
	inventory_panel.size = Vector2(310, 192)
	var inventory_style := StyleBoxFlat.new()
	inventory_style.bg_color = Color(0.08, 0.1, 0.09, 0.96)
	inventory_style.border_color = Color(0.75, 0.62, 0.3)
	inventory_style.set_border_width_all(2)
	inventory_style.set_corner_radius_all(5)
	inventory_panel.add_theme_stylebox_override("panel", inventory_style)
	root.add_child(inventory_panel)
	var inventory_title := _label(root, "BLOODLINE COLLECTION", 12, Color(1.0, 0.88, 0.55))
	inventory_title.position = Vector2(26, 516)
	inventory_title.size = Vector2(294, 20)
	var grid_scroll := ScrollContainer.new()
	grid_scroll.position = Vector2(24, 538)
	grid_scroll.size = Vector2(298, 160)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(grid_scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid_scroll.add_child(grid)

	# Character preview in the centre.
	var preview_frame := Panel.new()
	preview_frame.set_anchors_preset(Control.PRESET_CENTER)
	preview_frame.offset_left = -205
	preview_frame.offset_right = 205
	preview_frame.offset_top = -190
	preview_frame.offset_bottom = 180
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.14, 0.16, 0.78)
	ps.border_color = Color(0.75, 0.62, 0.3)
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(8)
	preview_frame.add_theme_stylebox_override("panel", ps)
	root.add_child(preview_frame)

	var character_tag := _label(root, "[ CHARACTER ]", 17, Color(1.0, 0.9, 0.65))
	character_tag.anchor_left = 0.5
	character_tag.anchor_right = 0.5
	character_tag.offset_left = -90
	character_tag.offset_right = 90
	character_tag.offset_top = 91
	character_tag.offset_bottom = 120
	character_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(400, 350)
	preview_viewport.transparent_bg = true
	preview_viewport.own_world_3d = true
	var vpc := SubViewportContainer.new()
	vpc.set_anchors_preset(Control.PRESET_CENTER)
	vpc.offset_left = -198
	vpc.offset_right = 198
	vpc.offset_top = -155
	vpc.offset_bottom = 170
	vpc.stretch = true
	vpc.add_child(preview_viewport)
	root.add_child(vpc)
	_setup_preview()

	# Element panel and spin controls below character.
	var elements_tag := _label(root, "[ ELEMENTS ]", 17, Color(1.0, 0.9, 0.65))
	elements_tag.anchor_left = 0.5
	elements_tag.anchor_right = 0.5
	elements_tag.offset_left = -100
	elements_tag.offset_right = 100
	elements_tag.anchor_top = 0.75
	elements_tag.anchor_bottom = 0.79
	elements_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	element_label = _label(root, "", 17, Color.WHITE)
	element_label.anchor_left = 0.5
	element_label.anchor_right = 0.5
	element_label.offset_left = -240
	element_label.offset_right = 240
	element_label.anchor_top = 0.79
	element_label.anchor_bottom = 0.82
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	element_btn = _button(root, "SPIN ELEMENT", Vector2(0.5, 0.83), Vector2(-205, 0), Vector2(190, 38))
	element_btn.pressed.connect(_on_element_spin)

	var bloodline_tag := _label(root, "[ BLOODLINE ]", 17, Color(1.0, 0.9, 0.65))
	bloodline_tag.anchor_left = 0.5
	bloodline_tag.anchor_right = 0.5
	bloodline_tag.offset_left = -100
	bloodline_tag.offset_right = 100
	bloodline_tag.anchor_top = 0.89
	bloodline_tag.anchor_bottom = 0.92
	bloodline_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	result_label = _label(root, "?", 26, Color.WHITE)
	result_label.anchor_left = 0.5
	result_label.anchor_right = 0.5
	result_label.offset_left = -200
	result_label.offset_right = 200
	result_label.anchor_top = 0.92
	result_label.anchor_bottom = 0.955
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	desc_label = _label(root, "", 14, Color(0.9, 0.87, 0.78))
	desc_label.anchor_left = 0.5
	desc_label.anchor_right = 0.5
	desc_label.offset_left = -240
	desc_label.offset_right = 240
	desc_label.anchor_top = 0.955
	desc_label.anchor_bottom = 0.995
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	spin_btn = _button(root, "SPIN BLOODLINE", Vector2(0.5, 0.83), Vector2(15, 0), Vector2(190, 38))
	spin_btn.pressed.connect(_on_spin)

	pity_label = _label(root, "", 14, Color(0.8, 0.78, 0.68))
	pity_label.position = Vector2(24, 92)
	pity_label.size = Vector2(260, 18)

	var close := _button(root, "CLOSE  [ B / ESC ]", Vector2(1, 1), Vector2(-190, -58), Vector2(166, 40))
	close.pressed.connect(toggle)

	root.visible = false

func _build_slot_panel(pos: Vector2, title: String, index: int, right_side := false) -> void:
	var panel := Panel.new()
	panel.size = Vector2(150, 184)
	panel.position = pos
	if right_side:
		panel.anchor_left = 1
		panel.anchor_right = 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.78, 0.74, 0.58, 0.96)
	style.border_color = Color(0.08, 0.32, 0.18)
	style.set_border_width_all(4)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var top := ColorRect.new()
	top.color = Color(0.04, 0.48, 0.22)
	top.size = Vector2(142, 13)
	top.position = Vector2(4, 4)
	panel.add_child(top)
	var name := _label(panel, title, 12, Color(0.12, 0.1, 0.07))
	name.position = Vector2(7, 25)
	name.size = Vector2(136, 24)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value := _label(panel, "???", 22, Color(0.45, 0.06, 0.12))
	value.position = Vector2(7, 62)
	value.size = Vector2(136, 35)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_labels.append(value)
	var b := Button.new()
	b.text = " [ CLICK TO SPIN ] "
	b.position = Vector2(9, 112)
	b.size = Vector2(132, 35)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(_on_spin)
	panel.add_child(b)
	var bottom := ColorRect.new()
	bottom.color = Color(0.04, 0.48, 0.22)
	bottom.position = Vector2(4, 166)
	bottom.size = Vector2(142, 13)
	panel.add_child(bottom)

func _setup_preview() -> void:
	var world := World3D.new()
	preview_viewport.world_3d = world
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	environment.ambient_light_energy = 0.8
	env.environment = environment
	preview_viewport.add_child(env)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.45, 4.2)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	preview_viewport.add_child(camera)
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_energy = 1.5
	preview_viewport.add_child(key)
	_replace_preview_model()

func _replace_preview_model() -> void:
	if preview_model != null and is_instance_valid(preview_model):
		if preview_model.get_parent() == preview_viewport:
			preview_viewport.remove_child(preview_model)
		preview_model.queue_free()
	if p != null and p.model != null:
		preview_model = p.model.duplicate()
	else:
		preview_model = Hero.create()
	if preview_model == null:
		preview_model = Fx.make_ninja(Color(0.9, 0.75, 0.55), Color(0.1, 0.1, 0.16))
	preview_model.position = Vector3.ZERO
	preview_viewport.add_child(preview_model)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, anchor: Vector2, offset: Vector2, extent: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + extent.x
	b.offset_bottom = offset.y + extent.y
	b.add_theme_font_size_override("font_size", 17)
	parent.add_child(b)
	return b

func bind(player: Player) -> void:
	p = player
	if preview_viewport != null:
		_replace_preview_model()

func _unhandled_input(event: InputEvent) -> void:
	var gm = get_parent().get("gmenu")
	if gm != null and gm.is_open:
		return
	if event.is_action_pressed("spin_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif root.visible and event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if spinning:
		return
	root.visible = not root.visible
	get_tree().paused = root.visible
	if root.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_equipped()
		_refresh()
	else:
		if p and not p.is_dead:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_equipped() -> void:
	var d := Bloodline.get_def(GameData.equipped)
	result_label.text = d["name"]
	result_label.modulate = d["color"]
	desc_label.text = "[%s]  %s" % [d["rarity"], d["desc"]]

func _refresh() -> void:
	spins_label.text = "✦  %d SPINS" % GameData.spins
	pity_label.text = "Legendary pity: %d / %d" % [GameData.pity, GameData.PITY_LIMIT]
	element_label.text = "Equipped: %s     •     Owned: %s" % [GameData.equipped_element, ", ".join(PackedStringArray(GameData.owned_elements))]
	element_btn.text = "SPIN ELEMENT  (%d LEFT)" % GameData.element_spins
	element_btn.disabled = spinning or GameData.element_spins <= 0
	spin_btn.disabled = spinning or GameData.spins <= 0
	for i in slot_labels.size():
		slot_labels[i].text = Bloodline.get_def(GameData.equipped)["name"] if i == 0 else "EMPTY SLOT"
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for id in Bloodline.DEFS:
		var d := Bloodline.get_def(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(145, 50)
		if GameData.owned.has(id):
			b.text = "%s\n%s" % [d["name"], d["rarity"]]
			b.modulate = RARITY_COLORS[d["rarity"]]
			b.tooltip_text = d["desc"]
			b.pressed.connect(_equip.bind(id))
		else:
			b.text = "???\nLocked"
			b.disabled = true
		grid.add_child(b)

func _equip(id: String) -> void:
	GameData.equipped = id
	GameData.save()
	if p:
		p.apply_bloodline()
	_show_equipped()
	_refresh()

func _on_spin() -> void:
	if spinning or GameData.spins <= 0:
		return
	spinning = true
	spin_btn.disabled = true
	var id := GameData.roll()
	var is_new := GameData.last_new
	var ids: Array = Bloodline.DEFS.keys()
	ids.erase("none")
	desc_label.text = "Awakening..."
	for i in 22:
		var rid: String = ids[randi() % ids.size()]
		var rd := Bloodline.get_def(rid)
		result_label.text = rd["name"]
		result_label.modulate = rd["color"]
		await get_tree().create_timer(0.05 + i * 0.012, true, false, true).timeout
	var d := Bloodline.get_def(id)
	result_label.text = d["name"]
	result_label.modulate = d["color"]
	desc_label.text = "[%s] %s\n%s" % [d["rarity"], "NEW BLOODLINE!" if is_new else "Duplicate", d["desc"]]
	spinning = false
	_refresh()

func _on_element_spin() -> void:
	if spinning or GameData.element_spins <= 0:
		return
	var result := GameData.roll_element()
	element_label.text = "Equipped: %s     •     Owned: %s" % [GameData.equipped_element, ", ".join(PackedStringArray(GameData.owned_elements))]
	desc_label.text = "Element awakened! %s Style is now equipped." % result
	_refresh()
