@tool
extends EditorScript
## Run with File > Run in the Godot script editor.
## Prints the actual UV islands for surfaces using a material with "headband" in its name.

const GLB := "res://assets/character/character_main.glb"

func _run() -> void:
	var packed := load(GLB) as PackedScene
	if packed == null:
		push_error("[Headband UV] Could not load character scene: %s" % GLB)
		return
	var instance := packed.instantiate()
	if instance == null:
		push_error("[Headband UV] Could not instantiate character scene: %s" % GLB)
		return
	_walk(instance)
	instance.free()


func _walk(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.mesh.surface_get_material(surface)
				var material_name := material.resource_name if material != null else ""
				if material_name.to_lower().contains("headband"):
					_report(mesh_instance, surface, material)
	for child in node.get_children():
		_walk(child)


func _report(mesh_instance: MeshInstance3D, surface: int, material: Material) -> void:
	var mesh := mesh_instance.mesh
	var arrays := mesh.surface_get_arrays(surface)
	var uv_data = arrays[Mesh.ARRAY_TEX_UV]
	if not uv_data is PackedVector2Array or (uv_data as PackedVector2Array).is_empty():
		print("[Headband UV] %s surface %d has no UV data." % [mesh_instance.get_path(), surface])
		return
	var uvs: PackedVector2Array = uv_data
	if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
		print("[Headband UV] %s surface %d is not triangle geometry; inspect manually." % [mesh_instance.get_path(), surface])
		return

	var index_data = arrays[Mesh.ARRAY_INDEX]
	var use_indices := index_data is PackedInt32Array and not (index_data as PackedInt32Array).is_empty()
	var indices := PackedInt32Array()
	if use_indices:
		indices = index_data as PackedInt32Array
	var element_count := indices.size() if use_indices else uvs.size()
	if element_count % 3 != 0:
		print("[Headband UV] %s surface %d has an invalid triangle count." % [mesh_instance.get_path(), surface])
		return

	var parent: Array[int] = []
	for i in uvs.size():
		parent.append(i)
	for t in range(0, element_count, 3):
		var a: int = indices[t] if use_indices else t
		var b: int = indices[t + 1] if use_indices else t + 1
		var c: int = indices[t + 2] if use_indices else t + 2
		if a < 0 or b < 0 or c < 0 or a >= uvs.size() or b >= uvs.size() or c >= uvs.size():
			print("[Headband UV] %s surface %d contains invalid indices." % [mesh_instance.get_path(), surface])
			return
		var root_a := _find_root(parent, a)
		var root_b := _find_root(parent, b)
		var root_c := _find_root(parent, c)
		parent[root_b] = root_a
		parent[root_c] = root_a

	var islands: Dictionary = {}
	for i in uvs.size():
		var root := _find_root(parent, i)
		var entry: Dictionary = islands.get(root, {
			"min": Vector2(INF, INF),
			"max": Vector2(-INF, -INF),
			"vertices": 0
		})
		entry["min"] = Vector2(minf(entry["min"].x, uvs[i].x), minf(entry["min"].y, uvs[i].y))
		entry["max"] = Vector2(maxf(entry["max"].x, uvs[i].x), maxf(entry["max"].y, uvs[i].y))
		entry["vertices"] += 1
		islands[root] = entry

	var base_material := material as BaseMaterial3D
	print("== %s surface %d material '%s' ==" % [mesh_instance.get_path(), surface, material.resource_name if material else ""])
	if base_material != null:
		var texture_size: Variant = base_material.albedo_texture.get_size() if base_material.albedo_texture != null else "none"
		print("   uv1_scale=%s uv1_offset=%s texture_size=%s" % [base_material.uv1_scale, base_material.uv1_offset, texture_size])
	for root in islands:
		var entry: Dictionary = islands[root]
		var lo := float(entry["min"].x)
		var hi := float(entry["max"].x)
		var flag := ""
		if lo < 0.499 and hi > 0.501:
			flag = "  <-- STRADDLES u=0.5 (must be repacked before remapping)"
		elif hi <= 0.5:
			flag = "  [left half]"
		else:
			flag = "  [right half]"
		print("   island verts=%d  u[%.4f..%.4f]  v[%.4f..%.4f]%s" % [
			entry["vertices"], lo, hi, entry["min"].y, entry["max"].y, flag
		])


func _find_root(parent: Array[int], index: int) -> int:
	var current := index
	while parent[current] != current:
		parent[current] = parent[parent[current]]
		current = parent[current]
	return current
