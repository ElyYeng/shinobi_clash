class_name GameData
extends RefCounted
## Persistent progress (spins, bloodlines, quests) saved to user://save.json

const SAVE_PATH := "user://save.json"
const PITY_LIMIT := 20
const ELEMENTS := ["Fire", "Earth", "Lightning", "Water", "Wind"]
const ELEMENT_COLORS := {
	"Fire": Color(1.0, 0.38, 0.10),
	"Earth": Color(0.68, 0.48, 0.25),
	"Lightning": Color(0.62, 0.78, 1.0),
	"Water": Color(0.18, 0.58, 1.0),
	"Wind": Color(0.45, 0.88, 0.62),
}

static var mode := "fight"          # "kurama" | "fight" | "world"  (chosen in the menu)
static var spins := 3
static var element_spins := 3
static var equipped_element := "Fire"
static var owned_elements: Array[String] = ["Fire"]
static var pity := 0
static var owned: Array = ["none"]
static var equipped := "none"
static var last_new := false
static var kurama_defeated := false
static var quests_done: Array = []
static var quest_active := ""
static var quest_state := ""        # "active" | "ready"
static var quest_progress := 0
static var _loaded := false

static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		spins = maxi(int(d.get("spins", 3)), 0)
		element_spins = maxi(int(d.get("element_spins", 3)), 0)
		pity = maxi(int(d.get("pity", 0)), 0)
		var saved_elements = d.get("owned_elements", ["Fire"])
		owned_elements.clear()
		if saved_elements is Array:
			for element in saved_elements:
				var element_name := str(element)
				if ELEMENTS.has(element_name) and not owned_elements.has(element_name):
					owned_elements.append(element_name)
		if owned_elements.is_empty():
			owned_elements.append("Fire")
		equipped_element = str(d.get("equipped_element", "Fire"))
		if not owned_elements.has(equipped_element):
			equipped_element = owned_elements[0]
		owned = d.get("owned", ["none"])
		equipped = str(d.get("equipped", "none"))
		kurama_defeated = bool(d.get("kurama_defeated", false))
		quests_done = d.get("quests_done", [])
		quest_active = str(d.get("quest_active", ""))
		quest_state = str(d.get("quest_state", ""))
		quest_progress = int(d.get("quest_progress", 0))
	if not owned.has("none"):
		owned.append("none")
	if not owned.has(equipped):
		equipped = "none"

static func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"spins": spins, "pity": pity, "owned": owned, "equipped": equipped,
			"element_spins": element_spins, "owned_elements": owned_elements,
			"equipped_element": equipped_element,
			"kurama_defeated": kurama_defeated, "quests_done": quests_done,
			"quest_active": quest_active, "quest_state": quest_state,
			"quest_progress": quest_progress}))

## Spends one spin and returns the bloodline id won.
static func roll() -> String:
	if spins <= 0:
		return equipped
	spins -= 1
	pity += 1
	var id := Bloodline.roll(pity >= PITY_LIMIT)
	if Bloodline.get_def(id)["rarity"] == "Legendary":
		pity = 0
	last_new = not owned.has(id)
	if last_new:
		owned.append(id)
	save()
	return id

## Spends one element spin, preferring an element that is not owned yet.
## Once all elements are collected, duplicate rolls remain possible.
static func roll_element() -> String:
	if element_spins <= 0:
		return equipped_element
	element_spins -= 1
	var choices: Array[String] = []
	for element in ELEMENTS:
		if not owned_elements.has(element):
			choices.append(element)
	if choices.is_empty():
		choices.assign(ELEMENTS)
	var result: String = choices[randi() % choices.size()]
	if not owned_elements.has(result):
		owned_elements.append(result)
	equipped_element = result
	save()
	return result

static func get_element_color(element: String = "") -> Color:
	var key := equipped_element if element.is_empty() else element
	return ELEMENT_COLORS.get(key, Color.WHITE)
