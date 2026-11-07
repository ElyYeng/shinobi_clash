class_name Npc
extends StaticBody3D
## A villager standing in the open world. Shows "!" when it has a quest and "?" when you can turn one in.

var npc_id := ""
var display_name := "Villager"
var body_color := Color(0.3, 0.5, 0.7)
var band_color := Color(0.9, 0.9, 0.9)
var greeting := "Hello."
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
	model = Fx.make_ninja(body_color, band_color)
	add_child(model)
	var nl := Label3D.new()
	nl.text = display_name
	nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nl.no_depth_test = true
	nl.font_size = 40
	nl.outline_size = 10
	nl.pixel_size = 0.005
	nl.position.y = 2.6
	add_child(nl)
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.font_size = 96
	marker.outline_size = 18
	marker.pixel_size = 0.01
	marker.position.y = 3.4
	add_child(marker)
	set_marker("")

func set_marker(text: String, color := Color(1.0, 0.9, 0.2)) -> void:
	marker.text = text
	marker.modulate = color
	marker.visible = text != ""

func _process(delta: float) -> void:
	if marker.visible:
		marker.position.y = 3.4 + sin(Time.get_ticks_msec() / 300.0) * 0.12
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() < 9.0 and to.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-to.x, -to.z), 6.0 * delta)
