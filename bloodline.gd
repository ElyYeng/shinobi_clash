class_name Bloodline
extends RefCounted
## Bloodline definitions (Shindo Life style).
##
## Every bloodline has:
##   stats      passive bonuses while equipped:
##              hp, chakra (add) | speed, regen, dmg, fire_cost, dash_cost (mult) | clone_count, clone_time, hp_regen (add)
##   abilities  3 moves on keys 1 / 2 / 3, unlocked at bloodline (mastery) levels UNLOCK_LEVELS (or "lvl")
##   mode       the power-up on C, unlocked at bloodline LV 1000. It has no timer: it drains MD and ends
##              when MD is empty or you press C again.
## weight = relative roll chance (the ODDS panel in the spin menu shows the real %).
## Rarity tiers: Common < Rare < Epic < Legendary < Mythic.
##
## Ability fields (anything left out uses ABILITY_DEFAULTS / the per-slot cost and cooldown):
##   kind:  burst  - hits everything within r around you          (dmg, knock, stun)
##          cone   - hits everything within r in front of you     (dmg, knock, stun, dot = how wide, 0..1)
##          target - hits the nearest enemy within r              (dmg, stun)
##          fan    - fires n projectiles spread degrees apart      (n, spread, speed, dmg, aoe, size, long)
##          homing - n projectiles that hunt the nearest enemies  (n, dmg, aoe, size)
##          dash   - dashes dist metres, hitting everything on the line (dist, dmg)
##          buff   - lasts t seconds: dmg / speed (mult), def (damage taken mult), hp / ck (regen per s),
##                   immune, slow (enemy speed mult), r + dps (damage aura around you)
##          aura   - damage aura for t seconds (r, dps)
##   heal: instant health   |   col: effect colour (defaults to the bloodline colour)
## Mode fields: name, desc, dmg, speed, def, hp, ck, slow, cd (cooldown mult), r + dps (aura), col.

const UNLOCK_LEVELS := [0, 250, 600]
const MODE_LEVEL := 1000
const SLOT_COST := [25.0, 35.0, 50.0]
const SLOT_CD := [8.0, 12.0, 18.0]
const ABILITY_DEFAULTS := {"kind": "burst", "r": 0.0, "dmg": 0.0, "knock": 0.0, "stun": 0.0, "dot": 0.4,
	"n": 1, "spread": 10.0, "speed": 30.0, "aoe": 0.0, "size": 0.25, "long": false, "dist": 10.0,
	"t": 0.0, "def": 1.0, "hp": 0.0, "ck": 0.0, "immune": false, "slow": 1.0, "dps": 0.0, "heal": 0.0, "desc": ""}
const MODE_DEFAULTS := {"name": "Power-Up", "desc": "", "dmg": 1.0, "speed": 1.0, "def": 1.0, "hp": 0.0, "ck": 0.0,
	"slow": 1.0, "cd": 1.0, "r": 0.0, "dps": 0.0}
const TOP_TIERS := ["Legendary", "Mythic"]   # what the pity guarantee can land on

