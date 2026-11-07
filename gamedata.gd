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

# ---- Shinobi level + stat points (Stats tab in the M menu)
const MAX_LEVEL := 500
const POINTS_PER_LEVEL := 3
const STAT_CAP := 200                   # max points in one stat
const STAT_KEYS := ["health", "chakra", "md", "stamina", "bloodline"]
## What one point in each stat gives (used by player.gd and shown in the menu).
const STAT_PER_POINT := {"health": 3.0, "chakra": 3.0, "md": 0.015, "stamina": 2.0, "bloodline": 0.01}
const XP_KILL := 100
const XP_BOSS := 1000
const XP_QUEST := 300
static var level := 1
static var xp := 0
static var stat_points := 0
static var stats := {"health": 0, "chakra": 0, "md": 0, "stamina": 0, "bloodline": 0}

# ---- Bloodline mastery: every bloodline levels up on its own, to LV 1000
const MASTERY_MAX := 1000
const MASTERY_KILL := 100              # mastery XP per kill with that bloodline active
const MASTERY_BOSS := 1000
const MASTERY_HIT := 3                 # per enemy hit by one of its abilities
static var mastery := {}               # bloodline id -> total mastery XP

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
		level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
		xp = maxi(int(d.get("xp", 0)), 0)
		stat_points = maxi(int(d.get("stat_points", 0)), 0)
		var st = d.get("stats", {})
		for k in STAT_KEYS:
			stats[k] = clampi(int(st.get(k, 0)), 0, STAT_CAP) if st is Dictionary else 0
		var m = d.get("mastery", {})
		mastery = {}
		if m is Dictionary:
			for k in m:
				if Bloodline.DEFS.has(str(k)):
					mastery[str(k)] = maxi(int(m[k]), 0)
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
			"total_spins_used": total_spins_used,
			"level": level, "xp": xp, "stat_points": stat_points, "stats": stats, "mastery": mastery}))

# ------------------------------------------------------------------ shinobi level
static func xp_needed(lv: int = -1) -> int:
	var l := level if lv < 0 else lv
	return 100 + 25 * (l - 1)

## Adds XP and returns how many levels were gained (each gives POINTS_PER_LEVEL stat points).
static func add_xp(n: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	xp += n
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		stat_points += POINTS_PER_LEVEL
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	return gained

## Spends up to `n` stat points on `key`. Returns how many were spent.
static func add_stat(key: String, n: int = 1) -> int:
	if not stats.has(key):
		return 0
	var k := mini(mini(n, stat_points), STAT_CAP - int(stats[key]))
	if k <= 0:
		return 0
	stats[key] = int(stats[key]) + k
	stat_points -= k
	save()
	return k

static func reset_stats() -> void:
	for k in STAT_KEYS:
		stat_points += int(stats[k])
		stats[k] = 0
	save()

## Bonus from the points in a stat (e.g. stat_bonus("health") = extra max HP).
static func stat_bonus(key: String) -> float:
	return float(stats.get(key, 0)) * float(STAT_PER_POINT.get(key, 0.0))

# ------------------------------------------------------------------ bloodline mastery
## Mastery XP needed to go from level `lv` to `lv + 1` (about 35k XP to reach LV 1000).
static func mastery_needed(lv: int) -> int:
	return 10 + lv / 20

static var _mastery_table: PackedInt32Array = PackedInt32Array()

## Total XP needed to reach each level, built once.
static func _table() -> PackedInt32Array:
	if _mastery_table.is_empty():
		_mastery_table.resize(MASTERY_MAX + 1)
		var total := 0
		for lv in MASTERY_MAX + 1:
			_mastery_table[lv] = total
			total += mastery_needed(lv)
	return _mastery_table

static func mastery_level(id: String) -> int:
	if id == "none" or id == "":
		return 0
	var x := int(mastery.get(id, 0))
	var t := _table()
	var lo := 0
	var hi := MASTERY_MAX
	while lo < hi:   # highest level whose total is <= x
		var mid := (lo + hi + 1) / 2
		if t[mid] <= x:
			lo = mid
		else:
			hi = mid - 1
	return lo

## [xp into the current level, xp needed for the next level] (both 0 at max).
static func mastery_progress(id: String) -> Array:
	var lv := mastery_level(id)
	if lv >= MASTERY_MAX:
		return [0, 0]
	return [int(mastery.get(id, 0)) - _table()[lv], mastery_needed(lv)]

## Adds mastery XP; returns [old level, new level].
static func add_mastery(id: String, n: int) -> Array:
	if id == "none" or id == "" or n <= 0:
		return [0, 0]
	var old := mastery_level(id)
	mastery[id] = mini(int(mastery.get(id, 0)) + n, _table()[MASTERY_MAX])
	return [old, mastery_level(id)]

## Sets a bloodline straight to a mastery level (cheats / testing).
static func set_mastery_level(id: String, lv: int) -> void:
	mastery[id] = _table()[clampi(lv, 0, MASTERY_MAX)]
	save()

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
