class_name Player
extends CharacterBody3D

const WALK_SPEED := 7.0
const SPRINT_SPEED := 12.5
const JUMP_VELOCITY := 9.5
const GRAVITY := 26.0
const DASH_SPEED := 30.0

var health := 100.0
var max_health := 100.0
var chakra := 100.0
var max_chakra := 100.0
var kills := 0
var is_dead := false
const MODE_MAX := 100.0
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
var kunai_cd := 0.0
var fire_cd := 0.0
var clone_cd := 0.0
var invuln := 0.0
var lock_target: Enemy = null

var pivot: Node3D
var spring: SpringArm3D
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
	pivot.position.y = 1.6
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 6.0
	spring.margin = 0.3
	pivot.add_child(spring)
	spring.add_excluded_object(get_rid())
	cam = Camera3D.new()
	cam.fov = 70.0
	spring.add_child(cam)
	cam.make_current()
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
	refresh_stats()
	_clear_buffs()
	_power_off()
	aura.visible = GameData.equipped != "none"
	aura.light_color = def["color"]
	aura.light_energy = 1.2

func _dmg() -> float:
	var m := dmg_mult
	if kurama:
		m *= 2.0
	m *= _bmul("dmg")
	return m

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0028 * sens_mult
		pitch = clampf(pitch - event.relative.y * 0.0028 * sens_mult, -1.2, 0.6)
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("lockon"):
		lock_target = null if lock_target else _nearest_enemy(30.0)

func _process(delta: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	# FOV kick: wider when sprinting, widest when dashing
	var target_fov := fov_base
	if dash_time > 0.0:
		target_fov = fov_base + 20.0
	elif not is_dead and Input.is_action_pressed("sprint") and Vector2(velocity.x, velocity.z).length() > WALK_SPEED * 1.2:
		target_fov = fov_base + 8.0
	cam.fov = lerpf(cam.fov, target_fov, 8.0 * delta)

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
	elif mode_meter < MODE_MAX:
		mode_meter = minf(MODE_MAX, mode_meter + 1.0 * delta * _md_mult())
	invuln = maxf(0.0, invuln - delta)
	_update_buffs(delta)
	var hpr := hp_regen + _badd("hp") + (6.0 if kurama else 0.0)
	if hpr > 0.0:
		health = minf(max_health, health + hpr * delta)

	# Lock-on camera
	if not is_instance_valid(lock_target):
		lock_target = null
	elif global_position.distance_to(lock_target.global_position) > 45.0:
		lock_target = null
	if lock_target:
		var d := lock_target.global_position - global_position
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), 6.0 * delta)
		pitch = lerpf(pitch, -0.3, 3.0 * delta)

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

	# Abilities
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
	# C: tap = bloodline power-up on / off (needs bloodline LV 1000, drains MD), hold = charge chakra
	if Input.is_action_pressed("charge"):
		c_hold += delta
	else:
		if c_hold > 0.0 and c_hold < 0.25:
			_toggle_power()
		c_hold = 0.0

	move_and_slide()
	dust_t -= delta
	if dust_t <= 0.0 and is_on_floor() and Vector2(velocity.x, velocity.z).length() > SPRINT_SPEED * 0.55 * speed_mult:
		dust_t = 0.11
		Vfx.dust(get_parent(), global_position)
	_update_anim()

func _update_anim() -> void:
	if anim_lock > 0.0:
		return
	var st := "idle"
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if not is_on_floor():
		st = "jump" if velocity.y > 0.5 else "fall"
	elif dash_time > 0.0:
		st = "dash"
	elif hv.length() > 1.0:
		st = "run"
		if lock_target:
			var fwd := hv.dot(facing)
			var side := hv.dot(facing.cross(Vector3.UP))
			if absf(side) > absf(fwd) * 0.8:
				st = "strafe_r" if side > 0.0 else "strafe_l"
	Hero.play(model, st)

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
	var tgt: Enemy = lock_target if lock_target else _nearest_enemy(6.0)
	if tgt:
		var f := tgt.global_position - global_position
		f.y = 0.0
		if f.length() > 0.01:
			facing = f.normalized()
			model.rotation.y = atan2(-facing.x, -facing.z)
	velocity.x = facing.x * 10.0
	velocity.z = facing.z * 10.0
	Sfx.play(self, "swing", -4.0)
	var dmg := (10.0 + combo * 4.0) * _dmg()
	var knock := 14.0 if combo == 3 else 4.0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var to := e.global_position - global_position
		to.y = 0.0
		var reach := 3.2 * e.k
		if to.length() < reach and (to.length() < 0.8 or facing.dot(to.normalized()) > 0.3):
			e.take_damage(dmg, facing * knock)
	if NetworkSession.is_active() and NetworkSession.session_mode == "pvp":
		NetworkSession.try_hit_players(dmg, facing * knock)
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

