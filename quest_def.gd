class_name QuestDef
extends Resource
## One quest = one .tres file in res://data/quests/. The game loads every file in that folder
## (see Quests.ensure_loaded), so to add a quest: duplicate a file there and edit it in the Inspector.
##
## A quest is either ONE objective (the Objective / Enemies fields below) or a list of `steps`
## (QuestStep resources, done in order: e.g. goto -> kill -> deliver). If `steps` has anything in
## it, the single-objective fields are ignored. When the last objective is done, you return to
## the giver for the reward.
##
## Objective types (each one is a script in res://quest_objectives/ - add a file for a new type):
##   goto     walk to `pos` (a golden beam marks it; `place` is its name, `radius` how close)
##   deliver  talk to `target` NPC (`deliver_text` is what they say)
##   kill     defeat `count` enemies that spawn around `pos`
##   hunt     defeat the `count` named enemies that spawn at `pos` (see the Enemies group)
##   collect  pick up `count` `item_name`s scattered within `radius` of `pos`
##   survive  hold out for `time` seconds near `pos` while waves of enemies attack
##   kurama   beat the Kurama Boss Fight

@export var id := ""                 ## unique id, saved in the player's progress (don't rename once shipped)
@export var title := ""
@export var giver := ""              ## NPC id (file name in res://data/npcs/ without .tres)
@export var requires := ""           ## quest id that must be finished first ("" = none)
@export var repeatable := false   ## repeatable quests can be accepted again after turning them in
@export var order := 0               ## if one NPC offers several quests, lower order comes first
@export_enum("goto", "deliver", "kill", "hunt", "collect", "survive", "kurama") var type := "goto"
## Multi-step quest: the objectives in order. Leave empty for a single-objective quest.
@export var steps: Array[QuestStep] = []

@export_group("Objective")
@export var pos := Vector3.ZERO      ## goto / kill / hunt location
@export var place := ""              ## goto: name shown on the beam
@export var radius := 5.0            ## goto: how close you must get
@export var target := ""             ## deliver: NPC id to talk to
@export var count := 1               ## kill / hunt / collect: how many
@export var item_name := "Scroll"    ## collect: what you pick up
@export var time := 45.0             ## survive: seconds

@export_group("Enemies (kill / hunt)")
@export var enemy_name := ""         ## shown above them (hunt)
@export var enemy_health := 45.0
@export var enemy_damage := 6.0
@export var enemy_speed := 4.2
@export var enemy_color := Color(0.25, 0.25, 0.32)
@export var enemy_band := Color(0.6, 0.6, 0.65)

@export_group("Rewards")
@export var reward_spins := 0
@export var reward_levels := 0       ## whole shinobi levels (with their stat points)
@export var reward_xp := 300         ## shinobi XP on top
@export var reward_element_spins := 0

@export_group("Dialog")
@export_multiline var offer := ""
@export_multiline var remind := ""
@export_multiline var deliver_text := ""
@export_multiline var turn := ""

## The dictionary shape the rest of the game uses (Quests.DEFS[id]).
func to_dict() -> Dictionary:
	return {"id": id, "title": title, "giver": giver, "req": requires, "repeatable": repeatable, "order": order, "type": type,
		"pos": pos, "place": place, "radius": radius, "target": target, "count": count,
		"enemy_name": enemy_name, "enemy_health": enemy_health, "enemy_damage": enemy_damage,
		"enemy_speed": enemy_speed, "enemy_color": enemy_color, "enemy_band": enemy_band,
		"item_name": item_name, "time": time,
		"reward": reward_spins, "levels": reward_levels, "xp": reward_xp, "el_spins": reward_element_spins,
		"offer": offer, "remind": remind, "deliver_text": deliver_text, "turn": turn,
		"steps": _step_dicts()}

## The objectives in order (a single-objective quest gives one step built from its own fields).
func _step_dicts() -> Array:
	var out: Array = []
	for st in steps:
		if st != null:
			out.append(st.to_dict())
	if out.is_empty():
		out.append({"type": type, "text": "", "pos": pos, "place": place, "radius": radius, "target": target,
			"deliver_text": deliver_text, "count": count, "item_name": item_name, "time": time,
			"enemy_name": enemy_name, "enemy_health": enemy_health, "enemy_damage": enemy_damage,
			"enemy_speed": enemy_speed, "enemy_color": enemy_color, "enemy_band": enemy_band})
	return out
