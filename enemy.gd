class_name Enemy
extends CharacterBody3D

var health := 60.0
var max_health := 60.0
var speed := 4.5
var damage := 8.0
var is_boss := false
var aggro_range := 0.0   # 0 = always hunts the player; >0 = idles until the player is this close
var aggroed := false
var display_name := ""                       # shown above the health bar (quest targets)
var body_color := Color(0.25, 0.25, 0.32)
var band_color := Color(0.6, 0.6, 0.65)
var network_quest_id := ""
var network_quest_party_leader := 0
var network_quest_mirror := false
var last_hit_peer := 1   # host: peer that dealt the latest hit (gets the kill in the PvP arena)
var network_quest_defeated := false
var character_appearance: Dictionary = {}
var _quest_net_position := Vector3.ZERO
var _quest_net_yaw := 0.0
var _quest_net_health := -1.0

var atk_cd := 1.0
var windup := 0.0
var stun := 0.0
var model: Node3D
# --- random bloodline (non-boss NPCs): passive stats + one ability cast every few seconds
const NPC_DMG := 0.4          # NPC ability damage = the bloodline's listed damage x this
var bloodline_id := "none"
var dmg_mult := 1.0
var bl_cd := 5.0
var bl_pending: Dictionary = {}
var bl_buff_t := 0.0
var bl_speed := 1.0
var bl_dmg := 1.0
var bl_def := 1.0
var bl_dash_t := 0.0
var bl_dash_dir := Vector3.ZERO
var bl_dash_hit := false
var bl_dash_dmg := 0.0
var uses_hero := false   # true = random-outfit Hero model instead of the placeholder ninja
var arm: Node3D
var label: Label3D
var k := 1.0
var bob_t := 0.0
static var time_scale := 1.0  # <1 slows all enemies (Sharingan)

func _ready() -> void:
	_setup()
	if network_quest_mirror:
		_quest_net_position = global_position
		_quest_net_yaw = model.rotation.y if model != null else 0.0
		if NetworkSession.is_active():
			NetworkSession.apply_pending_quest_enemy_identity(self)

func _setup() -> void:
	add_to_group("enemies")
	max_health = health
	if not is_boss:
		# A quest mirror waits for the host's identity instead of rolling a local clan.
		if network_quest_mirror:
			bloodline_id = "none"
		else:
			_apply_bloodline(Bloodline.roll(false))
	k = 1.6 if is_boss else 1.0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * k
	cap.height = 1.9 * k
	col.shape = cap
	col.position.y = 0.95 * k
	add_child(col)
	if not is_boss:
		var hero_model := Hero.create(Hero.DEFAULT_APPEARANCE)
		if hero_model != null:
			if network_quest_mirror:
				character_appearance = Hero.sanitize_appearance(Hero.DEFAULT_APPEARANCE)
			else:
				character_appearance = Hero.randomize_look(hero_model)
			model = hero_model
			uses_hero = true
	if model == null:
		model = Fx.make_ninja(Color(0.5, 0.1, 0.1) if is_boss else body_color, Color(0.6, 0.6, 0.65) if is_boss else band_color, Color(1.0, 0.15, 0.08))
	model.scale = Vector3.ONE * k
	add_child(model)
	if uses_hero:
		arm = Node3D.new()   # stand-in so the old arm-swing tweens keep working; the clip does the real animation
		model.add_child(arm)
	else:
		arm = model.get_node("Arm")
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.pixel_size = 0.005
	label.position.y = 2.5 * k
	add_child(label)
	_update_label()

func _update_label() -> void:
	# Some special enemies (including Kurama) create their own model/setup.
	# Their label may not exist yet when the first multiplayer snapshot arrives.
	if not is_instance_valid(label):
		return
	var safe_max_health := maxf(max_health, 1.0)
	var n := int(ceil(clampf(health / safe_max_health, 0.0, 1.0) * 10.0))
	label.text = "█".repeat(n) + "░".repeat(10 - n)
	if display_name != "":
		label.text = display_name + "\n" + label.text
	label.modulate = Color(1, 0.3, 0.3) if is_boss else Color(1, 0.9, 0.9)
	if bloodline_id != "none" and not is_boss:
		var def := Bloodline.get_def(bloodline_id)
		label.text = str(def["name"]) + "\n" + label.text
		label.modulate = (def["color"] as Color).lerp(Color.WHITE, 0.35)

