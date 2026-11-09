class_name Hero
extends RefCounted
## The main character. Loads the customizable Mixamo rig, fits it to the player's size,
## applies the saved look (hair / shirt / pants meshes + hair colour) and maps animations.
##
## CUSTOMIZATION: every part is a real skinned mesh inside the GLB, found by its mesh name:
##   hair1, hair2 ... | shirt1, shirt2 ... | pants1, pants2 ...
## Add "hair3" (or shirt3, pants3 ...) to the GLB and it shows up in the Character Creator
## automatically - no code change needed.

const ASSET_DIR := "res://assets/character"
const CUSTOM_MODEL_FILE := "character_main.glb"
const TARGET_HEIGHT := 1.75
const CREDIT := "Character model: supplied custom Mixamo rig"
const MANUAL_SCALE := 0.0        # set >0 to override auto-scale
const FALLBACK_SCALE := 0.34     # only used if the model can't be measured (this GLB is ~5.1 m tall natively)
const YAW_OFFSET := PI           # glTF models face +Z; set to 0.0 if yours faces away from movement

## One entry per customizable category. "key" is the field in GameData.character_appearance,
## "pattern" matches the mesh name (the number becomes the option id: hair1, shirt2, ...).
const CATEGORIES := {
	"hair": {"key": "hair_style", "label": "HAIRSTYLE", "pattern": "^hair(\\d+)$"},
	"shirt": {"key": "shirt_style", "label": "SHIRT", "pattern": "^shirts?(\\d+)$"},
	"pants": {"key": "pants_style", "label": "PANTS", "pattern": "^pants(\\d+)$"},
}
const DEFAULT_APPEARANCE := {
	"hair_style": "hair1",
	"hair_color": "#E6B52E",
	"shirt_style": "shirt1",
	"pants_style": "pants1",
	"headband_color": "#2B3A67",
	"headbandmetal_color": "#FFFFFF",   # white = show the texture untinted
	"headbandmetal_texture": "",        # "" = the texture embedded in the GLB
}
## Extra colour targets on hair meshes. A hairstyle gets one only if it has a surface whose
## MATERIAL NAME matches ("headband", "headbandmetal"), so hairs without a headband show
## nothing extra. To add another (e.g. a scarf) add an entry here + a default above.
const COLOR_SLOTS := {
	"headband": {"key": "headband_color", "label": "Headband", "material": "headband"},
	## "textures_dir": every png/jpg/webp in that folder becomes a selectable texture for the slot
	## (stored under "texture_key"). Drop a new image in the folder and it shows up in the creator.
	"headbandmetal": {"key": "headbandmetal_color", "label": "Headband plate", "material": "headbandmetal",
		"texture_key": "headbandmetal_texture", "textures_dir": "res://assets/character/headband_textures"},
}
## Older saves / older code used other ids. They are mapped onto the mesh names.
const LEGACY_IDS := {
	"short": "hair1", "spiky": "hair2",
	"shirta": "shirt1", "shirtb": "shirt2", "shirts1": "shirt1", "shirts2": "shirt2",
	"pantsa": "pants1", "pantsb": "pants2",
}
## Original node names from the GLB (Godot turns "." into "_"). Only used if a mesh
## lost its name on import, so the creator still works.
const LEGACY_NODE_PARTS := {
	"sk_chr_man_shortspikyhair_05mo": ["hair", 1],
	"sk_chr_man_spikyhair_08mo": ["hair", 2],
	"mesh_0147_rip_053": ["shirt", 1],
	"male_lobby_top_cos_nb_yellow": ["shirt", 2],
	"mesh_0147_rip_110": ["pants", 1],
	"male_lobby_bottom_cos_nb_yellow": ["pants", 2],
}
## Meshes that are not options but must follow the hair colour (scalp + eyebrows).
const EXTRA_NAMES := {
	"backhead": ["backhead", "sk_chr_face_bald"],
	"face": ["face", "sk_chr_face_mo"],
}

