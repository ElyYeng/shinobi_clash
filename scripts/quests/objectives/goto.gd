extends QuestObjective
## Walk to `pos` (within `radius`). A golden beam named `place` marks the spot.

func start() -> void:
	quests.make_beacon(step["pos"], str(step["place"]))

func update(_delta: float) -> void:
	if flat_distance(step["pos"]) < float(step["radius"]):
		complete()

func hud_text() -> String:
	return text_or("Reach the %s (%d m)" % [step["place"], int(flat_distance(step["pos"]))])
