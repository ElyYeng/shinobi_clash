class_name Kurama
extends Enemy
## Kurama, the Nine-Tailed Beast - boss.
## Model: res://assets/kurama/scene.gltf (auto-sized, auto-oriented, toon shaded).
## Edit ANIM to change which model animation each move uses, and the constants below to tune the fight.

signal defeated
signal enraged(phase: int)

const ASSET_DIR := "res://assets/kurama"
const CREDIT := 'Model: "Kurama" by Witsanu Superball (CC-BY-4.0)'
const BOSS_NAME := "KURAMA  -  The Nine-Tailed Beast"
const TARGET_HEIGHT := 9.0     # metres, toes to ear tips
const MAX_HP := 2400.0

# move -> animation name (the part after "Armature|")
const ANIM := {
	"idle": "stand", "wait": "wait", "combat": "atstand", "run": "run",
	"claw": "attack01",   # melee swipe
	"roar": "skill01_1",  # shockwave - JUMP over it
	"bomb": "skill02",    # Tailed Beast Bomb (charges, then fires)
	"slam": "skill03",    # ground smash on the spot where you stood - MOVE out of the red circle
	"hurt": "hurt01",
}
# fraction of the animation at which the attack lands
const HIT_AT := {"claw": 0.45, "roar": 0.4, "slam": 0.55, "bomb": 0.62}
const FALLBACK_LEN := {"claw": 2.4, "roar": 3.9, "bomb": 3.3, "slam": 2.4}
const COOLDOWNS := [1.5, 1.0, 0.55]      # pause between attacks in phase 1 / 2 / 3

const CLAW_RANGE := 12.5
const CLAW_DMG := 22.0
const SLAM_RADIUS := 8.0
const SLAM_DMG := 28.0
const ROAR_RADIUS := 32.0
const ROAR_DMG := 16.0
const BOMB_DMG := 38.0
const BOMB_AOE := 9.0

enum State { INTRO, CHASE, ATTACK, HURT, DEAD }

static var _scene: PackedScene = null
static var _searched := false
var _raid_target_peer_id := 0

var state := State.INTRO
var phase := 1
var ap: AnimationPlayer
var anims := {}
var atk := ""
var atk_t := 0.0
var atk_len := 1.0
var atk_hit := false
var atk_harmless := false
var cd := 1.0
var hurt_t := 0.0
var hurt_cd := 0.0
var intro_t := 0.0
var pending_roar := false
var last_move := ""
var slam_pos := Vector3.ZERO
var bomb: BossShot = null

# ------------------------------------------------------------------ setup

func _physics_process(delta: float) -> void:
	if NetworkSession.is_active() and NetworkSession.session_mode == "raid" and not multiplayer.is_server():
		# Client replica is driven by the host snapshots; never run a second boss AI.
		if state == State.DEAD:
			return
		return
	_ai(delta)
	_animate_body(delta)

func apply_raid_snapshot(pos: Vector3, yaw: float, hp: float, boss_phase: int, boss_state: int, attack: String, attack_time: float, attack_length: float, target_pos: Vector3) -> void:
	global_position = global_position.lerp(pos, 0.65)
	model.rotation.y = lerp_angle(model.rotation.y, yaw, 0.65)
	health = hp
	phase = boss_phase
	_update_label()
	var incoming_state: int = int(State.values()[clampi(boss_state, 0, State.size() - 1)])
	if incoming_state == State.DEAD and state != State.DEAD:
		_die()
		return
	if attack != "" and (atk != attack or state != incoming_state):
		atk = attack
		state = incoming_state
		atk_len = maxf(attack_length, 0.1)
		_start_anim(attack)
		slam_pos = target_pos
	elif incoming_state != state:
		state = incoming_state
	if attack == "" and incoming_state == State.CHASE:
		_loop_anim("run" if pos.distance_to(global_position) > 0.08 else "combat")
	atk_t = attack_time
	atk_len = maxf(attack_length, 0.1)

func _setup() -> void:
	add_to_group("enemies")
	is_boss = true
	health = MAX_HP
	max_health = MAX_HP
	k = 2.4          # melee reach multiplier used by the player's attacks
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.6
	cyl.height = 7.0
	col.shape = cyl
	col.position.y = 3.5
	add_child(col)
	model = _make_model()
	add_child(model)
	# Kurama overrides Enemy._setup(), so create the inherited health label here too.
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.pixel_size = 0.005
	label.position.y = 2.5 * k
	add_child(label)
	_update_label()
	_loop_anim("idle", 0.0)
	# fiery chakra aura: flames licking up around him + a hot orange light on the arena
	Vfx.aura_flames(self, Vector3(0, 2.5, 0), 4.2, Color(1.0, 0.45, 0.08), 110)
	Vfx.glow_light(self, Color(1.0, 0.45, 0.12), 3.0, 38.0, Vector3(0, 7, 0))