const DEFS := {
	"none": {"name": "No Bloodline", "rarity": "Common", "weight": 0, "color": Color(0.7, 0.7, 0.7),
		"desc": "A plain shinobi. Spin to awaken a bloodline!", "stats": {}, "abilities": [], "mode": {}},

	# ================================================================ Common (45%)
	"inuzuka": {"name": "Inuzuka", "rarity": "Common", "weight": 15, "color": Color(0.85, 0.65, 0.4),
		"desc": "Feral instincts: +15% move speed.", "stats": {"speed": 1.15},
		"abilities": [
			{"name": "Fang Over Fang", "kind": "dash", "dist": 11.0, "dmg": 35.0, "desc": "Spin forward like a drill, hitting everything in your path."},
			{"name": "Beast Howl", "kind": "burst", "r": 8.0, "dmg": 15.0, "stun": 2.0, "desc": "A howl that stuns enemies around you."},
			{"name": "Wild Instinct", "kind": "buff", "t": 8.0, "speed": 1.35, "dmg": 1.2, "desc": "8s: +35% speed and +20% damage."}],
		"mode": {"name": "Beast Mimicry", "dmg": 1.2, "speed": 1.35, "desc": "+20% damage, +35% speed."}},
	"akimichi": {"name": "Akimichi", "rarity": "Common", "weight": 15, "color": Color(0.9, 0.5, 0.3),
		"desc": "Hardy body: +50 max health.", "stats": {"hp": 50.0},
		"abilities": [
			{"name": "Human Boulder", "kind": "dash", "dist": 12.0, "dmg": 45.0, "desc": "Roll forward as a giant boulder."},
			{"name": "Expansion Palm", "kind": "cone", "r": 7.0, "dmg": 50.0, "knock": 20.0, "dot": 0.3, "desc": "A giant palm swats everything in front of you."},
			{"name": "Calorie Control", "kind": "buff", "t": 8.0, "def": 0.6, "hp": 4.0, "dmg": 1.15, "desc": "8s: take 40% less damage, heal 4/s, +15% damage."}],
		"mode": {"name": "Butterfly Mode", "dmg": 1.4, "def": 0.7, "hp": 3.0, "desc": "+40% damage, take 30% less damage, heal 3/s."}},
	"sarutobi": {"name": "Sarutobi", "rarity": "Common", "weight": 15, "color": Color(0.55, 0.42, 0.25),
		"desc": "Fire lineage: fireball costs 15% less.", "stats": {"fire_cost": 0.85},
		"abilities": [
			{"name": "Staff Sweep", "kind": "cone", "r": 9.0, "dmg": 45.0, "knock": 18.0, "desc": "A wide swing that smashes enemies in front of you away."},
			{"name": "Ash Cloud", "kind": "burst", "r": 9.0, "dmg": 20.0, "stun": 2.0, "col": Color(0.45, 0.42, 0.4), "desc": "Burning ash chokes and stuns nearby enemies."},
			{"name": "Monkey King Barrage", "kind": "fan", "n": 7, "spread": 12.0, "speed": 30.0, "dmg": 25.0, "aoe": 1.5, "size": 0.3, "desc": "Seven exploding fire shots."}],
		"mode": {"name": "Monkey King Mode", "dmg": 1.3, "def": 0.8, "speed": 1.1, "desc": "+30% damage, take 20% less damage, +10% speed."}},

	# ================================================================ Rare (30%)
	"nara": {"name": "Nara", "rarity": "Rare", "weight": 7.5, "color": Color(0.5, 0.45, 0.8),
		"desc": "Strategist: chakra regens 50% faster.", "stats": {"regen": 1.5},
		"abilities": [
			{"name": "Shadow Bind", "kind": "burst", "r": 14.0, "stun": 4.0, "col": Color(0.25, 0.1, 0.4), "desc": "Freezes every enemy within 14m for 4s."},
			{"name": "Shadow Strangle", "kind": "target", "r": 16.0, "dmg": 60.0, "stun": 2.0, "col": Color(0.25, 0.1, 0.4), "desc": "Shadow hands choke the nearest enemy."},
			{"name": "Shadow Web", "kind": "burst", "r": 20.0, "dmg": 30.0, "stun": 5.0, "col": Color(0.25, 0.1, 0.4), "desc": "A huge web of shadows pins everything within 20m."}],
		"mode": {"name": "Shadow Domain", "slow": 0.7, "ck": 15.0, "dmg": 1.15, "desc": "Enemies move 30% slower, +15 chakra/s, +15% damage."}},
	"hyuga": {"name": "Hyuga", "rarity": "Rare", "weight": 7.5, "color": Color(0.75, 0.85, 1.0),
		"desc": "Precise strikes: +15% damage, dash costs half.", "stats": {"dmg": 1.15, "dash_cost": 0.5},
		"abilities": [
			{"name": "Gentle Burst", "kind": "burst", "r": 7.0, "dmg": 40.0, "knock": 15.0, "desc": "A chakra shockwave around you."},
			{"name": "Air Palm", "kind": "fan", "n": 1, "speed": 40.0, "dmg": 45.0, "aoe": 2.0, "size": 0.45, "desc": "Fires a blast of compressed air."},
			{"name": "64 Palms", "kind": "target", "r": 6.0, "dmg": 120.0, "stun": 2.5, "desc": "Close range: 64 strikes on the nearest enemy."}],
		"mode": {"name": "Byakugan", "dmg": 1.3, "def": 0.85, "slow": 0.85, "desc": "+30% damage, take 15% less damage, enemies 15% slower."}},
	"aburame": {"name": "Aburame", "rarity": "Rare", "weight": 5, "color": Color(0.35, 0.45, 0.3),
		"desc": "Hive body: +20 max chakra.", "stats": {"chakra": 20.0},
		"abilities": [
			{"name": "Insect Swarm", "kind": "aura", "t": 5.0, "r": 6.0, "dps": 10.0, "col": Color(0.15, 0.2, 0.1), "desc": "5s: a bug cloud chews enemies within 6m."},
			{"name": "Bug Bullets", "kind": "homing", "n": 5, "dmg": 25.0, "aoe": 1.5, "size": 0.25, "col": Color(0.15, 0.2, 0.1), "desc": "Five beetles hunt nearby enemies."},
			{"name": "Hive Sphere", "kind": "buff", "t": 6.0, "def": 0.5, "r": 5.0, "dps": 15.0, "col": Color(0.15, 0.2, 0.1), "desc": "6s: a bug shell halves damage and bites enemies within 5m."}],
		"mode": {"name": "Kikaichu Host", "dmg": 1.1, "r": 7.0, "dps": 12.0, "desc": "+10% damage and a constant bug swarm (7m)."}},
	"yamanaka": {"name": "Yamanaka", "rarity": "Rare", "weight": 5, "color": Color(0.95, 0.75, 0.85),
		"desc": "Focused mind: chakra regens 25% faster.", "stats": {"regen": 1.25},
		"abilities": [
			{"name": "Mind Burst", "kind": "target", "r": 18.0, "dmg": 70.0, "stun": 4.0, "desc": "Heavy damage and a 4s stun on the nearest enemy."},
			{"name": "Mind Disturbance", "kind": "burst", "r": 10.0, "dmg": 10.0, "stun": 3.0, "desc": "Confuses every enemy within 10m."},
			{"name": "Mind Destruction", "kind": "target", "r": 20.0, "dmg": 160.0, "stun": 3.0, "desc": "Shatters the nearest enemy's mind."}],
		"mode": {"name": "Mind Link", "ck": 20.0, "cd": 0.6, "dmg": 1.15, "desc": "+20 chakra/s, cooldowns 40% faster, +15% damage."}},
	"hozuki": {"name": "Hozuki", "rarity": "Rare", "weight": 5, "color": Color(0.4, 0.75, 0.95),
		"desc": "Liquid body: slowly regenerates health.", "stats": {"hp_regen": 1.0},
		"abilities": [
			{"name": "Hydrification", "kind": "buff", "t": 4.0, "immune": true, "heal": 30.0, "desc": "Turn to water: immune for 4s and heal 30."},
			{"name": "Water Gun", "kind": "fan", "n": 3, "spread": 8.0, "speed": 38.0, "dmg": 30.0, "size": 0.2, "long": true, "desc": "Three high-pressure water shots."},
			{"name": "Great Water Arm", "kind": "cone", "r": 8.0, "dmg": 70.0, "knock": 22.0, "desc": "A swollen arm smashes everything in front."}],
		"mode": {"name": "Hydro Form", "def": 0.5, "hp": 4.0, "dmg": 1.15, "desc": "Take 50% less damage, heal 4/s, +15% damage."}},

	# ================================================================ Epic (15%)
	"senju": {"name": "Senju", "rarity": "Epic", "weight": 4, "color": Color(0.3, 0.9, 0.4),
		"desc": "Vitality: +60 max health, constant regeneration.", "stats": {"hp": 60.0, "hp_regen": 2.0},
		"abilities": [
			{"name": "Regeneration", "kind": "buff", "t": 5.0, "hp": 8.0, "desc": "5s: heal 8 health per second."},
			{"name": "Wood Spikes", "kind": "burst", "r": 9.0, "dmg": 45.0, "knock": 6.0, "stun": 1.0, "desc": "Wooden spikes erupt around you."},
			{"name": "Deep Forest", "kind": "burst", "r": 16.0, "dmg": 35.0, "stun": 4.0, "desc": "A forest bursts out and binds everything within 16m."}],
		"mode": {"name": "Sage of the Forest", "hp": 6.0, "def": 0.7, "dmg": 1.25, "desc": "Heal 6/s, take 30% less damage, +25% damage."}},
	"kaguya": {"name": "Kaguya", "rarity": "Epic", "weight": 4, "color": Color(0.95, 0.93, 0.85),
		"desc": "Bone warrior: +10% damage, +20 max health.", "stats": {"dmg": 1.1, "hp": 20.0},
		"abilities": [
			{"name": "Bone Spikes", "kind": "fan", "n": 12, "spread": 30.0, "speed": 26.0, "dmg": 30.0, "size": 0.2, "long": true, "desc": "12 bone spears burst out in every direction."},
			{"name": "Bone Drill", "kind": "dash", "dist": 10.0, "dmg": 60.0, "desc": "Lunge forward with a drill of bone."},
			{"name": "Bracken Dance", "kind": "burst", "r": 12.0, "dmg": 65.0, "knock": 10.0, "stun": 1.5, "desc": "A field of bone blades erupts around you."}],
		"mode": {"name": "Curse Mark", "dmg": 1.4, "speed": 1.15, "def": 0.85, "desc": "+40% damage, +15% speed, take 15% less damage."}},
	"hoshigaki": {"name": "Hoshigaki", "rarity": "Epic", "weight": 3.5, "color": Color(0.25, 0.45, 0.75),
		"desc": "Tailless beast: +60 max chakra.", "stats": {"chakra": 60.0},
		"abilities": [
			{"name": "Shark Bombs", "kind": "homing", "n": 4, "dmg": 50.0, "aoe": 2.5, "size": 0.4, "col": Color(0.2, 0.5, 1.0), "desc": "4 water sharks hunt enemies and explode."},
			{"name": "Water Prison", "kind": "target", "r": 14.0, "dmg": 30.0, "stun": 5.0, "col": Color(0.2, 0.5, 1.0), "desc": "Traps the nearest enemy in a water sphere for 5s."},
			{"name": "Thousand Sharks", "kind": "homing", "n": 10, "dmg": 35.0, "aoe": 2.0, "size": 0.35, "col": Color(0.2, 0.5, 1.0), "desc": "A school of 10 sharks."}],
		"mode": {"name": "Samehada Fusion", "ck": 25.0, "def": 0.75, "dmg": 1.25, "desc": "+25 chakra/s, take 25% less damage, +25% damage."}},
	"yuki": {"name": "Yuki", "rarity": "Epic", "weight": 3.5, "color": Color(0.7, 0.92, 1.0),
		"desc": "Ice release: +8% move speed, dash costs 30% less.", "stats": {"speed": 1.08, "dash_cost": 0.7},
		"abilities": [
			{"name": "Ice Prison", "kind": "burst", "r": 12.0, "dmg": 25.0, "stun": 4.0, "desc": "Freezes every enemy within 12m for 4s."},
			{"name": "Ice Needles", "kind": "fan", "n": 9, "spread": 8.0, "speed": 34.0, "dmg": 18.0, "size": 0.15, "long": true, "desc": "A spread of nine ice needles."},
			{"name": "Demonic Mirrors", "kind": "burst", "r": 10.0, "dmg": 90.0, "stun": 2.0, "desc": "A dome of ice mirrors shreds everything within 10m."}],
		"mode": {"name": "Hyoton Mode", "slow": 0.6, "dmg": 1.2, "speed": 1.1, "desc": "Enemies move 40% slower, +20% damage, +10% speed."}},

	# ================================================================ Legendary (8.5%)
	"uzumaki": {"name": "Uzumaki", "rarity": "Legendary", "weight": 2.5, "color": Color(1.0, 0.45, 0.15),
		"desc": "Huge chakra: +50 max, 2x regen, 4 clones that last longer.",
		"stats": {"chakra": 50.0, "regen": 2.0, "clone_count": 2, "clone_time": 6.0},
		"abilities": [
			{"name": "Chakra Surge", "kind": "buff", "t": 8.0, "dmg": 1.5, "speed": 1.25, "ck": 30.0, "desc": "8s: +50% damage, +25% speed, +30 chakra/s."},
			{"name": "Sealing Chains", "kind": "burst", "r": 14.0, "dmg": 30.0, "stun": 4.5, "knock": -10.0, "desc": "Chains pull every enemy within 14m in and bind them."},
			{"name": "Rasenshuriken", "kind": "fan", "n": 1, "speed": 26.0, "dmg": 140.0, "aoe": 5.0, "size": 0.6, "col": Color(0.6, 0.85, 1.0), "desc": "A wind shuriken that explodes in a 5m storm."}],
		"mode": {"name": "Kurama Ink Mode", "dmg": 1.4, "speed": 1.25, "def": 0.7, "ck": 20.0, "hp": 3.0,
			"col": Color(1.0, 0.78, 0.3),
			# Recolours the character while the power-up is on (see Hero.apply_mode_look).
			"look": {"glow": "#E3D79A", "under": "#2B261A", "energy": 0.25, "flat": true}, "desc": "+40% damage, +25% speed, take 30% less damage, +20 chakra/s, heal 3/s."}},
	"uchiha": {"name": "Uchiha", "rarity": "Legendary", "weight": 2.5, "color": Color(0.9, 0.1, 0.15),
		"desc": "Fire prodigy: +20% damage, fireball costs 40% less.", "stats": {"dmg": 1.2, "fire_cost": 0.6},
		"abilities": [
			{"name": "Genjutsu Glare", "kind": "buff", "t": 6.0, "slow": 0.35, "dmg": 1.25, "desc": "6s: enemies slowed to 35% speed, +25% damage."},
			{"name": "Amaterasu", "kind": "target", "r": 20.0, "dmg": 110.0, "stun": 1.0, "col": Color(0.05, 0.02, 0.05), "desc": "Black flames engulf the nearest enemy."},
			{"name": "Susanoo Arrow", "kind": "fan", "n": 1, "speed": 50.0, "dmg": 150.0, "aoe": 3.0, "size": 0.5, "long": true, "col": Color(0.6, 0.3, 1.0), "desc": "A giant chakra arrow."}],
		"mode": {"name": "Sharingan", "dmg": 1.3, "slow": 0.75, "speed": 1.1,
			"look": {"eyes": "res://assets/character/character_main_T_CHR_Eye_Sharingan.png"}, "desc": "+30% damage, enemies 25% slower, +10% speed."}},
	"hatake": {"name": "Hatake", "rarity": "Legendary", "weight": 2, "color": Color(0.55, 0.8, 1.0),
		"desc": "Copy ninja: +15% damage, chakra regens 30% faster.", "stats": {"dmg": 1.15, "regen": 1.3},
		"abilities": [
			{"name": "Lightning Blade", "kind": "dash", "dist": 12.0, "dmg": 80.0, "desc": "Dash through enemies, striking everything in your path."},
			{"name": "Lightning Hound", "kind": "homing", "n": 1, "dmg": 90.0, "aoe": 3.0, "size": 0.45, "desc": "A lightning hound hunts the nearest enemy."},
			{"name": "Kamui", "kind": "target", "r": 20.0, "dmg": 150.0, "stun": 1.0, "col": Color(0.25, 0.1, 0.35), "desc": "Warps away a chunk of the nearest enemy."}],
		"mode": {"name": "Copy Wheel Eye", "dmg": 1.25, "cd": 0.6, "ck": 15.0, "desc": "+25% damage, cooldowns 40% faster, +15 chakra/s."}},
	"chinoike": {"name": "Chinoike", "rarity": "Legendary", "weight": 1.5, "color": Color(0.6, 0.02, 0.08),
		"desc": "Blood clan: +40 max health, slow regeneration.", "stats": {"hp": 40.0, "hp_regen": 1.0},
		"abilities": [
			{"name": "Blood Rage", "kind": "buff", "t": 7.0, "dmg": 1.4, "r": 8.0, "dps": 12.0, "desc": "7s: +40% damage and enemies within 8m bleed."},
			{"name": "Blood Spears", "kind": "fan", "n": 5, "spread": 14.0, "speed": 32.0, "dmg": 35.0, "size": 0.2, "long": true, "desc": "Five spears of hardened blood."},
			{"name": "Ketsuryugan", "kind": "burst", "r": 14.0, "dmg": 40.0, "stun": 3.5, "desc": "A blood-red glare paralyses everything within 14m."}],
		"mode": {"name": "Ketsuryugan Awakening", "dmg": 1.35, "hp": 3.0, "r": 6.0, "dps": 10.0, "desc": "+35% damage, heal 3/s, enemies within 6m bleed."}},

	# ================================================================ Mythic (1.5%)
	"otsutsuki": {"name": "Otsutsuki", "rarity": "Mythic", "weight": 1.5, "color": Color(0.85, 0.8, 1.0),
		"desc": "Celestial: +50 max health and chakra, +25% damage, 1.5x chakra regen.",
		"stats": {"hp": 50.0, "chakra": 50.0, "dmg": 1.25, "regen": 1.5},
		"abilities": [
			{"name": "Truth-Seeking Orbs", "kind": "homing", "n": 6, "dmg": 70.0, "aoe": 2.0, "size": 0.35, "col": Color(0.06, 0.04, 0.1), "desc": "6 black orbs hunt down enemies and explode."},
			{"name": "Amenominaka", "kind": "burst", "r": 18.0, "dmg": 100.0, "knock": 25.0, "stun": 2.0, "desc": "Bends space: blasts everything within 18m."},
			{"name": "Ash Killing Bones", "kind": "fan", "n": 5, "spread": 10.0, "speed": 45.0, "dmg": 90.0, "aoe": 2.0, "size": 0.25, "long": true, "desc": "Five bones that turn targets to ash."}],
		"mode": {"name": "Six Paths", "dmg": 1.5, "def": 0.6, "speed": 1.25, "ck": 25.0, "hp": 5.0, "slow": 0.85,
			"desc": "+50% damage, take 40% less damage, +25% speed, +25 chakra/s, heal 5/s, enemies 15% slower."}},
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["none"])

## Ability `i` (0..2) of a bloodline with every field filled in, plus "lvl", "cost", "cd", "col".
static func ability(id: String, i: int) -> Dictionary:
	var def := get_def(id)
	var list: Array = def["abilities"]
	if i < 0 or i >= list.size():
		return {}
	var a: Dictionary = ABILITY_DEFAULTS.duplicate()
	a.merge({"lvl": UNLOCK_LEVELS[i], "cost": SLOT_COST[i], "cd": SLOT_CD[i], "col": def["color"]}, true)
	a.merge(list[i], true)
	return a

## The bloodline's power-up mode with every field filled in ({} for no bloodline).
static func mode(id: String) -> Dictionary:
	var def := get_def(id)
	if (def["mode"] as Dictionary).is_empty():
		return {}
	var m: Dictionary = MODE_DEFAULTS.duplicate()
	m["col"] = def["color"]
	m.merge(def["mode"], true)
	return m

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