# Animation-name keywords (lowercase). Edit these if your animations are named differently.
const KEYWORDS := {
	"idle": ["stand", "idle", "wait", "breath"],
	"run": ["run", "sprint", "jog"],
	"walk": ["walk"],
	"jump": ["jumpup", "jump"],
	"fall": ["jumpdown", "fall"],
	"strafe_l": ["strafeleft", "strafe_left"],
	"strafe_r": ["straferight", "strafe_right"],
	"attack": ["punch", "attack", "kick", "slash", "combo", "fight", "melee"],
	"throw": ["throw", "kunai", "shoot"],
	"jutsu": ["jutsu", "seal", "cast", "special", "skill", "rasen", "charge"],
	"dash": ["dash", "dodge", "roll", "evade"],
	"hurt": ["hurt", "damage", "react", "flinch"],
	"die": ["die", "death", "dead", "defeat", "knock"],
}
const FALLBACKS := {
	"walk": ["run"], "run": ["walk"], "dash": ["run"],
	"throw": ["attack"], "jutsu": ["throw", "attack"], "jump": ["idle"], "fall": ["jump"],
	"strafe_l": ["run"], "strafe_r": ["run"],
}

static var _scene: PackedScene = null
static var _searched := false
static var _warned_missing := false
static var _printed := false
static var _warned_no_anims := false
static var credit := ""

## Returns a Node3D wrapper (forward = -Z, feet at y=0) or null if no model found.
static func create(appearance: Dictionary = {}) -> Node3D:
	if not _searched or _scene == null:
		_searched = true
		var custom_path := _resolve_custom_model_path()
		if custom_path != "":
			_scene = load(custom_path) as PackedScene
			if _scene != null:
				print("[Hero] loaded main character: ", custom_path)
				credit = CREDIT
			else:
				push_error("[Hero] Could not load the character scene at %s." % custom_path)
		else:
			_scene = null
			if not _warned_missing:
				push_warning("[Hero] Main character GLB not found. Put it at res://assets/character/character_main.glb. Using the placeholder ninja.")
				_warned_missing = true
	if _scene == null:
		return null
	var inst := _scene.instantiate() as Node3D
	if inst == null:
		return null
	var wrapper := Node3D.new()
	var fixer := Node3D.new()
	fixer.rotation.y = YAW_OFFSET
	wrapper.add_child(fixer)
	fixer.add_child(inst)
	_fit(fixer, inst)
	Fx.toonify_model(inst)
	_setup_anims(wrapper, inst)
	wrapper.set_meta("hero_parts", _discover_parts(inst))
	wrapper.set_meta("hero_extra", _find_extras(inst))
	apply_appearance(wrapper, appearance)
	return wrapper


static func _resolve_custom_model_path() -> String:
	var candidates := [
		ASSET_DIR.path_join(CUSTOM_MODEL_FILE),
		ASSET_DIR.path_join("character.glb"),
		ASSET_DIR.path_join("character_costum_test1.glb"),
		ASSET_DIR.path_join("character costum test1.glb"),
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	# Accept a differently named GLB placed by the user in the character folder.
	return _scan(ASSET_DIR, 1)


# =============================================================== customization

## Turns anything (old saves, network data) into a safe, complete appearance dictionary.
## Ids are only checked for shape here; apply_appearance falls back if the model lacks one.
static func sanitize_appearance(raw: Dictionary) -> Dictionary:
	var safe: Dictionary = DEFAULT_APPEARANCE.duplicate()
	for cat in CATEGORIES:
		var key: String = CATEGORIES[cat]["key"]
		if not raw.has(key):
			continue
		var id := normalize_id(raw[key])
		var number := id.substr(String(cat).length())
		if id.begins_with(String(cat)) and number.is_valid_int() and number.length() <= 2:
			safe[key] = id
	var color_keys: Array = ["hair_color"]
	for slot in COLOR_SLOTS:
		color_keys.append(COLOR_SLOTS[slot]["key"])
	for color_key in color_keys:
		var hex := str(raw.get(color_key, "")).strip_edges()
		if Color.html_is_valid(hex):
			safe[color_key] = "#" + Color.html(hex).to_html(false)
	for slot in COLOR_SLOTS:
		var tkey := str(COLOR_SLOTS[slot].get("texture_key", ""))
		if tkey != "":
			var tname := str(raw.get(tkey, "")).strip_edges()
			if tname == "" or (tname.get_file() == tname and tname.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]):
				safe[tkey] = tname
	return safe


