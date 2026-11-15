@tool
class_name NpcDef
extends Resource
## One NPC = one .tres file in res://data/npcs/ (the file name is the NPC id quests refer to).
## Leave model empty to use the game's customizable character; set a GLB / GLTF / TSCN for a unique model.

## Cached list of facial shape-key variants found in the character model.
static var _face_variant_options_cache: Dictionary = {}
const _FACE_PARTS := ["eyebrows", "eyes", "nose", "mouth"]
const _FACE_EXPRESSIONS := ["blink", "blank", "blind", "scream", "screaml", "screamr", "tension", "down"]
const _CHARACTER_MODEL_PATH := "res://assets/character/character_main.glb"

## Inspector enum hints are generated from the assigned model's actual facial blend shapes.
func _validate_property(property: Dictionary) -> void:
	var property_name := str(property.get("name", ""))
	# Kept only so older NPC resources still load; world NPCs all use Hero's shared character.
	if property_name in ["model", "model_height", "model_yaw_deg", "outline"]:
		property["usage"] = PROPERTY_USAGE_STORAGE
		return
	if not property_name.begins_with("face_"):
		return
	var part := property_name.trim_prefix("face_")
	if not _FACE_PARTS.has(part):
		return
	var variants: Array = _get_face_variant_options().get(part, [])
	# String enum hints must contain the actual stored string values. Label:value pairs
	# are displayed/stored literally here (e.g. "Itachi:itachi"), so blend-shape names never match.
	var choices := PackedStringArray(["__default"])
	for variant in variants:
		choices.append(str(variant))
	property["hint"] = PROPERTY_HINT_ENUM
	property["hint_string"] = ",".join(choices)

## Uses each NPC's own model when one is assigned; otherwise uses the game's default character.
static func _get_face_variant_options(source_path: String = "") -> Dictionary:
	var path := source_path if source_path != "" else _CHARACTER_MODEL_PATH
	if _face_variant_options_cache.has(path):
		return _face_variant_options_cache[path]
	var result: Dictionary = {}
	if not ResourceLoader.exists(path):
		_face_variant_options_cache[path] = result
		return result
	var packed := load(path) as PackedScene
	if packed == null:
		_face_variant_options_cache[path] = result
		return result
	var instance := packed.instantiate()
	if instance == null:
		_face_variant_options_cache[path] = result
		return result
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_blend_shape_count():
			var key := _parse_face_shape(str(mesh.get_blend_shape_name(i)))
			if key[0] == "" or key[3] != "":
				continue
			if not result.has(key[0]):
				result[key[0]] = []
			if not (result[key[0]] as Array).has(key[1]):
				(result[key[0]] as Array).append(key[1])
	instance.free()
	for part in result:
		(result[part] as Array).sort_custom(func(a, b) -> bool:
			var a_original := str(a).contains("original")
			var b_original := str(b).contains("original")
			return a_original if a_original != b_original else str(a) < str(b))
	_face_variant_options_cache[path] = result
	return result

## [part, variant, side, expression], matching Hero.face_key().
static func _parse_face_shape(shape_name: String) -> Array:
	var cut := shape_name.find("_")
	if cut < 0:
		return ["", "", "", ""]
	var part := shape_name.left(cut).to_lower()
	if not _FACE_PARTS.has(part):
		return ["", "", "", ""]
	var rest := shape_name.substr(cut + 1)
	var expression := ""
	var bits := rest.split("_")
	if bits.size() > 1 and _FACE_EXPRESSIONS.has(str(bits[-1]).to_lower()):
		var last := str(bits[-1]).to_lower()
		expression = last.trim_suffix("l").trim_suffix("r") if last.begins_with("scream") else last
		if expression in ["blank", "blind"]:
			expression = "blink"
		bits.remove_at(bits.size() - 1)
		rest = "_".join(bits)
	var side := ""
	if part == "eyes" and (rest.ends_with("L") or rest.ends_with("R")):
		side = rest.right(1)
		rest = rest.left(rest.length() - 1)
	return [part, rest, side, expression]

