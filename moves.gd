class_name Moves
extends RefCounted
## Every move you can put on a hotbar key, and the keybinds (Shindo Life style).
##
## Move ids:
##   "bl:<bloodline>:<0-2>"   a bloodline ability   (usable while that bloodline is equipped)
##   "el:<Element>:<0-3>"     an element ability    (usable when you own the element)
##   "base:<name>"            always available (clones, substitution, armor)
## Each must also be unlocked by mastery level (bloodline LV / element LV).
##
## Images: a move shows res://assets/icons/<id with ':' -> '_'>.png if it exists
## (e.g. bl_uchiha_2.png, el_fire_0.png, base_clones.png, mode_uchiha.png),
## or the file named by an "icon" field in its data. Drop in your own PNG to replace one.

## Hotbar keys you can assign moves to.
const BIND_KEYS := ["R", "T", "Y", "F", "G", "H", "V", "B", "N"]
const DEFAULT_BINDS := {"R": "el:Fire:0", "T": "el:Fire:1", "Y": "el:Fire:2", "F": "base:clones",
	"G": "el:Fire:3", "H": "base:armor", "V": "base:sub", "B": "", "N": ""}
const ICON_DIR := "res://assets/icons/"

const BASE := {
	"clones": {"name": "Shadow Clones", "kind": "custom", "fn": "_fx_clones", "cost": 40.0, "cd": 6.0,
		"col": Color(0.3, 0.6, 1.0), "desc": "Summons clones that fight for you (more with Uzumaki)."},
	"sub": {"name": "Substitution", "kind": "custom", "fn": "_fx_sub", "cost": 25.0, "cd": 10.0,
		"col": Color(0.7, 0.6, 0.4), "desc": "Swap with a log: land behind the nearest enemy, or back off. Short invulnerability."},
	"armor": {"name": "Element Armor", "kind": "custom", "fn": "_fx_armor", "cost": 40.0, "cd": 20.0,
		"col": Color(0.95, 0.5, 0.15), "desc": "6s: take 60% less damage. Glows in your element's colour."},
}

static var _tex_cache := {}

## Full data for a move ({} if the id is unknown). Adds: id, src ("bl" / "el" / "base"),
## owner (bloodline id / element name), mkey (mastery key), icon (path).
static func spec(id: String) -> Dictionary:
	if id == "":
		return {}
	var parts := id.split(":")
	var s: Dictionary = {}
	match parts[0]:
		"bl":
			if parts.size() < 3:
				return {}
			s = Bloodline.ability(parts[1], int(parts[2]))
			if s.is_empty():
				return {}
			s.merge({"src": "bl", "owner": parts[1], "mkey": parts[1]}, true)
		"el":
			if parts.size() < 3:
				return {}
			s = ElementData.ability(parts[1], int(parts[2]))
			if s.is_empty():
				return {}
			s.merge({"src": "el", "owner": parts[1], "mkey": "el:" + parts[1]}, true)
		"base":
			if not BASE.has(parts[1]):
				return {}
			s = Bloodline.ABILITY_DEFAULTS.duplicate()
			s.merge({"lvl": 0, "fn": "", "fire_cost": false}, true)
			s.merge(BASE[parts[1]], true)
			s.merge({"src": "base", "owner": "", "mkey": ""}, true)
		_:
			return {}
	if not s.has("fn"):
		s["fn"] = ""
	if not s.has("fire_cost"):
		s["fire_cost"] = false
	s["id"] = id
	if not s.has("icon") or str(s["icon"]) == "":
		s["icon"] = icon_path(id)
	return s

## The move's own data as written (no defaults filled in), used for buffs so unset fields mean "no change".
static func raw(id: String) -> Dictionary:
	var parts := id.split(":")
	match parts[0]:
		"bl":
			var list: Array = Bloodline.get_def(parts[1])["abilities"]
			return list[int(parts[2])] if int(parts[2]) < list.size() else {}
		"el":
			var el: Array = ElementData.DEFS.get(parts[1], [])
			return el[int(parts[2])] if int(parts[2]) < el.size() else {}
		"base":
			return BASE.get(parts[1], {})
	return {}

static func icon_path(id: String) -> String:
	return ICON_DIR + id.replace(":", "_").to_lower() + ".png"

## Why a move can't be used right now ("" = it can). Ignores cooldown and chakra.
static func block(id: String) -> String:
	var s := spec(id)
	if s.is_empty():
		return "Empty"
	match str(s["src"]):
		"bl":
			var bname: String = Bloodline.get_def(s["owner"])["name"]
			if not GameData.is_equipped(s["owner"]):
				return "Equip %s (main or 2nd) to use this" % bname
			var lv := GameData.mastery_level(s["owner"])
			if lv < int(s["lvl"]):
				return "Needs %s LV %d (now %d)" % [bname, int(s["lvl"]), lv]
		"el":
			if not GameData.owned_elements.has(s["owner"]):
				return "%s not owned - roll it at the main menu" % s["owner"]
			var elv := GameData.mastery_level(s["mkey"])
			if elv < int(s["lvl"]):
				return "Needs %s LV %d (now %d)" % [s["owner"], int(s["lvl"]), elv]
	return ""

## Texture for a path, or null if there is no image. Works for imported and plain PNG files.
static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t

static func icon(id: String) -> Texture2D:
	var s := spec(id)
	return tex(str(s["icon"])) if not s.is_empty() else null

## The power-up icon of a bloodline (mode_<id>.png).
static func mode_icon(bloodline: String) -> Texture2D:
	return tex(ICON_DIR + "mode_%s.png" % bloodline)
