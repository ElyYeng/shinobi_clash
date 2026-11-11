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
	"shirt_color": "#FFFFFF",           # tint for every shirt / pants mesh; white = original colours
	"pants_color": "#FFFFFF",
}
## Clothing tints: category -> appearance key. The colour multiplies the mesh's own colours.
const CLOTH_COLORS := {"shirt": "shirt_color", "pants": "pants_color"}
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
static var _stride_speed := {}   # animation name -> metres/second its feet move (model space, measured once)

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
	# New rigid hair meshes are not necessarily skinned/parented to the head in the GLB.
	# Attach those meshes to the Head bone so every Hero.create() consumer gets the fix.
	attach_rigid_hair_to_head(inst)
	Fx.toonify_model(inst)
	_setup_anims(wrapper, inst)
	wrapper.set_meta("hero_parts", _discover_parts(inst))
	wrapper.set_meta("hero_extra", _find_extras(inst))
	wrapper.set_meta("hero_outfits", _find_outfits(inst))
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
	var color_keys: Array = ["hair_color", "shirt_color", "pants_color"]
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
## (headband) and a random texture for texture slots.
## Outfits friendly villagers / Konoha NPCs never roll (shirt3 = Akatsuki cloak). Enemies still can.
const VILLAGER_EXCLUDE := ["shirt3"]

static func randomize_look(model: Node3D, rng: RandomNumberGenerator = null, exclude: Array = []) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var look: Dictionary = DEFAULT_APPEARANCE.duplicate()
	var options := get_options(model)
	for cat in CATEGORIES:
		var ids: Array = (options.get(cat, []) as Array).filter(func(id) -> bool: return not exclude.has(str(id)))
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
	for oid in model.get_meta("hero_outfits", {}):   # power-up outfits only show during the power-up
		for cat in model.get_meta("hero_outfits")[oid]:
			(model.get_meta("hero_outfits")[oid][cat] as MeshInstance3D).visible = false
	_apply_hair_color(model, Color.html(str(look["hair_color"])), look)
	for cat in CLOTH_COLORS:
		var tint := Color.html(str(look[CLOTH_COLORS[cat]]))
		for entry in parts.get(cat, []):
			var mi := entry["node"] as MeshInstance3D
			for surface in mi.mesh.get_surface_count():
				_tint_surface(mi, surface, tint, false, null, true)


