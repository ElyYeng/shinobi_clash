class_name GenjutsuWorld
extends Node3D
## The paralysis genjutsu's dimension. EDIT IT IN THE EDITOR: res://maps/genjutsu_world.tscn
## (sky, blood moon + glow, mountains, floor, cross, moon light, and two markers: VictimSpot =
## where the victim is bound, CasterSpot = where the caster starts). `dark` is the environment the
## camera uses while inside (darkness, fog, glow) - tweak it in the Inspector.
## Built far below the map; only the players in the genjutsu see it.

const SCENE := "res://maps/genjutsu_world.tscn"
const ORIGIN := Vector3(0, -900, 0)

@export var dark: Environment   ## the look while inside (the camera's environment)
@export var silhouette_color := Color(0.085, 0.0, 0.01)   ## mountains, trees, cross
@export var ground_color := Color(0.06, 0.0, 0.008)       ## the water / floor

var caster_fig: Node3D          # (victim) the caster, walking around in here
var caster_peer := 0
var anchor := Vector3.ZERO      # the victim's body in the real world
var master := false             # built for the caster (who walks around freely in here)
var master_off := Vector3(0, 0, -5.1)   # (victim) where the caster is, relative to you
var master_yaw := PI
var _cams: Array = []           # cameras we darkened (restored on exit)

## caster_look: the caster's appearance (the victim sees them in here; master = built for the caster).
static func build(world: Node3D, caster_look: Dictionary, caster := 0, body := Vector3.ZERO, is_master := false) -> GenjutsuWorld:
	var ps := load(SCENE) as PackedScene
	var g: GenjutsuWorld = ps.instantiate() as GenjutsuWorld if ps != null else GenjutsuWorld.new()
	g.name = "GenjutsuWorld"
	g.caster_peer = caster
	g.anchor = body
	g.master = is_master
	world.add_child(g)
	g.global_position = ORIGIN
	if not is_master and not caster_look.is_empty():
		g._add_caster(caster_look)
	g._go_dark(world)
	g._silhouettes()
	return g

## The whole place is flat silhouettes against the red sky (the fog gives the depth). Everything
## except the sky, the moon and its glow - characters keep their own shading.
func _silhouettes() -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.name in ["Sky", "BloodMoon", "MoonGlow"]:
			continue
		var col := ground_color if str(mi.name).begins_with("Water") or mi.get_parent().name == "Floor" else silhouette_color
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = col
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if src != null and src.albedo_texture != null and src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				m.albedo_texture = src.albedo_texture   # (the trees: keep the cut-out shape)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4
			mi.set_surface_override_material(i, m)
		mi.material_override = null
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _add_caster(look: Dictionary) -> void:
	var c := Hero.create(look)
	if c == null:
		return
	add_child(c)
	var cs := get_node_or_null("CasterSpot") as Node3D
	c.position = cs.position if cs != null else Vector3(0, 0.2, -4.5)
	c.rotation.y = PI   # (models face -Z: turned to face the victim at +Z)
	Hero.apply_appearance(c, look)
	var eyes: String = str(Bloodline.mode("uchiha").get("look", {}).get("eyes", ""))
	if eyes != "":
		Hero.set_eyes(c, Moves.tex(eyes))   # Sharingan, staring at you
	Hero.play(c, "idle")
	caster_fig = c

## Inside, the camera uses the genjutsu's own dark environment and the real sun is switched off.
func _go_dark(world: Node3D) -> void:
	_world = world
	for l in world.get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if not is_ancestor_of(l) and (l as Light3D).visible and not l.has_meta("gen_hidden"):
			(l as Light3D).visible = false
			l.set_meta("gen_hidden", true)   # (marked: whoever leaves last turns it back on)
	var cam := get_viewport().get_camera_3d()
	if cam != null and dark != null:
		if not cam.has_meta("gen_env"):
			cam.set_meta("gen_env", cam.environment if cam.environment != null else false)
		cam.environment = dark
		_cams.append(cam)

var _world: Node3D

## Leaving: put the real world's light and the camera back exactly as they were - unless another
## genjutsu world is still open here.
func _exit_tree() -> void:
	restore_world(_world, self)

static func restore_world(world: Node, leaving: Node = null) -> void:
	if world == null or not is_instance_valid(world):
		return
	for g in world.find_children("GenjutsuWorld*", "Node3D", true, false):
		if g != leaving and g is GenjutsuWorld and not g.is_queued_for_deletion():
			return   # still inside another one
	var root := world.get_tree().root
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l.has_meta("gen_hidden"):
			(l as Light3D).visible = true
			l.remove_meta("gen_hidden")
	for c in root.find_children("*", "Camera3D", true, false):
		if c.has_meta("gen_env"):
			var e = c.get_meta("gen_env")
			(c as Camera3D).environment = e if e is Environment else null
			c.remove_meta("gen_env")

