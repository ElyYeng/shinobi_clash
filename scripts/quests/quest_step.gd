class_name QuestStep
extends Resource
## One step of a multi-step quest (QuestDef "steps"). The steps run in order; when the last one is
## done you return to the quest giver. Which fields matter depends on `type` - each type is a
## script in res://scripts/quests/objectives/ (the file name is the type), so new types are just new files:
##   goto     walk to `pos` (a golden beam marks it; `place` is its name, `radius` how close)
##   deliver  talk to the `target` NPC (`deliver_text` is what they say)
##   kill     defeat `count` enemies that spawn around `pos`
##   hunt     defeat the `count` named enemies (`enemy_name`) that spawn at `pos`
##   collect  pick up `count` `item_name`s scattered within `radius` of `pos`
##   survive  hold out for `time` seconds near `pos` while waves of enemies attack
##   kurama   beat the Kurama Boss Fight

@export_enum("goto", "deliver", "kill", "hunt", "collect", "survive", "kurama") var type := "goto"
@export var text := ""               ## optional HUD line instead of the default ("Reach the ...")
@export var pos := Vector3.ZERO
@export var place := ""              ## goto: name on the beam
@export var radius := 5.0            ## goto: how close / collect: scatter area / survive: arena size
@export var target := ""             ## deliver: NPC id
@export_multiline var deliver_text := ""
@export var count := 1               ## kill / hunt / collect
@export var item_name := "Scroll"    ## collect
@export var time := 45.0             ## survive: seconds

@export_group("Enemies (kill / hunt / survive)")
@export var enemy_name := ""
@export var enemy_health := 45.0
@export var enemy_damage := 6.0
@export var enemy_speed := 4.2
@export var enemy_color := Color(0.25, 0.25, 0.32)
@export var enemy_band := Color(0.6, 0.6, 0.65)

func to_dict() -> Dictionary:
	return {"type": type, "text": text, "pos": pos, "place": place, "radius": radius, "target": target,
		"deliver_text": deliver_text, "count": count, "item_name": item_name, "time": time,
		"enemy_name": enemy_name, "enemy_health": enemy_health, "enemy_damage": enemy_damage,
		"enemy_speed": enemy_speed, "enemy_color": enemy_color, "enemy_band": enemy_band}
