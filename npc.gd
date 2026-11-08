class_name Npc
extends StaticBody3D
## A villager standing in the open world. Shows "!" when it has a quest and "?" when you can turn one in.

var npc_id := ""
var display_name := "Villager"
var body_color := Color(0.3, 0.5, 0.7)
var band_color := Color(0.9, 0.9, 0.9)
var greeting := "Hello."
var model_path := ""        # .glb / .gltf / .tscn; empty = placeholder ninja
var model_height := 1.85
var model_yaw_deg := 180.0
var outline := true
var label_y := 2.6
var model: Node3D
var marker: Label3D

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.9
	col.shape = cap
	col.position.y = 0.95
	add_child(col)
	model = _load_model()
	if model == null:
		model = Fx.make_ninja(body_color, band_color)
	add_child(model)
	var nl := Label3D.new()
	nl.text = display_name
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nl.no_depth_test = true
	nl.font_size = 40
	nl.outline_size = 10
	nl.pixel_size = 0.005
	nl.position.y = label_y
	add_child(nl)
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.font_size = 96
	marker.outline_size = 18
	marker.pixel_size = 0.01
	marker.position.y = label_y + 0.8
	add_child(marker)
	set_marker("")

## Loads a real character model (also used by NpcSpawn for its editor preview).
func _load_model() -> Node3D:
	var m := Npc.build_model(model_path, model_height, model_yaw_deg, outline, display_name)
	if m != null:
		label_y = float(m.get_meta("label_y", label_y))
	return m

## Builds a character model: scaled to `height`, feet on the ground, first animation looped as idle.
## Returns null if there is no model. The name-tag height is stored in meta "label_y".
static func build_model(path: String, height: float, yaw_deg: float, use_outline: bool, who := "") -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		if path != "":
			push_warning("[Npc] %s: model not found: %s" % [who, path])
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	var wrapper := Node3D.new()
	var fixer := Node3D.new()
	fixer.rotation.y = deg_to_rad(yaw_deg)
	wrapper.add_child(fixer)
	fixer.add_child(inst)
	var box := AABB()
	var first := true
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# Skinned meshes are posed by their bones, which already undo any armature scale
		# (common in Blender exports), so their own bounds are the real size.
		var skinned := mi.skin != null or mi.skeleton != NodePath("")
		var b := mi.get_aabb() if skinned else Hero._rel(mi, fixer) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if not first and box.size.y > 0.001:
		var sc := height / box.size.y
		inst.scale *= sc
		inst.position = Vector3(-(box.position.x + box.size.x / 2.0) * sc, -box.position.y * sc, -(box.position.z + box.size.z / 2.0) * sc)
		wrapper.set_meta("label_y", height + 0.55)
	Fx.toonify_model(inst, use_outline)
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		var ap := aps[0] as AnimationPlayer
		for nm in ap.get_animation_list():
			if String(nm).to_lower() != "reset":
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
				ap.play(nm)
				break
	return wrapper

func set_marker(text: String, color := Color(1.0, 0.9, 0.2)) -> void:
	marker.text = text
	marker.modulate = color
	marker.visible = text != ""

func _process(delta: float) -> void:
	if marker.visible:
		marker.position.y = label_y + 0.8 + sin(Time.get_ticks_msec() / 300.0) * 0.12
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() < 9.0 and to.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), 6.0 * delta)