## Power-up look (Bloodline mode "look"). An empty look puts the normal appearance back.
##   glow/under/energy/flat - hair and top turn `glow` and glow, pants turn `under` (Uzumaki)
##   eyes                   - iris texture for both eyes (Uchiha's Sharingan)
##   outfit_glow            - neon: the outfit glows in its own texture colours (0 = off)
##   outfit                 - "uzumaki" shows the shirt_uzumaki / pants_uzumaki meshes instead of
##                            your clothes (those keep their own textures; the glow then only
##                            goes on what the outfit doesn't replace, e.g. the hair)
## e.g. {"glow": "#E3D79A", "under": "#2B261A", "energy": 0.25, "flat": true}
## flat = drop the clothes' own textures so the top is one glowing colour (outline keeps the shape).
static func apply_mode_look(model: Node3D, look: Dictionary, appearance: Dictionary = {}) -> void:
	if model == null or not model.has_meta("hero_parts"):
		return
	apply_appearance(model, appearance)
	set_eyes(model, Moves.tex(str(look["eyes"])) if look.has("eyes") else null)
	var outfit: Dictionary = (model.get_meta("hero_outfits", {}) as Dictionary).get(str(look.get("outfit", "")), {})
	var outfit_glow := float(look.get("outfit_glow", 0.0))
	for cat in outfit:   # swap in the power-up outfit (it has its own textures and colours)
		for entry in (model.get_meta("hero_parts") as Dictionary).get(cat, []):
			(entry["node"] as MeshInstance3D).visible = false
		var om := outfit[cat] as MeshInstance3D
		om.visible = true
		for surface in om.mesh.get_surface_count():   # neon: the outfit lights up in its own colours
			var src := om.mesh.surface_get_material(surface) as BaseMaterial3D
			if src == null:
				continue
			if outfit_glow <= 0.0:
				om.set_surface_override_material(surface, null)
				continue
			# Like the hair: the glow colour over the outfit's own texture (details kept). The glow
			# comes from the texture too, so its black lines don't emit and stay crisp "neon black".
			var tint := Color.html(str(look.get("glow", "#FFFFFF")))
			var neon := _neon_texture(src.albedo_texture)
			# Emission mask: "<texture>_Glow.png" next to the outfit texture (white = glows,
			# black = doesn't, e.g. the black lines). Without one, the texture itself is the mask.
			var mask: Texture2D = null
			if src.albedo_texture != null and src.albedo_texture.resource_path != "":
				mask = Moves.tex(src.albedo_texture.resource_path.get_basename() + "_Glow.png")
			var nm := src.duplicate() as BaseMaterial3D
			nm.albedo_color = src.albedo_color * tint
			nm.albedo_texture = neon
			# The *_SP textures keep a mask in alpha (0.12 on the lines) - not transparency. As
			# transparency the lines turned see-through and showed the layer behind them.
			nm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			nm.metallic = 0.0          # glTF defaults to metal: black lines would mirror the sky
			nm.roughness = 1.0
			nm.metallic_specular = 0.0
			nm.emission_enabled = true
			nm.emission = tint
			nm.emission_texture = mask if mask != null else neon
			nm.emission_energy_multiplier = outfit_glow
			om.set_surface_override_material(surface, nm)
	if not look.has("glow"):
		return
	var glow := Color.html(str(look.get("glow", "#E3D79A")))
	var under := Color.html(str(look.get("under", "#2B261A")))
	var energy := float(look.get("energy", 0.5))
	var flat := bool(look.get("flat", true))
	var parts: Dictionary = model.get_meta("hero_parts")
	var extras: Dictionary = model.get_meta("hero_extra", {})
	var glowing: Array = []
	for cat in ["hair", "shirt"]:
		if outfit.has(cat):
			continue   # the outfit keeps its own colours; only the rest glows
		for entry in parts.get(cat, []):
			glowing.append(entry["node"])
	if extras.has("backhead"):
		glowing.append(extras["backhead"])
	var brows: Array = []   # [mesh, surface]: the eyebrows are one surface of the face mesh
	if extras.has("face"):
		var face := extras["face"] as MeshInstance3D
		for surface in face.mesh.get_surface_count():
			var src := face.mesh.surface_get_material(surface)
			if src != null and src.resource_name.to_lower().contains("eyebrow"):
				brows.append([face, surface])
	for b in brows:
		_tint_surface(b[0], b[1], glow, true)
		var bm := (b[0] as MeshInstance3D).get_surface_override_material(b[1]) as BaseMaterial3D
		if bm != null:
			bm.emission_enabled = true
			bm.emission = glow
			bm.emission_energy_multiplier = energy
	for mi in glowing:
		for surface in (mi as MeshInstance3D).mesh.get_surface_count():
			if cat_skip_surface(mi, surface):
				continue
			_tint_surface(mi, surface, glow, true)
			var m := (mi as MeshInstance3D).get_surface_override_material(surface) as BaseMaterial3D
			if m != null:
				if flat:
					m.albedo_texture = null
				m.emission_enabled = true
				m.emission = glow
				m.emission_energy_multiplier = energy
	for entry in ([] if outfit.has("pants") else parts.get("pants", [])):
		var pm := entry["node"] as MeshInstance3D
		for surface in pm.mesh.get_surface_count():
			_tint_surface(pm, surface, under, true)
			var pmat := pm.get_surface_override_material(surface) as BaseMaterial3D
			if flat and pmat != null:
				pmat.albedo_texture = null

const EYE_GLOW := 0.9   # how bright transformed irises glow (needs <eye>_Glow.png next to the eye texture)

static var _neon_cache := {}

## Copy of an outfit texture with its dark lines pushed to black (they'd otherwise look brown once
## tinted, lit and surrounded by glow), bright parts unchanged. Cached per texture.
static func _neon_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var key := tex.get_rid().get_id()
	if _neon_cache.has(key):
		return _neon_cache[key]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			if l < NEON_DARK:
				var k := 0.12 * l / NEON_DARK
				img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_neon_cache[key] = out
	return out

