@tool
class_name NpcDef
extends Resource
## One NPC = one .tres file in res://data/npcs/ (the file name is the NPC id quests refer to).
## Leave model empty to use the game's customizable character; set a GLB / GLTF / TSCN for a unique model.

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
@export var randomize_appearance := true:
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

## Array consumed by the NPC at runtime. Blank lines are ignored.
func get_dialogue_lines() -> Array[String]:
	var out: Array[String] = []
	for raw_line in dialogue_lines_text.split("\n"):
		var line := raw_line.strip_edges()
		if line != "":
			out.append(line)
	return out

## Builds the appearance dictionary expected by Hero. Randomized NPCs retain their old behaviour.
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
