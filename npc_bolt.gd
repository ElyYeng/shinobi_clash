class_name NpcBolt
extends Node3D
## Small projectile fired by NPC bloodline abilities (fan / homing kinds). Hits the local player.

var velocity := Vector3.ZERO
var damage := 10.0
var color := Color.WHITE
var size := 0.25
var homing := false
var life := 3.0


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = maxf(size, 0.15)
	sphere.height = sphere.radius * 2.0
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _physics_process(delta: float) -> void:
	life -= delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		var chest := p.global_position + Vector3.UP
		if homing and velocity.length() > 0.1:
			velocity = velocity.lerp((chest - global_position).normalized() * velocity.length(), 2.5 * delta)
		if global_position.distance_to(chest) < 0.9:
			p.take_damage(damage, velocity.normalized() * 4.0)
			Vfx.burst(get_parent(), global_position, color, 14, 5.0, 0.2, 0.5)
			queue_free()
			return
	global_position += velocity * delta
	if life <= 0.0:
		queue_free()