func _placeholder() -> Node3D:
	var ph := Fx.make_ninja(Color(0.95, 0.45, 0.1), Color(0.6, 0.1, 0.1))
	ph.scale = Vector3.ONE * 4.0
	return ph

func _make_model() -> Node3D:
	if not _searched:
		_searched = true
		var path := Hero._scan(ASSET_DIR, 1)
		if path != "":
			_scene = load(path) as PackedScene
			print("[Kurama] loaded model: ", path)
		else:
			push_warning("[Kurama] no .gltf/.glb found in " + ASSET_DIR + " - using a placeholder")
	if _scene == null:
		return _placeholder()
	var inst := _scene.instantiate() as Node3D
	if inst == null:
		return _placeholder()
	var wrapper := Node3D.new()
	var fixer := Node3D.new()
	wrapper.add_child(fixer)
	fixer.add_child(inst)
	_fit(fixer, inst)
	Fx.toonify_model(inst)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).extra_cull_margin = 40.0   # skinned mesh bounds can be stale
	_setup_anims(inst)
	return wrapper

## Sizes the model from its skeleton and rotates it so the head points toward -Z (the game's "forward").
func _fit(fixer: Node3D, inst: Node3D) -> void:
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		var sk := sks[0] as Skeleton3D
		var ib := sk.find_bone("Head_028")
		var tb := sk.find_bone("Tail_040")
		var hb := sk.find_bone("Hip_011")
		var eb := sk.find_bone("L_Ear2_end_070")
		var fl := sk.find_bone("L_Toe_end_067")
		var fr := sk.find_bone("R_Toe_end_068")
		if ib >= 0 and tb >= 0 and hb >= 0 and (fl >= 0 or fr >= 0):
			var rel := Hero._rel(sk, fixer)
			var head: Vector3 = rel * sk.get_bone_global_rest(ib).origin
			var tail: Vector3 = rel * sk.get_bone_global_rest(tb).origin
			var hip: Vector3 = rel * sk.get_bone_global_rest(hb).origin
			var foot_y := 1.0e9
			if fl >= 0:
				foot_y = minf(foot_y, (rel * sk.get_bone_global_rest(fl).origin).y)
			if fr >= 0:
				foot_y = minf(foot_y, (rel * sk.get_bone_global_rest(fr).origin).y)
			var top := head.y
			if eb >= 0:
				top = maxf(top, (rel * sk.get_bone_global_rest(eb).origin).y)
			var height := top - foot_y
			if height > 0.05:
				var s := TARGET_HEIGHT / height
				var dir := head - tail
				dir.y = 0.0
				fixer.rotation.y = PI - atan2(dir.x, dir.z) if dir.length() > 0.2 else PI
				var mid := (head + hip) * 0.5
				inst.scale = inst.scale * s
				inst.position = Vector3(-mid.x * s, -foot_y * s, -mid.z * s)
				print("[Kurama] bone-fit: height ", height, " -> scale x", s, ", head dir ", dir)
				return
	_fit_mesh(fixer, inst)

func _fit_mesh(fixer: Node3D, inst: Node3D) -> void:
	var box := AABB()
	var first := true
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := Hero._rel(mi, fixer) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y < 0.01:
		return
	var s := TARGET_HEIGHT / box.size.y
	inst.scale = inst.scale * s
	inst.position = Vector3(-(box.position.x + box.size.x / 2.0) * s, -box.position.y * s, -(box.position.z + box.size.z / 2.0) * s)
	fixer.rotation.y = PI
	print("[Kurama] mesh-fit (bones not found): height ", box.size.y, " -> scale x", s)

func _match_anim(list: PackedStringArray, key: String) -> String:
	for nm in list:
		var low := String(nm).to_lower()
		var tail := low.get_slice("|", low.get_slice_count("|") - 1)
		if tail == key:
			return String(nm)
	for nm in list:
		if String(nm).to_lower().ends_with(key):
			return String(nm)
	return ""

func _setup_anims(inst: Node3D) -> void:
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		print("[Kurama] model has no AnimationPlayer")
		return
	ap = aps[0] as AnimationPlayer
	var list := ap.get_animation_list()
	print("[Kurama] animations found: ", list)
	for key in ANIM:
		var nm := _match_anim(list, ANIM[key])
		if nm != "":
			anims[key] = nm
	for key in ["idle", "wait", "combat", "run"]:
		if anims.has(key):
			ap.get_animation(anims[key]).loop_mode = Animation.LOOP_LINEAR
	for key in ["claw", "roar", "bomb", "slam", "hurt"]:
		if anims.has(key):
			ap.get_animation(anims[key]).loop_mode = Animation.LOOP_NONE
	print("[Kurama] animation map: ", anims)

