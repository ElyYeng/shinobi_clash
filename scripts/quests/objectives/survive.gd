extends QuestObjective
## Hold out for `time` seconds near `pos`: the clock runs while you're within `radius` + 15 m,
## and a wave of enemies (enemy_* fields) arrives every WAVE_EVERY seconds. Progress = seconds.

const WAVE_EVERY := 10.0
const WAVE_SIZE := 2
var _t := 0.0
var _wave_t := 0.0
var _wave := 0
var _started := false

func start() -> void:
	quests.make_beacon(step["pos"], str(step["place"]) if str(step["place"]) != "" else "Hold out here")
	_t = float(progress())
	_wave = int(_t / WAVE_EVERY)

func update(delta: float) -> void:
	var inside := flat_distance(step["pos"]) < float(step["radius"]) + 15.0
	if not _started:
		if flat_distance(step["pos"]) < float(step["radius"]):
			_started = true
			_wave_t = WAVE_EVERY   # first wave right away
			quests.hud.toast("Survive for %d seconds!" % int(float(step["time"]) - _t))
		return
	if not inside or player().is_dead:
		return
	_t += delta
	_wave_t += delta
	if _wave_t >= WAVE_EVERY:
		_wave_t = 0.0
		quests.spawn_enemies(WAVE_SIZE, step, false, 100 + _wave * WAVE_SIZE)
		_wave += 1
	if int(_t) != progress():
		set_progress(int(_t))
	if _t >= float(step["time"]):
		complete()   # the manager removes the remaining wave enemies

func hud_text() -> String:
	if not _started:
		return text_or("Go to the %s" % (str(step["place"]) if str(step["place"]) != "" else "marked area"))
	var left := maxi(0, int(ceil(float(step["time"]) - _t)))
	return text_or("Survive: %d s left" % left) + ("" if flat_distance(step["pos"]) < float(step["radius"]) + 15.0 else "\n(get back to the area!)")
