extends Node
## ENet session manager. Radmin VPN carries ENet's UDP traffic over its virtual LAN.
signal connection_succeeded
signal connection_failed(message: String)
signal server_disconnected

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 8
const MAX_CLIENTS := MAX_PLAYERS - 1
const SYNC_INTERVAL := 0.05

var is_host := false
var session_mode := "coop"
var player_name := "Shinobi"
var _local_player: Player
var _game_root: Node
var _sync_timer := 0.0
var _known_players: Dictionary = {}
var _avatars: Dictionary = {}

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func host(port: int = DEFAULT_PORT, mode: String = "coop", display_name: String = "Shinobi") -> Error:
	disconnect_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	session_mode = mode
	player_name = display_name.strip_edges()
	if player_name == "":
		player_name = "Shinobi"
	_known_players[1] = player_name
	return OK

func join(address: String, port: int = DEFAULT_PORT, display_name: String = "Shinobi") -> Error:
	disconnect_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	player_name = display_name.strip_edges()
	if player_name == "":
		player_name = "Shinobi"
	return OK

func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	_local_player = null
	_game_root = null
	_sync_timer = 0.0
	_known_players.clear()
	for avatar in _avatars.values():
		if is_instance_valid(avatar):
			avatar.queue_free()
	_avatars.clear()

func is_active() -> bool:
	return multiplayer.multiplayer_peer != null

func bind_local_player(player: Player, game_root: Node) -> void:
	_local_player = player
	_game_root = game_root
	for id in _known_players:
		if int(id) != multiplayer.get_unique_id():
			_spawn_remote_local(int(id), str(_known_players[id]))

func _process(delta: float) -> void:
	if not is_active() or _local_player == null:
		return
	_sync_timer += delta
	if _sync_timer < SYNC_INTERVAL:
		return
	_sync_timer = 0.0
	var pos := _local_player.global_position
	var yaw := _local_player.model.rotation.y if _local_player.model != null else 0.0
	if multiplayer.is_server():
		_broadcast_state.rpc(1, pos, yaw)
	else:
		_submit_state.rpc_id(1, pos, yaw)

func _on_connected_to_server() -> void:
	_request_join.rpc_id(1, player_name)

