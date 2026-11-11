class_name Villager
extends Node3D
## Ambient villagers that stroll the Konoha greybox streets (cosmetic, local only - no collision).
## They follow a small street graph, keep to their side of the road, pause now and then, glance at
## the player when they pass and stop if the player stands right in front of them.
## Villager.populate(map, count) is called by main.gd for the greybox map.

## Street graph (x, z) for maps/konoha_greybox.tscn - edit along with the roads in konoha_greybox.gd.
const NODES := {
	"gate": Vector2(0, 163), "south": Vector2(0, 110), "cross": Vector2(0, 40), "north": Vector2(0, -40),
	"tower": Vector2(0, -78), "sw": Vector2(-118, 110), "se": Vector2(118, 110), "cw": Vector2(-148, 40),
	"ce": Vector2(148, 40), "nw": Vector2(-122, -40), "ne": Vector2(122, -40),
}
const EDGES := [["gate", "south"], ["south", "cross"], ["cross", "north"], ["north", "tower"],
	["south", "sw"], ["south", "se"], ["cross", "cw"], ["cross", "ce"], ["north", "nw"], ["north", "ne"]]
const LANE := 3.2              # how far from the road centre they walk (right-hand side)
const ACTIVE_RANGE := 110.0    # further than this from the player: hidden, not animated

var model: Node3D
var speed := 1.4
var lane_jitter := 0.0
var from_id := ""
var to_id := ""
var goal := Vector3.ZERO
var pause := 0.0
var rng := RandomNumberGenerator.new()
var _far := false

static var _adj: Dictionary = {}

static func populate(parent: Node, count: int, seed_base := 77) -> void:
	_build_adj()
	var edges := EDGES.duplicate()
	for i in count:
		var v := Villager.new()
		v.name = "Villager%d" % i
		v.rng.seed = seed_base * 1000 + i
		var e: Array = edges[i % edges.size()]
		var a := NODES[e[0]] as Vector2
		var b := NODES[e[1]] as Vector2
		var t := v.rng.randf_range(0.1, 0.9)
		var p := a.lerp(b, t)
		v.position = Vector3(p.x, 0, p.y)
		v.from_id = e[0] if v.rng.randf() < 0.5 else e[1]
		v.to_id = e[1] if v.from_id == e[0] else e[0]
		parent.add_child(v)

static func _build_adj() -> void:
	if not _adj.is_empty():
		return
	for e in EDGES:
		for k in 2:
			var a: String = e[k]
			var b: String = e[1 - k]
			if not _adj.has(a):
				_adj[a] = []
			_adj[a].append(b)

func _ready() -> void:
	speed = rng.randf_range(1.15, 1.75)
	lane_jitter = rng.randf_range(-1.0, 1.0)
	model = Npc.character_look({}, "villager_%d" % rng.seed)
	if model == null:
		model = Fx.make_ninja(Color.from_hsv(rng.randf(), 0.4, 0.7), Color(0.2, 0.2, 0.25))
	add_child(model)
	_set_goal()
	position += _lane_offset(from_id, to_id)   # start on our side of the road

func _lane_offset(a_id: String, b_id: String) -> Vector3:
	var a: Vector2 = NODES[a_id]
	var b: Vector2 = NODES[b_id]
	var d := (b - a).normalized()
	var right := Vector2(-d.y, d.x)   # right-hand side of the direction of travel
	return Vector3(right.x, 0, right.y) * (LANE + lane_jitter * 0.6)

func _set_goal() -> void:
	var b: Vector2 = NODES[to_id]
	goal = Vector3(b.x, 0, b.y) + _lane_offset(from_id, to_id)

func _next_segment() -> void:
	var options: Array = (_adj[to_id] as Array).duplicate()
	if options.size() > 1:
		options.erase(from_id)   # don't turn straight back unless it's a dead end
	from_id = to_id
	to_id = options[rng.randi() % options.size()]
	_set_goal()
	if rng.randf() < 0.3:
		pause = rng.randf_range(1.5, 5.0)

func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var to_p := (p.global_position - global_position) if p != null else Vector3(999, 0, 999)
	to_p.y = 0.0
	var pd := to_p.length()
	var far := pd > ACTIVE_RANGE
	if far != _far:
		_far = far
		model.visible = not far
		model.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT

	var to_goal := goal - global_position
	to_goal.y = 0.0
	var dir := to_goal.normalized() if to_goal.length() > 0.01 else Vector3.ZERO
	# stop if the player stands right in front of us
	var blocked := pd < 1.6 and dir != Vector3.ZERO and dir.dot(to_p / maxf(pd, 0.01)) > 0.3
	var moving := pause <= 0.0 and not blocked
	if pause > 0.0:
		pause -= delta
	if moving:
		var step := minf(speed * delta, to_goal.length())
		global_position += dir * step
		if to_goal.length() < 0.3:
			_next_segment()
	if far:
		return
	if moving and dir != Vector3.ZERO:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-6.0 * delta))
	elif blocked and pd > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to_p.x, -to_p.z), 1.0 - exp(-4.0 * delta))
	Hero.play_move(model, Hero.move_state(speed) if moving else "idle", speed if moving else 0.0)
	# glance at the player when they're close
	if pd < 7.0 and pd > 0.1:
		var want := wrapf(atan2(-to_p.x, -to_p.z) - model.global_rotation.y, -PI, PI)
		var dy := (p.global_position.y + 1.5) - (global_position.y + 1.6)
		HeadLook.drive(model, want, atan2(dy, pd), delta)
	else:
		HeadLook.drive(model, 0.0, 0.0, delta)