static func _face_variant_label(variant: String) -> String:
	if variant.contains("original"):
		return "Original %d (%s)" % [int(variant.right(2)), "F" if variant.begins_with("W") else "M"]
	return variant.replace("_", " ").capitalize()

@export_group("Identity")
@export var display_name := "Villager":
	set(value):
		if display_name == value:
			return
		display_name = value
		emit_changed()
@export var pos := Vector3.ZERO:
	set(value):
		if pos == value:
			return
		pos = value
		emit_changed()

@export_group("Dialogue")
@export_multiline var greeting := "Hello.":
	set(value):
		if greeting == value:
			return
		greeting = value
		emit_changed()
## Optional extra lines, one per line. They play in order after the greeting, then loop.
@export_multiline var dialogue_lines_text := "":
	set(value):
		if dialogue_lines_text == value:
			return
		dialogue_lines_text = value
		emit_changed()
@export var goodbye_label := "Goodbye":
	set(value):
		if goodbye_label == value:
			return
		goodbye_label = value
		emit_changed()

@export_group("Character Appearance")
## Keep enabled for the existing deterministic random village look. Disable to use the controls below.
@export var randomize_appearance := false:
	set(value):
		if randomize_appearance == value:
			return
		randomize_appearance = value
		emit_changed()

@export_subgroup("Hair")
## Mesh IDs are named like hair1, hair2, etc. Use an ID present in character_main.glb.
@export var hair_style := "hair1":
	set(value):
		if hair_style == value:
			return
		hair_style = value
		emit_changed()
@export_color_no_alpha var hair_color := Color(0.902, 0.710, 0.180):
	set(value):
		if hair_color == value:
			return
		hair_color = value
		emit_changed()

@export_subgroup("Clothing")
## Mesh IDs are named like shirt1, shirt2, pants1, etc.
@export var shirt_style := "shirt1":
	set(value):
		if shirt_style == value:
			return
		shirt_style = value
		emit_changed()
@export_color_no_alpha var shirt_color := Color.WHITE:
	set(value):
		if shirt_color == value:
			return
		shirt_color = value
		emit_changed()
@export var pants_style := "pants1":
	set(value):
		if pants_style == value:
			return
		pants_style = value
		emit_changed()
@export_color_no_alpha var pants_color := Color.WHITE:
	set(value):
		if pants_color == value:
			return
		pants_color = value
		emit_changed()

@export_subgroup("Headband")
@export_color_no_alpha var headband_color := Color(0.169, 0.227, 0.404):
	set(value):
		if headband_color == value:
			return
		headband_color = value
		emit_changed()
@export_color_no_alpha var headbandmetal_color := Color.WHITE:
	set(value):
		if headbandmetal_color == value:
			return
		headbandmetal_color = value
		emit_changed()

@export_subgroup("Face")
## Face type chooses the default original facial features. Specific selectors below override it.
@export_enum("male", "female") var face_sex := "male":
	set(value):
		var normalized := _face_option_value(value)
		if face_sex == normalized:
			return
		face_sex = normalized
		emit_changed()
## These dropdowns are populated from the facial shape keys in character_main.glb.
## The stored String is the exact blend-shape identifier (e.g. "itachi"), not a display label.
@export var face_eyebrows := "__default":
	set(value):
		var normalized := _face_option_value(value)
		if face_eyebrows == normalized:
			return
		face_eyebrows = normalized
		emit_changed()
@export var face_eyes := "__default":
	set(value):
		var normalized := _face_option_value(value)
		if face_eyes == normalized:
			return
		face_eyes = normalized
		emit_changed()
@export var face_nose := "__default":
	set(value):
		var normalized := _face_option_value(value)
		if face_nose == normalized:
			return
		face_nose = normalized
		emit_changed()
@export var face_mouth := "__default":
	set(value):
		var normalized := _face_option_value(value)
		if face_mouth == normalized:
			return
		face_mouth = normalized
		emit_changed()
@export var use_custom_skin_color := false:
	set(value):
		if use_custom_skin_color == value:
			return
		use_custom_skin_color = value
		emit_changed()
