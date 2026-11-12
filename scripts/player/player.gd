class_name Player
extends CharacterBody3D

const WALK_SPEED := 2.5      # m/s; walk/run clips are sped up to match (Hero.play_move)
const SPRINT_SPEED := 11.0
const JUMP_VELOCITY := 9.5
const GRAVITY := 26.0
const DASH_SPEED := 30.0

var health := 100.0
var max_health := 100.0
var chakra := 100.0
var max_chakra := 100.0
var kills := 0
var is_dead := false
const MODE_MAX := 100.0   # base MD; drain rates are per 100 MD, so a bigger cap (MD stat) lasts longer
const MODE_TIME := 25.0        # seconds a full MD bar lasts in Kurama Mode (no timer: it drains MD)
const KURAMA_MIN_MD := 50.0    # MD needed to enter Kurama Mode
const BOTH_DRAIN_MULT := 1.25  # Kurama Mode + bloodline power-up together drain both rates, x1.25
var stamina := 100.0
var max_stamina := 100.0
var stam_delay := 0.0
var mode_meter := 0.0        # "MD" bar: fills over time and with kills; Z (Kurama Mode) needs it full
var kurama := false          # Kurama Mode (Z) is on; drains MD, no timer
var armor_time := 0.0
var t_cd := 0.0
var y_cd := 0.0
var g_cd := 0.0
var h_cd := 0.0
var v_cd := 0.0
var volley_cd := 0.0
var c_hold := 0.0
var cloak_fx: Node3D = null
var god_mode := false        # set from the menu (Cheats)
var inf_chakra := false
var sens_mult := 1.0         # set from the menu (Customs)
var fov_base := 70.0

# Bloodline-driven stats (see apply_bloodline)
var speed_mult := 1.0
var regen_mult := 1.0
var dmg_mult := 1.0
var fire_cost := 30.0
var dash_cost := 15.0
var clone_count := 2
var clone_time := 8.0
var hp_regen := 0.0
var move_cd := {}                           # move id -> cooldown left (see moves.gd)
var cur_mkey := ""                          # mastery key of the move being cast (for hit XP)
var buffs: Array[Dictionary] = []           # active bloodline buffs / auras
var powered := false                        # bloodline power-up (C) is on
var pmode: Dictionary = {}                  # Bloodline.mode() while powered
var pmode_fx: Node3D = null
var mode_tick := 0.0

var yaw := 0.0
var pitch := -0.25
var facing := Vector3(0, 0, -1)
var jumps_left := 2
var dash_time := 0.0
var dash_dir := Vector3.ZERO
var combo := 0
var combo_timer := 0.0
var attack_cd := 0.0
var attack_lock := 0.0
var anim_lock := 0.0
var downed := 0.0      # knocked down by a combo finisher (PvP): ragdoll, then get up
var _kd_rag: Ragdoll
var sitting := false   # P: sit on the floor (test pose); moving gets you up
var kunai_cd := 0.0
var fire_cd := 0.0
var clone_cd := 0.0
var invuln := 0.0
var lock_target: Node3D = null   # an Enemy, or another player's avatar in PvP

var pivot: Node3D
var spring: Node3D          # camera boom (the camera sits on it; see _update_camera)
var cam: Camera3D
var model: Node3D
var arm: Node3D
var aura: OmniLight3D
var body_col: CollisionShape3D
var dust_t := 0.0
var ragdoll: Ragdoll

func _ready() -> void:
	add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	col.shape = cap
	col.position.y = 0.95
	add_child(col)
	body_col = col
	model = Hero.create()
	if model == null:
		model = Fx.make_ninja(Color(0.95, 0.5, 0.1), Color(0.15, 0.3, 0.8))
	add_child(model)
	arm = model.get_node_or_null("Arm")
	aura = OmniLight3D.new()
	aura.position.y = 1.0
	aura.omni_range = 6.0
	add_child(aura)
	pivot = Node3D.new()
	pivot.position.y = CAM_HEIGHT
	add_child(pivot)
	pivot.top_level = true          # follows the player with a little lag (_update_camera)
	pivot.global_position = global_position + Vector3.UP * CAM_HEIGHT
	spring = Node3D.new()
	spring.name = "Boom"
	pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	spring.add_child(cam)
	cam.set_meta("rig", self)       # Vfx.shake routes screen shake to add_trauma()
	cam.make_current()
	_shake_noise.seed = randi()
	_shake_noise.frequency = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	apply_bloodline()
	health = max_health
	chakra = max_chakra

## Recomputes max health / chakra / stamina and bloodline passives (bloodline + stat points).
func refresh_stats() -> void:
	var def := Bloodline.get_def(GameData.equipped)
	var s: Dictionary = def["stats"]
	var old_hp := max_health
	var old_ck := max_chakra
	max_health = 100.0 + float(s.get("hp", 0.0)) + GameData.stat_bonus("health")
	max_chakra = 100.0 + float(s.get("chakra", 0.0)) + GameData.stat_bonus("chakra")
	max_stamina = 100.0 + GameData.stat_bonus("stamina")
	stamina = minf(stamina, max_stamina)
	speed_mult = float(s.get("speed", 1.0))
	regen_mult = float(s.get("regen", 1.0))
	dmg_mult = float(s.get("dmg", 1.0))
	fire_cost = 30.0 * float(s.get("fire_cost", 1.0))
	dash_cost = 15.0 * float(s.get("dash_cost", 1.0))
	clone_count = 2 + int(s.get("clone_count", 0))
	clone_time = 8.0 + float(s.get("clone_time", 0.0))
	hp_regen = float(s.get("hp_regen", 0.0))
	if max_health > old_hp:
		health += max_health - old_hp
	if max_chakra > old_ck:
		chakra += max_chakra - old_ck
	health = minf(health, max_health)
	chakra = minf(chakra, max_chakra)

## Called when the equipped bloodline changes.
func apply_bloodline() -> void:
	var def := Bloodline.get_def(GameData.equipped)
	NetworkSession.broadcast_clan(GameData.equipped)   # clan next to your name for other players
	refresh_stats()
	_clear_buffs()
	_power_off()
	aura.visible = false   # no idle glow - the aura only lights up for forms, buffs and jutsu
	aura.light_color = def["color"]
	aura.light_energy = 1.2

func _dmg() -> float:
	var m := dmg_mult
	if kurama:
		m *= 2.0
	m *= _bmul("dmg")
	return m

## ---- Camera rig ----------------------------------------------------------------------------
## Mouse wheel zooms smoothly from ZOOM_MAX in to a tight over-the-shoulder view, then one more
## notch goes first person (cam_zoom 0). The camera trails the player a little, sits over the
## right shoulder, dips on hard landings, rolls slightly when strafing and shakes with trauma.
const CAM_HEIGHT := 1.6
const ZOOM_MIN := 1.1           # closest third-person distance (one more notch = first person)
const ZOOM_MAX := 18.0
const ZOOM_FACTOR := 0.82       # each wheel notch scales the distance by this
const CAM_MARGIN := 0.25        # gap kept between the camera and walls
var cam_zoom := 5.5             # wanted distance (0 = first person)
var _cam_dist := 5.5            # actual distance after easing / wall collision
var _cam_roll := 0.0
var _land_dip := 0.0
var _land_vel := 0.0
var _fall_speed := 0.0
var _was_floor := true
var _trauma := 0.0
var _shake_t := 0.0
var _shake_noise := FastNoiseLite.new()
var _first_person := false
var look_angles := Vector2.ZERO   # head look (yaw, pitch) relative to the body - sent to other players

## Screen shake: 0..1, stacks, decays on its own (Vfx.shake calls this for the player camera).
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _zoom_step(dir: int) -> void:
	if dir < 0:   # in
		cam_zoom = 0.0 if cam_zoom <= ZOOM_MIN + 0.01 else maxf(ZOOM_MIN, cam_zoom * ZOOM_FACTOR)
	else:
		cam_zoom = ZOOM_MIN if cam_zoom < ZOOM_MIN else minf(ZOOM_MAX, cam_zoom / ZOOM_FACTOR)

