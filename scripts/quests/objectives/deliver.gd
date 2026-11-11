extends QuestObjective
## Talk to the `target` NPC. They say `deliver_text`.

func talk_target() -> String:
	return str(step["target"])

func on_talk() -> void:
	complete()

func target_position() -> Vector3:
	var n: Dictionary = Quests.NPCS.get(str(step["target"]), {})
	return n.get("pos", Vector3.INF)

func hud_text() -> String:
	var n: Dictionary = Quests.NPCS.get(str(step["target"]), {})
	return text_or("Speak to %s" % n.get("name", step["target"]))
