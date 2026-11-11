extends Node3D
## Lightweight remote player representation. The owning peer controls its own Player node.

var peer_id := 0
var display_name := "Shinobi"
var player_level := 1
var clan := "none"   # equipped bloodline, shown next to the name
var is_party_member := false
var character_appearance: Dictionary = {}
var target_position := Vector3.ZERO
var target_yaw := 0.0
var target_look := Vector2.ZERO   # head look (yaw, pitch) relative to the body
var stuck := false                # on a wall / ceiling (chakra walk)
var stick_q := Quaternion.IDENTITY
var stick_feet := Vector3.ZERO

## Chakra-walk pose from the owner: model rotation (as x,y,z,w; all zero = standing normally) and
## the feet's offset from the body.
func set_stick_pose(q: Vector4, feet: Vector3) -> void:
	if network_ragdoll_started:
		return
	var was := stuck
	stuck = q != Vector4.ZERO
	if stuck:
		stick_q = Quaternion(q.x, q.y, q.z, q.w).normalized()
		stick_feet = feet
	elif was and model != null:   # back on the ground: stand upright again
		model.position = Vector3.ZERO
		model.basis = Basis(Vector3.UP, target_yaw).scaled(model.basis.get_scale())
var model: Node3D
var name_tag: Label3D
var _last_position := Vector3.ZERO
var power_fx: Node3D
var ragdoll: Ragdoll
var network_ragdoll_started := false

func _ready() -> void:
	add_to_group("network_players")
	model = Hero.create(character_appearance)
	if model == null:
		var hue := fposmod(float(peer_id) * 0.173, 1.0)
		model = Fx.make_ninja(Color.from_hsv(hue, 0.7, 0.95), Color(0.12, 0.16, 0.24))
	add_child(model)
	name_tag = Label3D.new()
	name_tag.text = _tag_text()
	name_tag.position = Vector3(0, 2.4, 0)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.font_size = 32
	name_tag.outline_size = 8
	add_child(name_tag)
	target_position = global_position
	_last_position = global_position

var kurama_fx: Node3D
var animation_lock := 0.0

func set_kurama_visual(enabled: bool) -> void:
	if enabled:
		if kurama_fx != null and is_instance_valid(kurama_fx):
			kurama_fx.queue_free()
		kurama_fx = Node3D.new()
		add_child(kurama_fx)
		model.scale = Vector3.ONE * 1.3
		Vfx.aura_flames(kurama_fx, Vector3(0, 1.0, 0), 0.65, Color(1.0, 0.5, 0.1), 26, true)
		Vfx.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.55, 0.1), 36, 9.0, 0.22, 0.6, 0.0)
	else:
		if kurama_fx != null and is_instance_valid(kurama_fx):
			kurama_fx.queue_free()
		kurama_fx = null
		model.scale = Vector3.ONE

var susanoo: Susanoo

func play_combat_animation(state: String, variant: int = 0) -> void:
	if model == null or network_ragdoll_started:
		return
	if state.begins_with("susanoo_"):   # Susanoo (Uchiha): form / release / attacks
		_susanoo_event(state.trim_prefix("susanoo_"), variant)
		return
	var lock := 0.45
	if state == "attack":
		lock = 0.5
	elif state == "throw":
		lock = 0.25
	Hero.play(model, state, true, variant, lock)
	animation_lock = lock

func _susanoo_event(ev: String, variant: int) -> void:
	match ev:
		"on":
			if susanoo != null and is_instance_valid(susanoo):
				susanoo.queue_free()
			var col := Susanoo.palette_color(variant)
			susanoo = Susanoo.create(col, model)
			add_child(susanoo)
			Vfx.burst(get_parent(), global_position + Vector3.UP * 2.0, col, 40, 10.0, 0.3, 0.8, 0.0)
		"off":
			if susanoo != null and is_instance_valid(susanoo):
				susanoo.dismiss()
			susanoo = null
		_:
			if susanoo != null and is_instance_valid(susanoo):
				susanoo.attack(ev)

## Starts a ragdoll for this remote avatar. The owning player sends the body
## transforms; this peer never runs a second independent physics simulation.
func start_network_ragdoll(position: Vector3, yaw: float, launch_velocity: Vector3) -> void:
	if network_ragdoll_started:
		return
	network_ragdoll_started = true
	global_position = position
	target_position = position
	target_yaw = yaw
	if model == null or not is_instance_valid(model):
		return
	model.rotation.y = yaw
	set_process(false)
	set_physics_process(false)
	if name_tag != null:
		name_tag.visible = false
	ragdoll = Ragdoll.start(model, self, launch_velocity)
	if ragdoll != null:
		ragdoll.set_network_driven(true)
	else:
		Hero.play(model, "die", true)

func apply_network_ragdoll_state(state: PackedFloat32Array) -> void:
	if ragdoll != null and is_instance_valid(ragdoll):
		ragdoll.apply_network_state(state)