## "Shirt_1", "shirt1", "shirts1", "spiky" ... -> canonical mesh id ("shirt1", "hair2").
static func normalize_id(raw: Variant) -> String:
	var s := str(raw).strip_edges().to_lower().replace("_", "").replace("-", "").replace(" ", "")
	return str(LEGACY_IDS.get(s, s))


## "hair1" -> "Hair 1" (label for the creator buttons).
static func display_name(id: String) -> String:
	var i := id.length()
	while i > 0 and id[i - 1].is_valid_int():
		i -= 1
	if i == 0 or i == id.length():
		return id.capitalize()
	return "%s %s" % [id.substr(0, i).capitalize(), id.substr(i)]


## Options found on a model created by Hero.create: {"hair": ["hair1", "hair2"], "shirt": [...], ...}
## Random outfit for NPCs (bandits / shinobi): picks random hairstyle, shirt and pants from the
## meshes the model really has, a random hair colour, random colours for colour-only slots
## (headband) and a random texture for texture slots. Applies it and returns the look.
static func randomize_look(model: Node3D, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var look: Dictionary = DEFAULT_APPEARANCE.duplicate()
	var options := get_options(model)
	for cat in CATEGORIES:
		var ids: Array = options.get(cat, [])
		if not ids.is_empty():
			look[CATEGORIES[cat]["key"]] = str(ids[rng.randi() % ids.size()])
	look["hair_color"] = "#" + Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.8), rng.randf_range(0.15, 1.0)).to_html(false)
	for slot in COLOR_SLOTS:
		var info: Dictionary = COLOR_SLOTS[slot]
		var tkey := str(info.get("texture_key", ""))
		if tkey == "":
			look[info["key"]] = "#" + Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.9)).to_html(false)
		else:
			var choices: Array = [""] + list_slot_textures(slot)
			look[tkey] = str(choices[rng.randi() % choices.size()])
	apply_appearance(model, look)
	return look


static func get_options(model: Node3D) -> Dictionary:
	var out := {}
	if model == null or not model.has_meta("hero_parts"):
		return out
	var parts: Dictionary = model.get_meta("hero_parts")
	for cat in parts:
		var ids: Array = []
		for entry in parts[cat]:
			ids.append(entry["id"])
		out[cat] = ids
	return out


## Shows the chosen hair / shirt / pants and colours the hair. Cheap - the creator calls it live.
static func apply_appearance(model: Node3D, appearance: Dictionary = {}) -> void:
	if model == null or not model.has_meta("hero_parts"):
		return
	var look := sanitize_appearance(appearance if not appearance.is_empty() else GameData.character_appearance)
	var parts: Dictionary = model.get_meta("hero_parts")
	for cat in CATEGORIES:
		var entries: Array = parts.get(cat, [])
		if entries.is_empty():
			continue
		var want := str(look[CATEGORIES[cat]["key"]])
		var available := false
		for entry in entries:
			if entry["id"] == want:
				available = true
		if not available:
			want = str(entries[0]["id"])
		for entry in entries:
			(entry["node"] as MeshInstance3D).visible = entry["id"] == want
	_apply_hair_color(model, Color.html(str(look["hair_color"])), look)


## Which COLOR_SLOTS slot a material belongs to ("" = plain hair). Ignores Blender's ".001" suffixes.
static func _slot_of(material: Material) -> String:
	if material == null:
		return ""
	var name := material.resource_name.to_lower().replace(".", "_")
	var cut := name.rfind("_")
	if cut > 0 and name.substr(cut + 1).is_valid_int():
		name = name.substr(0, cut)
	for slot in COLOR_SLOTS:
		if name == COLOR_SLOTS[slot]["material"]:
			return str(slot)
	return ""