const NEON_DARK := 0.42  # outfit pixels darker than this become (near) black in the neon form

## Swaps the iris texture on both eyes (null = the model's own eyes). The eyes are the face
## surfaces whose material is called "... Eye" or uses an "Eye" texture (not the eyebrows).
static func set_eyes(model: Node3D, tex: Texture2D) -> void:
	if model == null or not model.has_meta("hero_extra"):
		return
	var face = (model.get_meta("hero_extra") as Dictionary).get("face")
	if face == null or not is_instance_valid(face):
		return
	var mi := face as MeshInstance3D
	for surface in mi.mesh.get_surface_count():
		var base := mi.mesh.surface_get_material(surface)
		if base == null:
			continue
		var nm := base.resource_name.to_lower()
		var tex_path := ""
		if base is BaseMaterial3D and (base as BaseMaterial3D).albedo_texture != null:
			tex_path = (base as BaseMaterial3D).albedo_texture.resource_path.to_lower()
		if nm.contains("brow") or not (nm.ends_with("eye") or tex_path.contains("eye_bc")):
			continue
		if tex == null:
			mi.set_surface_override_material(surface, null)
		elif base is BaseMaterial3D:
			var m := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
			m.albedo_texture = tex
			# Unshaded: toon lighting over-brightens the eye and washes the iris colours out.
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			# Neon iris: "<eye>_Glow.png" (black outside the iris) lights up only the iris.
			var glow := Moves.tex(tex.resource_path.get_basename() + "_Glow.png") if tex.resource_path != "" else null
			if glow != null:
				m.emission_enabled = true
				m.emission = Color.WHITE
				m.emission_texture = glow
				m.emission_energy_multiplier = EYE_GLOW
			mi.set_surface_override_material(surface, m)

## World position of the eyes (for close-ups): 30% of the way from the head bone to the head top.
static func eyes_position(model: Node3D) -> Vector3:
	var head := head_position(model)
	for sk in model.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		for i in s.get_bone_count():
			var bn := s.get_bone_name(i).to_lower()
			if bn.ends_with("headtop_end") or bn.ends_with("head_end") or bn.ends_with("headtop"):
				return head.lerp(s.global_transform * s.get_bone_global_pose(i).origin, 0.3)
	return head + Vector3.UP * 0.15

## World position of the head bone (for close-ups); falls back to 1.6 m above the model.
static func head_position(model: Node3D) -> Vector3:
	for sk in model.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		for i in s.get_bone_count():
			var bn := s.get_bone_name(i).to_lower()
			if bn.ends_with("head") and not bn.contains("top") and not bn.contains("ctrl"):
				return s.global_transform * s.get_bone_global_pose(i).origin
	return model.global_position + Vector3.UP * 1.6

## Keeps the headband plate (its own texture) and similar slot surfaces out of the glow.
static func cat_skip_surface(mi: MeshInstance3D, surface: int) -> bool:
	return _slot_of(mi.mesh.surface_get_material(surface)) == "headbandmetal"


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


