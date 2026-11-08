class_name NpcDef
extends Resource
## One NPC = one .tres file in res://data/npcs/ (the file name is the NPC id quests refer to).
## Leave `model` empty for the simple placeholder ninja, or point it at a .glb / .gltf / .tscn
## to use a real character (it is scaled to `model_height` and plays its first animation as idle).

@export var display_name := "Villager"
@export var pos := Vector3.ZERO
@export_multiline var greeting := "Hello."
@export var body_color := Color(0.3, 0.5, 0.7)    ## placeholder model colours
@export var band_color := Color(0.9, 0.9, 0.9)
@export_file("*.glb", "*.gltf", "*.tscn") var model := ""
@export var model_height := 1.85                  ## metres
@export var model_yaw_deg := 180.0                ## turn the model if it faces the wrong way
@export var outline := true                       ## ink outline; turn off if the model turns black

func to_dict(id: String) -> Dictionary:
	return {"id": id, "name": display_name, "pos": pos, "greet": greeting, "color": body_color, "band": band_color,
		"model": model, "model_height": model_height, "model_yaw": model_yaw_deg, "outline": outline}
