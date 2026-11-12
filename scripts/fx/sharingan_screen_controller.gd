extends Node
## Watches the local Player and starts the one-shot Sharingan screen effect for Uchiha mode.

const SHARINGAN_EFFECT_SCRIPT := preload("res://scripts/fx/sharingan_effect.gd")

var _tracked_player: Node = null
var _was_active := false

func _process(_delta: float) -> void:
	if _tracked_player == null or not is_instance_valid(_tracked_player):
		_tracked_player = get_tree().get_first_node_in_group("player")
		_was_active = false
		if _tracked_player == null:
			return

	var is_powered := bool(_tracked_player.get("powered")) and not bool(_tracked_player.get("is_dead"))
	if is_powered and not _was_active:
		# Which activation cutscene: bloodline mode "cutscene" ("eyes" = Sharingan close-up,
		# "body" = full-body transformation).
		var mode: Dictionary = Bloodline.mode(str(GameData.equipped))
		var pm = _tracked_player.get("pmode")
		if pm is Dictionary and not (pm as Dictionary).is_empty():
			mode = pm   # the player's own version (e.g. Ink Mode in their colour)
		match str(mode.get("cutscene", "")):
			"eyes":
				_stop_old_procedural_power_sound()
				SHARINGAN_EFFECT_SCRIPT.play_cutscene(_tracked_player, str(GameData.equipped))
			"body":
				TransformCutscene.play(_tracked_player, mode)
	_was_active = is_powered

func _stop_old_procedural_power_sound() -> void:
	# Sfx.play(self, "power") creates an unnamed root AudioStreamPlayer with an
	# in-memory AudioStreamWAV of about 0.8 seconds. Stop only that generated cue;
	# the supplied MP3 is AudioStreamMP3 and is deliberately left playing.
	for child in get_tree().root.get_children():
		if child is AudioStreamPlayer and child.stream is AudioStreamWAV:
			var wav_stream: AudioStreamWAV = child.stream as AudioStreamWAV
			var stream_length: float = wav_stream.get_length()
			if child.name.begins_with("AudioStreamPlayer") and stream_length >= 0.7 and stream_length <= 0.9:
				child.stop()
				child.queue_free()
