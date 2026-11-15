class_name Shien
extends RefCounted
## Shien - Violet Calamity (original Legendary bloodline: Lightning + Yin violet flame).
## Data (damage, cooldown, range, mastery levels, brand numbers) lives in Bloodline.DEFS["shien"];
## this file only holds the move behaviour + Violet Brand. Moves are "custom" abilities whose "fn"
## is a one-line wrapper in player.gd (_fx_shien_*), so cost, cooldown, hotbar and mastery all use
## the normal bloodline pipeline.
##
## Slots (this game has 3 bloodline slots + the C power-up):
##   1 Demon Claw   2 Violet Cremation   3 Phantom Bind (LV 500)
## Power-up (Violet Awakening, LV 1000) swaps them for:
##   1 Demon Rush    2 Phantom Wolves    3 Calamity Burst
## Placeholder visuals: procedural additive meshes (no new art assets).

const COL := Color("#A44BFF")
const EDGE := Color("#7137D8")
const PLUM := Color("#35134F")
const LAV := Color("#E3CCFF")

# ---------------------------------------------------------------- helpers
static func _spec(p) -> Dictionary:
	return Moves.spec(p.cur_move)

static func _cast(p) -> int:
	var n := int(p.get_meta("shien_cast", 0)) + 1
	p.set_meta("shien_cast", n)
	return n

static func _total(p, s: Dictionary) -> float:
	return float(s["dmg"]) * p._dmg() * p._bl_mult()

static func _aim(p) -> Vector3:
	var dir: Vector3 = p.facing
	if p._alive(p.lock_target):
		var d: Vector3 = (p.lock_target.global_position - p.global_position) * Vector3(1, 0, 1)
		if d.length() > 0.1:
			dir = d.normalized()
	return dir

static func _target(p, r: float) -> Node3D:
	if p._alive(p.lock_target) and p.lock_target.global_position.distance_to(p.global_position) <= r:
		return p.lock_target
	return p._nearest_foe(r)

## Runs fn after `secs`, only if the caster is still around and alive.
static func _later(p, secs: float, fn: Callable) -> void:
	p.get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(p) and p.is_inside_tree() and not p.is_dead:
			fn.call())

## One confirmed hit on a foe (mastery XP + Violet Brand through Player._hit).
static func strike(p, e, amount: float, knock := Vector3.ZERO) -> void:
	if not is_instance_valid(e):
		return
	p.cur_mkey = "shien"
	p._hit_foe(e, amount, knock)
	p.cur_mkey = ""

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# ---------------------------------------------------------------- Violet Brand
static func _brand_cfg() -> Dictionary:
	return Bloodline.get_def("shien").get("brand", {"secs": 6.0, "bonus": 1.10})

## Called from Player._hit for every Shien hit. First brand interaction per target per cast only:
## a Brand on the target is consumed for bonus damage, otherwise the hit applies/refreshes one.
static func on_hit(p, e, amount: float) -> float:
	if not is_instance_valid(e) or not (e is Enemy) or amount < 8.0:   # no DoT ticks
		return amount
	var cast := int(p.get_meta("shien_cast", 0))
	if int(e.get_meta("shien_seen", -1)) == cast:
		return amount
	e.set_meta("shien_seen", cast)
	var cfg := _brand_cfg()
	if int(e.get_meta("brand_until", 0)) > Time.get_ticks_msec():
		clear_brand(e)
		Sfx.play(p, "zap", -2.0)
		Vfx.burst(p.get_parent(), e.global_position + Vector3.UP * 1.2, COL, 22, 7.0, 0.2, 0.5, 0.0)
		return amount * float(cfg["bonus"])
	_apply_brand(p, e, float(cfg["secs"]))
	return amount

