class_name HatakeCutscene
extends CanvasLayer
## Hatake's local activation: anticipation, left-eye reveal, quiet hold, camera return.
## Uses the real character/eye texture. Never changes global time scale or online pause.

const REVEAL_AT := 1.05
const RETURN_AT := 2.25
const DURATION := 2.95
const OWNER_META := "hatake_cutscene"

var player: Player
var _scene: Node
var _camera: Camera3D
var _previous_camera: Camera3D
var _hud: CanvasLayer
var _hud_visible := true
var _player_mode := Node.PROCESS_MODE_INHERIT
var _ap: AnimationPlayer
var _ap_mode := Node.PROCESS_MODE_INHERIT
var _was_paused := false
var _owns_pause := false
var _old_invuln := 0.0
var _aura_energy := 0.0
var _aura_visible := false
var _begun := false
var _cleaned := false
var _revealed := false
var _time := 0.0
var _front := Vector3.FORWARD
var _right := Vector3.RIGHT
var _return_transform := Transform3D.IDENTITY
var _return_fov := 30.0
var _bars: Array[ColorRect] = []
var _veil: ColorRect
var _flash: ColorRect
var _eye_light: OmniLight3D
var _sound: AudioStreamPlayer
var _hidden_fx: Array[Node3D] = []

static func play(subject: Player) -> void:
	if not is_instance_valid(subject) or not is_instance_valid(subject.model):
		return
	if subject.has_meta(OWNER_META):
		return
	var shot := HatakeCutscene.new()
	shot.player = subject
	subject.set_meta(OWNER_META, shot)
	subject.get_tree().root.add_child(shot)

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _valid_subject():
		queue_free()
		return
	_scene = player.get_parent()
	_previous_camera = get_viewport().get_camera_3d()
	_player_mode = player.process_mode
	_old_invuln = player.invuln
	_was_paused = get_tree().paused
	_owns_pause = not NetworkSession.is_online() and not _was_paused
	_begun = true
	# Freeze only the local character online. RPCs and the rest of the match keep running.
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.velocity = Vector3.ZERO
	player.invuln = maxf(_old_invuln, 0.2)
	if _owns_pause:
		get_tree().paused = true
	_hud = _scene.get("hud") as CanvasLayer
	if is_instance_valid(_hud):
		_hud_visible = _hud.visible
		_hud.visible = false
	if player.model.has_meta("anim_player"):
		_ap = player.model.get_meta("anim_player") as AnimationPlayer
		if is_instance_valid(_ap):
			_ap_mode = _ap.process_mode
			_ap.process_mode = Node.PROCESS_MODE_ALWAYS
	Hero.play(player.model, "idle", true)
	Hero.apply_mode_look(player.model, {})
	# A held C can leave its charging shell alive; keep it out of the face shot.
	for effect in [player.pmode_fx, player.get("_charge_fx")]:
		if is_instance_valid(effect) and effect is Node3D and effect.visible:
			_hidden_fx.append(effect)
			effect.visible = false
	if is_instance_valid(player.aura):
		_aura_energy = player.aura.light_energy
		_aura_visible = player.aura.visible
		player.aura.visible = false
	_front = -player.model.global_basis.z
	_front.y = 0.0
	_front = _front.normalized() if _front.length_squared() > 0.001 else Vector3.FORWARD
	_right = _front.cross(Vector3.UP).normalized()
	_camera = Camera3D.new()
	_camera.near = 0.015
	_camera.fov = 34.0
	_scene.add_child(_camera)
	_camera.global_transform = _portrait(0.0)
	_return_transform = _camera.global_transform
	_return_fov = _camera.fov
	_camera.make_current()
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(1.0, 0.06, 0.12)
	_eye_light.omni_range = 0.55
	_eye_light.light_energy = 0.0
	_scene.add_child(_eye_light)
	_build_overlay()

func _valid_subject() -> bool:
	return is_instance_valid(player) and player.is_inside_tree() and not player.is_dead \
		and player.powered and is_instance_valid(player.model)

func _build_overlay() -> void:
	_veil = _rect(Color.WHITE)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.22, 1.35, length(p));
	COLOR = vec4(0.012, 0.019, 0.035, edge * strength);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_veil.material = material
	_flash = _rect(Color(1.0, 0.12, 0.18, 0.0))
	for top in [true, false]:
		var bar := _rect(Color.BLACK)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		_bars.append(bar)

func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

func _input(event: InputEvent) -> void:
	if _begun and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_finish()

