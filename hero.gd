class_name Hero
extends RefCounted
## Loads the character model you drop into res://assets/ (.glb / .gltf),
## auto-fits it to the player's size and maps its animations by name.

const ASSET_DIR := "res://assets/character"
const CUSTOM_MODEL_FILE := "character_main.glb"
const LEGACY_ASSET_DIR := "res://assets/naruto"
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
static var _using_custom_model := false
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
			_using_custom_model = _scene != null
			if _using_custom_model:
				print("[Hero] loaded user's main Mixamo character: ", custom_path)
				credit = CREDIT
		else:
			_scene = null
			_using_custom_model = false
			push_warning("[Hero] User Mixamo GLB not found. Install character.glb under res://assets/character/. Current characters will use the temporary placeholder.")
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
	if _using_custom_model:
		_apply_custom_model_parts(inst, chosen)
	else:
		_apply_wearables(inst, chosen)
	return wrapper


## The supplied GLB contains two hair meshes, two shirt meshes and two pants
## meshes, all authored for the same Mixamo skeleton. Toggle the actual meshes
## instead of adding primitive clothing overlays.
static func _resolve_custom_model_path() -> String:
	var candidates := [
		ASSET_DIR.path_join(CUSTOM_MODEL_FILE),
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

## Experimental modular wearables for the existing rig. These are separate
## meshes attached to the character's actual bones, so they follow its animations.
## Replace the primitive meshes with authored skinned clothing assets as the art
## pipeline grows; the saved appearance format stays the same.
static func _apply_wearables(inst: Node3D, appearance: Dictionary) -> void:
	var skeletons := inst.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("[Hero] Character rig has no Skeleton3D; skipping wearable overlays.")
		return
	var skeleton := skeletons[0] as Skeleton3D
	var unit_scale := 1.0 / maxf(absf(inst.scale.x), 0.00001)
	var hair := Color.from_string(str(appearance.get("hair_color", "#20202A")), Color(0.12, 0.12, 0.16))
	var top := Color.from_string(str(appearance.get("top_color", "#D65A24")), Color(0.84, 0.35, 0.14))
	var pants := Color.from_string(str(appearance.get("pants_color", "#343C52")), Color(0.2, 0.23, 0.32))
	var shoes := Color.from_string(str(appearance.get("shoes_color", "#20202A")), Color(0.12, 0.12, 0.16))
	var band := Color.from_string(str(appearance.get("headband_color", "#343C52")), Color(0.2, 0.23, 0.32))
	var style := str(appearance.get("hair_style", "spiky"))

	# Hair cap and hairstyle variations are parented to the head bone.
	var hair_attachment := _make_bone_attachment(skeleton, ["Head_06", "Head"], "Wear_Hair")
	if hair_attachment != null:
		var cap := SphereMesh.new()
		cap.radius = 0.18 * unit_scale
		cap.height = 0.27 * unit_scale
		_add_wear_mesh(hair_attachment, "HairCap", cap, hair, Vector3(0, 0.11, 0) * unit_scale, Vector3.ZERO)
		if style == "spiky":
			var spike_positions := [
				Vector3(-0.10, 0.22, 0.00), Vector3(-0.04, 0.26, 0.03),
				Vector3(0.04, 0.25, 0.02), Vector3(0.11, 0.20, 0.00),
				Vector3(0.00, 0.24, -0.08)
			]
			for i in spike_positions.size():
				var spike := CylinderMesh.new()
				spike.top_radius = 0.0
				spike.bottom_radius = 0.075 * unit_scale
				spike.height = 0.25 * unit_scale
				_add_wear_mesh(hair_attachment, "HairSpike%d" % i, spike, hair, spike_positions[i] * unit_scale, Vector3(0.0, 0.0, deg_to_rad(float(i - 2) * 12.0)))
		elif style == "ponytail":
			var tail := CapsuleMesh.new()
			tail.radius = 0.075 * unit_scale
			tail.height = 0.42 * unit_scale
			_add_wear_mesh(hair_attachment, "Ponytail", tail, hair, Vector3(0, -0.13, -0.17) * unit_scale, Vector3(0.35, 0, 0))

	# A thin forehead band can be toggled and recolored independently.
	if bool(appearance.get("show_headband", true)):
		var head_attachment := _make_bone_attachment(skeleton, ["Head_06", "Head"], "Wear_Headband")
		if head_attachment != null:
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(0.38, 0.055, 0.08) * unit_scale
			_add_wear_mesh(head_attachment, "Headband", band_mesh, band, Vector3(0, 0.035, 0.165) * unit_scale, Vector3.ZERO)

	# Chest piece and sleeves follow the torso and arm bones.
	var torso_attachment := _make_bone_attachment(skeleton, ["Spine2_04", "Spine1_03", "Spine"], "Wear_Top")
	if torso_attachment != null:
		var torso := CapsuleMesh.new()
		torso.radius = 0.255 * unit_scale
		torso.height = 0.72 * unit_scale
		_add_wear_mesh(torso_attachment, "JacketTorso", torso, top, Vector3(0, -0.15, 0) * unit_scale, Vector3.ZERO)
	for arm_token in ["LeftArm_09", "RightArm_033"]:
		var arm_attachment := _make_bone_attachment(skeleton, [arm_token, "LeftArm" if arm_token.begins_with("Left") else "RightArm"], "Wear_Sleeve_" + arm_token)
		if arm_attachment != null:
			var sleeve := CapsuleMesh.new()
			sleeve.radius = 0.095 * unit_scale
			sleeve.height = 0.42 * unit_scale
			_add_wear_mesh(arm_attachment, "Sleeve", sleeve, top.darkened(0.12), Vector3(0, -0.18, 0) * unit_scale, Vector3.ZERO)

	# Pants and sandals follow each leg/foot independently.
	for leg_token in ["LeftUpLeg_056", "RightUpLeg_00"]:
		var leg_attachment := _make_bone_attachment(skeleton, [leg_token, "UpLeg"], "Wear_Pants_" + leg_token)
		if leg_attachment != null:
			var leg := CapsuleMesh.new()
			leg.radius = 0.14 * unit_scale
			leg.height = 0.58 * unit_scale
			_add_wear_mesh(leg_attachment, "TrouserLeg", leg, pants, Vector3(0, -0.23, 0) * unit_scale, Vector3.ZERO)
	for foot_token in ["LeftFoot_058", "RightFoot_062"]:
		var foot_attachment := _make_bone_attachment(skeleton, [foot_token, "Foot"], "Wear_Shoe_" + foot_token)
		if foot_attachment != null:
			var shoe := BoxMesh.new()
			shoe.size = Vector3(0.23, 0.13, 0.36) * unit_scale
			_add_wear_mesh(foot_attachment, "NinjaSandal", shoe, shoes, Vector3(0, -0.045, 0.075) * unit_scale, Vector3.ZERO)

static func _make_bone_attachment(skeleton: Skeleton3D, tokens: Array, node_name: String) -> BoneAttachment3D:
	var bone_index := -1
	for token in tokens:
		for i in skeleton.get_bone_count():
			if skeleton.get_bone_name(i).to_lower().contains(str(token).to_lower()):
				bone_index = i
				break
		if bone_index >= 0:
			break
	if bone_index < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	skeleton.add_child(attachment)
	attachment.bone_name = skeleton.get_bone_name(bone_index)
	return attachment

static func _add_wear_mesh(parent: Node3D, node_name: String, mesh: Mesh, color: Color, offset: Vector3, rotation: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = mesh
	part.position = offset
	part.rotation = rotation
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.0
	part.material_override = material
	parent.add_child(part)

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
