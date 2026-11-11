class_name QuestObjective
extends RefCounted
## Base class for one quest objective type. Every type is its own script in
## res://scripts/quests/objectives/<type>.gd that extends this; Quests finds them by file name, so a new
## objective type is just a new file (and a new entry in QuestStep's `type` list for the Inspector).
##
## The step's fields are in `step` (QuestStep.to_dict). Progress within the step is a number
## (progress() / set_progress()) that is saved and shared with your co-op party; call complete()
## when the step is done.

var quests: Quests        # the quest manager: beacons, enemy spawning, the player, the world
var step: Dictionary = {}
var step_index := 0

## The step became active (also after loading a save or joining a party mid-quest).
func start() -> void:
	pass

## Every frame while the step is active.
func update(_delta: float) -> void:
	pass

## The step ended or the quest was dropped: remove anything start() created.
## (Beacons and quest enemies are removed by the manager.)
func stop() -> void:
	pass

## Line under the quest title on the HUD.
func hud_text() -> String:
	return str(step.get("text", ""))

## Where the quest arrow / "Travel" in the M menu should point (Vector3.INF = nowhere special).
func target_position() -> Vector3:
	return step.get("pos", Vector3.INF)

## NPC id that has something to say for this step ("" = none).
func talk_target() -> String:
	return ""

## The player talked to talk_target().
func on_talk() -> void:
	pass

## True if quest-enemy kills count for this step (the co-op host counts them for the party).
func counts_enemy_kills() -> bool:
	return false

# ---- helpers
func progress() -> int:
	return quests.step_progress()

func set_progress(n: int) -> void:
	quests.set_step_progress(n)

func complete() -> void:
	quests.complete_step()

func player() -> Player:
	return quests.player

func flat_distance(to: Vector3) -> float:
	var p := quests.player.global_position
	return Vector2(p.x - to.x, p.z - to.z).length()

## The HUD text if the quest file set one, otherwise `default`.
func text_or(default: String) -> String:
	var t := str(step.get("text", ""))
	return t if t != "" else default
