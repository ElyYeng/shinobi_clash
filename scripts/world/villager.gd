class_name Villager
extends Node3D
## Ambient villagers that stroll the Konoha greybox streets (cosmetic - no collision).
## They follow a small street graph, keep to their side of the road, pause now and then and glance
## at nearby players. Multiplayer: every villager's walk is a fixed function of its seed and a
## shared clock (Villager.now(); the host sends its clock through NetworkSession), so everyone
## sees the same people in the same places without streaming their positions.
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
const ACTIVE_RANGE := 75.0     # further than this from the player: hidden, not animated

var model: Node3D
var speed := 1.4
var lane_jitter := 0.0
var from_id := ""
var to_id := ""
var goal := Vector3.ZERO
var pause := 0.0
var rng := RandomNumberGenerator.new()
var _far := false
var _leg_start := Vector3.ZERO    # current leg: walk from _leg_start (at _t0) to goal (at _t1),
var _t0 := 0.0                    # then stand still until _t2
var _t1 := 0.0
var _t2 := 0.0

static var _adj: Dictionary = {}
static var _all: Array = []        # villagers by index (quest givers are looked up by it)
const FIRST := ["Haruto", "Yui", "Sota", "Hina", "Ren", "Aoi", "Kaito", "Mei", "Riku", "Sakura",
	"Takumi", "Nanami", "Daiki", "Emi", "Kenta", "Mio", "Shin", "Rika", "Yuto", "Kana"]
const ROLE := ["Shopkeeper", "Farmer", "Baker", "Fisher", "Potter", "Tea Seller", "Carpenter", "Old", "Young",
	"Weaver", "Courier", "Herbalist"]

var index := 0
var _marker: Label3D
var held := false        # stands still (and looks at you) while you talk to them
var _catch := 0.0        # after talking: seconds left easing back onto the shared route

static func name_for(i: int) -> String:
	return "%s %s" % [ROLE[(i * 7 + 3) % ROLE.size()], FIRST[(i * 11 + 5) % FIRST.size()]]

static func by_index(i: int) -> Villager:
	return _all[i] if i >= 0 and i < _all.size() and is_instance_valid(_all[i]) else null

## Villagers within `r` m of `pos` (nearest first).
static func near(pos: Vector3, r: float) -> Villager:
	var best: Villager = null
	var bd := r
	for v in _all:
		if is_instance_valid(v):
			var d: float = (v as Villager).global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = v
	return best
## Shared villager clock: seconds since the host's villagers started (clients get the host's value).
static var _clock_base := 0.0

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0 - _clock_base

## Clients: adopt the host's villager time (small differences are eased to avoid popping).
static func sync_clock(host_time: float) -> void:
	var want := Time.get_ticks_msec() / 1000.0 - host_time
	_clock_base = want if absf(want - _clock_base) > 1.5 else lerpf(_clock_base, want, 0.3)

static func populate(parent: Node, count: int, seed_base := 77) -> void:
	_build_adj()
	_clock_base = Time.get_ticks_msec() / 1000.0   # host / single player: start the clock now
	_all.clear()
	var edges := EDGES.duplicate()
	for i in count:
		var v := Villager.new()
		v.name = "Villager%d" % i
		v.index = i
		_all.append(v)
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
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.font_size = 96
	_marker.outline_size = 18
	_marker.modulate = Color(1.0, 0.9, 0.2)
	_marker.position = Vector3(0, 2.5, 0)
	_marker.no_depth_test = true
	add_child(_marker)
	_set_goal()
	position += _lane_offset(from_id, to_id)   # start on our side of the road
	_leg_start = position
	_t0 = 0.0
	_t1 = position.distance_to(goal) / speed
	_t2 = _t1

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
	pause = rng.randf_range(1.5, 5.0) if rng.randf() < 0.3 else 0.0

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

	# walk along the timeline to the shared clock (same result on every machine)
	var t := now()
	var guard := 0
	while t >= _t2 and guard < 200:
		guard += 1
		_leg_start = goal
		_next_segment()
		_t0 = _t2 + pause
		_t1 = _t0 + _leg_start.distance_to(goal) / speed
		_t2 = _t1
	var dir := goal - _leg_start
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	var moving := t >= _t0 and t < _t1
	var k := clampf(inverse_lerp(_t0, _t1, t), 0.0, 1.0) if _t1 > _t0 else 1.0
	var route_pos := _leg_start.lerp(goal, k)
	if held:   # talking: stay put and look at you (the route keeps running - we catch up after)
		moving = false
		_catch = 1.5
	elif _catch > 0.0:   # walk briskly back onto the route
		_catch -= delta
		var gap := route_pos - global_position
		gap.y = 0.0
		if gap.length() > 0.05:
			global_position += gap.normalized() * minf(gap.length(), maxf(speed * 2.5, gap.length() * 3.0) * delta)
			dir = gap.normalized()
			moving = true
		else:
			_catch = 0.0
		if _catch <= 0.0:
			global_position = route_pos
	else:
		global_position = route_pos
	_update_marker()
	if far:
		return
	if moving and dir != Vector3.ZERO:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-6.0 * delta))
	Hero.play_move(model, Hero.move_state(speed) if moving else "idle", speed if moving else 0.0)
	# glance at the player when they're close
	var want := wrapf(atan2(-to_p.x, -to_p.z) - model.global_rotation.y, -PI, PI) if p != null else 0.0
	var fade := 1.0 - smoothstep(deg_to_rad(95.0), deg_to_rad(130.0), absf(want))   # not behind them
	if pd < 7.0 and pd > 0.1 and fade > 0.0:
		var dy := (p.global_position.y + 1.5) - (global_position.y + 1.6)
		HeadLook.drive(model, want * fade, atan2(dy, pd) * fade, delta)
	else:
		HeadLook.drive(model, 0.0, 0.0, delta)

## "!" = has an errand for you, "?" = you finished their errand (come back to them).
func _update_marker() -> void:
	var t := ""
	if GameData.quest_active == "":
		t = "!" if Errands.offers(index) else ""
	elif Errands.is_errand(GameData.quest_active) and Errands.villager_of(GameData.quest_active) == index:
		t = "?" if GameData.quest_state == "ready" else ""
	if _marker.text != t:
		_marker.text = t
	_marker.visible = t != "" and not _far