## Image file names available for a slot (see COLOR_SLOTS "textures_dir"), sorted.
static func list_slot_textures(slot: String) -> Array:
	var found: Array = []
	var dir_path := str(COLOR_SLOTS[slot].get("textures_dir", ""))
	if dir_path == "" or not DirAccess.dir_exists_absolute(dir_path):
		return found
	for f in DirAccess.get_files_at(dir_path):
		var fname := str(f).trim_suffix(".import").trim_suffix(".remap")
		if fname.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] and not found.has(fname):
			found.append(fname)
	found.sort()
	return found


static func slot_for_key(color_key: String) -> String:
	for slot in COLOR_SLOTS:
		if COLOR_SLOTS[slot]["key"] == color_key:
			return str(slot)
	return ""


static func _slot_texture(slot: String, file_name: String) -> Texture2D:
	if file_name == "":
		return null
	var path := str(COLOR_SLOTS[slot]["textures_dir"]).path_join(file_name)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Slots (headband ...) that the given hairstyle id actually contains. Used by the creator.
static func get_color_slots(model: Node3D, hair_id: String) -> Array:
	var found: Array = []
	if model == null or not model.has_meta("hero_parts"):
		return found
	for entry in (model.get_meta("hero_parts") as Dictionary).get("hair", []):
		if entry["id"] != hair_id:
			continue
		var hair := entry["node"] as MeshInstance3D
		for surface in hair.mesh.get_surface_count():
			var slot := _slot_of(hair.mesh.surface_get_material(surface))
			if slot != "" and not found.has(slot):
				found.append(slot)
	return found


static func _names_of(mi: MeshInstance3D) -> Array:
	var names: Array = []
	if mi.mesh != null and mi.mesh.resource_name != "":
		names.append(mi.mesh.resource_name.to_lower().replace(".", "_"))
	names.append(String(mi.name).to_lower().replace(".", "_"))
	return names


## Scans the model once and remembers which MeshInstance3D is which option.
static func _discover_parts(inst: Node) -> Dictionary:
	var regexes := {}
	var found := {}
	for cat in CATEGORIES:
		regexes[cat] = RegEx.create_from_string(CATEGORIES[cat]["pattern"])
		found[cat] = []
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var hit := _classify(mi, regexes)
		if hit.is_empty():
			continue
		var cat := str(hit[0])
		var number := int(hit[1])
		found[cat].append({"id": "%s%d" % [cat, number], "num": number, "node": mi})
	for cat in found:
		(found[cat] as Array).sort_custom(func(a, b): return int(a["num"]) < int(b["num"]))
		if found[cat].is_empty():
			push_warning("[Hero] No '%s' meshes found in the model (expected names like %s1)." % [cat, cat])
	return found


static func _classify(mi: MeshInstance3D, regexes: Dictionary) -> Array:
	for nm in _names_of(mi):
		for cat in CATEGORIES:
			var m: RegExMatch = (regexes[cat] as RegEx).search(str(nm))
			if m != null:
				return [cat, int(m.get_string(1))]
		if LEGACY_NODE_PARTS.has(nm):
			return LEGACY_NODE_PARTS[nm]
	return []


static func _find_extras(inst: Node) -> Dictionary:
	var extras := {}
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var names := _names_of(mi)
		for extra in EXTRA_NAMES:
			for wanted in EXTRA_NAMES[extra]:
				if names.has(wanted):
					extras[extra] = mi
	return extras


