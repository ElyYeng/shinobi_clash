extends QuestObjective
## Beat the Kurama Boss Fight (main menu or M > Travel).

func update(_delta: float) -> void:
	if GameData.kurama_defeated:
		complete()

func target_position() -> Vector3:
	return Vector3.INF

func hud_text() -> String:
	return text_or("Defeat Kurama\n(Menu > Kurama Boss Fight)")
