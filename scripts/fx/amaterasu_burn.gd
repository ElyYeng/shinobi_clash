class_name AmaterasuBurn
extends Node3D
## Amaterasu on a body: black flames that cling to it and burn until it dies (as in the anime,
## they can't be put out). On the caster's side `on_tick` deals the damage every TICK seconds;
## everyone else only sees the flames. Re-casting on a burning target just refreshes it.

const TICK := 0.5
const MAX_TIME := 60.0   # safety net (e.g. the unkillable training log)
const PLAYER_TIME := 8.0 # players (PvP / NPC Uchiha) burn for a while, not forever

var on_tick := Callable()
var _t := 0.0
var _life := 0.0

## Set `target` ablaze (or refresh its flames). Returns the burn node.
static func ignite(target: Node3D, tick := Callable()) -> AmaterasuBurn:
	if target == null or not is_instance_valid(target):
		return null
	var b := target.get_node_or_null("Amaterasu") as AmaterasuBurn
	if b == null:
		b = AmaterasuBurn.new()
		b.name = "Amaterasu"
		target.add_child(b)
		SharinganFx.black_flames(b, 1.8, 0.4)
		Fx.puff(target.get_parent(), target.global_position + Vector3.UP * 1.0, Color(0.05, 0.02, 0.06, 0.95), 1.6)
		Sfx.play(b, "fire", -2.0)
	b._life = 0.0
	if not b.is_processing():   # was going out: light it back up
		b.set_process(true)
		for c in b.find_children("*", "CPUParticles3D", true, false):
			(c as CPUParticles3D).emitting = true
	if tick.is_valid():
		b.on_tick = tick
	return b

func _process(delta: float) -> void:
	_life += delta
	var host := get_parent()
	var cap := MAX_TIME if host is Enemy else PLAYER_TIME
	if _life > cap or _dead(host):
		_go_out()
		return
	_t += delta
	if _t >= TICK:
		_t -= TICK
		if on_tick.is_valid():
			on_tick.call(host)

func _dead(host: Node) -> bool:
	if host == null or not is_instance_valid(host):
		return true
	if host is Enemy:
		return (host as Enemy).health <= 0.0 or not host.is_in_group("enemies")
	if host.get("network_ragdoll_started") == true or host.get("is_dead") == true:
		return true
	return false

func _go_out() -> void:
	set_process(false)
	for c in find_children("*", "CPUParticles3D", true, false):
		(c as CPUParticles3D).emitting = false
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_processing():
			queue_free())
