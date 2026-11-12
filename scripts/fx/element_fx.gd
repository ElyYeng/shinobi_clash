class_name ElementFx
## Element-style looks (Fire / Earth / Lightning / Water / Wind), built from the VFX pack.
## World effects arrive through KokuganFx.play -> MythicFx -> LegendFx -> ElementFx.play (synced by
## NetworkSession.broadcast_world_fx). Projectiles are LegendFx.PROJ entries whose shape starts
## with "el_" (built + exploded here). a = caster, b = facing (or the target for Kirin), f = range.

const EARTH := Color(0.45, 0.33, 0.22)
const ROCK := Color(0.4, 0.36, 0.32)
const BOLT := Color(0.6, 0.85, 1.0)
const WATER := Color(0.3, 0.65, 1.0)
const WIND := Color(0.8, 1.0, 0.9)
const FIRE := Color(1.0, 0.5, 0.15)
const UP := Vector3.UP

static func play(kind: String, world: Node3D, a: Vector3, b: Vector3, f: float) -> bool:
	match kind:
		"el_flamewave":   # a ring of fire rolling out from you
			LegendFx.flames(world, a, FIRE, maxf(f * 0.5, 2.0), 2.5, 0.8, 90)
			LegendFx.ground(world, a, "circles/Ring_ShockWave_005.png", FIRE, f, 0.6, 1.5)
			Vfx.burst(world, a + UP, FIRE, 60, 14.0, 0.5, 0.6, 0.0)
			LegendFx._flash(world, a + UP, FIRE, 6.0, f * 1.5)
			LegendFx._shake(world, 0.25)
		"el_rock":   # Rock Avalanche: boulders rain down around you
			_boulders(world, a, f, 9)
			LegendFx.ground(world, a, "circles/Circle_Cracks_01.png", Color(0.75, 0.6, 0.45), f, 1.6, 0.0, 0.6)
			LegendFx._shake(world, 0.35)
			Sfx.play(world, "rock")
		"el_stone":   # Stone Skin: rock shards burst up around you
			LegendFx.spikes(world, LegendFx._ring_pts(LegendFx._gpos(world, a), 1.3, 8, 0.15), ROCK, 1.6, 0.35, 5, 0.5)
			LegendFx.ground(world, a, "circles/Circle_Cracks_02.png", Color(0.75, 0.6, 0.45), 3.5, 1.0, 0.0, 0.5)
			Vfx.smoke(world, a + UP * 0.3, Color(0.55, 0.47, 0.38, 0.7), 2.0)
		"el_thunder":   # Thunder Clap: lightning strikes all around you
			LegendFx.ground(world, a, "circles/Lightning_Mark_Big_01.png", BOLT, f * 0.5, 0.7, 0.6)
			LegendFx.ground(world, a, "circles/Ring_SharpBlur_000.png", BOLT, f, 0.45)
			for p in LegendFx._ring_pts(a, f * 0.55, 7, 1.0):
				bolt_column(world, LegendFx._gpos(world, p), 6.0, 0.35)
			Vfx.burst(world, a + UP, BOLT, 50, 16.0, 0.12, 0.35, 0.0)
			LegendFx._flash(world, a + UP * 2.0, BOLT, 10.0, f * 2.0)
			LegendFx._shake(world, 0.3)
			Sfx.play(world, "thunder", -3.0)
		"el_kirin":   # Kirin: a pillar of lightning from the sky onto the target
			var g := LegendFx._gpos(world, b)
			bolt_column(world, g, 40.0, 0.7, 3.5)
			bolt_column(world, g + Vector3(0.6, 0, 0.3), 40.0, 0.5, 2.0)
			_sprite(world, g + UP * 1.5, "effects/Lightning_Impact_01.png", BOLT, 8.0, 0.6)
			LegendFx.ground(world, g, "circles/Lightning_Mark_Big_01.png", BOLT, 6.0, 1.2, 0.0, 0.4)
			LegendFx.ground(world, g, "circles/Ring_ShockWave_002.png", BOLT, 10.0, 0.6)
			Vfx.burst(world, g + UP, BOLT, 80, 22.0, 0.15, 0.5, -6.0)
			Vfx.flash(world, g + UP * 4.0, BOLT, 16.0, 40.0, 0.5)
			Vfx.smoke(world, g + UP * 0.5, Color(0.5, 0.55, 0.6, 0.6), 3.0)
			LegendFx._shake(world, 0.5)
			Sfx.play(world, "thunder")
		"el_wave":   # Water Wave: a wall of water rushing forward
			_wave(world, a, LegendFx._dir(b), maxf(f, 4.0))
			LegendFx._shake(world, 0.2)
			Sfx.play(world, "splash")
		"el_vacuum":   # Vacuum Wave: a ring of air blasting outward
			LegendFx.ground(world, a, "circles/Swirly_Shockwave_01.png", WIND, f, 0.6, 4.0)
			LegendFx.ground(world, a, "circles/Ring_ShockWave_000.png", WIND, f * 1.1, 0.4)
			LegendFx.streaks(world, a + UP, WIND, f * 0.8, false, 18)
			Vfx.smoke(world, a + UP * 0.3, Color(0.8, 0.75, 0.65, 0.5), f * 0.5)
			LegendFx._shake(world, 0.2)
			Sfx.play(world, "wind")
		"el_gale":   # Gale Palm: crescent gusts flying forward
			_gust(world, a, LegendFx._dir(b), maxf(f, 4.0))
			LegendFx._shake(world, 0.2)
			Sfx.play(world, "wind")
		"el_tornado":   # Tornado: a spinning funnel around you for 5 s
			_tornado(world, a, maxf(f, 3.0), 5.0)
			LegendFx.streaks(world, a + UP, WIND, f, true, 16)
			Sfx.play(world, "wind")
		_:
			return false
	return true

