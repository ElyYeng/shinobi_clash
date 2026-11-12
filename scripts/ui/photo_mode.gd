class_name PhotoMode
extends Node3D
## Photo mode (F2). A free camera you fly around your character with the HUD hidden:
##   mouse: look   WASD: move   Space / Ctrl: up / down   Shift: faster
##   wheel: zoom (field of view)   Q / E: tilt   1-6: pose your character   H: hide this help
##   Enter / F12: take a photo (saved to the "Screenshots" folder)   F2 / Esc: leave
## Single player freezes time; online the world keeps going (only you stand still).

const POSES := [["idle", "Idle"], ["jutsu", "Jutsu"], ["attack", "Strike"], ["hurt", "Hit"], ["sit", "Sit"], ["walk", "Walk"]]
const SPEED := 6.0

var player: Player
var hud: CanvasLayer
var cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _ui: CanvasLayer
var _help: Label
var _flash: ColorRect
var _old_cam: Camera3D
var _was_paused := false

static func toggle(world: Node, p: Player, h: CanvasLayer) -> void:
	var cur := world.get_node_or_null("PhotoMode") as PhotoMode
	if cur != null:
		cur.leave()
		return
	if p == null or p.is_dead:
		return
	var pm := PhotoMode.new()
	pm.name = "PhotoMode"
	pm.player = p
	pm.hud = h
	pm.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child(pm)

func _ready() -> void:
	_old_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	add_child(cam)
	if _old_cam != null:
		cam.global_transform = _old_cam.global_transform
		cam.fov = _old_cam.fov
		var e := cam.global_basis.get_euler()
		_pitch = e.x
		_yaw = e.y
	cam.current = true
	if hud != null:
		hud.visible = false
	_was_paused = get_tree().paused
	if not NetworkSession.is_active():
		get_tree().paused = true   # freeze the moment
	player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ui = CanvasLayer.new()
	_ui.layer = 60
	add_child(_ui)
	_help = Label.new()
	_help.text = "PHOTO MODE\nMouse look  ·  WASD move  ·  Space/Ctrl up/down  ·  Shift fast\nWheel zoom  ·  Q/E tilt  ·  1-6 pose  ·  H hide help\nEnter / F12: take photo  ·  F2 / Esc: leave"
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_outline_color", Color.BLACK)
	_help.add_theme_constant_override("outline_size", 6)
	_help.position = Vector2(16, 16)
	_ui.add_child(_help)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_flash)

func leave() -> void:
	if not NetworkSession.is_active():
		get_tree().paused = _was_paused
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
		Hero.play(player.model, "idle", true)
	if hud != null and is_instance_valid(hud):
		hud.visible = true
	if _old_cam != null and is_instance_valid(_old_cam):
		_old_cam.current = true
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.fov = clampf(cam.fov - 3.0, 10.0, 110.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.fov = clampf(cam.fov + 3.0, 10.0, 110.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F2, KEY_ESCAPE:
				leave()
			KEY_ENTER, KEY_F12:
				_snap()
			KEY_H:
				_help.visible = not _help.visible
			_:
				var n: int = event.physical_keycode - KEY_1
				if n >= 0 and n < POSES.size() and is_instance_valid(player):
					Hero.play(player.model, POSES[n][0], true)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var dt := delta if delta > 0.0 else 1.0 / 60.0
	var mv := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): mv.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): mv.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_SPACE): mv.y += 1.0
	if Input.is_physical_key_pressed(KEY_CTRL): mv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_Q): _roll += dt * 0.8
	if Input.is_physical_key_pressed(KEY_E): _roll -= dt * 0.8
	var spd := SPEED * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	var b := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var next := cam.global_position + b * mv.normalized() * spd * dt
	if is_instance_valid(player) and next.distance_to(player.global_position) > 40.0:   # stay near your character
		next = player.global_position + (next - player.global_position).limit_length(40.0)
	cam.global_position = next
	cam.global_basis = b * Basis(Vector3.FORWARD, _roll)

## Saves the frame (without the help text) to user://Screenshots and flashes.
func _snap() -> void:
	var help_was := _help.visible
	_help.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_help.visible = help_was
	DirAccess.make_dir_recursive_absolute("user://Screenshots")
	var t := Time.get_datetime_dict_from_system()
	var path := "user://Screenshots/shinobi_%04d%02d%02d_%02d%02d%02d.png" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	img.save_png(path)
	Sfx.play(self, "swing", -6.0)
	_flash.color.a = 0.8
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	var where := Label.new()
	where.text = "Saved: " + ProjectSettings.globalize_path(path)
	where.add_theme_font_size_override("font_size", 14)
	where.add_theme_color_override("font_outline_color", Color.BLACK)
	where.add_theme_constant_override("outline_size", 5)
	where.position = Vector2(16, get_viewport().get_visible_rect().size.y - 40)
	_ui.add_child(where)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(where.queue_free)
