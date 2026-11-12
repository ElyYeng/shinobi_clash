class_name Susanoo
extends Node3D
## The skeletal Susanoo (Uchiha, hold C). Pure visual: model + chakra shader + animations, used by
## the local player and by remote avatars. The player script does the damage (player.gd).
## Model: assets/susanoo/susanoo.glb - animations idle / Leftpunch / rightpunch / slampunch.

## Susanoo colours - every player rolls one at random the first time (GameData.susanoo_color).
const PALETTE := [
	Color(0.55, 0.25, 1.0),   # purple
	Color(0.2, 0.5, 1.0),     # blue
	Color(1.0, 0.15, 0.2),    # red
	Color(0.2, 0.95, 0.45),   # green
	Color(1.0, 0.55, 0.1),    # orange
	Color(1.0, 0.88, 0.2),    # yellow
	Color(0.2, 0.95, 1.0),    # cyan
	Color(1.0, 0.35, 0.75),   # pink
	Color(0.9, 0.95, 1.0),    # white
]
const NAMES := ["Purple", "Blue", "Red", "Green", "Orange", "Yellow", "Cyan", "Pink", "White"]
const SCALE := 1.3
const ANIMS := {"lpunch": "Leftpunch", "rpunch": "rightpunch", "slam": "slampunch"}
const SPEED := {"lpunch": 1.5, "rpunch": 1.5, "slam": 1.25}
const IMPACT := 1.1    # seconds into each attack animation (at speed 1) where the hit lands

## Sounds (assets/susanoo/sfx, cut from the Susanoo sound pack). `peak` = seconds into the clip
## where it's loudest - hits are timed so that lands on the impact frame.
const SFX := "res://assets/susanoo/sfx/"
const HITS := [{"file": "punch_hit_a.ogg", "peak": 0.36}, {"file": "punch_hit_b.ogg", "peak": 0.24}]
const SLAM_PEAK := 1.48

var color := Color.WHITE
var follow: Node3D       # model whose facing we copy
var ap: AnimationPlayer
var _mats: Array[ShaderMaterial] = []
var _fade := 0.0
var _dying := false
var _hit_variant := 0
var _aura: AuraShell

static var _noise: NoiseTexture2D

## Shared seamless noise for the chakra fire (generated once).
static func fire_noise() -> NoiseTexture2D:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.012
		fn.fractal_octaves = 4
		fn.fractal_gain = 0.55
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.generate_mipmaps = true
		_noise.noise = fn
	return _noise

## Fixed anime colours for other Mangekyo users (sent as colour index 100 + n):
## 100 = Kakashi's blue, 101 = Shisui's green.
## Form 2 = the skeletal Susanoo (everyone). Form 3 = Shisui's armoured Susanoo (Mangekyo, hold C + 3)
## with glowing yellow eyes; its one attack animation plays for every attack.
const FORM3 := "res://assets/susanoo/ShisuiSusanooForm2.glb"
const FORM3_ATTACK := "4ssiawatk01"
const FORM3_USERS := ["mangekyo"]
const FORM3_DMG := 1.4      # form 3 hits harder...
const FORM3_DRAIN := 1.5    # ...and burns chakra faster
const EYE_COLOR := Color(1.0, 0.85, 0.2)
var form := 2

const ANIME_COLORS := [Color(0.25, 0.62, 1.0), Color(0.22, 0.85, 0.42)]
const ANIME_BASE := 100

static func palette_color(i: int) -> Color:
	if i >= ANIME_BASE and i < ANIME_BASE + ANIME_COLORS.size():
		return ANIME_COLORS[i - ANIME_BASE]
	return PALETTE[posmod(i, PALETTE.size())]

## The Susanoo colour for a bloodline: Hatake = Kakashi's blue, Mangekyo = Shisui's green,
## Uchiha = your own random colour.
static func color_index_for(bloodline: String) -> int:
	match bloodline:
		"hatake": return ANIME_BASE
		"mangekyo": return ANIME_BASE + 1
	return my_color_index()

const USERS := ["uchiha", "hatake", "mangekyo"]   # bloodlines with a Susanoo (hold C + 2)

