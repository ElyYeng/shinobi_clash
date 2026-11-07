class_name Hero
extends RefCounted
## Loads the character model you drop into res://assets/ (.glb / .gltf),
## auto-fits it to the player's size and maps its animations by name.

const ASSET_DIR := "res://assets/naruto"
const TARGET_HEIGHT := 1.75
const CREDIT := 'Model: "Naruto Rigged (HatchXR)" by nitwit.friends (CC-BY-4.0)'
const MANUAL_SCALE := 0.0        # set >0 to override auto-scale
const YAW_OFFSET := PI           # glTF models face +Z; set to 0.0 if yours faces away from movement

# Animation-name keywords (lowercase). Edit these if your animations are named differently.
const KEYWORDS := {
	"idle": ["stand", "idle", "wait", "breath"],
	"run": ["run", "sprint", "jog"],
	"walk": ["walk"],
	"jump": ["jumpup", "jump"],
	"fall": ["jumpdown", "fall"],
	"strafe_l": ["strafeleft", "strafe_left"],
	"strafe_r": ["straferight", "strafe_right"],
	"attack": ["punch", "attack", "kick", "slash", "combo", "fight", "melee"],
	"throw": ["throw", "kunai", "shoot"],
	"jutsu": ["jutsu", "seal", "cast", "special", "skill", "rasen", "charge"],
	"dash": ["dash", "dodge", "roll", "evade"],
	"hurt": ["hurt", "damage", "react", "flinch"],
	"die": ["die", "death", "dead", "defeat", "knock"],
}
const FALLBACKS := {
	"walk": ["run"], "run": ["walk"], "dash": ["run"],
	"throw": ["attack"], "jutsu": ["throw", "attack"], "jump": ["idle"], "fall": ["jump"],
	"strafe_l": ["run"], "strafe_r": ["run"],
}

static var _scene: PackedScene = null
static var _searched := false
static var _printed := false
static var credit := ""

## Returns a Node3D wrapper (forward = -Z, feet at y=0) or null if no model found.
static func create() -> Node3D:
	if not _searched:
		_searched = true
		var path := _scan(ASSET_DIR, 2)
		if path != "":
			_scene = load(path) as PackedScene
			print("[Hero] loaded model: ", path)
			credit = CREDIT
		else:
			print("[Hero] no .glb/.gltf in res://assets - using placeholder model")
	if _scene == null:
		return null
	var inst := _scene.instantiate() as Node3D
	if inst == null:
		return null
	var wrapper := Node3D.new()
	var fixer := Node3D.new()
	fixer.rotation.y = YAW_OFFSET
	wrapper.add_child(fixer)
	fixer.add_child(inst)
	_fit(fixer, inst)
	Fx.toonify_model(inst)
	_setup_anims(wrapper, inst)
	return wrapper

static func _scan(dir_path: String, depth: int) -> String:
	var d := DirAccess.open(dir_path)
	if d == null:
		return ""
	for f in d.get_files():
		var n := f.trim_suffix(".import").trim_suffix(".remap")
		var ext := n.get_extension().to_lower()
		if ext == "glb" or ext == "gltf":
			var full := dir_path.path_join(n)
			if ResourceLoader.exists(full):
				return full
	if depth > 0:
		for sub in d.get_directories():
			var r := _scan(dir_path.path_join(sub), depth - 1)
			if r != "":
				return r
	return ""

static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

static func _fit(fixer: Node3D, inst: Node3D) -> void:
	var box := AABB()
	var first := true
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := _rel(mi, fixer) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	print("[Hero] measured model height (m): ", box.size.y)
	if box.size.y < 0.3 or box.size.y > 5.0:
		push_warning("[Hero] suspicious model size - leaving scale at 1.0. Set MANUAL_SCALE in hero.gd.")
		return
	var s := MANUAL_SCALE if MANUAL_SCALE > 0.0 else TARGET_HEIGHT / maxf(box.size.y, 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(
		-(box.position.x + box.size.x / 2.0) * s,
		-box.position.y * s,
		-(box.position.z + box.size.z / 2.0) * s)

static func _setup_anims(wrapper: Node3D, inst: Node3D) -> void:
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		print("[Hero] model has no AnimationPlayer")
		return
	var ap := aps[0] as AnimationPlayer
	var list := ap.get_animation_list()
	if not _printed:
		print("[Hero] animations found: ", list)
	var map := {}
	for state in KEYWORDS:
		var found: Array = []
		for kw in KEYWORDS[state]:
			for nm in list:
				var low := String(nm).to_lower()
				if low == "reset":
					continue
				if low.contains(kw) and not found.has(String(nm)):
					found.append(String(nm))
		if not found.is_empty():
			map[state] = found
	if map.is_empty() and list.size() > 0:
		map["idle"] = [String(list[0])]
		print("[Hero] no names matched KEYWORDS; using first animation as idle. Edit KEYWORDS in hero.gd")
	for st in ["idle", "run", "walk", "strafe_l", "strafe_r"]:
		if map.has(st):
			for nm in map[st]:
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	if not _printed:
		print("[Hero] animation map: ", map)
		_printed = true
	wrapper.set_meta("anim_player", ap)
	wrapper.set_meta("anim_map", map)

static func _lookup(map: Dictionary, state: String) -> Array:
	if map.has(state):
		return map[state]
	for fb in FALLBACKS.get(state, []):
		if map.has(fb):
			return map[fb]
	return []

## Plays an animation state; returns its length (0.0 if the model has none).
static func play(model: Node3D, state: String, force := false, variant := 0, fit_time := 0.0) -> float:
	if model == null or not model.has_meta("anim_player"):
		return 0.0
	var ap := model.get_meta("anim_player") as AnimationPlayer
	if not is_instance_valid(ap):
		return 0.0
	var names: Array = _lookup(model.get_meta("anim_map"), state)
	if names.is_empty():
		return 0.0
	var nm: String = names[variant % names.size()]
	if not force and ap.current_animation == nm and ap.is_playing():
		return ap.get_animation(nm).length
	ap.play(nm, 0.15)
	var l := ap.get_animation(nm).length
	ap.speed_scale = 1.0
	if fit_time > 0.0 and l > fit_time:
		ap.speed_scale = minf(l / fit_time, 3.0)
	if force:
		ap.seek(0.0, true)
	return l