## Fixes only truly standalone rigid hair meshes that are neither skinned nor assigned a
## Skeleton3D path and are not already parented to a BoneAttachment3D. Their original imported
## transform is preserved, then they are made a child of a Head BoneAttachment3D. Meshes with
## either Skin OR Skeleton3D path are already rig-driven and are always left in their GLB hierarchy.
## This is shared by players, remote avatars, clones, previews and NPC model loading.
static func attach_rigid_hair_to_head(inst: Node) -> int:
	if inst == null:
		return 0
	var skeleton_nodes := inst.find_children("*", "Skeleton3D", true, false)
	if skeleton_nodes.is_empty():
		return 0
	var sk := skeleton_nodes[0] as Skeleton3D
	if sk == null:
		return 0

	var rigid_hair: Array[MeshInstance3D] = []
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		# IMPORTANT: some imported GLB hairs have no Skin resource but DO have a
		# Skeleton3D path. They are already rig-driven and must never be reparented.
		# The previous check only tested `skin`, which detached those meshes from
		# their rig and made characters appear bald or left hair floating elsewhere.
		if mi == null or mi.mesh == null or mi.skin != null or mi.skeleton != NodePath(""):
			continue
		var is_hair := false
		for raw_name in _names_of(mi):
			var compact_name := str(raw_name).to_lower().replace("_", "").replace(" ", "")
			if compact_name.contains("hair") and not compact_name.contains("headband"):
				is_hair = true
				break
		if is_hair:
			rigid_hair.append(mi)
	if rigid_hair.is_empty():
		return 0

	var head_idx := -1
	for i in sk.get_bone_count():
		var bone_name := str(sk.get_bone_name(i)).to_lower()
		bone_name = bone_name.replace("mixamorig:", "").replace("mixamorig_", "")
		bone_name = bone_name.replace(" ", "").replace("_", "")
		if bone_name == "head":
			head_idx = i
			break
	if head_idx < 0:
		push_warning("[Hero] Found rigid hair meshes, but the model has no Head bone. Hair must be parented/weighted to a head bone in the source model.")
		return 0

	var head_bone_name := sk.get_bone_name(head_idx)
	# Everything is measured in the skeleton's own space (not world space): this runs while
	# the model is being built, before it is in the scene tree, where global transforms
	# don't exist yet. A BoneAttachment3D places its children at the bone's pose in that space.
	var head_pose := sk.get_bone_global_pose(head_idx)
	var sk_from_inst := _rel(sk, inst).affine_inverse()
	var attached_count := 0
	for mi in rigid_hair:
		var ancestor := mi.get_parent()
		var already_bone_attached := false
		while ancestor != null and ancestor != sk:
			# Leave all explicit BoneAttachment3D hierarchies as authored. The
			# mesh may already be positioned on Head (or a custom head bone alias).
			if ancestor is BoneAttachment3D:
				already_bone_attached = true
				break
			ancestor = ancestor.get_parent()
		if already_bone_attached:
			continue

		# Save the mesh's pose (in skeleton space) before moving it under the head attachment.
		var original_in_sk := sk_from_inst * _rel(mi, inst)
		var attachment := BoneAttachment3D.new()
		attachment.name = "AutoHairHead_%d" % mi.get_instance_id()
		attachment.bone_name = head_bone_name
		sk.add_child(attachment)
		mi.reparent(attachment, false)
		mi.transform = head_pose.affine_inverse() * original_in_sk
		# Ragdoll.start() moves this rigid hair mesh under the physics Head body
		# so it follows the falling head instead of remaining at its last bone pose.
		mi.set_meta("ragdoll_follow_head", true)
		attached_count += 1

	if attached_count > 0:
		print("[Hero] Attached %d rigid hair mesh(es) to bone '%s'." % [attached_count, head_bone_name])
	return attached_count


## Scans the model once and remembers which MeshInstance3D is which.
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
		if (found[cat] as Array).is_empty():
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


## Power-up outfits: meshes named <category>_<name> (shirt_uzumaki, pants_uzumaki, hair_...).
## They are hidden normally; a bloodline mode with look "outfit": "<name>" swaps them in.
## Returns {"uzumaki": {"shirt": MeshInstance3D, "pants": MeshInstance3D}}.
static func _find_outfits(inst: Node) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("^(hair|shirts?|pants)_([a-z][a-z0-9]*)$")
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for nm in _names_of(mi):
			var m := re.search(str(nm))
			if m == null:
				continue
			var cat := m.get_string(1).trim_suffix("s") if m.get_string(1) != "pants" else "pants"
			var oid := m.get_string(2)
			if not out.has(oid):
				out[oid] = {}
			out[oid][cat] = mi
			break
	return out

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
## multiply = true keeps the material's own colour and multiplies it (white = unchanged).
static func _tint_surface(mi: MeshInstance3D, surface: int, color: Color, matte := false, texture: Texture2D = null, multiply := false) -> void:
	var meta_key := "hero_base_%d" % surface
	var base: Material
	if mi.has_meta(meta_key):
		base = mi.get_meta(meta_key) as Material
	else:
		base = mi.get_active_material(surface)
		mi.set_meta(meta_key, base)
	if base is BaseMaterial3D:
		var tinted := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
		tinted.albedo_color = (base as BaseMaterial3D).albedo_color * color if multiply else color
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
			print("[Hero] the character GLB has no animations, so it stays in the T-pose until idle/run/attack clips for this skeleton are added.")
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

