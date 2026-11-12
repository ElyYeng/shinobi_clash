class_name HUD
extends CanvasLayer

var p: Player
var mode := "fight"
var boss: Enemy = null
var victory := false
var victory_text := "The Nine-Tailed Beast has fallen   -   +5 spins"
var quest_text := ""
var prompt_text := ""

var boss_bar: ProgressBar
var boss_label: Label
var bar: AbilityBar
var quest_visible := true
var msg_label: Label
var end_screen: EndScreen
var spec_label: Label   # "SPECTATING: name" while you watch after dying in a boss fight
var _alive_time := 0.0   # time survived (shown on the defeat screen)
var _dead_time := 0.0
var lock_label: Label
var toast_label: Label
var quest_label: Label
var prompt_label: Label
var sharingan_overlay: ColorRect
var boss_ghost: ProgressBar
var vignette: ColorRect
var vignette_mat: ShaderMaterial
var end_overlay: ColorRect
var end_alpha := 0.0
var flash := 0.0
var last_hp := -1.0

const VIGNETTE_SHADER := """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.35;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = dot(uv, uv) * 2.2;
	float v = smoothstep(0.18, 1.0, d);
	COLOR = vec4(tint.rgb, v * strength);
}
"""

func _ready() -> void:
	sharingan_overlay = ColorRect.new()
	sharingan_overlay.color = Color(0.8, 0.0, 0.05, 0.14)
	sharingan_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sharingan_overlay.visible = false
	add_child(sharingan_overlay)
	sharingan_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# screen vignette (darkens edges, flashes red when hurt)
	var vsh := Shader.new()
	vsh.code = VIGNETTE_SHADER
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = vsh
	vignette = ColorRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.material = vignette_mat
	add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay = ColorRect.new()
	end_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(end_overlay)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Shindo-Life style bottom HUD (key slots + HP / MD / CHI / STM bars)
	bar = AbilityBar.new()
	bar.world_mode = mode == "world"
	add_child(bar)
	var credit := Hero.credit
	if mode == "kurama":
		credit += "\n" + Kurama.CREDIT
	if credit != "":
		var cl := _label(Vector2(0, 0), 11)
		_anchor_bl(cl, 20, 8)
		cl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		cl.text = credit
	# Boss bar (top centre)
	boss_ghost = _bar(Vector2(0, 0), Color(1.0, 0.8, 0.5), Vector2(560, 28), true)
	boss_bar = _bar(Vector2(0, 0), Color(0.95, 0.38, 0.06), Vector2(560, 28), false)
	_anchor_ct(boss_ghost, 54, 560.0)
	_anchor_ct(boss_bar, 54, 560.0)
	for frac in [0.34, 0.67]:   # phase markers
		var tick := ColorRect.new()
		tick.color = Color(0, 0, 0, 0.7)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_bar.add_child(tick)
		tick.position = Vector2(560.0 * frac, 0)
		tick.size = Vector2(3, 28)
	boss_bar.visible = false
	boss_ghost.visible = false
	boss_label = _label(Vector2(0, 0), 22)
	boss_label.text = Kurama.BOSS_NAME
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.custom_minimum_size = Vector2(560, 0)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
	_anchor_ct(boss_label, 20, 560.0)
	boss_label.visible = false
	# Quest tracker (top right)
	quest_label = _label(Vector2(0, 0), 18)
	quest_label.custom_minimum_size = Vector2(320, 0)
	quest_label.anchor_left = 1.0
	quest_label.anchor_right = 1.0
	quest_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quest_label.offset_left = -20.0
	quest_label.offset_right = -20.0
	quest_label.offset_top = 20.0
	quest_label.offset_bottom = 20.0
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	# Talk prompt (bottom centre)
	prompt_label = _label(Vector2(0, 0), 26)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_label.offset_left = 0.0
	prompt_label.offset_right = 0.0
	prompt_label.offset_top = -215.0
	prompt_label.offset_bottom = -215.0
	lock_label = _label(Vector2.ZERO, 32)
	lock_label.text = "◎"
	lock_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	lock_label.visible = false
	toast_label = Label.new()
	add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.position.y = 90
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.modulate.a = 0.0
	end_screen = EndScreen.new()
	add_child(end_screen)
	end_screen.retry.connect(func() -> void: get_tree().reload_current_scene())
	spec_label = Label.new()
	add_child(spec_label)
	spec_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	spec_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	spec_label.position.y -= 170
	spec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spec_label.add_theme_font_override("font", GameMenu.font())
	spec_label.add_theme_font_size_override("font_size", 24)
	spec_label.add_theme_color_override("font_outline_color", Color.BLACK)
	spec_label.add_theme_constant_override("outline_size", 8)
	spec_label.visible = false
	msg_label = Label.new()
	add_child(msg_label)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 48)
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 10)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		quest_visible = not quest_visible
	if event.is_action_pressed("leaderboard"):
		_toggle_board()