## Your colour index - rolled randomly once and saved.
static func my_color_index() -> int:
	if GameData.susanoo_color < 0 or GameData.susanoo_color >= PALETTE.size():
		GameData.susanoo_color = randi() % PALETTE.size()
		GameData.save()
	return GameData.susanoo_color

## Rolls a new random colour (never the same one again) and saves it. Customize > ROLL.
static func reroll_color() -> int:
	var cur := my_color_index()
	var n := randi() % (PALETTE.size() - 1)
	GameData.susanoo_color = n if n < cur else n + 1
	GameData.save()
	return GameData.susanoo_color

## Seconds from starting an attack to its hit landing.
static func impact_delay(kind: String) -> float:
	return IMPACT / float(SPEED.get(kind, 1.0))

static func create(col: Color, follow_model: Node3D, form_ := 2) -> Susanoo:
	var s := Susanoo.new()
	s.form = form_
	s.name = "Susanoo"
	s.color = col
	s.follow = follow_model
	return s

func _ready() -> void:
	var m: Node3D = load(FORM3 if form == 3 else "res://assets/susanoo/susanoo.glb").instantiate()
	add_child(m)
	m.rotation.y = PI          # the model faces +Z, characters face -Z
	scale = Vector3.ONE * SCALE * 0.3
	var sh := load("res://shaders/susanoo.gdshader") as Shader
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var src := (mi as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("color", color)
		if src != null and src.albedo_texture != null:
			mat.set_shader_parameter("detail", src.albedo_texture)
		mat.set_shader_parameter("fade", 0.0)
		mat.set_shader_parameter("noise", fire_noise())
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats.append(mat)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		ap = aps[0]
		var idle := ap.get_animation("idle")
		if idle != null:
			idle.loop_mode = Animation.LOOP_LINEAR
		ap.animation_finished.connect(func(_n: StringName) -> void: ap.play("idle", 0.35))
		ap.play("idle")
	# chakra aura around the whole Susanoo (Aura 3D shell, follows its animation)
	_aura = AuraShell.make(self, m, color, color.lightened(0.6), 0.45, 0.22)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 2.5, 0)
	add_child(light)
	if form == 3:
		_add_eyes(m)
		_grip_sword(m)
	_sound("summon.ogg", 2.0)
	# form up: grow from small and fade in
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * SCALE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_fade, 0.0, 1.0, 0.45)

## Form 3: two glowing yellow eyes on the face, riding the head bone.
func _add_eyes(m: Node3D) -> void:
	var sks := m.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk := sks[0] as Skeleton3D
	var head := sk.find_bone("4zss00t0 head")
	if head < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = head
	sk.add_child(att)
	var inv := sk.get_bone_global_rest(head).affine_inverse()
	for x in [-0.12, 0.12]:
		var eye := Node3D.new()
		att.add_child(eye)
		eye.position = inv * Vector3(x, 2.9, 0.62)   # (on the face, in the head bone's space)
		var core := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.07
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.albedo_color = Color(1.0, 0.97, 0.75)
		cm.emission_enabled = true
		cm.emission = EYE_COLOR
		cm.emission_energy_multiplier = 6.0
		sm.material = cm
		core.mesh = sm
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(core)
		var glow := MeshInstance3D.new()
		glow.mesh = Vfx.quad()
		var gm := Vfx.tex_mat("effects/Glow01.png", EYE_COLOR, 2.4, true)
		gm.billboard_keep_scale = true
		glow.material_override = gm
		glow.scale = Vector3.ONE * 0.45
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(glow)
		glow.create_tween().set_loops().tween_property(glow, "scale", Vector3.ONE * 0.55, 0.6).from(Vector3.ONE * 0.4).set_trans(Tween.TRANS_SINE)

func _set_fade(v: float) -> void:
	_fade = v
	for mat in _mats:
		mat.set_shader_parameter("fade", v)

# Form 3's sword is its own little skeleton, animated only in "idle" - the attack animation leaves
# it hanging in the air. So the sword is held: its grip offset from the nearest hand bone is taken
# from the idle pose, and every frame (after the animation) the sword is put back in that hand.
var _sk: Skeleton3D
var _sword_root := -1
var _hand := -1
var _grip := Transform3D()

