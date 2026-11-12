class_name GenjutsuWorld
extends Node3D
## The paralysis genjutsu's dimension (only the victim sees it): a red sky dome with a huge red
## moon, a black mirror floor, a cross you're bound in front of, and the caster standing there
## staring at you with the Sharingan. Built far below the map.

const ORIGIN := Vector3(0, -900, 0)

## caster_look: who stands in it with you (the victim sees the caster; the caster, master=true,
## sees nobody extra - the victim's own avatar is moved in instead).
static func build(world: Node3D, caster_look: Dictionary, caster := 0, body := Vector3.ZERO, master := false) -> GenjutsuWorld:
	var g := GenjutsuWorld.new()
	g.name = "GenjutsuWorld"
	g.caster_peer = caster
	g.anchor = body
	g.master = master
	world.add_child(g)
	g.global_position = ORIGIN
	g._make(caster_look)
	return g

func _unshaded(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m

var caster_fig: Node3D       # the caster's figure in here (mirrors their real movement)
var caster_peer := 0
var anchor := Vector3.ZERO     # the victim's body in the real world
var master := false            # built for the caster (who walks around freely in here)
var master_off := Vector3(0, 0, -5.1)   # (victim) where the caster is, relative to you - sent by the caster
var master_yaw := PI

func _make(caster_look: Dictionary) -> void:
	var sky := MeshInstance3D.new()   # inside of a huge sphere: blood-red sky, darker at the top
	var sm := SphereMesh.new()
	sm.radius = 320.0
	sm.height = 640.0
	sky.mesh = sm
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, cull_front;\nvarying float h;\nvoid vertex(){ h = VERTEX.y / 320.0; }\nvoid fragment(){ ALBEDO = mix(vec3(0.62, 0.05, 0.04), vec3(0.12, 0.0, 0.02), clamp(h * 1.6, 0.0, 1.0)); }"
	var skm := ShaderMaterial.new()
	skm.shader = sh
	sky.material_override = skm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	# the blood moon: a huge red disc with a glow around it
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 42.0
	mm.height = 84.0
	moon.mesh = mm
	moon.material_override = _unshaded(Color(0.85, 0.06, 0.04))
	moon.position = Vector3(0, 120, -240)
	add_child(moon)
	var halo := MeshInstance3D.new()
	halo.mesh = Vfx.quad()
	halo.material_override = Vfx.tex_mat("effects/Glow01.png", Color(1.0, 0.15, 0.08), 1.2, true)
	halo.scale = Vector3.ONE * 190.0
	halo.position = moon.position + Vector3(0, 0, 10)
	add_child(halo)
	# dark mountains all around the horizon
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.06, 0.02, 0.03)
	rock.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 34:
		var a := TAU * i / 34.0 + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(150.0, 250.0)
		var h := rng.randf_range(40.0, 120.0)
		var cm := CylinderMesh.new()
		cm.top_radius = rng.randf_range(0.0, 6.0)
		cm.bottom_radius = h * rng.randf_range(0.55, 0.9)
		cm.height = h
		cm.radial_segments = 6
		cm.rings = 1
		cm.material = rock
		var m := MeshInstance3D.new()
		m.mesh = cm
		m.position = Vector3(cos(a) * dist, h * 0.5 - 2.0, sin(a) * dist)
		m.rotation.y = rng.randf() * TAU
		add_child(m)
	var floor := StaticBody3D.new()   # (solid, so the victim stands on it)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 0.4, 600)
	cs.shape = bs
	floor.add_child(cs)
	var fm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	fm.mesh = pm
	var flm := StandardMaterial3D.new()   # black mirror ground that catches the red light
	flm.albedo_color = Color(0.05, 0.01, 0.02)
	flm.metallic = 0.7
	flm.roughness = 0.12
	fm.material_override = flm
	fm.position.y = 0.2
	floor.add_child(fm)
	add_child(floor)
	var wood := StandardMaterial3D.new()   # the cross behind you
	wood.albedo_color = Color(0.12, 0.08, 0.06)
	for spec in [[Vector3(0.35, 4.2, 0.35), Vector3(0, 2.3, 1.2)], [Vector3(3.0, 0.32, 0.32), Vector3(0, 3.4, 1.2)]]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[0]
		bm.material = wood
		b.mesh = bm
		b.position = spec[1]
		add_child(b)
	var moonlight := DirectionalLight3D.new()   # red light from the moon
	moonlight.light_color = Color(1.0, 0.3, 0.22)
	moonlight.light_energy = 0.9
	moonlight.shadow_enabled = true
	add_child(moonlight)
	moonlight.look_at_from_position(moon.position, Vector3.ZERO, Vector3.UP)
	var caster: Node3D = null if master else Hero.create(caster_look)   # the caster, in here with you
	if caster != null:
		add_child(caster)
		caster.position = Vector3(0, 0.2, -4.5)
		caster.rotation.y = PI   # (models face -Z: turned to face the victim at +Z)
		Hero.apply_mode_look(caster, Bloodline.mode("uchiha").get("look", {}))
		Hero.play(caster, "idle")
		caster_fig = caster
	CharToon.apply(self)

## The caster moves around in here exactly as they move around your body in the real world.
func _process(delta: float) -> void:
	if caster_fig == null or not is_instance_valid(caster_fig):
		return
	var want := victim_spot() + Vector3(master_off.x, -0.1, master_off.z)   # the caster walks around in here
	var step := want - caster_fig.global_position
	step.y = 0.0
	var spd := step.length() / maxf(delta, 0.001)
	caster_fig.global_position = caster_fig.global_position.lerp(want, minf(1.0, 12.0 * delta))
	caster_fig.rotation.y = lerp_angle(caster_fig.rotation.y, master_yaw, minf(1.0, 12.0 * delta))
	Hero.play_move(caster_fig, Hero.move_state(spd) if spd > 0.4 else "idle", spd if spd > 0.4 else 0.0)

## Where the victim stands (in front of the cross, facing the caster).
func victim_spot() -> Vector3:
	return global_position + Vector3(0, 0.3, 0.6)
