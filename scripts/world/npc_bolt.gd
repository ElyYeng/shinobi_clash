class_name NpcBolt
extends Node3D
## Small projectile fired by NPC bloodline abilities (fan / homing kinds).
## Single player: hits you. Multiplayer host: hits any player its enemy may target (see
## Enemy.targetable_players). cosmetic = true: a harmless copy shown on the other players' screens.

var velocity := Vector3.ZERO
var damage := 10.0
var color := Color.WHITE
var size := 0.25
var homing := false
var life := 3.0
var shooter: Enemy = null      # host: the enemy that fired it (decides who it can hit)
var target_peer := 1           # who a homing bolt chases
var cosmetic := false
var visual := ""               # the move's projectile look (LegendFx.PROJ / Mythic kinds), "" = glowing ball


func _ready() -> void:
	if visual != "" and _build_visual():
		return
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


## Player positions this bolt can hit / chase, as {peer_id: chest position}.
func _targets() -> Dictionary:
	var out := {}
	if cosmetic:   # a copy: chase the same player on this screen, hit nobody
		var me := multiplayer.get_unique_id() if NetworkSession.is_active() else 1
		if target_peer == me:
			var p := get_tree().get_first_node_in_group("player") as Player
			if p != null:
				out[me] = p.global_position + Vector3.UP
		elif NetworkSession._avatars.has(target_peer) and is_instance_valid(NetworkSession._avatars[target_peer]):
			out[target_peer] = (NetworkSession._avatars[target_peer] as Node3D).global_position + Vector3.UP
		return out
	if shooter != null and is_instance_valid(shooter):
		var players := shooter.targetable_players()
		for id in players:
			out[id] = (players[id] as Vector3) + Vector3.UP
		return out
	var lp := get_tree().get_first_node_in_group("player") as Player
	if lp != null and not lp.is_dead:
		out[1] = lp.global_position + Vector3.UP
	return out


## The same projectile looks the players' moves have (spears, orbs, crystals, bones...).
func _build_visual() -> bool:
	if LegendFx.PROJ.has(visual):
		LegendFx.build_proj(self, visual, size)
	else:
		match visual:
			"dust": MythicFx.build_dust_cube(self, size)
			"orb": MythicFx.build_orb(self, size)
			"bone": MythicFx.build_bone(self, size)
			"susanoo_arrow": SharinganFx.build_susanoo_arrow(self, size)
			_: return false
	if velocity.length() > 0.01:
		look_at.call_deferred(global_position + velocity)
	return true

func _physics_process(delta: float) -> void:
	if visual != "" and velocity.length() > 0.01 and is_inside_tree():
		look_at(global_position + velocity)
	life -= delta
	var targets := _targets()
	if homing and velocity.length() > 0.1 and targets.has(target_peer):
		var chase: Vector3 = targets[target_peer]
		velocity = velocity.lerp((chase - global_position).normalized() * velocity.length(), 2.5 * delta)
	for id in targets:
		if global_position.distance_to(targets[id]) < 0.9:
			if not cosmetic:
				if shooter != null and is_instance_valid(shooter):
					shooter.hurt_peer(int(id), damage, velocity.normalized() * 4.0)
				else:
					var p := get_tree().get_first_node_in_group("player") as Player
					if p != null:
						p.take_damage(damage, velocity.normalized() * 4.0)
			Vfx.burst(get_parent(), global_position, color, 14, 5.0, 0.2, 0.5)
			queue_free()
			return
	global_position += velocity * delta
	if life <= 0.0:
		queue_free()