func _physics_process(delta: float) -> void:
	if network_quest_mirror:
		var old_position := global_position
		var blend := 1.0 - exp(-14.0 * delta)
		global_position = global_position.lerp(_quest_net_position, blend)
		if delta > 0.0:
			velocity = (global_position - old_position) / delta
		if model != null:
			model.rotation.y = lerp_angle(model.rotation.y, _quest_net_yaw, blend)
		if _quest_net_health >= 0.0 and absf(health - _quest_net_health) > 0.01:
			health = _quest_net_health
			_update_label()
		_animate_body(delta)
		return
	_ai(delta)
	_animate_body(delta)

func apply_quest_network_state(pos: Vector3, yaw: float, hp: float) -> void:
	_quest_net_position = pos
	_quest_net_yaw = yaw
	_quest_net_health = hp


## Applies the host-selected clan and full randomized outfit to a local quest-enemy mirror.
func apply_quest_network_identity(id: String, appearance: Dictionary, synced_max_health: float) -> void:
	bloodline_id = id if Bloodline.DEFS.has(id) else "none"
	character_appearance = Hero.sanitize_appearance(appearance)
	if synced_max_health > 0.0:
		max_health = synced_max_health
	if uses_hero and model != null:
		Hero.apply_appearance(model, character_appearance)
	_update_label()


## Procedural run bob + forward lean for the placeholder ninjas (skipped for models with real animations).
func _animate_body(delta: float) -> void:
	if is_boss or model == null:
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	if uses_hero:
		if windup <= 0.0:
			Hero.play(model, "run" if sp > 0.6 else "idle")
		return
	if sp > 0.6:
		bob_t += delta * (6.0 + sp * 1.4)
		model.position.y = absf(sin(bob_t)) * 0.12
		model.rotation.x = lerpf(model.rotation.x, -0.16, 8.0 * delta)
	else:
		model.position.y = lerpf(model.position.y, 0.0, 10.0 * delta)
		model.rotation.x = lerpf(model.rotation.x, 0.0, 8.0 * delta)

