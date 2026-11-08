class_name Enemy
extends CharacterBody3D

var health := 60.0
var max_health := 60.0
var speed := 4.5
var damage := 8.0
var is_boss := false
var aggro_range := 0.0   # 0 = always hunts the player; >0 = idles until the player is this close
var aggroed := false
var display_name := ""                       # shown above the health bar (quest targets)
var body_color := Color(0.25, 0.25, 0.32)
var band_color := Color(0.6, 0.6, 0.65)

var atk_cd := 1.0
var windup := 0.0
var stun := 0.0
var model: Node3D
var arm: Node3D
var label: Label3D
var k := 1.0
var bob_t := 0.0
static var time_scale := 1.0  # <1 slows all enemies (Sharingan)

func _ready() -> void:
	_setup()

func _setup() -> void:
	add_to_group("enemies")
	max_health = health
	k = 1.6 if is_boss else 1.0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * k
	cap.height = 1.9 * k
	col.shape = cap
	col.position.y = 0.95 * k
	add_child(col)
	model = Fx.make_ninja(Color(0.5, 0.1, 0.1) if is_boss else body_color, Color(0.6, 0.6, 0.65) if is_boss else band_color, Color(1.0, 0.15, 0.08))
	model.scale = Vector3.ONE * k
	add_child(model)
	arm = model.get_node("Arm")
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.pixel_size = 0.005
	label.position.y = 2.5 * k
	add_child(label)
	_update_label()

func _update_label() -> void:
	var n := int(ceil(clampf(health / max_health, 0.0, 1.0) * 10.0))
	label.text = "█".repeat(n) + "░".repeat(10 - n)
	if display_name != "":
		label.text = display_name + "\n" + label.text
	label.modulate = Color(1, 0.3, 0.3) if is_boss else Color(1, 0.9, 0.9)

func _physics_process(delta: float) -> void:
	_ai(delta)
	_animate_body(delta)

## Procedural run bob + forward lean for the placeholder ninjas (skipped for models with real animations).
func _animate_body(delta: float) -> void:
	if is_boss or model == null:
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp > 0.6:
		bob_t += delta * (6.0 + sp * 1.4)
		model.position.y = absf(sin(bob_t)) * 0.12
		model.rotation.x = lerpf(model.rotation.x, -0.16, 8.0 * delta)
	else:
		model.position.y = lerpf(model.position.y, 0.0, 10.0 * delta)
		model.rotation.x = lerpf(model.rotation.x, 0.0, 8.0 * delta)

func _ai(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	var ts := time_scale
	atk_cd -= delta * ts
	stun -= delta * ts
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized()
	if aggro_range > 0.0 and not aggroed:
		if dist <= aggro_range:
			aggroed = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			move_and_slide()
			return
	if stun > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
	elif windup > 0.0:
		windup -= delta * ts
		velocity.x = 0.0
		velocity.z = 0.0
		if windup <= 0.0:
			_strike(p, dir, dist)
	else:
		if dist > 2.0 * k:
			velocity.x = dir.x * speed * ts
			velocity.z = dir.z * speed * ts
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if atk_cd <= 0.0:
				windup = 0.55
				atk_cd = 1.4
				var t := arm.create_tween()
				t.tween_property(arm, "rotation:x", -2.5, 0.35)
	if dist > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	move_and_slide()

func _strike(p: Player, dir: Vector3, _dist: float) -> void:
	Fx.swing(arm)
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() < 2.8 * k:
		p.take_damage(damage * (1.5 if is_boss else 1.0), dir * 7.0)

func take_damage(amount: float, knock: Vector3 = Vector3.ZERO) -> void:
	health -= amount
	aggroed = true
	Sfx.play(self, "hit", -5.0)
	velocity.x += knock.x
	velocity.z += knock.z
	if not is_boss:
		stun = maxf(stun, 0.25)
		windup = 0.0
	Fx.puff(get_parent(), global_position + Vector3.UP * 1.2, Color(1, 1, 0.7, 0.9), 0.7)
	Vfx.damage_number(get_parent(), global_position + Vector3.UP * (2.2 * k), amount)
	_update_label()
	if health <= 0.0:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p:
			p.kills += 1
			p.on_kill(is_boss)
			p.add_mode(10.0)
			p.chakra = minf(p.max_chakra, p.chakra + 10.0)
			if is_boss:
				p.health = minf(p.max_health, p.health + 30.0)
		Fx.puff(get_parent(), global_position + Vector3.UP, Color(1, 0.85, 0.6, 0.9), 2.5 * k)
		Vfx.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.5, 0.15), 40, 9.0, 0.3, 0.9)
		Sfx.play(self, "poof", -2.0)
		remove_from_group("enemies")
		queue_free()
