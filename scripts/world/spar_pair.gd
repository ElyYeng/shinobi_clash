class_name SparPair
extends Node3D
## Two random shinobi fighting to the death outside the village, using the game's moveset:
## punch combos (slash VFX), dash strikes, kunai, fireballs and chakra bursts. When one runs
## out of health it ragdolls and fades away, and a fresh random challenger appears in a puff
## of smoke. Purely for show - they ignore the player and deal no real damage.

const NEAR := 60.0      # only fight when the player is this close
const DIST := 2.6       # stance distance
const MAX_HP := 100.0

var f: Array = []       # two fighters: {"m": Node3D, "hp": float}
var _angle := 0.0
var _next := 1.0
var _busy := 0.0        # a move (or a death) is playing out
var _rng := RandomNumberGenerator.new()
var _seed := 0

static func spawn(parent: Node, pos: Vector3, seed_: int) -> SparPair:
	var s := SparPair.new()
	s._rng.seed = seed_
	s._seed = seed_
	parent.add_child(s)
	s.global_position = pos
	return s

func _ready() -> void:
	f = [{"m": _ninja(), "hp": MAX_HP}, {"m": _ninja(), "hp": MAX_HP}]
	_angle = _rng.randf() * TAU
	_place(0.0)

func _ninja() -> Node3D:
	var m := Hero.create({})
	add_child(m)
	if m != null and m.has_meta("hero_parts"):
		Hero.randomize_look(m, _rng, Hero.VILLAGER_EXCLUDE)
	return m

func _alive(i: int) -> bool:
	return is_instance_valid(f[i]["m"]) and float(f[i]["hp"]) > 0.0

## Both on a slowly turning circle, facing each other.
func _place(delta: float) -> void:
	var off := Vector3(cos(_angle), 0.0, sin(_angle)) * DIST * 0.5
	for i in 2:
		var m: Node3D = f[i]["m"]
		if not is_instance_valid(m):
			continue
		var want := off if i == 0 else -off
		m.position = m.position.lerp(want, minf(1.0, 6.0 * delta)) if delta > 0.0 else want
		var other: Node3D = f[1 - i]["m"]
		if is_instance_valid(other):
			var to := other.position - m.position
			to.y = 0.0
			if to.length() > 0.01:
				m.rotation.y = lerp_angle(m.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-12.0 * delta)) if delta > 0.0 else atan2(-to.x, -to.z)

func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or p.global_position.distance_to(global_position) > NEAR:
		return
	if _busy > 0.0:
		_busy -= delta
		return
	if not (_alive(0) and _alive(1)):
		return
	_angle += delta * 0.35   # circle each other
	_place(delta)
	for i in 2:
		Hero.play_move(f[i]["m"], "idle", 0.0)
	_next -= delta
	if _next <= 0.0:
		_attack(_rng.randi() % 2)

## The attacker picks a move from the moveset.
func _attack(a: int) -> void:
	var d := 1 - a
	var atk: Node3D = f[a]["m"]
	var def: Node3D = f[d]["m"]
	var roll := _rng.randf()
	if roll < 0.4:
		_combo(atk, d, _rng.randi_range(2, 3))
	elif roll < 0.55:
		_dash_strike(atk, d)
	elif roll < 0.7:
		_kunai(atk, d)
	elif roll < 0.85:
		_fireball(atk, d)
	else:
		_chakra_burst(atk, d)
	_next = _rng.randf_range(0.25, 0.8)   # (counted after the move finishes)

func _dir(from: Node3D, to: Node3D) -> Vector3:
	var v := (to.global_position - from.global_position) * Vector3(1, 0, 1)
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD

## Damage the defender (index `d`); kills / knockdowns handled here.
func _hurt(d: int, amount: float, from: Node3D, knock := 0.0) -> void:
	var m: Node3D = f[d]["m"]
	if not is_instance_valid(m) or float(f[d]["hp"]) <= 0.0:
		return
	f[d]["hp"] = float(f[d]["hp"]) - amount
	Sfx.play(self, "hit", -10.0)
	VfxKit.hit(get_parent(), m.global_position + Vector3.UP * 1.2, null, 0.6)
	if float(f[d]["hp"]) <= 0.0:
		_die(d, _dir(from, m))
	elif knock > 0.0:
		var r := Ragdoll.knockdown(m, get_parent(), _dir(from, m) * knock + Vector3.UP * 3.0, 1.4)
		if r != null:
			_busy = maxf(_busy, 1.4 + Enemy.RISE_TIME + 0.3)
			get_tree().create_timer(1.4 + Enemy.RISE_TIME + 0.2).timeout.connect(func() -> void:
				_place(0.0))
	else:
		Hero.play(m, "hurt", true, 0, 0.3)

func _combo(atk: Node3D, d: int, hits: int) -> void:
	_busy = hits * 0.42 + 0.3
	var def: Node3D = f[d]["m"]
	for i in hits:
		get_tree().create_timer(i * 0.42).timeout.connect(func() -> void:
			if not is_instance_valid(atk) or not is_instance_valid(def) or float(f[d]["hp"]) <= 0.0:
				return
			var dir := _dir(atk, def)
			Hero.play(atk, "attack", true, i, 0.4)
			Sfx.play(self, "swing", -10.0)
			Vfx.slash(get_parent(), atk.global_position + Vector3.UP * 1.1, dir, Color(0.85, 0.92, 1.0), i + 1, 1.8)
			var home := atk.position
			var tw := atk.create_tween()   # step in with the punch
			tw.tween_property(atk, "position", home + dir * 0.5, 0.1)
			tw.tween_property(atk, "position", home, 0.22)
			get_tree().create_timer(0.16).timeout.connect(_hurt.bind(d, 7.0, atk, 5.0 if i == 2 and _rng.randf() < 0.5 else 0.0)))