static func _apply_brand(p, e: Node3D, secs: float) -> void:
	clear_brand(e)   # one Brand per target: refresh, never stack
	e.set_meta("brand_until", Time.get_ticks_msec() + int(secs * 1000.0))
	Sfx.play(p, "zap", -9.0)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.42
	var mark := MythicFx._mesh(e, torus, MythicFx._glow_mat(COL, 0.9), e.global_position + Vector3.UP * 2.5 * float(e.get("k") if e.get("k") != null else 1.0))
	mark.name = "VioletBrand"
	mark.rotation_degrees = Vector3(90, 0, 0)
	var core := MythicFx._mesh(mark, MythicFx._sphere(0.14, 8), MythicFx._glow_mat(LAV, 0.9), mark.global_position)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := mark.create_tween()
	tw.tween_interval(maxf(secs - 0.4, 0.1))
	tw.tween_property(mark, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(mark.queue_free)

static func clear_brand(e: Node) -> void:
	if not is_instance_valid(e):
		return
	e.set_meta("brand_until", 0)
	var m := e.get_node_or_null("VioletBrand")
	if m != null:
		m.queue_free()
		m.name = "VioletBrand_gone"

# ---------------------------------------------------------------- visuals
static func _pillar(world: Node3D, pos: Vector3, h: float, r: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = r
	cyl.top_radius = r * 0.25
	cyl.height = h
	var gy := MythicFx._ground(world, pos)
	var mi := MythicFx._mesh(world, cyl, MythicFx._glow_mat(COL, 0.8), Vector3(pos.x, gy + h * 0.025, pos.z))
	mi.scale = Vector3(1, 0.05, 1)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "global_position:y", gy + h * 0.5, 0.18)
	tw.chain().tween_property(mi.material_override, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)
	Vfx.burst(world, Vector3(pos.x, gy + 0.3, pos.z), COL, 26, 7.0, 0.22, 0.6, -2.0)
	Vfx.shockwave(world, Vector3(pos.x, gy + 0.2, pos.z), EDGE, r * 2.2, 0.35)

static func _chain(world: Node3D, a: Vector3, b: Vector3, secs: float) -> void:
	var dist := a.distance_to(b)
	if dist < 0.1:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = dist
	var mi := MythicFx._mesh(world, cyl, MythicFx._glow_mat(COL, 0.9), (a + b) * 0.5)
	mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	MythicFx._fade(mi, 0.25, secs)

static func _flash(world: Node3D, pos: Vector3, size: float) -> void:
	Vfx.sprite_flash(world, pos, "effects/Impact24.png", COL, size, 0.2)

# ---------------------------------------------------------------- 1: Demon Claw
static func claw(p, _col: Color) -> void:
	var s := _spec(p)
	_cast(p)
	var dir := _aim(p)
	p.facing = dir
	p.dash_dir = dir
	p.dash_time = float(s["lunge"]) / p.DASH_SPEED
	Vfx.trail(p, COL, 0.35, 40, 0.5)
	var total := _total(p, s)
	var shares := [0.3, 0.3, 0.4]
	var times := [0.08, 0.24, 0.4]
	for i in 3:
		_later(p, float(times[i]), func() -> void:
			var world: Node3D = p.get_parent()
			_flash(world, p.global_position + Vector3.UP * 1.3 + dir * 1.6, 2.4)
			Vfx.burst(world, p.global_position + Vector3.UP * 1.3 + dir * 1.4, COL, 12, 6.0, 0.15, 0.3, 0.0)
			for e in p._foes_in(float(s["r"])):
				var to: Vector3 = (e.global_position - p.global_position) * Vector3(1, 0, 1)
				if to.length() > 0.1 and to.normalized().dot(dir) > 0.3:
					if i == 2:
						p._stun(e, float(s["stun"]))   # final claw staggers / launches
					strike(p, e, total * float(shares[i]), (Vector3.UP * 5.0 + dir * 9.0) if i == 2 else dir * 2.0))

# ---------------------------------------------------------------- 2: Violet Cremation
static func cremation(p, _col: Color) -> void:
	var s := _spec(p)
	_cast(p)
	var world: Node3D = p.get_parent()
	var f: Vector3 = p.facing
	var r := float(s["r"])
	var tgt := _target(p, r)
	var center: Vector3 = tgt.global_position if tgt != null else p.global_position + f * 7.0
	var side := Vector3(-f.z, 0, f.x)
	var spots: Array[Vector3] = [center, center + side * 3.6 - f * 1.2, center - side * 3.6 + f * 1.2]
	var per := _total(p, s) / 3.0
	var hits := {}   # target id -> pillars that hit it (capped per cast)
	for i in 3:
		var spot := spots[i]
		MythicFx._ring(world, Vector3(spot.x, MythicFx._ground(world, spot) + 0.1, spot.z), 3.0, COL, 0.6 + 0.35 * i, 1.0)   # warning
		_later(p, 0.6 + 0.35 * i, func() -> void:
			_pillar(world, spot, 9.0, 1.5)
			Vfx.shake(p.cam, 0.12, 0.2)
			for e in p._foes_in(60.0):
				var id: int = e.get_instance_id()
				if _flat(e.global_position, spot) <= 2.8 and int(hits.get(id, 0)) < int(s["max_hits"]):
					hits[id] = int(hits.get(id, 0)) + 1
					if i == 2:
						p._stun(e, float(s["stun"]))
					strike(p, e, per, Vector3.UP * (6.0 if i == 2 else 1.0)))

# ---------------------------------------------------------------- 3: Phantom Bind
static func bind(p, _col: Color) -> void:
	var s := _spec(p)
	_cast(p)
	var e := _target(p, float(s["r"]))
	if e == null:   # nothing to chain: give the cost back
		p.chakra += float(s["cost"])
		p.move_cd[p.cur_move] = 0.0
		p._toast("No enemy in range (%dm)" % int(s["r"]))
		return
	var world: Node3D = p.get_parent()
	var from: Vector3 = p.global_position + Vector3.UP * 1.4
	_chain(world, from, e.global_position + Vector3.UP * 1.2, float(s["root"]))
	Sfx.play(p, "zap", -4.0)
	strike(p, e, _total(p, s), Vector3.ZERO)
	if not (e is Enemy):
		return   # PvP avatars: the host validates damage only (no root/pull from here)
	p._stun(e, float(s["root"]))
	if e.is_boss or float(e.k) > 1.6:   # bosses / large targets resist the pull
		return
	var away: Vector3 = (p.global_position - e.global_position) * Vector3(1, 0, 1)
	var gap := away.length()
	if gap < 2.5:
		return
	var dest: Vector3 = e.global_position + away.normalized() * minf(float(s["pull"]), gap - 2.0)
	var space := world.get_world_3d().direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(e.global_position + Vector3.UP, dest + Vector3.UP, 1))
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(dest + Vector3.UP * 2.0, dest + Vector3.DOWN * 4.0, 1))
	if not wall.is_empty() or floor_hit.is_empty():   # no pulling through walls or off the map
		return
	dest.y = float((floor_hit["position"] as Vector3).y)
	e.create_tween().tween_property(e, "global_position", dest, 0.2)

