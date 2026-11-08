extends Control
## Simple host/join screen for friends on the same Radmin VPN network.

var name_input: LineEdit
var address_input: LineEdit
var port_input: LineEdit
var status_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkSession.connection_succeeded.connect(_on_joined)
	NetworkSession.connection_failed.connect(_on_failed)
	NetworkSession.server_disconnected.connect(_on_disconnected)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.025, 0.045, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var title := Label.new()
	title.text = "SHINOBI CLASH  |  MULTIPLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	col.add_child(title)
	name_input = _field(col, "Player name", "Shinobi")
	address_input = _field(col, "Host Radmin VPN IPv4", "26.x.x.x")
	port_input = _field(col, "UDP port", "7000")
	var coop := Button.new()
	coop.text = "HOST CO-OP WORLD  (up to 8 players)"
	coop.pressed.connect(_host.bind("coop"))
	col.add_child(coop)
	var pvp := Button.new()
	pvp.text = "HOST PVP ARENA  (up to 8 players)"
	pvp.pressed.connect(_host.bind("pvp"))
	col.add_child(pvp)
	var raid := Button.new()
	raid.text = "HOST KURAMA RAID  (LEVEL 10+, PARTY CO-OP)"
	raid.pressed.connect(_host.bind("raid"))
	col.add_child(raid)
	var join := Button.new()
	join.text = "JOIN HOST"
	join.pressed.connect(_join)
	col.add_child(join)
	status_label = Label.new()
	status_label.text = "Kurama Raid requires Level 10 for every player. Same Radmin VPN network; UDP 7000."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status_label)
	var back := Button.new()
	back.text = "BACK TO MAIN MENU"
	back.pressed.connect(_back)
	col.add_child(back)

func _field(parent: Node, hint: String, value: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.text = value
	parent.add_child(field)
	return field

func _host(mode: String) -> void:
	if mode == "raid" and GameData.level < 10:
		status_label.text = "Kurama Raid requires Level 10."
		return
	var port := _read_port()
	if port < 1:
		return
	var error := NetworkSession.host(port, mode, name_input.text)
	if error != OK:
		status_label.text = "Could not host: %s" % error_string(error)
		return
	GameData.mode = "world" if mode == "coop" else ("kurama" if mode == "raid" else "fight")
	get_tree().change_scene_to_file("res://main.tscn")

func _join() -> void:
	var port := _read_port()
	if port < 1:
		return
	var address := address_input.text.strip_edges()
	if address == "":
		status_label.text = "Enter the host's Radmin VPN IPv4 address."
		return
	status_label.text = "Connecting to %s:%d ..." % [address, port]
	var error := NetworkSession.join(address, port, name_input.text)
	if error != OK:
		status_label.text = "Could not start connection: %s" % error_string(error)

func _read_port() -> int:
	var port := int(port_input.text)
	if port < 1 or port > 65535:
		status_label.text = "Port must be between 1 and 65535."
		return -1
	return port

func _on_joined() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_failed(message: String) -> void:
	status_label.text = message

func _on_disconnected() -> void:
	status_label.text = "Disconnected from the host."

func _back() -> void:
	NetworkSession.disconnect_session()
	get_tree().change_scene_to_file("res://menu.tscn")
