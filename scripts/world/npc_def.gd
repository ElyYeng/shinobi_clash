class_name NpcDef
extends Resource
## One NPC = one .tres file in res://data/npcs/ (the file name is the NPC id quests refer to).
## Leave model empty to use the game's customizable character; set a GLB / GLTF / TSCN for a unique model.

@export_group("Identity")
@export var display_name := "Villager"
@export var pos := Vector3.ZERO

@export_group("Dialogue")
@export_multiline var greeting := "Hello."
## Optional extra lines, one per line. They play in order after the greeting, then loop.
@export_multiline var dialogue_lines_text := ""
@export var goodbye_label := "Goodbye"

@export_group("Character Appearance")
## Keep enabled for the existing deterministic random village look. Disable to use the controls below.
@export var randomize_appearance := true

@export_subgroup("Hair")
## Mesh IDs are named like hair1, hair2, etc. Use an ID present in character_main.glb.
@export var hair_style := "hair1"
@export_color_no_alpha var hair_color := Color(0.902, 0.710, 0.180)

@export_subgroup("Clothing")
## Mesh IDs are named like shirt1, shirt2, pants1, etc.
@export var shirt_style := "shirt1"
@export_color_no_alpha var shirt_color := Color.WHITE
@export var pants_style := "pants1"
@export_color_no_alpha var pants_color := Color.WHITE

@export_subgroup("Headband")
@export_color_no_alpha var headband_color := Color(0.169, 0.227, 0.404)
@export_color_no_alpha var headbandmetal_color := Color.WHITE

@export_subgroup("Face")
@export var use_custom_skin_color := false
@export_color_no_alpha var skin_color := Color(0.922, 0.718, 0.608)
@export var use_custom_eye_color := false
@export_color_no_alpha var eye_color := Color(0.420, 0.267, 0.137)

@export_subgroup("Special outfit colours")
@export_color_no_alpha var cloak_color1 := Color(0.110, 0.106, 0.141)
@export_color_no_alpha var cloak_color2 := Color(0.722, 0.086, 0.122)
@export_color_no_alpha var vest_color1 := Color(0.518, 0.553, 0.478)
@export_color_no_alpha var vest_color2 := Color(0.208, 0.224, 0.310)
@export_color_no_alpha var top_color1 := Color(0.275, 0.267, 0.310)
@export_color_no_alpha var top_color2 := Color(0.914, 0.514, 0.322)
@export_color_no_alpha var bpants_color1 := Color(0.204, 0.220, 0.306)
@export_color_no_alpha var bpants_color2 := Color(0.761, 0.694, 0.694)
@export_color_no_alpha var boar_color1 := Color(0.102, 0.102, 0.169)
@export_color_no_alpha var boar_color2 := Color(0.600, 0.431, 0.286)
@export_color_no_alpha var pants_color1 := Color(0.890, 0.502, 0.310)
@export_color_no_alpha var pants_color2 := Color(0.196, 0.208, 0.298)
@export_color_no_alpha var jacket_color1 := Color(0.329, 0.114, 0.118)
@export_color_no_alpha var jacket_color2 := Color(0.216, 0.173, 0.329)
@export_color_no_alpha var jacket_trim := Color.BLACK

## Legacy / advanced overrides for appearance keys not exposed above (e.g. custom textures).
@export_group("Advanced")
@export var appearance: Dictionary = {}

@export_group("Model")
@export_file("*.glb", "*.gltf", "*.tscn") var model := ""
@export var model_height := 1.85
@export var model_yaw_deg := 180.0
@export var outline := true

@export_group("Fallback Placeholder")
@export_color_no_alpha var body_color := Color(0.3, 0.5, 0.7)
@export_color_no_alpha var band_color := Color(0.9, 0.9, 0.9)

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
