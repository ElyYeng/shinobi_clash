class_name StaticBatcher
extends RefCounted
## Cuts draw calls on block-built maps (the Konoha greybox): at load time every plain mesh with a
## shared material is merged into one mesh per material per grid cell, and the originals are
## dropped (their colliders stay). The scene file is untouched, so blocks stay editable in Godot.

const CELL := 64.0   # merge cells (metres) - small enough that off-screen cells still get culled

## Merges the meshes under `root` (skips skinned meshes, NPCs, markers and anything with its own
## script). Returns how many mesh instances were folded into how many batches.
static func batch(root: Node3D, skip_groups := ["NPCs", "Markers", "Villagers", "Environment"]) -> Vector2i:
	var buckets := {}   # "material|cx|cz|shadow" -> {mat, st, shadow}
	var sigs := {}      # material -> signature (copies with identical settings share one)
	var folded := 0
	var to_free: Array[MeshInstance3D] = []
	var inv := root.global_transform.affine_inverse()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null or mi.get_script() != null or not mi.visible or mi.mesh == null:
			continue
		if mi.extra_cull_margin > 0.0:   # full-screen effects (anime outline quad) must stay as they are
			continue
		if _under_skipped(mi, root, skip_groups):
			continue
		var n := mi.mesh.get_surface_count()
		var ok := n > 0
		for i in n:   # every surface needs a material and plain triangles
			var prim := (mi.mesh as ArrayMesh).surface_get_primitive_type(i) if mi.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
			if mi.get_active_material(i) == null or prim != Mesh.PRIMITIVE_TRIANGLES:
				ok = false
		if not ok:
			continue
		var xf := inv * mi.global_transform
		var c := xf.origin
		for i in n:
			var mat := mi.get_active_material(i)
			var key := "%s|%d|%d|%d" % [_mat_sig(mat, sigs), floori(c.x / CELL), floori(c.z / CELL), int(mi.cast_shadow)]
			if not buckets.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				buckets[key] = {"mat": mat, "st": st, "shadow": mi.cast_shadow}
			(buckets[key]["st"] as SurfaceTool).append_from(mi.mesh, i, xf)
		to_free.append(mi)
		folded += 1
	var holder := Node3D.new()
	holder.name = "Batched"
	root.add_child(holder)
	for key in buckets:
		var b: Dictionary = buckets[key]
		var out := MeshInstance3D.new()
		out.mesh = (b["st"] as SurfaceTool).commit()
		out.material_override = b["mat"]
		out.cast_shadow = b["shadow"]
		holder.add_child(out)
	for mi in to_free:
		mi.queue_free()
	return Vector2i(folded, buckets.size())

## Identical-looking materials (e.g. each tree carrying its own copy) get the same signature so
## they merge into one draw.
static func _mat_sig(mat: Material, cache: Dictionary) -> String:
	var id := mat.get_instance_id()
	if cache.has(id):
		return cache[id]
	var parts := PackedStringArray([mat.get_class()])
	for prop in mat.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_STORAGE and String(prop["name"]) != "resource_name":
			parts.append(str(mat.get(prop["name"])))
	var sig := str("|".join(parts).hash())
	cache[id] = sig
	return sig

static func _under_skipped(n: Node, root: Node, skip: Array) -> bool:
	var p := n.get_parent()
	while p != null and p != root:
		if skip.has(String(p.name)):
			return true
		p = p.get_parent()
	return false