func _process(delta: float) -> void:
	if not _begun:
		return
	if not _valid_subject() or not is_instance_valid(_scene) or not _scene.is_inside_tree():
		_finish()
		return
	_time += delta
	var envelope := smoothstep(0.0, 0.3, _time) * (1.0 - smoothstep(RETURN_AT, DURATION, _time))
	var height := get_viewport().get_visible_rect().size.y * 0.105 * envelope
	_bars[0].offset_bottom = height
	_bars[1].offset_top = -height
	(_veil.material as ShaderMaterial).set_shader_parameter("strength", envelope * 0.65)
	if not _revealed and _time >= REVEAL_AT:
		_reveal()
	if _revealed:
		# Open the actual left eyelid over 180 ms; the right eye keeps its normal iris.
		player.model.set_meta("eye_closed", 1.0 - smoothstep(REVEAL_AT, REVEAL_AT + 0.18, _time))
		var blink := player.model.get_node_or_null("FaceBlink") as FaceBlink
		if blink != null:
			blink.refresh()
	var pulse := maxf(0.0, 1.0 - (_time - REVEAL_AT) / 0.38) if _revealed else 0.0
	_flash.color.a = pulse * pulse * 0.16
	_eye_light.light_energy = pulse * 0.7
	_eye_light.global_position = _eye_position() + _front * 0.12
	if _time < RETURN_AT:
		_camera.global_transform = _portrait(_time)
		_camera.fov = lerpf(34.0, 27.0, smoothstep(0.0, REVEAL_AT, _time))
		_return_transform = _camera.global_transform
		_return_fov = _camera.fov
	elif is_instance_valid(_previous_camera):
		var blend := smoothstep(RETURN_AT, DURATION, _time)
		_camera.global_transform = _return_transform.interpolate_with(_previous_camera.global_transform, blend)
		_camera.fov = lerpf(_return_fov, _previous_camera.fov, blend)
	if _time >= DURATION:
		_finish()

func _eye_position() -> Vector3:
	# Anatomical left is screen-right when facing the character.
	return Hero.eyes_position(player.model) - _right * 0.035

func _portrait(t: float) -> Transform3D:
	var approach := smoothstep(0.0, REVEAL_AT, t)
	var settle := smoothstep(REVEAL_AT, RETURN_AT, t)
	var target := Hero.eyes_position(player.model).lerp(_eye_position(), approach)
	var distance := lerpf(1.05, 0.43, approach) - settle * 0.035
	var side := lerpf(0.28, 0.015, approach)
	var position := target + _front * distance + _right * side + Vector3.UP * lerpf(0.045, 0.005, approach)
	return Transform3D(Basis.IDENTITY, position).looking_at(target, Vector3.UP)

func _reveal() -> void:
	_revealed = true
	Hero.apply_mode_look(player.model, player.pmode.get("look", {}))
	# Own the audio so scene changes cannot leave an orphaned cue.
	if ResourceLoader.exists(SharinganEffect.SOUND_PATH):
		_sound = AudioStreamPlayer.new()
		_sound.stream = load(SharinganEffect.SOUND_PATH) as AudioStream
		_sound.volume_db = -5.0
		add_child(_sound)
		_sound.play()

func _finish() -> void:
	_cleanup()
	queue_free()

func _exit_tree() -> void:
	_cleanup()

func _cleanup() -> void:
	if _cleaned:
		return
	_cleaned = true
	set_process(false)
	if _begun:
		if _owns_pause:
			get_tree().paused = _was_paused
		if is_instance_valid(_hud):
			_hud.visible = _hud_visible
		if is_instance_valid(_ap):
			_ap.process_mode = _ap_mode
		if is_instance_valid(player):
			player.process_mode = _player_mode
			player.invuln = _old_invuln
			player.anim_lock = 0.0
			if is_instance_valid(player.aura):
				player.aura.light_energy = _aura_energy
				player.aura.visible = _aura_visible
			if is_instance_valid(player.model):
				Hero.apply_mode_look(player.model, player.pmode.get("look", {}) if player.powered and not player.is_dead else {})
		for effect in _hidden_fx:
			if is_instance_valid(effect):
				effect.visible = true
		if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
			_previous_camera.make_current()
	if is_instance_valid(player) and player.get_meta(OWNER_META, null) == self:
		player.remove_meta(OWNER_META)
	for node in [_camera, _eye_light]:
		if is_instance_valid(node):
			node.queue_free()