func _update_camera(delta: float) -> void:
	# --- follow (top-level pivot eases toward the head; snaps after teleports)
	var head := global_position + Vector3.UP * CAM_HEIGHT
	if wall_walking:   # head sticks out from the surface we stand on
		head = _feet + wall_n * CAM_HEIGHT
	_cam_q = _cam_q.slerp(_surf_q, 1.0 - exp(-7.0 * delta)).normalized()
	if not (is_dead and ragdoll):   # while ragdolled, _physics_process follows the body
		var p := pivot.global_position
		if p.distance_to(head) > 6.0:
			p = head
		else:
			var kh := 1.0 - exp(-18.0 * delta)
			var kv := 1.0 - exp(-11.0 * delta)
			p = Vector3(lerpf(p.x, head.x, kh), lerpf(p.y, head.y, kv), lerpf(p.z, head.z, kh))
			var lag := p - head   # never trail too far behind at dash speed
			if lag.length() > 2.2:
				p = head + lag.limit_length(2.2)
		# landing dip: a damped spring kicked by hard landings
		var floor_now := is_on_floor()
		if not floor_now:
			_fall_speed = maxf(_fall_speed, -velocity.y)
		elif not _was_floor and _fall_speed > 7.0:
			_land_vel -= clampf(_fall_speed * 0.09, 0.0, 2.6)
			add_trauma(clampf((_fall_speed - 7.0) / 40.0, 0.0, 0.35))
			_fall_speed = 0.0
		if floor_now:
			_fall_speed = 0.0
		_was_floor = floor_now
		_land_vel += (-_land_dip * 120.0 - _land_vel * 16.0) * delta
		_land_dip += _land_vel * delta
		pivot.global_position = p + Vector3.UP * _land_dip
	pivot.global_basis = Basis(_cam_q) * Basis.from_euler(Vector3(pitch, yaw, 0.0))

	# --- distance: ease to the wanted zoom, pulled in instantly by walls (characters ignored)
	var want := cam_zoom
	_first_person = want < 0.05 and cam.current
	var shoulder := 0.0 if want < 0.05 else 0.55 * clampf(1.0 - (want - ZOOM_MIN) / 9.0, 0.25, 1.0)
	spring.position = Vector3(lerpf(spring.position.x, shoulder, 1.0 - exp(-8.0 * delta)), 0.0, 0.0)
	var hit := _cam_block(want)
	var target_dist := minf(want, hit)
	if target_dist < _cam_dist:
		_cam_dist = target_dist if hit < want else lerpf(_cam_dist, target_dist, 1.0 - exp(-12.0 * delta))
	else:
		_cam_dist = lerpf(_cam_dist, target_dist, 1.0 - exp(-(10.0 if hit >= want else 5.0) * delta))

	# --- first person: hide our own body
	if model != null:
		model.visible = not (_first_person and _cam_dist < 0.3)

	# --- strafe roll + trauma shake
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var lateral := Vector2(velocity.x, velocity.z).dot(Vector2(right.x, right.z))
	var roll_to := 0.0 if wall_walking else clampf(-lateral * 0.0035, -0.035, 0.035)
	_cam_roll = lerpf(_cam_roll, roll_to, 1.0 - exp(-6.0 * delta))
	_trauma = maxf(0.0, _trauma - delta * 1.5)
	_shake_t += delta * 28.0
	var s := _trauma * _trauma
	var nx := _shake_noise.get_noise_2d(_shake_t, 0.0)
	var ny := _shake_noise.get_noise_2d(0.0, _shake_t)
	var nz := _shake_noise.get_noise_2d(_shake_t, 77.0)
	cam.position = Vector3(nx * s * 0.3, ny * s * 0.3, _cam_dist)
	cam.rotation = Vector3(ny * s * 0.05, nx * s * 0.05, _cam_roll + nz * s * 0.08)

	# --- head follows the camera (also what other players see)
	if model != null:
		var alive := not is_dead and ragdoll == null and not wall_walking
		look_angles = HeadLook.angles_from_camera(yaw, pitch, model.global_rotation.y) if alive else Vector2.ZERO
		HeadLook.drive(model, look_angles.x, look_angles.y, delta, alive)

## How far the camera can sit behind the pivot before a wall gets in the way (rays from the
## pivot to the camera centre and the corners of a small box around it; other characters ignored).
func _cam_block(dist: float) -> float:
	if dist < 0.05 or not is_inside_tree():
		return dist
	var space := get_world_3d().direct_space_state
	var from := spring.global_position
	var back := pivot.global_basis.z
	var r := pivot.global_basis.x * 0.18
	var u := pivot.global_basis.y * 0.12
	var best := dist
	for off in [Vector3.ZERO, r + u, r - u, -r + u, -r - u]:
		var a: Vector3 = from + off * 0.5
		var b: Vector3 = from + back * (dist + CAM_MARGIN) + off
		var exclude: Array[RID] = [get_rid()]
		for i in 4:
			var q := PhysicsRayQueryParameters3D.create(a, b)
			q.exclude = exclude
			var h := space.intersect_ray(q)
			if h.is_empty():
				break
			var col: Object = h["collider"]
			if col is CharacterBody3D or col is RigidBody3D:   # enemies, NPCs, ragdolls, players
				exclude.append((col as CollisionObject3D).get_rid())
				continue
			best = minf(best, maxf(0.0, a.distance_to(h["position"]) - CAM_MARGIN))
			break
	return best

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_step(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_step(1)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0028 * sens_mult
		pitch = clampf(pitch - event.relative.y * 0.0028 * sens_mult, -1.35, 1.0)
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("lockon"):
		lock_target = null if lock_target else _nearest_foe(30.0)

func _process(delta: float) -> void:
	_update_camera(delta)
	# FOV kick: wider when sprinting, widest when dashing
	var target_fov := fov_base
	if dash_time > 0.0:
		target_fov = fov_base + 22.0
	elif not is_dead and Input.is_action_pressed("sprint") and Vector2(velocity.x, velocity.z).length() > WALK_SPEED * 1.2:
		target_fov = fov_base + 10.0
	cam.fov = lerpf(cam.fov, target_fov, 1.0 - exp(-(14.0 if target_fov > cam.fov else 5.0) * delta))

func _nearest_enemy(max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_dist
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _physics_process(delta: float) -> void:
	if is_dead:
		if ragdoll:  # camera follows the body
			pivot.global_position = pivot.global_position.lerp(ragdoll.hips() + Vector3.UP * 0.6, 4.0 * delta)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
			move_and_slide()
		return

	if downed > 0.0:   # knocked down: no control until you're back up
		downed -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		if _kd_rag != null and is_instance_valid(_kd_rag) and not _kd_rag.parts.is_empty():
			pivot.global_position = pivot.global_position.lerp(_kd_rag.hips() + Vector3.UP * 0.6, 4.0 * delta)
		return

	combo_timer = maxf(0.0, combo_timer - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	attack_lock = maxf(0.0, attack_lock - delta)
	anim_lock = maxf(0.0, anim_lock - delta)
	kunai_cd = maxf(0.0, kunai_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	clone_cd = maxf(0.0, clone_cd - delta)
	var cd_rate := 1.0 / maxf(_bmul("cd"), 0.1)
	for k in move_cd.keys():
		move_cd[k] = float(move_cd[k]) - delta * cd_rate
		if float(move_cd[k]) <= 0.0:
			move_cd.erase(k)
	t_cd = maxf(0.0, t_cd - delta)
	y_cd = maxf(0.0, y_cd - delta)
	g_cd = maxf(0.0, g_cd - delta)
	h_cd = maxf(0.0, h_cd - delta)
	v_cd = maxf(0.0, v_cd - delta)
	volley_cd = maxf(0.0, volley_cd - delta)
	stam_delay = maxf(0.0, stam_delay - delta)
	if armor_time > 0.0:
		armor_time -= delta
		if armor_time <= 0.0 and not kurama:
			_reset_aura()
	var drain := md_drain()
	if drain > 0.0:   # Kurama Mode and / or the bloodline power-up drain MD; no timers
		mode_meter = maxf(0.0, mode_meter - drain * delta)
		if kurama and not powered:
			aura.light_color = Color(1.0, 0.5, 0.08)
			aura.light_energy = 2.0
		if mode_meter <= 0.0:
			var both := kurama and powered
			_end_mode()
			_power_off()
			_toast("Out of MD - %s ended" % ("both modes" if both else "power-up"))
	elif mode_meter < GameData.md_max():
		mode_meter = minf(GameData.md_max(), mode_meter + 1.0 * delta * _md_mult())
	invuln = maxf(0.0, invuln - delta)
	_update_buffs(delta)
	var hpr := hp_regen + _badd("hp") + (6.0 if kurama else 0.0)
	if hpr > 0.0:
		health = minf(max_health, health + hpr * delta)

	# Lock-on camera
	if not _alive(lock_target):
		lock_target = null
	elif global_position.distance_to(lock_target.global_position) > 45.0:
		lock_target = null
	if lock_target and not wall_walking:
		var d := lock_target.global_position - global_position
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), 6.0 * delta)
		pitch = lerpf(pitch, -0.3, 3.0 * delta)

	# Chakra walk: running up / along walls (see _wall_walk_step)
	if wall_walking:
		if _wall_walk_step(delta):
			move_and_slide()
			return

	# Gravity / jumping
	if is_on_floor():
		jumps_left = 2
	else:
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and jumps_left > 0 and dash_time <= 0.0:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1
		Sfx.play(self, "jump", -6.0)
		if not is_on_floor():
			Fx.puff(get_parent(), global_position, Color(1, 1, 1, 0.6), 1.2)

	# Movement input (camera relative)
	var inp := Input.get_vector("left", "right", "forward", "back")
	var dir := Basis(Vector3.UP, yaw) * Vector3(inp.x, 0.0, inp.y)
	var moving := dir.length() > 0.1

	# Dash (brief invulnerability)
	if Input.is_action_just_pressed("dash") and chakra >= dash_cost and dash_time <= 0.0:
		dash_dir = dir.normalized() if moving else facing
		facing = dash_dir
		dash_time = 0.2
		invuln = 0.35
		chakra -= dash_cost
		Sfx.play(self, "dash", -3.0)
		Fx.puff(get_parent(), global_position + Vector3.UP, Color(0.9, 0.9, 0.9, 0.7), 1.8)
		Vfx.burst(get_parent(), global_position + Vector3.UP, Color(0.6, 0.85, 1.0), 26, 8.0, 0.25, 0.5, 0.0)

	var charging := Input.is_action_pressed("charge") and is_on_floor() and not moving
	_charge_aura(charging)
	var surge := _bmul("speed")
	if kurama:
		surge *= 1.3

	if dash_time > 0.0:
		dash_time -= delta
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
	elif attack_lock > 0.0:
		velocity.x = move_toward(velocity.x, dir.x * 2.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * 2.0, 40.0 * delta)
	else:
		var speed := WALK_SPEED * speed_mult * surge
		if Input.is_action_pressed("sprint") and moving and stamina > 1.0:
			speed = SPRINT_SPEED * speed_mult * surge
			stamina -= 18.0 * delta
			stam_delay = 0.8
		velocity.x = move_toward(velocity.x, dir.x * speed, 70.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, 70.0 * delta)

	_footsteps(delta)
	var regen := (40.0 if charging else 5.0) * regen_mult
	regen += _badd("ck")
	chakra = clampf(chakra + regen * delta, 0.0, max_chakra)
	if stam_delay <= 0.0:
		stamina = minf(max_stamina, stamina + 30.0 * delta)
	stamina = maxf(stamina, 0.0)
	if inf_chakra:
		chakra = max_chakra
		stamina = max_stamina

	if attack_lock <= 0.0 and dash_time <= 0.0:
		if lock_target:
			var tf := lock_target.global_position - global_position
			tf.y = 0.0
			if tf.length() > 0.1:
				facing = tf.normalized()
		elif moving:
			facing = dir.normalized()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-facing.x, -facing.z), 14.0 * delta)

	# Abilities (in Susanoo: left click = punches, right click = slam)
	if susanoo != null:
		_susanoo_update(delta)
	else:
		if Input.is_action_pressed("attack"):
			_melee()
		if Input.is_action_pressed("kunai"):
			_throw_kunai()
	if Input.is_action_just_pressed("ability"):
		_toggle_power()
	for k in Moves.BIND_KEYS:   # hotbar keys run whatever move is bound to them (M > Bloodline / Element)
		if Input.is_action_just_pressed("slot_" + k):
			use_key(k)
	if Input.is_action_just_pressed("biju"):
		_kurama_mode()
	if Input.is_action_just_pressed("volley") and Input.is_action_pressed("kunai"):
		_kunai_volley()
	# C: hold = charge chakra; keep holding for POWER_HOLD s to activate the bloodline power-up
	# (like Shindo Life; needs bloodline LV 1000 and MD). X still turns it on / off.
	# (hold C + 1..4 = forms; Uchiha: 2 = Susanoo)
	if Input.is_action_pressed("charge"):
		c_hold += delta
		for n in 4:
			if Input.is_action_just_pressed("form_%d" % (n + 1)):
				_c_form_used = true
				_activate_form(n + 1)
		# hold C: power up, or release what's on (the Susanoo first, then the power-up)
		var can := susanoo != null or powered or _power_ready()
		if not can:
			_c_power_hold = 0.0
		elif not _c_form_used and not _c_activated:
			_c_power_hold += delta
			if _charge_fx != null and is_instance_valid(_charge_fx):   # aura builds up while you hold
				_charge_fx.set_strength(1.0 + 0.8 * clampf(_c_power_hold / POWER_HOLD, 0.0, 1.0))
			if _c_power_hold >= POWER_HOLD:
				_c_activated = true
				if susanoo != null:
					_susanoo_off()
					_toast("Susanoo released")
				elif powered:
					_power_off()
					_toast("Power-up released")
				else:
					_toggle_power()
	else:
		c_hold = 0.0
		_c_power_hold = 0.0
		_c_form_used = false
		_c_activated = false

	move_and_slide()
	_try_wall_walk(dir)
	dust_t -= delta
	if dust_t <= 0.0 and is_on_floor() and Vector2(velocity.x, velocity.z).length() > SPRINT_SPEED * 0.55 * speed_mult:
		dust_t = 0.11
		Vfx.dust(get_parent(), global_position)
	_update_anim()