## Ground speed (m/s) -> locomotion state. Normal movement (Player.WALK_SPEED 2.5) plays the walk
## clip, sprinting (SPRINT_SPEED 11) plays the run clip. Raise/lower WALK_BELOW to taste.
const WALK_BELOW := 4.5
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
## Locomotion speeds the walk/run clips may be sped up or slowed down to (keeps them sane).
const ANIM_SPEED_MIN := 0.6
const ANIM_SPEED_MAX := 4.0
## Per-clip cap (walk looks hurried above this, even if the feet slide a little).
const ANIM_SPEED_CAP := {"walk": 1.7}

## Plays walk/run (or idle) for a model moving at `ground_speed` m/s and sets the playback speed
## so the feet move as fast as the body: no sliding or moonwalking. Use instead of play() for
## locomotion.
static func play_move(model: Node3D, state: String, ground_speed: float) -> void:
	play(model, state)
	if model == null or not model.has_meta("anim_player"):
		return
	var ap := model.get_meta("anim_player") as AnimationPlayer
	if not is_instance_valid(ap) or ap.current_animation == "":
		return
	if not (state in ["walk", "run", "strafe_l", "strafe_r"]) or ap.current_animation == "":
		ap.speed_scale = 1.0
		return
	var natural := stride_speed(model, ap.current_animation)
	if natural <= 0.01:
		return
	var scale := model.global_transform.basis.get_scale().x if model.is_inside_tree() else model.scale.x
	ap.speed_scale = clampf(ground_speed / (natural * maxf(scale, 0.01)), ANIM_SPEED_MIN, float(ANIM_SPEED_CAP.get(state, ANIM_SPEED_MAX)))

## How fast (m/s, in the model's own units) the planted foot slides back in clip `anim` at speed
## 1.0, i.e. the ground speed the clip was animated for. Measured once per clip by sampling the
## foot bones; 0 if the rig has no recognisable feet.
static func stride_speed(model: Node3D, anim: String) -> float:
	if _stride_speed.has(anim):
		return _stride_speed[anim]
	_stride_speed[anim] = 0.0
	var ap := model.get_meta("anim_player") as AnimationPlayer
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty() or not ap.has_animation(anim):
		return 0.0
	var sk := sks[0] as Skeleton3D
	var feet: Array[int] = []
	for side in ["left", "right"]:
		var best := -1
		var best_score := -1
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i).to_lower()
			if not (bn.contains(side) and bn.contains("foot")):
				continue
			var score := 1
			for junk in ["ctrl", "ik", "fk", "pole", "snap", "roll", "heel", "target", "cursor", "end", "index"]:
				if bn.contains(junk):
					score = 0
			if bn.contains("mixamorig") or bn.replace("_", "").contains(side + "foot"):
				score += 1
			if score > best_score:
				best_score = score
				best = i
		if best >= 0:
			feet.append(best)
	if feet.size() < 2:
		return 0.0
	var to_model := _rel(sk, model)
	var prev_anim := ap.current_animation
	var prev_pos := ap.current_animation_position
	var prev_scale := ap.speed_scale
	ap.speed_scale = 1.0
	ap.play(anim, 0.0)
	var length := ap.get_animation(anim).length
	var steps := 48
	var dt := length / steps
	var last: Array = []
	var speeds: Array[float] = []
	for k in steps + 1:
		ap.seek(k * dt, true)
		sk.force_update_all_bone_transforms()
		var pts: Array = []
		for f in feet:
			pts.append(to_model * sk.get_bone_global_pose(f).origin)
		if not last.is_empty():
			var low := 0 if (pts[0] as Vector3).y < (pts[1] as Vector3).y else 1   # the planted foot
			var d: Vector3 = pts[low] - last[low]
			d.y = 0.0
			speeds.append(d.length() / dt)
		last = pts
	if prev_anim != "":
		ap.play(prev_anim, 0.0)
		ap.seek(prev_pos, true)
	ap.speed_scale = prev_scale
	speeds.sort()
	var v: float = speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0   # median
	_stride_speed[anim] = v
	print("[Hero] '%s' moves its feet at %.2f m/s (model units); playback speed follows ground speed." % [anim, v])
	return v


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