# --- building blocks ------------------------------------------------------------------------------

## Pack-texture material that keeps the node's scale when it's a billboard.
static func _mat(tex: String, col: Color, boost := 1.6, bill := BaseMaterial3D.BILLBOARD_DISABLED) -> StandardMaterial3D:
	var m := Vfx.tex_mat(tex, col, boost)
	m.billboard_mode = bill
	m.billboard_keep_scale = true
	return m

static func _quad(parent: Node, mat: Material) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.mesh = Vfx.quad()
	q.material_override = mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	return q

## Camera-facing sprite that pops in and fades.
static func _sprite(world: Node3D, p: Vector3, tex: String, col: Color, size: float, secs := 0.3) -> void:
	var mat := _mat(tex, col, 1.8, BaseMaterial3D.BILLBOARD_ENABLED)
	var q := _quad(world, mat)
	q.global_position = p
	q.scale = Vector3.ONE * size * 0.3
	var t := q.create_tween().set_parallel(true)
	t.tween_property(q, "scale", Vector3.ONE * size, secs * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, secs * 0.6).set_delay(secs * 0.4)
	t.chain().tween_callback(q.queue_free)

## A flickering lightning strike standing on `base`, `h` metres tall.
static func bolt_column(world: Node3D, base: Vector3, h: float, secs: float, width := 1.6) -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = base
	var mat := _mat("effects/Lightning_17.png", BOLT, 2.6, BaseMaterial3D.BILLBOARD_FIXED_Y)
	var seg := width * 1.6
	var n := maxi(1, ceili(h / seg))
	for i in n:
		var q := _quad(root, mat)
		q.position = Vector3(randf_range(-0.25, 0.25), seg * (i + 0.5), 0)
		q.scale = Vector3(width * (1.0 if randf() < 0.5 else -1.0), seg * (1.0 if randf() < 0.5 else -1.0), 1.0)
	var glow := _quad(root, _mat("effects/Glow01.png", BOLT, 1.4, BaseMaterial3D.BILLBOARD_ENABLED))
	glow.position = UP * 0.6
	glow.scale = Vector3.ONE * width * 3.0
	var t := root.create_tween()
	for k in 3:   # flicker
		t.tween_callback(func() -> void: root.visible = false).set_delay(secs * 0.12)
		t.tween_callback(func() -> void: root.visible = true).set_delay(0.03)
	t.tween_property(mat, "albedo_color:a", 0.0, secs * 0.4)
	t.tween_callback(root.queue_free)

