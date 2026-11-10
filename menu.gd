extends Control
## Main menu: pick what you want to play (keys 1-6 work too), or CUSTOMIZE to spin bloodlines and elements.
## Styled like the in-game UI (UiStyle): black ink ribbons for the modes, green buttons for the rest.

const MODES := [
	["MAIN GAME", "world", "Open world - talk to villagers and take on quests"],
	["FIGHT", "fight", "Arena battle against shinobi in the village"],
	["KURAMA BOSS", "kurama", "Face the Nine-Tailed Beast"],
]

var spin: SpinMenu
var stat: Label
var custom_btn: Button
var hint: Label

func _ready() -> void:
	Fx.setup_inputs()
	GameData.load_data()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := MenuBG.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# One column on the left, so the moon and the scenery stay visible.
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(470, 0)
	vb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vb)

	UiStyle.title(vb, "SHINOBI CLASH")
	UiStyle.spacer(vb, 14)

	var first: Button
	for i in MODES.size():
		var m: Array = MODES[i]
		var b := UiStyle.ribbon_button(vb, m[0], 28)
		b.pressed.connect(_play.bind(m[1]))
		_describe(b, "%s   [%d]" % [m[2], _key_for(m[1])])
		if first == null:
			first = b

	hint = UiStyle.label(vb, "", 16, Color(1.0, 0.86, 0.6), 6)
	hint.custom_minimum_size = Vector2(0, 24)
	UiStyle.spacer(vb, 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	custom_btn = UiStyle.green_button(row, "CUSTOMIZE")
	custom_btn.pressed.connect(_open_customize)
	var creator_btn := UiStyle.green_button(row, "CHARACTER")
	creator_btn.pressed.connect(_open_character_creator)
	_describe(creator_btn, "Your look - hair, colours, shirt and pants   [6]")
	var multi_btn := UiStyle.green_button(row, "MULTIPLAYER")
	multi_btn.pressed.connect(_open_multiplayer)
	_describe(multi_btn, "Host or join friends over Radmin VPN   [5]")
	for b in [custom_btn, creator_btn, multi_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	UiStyle.spacer(vb, 6)
	stat = UiStyle.label(vb, "", 15, Color(0.86, 0.84, 0.8), 6)
	var quit := UiStyle.text_button(vb, "QUIT")
	quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit.pressed.connect(get_tree().quit)
	_describe(quit, "")

	var cred := UiStyle.label(self, Hero.CREDIT + "\n" + Kurama.CREDIT, 11, Color(0.6, 0.6, 0.65), 4)
	cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cred.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cred.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cred.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cred.position -= Vector2(14, 10)

	vb.modulate.a = 0.0   # fade the menu in
	vb.create_tween().tween_property(vb, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_refresh_info()
	spin = SpinMenu.new()   # bloodline + element spins live here, not in-game
	add_child(spin)
	spin.closed.connect(_refresh_info)
	if GameData.open_customize:   # came from "OPEN SPIN" in the in-game menu
		GameData.open_customize = false
		_open_customize.call_deferred()
	first.grab_focus()

## Hovering or focusing a button shows its one-line description under the mode list.
func _describe(b: Button, text: String) -> void:
	b.mouse_entered.connect(func() -> void: hint.text = b.get_meta("desc", ""))
	b.focus_entered.connect(func() -> void: hint.text = b.get_meta("desc", ""))
	b.set_meta("desc", text)

func _key_for(mode: String) -> int:
	return {"kurama": 1, "fight": 2, "world": 3}.get(mode, 0)

func _refresh_info() -> void:
	var spins := GameData.spins
	custom_btn.text = "CUSTOMIZE  (%d)" % spins if spins > 0 else "CUSTOMIZE"
	custom_btn.set_meta("desc", "Spin bloodlines and elements - %d spins   [4]" % GameData.spins)
	stat.text = "LV %d   ·   %s   ·   Quests %d/%d   ·   Kurama %s" % [
		GameData.level, Bloodline.get_def(GameData.equipped)["name"], GameData.quests_done.size(), Quests.DEFS.size(),
		"defeated" if GameData.kurama_defeated else "undefeated"]

func _open_character_creator() -> void:
	if spin != null:
		spin.open("look")

func _open_multiplayer() -> void:
	get_tree().change_scene_to_file("res://multiplayer_lobby.tscn")

func _open_customize() -> void:
	if spin != null:
		spin.open("bloodline")

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