func _ai(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	var ts := time_scale
	atk_cd -= delta * ts
	stun -= delta * ts
	var p := get_tree().get_first_node_in_group("player") as Player
	var target_peer_id := 1
	var target_pos := p.global_position if p != null and not p.is_dead else Vector3.INF
	if network_quest_id != "" and NetworkSession.is_active() and multiplayer.is_server():
		# The host AI can choose any living party avatar (any player for PvP arena ninjas), not only the host.
		target_pos = Vector3.INF
		var nearest := INF
		if p != null and not p.is_dead and NetworkSession.enemy_targets(1, network_quest_party_leader):
			nearest = global_position.distance_to(p.global_position)
			target_pos = p.global_position
			target_peer_id = 1
		for id in NetworkSession._avatars:
			var avatar = NetworkSession._avatars[id]
			if not is_instance_valid(avatar) or not NetworkSession.enemy_targets(int(id), network_quest_party_leader):
				continue
			var candidate_pos: Vector3 = avatar.global_position
			var candidate_dist := global_position.distance_to(candidate_pos)
			if candidate_dist < nearest:
				nearest = candidate_dist
				target_pos = candidate_pos
				target_peer_id = int(id)
	var has_target := target_pos != Vector3.INF
	if not has_target:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		move_and_slide()
		return
	var to := target_pos - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized()
	if aggro_range > 0.0 and not aggroed:
		if dist <= aggro_range:
			aggroed = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			move_and_slide()
			return
	if stun > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
	elif windup > 0.0:
		windup -= delta * ts
		velocity.x = 0.0
		velocity.z = 0.0
		if windup <= 0.0:
			_strike(p, dir, dist, target_peer_id, target_pos)
	else:
		bl_cd -= delta * ts
		bl_buff_t -= delta
		var spd := speed * ts * (bl_speed if bl_buff_t > 0.0 else 1.0)
		if bl_dash_t > 0.0:
			bl_dash_t -= delta
			velocity.x = bl_dash_dir.x * 26.0
			velocity.z = bl_dash_dir.z * 26.0
			if dist < 1.8 and p != null and not bl_dash_hit:
				bl_dash_hit = true
				p.take_damage(bl_dash_dmg, bl_dash_dir * 10.0)
		elif bl_cd <= 0.0 and bloodline_id != "none" and p != null and target_peer_id == 1 and dist < 14.0 and dist > 3.0:
			_bl_begin()
		elif dist > 2.0 * k:
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if atk_cd <= 0.0:
				windup = 0.55
				atk_cd = 1.4
				if uses_hero:
					Hero.play(model, "attack", true, 0, 0.9)
				var t := arm.create_tween()
				t.tween_property(arm, "rotation:x", -2.5, 0.35)
	if dist > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
	move_and_slide()

func _strike(p: Player, dir: Vector3, _dist: float, target_peer_id: int, target_pos: Vector3) -> void:
	if not bl_pending.is_empty():
		var ability := bl_pending
		bl_pending = {}
		_bl_release(ability, p, dir, _dist)
		return
	Fx.swing(arm)
	var to := target_pos - global_position
	to.y = 0.0
	if to.length() < 2.8 * k:
		var hit_damage := damage * (1.5 if is_boss else 1.0) * _bl_dmg_mult()
		var knockback := dir * 7.0
		if target_peer_id == 1 and p != null:
			p.take_damage(hit_damage, knockback)
		elif network_quest_id != "" and NetworkSession.is_active() and multiplayer.is_server():
			NetworkSession.damage_quest_party_member(target_peer_id, network_quest_party_leader, hit_damage, knockback)

## Hero-model enemies fall as a ragdoll instead of vanishing: the model is moved out of this
## node (which is freed) and cleaned up together with the ragdoll after CORPSE_TIME seconds.
const CORPSE_TIME := 8.0
## network_driven = true: a co-op client's copy; its bodies follow the host instead of simulating.
func _remove_with_ragdoll(knock: Vector3, network_driven := false) -> void:
	var world := get_parent()
	if uses_hero and is_instance_valid(model) and world != null and is_inside_tree():
		model.reparent(world, true)
		var vel := Vector3(velocity.x, 0.0, velocity.z) * 0.5 + knock * 0.8 + Vector3.UP * 3.0
		var body := Ragdoll.start(model, world, vel)
		var corpse := model
		if body != null and network_quest_id != "" and NetworkSession.is_active():
			if network_driven:
				body.set_network_driven(true)
				RagdollSync.follow_enemy_ragdoll(network_quest_id, body)
			elif multiplayer.is_server():
				RagdollSync.stream_enemy_ragdoll(network_quest_id, body)
		if body == null:
			corpse.queue_free()
		else:
			get_tree().create_timer(CORPSE_TIME).timeout.connect(func():
				if is_instance_valid(corpse):
					corpse.queue_free()
				if is_instance_valid(body):
					body.queue_free())
	queue_free()


# ---------------------------------------------------------------- bloodline
func _apply_bloodline(id: String) -> void:
	bloodline_id = id
	var st: Dictionary = Bloodline.get_def(id)["stats"]
	health += float(st.get("hp", 0.0))
	max_health = health
	speed *= float(st.get("speed", 1.0))
	dmg_mult = float(st.get("dmg", 1.0))
	bl_cd = randf_range(3.0, 7.0)


func _bl_dmg_mult() -> float:
	return dmg_mult * (bl_dmg if bl_buff_t > 0.0 else 1.0)


## Starts a random ability of this NPC's bloodline: a short telegraph, then _strike() releases it.
func _bl_begin() -> void:
	var count: int = (Bloodline.get_def(bloodline_id)["abilities"] as Array).size()
	bl_cd = randf_range(7.0, 12.0)
	if count == 0:
		return
	bl_pending = Bloodline.ability(bloodline_id, randi() % count)
	windup = 0.6
	velocity.x = 0.0
	velocity.z = 0.0
	Fx.puff(get_parent(), global_position + Vector3.UP * 0.3, bl_pending["col"] as Color, 2.0 * k)
	if uses_hero:
		Hero.play(model, "jutsu", true, 0, 0.8)


func _bl_release(a: Dictionary, p: Player, dir: Vector3, dist: float) -> void:
	var col: Color = a["col"]
	var kind := str(a["kind"])
	var is_buff := kind == "buff" or kind == "aura"
	var dmg := 0.0 if is_buff else float(a["dmg"]) * NPC_DMG * _bl_dmg_mult()
	Fx.puff(get_parent(), global_position + Vector3.UP, col, 2.5 * k)
	match kind:
		"burst", "cone", "target":
			Vfx.burst(get_parent(), global_position + Vector3.UP, col, 30, 7.0, 0.3, 0.7)
			if p != null and dist <= float(a["r"]) and dmg > 0.0:
				p.take_damage(dmg, dir * float(a["knock"]))
		"dash":
			bl_dash_t = 0.25
			bl_dash_dir = dir
			bl_dash_hit = false
			bl_dash_dmg = dmg
		"fan", "homing":
			var count := mini(int(a["n"]), 5)
			var gap := deg_to_rad(float(a["spread"]))
			for i in count:
				var bolt := NpcBolt.new()
				bolt.damage = dmg
				bolt.color = col
				bolt.size = float(a["size"])
				bolt.homing = kind == "homing"
				bolt.velocity = dir.rotated(Vector3.UP, (i - (count - 1) * 0.5) * gap) * minf(float(a["speed"]), 22.0)
				get_parent().add_child(bolt)
				bolt.global_position = global_position + Vector3.UP * 1.2 + dir * 0.8
		_:
			bl_buff_t = maxf(float(a["t"]), 4.0)
			var sp := float(a["speed"])
			bl_speed = clampf(sp if sp < 5.0 else 1.0, 1.0, 1.5)
			var dm := float(a["dmg"])
			bl_dmg = clampf(dm if dm > 0.0 and dm < 3.0 else 1.0, 1.0, 1.5)
			bl_def = clampf(float(a["def"]), 0.5, 1.0)
	if float(a["heal"]) > 0.0:
		health = minf(max_health, health + float(a["heal"]) * 0.5)
		_update_label()


func take_damage(amount: float, knock: Vector3 = Vector3.ZERO) -> void:
	if network_quest_defeated or health <= 0.0:
		return
	if network_quest_mirror and network_quest_id != "":
		NetworkSession.request_quest_enemy_damage(network_quest_id, amount, knock)
		return
	if bl_buff_t > 0.0:
		amount *= bl_def
	health -= amount
	aggroed = true
	Sfx.play(self, "hit", -5.0)
	velocity.x += knock.x
	velocity.z += knock.z
	if not is_boss:
		stun = maxf(stun, 0.25)
		windup = 0.0
	Fx.puff(get_parent(), global_position + Vector3.UP * 1.2, Color(1, 1, 0.7, 0.9), 0.7)
	Vfx.damage_number(get_parent(), global_position + Vector3.UP * (2.2 * k), amount)
	_update_label()
	if health <= 0.0:
		network_quest_defeated = true
		if network_quest_id != "" and NetworkSession.is_active() and multiplayer.is_server():
			if network_quest_party_leader == NetworkSession.ARENA_ENEMY:
				NetworkSession.arena_enemy_killed(network_quest_id, last_hit_peer)
			else:
				NetworkSession.quest_enemy_killed(network_quest_id, network_quest_party_leader)
		else:
			var p := get_tree().get_first_node_in_group("player") as Player
			if p:
				p.kills += 1
				p.on_kill(is_boss)
				p.add_mode(10.0)
				p.chakra = minf(p.max_chakra, p.chakra + 10.0)
				if is_boss:
					p.health = minf(p.max_health, p.health + 30.0)
		_death_fx()
		remove_from_group("enemies")
		_remove_with_ragdoll(knock)

func _death_fx() -> void:
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(1, 0.85, 0.6, 0.9), 2.5 * k)
	Vfx.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.5, 0.15), 40, 9.0, 0.3, 0.9)
	Sfx.play(self, "poof", -2.0)

## Co-op client: the host killed this mirrored quest enemy. Play the same death and fall as a
## ragdoll that follows the host's body snapshots (RagdollSync), instead of just vanishing.
func die_from_network() -> void:
	if health <= 0.0 and network_quest_defeated and not is_in_group("enemies"):
		return
	health = 0.0
	network_quest_defeated = true
	_update_label()
	_death_fx()
	remove_from_group("enemies")
	remove_from_group("quest_enemies")
	_remove_with_ragdoll(Vector3.ZERO, true)
