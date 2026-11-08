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
