extends QuestObjective
## Defeat `count` enemies. They spawn around `pos` (enemy_* fields set how tough they are).

var _last_kills := 0

func start() -> void:
	quests.make_beacon(step["pos"], str(step["place"]) if str(step["place"]) != "" else "Enemy camp")
	quests.spawn_enemies(int(step["count"]) - progress(), step, false)
	_last_kills = player().kills

func update(_delta: float) -> void:
	var kd := player().kills - _last_kills
	_last_kills = player().kills
	if quests.party_coop():
		return   # the host counts quest-enemy kills for the party
	if kd > 0:
		set_progress(mini(progress() + kd, int(step["count"])))
		if progress() >= int(step["count"]):
			complete()

func counts_enemy_kills() -> bool:
	return true

func hud_text() -> String:
	return text_or("Defeat enemies: %d / %d" % [progress(), int(step["count"])])
