class_name MythicFx
## Signature visuals for the Mythic bloodlines (Dust, Otsutsuki, Rinnegan), anime-accurate.
## Pure visuals: played by the caster and, through NetworkSession.broadcast_world_fx, by everyone.
## Projectile looks (Dust cube, Truth-Seeking Orb, Ash Killing Bone) live in Projectile via
## visual_kind and are built by the helpers at the bottom.

static func _glow_mat(col: Color, alpha := 1.0, additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	return m

static func _mesh(world: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = pos
	return mi

static func _sphere(r: float, rings := 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = rings * 2
	s.rings = rings
	return s

static func _fade(mi: MeshInstance3D, t: float, delay := 0.0) -> void:
	var m := mi.material_override as StandardMaterial3D
	var tw := mi.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(m, "albedo_color:a", 0.0, t)
	tw.tween_callback(mi.queue_free)

static func _ring(world: Node3D, pos: Vector3, r: float, col: Color, t: float, grow := 1.0) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.9
	tm.outer_radius = r
	tm.rings = 48
	var mi := _mesh(world, tm, _glow_mat(col, 0.8), pos)
	mi.scale = Vector3(0.1, 0.25, 0.1)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(grow, 1.0, grow), t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, t).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

static func _flash(world: Node3D, pos: Vector3, col: Color, energy: float, rng: float, t: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, t)
	tw.tween_callback(l.queue_free)

static func _shake(world: Node3D, amt: float) -> void:
	var cam := world.get_viewport().get_camera_3d()
	if cam != null:
		Vfx.shake(cam, amt, 0.4)

static func _ground(world: Node3D, p: Vector3) -> float:
	var h := world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 20.0))
	return (h["position"] as Vector3).y if not h.is_empty() else p.y

## Dispatcher (kind, caster position a, direction / target b, size f).
static func play(kind: String, world: Node3D, a: Vector3, b: Vector3, f: float) -> bool:
	match kind:
		"dust_sphere": dust_sphere(world, a, f)
		"dust_cone": dust_cone(world, a, b, f)
		"amenominaka": amenominaka(world, a, f)
		"shinra": shinra_tensei(world, a, f)
		"bansho": bansho_tenin(world, a, f)
		"chibaku": chibaku_tensei(world, b)
		"glare": SharinganFx.glare(world, a, f)
		"amaterasu":   # (remote view) the flames on whoever stands at `b`
			var body := nearest_body(world, b, 3.0)
			if body != null:
				AmaterasuBurn.ignite(body)
		_: return false
	return true

## The enemy / player / avatar closest to `p` (within `max_d`), to attach effects to remotely.
static func nearest_body(world: Node3D, p: Vector3, max_d: float) -> Node3D:
	var best: Node3D = null
	var bd := max_d
	var pool: Array = world.get_tree().get_nodes_in_group("enemies")
	pool.append_array(world.get_tree().get_nodes_in_group("player"))
	for av in NetworkSession._avatars.values():
		pool.append(av)
	for n in pool:
		if n is Node3D and is_instance_valid(n):
			var d := (n as Node3D).global_position.distance_to(p)
			if d < bd:
				bd = d
				best = n
	return best

# --- Dust Release -----------------------------------------------------------------------------

