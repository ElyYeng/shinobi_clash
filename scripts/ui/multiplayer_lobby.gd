extends Control
## Simple host/join screen for friends on the same Radmin VPN network.

var name_input: LineEdit
var address_input: LineEdit
var port_input: LineEdit
var status_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameData.load_data()
	NetworkSession.connection_succeeded.connect(_on_joined)
	NetworkSession.connection_failed.connect(_on_failed)
	NetworkSession.server_disconnected.connect(_on_disconnected)
	_build_ui()

func _build_ui() -> void:
	var bg := MenuBG.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()   # dim the scenery a little behind the scroll
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	center.add_child(outer)
	UiStyle.title(outer, "MULTIPLAYER", 48)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	UiStyle.scroll(outer, Vector2(600, 0)).add_child(col)
	name_input = UiStyle.field(col, "NAME", GameData.mp_name, "Player name")
	address_input = UiStyle.field(col, "HOST IP", GameData.mp_address, "Host Radmin VPN IPv4")
	port_input = UiStyle.field(col, "UDP PORT", GameData.mp_port)
	for e in [name_input, address_input, port_input]:   # remember what was typed
		e.text_changed.connect(func(_t: String) -> void: _remember())
	UiStyle.divider(col)
	UiStyle.label(col, "HOST A GAME", 15, UiStyle.GREEN_DK)
	var hosts := HBoxContainer.new()
	hosts.add_theme_constant_override("separation", 8)
	col.add_child(hosts)
	for h in [["CO-OP WORLD", "coop"], ["PVP ARENA", "pvp"], ["KURAMA RAID", "raid"]]:
		var b := UiStyle.green_button(hosts, h[0], 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_host.bind(h[1]))
	UiStyle.label(col, "OR JOIN A FRIEND", 15, UiStyle.GREEN_DK)
	var join := UiStyle.ribbon_button(col, "JOIN HOST", 24)
	join.alignment = HORIZONTAL_ALIGNMENT_CENTER
	join.pressed.connect(_join)
	join.grab_focus.call_deferred()
	status_label = UiStyle.label(col, "Up to 8 players. Kurama Raid needs Level 10 for everyone. Same Radmin VPN network, UDP 7000.", 14, UiStyle.BODY_TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(540, 0)

	var back := UiStyle.text_button(outer, "<  BACK TO MAIN MENU")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back)

func _remember() -> void:
	GameData.mp_name = name_input.text.strip_edges()
	GameData.mp_address = address_input.text.strip_edges()
	GameData.mp_port = port_input.text.strip_edges()

func _save_fields() -> void:
	_remember()
	GameData.save()

func _host(mode: String) -> void:
	_save_fields()
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
	LoadingScreen.go(get_tree(), "res://scenes/main.tscn")

func _join() -> void:
	_save_fields()
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
	LoadingScreen.go(get_tree(), "res://scenes/main.tscn")

func _on_failed(message: String) -> void:
	status_label.text = message

func _on_disconnected() -> void:
	status_label.text = "Disconnected from the host."

func _back() -> void:
	_save_fields()
	NetworkSession.disconnect_session()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
