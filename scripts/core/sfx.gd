class_name Sfx
extends RefCounted
## Tiny procedural sound bank: every sound is synthesised once at first use
## (no audio files, a few KB of RAM each). Sfx.play(node, "hit")

const RATE := 22050
# id: [seconds, tone_start_hz, tone_end_hz, tone_amp, noise_amp, noise_brightness(0-1), attack(0-1)]
const SPEC := {
	"swing": [0.16, 0.0, 0.0, 0.0, 0.9, 0.35, 0.35],
	"hit":   [0.16, 150.0, 45.0, 1.0, 0.6, 0.5, 0.02],
	"throw": [0.12, 1800.0, 900.0, 0.12, 0.8, 0.75, 0.3],
	"fire":  [0.55, 110.0, 60.0, 0.45, 1.0, 0.14, 0.08],
	"boom":  [0.8, 75.0, 28.0, 1.0, 1.0, 0.08, 0.01],
	"poof":  [0.3, 0.0, 0.0, 0.0, 0.9, 0.25, 0.12],
	"jump":  [0.14, 280.0, 620.0, 0.45, 0.3, 0.5, 0.05],
	"dash":  [0.26, 0.0, 0.0, 0.0, 1.0, 0.55, 0.45],
	"hurt":  [0.22, 420.0, 170.0, 0.7, 0.35, 0.4, 0.02],
	"death": [1.1, 260.0, 55.0, 0.7, 0.4, 0.2, 0.02],
	"power": [0.8, 180.0, 900.0, 0.45, 0.45, 0.3, 0.35],
	"thud":  [0.25, 90.0, 40.0, 0.9, 0.5, 0.12, 0.01],
}
static var _cache := {}

static func play(from: Node, id: String, vol_db := 0.0) -> void:
	if from == null or not from.is_inside_tree() or not SPEC.has(id):
		return
	if not _cache.has(id):
		_cache[id] = _make(SPEC[id])
	var p := AudioStreamPlayer.new()
	p.stream = _cache[id]
	p.volume_db = vol_db - 4.0
	p.pitch_scale = randf_range(0.9, 1.1)
	from.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

static func _make(s: Array) -> AudioStreamWAV:
	var n := int(s[0] * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var atk: float = maxf(s[6], 0.001)
	for i in n:
		var x := float(i) / n
		phase += TAU * lerpf(s[1], s[2], x) / RATE
		lp += s[5] * (randf_range(-1.0, 1.0) - lp)
		var env := x / atk if x < atk else exp(-4.0 * (x - atk) / (1.0 - atk))
		var v: float = (sin(phase) * s[3] + lp * s[4] * 1.6) * env * (1.0 - x)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