# ---------------------------------------------------------------- leaderboard (Tab)
## Everyone in the session ranked by level, top-right of the screen; refreshes while open.
var _board: PanelContainer
var _board_list: VBoxContainer
var _board_t := 0.0

func _toggle_board() -> void:
	if _board == null:
		_board = PanelContainer.new()
		_board.add_theme_stylebox_override("panel", UiStyle.tex_box("frame_roped", [46, 44, 46, 44], [58, 52, 58, 56]))
		_board.custom_minimum_size = Vector2(420, 220)
		_board.position = (get_viewport().get_visible_rect().size - Vector2(300, 260)) * 0.5   # centre of the screen
		add_child(_board)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		_board.add_child(v)
		var t := Label.new()
		t.text = "LEADERBOARD"
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_size_override("font_size", 18)
		t.add_theme_color_override("font_color", Color(0.62, 0.08, 0.05))
		t.add_theme_font_override("font", GameMenu.font())
		v.add_child(t)
		_board_list = VBoxContainer.new()
		_board_list.add_theme_constant_override("separation", 2)
		v.add_child(_board_list)
		_board.visible = false
	_board.visible = not _board.visible
	if _board.visible:
		_board.position = (get_viewport().get_visible_rect().size - Vector2(300, _board.size.y)) * 0.5
		_fill_board()

func _fill_board() -> void:
	for c in _board_list.get_children():
		c.queue_free()
	var rows: Array = []
	var online := NetworkSession.is_active()
	var my_id := multiplayer.get_unique_id() if online else 1
	if online:
		for id in NetworkSession._known_players:
			var lv := GameData.level if int(id) == my_id else int(NetworkSession._known_levels.get(id, 1))
			rows.append({"id": int(id), "name": NetworkSession.name_with_clan(int(id)), "lv": lv})
	else:
		rows.append({"id": 1, "name": NetworkSession.player_name, "lv": GameData.level})
	rows.sort_custom(func(a, b) -> bool:
		return int(a["lv"]) > int(b["lv"]) if int(a["lv"]) != int(b["lv"]) else str(a["name"]) < str(b["name"]))
	var medals := [Color(0.72, 0.5, 0.02), Color(0.38, 0.4, 0.46), Color(0.6, 0.3, 0.1)]   # gold / silver / bronze ink
	for i in rows.size():
		var r: Dictionary = rows[i]
		var row := HBoxContainer.new()
		_board_list.add_child(row)
		var me := int(r["id"]) == my_id
		var col: Color = medals[i] if i < 3 else (Color(0.1, 0.45, 0.12) if me else Color(0.16, 0.1, 0.06))
		for spec in [["#%d" % (i + 1), 34.0, HORIZONTAL_ALIGNMENT_LEFT], [str(r["name"]) + ("  (you)" if me else ""), 0.0, HORIZONTAL_ALIGNMENT_LEFT], ["Lv %d" % int(r["lv"]), 56.0, HORIZONTAL_ALIGNMENT_RIGHT]]:
			var l := Label.new()
			l.text = spec[0]
			l.horizontal_alignment = spec[2]
			l.clip_text = true
			if float(spec[1]) > 0.0:
				l.custom_minimum_size = Vector2(spec[1], 0)
			else:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", col)
			row.add_child(l)
	if not online:
		var n := Label.new()
		n.text = "Host or join a game to see other players"
		n.add_theme_font_size_override("font_size", 12)
		n.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		_board_list.add_child(n)

var minimap: Minimap

# ---------------------------------------------------------------- quest panel (under the minimap)
var _qpanel: PanelContainer
var _qtitle: Label
var _qbody: Label

static func _panel_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.04, 0.78)
	sb.border_color = accent
	sb.border_width_left = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	return sb

