extends Node
## Multiplayer ragdoll death relay.
##
## Install this script as an Autoload named "RagdollSync".
## It watches NetworkSession's local Player for death, asks the host to relay
## the event, and starts a local physics ragdoll on each remote avatar.
##
## Requires the existing project scripts/classes:
##   NetworkSession (autoload), Player, Ragdoll, and multiplayer_avatar.gd.

var _local_death_sent := false


func _process(_delta: float) -> void:
	if not NetworkSession.is_active():
		_local_death_sent = false
		return

	var local_player := NetworkSession.get("_local_player") as Player
	if local_player == null or not is_instance_valid(local_player):
		return

	if not local_player.is_dead:
		_local_death_sent = false
		return

	if _local_death_sent:
		return

	_local_death_sent = true

	var player_model: Node3D = local_player.model
	var facing_yaw := player_model.rotation.y if is_instance_valid(player_model) else 0.0
	# The local Player has already applied its hit knockback before dying.
	var launch_velocity := Vector3(
		local_player.velocity.x * 0.5,
		3.0,
		local_player.velocity.z * 0.5
	)

	if multiplayer.is_server():
		_broadcast_ragdoll.rpc(
			multiplayer.get_unique_id(),
			local_player.global_position,
			facing_yaw,
			launch_velocity
		)
	else:
		_request_ragdoll.rpc_id(
			1,
			local_player.global_position,
			facing_yaw,
			launch_velocity
		)


@rpc("any_peer", "call_remote", "reliable")
func _request_ragdoll(position: Vector3, yaw: float, launch_velocity: Vector3) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	var known_players: Dictionary = NetworkSession.get("_known_players")
	if not known_players.has(sender_id):
		return

	# Keep client-provided physics values within sensible bounds.
	var safe_position := position
	var safe_yaw := yaw
	var safe_velocity := launch_velocity.limit_length(35.0)

	# call_remote does not execute on the host, so apply the client's death
	# to the host's remote avatar explicitly before relaying it.
	_apply_remote_ragdoll(sender_id, safe_position, safe_yaw, safe_velocity)
	_broadcast_ragdoll.rpc(sender_id, safe_position, safe_yaw, safe_velocity)


@rpc("authority", "call_remote", "reliable")
func _broadcast_ragdoll(
	peer_id: int,
	position: Vector3,
	yaw: float,
	launch_velocity: Vector3
) -> void:
	if peer_id == multiplayer.get_unique_id():
		return

	_apply_remote_ragdoll(
		peer_id,
		position,
		yaw,
		launch_velocity.limit_length(35.0)
	)


func _apply_remote_ragdoll(
	peer_id: int,
	position: Vector3,
	yaw: float,
	launch_velocity: Vector3
) -> void:
	var avatars: Dictionary = NetworkSession.get("_avatars")
	if not avatars.has(peer_id):
		return

	var avatar := avatars[peer_id] as Node3D
	if avatar == null or not is_instance_valid(avatar):
		return

	# Avoid starting a second ragdoll if a reliable event is received twice.
	if avatar.has_meta("network_ragdoll_started"):
		return
	avatar.set_meta("network_ragdoll_started", true)

	avatar.global_position = position
	var model := avatar.get("model") as Node3D
	if model == null or not is_instance_valid(model):
		return

	model.rotation.y = yaw

	# Stop the avatar's interpolation/animation so it cannot fight the physics.
	avatar.set_process(false)
	avatar.set_physics_process(false)

	var name_tag := avatar.get("name_tag") as Label3D
	if name_tag != null:
		name_tag.visible = false

	# Parent the ragdoll under the remote avatar. Its rigid bodies use global
	# transforms, so they remain aligned with the skeleton as they fall.
	var ragdoll := Ragdoll.start(model, avatar, launch_velocity)
	if ragdoll == null:
		# If this character's skeleton is incompatible, leave a stable death
		# pose rather than letting the standing avatar keep moving.
		Hero.play(model, "die", true)
