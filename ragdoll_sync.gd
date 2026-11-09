extends Node
## Multiplayer ragdoll replication for Shinobi Clash.
##
## The peer that owns a Player simulates that character's ragdoll. It sends a
## reliable start event and compact body-transform snapshots to the host. The
## host validates/relays the snapshots to every other peer. Remote avatars use
## frozen rigid bodies and apply those transforms, so all players see the same
## fall rather than a locally simulated approximation.

const SNAPSHOT_INTERVAL := 0.05       # 20 Hz while a ragdoll is settling
const SNAPSHOT_LIFETIME := 6.15       # Ragdoll.gd freezes its bodies after 6 s
const MAX_COORDINATE := 100000.0

var _local_death_sent := false
var _snapshot_timer := 0.0
var _pending_starts: Dictionary = {}
var _pending_states: Dictionary = {}

func _process(delta: float) -> void:
	if not NetworkSession.is_active():
		_reset_session_state()
		return

	_apply_pending_events()
	var local_player := NetworkSession.get("_local_player") as Player
	if local_player == null or not is_instance_valid(local_player):
		return

	if not local_player.is_dead:
		_local_death_sent = false
		_snapshot_timer = 0.0
		return

	if not _local_death_sent:
		_local_death_sent = true
		_snapshot_timer = 0.0
		_send_ragdoll_start(local_player)

	if local_player.ragdoll == null or not is_instance_valid(local_player.ragdoll):
		return
	if local_player.ragdoll.life > SNAPSHOT_LIFETIME:
		return

	_snapshot_timer += delta
	if _snapshot_timer < SNAPSHOT_INTERVAL:
		return
	_snapshot_timer = 0.0
	_send_ragdoll_state(local_player.ragdoll.get_network_state())

func _reset_session_state() -> void:
	_local_death_sent = false
	_snapshot_timer = 0.0
	_pending_starts.clear()
	_pending_states.clear()

func _send_ragdoll_start(player: Player) -> void:
	var yaw := player.model.rotation.y if player.model != null else 0.0
	var launch_velocity := Vector3(player.velocity.x * 0.5, 3.0, player.velocity.z * 0.5)
	var peer_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_broadcast_ragdoll_start.rpc(peer_id, player.global_position, yaw, launch_velocity)
	else:
		_request_ragdoll_start.rpc_id(1, player.global_position, yaw, launch_velocity)

func _send_ragdoll_state(state: PackedFloat32Array) -> void:
	if not _valid_state(state):
		return
	var peer_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_broadcast_ragdoll_state.rpc(peer_id, state)
	else:
		_request_ragdoll_state.rpc_id(1, state)

