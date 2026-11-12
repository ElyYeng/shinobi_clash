class_name ArenaMap
extends Node3D
## The imported PvP / PvE arena model (assets/arena/arenamap.glb, placed as "Ground" in
## maps/arena.tscn). At load: solid trimesh colliders for the arena (floor, walls, stands), and
## the model's materials cleaned up - everything came in as "see-through", so the ones whose
## texture has no real transparency become solid (toon-shaded like the rest of the game) and the
## cut-outs (leaves, banners) become alpha-scissor (sharp edges, cast shadows, no sorting issues).

@export var collide_max_size := 200.0   ## meshes wider than this (the far backdrop) get no collision

func _ready() -> void:
	var col := Node3D.new()
	col.name = "Collision"
	add_child(col)
	var done := {}
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m != null and not done.has(m):
				done[m] = true
				_fix_material(m)
		var a := mi.get_aabb()
		if maxf(a.size.x, a.size.z) > collide_max_size:
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		col.add_child(body)
		body.global_transform = mi.global_transform

static func _fix_material(m: BaseMaterial3D) -> void:
	if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	var tex := m.albedo_texture
	var img: Image = tex.get_image() if tex != null else null
	var see_through := m.albedo_color.a < 0.99 or (img != null and img.detect_alpha() != Image.ALPHA_NONE)
	if not see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	elif m.albedo_color.a >= 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
