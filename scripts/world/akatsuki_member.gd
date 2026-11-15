@tool
class_name AkatsukiMember
extends Marker3D
## An Akatsuki member on the Akatsuki map. Drag it in the 3D editor (it stands where you put it,
## feet at the marker), or Ctrl+D to add more. wander_radius 0 = stands still; above 0 = strolls
## around the spot (following the ground, never leaving the radius).

@export var display_name := "Akatsuki Member":
	set(v):
		display_name = v
		_queue()
@export var hair_style := "hair1":
	set(v):
		hair_style = v
		_queue()
@export var hair_color := Color("#1C1B24"):
	set(v):
		hair_color = v
		_queue()
@export var wander_radius := 0.0
@export var speed := 1.4

var model: Node3D
var _home := Vector3.ZERO
var _goal := Vector3.ZERO
var _pause := 1.0
var _pending := false
var _step_t := 0.0
var _surface := "ground"

func _ready() -> void:
	_home = position
	_goal = position
	_build()

func _queue() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		_build.call_deferred()

func _build() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta("member_visual"):
			remove_child(c)
			c.queue_free()
	var look: Dictionary = Hero.DEFAULT_APPEARANCE.duplicate()
	look["shirt_style"] = "shirt3"
	look["hair_style"] = hair_style
	look["hair_color"] = "#" + hair_color.to_html(false)
	look["headband_state"] = "scratched"
	model = Npc.character_look(look, "akatsuki_" + display_name)
	if model == null:
		model = Fx.make_ninja(Color(0.1, 0.1, 0.14), Color(0.8, 0.1, 0.1))
	model.set_meta("member_visual", true)
	add_child(model)
	var nl := Label3D.new()
	nl.text = display_name
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nl.no_depth_test = true
	nl.font_size = 40
	nl.outline_size = 10
	nl.pixel_size = 0.005
	nl.position.y = 2.3
	nl.set_meta("member_visual", true)
	add_child(nl)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or model == null:
		return
	_look_at_player(delta)
	FootIK.drive(model, true)
	if wander_radius <= 0.0:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			var a := randf() * TAU
			_goal = _home + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.0) * wander_radius
		return
	var d := _goal - position
	d.y = 0.0
	if d.length() < 0.4:
		_pause = randf_range(1.5, 5.0)
		Hero.play_move(model, "idle", 0.0)
		return
	# heading in WORLD space (the marker itself may be rotated in the editor, which used to
	# make walkers moonwalk / sidestep). Same -Z-forward convention as villagers.
	var par := get_parent() as Node3D
	var wd := (par.global_transform.basis * d.normalized()) if par != null else d.normalized()
	var want := atan2(-wd.x, -wd.z)
	model.global_rotation.y = lerp_angle(model.global_rotation.y, want, 1.0 - exp(-6.0 * delta))
	if absf(angle_difference(model.global_rotation.y, want)) > 0.6:   # turn on the spot first, then walk
		Hero.play_move(model, "idle", 0.0)
		return
	position += d.normalized() * speed * delta
	# follow the ground (sand / river surface) within a few metres of the spot you placed
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 4.0, global_position + Vector3.DOWN * 6.0, 1 | 512)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		_surface = "water" if (h["collider"] as Node).has_meta("water_walk") else "ground"
		global_position.y = lerpf(global_position.y, float(h["position"].y), clampf(delta * 8.0, 0.0, 1.0))
	Hero.play_move(model, Hero.move_state(speed), speed)
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = clampf(1.7 / maxf(speed, 0.5), 0.3, 0.7)
		var cam := get_viewport().get_camera_3d()
		var dist := cam.global_position.distance_to(global_position) if cam != null else 999.0
		if dist < 30.0:   # only audible near you
			Sfx.step(self, speed >= Hero.WALK_BELOW, _surface, -4.0 - dist * 0.4)

## Glance at the player when close, like the villagers do (head only, never from behind).
func _look_at_player(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var to_p := (p.global_position - global_position) if p != null else Vector3(999, 0, 999)
	to_p.y = 0.0
	var pd := to_p.length()
	var want := wrapf(atan2(-to_p.x, -to_p.z) - model.global_rotation.y, -PI, PI)
	var fade := 1.0 - smoothstep(deg_to_rad(95.0), deg_to_rad(130.0), absf(want))
	if p != null and pd < 7.0 and pd > 0.1 and fade > 0.0:
		var dy := (p.global_position.y + 1.5) - (global_position.y + 1.6)
		HeadLook.drive(model, want * fade, atan2(dy, pd) * fade, delta)
	elif pd < 9.0:
		HeadLook.drive(model, 0.0, 0.0, delta)