func _update_quest_panel() -> void:
	var show := mode == "world" and quest_visible and quest_text != ""
	if _qpanel == null:
		if not show:
			return
		_qpanel = PanelContainer.new()
		_qpanel.add_theme_stylebox_override("panel", UiStyle.tex_box("paper_card_wide", [26, 20, 26, 20], [32, 18, 30, 20]))
		_qpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_qpanel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		_qpanel.add_child(v)
		_qtitle = Label.new()
		_qtitle.add_theme_font_override("font", GameMenu.font())
		_qtitle.add_theme_font_size_override("font_size", 17)
		_qtitle.add_theme_color_override("font_color", Color(0.62, 0.08, 0.05))
		_qtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_qtitle.custom_minimum_size.x = Minimap.SIZE + 2.0   # (width from the start: no tall wrap)
		v.add_child(_qtitle)
		_qbody = Label.new()
		_qbody.add_theme_font_size_override("font_size", 14)
		_qbody.add_theme_color_override("font_color", Color(0.16, 0.1, 0.06))
		_qbody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_qbody.custom_minimum_size.x = Minimap.SIZE + 2.0
		v.add_child(_qbody)
	_qpanel.visible = show
	if not show:
		return
	var lines := quest_text.split("\n", false)
	var t := lines[0] if lines.size() > 0 else ""
	_qtitle.text = t.trim_prefix("QUEST: ")
	_qbody.text = "\n".join(lines.slice(1)) if lines.size() > 1 else ""
	_qbody.visible = _qbody.text != ""
	var w := Minimap.SIZE + 40.0
	_qpanel.reset_size()   # shrink to the text
	var mm_x := get_viewport().get_visible_rect().size.x - Minimap.SIZE - 16.0   # centred under the minimap
	_qpanel.position = Vector2(mm_x + Minimap.SIZE * 0.5 - _qpanel.size.x * 0.5, 16.0 + Minimap.SIZE + 18.0)
	_qpanel.position.x = minf(_qpanel.position.x, get_viewport().get_visible_rect().size.x - _qpanel.size.x - 8.0)

# ---------------------------------------------------------------- party frames (top-left)
var _party: VBoxContainer
var _party_t := 0.0

func _update_party_frames(delta: float) -> void:
	_party_t -= delta
	if _party_t > 0.0:
		return
	_party_t = 0.25
	var online := NetworkSession.is_active()
	if _party == null:
		_party = VBoxContainer.new()
		_party.add_theme_constant_override("separation", 5)
		_party.position = Vector2(16, 16)
		_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_party)
	for c in _party.get_children():
		c.queue_free()
	if not online:
		return
	var my_id := multiplayer.get_unique_id()
	var members: Array = []
	for id in NetworkSession._known_players:
		if int(id) != my_id and NetworkSession._same_party(my_id, int(id)):
			members.append(int(id))
	if members.is_empty():
		return
	var head := Label.new()
	head.text = "PARTY  %d / 4" % (members.size() + 1)
	head.add_theme_font_override("font", GameMenu.font())
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
	head.add_theme_color_override("font_outline_color", Color.BLACK)
	head.add_theme_constant_override("outline_size", 5)
	_party.add_child(head)
	for id in members:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiStyle.tex_box("plate_dark", [22, 10, 22, 10], [16, 7, 16, 8]))
		card.custom_minimum_size = Vector2(210, 0)
		_party.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var nm := Label.new()
		var leader: bool = int(NetworkSession._party_leader.get(id, id)) == int(id)
		nm.text = "%s%s   Lv %d" % ["★ " if leader else "", str(NetworkSession._known_players.get(id, "?")), int(NetworkSession._known_levels.get(id, 1))]
		nm.add_theme_font_size_override("font_size", 14)
		nm.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
		nm.clip_text = true
		v.add_child(nm)
		var av = NetworkSession._avatars.get(id)
		var hp := float(av.get_meta("hp", 1.0)) if av != null and is_instance_valid(av) else 1.0
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.value = hp * 100.0
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.3, 0.85, 0.3) if hp > 0.5 else (Color(0.95, 0.75, 0.2) if hp > 0.25 else Color(0.95, 0.25, 0.2))
		f.set_corner_radius_all(3)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.15, 0.12, 0.1)
		bg.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", f)
		bar.add_theme_stylebox_override("background", bg)
		v.add_child(bar)

func bind(player: Player) -> void:
	p = player
	if minimap == null and player != null:   # round minimap, top-right
		minimap = Minimap.new()
		minimap.player = player
		minimap.world = player.get_parent() as Node3D
		var ph = player.get_parent().get("play_half")
		if ph != null:
			minimap.half = float(ph)
		minimap.position = Vector2(get_viewport().get_visible_rect().size.x - Minimap.SIZE - 16.0, 16.0)
		add_child(minimap)
		get_viewport().size_changed.connect(func() -> void:
			if is_instance_valid(minimap):
				minimap.position.x = get_viewport().get_visible_rect().size.x - Minimap.SIZE - 16.0)

func toast(text: String) -> void:
	text = Fx.keyfix(text)
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var t := toast_label.create_tween()
	t.tween_interval(2.8)
	t.tween_property(toast_label, "modulate:a", 0.0, 0.6)

