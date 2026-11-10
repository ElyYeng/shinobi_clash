class_name TransformCutscene
extends CanvasLayer
## Full-body transformation cutscene for bloodline power-ups with an outfit / glow look
## (Bloodline mode "cutscene": "body", e.g. Uzumaki's Kurama Ink Mode).
##   0.0s  letterbox, normal look; camera low in front, starts circling while chakra gathers
##   1.0s  flash + shockwave + burst: the power-up look (outfit, glowing hair) switches on
##   2.0s  back to the game camera
## Single player: the game is paused meanwhile. Multiplayer: not paused, the player is invulnerable.

const DELAY := 0.65   # let the power-up burst (0.6 s) finish first - pausing would freeze it on screen
const DURATION := 2.0
const SWAP_AT := 1.0

var player: Player
var look: Dictionary = {}
var color := Color(1.0, 0.78, 0.3)
var cam: Camera3D
var flash: ColorRect
var bars: Array[ColorRect] = []
var fx_root: Node3D             # effects live here and keep animating while the game is paused
var _paused := false
var _hud: CanvasLayer
var _ap: AnimationPlayer
var _ap_mode := Node.PROCESS_MODE_INHERIT
var _t := 0.0
var _swapped := false
var _front := Vector3.FORWARD
var _gather_t := 0.0

static func play(p: Player, mode: Dictionary) -> void:
	if p == null or not is_instance_valid(p) or p.model == null:
		return
	var cs := TransformCutscene.new()
	cs.player = p
	cs.look = mode.get("look", {})
	cs.color = mode.get("col", cs.color)
	p.get_tree().root.add_child(cs)

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
	Hero.apply_mode_look(model, {})   # start in the normal look; it switches on at SWAP_AT
	if model.has_meta("anim_player"):
		_ap = model.get_meta("anim_player") as AnimationPlayer
		_ap_mode = _ap.process_mode
		_ap.process_mode = Node.PROCESS_MODE_ALWAYS
	Hero.play(model, "idle", true)
	player.anim_lock = 0.0
	_paused = not NetworkSession.is_online()
	if _paused:
		get_tree().paused = true
	else:
		player.invuln = maxf(player.invuln, DURATION + 0.3)
	_hud = player.get_parent().get("hud")
	if _hud != null:
		_hud.visible = false
	var front := -model.global_transform.basis.z
	front.y = 0.0
	_front = front.normalized() if front.length() > 0.01 else Vector3.FORWARD
	fx_root = Node3D.new()
	fx_root.process_mode = Node.PROCESS_MODE_ALWAYS
	player.get_parent().add_child(fx_root)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	player.get_parent().add_child(cam)
	cam.global_transform = _shot(0.0)
	cam.make_current()
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		bar.set_meta("top", top)
		bars.append(bar)
	flash = ColorRect.new()
	flash.color = Color(1.0, 0.92, 0.6, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Sfx.play(player, "power", -4.0)

## Camera for progress k (0..1): low in front, circling ~110 degrees and rising, looking at the chest.
func _shot(k: float) -> Transform3D:
	var center := player.global_position + Vector3.UP * lerpf(0.9, 1.25, k)
	var ang := lerpf(-0.9, 1.0, ease(k, 0.6))
	var dir := _front.rotated(Vector3.UP, ang)
	var dist := lerpf(3.4, 2.6, k)
	var pos := player.global_position + dir * dist + Vector3.UP * lerpf(0.35, 1.5, k)
	return Transform3D(Basis(), pos).looking_at(center, Vector3.UP)

func _process(delta: float) -> void:
	_t += delta
	var vh := get_viewport().get_visible_rect().size.y
	var bar_h := vh * 0.11 * clampf(minf(_t / 0.2, (DURATION - _t) / 0.15), 0.0, 1.0)
	for bar in bars:
		if bar.get_meta("top"):
			bar.offset_bottom = bar_h
		else:
			bar.offset_top = -bar_h
	if is_instance_valid(cam) and is_instance_valid(player):
		var tf := _shot(clampf(_t / DURATION, 0.0, 1.0))
		if _swapped and _t < SWAP_AT + 0.3:
			tf.origin += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.03
		cam.global_transform = tf
	# chakra gathering before the swap: sparks drawn in towards the body
	if not _swapped and is_instance_valid(player):
		_gather_t -= delta
		if _gather_t <= 0.0:
			_gather_t = 0.1
			var a := randf() * TAU
			var p := player.global_position + Vector3(cos(a) * 1.5, randf_range(0.2, 1.9), sin(a) * 1.5)
			Vfx.burst(fx_root, p, color, 3, 1.2, 0.05, 0.3, 0.0)
	if not _swapped and _t >= SWAP_AT:
		_swapped = true
		if is_instance_valid(player) and player.powered:
			Hero.apply_mode_look(player.model, look)
		var c := player.global_position + Vector3.UP
		Vfx.burst(fx_root, c, color, 24, 9.0, 0.12, 0.45, 0.0)
		Vfx.shockwave(fx_root, player.global_position + Vector3.UP * 0.1, color, 7.0, 0.5)
		Vfx.shockwave(fx_root, c, Color(1, 1, 1), 3.5, 0.35)
		Sfx.play(player, "power", 0.0)
		flash.color.a = 0.6
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - delta * 1.8)
	if _t >= DURATION:
		_finish()

func _finish() -> void:
	set_process(false)
	if _paused:
		get_tree().paused = false
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	if _ap != null and is_instance_valid(_ap):
		_ap.process_mode = _ap_mode
	if is_instance_valid(player):
		if player.cam != null:
			player.cam.make_current()
		# make sure the look matches the power state (e.g. it ended meanwhile in multiplayer)
		Hero.apply_mode_look(player.model, look if player.powered else {})
	if cam != null and is_instance_valid(cam):
		cam.queue_free()
	if fx_root != null and is_instance_valid(fx_root):
		var r := fx_root
		r.get_tree().create_timer(1.5).timeout.connect(r.queue_free)
	queue_free()
