class_name KuramaCutscene
extends CanvasLayer
const DURATION := 2.8
var player: Player
var form := 1
var cam: Camera3D
var previous: Camera3D
var hud: CanvasLayer
var hud_visible := true
var old_mode := Node.PROCESS_MODE_INHERIT
var old_invuln := 0.0
var owns_pause := false
var cleaned := false
var clock := 0.0
var front := Vector3.FORWARD
var return_pose := Transform3D.IDENTITY
var title: Label
var bars: Array[ColorRect] = []

static func play(p: Player, count: int) -> void:
	if not is_instance_valid(p) or p.has_meta("kurama_cutscene"):
		return
	var shot := KuramaCutscene.new()
	shot.player = p
	shot.form = clampi(count, 1, 3)
	p.set_meta("kurama_cutscene", shot)
	p.get_tree().root.add_child(shot)

func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous = get_viewport().get_camera_3d()
	old_mode = player.process_mode
	old_invuln = player.invuln
	owns_pause = not NetworkSession.is_online() and not get_tree().paused
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.velocity = Vector3.ZERO
	player.invuln = maxf(old_invuln, 0.2)
	if owns_pause:
		get_tree().paused = true
	if is_instance_valid(player.cloak_fx):
		player.cloak_fx.process_mode = Node.PROCESS_MODE_ALWAYS
	hud = player.get_parent().get("hud") as CanvasLayer
	if is_instance_valid(hud):
		hud_visible = hud.visible
		hud.visible = false
	front = -player.model.global_basis.z.normalized()
	cam = Camera3D.new()
	cam.fov = 48.0
	player.get_parent().add_child(cam)
	cam.global_transform = _shot(0.0)
	return_pose = cam.global_transform
	cam.make_current()
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0
		bar.offset_bottom = 0
		bars.append(bar)
	title = Label.new()
	var beast: Dictionary = GameData.BEASTS[player.kurama_beast]
	title.text = "CLOAK %d\n%s" % [form, ["ONE TAIL • AWAKENING", "TWO TAILS • SURGING CHAKRA", "THREE TAILS • UNLEASHED"][form - 1]] if player.kurama_beast == "kurama" \
		else "%s\nTWO TAILS • BLUE FLAME" % str(beast["name"]).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", beast["title"])
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.025, 0.01))
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	title.anchor_right = 1.0
	title.anchor_top = 0.73
	title.anchor_bottom = 0.73
	title.modulate.a = 0

func _shot(t: float) -> Transform3D:
	var k := smoothstep(0.0, 1.9, t)
	var direction := front.rotated(Vector3.UP, lerpf(-0.55 - form * 0.12, 0.35 + form * 0.15, k))
	var target := player.global_position + Vector3.UP * 1.45
	var pos := player.global_position + direction * lerpf(4.6 + form * 0.3, 4.0 + form * 0.25, k) + Vector3.UP * lerpf(0.85, 1.65, k)
	return Transform3D(Basis.IDENTITY, pos).looking_at(target, Vector3.UP)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_dead or not player.kurama:
		_finish()
		return
	clock += delta
	var fade := smoothstep(0.0, 0.25, clock) * (1.0 - smoothstep(2.0, DURATION, clock))
	var height := get_viewport().get_visible_rect().size.y * 0.09 * fade
	bars[0].offset_bottom = height
	bars[1].offset_top = -height
	title.modulate.a = smoothstep(0.45, 0.8, clock) * fade
	if clock < 2.0:
		cam.global_transform = _shot(clock)
		return_pose = cam.global_transform
	elif is_instance_valid(previous):
		var blend := smoothstep(2.0, DURATION, clock)
		cam.global_transform = return_pose.interpolate_with(previous.global_transform, blend)
		cam.fov = lerpf(48.0, previous.fov, blend)
	if clock >= DURATION:
		_finish()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	_cleanup()
	queue_free()

func _exit_tree() -> void:
	_cleanup()

func _cleanup() -> void:
	if cleaned:
		return
	cleaned = true
	set_process(false)
	if owns_pause:
		get_tree().paused = false
	if is_instance_valid(player):
		player.process_mode = old_mode
		player.invuln = old_invuln
		player.remove_meta("kurama_cutscene")
		if is_instance_valid(player.cloak_fx):
			player.cloak_fx.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(hud):
		hud.visible = hud_visible
	if is_instance_valid(previous) and previous.is_inside_tree():
		previous.make_current()
	if is_instance_valid(cam):
		cam.queue_free()
