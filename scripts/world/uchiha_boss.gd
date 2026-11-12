class_name UchihaBoss
extends Enemy
## Boss: a rogue Uchiha in an Akatsuki cloak with the Sharingan.
##   Phase 1 (100-66%): taijutsu combos (3rd hit knocks you down), Fire Style fireballs, body
##                      flicker behind you.
##   Phase 2 (66-33%):  forms the Susanoo (Aura 3D) - telegraphed giant punches and a slam that
##                      knocks you down; takes 35% less damage while it's out.
##   Phase 3 (<33%):    enraged - faster, fireball fans, dark aura.
## Single player (the co-op raid is Kurama's).

signal defeated
signal phase_changed(phase: int)

const BOSS_TITLE := "AKATSUKI UCHIHA  -  Rogue of the Leaf"
const MAX_HP := 3000.0
const LOOK := {"hair_style": "hair2", "hair_color": "#15151A", "shirt_style": "shirt3", "pants_style": "pants1",
	"skin_color": "#F4CDAE", "headband_color": "#2B3A67", "shirt_color": "#FFFFFF", "pants_color": "#FFFFFF"}
const SUSANOO_COLOR := Color(0.55, 0.25, 1.0)
const ENRAGE_COLOR := Color(0.75, 0.05, 0.08)

const COMBO_DMG := [9.0, 10.0, 14.0]
const COMBO_AT := [0.25, 0.72, 1.19]  # seconds into the combo each hit lands (> the 0.4 s hit immunity apart)
const COMBO_RANGE := 2.7
const FIRE_DMG := 18.0
const PUNCH_DMG := 24.0
const PUNCH_AHEAD := 6.0
const PUNCH_R := 4.2
const SLAM_DMG := 30.0
const SLAM_R := 7.0

enum S { INTRO, FIGHT, ATTACK, FORMING, DEAD }
var boss_title := BOSS_TITLE
var st := S.INTRO
var phase := 1
var cd := 1.5
var atk := ""
var atk_t := 0.0
var atk_len := 0.0
var _hits_done := 0
var _aim := Vector3.ZERO     # where a telegraphed attack lands
var _intro := 0.0
var susanoo: Susanoo
var _rage: AuraShell
var _fwd := Vector3.FORWARD

func _setup() -> void:
	add_to_group("enemies")
	is_boss = true
	health = MAX_HP
	max_health = MAX_HP
	speed = 5.2
	k = 1.0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.9
	col.shape = cap
	col.position.y = 0.95
	add_child(col)
	model = Hero.create(LOOK)
	uses_hero = true
	add_child(model)
	var look := Hero.DEFAULT_APPEARANCE.duplicate()
	look.merge(LOOK, true)
	character_appearance = look
	Hero.apply_appearance(model, look)   # Akatsuki cloak, black hair
	Hero.apply_mode_look(model, Bloodline.mode("uchiha").get("look", {}), look)   # Sharingan (keeps his look)
	arm = Node3D.new()
	model.add_child(arm)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.pixel_size = 0.005
	label.position.y = 2.5
	add_child(label)
	display_name = "Akatsuki Uchiha"
	_update_label()

func _update_label() -> void:
	if is_instance_valid(label):
		label.text = display_name
		label.modulate = Color(1.0, 0.35, 0.35)

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

