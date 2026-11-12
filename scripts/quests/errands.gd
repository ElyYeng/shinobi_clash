class_name Errands
extends RefCounted
## Random villager quests ("errands"). Walking villagers in Konoha with a "!" over their head offer
## one; it uses the normal quest system (objective types in scripts/quests/objectives) and is
## built entirely from its id - "errand_<villager>_<n>" - so a reload or a co-op party member
## regenerates exactly the same quest. n = how many errands you've finished, so each villager has
## something new after you complete one, and which villagers offer one rotates too.

const PREFIX := "errand_"
const GIVER_EVERY := 4   # 1 in 4 villagers has an errand at a time

## Open-ground spots in the Konoha greybox: [name, position].
const SPOTS := [
	["the crossroads", Vector3(0, 0, 40)], ["the Academy yard", Vector3(-62, 0, -58)],
	["the river bridge", Vector3(70, 0, 118)], ["the Hokage Tower plaza", Vector3(0, 0, -76)],
	["the memorial stone", Vector3(-98, 0, 76)], ["the main gate", Vector3(-14, 0, 162)],
	["the east street", Vector3(130, 0, 38)], ["the foot of the Hokage Rock", Vector3(-122, 0, -48)],
	["the south riverbank", Vector3(80, 0, 142)], ["the forest outside the gate", Vector3(-60, 0, 210)],
	["the meadow outside the gate", Vector3(55, 0, 210)],
]
const ITEMS := [["lost coins", "Lost Coin"], ["spilled herbs", "Herb Bundle"], ["scattered letters", "Letter"],
	["kunai from training", "Training Kunai"], ["runaway kittens", "Kitten"], ["dropped scrolls", "Scroll"]]
const THUGS := [["Rogue Ninja", Color(0.3, 0.25, 0.3), Color(0.55, 0.2, 0.2)],
	["Bandit", Color(0.35, 0.3, 0.22), Color(0.5, 0.45, 0.3)],
	["Thief", Color(0.2, 0.22, 0.28), Color(0.3, 0.3, 0.35)]]

static func is_errand(id: String) -> bool:
	return id.begins_with(PREFIX)

static func id_for(villager: int) -> String:
	return "%s%d_%d" % [PREFIX, villager, GameData.errands_done]

## Does this villager have an errand for you right now (and no quest is running)?
static func offers(villager: int) -> bool:
	return GameData.quest_active == "" and (villager + GameData.errands_done) % GIVER_EVERY == 0

static func villager_of(id: String) -> int:
	var parts := id.trim_prefix(PREFIX).split("_")
	return int(parts[0]) if parts.size() > 0 else -1

## The quest dictionary (same shape as QuestDef.to_dict) for an errand id.
static func make(id: String) -> Dictionary:
	var parts := id.trim_prefix(PREFIX).split("_")
	var vi := int(parts[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var who := Villager.name_for(vi)
	var spot: Array = SPOTS[rng.randi() % SPOTS.size()]
	var place: String = spot[0]
	var pos: Vector3 = spot[1]
	var step := {"type": "goto", "text": "", "pos": pos, "place": place.trim_prefix("the ").left(1).to_upper() + place.trim_prefix("the ").substr(1), "radius": 8.0, "target": "",
		"deliver_text": "", "count": 1, "item_name": "", "time": 0.0, "enemy_name": "", "enemy_health": 60.0,
		"enemy_damage": 6.0, "enemy_speed": 4.0, "enemy_color": Color(0.25, 0.25, 0.32), "enemy_band": Color(0.6, 0.6, 0.65)}
	var title := ""
	var offer := ""
	var remind := ""
	var turn := ""
	var xp := 0
	var spins := 0
	match rng.randi() % 4:
		0:   # gather things
			var it: Array = ITEMS[rng.randi() % ITEMS.size()]
			var n := rng.randi_range(4, 7)
			step["type"] = "collect"
			step["count"] = n
			step["item_name"] = it[1]
			step["radius"] = 9.0
			title = "Lost and Found"
			offer = "Oh, a shinobi! I lost %d %s near %s. Could you pick them up for me?" % [n, it[0], place]
			remind = "The %s should still be near %s." % [it[0], place]
			turn = "That's all of them! Thank you so much."
			xp = 60 + n * 10
		1:   # chase off troublemakers
			var th: Array = THUGS[rng.randi() % THUGS.size()]
			var n := rng.randi_range(2, 4)
			step["type"] = "kill"
			step["count"] = n
			step["enemy_name"] = th[0]
			step["enemy_color"] = th[1]
			step["enemy_band"] = th[2]
			step["enemy_health"] = 50.0 + rng.randf_range(0.0, 30.0)
			title = "Trouble at %s" % str(step["place"])
			offer = "%ss are bothering people near %s. Please, chase them off - %d of them!" % [th[0], place, n]
			remind = "The %ss are still near %s." % [th[0].to_lower(), place]
			turn = "They're gone? You're a real hero."
			xp = 90 + n * 25
			spins = 1 if rng.randf() < 0.3 else 0
		2:   # hold the spot
			var t := float(rng.randi_range(3, 5) * 10)
			step["type"] = "survive"
			step["time"] = t
			step["radius"] = 10.0
			step["count"] = rng.randi_range(2, 3)
			step["enemy_name"] = "Rogue Ninja"
			title = "Stand Guard"
			offer = "I need someone to watch %s for %d seconds while I fetch help. Stay in the area!" % [place, int(t)]
			remind = "Please - keep watch at %s." % place
			turn = "Everything's safe. Thanks for standing guard!"
			xp = 100 + int(t) * 2
			spins = 1 if rng.randf() < 0.25 else 0
		_:   # go and check something
			step["type"] = "goto"
			title = "A Quick Look"
			offer = "I heard a strange noise from %s. Could you go and take a look?" % place
			remind = "Did you check %s yet?" % place
			turn = "Nothing there? What a relief. Thank you!"
			xp = 50
	return {"id": id, "title": title, "giver": "villager_%d" % vi, "req": "", "repeatable": true, "order": 999,
		"type": step["type"], "pos": pos, "place": step["place"], "radius": step["radius"], "target": "",
		"count": step["count"], "enemy_name": step["enemy_name"], "enemy_health": step["enemy_health"],
		"enemy_damage": step["enemy_damage"], "enemy_speed": step["enemy_speed"], "enemy_color": step["enemy_color"],
		"enemy_band": step["enemy_band"], "item_name": step["item_name"], "time": step["time"],
		"reward": spins, "levels": 0, "xp": xp, "el_spins": 0,
		"offer": offer, "remind": remind, "deliver_text": "", "turn": turn, "steps": [step],
		"giver_name": who}
