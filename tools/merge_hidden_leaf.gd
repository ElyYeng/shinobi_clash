extends Node
## Bakes the Hidden Leaf Village model into the open-world map, with its 142 materials merged.
## Run it (from the project folder) when the model changes:
##   1)  godot --headless --path . res://tools/merge_hidden_leaf.tscn            (STEP=bake, default)
##   2)  godot --headless --path . --import                                       (imports the atlas)
##   3)  STEP=scene godot --headless --path . res://tools/merge_hidden_leaf.tscn  (writes the map)
##
## bake:  every texture goes into ONE atlas (assets/hidden_leaf/atlas.webp). Meshes are merged
##        into chunks of CHUNK metres, split into 3 kinds: opaque, cutout (leaves, fences...) and
##        water. Each vertex stores its texture's atlas region (CUSTOM0), and the atlas shaders
##        (shaders/atlas_*.gdshader) wrap tiling UVs inside it - so 3 materials draw everything.
##        Opaque chunks also get a trimesh collision shape.
## scene: maps/open_world.tscn = the merged village + Environment / Decor / Markers / NPCs taken
##        from the stashed procedural open world (maps/stash/open_world_procedural.tscn), with the
##        markers dropped onto the ground.

const SRC := "res://assets/hidden_leaf/source/hiddenleafvillagewip.glb"
const OUT := "res://assets/hidden_leaf/"
const STASH := "res://maps/stash/open_world_procedural.tscn"
const MAP := "res://maps/open_world.tscn"
const MAX_TEX := 1024          # bigger textures are scaled down to this before packing
const ATLAS_W := 8192
const PAD := 8                 # wrapped border around every region (keeps mipmaps clean)
const CHUNK := 96.0            # metres; chunks can be culled when off screen
const WATER_WORDS := ["water", "lake", "stream", "wave", "river"]
const PLACE_NPCS := true       # scene step: put the NPC spawns on open ground around the player spawn

func _ready() -> void:
	if OS.get_environment("STEP") == "scene":
		await _compose_scene()
	else:
		_bake()
	get_tree().quit()

