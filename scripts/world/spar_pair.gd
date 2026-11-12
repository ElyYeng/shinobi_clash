class_name SparPair
extends Node3D
## Two random shinobi sparring outside the village: they circle each other, trade punch combos
## (hit sparks + sounds) and now and then a combo finisher sends one flying (ragdoll) - they get
## back up and go again. Purely for show: they ignore the player.

var a: Node3D
var b: Node3D
var _t := 0.0
var _angle := 0.0
var _next := 1.0
var _down := 0.0          # someone is on the ground
var _rng := RandomNumberGenerator.new()

const DIST := 1.7         # how far apart they stand
const NEAR := 60.0        # only animate when the player is this close

static func spawn(parent: Node, pos: Vector3, seed_: int) -> SparPair:
	var s := SparPair.new()
	s._rng.seed = seed_
	parent.add_child(s)
	s.global_position = pos
	return s

func _ready() -> void:
	a = _ninja()
	b = _ninja()
	_angle = _rng.randf() * TAU
	_place(0.0)

func _ninja() -> Node3D:
	var m := Hero.create({})
	add_child(m)
	if m != null and m.has_meta("hero_parts"):
		Hero.randomize_look(m, _rng, Hero.VILLAGER_EXCLUDE)
	return m

## Put both on the circle facing each other.
func _place(delta: float) -> void:
	var off := Vector3(cos(_angle), 0.0, sin(_angle)) * DIST * 0.5
	a.position = a.position.lerp(off, minf(1.0, 8.0 * delta)) if delta > 0.0 else off
	b.position = b.position.lerp(-off, minf(1.0, 8.0 * delta)) if delta > 0.0 else -off
	for pair in [[a, b], [b, a]]:
		var me: Node3D = pair[0]
		var to: Vector3 = (pair[1] as Node3D).position - me.position
		to.y = 0.0
		if to.length() > 0.01:
			me.rotation.y = atan2(-to.x, -to.z)

func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or p.global_position.distance_to(global_position) > NEAR:
		return
	_t += delta
	if _down > 0.0:
		_down -= delta
		return
	# circle slowly (strafing) between exchanges
	_angle += delta * 0.6
	_place(delta)
	var moving := fmod(_t, 4.0) < 1.5
	for m in [a, b]:
		Hero.play_move(m, "strafe_l" if moving else "idle", 2.0 if moving else 0.0)
	_next -= delta
	if _next <= 0.0:
		_exchange()

## One exchange: the attacker throws 1-3 punches; the 3rd can knock the defender down.
func _exchange() -> void:
	var atk := a if _rng.randf() < 0.5 else b
	var def := b if atk == a else a
	var hits := _rng.randi_range(1, 3)
	_next = 0.9 + hits * 0.45 + _rng.randf() * 1.5
	for i in hits:
		get_tree().create_timer(i * 0.42).timeout.connect(_punch.bind(atk, def, i, i == 2 and _rng.randf() < 0.55))

func _punch(atk: Node3D, def: Node3D, i: int, finisher: bool) -> void:
	if not is_instance_valid(atk) or not is_instance_valid(def) or _down > 0.0:
		return
	Hero.play(atk, "attack", true, i, 0.4)
	var hit_at := def.global_position + Vector3.UP * 1.2
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		if not is_instance_valid(def) or _down > 0.0:
			return
		Sfx.play(self, "hit", -10.0)
		VfxKit.hit(get_parent(), hit_at, null, 0.6)
		if finisher:
			var dir := def.global_position - atk.global_position
			dir.y = 0.0
			var r := Ragdoll.knockdown(def, get_parent(), dir.normalized() * 5.0 + Vector3.UP * 3.0, 1.8)
			if r != null:
				_down = 1.8 + Enemy.RISE_TIME + 0.4
				get_tree().create_timer(_down).timeout.connect(func() -> void:
					if is_instance_valid(def):   # back in position after getting up
						_place(0.0))
		else:
			Hero.play(def, "hurt", true, 0, 0.3))