# ------------------------------------------------------------------ animation helpers
func _loop_anim(key: String, blend := 0.25) -> void:
	if ap == null or not anims.has(key):
		return
	var nm: String = anims[key]
	if ap.current_animation != nm or not ap.is_playing():
		ap.play(nm, blend)

func _start_anim(key: String, blend := 0.15) -> float:
	if ap == null or not anims.has(key):
		return 0.0
	var nm: String = anims[key]
	ap.play(nm, blend)
	ap.seek(0.0, true)
	return ap.get_animation(nm).length

# ------------------------------------------------------------------ helpers
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _fwd() -> Vector3:
	return Vector3(-sin(model.rotation.y), 0.0, -cos(model.rotation.y))

func _mouth() -> Vector3:
	return global_position + _fwd() * 7.5 + Vector3.UP * 5.5

func _turn(dir: Vector3, rate: float, delta: float) -> void:
	var target := atan2(-dir.x, -dir.z)
	var diff := wrapf(target - model.rotation.y, -PI, PI)
	model.rotation.y += clampf(diff, -rate * delta, rate * delta)

func _dmg_mul() -> float:
	return 1.0 + 0.15 * float(phase - 1)

# ------------------------------------------------------------------ AI
func _ai(delta: float) -> void:
	var ts := Enemy.time_scale
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if stun > 0.0:
		stun -= delta * ts
		velocity.x = 0.0
		velocity.z = 0.0
		if ap:
			ap.speed_scale = 0.0
		move_and_slide()
		return
	if ap:
		ap.speed_scale = ts * (1.15 if phase == 3 else 1.0)
	var target_pos := _raid_target_position()
	var has_target := target_pos != Vector3.INF
	if not (NetworkSession.is_active() and NetworkSession.session_mode == "raid"):
		var p := _player()
		has_target = p != null and not p.is_dead
		if has_target:
			target_pos = p.global_position
	var dir := _fwd()
	var dist := 999.0
	if has_target:
		var to := target_pos - global_position
		to.y = 0.0
		dist = to.length()
		if dist > 0.01:
			dir = to / dist
	cd -= delta * ts
	hurt_cd -= delta * ts
	match state:
		State.INTRO:
			intro_t += delta
			velocity.x = 0.0
			velocity.z = 0.0
			if intro_t > 1.0 and has_target:
				_select_next_raid_target()
				_start_attack("roar", true)
		State.CHASE:
			_chase(delta, ts, has_target, dir, dist)
		State.ATTACK:
			_attack(delta, ts, has_target, dir)
		State.HURT:
			hurt_t -= delta * ts
			velocity.x = 0.0
			velocity.z = 0.0
			if hurt_t <= 0.0:
				state = State.CHASE
	move_and_slide()

func _raid_target_position() -> Vector3:
	if not NetworkSession.is_active() or NetworkSession.session_mode != "raid" or not multiplayer.is_server():
		return Vector3.INF
	if _raid_target_peer_id == 1:
		if NetworkSession._local_player != null and not NetworkSession._local_player.is_dead:
			return NetworkSession._local_player.global_position
	elif NetworkSession._avatars.has(_raid_target_peer_id):
		var avatar = NetworkSession._avatars[_raid_target_peer_id]
		if is_instance_valid(avatar):
			return avatar.global_position
	return Vector3.INF

func _select_next_raid_target() -> void:
	if not NetworkSession.is_active() or NetworkSession.session_mode != "raid" or not multiplayer.is_server():
		return
	var ids: Array[int] = []
	if NetworkSession._local_player != null and not NetworkSession._local_player.is_dead:
		ids.append(1)
	for id in NetworkSession._avatars:
		var avatar = NetworkSession._avatars[id]
		if is_instance_valid(avatar):
			ids.append(int(id))
	ids.sort()
	if ids.is_empty():
		_raid_target_peer_id = 0
		return
	var current_index := ids.find(_raid_target_peer_id)
	_raid_target_peer_id = ids[(current_index + 1) % ids.size()]