func _dash_strike(atk: Node3D, d: int) -> void:
	_busy = 0.9
	var def: Node3D = f[d]["m"]
	var dir := _dir(atk, def)
	var home := atk.position
	Sfx.play(self, "dash", -8.0)
	Hero.play(atk, "attack", true, 2, 0.5)
	Fx.puff(get_parent(), atk.global_position + Vector3.UP * 0.5, Color(0.8, 0.8, 0.8, 0.6), 0.6)
	var tw := atk.create_tween()
	tw.tween_property(atk, "position", home + dir * (DIST + 0.8), 0.18)   # dash through
	tw.tween_callback(func() -> void:
		Vfx.slash(get_parent(), atk.global_position + Vector3.UP * 1.1, -dir, Color(1.0, 0.95, 0.7), 3, 2.4)
		_hurt(d, 12.0, atk))
	tw.tween_interval(0.25)
	tw.tween_property(atk, "position", home, 0.3)

func _throw(atk: Node3D, def: Node3D, visual: String, size: float, speed: float, col: Color, long: bool) -> float:
	var from := atk.global_position + Vector3.UP * 1.3 + _dir(atk, def) * 0.6
	var to := def.global_position + Vector3.UP * 1.1
	var pr := Projectile.new()
	pr.speed = speed
	pr.velocity = (to - from).normalized() * speed
	pr.damage = 0.0   # (show only)
	pr.size = size
	pr.color = col
	pr.long_shape = long
	pr.visual_kind = visual
	pr.life = from.distance_to(to) / speed
	get_parent().add_child(pr)
	pr.global_position = from
	return pr.life

func _kunai(atk: Node3D, d: int) -> void:
	_busy = 0.7
	Hero.play(atk, "attack", true, 1, 0.35)
	Sfx.play(self, "swing", -10.0)
	for k in 2:
		get_tree().create_timer(k * 0.15).timeout.connect(func() -> void:
			if is_instance_valid(atk) and is_instance_valid(f[d]["m"]):
				var t := _throw(atk, f[d]["m"], "", 0.12, 34.0, Color(0.8, 0.8, 0.85), true)
				get_tree().create_timer(t).timeout.connect(_hurt.bind(d, 6.0, atk)))

func _fireball(atk: Node3D, d: int) -> void:
	_busy = 1.3
	Hero.play(atk, "jutsu", true)
	Sfx.play(self, "fire", -6.0)
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if is_instance_valid(atk) and is_instance_valid(f[d]["m"]):
			var t := _throw(atk, f[d]["m"], "fireball", 0.5, 16.0, Color(1.0, 0.5, 0.15), false)
			get_tree().create_timer(t).timeout.connect(_hurt.bind(d, 18.0, atk, 4.0)))

func _chakra_burst(atk: Node3D, d: int) -> void:
	_busy = 1.1
	Hero.play(atk, "jutsu", true)
	var col := Color.from_hsv(_rng.randf(), 0.7, 1.0)
	Vfx.aura_flames(atk, Vector3(0, 1.0, 0), 0.5, col, 20, true)
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if not is_instance_valid(atk):
			return
		for c in atk.get_children():   # the charge flames go out
			if c is CPUParticles3D:
				(c as CPUParticles3D).emitting = false
		Vfx.shockwave(get_parent(), atk.global_position, col, 4.5, 0.45)
		Sfx.play(self, "power", -8.0)
		_hurt(d, 15.0, atk, 6.0))

## Out of health: ragdoll, fade away, and a new challenger appears.
func _die(d: int, dir: Vector3) -> void:
	var m: Node3D = f[d]["m"]
	_busy = 5.0
	var r := Ragdoll.start(m, get_parent(), dir * 7.0 + Vector3.UP * 4.0)
	var w: Node3D = f[1 - d]["m"]
	if is_instance_valid(w):
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_instance_valid(w):
				Hero.play(w, "jutsu", true))   # victory pose
	get_tree().create_timer(2.8).timeout.connect(func() -> void:
		var at: Vector3 = m.global_position if is_instance_valid(m) else global_position
		if r != null and is_instance_valid(r):
			at = r.hips()
		Fx.puff(get_parent(), at + Vector3.UP * 0.4, Color(0.85, 0.85, 0.85, 0.8), 1.2)
		if is_instance_valid(m):
			m.queue_free()
		if r != null and is_instance_valid(r):
			r.queue_free())
	get_tree().create_timer(4.2).timeout.connect(func() -> void:   # next challenger
		var n := _ninja()
		f[d] = {"m": n, "hp": MAX_HP}
		f[1 - d]["hp"] = MAX_HP   # the winner catches their breath
		_angle = _rng.randf() * TAU
		_place(0.0)
		Fx.puff(get_parent(), n.global_position + Vector3.UP * 1.0, Color(0.9, 0.9, 0.9, 0.85), 1.4)
		Sfx.play(self, "teleport", -8.0))
