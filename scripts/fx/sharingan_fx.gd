class_name SharinganFx
## Sharingan (Uchiha) technique visuals, anime style:
##  - glare:     Genjutsu - the three tomoe spin up in a red ring around the user and flash out.
##  - amaterasu: black flames with a dark crimson edge that cling to the target and keep burning
##               until it dies (see AmaterasuBurn) - started where the user looks, no travel.
##  - Susanoo arrow projectile (Projectile visual_kind "susanoo_arrow").

const RED := Color(0.85, 0.05, 0.08)

static var _flame_tex: ImageTexture
## A hard-edged teardrop flame (toon look), white - tinted per particle.
static func flame_tex() -> ImageTexture:
	if _flame_tex != null:
		return _flame_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0   # -1..1
			var v := (y + 0.5) / n               # 0 top .. 1 bottom
			# teardrop: round bottom, pointed wavy top
			var w := 0.0
			if v > 0.55:
				w = sqrt(maxf(0.0, 1.0 - pow((v - 0.55) / 0.42, 2.0))) * 0.62
			else:
				w = pow(v / 0.55, 1.6) * 0.62 + sin(v * 18.0) * 0.04 * (1.0 - v / 0.55)
			var a := 1.0 if absf(u) < w else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_flame_tex = ImageTexture.create_from_image(img)
	return _flame_tex

static func _flame_mat(priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA   # (sorted by render_priority: black on top)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = flame_tex()
	m.render_priority = priority
	return m

## Black flames covering a body of `height` (attached to `node`, in its local space).
static func black_flames(node: Node3D, height := 1.8, width := 0.45) -> Node3D:
	var root := Node3D.new()
	root.name = "AmaterasuFlames"
	node.add_child(root)
	for layer in 2:   # 0: crimson edge (bigger, behind) / 1: the black fire itself
		var p := CPUParticles3D.new()
		p.amount = 90 if layer == 1 else 45
		p.lifetime = 0.9
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(width, height * 0.5, width)
		p.position = Vector3(0, height * 0.5, 0)
		p.mesh = Vfx.quad()
		var fm := _flame_mat(layer)
		if Vfx.tex(Vfx.FIRE_BOOK) != null:   # the fire flipbook, dark
			fm.albedo_texture = Vfx.tex(Vfx.FIRE_BOOK)
			fm.particles_anim_h_frames = 4
			fm.particles_anim_v_frames = 4
			fm.particles_anim_loop = false
			p.anim_speed_min = 1.0
			p.anim_speed_max = 1.0
			p.angle_min = -12.0
			p.angle_max = 12.0
		p.material_override = fm
		p.direction = Vector3.UP
		p.spread = 12.0
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 1.6
		p.gravity = Vector3(0, 2.2, 0)
		p.scale_amount_min = 0.4 if layer == 1 else 0.45
		p.scale_amount_max = 0.75 if layer == 1 else 0.82
		p.scale_amount_curve = Vfx.shrink_curve()
		var g := Gradient.new()
		if layer == 1:
			g.colors = PackedColorArray([Color(0.02, 0.01, 0.03), Color(0.05, 0.02, 0.06), Color(0.1, 0.03, 0.08, 0.0)])
		else:
			g.colors = PackedColorArray([Color(0.38, 0.02, 0.08), Color(0.22, 0.01, 0.08), Color(0.1, 0.0, 0.06, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		p.color_ramp = g
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(p)
	# black smoke drifting off the top
	var s := CPUParticles3D.new()
	s.amount = 16
	s.lifetime = 1.6
	s.local_coords = false
	s.position = Vector3(0, height, 0)
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = width
	s.mesh = Vfx.quad()
	s.material_override = Vfx.particle_mat(false, 1.0)
	s.direction = Vector3.UP
	s.initial_velocity_min = 0.8
	s.initial_velocity_max = 1.5
	s.scale_amount_min = 0.5
	s.scale_amount_max = 0.9
	var sg := Gradient.new()
	sg.colors = PackedColorArray([Color(0.05, 0.03, 0.06, 0.6), Color(0.08, 0.05, 0.08, 0.0)])
	s.color_ramp = sg
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(s)
	return root

## Genjutsu glare: three tomoe on a red ring spin around the user, then flash outwards.
static func glare(world: Node3D, pos: Vector3, r: float) -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos + Vector3.UP * 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = RED
	var tm := TorusMesh.new()
	tm.inner_radius = 1.45
	tm.outer_radius = 1.55
	tm.rings = 48
	tm.material = mat
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	root.add_child(ring)
	var bmat := mat.duplicate() as StandardMaterial3D
	bmat.albedo_color = Color(0.05, 0.0, 0.0)
	for i in 3:   # tomoe: a black dot with a tail
		var t := Node3D.new()
		root.add_child(t)
		t.rotation.y = TAU * i / 3.0
		var dot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		sm.material = bmat
		dot.mesh = sm
		dot.position = Vector3(1.5, 0, 0)
		t.add_child(dot)
		var tail := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.12
		cm.height = 0.55
		cm.material = bmat
		tail.mesh = cm
		tail.position = Vector3(1.42, 0, 0.3)
		tail.rotation = Vector3(PI * 0.5, 0.25, 0)
		t.add_child(tail)
	root.scale = Vector3.ONE * 0.3
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "rotation:y", -TAU * 1.5, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(root, "scale", Vector3.ONE * (r / 1.5), 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.parallel().tween_property(bmat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(root.queue_free)
	Vfx.glow_light(root, RED, 3.0, 8.0)
	Sfx.play(root, "power", -2.0)

## Susanoo arrow: a huge glowing purple arrow (shaft, broad head, fletching).
static func build_susanoo_arrow(parent: Node3D, size: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var col := Color(0.62, 0.35, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	var L := size * 9.0
	var shaft := CylinderMesh.new()
	shaft.top_radius = size * 0.18
	shaft.bottom_radius = size * 0.18
	shaft.height = L
	shaft.material = mat
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = size * 0.7
	head.height = size * 2.2
	head.radial_segments = 4   # a flat-ish blade
	head.material = mat
	for spec in [[shaft, 0.0], [head, -L * 0.5 - size * 1.1]]:
		var mi := MeshInstance3D.new()
		mi.mesh = spec[0]
		mi.rotation.x = -PI * 0.5   # +Y -> -Z (forward)
		mi.position.z = spec[1]
		root.add_child(mi)
	for i in 3:   # fletching
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size * 0.05, size * 0.8, size * 1.6)
		bm.material = mat
		f.mesh = bm
		f.position.z = L * 0.5 - size * 0.6
		f.rotation.z = TAU * i / 3.0
		f.translate_object_local(Vector3(0, size * 0.4, 0))
		root.add_child(f)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 3.0
	l.omni_range = size * 10.0
	root.add_child(l)
	return root
