extends QuestObjective
## Defeat the `count` named enemies (`enemy_name`) that spawn at `pos`.

var _base := 0
var _spawned := 0

func start() -> void:
	var nm := str(step["enemy_name"])
	quests.make_beacon(step["pos"], nm if nm != "" else "Targets")
	_base = progress()
	_spawned = maxi(int(step["count"]) - progress(), 0)
	quests.spawn_enemies(_spawned, step, true)

func update(_delta: float) -> void:
	if quests.party_coop():
		return   # the host counts quest-enemy kills for the party
	var alive := 0
	for e in quests.get_tree().get_nodes_in_group("hunt_targets"):
		if e.is_in_group("enemies"):
			alive += 1
	var prog := _base + _spawned - alive
	if prog != progress():
		set_progress(prog)
	if progress() >= int(step["count"]):
		complete()

func counts_enemy_kills() -> bool:
	return true

func hud_text() -> String:
	return text_or("Defeat %ss: %d / %d" % [step["enemy_name"], progress(), int(step["count"])])
