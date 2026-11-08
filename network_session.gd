extends Node
## Small ENet session wrapper. ENet uses UDP, which Radmin VPN carries over its virtual LAN.

signal connection_succeeded
signal connection_failed(message: String)
signal server_disconnected

const DEFAULT_PORT := 7000
const MAX_CLIENTS := 8

var is_host := false

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	disconnect_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	return OK

func join(address: String, port: int = DEFAULT_PORT) -> Error:
	disconnect_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	return OK

func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false

func is_active() -> bool:
	return multiplayer.multiplayer_peer != null

func _on_connected_to_server() -> void:
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	is_host = false
	connection_failed.emit("Could not connect. Check the host's Radmin IP, port, and firewall.")

func _on_server_disconnected() -> void:
	is_host = false
	server_disconnected.emit()
