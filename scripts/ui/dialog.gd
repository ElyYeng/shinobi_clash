class_name DialogBox
extends CanvasLayer
## Simple NPC dialogue box. open(name, text, [[button label, Callable], ...]). Pauses the game while open.

var p: Player
var root: Control
var name_label: Label
var text_label: Label
var box: VBoxContainer
var is_open := false

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(640, 0)
	margin.add_child(vb)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vb.add_child(name_label)
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(640, 100)
	vb.add_child(text_label)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	vb.add_child(box)
	root.visible = false

func bind(player: Player) -> void:
	p = player

func open(who: String, text: String, options: Array) -> void:
	name_label.text = who
	text_label.text = text
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for o in options:
		var b := Button.new()
		b.text = str(o[0])
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_choose.bind(o[1]))
		box.add_child(b)
	root.visible = true
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if box.get_child_count() > 0:
		(box.get_child(0) as Button).grab_focus()

func _choose(cb: Callable) -> void:
	close()
	if cb.is_valid():
		cb.call()

func close() -> void:
	root.visible = false
	is_open = false
	get_tree().paused = false
	if p != null and not p.is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
