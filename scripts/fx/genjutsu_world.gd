class_name GenjutsuWorld
extends Node3D
## The paralysis genjutsu's dimension (only the victim sees it): a red sky dome with a huge red
## moon, a black mirror floor, a cross you're bound in front of, and the caster standing there
## staring at you with the Sharingan. Built far below the map.

const ORIGIN := Vector3(0, -900, 0)

static func build(world: Node3D, caster_look: Dictionary) -> GenjutsuWorld:
	var g := GenjutsuWorld.new()
	g.name = "GenjutsuWorld"
	world.add_child(g)
	g.global_position = ORIGIN
	g._make(caster_look)
	return g

func _unshaded(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m

func _make(caster_look: Dictionary) -> void:
	var sky := MeshInstance3D.new()   # inside of a sphere: blood-red sky
	var sm := SphereMesh.new()
	sm.radius = 60.0
	sm.height = 120.0
	sky.mesh = sm
	var skm := _unshaded(Color(0.55, 0.02, 0.03))
	skm.cull_mode = BaseMaterial3D.CULL_FRONT
	sky.material_override = skm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 9.0
	mm.height = 18.0
	moon.mesh = mm
	moon.material_override = _unshaded(Color(0.95, 0.12, 0.1))
	moon.position = Vector3(0, 30, -48)
	add_child(moon)
	var floor := StaticBody3D.new()   # (solid, so the victim stands on it)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(80, 0.4, 80)
	cs.shape = bs
	floor.add_child(cs)
	var fm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	fm.mesh = pm
	var flm := StandardMaterial3D.new()
	flm.albedo_color = Color(0.05, 0.01, 0.02)
	flm.metallic = 0.6
	flm.roughness = 0.15
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
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.25, 0.2)
	light.light_energy = 2.0
	light.omni_range = 30.0
	light.position = Vector3(0, 8, -6)
	add_child(light)
	var caster := Hero.create(caster_look)   # the caster, watching you
	if caster != null:
		add_child(caster)
		caster.position = Vector3(0, 0.2, -4.5)
		caster.rotation.y = PI   # (models face -Z: turned to face the victim at +Z)
		Hero.apply_mode_look(caster, Bloodline.mode("uchiha").get("look", {}))
		Hero.play(caster, "idle")
	CharToon.apply(self)

## Where the victim stands (in front of the cross, facing the caster).
func victim_spot() -> Vector3:
	return global_position + Vector3(0, 0.3, 0.6)