# ------------------------------------------------------------------ AI
func _ai(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	var ts := Enemy.time_scale
	var p := _player()
	var alive := p != null and not p.is_dead
	var to := (p.global_position - global_position) if alive else Vector3.ZERO
	to.y = 0.0
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else _fwd
	match st:
		S.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0
		S.INTRO:
			velocity.x = 0.0
			velocity.z = 0.0
			_face(dir, delta, 6.0)
			_intro += delta
			if _intro > 1.6 and alive:
				st = S.FIGHT
		S.FORMING:
			velocity.x = 0.0
			velocity.z = 0.0
			atk_t += delta
			if atk_t >= 1.6:
				st = S.FIGHT
				cd = 0.8
		S.FIGHT:
			if not alive:
				velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
				Hero.play_move(model, "idle", 0.0)
			else:
				_fight(delta * ts, dir, dist, p)
		S.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			_attack_step(delta * ts, dir, p)
	move_and_slide()

func _animate_body(_delta: float) -> void:
	pass   # the boss drives its own animations

func _face(dir: Vector3, delta: float, rate := 10.0) -> void:
	if dir.length() < 0.01:
		return
	_fwd = _fwd.slerp(dir, minf(1.0, rate * delta)).normalized()
	model.rotation.y = atan2(-_fwd.x, -_fwd.z)

func _fight(delta: float, dir: Vector3, dist: float, p: Player) -> void:
	_face(dir, delta)
	cd -= delta
	var rage := 0.6 if phase == 3 else 1.0
	# keep the right distance: in close for taijutsu, a few metres off with the Susanoo
	var want := 4.5 if susanoo != null else 1.8
	var spd := speed * (1.25 if phase == 3 else 1.0)
	if dist > want + 0.4:
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	elif dist < want - 1.0 and susanoo != null:
		velocity.x = -dir.x * spd * 0.6
		velocity.z = -dir.z * spd * 0.6
	else:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	Hero.play_move(model, Hero.move_state(Vector2(velocity.x, velocity.z).length()), Vector2(velocity.x, velocity.z).length())
	if cd > 0.0:
		return
	if susanoo != null:
		if dist < PUNCH_AHEAD + 2.0:
			_start("slam" if randf() < 0.35 else ("lpunch" if randf() < 0.5 else "rpunch"), p)
			cd = 1.6 * rage
		elif dist > 9.0:
			_start("fireball", p)
			cd = 2.0 * rage
		return
	if dist < COMBO_RANGE:
		_start("combo", p)
		cd = 1.4 * rage
	elif dist > 8.0 and randf() < 0.5:
		_start("flicker", p)
		cd = 0.3
	elif dist > 4.0:
		_start("fireball", p)
		cd = 2.2 * rage

func _start(kind: String, p: Player) -> void:
	st = S.ATTACK
	atk = kind
	atk_t = 0.0
	_hits_done = 0
	match kind:
		"combo":
			atk_len = 1.5
		"fireball":
			atk_len = 0.9
			Hero.play(model, "jutsu", true, 0, 0.6)
			VfxKit.cast(get_parent(), global_position + Vector3.UP * 1.3 + _fwd, _fwd, Color(1.0, 0.45, 0.1), 0.7)
		"flicker":
			atk_len = 0.35
			_flicker(p)
		"lpunch", "rpunch", "slam":
			susanoo.attack(kind)
			atk_len = susanoo.impact_delay(kind) + 0.35
			var r := SLAM_R if kind == "slam" else PUNCH_R
			_aim = global_position + _fwd * (1.5 if kind == "slam" else PUNCH_AHEAD)
			_aim.y = global_position.y
			_telegraph(_aim, r, susanoo.impact_delay(kind))

func _attack_step(delta: float, dir: Vector3, p: Player) -> void:
	atk_t += delta
	match atk:
		"combo":
			_face(dir, delta, 6.0)
			while _hits_done < 3 and atk_t >= COMBO_AT[_hits_done]:
				Hero.play(model, "attack", true, _hits_done, 0.35)
				Sfx.play(self, "swing", -2.0)
				velocity += _fwd * 6.0
				_melee_hit(p, _hits_done)
				_hits_done += 1
		"fireball":
			if _hits_done == 0 and atk_t >= 0.5:
				_hits_done = 1
				Sfx.play(self, "fire")
				var n := 3 if phase == 3 else 1
				for i in n:
					var a := (float(i) - float(n - 1) / 2.0) * 0.28
					var d := _fwd.rotated(Vector3.UP, a)
					if p != null and n == 1:   # aim where they're heading
						var lead := p.global_position + Vector3(p.velocity.x, 0.0, p.velocity.z) * 0.35 - global_position
						lead.y = 0.0
						if lead.length() > 0.1:
							d = lead.normalized()
					BossFireball.fire(get_parent(), global_position + Vector3.UP * 1.3 + d * 1.0, d, FIRE_DMG * _dmg())
		"lpunch", "rpunch", "slam":
			var at := susanoo.impact_delay(atk) if susanoo != null else 0.0
			if _hits_done == 0 and atk_t >= at:
				_hits_done = 1
				if susanoo != null:
					_susanoo_hit(p, atk)
	if atk_t >= atk_len:
		st = S.FIGHT

func _dmg() -> float:
	return 1.25 if phase == 3 else 1.0

func _melee_hit(p: Player, i: int) -> void:
	if p == null or p.is_dead:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() > COMBO_RANGE + 0.6 or (to.length() > 0.8 and _fwd.dot(to.normalized()) < 0.3):
		return
	var last := i == 2
	p.take_damage(COMBO_DMG[i] * _dmg(), _fwd * (12.0 if last else 3.0), last)
	VfxKit.hit(get_parent(), p.global_position + Vector3.UP * 1.1, null, 1.0 if last else 0.7)
	Sfx.play(self, "hit", -2.0)

func _susanoo_hit(p: Player, kind: String) -> void:
	var r := SLAM_R if kind == "slam" else PUNCH_R
	Vfx.shockwave(get_parent(), _aim + Vector3.UP * 0.2, SUSANOO_COLOR, r, 0.4)
	Vfx.burst(get_parent(), _aim + Vector3.UP * 0.5, SUSANOO_COLOR, 28, 8.0, 0.25, 0.6, 0.0)
	if p != null:
		Vfx.shake(p.cam, 0.25 if kind == "slam" else 0.15, 0.4)
	if p == null or p.is_dead:
		return
	var to := p.global_position - _aim
	to.y = 0.0
	if to.length() > r:
		return
	var push := (p.global_position - global_position)
	push.y = 0.0
	push = push.normalized() if push.length() > 0.01 else _fwd
	if kind == "slam":
		p.take_damage(SLAM_DMG * _dmg(), push * 14.0, true)
	else:
		p.take_damage(PUNCH_DMG * _dmg(), push * 10.0)

## Body flicker: vanish in smoke and reappear behind the player, already swinging.
func _flicker(p: Player) -> void:
	if p == null:
		return
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(0.15, 0.12, 0.15, 0.9), 2.0)
	Sfx.play(self, "teleport")
	var behind := p.global_position - p.facing * 1.6
	behind.y = global_position.y
	global_position = behind
	var d := p.global_position - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_fwd = d.normalized()
		model.rotation.y = atan2(-_fwd.x, -_fwd.z)
	Fx.puff(get_parent(), global_position + Vector3.UP, Color(0.15, 0.12, 0.15, 0.9), 2.0)
	cd = 0.15   # straight into a combo