## The white light sphere: a geometric shell that swells over the area, flashes, then collapses.
static func dust_sphere(world: Node3D, pos: Vector3, r: float) -> void:
	var c := pos + Vector3.UP * 1.0
	var core := _mesh(world, _sphere(1.0), _glow_mat(Color(1.0, 1.0, 0.92), 0.55), c)
	var shell := _mesh(world, _sphere(1.0, 8), _glow_mat(Color(0.75, 0.85, 1.0), 0.35), c)
	(shell.material_override as StandardMaterial3D).wireframe = true   # (ignored where unsupported)
	for mi in [core, shell]:
		mi.scale = Vector3.ONE * 0.2
	var tw := core.create_tween().set_parallel()
	tw.tween_property(core, "scale", Vector3.ONE * r * 0.85, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(shell, "scale", Vector3.ONE * r, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(shell, "rotation", Vector3(0.6, 1.4, 0.2), 1.0)
	tw.chain().tween_interval(0.35)
	tw.chain().tween_property(core, "scale", Vector3.ONE * 0.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(shell, "scale", Vector3.ONE * 0.05, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		core.queue_free()
		shell.queue_free())
	_flash(world, c, Color(1.0, 1.0, 0.9), 8.0, r * 2.5, 0.9)
	_ring(world, Vector3(pos.x, _ground(world, pos) + 0.1, pos.z), r, Color(0.9, 0.95, 1.0), 0.6, 1.0)
	Vfx.burst(world, c, Color(1.0, 1.0, 0.9), 40, r * 0.8, 0.12, 0.6, 0.0)
	_shake(world, 0.2)

## The particle cone: a widening beam of white light that erases everything in front.
static func dust_cone(world: Node3D, pos: Vector3, dir: Vector3, r: float) -> void:
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = r * 0.45
	cm.height = r
	cm.radial_segments = 6   # faceted: the geometric look of Dust Release
	cm.cap_bottom = false
	cm.cap_top = false
	var start := pos + Vector3.UP * 1.2
	for k in 2:   # bright core + soft outer layer
		var mi := _mesh(world, cm, _glow_mat(Color(1.0, 1.0, 0.92) if k == 0 else Color(0.8, 0.9, 1.0), 0.6 if k == 0 else 0.3), start)
		mi.look_at(start + dir, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)   # cylinder axis (Y) -> forward
		mi.translate_object_local(Vector3.DOWN * r * 0.5)
		mi.scale = Vector3(0.6 if k == 0 else 1.0, 0.05, 0.6 if k == 0 else 1.0)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "rotation:y", mi.rotation.y + 0.0, 0.25)
		_fade(mi, 0.35, 0.3)
	_flash(world, start + dir * r * 0.5, Color(1.0, 1.0, 0.9), 6.0, r, 0.6)
	_shake(world, 0.15)

# --- Otsutsuki --------------------------------------------------------------------------------

## Amenominaka: the whole area is swapped into another dimension - a dark dome rushes out
## from Kaguya, the world flashes, then it snaps back.
static func amenominaka(world: Node3D, pos: Vector3, r: float) -> void:
	var c := pos + Vector3.UP * 0.5
	var dome := _mesh(world, _sphere(1.0), _glow_mat(Color(0.25, 0.1, 0.4), 0.45, false), c)
	dome.scale = Vector3.ONE * 0.3
	var rim := _mesh(world, _sphere(1.0), _glow_mat(Color(0.75, 0.6, 1.0), 0.25), c)
	rim.scale = Vector3.ONE * 0.3
	var tw := dome.create_tween().set_parallel()
	tw.tween_property(dome, "scale", Vector3.ONE * r, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(rim, "scale", Vector3.ONE * r * 1.03, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade(dome, 0.5, 0.5)
	_fade(rim, 0.35, 0.4)
	for i in 3:
		world.get_tree().create_timer(i * 0.12).timeout.connect(func() -> void:
			if is_instance_valid(world):
				_ring(world, Vector3(pos.x, _ground(world, pos) + 0.1, pos.z), r * (0.6 + i * 0.25), Color(0.7, 0.55, 1.0), 0.7, 1.0))
	_flash(world, c + Vector3.UP * 2.0, Color(0.7, 0.5, 1.0), 10.0, r * 2.0, 1.0)
	_shake(world, 0.35)

# --- Rinnegan ---------------------------------------------------------------------------------

## Shinra Tensei: an invisible push - a clear distortion sphere bursting outwards, a ring of
## dust racing along the ground and a crater flash.
static func shinra_tensei(world: Node3D, pos: Vector3, r: float) -> void:
	var c := pos + Vector3.UP * 1.0
	var wave := _mesh(world, _sphere(1.0), _glow_mat(Color(0.85, 0.85, 1.0), 0.22), c)
	wave.scale = Vector3.ONE * 0.5
	var tw := wave.create_tween()
	tw.tween_property(wave, "scale", Vector3.ONE * r, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade(wave, 0.25, 0.15)
	var g := Vector3(pos.x, _ground(world, pos) + 0.1, pos.z)
	_ring(world, g, r, Color(0.9, 0.85, 0.75), 0.5, 1.0)
	for i in 14:   # dust kicked up all around the edge
		var a := TAU * i / 14.0
		var p := g + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.55, 0.95)
		world.get_tree().create_timer(0.08 + randf() * 0.12).timeout.connect(func() -> void:
			if is_instance_valid(world):
				Fx.puff(world, p + Vector3.UP * 0.4, Color(0.7, 0.65, 0.55, 0.85), 2.0))
	_flash(world, c, Color(0.85, 0.8, 1.0), 6.0, r * 1.5, 0.5)
	_shake(world, 0.4)

## Bansho Ten'in: the reverse - rings and streaks rush IN to the user's palm.
static func bansho_tenin(world: Node3D, pos: Vector3, r: float) -> void:
	var c := pos + Vector3.UP * 1.0
	for i in 3:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.92
		tm.outer_radius = 1.0
		tm.rings = 48
		var mi := _mesh(world, tm, _glow_mat(Color(0.6, 0.5, 0.95), 0.0), c)
		mi.scale = Vector3(r, 0.5, r)
		var tw := mi.create_tween()
		tw.tween_interval(i * 0.12)
		tw.tween_property(mi.material_override, "albedo_color:a", 0.7, 0.05)
		tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 0.2), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	for i in 16:   # streaks converging on the user
		var a := TAU * i / 16.0
		var from := c + Vector3(cos(a), randf_range(-0.3, 0.6), sin(a)) * r * 0.8
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 1.6)
		var s := _mesh(world, bm, _glow_mat(Color(0.75, 0.65, 1.0), 0.7), from)
		s.look_at(c, Vector3.UP)
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", c, 0.3 + randf() * 0.15).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)
	var core := _mesh(world, _sphere(0.35), _glow_mat(Color(0.7, 0.6, 1.0), 0.8), c)
	var tw2 := core.create_tween()
	tw2.tween_property(core, "scale", Vector3.ONE * 1.8, 0.45)
	_fade(core, 0.2, 0.45)
	_shake(world, 0.15)

## Chibaku Tensei: a black core rises over the target; rocks fly in from the ground and pack
## into a sphere around it, then the planet crumbles.
static func chibaku_tensei(world: Node3D, target: Vector3) -> void:
	var g := Vector3(target.x, _ground(world, target), target.z)
	var c := g + Vector3.UP * 2.0
	var core := MeshInstance3D.new()
	core.mesh = _sphere(0.45)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.05, 0.04, 0.07)
	core.mesh.surface_set_material(0, cm)
	world.add_child(core)
	CharToon.apply(core)
	core.global_position = g + Vector3.UP * 0.5
	var ct := core.create_tween()
	ct.tween_property(core, "global_position", c, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.36, 0.3)
	var rocks: Array[MeshInstance3D] = []
	for i in 26:
		var rk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.6, 1.3), randf_range(0.5, 1.1), randf_range(0.6, 1.3))
		bm.material = rock_mat
		rk.mesh = bm
		world.add_child(rk)
		CharToon.apply(rk)
		var a := randf() * TAU
		rk.global_position = g + Vector3(cos(a), 0.0, sin(a)) * randf_range(4.0, 9.0)
		rk.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var tw := rk.create_tween()
		tw.tween_interval(0.25 + i * 0.03)
		tw.tween_property(rk, "global_position", c + dir * randf_range(1.5, 2.1), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rocks.append(rk)
	Sfx.play(core, "power", 0.0)
	var end := core.create_tween()
	end.tween_interval(2.6)
	end.tween_callback(func() -> void:
		Sfx.play(core, "boom", 2.0)
		Fx.puff(world, c, Color(0.5, 0.45, 0.4, 0.9), 4.0)
		_shake(world, 0.3)
		for rk in rocks:   # the sphere breaks apart and the rocks drop
			if is_instance_valid(rk):
				var out := (rk.global_position - c).normalized()
				var tw := rk.create_tween()
				tw.tween_property(rk, "global_position", rk.global_position + out * 2.5 + Vector3.DOWN * 3.0, 0.6).set_ease(Tween.EASE_IN)
				tw.tween_property(rk, "scale", Vector3.ONE * 0.01, 0.3)
				tw.tween_callback(rk.queue_free)
		core.queue_free())

# --- Projectile looks (used by Projectile._ready for its visual_kind) --------------------------

## Detachment of the Primitive World: a translucent cube with a cylinder of light inside.
static func build_dust_cube(parent: Node3D, size: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size * 2.0
	var box := MeshInstance3D.new()
	box.mesh = bm
	box.material_override = _glow_mat(Color(0.8, 0.9, 1.0), 0.3)
	root.add_child(box)
	var cy := CylinderMesh.new()
	cy.top_radius = size * 0.45
	cy.bottom_radius = size * 0.45
	cy.height = size * 1.9
	var inner := MeshInstance3D.new()
	inner.mesh = cy
	inner.material_override = _glow_mat(Color(1.0, 1.0, 0.9), 0.85)
	root.add_child(inner)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 1.0, 0.9)
	l.light_energy = 3.0
	l.omni_range = size * 8.0
	root.add_child(l)
	return root

## Dust impact: the cube balloons out over the blast radius and vanishes in a flash.
static func dust_impact(world: Node3D, pos: Vector3, r: float) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 2.0
	var box := _mesh(world, bm, _glow_mat(Color(0.85, 0.92, 1.0), 0.45), pos)
	box.scale = Vector3.ONE * 0.3
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector3.ONE * r, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_property(box, "scale", Vector3.ONE * 0.02, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(box.queue_free)
	_flash(world, pos, Color(1.0, 1.0, 0.9), 10.0, r * 3.0, 0.7)
	_shake(world, 0.2)

## Truth-Seeking Orb: a matte black sphere (toon) with a faint dark rim.
static func build_orb(parent: Node3D, size: float) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere(maxf(size, 0.22))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.035, 0.05)
	mi.mesh.surface_set_material(0, m)
	parent.add_child(mi)
	CharToon.apply(mi)
	return mi

## Ash Killing Bone: a long white bone spike.
static func build_bone(parent: Node3D, size: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = maxf(size, 0.12) * 0.6
	cm.height = maxf(size, 0.12) * 9.0
	cm.radial_segments = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.93, 0.86)
	cm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.rotation.x = -PI * 0.5   # point along -Z (the projectile's forward after look_at)
	root.add_child(mi)
	var knob := MeshInstance3D.new()   # the bone's joint at the back
	knob.mesh = _sphere(cm.bottom_radius * 1.2, 8)
	knob.mesh.surface_set_material(0, m)
	knob.position.z = cm.height * 0.5
	root.add_child(knob)
	CharToon.apply(root)
	return root