@rpc("any_peer", "call_remote", "reliable")
func _request_ragdoll_start(_position: Vector3, yaw: float, launch_velocity: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _is_known_peer(sender_id):
		return
	var avatar := _get_remote_avatar(sender_id)
	if avatar == null:
		return

	# Use the server's latest replicated avatar position rather than trusting a
	# client-supplied teleport. Yaw/impulse only affect the cosmetic fall.
	var safe_position := avatar.global_position
	var safe_yaw := wrapf(yaw, -PI, PI) if is_finite(yaw) else 0.0
	var safe_velocity := _safe_launch_velocity(launch_velocity)
	_apply_remote_ragdoll_start(sender_id, safe_position, safe_yaw, safe_velocity)
	_broadcast_ragdoll_start.rpc(sender_id, safe_position, safe_yaw, safe_velocity)

@rpc("authority", "call_remote", "reliable")
func _broadcast_ragdoll_start(peer_id: int, position: Vector3, yaw: float, launch_velocity: Vector3) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	_apply_remote_ragdoll_start(peer_id, position, wrapf(yaw, -PI, PI) if is_finite(yaw) else 0.0, _safe_launch_velocity(launch_velocity))

func _apply_remote_ragdoll_start(peer_id: int, position: Vector3, yaw: float, launch_velocity: Vector3) -> void:
	var avatar := _get_remote_avatar(peer_id)
	if avatar == null:
		_pending_starts[peer_id] = [position, yaw, launch_velocity]
		return
	if not avatar.has_method("start_network_ragdoll"):
		return
	avatar.call("start_network_ragdoll", position, yaw, launch_velocity)
	_apply_pending_state(peer_id, avatar)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _request_ragdoll_state(state: PackedFloat32Array) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _is_known_peer(sender_id) or not _valid_state(state):
		return
	_apply_remote_ragdoll_state(sender_id, state)
	_broadcast_ragdoll_state.rpc(sender_id, state)

@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_ragdoll_state(peer_id: int, state: PackedFloat32Array) -> void:
	if peer_id == multiplayer.get_unique_id() or not _valid_state(state):
		return
	_apply_remote_ragdoll_state(peer_id, state)

func _apply_remote_ragdoll_state(peer_id: int, state: PackedFloat32Array) -> void:
	var avatar := _get_remote_avatar(peer_id)
	if avatar == null or not bool(avatar.get("network_ragdoll_started")):
		# Unreliable snapshots can arrive before the reliable start event.
		# Keep only the latest packet and apply it as soon as the avatar exists.
		_pending_states[peer_id] = state.duplicate()
		return
	if avatar.has_method("apply_network_ragdoll_state"):
		avatar.call("apply_network_ragdoll_state", state)

func _apply_pending_events() -> void:
	var known_players: Dictionary = NetworkSession.get("_known_players")
	for peer_value in _pending_starts.keys():
		var peer_id := int(peer_value)
		if not known_players.has(peer_id):
			_pending_starts.erase(peer_value)
			_pending_states.erase(peer_value)
			continue
		var pending: Array = _pending_starts[peer_value]
		var avatar := _get_remote_avatar(peer_id)
		if avatar != null:
			_pending_starts.erase(peer_value)
			_apply_remote_ragdoll_start(peer_id, pending[0], float(pending[1]), pending[2])

	for peer_value in _pending_states.keys():
		var peer_id := int(peer_value)
		if not known_players.has(peer_id):
			_pending_states.erase(peer_value)
			continue
		var avatar := _get_remote_avatar(peer_id)
		if avatar != null and bool(avatar.get("network_ragdoll_started")):
			_apply_pending_state(peer_id, avatar)

func _apply_pending_state(peer_id: int, avatar: Node3D) -> void:
	if not _pending_states.has(peer_id):
		return
	var state: PackedFloat32Array = _pending_states[peer_id]
	_pending_states.erase(peer_id)
	if avatar.has_method("apply_network_ragdoll_state"):
		avatar.call("apply_network_ragdoll_state", state)

func _get_remote_avatar(peer_id: int) -> Node3D:
	var avatars: Dictionary = NetworkSession.get("_avatars")
	if not avatars.has(peer_id):
		return null
	var avatar := avatars[peer_id] as Node3D
	return avatar if is_instance_valid(avatar) else null

func _is_known_peer(peer_id: int) -> bool:
	var known_players: Dictionary = NetworkSession.get("_known_players")
	return peer_id > 0 and known_players.has(peer_id)

func _safe_launch_velocity(value: Vector3) -> Vector3:
	if not is_finite(value.x) or not is_finite(value.y) or not is_finite(value.z):
		return Vector3(0.0, 3.0, 0.0)
	return value.limit_length(35.0)

func _valid_state(state: PackedFloat32Array) -> bool:
	if state.size() != Ragdoll.NETWORK_STATE_SIZE:
		return false
	for offset in range(0, state.size(), Ragdoll.NETWORK_FLOATS_PER_PART):
		for axis in 3:
			var value := state[offset + axis]
			if not is_finite(value) or absf(value) > MAX_COORDINATE:
				return false
		var q_len_sq := 0.0
		for axis in 4:
			var q_value := state[offset + 3 + axis]
			if not is_finite(q_value) or absf(q_value) > 1.1:
				return false
			q_len_sq += q_value * q_value
		if q_len_sq < 0.5 or q_len_sq > 1.5:
			return false
	return true