## Red warning circle on the ground where a Susanoo blow will land.
func _telegraph(pos: Vector3, r: float, t: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.04
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.1, 0.1, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.06
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.45, maxf(t, 0.1))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(mi.queue_free)

# ------------------------------------------------------------------ damage / phases
func take_damage(amount: float, knock: Vector3 = Vector3.ZERO) -> void:
	if st == S.DEAD or st == S.INTRO or st == S.FORMING:
		return
	if susanoo != null:
		amount *= 0.65
	health -= amount
	Sfx.play(self, "hit", -5.0)
	Fx.puff(get_parent(), global_position + Vector3.UP * 1.2, Color(1, 1, 0.7, 0.9), 0.8)
	Vfx.damage_number(get_parent(), global_position + Vector3.UP * 2.3, amount, Color(1.0, 0.85, 0.3))
	velocity.x += knock.x * 0.2
	velocity.z += knock.z * 0.2
	var np := 3 if health < MAX_HP * 0.33 else (2 if health < MAX_HP * 0.66 else 1)
	if health <= 0.0:
		_die()
	elif np > phase:
		phase = np
		phase_changed.emit(phase)
		if phase == 2:
			_form_susanoo()
		elif phase == 3:
			_enrage()

func _form_susanoo() -> void:
	st = S.FORMING
	atk_t = 0.0
	Hero.play(model, "jutsu", true)
	susanoo = Susanoo.create(SUSANOO_COLOR, model)
	add_child(susanoo)
	AuraShell.flare(self, model, SUSANOO_COLOR, 1.6)
	Vfx.shockwave(get_parent(), global_position + Vector3.UP * 0.2, SUSANOO_COLOR, 8.0, 0.5)
	Vfx.burst(get_parent(), global_position + Vector3.UP * 2.0, SUSANOO_COLOR, 50, 11.0, 0.3, 0.8, 0.0)
	var p := _player()
	if p != null:
		Vfx.shake(p.cam, 0.35, 0.6)
		var away := p.global_position - global_position
		away.y = 0.0
		if away.length() < 6.0:   # the Susanoo forming throws you back
			p.take_damage(8.0, (away.normalized() if away.length() > 0.01 else -_fwd) * 16.0, true)