# ---------------------------------------------------------------- mode 1: Demon Rush
static func rush(p, _col: Color) -> void:
	var s := _spec(p)
	_cast(p)
	var dir := _aim(p)
	var dist := float(s["lunge"])
	p.facing = dir
	p.dash_dir = dir
	p.dash_time = dist / p.DASH_SPEED
	var world: Node3D = p.get_parent()
	Vfx.trail(p, COL, 0.4, 50, 0.6)
	Vfx.burst(world, p.global_position + Vector3.UP, COL, 30, 8.0, 0.25, 0.5, 0.0)   # afterimage burst where you started
	MythicFx._flash(world, p.global_position + Vector3.UP, COL, 3.0, 8.0, 0.3)
	var dmg := _total(p, s)
	_later(p, dist / p.DASH_SPEED + 0.05, func() -> void:   # flaming uppercut where the dash ended
		_flash(world, p.global_position + Vector3.UP * 1.4 + dir * 1.5, 3.2)
		for e in p._foes_in(float(s["r"])):
			var to: Vector3 = (e.global_position - p.global_position) * Vector3(1, 0, 1)
			if to.length() < 0.1 or to.normalized().dot(dir) > -0.2:
				p._stun(e, float(s["stun"]))
				strike(p, e, dmg, Vector3.UP * 9.0 + dir * 4.0))

