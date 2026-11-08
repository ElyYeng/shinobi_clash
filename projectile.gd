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
var network_attacker_id := 0
var network_damage_enabled := false
var source_player: Player
var visual_kind := ""
var visual_root: Node3D
var visual_model: Node3D

func _ready() -> void:
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = maxf(size, 0.25)
	col.shape = sh
	add_child(col)
	if visual_kind == "rasenshuriken":
		_build_rasenshuriken_visual()
	else:
		var mi := MeshInstance3D.new()
		if long_shape:
			var b := BoxMesh.new()
			b.size = Vector3(size * 0.5, size * 0.5, size * 5.0)
			mi.mesh = b
		else:
			var sphere := SphereMesh.new()
			sphere.radius = size
			sphere.height = size * 2.0
			mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0 if aoe > 0.0 else 1.6
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	if aoe > 0.0 and visual_kind != "rasenshuriken":
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
	if visual_kind == "rasenshuriken" and visual_root != null:
		if velocity.length() > 0.01:
			look_at(global_position + velocity, Vector3.UP)
		if visual_model != null:
			visual_model.rotate_object_local(Vector3.UP, 22.0 * delta)

func _build_rasenshuriken_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "RasenshurikenSpin"
	add_child(visual_root)
	var path := "res://assets/rasenshuriken/scene.gltf"
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			visual_model = packed.instantiate() as Node3D
	if visual_model != null:
		# The supplied model is a flat XZ wind disc. Turn its normal toward
		# projectile forward, then spin around that normal while it travels.
		visual_model.rotation.x = PI * 0.5
		visual_root.add_child(visual_model)
		var bounds := AABB()
		var found := false
		for node in visual_model.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			var relative_transform := visual_model.global_transform.affine_inverse() * mesh_instance.global_transform
			var mesh_bounds := relative_transform * mesh_instance.get_aabb()
			bounds = mesh_bounds if not found else bounds.merge(mesh_bounds)
			found = true
		var max_dimension := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) if found else 1.5
		var desired_diameter := maxf(size * 3.0, 0.9)
		visual_model.scale = Vector3.ONE * (desired_diameter / maxf(max_dimension, 0.001))
		return

	# Fallback if the project has not yet had the supplied GLTF extracted into
	# res://assets/rasenshuriken. This keeps the move usable while assets are copied.
	var disc := MeshInstance3D.new()
	var disk_mesh := CylinderMesh.new()
	disk_mesh.top_radius = 0.55
	disk_mesh.bottom_radius = 0.55
	disk_mesh.height = 0.08
	disc.mesh = disk_mesh
	disc.rotation.x = PI * 0.5
	var disk_mat := StandardMaterial3D.new()
	disk_mat.albedo_color = color
	disk_mat.emission_enabled = true
	disk_mat.emission = color
	disk_mat.emission_energy_multiplier = 4.0
	disc.material_override = disk_mat
	visual_root.add_child(disc)
	visual_model = disc
	for blade_index in 4:
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.22, 0.12, 1.05)
		blade.mesh = blade_mesh
		blade.position = Vector3(0, 0, 0.32)
		blade.rotation.z = TAU * float(blade_index) / 4.0
		blade.material_override = disk_mat
		visual_root.add_child(blade)

func _on_body(b: Node3D) -> void:
	if done:
		return
	if b == source_player:
		return # Never collide with the shinobi who launched this projectile.
	if b is Player:
		if network_damage_enabled and NetworkSession.is_active() and b == NetworkSession._local_player:
			NetworkSession.request_projectile_player_hit(network_attacker_id, damage, global_position)
		_explode()
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
