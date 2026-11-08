extends Node3D
## Lightweight remote player representation. The owning peer controls its own Player node.

var peer_id := 0
var display_name := "Shinobi"
var target_position := Vector3.ZERO
var target_yaw := 0.0
var model: Node3D
var name_tag: Label3D
var _last_position := Vector3.ZERO

func _ready() -> void:
	add_to_group("network_players")
	model = Hero.create()
	if model == null:
		var hue := fposmod(float(peer_id) * 0.173, 1.0)
		model = Fx.make_ninja(Color.from_hsv(hue, 0.7, 0.95), Color(0.12, 0.16, 0.24))
	add_child(model)
	name_tag = Label3D.new()
	name_tag.text = display_name
	name_tag.position = Vector3(0, 2.4, 0)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.font_size = 32
	name_tag.outline_size = 8
	add_child(name_tag)
	target_position = global_position
	_last_position = global_position


## Cosmetic-only ability playback on this remote avatar; gameplay remains owned by its player.
func play_ability(move_id: String, color: Color) -> void:
	if model != null:
		Hero.play(model, "jutsu", true)
	var root := get_parent()
	if root != null:
		Vfx.burst(root, global_position + Vector3.UP, color, 30, 8.0, 0.28, 0.55, 0.0)
		Vfx.shockwave(root, global_position + Vector3.UP * 0.2, color, 3.5, 0.4)
	if name_tag != null:
		name_tag.text = "%s  •  %s" % [display_name, move_id]
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(name_tag):
				name_tag.text = display_name
		)

func set_network_transform(pos: Vector3, yaw: float) -> void:
	target_position = pos
	target_yaw = yaw

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, minf(1.0, delta * 14.0))
	if model != null:
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(1.0, delta * 14.0))
		var speed := global_position.distance_to(_last_position) / maxf(delta, 0.001)
		Hero.play(model, "run" if speed > 1.0 else "idle")
	_last_position = global_position