func _bar(pos: Vector2, color: Color, size := Vector2(320, 22), is_back := false) -> ProgressBar:
	var b := ProgressBar.new()
	add_child(b)
	b.position = pos
	b.custom_minimum_size = size
	b.size = size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	if not is_back:
		fill.border_width_top = 3
		fill.border_color = color.lightened(0.45)
	b.add_theme_stylebox_override("fill", fill)
	var bg: StyleBox
	if is_back:   # the back bar (trailing "damage ghost") also carries the dark frame
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.0, 0.0, 0.0, 0.6)
		f.set_corner_radius_all(6)
		f.set_border_width_all(2)
		f.border_color = Color(1, 1, 1, 0.35)
		bg = f
	else:
		bg = StyleBoxEmpty.new()
	b.add_theme_stylebox_override("background", bg)
	return b

func _bar_text(bar: ProgressBar, prefix: String) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = prefix
	bar.add_child(l)
	l.position = Vector2(8, -3 if bar.size.y > 20.0 else -4)
	return l

func _anchor_bl(c: Control, x: float, bottom: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.offset_left = x
	c.offset_right = x
	c.offset_top = -bottom
	c.offset_bottom = -bottom

func _anchor_ct(c: Control, y: float, width: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = y
	c.offset_bottom = y
	c.custom_minimum_size.x = width

func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	add_child(l)
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l

func _process(delta: float) -> void:
	if _board != null and _board.visible:   # keep the leaderboard live while it's open
		_board_t -= delta
		if _board_t <= 0.0:
			_board_t = 1.0
			_fill_board()
	if p == null:
		return
	bar.update_from(p)
	# vignette: dark edges, red flash when hit, red pulse at low health
	if last_hp >= 0.0 and p.health < last_hp - 0.5:
		flash = 1.0
	last_hp = p.health
	flash = maxf(0.0, flash - delta * 2.2)
	var low := 0.0
	if not p.is_dead and p.health < p.max_health * 0.3:
		low = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
	var red := clampf(maxf(flash, low * 0.6), 0.0, 1.0)
	vignette_mat.set_shader_parameter("tint", Color(0.0, 0.0, 0.0).lerp(Color(0.85, 0.02, 0.04), red))
	vignette_mat.set_shader_parameter("strength", 0.38 + red * 0.55)
	var end_target := 0.55 if ((p.is_dead and not p.spectating) or victory) else 0.0
	end_alpha = move_toward(end_alpha, end_target, delta * 0.8)
	end_overlay.color = Color(0.0, 0.0, 0.0, end_alpha)
	sharingan_overlay.visible = p.eye_overlay()
	# boss bar
	var show_boss := is_instance_valid(boss) and boss.health > 0.0
	boss_bar.visible = show_boss
	boss_ghost.visible = show_boss
	boss_label.visible = show_boss
	if show_boss:
		var bt = boss.get("boss_title")
		boss_label.text = str(bt) if bt != null else Kurama.BOSS_NAME
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
		boss_ghost.max_value = boss.max_health
		boss_ghost.value = maxf(boss_bar.value, move_toward(boss_ghost.value, boss_bar.value, boss.max_health * 0.12 * delta))
	quest_label.visible = false   # (shown in the styled quest panel instead)
	_update_quest_panel()
	_update_party_frames(delta)
	prompt_label.text = Fx.keyfix(prompt_text)
	if is_instance_valid(p.lock_target) and not p.cam.is_position_behind(p.lock_target.global_position):
		lock_label.visible = true
		lock_label.position = p.cam.unproject_position(p.lock_target.global_position + Vector3.UP * 1.2) - Vector2(14, 22)
	else:
		lock_label.visible = false
	msg_label.text = ""
	if p.is_dead:
		_dead_time += delta
		if p.spectating:
			end_screen.visible = false
			spec_label.visible = true
			spec_label.text = "SPECTATING:  %s\n[A] / [D] or click: switch    [Esc]: back    [Enter]: retry" % p.spectate_name()
		elif _dead_time > 1.1:   # let the body fall first
			spec_label.visible = false
			if end_screen.is_shown():
				end_screen.visible = true
			var t := int(_alive_time)
			var boss_fight := mode == "kurama" or mode == "uchiha"
			if not end_screen.spectate.is_connected(p.start_spectate):
				end_screen.spectate.connect(p.start_spectate)
			end_screen.show_end("DEFEATED", false, "Get back up, shinobi.", [["KILLS", p.kills],
				["LEVEL", GameData.level], ["TIME", "%d:%02d" % [t / 60, t % 60]]], boss_fight)
	elif victory:
		end_screen.show_end("VICTORY", true, victory_text,
			[["KILLS", p.kills], ["LEVEL", GameData.level]])
	else:
		_alive_time += delta
		_dead_time = 0.0
		spec_label.visible = false
		if end_screen.visible:
			end_screen.hide_end()