## Restores this remote player after the owner respawns. Rebuilding the model
## clears every ragdoll bone pose and restarts its AnimationPlayer cleanly.
func reset_network_ragdoll(position: Vector3, yaw: float) -> void:
	if ragdoll != null and is_instance_valid(ragdoll):
		ragdoll.set_process(false)
		ragdoll.queue_free()
	ragdoll = null

	if model != null and is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	model = Hero.create(character_appearance)
	if model == null:
		var hue := fposmod(float(peer_id) * 0.173, 1.0)
		model = Fx.make_ninja(Color.from_hsv(hue, 0.7, 0.95), Color(0.12, 0.16, 0.24))
	add_child(model)
	model.rotation.y = yaw
	model.scale = Vector3.ONE

	if power_fx != null and is_instance_valid(power_fx):
		power_fx.queue_free()
	power_fx = null
	if kurama_fx != null and is_instance_valid(kurama_fx):
		kurama_fx.queue_free()
	kurama_fx = null

	global_position = position
	target_position = position
	target_yaw = yaw
	_last_position = position
	animation_lock = 0.0
	network_ragdoll_started = false
	set_process(true)
	set_physics_process(true)
	if name_tag != null:
		name_tag.visible = true
		name_tag.text = _tag_text()
	Hero.play(model, "idle")

## Cosmetic-only ability playback on this remote avatar; gameplay remains owned by its player.
func play_ability(move_id: String, color: Color) -> void:
	if network_ragdoll_started:
		return
	if model != null:
		Hero.play(model, "jutsu", true)
	var root := get_parent()
	if root != null:
		Vfx.burst(root, global_position + Vector3.UP, color, 30, 8.0, 0.28, 0.55, 0.0)
		Vfx.shockwave(root, global_position + Vector3.UP * 0.2, color, 3.5, 0.4)
	if name_tag != null:
		name_tag.text = _tag_text() + "\n" + move_id
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(name_tag):
				name_tag.text = _tag_text()
		)

## Spawn a cosmetic projectile on this peer; damage is deliberately zero.
func play_projectile(origin: Vector3, shot_velocity: Vector3, shot_speed: float, shot_size: float, color: Color, long_shape: bool, aoe: float, shot_damage: float, visual_kind: String = "", homing_on: Node3D = null) -> void:
	var shot := Projectile.new()
	shot.target = homing_on
	shot.global_position = origin
	shot.velocity = shot_velocity
	shot.speed = shot_speed
	shot.size = shot_size
	shot.color = color
	shot.long_shape = long_shape
	shot.aoe = aoe
	shot.damage = shot_damage
	shot.life = 4.0
	shot.network_attacker_id = peer_id
	shot.visual_kind = visual_kind
	shot.network_damage_enabled = true
	var root := get_parent()
	if root != null:
		root.add_child(shot)
		shot.global_position = origin

func set_powered_visual(enabled: bool, color: Color, bloodline := "") -> void:
	if network_ragdoll_started:
		return
	var look: Dictionary = Bloodline.mode(bloodline).get("look", {}) if enabled and bloodline != "" else {}
	if model != null and is_instance_valid(model):
		Hero.apply_mode_look(model, look, character_appearance)
	if enabled:
		if power_fx != null and is_instance_valid(power_fx):
			power_fx.queue_free()
		power_fx = Node3D.new()
		add_child(power_fx)
		if not look.has("glow"):
			Vfx.aura_flames(power_fx, Vector3(0, 1.0, 0), 0.6, color, 24, true)
		else:
			Vfx.aura_flames(power_fx, Vector3(0, 0.9, 0), 0.45, Color(color.r, color.g, color.b, 0.35), 10, true)
	else:
		if power_fx != null and is_instance_valid(power_fx):
			power_fx.queue_free()
		power_fx = null

func set_party_member(value: bool) -> void:
	is_party_member = value
	if name_tag != null:
		name_tag.modulate = Color(0.55, 1.0, 0.65) if value else Color.WHITE

func set_network_transform(pos: Vector3, yaw: float, look := Vector2.ZERO) -> void:
	if network_ragdoll_started:
		return
	target_position = pos
	target_yaw = yaw
	target_look = look

func _process(delta: float) -> void:
	if network_ragdoll_started:
		return
	animation_lock = maxf(0.0, animation_lock - delta)
	global_position = global_position.lerp(target_position, minf(1.0, delta * 14.0))
	if model != null:
		if stuck:   # sideways on a wall / upside down on a ceiling
			var k := minf(1.0, delta * 14.0)
			var sc := model.basis.get_scale()
			var cur := model.global_basis.get_rotation_quaternion()
			model.global_basis = Basis(cur.slerp(stick_q, k)).scaled(sc)
			model.position = model.position.lerp(stick_feet, k)
		else:
			model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(1.0, delta * 14.0))
		var speed := global_position.distance_to(_last_position) / maxf(delta, 0.001)
		if animation_lock <= 0.0:
			Hero.play_move(model, Hero.move_state(speed), speed)
		HeadLook.drive(model, target_look.x, target_look.y, delta, not stuck)
	_last_position = global_position


## "Ely  [Uchiha]  •  Lv. 5" (no clan part without a bloodline).
func _tag_text() -> String:
	var c := "" if clan == "none" else "  [%s]" % Bloodline.get_def(clan)["name"]
	return "%s%s  •  Lv. %d" % [display_name, c, player_level]

func set_level(value: int) -> void:
	player_level = value
	if name_tag != null:
		name_tag.text = _tag_text()

func set_clan(value: String) -> void:
	clan = value
	if name_tag != null:
		name_tag.text = _tag_text()
