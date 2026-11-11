class_name Clone
extends Node3D
## Temporary AI ally that rushes the nearest enemy (uses the hero model if present).

var life := 8.0
var hit_cd := 0.0
var anim_lock := 0.0
var cosmetic_only := false
var network_peer_id := 0
var network_summon_id := 0
var network_clone_index := 0
var network_target_position := Vector3.ZERO
var network_target_yaw := 0.0
var model: Node3D
var arm: Node3D
var slot := 0          # place in the formation behind the player (set by the summoner)
var slot_count := 1

const FOLLOW_SPEED := 9.0
const SPACING := 1.4   # clones keep at least this far from each other

func _ready() -> void:
	add_to_group("shadow_clones")
	# Local clones use the local player's current look. A remote cosmetic clone
	# must use the appearance cached for the peer who summoned it, not the
	# receiving player's GameData.character_appearance.
	var look: Dictionary = GameData.character_appearance.duplicate(true)
	if cosmetic_only and network_peer_id > 0:
		var appearances_by_peer: Dictionary = NetworkSession.get("_known_appearances")
		look = Hero.sanitize_appearance(appearances_by_peer.get(network_peer_id, {}))
	model = Hero.create(look)
	if model == null:
		model = Fx.make_ninja(Color(0.95, 0.6, 0.25), Color(0.15, 0.3, 0.8))
	add_child(model)
	arm = model.get_node_or_null("Arm")
	_snap_to_ground()
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(1, 1, 1, 0.8), 2.2)

func _snap_to_ground() -> void:
	var terrain := get_tree().get_first_node_in_group("world_terrain")
	if terrain != null and terrain.has_method("height_at"):
		global_position.y = float(terrain.call("height_at", global_position.x, global_position.z))
	else:
		global_position.y = 0.0

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		Fx.puff(get_parent(), global_position + Vector3.UP, Color(1, 1, 1, 0.8), 2.2)
		queue_free()
		return
	if cosmetic_only:
		global_position = global_position.lerp(network_target_position, minf(1.0, delta * 18.0))
		_snap_to_ground()
		if model != null:
			model.rotation.y = lerp_angle(model.rotation.y, network_target_yaw, minf(1.0, delta * 18.0))
			Hero.play(model, "run" if global_position.distance_to(network_target_position) > 0.15 else "idle")
		return
	hit_cd -= delta
	anim_lock = maxf(0.0, anim_lock - delta)
	var best: Enemy = null
	var best_d := 40.0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	var to := Vector3.ZERO
	var running := false
	var goal := global_position
	var face := Vector3.ZERO
	if best:
		# surround the enemy: each clone attacks from its own side instead of piling up
		var reach := 1.6 * best.k
		var ang := TAU * float(slot) / float(maxi(slot_count, 1))
		var around := Vector3(sin(ang), 0, cos(ang)) * reach
		goal = best.global_position + around
		face = best.global_position - global_position
		face.y = 0.0
		if face.length() <= reach + 0.6 and hit_cd <= 0.0:
			hit_cd = 0.7
			if not cosmetic_only:
				best.take_damage(8.0, face.normalized() * 5.0)
			var l := Hero.play(model, "attack", true)
			if l > 0.0:
				anim_lock = minf(l, 0.5)
			else:
				Fx.swing(arm)
	else:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p:
			goal = p.global_position + _formation_offset(p)
			face = _player_facing(p)
	# move toward our spot (slowing down as we arrive), pushed apart from the other clones
	var step := goal - global_position
	step.y = 0.0
	var sep := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("shadow_clones"):
		if o == self or not is_instance_valid(o):
			continue
		var d: Vector3 = global_position - (o as Node3D).global_position
		d.y = 0.0
		var dl := d.length()
		if dl < SPACING:
			sep += (d / maxf(dl, 0.01) if dl > 0.01 else Vector3(sin(slot * 2.4), 0, cos(slot * 2.4))) * (SPACING - dl)
	var vel := step.normalized() * minf(FOLLOW_SPEED, step.length() * 4.0) if step.length() > 0.25 else Vector3.ZERO
	vel += sep * 6.0
	global_position += vel * delta
	running = vel.length() > 1.2
	to = vel if running else face
	_snap_to_ground()
	if to.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), 12.0 * delta)
	if anim_lock <= 0.0:
		Hero.play_move(model, "run" if running else "idle", 8.0 if running else 0.0)


## Spot in a V behind the player, turned with the way they face (+Z = behind for a -Z facing model).
func _formation_offset(p: Node3D) -> Vector3:
	var row := slot / 2 + 1
	var side := -1.0 if slot % 2 == 0 else 1.0
	if slot_count % 2 == 1 and slot == slot_count - 1:
		side = 0.0   # odd one out walks straight behind
	var local := Vector3(side * 1.7 * row, 0, 1.6 + 1.3 * row)
	var f := _player_facing(p)
	return Basis(Vector3.UP, atan2(-f.x, -f.z)) * local

func _player_facing(p: Node3D) -> Vector3:
	var m = p.get("model")
	if m is Node3D:
		var z: Vector3 = -(m as Node3D).global_basis.z
		z.y = 0.0
		if z.length() > 0.01:
			return z.normalized()
	return Vector3.FORWARD

func set_network_transform(pos: Vector3, yaw: float) -> void:
	network_target_position = pos
	network_target_yaw = yaw