@export_color_no_alpha var skin_color := Color(0.922, 0.718, 0.608):
	set(value):
		if skin_color == value:
			return
		skin_color = value
		emit_changed()
@export var use_custom_eye_color := false:
	set(value):
		if use_custom_eye_color == value:
			return
		use_custom_eye_color = value
		emit_changed()
@export_color_no_alpha var eye_color := Color(0.420, 0.267, 0.137):
	set(value):
		if eye_color == value:
			return
		eye_color = value
		emit_changed()

@export_subgroup("Special outfit colours")
@export_color_no_alpha var cloak_color1 := Color(0.110, 0.106, 0.141):
	set(value):
		if cloak_color1 == value:
			return
		cloak_color1 = value
		emit_changed()
@export_color_no_alpha var cloak_color2 := Color(0.722, 0.086, 0.122):
	set(value):
		if cloak_color2 == value:
			return
		cloak_color2 = value
		emit_changed()
@export_color_no_alpha var vest_color1 := Color(0.518, 0.553, 0.478):
	set(value):
		if vest_color1 == value:
			return
		vest_color1 = value
		emit_changed()
@export_color_no_alpha var vest_color2 := Color(0.208, 0.224, 0.310):
	set(value):
		if vest_color2 == value:
			return
		vest_color2 = value
		emit_changed()
@export_color_no_alpha var top_color1 := Color(0.275, 0.267, 0.310):
	set(value):
		if top_color1 == value:
			return
		top_color1 = value
		emit_changed()
@export_color_no_alpha var top_color2 := Color(0.914, 0.514, 0.322):
	set(value):
		if top_color2 == value:
			return
		top_color2 = value
		emit_changed()
@export_color_no_alpha var bpants_color1 := Color(0.204, 0.220, 0.306):
	set(value):
		if bpants_color1 == value:
			return
		bpants_color1 = value
		emit_changed()
@export_color_no_alpha var bpants_color2 := Color(0.761, 0.694, 0.694):
	set(value):
		if bpants_color2 == value:
			return
		bpants_color2 = value
		emit_changed()
@export_color_no_alpha var boar_color1 := Color(0.102, 0.102, 0.169):
	set(value):
		if boar_color1 == value:
			return
		boar_color1 = value
		emit_changed()
@export_color_no_alpha var boar_color2 := Color(0.600, 0.431, 0.286):
	set(value):
		if boar_color2 == value:
			return
		boar_color2 = value
		emit_changed()
@export_color_no_alpha var pants_color1 := Color(0.890, 0.502, 0.310):
	set(value):
		if pants_color1 == value:
			return
		pants_color1 = value
		emit_changed()
@export_color_no_alpha var pants_color2 := Color(0.196, 0.208, 0.298):
	set(value):
		if pants_color2 == value:
			return
		pants_color2 = value
		emit_changed()
@export_color_no_alpha var jacket_color1 := Color(0.329, 0.114, 0.118):
	set(value):
		if jacket_color1 == value:
			return
		jacket_color1 = value
		emit_changed()
@export_color_no_alpha var jacket_color2 := Color(0.216, 0.173, 0.329):
	set(value):
		if jacket_color2 == value:
			return
		jacket_color2 = value
		emit_changed()
@export_color_no_alpha var jacket_trim := Color.BLACK:
	set(value):
		if jacket_trim == value:
			return
		jacket_trim = value
		emit_changed()

## Legacy / advanced overrides for appearance keys not exposed above (e.g. custom textures).
@export_group("Advanced")
@export var appearance: Dictionary = {}:
	set(value):
		if appearance == value:
			return
		appearance = value
		emit_changed()

@export_group("Model")
@export_file("*.glb", "*.gltf", "*.tscn") var model := "":
	set(value):
		if model == value:
			return
		model = value
		notify_property_list_changed()
		emit_changed()
@export var model_height := 1.85:
	set(value):
		if model_height == value:
			return
		model_height = value
		emit_changed()