# ---------------------------------------------------------------- susanoo (Uchiha)
## Uchiha form 2: hold C and press 2 - the Susanoo forms around you (the Sharingan turns on with it). Left click = alternating left /
## right punches, right click = slam. Drains chakra; ends when chakra runs out, the Sharingan ends
## (hold C) or you die. Each player has their own random Susanoo colour.
const SUS_MIN_CHAKRA := 25.0
const POWER_HOLD := 1.2           # seconds of holding C to power up / release
var _c_power_hold := 0.0          # how long C has been held while powering up / releasing is possible
var _c_activated := false         # this C hold already powered you up
var _c_form_used := false         # a form key was pressed during this C hold (so no tap toggle)
const SUS_DRAIN := 4.0            # chakra per second while it's out
const SUS_PUNCH := {"cd": 0.8, "ck": 6.0, "dmg": 55.0, "ahead": 6.5, "r": 4.5, "knock": 12.0}
const SUS_SLAM := {"cd": 5.0, "ck": 20.0, "dmg": 120.0, "ahead": 5.0, "r": 7.5, "knock": 9.0}
var susanoo: Susanoo
var _sus_charge_fx: Node3D
var _sus_cd := 0.0
var _sus_slam_cd := 0.0
var _sus_left := true
var _sus_zoom := -1.0             # your camera distance before the Susanoo (restored after)

func _susanoo_ready() -> bool:
	return GameData.equipped == "uchiha" and _bl_level() >= Bloodline.MODE_LEVEL

## Hold C and press 1-4: bloodline forms. Uchiha form 2 = Susanoo; the others are coming.
func _activate_form(n: int) -> void:
	if is_dead:
		return
	if GameData.equipped == "uchiha" and n == 2:
		if susanoo != null:
			_susanoo_off()
			_toast("Susanoo released")
		elif not _susanoo_ready():
			_toast("Susanoo unlocks at Uchiha LV %d  (you are LV %d)" % [Bloodline.MODE_LEVEL, _bl_level()])
		elif chakra < SUS_MIN_CHAKRA:
			_toast("Not enough chakra for Susanoo  (%d / %d)" % [int(chakra), int(SUS_MIN_CHAKRA)])
		else:
			_susanoo_on()
		return
	_toast("Form %d - coming soon" % n)

func _susanoo_charge_stop() -> void:
	if _sus_charge_fx != null and is_instance_valid(_sus_charge_fx):
		_sus_charge_fx.queue_free()
	_sus_charge_fx = null

func _susanoo_on() -> void:
	if susanoo != null:
		return
	if not powered:
		_toggle_power()   # Sharingan first (needs MD like a normal power-up)
		if not powered:
			return
	var idx := Susanoo.my_color_index()
	var col := Susanoo.palette_color(idx)
	susanoo = Susanoo.create(col, model)
	add_child(susanoo)
	_sus_cd = 0.6
	_sus_zoom = cam_zoom
	cam_zoom = maxf(cam_zoom, 13.0)   # pull back so the ribcage doesn't fill the screen
	if NetworkSession.is_active():
		NetworkSession.broadcast_combat_animation("susanoo_on", idx)
	Sfx.play(self, "power")
	Vfx.burst(get_parent(), global_position + Vector3.UP * 2.0, col, 48, 11.0, 0.3, 0.8, 0.0)
	Vfx.shockwave(get_parent(), global_position + Vector3.UP * 0.2, col, 7.0, 0.45)
	AuraShell.flare(self, model, col, 1.6)
	var ma := AuraShell.find_in(pmode_fx)   # the Sharingan's aura takes the Susanoo's colour
	if ma != null:
		ma.set_colors(col, col.lightened(0.6))
	Vfx.shake(cam, 0.35, 0.5)
	_toast("SUSANOO!   left click: punch  -  right click: slam  -  hold C: release")

func _susanoo_off() -> void:
	_susanoo_charge_stop()
	if susanoo == null:
		return
	if is_instance_valid(susanoo):
		susanoo.dismiss()
	susanoo = null
	var ma := AuraShell.find_in(pmode_fx)   # back to the mode's own colour
	if ma != null and powered:
		var mc: Color = pmode.get("col", Color.WHITE)
		ma.set_colors(mc, mc.lightened(0.6))
	if _sus_zoom >= 0.0:
		cam_zoom = _sus_zoom
		_sus_zoom = -1.0
	if NetworkSession.is_active():
		NetworkSession.broadcast_combat_animation("susanoo_off", 0)

func _susanoo_update(delta: float) -> void:
	if not is_instance_valid(susanoo):
		susanoo = null
		return
	_sus_cd = maxf(0.0, _sus_cd - delta)
	_sus_slam_cd = maxf(0.0, _sus_slam_cd - delta)
	if not inf_chakra:
		chakra = maxf(0.0, chakra - SUS_DRAIN * delta)
	if chakra <= 0.0 or not powered or is_dead:
		_toast("Susanoo faded - out of chakra" if chakra <= 0.0 else "Susanoo released")
		_susanoo_off()
		return
	if Input.is_action_pressed("attack") and _sus_cd <= 0.0 and chakra >= float(SUS_PUNCH["ck"]):
		var kind := "lpunch" if _sus_left else "rpunch"
		_sus_left = not _sus_left
		_susanoo_attack(kind, SUS_PUNCH)
		_sus_cd = float(SUS_PUNCH["cd"])
	elif Input.is_action_just_pressed("kunai") and _sus_slam_cd <= 0.0 and chakra >= float(SUS_SLAM["ck"]):
		_susanoo_attack("slam", SUS_SLAM)
		_sus_slam_cd = float(SUS_SLAM["cd"])
		_sus_cd = 1.2

func _susanoo_attack(kind: String, d: Dictionary) -> void:
	if not inf_chakra:
		chakra -= float(d["ck"])
	# face where the camera looks
	var f := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	facing = Vector3(f.x, 0, f.z).normalized()
	model.rotation.y = atan2(-facing.x, -facing.z)
	susanoo.attack(kind)
	if NetworkSession.is_active():
		NetworkSession.broadcast_combat_animation("susanoo_" + kind, 0)
	var fwd := facing
	get_tree().create_timer(Susanoo.impact_delay(kind)).timeout.connect(func() -> void: _susanoo_impact(kind, d, fwd))

func _susanoo_impact(kind: String, d: Dictionary, fwd: Vector3) -> void:
	if susanoo == null or is_dead or not is_inside_tree():
		return
	var center := global_position + fwd * float(d["ahead"]) * Susanoo.SCALE / 1.3
	var r := float(d["r"])
	var col := susanoo.color
	for t in _foes_in(float(d["ahead"]) + r):
		var to := t.global_position - center
		to.y = 0.0
		if to.length() <= r:
			var away := (t.global_position - global_position)
			away.y = 0.0
			var knock := away.normalized() * float(d["knock"]) + Vector3.UP * (7.0 if kind == "slam" else 3.0)
			_hit_foe(t, float(d["dmg"]) * _dmg(), knock)
			VfxKit.hit(get_parent(), t.global_position + Vector3.UP * 1.2, col, 1.4)
	if kind == "slam":
		Vfx.shockwave(get_parent(), center + Vector3.UP * 0.15, col, r, 0.5)
		Vfx.burst(get_parent(), center + Vector3.UP * 0.5, col, 40, 10.0, 0.35, 0.7, 0.0)
		for k in 8:
			Vfx.dust(get_parent(), center + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * r * 0.6)
		Vfx.shake(cam, 0.45, 0.5)
	else:
		Vfx.burst(get_parent(), center + Vector3.UP * 1.0, col, 22, 7.0, 0.25, 0.45, 0.0)
		Vfx.dust(get_parent(), center)
		Vfx.shake(cam, 0.18, 0.25)
	Sfx.play(self, "hit")