# ---------------------------------------------------------------- mode 2: Phantom Wolves
class Wolf extends Node3D:
	var caster
	var dmg := 0.0
	var vel := Vector3.ZERO
	var life := 2.2
	var speed := 17.0
	var target: Node3D

	func _ready() -> void:
		var mat := MythicFx._glow_mat(Shien.COL, 0.85)
		var body := MeshInstance3D.new()
		body.mesh = MythicFx._sphere(0.4, 8)
		body.scale = Vector3(0.9, 0.8, 1.8)
		body.material_override = mat
		add_child(body)
		var head := MeshInstance3D.new()
		head.mesh = MythicFx._sphere(0.28, 8)
		head.material_override = mat
		head.position = Vector3(0, 0.3, -0.85)
		add_child(head)
		for sx in [-0.14, 0.14]:
			var ear := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.1
			cone.height = 0.3
			ear.mesh = cone
			ear.material_override = mat
			ear.position = Vector3(sx, 0.6, -0.8)
			add_child(ear)
		var tail := MeshInstance3D.new()
		tail.mesh = MythicFx._sphere(0.2, 8)
		tail.scale = Vector3(0.7, 0.7, 2.0)
		tail.material_override = mat
		tail.position = Vector3(0, 0.15, 1.0)
		add_child(tail)
		Vfx.trail(self, Shien.COL, 0.3, 30, 0.4)

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0 or not is_instance_valid(caster) or bool(caster.get("is_dead")):
			queue_free()
			return
		var foes: Array = caster._foes_in(80.0)
		if not is_instance_valid(target) or not foes.has(target):
			target = null
			var best := 40.0
			for e in foes:
				var d: float = e.global_position.distance_to(global_position)
				if d < best:
					best = d
					target = e
		if target != null:   # limited tracking: it turns slowly, so it can be dodged
			var want := (target.global_position + Vector3.UP - global_position).normalized() * speed
			vel = vel.lerp(want, minf(delta * 2.5, 1.0))
		global_position += vel * delta
		if vel.length() > 0.1:
			look_at(global_position + vel, Vector3.UP)
		for e in foes:
			if e.global_position.distance_to(global_position - Vector3.UP * 0.8) < 1.7:
				Shien.strike(caster, e, dmg, vel.normalized() * 8.0)
				Vfx.burst(get_parent(), global_position, Shien.COL, 20, 6.0, 0.2, 0.4, 0.0)
				Vfx.shockwave(get_parent(), global_position, Shien.EDGE, 3.0, 0.25)
				queue_free()   # each wolf hits once
				return

static func wolves(p, _col: Color) -> void:
	var s := _spec(p)
	_cast(p)
	var f: Vector3 = _aim(p)
	var n := int(s["wolves"])
	for i in n:
		var w := Wolf.new()
		w.caster = p
		w.dmg = _total(p, s) / float(n)
		w.speed = float(s["speed"])
		var ang := deg_to_rad(float(s["spread"])) * (float(i) - float(n - 1) * 0.5)
		w.vel = (f.rotated(Vector3.UP, ang) + Vector3.UP * 0.1).normalized() * w.speed
		p.get_parent().add_child(w)
		w.global_position = p.global_position + Vector3.UP * 1.3 + f * 1.2
	Vfx.burst(p.get_parent(), p.global_position + Vector3.UP * 1.3 + f, COL, 24, 6.0, 0.2, 0.4, 0.0)

