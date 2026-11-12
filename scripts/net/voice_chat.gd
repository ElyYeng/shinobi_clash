class_name VoiceChat
extends Node
## Proximity voice chat, voice-activated (K mutes / unmutes your mic): the mic is captured, cut down to 12 kHz
## mono, squeezed to 8-bit mu-law (~96 kbit/s while talking) and sent to every peer over the
## game's own connection (unreliable, ordered). Each player's voice plays from their character
## in 3D, so it fades with distance. Lives under the NetworkSession autoload ("VoiceChat"),
## so the RPC path is the same on every peer.

const MUTE_KEY := KEY_K
const GATE := 0.018            # mic level that counts as talking
const HANGOVER := 0.35         # keep sending this long after you stop (no clipped word ends)
const RATE := 12000            # voice sample rate
const CHUNK := 480             # samples per packet (40 ms)
const HEAR_DIST := 45.0        # metres until a voice fades out

var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
var _talking := false         # mic open (online and not muted)
var muted := false
var _k_was := false
var _open := 0.0               # voice gate: > 0 = sending
var _level := 0.0              # own mic level (mouth)
var _step := 4                 # mix rate / RATE
var _pending := PackedFloat32Array()
var _voices := {}              # peer id -> {"player": AudioStreamPlayer3D, "pb": AudioStreamGeneratorPlayback}
var _hint: Label

func _ready() -> void:
	_step = maxi(1, int(round(AudioServer.get_mix_rate() / RATE)))
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "VoiceMic")
	AudioServer.set_bus_mute(bus, true)   # never hear yourself
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(bus, _capture)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "VoiceMic"
	add_child(_mic)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_hint = Label.new()
	_hint.text = "● TALKING"
	_hint.add_theme_color_override("font_color", Color(0.4, 1.0, 0.45))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.position = Vector2(16, 120)
	_hint.visible = false
	layer.add_child(_hint)

func _process(_delta: float) -> void:
	var ns := get_parent()
	var online: bool = ns != null and ns.has_method("is_active") and ns.is_active()
	var k := Input.is_physical_key_pressed(MUTE_KEY) and not _typing()
	if k and not _k_was and online:
		muted = not muted
	_k_was = k
	var want := online and not muted
	if want != _talking:
		_talking = want
		if want:
			_capture.clear_buffer()
			_mic.play()
		else:
			_mic.stop()
			_pending.clear()
			_open = 0.0
	if _talking:
		_send_mic()
	_open = maxf(0.0, _open - _delta)
	_level = lerpf(_level, 0.0, minf(1.0, 12.0 * _delta))
	_hint.visible = online and (muted or _open > 0.0)
	_hint.text = "MIC MUTED  [K]" if muted else "● TALKING"
	_hint.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if muted else Color(0.4, 1.0, 0.45))
	var me := get_tree().get_first_node_in_group("player")
	if me != null and me.get("model") != null:
		Hero.set_mouth_open(me.get("model"), _level)
	_place_voices(_delta)

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

## Mic frames -> 12 kHz mono -> mu-law packets.
func _send_mic() -> void:
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var frames := _capture.get_buffer(n)
	var i := 0
	while i + _step <= frames.size():
		var s := 0.0
		for k in _step:
			var f: Vector2 = frames[i + k]
			s += (f.x + f.y) * 0.5
		_pending.append(s / _step)
		i += _step
	while _pending.size() >= CHUNK:
		var rms := 0.0
		for k in CHUNK:
			rms += _pending[k] * _pending[k]
		rms = sqrt(rms / CHUNK)
		if rms > GATE:   # voice activation
			_open = HANGOVER
			_level = maxf(_level, clampf(rms * 9.0, 0.0, 1.0))
		if _open > 0.0:
			var pkt := PackedByteArray()
			pkt.resize(CHUNK)
			for k in CHUNK:
				pkt[k] = _mulaw(clampf(_pending[k] * 1.6, -1.0, 1.0))
			_voice.rpc(pkt)
		_pending = _pending.slice(CHUNK)

static func _mulaw(x: float) -> int:
	var y := signf(x) * log(1.0 + 255.0 * absf(x)) / log(256.0)
	return clampi(int(round((y + 1.0) * 127.5)), 0, 255)

static func _unmulaw(b: int) -> float:
	var y := float(b) / 127.5 - 1.0
	return signf(y) * (pow(256.0, absf(y)) - 1.0) / 255.0

@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _voice(pkt: PackedByteArray) -> void:
	var from := multiplayer.get_remote_sender_id()
	if pkt.size() != CHUNK:
		return
	var v := _voice_for(from)
	if v.is_empty():
		return
	var pb := v["pb"] as AudioStreamGeneratorPlayback
	if pb.get_frames_available() < CHUNK:
		return   # (behind: drop rather than build up delay)
	var rms := 0.0
	for b in pkt:
		var s := _unmulaw(b)
		rms += s * s
		pb.push_frame(Vector2(s, s))
	v["t"] = Time.get_ticks_msec()
	v["level"] = maxf(float(v.get("level", 0.0)), clampf(sqrt(rms / CHUNK) * 6.0, 0.0, 1.0))

## A 3D voice player that follows the speaker's avatar.
func _voice_for(peer: int) -> Dictionary:
	if _voices.has(peer) and is_instance_valid(_voices[peer]["player"]):
		return _voices[peer]
	var ns := get_parent()
	var av = ns._avatars.get(peer) if ns != null else null
	if av == null or not is_instance_valid(av):
		return {}
	var p := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.3
	p.stream = gen
	p.max_distance = HEAR_DIST
	p.unit_size = 8.0
	p.volume_db = 4.0
	(av as Node3D).add_child(p)
	p.position = Vector3.UP * 1.6
	p.play()
	_voices[peer] = {"player": p, "pb": p.get_stream_playback(), "t": 0}
	return _voices[peer]

## Talking indicator on the speaker's name tag; forget players who left.
func _place_voices(delta: float) -> void:
	for peer in _voices.keys():
		var v: Dictionary = _voices[peer]
		if not is_instance_valid(v["player"]):
			_voices.erase(peer)
			continue
		var av := (v["player"] as Node).get_parent()
		v["level"] = lerpf(float(v.get("level", 0.0)), 0.0, minf(1.0, 12.0 * delta))
		if av != null and av.get("model") != null:   # their mouth moves while they talk
			Hero.set_mouth_open(av.get("model"), float(v["level"]))
		var tag = av.get("name_tag") if av != null else null
		if tag is Label3D:
			var on := Time.get_ticks_msec() - int(v["t"]) < 250
			(tag as Label3D).modulate = Color(0.55, 1.0, 0.6) if on else Color.WHITE