# ---------------------------------------------------------------- chakra walk
## Stick to walls and ceilings like in Naruto. Sprint into a wall (or jump into a ceiling while
## holding Sprint) and your feet stick to it; then walk anywhere on it with WASD (camera-relative:
## looking at a wall, W goes up). You stay stuck without holding anything - Space jumps off,
## running out of chakra drops you, and walking over an edge wraps you onto the next surface
## (wall -> roof, wall -> ceiling...). Stepping onto ground that faces up turns it back off.
## Holding Sprint while stuck moves faster but drains more.
const STICK_SPEED := 5.5
const STICK_SPRINT := 10.0
const STICK_CHAKRA_WALL := 4.0      # chakra per second on walls
const STICK_CHAKRA_CEILING := 7.0   # ... upside down
const STICK_REACH := 1.35           # how far the feet look for the surface
var wall_walking := false           # true while stuck to a wall / ceiling
var wall_n := Vector3.ZERO          # normal of the surface we stand on (points away from it)
var _wall_cd := 0.0
var _stick_fwd := Vector3.UP        # last movement direction on the surface (model faces it)
var _feet := Vector3.ZERO           # surface point under the feet
var _surf_q := Quaternion.IDENTITY  # turns world-up onto the surface we stand on (carried across edges)
var _cam_q := Quaternion.IDENTITY   # what the camera currently uses (eases toward _surf_q)

func _try_wall_walk(dir: Vector3) -> void:
	_wall_cd = maxf(0.0, _wall_cd - get_physics_process_delta_time())
	if wall_walking or _wall_cd > 0.0 or dash_time > 0.0 or attack_lock > 0.0 or is_dead or susanoo != null:
		return
	if not Input.is_action_pressed("sprint") or chakra < 5.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if not _climbable(c.get_collider()):
			continue
		var wall := absf(n.y) < 0.3 and dir.length() > 0.1 and dir.normalized().dot(-n) > 0.55
		var ceiling := n.y < -0.7 and not is_on_floor()
		if wall or ceiling:
			_stick_to(n.normalized(), c.get_position())
			Fx.puff(get_parent(), c.get_position(), Color(0.7, 0.85, 1.0, 0.6), 1.0)
			return

func _climbable(col: Object) -> bool:
	if not (col is StaticBody3D or col is CSGShape3D):
		return false   # not enemies / NPCs / ragdolls
	var n := col as Node
	return not (n.name.begins_with("Bound") or (n.get_parent() != null and n.get_parent().name == "Bounds"))

func _stick_to(n: Vector3, point: Vector3) -> void:
	wall_walking = true
	wall_n = n
	_feet = point
	velocity = Vector3.ZERO
	# keep facing "forward" along the new surface: up the wall, or away from it on ceilings
	var f := Vector3.UP - n * n.dot(Vector3.UP)
	if f.length() < 0.2:
		f = facing - n * n.dot(facing)
	_stick_fwd = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	# the camera tilts with us: the surface becomes "the ground" (looking at a wall -> looking up it)
	_surf_q = _arc(Vector3.UP, n) * _surf_q

## Shortest rotation taking direction a onto b (a stable axis when they point opposite ways).
func _arc(a: Vector3, b: Vector3) -> Quaternion:
	if a.dot(b) < -0.999:
		var ax := pivot.global_basis.x
		ax = (ax - a * a.dot(ax)).normalized()
		if ax.length() < 0.5:
			ax = a.cross(Vector3.RIGHT if absf(a.x) < 0.9 else Vector3.FORWARD).normalized()
		return Quaternion(ax, PI)
	return Quaternion(a.normalized(), b.normalized())

## Middle of the body - the point the feet probe from (the capsule stays upright).
func _stick_center() -> Vector3:
	return global_position + Vector3.UP * 0.9

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty() and not _climbable(h["collider"]):
		return {}
	return h

## Movement on the surface, relative to the (tilted) camera: W = forward on screen, A/D strafe,
## the mouse turns. The camera frame is carried across edges, so W keeps going the same way.
func _surface_move(n: Vector3) -> Vector3:
	var inp := Input.get_vector("left", "right", "forward", "back")
	if inp.length() < 0.1:
		return Vector3.ZERO
	var b := Basis(_surf_q) * Basis(Vector3.UP, yaw)
	var f := b * Vector3.FORWARD
	var rgt := b * Vector3.RIGHT
	f = (f - n * n.dot(f)).normalized()
	rgt = (rgt - n * n.dot(rgt)).normalized()
	var m := f * -inp.y + rgt * inp.x
	return m.normalized() * minf(inp.length(), 1.0)

## One physics step while stuck. Returns false when we let go (normal movement takes over).
func _wall_walk_step(delta: float) -> bool:
	if is_dead:
		_end_wall_walk(Vector3.ZERO)
		return false
	if Input.is_action_just_pressed("jump"):   # leap off the surface
		_end_wall_walk(wall_n * 9.0 + Vector3.UP * (6.0 if wall_n.y > -0.5 else 0.0))
		jumps_left = 1
		Sfx.play(self, "jump", -6.0)
		Fx.puff(get_parent(), _feet, Color(0.7, 0.85, 1.0, 0.6), 1.4)
		return false
	var sprinting := Input.is_action_pressed("sprint")
	var drain := STICK_CHAKRA_CEILING if wall_n.y < -0.5 else STICK_CHAKRA_WALL
	if not inf_chakra:
		chakra = maxf(0.0, chakra - drain * (1.6 if sprinting else 1.0) * delta)
	if chakra <= 0.0:
		_toast("Out of chakra")
		_end_wall_walk(wall_n * 2.0)
		return false

	var move := _surface_move(wall_n)
	var spd := (STICK_SPRINT if sprinting else STICK_SPEED) * speed_mult

	# find the surface under the feet; wrap over edges / into corners
	var c := _stick_center()
	var hit := _ray(c, c - wall_n * STICK_REACH)
	if move.length() > 0.1:
		# concave corner: another surface right ahead of us -> climb onto it
		var ahead := _ray(c, c + move.normalized() * 1.25)   # body is ~0.9 m from centre to head
		if not ahead.is_empty() and (ahead["normal"] as Vector3).dot(wall_n) < 0.5:
			hit = ahead
	var wrapped := false
	if hit.is_empty() and move.length() > 0.1:
		# convex edge (top of a wall, roof edge...): look around the corner, behind and below us
		var corner := c + move.normalized() * 0.5 - wall_n * (STICK_REACH + 0.4)
		hit = _ray(corner, corner - move.normalized() * 1.6)
		wrapped = not hit.is_empty()
	if hit.is_empty():
		_end_wall_walk(wall_n * 1.5)   # nothing to stand on: fall
		return false
	var n: Vector3 = (hit["normal"] as Vector3).normalized()
	_feet = hit["position"]
	if n.y > 0.7:   # walked onto ground that faces up: back to normal walking
		_end_wall_walk(Vector3.ZERO)
		global_position = _feet + Vector3.UP * 0.05
		return false
	var new_n := wall_n.slerp(n, 1.0 - exp(-14.0 * delta)).normalized() if wall_n.dot(n) > 0.2 else n
	if new_n.dot(wall_n) < 0.99999:   # carry the camera frame (and facing) over the edge
		var q := _arc(wall_n, new_n)
		_surf_q = q * _surf_q
		_stick_fwd = q * _stick_fwd
	wall_n = new_n
	if wrapped and n.y <= 0.7:   # went round an edge: put the body in front of the new face
		if n.dot(wall_n) < 0.99999:
			var q2 := _arc(wall_n, n)
			_surf_q = q2 * _surf_q
			_stick_fwd = q2 * _stick_fwd
		wall_n = n
		global_position = _feet + n * 0.55 - Vector3.UP * 0.9
		c = _stick_center()
	# move along the surface, pulled gently onto it so the body hugs it
	var gap := (c - _feet).dot(wall_n)
	velocity = move * spd - wall_n * clampf((gap - 0.55) * 8.0, -3.0, 6.0)
	if move.length() > 0.1:
		_stick_fwd = move.normalized()
	# model: feet on the surface, head pointing away from it, facing the way we walk
	var fwd := _stick_fwd - wall_n * wall_n.dot(_stick_fwd)
	if fwd.length() < 0.05:
		fwd = Vector3.UP - wall_n * wall_n.dot(Vector3.UP)
	if fwd.normalized().cross(wall_n).length() > 0.05:
		model.global_basis = Basis.looking_at(fwd.normalized(), wall_n).scaled(model.basis.get_scale())
	model.global_position = _feet
	var moving := move.length() > 0.1
	Hero.play_move(model, "run" if moving else "idle", spd if moving else 0.0)
	dust_t -= delta
	if dust_t <= 0.0 and moving:
		dust_t = 0.15 if sprinting else 0.25
		Vfx.dust(get_parent(), _feet)
	return true

