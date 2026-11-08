class_name Hero
extends RefCounted
## Loads the character model you drop into res://assets/ (.glb / .gltf),
## auto-fits it to the player's size and maps its animations by name.

const ASSET_DIR := "res://assets/character"
const CUSTOM_MODEL_FILE := "character_main.glb"
const TARGET_HEIGHT := 1.75
const CREDIT := "Character model: supplied custom Mixamo rig"
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
static func create(appearance: Dictionary = {}) -> Node3D:
	if not _searched:
		_searched = true
		var custom_path := _resolve_custom_model_path()
		# The user's Mixamo rig is the only supported main character model.
		# Check the standardized filename first, then earlier names used in setup instructions.
		if custom_path != "":
			_scene = load(custom_path) as PackedScene
			if _using_custom_model:
				print("[Hero] loaded user's main Mixamo character: ", custom_path)
				credit = CREDIT
		else:
			_scene = null
			push_warning("[Hero] User Mixamo GLB not found. Install character_main.glb under res://assets/character/. Current characters will use the temporary placeholder.")
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
	var chosen := appearance if not appearance.is_empty() else GameData.character_appearance
	_apply_custom_model_parts(inst, chosen)
	return wrapper


## The supplied GLB contains two hair meshes, two shirt meshes and two pants
## meshes, all authored for the same Mixamo skeleton. Toggle the actual meshes
## instead of adding primitive clothing overlays.
static func _resolve_custom_model_path() -> String:
	var candidates := [
		ASSET_DIR.path_join(CUSTOM_MODEL_FILE),
		ASSET_DIR.path_join("character.glb"),
		ASSET_DIR.path_join("character costum test1(3).glb"),
		ASSET_DIR.path_join("character costum test1(2).glb"),
		ASSET_DIR.path_join("character costum test1.glb")
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""


static func _find_mesh(root: Node, mesh_id: String, old_node_name: String = "") -> MeshInstance3D:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null:
			continue
		var resource_id := part.mesh.resource_name.to_lower()
		if resource_id == mesh_id.to_lower() or (old_node_name != "" and part.name == old_node_name):
			return part
	return null


## Uses the exact mesh resource names exported in the latest user-supplied GLB:
## hair1/hair2, shirt1/shirt2, pants1/pants2. Each skinned part shares the Mixamo rig.
static func _apply_custom_model_parts(inst: Node3D, appearance: Dictionary) -> void:
	var hair_choice := str(appearance.get("hair_style", "short"))
	var hair_1 := _find_mesh(inst, "hair1", "SK_CHR_Man_ShortSpikyHair_05mo")
	var hair_2 := _find_mesh(inst, "hair2", "SK_CHR_Man_SpikyHair_08mo")
	if hair_1 != null:
		hair_1.visible = hair_choice == "short" or hair_choice == "hair_1"
		_tint_mesh(hair_1, Color.from_string(str(appearance.get("hair_color", "#E6B52E")), Color(0.9, 0.72, 0.2)))
	if hair_2 != null:
		hair_2.visible = not (hair_choice == "short" or hair_choice == "hair_1")
		_tint_mesh(hair_2, Color.from_string(str(appearance.get("hair_color", "#E6B52E")), Color(0.9, 0.72, 0.2)))

	var shirt_choice := str(appearance.get("shirt_style", "shirt_1"))
	if shirt_choice == "shirt_a":
		shirt_choice = "shirt_1"
	elif shirt_choice == "shirt_b":
		shirt_choice = "shirt_2"
	var shirt_1 := _find_mesh(inst, "shirt1", "Mesh_0147.rip.053")
	var shirt_2 := _find_mesh(inst, "shirt2", "Male_Lobby_Top_Cos_NB_Yellow")
	if shirt_1 != null:
		shirt_1.visible = shirt_choice == "shirt_1"
	if shirt_2 != null:
		shirt_2.visible = shirt_choice == "shirt_2"

	var pants_choice := str(appearance.get("pants_style", "pants_1"))
	if pants_choice == "pants_a":
		pants_choice = "pants_1"
	elif pants_choice == "pants_b":
		pants_choice = "pants_2"
	var pants_1 := _find_mesh(inst, "pants1", "Mesh_0147.rip.110")
	var pants_2 := _find_mesh(inst, "pants2", "Male_Lobby_Bottom_Cos_NB_Yellow")
	if pants_1 != null:
		pants_1.visible = pants_choice == "pants_1"
	if pants_2 != null:
		pants_2.visible = pants_choice == "pants_2"

	# Keep the user's face, rear-head and footwear meshes as authored.
	var shoes := _find_mesh(inst, "shoes", "Mesh_0145.rip")
	if shoes != null:
		shoes.visible = true
	for required_name in ["hair1", "hair2", "shirt1", "shirt2", "pants1", "pants2"]:
		var found := false
		for node in inst.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			if part.mesh != null and part.mesh.resource_name.to_lower() == required_name:
				found = true
				break
		if not found:
			push_warning("[Hero] Expected customization mesh '%s' was not found in the imported GLB." % required_name)


static func _tint_mesh(mesh_instance: MeshInstance3D, tint: Color) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.get_active_material(surface)
		var material := source.duplicate() as BaseMaterial3D if source is BaseMaterial3D else StandardMaterial3D.new()
		material.albedo_color = tint
		mesh_instance.set_surface_override_material(surface, material)

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
