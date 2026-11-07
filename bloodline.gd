class_name Bloodline
extends RefCounted
## Bloodline definitions. stats keys: hp, chakra (add) | speed, regen, dmg, fire_cost, dash_cost (mult)
## clone_count, clone_time, hp_regen (add). Active ability is bound to X.

const DEFS := {
	"none": {"name": "No Bloodline", "rarity": "Common", "weight": 0, "color": Color(0.7, 0.7, 0.7),
		"desc": "A plain shinobi. Spin to awaken a bloodline!", "stats": {},
		"ability": "", "ability_name": "", "ability_cost": 0.0, "ability_cd": 0.0},
	"inuzuka": {"name": "Inuzuka", "rarity": "Common", "weight": 22, "color": Color(0.85, 0.65, 0.4),
		"desc": "Feral instincts: +15% move speed.", "stats": {"speed": 1.15},
		"ability": "", "ability_name": "", "ability_cost": 0.0, "ability_cd": 0.0},
	"akimichi": {"name": "Akimichi", "rarity": "Common", "weight": 22, "color": Color(0.9, 0.5, 0.3),
		"desc": "Hardy body: +50 max health.", "stats": {"hp": 50.0},
		"ability": "", "ability_name": "", "ability_cost": 0.0, "ability_cd": 0.0},
	"nara": {"name": "Nara", "rarity": "Rare", "weight": 15, "color": Color(0.5, 0.45, 0.8),
		"desc": "Strategist: chakra regens 50% faster.\nX - Shadow Bind: freezes nearby enemies for 4s.",
		"stats": {"regen": 1.5},
		"ability": "shadow_bind", "ability_name": "Shadow Bind", "ability_cost": 35.0, "ability_cd": 12.0},
	"hyuga": {"name": "Hyuga", "rarity": "Rare", "weight": 15, "color": Color(0.75, 0.85, 1.0),
		"desc": "Precise strikes: +15% damage, dash costs half.\nX - Gentle Burst: chakra shockwave around you.",
		"stats": {"dmg": 1.15, "dash_cost": 0.5},
		"ability": "gentle_burst", "ability_name": "Gentle Burst", "ability_cost": 30.0, "ability_cd": 8.0},
	"senju": {"name": "Senju", "rarity": "Epic", "weight": 14, "color": Color(0.3, 0.9, 0.4),
		"desc": "Vitality: +60 max health, constant regeneration.\nX - Regeneration: heal quickly for 5s.",
		"stats": {"hp": 60.0, "hp_regen": 2.0},
		"ability": "regen", "ability_name": "Regeneration", "ability_cost": 25.0, "ability_cd": 20.0},
	"uzumaki": {"name": "Uzumaki", "rarity": "Legendary", "weight": 6, "color": Color(1.0, 0.45, 0.15),
		"desc": "Huge chakra: +50 max, 2x regen, 4 clones that last longer.\nX - Chakra Surge: +50% damage, +25% speed for 8s.",
		"stats": {"chakra": 50.0, "regen": 2.0, "clone_count": 2, "clone_time": 6.0},
		"ability": "chakra_surge", "ability_name": "Chakra Surge", "ability_cost": 20.0, "ability_cd": 20.0},
	"uchiha": {"name": "Uchiha", "rarity": "Legendary", "weight": 6, "color": Color(0.9, 0.1, 0.15),
		"desc": "Fire prodigy: +20% damage, fireball costs 40% less.\nX - Sharingan: enemies slowed to 35% speed for 6s.",
		"stats": {"dmg": 1.2, "fire_cost": 0.6},
		"ability": "sharingan", "ability_name": "Sharingan", "ability_cost": 35.0, "ability_cd": 15.0},
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["none"])

static func roll(guarantee_legendary: bool) -> String:
	var pool: Array[String] = []
	var total := 0.0
	for id in DEFS:
		if id == "none":
			continue
		if guarantee_legendary and DEFS[id]["rarity"] != "Legendary":
			continue
		pool.append(id)
		total += float(DEFS[id]["weight"])
	var r := randf() * total
	for id in pool:
		r -= float(DEFS[id]["weight"])
		if r <= 0.0:
			return id
	return pool[pool.size() - 1]
