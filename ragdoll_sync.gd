extends Node
## Multiplayer ragdoll replication for Shinobi Clash.
##
## The peer that owns a Player simulates that character's ragdoll. It sends a
## reliable start event and compact body-transform snapshots to the host. The
## host validates/relays the snapshots to every other peer. Remote avatars use
## frozen rigid bodies and apply those transforms, so all players see the same
## fall rather than a locally simulated approximation.
##
## Co-op quest enemies work the same way with the host as owner: the host simulates
## the enemy's ragdoll and streams it; each client's mirrored enemy goes limp and
## follows those snapshots (Enemy.die_from_network -> follow_enemy_ragdoll).

const SNAPSHOT_INTERVAL := 0.05       # 20 Hz while a ragdoll is settling
const SNAPSHOT_LIFETIME := 6.15       # Ragdoll.gd freezes its bodies after 6 s
const MAX_COORDINATE := 100000.0

var _local_death_sent := false
var _snapshot_timer := 0.0
var _pending_starts: Dictionary = {}
var _pending_states: Dictionary = {}
var _pending_respawns: Dictionary = {}
var _tracked_local_player: Player
var _has_tracked_local_player := false
var _tracked_player_died := false

# ---- enemy ragdolls (key = Enemy.network_quest_id)
const ENEMY_PENDING_TTL := 2.0          # drop snapshots for an enemy this client never saw die
var _streamed_enemies: Dictionary = {}  # host: id -> Ragdoll it simulates and sends
var _followed_enemies: Dictionary = {}  # client: id -> network-driven Ragdoll
var _pending_enemy_states: Dictionary = {}  # client: id -> [state, age] that arrived before the death event
var _enemy_snapshot_timer := 0.0

func _process(delta: float) -> void:
	if not NetworkSession.is_active():
		_reset_session_state()
		return

	_apply_pending_events()
	_update_enemy_ragdolls(delta)
	var local_player := NetworkSession.get("_local_player") as Player
	if local_player == null or not is_instance_valid(local_player):
		return

	# Main.gd respawns by reloading the scene, which creates a new Player node.
	# The autoload survives that reload, so detect the instance change and tell
	# the other peers to replace this player's old ragdoll with a fresh avatar.
	if not _has_tracked_local_player or local_player != _tracked_local_player:
		var was_respawned := _has_tracked_local_player and (_tracked_player_died or _local_death_sent)
		_tracked_local_player = local_player
		_has_tracked_local_player = true
		_tracked_player_died = false
		_local_death_sent = false
		_snapshot_timer = 0.0
		if was_respawned:
			_send_player_respawn(local_player)

	if not local_player.is_dead:
		_local_death_sent = false
		_snapshot_timer = 0.0
		return
	_tracked_player_died = true

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
	_pending_respawns.clear()
	_tracked_local_player = null
	_has_tracked_local_player = false
	_tracked_player_died = false
	_streamed_enemies.clear()
	_followed_enemies.clear()
	_pending_enemy_states.clear()
	_enemy_snapshot_timer = 0.0

func _send_player_respawn(player: Player) -> void:
	var position := player.global_position
	var yaw := player.model.rotation.y if player.model != null else 0.0
	var peer_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_broadcast_player_respawn.rpc(peer_id, position, yaw)
	else:
		_request_player_respawn.rpc_id(1, position, yaw)