## Boulders falling from the sky, each landing with a puff of dust.
static func _boulders(world: Node3D, a: Vector3, f: float, n: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROCK
	for i in n:
		var ang := randf() * TAU
		var g := LegendFx._gpos(world, a + Vector3(cos(ang), 0, sin(ang)) * randf_range(1.5, maxf(f * 0.85, 2.0)))
		var r := randf_range(0.5, 1.1)
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.6
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = mat
		var m := MeshInstance3D.new()
		m.mesh = sm
		world.add_child(m)
		CharToon.apply(m)
		m.global_position = g + Vector3(randf_range(-3, 3), 14.0 + randf() * 4.0, randf_range(-3, 3))
		m.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		var t := m.create_tween()
		t.tween_interval(randf() * 0.3)
		t.tween_property(m, "global_position", g + UP * r * 0.4, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.tween_callback(func() -> void:
			Vfx.smoke(world, g + UP * 0.3, Color(0.6, 0.52, 0.42, 0.75), 1.6)
			LegendFx.ground(world, g, "circles/Circle_Cracks_02.png", Color(0.7, 0.55, 0.4), r * 2.2, 1.0, 0.0, 0.6))
		t.tween_interval(1.2)
		t.tween_property(m, "scale", Vector3.ONE * 0.05, 0.35)
		t.tween_callback(m.queue_free)

## A wall of splashes rushing forward along `d`.
static func _wave(world: Node3D, a: Vector3, d: Vector3, f: float) -> void:
	var side := d.cross(UP)
	for i in 5:
		var mat := _mat("effects/Splash02_explode.png", WATER, 1.6)
		var s := _quad(world, mat)
		var start := LegendFx._gpos(world, a + d * 1.0 + side * (float(i) - 2.0) * f * 0.14) + UP * 1.2
		s.global_position = start
		s.look_at(start + d)
		s.scale = Vector3(f * 0.3, 2.0, 1.0)
		var t := s.create_tween().set_parallel(true)
		t.tween_property(s, "global_position", start + d * f, 0.5).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "scale", Vector3(f * 0.35, 3.4, 1.0), 0.5)
		t.tween_property(mat, "albedo_color:a", 0.0, 0.25).set_delay(0.3)
		t.chain().tween_callback(s.queue_free)
	for k in 3:   # spray along the way
		var p := a + d * f * (0.3 + 0.3 * k) + UP * 0.8
		world.get_tree().create_timer(0.12 * k).timeout.connect(func() -> void:
			if is_instance_valid(world):
				Vfx.burst(world, p, WATER.lerp(Color.WHITE, 0.4), 30, 8.0, 0.18, 0.7, -14.0))
	LegendFx.ground(world, a + d * f * 0.5, "effects/Splash13.png", WATER, f * 0.6, 0.9, 0.0, 0.4)

## A flat crescent of wind, lying on the ground plane with its bulge pointing along `d`.
static func _crescent(parent: Node, col: Color) -> Array:
	var mat := _mat("slashes/Shockwave_Moon_01.png", col, 1.4)
	return [_quad(parent, mat), mat]

static func _gust(world: Node3D, a: Vector3, d: Vector3, f: float) -> void:
	var flat := Basis(d, UP.cross(d), UP)
	for i in 4:
		var c := _crescent(world, WIND)
		var s: MeshInstance3D = c[0]
		var start := a + UP * (0.5 + i * 0.45) + d * 0.8
		s.global_basis = flat
		s.global_position = start
		s.scale = Vector3.ONE * 2.0
		var t := s.create_tween().set_parallel(true)
		t.tween_property(s, "global_position", start + d * f, 0.35 + i * 0.05).set_delay(i * 0.04)
		t.tween_property(s, "scale", Vector3.ONE * (3.5 + i * 0.6), 0.4)
		t.tween_property(c[1], "albedo_color:a", 0.0, 0.2).set_delay(0.25)
		t.chain().tween_callback(s.queue_free)
	Vfx.smoke(world, a + d * f * 0.7 + UP * 0.4, Color(0.8, 0.75, 0.65, 0.45), f * 0.3)

## A spinning funnel that follows whoever cast it (the body nearest `a`).
static func _tornado(world: Node3D, a: Vector3, r: float, secs: float) -> void:
	var root := Node3D.new()
	var host := MythicFx.nearest_body(world, a, 3.0)
	if host != null:
		host.add_child(root)
		root.top_level = true   # (follows below, but doesn't turn with the body)
	else:
		world.add_child(root)
	root.global_position = a
	root.set_meta("host", host)
	for i in 6:
		var pm := PlaneMesh.new()
		pm.size = Vector2(2, 2)
		var ring := MeshInstance3D.new()
		ring.mesh = pm
		ring.material_override = Vfx.tex_mat("circles/Ring_Twiri_000.png" if i % 2 == 0 else "circles/Ring_Twiri_001.png", WIND, 1.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		ring.position.y = 0.3 + i * 1.1
		var s := r * (0.15 + 0.1 * i)
		ring.scale = Vector3.ONE * s * 0.2
		ring.create_tween().tween_property(ring, "scale", Vector3.ONE * s, 0.4).set_ease(Tween.EASE_OUT)
		ring.create_tween().set_loops().tween_property(ring, "rotation:y", -TAU, 0.35 + 0.05 * i).from(0.0)
	var q := CPUParticles3D.new()   # dust and leaves whipped around
	q.amount = 60
	q.lifetime = 1.2
	q.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	q.emission_ring_axis = Vector3.UP
	q.emission_ring_radius = r * 0.35
	q.emission_ring_inner_radius = r * 0.15
	q.emission_ring_height = 0.2
	q.direction = Vector3.UP
	q.spread = 15.0
	q.initial_velocity_min = 3.0
	q.initial_velocity_max = 6.0
	q.gravity = Vector3.ZERO
	q.tangential_accel_min = 25.0
	q.tangential_accel_max = 40.0
	q.mesh = Vfx.quad()
	q.material_override = Vfx.particle_mat(false, 1.0)
	q.scale_amount_min = 0.1
	q.scale_amount_max = 0.25
	q.color = Color(0.7, 0.68, 0.55, 0.7)
	root.add_child(q)
	var follow := func() -> void:
		var h = root.get_meta("host")
		if h != null and is_instance_valid(h):
			root.global_position = (h as Node3D).global_position
	var t := root.create_tween()
	t.tween_method(func(_v: float) -> void: follow.call(), 0.0, 1.0, secs)
	t.tween_callback(func() -> void: q.emitting = false)
	t.tween_property(root, "scale", Vector3(0.2, 1.4, 0.2), 0.4).set_ease(Tween.EASE_IN)
	t.tween_callback(root.queue_free)

# --- projectiles ----------------------------------------------------------------------------------

## (child of a projectile, which faces -Z) a flat quad lying along the travel direction.
const ALONG := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
## ... and one standing upright along it (crossed with ALONG = visible from every side).
const ALONG_UP := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

static func build_proj(p: Node3D, shape: String, col: Color, size: float) -> void:
	size = maxf(size, 0.15)
	match shape:
		"el_mud":   # a heavy tumbling ball of mud / rock (dragon = big)
			var sm := SphereMesh.new()
			sm.radius = size
			sm.height = size * 2.0
			sm.radial_segments = 8
			sm.rings = 4
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			sm.material = m
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			p.add_child(mi)
			CharToon.apply(mi)
			mi.create_tween().set_loops().tween_property(mi, "rotation:x", -TAU, 0.45).from(0.0)
			var q := CPUParticles3D.new()   # clods falling off behind it
			q.amount = 20
			q.lifetime = 0.5
			q.local_coords = false
			q.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			q.emission_sphere_radius = size * 0.8
			q.gravity = Vector3(0, -12, 0)
			q.mesh = Vfx.quad()
			q.material_override = Vfx.particle_mat(false, 1.0)
			q.scale_amount_min = size * 0.25
			q.scale_amount_max = size * 0.5
			q.color = col.darkened(0.2)
			p.add_child(q)
		"el_bolt":   # a crackling streak of lightning
			var mat := _mat("effects/Lightning_17.png", col, 2.8)
			for bs: Basis in [ALONG, ALONG_UP]:
				var s := _quad(p, mat)
				s.basis = bs.scaled(Vector3(size * 12.0, size * 4.0, 1.0))
			var glow := _quad(p, _mat("effects/Glow01.png", col, 1.3, BaseMaterial3D.BILLBOARD_ENABLED))
			glow.scale = Vector3.ONE * size * 6.0
			mat.albedo_color.a = 1.0
			p.create_tween().set_loops().tween_property(mat, "albedo_color:a", 0.35, 0.05).from(1.0)
			Vfx.trail(p, col, size * 0.6, 24, 0.2)
			Vfx.glow_light(p, col, 2.5, 7.0)
		"el_water":   # a ball of water (big = a spinning water dragon's head)
			var sm2 := SphereMesh.new()
			sm2.radius = size
			sm2.height = size * 2.0
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(col.r, col.g, col.b, 0.65)
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.emission_enabled = true
			wm.emission = col
			wm.emission_energy_multiplier = 0.6
			wm.rim_enabled = true
			wm.rim = 1.0
			var ball := MeshInstance3D.new()
			ball.mesh = sm2
			ball.material_override = wm
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(ball)
			var swirl := _quad(p, _mat("slashes/Swirl01.png", col.lerp(Color.WHITE, 0.3), 1.3))
			swirl.scale = Vector3.ONE * size * 4.0
			swirl.create_tween().set_loops().tween_property(swirl, "rotation:z", TAU, 0.3).from(0.0)
			Vfx.trail(p, col.lerp(Color.WHITE, 0.35), size * 0.9, 30, 0.35)
		"el_wind":   # a flat cutting crescent of wind
			var c := _crescent(p, col)
			(c[0] as MeshInstance3D).basis = ALONG.scaled(Vector3.ONE * size * 12.0)
			Vfx.trail(p, col, size * 0.8, 20, 0.2)

static func impact(world: Node3D, pos: Vector3, shape: String, col: Color, aoe: float) -> void:
	var r := maxf(aoe, 1.2)
	match shape:
		"el_mud":
			Vfx.smoke(world, pos, Color(col.r, col.g, col.b, 0.85), r)
			LegendFx.ground(world, pos, "effects/Splash02_explode.png", col.lerp(Color.WHITE, 0.25), r * 1.2, 1.0, 0.0, 0.5)
			if r > 4.0:   # (Earth Dragon) rocks burst up
				LegendFx.spikes(world, LegendFx._ring_pts(LegendFx._gpos(world, pos), r * 0.4, 7, 0.4), ROCK, 2.4, 0.45, 5, 1.0)
				LegendFx._shake(world, 0.3)
			Sfx.play(world, "rock", -4.0)
		"el_bolt":
			_sprite(world, pos, "effects/Lightning_Impact_01.png", col, r * 2.2, 0.25)
			Vfx.burst(world, pos, col, 30, 12.0, 0.1, 0.3, 0.0)
			Vfx.flash(world, pos, col, 6.0, r * 4.0, 0.15)
			if r >= 2.0:
				bolt_column(world, LegendFx._gpos(world, pos), 5.0, 0.25, 1.0)
			Sfx.play(world, "zap", -4.0)
		"el_water":
			_sprite(world, pos, "effects/Splash13.png", col, r * 2.2, 0.35)
			LegendFx.ground(world, pos, "effects/Splash02_explode.png", col, r * 1.3, 0.9, 0.0, 0.3)
			Vfx.burst(world, pos, col.lerp(Color.WHITE, 0.4), 40, 9.0, 0.18, 0.7, -14.0)
			if r > 4.0:
				LegendFx._shake(world, 0.3)
			Sfx.play(world, "splash", -3.0)
		"el_wind":
			_sprite(world, pos, "slashes/Slash_01.png", col, 2.5, 0.2)
			Vfx.burst(world, pos, col, 16, 8.0, 0.12, 0.3, 0.0)
			Sfx.play(world, "wind", -10.0)