func _end_wall_walk(launch: Vector3) -> void:
	wall_walking = false
	# fold the camera tilt back into a plain yaw so the view doesn't snap, then level out smoothly
	var back := _arc(wall_n, Vector3.UP) * _surf_q   # now only a turn around world up
	var v := back * Vector3.FORWARD
	var turn := atan2(-v.x, -v.z) if Vector2(v.x, v.z).length() > 0.01 else 0.0
	_cam_q = _cam_q * Quaternion(Vector3.UP, -turn)
	yaw += turn
	_surf_q = Quaternion.IDENTITY
	_wall_cd = 0.35
	velocity = launch
	model.position = Vector3.ZERO
	var f := Vector3(_stick_fwd.x, 0, _stick_fwd.z)
	if f.length() < 0.1:
		f = Vector3(-wall_n.x, 0, -wall_n.z) if launch.dot(wall_n) <= 0.0 else Vector3(wall_n.x, 0, wall_n.z)
	if f.length() > 0.1:
		facing = f.normalized()
	model.basis = Basis(Vector3.UP, atan2(-facing.x, -facing.z)).scaled(model.basis.get_scale())

func _update_anim() -> void:
	if anim_lock > 0.0:
		if sitting:
			sitting = false
			NetworkSession.broadcast_combat_animation("sit", 0)
		return
	var st := "idle"
	var ground := 0.0
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if Input.is_action_just_pressed("sit") and is_on_floor():
		sitting = not sitting
		if sitting:
			Hero.play(model, "sit", true, 0, 0.0, 0.45)
		else:
			Hero.play(model, "idle", false, 0, 0.0, 0.35)
		NetworkSession.broadcast_combat_animation("sit", 1 if sitting else 0)
	if sitting:
		if hv.length() > 0.5 or not is_on_floor() or dash_time > 0.0:
			sitting = false
			NetworkSession.broadcast_combat_animation("sit", 0)
		else:
			return
	if not is_on_floor():
		st = "jump" if velocity.y > 0.5 else "fall"
	elif dash_time > 0.0:
		st = "dash"
	elif hv.length() > 1.0:
		st = Hero.move_state(hv.length())
		ground = hv.length()
		if lock_target:
			var fwd := hv.dot(facing)
			var side := hv.dot(facing.cross(Vector3.UP))
			if absf(side) > absf(fwd) * 0.8:
				st = "strafe_r" if side > 0.0 else "strafe_l"
	Hero.play_move(model, st, ground)

func _play_once(state: String, max_lock: float, variant := 0) -> bool:
	var l := Hero.play(model, state, true, variant, max_lock)
	if l > 0.0:
		anim_lock = minf(l, max_lock)
		return true
	return false

func _melee() -> void:
	if attack_cd > 0.0 or dash_time > 0.0:
		return
	combo = combo + 1 if combo_timer > 0.0 else 1
	if combo > 3:
		combo = 1
	combo_timer = 0.8
	attack_cd = 0.5 if combo == 3 else 0.28
	attack_lock = attack_cd
	var tgt: Node3D = lock_target if lock_target else _nearest_foe(6.0)
	if tgt:
		var f := tgt.global_position - global_position
		f.y = 0.0
		if f.length() > 0.01:
			facing = f.normalized()
			model.rotation.y = atan2(-facing.x, -facing.z)
	velocity.x = facing.x * 10.0
	velocity.z = facing.z * 10.0
	Sfx.play(self, "swing", -4.0)
	if NetworkSession.is_active():
		NetworkSession.broadcast_combat_animation("attack", combo - 1)
	var dmg := (10.0 + combo * 4.0) * _dmg()
	var knock := 14.0 if combo == 3 else 4.0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var to := e.global_position - global_position
		to.y = 0.0
		var reach := 3.2 * e.k
		if to.length() < reach and (to.length() < 0.8 or facing.dot(to.normalized()) > 0.3):
			e.take_damage(dmg, facing * knock)
			if combo == 3:   # combo finisher knocks them down
				e.knockdown(facing * knock)
			VfxKit.hit(get_parent(), e.global_position + Vector3.UP * 1.1 * e.k, null, 0.7 if combo < 3 else 1.1)
	if NetworkSession.is_active() and NetworkSession.session_mode == "pvp":
		NetworkSession.try_hit_players(dmg, facing * knock, combo == 3)
	if not _play_once("attack", attack_cd + 0.1, combo - 1):
		Fx.swing(arm)

func _aim_dir(origin: Vector3) -> Vector3:
	var aim: Vector3
	if lock_target:
		aim = lock_target.global_position + Vector3.UP
	else:
		aim = cam.global_position - cam.global_transform.basis.z * 60.0
	var dir := (aim - origin).normalized()
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		facing = flat.normalized()
		model.rotation.y = atan2(-facing.x, -facing.z)
	return dir

func _shoot(speed: float, dmg: float, aoe: float, size: float, color: Color, long: bool, homing: bool, visual := "") -> void:
	var origin := global_position + Vector3.UP * 1.3 + facing * 1.25
	var dir := _aim_dir(origin)
	var pr := Projectile.new()
	pr.position = origin
	pr.speed = speed
	pr.velocity = dir * speed
	pr.damage = dmg * _dmg()
	pr.aoe = aoe
	pr.size = size
	pr.color = color
	pr.long_shape = long
	pr.source_player = self
	pr.visual_kind = visual
	if homing and _alive(lock_target):
		pr.target = lock_target
	get_parent().add_child(pr)
	pr.global_position = origin
	if NetworkSession.is_active():
		NetworkSession.broadcast_projectile(origin, dir * speed, speed, size, color, long, aoe, dmg * _dmg(), visual, _peer_of(pr.target))

func _throw_kunai() -> void:
	if kunai_cd > 0.0 or chakra < 3.0:
		return
	kunai_cd = 0.25
	chakra -= 3.0
	Sfx.play(self, "throw", -6.0)
	_shoot(42.0, 9.0, 0.0, 0.15, Color(0.85, 0.85, 0.95), true, true)
	if not _play_once("throw", 0.2):
		Fx.swing(arm)

# ---- hand-made jutsu used by moves.gd / element_data.gd ("custom" moves). Cost and cooldown
# are handled by _use_move(); these only do the effect. `col` = the move's colour.
func _fx_fireball(col: Color) -> void:
	Sfx.play(self, "fire")
	_shoot(22.0, 45.0, 5.0, 0.6, col, false, false, "fireball")
	VfxKit.cast(get_parent(), global_position + Vector3.UP * 1.3 + facing * 1.0, facing, Color(1.0, 0.45, 0.1), 0.75)
	if not _play_once("jutsu", 0.6):
		Fx.swing(arm)

func _fx_clones(_col: Color) -> void:
	Sfx.play(self, "poof")
	var side := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var spawned_clones: Array[Clone] = []
	for i in clone_count:
		var offs := (i - (clone_count - 1) / 2.0) * 2.5
		var spawn_pos := global_position + side * offs
		var c := Clone.new()
		c.life = clone_time
		c.slot = i
		c.slot_count = clone_count
		c.position = spawn_pos
		get_parent().add_child(c)
		spawned_clones.append(c)
	if NetworkSession.is_active():
		NetworkSession.broadcast_shadow_clones(spawned_clones, clone_time)
	_play_once("jutsu", 0.6)

## ---- Bloodline abilities (keys 1 2 3) and power-up mode (C) ----
## Abilities come from Bloodline.ability(); each unlocks at a bloodline (mastery) level.
## The power-up (C, unlocked at bloodline LV 1000) has no timer: it drains MD and ends
## when MD runs out or C is pressed again.
const POWER_DRAIN_TIME := 30.0   # seconds a full MD bar lasts while powered up
const POWER_MIN_MD := 10.0       # MD needed to power up

func _bl_level() -> int:
	return GameData.mastery_level(GameData.equipped)

func _bl_name() -> String:
	return str(Bloodline.get_def(GameData.equipped)["name"])

## Damage multiplier from points in the Bloodline stat.
func _bl_mult() -> float:
	return 1.0 + GameData.stat_bonus("bloodline")

## MD gain multiplier from points in the MD stat.
func _md_mult() -> float:
	return 1.0 + GameData.stat_bonus("md")

## Product of a multiplier over active buffs and the power-up mode (dmg, speed, def, cd).
func _bmul(key: String) -> float:
	var m := 1.0
	for b in buffs:
		m *= float(b[key])
	if powered:
		m *= float(pmode[key])
	return m

## Sum of an additive bonus over active buffs and the power-up mode (hp, ck).
func _badd(key: String) -> float:
	var s := 0.0
	for b in buffs:
		s += float(b[key])
	if powered:
		s += float(pmode[key])
	return s

func _immune() -> bool:
	for b in buffs:
		if b["immune"]:
			return true
	return false

## Speed multiplier applied to every enemy (Sharingan, Shadow Domain...).
func enemy_slow() -> float:
	var s := 1.0
	for b in buffs:
		s = minf(s, float(b["slow"]))
	if powered:
		s = minf(s, float(pmode["slow"]))
	return s

## True while an Uchiha eye effect is up (HUD red tint).
func eye_overlay() -> bool:
	if GameData.equipped != "uchiha":
		return false
	if powered:
		return true
	for b in buffs:
		if float(b["slow"]) < 0.5:
			return true
	return false

## Runs the move on a hotbar key.
func use_key(k: String) -> void:
	var mv := str(GameData.keybinds.get(k, ""))
	if mv == "":
		_toast("Nothing on [%s] - assign a move in M > Bloodline or M > Element" % k)
		return
	_use_move(mv)

