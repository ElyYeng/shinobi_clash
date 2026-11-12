class_name LegendFx
## Signature visuals for the Legendary bloodlines, built from the VFX pack textures.
## World effects go through KokuganFx.play -> MythicFx.play -> LegendFx.play (synced by
## NetworkSession.broadcast_world_fx); projectile looks are Projectile visual_kinds (PROJ).
## a = caster position, b = facing (burst / cone / buff / dash) or the target's position (target),
## f = the ability's range.

# --- small building blocks --------------------------------------------------------------------

static func _ground(world: Node3D, p: Vector3) -> float:
	var h := world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 20.0))
	return (h["position"] as Vector3).y if not h.is_empty() else p.y

static func _gpos(world: Node3D, p: Vector3) -> Vector3:
	return Vector3(p.x, _ground(world, p) + 0.12, p.z)

## Ground decal that grows, spins and fades.
static func ground(world: Node3D, p: Vector3, tex: String, col: Color, r: float, secs := 0.6, spin := 1.0, from := 0.2) -> MeshInstance3D:
	var m := Vfx.decal(world, _gpos(world, p), tex, col, 1.7)
	m.scale = Vector3.ONE * r * from
	var mat := m.material_override as StandardMaterial3D
	var t := m.create_tween().set_parallel(true)
	t.tween_property(m, "scale", Vector3.ONE * r, secs * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "rotation:y", spin, secs)
	t.tween_property(mat, "albedo_color:a", 0.0, secs * 0.55).set_delay(secs * 0.45)
	t.chain().tween_callback(m.queue_free)
	return m