func _grip_sword(m: Node3D) -> void:
	var sks := m.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty() or ap == null or not ap.has_animation("idle"):
		return
	_sk = sks[0]
	_sword_root = _sk.find_bone("4zsssword1_trall")
	var grip_bone := _sk.find_bone("4zsssword1_bone01")
	if _sword_root < 0 or grip_bone < 0:
		return
	ap.seek(0.3, true)   # (idle: the sword is in the hand)
	var gp := _gpose(grip_bone).origin
	var best := INF
	for i in _sk.get_bone_count():
		var nm := _sk.get_bone_name(i)
		if not nm.begins_with("4zss00t0 ") or not (" arm" in nm or "finger" in nm or "hand" in nm):
			continue
		var d := _gpose(i).origin.distance_to(gp)
		if d < best:
			best = d
			_hand = i
	if _hand < 0:
		return
	_grip = _gpose(_hand).affine_inverse() * _gpose(_sword_root)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL   # (we advance it, then fix the sword)

func _gpose(b: int) -> Transform3D:
	var t := Transform3D()
	while b >= 0:
		t = _sk.get_bone_pose(b) * t
		b = _sk.get_bone_parent(b)
	return t

func _hold_sword(delta: float) -> void:
	ap.advance(delta)
	var want := _gpose(_hand) * _grip
	var par := _sk.get_bone_parent(_sword_root)
	var local := (_gpose(par).affine_inverse() * want) if par >= 0 else want
	_sk.set_bone_pose_position(_sword_root, local.origin)
	_sk.set_bone_pose_rotation(_sword_root, local.basis.get_rotation_quaternion())

func _process(delta: float) -> void:
	if _hand >= 0 and _sk != null and ap != null:
		_hold_sword(delta)
	if follow != null and is_instance_valid(follow) and not _dying:
		rotation.y = lerp_angle(rotation.y, follow.global_rotation.y, 1.0 - exp(-10.0 * delta))

## lpunch / rpunch / slam
func attack(kind: String) -> void:
	if ap == null or _dying or not ANIMS.has(kind):
		return
	var anim: String = ANIMS[kind]
	if not ap.has_animation(anim) and ap.has_animation(FORM3_ATTACK):
		anim = FORM3_ATTACK
	if ap.has_animation(anim):
		ap.play(anim, 0.12, float(SPEED[kind]))
	var hit_at := impact_delay(kind)
	if kind == "slam":
		_sound("slam_windup.ogg", -2.0)
		# the boom's loudest moment lands on the impact (start it part-way in if needed)
		var lead := SLAM_PEAK - hit_at
		if lead > 0.0:
			_sound("slam.ogg", 3.0, lead)
		else:
			get_tree().create_timer(-lead).timeout.connect(_sound.bind("slam.ogg", 3.0, 0.0))
	else:
		_sound("punch_whoosh.ogg", -3.0)
		var h: Dictionary = HITS[_hit_variant % HITS.size()]
		_hit_variant += 1
		get_tree().create_timer(maxf(0.0, hit_at - float(h["peak"]))).timeout.connect(_sound.bind(str(h["file"]), 1.0, 0.0))

## Plays one of the Susanoo sounds from where the Susanoo is (others hear it too, by distance).
## detached = keep playing after the Susanoo is gone (release sound).
func _sound(file: String, db := 0.0, from := 0.0, detached := false) -> void:
	if not is_inside_tree():
		return
	var stream := load(SFX + file) as AudioStream
	if stream == null:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = stream
	pl.volume_db = db
	pl.unit_size = 14.0
	pl.max_distance = 90.0
	pl.bus = "Master"
	if detached and get_parent() != null and get_parent().get_parent() != null:
		var host := get_parent().get_parent()
		host.add_child(pl)
		pl.global_position = global_position + Vector3.UP * 2.0
	else:
		add_child(pl)
		pl.position = Vector3.UP * 2.0
	pl.finished.connect(pl.queue_free)
	pl.play(from)

## Shrinks and fades out, then frees itself.
func dismiss() -> void:
	if _dying:
		return
	_dying = true
	_sound("release.ogg", -1.0, 0.0, true)
	if _aura != null and is_instance_valid(_aura):
		_aura.fade_out(0.35)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * SCALE * 0.4, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_fade, _fade, 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