func _use_move(id: String) -> void:
	if is_dead:
		return
	var a := Moves.spec(id)
	if a.is_empty():
		return
	var why := Moves.block(id)
	if why != "":
		_toast("%s: %s" % [a["name"], why])
		return
	if float(move_cd.get(id, 0.0)) > 0.0:
		return
	var cost := float(a["cost"])
	if bool(a["fire_cost"]):
		cost *= fire_cost / 30.0
	if chakra < cost:
		_toast("Not enough chakra for %s" % a["name"])
		return
	var kind := str(a["kind"])
	var target: Node3D = null
	if kind == "target":
		target = lock_target if _alive(lock_target) \
			and lock_target.global_position.distance_to(global_position) <= float(a["r"]) else _nearest_foe(float(a["r"]))
		if target == null:
			_toast("No enemy in range (%dm)" % int(a["r"]))
			return
	chakra -= cost
	move_cd[id] = float(a["cd"])
	cur_mkey = str(a["mkey"])
	var raw := Moves.raw(id)
	var col: Color = a["col"]
	if NetworkSession.is_active():
		NetworkSession.broadcast_ability(id, col)
	var mult := _bl_mult() if a["src"] == "bl" else 1.0
	var dmg := float(a["dmg"]) * _dmg() * mult
	if kind != "custom":
		Sfx.play(self, "power", -3.0)
	match kind:
		"custom":   # hand-made jutsu (original Fire Style, clones, substitution, armor)
			call(str(a["fn"]), col)
		"burst":
			for e in _foes_in(float(a["r"])):
				var to := (e.global_position - global_position) * Vector3(1, 0, 1)
				_stun(e, float(a["stun"]))
				_hit_foe(e, dmg, to.normalized() * float(a["knock"]))
			Vfx.shockwave(get_parent(), global_position + Vector3.UP * 0.2, col, float(a["r"]), 0.45)
		"cone":
			for e in _foes_in(float(a["r"])):
				var to := (e.global_position - global_position) * Vector3(1, 0, 1)
				if to.normalized().dot(facing) > float(a["dot"]):
					_stun(e, float(a["stun"]))
					_hit_foe(e, dmg, to.normalized() * float(a["knock"]))
			Vfx.shockwave(get_parent(), global_position + facing * float(a["r"]) * 0.4 + Vector3.UP * 0.2, col, float(a["r"]) * 0.6, 0.35)
		"target":
			_stun(target, float(a["stun"]))
			Vfx.shockwave(get_parent(), target.global_position + Vector3.UP, col, 3.0, 0.4)
			Fx.puff(get_parent(), target.global_position + Vector3.UP, Color(col.r, col.g, col.b, 0.85), 2.0)
			_hit_foe(target, dmg, Vector3.ZERO)
		"fan":
			var projectile_visual := "rasenshuriken" if id == "bl:uzumaki:2" else ""
			_fan(int(a["n"]), float(a["spread"]), float(a["speed"]), float(a["dmg"]) * mult,
				float(a["aoe"]), float(a["size"]), col, bool(a["long"]), projectile_visual)
		"homing":
			_homing(int(a["n"]), float(a["dmg"]) * mult, float(a["aoe"]), col, float(a["size"]))
		"dash":
			var dir := facing
			if is_instance_valid(lock_target):
				var d := (lock_target.global_position - global_position) * Vector3(1, 0, 1)
				if d.length() > 0.1:
					dir = d.normalized()
			var reach := float(a["dist"])
			for e in _foes_in(reach + 1.0):
				var to := (e.global_position - global_position) * Vector3(1, 0, 1)
				var along := to.dot(dir)
				if along > -0.5 and along < reach + 1.0 and (to - dir * along).length() < 2.5:
					_hit_foe(e, dmg, dir * 12.0)
			facing = dir
			dash_dir = dir
			dash_time = reach / DASH_SPEED
			invuln = maxf(invuln, dash_time + 0.2)
			Vfx.burst(get_parent(), global_position + Vector3.UP, col, 40, 10.0, 0.25, 0.4, 0.0)
			Vfx.trail(self, col, 0.35, 40, 0.5)
		"buff", "aura":
			_add_buff(str(a["name"]), raw, col, cur_mkey)
	if float(a["heal"]) > 0.0:
		health = minf(max_health, health + float(a["heal"]))
	if not powered:
		aura.light_energy = 4.0
	if kind != "custom":
		Fx.puff(get_parent(), global_position + Vector3.UP, Color(col.r, col.g, col.b, 0.7), 3.0)
		_play_once("jutsu", 0.5)
	cur_mkey = ""

func _stun(e, secs: float) -> void:   # untyped: the target may already be freed
	if secs <= 0.0 or not is_instance_valid(e) or not (e is Enemy):
		return
	e.stun = maxf(e.stun, secs * (0.4 if e.is_boss else 1.0))   # bosses shrug most of it off
	e.windup = 0.0

## Buff/aura entry. `raw` is the ability's own data, so unset fields mean "no change".
func _add_buff(bname: String, raw: Dictionary, col: Color, mkey := "") -> void:
	buffs = buffs.filter(func(b: Dictionary) -> bool: return b["name"] != bname)
	buffs.append({"name": bname, "t": float(raw.get("t", 5.0)),
		"dmg": float(raw.get("dmg", 1.0)) if raw.get("kind", "") == "buff" else 1.0,
		"speed": float(raw.get("speed", 1.0)), "def": float(raw.get("def", 1.0)), "cd": 1.0,
		"hp": float(raw.get("hp", 0.0)), "ck": float(raw.get("ck", 0.0)),
		"immune": bool(raw.get("immune", false)), "slow": float(raw.get("slow", 1.0)),
		"r": float(raw.get("r", 0.0)), "dps": float(raw.get("dps", 0.0)), "col": col, "tick": 0.0, "mkey": mkey})

## Ticks buffs, damage auras and the power-up drain. Called every physics frame.
func _update_buffs(delta: float) -> void:
	for b in buffs:
		b["t"] = float(b["t"]) - delta
		if float(b["dps"]) > 0.0:
			b["tick"] = float(b["tick"]) - delta
			if float(b["tick"]) <= 0.0:
				b["tick"] = 0.5
				cur_mkey = str(b["mkey"])
				_aura_tick(float(b["r"]), float(b["dps"]), b["col"])
				cur_mkey = ""
	buffs = buffs.filter(func(b: Dictionary) -> bool: return float(b["t"]) > 0.0)
	if powered and float(pmode["dps"]) > 0.0:
		mode_tick -= delta
		if mode_tick <= 0.0:
			mode_tick = 0.5
			cur_mkey = GameData.equipped
			_aura_tick(float(pmode["r"]), float(pmode["dps"]), pmode["col"])
			cur_mkey = ""
	Enemy.time_scale = enemy_slow()
	if buffs.is_empty() and not powered and armor_time <= 0.0 and not kurama and aura.light_energy > 1.2:
		aura.light_energy = move_toward(aura.light_energy, 1.2, 6.0 * delta)
		if aura.light_energy <= 1.2:
			aura.visible = false   # buff faded: back to no glow

func _aura_tick(radius: float, dps: float, col: Color) -> void:
	for e in _foes_in(radius):
		_hit_foe(e, dps * 0.5 * _dmg() * (_bl_mult() if not cur_mkey.begins_with("el:") else 1.0), Vector3.ZERO)
		Fx.puff(get_parent(), e.global_position + Vector3.UP * 1.2, Color(col.r, col.g, col.b, 0.8), 0.9)
	Vfx.burst(get_parent(), global_position + Vector3.UP, col, 16, 5.0, 0.15, 0.5, 0.0)

