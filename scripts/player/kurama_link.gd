class_name KuramaLink
extends Node3D
## Uzumaki form 2 (hold C + 2): Kurama Link Mode - the giant chakra fox appears under you and you
## ride on its head. Pure visual (model + animations + rider seat); player.gd does the damage.
## Model: assets/kuramalinkmode (faces +Z). Animations: atstand / run / attack01 / skill01_1 /
## skill02 / skill03 / hurt01 / stand / wait.

const MODEL := "res://assets/kuramalinkmode/scene.gltf"
const SCALE := 10.0
const IDLE := "Armature|atstand"
const RUN := "Armature|run"
## move -> [animation, seconds into it where the hit lands]
const MOVES := {
	"claw": ["Armature|attack01", 0.9],
	"bomb": ["Armature|skill01_1", 2.3],
	"slam": ["Armature|skill02", 1.5],
	"roar": ["Armature|skill03", 0.9],
}

var follow: Node3D          # the rider's model (we copy its facing)
var ap: AnimationPlayer
var _seat: BoneAttachment3D
var _busy := 0.0
var _dying := false
var _aura: AuraShell
var _model: Node3D
var _sk: Skeleton3D
var _paws: Array[int] = []      # toe / foot bones: the lowest one is kept on the ground

static func create(rider_model: Node3D) -> KuramaLink:
	var k := KuramaLink.new()
	k.name = "KuramaLink"
	k.follow = rider_model
	return k

static func hit_delay(kind: String) -> float:
	return float(MOVES[kind][1]) if MOVES.has(kind) else 0.5

func _ready() -> void:
	var ps := load(MODEL) as PackedScene
	if ps == null:
		return
	var m := ps.instantiate() as Node3D
	add_child(m)
	_model = m
	process_priority = 100   # after the AnimationPlayer, so the paw grounding sees this frame's pose
	CharToon.apply(m)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		ap = aps[0]
		for n in [IDLE, RUN, "Armature|stand", "Armature|wait"]:
			if ap.has_animation(n):
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		ap.play(IDLE)
	var sks := m.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		var sk := sks[0] as Skeleton3D
		_sk = sk
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i).to_lower()
			if bn.contains("toe") or bn.contains("foot") or bn.contains("hand") or bn.contains("finger"):
				_paws.append(i)
		var head := sk.find_bone("Head_028")
		if head < 0:
			for i in sk.get_bone_count():
				if sk.get_bone_name(i).to_lower().contains("head"):
					head = i
					break
		if head >= 0:
			_seat = BoneAttachment3D.new()
			_seat.bone_name = sk.get_bone_name(head)
			sk.add_child(_seat)
	_aura = AuraShell.make(self, m, Color(1.0, 0.6, 0.12), Color(1.0, 0.85, 0.4), 0.4, 0.12)
	_aura.set_strength(0.5)
	scale = Vector3.ONE * 0.1
	create_tween().tween_property(self, "scale", Vector3.ONE * SCALE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "power", 4.0)

func _process(delta: float) -> void:
	_busy = maxf(0.0, _busy - delta)
	_snap_to_ground()
	_ground_paws(delta)
	if follow != null and is_instance_valid(follow) and not _dying:
		rotation.y = lerp_angle(rotation.y, follow.global_rotation.y + PI, 1.0 - exp(-10.0 * delta))

## Keep the paws on the ground (the owner may be in the air or offset, e.g. a remote avatar).
func _snap_to_ground() -> void:
	if not is_inside_tree():
		return
	var from: Vector3 = (get_parent() as Node3D).global_position if get_parent() is Node3D else global_position
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 3.0, from + Vector3.DOWN * 30.0)
	q.collision_mask = 1
	var ex: Array[RID] = []
	if get_parent() is CollisionObject3D:
		ex.append((get_parent() as CollisionObject3D).get_rid())
	q.exclude = ex
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		global_position.y = (h["position"] as Vector3).y

## The gallop lifts the whole body in the animation: shift the model down so the lowest paw
## touches the ground (never up into the floor).
func _ground_paws(delta: float) -> void:
	if _sk == null or _model == null or _paws.is_empty():
		return
	var low := INF
	var g := _sk.global_transform
	for b in _paws:
		low = minf(low, (g * _sk.get_bone_global_pose(b)).origin.y)
	if low == INF:
		return
	var lift := (low - global_position.y) / maxf(scale.y, 0.001)   # in model units
	var want := _model.position.y - lift
	want = minf(want, 0.0)   # only ever push down to the ground
	_model.position.y = lerpf(_model.position.y, want, 1.0 - exp(-20.0 * delta))

## Where the rider stands (on top of the head), in world space.
func seat_position() -> Vector3:
	if _seat != null and is_instance_valid(_seat):
		return _seat.global_position + Vector3.UP * 1.3   # head bone = base of the skull: stand on top
	return global_position + Vector3.UP * 3.8

## Run cycle speed per m/s of ground speed (so the paws keep up instead of sliding).
const RUN_RATE := 0.32
func set_moving(on: bool, speed := 8.0) -> void:
	if ap == null or _dying:
		return
	if _busy > 0.0:
		ap.speed_scale = 1.0
		return
	var want := RUN if on else IDLE
	if ap.current_animation != want:
		ap.play(want, 0.2)
	ap.speed_scale = clampf(speed * RUN_RATE, 1.3, 4.0) if on else 1.0

func attack(kind: String) -> void:
	if ap == null or _dying or not MOVES.has(kind):
		return
	var anim: String = MOVES[kind][0]
	if not ap.has_animation(anim):
		return
	ap.play(anim, 0.12)
	_busy = ap.get_animation(anim).length
	get_tree().create_timer(_busy).timeout.connect(func() -> void:
		if ap != null and not _dying:
			ap.play(IDLE, 0.25))

func hurt() -> void:
	if ap != null and _busy <= 0.0 and ap.has_animation("Armature|hurt01"):
		ap.play("Armature|hurt01", 0.08)
		_busy = 0.45

func dismiss() -> void:
	if _dying:
		return
	_dying = true
	if _aura != null and is_instance_valid(_aura):
		_aura.fade_out(0.3)
	Fx.puff(get_parent(), global_position + Vector3.UP * 2.0, Color(1.0, 0.75, 0.3, 0.9), 6.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.1, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