func _shoot(speed: float, dmg: float, aoe: float, size: float, color: Color, long: bool, homing: bool) -> void:
	var origin := global_position + Vector3.UP * 1.3 + facing * 0.6
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
	if homing and lock_target:
		pr.target = lock_target
	get_parent().add_child(pr)
	if NetworkSession.is_active():
		NetworkSession.broadcast_projectile(origin, dir * speed, speed, size, color, long, aoe)

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
	_shoot(22.0, 45.0, 5.0, 0.6, col, false, false)
	if not _play_once("jutsu", 0.6):
		Fx.swing(arm)

func _fx_clones(_col: Color) -> void:
	Sfx.play(self, "poof")
	var side := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	for i in clone_count:
		var offs := (i - (clone_count - 1) / 2.0) * 2.5
		var c := Clone.new()
		c.life = clone_time
		c.position = global_position + side * offs
		get_parent().add_child(c)
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
	var target: Enemy = null
	if kind == "target":
		target = lock_target if is_instance_valid(lock_target) and lock_target.health > 0.0 \
			and lock_target.global_position.distance_to(global_position) <= float(a["r"]) else _nearest_enemy(float(a["r"]))
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
			for e in _enemies_in(float(a["r"])):
				var to := (e.global_position - global_position) * Vector3(1, 0, 1)
				_stun(e, float(a["stun"]))
				_hit(e, dmg, to.normalized() * float(a["knock"]))
			Vfx.shockwave(get_parent(), global_position + Vector3.UP * 0.2, col, float(a["r"]), 0.45)
		"cone":
			for e in _enemies_in(float(a["r"])):
				var to := (e.global_position - global_position) * Vector3(1, 0, 1)
				if to.normalized().dot(facing) > float(a["dot"]):
					_stun(e, float(a["stun"]))
					_hit(e, dmg, to.normalized() * float(a["knock"]))
			Vfx.shockwave(get_parent(), global_position + facing * float(a["r"]) * 0.4 + Vector3.UP * 0.2, col, float(a["r"]) * 0.6, 0.35)
		"target":
			_stun(target, float(a["stun"]))
			Vfx.shockwave(get_parent(), target.global_position + Vector3.UP, col, 3.0, 0.4)
			Fx.puff(get_parent(), target.global_position + Vector3.UP, Color(col.r, col.g, col.b, 0.85), 2.0)
			_hit(target, dmg, Vector3.ZERO)
		"fan":
			_fan(int(a["n"]), float(a["spread"]), float(a["speed"]), float(a["dmg"]) * mult,
				float(a["aoe"]), float(a["size"]), col, bool(a["long"]))
		"homing":
			_homing(int(a["n"]), float(a["dmg"]) * mult, float(a["aoe"]), col, float(a["size"]))
		"dash":
			var dir := facing
			if is_instance_valid(lock_target):
				var d := (lock_target.global_position - global_position) * Vector3(1, 0, 1)
				if d.length() > 0.1:
					dir = d.normalized()
			var reach := float(a["dist"])
			for e in _enemies_in(reach + 1.0):
				var to := (e.global_position - global_position) * Vector3(1, 0, 1)
				var along := to.dot(dir)
				if along > -0.5 and along < reach + 1.0 and (to - dir * along).length() < 2.5:
					_hit(e, dmg, dir * 12.0)
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

func _stun(e: Enemy, secs: float) -> void:
	if secs <= 0.0 or not is_instance_valid(e):
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