@rpc("any_peer", "call_remote", "reliable")
func _request_join(requested_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.get_peers().size() > MAX_CLIENTS:
		_join_rejected.rpc_id(sender, "This room is full (8 players maximum).")
		return
	var safe_name := requested_name.strip_edges()
	if safe_name == "":
		safe_name = "Shinobi %d" % sender
	var roster: Array = []
	for id in _known_players:
		roster.append({"id": int(id), "name": str(_known_players[id])})
	_receive_roster.rpc_id(sender, roster)
	_known_players[sender] = safe_name
	_spawn_remote_local(sender, safe_name)
	_spawn_remote.rpc(sender, safe_name)
	_join_accepted.rpc_id(sender, session_mode)

@rpc("authority", "call_remote", "reliable")
func _receive_roster(roster: Array) -> void:
	for entry in roster:
		var id := int(entry.get("id", 0))
		var nm := str(entry.get("name", "Shinobi"))
		_known_players[id] = nm
		if id != multiplayer.get_unique_id():
			_spawn_remote_local(id, nm)

@rpc("authority", "call_remote", "reliable")
func _spawn_remote(peer_id: int, display_name: String) -> void:
	_known_players[peer_id] = display_name
	if peer_id != multiplayer.get_unique_id():
		_spawn_remote_local(peer_id, display_name)

func _spawn_remote_local(peer_id: int, display_name: String) -> void:
	if _game_root == null or not is_instance_valid(_game_root):
		return
	if _avatars.has(peer_id):
		if is_instance_valid(_avatars[peer_id]):
			return
		_avatars.erase(peer_id)
	var script := load("res://multiplayer_avatar.gd")
	if script == null:
		return
	var avatar := script.new() as Node3D
	avatar.name = "RemotePlayer_%d" % peer_id
	avatar.set("peer_id", peer_id)
	avatar.set("display_name", display_name)
	_game_root.add_child(avatar)
	_avatars[peer_id] = avatar

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_state(pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender):
		return
	_broadcast_state.rpc(sender, pos, yaw)
	_apply_remote_state(sender, pos, yaw)

@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_state(peer_id: int, pos: Vector3, yaw: float) -> void:
	_apply_remote_state(peer_id, pos, yaw)

func _apply_remote_state(peer_id: int, pos: Vector3, yaw: float) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	if _avatars.has(peer_id) and is_instance_valid(_avatars[peer_id]):
		_avatars[peer_id].set_network_transform(pos, yaw)

@rpc("authority", "call_remote", "reliable")
func _join_accepted(mode: String) -> void:
	session_mode = mode
	GameData.mode = "world" if mode == "coop" else "fight"
	connection_succeeded.emit()

@rpc("authority", "call_remote", "reliable")
func _join_rejected(message: String) -> void:
	connection_failed.emit(message)
	disconnect_session()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_known_players.erase(peer_id)
	_remove_remote_local(peer_id)
	_despawn_remote.rpc(peer_id)

@rpc("authority", "call_remote", "reliable")
func _despawn_remote(peer_id: int) -> void:
	_known_players.erase(peer_id)
	_remove_remote_local(peer_id)

func _remove_remote_local(peer_id: int) -> void:
	if _avatars.has(peer_id):
		var avatar = _avatars[peer_id]
		if is_instance_valid(avatar):
			avatar.queue_free()
		_avatars.erase(peer_id)

func try_hit_players(damage: float, knockback: Vector3) -> void:
	if not is_active() or session_mode != "pvp":
		return
	for peer_id in _avatars.keys():
		if not is_instance_valid(_avatars[peer_id]):
			continue
		var to: Vector3 = _avatars[peer_id].global_position - _local_player.global_position
		to.y = 0.0
		if to.length() <= 3.2 and to.length() > 0.01 and _local_player.facing.dot(to.normalized()) > 0.25:
			if multiplayer.is_server():
				_server_apply_hit(1, int(peer_id), damage, knockback)
			else:
				_request_player_hit.rpc_id(1, int(peer_id), damage, knockback)

@rpc("any_peer", "call_remote", "reliable")
func _request_player_hit(target_id: int, damage: float, knockback: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_server_apply_hit(multiplayer.get_remote_sender_id(), target_id, damage, knockback)

func _server_apply_hit(attacker_id: int, target_id: int, damage: float, knockback: Vector3) -> void:
	if attacker_id == target_id or not _known_players.has(target_id):
		return
	var attacker_pos: Vector3
	var target_pos: Vector3
	if attacker_id == 1 and _local_player != null:
		attacker_pos = _local_player.global_position
	elif _avatars.has(attacker_id) and is_instance_valid(_avatars[attacker_id]):
		attacker_pos = _avatars[attacker_id].global_position
	else:
		return
	if target_id == 1 and _local_player != null:
		target_pos = _local_player.global_position
	elif _avatars.has(target_id) and is_instance_valid(_avatars[target_id]):
		target_pos = _avatars[target_id].global_position
	else:
		return
	if attacker_pos.distance_to(target_pos) > 4.0:
		return
	var safe_damage := clampf(damage, 1.0, 80.0)
	if target_id == 1 and _local_player != null:
		_local_player.take_damage(safe_damage, knockback)
	else:
		_apply_player_damage.rpc_id(target_id, safe_damage, knockback)

@rpc("authority", "call_remote", "reliable")
func _apply_player_damage(amount: float, knockback: Vector3) -> void:
	if _local_player != null:
		_local_player.take_damage(amount, knockback)


## Broadcast a successful ability cast so every peer can render its remote visual.
func broadcast_ability(move_id: String, color: Color) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_broadcast_ability_visual.rpc(1, move_id, color)
	else:
		_request_ability_visual.rpc_id(1, move_id, color)

@rpc("any_peer", "call_remote", "reliable")
func _request_ability_visual(move_id: String, color: Color) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender):
		return
	_show_remote_ability(sender, move_id, color)
	_broadcast_ability_visual.rpc(sender, move_id, color)

@rpc("authority", "call_remote", "reliable")
func _broadcast_ability_visual(peer_id: int, move_id: String, color: Color) -> void:
	_show_remote_ability(peer_id, move_id, color)

func _show_remote_ability(peer_id: int, move_id: String, color: Color) -> void:
	if _avatars.has(peer_id) and is_instance_valid(_avatars[peer_id]):
		_avatars[peer_id].play_ability(move_id, color)

func _on_connection_failed() -> void:
	is_host = false
	connection_failed.emit("Could not connect. Check the host's Radmin IP, UDP port 7000, and firewall.")

func _on_server_disconnected() -> void:
	is_host = false
	server_disconnected.emit()
	disconnect_session()