static func _apply_hair_color(model: Node3D, color: Color, look: Dictionary) -> void:
	var parts: Dictionary = model.get_meta("hero_parts")
	var extras: Dictionary = model.get_meta("hero_extra", {})
	# Every hairstyle (also the hidden ones, so switching style keeps the colour).
	for entry in parts.get("hair", []):
		var hair := entry["node"] as MeshInstance3D
		for surface in hair.mesh.get_surface_count():
			var slot := _slot_of(hair.mesh.surface_get_material(surface))
			if slot == "":
				_tint_surface(hair, surface, color)
			else:
				var tex_name := str(look.get(str(COLOR_SLOTS[slot].get("texture_key", "")), ""))
				_tint_surface(hair, surface, Color.html(str(look[COLOR_SLOTS[slot]["key"]])), true, _slot_texture(slot, tex_name))
	# The scalp mesh uses the same material as the hair.
	if extras.has("backhead"):
		var back := extras["backhead"] as MeshInstance3D
		for surface in back.mesh.get_surface_count():
			_tint_surface(back, surface, color)
	# Eyebrows are one surface of the face mesh, found by material name.
	if extras.has("face"):
		var face := extras["face"] as MeshInstance3D
		for surface in face.mesh.get_surface_count():
			var source := face.mesh.surface_get_material(surface)
			if source != null and source.resource_name.to_lower().contains("eyebrow"):
				_tint_surface(face, surface, color)


## Each Hero gets its own copy of the (cached, shared) toon material, so one player's
## hair colour never leaks onto another player, a clone or a preview.
## matte = true forces metallic 0: glTF materials without a metallic value default to fully
## metal, which renders pitch black (there is no environment to reflect).
static func _tint_surface(mi: MeshInstance3D, surface: int, color: Color, matte := false, texture: Texture2D = null) -> void:
	var meta_key := "hero_base_%d" % surface
	var base: Material
	if mi.has_meta(meta_key):
		base = mi.get_meta(meta_key) as Material
	else:
		base = mi.get_active_material(surface)
		mi.set_meta(meta_key, base)
	if base is BaseMaterial3D:
		var tinted := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
		tinted.albedo_color = color
		if matte:
			tinted.metallic = 0.0
		if texture != null:
			tinted.albedo_texture = texture
		mi.set_surface_override_material(surface, tinted)


# ============================================================== asset lookup

## Shared asset scanner used by Hero and the Kurama boss model loader.
## Keep this public static helper: Kurama.gd calls Hero._scan(ASSET_DIR, 1).
static func _scan(dir_path: String, depth: int) -> String:
	var directory := DirAccess.open(dir_path)
	if directory == null:
		return ""
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		var clean_name := file_name.trim_suffix(".import").trim_suffix(".remap")
		var extension := clean_name.get_extension().to_lower()
		if extension == "glb" or extension == "gltf":
			var full_path := dir_path.path_join(clean_name)
			if ResourceLoader.exists(full_path):
				return full_path
	if depth > 0:
		var subdirectories := directory.get_directories()
		subdirectories.sort()
		for subdirectory in subdirectories:
			var found := _scan(dir_path.path_join(subdirectory), depth - 1)
			if found != "":
				return found
	return ""


static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


# ======================================================================== fitting

## Scales the model to TARGET_HEIGHT and puts its feet on y=0. The height comes from the
## skeleton (head-top bone to toe bones), NOT from mesh bounding boxes: the hair/face
## meshes sit on bone attachments and skinned AABBs are unreliable, which is why the old
## fit gave up on this ~5 m tall rig and left it giant.
static func _fit(fixer: Node3D, inst: Node3D) -> void:
	var m := _measure_skeleton(fixer, inst)
	if m.is_empty():
		_fit_by_bounds(fixer, inst)
		return
	var height: float = m["height"]
	var s := MANUAL_SCALE if MANUAL_SCALE > 0.0 else TARGET_HEIGHT / height
	var center: Vector3 = m["center"]
	var sole: float = m["sole"]
	print("[Hero] native height %.2f m -> scale %.3f (%.2f m)" % [height, s, height * s])
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-center.x * s, -sole * s, -center.z * s)


