extends Control
## Main menu: pick what you want to play (keys 1-6 work too), or CUSTOMIZE to spin bloodlines and elements.
## Styled like the in-game UI (UiStyle): black ink ribbons for the modes, green buttons for the rest.

const MODES := [
	["MAIN GAME", "world", "Konoha (greybox) - talk to villagers and take on quests"],
	["FIGHT", "fight", "Arena battle against shinobi in the village"],
	["KURAMA BOSS", "kurama", "Face the Nine-Tailed Beast"],
	["UCHIHA BOSS", "uchiha", "A rogue Uchiha of the Akatsuki - Sharingan and Susanoo"],
	["AKATSUKI CANYON", "akatsuki", "Free roam the Akatsuki canyon and its river"],
]

var spin: SpinMenu
var stat: Label
var custom_btn: Button
var hint: Label
var modes_page: VBoxContainer
var settings_page: VBoxContainer
var _main_page: VBoxContainer

func _ready() -> void:
	GameData.load_data()
	Fx.setup_inputs()   # (after loading: the saved keybind scheme decides the keys)
	Graphics.apply(get_tree())   # saved graphics preset (Settings)
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
	var online := NetworkSession.is_active()

	# three pages in the same column: the main buttons, the single-player modes, settings
	var main_page := _page(vb)
	var sp_btn := UiStyle.ribbon_button(main_page, "PLAY (PARTY)" if online else "SINGLE PLAYER", 30)
	sp_btn.pressed.connect(func() -> void: _show(modes_page))
	_describe(sp_btn, "Pick a mode - your party travels with you" if online else "Play alone: Konoha, the Arena, bosses, the Akatsuki canyon")
	var multi_btn := UiStyle.ribbon_button(main_page, "LEAVE SESSION" if online else "MULTIPLAYER", 30)
	multi_btn.pressed.connect(_open_multiplayer)
	_describe(multi_btn, "Disconnect from the multiplayer session   [5]" if online else "Host or join friends over Radmin VPN   [5]")
	var set_btn := UiStyle.ribbon_button(main_page, "SETTINGS", 30)
	set_btn.pressed.connect(func() -> void: _show(settings_page))
	_describe(set_btn, "Volume, keybinds, fullscreen")
	hint = UiStyle.label(vb, "", 16, Color(1.0, 0.86, 0.6), 6)
	hint.custom_minimum_size = Vector2(0, 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	main_page.add_child(row)
	main_page.move_child(row, main_page.get_child_count() - 1)
	custom_btn = UiStyle.text_button(row, "CUSTOMIZE")
	custom_btn.pressed.connect(_open_customize)
	var creator_btn := UiStyle.text_button(row, "CHARACTER")
	creator_btn.pressed.connect(_open_character_creator)
	_describe(creator_btn, "Your look - hair, colours, shirt and pants   [6]")
	var quit := UiStyle.text_button(row, "QUIT")
	quit.pressed.connect(get_tree().quit)
	_describe(quit, "")

	modes_page = _page(vb)
	for i in MODES.size():
		var m: Array = MODES[i]
		var b := UiStyle.ribbon_button(modes_page, m[0], 26)
		b.pressed.connect(_play.bind(m[1]))
		_describe(b, "%s   [%d]" % [m[2], _key_for(m[1])])
	var back1 := UiStyle.text_button(modes_page, "< BACK")
	back1.pressed.connect(func() -> void: _show(main_page))
	_describe(back1, "")

	settings_page = _page(vb)
	_build_settings(settings_page)
	var back2 := UiStyle.text_button(settings_page, "< BACK")
	back2.pressed.connect(func() -> void: _show(main_page))
	_describe(back2, "")
	_main_page = main_page
	_show(main_page)
	vb.move_child(hint, vb.get_child_count() - 1)

	UiStyle.spacer(vb, 6)
	stat = UiStyle.label(vb, "", 15, Color(0.86, 0.84, 0.8), 6)
	var first := sp_btn

	var cred := UiStyle.label(self, Hero.CREDIT + "\n" + Kurama.CREDIT, 11, Color(0.6, 0.6, 0.65), 4)
	cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cred.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cred.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cred.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cred.position -= Vector2(14, 10)

	vb.modulate.a = 0.0   # fade the menu in
	vb.create_tween().tween_property(vb, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_refresh_info()
	if online:   # travelled here with the party: picking a mode takes the whole party there
		var n := NetworkSession.party_member_count()
		hint.text = ("ONLINE - party of %d. Pick a mode and your party travels with you." % n) if NetworkSession._is_party_leader() \
			else "ONLINE - in a party. Your party leader picks where you go next."
		if not NetworkSession.travel_refused.is_connected(_on_travel_refused):
			NetworkSession.travel_refused.connect(_on_travel_refused)
	spin = SpinMenu.new()   # bloodline + element spins live here, not in-game
	add_child(spin)
	spin.closed.connect(_refresh_info)
	if GameData.open_customize:   # came from "OPEN SPIN" in the in-game menu
		GameData.open_customize = false
		_open_customize.call_deferred()
	first.grab_focus()

func _page(parent: Node) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	parent.add_child(page)
	return page

## Shows one page (main / modes / settings) and focuses its first button.
func _show(page: VBoxContainer) -> void:
	for pg in [_main_page, modes_page, settings_page]:
		if pg != null:
			pg.visible = pg == page
	if page == null:
		return
	page.visible = true
	hint.text = ""
	for c in page.get_children():
		if c is Button:
			(c as Button).grab_focus.call_deferred()
			break

func _build_settings(page: VBoxContainer) -> void:
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	page.add_child(vol_row)
	var vol_lbl := UiStyle.label(vol_row, "VOLUME", 22, Color(1, 1, 1), 6)
	vol_lbl.custom_minimum_size = Vector2(150, 0)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 100.0
	vol.step = 1.0
	vol.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	vol.custom_minimum_size = Vector2(260, 28)
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001) / 100.0)))
	vol_row.add_child(vol)
	var gfx := UiStyle.ribbon_button(page, "", 24)
	var refresh_gfx := func() -> void: gfx.text = "GRAPHICS: %s" % Graphics.label(GameData.graphics)
	refresh_gfx.call()
	gfx.pressed.connect(func() -> void:   # Auto -> Low -> Medium -> High -> Auto
		GameData.graphics = Graphics.PRESETS[(Graphics.PRESETS.find(GameData.graphics) + 1) % Graphics.PRESETS.size()]
		GameData.save()
		Graphics.apply(get_tree())
		refresh_gfx.call()
		hint.text = _gfx_desc())
	_describe(gfx, _gfx_desc())
	var keys := UiStyle.ribbon_button(page, "", 24)
	var refresh_keys := func() -> void: keys.text = "KEYBINDS: %s" % ("MODERN" if GameData.key_scheme == "modern" else "CLASSIC")
	refresh_keys.call()
	keys.pressed.connect(func() -> void:
		GameData.key_scheme = "classic" if GameData.key_scheme == "modern" else "modern"
		GameData.save()
		Fx.setup_inputs()
		refresh_keys.call())
	_describe(keys, "Classic: Q dash, C charge, Z beast.  Modern: hotbar on 1-6 / Z X C V B N / Q E R F T G")
	var fs := UiStyle.ribbon_button(page, "", 24)
	var refresh_fs := func() -> void: fs.text = "FULLSCREEN: %s" % ("ON" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "OFF")
	refresh_fs.call()
	fs.pressed.connect(func() -> void:
		var on := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if on else DisplayServer.WINDOW_MODE_FULLSCREEN)
		refresh_fs.call())
	_describe(fs, "Switch between fullscreen and a window")