func _enrage() -> void:
	_rage = AuraShell.make(self, model, ENRAGE_COLOR, Color(0.2, 0.0, 0.0), 0.5)
	Sfx.play(self, "power", 2.0)
	Vfx.burst(get_parent(), global_position + Vector3.UP * 1.5, ENRAGE_COLOR, 40, 9.0, 0.3, 0.8, 0.0)
	cd = minf(cd, 0.4)

func _die() -> void:
	st = S.DEAD
	health = 0.0
	remove_from_group("enemies")
	if susanoo != null and is_instance_valid(susanoo):
		susanoo.dismiss()
	susanoo = null
	if _rage != null and is_instance_valid(_rage):
		_rage.fade_out()
	var p := _player()
	if p != null:
		p.kills += 1
		p.on_kill(true)
		p.add_mode(25.0)
		p.chakra = p.max_chakra
		p.health = minf(p.max_health, p.health + 50.0)
	Sfx.play(self, "death", 4.0)
	Sfx.play(self, "boom", 2.0)
	var rag := Ragdoll.start(model, get_parent(), _fwd * -4.0 + Vector3.UP * 3.0)
	if rag != null:
		rag.add_to_group("boss_corpse")
	var t := create_tween()
	t.tween_interval(1.4)
	t.tween_callback(func() -> void: defeated.emit())


## The boss's Fire Style: the fire projectile VFX, explodes on the player, the ground or a wall.
class BossFireball extends Node3D:
	var vel := Vector3.ZERO
	var damage := 18.0
	var life := 3.0
	var done := false

	static func fire(parent: Node, pos: Vector3, dir: Vector3, dmg: float) -> void:
		if parent == null:
			return
		var f := BossFireball.new()
		f.vel = dir.normalized() * 20.0
		f.damage = dmg
		parent.add_child(f)
		f.global_position = pos
		f.look_at(pos + dir, Vector3.UP)
		var fx := VfxKit.fire_projectile(f, 1.6)
		if fx != null:
			fx.set("emission", 1.3)

	func _physics_process(delta: float) -> void:
		if done:
			return
		life -= delta
		var nxt := global_position + vel * delta
		var q := PhysicsRayQueryParameters3D.create(global_position, nxt)
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		global_position = nxt
		var p := get_tree().get_first_node_in_group("player") as Player
		if p != null and not p.is_dead and global_position.distance_to(p.global_position + Vector3.UP) < 1.3:
			_explode(p)
		elif (not hit.is_empty() and not (hit["collider"] is Enemy)) or life <= 0.0:
			_explode(p)

	func _explode(p: Player) -> void:
		done = true
		Sfx.play(self, "boom", -2.0)
		VfxKit.hit(get_parent(), global_position, Color(1.0, 0.55, 0.15), 1.3)
		if p != null and not p.is_dead and global_position.distance_to(p.global_position + Vector3.UP) < 3.0:
			var push := p.global_position - global_position
			push.y = 0.0
			p.take_damage(damage, (push.normalized() if push.length() > 0.01 else vel.normalized()) * 8.0)
		queue_free()