# ---------------------------------------------------------------- mode 3: Calamity Burst
static func calamity(p, _col: Color) -> void:
	var s := _spec(p)
	_cast(p)
	var world: Node3D = p.get_parent()
	var f: Vector3 = _aim(p)
	var tgt := _target(p, float(s["r"]))
	var spot: Vector3 = tgt.global_position if tgt != null else p.global_position + f * 14.0
	spot.y = MythicFx._ground(world, spot)
	var rad := float(s["blast"])
	var charge := float(s["charge"])
	MythicFx._ring(world, spot + Vector3.UP * 0.1, rad, COL, charge + 0.4, 1.0)   # impact warning
	var orb := MythicFx._mesh(world, MythicFx._sphere(0.6, 10), MythicFx._glow_mat(COL, 0.8), p.global_position + Vector3.UP * 3.3)
	var tw := orb.create_tween()
	tw.tween_property(orb, "scale", Vector3.ONE * 2.6, charge)
	tw.tween_callback(orb.queue_free)
	MythicFx._flash(world, p.global_position + Vector3.UP * 3.0, COL, 4.0, 14.0, charge)
	var dmg := _total(p, s)
	_later(p, charge, func() -> void:
		_serpent(world, spot, rad, p, s, dmg))

static func _serpent(world: Node3D, spot: Vector3, rad: float, p, s: Dictionary, dmg: float) -> void:
	var head := spot + Vector3(0, 24, 0) + Vector3(sin(spot.x), 0, cos(spot.z)) * 10.0
	var segs: Array[MeshInstance3D] = []
	for i in 12:
		var m := MythicFx._mesh(world, MythicFx._sphere(1.1 - i * 0.07, 8), MythicFx._glow_mat(COL if i % 2 == 0 else EDGE, 0.85), head)
		segs.append(m)
	var tw := world.create_tween()
	tw.tween_method(_serpent_step.bind(segs, head, spot), 0.0, 1.35, 0.45)
	tw.tween_callback(func() -> void:
		for m in segs:
			if is_instance_valid(m):
				MythicFx._fade(m, 0.4)
		_explode(world, spot, rad, p, s, dmg))

static func _serpent_step(t: float, segs: Array, head: Vector3, spot: Vector3) -> void:
	for i in segs.size():
		if is_instance_valid(segs[i]):
			var k := clampf(t - float(i) * 0.05, 0.0, 1.0)
			segs[i].global_position = head.lerp(spot + Vector3.UP * 0.5, k) + Vector3(sin(k * 9.0 + i), 0, cos(k * 9.0 + i)) * 0.8 * (1.0 - k)

static func _explode(world: Node3D, spot: Vector3, rad: float, p, s: Dictionary, dmg: float) -> void:
	MythicFx._ring(world, spot + Vector3.UP * 0.1, rad, COL, 0.5, 1.0)
	MythicFx._flash(world, spot + Vector3.UP * 2.0, COL, 8.0, rad * 2.0, 0.5)
	Vfx.burst(world, spot + Vector3.UP, COL, 80, 14.0, 0.35, 0.9, -3.0)
	Vfx.shockwave(world, spot + Vector3.UP * 0.2, COL, rad, 0.5)
	var cam := world.get_viewport().get_camera_3d()
	if cam != null:
		Vfx.shake(cam, 0.4, 0.5)
	if not is_instance_valid(p) or bool(p.get("is_dead")):
		return
	for e in p._foes_in(120.0):
		if _flat(e.global_position, spot) <= rad:
			var out: Vector3 = (e.global_position - spot) * Vector3(1, 0, 1)
			p._stun(e, float(s["stun"]))
			strike(p, e, dmg, out.normalized() * 14.0 + Vector3.UP * 5.0)
