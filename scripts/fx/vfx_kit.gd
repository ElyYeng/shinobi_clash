class_name VfxKit
extends RefCounted
## Spawns the imported VFX scenes (assets/BinbunVFX_Vol2, assets/GodotImpactVFX) and cleans them
## up. All of them free themselves; nothing needs to be stored by the caller unless it wants to
## stop a looping one early (chakra aura while charging).

const CHAKRA := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/chakra.tscn"
const FIRE_AREA := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn"
const FIRE_CAST := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn"
const FIRE_PROJECTILE := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn"
const HIT := "res://assets/GodotImpactVFX/effects/hit/vfx_hit_01.tscn"

static func _make(path: String) -> Node3D:
	var ps := load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null

## Recolours an effect (the VFX scripts push these into their shaders).
static func tint(n: Node3D, col: Color) -> void:
	if n == null:
		return
	if "primary_color" in n:
		n.set("primary_color", col.lightened(0.35))
	if "secondary_color" in n:
		n.set("secondary_color", col)
	if "tertiary_color" in n:
		n.set("tertiary_color", col.darkened(0.4))
	if "light_color" in n:
		n.set("light_color", col)

## Chakra aura at the feet. life > 0: plays that long then closes; life <= 0: keeps going until
## stop_area() is called on it. Optional colour (default: the effect's own chakra blue).
static func chakra(parent: Node3D, life := 0.0, col = null, scale := 1.0) -> Node3D:
	return area(CHAKRA, parent, Vector3.ZERO, life, col, scale)

static func area(path: String, parent: Node, pos: Vector3, life := 0.0, col = null, scale := 1.0) -> Node3D:
	var n := _make(path)
	if n == null or parent == null or not parent.is_inside_tree():
		return null
	parent.add_child(n)
	n.position = pos
	n.scale = Vector3.ONE * scale
	if col is Color:
		tint(n, col)
	if life > 0.0:
		n.get_tree().create_timer(life).timeout.connect(stop_area.bind(n))
	return n

## Closes a looping area effect (plays its close animation) and frees it afterwards.
static func stop_area(n) -> void:
	if not is_instance_valid(n):
		return
	if n.has_meta("closing"):
		return
	n.set_meta("closing", true)
	if "emitting" in n:
		n.set("emitting", false)
	n.get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())

## One flare burst (casting a jutsu), facing `dir`.
static func cast(parent: Node, pos: Vector3, dir: Vector3, col = null, scale := 1.0) -> void:
	var n := _make(FIRE_CAST)
	if n == null or parent == null or not parent.is_inside_tree():
		return
	n.set("one_shot", true)
	parent.add_child(n)
	n.global_position = pos
	n.scale = Vector3.ONE * scale
	if dir.length() > 0.01 and absf(dir.normalized().dot(Vector3.UP)) < 0.99:
		n.look_at(pos + dir, Vector3.UP)
	if col is Color:
		tint(n, col)
	if n.has_method("play"):
		n.call("play")
	n.get_tree().create_timer(1.2).timeout.connect(n.queue_free)

## Impact burst (melee / Susanoo / projectile hits).
static func hit(parent: Node, pos: Vector3, col = null, scale := 1.0) -> void:
	var n := _make(HIT)
	if n == null or parent == null or not parent.is_inside_tree():
		return
	n.set("one_shot", true)
	parent.add_child(n)
	n.global_position = pos
	n.scale = Vector3.ONE * scale
	if col is Color:
		tint(n, col)
	n.get_tree().create_timer(1.6).timeout.connect(n.queue_free)

## Fireball body (attached to a projectile; frees with it). The effect is built to fly along
## its +X (flames / tail trail off toward -X), so it's turned to fly along the parent's -Z
## (the way look_at points the projectile).
static func fire_projectile(parent: Node3D, scale := 1.0) -> Node3D:
	var n := _make(FIRE_PROJECTILE)
	if n == null:
		return null
	parent.add_child(n)
	n.rotation.y = PI / 2.0
	n.scale = Vector3.ONE * scale
	return n