# ================================================================== bake
func _bake() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC), st)
	if err != OK:
		push_error("[merge] can't read %s (%s)" % [SRC, error_string(err)])
		return
	var root := doc.generate_scene(st)
	# ---- textures -> atlas entries (one per distinct texture; untextured materials share white)
	var entries := {}          # key -> {"img": Image, "rect": Rect2i}
	var surfaces: Array = []   # {"mesh", "surface", "xf", "key", "color", "kind"}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := _xform(mi, root)
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if mi.get_surface_override_material(s) != null:
				m = mi.get_surface_override_material(s)
			var key := "white"
			var color := Color.WHITE
			var kind := "opaque"
			var mname := ""
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				color = bm.albedo_color
				mname = bm.resource_name.to_lower()
				if bm.albedo_texture != null:
					key = str(bm.albedo_texture.get_rid().get_id())
					if not entries.has(key):
						entries[key] = {"img": _prep(bm.albedo_texture.get_image())}
				if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					kind = "cutout"
			for w in WATER_WORDS:
				if mname.contains(w):
					kind = "water"
			surfaces.append({"mesh": mi.mesh, "surface": s, "xf": xf, "key": key, "color": color, "kind": kind})
	if not entries.has("white"):
		var white := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		entries["white"] = {"img": white}
	# ---- shelf packing (tallest first)
	var keys := entries.keys()
	keys.sort_custom(func(a, b): return (entries[a]["img"] as Image).get_height() > (entries[b]["img"] as Image).get_height())
	var x := 0
	var y := 0
	var shelf := 0
	for k in keys:
		var img: Image = entries[k]["img"]
		var w := img.get_width() + PAD * 2
		var h := img.get_height() + PAD * 2
		if x + w > ATLAS_W:
			x = 0
			y += shelf
			shelf = 0
		entries[k]["rect"] = Rect2i(x + PAD, y + PAD, img.get_width(), img.get_height())
		x += w
		shelf = maxi(shelf, h)
	var atlas_h := y + shelf
	atlas_h = ((atlas_h + 3) / 4) * 4
	var atlas := Image.create(ATLAS_W, atlas_h, false, Image.FORMAT_RGBA8)
	for k in keys:
		var img: Image = entries[k]["img"]
		var r: Rect2i = entries[k]["rect"]
		# padded copy: the texture plus a PAD-wide border of its own wrapped edges, so tiling and
		# mipmaps sample the right colours at region edges
		var padded := Image.create(r.size.x + PAD * 2, r.size.y + PAD * 2, false, Image.FORMAT_RGBA8)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				padded.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(PAD + dx * r.size.x, PAD + dy * r.size.y))
		atlas.blit_rect(padded, Rect2i(Vector2i.ZERO, padded.get_size()), r.position - Vector2i(PAD, PAD))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "chunks"))
	atlas.save_webp(ProjectSettings.globalize_path(OUT + "atlas.webp"), true, 0.92)
	_write_atlas_import()
	print("[merge] atlas %dx%d, %d textures" % [ATLAS_W, atlas_h, keys.size()])
	# ---- merge surfaces into chunks
	var chunks := {}
	for s in surfaces:
		var mesh: Mesh = s["mesh"]
		var arr := mesh.surface_get_arrays(int(s["surface"]))
		var xf: Transform3D = s["xf"]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var center := xf * mesh.get_aabb().get_center()
		var ck := "%s_%d_%d" % [s["kind"], int(floor(center.x / CHUNK)), int(floor(center.z / CHUNK))]
		if not chunks.has(ck):
			chunks[ck] = {"kind": s["kind"], "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
				"c": PackedColorArray(), "r": PackedFloat32Array(), "i": PackedInt32Array()}
		var c: Dictionary = chunks[ck]
		# Packed arrays are values: work on locals and store them back at the end.
		var cv: PackedVector3Array = c["v"]
		var cn: PackedVector3Array = c["n"]
		var cuv: PackedVector2Array = c["uv"]
		var cc: PackedColorArray = c["c"]
		var cr: PackedFloat32Array = c["r"]
		var ci: PackedInt32Array = c["i"]
		var base: int = cv.size()
		var nb := xf.basis.inverse().transposed()
		var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var r: Rect2i = entries[s["key"]]["rect"]
		var reg := [(r.position.x + 0.5) / ATLAS_W, (r.position.y + 0.5) / float(atlas_h),
			(r.size.x - 1.0) / ATLAS_W, (r.size.y - 1.0) / float(atlas_h)]
		var tint: Color = s["color"]
		var regp := PackedFloat32Array(reg)
		for i in verts.size():
			cv.append(xf * verts[i])
			cn.append((nb * normals[i]).normalized() if i < normals.size() else Vector3.UP)
			cuv.append(uvs[i] if i < uvs.size() else Vector2.ZERO)
			cc.append((cols[i] if i < cols.size() else Color.WHITE) * tint)
			cr.append_array(regp)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i in verts.size():
				ci.append(base + i)
		else:
			for i in idx:
				ci.append(base + i)
		c["v"] = cv
		c["n"] = cn
		c["uv"] = cuv
		c["c"] = cc
		c["r"] = cr
		c["i"] = ci
	var manifest := []
	for ck in chunks:
		var c: Dictionary = chunks[ck]
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = c["v"]
		a[Mesh.ARRAY_NORMAL] = c["n"]
		a[Mesh.ARRAY_TEX_UV] = c["uv"]
		a[Mesh.ARRAY_COLOR] = c["c"]
		a[Mesh.ARRAY_CUSTOM0] = c["r"]
		a[Mesh.ARRAY_INDEX] = c["i"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		var mp := OUT + "chunks/%s.res" % ck
		ResourceSaver.save(am, mp, ResourceSaver.FLAG_COMPRESS)
		var entry := {"name": ck, "kind": c["kind"], "mesh": mp}
		if c["kind"] == "opaque":
			var shape := am.create_trimesh_shape()
			var sp := OUT + "chunks/%s_col.res" % ck
			ResourceSaver.save(shape, sp, ResourceSaver.FLAG_COMPRESS)
			entry["shape"] = sp
		manifest.append(entry)
	var f := FileAccess.open(OUT + "chunks/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	print("[merge] %d surfaces -> %d chunks" % [surfaces.size(), chunks.size()])
	root.free()

## Import settings for the atlas: VRAM-compressed with mipmaps (Godot's default for a new image
## would be lossless without mipmaps - shimmering in the distance and lots of video memory).
func _write_atlas_import() -> void:
	var p := ProjectSettings.globalize_path(OUT + "atlas.webp.import")
	var keep_uid := ""
	if FileAccess.file_exists(p):
		for line in FileAccess.get_file_as_string(p).split("\n"):
			if line.begins_with("uid="):
				keep_uid = line
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n%s\n\n[deps]\n\nsource_file=\"%satlas.webp\"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=false\nmipmaps/generate=true\nmipmaps/limit=-1\ndetect_3d/compress_to=0\n" % [keep_uid, OUT])

## Uncompressed RGBA, at most MAX_TEX on a side.
func _prep(img: Image) -> Image:
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.has_mipmaps():
		img.clear_mipmaps()
	var s := maxf(img.get_width(), img.get_height())
	if s > MAX_TEX:
		var k := MAX_TEX / s
		img.resize(maxi(4, int(img.get_width() * k)), maxi(4, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return img

func _xform(node: Node3D, root: Node) -> Transform3D:
	# Skinned meshes are placed by their skeleton (bone pose x bind pose), not by their own node
	# transform - skip that and those pieces land rotated/mirrored. Same placement Blender shows.
	var mi := node as MeshInstance3D
	if mi != null and mi.skin != null and mi.skin.get_bind_count() > 0:
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if skel == null:
			skel = mi.get_parent() as Skeleton3D
		if skel != null:
			var bone := mi.skin.get_bind_bone(0)
			if bone < 0:
				bone = skel.find_bone(mi.skin.get_bind_name(0))
			return _xform(skel, root) * skel.get_bone_global_pose(maxi(bone, 0)) * mi.skin.get_bind_pose(0)
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

# ================================================================== scene
func _compose_scene() -> void:
	await get_tree().process_frame   # the tree must finish setting up before adding the map
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(OUT + "chunks/manifest.json"))
	var atlas := load(OUT + "atlas.webp") as Texture2D
	var mats := {}
	for kind in ["opaque", "cutout", "water"]:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/atlas_%s.gdshader" % kind)
		sm.set_shader_parameter("atlas", atlas)
		ResourceSaver.save(sm, OUT + "atlas_%s.tres" % kind)
		mats[kind] = load(OUT + "atlas_%s.tres" % kind)
	var old: Node3D = (load(STASH) as PackedScene).instantiate()
	var map := Node3D.new()
	map.name = "OpenWorld"
	map.set_script(load("res://game_map.gd"))
	map.set("play_half", 420.0)
	get_tree().root.add_child(map)
	var village := Node3D.new()
	village.name = "Village"
	map.add_child(village)
	village.owner = map
	for e in manifest:
		var mi := MeshInstance3D.new()
		mi.name = str(e["name"])
		mi.mesh = load(str(e["mesh"]))
		mi.material_override = mats[str(e["kind"])]
		if str(e["kind"]) != "opaque":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if str(e["kind"]) == "cutout" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		village.add_child(mi)
		mi.owner = map
		if e.has("shape"):
			var body := StaticBody3D.new()
			body.name = "Col"
			mi.add_child(body)
			body.owner = map
			var cs := CollisionShape3D.new()
			cs.shape = load(str(e["shape"]))
			body.add_child(cs)
			cs.owner = map
	for keep in ["Environment", "Decor", "Markers", "NPCs"]:   # from the stashed open world
		var n := old.get_node_or_null(keep)
		if n == null:
			continue
		old.remove_child(n)
		map.add_child(n)
		_own(n, map)
	_add_bounds(map, manifest)
	# wait for physics, then drop the player spawn onto the ground and put the NPCs on open ground
	for i in 3:
		await get_tree().physics_frame
	var space := map.get_world_3d().direct_space_state
	var spawn := map.get_node_or_null("Markers/PlayerSpawn") as Node3D
	var ground := _ground(space, spawn.global_position) if spawn != null else Vector3.ZERO
	if spawn != null:
		spawn.global_position = ground + Vector3.UP
	var npcs := map.get_node_or_null("NPCs")
	if npcs != null and PLACE_NPCS:
		var spots := _open_spots(space, ground, npcs.get_child_count())
		var i := 0
		for m in npcs.get_children():
			if m is Node3D and i < spots.size():
				(m as Node3D).global_position = spots[i]
				print("[merge] NPC %s -> %s" % [m.name, spots[i]])
				i += 1
	if OS.get_environment("SPOTS") != "":   # helper: print open ground spots across the village
		for r in [30.0, 45.0, 60.0, 75.0, 90.0, 105.0]:
			for k in 12:
				var a := TAU * k / 12.0
				var p := _ground(space, ground + Vector3(cos(a), 0, sin(a)) * r)
				if absf(p.y - ground.y) < 1.5:
					var clear := 0
					for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
						if space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP, p + Vector3.UP + d * 6.0)).is_empty():
							clear += 1
					if clear == 4:
						print("[spot] %.0f %.0f %.1f r=%d" % [p.x, p.z, p.y, int(r)])
	# where would the quests' objectives land? (positions come from the old map)
	Quests.ensure_loaded()
	for id in Quests.DEFS:
		for st in Quests.DEFS[id]["steps"]:
			if str(st["type"]) in ["goto", "kill", "hunt", "collect", "survive"]:
				var g := _ground(space, st["pos"])
				print("[merge] quest %s %s at %s: ground y=%.1f %s" % [id, st["type"], st["pos"], g.y,
					"(roof / high?)" if absf(g.y - ground.y) > 3.0 else ""])
	var ps := PackedScene.new()
	ps.pack(map)
	ResourceSaver.save(ps, MAP)
	print("[merge] wrote ", MAP)

