class_name ElementData
extends RefCounted
## Element styles (Shindo Life style). Each element has 4 abilities that unlock as that element levels up
## (element mastery, separate from bloodline mastery). There is no power-up for elements.
## Ability fields are the same as in bloodline.gd (kind, dmg, r, n, ...). Extra:
##   kind "custom" + fn  - runs a hand-made jutsu in player.gd (the original Fire Style moves)
##   fire_cost: true     - cost is scaled by the bloodline's fireball discount (Uchiha, Sarutobi)
## Colours come from GameData.ELEMENT_COLORS. Icons: assets/icons/el_<element>_<n>.png (or set "icon").

const UNLOCK_LEVELS := [0, 20, 60, 120]

const DEFS := {
	"Fire": [
		{"name": "Fireball", "kind": "custom", "fn": "_fx_fireball", "cost": 30.0, "cd": 1.0, "fire_cost": true,
			"desc": "Explodes on impact: 45 damage in a 5 m radius."},
		{"name": "Phoenix Flowers", "kind": "custom", "fn": "_fx_phoenix", "cost": 35.0, "cd": 5.0,
			"desc": "Fires 5 small fireballs in a fan."},
		{"name": "Flame Wave", "kind": "custom", "fn": "_fx_flame_wave", "cost": 45.0, "cd": 8.0,
			"desc": "A burst of fire around you: 40 damage and knockback."},
		{"name": "Dragon Flame", "kind": "custom", "fn": "_fx_dragon", "cost": 60.0, "cd": 12.0,
			"desc": "A huge homing fire dragon: 90 damage in an 8 m blast."}],
	"Earth": [
		{"name": "Mud Bullet", "kind": "fan", "n": 1, "speed": 26.0, "dmg": 45.0, "aoe": 4.0, "size": 0.55, "cost": 30.0, "cd": 1.5,
			"desc": "A heavy ball of mud that bursts on impact."},
		{"name": "Rock Avalanche", "kind": "burst", "r": 9.0, "dmg": 40.0, "knock": 12.0, "stun": 1.0, "cost": 40.0, "cd": 7.0,
			"desc": "Boulders crash down around you."},
		{"name": "Stone Skin", "kind": "buff", "t": 6.0, "def": 0.4, "cost": 40.0, "cd": 18.0,
			"desc": "6s: take 60% less damage."},
		{"name": "Earth Dragon", "kind": "homing", "n": 1, "dmg": 100.0, "aoe": 7.0, "size": 0.9, "cost": 60.0, "cd": 12.0,
			"desc": "A dragon of rock hunts the nearest enemy."}],
	"Lightning": [
		{"name": "Lightning Bolt", "kind": "fan", "n": 1, "speed": 50.0, "dmg": 40.0, "aoe": 2.5, "size": 0.3, "long": true, "cost": 30.0, "cd": 1.5,
			"desc": "A fast bolt of lightning."},
		{"name": "Thunder Clap", "kind": "burst", "r": 8.0, "dmg": 30.0, "stun": 1.5, "cost": 40.0, "cd": 7.0,
			"desc": "A shock that stuns enemies around you."},
		{"name": "Chain Lightning", "kind": "homing", "n": 4, "dmg": 30.0, "aoe": 1.5, "size": 0.25, "cost": 45.0, "cd": 9.0,
			"desc": "Four sparks jump to the nearest enemies."},
		{"name": "Kirin", "kind": "target", "r": 25.0, "dmg": 160.0, "stun": 1.5, "cost": 60.0, "cd": 14.0,
			"desc": "A lightning beast strikes the nearest enemy from the sky."}],
	"Water": [
		{"name": "Water Bullet", "kind": "fan", "n": 1, "speed": 30.0, "dmg": 40.0, "aoe": 3.0, "size": 0.5, "cost": 30.0, "cd": 1.5,
			"desc": "A splashing water shot."},
		{"name": "Water Wave", "kind": "cone", "r": 10.0, "dmg": 35.0, "knock": 22.0, "dot": 0.2, "cost": 40.0, "cd": 7.0,
			"desc": "A wave that washes away everything in front of you."},
		{"name": "Water Sharks", "kind": "homing", "n": 2, "dmg": 50.0, "aoe": 3.0, "size": 0.4, "cost": 45.0, "cd": 9.0,
			"desc": "Two sharks hunt nearby enemies."},
		{"name": "Water Dragon", "kind": "homing", "n": 1, "dmg": 110.0, "aoe": 7.0, "size": 0.9, "cost": 60.0, "cd": 12.0,
			"desc": "A great water dragon crashes into the nearest enemy."}],
	"Wind": [
		{"name": "Wind Blades", "kind": "fan", "n": 3, "spread": 10.0, "speed": 40.0, "dmg": 18.0, "size": 0.2, "long": true, "cost": 30.0, "cd": 1.5,
			"desc": "Three cutting blades of wind."},
		{"name": "Vacuum Wave", "kind": "burst", "r": 10.0, "dmg": 35.0, "knock": 20.0, "cost": 40.0, "cd": 7.0,
			"desc": "A blast of air that throws enemies back."},
		{"name": "Gale Palm", "kind": "cone", "r": 12.0, "dmg": 45.0, "knock": 30.0, "dot": 0.3, "cost": 45.0, "cd": 9.0,
			"desc": "A huge gust in front of you."},
		{"name": "Tornado", "kind": "aura", "t": 5.0, "r": 7.0, "dps": 20.0, "cost": 60.0, "cd": 14.0,
			"desc": "5s: a tornado around you shreds enemies within 7m."}],
}

static func count(element: String) -> int:
	return (DEFS.get(element, []) as Array).size()

## Ability `i` of an element with every field filled in (same shape as Bloodline.ability()).
static func ability(element: String, i: int) -> Dictionary:
	var list: Array = DEFS.get(element, [])
	if i < 0 or i >= list.size():
		return {}
	var a: Dictionary = Bloodline.ABILITY_DEFAULTS.duplicate()
	a.merge({"lvl": UNLOCK_LEVELS[mini(i, UNLOCK_LEVELS.size() - 1)], "cost": 30.0, "cd": 5.0,
		"col": GameData.get_element_color(element), "fn": "", "fire_cost": false}, true)
	a.merge(list[i], true)
	return a