func _aura_tick(radius: float, dps: float, col: Color) -> void:
	for e in _enemies_in(radius):
		_hit(e, dps * 0.5 * _dmg() * (_bl_mult() if not cur_mkey.begins_with("el:") else 1.0), Vector3.ZERO)
		Fx.puff(get_parent(), e.global_position + Vector3.UP * 1.2, Color(col.r, col.g, col.b, 0.8), 0.9)
	Vfx.burst(get_parent(), global_position + Vector3.UP, col, 16, 5.0, 0.15, 0.5, 0.0)

func _clear_buffs() -> void:
	buffs.clear()
	Enemy.time_scale = 1.0

## C (tap) / X: turn the bloodline power-up on or off.
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
	powered = true
	pmode = m
	mode_tick = 0.0
	var col: Color = m["col"]
	pmode_fx = Node3D.new()
	add_child(pmode_fx)
	Vfx.aura_flames(pmode_fx, Vector3(0, 1.0, 0), 0.6, col, 24, true)
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
	if not powered:
		return
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
		_toast("POWER-UP UNLOCKED: %s  - tap C!" % Bloodline.mode(id)["name"])
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

## Damages an enemy only if it is still alive (stops double kills in one frame). Gives mastery XP.
func _hit(e: Enemy, amount: float, knock: Vector3) -> void:
	if is_instance_valid(e) and e.health > 0.0:
		e.take_damage(amount, knock)
		if cur_mkey != "":
			GameData.add_mastery(cur_mkey, GameData.MASTERY_HIT)

## Fires `count` homing projectiles, spread over the nearest enemies.
func _homing(count: int, dmg: float, aoe: float, color: Color, size: float) -> void:
	var targets := _enemies_in(40.0)
	targets.sort_custom(func(a: Enemy, b: Enemy): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
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
		if not targets.is_empty():
			pr.target = targets[i % targets.size()]
		get_parent().add_child(pr)
		if NetworkSession.is_active():
			NetworkSession.broadcast_projectile(pr.global_position, pr.velocity, pr.speed, pr.size, pr.color, pr.long_shape, pr.aoe)

## ---- Fire Style jutsu + Kurama Mode (keys: T Y G H, V, RMB+E, Z) ----
func _toast(t: String) -> void:
	var h = get_parent().get("hud")
	if h != null:
		h.toast(t)

## MD gained from kills etc. (also while a mode is on, so kills keep it going).
func add_mode(amount: float) -> void:
	mode_meter = minf(MODE_MAX, mode_meter + amount * _md_mult())

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
	if powered:
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
	aura.visible = GameData.equipped != "none"
	aura.light_color = def["color"]
	aura.light_energy = 1.2

## Fires `count` projectiles in a fan around the aim direction.
func _fan(count: int, spread: float, speed: float, dmg: float, aoe: float, size: float, color: Color, long: bool) -> void:
	var origin := global_position + Vector3.UP * 1.3 + facing * 0.6
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
		get_parent().add_child(pr)
		if NetworkSession.is_active():
			NetworkSession.broadcast_projectile(origin, d * speed, speed, size, color, long, aoe)

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
	Sfx.play(self, "poof")
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
	Sfx.play(self, "power")
	model.scale = Vector3.ONE * 1.3
	cloak_fx = Node3D.new()
	add_child(cloak_fx)
	Vfx.aura_flames(cloak_fx, Vector3(0, 1.0, 0), 0.65, Color(1.0, 0.5, 0.1), 26, true)
	health = minf(max_health, health + max_health * 0.25)
	Vfx.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.55, 0.1), 36, 9.0, 0.22, 0.6, 0.0)
	Vfx.shake(cam, 0.25, 0.4)
	_toast("KURAMA MODE + %s!" % str(pmode["name"]).to_upper() if powered else "KURAMA MODE!")
	_play_once("jutsu", 0.6)

func _end_mode() -> void:
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

func take_damage(amount: float, knock: Vector3 = Vector3.ZERO) -> void:
	if invuln > 0.0 or is_dead or god_mode:
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
		_play_once("hurt", 0.3)
