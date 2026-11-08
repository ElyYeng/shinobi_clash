extends Node
## ENet session manager. Radmin VPN carries ENet's UDP traffic over its virtual LAN.
signal connection_succeeded
signal connection_failed(message: String)
signal server_disconnected
signal party_invite_received(inviter_id: int, inviter_name: String)
signal party_updated

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
var _known_levels: Dictionary = {}
var _party_leader: Dictionary = {}
var _pending_party_invites: Dictionary = {}
var _avatars: Dictionary = {}
var _remote_clones: Dictionary = {}
var _next_clone_summon_id := 1
var _raid_boss: Kurama
var _raid_sync_timer := 0.0
var _quest_manager: Quests
var _party_quest_states: Dictionary = {}
var _server_quest_leader_override := 0

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
	_known_levels[1] = GameData.level
	_party_leader[1] = 1
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
	_raid_boss = null
	_raid_sync_timer = 0.0
	_quest_manager = null
	_party_quest_states.clear()
	_server_quest_leader_override = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	_local_player = null
	_game_root = null
	_sync_timer = 0.0
	_known_players.clear()
	_known_levels.clear()
	_party_leader.clear()
	_pending_party_invites.clear()
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
	_sync_shadow_clone_transforms()
	if multiplayer.is_server() and session_mode == "coop":
		_sync_quest_enemy_states()
	if multiplayer.is_server() and session_mode == "raid" and _raid_boss != null and is_instance_valid(_raid_boss):
		_raid_sync_timer += delta
		if _raid_sync_timer >= 0.1:
			_raid_sync_timer = 0.0
			_raid_snapshot.rpc(_raid_boss.global_position, _raid_boss.model.rotation.y, _raid_boss.health, _raid_boss.phase, int(_raid_boss.state), _raid_boss.atk, _raid_boss.atk_t, _raid_boss.atk_len, _raid_boss.slam_pos)
	var pos := _local_player.global_position
	var yaw := _local_player.model.rotation.y if _local_player.model != null else 0.0
	if multiplayer.is_server():
		_broadcast_state.rpc(1, pos, yaw)
	else:
		_submit_state.rpc_id(1, pos, yaw)

func _on_connected_to_server() -> void:
	_request_join.rpc_id(1, player_name, GameData.level)

