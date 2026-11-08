extends Control
## Main menu: pick what you want to play (1 / 2 / 3 also work), or CUSTOMIZE to spin bloodlines and elements.

var spin: SpinMenu
var stat: Label
var custom_btn: Button

func _ready() -> void:
	Fx.setup_inputs()
	GameData.load_data()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := MenuBG.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	var title := _label(vb, "SHINOBI CLASH", 72, Color(1.0, 0.62, 0.16))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0.9, 0.15, 0.05, 0.75))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("outline_size", 16)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "modulate", Color(1.2, 1.05, 0.85), 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "modulate", Color(1, 1, 1), 1.5).set_trans(Tween.TRANS_SINE)
	var sub := _label(vb, "~  choose your path  ~", 22, Color(1.0, 0.85, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var line := ColorRect.new()
	line.color = Color(1.0, 0.55, 0.2, 0.7)
	line.custom_minimum_size = Vector2(0, 2)
	vb.add_child(line)
	_spacer(vb, 8)

	var b1 := _button(vb, "1   KURAMA BOSS FIGHT\nFace the Nine-Tailed Beast", "kurama", Color(1.0, 0.3, 0.1))
	_button(vb, "2   FIGHT\nArena battle against shinobi in the village", "fight", Color(0.3, 0.6, 1.0))
	_button(vb, "3   MAIN GAME\nOpen world - talk to villagers and take on quests", "world", Color(0.35, 0.85, 0.4))
	custom_btn = _button(vb, "", "", Color(0.85, 0.3, 0.9))
	custom_btn.pressed.disconnect(_play.bind(""))
	custom_btn.pressed.connect(_open_customize)
	var creator_btn := _button(vb, "CHARACTER CREATOR\\nBuild your original shinobi", "", Color(0.72, 0.48, 0.9))
	creator_btn.pressed.disconnect(_play.bind(""))
	creator_btn.pressed.connect(_open_character_creator)
	var multi_btn := Button.new()
	multi_btn.text = "5   MULTIPLAYER  -  Host or join friends over Radmin VPN"
	multi_btn.custom_minimum_size = Vector2(580, 52)
	multi_btn.add_theme_font_size_override("font_size", 20)
	_style_button(multi_btn, Color(0.25, 0.75, 0.95))
	multi_btn.pressed.connect(_open_multiplayer)
	vb.add_child(multi_btn)
	_spacer(vb, 6)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(0, 40)
	quit.add_theme_font_size_override("font_size", 20)
	_style_button(quit, Color(0.7, 0.7, 0.78))
	quit.pressed.connect(get_tree().quit)
	vb.add_child(quit)
	vb.modulate.a = 0.0   # fade the whole menu in
	var fade := vb.create_tween()
	fade.tween_property(vb, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spacer(vb, 6)

	stat = _label(vb, "", 16, Color(0.8, 0.8, 0.85))
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh_info()
	spin = SpinMenu.new()   # bloodline + element spins live here, not in-game
	add_child(spin)
	spin.closed.connect(_refresh_info)
	if GameData.open_customize:   # came from "OPEN SPIN" in the in-game menu
		GameData.open_customize = false
		_open_customize.call_deferred()
	var cred := _label(vb, Hero.CREDIT + "\n" + Kurama.CREDIT, 12, Color(0.6, 0.6, 0.65))
	cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b1.grab_focus()

func _refresh_info() -> void:
	custom_btn.text = "4   CUSTOMIZE\nSpin bloodlines and elements   [ %d spins  /  %d element spins ]" % [GameData.spins, GameData.element_spins]
	stat.text = "Shinobi LV %d    Bloodline: %s    Quests done: %d / %d    Kurama: %s" % [
		GameData.level, Bloodline.get_def(GameData.equipped)["name"], GameData.quests_done.size(), Quests.DEFS.size(),
		"DEFEATED" if GameData.kurama_defeated else "undefeated"]

func _open_character_creator() -> void:
	var script = load("res://character_creator.gd")
	if script == null:
		return
	var creator = script.new()
	add_child(creator)

func _open_multiplayer() -> void:
	get_tree().change_scene_to_file("res://multiplayer_lobby.tscn")

func _open_customize() -> void:
	if spin != null and not spin.root.visible:
		spin.toggle()

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l

func _spacer(parent: Node, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

func _style_button(b: Button, accent: Color) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		var lit: bool = st != "normal"
		sb.bg_color = Color(0.2, 0.07, 0.05, 0.92) if lit else Color(0.05, 0.03, 0.07, 0.8)
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(2)
		sb.border_width_left = 8
		sb.border_color = accent if lit else accent.darkened(0.45)
		sb.content_margin_left = 26
		sb.content_margin_right = 20
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35 if lit else 0.0)
		sb.shadow_size = 12 if lit else 0
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.88))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.8))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _button(parent: Node, text: String, mode: String, accent := Color(1.0, 0.5, 0.2)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(580, 68)
	b.add_theme_font_size_override("font_size", 20)
	_style_button(b, accent)
	b.pressed.connect(_play.bind(mode))
	parent.add_child(b)
	return b

func _play(mode: String) -> void:
	GameData.mode = mode
	get_tree().change_scene_to_file("res://main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if spin != null and spin.root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_play("kurama")
			KEY_2:
				_play("fight")
			KEY_3:
				_play("world")
			KEY_4:
				_open_customize()
			KEY_5:
				_open_multiplayer()
			KEY_6:
				_open_character_creator()
