class_name KokuganFx
## Kokugan (Isshiki / Jigen) techniques, Shinobi Striker style. Pure visuals with an optional
## callback for the caster's damage, so every peer can play the same thing (NetworkSession.world_fx).
##  - cube:   Daikokuten - a giant black cube drops from the sky (shadow warning first).
##  - rods:   Daikokuten: Black Rods - a line of giant stakes erupts from the ground ahead.
##  - shrink: Sukunahikona - a tiny shrunken rod flies to the target and grows huge on impact.

const BLACK := Color(0.13, 0.12, 0.16)

static func play(kind: String, world: Node3D, a: Vector3, b: Vector3, f: float, on_hit := Callable()) -> void:
	if world == null or not world.is_inside_tree():
		return
	if MythicFx.play(kind, world, a, b, f):   # Dust / Otsutsuki / Rinnegan signature effects
		return
	match kind:
		"cube":
			cube(world, a, f, on_hit)
		"rods":
			rods(world, a, b, f, on_hit)
		"shrink":
			shrink(world, a, b, on_hit)

static func _ground(world: Node3D, p: Vector3) -> float:
	var h := world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 20.0))
	return (h["position"] as Vector3).y if not h.is_empty() else p.y

static func _mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = BLACK
	return m

static func _shadow(world: Node3D, pos: Vector3, r: float) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.03
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0, 0.45)
	cm.material = sm
	s.mesh = cm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(s)
	s.global_position = pos + Vector3.UP * 0.05
	return s

## Daikokuten: the cube falls on `spot` (on_hit(spot) at impact), stays a moment, sinks away.
static func cube(world: Node3D, spot: Vector3, r: float, on_hit := Callable()) -> void:
	var ground := _ground(world, spot)
	spot.y = ground
	var c := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * r * 1.4
	bm.material = _mat()
	c.mesh = bm
	world.add_child(c)
	CharToon.apply(c)
	var rest := spot + Vector3.UP * r * 0.7
	c.global_position = rest + Vector3.UP * 22.0
	c.rotation.y = randf() * TAU
	var shadow := _shadow(world, spot, r)
	Sfx.play(world, "power", -2.0)
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", rest, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(shadow):
			shadow.queue_free()
		Sfx.play(c, "boom", 4.0)
		Vfx.shockwave(world, spot + Vector3.UP * 0.2, Color(0.5, 0.45, 0.55), r * 1.6, 0.5)
		Fx.puff(world, spot + Vector3.UP * 0.5, Color(0.6, 0.55, 0.5, 0.9), r)
		_shake(world, 0.3)
		if on_hit.is_valid():
			on_hit.call(spot))
	tw.tween_interval(2.0)
	tw.tween_property(c, "global_position", rest + Vector3.DOWN * r * 1.5, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(c.queue_free)

## Black Rods: stakes burst out of the ground one after another along `dir` (on_hit(pos) each).
static func rods(world: Node3D, origin: Vector3, dir: Vector3, length: float, on_hit := Callable()) -> void:
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var n := int(clampf(length / 2.2, 3.0, 12.0))
	var side := dir.cross(Vector3.UP)
	var tree := world.get_tree()
	for i in n:
		var p := origin + dir * (2.5 + i * length / n) + side * randf_range(-0.6, 0.6)
		tree.create_timer(i * 0.06).timeout.connect(func() -> void:
			if not is_instance_valid(world):
				return
			p.y = _ground(world, p)
			_stake(world, p, randf_range(3.2, 4.6), 0.28, dir)
			if on_hit.is_valid():
				on_hit.call(p))
	Sfx.play(world, "power", -2.0)

## One giant stake shooting out of the ground at `p`, then crumbling away.
static func _stake(world: Node3D, p: Vector3, h: float, rad: float, lean_dir: Vector3) -> void:
	var s := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = rad
	cm.height = h
	cm.radial_segments = 6
	cm.material = _mat()
	s.mesh = cm
	var piv := Node3D.new()
	world.add_child(piv)
	piv.global_position = p
	piv.add_child(s)
	s.position.y = h * 0.5
	piv.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
	piv.look_at(p + Vector3.UP * 3.0 + lean_dir * 1.2 + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), Vector3.FORWARD)
	piv.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	CharToon.apply(s)
	piv.scale = Vector3(1, 0.05, 1)
	Fx.puff(world, p + Vector3.UP * 0.3, Color(0.45, 0.4, 0.38, 0.8), 1.2)
	Sfx.play(piv, "hit", -6.0)
	var tw := piv.create_tween()
	tw.tween_property(piv, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(piv, "scale", Vector3(0.2, 0.0, 0.2), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(piv.queue_free)

## Sukunahikona: a tiny rod darts from `from` to `to`, then grows into a giant stake impaling it.
static func shrink(world: Node3D, from: Vector3, to: Vector3, on_hit := Callable()) -> void:
	var dart := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.035
	cm.height = 0.5
	cm.radial_segments = 5
	var m := _mat()
	m.emission_enabled = true
	m.emission = Color(0.55, 0.5, 0.7)
	m.emission_energy_multiplier = 0.6
	cm.material = m
	dart.mesh = cm
	world.add_child(dart)
	dart.global_position = from
	var aim := to + Vector3.UP * 1.0
	if (aim - from).length() > 0.05:
		dart.look_at(aim, Vector3.UP)
		dart.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	Vfx.trail(dart, Color(0.7, 0.65, 0.85), 0.05, 14, 0.2)
	var t := clampf(from.distance_to(aim) / 45.0, 0.08, 0.6)
	var tw := dart.create_tween()
	tw.tween_property(dart, "global_position", aim, t)
	tw.tween_callback(func() -> void:
		var g := to
		g.y = _ground(world, to)
		dart.queue_free()
		# the rod returns to full size inside the target: a huge stake + a ring of smaller ones
		_stake(world, g, 6.5, 0.55, Vector3.ZERO)
		for i in 5:
			var off := Vector3(cos(i * TAU / 5.0), 0, sin(i * TAU / 5.0)) * 1.6
			_stake(world, g + off, randf_range(2.0, 3.0), 0.22, off * 0.4)
		Vfx.shockwave(world, g + Vector3.UP * 0.2, Color(0.55, 0.5, 0.7), 4.0, 0.4)
		Sfx.play(world, "boom", 0.0)
		_shake(world, 0.2)
		if on_hit.is_valid():
			on_hit.call(g))

static func _shake(world: Node3D, amt: float) -> void:
	var cam := world.get_viewport().get_camera_3d()
	if cam != null:
		Vfx.shake(cam, amt, 0.4)
