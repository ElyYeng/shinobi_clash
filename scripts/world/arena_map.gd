class_name ArenaMap
extends Node3D
## The imported PvP / PvE arena model (assets/arena/arenamap.glb, placed as "Ground" in
## maps/arena.tscn). At load: solid trimesh colliders for the arena (floor, walls, stands), and
## the model's materials cleaned up - everything came in as "see-through", so the ones whose
## texture has no real transparency become solid (toon-shaded like the rest of the game) and the
## cut-outs (leaves, banners) become alpha-scissor (sharp edges, cast shadows, no sorting issues).

## The model's own solid meshes as colliders: floor tiles, walls, tree trunks, stands. Cut-out
## meshes (grass tufts, leaf cards, ground decals) never collide - they trapped the player.
@export var mesh_collision := true
@export var collide_max_size := 200.0   ## (mesh_collision) meshes wider than this get no collision
## The round arena wall is one smooth invisible ring instead of its mesh (whose seams you could slip
## through): inner radius in model units (scaled with this node), segments, height.
@export var wall_radius := 41.79
@export var wall_segments := 96
@export var wall_height := 140.0
@export var wall_meshes: Array[String] = ["7_mesh26_0_16_16", "7_mesh29_0_16_16", "7_mesh30_0_16_16"]

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
		if not mesh_collision or maxf(a.size.x, a.size.z) > collide_max_size:
			continue
		if wall_meshes.has(str(mi.name)):
			continue
		var solid := true
		for i in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if sm != null and sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				solid = false
		if not solid:
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

	_build_ring()

## A smooth round wall (overlapping thick boxes all the way round, so there are no seams) and a
## round floor under everything, in world units under Bounds.
func _build_ring() -> void:
	var holder: Node3D = get_parent().get_node_or_null("Bounds") if get_parent() != null else null
	if holder == null:
		holder = self
	var sc := global_transform.basis.get_scale().x
	var r := wall_radius * sc
	var c := global_position
	var thick := 4.0
	var chord := TAU * (r + thick * 0.5) / float(wall_segments) * 1.25   # (overlap: no gaps)
	var box := BoxShape3D.new()
	box.size = Vector3(chord, wall_height, thick)
	var ring := StaticBody3D.new()
	ring.name = "RoundWall"
	holder.add_child(ring)
	ring.global_position = c
	for i in wall_segments:
		var a := TAU * float(i) / float(wall_segments)
		var cs := CollisionShape3D.new()
		cs.shape = box
		ring.add_child(cs)
		var out := Vector3(sin(a), 0, cos(a))
		cs.position = out * (r + thick * 0.5) + Vector3.UP * (wall_height * 0.5 - 2.0)
		cs.rotation.y = a   # (the box's thin side faces the centre)
	var floor_body := StaticBody3D.new()
	floor_body.name = "RoundFloor"
	var fs := CylinderShape3D.new()
	fs.radius = r + thick
	fs.height = 4.0
	var fcs := CollisionShape3D.new()
	fcs.shape = fs
	floor_body.add_child(fcs)
	holder.add_child(floor_body)
	floor_body.global_position = c + Vector3.DOWN * 2.0   # (top at the arena floor)

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