@rpc("any_peer", "call_remote", "reliable")
func _request_player_respawn(position: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _is_known_peer(sender_id) or not _valid_spawn(position, yaw):
		return
	var safe_yaw := wrapf(yaw, -PI, PI)
	_apply_remote_player_respawn(sender_id, position, safe_yaw)
	_broadcast_player_respawn.rpc(sender_id, position, safe_yaw)

@rpc("authority", "call_remote", "reliable")
func _broadcast_player_respawn(peer_id: int, position: Vector3, yaw: float) -> void:
	if peer_id == multiplayer.get_unique_id() or not _valid_spawn(position, yaw):
		return
	_apply_remote_player_respawn(peer_id, position, wrapf(yaw, -PI, PI))

func _apply_remote_player_respawn(peer_id: int, position: Vector3, yaw: float) -> void:
	# A respawn supersedes any late snapshots queued for the previous life.
	_pending_starts.erase(peer_id)
	_pending_states.erase(peer_id)
	var avatar := _get_remote_avatar(peer_id)
	if avatar == null:
		_pending_respawns[peer_id] = [position, yaw]
		return
	if avatar.has_method("reset_network_ragdoll"):
		avatar.call("reset_network_ragdoll", position, yaw)

func _valid_spawn(position: Vector3, yaw: float) -> bool:
	return is_finite(position.x) and is_finite(position.y) and is_finite(position.z) \
		and absf(position.x) <= MAX_COORDINATE and absf(position.y) <= MAX_COORDINATE \
		and absf(position.z) <= MAX_COORDINATE and is_finite(yaw)

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
	if avatar == null:
		# The remote avatar may still be spawning while the start event arrives.
		_pending_states[peer_id] = state.duplicate()
		return
	if not bool(avatar.get("network_ragdoll_started")):
		# Ignore a delayed snapshot from a previous life after this player respawned.
		return
	if avatar.has_method("apply_network_ragdoll_state"):
		avatar.call("apply_network_ragdoll_state", state)

func _apply_pending_events() -> void:
	var known_players: Dictionary = NetworkSession.get("_known_players")
	for peer_value in _pending_respawns.keys():
		var peer_id := int(peer_value)
		if not known_players.has(peer_id):
			_pending_respawns.erase(peer_value)
			continue
		var avatar := _get_remote_avatar(peer_id)
		if avatar != null:
			var pending_respawn: Array = _pending_respawns[peer_value]
			_pending_respawns.erase(peer_value)
			if avatar.has_method("reset_network_ragdoll"):
				avatar.call("reset_network_ragdoll", pending_respawn[0], float(pending_respawn[1]))

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

# ---------------------------------------------------------------- enemy ragdolls
## Host: send this enemy ragdoll's body transforms to the other players while it settles.
func stream_enemy_ragdoll(enemy_id: String, ragdoll: Ragdoll) -> void:
	if enemy_id == "" or ragdoll == null or not multiplayer.is_server():
		return
	_streamed_enemies[enemy_id] = ragdoll
	_send_enemy_state(enemy_id, ragdoll)   # first pose right away, so clients don't wait a tick

## Client: drive this (network-driven) ragdoll from the host's snapshots.
func follow_enemy_ragdoll(enemy_id: String, ragdoll: Ragdoll) -> void:
	if enemy_id == "" or ragdoll == null:
		return
	_followed_enemies[enemy_id] = ragdoll
	if _pending_enemy_states.has(enemy_id):   # a snapshot overtook the (reliable) death event
		ragdoll.apply_network_state(_pending_enemy_states[enemy_id][0])
		_pending_enemy_states.erase(enemy_id)

func _update_enemy_ragdolls(delta: float) -> void:
	for id in _followed_enemies.keys():
		if not is_instance_valid(_followed_enemies[id]):
			_followed_enemies.erase(id)
	for id in _pending_enemy_states.keys():
		_pending_enemy_states[id][1] += delta
		if _pending_enemy_states[id][1] > ENEMY_PENDING_TTL:
			_pending_enemy_states.erase(id)
	if _streamed_enemies.is_empty() or not multiplayer.is_server():
		return
	_enemy_snapshot_timer += delta
	if _enemy_snapshot_timer < SNAPSHOT_INTERVAL:
		return
	_enemy_snapshot_timer = 0.0
	for id in _streamed_enemies.keys():
		var r = _streamed_enemies[id]
		if not is_instance_valid(r) or (r as Ragdoll).life > SNAPSHOT_LIFETIME:
			_streamed_enemies.erase(id)   # settled (bodies frozen) or cleaned up
			continue
		_send_enemy_state(id, r)

func _send_enemy_state(enemy_id: String, ragdoll: Ragdoll) -> void:
	var state := ragdoll.get_network_state()
	if _valid_state(state):
		_enemy_ragdoll_state.rpc(enemy_id, state)

@rpc("authority", "call_remote", "unreliable_ordered")
func _enemy_ragdoll_state(enemy_id: String, state: PackedFloat32Array) -> void:
	if not _valid_state(state):
		return
	var r = _followed_enemies.get(enemy_id)
	if r != null and is_instance_valid(r):
		(r as Ragdoll).apply_network_state(state)
	else:
		_pending_enemy_states[enemy_id] = [state, 0.0]