@export var model_yaw_deg := 180.0:
	set(value):
		if model_yaw_deg == value:
			return
		model_yaw_deg = value
		emit_changed()
@export var outline := true:
	set(value):
		if outline == value:
			return
		outline = value
		emit_changed()

@export_group("Fallback Placeholder")
@export_color_no_alpha var body_color := Color(0.3, 0.5, 0.7):
	set(value):
		if body_color == value:
			return
		body_color = value
		emit_changed()
@export_color_no_alpha var band_color := Color(0.9, 0.9, 0.9):
	set(value):
		if band_color == value:
			return
		band_color = value
		emit_changed()

## Converts a string enum value to the exact identifier stored in the character's blend shapes.
## This also repairs values saved by the earlier "Label:identifier" Inspector dropdowns.
static func _face_option_value(raw: String) -> String:
	var value := raw.strip_edges()
	var separator := value.rfind(":")
	if separator >= 0:
		value = value.substr(separator + 1).strip_edges()
	return value

## Array consumed by the NPC at runtime. Blank lines are ignored.
func get_dialogue_lines() -> Array[String]:
	var out: Array[String] = []
	for raw_line in dialogue_lines_text.split("\n"):
		var line := raw_line.strip_edges()
		if line != "":
			out.append(line)
	return out

## Builds the shared Hero appearance. Manual Inspector options are active by default; enable
## randomize_appearance only when a deterministic random village appearance is desired.
func get_appearance() -> Dictionary:
	var out: Dictionary = appearance.duplicate(true)
	if randomize_appearance:
		return out

	var colours := {
		"hair_style": hair_style,
		"hair_color": "#" + hair_color.to_html(false),
		"shirt_style": shirt_style,
		"shirt_color": "#" + shirt_color.to_html(false),
		"pants_style": pants_style,
		"pants_color": "#" + pants_color.to_html(false),
		"headband_color": "#" + headband_color.to_html(false),
		"headbandmetal_color": "#" + headbandmetal_color.to_html(false),
		"cloak_color1": "#" + cloak_color1.to_html(false),
		"cloak_color2": "#" + cloak_color2.to_html(false),
		"vest_color1": "#" + vest_color1.to_html(false),
		"vest_color2": "#" + vest_color2.to_html(false),
		"top_color1": "#" + top_color1.to_html(false),
		"top_color2": "#" + top_color2.to_html(false),
		"bpants_color1": "#" + bpants_color1.to_html(false),
		"bpants_color2": "#" + bpants_color2.to_html(false),
		"boar_color1": "#" + boar_color1.to_html(false),
		"boar_color2": "#" + boar_color2.to_html(false),
		"pants_color1": "#" + pants_color1.to_html(false),
		"pants_color2": "#" + pants_color2.to_html(false),
		"jacket_color1": "#" + jacket_color1.to_html(false),
		"jacket_color2": "#" + jacket_color2.to_html(false),
		"jacket_trim": "#" + jacket_trim.to_html(false),
	}
	out.merge(colours, true)
	# Older Inspector enum selections may have saved the display label and id together,
	# e.g. "Itachi:itachi". Hero expects only the exact blend-shape id ("itachi").
	out["sex"] = _face_option_value(face_sex)
	var face := {}
	for part in _FACE_PARTS:
		var selected := _face_option_value(str(get("face_" + part)))
		if selected != "" and selected != "__default":
			face[part] = selected
	out["face"] = face
	if use_custom_skin_color:
		out["skin_color"] = "#" + skin_color.to_html(false)
	else:
		out.erase("skin_color")
	if use_custom_eye_color:
		out["eye_color"] = "#" + eye_color.to_html(false)
	else:
		out.erase("eye_color")
	return out

func to_dict(id: String) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"pos": pos,
		"greet": greeting,
		"dialogue_lines": get_dialogue_lines(),
		"goodbye": goodbye_label,
		"color": body_color,
		"band": band_color,
		"model": model,
		"model_height": model_height,
		"model_yaw": model_yaw_deg,
		"outline": outline,
		"appearance": get_appearance()
	}