func _chase(delta: float, ts: float, has_target: bool, dir: Vector3, dist: float) -> void:
	if not has_target:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		_loop_anim("combat")
		return
	_turn(dir, (2.0 + phase * 0.5) * ts, delta)
	if dist > CLAW_RANGE * 0.8:
		var f := _fwd()
		var run_speed := (9.0 + phase * 2.0) * ts
		velocity.x = f.x * run_speed
		velocity.z = f.z * run_speed
		_loop_anim("run")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		_loop_anim("combat")
	if cd <= 0.0:
		_pick_attack(dist)

func _pick_attack(dist: float) -> void:
	_select_next_raid_target()
	if pending_roar:
		pending_roar = false
		_start_attack("roar")
		return
	var move := "claw"
	for _i in 3:
		var r := randf()
		if dist <= CLAW_RANGE:
			if r < 0.5:
				move = "claw"
			elif r < 0.75:
				move = "slam"
			elif r < 0.9:
				move = "roar"
			else:
				move = "bomb"
		else:
			if r < 0.45:
				move = "bomb"
			elif r < 0.75:
				move = "slam"
			else:
				move = "roar"
		if move != last_move:
			break
	last_move = move
	_start_attack(move)

func _start_attack(move: String, harmless := false) -> void:
	state = State.ATTACK
	atk = move
	atk_t = 0.0
	atk_hit = false
	atk_harmless = harmless
	var l := _start_anim(move)
	atk_len = l if l > 0.1 else float(FALLBACK_LEN.get(move, 2.0))
	var p := _player()
	match move:
		"slam":
			slam_pos = p.global_position if p != null else global_position + _fwd() * 10.0
			var hit_f: float = HIT_AT["slam"]
			_telegraph(slam_pos, SLAM_RADIUS, atk_len * hit_f)
		"bomb":
			bomb = BossShot.new()
			bomb.damage = BOMB_DMG * _dmg_mul()
			bomb.aoe = BOMB_AOE
			get_parent().add_child(bomb)
			bomb.global_position = _mouth()
		"roar":
			Sfx.play(self, "power", 5.0)

func _attack(delta: float, ts: float, has_target: bool, dir: Vector3) -> void:
	atk_t += delta * ts * (1.15 if phase == 3 else 1.0)
	var f := atk_t / atk_len
	velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
	if has_target and f < 0.4 and atk != "slam":
		_turn(dir, 1.6 * ts, delta)
	if atk == "bomb" and not atk_hit and bomb != null and is_instance_valid(bomb):
		bomb.global_position = _mouth()
	var hit_f: float = HIT_AT.get(atk, 0.5)
	if not atk_hit and f >= hit_f:
		atk_hit = true
		_do_hit(atk)
	if f >= 1.0:
		_end_attack()

func _do_hit(move: String) -> void:
	if NetworkSession.is_active() and NetworkSession.session_mode == "raid" and multiplayer.is_server():
		NetworkSession.raid_apply_boss_attack(move, global_position, _fwd(), slam_pos, phase)
	var p := _player()
	var alive := p != null and not p.is_dead and not atk_harmless and not (NetworkSession.is_active() and NetworkSession.session_mode == "raid")
	match move:
		"claw":
			Sfx.play(self, "swing", 4.0)
			_shake(0.25, 0.25)
			if alive:
				var to := p.global_position - global_position
				to.y = 0.0
				if to.length() < CLAW_RANGE and _fwd().dot(to.normalized()) > 0.25:
					p.take_damage(CLAW_DMG * _dmg_mul(), _fwd() * 16.0)
		"slam":
			_ring(slam_pos, SLAM_RADIUS, Color(1.0, 0.5, 0.1, 0.8), 0.45)
			Sfx.play(self, "boom", 4.0)
			_shake(0.6, 0.5)
			if alive:
				var d := p.global_position - slam_pos
				d.y = 0.0
				if d.length() < SLAM_RADIUS and p.global_position.y < 3.0:
					p.take_damage(SLAM_DMG * _dmg_mul(), d.normalized() * 14.0)
		"roar":
			_ring(global_position, ROAR_RADIUS, Color(1.0, 0.9, 0.5, 0.7), 0.8)
			_shake(0.5, 0.8)
			if alive:
				var d := p.global_position - global_position
				d.y = 0.0
				# the shockwave rolls along the ground - jump over it!
				if d.length() < ROAR_RADIUS and p.global_position.y < 0.7:
					p.take_damage(ROAR_DMG * _dmg_mul(), d.normalized() * 18.0)
		"bomb":
			if bomb != null and is_instance_valid(bomb):
				var aim := _fwd()
				var target_pos := _raid_target_position()
				if target_pos == Vector3.INF and p != null and not p.is_dead:
					target_pos = p.global_position
				if target_pos != Vector3.INF:
					aim = (target_pos + Vector3.UP - bomb.global_position).normalized()
				bomb.release(aim, 38.0)
				bomb = null