## Footstep sounds: walk / run steps paced by your ground speed.
var _step_t := 0.0
func _footsteps(delta: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or sp < 1.0 or wall_walking:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		var run := sp > Hero.WALK_BELOW
		Sfx.play(self, "step_run" if run else "step_walk")
		_step_t = clampf(2.4 / sp, 0.22, 0.55) if run else 0.5

## A combo finisher knocked you down: limp for a moment, then you get up where you landed.
func _knockdown(knock: Vector3) -> void:
	if downed > 0.0 or is_dead or susanoo != null or model == null:
		return
	if wall_walking:
		_end_wall_walk(Vector3.ZERO)
	sitting = false
	_charge_aura(false)
	_kd_rag = Ragdoll.knockdown(model, get_parent(), knock * 0.45 + Vector3.UP * 3.5, Enemy.DOWN_TIME, func(hips: Vector3, yaw: float) -> void:
		global_position = Vector3(hips.x, global_position.y, hips.z)
		if not is_nan(yaw):
			facing = Vector3(-sin(yaw), 0.0, -cos(yaw))
			model.basis = Basis(Vector3.UP, yaw).scaled(model.basis.get_scale()), self)
	if _kd_rag == null:
		return
	downed = Enemy.DOWN_TIME + Enemy.RISE_TIME
	anim_lock = 0.0
	Sfx.play(self, "thud", -2.0)
	if NetworkSession.is_active():
		NetworkSession.broadcast_combat_animation("knockdown", 0)

## Chakra aura around you while you hold C to charge (Aura 3D shader shell).
const CHARGE_AURA := Color(0.2, 0.55, 1.0)
const CHARGE_RIM := Color(0.75, 0.92, 1.0)
var _charge_fx: AuraShell
func _charge_aura(on: bool) -> void:
	if on and is_dead == false and model != null:
		# in the Susanoo your chakra takes its colour
		var col := CHARGE_AURA
		var rim := CHARGE_RIM
		if susanoo != null and is_instance_valid(susanoo):
			col = susanoo.color
			rim = susanoo.color.lightened(0.6)
		if _charge_fx == null or not is_instance_valid(_charge_fx) or _charge_fx.has_meta("closing"):
			_charge_fx = AuraShell.make(self, model, col, rim)
		elif _charge_fx.aura_col != col:
			_charge_fx.set_colors(col, rim)
	elif _charge_fx != null:
		if is_instance_valid(_charge_fx):
			_charge_fx.fade_out()
		_charge_fx = null

## Could you power up right now? (quiet version of the checks in _toggle_power)
func _power_ready() -> bool:
	var id := GameData.equipped
	return id != "none" and _bl_level() >= Bloodline.MODE_LEVEL and mode_meter >= POWER_MIN_MD and _chakra_full()

func _chakra_full() -> bool:
	return chakra >= max_chakra - 0.5

func _clear_buffs() -> void:
	buffs.clear()
	Enemy.time_scale = 1.0

## Hold C / X: turn the bloodline power-up on (X also turns it off).
func _toggle_power() -> void:
	if is_dead:
		return
	if powered:
		_power_off()
		_toast("Power-up released")
		return
	var id := GameData.equipped
	if id == "none":
		_toast("No bloodline equipped - spin one at the main menu")
		return
	var m := Bloodline.mode(id)
	var lv := _bl_level()
	if lv < Bloodline.MODE_LEVEL:
		_toast("%s unlocks at %s LV %d  (you are LV %d)" % [m["name"], _bl_name(), Bloodline.MODE_LEVEL, lv])
		return
	if mode_meter < POWER_MIN_MD:
		_toast("Not enough MD to power up  (%d / %d)" % [int(mode_meter), int(POWER_MIN_MD)])
		return
	if not _chakra_full():
		_toast("Charge your chakra to full to transform  (%d / %d)" % [int(chakra), int(max_chakra)])
		return
	powered = true
	pmode = m
	mode_tick = 0.0
	var col: Color = m["col"]
	if NetworkSession.is_active():
		NetworkSession.broadcast_power_state(true, col, id)
	if not m.has("cutscene"):   # with a cutscene, the look switches on at its big moment instead
		Hero.apply_mode_look(model, m.get("look", {}))
	pmode_fx = Node3D.new()
	add_child(pmode_fx)
	# the mode's aura (Aura 3D shell); faint when the body already glows so it doesn't hide it.
	# Eye techniques get none - their glowing eyes are the effect.
	if not Bloodline.eye_mode(m):
		var mode_aura := AuraShell.make(pmode_fx, model, col, col.lightened(0.6), 0.4)
		if m.get("look", {}).has("glow"):
			mode_aura.set_strength(0.45)
		aura.visible = true
		aura.light_color = col
		aura.light_energy = 1.8
	Sfx.play(self, "power")
	Vfx.burst(get_parent(), global_position + Vector3.UP, col, 32, 8.0, 0.22, 0.6, 0.0)
	Vfx.shockwave(get_parent(), global_position + Vector3.UP * 0.2, col, 4.0, 0.35)
	Vfx.shake(cam, 0.2, 0.35)
	_toast("KURAMA MODE + %s!" % str(m["name"]).to_upper() if kurama else "%s!" % str(m["name"]).to_upper())
	_play_once("jutsu", 0.6)

func _power_off() -> void:
	_susanoo_off()   # the Susanoo needs the Sharingan
	if not powered:
		return
	if NetworkSession.is_active():
		NetworkSession.broadcast_power_state(false, Color.WHITE, "")
	if model != null and not pmode.get("look", {}).is_empty():
		Hero.apply_mode_look(model, {})
	powered = false
	pmode = {}
	if pmode_fx != null and is_instance_valid(pmode_fx):
		pmode_fx.queue_free()
	pmode_fx = null
	Enemy.time_scale = enemy_slow()
	if aura:
		_reset_aura()

# ---- XP / mastery ----
func on_kill(boss: bool) -> void:
	gain_xp(GameData.XP_BOSS if boss else GameData.XP_KILL)
	_gain_mastery(GameData.MASTERY_BOSS if boss else GameData.MASTERY_KILL)
	_gain_element(GameData.MASTERY_BOSS if boss else GameData.MASTERY_KILL)
	GameData.save()

func gain_xp(n: int) -> void:
	var gained := GameData.add_xp(n)
	if gained > 0:
		Sfx.play(self, "power", -2.0)
		Vfx.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.85, 0.3), 50, 9.0, 0.3, 0.8, 0.0)
		_toast("LEVEL UP!  LV %d   (+%d stat points - M > Stats)" % [GameData.level, gained * GameData.POINTS_PER_LEVEL])

func _gain_mastery(n: int) -> void:
	var id := GameData.equipped
	if id == "none":
		return
	var r := GameData.add_mastery(id, n)
	var old: int = r[0]
	var now: int = r[1]
	if now <= old:
		return
	for i in 3:
		var a := Bloodline.ability(id, i)
		if not a.is_empty() and old < int(a["lvl"]) and now >= int(a["lvl"]):
			_toast("NEW ABILITY: %s  - assign it to a key in M > Bloodline" % a["name"])
			return
	if old < Bloodline.MODE_LEVEL and now >= Bloodline.MODE_LEVEL:
		_toast("POWER-UP UNLOCKED: %s  - hold C!" % Bloodline.mode(id)["name"])
		Sfx.play(self, "power")
	elif now / 100 > old / 100:
		_toast("%s mastery LV %d" % [_bl_name(), now])

## Element mastery from kills goes to your main (equipped) element.
func _gain_element(n: int) -> void:
	var el := GameData.equipped_element
	var key := "el:" + el
	var r := GameData.add_mastery(key, n)
	var old: int = r[0]
	var now: int = r[1]
	for i in ElementData.count(el):
		var a := ElementData.ability(el, i)
		if old < int(a["lvl"]) and now >= int(a["lvl"]):
			_toast("NEW %s JUTSU: %s  - assign it in M > Element" % [el.to_upper(), a["name"]])
			return

