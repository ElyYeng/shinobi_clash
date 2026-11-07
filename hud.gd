class_name HUD
extends CanvasLayer

var p: Player
var mode := "fight"
var boss: Enemy = null
var victory := false
var quest_text := ""
var prompt_text := ""

var boss_bar: ProgressBar
var boss_label: Label
var bar: AbilityBar
var quest_visible := true
var msg_label: Label
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

func bind(player: Player) -> void:
	p = player

func toast(text: String) -> void:
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
	var end_target := 0.55 if (p.is_dead or victory) else 0.0
	end_alpha = move_toward(end_alpha, end_target, delta * 0.8)
	end_overlay.color = Color(0.0, 0.0, 0.0, end_alpha)
	sharingan_overlay.visible = p.active_ability == "sharingan"
	# boss bar
	var show_boss := is_instance_valid(boss) and boss.health > 0.0
	boss_bar.visible = show_boss
	boss_ghost.visible = show_boss
	boss_label.visible = show_boss
	if show_boss:
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
		boss_ghost.max_value = boss.max_health
		boss_ghost.value = maxf(boss_bar.value, move_toward(boss_ghost.value, boss_bar.value, boss.max_health * 0.12 * delta))
	quest_label.visible = mode == "world" and quest_visible
	quest_label.text = quest_text
	prompt_label.text = prompt_text
	if is_instance_valid(p.lock_target) and not p.cam.is_position_behind(p.lock_target.global_position):
		lock_label.visible = true
		lock_label.position = p.cam.unproject_position(p.lock_target.global_position + Vector3.UP * 1.2) - Vector2(14, 22)
	else:
		lock_label.visible = false
	if p.is_dead:
		msg_label.text = "DEFEATED\nKills %d\nEnter = retry   M = menu   B = bloodline spin" % p.kills
	elif victory:
		msg_label.text = "VICTORY!\nThe Nine-Tailed Beast has fallen\n+5 spins   (press B)\nEnter = fight again   M = menu"
	else:
		msg_label.text = ""