## Highest surface under (x, z), or (x, 0, z).
func _ground(space: PhysicsDirectSpaceState3D, p: Vector3) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 400, p.z), Vector3(p.x, -400, p.z)))
	return hit["position"] if not hit.is_empty() else Vector3(p.x, 0, p.z)

## `n` spots around `center` on open ground at the same level (not roofs), with 2 m of free
## space around them and at least 7 m apart.
func _open_spots(space: PhysicsDirectSpaceState3D, center: Vector3, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for ring in [8.0, 13.0, 18.0, 24.0, 30.0, 38.0, 46.0]:
		for k in 16:
			if out.size() >= n:
				return out
			var a: float = TAU * k / 16.0 + ring * 0.37
			var p := _ground(space, center + Vector3(cos(a), 0, sin(a)) * ring)
			if absf(p.y - center.y) > 1.2:
				continue
			var clear := true
			for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
				var from := p + Vector3.UP
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + d * 2.0)).is_empty():
					clear = false
			if clear and out.all(func(q): return q.distance_to(p) > 7.0):
				out.append(p)
	return out

## Invisible walls around the opaque geometry so nobody walks off the edge of the world.
func _add_bounds(map: Node3D, manifest: Array) -> void:
	var box := AABB()
	var first := true
	for e in manifest:
		if str(e["kind"]) == "opaque":
			var b := (load(str(e["mesh"])) as Mesh).get_aabb()
			box = b if first else box.merge(b)
			first = false
	var bounds := Node3D.new()
	bounds.name = "Bounds"
	map.add_child(bounds)
	bounds.owner = map
	var c := box.get_center()
	var hx := box.size.x / 2.0 - 4.0
	var hz := box.size.z / 2.0 - 4.0
	for w in [[Vector3(c.x + hx, 0, c.z), Vector3(1, 200, hz * 2)], [Vector3(c.x - hx, 0, c.z), Vector3(1, 200, hz * 2)],
			[Vector3(c.x, 0, c.z + hz), Vector3(hx * 2, 200, 1)], [Vector3(c.x, 0, c.z - hz), Vector3(hx * 2, 200, 1)]]:
		var body := StaticBody3D.new()
		body.name = "Wall"
		body.position = w[0]
		bounds.add_child(body)
		body.owner = map
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = w[1]
		cs.shape = sh
		body.add_child(cs)
		cs.owner = map
	print("[merge] bounds: x %.0f..%.0f, z %.0f..%.0f" % [c.x - hx, c.x + hx, c.z - hz, c.z + hz])

func _own(n: Node, owner_node: Node) -> void:
	n.owner = owner_node
	for c in n.get_children():
		if c.scene_file_path == "":
			_own(c, owner_node)
		else:
			c.owner = owner_node