## Enemies still alive within `radius` metres (flat distance).
func _enemies_in(radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.health > 0.0:
			var to := e.global_position - global_position
			to.y = 0.0
			if to.length() <= radius:
				out.append(e)
	return out

## Enemies plus, in the PvP arena, other players you can fight (both joined PvP Battle).
func _foes_in(radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e in _enemies_in(radius):
		out.append(e)
	for av in NetworkSession.hostile_avatars():
		var to := av.global_position - global_position
		to.y = 0.0
		if to.length() <= radius:
			out.append(av)
	return out

func _nearest_foe(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	for f in _foes_in(max_dist):
		var d := global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best

## Still a valid target: a living enemy, or a player you can still fight.
## Untyped on purpose: a lock target that was freed (enemy died) can't be passed as Node3D.
func _alive(t) -> bool:
	if not is_instance_valid(t):
		return false
	if t is Enemy:
		return t.health > 0.0
	return NetworkSession.hostile_avatars().has(t)

## Network id of a target player's avatar (0 for enemies / nothing).
func _peer_of(t) -> int:
	if is_instance_valid(t) and not (t is Enemy) and "peer_id" in t:
		return int(t.get("peer_id"))
	return 0

## Hits an enemy, or asks the host to hit another player with an ability.
func _hit_foe(t, amount: float, knock: Vector3) -> void:
	if not is_instance_valid(t):
		return
	if t is Enemy:
		_hit(t, amount, knock)
	elif _peer_of(t) != 0:
		NetworkSession.request_ability_hit(_peer_of(t), amount, knock)

## Damages an enemy only if it is still alive (stops double kills in one frame). Gives mastery XP.
func _hit(e: Enemy, amount: float, knock: Vector3) -> void:
	if is_instance_valid(e) and e.health > 0.0:
		e.take_damage(amount, knock)
		if amount >= 8.0:   # not for tiny damage-over-time ticks
			VfxKit.hit(get_parent(), e.global_position + Vector3.UP * 1.1 * e.k, null, 0.8)
		if cur_mkey != "":
			GameData.add_mastery(cur_mkey, GameData.MASTERY_HIT)

## Fires `count` homing projectiles, spread over the nearest enemies.
func _homing(count: int, dmg: float, aoe: float, color: Color, size: float) -> void:
	var targets := _foes_in(40.0)
	targets.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	var origin := global_position + Vector3.UP * 1.6
	for i in count:
		var ang := TAU * float(i) / float(count)
		var pr := Projectile.new()
		pr.position = origin + Vector3(cos(ang), 0.3, sin(ang)) * 0.8
		pr.speed = 18.0
		pr.velocity = (Vector3(cos(ang), 0.6, sin(ang)).normalized() + facing).normalized() * pr.speed
		pr.damage = dmg * _dmg()
		pr.aoe = aoe
		pr.size = size
		pr.color = color
		pr.life = 4.0
		pr.source_player = self
		if not targets.is_empty():
			pr.target = targets[i % targets.size()]
		get_parent().add_child(pr)
		pr.global_position = origin + Vector3(cos(ang), 0.3, sin(ang)) * 0.8
		if NetworkSession.is_active():
			NetworkSession.broadcast_projectile(pr.global_position, pr.velocity, pr.speed, pr.size, pr.color, pr.long_shape, pr.aoe, pr.damage, "", _peer_of(pr.target))

## ---- Fire Style jutsu + Kurama Mode (keys: T Y G H, V, RMB+E, Z) ----
func _toast(t: String) -> void:
	var h = get_parent().get("hud")
	if h != null:
		h.toast(t)

## MD gained from kills etc. (also while a mode is on, so kills keep it going).
func add_mode(amount: float) -> void:
	mode_meter = minf(GameData.md_max(), mode_meter + amount * _md_mult())

## MD lost per second right now: Kurama Mode, the bloodline power-up, or both (faster).
func md_drain() -> float:
	var d := 0.0
	if kurama:
		d += MODE_MAX / MODE_TIME
	if powered:
		d += MODE_MAX / POWER_DRAIN_TIME
	if kurama and powered:
		d *= BOTH_DRAIN_MULT
	return d

func _element_color() -> Color:
	return GameData.get_element_color()

func _reset_aura() -> void:
	if powered and not Bloodline.eye_mode(pmode):
		aura.visible = true
		aura.light_color = pmode["col"]
		aura.light_energy = 1.8
		return
	if kurama:
		aura.visible = true
		aura.light_color = Color(1.0, 0.5, 0.08)
		aura.light_energy = 2.0
		return
	var def := Bloodline.get_def(GameData.equipped)
	aura.visible = false   # no idle glow - the aura only lights up for forms, buffs and jutsu
	aura.light_color = def["color"]
	aura.light_energy = 1.2

## Fires `count` projectiles in a fan around the aim direction.
func _fan(count: int, spread: float, speed: float, dmg: float, aoe: float, size: float, color: Color, long: bool, visual_kind: String = "") -> void:
	var origin := global_position + Vector3.UP * 1.3 + facing * 1.25
	var dir := _aim_dir(origin)
	for i in count:
		var ang := deg_to_rad((float(i) - float(count - 1) / 2.0) * spread)
		var d := dir.rotated(Vector3.UP, ang)
		var pr := Projectile.new()
		pr.position = origin
		pr.speed = speed
		pr.velocity = d * speed
		pr.damage = dmg * _dmg()
		pr.aoe = aoe
		pr.size = size
		pr.color = color
		pr.long_shape = long
		pr.source_player = self
		pr.visual_kind = visual_kind
		get_parent().add_child(pr)
		pr.global_position = origin
		if NetworkSession.is_active():
			NetworkSession.broadcast_projectile(origin, d * speed, speed, size, color, long, aoe, dmg * _dmg(), visual_kind)

func _fx_phoenix(col: Color) -> void:
	Sfx.play(self, "fire", -2.0)
	_fan(5, 14.0, 26.0, 18.0, 2.5, 0.35, col, false)
	if not _play_once("jutsu", 0.6):
		Fx.swing(arm)

func _fx_flame_wave(col: Color) -> void:
	Sfx.play(self, "power")
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var to := e.global_position - global_position
		to.y = 0.0
		if to.length() < 9.0 + e.k * 1.5:
			e.take_damage(40.0 * _dmg(), to.normalized() * 14.0)
	for av in NetworkSession.hostile_avatars():
		var to := (av.global_position - global_position) * Vector3(1, 0, 1)
		if to.length() < 10.0:
			_hit_foe(av, 40.0 * _dmg(), to.normalized() * 14.0)
	var element_col := col
	Vfx.burst(get_parent(), global_position + Vector3.UP, element_col, 60, 12.0, 0.5, 0.7, 0.0)
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(element_col.r, element_col.g, element_col.b, 0.7), 12.0)
	_play_once("jutsu", 0.6)

func _fx_dragon(col: Color) -> void:
	Sfx.play(self, "fire")
	_shoot(32.0, 90.0, 8.0, 1.1, col, false, true)
	if not _play_once("jutsu", 0.6):
		Fx.swing(arm)

func _fx_armor(_col: Color) -> void:   # coloured by your main element
	armor_time = 6.0
	Sfx.play(self, "power")
	var element_col := _element_color()
	aura.visible = true
	aura.light_color = element_col
	aura.light_energy = 3.0
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(element_col.r, element_col.g, element_col.b, 0.7), 3.0)
	_play_once("jutsu", 0.6)

func _kunai_volley() -> void: # RMB + E
	if volley_cd > 0.0 or chakra < 15.0:
		return
	volley_cd = 4.0
	chakra -= 15.0
	Sfx.play(self, "throw", -4.0)
	_fan(5, 9.0, 42.0, 9.0, 0.0, 0.15, Color(0.85, 0.85, 0.95), true)
	if not _play_once("throw", 0.2):
		Fx.swing(arm)

func _fx_sub(_col: Color) -> void:   # swap with a log; lands behind the nearest enemy (or backs off)
	var from := global_position
	var tgt := _nearest_enemy(25.0)
	var dest := from - facing * 6.0
	if tgt:
		var d := tgt.global_position - from
		d.y = 0.0
		if d.length() > 0.1:
			dest = tgt.global_position + d.normalized() * (2.5 * tgt.k + 1.0)
	var half := 240.0
	var ph = get_parent().get("play_half")
	if ph != null:
		half = float(ph)
	dest.x = clampf(dest.x, -half, half)
	dest.z = clampf(dest.z, -half, half)
	dest.y = from.y
	Sfx.play(self, "teleport")
	Fx.puff(get_parent(), from + Vector3.UP, Color(0.8, 0.75, 0.65, 0.9), 2.2)
	global_position = dest
	velocity = Vector3.ZERO
	invuln = maxf(invuln, 0.6)
	if tgt:
		var f := tgt.global_position - dest
		f.y = 0.0
		if f.length() > 0.1:
			facing = f.normalized()
	Fx.puff(get_parent(), dest + Vector3.UP, Color(0.9, 0.9, 0.9, 0.8), 2.0)

## Z - Kurama Mode on / off. Needs Kurama defeated and KURAMA_MIN_MD to start; no timer, it drains MD.
## Works together with the bloodline power-up (C); with both on, MD drains faster.
func _kurama_mode() -> void:
	if is_dead:
		return
	if kurama:
		_end_mode()
		_toast("Kurama Mode released")
		return
	if not GameData.kurama_defeated:
		_toast("Defeat Kurama in the Kurama Boss Fight to unlock Kurama Mode")
		return
	if mode_meter < KURAMA_MIN_MD:
		_toast("Not enough MD for Kurama Mode  (%d / %d)" % [int(mode_meter), int(KURAMA_MIN_MD)])
		return
	kurama = true
	if NetworkSession.is_active():
		NetworkSession.broadcast_kurama_state(true)
	Sfx.play(self, "power")
	model.scale = Vector3.ONE * 1.3
	cloak_fx = Node3D.new()
	add_child(cloak_fx)
	Vfx.aura_flames(cloak_fx, Vector3(0, 1.0, 0), 0.65, Color(1.0, 0.5, 0.1), 26, true)
	VfxKit.chakra(self, 1.4, Color(1.0, 0.5, 0.1), 1.6)
	health = minf(max_health, health + max_health * 0.25)
	Vfx.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.55, 0.1), 36, 9.0, 0.22, 0.6, 0.0)
	Vfx.shake(cam, 0.25, 0.4)
	_toast("KURAMA MODE + %s!" % str(pmode["name"]).to_upper() if powered else "KURAMA MODE!")
	_play_once("jutsu", 0.6)

func _end_mode() -> void:
	if kurama and NetworkSession.is_active():
		NetworkSession.broadcast_kurama_state(false)
	kurama = false
	if model:
		model.scale = Vector3.ONE
	if cloak_fx != null and is_instance_valid(cloak_fx):
		cloak_fx.queue_free()
	cloak_fx = null
	if aura:
		_reset_aura()

## What the bottom HUD shows for each key slot.
func slot_info(key: String) -> Dictionary:
	var d := {"name": "", "cd": 0.0, "max": 1.0, "cost": 0.0, "locked": false, "active": false, "timer": 0.0,
		"not_ready": false, "icon": null, "empty": false}
	if Moves.BIND_KEYS.has(key):   # assignable key: shows the move bound to it
		var mv := str(GameData.keybinds.get(key, ""))
		var a := Moves.spec(mv)
		if a.is_empty():
			d["empty"] = true
			return d
		var left := 0.0
		for b in buffs:
			if b["name"] == a["name"]:
				left = float(b["t"])
		if mv == "base:armor" and armor_time > 0.0:
			left = armor_time
		var cost := float(a["cost"]) * (fire_cost / 30.0 if bool(a["fire_cost"]) else 1.0)
		d.merge({"name": a["name"], "cd": float(move_cd.get(mv, 0.0)), "max": float(a["cd"]), "cost": cost,
			"locked": Moves.block(mv) != "", "active": left > 0.0, "timer": left, "icon": Moves.icon(mv)}, true)
		return d
	match key:
		"Q":
			d.merge({"name": "Dash", "cost": dash_cost}, true)
		"RMB+E":
			d.merge({"name": "Kunai", "cd": volley_cd, "max": 4.0, "cost": 15.0}, true)
		"E":
			d["name"] = "Talk"
		"Z":
			d.merge({"name": "Kurama", "locked": not GameData.kurama_defeated, "active": kurama,
				"not_ready": mode_meter < KURAMA_MIN_MD and not kurama}, true)
		"C":   # power-up: no timer, drains MD
			var m := Bloodline.mode(GameData.equipped)
			if powered:
				d.merge({"name": pmode["name"], "active": true, "icon": Moves.mode_icon(GameData.equipped)}, true)
			elif not m.is_empty() and _bl_level() >= Bloodline.MODE_LEVEL:
				d.merge({"name": m["name"], "not_ready": mode_meter < POWER_MIN_MD,
					"icon": Moves.mode_icon(GameData.equipped)}, true)
			else:
				d["name"] = "Charge"
	return d

func take_damage(amount: float, knock: Vector3 = Vector3.ZERO, knockdown := false) -> void:
	if invuln > 0.0 or is_dead or god_mode or downed > 0.0:
		return
	if _immune():   # e.g. Hozuki Hydrification
		Fx.puff(get_parent(), global_position + Vector3.UP, Color(0.4, 0.75, 0.95, 0.7), 1.2)
		return
	if armor_time > 0.0:
		amount *= 0.4
	if kurama:
		amount *= 0.5
	amount *= _bmul("def")
	health -= amount
	invuln = 0.4
	velocity.x += knock.x
	velocity.z += knock.z
	Fx.puff(get_parent(), global_position + Vector3.UP * 1.2, Color(1, 0.2, 0.2, 0.8), 1.0)
	Vfx.shake(cam, clampf(amount / 120.0, 0.05, 0.3), 0.3)
	if health <= 0.0:
		health = 0.0
		_susanoo_off()
		if wall_walking:
			_end_wall_walk(Vector3.ZERO)
		is_dead = true
		lock_target = null
		_clear_buffs()
		_power_off()
		_end_mode()
		armor_time = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Sfx.play(self, "death")
		Sfx.play(self, "thud", -2.0)
		body_col.set_deferred("disabled", true)
		ragdoll = Ragdoll.start(model, get_parent(), Vector3(velocity.x, 0, velocity.z) * 0.5 + knock * 0.8 + Vector3.UP * 3.0)
		if ragdoll == null and Hero.play(model, "die", true) <= 0.0:
			create_tween().tween_property(model, "rotation:x", -PI / 2.0, 0.4)
	else:
		Sfx.play(self, "hurt", -3.0)
		if knockdown:
			_knockdown(knock)
		_play_once("hurt", 0.3)