func _end_attack() -> void:
	if bomb != null and is_instance_valid(bomb) and bomb.held:
		bomb.queue_free()
	bomb = null
	atk = ""
	atk_harmless = false
	state = State.CHASE
	cd = COOLDOWNS[phase - 1]

# ------------------------------------------------------------------ taking damage / dying
@warning_ignore("unused_parameter")
func take_damage(amount: float, knock: Vector3 = Vector3.ZERO) -> void:
	if NetworkSession.is_active() and NetworkSession.session_mode == "raid" and not multiplayer.is_server():
		NetworkSession.request_raid_boss_damage(amount)
		return
	if state == State.DEAD or state == State.INTRO or atk_harmless:
		return
	health -= amount
	Sfx.play(self, "hit", -5.0)
	var p := _player()
	var spot := global_position + Vector3.UP * 3.0
	if p != null:
		var tp := p.global_position - global_position
		tp.y = 0.0
		if tp.length() > 0.01:
			spot += tp.normalized() * 3.8
	Fx.puff(get_parent(), spot, Color(1, 1, 0.7, 0.9), 1.4)
	Vfx.damage_number(get_parent(), spot + Vector3.UP * 1.5, amount, Color(1.0, 0.85, 0.3))
	var np := 1
	if health < MAX_HP * 0.33:
		np = 3
	elif health < MAX_HP * 0.66:
		np = 2
	if np > phase:
		phase = np
		pending_roar = true
		cd = minf(cd, 0.3)
		enraged.emit(phase)
	if health <= 0.0:
		_die()
	elif state == State.CHASE and hurt_cd <= 0.0:
		hurt_cd = 6.0
		hurt_t = 0.55
		state = State.HURT
		_start_anim("hurt")

func _die() -> void:
	state = State.DEAD
	health = 0.0
	remove_from_group("enemies")
	if bomb != null and is_instance_valid(bomb):
		bomb.queue_free()
	bomb = null
	var p := _player()
	if p != null:
		p.kills += 1
		p.on_kill(true)
		p.add_mode(25.0)
		p.chakra = p.max_chakra
		p.health = minf(p.max_health, p.health + 50.0)
	Sfx.play(self, "death", 5.0)
	Sfx.play(self, "boom", 4.0)
	_start_anim("hurt")
	if ap:
		ap.speed_scale = 0.35     # slow-mo flinch as the beast falls
	_shake(0.8, 1.5)
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_callback(func() -> void: defeated.emit())
	for i in 6:
		t.tween_callback(_death_puff)
		t.tween_interval(0.45)
	t.tween_callback(queue_free)
	var t2 := create_tween()
	t2.tween_interval(1.0)
	t2.tween_property(model, "scale", Vector3.ONE * 0.05, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _death_puff() -> void:
	var at := global_position + Vector3(randf_range(-4, 4), randf_range(1, 8), randf_range(-4, 4))
	Fx.puff(get_parent(), at, Color(1.0, 0.5, 0.1, 0.8), randf_range(3.0, 6.0))
	Vfx.burst(get_parent(), at, Color(1.0, 0.6, 0.2), 60, 12.0, 0.45, 1.2)

# ------------------------------------------------------------------ effects
func _telegraph(pos: Vector3, radius: float, secs: float) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.05
	c.radial_segments = 32
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.05, 0.05)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.material_override = mat
	get_parent().add_child(m)
	m.global_position = Vector3(pos.x, 0.1, pos.z)
	var t := m.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.6, secs)
	t.tween_callback(m.queue_free)

func _ring(pos: Vector3, radius: float, col: Color, secs: float) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	m.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, col.a)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.material_override = mat
	get_parent().add_child(m)
	m.global_position = Vector3(pos.x, 0.4, pos.z)
	var t := m.create_tween().set_parallel(true)
	t.tween_property(m, "scale", Vector3(radius, radius * 0.25, radius), secs)
	t.tween_property(mat, "albedo_color:a", 0.0, secs)
	t.chain().tween_callback(m.queue_free)

func _shake(strength: float, secs: float) -> void:
	var p := _player()
	if p == null or p.cam == null:
		return
	var t := create_tween()
	t.tween_method(_shake_step.bind(p.cam), strength, 0.0, secs)
	t.tween_callback(_shake_step.bind(0.0, p.cam))

func _shake_step(v: float, cam: Camera3D) -> void:
	if not is_instance_valid(cam):
		return
	cam.h_offset = randf_range(-v, v)
	cam.v_offset = randf_range(-v, v)
