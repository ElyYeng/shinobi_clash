class_name TrainingLog
extends Enemy
## A wooden training log to try jutsu on: never dies, doesn't move or fight back, shows each
## hit's damage and the total of the last few seconds (DPS check). Counts as an enemy, so every
## ability, projectile and lock-on works on it.

var _hits: Array = []   # [time, amount]
var _shake := 0.0
var _log: Node3D

static func spawn(parent: Node, pos: Vector3) -> TrainingLog:
	var t := TrainingLog.new()
	t.display_name = "Training Log"
	t.health = 1000000.0
	parent.add_child(t)
	t.global_position = pos
	return t

func _setup() -> void:
	add_to_group("enemies")
	max_health = health
	bloodline_id = "none"
	k = 1.0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	col.shape = cap
	col.position.y = 0.95
	add_child(col)
	_log = Node3D.new()
	add_child(_log)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.22)
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.85, 0.78, 0.55)
	_part(_cyl(0.32, 2.0, wood), Vector3(0, 1.0, 0))                      # the post
	_part(_cyl(0.33, 0.12, rope), Vector3(0, 1.45, 0))                    # rope bands
	_part(_cyl(0.33, 0.12, rope), Vector3(0, 0.6, 0))
	var arm := _part(_cyl(0.09, 1.3, wood), Vector3(0, 1.3, 0))          # cross arm
	arm.rotation.z = PI * 0.5
	CharToon.apply(_log)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.006
	label.outline_size = 12
	label.position.y = 2.5
	add_child(label)
	_update_label()

func _cyl(r: float, h: float, m: Material) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	c.material = m
	return c

func _part(mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	_log.add_child(mi)
	return mi

func _update_label() -> void:
	if label == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var tot := 0.0
	for h in _hits:
		if now - float(h[0]) <= 5.0:
			tot += float(h[1])
	label.text = "Training Log" + ("\n%d dmg (last 5s)" % int(tot) if tot > 0.0 else "")

func _physics_process(delta: float) -> void:
	stun = maxf(0.0, stun - delta)
	velocity = Vector3.ZERO
	if _shake > 0.0:   # wobble when hit
		_shake = maxf(0.0, _shake - delta)
		_log.rotation.x = sin(_shake * 40.0) * _shake * 0.25
		_log.rotation.z = cos(_shake * 33.0) * _shake * 0.2
	var now := Time.get_ticks_msec() / 1000.0
	if not _hits.is_empty() and now - float(_hits[0][0]) > 5.0:
		_hits.pop_front()
		_update_label()

func take_damage(amount: float, _knock: Vector3 = Vector3.ZERO) -> void:
	_hits.append([Time.get_ticks_msec() / 1000.0, amount])
	_shake = 0.35
	Sfx.play(self, "hit", -6.0)
	Fx.puff(get_parent(), global_position + Vector3.UP * 1.2, Color(0.8, 0.65, 0.4, 0.9), 0.6)
	Vfx.damage_number(get_parent(), global_position + Vector3.UP * 2.2, amount)
	_update_label()

func knockdown(_knock: Vector3) -> void:
	_shake = 0.6   # a log doesn't fall over
