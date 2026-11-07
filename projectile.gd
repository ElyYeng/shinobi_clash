class_name Projectile
extends Area3D
## Kunai (long, homing optional) and fireballs (aoe > 0).

var velocity := Vector3.ZERO
var speed := 30.0
var damage := 10.0
var aoe := 0.0
var life := 3.0
var size := 0.15
var color := Color(0.8, 0.8, 0.85)
var long_shape := false
var target: Node3D = null
var done := false

func _ready() -> void:
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = maxf(size, 0.25)
	col.shape = sh
	add_child(col)
	var mi := MeshInstance3D.new()
	if long_shape:
		var b := BoxMesh.new()
		b.size = Vector3(size * 0.5, size * 0.5, size * 5.0)
		mi.mesh = b
	else:
		var s := SphereMesh.new()
		s.radius = size; s.height = size * 2.0
		mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0 if aoe > 0.0 else 1.6
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if aoe > 0.0:
		# fireball: bright core, flame trail and a light that flickers across the scenery
		var halo := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = size * 1.6; hs.height = size * 3.2
		halo.mesh = hs
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hm.albedo_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 0.35)
		halo.material_override = hm
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(halo)
		Vfx.trail(self, color, size * 2.2, 40, 0.5)
		Vfx.glow_light(self, color, 3.0, 12.0)
	else:
		Vfx.trail(self, Color(0.85, 0.92, 1.0), 0.16, 22, 0.28)
		Vfx.glow_light(self, Color(0.8, 0.9, 1.0), 0.6, 4.0)
	body_entered.connect(_on_body)
	if long_shape and velocity.length() > 0.01:
		look_at(global_position + velocity)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_explode()
		return
	if is_instance_valid(target):
		var want := global_position.direction_to(target.global_position + Vector3.UP) * speed
		velocity = velocity.lerp(want, 5.0 * delta)
		if long_shape and velocity.length() > 0.01:
			look_at(global_position + velocity)
	global_position += velocity * delta

func _on_body(b: Node3D) -> void:
	if done or b is Player:
		return
	if aoe > 0.0:
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) <= aoe:
				e.take_damage(damage, (e.global_position - global_position).normalized() * 10.0)
	elif b is Enemy:
		b.take_damage(damage, velocity.normalized() * 4.0)
	_explode()

func _explode() -> void:
	if done:
		return
	done = true
	if aoe > 0.0:
		Sfx.play(self, "boom")
	Fx.puff(get_parent(), global_position, color, maxf(aoe * 2.0, 0.6))
	if aoe > 0.0 and get_parent() != null:
		Vfx.shake(get_viewport().get_camera_3d(), 0.12, 0.3)
	queue_free()