func _gfx_desc() -> String:
	return {"low": "Low: lower resolution (sharpened), hard shadows, no ambient occlusion / fog / glow - fastest",
		"medium": "Medium: slightly lower resolution, softer shadows, light ambient occlusion and glow",
		"high": "High: full resolution, 2x anti-aliasing, sharp long-range shadows, all effects"}.get(Graphics.resolved(), "") \
		+ ("   (Auto picked this for your graphics card)" if GameData.graphics == "auto" else "")

## Hovering or focusing a button shows its one-line description under the mode list.
func _describe(b: Button, text: String) -> void:
	b.mouse_entered.connect(func() -> void: hint.text = b.get_meta("desc", ""))
	b.focus_entered.connect(func() -> void: hint.text = b.get_meta("desc", ""))
	b.set_meta("desc", text)

func _key_for(mode: String) -> int:
	return {"kurama": 1, "fight": 2, "world": 3, "uchiha": 7, "akatsuki": 8}.get(mode, 0)

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
	if NetworkSession.is_active():   # in a session (came here with the party): leave it
		NetworkSession.disconnect_session()
		get_tree().reload_current_scene()
		return
	get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")

func _on_travel_refused(message: String) -> void:
	if is_instance_valid(hint):
		hint.text = message

func _open_customize() -> void:
	if spin != null:
		spin.open("bloodline")

func _play(mode: String) -> void:
	GameData.boss_from_world = false
	if NetworkSession.is_active():   # online: the party travels together (leader's choice)
		NetworkSession.travel(mode)
		return
	GameData.mode = mode
	LoadingScreen.go(get_tree(), "res://scenes/main.tscn")

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
			KEY_7:
				_play("uchiha")
			KEY_8:
				_play("akatsuki")
