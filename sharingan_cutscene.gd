class_name SharinganCutscene
extends CanvasLayer
## The Sharingan activation close-up (started by SharinganEffect.play_cutscene).
##   (0.35s after the power-up, so its burst has played)
##   0.0s  letterbox bars slide in, camera cuts to the face and slowly pushes in (normal eyes)
##   0.8s  flash + sound, the eyes change (the bloodline's mode "look.eyes": Sharingan, Byakugan,
##         Ketsuryugan ...). Used by every mode with "cutscene": "eyes".
##   1.6s  back to the game camera through the spinning emblem overlay
## Single player: the game is paused meanwhile. Multiplayer: not paused, the player is invulnerable.

const DELAY := 0.35   # let the power-up burst play out before cutting to the face
const DURATION := 1.6
const SWAP_AT := 0.8

var player: Player
var bloodline := "uchiha"
var cam: Camera3D
var flash: ColorRect
var bars: Array[ColorRect] = []
var _paused := false
var _hud: CanvasLayer
var _ap: AnimationPlayer
var _ap_mode := Node.PROCESS_MODE_INHERIT
var _t := 0.0
var _swapped := false
var _front := Vector3.FORWARD
var _aura_energy := -1.0

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	await get_tree().create_timer(DELAY).timeout
	if not is_instance_valid(player) or player.is_dead or not player.powered:
		queue_free()
		return
	_begin()
	set_process(true)

func _begin() -> void:
	var model := player.model
	# Neutral pose so the head faces the camera; the model keeps animating while the game is paused.
	if model.has_meta("anim_player"):
		_ap = model.get_meta("anim_player") as AnimationPlayer
		_ap_mode = _ap.process_mode
		_ap.process_mode = Node.PROCESS_MODE_ALWAYS
	Hero.play(model, "idle", true)
	player.anim_lock = 0.0
	Hero.set_eyes(model, null)   # start with the normal eyes
	_paused = not NetworkSession.is_online()
	_hud = player.get_parent().get("hud")
	if _hud != null:
		_hud.visible = false
	if _paused:
		get_tree().paused = true
	else:
		player.invuln = maxf(player.invuln, DURATION + 0.2)
	# Camera in front of the face, slightly above, looking at the eyes.
	var front := -model.global_transform.basis.z
	front.y = 0.0
	_front = front.normalized() if front.length() > 0.01 else Vector3.FORWARD
	if player.aura != null:   # the power-up light is right next to the face: dim it for the close-up
		_aura_energy = player.aura.light_energy
		player.aura.light_energy = minf(_aura_energy, 0.35)
	cam = Camera3D.new()
	cam.fov = 26.0
	cam.near = 0.02
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	player.get_parent().add_child(cam)
	cam.global_transform = _shot(0.0)
	cam.make_current()
	# Letterbox + flash
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 0)
		bar.offset_top = 0.0 if top else 0.0
		bar.offset_bottom = 0.0
		bar.set_meta("top", top)
		bars.append(bar)
	flash = ColorRect.new()
	var mc: Color = Bloodline.mode(bloodline).get("col", Color(0.9, 0.0, 0.05))
	flash.color = Color(mc.r, mc.g, mc.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_t += delta
	var vh := get_viewport().get_visible_rect().size.y
	var bar_h := vh * 0.12 * clampf(minf(_t / 0.2, (DURATION - _t) / 0.15), 0.0, 1.0)
	for bar in bars:
		if bar.get_meta("top"):
			bar.offset_bottom = bar_h
		else:
			bar.offset_top = -bar_h
	if cam != null and is_instance_valid(cam):
		var k := ease(clampf(_t / DURATION, 0.0, 1.0), 0.4)   # fast push-in that settles
		var tf := _shot(k)
		if _swapped and _t < SWAP_AT + 0.25:   # small shake on activation
			tf.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.006
		cam.global_transform = tf
	if not _swapped and _t >= SWAP_AT:
		_swapped = true
		var m: Dictionary = Bloodline.mode(bloodline)
		var look: Dictionary = m.get("look", {})
		if is_instance_valid(player) and player.powered:
			Hero.apply_mode_look(player.model, look)   # eyes (and anything else the look has)
		if bloodline == "uchiha":
			SharinganEffect.play_sound(get_tree())
		else:
			Sfx.play(player, "power", -2.0)
		flash.color.a = 0.55
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - delta * 1.6)
	if _t >= DURATION:
		_finish()

## Camera for push-in progress k (0..1), aimed at the eyes as they are right now.
func _shot(k: float) -> Transform3D:
	var eyes := Hero.eyes_position(player.model) if is_instance_valid(player) else Vector3.ZERO
	var dist := lerpf(0.9, 0.3, k)
	var pos := eyes + _front * dist + Vector3.UP * lerpf(0.08, 0.01, k)
	return Transform3D(Basis(), pos).looking_at(eyes, Vector3.UP)

func _finish() -> void:
	set_process(false)
	if _paused:
		get_tree().paused = false
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	if _ap != null and is_instance_valid(_ap):
		_ap.process_mode = _ap_mode
	if _aura_energy >= 0.0 and is_instance_valid(player) and player.aura != null:
		player.aura.light_energy = _aura_energy
	if is_instance_valid(player) and player.cam != null:
		player.cam.make_current()
		# make sure the look matches the power state (it may have ended meanwhile in multiplayer)
		Hero.apply_mode_look(player.model, Bloodline.mode(bloodline).get("look", {}) if player.powered else {})
	if cam != null and is_instance_valid(cam):
		cam.queue_free()
	if bloodline == "uchiha":   # the spinning Sharingan emblem
		SharinganEffect.play_activation(get_tree(), false)
	queue_free()
