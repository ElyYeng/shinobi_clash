extends Node3D
## Lightweight remote player representation. The owning peer controls its own Player node.

var peer_id := 0
var display_name := "Shinobi"
var player_level := 1
var is_party_member := false
var character_appearance: Dictionary = {}
var target_position := Vector3.ZERO
var target_yaw := 0.0
var model: Node3D
var name_tag: Label3D
var _last_position := Vector3.ZERO
var power_fx: Node3D

func _ready() -> void:
	add_to_group("network_players")
	model = Hero.create(character_appearance)
	if model == null:
		var hue := fposmod(float(peer_id) * 0.173, 1.0)
		model = Fx.make_ninja(Color.from_hsv(hue, 0.7, 0.95), Color(0.12, 0.16, 0.24))
	add_child(model)
	name_tag = Label3D.new()
	name_tag.text = "%s  •  Lv. %d" % [display_name, player_level]
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

func play_combat_animation(state: String, variant: int = 0) -> void:
	if model == null:
		return
	var lock := 0.45
	if state == "attack":
		lock = 0.5
	elif state == "throw":
		lock = 0.25
	Hero.play(model, state, true, variant, lock)
	animation_lock = lock

## Cosmetic-only ability playback on this remote avatar; gameplay remains owned by its player.
func play_ability(move_id: String, color: Color) -> void:
	if model != null:
		Hero.play(model, "jutsu", true)
	var root := get_parent()
	if root != null:
		Vfx.burst(root, global_position + Vector3.UP, color, 30, 8.0, 0.28, 0.55, 0.0)
		Vfx.shockwave(root, global_position + Vector3.UP * 0.2, color, 3.5, 0.4)
	if name_tag != null:
		name_tag.text = "%s  •  Lv. %d\n%s" % [display_name, player_level, move_id]
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(name_tag):
				name_tag.text = "%s  •  Lv. %d" % [display_name, player_level]
		)


## Spawn a cosmetic projectile on this peer; damage is deliberately zero.
func play_projectile(origin: Vector3, shot_velocity: Vector3, shot_speed: float, shot_size: float, color: Color, long_shape: bool, aoe: float, shot_damage: float, visual_kind: String = "") -> void:
	var shot := Projectile.new()
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

func set_powered_visual(enabled: bool, color: Color) -> void:
	if enabled:
		if power_fx != null and is_instance_valid(power_fx):
			power_fx.queue_free()
		power_fx = Node3D.new()
		add_child(power_fx)
		Vfx.aura_flames(power_fx, Vector3(0, 1.0, 0), 0.6, color, 24, true)
	else:
		if power_fx != null and is_instance_valid(power_fx):
			power_fx.queue_free()
		power_fx = null

func set_party_member(value: bool) -> void:
	is_party_member = value
	if name_tag != null:
		name_tag.modulate = Color(0.55, 1.0, 0.65) if value else Color.WHITE

func set_network_transform(pos: Vector3, yaw: float) -> void:
	target_position = pos
	target_yaw = yaw

func _process(delta: float) -> void:
	animation_lock = maxf(0.0, animation_lock - delta)
	global_position = global_position.lerp(target_position, minf(1.0, delta * 14.0))
	if model != null:
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(1.0, delta * 14.0))
		var speed := global_position.distance_to(_last_position) / maxf(delta, 0.001)
		if animation_lock <= 0.0:
			Hero.play(model, "run" if speed > 1.0 else "idle")
	_last_position = global_position