## Height of the cross bar (the bound victim's shoulders go here).
func bar_y() -> float:
	var bar := get_node_or_null("Cross2") as Node3D
	return bar.global_position.y if bar != null else victim_spot().y + 3.1

## Bound to the cross: lifted up so the shoulders are at the bar (`bar`, world height), arms
## straight out in a T-pose, no animations until unbound (Hero.play skips a bound model).
static func bind(model: Node3D, bar := INF) -> void:
	if model == null or not is_instance_valid(model):
		return
	if not model.has_meta("gen_bound"):
		model.set_meta("gen_y", model.position.y)
	model.set_meta("gen_bound", true)
	if model.has_meta("anim_player"):
		var ap = model.get_meta("anim_player")
		if ap is AnimationPlayer and is_instance_valid(ap):
			(ap as AnimationPlayer).stop()
	for sk: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		sk.reset_bone_poses()
		var shoulder := INF
		for side in ["Left", "Right"]:   # the rest pose is an A-pose: straighten each arm out sideways
			var chain: Array[int] = []
			for part in ["Arm", "ForeArm", "Hand", "HandMiddle1"]:
				chain.append(_bone(sk, side + part))
			if chain[0] < 0 or chain[1] < 0:
				continue
			var out := Vector3(signf((_gpose(sk, chain[1]).origin - _gpose(sk, chain[0]).origin).x), 0, 0)
			for k in 3:
				if chain[k] < 0 or chain[k + 1] < 0:
					break
				var g := _gpose(sk, chain[k])
				var cur := ((g * sk.get_bone_pose(chain[k + 1])).origin - g.origin).normalized()
				if cur.length() < 0.5 or cur.is_equal_approx(out):
					continue
				var want := Basis(Quaternion(cur, out)) * g.basis   # (turned in skeleton space)
				var par := sk.get_bone_parent(chain[k])
				var pb := _gpose(sk, par).basis if par >= 0 else Basis()
				sk.set_bone_pose_rotation(chain[k], (pb.inverse() * want).get_rotation_quaternion())
			if sk.is_inside_tree():
				shoulder = (sk.global_transform * _gpose(sk, chain[0]).origin).y
		if bar != INF and shoulder != INF:   # up onto the cross
			model.global_position.y += bar - shoulder

## A bone's pose in skeleton space, from the local poses (always current, unlike the cached one).
static func _gpose(sk: Skeleton3D, b: int) -> Transform3D:
	var t := Transform3D()
	while b >= 0:
		t = sk.get_bone_pose(b) * t
		b = sk.get_bone_parent(b)
	return t

static func _bone(sk: Skeleton3D, n: String) -> int:
	var i := sk.find_bone("mixamorig_" + n)
	if i < 0:
		i = sk.find_bone("mixamorig:" + n)
	return i if i >= 0 else sk.find_bone(n)

static func unbind(model: Node3D) -> void:
	if model == null or not is_instance_valid(model) or not model.has_meta("gen_bound"):
		return
	model.remove_meta("gen_bound")
	model.position.y = float(model.get_meta("gen_y", model.position.y))
	model.remove_meta("gen_y")
	Hero.play(model, "idle", true)

## Where the victim stands (in front of the cross, facing the caster).
func victim_spot() -> Vector3:
	var vs := get_node_or_null("VictimSpot") as Node3D
	return vs.global_position if vs != null else global_position + Vector3(0, 0.3, 0.6)

## The caster moves around in here as they move in their own copy of the genjutsu.
func _process(delta: float) -> void:
	if caster_fig == null or not is_instance_valid(caster_fig):
		return
	var want := victim_spot() + Vector3(master_off.x, -0.1, master_off.z)
	var step := want - caster_fig.global_position
	step.y = 0.0
	var spd := step.length() / maxf(delta, 0.001)
	caster_fig.global_position = caster_fig.global_position.lerp(want, minf(1.0, 12.0 * delta))
	caster_fig.rotation.y = lerp_angle(caster_fig.rotation.y, master_yaw, minf(1.0, 12.0 * delta))
	Hero.play_move(caster_fig, Hero.move_state(spd) if spd > 0.4 else "idle", spd if spd > 0.4 else 0.0)
