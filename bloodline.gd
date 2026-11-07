class_name Bloodline
extends RefCounted
## Bloodline definitions. stats keys: hp, chakra (add) | speed, regen, dmg, fire_cost, dash_cost (mult)
## clone_count, clone_time, hp_regen (add). The active ability is on C (tap) / X and runs in player.gd _use_ability().
## weight = relative roll chance (any positive number; the ODDS panel shows the real %).
## Rarity tiers: Common < Rare < Epic < Legendary < Mythic.

const DEFS := {
	"none": {"name": "No Bloodline", "rarity": "Common", "weight": 0, "color": Color(0.7, 0.7, 0.7),
		"desc": "A plain shinobi. Spin to awaken a bloodline!", "stats": {},
		"ability": "", "ability_name": "", "ability_cost": 0.0, "ability_cd": 0.0},

	# ---------------- Common (45%)
	"inuzuka": {"name": "Inuzuka", "rarity": "Common", "weight": 15, "color": Color(0.85, 0.65, 0.4),
		"desc": "Feral instincts: +15% move speed.", "stats": {"speed": 1.15},
		"ability": "", "ability_name": "", "ability_cost": 0.0, "ability_cd": 0.0},
	"akimichi": {"name": "Akimichi", "rarity": "Common", "weight": 15, "color": Color(0.9, 0.5, 0.3),
		"desc": "Hardy body: +50 max health.", "stats": {"hp": 50.0},
		"ability": "", "ability_name": "", "ability_cost": 0.0, "ability_cd": 0.0},
	"sarutobi": {"name": "Sarutobi", "rarity": "Common", "weight": 15, "color": Color(0.55, 0.42, 0.25),
		"desc": "Fire lineage: fireball costs 15% less.\nC - Staff Sweep: a wide swing that smashes enemies in front of you away.",
		"stats": {"fire_cost": 0.85},
		"ability": "staff_sweep", "ability_name": "Staff Sweep", "ability_cost": 20.0, "ability_cd": 7.0},

	# ---------------- Rare (30%)
	"nara": {"name": "Nara", "rarity": "Rare", "weight": 7.5, "color": Color(0.5, 0.45, 0.8),
		"desc": "Strategist: chakra regens 50% faster.\nC - Shadow Bind: freezes nearby enemies for 4s.",
		"stats": {"regen": 1.5},
		"ability": "shadow_bind", "ability_name": "Shadow Bind", "ability_cost": 35.0, "ability_cd": 12.0},
	"hyuga": {"name": "Hyuga", "rarity": "Rare", "weight": 7.5, "color": Color(0.75, 0.85, 1.0),
		"desc": "Precise strikes: +15% damage, dash costs half.\nC - Gentle Burst: chakra shockwave around you.",
		"stats": {"dmg": 1.15, "dash_cost": 0.5},
		"ability": "gentle_burst", "ability_name": "Gentle Burst", "ability_cost": 30.0, "ability_cd": 8.0},
	"aburame": {"name": "Aburame", "rarity": "Rare", "weight": 5, "color": Color(0.35, 0.45, 0.3),
		"desc": "Hive body: +20 max chakra.\nC - Insect Swarm: a bug cloud follows you for 5s, chewing enemies within 6m.",
		"stats": {"chakra": 20.0},
		"ability": "insect_swarm", "ability_name": "Insect Swarm", "ability_cost": 30.0, "ability_cd": 12.0},
	"yamanaka": {"name": "Yamanaka", "rarity": "Rare", "weight": 5, "color": Color(0.95, 0.75, 0.85),
		"desc": "Focused mind: chakra regens 25% faster.\nC - Mind Burst: shatters the nearest enemy's mind - heavy damage and a 4s stun.",
		"stats": {"regen": 1.25},
		"ability": "mind_burst", "ability_name": "Mind Burst", "ability_cost": 30.0, "ability_cd": 9.0},
	"hozuki": {"name": "Hozuki", "rarity": "Rare", "weight": 5, "color": Color(0.4, 0.75, 0.95),
		"desc": "Liquid body: slowly regenerates health.\nC - Hydrification: turn to water - immune to damage for 4s and heal 30.",
		"stats": {"hp_regen": 1.0},
		"ability": "hydrify", "ability_name": "Hydrification", "ability_cost": 30.0, "ability_cd": 16.0},

	# ---------------- Epic (15%)
	"senju": {"name": "Senju", "rarity": "Epic", "weight": 4, "color": Color(0.3, 0.9, 0.4),
		"desc": "Vitality: +60 max health, constant regeneration.\nC - Regeneration: heal quickly for 5s.",
		"stats": {"hp": 60.0, "hp_regen": 2.0},
		"ability": "regen", "ability_name": "Regeneration", "ability_cost": 25.0, "ability_cd": 20.0},
	"kaguya": {"name": "Kaguya", "rarity": "Epic", "weight": 4, "color": Color(0.95, 0.93, 0.85),
		"desc": "Bone warrior: +10% damage, +20 max health.\nC - Bone Spikes: 12 bone spears burst out in every direction.",
		"stats": {"dmg": 1.1, "hp": 20.0},
		"ability": "bone_spikes", "ability_name": "Bone Spikes", "ability_cost": 30.0, "ability_cd": 9.0},
	"hoshigaki": {"name": "Hoshigaki", "rarity": "Epic", "weight": 3.5, "color": Color(0.25, 0.45, 0.75),
		"desc": "Tailless beast: +60 max chakra.\nC - Shark Bombs: 4 water sharks hunt the nearest enemies and explode.",
		"stats": {"chakra": 60.0},
		"ability": "shark_bombs", "ability_name": "Shark Bombs", "ability_cost": 35.0, "ability_cd": 10.0},
	"yuki": {"name": "Yuki", "rarity": "Epic", "weight": 3.5, "color": Color(0.7, 0.92, 1.0),
		"desc": "Ice release: +8% move speed, dash costs 30% less.\nC - Ice Prison: freezes every enemy within 12m solid for 4s.",
		"stats": {"speed": 1.08, "dash_cost": 0.7},
		"ability": "ice_prison", "ability_name": "Ice Prison", "ability_cost": 40.0, "ability_cd": 14.0},

	# ---------------- Legendary (8.5%)
	"uzumaki": {"name": "Uzumaki", "rarity": "Legendary", "weight": 2.5, "color": Color(1.0, 0.45, 0.15),
		"desc": "Huge chakra: +50 max, 2x regen, 4 clones that last longer.\nC - Chakra Surge: +50% damage, +25% speed for 8s.",
		"stats": {"chakra": 50.0, "regen": 2.0, "clone_count": 2, "clone_time": 6.0},
		"ability": "chakra_surge", "ability_name": "Chakra Surge", "ability_cost": 20.0, "ability_cd": 20.0},
	"uchiha": {"name": "Uchiha", "rarity": "Legendary", "weight": 2.5, "color": Color(0.9, 0.1, 0.15),
		"desc": "Fire prodigy: +20% damage, fireball costs 40% less.\nC - Sharingan: enemies slowed to 35% speed for 6s.",
		"stats": {"dmg": 1.2, "fire_cost": 0.6},
		"ability": "sharingan", "ability_name": "Sharingan", "ability_cost": 35.0, "ability_cd": 15.0},
	"hatake": {"name": "Hatake", "rarity": "Legendary", "weight": 2, "color": Color(0.55, 0.8, 1.0),
		"desc": "Copy ninja: +15% damage, chakra regens 30% faster.\nC - Lightning Blade: dash forward through enemies, striking everything in your path.",
		"stats": {"dmg": 1.15, "regen": 1.3},
		"ability": "lightning_blade", "ability_name": "Lightning Blade", "ability_cost": 30.0, "ability_cd": 8.0},
	"chinoike": {"name": "Chinoike", "rarity": "Legendary", "weight": 1.5, "color": Color(0.6, 0.02, 0.08),
		"desc": "Blood clan: +40 max health, slow regeneration.\nC - Blood Rage: +40% damage for 7s and enemies within 8m bleed.",
		"stats": {"hp": 40.0, "hp_regen": 1.0},
		"ability": "blood_rage", "ability_name": "Blood Rage", "ability_cost": 30.0, "ability_cd": 18.0},

	# ---------------- Mythic (1.5%)
	"otsutsuki": {"name": "Otsutsuki", "rarity": "Mythic", "weight": 1.5, "color": Color(0.85, 0.8, 1.0),
		"desc": "Celestial: +50 max health and chakra, +25% damage, 1.5x chakra regen.\nC - Truth-Seeking Orbs: 6 black orbs hunt down enemies and explode.",
		"stats": {"hp": 50.0, "chakra": 50.0, "dmg": 1.25, "regen": 1.5},
		"ability": "truth_orbs", "ability_name": "Truth-Seeking Orbs", "ability_cost": 40.0, "ability_cd": 12.0},
}

const TOP_TIERS := ["Legendary", "Mythic"]   # what the pity guarantee can land on

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["none"])

static func roll(guarantee_legendary: bool) -> String:
	var pool: Array[String] = []
	var total := 0.0
	for id in DEFS:
		if id == "none":
			continue
		if guarantee_legendary and not TOP_TIERS.has(DEFS[id]["rarity"]):
			continue
		pool.append(id)
		total += float(DEFS[id]["weight"])
	var r := randf() * total
	for id in pool:
		r -= float(DEFS[id]["weight"])
		if r <= 0.0:
			return id
	return pool[pool.size() - 1]
