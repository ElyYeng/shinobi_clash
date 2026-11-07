class_name GameData
extends RefCounted
## Persistent progress (spins, bloodline slots, quests) saved to user://save.json

const SAVE_PATH := "user://save.json"
const PITY_LIMIT := 20
## Bloodline slots (Shinobi Life style): each slot holds one bloodline and is spun on its own.
## Spinning a slot REPLACES whatever it held. Slots 1-2 start open; 3-4 are bought with spins.
const SLOT_COUNT := 4
const SLOT_UNLOCK_COST := [0, 0, 10, 25]
const RARITY_ORDER := ["Common", "Rare", "Epic", "Legendary", "Mythic"]
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
static var owned: Array = ["none"]      # every bloodline ever rolled (codex / achievements)
static var equipped := "none"           # always slots[active_slot]; use set_active_slot() to change
static var slots: Array = ["none", "none", "none", "none"]
static var slot_unlocked: Array = [true, true, false, false]
static var active_slot := 0
static var total_spins_used := 0
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
		total_spins_used = maxi(int(d.get("total_spins_used", 0)), 0)
		if d.has("slots"):
			_load_slots(d)
		else:
			_migrate_old_collection()
	if not owned.has("none"):
		owned.append("none")
	_sync_equipped()

static func _load_slots(d: Dictionary) -> void:
	var s = d.get("slots", [])
	var u = d.get("slot_unlocked", [])
	for i in SLOT_COUNT:
		var id := str(s[i]) if s is Array and i < s.size() else "none"
		slots[i] = id if Bloodline.DEFS.has(id) else "none"
		slot_unlocked[i] = SLOT_UNLOCK_COST[i] == 0 or (u is Array and i < u.size() and bool(u[i]))
	active_slot = clampi(int(d.get("active_slot", 0)), 0, SLOT_COUNT - 1)
	if not slot_unlocked[active_slot]:
		active_slot = 0

## Old saves had a collection + one equipped bloodline. Put the equipped one in slot 1
## and the best other owned bloodline in slot 2 so nobody loses their roll.
static func _migrate_old_collection() -> void:
	if not Bloodline.DEFS.has(equipped):
		equipped = "none"
	slots[0] = equipped
	var best := "none"
	for id in owned:
		var sid := str(id)
		if sid == equipped or sid == "none" or not Bloodline.DEFS.has(sid):
			continue
		if best == "none" or rarity_rank(sid) > rarity_rank(best):
			best = sid
	slots[1] = best
	active_slot = 0

static func _sync_equipped() -> void:
	equipped = str(slots[active_slot]) if slot_unlocked[active_slot] else "none"

static func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"spins": spins, "pity": pity, "owned": owned, "equipped": equipped,
			"element_spins": element_spins, "owned_elements": owned_elements,
			"equipped_element": equipped_element,
			"kurama_defeated": kurama_defeated, "quests_done": quests_done,
			"quest_active": quest_active, "quest_state": quest_state,
			"quest_progress": quest_progress,
			"slots": slots, "slot_unlocked": slot_unlocked, "active_slot": active_slot,
			"total_spins_used": total_spins_used}))

static func rarity_rank(id: String) -> int:
	if id == "none" or id == "":
		return -1
	return RARITY_ORDER.find(str(Bloodline.get_def(id)["rarity"]))

## Spends one spin on slot `i` and returns the bloodline id won ("" if it could not spin).
## The slot's old bloodline is replaced. Pity is shared across all slots.
static func roll_slot(i: int) -> String:
	if i < 0 or i >= SLOT_COUNT or not slot_unlocked[i] or spins <= 0:
		return ""
	spins -= 1
	total_spins_used += 1
	pity += 1
	var id := Bloodline.roll(pity >= PITY_LIMIT)
	if rarity_rank(id) >= 3:   # Legendary or Mythic resets pity
		pity = 0
	last_new = not owned.has(id)
	if last_new:
		owned.append(id)
	slots[i] = id
	_sync_equipped()
	save()
	return id

## Kept for older callers: spins the active slot.
static func roll() -> String:
	var id := roll_slot(active_slot)
	return equipped if id == "" else id

static func unlock_slot(i: int) -> bool:
	if i < 0 or i >= SLOT_COUNT or slot_unlocked[i] or spins < SLOT_UNLOCK_COST[i]:
		return false
	spins -= SLOT_UNLOCK_COST[i]
	slot_unlocked[i] = true
	save()
	return true

## Makes slot `i` the one whose bloodline the player uses in combat.
static func set_active_slot(i: int) -> bool:
	if i < 0 or i >= SLOT_COUNT or not slot_unlocked[i]:
		return false
	active_slot = i
	_sync_equipped()
	save()
	return true

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