@rpc("any_peer", "call_remote", "reliable")
func _request_join(requested_name: String, requested_level: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if session_mode == "raid" and requested_level < 10:
		_join_rejected.rpc_id(sender, "Kurama Raid requires Level 10.")
		return
	if multiplayer.get_peers().size() > MAX_CLIENTS:
		_join_rejected.rpc_id(sender, "This room is full (8 players maximum).")
		return
	var safe_name := requested_name.strip_edges()
	if safe_name == "":
		safe_name = "Shinobi %d" % sender
	var roster: Array = []
	for id in _known_players:
		roster.append({"id": int(id), "name": str(_known_players[id]), "level": int(_known_levels.get(id, 1)), "party_leader": int(_party_leader.get(id, id))})
	_receive_roster.rpc_id(sender, roster)
	_known_players[sender] = safe_name
	_known_levels[sender] = clampi(requested_level, 1, 9999)
	_party_leader[sender] = 1 if session_mode == "raid" else sender
	_spawn_remote_local(sender, safe_name, int(_known_levels[sender]))
	_spawn_remote.rpc(sender, safe_name, int(_known_levels[sender]))
	if session_mode == "raid":
		_broadcast_party_state.rpc(_party_leader.keys(), _party_leader.values())
	_join_accepted.rpc_id(sender, session_mode)

@rpc("authority", "call_remote", "reliable")
func _receive_roster(roster: Array) -> void:
	for entry in roster:
		var id := int(entry.get("id", 0))
		var nm := str(entry.get("name", "Shinobi"))
		var lv := int(entry.get("level", 1))
		_known_players[id] = nm
		_known_levels[id] = lv
		_party_leader[id] = int(entry.get("party_leader", id))
		if id != multiplayer.get_unique_id():
			_spawn_remote_local(id, nm, lv)
	party_updated.emit()

@rpc("authority", "call_remote", "reliable")
func _spawn_remote(peer_id: int, display_name: String, level: int) -> void:
	_known_players[peer_id] = display_name
	_known_levels[peer_id] = level
	if peer_id != multiplayer.get_unique_id():
		_spawn_remote_local(peer_id, display_name, level)

func _spawn_remote_local(peer_id: int, display_name: String, level: int = 1) -> void:
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
	avatar.set("player_level", level)
	avatar.set("is_party_member", _same_party(multiplayer.get_unique_id(), peer_id))
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
	GameData.mode = "world" if mode == "coop" else ("kurama" if mode == "raid" else "fight")
	var local_id := multiplayer.get_unique_id()
	_known_players[local_id] = player_name
	_known_levels[local_id] = GameData.level
	_party_leader[local_id] = 1 if mode == "raid" else local_id
	party_updated.emit()
	connection_succeeded.emit()

@rpc("authority", "call_remote", "reliable")
func _join_rejected(message: String) -> void:
	connection_failed.emit(message)
	disconnect_session()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _party_leader.has(peer_id):
		_server_leave_party(peer_id)
	_known_players.erase(peer_id)
	_known_levels.erase(peer_id)
	_party_leader.erase(peer_id)
	_remove_remote_local(peer_id)
	_despawn_remote.rpc(peer_id)

@rpc("authority", "call_remote", "reliable")
func _despawn_remote(peer_id: int) -> void:
	_known_players.erase(peer_id)
	_known_levels.erase(peer_id)
	_party_leader.erase(peer_id)
	_remove_remote_local(peer_id)

func _remove_remote_local(peer_id: int) -> void:
	if _avatars.has(peer_id):
		var avatar = _avatars[peer_id]
		if is_instance_valid(avatar):
			avatar.queue_free()
		_avatars.erase(peer_id)

## Party system: party leader ID is shared by every member.
func _same_party(a_id: int, b_id: int) -> bool:
	return _party_leader.has(a_id) and _party_leader.has(b_id) and int(_party_leader[a_id]) == int(_party_leader[b_id])

func invite_to_party(target_id: int) -> void:
	if not is_active() or target_id == multiplayer.get_unique_id():
		return
	if multiplayer.is_server():
		_server_party_invite(1, target_id)
	else:
		_request_party_invite.rpc_id(1, target_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_party_invite(target_id: int) -> void:
	if multiplayer.is_server():
		_server_party_invite(multiplayer.get_remote_sender_id(), target_id)

func _server_party_invite(sender_id: int, target_id: int) -> void:
	if not _known_players.has(sender_id) or not _known_players.has(target_id):
		return
	var leader := int(_party_leader.get(sender_id, sender_id))
	if _party_size(leader) >= 4:
		return
	_pending_party_invites[target_id] = leader
	if target_id == 1:
		party_invite_received.emit(sender_id, str(_known_players[sender_id]))
	else:
		_party_invite.rpc_id(target_id, sender_id, str(_known_players[sender_id]), leader)

@rpc("authority", "call_remote", "reliable")
func _party_invite(inviter_id: int, inviter_name: String, leader_id: int) -> void:
	_pending_party_invites[leader_id] = inviter_id
	party_invite_received.emit(inviter_id, inviter_name)

func decline_party_invite(inviter_id: int) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_pending_party_invites.erase(1)
	else:
		_request_decline_party.rpc_id(1, inviter_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_decline_party(inviter_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if int(_pending_party_invites.get(sender, -1)) == int(_party_leader.get(inviter_id, inviter_id)):
		_pending_party_invites.erase(sender)

func accept_party_invite(inviter_id: int) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_server_accept_party(1, inviter_id)
	else:
		_request_accept_party.rpc_id(1, inviter_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_accept_party(inviter_id: int) -> void:
	if multiplayer.is_server():
		_server_accept_party(multiplayer.get_remote_sender_id(), inviter_id)

func _server_accept_party(member_id: int, inviter_id: int) -> void:
	var leader := int(_party_leader.get(inviter_id, inviter_id))
	if int(_pending_party_invites.get(member_id, -1)) != leader or _party_size(leader) >= 4:
		return
	_party_leader[member_id] = leader
	_pending_party_invites.erase(member_id)
	_broadcast_party_state.rpc(_party_leader.keys(), _party_leader.values())
	_apply_party_state(_party_leader.keys(), _party_leader.values())
	_send_party_quest_state_to_member(member_id, leader)

@rpc("authority", "call_remote", "reliable")
func _broadcast_party_state(ids: Array, leaders: Array) -> void:
	_apply_party_state(ids, leaders)

func _apply_party_state(ids: Array, leaders: Array) -> void:
	for i in mini(ids.size(), leaders.size()):
		_party_leader[int(ids[i])] = int(leaders[i])
	for peer_id in _avatars:
		if is_instance_valid(_avatars[peer_id]):
			_avatars[peer_id].set_party_member(_same_party(multiplayer.get_unique_id(), int(peer_id)))
	party_updated.emit()

func leave_party() -> void:
	if not is_active():
		return
	var my_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_server_leave_party(my_id)
	else:
		_request_leave_party.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _request_leave_party() -> void:
	if multiplayer.is_server():
		_server_leave_party(multiplayer.get_remote_sender_id())

func _server_leave_party(member_id: int) -> void:
	if not _party_leader.has(member_id):
		return
	var old_leader := int(_party_leader[member_id])
	var members: Array[int] = []
	for id in _party_leader:
		if int(_party_leader[id]) == old_leader and int(id) != member_id:
			members.append(int(id))
	var promoted_leader := old_leader
	if member_id == old_leader and not members.is_empty():
		members.sort()
		promoted_leader = members[0]
		for id in members:
			_party_leader[id] = promoted_leader
		if _party_quest_states.has(old_leader):
			_party_quest_states[promoted_leader] = _party_quest_states[old_leader]
			_party_quest_states.erase(old_leader)
	_party_leader[member_id] = member_id
	_broadcast_party_state.rpc(_party_leader.keys(), _party_leader.values())
	_apply_party_state(_party_leader.keys(), _party_leader.values())
	if promoted_leader != old_leader and _party_quest_states.has(promoted_leader):
		var shared: Dictionary = _party_quest_states[promoted_leader]
		_publish_party_quest_state(promoted_leader, str(shared.get("id", "")), str(shared.get("state", "")), int(shared.get("progress", 0)))

func _party_size(leader_id: int) -> int:
	var count := 0
	for peer_id in _party_leader:
		if int(_party_leader[peer_id]) == leader_id:
			count += 1
	return count

func local_party_leader() -> int:
	if multiplayer.is_server() and _server_quest_leader_override > 0:
		return _server_quest_leader_override
	if not is_active():
		return 1
	var local_id := multiplayer.get_unique_id()
	return int(_party_leader.get(local_id, local_id))

func register_quest_manager(manager: Quests) -> bool:
	_quest_manager = manager
	if not is_active() or session_mode != "coop":
		return false
	var leader := local_party_leader()
	if _party_quest_states.has(leader):
		var state: Dictionary = _party_quest_states[leader]
		_server_quest_leader_override = leader if multiplayer.is_server() else 0
		manager.apply_shared_quest_state(str(state.get("id", "")), str(state.get("state", "")), int(state.get("progress", 0)))
		_server_quest_leader_override = 0
		return true
	if multiplayer.is_server():
		for party_leader in _party_quest_states:
			var party_state: Dictionary = _party_quest_states[party_leader]
			_server_quest_leader_override = int(party_leader)
			manager.apply_shared_quest_state(str(party_state.get("id", "")), str(party_state.get("state", "")), int(party_state.get("progress", 0)))
			_server_quest_leader_override = 0
			return true
		if GameData.quest_active != "":
			_publish_party_quest_state(leader, GameData.quest_active, GameData.quest_state, GameData.quest_progress)
			return true
	return false

func request_party_quest_accept(quest_id: String) -> void:
	if not is_active() or session_mode != "coop":
		return
	if multiplayer.is_server():
		_server_party_quest_accept(1, quest_id)
	else:
		_request_party_quest_accept.rpc_id(1, quest_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_party_quest_accept(quest_id: String) -> void:
	if multiplayer.is_server():
		_server_party_quest_accept(multiplayer.get_remote_sender_id(), quest_id)

func _server_party_quest_accept(sender_id: int, quest_id: String) -> void:
	if not _known_players.has(sender_id):
		return
	Quests.ensure_loaded()
	if not Quests.DEFS.has(quest_id):
		return
	var leader := int(_party_leader.get(sender_id, sender_id))
	if _party_quest_states.has(leader):
		var existing: Dictionary = _party_quest_states[leader]
		if str(existing.get("id", "")) != "":
			_publish_party_quest_state(leader, str(existing["id"]), str(existing["state"]), int(existing["progress"]))
			return
	_publish_party_quest_state(leader, quest_id, "active", 0)

func request_party_quest_ready(quest_id: String) -> void:
	if not is_active() or session_mode != "coop" or quest_id == "":
		return
	if multiplayer.is_server():
		_server_party_quest_ready(1, quest_id)
	else:
		_request_party_quest_ready.rpc_id(1, quest_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_party_quest_ready(quest_id: String) -> void:
	if multiplayer.is_server():
		_server_party_quest_ready(multiplayer.get_remote_sender_id(), quest_id)

func _server_party_quest_ready(sender_id: int, quest_id: String) -> void:
	if not _known_players.has(sender_id):
		return
	var leader := int(_party_leader.get(sender_id, sender_id))
	if not _party_quest_states.has(leader):
		return
	var state: Dictionary = _party_quest_states[leader]
	if str(state.get("id", "")) != quest_id or str(state.get("state", "")) != "active":
		return
	_publish_party_quest_state(leader, quest_id, "ready", int(state.get("progress", 0)))

func _publish_party_quest_state(leader_id: int, quest_id: String, state: String, progress: int) -> void:
	_party_quest_states[leader_id] = {"id": quest_id, "state": state, "progress": progress}
	# The server simulates quest enemies even when the host player is not in
	# the party that accepted the quest; rewards are still restricted to members.
	if _quest_manager != null and is_instance_valid(_quest_manager):
		_server_quest_leader_override = leader_id
		_quest_manager.apply_shared_quest_state(quest_id, state, progress)
		_server_quest_leader_override = 0
	for id in _known_players:
		var peer_id := int(id)
		if peer_id != 1 and _same_party(peer_id, leader_id):
			_receive_party_quest_state.rpc_id(peer_id, leader_id, quest_id, state, progress)

@rpc("authority", "call_remote", "reliable")
func _receive_party_quest_state(leader_id: int, quest_id: String, state: String, progress: int) -> void:
	if not _same_party(multiplayer.get_unique_id(), leader_id):
		return
	_party_quest_states[leader_id] = {"id": quest_id, "state": state, "progress": progress}
	if _quest_manager != null and is_instance_valid(_quest_manager):
		_quest_manager.apply_shared_quest_state(quest_id, state, progress)

func _send_party_quest_state_to_member(peer_id: int, leader_id: int) -> void:
	if not _party_quest_states.has(leader_id):
		return
	var state: Dictionary = _party_quest_states[leader_id]
	_receive_party_quest_state.rpc_id(peer_id, leader_id, str(state.get("id", "")), str(state.get("state", "")), int(state.get("progress", 0)))

func request_party_quest_turn_in(quest_id: String) -> void:
	if not is_active() or session_mode != "coop" or quest_id == "":
		return
	if multiplayer.is_server():
		_server_party_quest_turn_in(1, quest_id, GameData.level)
	else:
		_request_party_quest_turn_in.rpc_id(1, quest_id, GameData.level)

@rpc("any_peer", "call_remote", "reliable")
func _request_party_quest_turn_in(quest_id: String, player_level: int) -> void:
	if multiplayer.is_server():
		_server_party_quest_turn_in(multiplayer.get_remote_sender_id(), quest_id, player_level)

func _server_party_quest_turn_in(sender_id: int, quest_id: String, player_level: int) -> void:
	if not _known_players.has(sender_id):
		return
	var leader := int(_party_leader.get(sender_id, sender_id))
	if not _party_quest_states.has(leader):
		return
	var state: Dictionary = _party_quest_states[leader]
	if str(state.get("id", "")) != quest_id or str(state.get("state", "")) != "ready":
		return
	Quests.ensure_loaded()
	var d: Dictionary = Quests.DEFS.get(quest_id, {})
	if d.is_empty():
		return
	var base_level := clampi(player_level, 1, GameData.MAX_LEVEL)
	var xp := int(d.get("xp", 0))
	for i in int(d.get("levels", 0)):
		xp += GameData.xp_needed(base_level + i)
	var spins := int(d.get("reward", 0))
	_party_quest_states.erase(leader)
	var host_in_party := _same_party(1, leader)
	for id in _known_players:
		var peer_id := int(id)
		if not _same_party(peer_id, leader):
			continue
		if peer_id == 1:
			if _quest_manager != null and is_instance_valid(_quest_manager):
				_quest_manager.apply_party_quest_reward(quest_id, xp, spins)
		else:
			_receive_party_quest_reward.rpc_id(peer_id, quest_id, xp, spins)
	if not host_in_party and _quest_manager != null and is_instance_valid(_quest_manager):
		_quest_manager.apply_shared_quest_state("", "", 0)

@rpc("authority", "call_remote", "reliable")
func _receive_party_quest_reward(quest_id: String, xp: int, spins: int) -> void:
	if _quest_manager != null and is_instance_valid(_quest_manager):
		_quest_manager.apply_party_quest_reward(quest_id, xp, spins)
	_party_quest_states.erase(local_party_leader())

func quest_enemy_killed(enemy_id: String, leader_id: int) -> void:
	if not is_active() or session_mode != "coop" or not multiplayer.is_server():
		return
	_remove_quest_enemy.rpc(enemy_id)
	_grant_party_quest_kill_reward(leader_id)
	if not _party_quest_states.has(leader_id):
		return
	var state: Dictionary = _party_quest_states[leader_id]
	var quest_id := str(state.get("id", ""))
	if quest_id == "" or str(state.get("state", "")) != "active":
		return
	Quests.ensure_loaded()
	var d: Dictionary = Quests.DEFS.get(quest_id, {})
	if d.is_empty() or not ["kill", "hunt"].has(str(d.get("type", ""))):
		return
	var progress := mini(int(state.get("progress", 0)) + 1, int(d.get("count", 1)))
	var next_state := "ready" if progress >= int(d.get("count", 1)) else "active"
	_publish_party_quest_state(leader_id, quest_id, next_state, progress)

func _grant_party_quest_kill_reward(leader_id: int) -> void:
	for id in _known_players:
		var peer_id := int(id)
		if not _same_party(peer_id, leader_id):
			continue
		if peer_id == 1:
			_apply_local_party_quest_kill_reward()
		else:
			_party_quest_kill_reward.rpc_id(peer_id)

func _apply_local_party_quest_kill_reward() -> void:
	if _local_player == null:
		return
	_local_player.kills += 1
	_local_player.on_kill(false)
	_local_player.add_mode(10.0)
	_local_player.chakra = minf(_local_player.max_chakra, _local_player.chakra + 10.0)

@rpc("authority", "call_remote", "reliable")
func _party_quest_kill_reward() -> void:
	_apply_local_party_quest_kill_reward()

func damage_quest_party_member(peer_id: int, leader_id: int, amount: float, knockback: Vector3) -> void:
	if not is_active() or not multiplayer.is_server() or not _same_party(peer_id, leader_id):
		return
	var safe_damage := clampf(amount, 1.0, 80.0)
	if peer_id == 1 and _local_player != null:
		_local_player.take_damage(safe_damage, knockback)
	elif _known_players.has(peer_id):
		_apply_player_damage.rpc_id(peer_id, safe_damage, knockback)

func request_quest_enemy_damage(enemy_id: String, amount: float, knock: Vector3) -> void:
	if not is_active() or session_mode != "coop" or enemy_id == "":
		return
	if multiplayer.is_server():
		_server_quest_enemy_damage(1, enemy_id, amount, knock)
	else:
		_request_quest_enemy_damage.rpc_id(1, enemy_id, amount, knock)

@rpc("any_peer", "call_remote", "reliable")
func _request_quest_enemy_damage(enemy_id: String, amount: float, knock: Vector3) -> void:
	if multiplayer.is_server():
		_server_quest_enemy_damage(multiplayer.get_remote_sender_id(), enemy_id, amount, knock)

func _server_quest_enemy_damage(sender_id: int, enemy_id: String, amount: float, knock: Vector3) -> void:
	if not _known_players.has(sender_id):
		return
	var enemy: Enemy
	for candidate in get_tree().get_nodes_in_group("quest_enemies"):
		if candidate is Enemy and (candidate as Enemy).network_quest_id == enemy_id:
			enemy = candidate as Enemy
			break
	if enemy == null or enemy.health <= 0.0 or enemy.network_quest_defeated or enemy.network_quest_mirror or not _same_party(sender_id, enemy.network_quest_party_leader):
		return
	var attacker_pos := Vector3.ZERO
	if sender_id == 1:
		if _local_player == null:
			return
		attacker_pos = _local_player.global_position
	elif _avatars.has(sender_id) and is_instance_valid(_avatars[sender_id]):
		attacker_pos = _avatars[sender_id].global_position
	else:
		return
	if attacker_pos.distance_to(enemy.global_position) > 55.0:
		return
	enemy.take_damage(clampf(amount, 1.0, 150.0), knock.limit_length(18.0))

func _sync_quest_enemy_states() -> void:
	for node in get_tree().get_nodes_in_group("quest_enemies"):
		if not node is Enemy:
			continue
		var enemy := node as Enemy
		if enemy.network_quest_id == "" or enemy.network_quest_mirror:
			continue
		var yaw := enemy.model.rotation.y if enemy.model != null else 0.0
		_quest_enemy_state.rpc(enemy.network_quest_id, enemy.global_position, yaw, enemy.health)

@rpc("authority", "call_remote", "unreliable_ordered")
func _quest_enemy_state(enemy_id: String, pos: Vector3, yaw: float, hp: float) -> void:
	for node in get_tree().get_nodes_in_group("quest_enemies"):
		if node is Enemy and (node as Enemy).network_quest_id == enemy_id:
			(node as Enemy).apply_quest_network_state(pos, yaw, hp)
			return

@rpc("authority", "call_remote", "reliable")
func _remove_quest_enemy(enemy_id: String) -> void:
	for node in get_tree().get_nodes_in_group("quest_enemies"):
		if node is Enemy and (node as Enemy).network_quest_id == enemy_id:
			(node as Enemy).queue_free()
			return

## Shared Kurama raid. Host simulates the boss; clients receive authoritative snapshots.
func register_raid_boss(boss: Kurama) -> void:
	_raid_boss = boss

## Called by the authoritative host after Kurama's defeat sequence.
## The RPC changes every participant back to the open world without ending
## the network session, preserving the party leader/member roster.
func complete_kurama_raid() -> void:
	if not is_active() or session_mode != "raid" or not multiplayer.is_server():
		return
	_return_raid_party_to_world.rpc()

@rpc("authority", "call_local", "reliable")
func _return_raid_party_to_world() -> void:
	if not is_active():
		return
	_raid_boss = null
	_raid_sync_timer = 0.0
	session_mode = "coop"
	GameData.mode = "world"
	get_tree().change_scene_to_file("res://main.tscn")

@rpc("authority", "call_remote", "unreliable_ordered")
func _raid_snapshot(pos: Vector3, yaw: float, hp: float, boss_phase: int, boss_state: int, attack: String, attack_time: float, attack_length: float, target_pos: Vector3) -> void:
	if multiplayer.is_server() or _raid_boss == null or not is_instance_valid(_raid_boss):
		return
	_raid_boss.apply_raid_snapshot(pos, yaw, hp, boss_phase, boss_state, attack, attack_time, attack_length, target_pos)

func request_raid_boss_damage(amount: float) -> void:
	if not is_active() or session_mode != "raid":
		return
	if multiplayer.is_server():
		if _raid_boss != null and is_instance_valid(_raid_boss):
			_raid_boss.take_damage(amount)
	else:
		_request_raid_boss_damage.rpc_id(1, amount)

@rpc("any_peer", "call_remote", "reliable")
func _request_raid_boss_damage(amount: float) -> void:
	if not multiplayer.is_server() or session_mode != "raid" or _raid_boss == null or not is_instance_valid(_raid_boss):
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _avatars.has(sender) or not is_instance_valid(_avatars[sender]):
		return
	if _avatars[sender].global_position.distance_to(_raid_boss.global_position) > 42.0:
		return
	_raid_boss.take_damage(clampf(amount, 1.0, 120.0))

func raid_apply_boss_attack(move: String, boss_pos: Vector3, forward: Vector3, slam_target: Vector3, boss_phase: int) -> void:
	if not is_active() or session_mode != "raid" or not multiplayer.is_server():
		return
	var damage := 0.0
	var radius := 0.0
	match move:
		"claw":
			damage = Kurama.CLAW_DMG * (1.0 + 0.15 * float(boss_phase - 1))
			radius = Kurama.CLAW_RANGE
		"slam":
			damage = Kurama.SLAM_DMG * (1.0 + 0.15 * float(boss_phase - 1))
			radius = Kurama.SLAM_RADIUS
		"roar":
			damage = Kurama.ROAR_DMG * (1.0 + 0.15 * float(boss_phase - 1))
			radius = Kurama.ROAR_RADIUS
		_:
			return
	var targets: Array[int] = [1]
	for id in _avatars:
		targets.append(int(id))
	for target_id in targets:
		var target_pos := Vector3.ZERO
		var target_player: Player
		if target_id == 1:
			target_player = _local_player
			if target_player == null or target_player.is_dead:
				continue
			target_pos = target_player.global_position
		else:
			if not _avatars.has(target_id) or not is_instance_valid(_avatars[target_id]):
				continue
			target_pos = _avatars[target_id].global_position
		var delta := target_pos - (slam_target if move == "slam" else boss_pos)
		delta.y = 0.0
		var hit := delta.length() < radius
		if move == "claw":
			var to_boss := target_pos - boss_pos
			to_boss.y = 0.0
			hit = to_boss.length() < radius and forward.dot(to_boss.normalized()) > 0.25
		if move == "roar":
			hit = hit and target_pos.y < 0.7
		elif move == "slam":
			hit = hit and target_pos.y < 3.0
		if hit:
			var knock := delta.normalized() * (16.0 if move == "claw" else (18.0 if move == "roar" else 14.0))
			if target_id == 1:
				target_player.take_damage(damage, knock)
			else:
				_apply_player_damage.rpc_id(target_id, damage, knock)

func request_projectile_player_hit(attacker_id: int, damage: float, impact_position: Vector3) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_server_projectile_player_hit(attacker_id, multiplayer.get_unique_id(), damage, impact_position)
	else:
		_request_projectile_player_hit.rpc_id(1, attacker_id, damage, impact_position)

@rpc("any_peer", "call_remote", "reliable")
func _request_projectile_player_hit(attacker_id: int, damage: float, impact_position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_server_projectile_player_hit(attacker_id, multiplayer.get_remote_sender_id(), damage, impact_position)

func _server_projectile_player_hit(attacker_id: int, target_id: int, damage: float, impact_position: Vector3) -> void:
	if attacker_id == target_id or not _known_players.has(attacker_id) or not _known_players.has(target_id) or _same_party(attacker_id, target_id):
		return
	var target_pos: Vector3
	if target_id == 1 and _local_player != null:
		target_pos = _local_player.global_position
	elif _avatars.has(target_id) and is_instance_valid(_avatars[target_id]):
		target_pos = _avatars[target_id].global_position
	else:
		return
	if target_pos.distance_to(impact_position) > 3.5:
		return
	var safe_damage := clampf(damage, 1.0, 80.0)
	if target_id == 1 and _local_player != null:
		_local_player.take_damage(safe_damage, Vector3.ZERO)
	else:
		_apply_player_damage.rpc_id(target_id, safe_damage, Vector3.ZERO)

func try_hit_players(damage: float, knockback: Vector3) -> void:
	if not is_active() or session_mode != "pvp":
		return
	for peer_id in _avatars.keys():
		if _same_party(multiplayer.get_unique_id(), int(peer_id)):
			continue
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
	if attacker_id == target_id or not _known_players.has(target_id) or _same_party(attacker_id, target_id):
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


## Replicate the persistent bloodline power-up aura on remote player avatars.
func broadcast_power_state(enabled: bool, color: Color) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_broadcast_power_state.rpc(1, enabled, color)
	else:
		_request_power_state.rpc_id(1, enabled, color)

@rpc("any_peer", "call_remote", "reliable")
func _request_power_state(enabled: bool, color: Color) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender):
		return
	_apply_power_state(sender, enabled, color)
	_broadcast_power_state.rpc(sender, enabled, color)

@rpc("authority", "call_remote", "reliable")
func _broadcast_power_state(peer_id: int, enabled: bool, color: Color) -> void:
	_apply_power_state(peer_id, enabled, color)

func _apply_power_state(peer_id: int, enabled: bool, color: Color) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	if _avatars.has(peer_id) and is_instance_valid(_avatars[peer_id]):
		_avatars[peer_id].set_powered_visual(enabled, color)

## Replicate Kurama Mode (Z) on remote avatars.
func broadcast_kurama_state(enabled: bool) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_broadcast_kurama_state.rpc(1, enabled)
	else:
		_request_kurama_state.rpc_id(1, enabled)

@rpc("any_peer", "call_remote", "reliable")
func _request_kurama_state(enabled: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender):
		return
	# The host must update its own remote avatar; RPC call_remote never runs locally.
	if _avatars.has(sender) and is_instance_valid(_avatars[sender]):
		_avatars[sender].set_kurama_visual(enabled)
	_broadcast_kurama_state.rpc(sender, enabled)

@rpc("authority", "call_remote", "reliable")
func _broadcast_kurama_state(peer_id: int, enabled: bool) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	if _avatars.has(peer_id) and is_instance_valid(_avatars[peer_id]):
		_avatars[peer_id].set_kurama_visual(enabled)

## Relay basic combat animation events (melee, dash, throw) to remote avatars.
func broadcast_combat_animation(state: String, variant: int = 0) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_broadcast_combat_animation.rpc(1, state, variant)
	else:
		_request_combat_animation.rpc_id(1, state, variant)

@rpc("any_peer", "call_remote", "reliable")
func _request_combat_animation(state: String, variant: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender):
		return
	# Apply on the host too; call_remote RPCs are not executed on the sending server.
	if _avatars.has(sender) and is_instance_valid(_avatars[sender]):
		_avatars[sender].play_combat_animation(state, variant)
	_broadcast_combat_animation.rpc(sender, state, variant)

@rpc("authority", "call_remote", "reliable")
func _broadcast_combat_animation(peer_id: int, state: String, variant: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	if _avatars.has(peer_id) and is_instance_valid(_avatars[peer_id]):
		_avatars[peer_id].play_combat_animation(state, variant)

## Broadcast a successful ability cast so every peer can render its remote visual.
func broadcast_ability(move_id: String, color: Color) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_broadcast_ability_visual.rpc(1, move_id, color)
	else:
		_request_ability_visual.rpc_id(1, move_id, color)



## Replicate clone spawns and their live transforms. Remote clones are visual-only.
func broadcast_shadow_clones(clones: Array[Clone], lifetime: float) -> void:
	if not is_active():
		return
	var summon_id := _next_clone_summon_id
	_next_clone_summon_id += 1
	var spawn_positions: Array[Vector3] = []
	for i in clones.size():
		var clone := clones[i]
		clone.network_peer_id = multiplayer.get_unique_id()
		clone.network_summon_id = summon_id
		clone.network_clone_index = i
		spawn_positions.append(clone.global_position)
	if multiplayer.is_server():
		_broadcast_shadow_clones.rpc(1, summon_id, spawn_positions, lifetime)
	else:
		_request_shadow_clones.rpc_id(1, summon_id, spawn_positions, lifetime)

@rpc("any_peer", "call_remote", "reliable")
func _request_shadow_clones(summon_id: int, spawn_positions: Array[Vector3], lifetime: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender):
		return
	_spawn_remote_clones(sender, summon_id, spawn_positions, lifetime)
	_broadcast_shadow_clones.rpc(sender, summon_id, spawn_positions, lifetime)

@rpc("authority", "call_remote", "reliable")
func _broadcast_shadow_clones(peer_id: int, summon_id: int, spawn_positions: Array[Vector3], lifetime: float) -> void:
	_spawn_remote_clones(peer_id, summon_id, spawn_positions, lifetime)

func _spawn_remote_clones(peer_id: int, summon_id: int, spawn_positions: Array[Vector3], lifetime: float) -> void:
	if peer_id == multiplayer.get_unique_id() or _game_root == null or not is_instance_valid(_game_root):
		return
	for i in spawn_positions.size():
		var key := "%d:%d:%d" % [peer_id, summon_id, i]
		if _remote_clones.has(key) and is_instance_valid(_remote_clones[key]):
			continue
		var clone := Clone.new()
		clone.life = clampf(lifetime, 0.5, 20.0)
		clone.cosmetic_only = true
		clone.network_peer_id = peer_id
		clone.network_summon_id = summon_id
		clone.network_clone_index = i
		_game_root.add_child(clone)
		clone.global_position = spawn_positions[i]
		_remote_clones[key] = clone

func _sync_shadow_clone_transforms() -> void:
	var ids := PackedInt32Array()
	var indices := PackedInt32Array()
	var positions := PackedVector3Array()
	var yaws := PackedFloat32Array()
	var owner_id := multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("shadow_clones"):
		var clone := node as Clone
		if clone == null or clone.cosmetic_only or clone.network_peer_id != owner_id:
			continue
		ids.append(clone.network_summon_id)
		indices.append(clone.network_clone_index)
		positions.append(clone.global_position)
		yaws.append(clone.model.rotation.y if clone.model != null else 0.0)
	if ids.is_empty():
		return
	if multiplayer.is_server():
		_broadcast_shadow_clone_states.rpc(owner_id, ids, indices, positions, yaws)
	else:
		_submit_shadow_clone_states.rpc_id(1, ids, indices, positions, yaws)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_shadow_clone_states(ids: PackedInt32Array, indices: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender) or ids.size() != indices.size() or ids.size() != positions.size() or ids.size() != yaws.size():
		return
	_apply_shadow_clone_states(sender, ids, indices, positions, yaws)
	_broadcast_shadow_clone_states.rpc(sender, ids, indices, positions, yaws)

@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_shadow_clone_states(peer_id: int, ids: PackedInt32Array, indices: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	_apply_shadow_clone_states(peer_id, ids, indices, positions, yaws)

func _apply_shadow_clone_states(peer_id: int, ids: PackedInt32Array, indices: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	for i in ids.size():
		var key := "%d:%d:%d" % [peer_id, ids[i], indices[i]]
		if not _remote_clones.has(key) or not is_instance_valid(_remote_clones[key]):
			continue
		var clone: Clone = _remote_clones[key]
		clone.set_network_transform(positions[i], yaws[i])

func broadcast_projectile(origin: Vector3, velocity: Vector3, speed: float, size: float, color: Color, long_shape: bool, aoe: float, damage: float) -> void:
	if not is_active():
		return
	if multiplayer.is_server():
		_broadcast_projectile_visual.rpc(1, origin, velocity, speed, size, color, long_shape, aoe, damage)
	else:
		_request_projectile_visual.rpc_id(1, origin, velocity, speed, size, color, long_shape, aoe, damage)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _request_projectile_visual(origin: Vector3, velocity: Vector3, speed: float, size: float, color: Color, long_shape: bool, aoe: float, damage: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _known_players.has(sender):
		return
	_show_remote_projectile(sender, origin, velocity, speed, size, color, long_shape, aoe, damage)
	_broadcast_projectile_visual.rpc(sender, origin, velocity, speed, size, color, long_shape, aoe, damage)

@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_projectile_visual(peer_id: int, origin: Vector3, velocity: Vector3, speed: float, size: float, color: Color, long_shape: bool, aoe: float, damage: float) -> void:
	_show_remote_projectile(peer_id, origin, velocity, speed, size, color, long_shape, aoe, damage)

func _show_remote_projectile(peer_id: int, origin: Vector3, velocity: Vector3, speed: float, size: float, color: Color, long_shape: bool, aoe: float, damage: float) -> void:
	if _avatars.has(peer_id) and is_instance_valid(_avatars[peer_id]):
		_avatars[peer_id].play_projectile(origin, velocity, speed, size, color, long_shape, aoe, damage)

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
