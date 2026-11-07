class_name Clone
extends Node3D
## Temporary AI ally that rushes the nearest enemy (uses the hero model if present).

var life := 8.0
var hit_cd := 0.0
var anim_lock := 0.0
var model: Node3D
var arm: Node3D

func _ready() -> void:
	model = Hero.create()
	if model == null:
		model = Fx.make_ninja(Color(0.95, 0.6, 0.25), Color(0.15, 0.3, 0.8))
	add_child(model)
	arm = model.get_node_or_null("Arm")
	global_position.y = 0.0
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(1, 1, 1, 0.8), 2.2)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		Fx.puff(get_parent(), global_position + Vector3.UP, Color(1, 1, 1, 0.8), 2.2)
		queue_free()
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
	if best:
		to = best.global_position - global_position
		to.y = 0.0
		if to.length() > 1.8 * best.k:
			global_position += to.normalized() * 9.0 * delta
			running = true
		elif hit_cd <= 0.0:
			hit_cd = 0.7
			best.take_damage(8.0, to.normalized() * 5.0)
			var l := Hero.play(model, "attack", true)
			if l > 0.0:
				anim_lock = minf(l, 0.5)
			else:
				Fx.swing(arm)
	else:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p:
			to = p.global_position - global_position
			to.y = 0.0
			if to.length() > 4.0:
				global_position += to.normalized() * 8.0 * delta
				running = true
	global_position.y = 0.0
	if to.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), 12.0 * delta)
	if anim_lock <= 0.0:
		Hero.play(model, "run" if running else "idle")
