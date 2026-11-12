class_name CrystalAura
extends Node3D
## Crystal Armor's aura: faceted crystal clusters growing around the user - a slowly turning ring
## of shards at the waist, spikes on the ground around the feet and a few floating at the
## shoulders. Toon shaded, translucent ice-blue with a soft glow.

const COL := Color(0.55, 0.85, 1.0)
var _ring: Node3D

static func make(parent: Node3D) -> CrystalAura:
	var c := CrystalAura.new()
	c.name = "CrystalAura"
	parent.add_child(c)
	return c

static func shard_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(COL.r, COL.g, COL.b, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = COL
	m.emission_energy_multiplier = 0.35
	m.metallic_specular = 1.0
	m.roughness = 0.1
	m.rim_enabled = true
	m.rim = 0.8
	return m

func _shard(parent: Node3D, pos: Vector3, h: float, rad: float, tilt: Vector3, mat: Material) -> Node3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = rad
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	cm.material = mat
	var piv := Node3D.new()
	parent.add_child(piv)
	piv.position = pos
	piv.rotation = tilt
	var s := MeshInstance3D.new()
	s.mesh = cm
	s.position.y = h * 0.5
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piv.add_child(s)
	piv.scale = Vector3(1, 0.02, 1)
	piv.create_tween().tween_property(piv, "scale", Vector3.ONE, randf_range(0.15, 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return piv

func _ready() -> void:
	var mat := shard_mat()
	_ring = Node3D.new()
	add_child(_ring)
	for i in 9:   # waist ring, pointing outwards and up
		var a := TAU * i / 9.0
		var p := Vector3(cos(a), 0.0, sin(a)) * 0.75 + Vector3.UP * randf_range(0.6, 1.3)
		var sh := _shard(_ring, p, randf_range(0.45, 0.8), randf_range(0.07, 0.12), Vector3.ZERO, mat)
		sh.look_at_from_position(sh.position, sh.position + Vector3(cos(a), 1.2, sin(a)), Vector3.UP)
		sh.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	for i in 12:   # ground cluster around the feet
		var a := TAU * i / 12.0 + randf_range(-0.2, 0.2)
		var p := Vector3(cos(a), 0.0, sin(a)) * randf_range(0.7, 1.3)
		_shard(self, p, randf_range(0.5, 1.1), randf_range(0.1, 0.2), Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4), mat)
	for side in [-1.0, 1.0]:   # shoulder crystals
		for k in 2:
			_shard(self, Vector3(side * 0.35, 1.55, -0.1 + k * 0.15), randf_range(0.35, 0.55), 0.07, Vector3(0, 0, side * -0.7 + k * 0.2 * side), mat)
	CharToon.apply(self)
	Vfx.burst(get_parent(), global_position + Vector3.UP, COL, 30, 6.0, 0.2, 0.6)

func _process(delta: float) -> void:
	if _ring != null:
		_ring.rotation.y += delta * 0.6