static func _measure_skeleton(fixer: Node3D, inst: Node) -> Dictionary:
	var skeletons := inst.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return {}
	var sk := skeletons[0] as Skeleton3D
	var xf := _rel(sk, fixer)
	var top := -INF
	var sole := INF
	var lowest := INF
	var highest := -INF
	var center := Vector3.ZERO
	for i in sk.get_bone_count():
		var key := sk.get_bone_name(i).to_lower()
		var p: Vector3 = xf * sk.get_bone_global_rest(i).origin
		lowest = minf(lowest, p.y)
		highest = maxf(highest, p.y)
		if key.ends_with("headtop_end"):
			top = p.y
		elif key.contains("toe"):
			sole = minf(sole, p.y)
		elif key.ends_with("hips"):
			center = p
	if top == -INF:
		top = highest
	if sole == INF:
		sole = lowest
	if top - sole < 0.01:
		return {}
	return {"height": top - sole, "sole": sole, "center": center}


## Fallback for models without a skeleton.
static func _fit_by_bounds(fixer: Node3D, inst: Node3D) -> void:
	var box := AABB()
	var first := true
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := _rel(mi, fixer) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y < 0.001:
		inst.scale = Vector3.ONE * FALLBACK_SCALE
		return
	var s := MANUAL_SCALE if MANUAL_SCALE > 0.0 else TARGET_HEIGHT / box.size.y
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(
		-(box.position.x + box.size.x / 2.0) * s,
		-box.position.y * s,
		-(box.position.z + box.size.z / 2.0) * s)


# ===================================================================== animations

static func _setup_anims(wrapper: Node3D, inst: Node3D) -> void:
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		if not _warned_no_anims:
			_warned_no_anims = true
			print("[Hero] the character GLB has no animations, so it stays in its T-pose until idle/run/attack clips are added.")
		return
	var ap := aps[0] as AnimationPlayer
	var list := ap.get_animation_list()
	if not _printed:
		print("[Hero] animations found: ", list)
	var map := {}
	for state in KEYWORDS:
		var found: Array = []
		for kw in KEYWORDS[state]:
			for nm in list:
				var low := String(nm).to_lower()
				if low == "reset":
					continue
				if low.contains(kw) and not found.has(String(nm)):
					found.append(String(nm))
		if not found.is_empty():
			map[state] = found
	if map.is_empty() and list.size() > 0:
		map["idle"] = [String(list[0])]
		print("[Hero] no names matched KEYWORDS; using first animation as idle. Edit KEYWORDS in hero.gd")
	for st in ["idle", "run", "walk", "fall", "strafe_l", "strafe_r"]:
		if map.has(st):
			for nm in map[st]:
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	if not _printed:
		print("[Hero] animation map: ", map)
		_printed = true
	wrapper.set_meta("anim_player", ap)
	wrapper.set_meta("anim_map", map)

## Ground speed (m/s) -> locomotion state. Normal movement (WALK_SPEED 7) plays the walk
## clip, sprinting (SPRINT_SPEED 12.5) plays the run clip. Raise/lower WALK_BELOW to taste.
const WALK_BELOW := 9.5
static func move_state(speed: float) -> String:
	if speed <= 1.0:
		return "idle"
	return "walk" if speed < WALK_BELOW else "run"


static func _lookup(map: Dictionary, state: String) -> Array:
	if map.has(state):
		return map[state]
	for fb in FALLBACKS.get(state, []):
		if map.has(fb):
			return map[fb]
	return []

## Plays an animation state; returns its length (0.0 if the model has none).
static func play(model: Node3D, state: String, force := false, variant := 0, fit_time := 0.0) -> float:
	if model == null or not model.has_meta("anim_player"):
		return 0.0
	var ap := model.get_meta("anim_player") as AnimationPlayer
	if not is_instance_valid(ap):
		return 0.0
	var names: Array = _lookup(model.get_meta("anim_map"), state)
	if names.is_empty():
		return 0.0
	var nm: String = names[variant % names.size()]
	if not force and ap.current_animation == nm and ap.is_playing():
		return ap.get_animation(nm).length
	ap.play(nm, 0.15)
	var l := ap.get_animation(nm).length
	ap.speed_scale = 1.0
	if fit_time > 0.0 and l > fit_time:
		ap.speed_scale = minf(l / fit_time, 3.0)
	if force:
		ap.seek(0.0, true)
	return l
