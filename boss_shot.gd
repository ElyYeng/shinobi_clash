class_name BossShot
extends Node3D
## Kurama's Tailed Beast Bomb. Starts "held" (charging at his mouth), then release() fires it.

var damage := 38.0
var aoe := 9.0          # blast radius
var radius := 2.5       # visual size when fully charged
var held := true
var velocity := Vector3.ZERO
var life := 6.0
var charge := 0.0
var done := false
var mesh: MeshInstance3D
var core: MeshInstance3D
var halo: MeshInstance3D
var light: OmniLight3D

func _ready() -> void:
	mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	mesh.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.03, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.1, 0.95)
	mat.emission_energy_multiplier = 2.5
	mesh.material_override = mat
	mesh.scale = Vector3.ONE * 0.2
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	# white-hot core + soft purple halo + swirling sparks
	core = MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 1.0
	cs.height = 2.0
	cs.radial_segments = 20
	cs.rings = 10
	core.mesh = cs
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1.0, 0.85, 1.0)
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * 0.1
	add_child(core)
	halo = MeshInstance3D.new()
	halo.mesh = cs
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(0.9, 0.3, 1.6, 0.3)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.scale = Vector3.ONE * 0.3
	add_child(halo)
	Vfx.aura_flames(self, Vector3.ZERO, 1.6, Color(0.7, 0.15, 1.0), 70)
	Vfx.trail(self, Color(0.8, 0.3, 1.0), 1.4, 36, 0.6)
	light = OmniLight3D.new()
	light.light_color = Color(0.8, 0.2, 1.0)
	light.omni_range = 18.0
	light.light_energy = 2.0
	add_child(light)

func release(dir: Vector3, speed: float) -> void:
	held = false
	velocity = dir.normalized() * speed
	Sfx.play(self, "fire", 4.0)

func _physics_process(delta: float) -> void:
	if done:
		return
	if held:
		charge = minf(charge + delta, 1.6)
		var f := charge / 1.6
		mesh.scale = Vector3.ONE * lerpf(0.2, radius, f)
		core.scale = mesh.scale * 0.55
		halo.scale = mesh.scale * (1.5 + 0.12 * sin(Time.get_ticks_msec() * 0.03))
		light.light_energy = lerpf(2.0, 6.0, f)
		return
	life -= delta
	core.scale = mesh.scale * 0.55
	halo.scale = mesh.scale * (1.5 + 0.12 * sin(Time.get_ticks_msec() * 0.03))
	global_position += velocity * delta
	var p := get_tree().get_first_node_in_group("player") as Player
	var hit_player := false
	if p != null and not p.is_dead:
		hit_player = global_position.distance_to(p.global_position + Vector3.UP) < radius + 0.8
	if global_position.y <= 0.6 or life <= 0.0 or hit_player:
		_explode()

func _explode() -> void:
	if done:
		return
	done = true
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and not p.is_dead:
		var d := p.global_position - global_position
		if d.length() < aoe:
			d.y = 0.0
			var push := d.normalized() * 16.0 if d.length() > 0.01 else Vector3.ZERO
			p.take_damage(damage, push)
	Sfx.play(self, "boom", 6.0)
	Fx.puff(get_parent(), global_position, Color(0.7, 0.15, 0.95, 0.85), aoe * 2.0)
	Fx.puff(get_parent(), global_position, Color(1.0, 0.8, 1.0, 0.9), aoe)
	Vfx.shockwave(get_parent(), global_position, Color(0.8, 0.3, 1.0), aoe * 1.5, 0.7)
	Vfx.flash(get_parent(), global_position + Vector3.UP * 2.0, Color(0.85, 0.4, 1.0), 14.0, 40.0, 0.5)
	if p != null:
		Vfx.shake(p.cam, 0.5, 0.7)
	queue_free()