## Upright camera-facing sprite (portals, eyes, tears) that pops, holds and shrinks away.
static func sprite(world: Node3D, p: Vector3, tex: String, col: Color, size: float, secs := 0.8, spin := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = Vfx.quad()
	var mat := Vfx.tex_mat(tex, col, 1.8, true)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = p
	m.scale = Vector3.ONE * size * 0.1
	var t := m.create_tween()
	t.tween_property(m, "scale", Vector3.ONE * size, secs * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if spin != 0.0:
		m.create_tween().tween_property(m, "rotation:z", spin, secs)
	t.tween_interval(secs * 0.45)
	t.tween_property(m, "scale", Vector3.ONE * size * 0.05, secs * 0.3).set_ease(Tween.EASE_IN)
	t.tween_callback(m.queue_free)
	return m

## A burst of fire-flipbook flames (column or ring) that dies down.
static func flames(world: Node3D, p: Vector3, col: Color, radius: float, height: float, secs := 1.2, amount := 50, additive := true) -> void:
	var q := CPUParticles3D.new()
	q.amount = amount
	q.lifetime = 0.8
	q.one_shot = false
	q.local_coords = false
	q.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING if radius > 1.5 else CPUParticles3D.EMISSION_SHAPE_SPHERE
	q.emission_ring_axis = Vector3.UP
	q.emission_ring_radius = radius
	q.emission_ring_inner_radius = radius * 0.85
	q.emission_ring_height = 0.2
	q.emission_sphere_radius = maxf(radius, 0.3)
	q.mesh = Vfx.quad()
	Vfx.use_flame(q, additive, 1.6 if additive else 1.0)
	q.direction = Vector3.UP
	q.spread = 15.0
	q.initial_velocity_min = height * 0.8
	q.initial_velocity_max = height * 1.4
	q.scale_amount_min = 0.6
	q.scale_amount_max = 1.2
	q.scale_amount_curve = Vfx.shrink_curve()
	var g := Gradient.new()
	g.colors = PackedColorArray([col.lerp(Color.WHITE, 0.4) if additive else col, col, Color(col.r, col.g, col.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	q.color_ramp = g
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(q)
	q.global_position = _gpos(world, p)
	world.get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(q):
			q.emitting = false)
	world.get_tree().create_timer(secs + 1.0).timeout.connect(func() -> void:
		if is_instance_valid(q):
			q.queue_free())

## Toon spikes (crystal, iron, blood) shooting out of the ground at `points`.
static func spikes(world: Node3D, points: Array, col: Color, h := 2.6, rad := 0.32, sides := 6, hold := 1.4, glow := 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = glow
	for i in points.size():
		var p: Vector3 = points[i]
		world.get_tree().create_timer(i * 0.025).timeout.connect(func() -> void:
			if not is_instance_valid(world):
				return
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = rad * randf_range(0.7, 1.2)
			cm.height = h * randf_range(0.7, 1.25)
			cm.radial_segments = sides
			cm.rings = 1
			cm.material = mat
			var s := MeshInstance3D.new()
			s.mesh = cm
			var piv := Node3D.new()
			world.add_child(piv)
			piv.global_position = _gpos(world, p) - Vector3.UP * 0.1
			piv.add_child(s)
			s.position.y = cm.height * 0.5
			piv.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
			CharToon.apply(s)
			piv.scale = Vector3(1, 0.05, 1)
			var t := piv.create_tween()
			t.tween_property(piv, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_interval(hold)
			t.tween_property(piv, "scale", Vector3(0.3, 0.0, 0.3), 0.3).set_ease(Tween.EASE_IN)
			t.tween_callback(piv.queue_free))

static func _ring_pts(c: Vector3, r: float, n: int, jitter := 0.4) -> Array:
	var out := []
	for i in n:
		var a := TAU * i / n + randf_range(-0.1, 0.1)
		out.append(c + Vector3(cos(a), 0, sin(a)) * (r + randf_range(-jitter, jitter)))
	return out

static func _cone_pts(c: Vector3, dir: Vector3, r: float, n: int) -> Array:
	var out := []
	for i in n:
		var d := dir.rotated(Vector3.UP, randf_range(-0.5, 0.5))
		out.append(c + d * randf_range(1.5, r))
	return out

## Streaks rushing in to (or out from) a point.
static func streaks(world: Node3D, c: Vector3, col: Color, r: float, inward := true, n := 14) -> void:
	for i in n:
		var a := TAU * i / n
		var out := c + Vector3(cos(a), randf_range(-0.2, 0.6), sin(a)) * r
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 1.8)
		var s := MeshInstance3D.new()
		s.mesh = bm
		s.material_override = Vfx.tex_mat("effects/Glow01.png", col, 2.0)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(s)
		s.global_position = out if inward else c
		s.look_at(c if inward else out, Vector3.UP)
		var t := s.create_tween()
		t.tween_property(s, "global_position", c if inward else out, 0.3 + randf() * 0.15).set_ease(Tween.EASE_IN if inward else Tween.EASE_OUT)
		t.tween_callback(s.queue_free)

static func _flash(world: Node3D, p: Vector3, col: Color, e := 5.0, rng := 10.0) -> void:
	Vfx.flash(world, p, col, e, rng, 0.35)

static func _shake(world: Node3D, amt: float) -> void:
	var cam := world.get_viewport().get_camera_3d()
	if cam != null:
		Vfx.shake(cam, amt, 0.35)

static func _dir(b: Vector3) -> Vector3:
	b.y = 0.0
	return b.normalized() if b.length() > 0.01 else Vector3.FORWARD

# --- the techniques ----------------------------------------------------------------------------

static func play(kind: String, world: Node3D, a: Vector3, b: Vector3, f: float) -> bool:
	var up := Vector3.UP
	match kind:
		# Scorch Release
		"halo_hurricane":   # spinning ring of scorching fire
			flames(world, a, Color(1.0, 0.45, 0.1), f * 0.6, 3.0, 0.9, 90)
			ground(world, a, "circles/Ring_ShockWave_005.png", Color(1.0, 0.5, 0.15), f, 0.7, 2.5)
			_flash(world, a + up, Color(1.0, 0.5, 0.15), 6.0, f * 1.5)
		"mummify":   # the target dries up inside a column of steam and heat
			flames(world, b, Color(1.0, 0.55, 0.15), 0.6, 4.0, 1.4, 60)
			flames(world, b, Color(0.85, 0.85, 0.8), 0.9, 2.0, 1.6, 30, false)
			ground(world, b, "circles/Circle_Glow_01.png", Color(1.0, 0.5, 0.1), 2.5, 1.2, 1.0)
		# Magnet Release
		"sand_pull":   # iron sand swirling in
			ground(world, a, "circles/Swirly_Shockwave_01.png", Color(0.35, 0.3, 0.25), f, 0.9, -4.0, 1.0)
			streaks(world, a + up, Color(0.45, 0.4, 0.35), f * 0.7, true, 18)
		"sand_fist":   # a giant iron sand fist slams forward
			var d := _dir(b)
			spikes(world, _cone_pts(a, d, f, 14), Color(0.18, 0.16, 0.15), 1.6, 0.5, 5, 0.6)
			ground(world, a + d * f * 0.5, "circles/Circle_Cracks_01.png", Color(0.5, 0.45, 0.4), f * 0.6, 0.9, 0.0, 0.6)
			_shake(world, 0.25)
		# Crystal Release
		"crystal_prison":   # a crystal grows around the target, then shatters
			var g := _gpos(world, b)
			spikes(world, _ring_pts(g, 0.8, 7, 0.1) + [g], Color(0.55, 0.85, 1.0), 3.0, 0.55, 6, 2.6, 0.4)
			sprite(world, g + up * 1.2, "effects/Impact24.png", Color(0.6, 0.9, 1.0), 3.0, 0.5)
		"crystal_spikes":
			spikes(world, _ring_pts(a, f * 0.35, 10) + _ring_pts(a, f * 0.7, 14), Color(0.55, 0.85, 1.0), 2.4, 0.35, 6, 1.2, 0.4)
			ground(world, a, "circles/Ring_SharpBlur_000.png", Color(0.5, 0.85, 1.0), f, 0.6)
		# Steel Release
		"steel_skin":
			sprite(world, a + up, "effects/Glow01.png", Color(0.8, 0.85, 0.95), 4.0, 0.5)
			ground(world, a, "circles/Ring_Thick_001.png", Color(0.75, 0.8, 0.9), 3.0, 0.6)
		"steel_fist", "rift":   # a crushing shockwave straight ahead
			var d2 := _dir(b)
			var col := Color(0.8, 0.85, 0.95) if kind == "steel_fist" else Color(0.75, 0.85, 1.0)
			Vfx.slash(world, a + up * 1.1, d2, col, 3, 3.2)
			ground(world, a + d2 * f * 0.5, "circles/Ring_ShockWave_005.png", col, f * 0.6, 0.5, 1.5)
			if kind == "rift":   # Jogan: space itself cracks
				sprite(world, a + d2 * 2.5 + up * 1.2, "effects/Cracks_10.png", Color(0.7, 0.85, 1.0), 4.0, 0.9)
			_shake(world, 0.2)
		"iron_quake":
			ground(world, a, "circles/Circle_Cracks_01.png", Color(0.6, 0.55, 0.5), f, 1.2, 0.0, 0.5)
			spikes(world, _ring_pts(a, f * 0.5, 12, 1.2), Color(0.4, 0.38, 0.36), 1.4, 0.45, 4, 0.8)
			Vfx.shockwave(world, a, Color(0.8, 0.75, 0.65), f, 0.5)
			_shake(world, 0.35)
		# Dark Release
		"dark_aura":
			ground(world, a, "circles/Swirly_Shockwave_01.png", Color(0.45, 0.2, 0.7), f, 1.2, -6.0, 1.0)
			flames(world, a, Color(0.12, 0.05, 0.2), 0.5, 2.0, 1.0, 30, false)
		"void_grasp":
			ground(world, a, "circles/Portal_01.png", Color(0.4, 0.15, 0.6), f, 1.0, -5.0, 1.0)
			streaks(world, a + up, Color(0.5, 0.25, 0.8), f * 0.7, true, 16)
		# Uzumaki
		"chakra_surge":
			flames(world, a, Color(1.0, 0.55, 0.15), 0.5, 2.5, 0.8, 40)
			ground(world, a, "circles/Ring_ShockWave_005.png", Color(1.0, 0.6, 0.2), 5.0, 0.6, 2.0)
		"sealing_chains":   # golden chains lash out in every direction, then reel in
			for i in 8:
				var ang := TAU * i / 8.0
				_chain(world, a + up * 1.0, Vector3(cos(ang), 0.05, sin(ang)), f * 0.8)
			ground(world, a, "circles/Circle_18.png", Color(1.0, 0.8, 0.3), 3.5, 1.0, 1.0)
		# Hatake
		"chidori":   # lightning crackling along the dash
			var d3 := _dir(b)
			for i in 6:
				var p := a + d3 * f * i / 6.0 + up * 1.0
				world.get_tree().create_timer(i * 0.04).timeout.connect(func() -> void:
					if is_instance_valid(world):
						sprite(world, p, "symbols/Lightning_Mark_03.png", Color(0.55, 0.8, 1.0), 1.6, 0.35, randf() * TAU))
			sprite(world, a + d3 * f + up, "effects/Lightning_Impact_01.png", Color(0.6, 0.85, 1.0), 3.0, 0.4)
			_flash(world, a + up, Color(0.5, 0.75, 1.0), 6.0, 10.0)
		"kamui":   # a swirl in space sucks the target in
			sprite(world, b + up * 1.1, "effects/Spin_02.png", Color(0.45, 0.3, 0.6), 3.5, 1.0, -TAU * 1.5)
			streaks(world, b + up * 1.1, Color(0.5, 0.35, 0.7), 2.5, true, 10)
		# Chinoike
		"blood_rage":
			flames(world, a, Color(0.75, 0.05, 0.08), 0.5, 2.5, 1.0, 40)
			ground(world, a, "circles/Circle_DragonLord_02.png", Color(0.9, 0.1, 0.12), 4.0, 0.9, 1.5)
		"ketsuryugan":   # the blood eyes glare: everything around freezes
			sprite(world, a + up * 2.6, "symbols/MedusasEyes_01.png", Color(1.0, 0.1, 0.1), 2.5, 1.0)
			ground(world, a, "circles/Ring_SharpBlur_000.png", Color(0.9, 0.05, 0.1), f, 0.8)
		# Mangekyo
		"tsukuyomi":   # red moon world for an instant
			sprite(world, a + up * 4.0, "circles/Moon_Circle_Inner.png", Color(1.0, 0.1, 0.1), 5.0, 1.2, 0.6)
			ground(world, a, "circles/Circle_18.png", Color(0.9, 0.05, 0.1), f, 1.0, -3.0)
			_flash(world, a + up * 2.0, Color(1.0, 0.1, 0.1), 8.0, f * 2.0)
		"kamui_warp":
			sprite(world, b + up * 1.1, "effects/Spin_02.png", Color(0.35, 0.15, 0.45), 4.0, 0.9, TAU * 2.0)
			streaks(world, b + up * 1.1, Color(0.4, 0.2, 0.55), 3.0, true, 12)
		# Jogan
		"pure_sight":
			sprite(world, a + up * 2.4, "symbols/Symbol_03_Eye.png", Color(0.6, 0.8, 1.0), 1.8, 0.9)
			ground(world, a, "circles/Ring_Thick_001.png", Color(0.6, 0.8, 1.0), 4.0, 0.7)
		"space_tear":
			sprite(world, b + up * 1.2, "effects/Cracks_10.png", Color(0.75, 0.6, 1.0), 4.0, 1.0)
			sprite(world, b + up * 1.2, "circles/Portal_01.png", Color(0.6, 0.45, 1.0), 3.0, 1.0, TAU)
		# Tenseigan
		"golden_wheel":   # a giant golden wheel of chakra spins out
			ground(world, a, "symbols/Sun_Circle_Middle.png", Color(1.0, 0.82, 0.35), f, 1.0, TAU)
			ground(world, a, "symbols/Sun_Circle_Inner.png", Color(1.0, 0.9, 0.5), f * 0.5, 1.0, -TAU)
			_flash(world, a + up, Color(1.0, 0.85, 0.4), 8.0, f * 1.5)
			_shake(world, 0.25)
		"golden_cloak":
			flames(world, a, Color(1.0, 0.85, 0.35), 0.5, 2.5, 1.0, 45)
			ground(world, a, "symbols/Sun_Circle_Middle.png", Color(1.0, 0.85, 0.4), 4.0, 0.9, 2.0)
		_:
			return ElementFx.play(kind, world, a, b, f)   # element styles
	return true

## One golden chain: links flying out along `dir`, then pulled back.
static func _chain(world: Node3D, from: Vector3, dir: Vector3, length: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 0.6
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.2
	tm.rings = 10
	tm.ring_segments = 6
	tm.material = mat
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = from
	root.look_at(from + dir, Vector3.UP)
	var n := int(length / 0.32)
	for i in n:
		var l := MeshInstance3D.new()
		l.mesh = tm
		l.position = Vector3(0, 0, -i * 0.32)
		l.rotation = Vector3(PI * 0.5, 0, PI * 0.5 if i % 2 == 0 else 0.0)
		root.add_child(l)
	CharToon.apply(root)
	root.scale = Vector3(1, 1, 0.02)
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(root, "scale", Vector3(1, 1, 0.02), 0.25).set_ease(Tween.EASE_IN)
	t.tween_callback(root.queue_free)

# --- projectiles -------------------------------------------------------------------------------

## visual_kind -> [shape, colour]: orb (glowing sphere), spear (long spike), sand (grain cluster),
## shard (crystal), hound (lightning), flame (fire flipbook ball, dark = black flames).
const PROJ := {
	"steam_orb": ["orb", Color(1.0, 0.55, 0.2)],
	"gold_orb": ["orb", Color(1.0, 0.85, 0.35)],
	"iron_sand": ["sand", Color(0.2, 0.18, 0.16)],
	"crystal": ["shard", Color(0.55, 0.85, 1.0)],
	"dark_spear": ["spear", Color(0.12, 0.05, 0.18)],
	"blood_spear": ["spear", Color(0.7, 0.04, 0.06)],
	"lightning_hound": ["hound", Color(0.55, 0.8, 1.0)],
	"black_flame": ["flame", Color(0.05, 0.02, 0.06)],
	# Element styles (built by ElementFx)
	"mud": ["el_mud", Color(0.42, 0.3, 0.2)],
	"earth_dragon": ["el_mud", Color(0.4, 0.34, 0.27)],
	"lightning_bolt": ["el_bolt", Color(0.6, 0.85, 1.0)],
	"water_shot": ["el_water", Color(0.3, 0.65, 1.0)],
	"water_dragon": ["el_water", Color(0.25, 0.6, 1.0)],
	"wind_blade": ["el_wind", Color(0.8, 1.0, 0.9)],
}

static func build_proj(p: Node3D, kind: String, size: float) -> void:
	var spec: Array = PROJ[kind]
	var col: Color = spec[1]
	if str(spec[0]).begins_with("el_"):
		ElementFx.build_proj(p, str(spec[0]), col, size)
		return
	match str(spec[0]):
		"orb":
			var s := MeshInstance3D.new()
			s.mesh = Vfx.quad()
			s.material_override = Vfx.tex_mat("effects/Glow01.png", col, 1.1, true)
			s.scale = Vector3.ONE * maxf(size, 0.3) * 4.0
			p.add_child(s)
			var core := MeshInstance3D.new()
			core.mesh = Vfx.quad()
			core.material_override = Vfx.tex_mat("effects/Star_Shape_03.png", col.lerp(Color.WHITE, 0.25), 1.2, true)
			core.scale = Vector3.ONE * maxf(size, 0.3) * 2.5
			p.add_child(core)
			Vfx.trail(p, col * 0.6, size * 0.35, 16, 0.25)
		"spear", "shard":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = maxf(size, 0.1) * (0.5 if spec[0] == "spear" else 0.9)
			cm.height = maxf(size, 0.1) * (10.0 if spec[0] == "spear" else 4.0)
			cm.radial_segments = 6 if spec[0] == "shard" else 8
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			if spec[0] == "shard" or kind == "blood_spear":
				m.emission_enabled = true
				m.emission = col
				m.emission_energy_multiplier = 0.5
			cm.material = m
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.rotation.x = -PI * 0.5   # point along -Z
			p.add_child(mi)
			CharToon.apply(mi)
			Vfx.trail(p, col * 0.5, 0.08, 12, 0.2)
		"sand":
			var q := CPUParticles3D.new()
			q.amount = 24
			q.lifetime = 0.3
			q.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			q.emission_sphere_radius = 0.25
			q.mesh = Vfx.quad()
			q.material_override = Vfx.particle_mat(false, 1.0)
			q.scale_amount_min = 0.08
			q.scale_amount_max = 0.16
			q.color = col
			q.gravity = Vector3.ZERO
			p.add_child(q)
		"hound":
			var s2 := MeshInstance3D.new()
			s2.mesh = Vfx.quad()
			s2.material_override = Vfx.tex_mat("symbols/Lightning_Mark_03.png", col, 2.2, true)
			s2.scale = Vector3.ONE * 2.2
			p.add_child(s2)
			s2.create_tween().set_loops().tween_property(s2, "rotation:z", TAU, 0.3).from(0.0)
			Vfx.trail(p, col, 0.3, 24, 0.3)
			Vfx.glow_light(p, col, 2.0, 6.0)
		"flame":
			var q2 := CPUParticles3D.new()
			q2.amount = 28
			q2.lifetime = 0.45
			q2.local_coords = false
			q2.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			q2.emission_sphere_radius = maxf(size, 0.3) * 0.6
			q2.mesh = Vfx.quad()
			Vfx.use_flame(q2, false, 1.0)
			q2.gravity = Vector3(0, 2.0, 0)
			q2.scale_amount_min = 0.5
			q2.scale_amount_max = 0.9
			var g := Gradient.new()
			g.colors = PackedColorArray([Color(0.02, 0.01, 0.03), Color(0.3, 0.02, 0.1), Color(0.1, 0.0, 0.05, 0.0)])
			q2.color_ramp = g
			p.add_child(q2)

static func proj_impact(world: Node3D, pos: Vector3, kind: String, aoe: float) -> void:
	var col: Color = PROJ[kind][1]
	if str(PROJ[kind][0]).begins_with("el_"):
		ElementFx.impact(world, pos, str(PROJ[kind][0]), col, aoe)
		return
	var r := maxf(aoe, 1.2)
	match str(PROJ[kind][0]):
		"orb", "hound":
			Vfx.sprite_flash(world, pos, "effects/Impact24.png", col.lerp(Color.WHITE, 0.3), r * 1.6, 0.3)
			Vfx.shockwave(world, pos, col, r * 1.3, 0.35)
		"shard":
			spikes(world, _ring_pts(pos, 0.5, 4, 0.2), col, 1.2, 0.18, 6, 0.6, 0.4)
		"spear":
			spikes(world, [pos], col, 1.8, 0.2, 8, 0.8)
		"flame":
			flames(world, pos, col, 0.6, 1.5, 0.8, 30, false)
		_:
			Fx.puff(world, pos, Color(col.r, col.g, col.b, 0.9), r)
