class_name GameMap
extends Node3D
## Root of a map scene (res://maps/*.tscn). Open the scene in Godot and edit it like any level:
## move / duplicate / delete houses, trees, rocks, lanterns... Everything is a normal node.
##
## Groups (child nodes) the game understands:
##   Ground, Bounds        floor and invisible walls (ignored when checking where things can spawn)
##   anything else         solid StaticBody3D nodes in it block enemy spawns and grass (Buildings, Trees, Props...)
##   Markers/PlayerSpawn   where the player starts (Marker3D; move it in the editor)
##   Markers/BossSpawn     where Kurama appears (Kurama arena)
## GrassPatch nodes (in Grass) scatter grass and flowers; their settings are in the Inspector.

@export var play_half := 46.0                 ## half-size of the playable square (keeps teleports in bounds)
@export var spawn_area := Rect2(-45, -36, 90, 81)   ## x / z area where fight-mode enemies may spawn

const NO_FOOTPRINT := ["Ground", "Bounds", "Markers", "Grass", "Environment"]

var footprints: Array[Rect2] = []

func _ready() -> void:
	footprints = GameMap.footprints_of(self)

## Position of a marker under Markers (or `fallback` if the map has none).
func spawn(marker: String, fallback: Vector3) -> Vector3:
	var m := get_node_or_null("Markers/" + marker) as Node3D
	return m.global_position if m != null else fallback

## Is this x/z point inside (or within `pad` of) something solid?
func blocked(p: Vector3, pad: float) -> bool:
	for r in footprints:
		if r.grow(pad).has_point(Vector2(p.x, p.z)):
			return true
	return false

## x/z rectangles of every solid box / cylinder collider in the map, except floor and walls.
static func footprints_of(root: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for child in root.get_children():
		if NO_FOOTPRINT.has(String(child.name)):
			continue
		for n in child.find_children("*", "CollisionShape3D", true, false):
			var cs := n as CollisionShape3D
			if cs.disabled or not (cs.get_parent() is StaticBody3D):
				continue
			var half := Vector3.ZERO
			if cs.shape is BoxShape3D:
				half = (cs.shape as BoxShape3D).size / 2.0
			elif cs.shape is CylinderShape3D:
				var r := (cs.shape as CylinderShape3D).radius
				half = Vector3(r, 0, r)
			else:
				continue
			var xf := cs.global_transform if cs.is_inside_tree() else _xform_to(cs, root)
			var c := xf.origin
			var ex := (xf.basis.x * half.x).abs() + (xf.basis.z * half.z).abs()
			out.append(Rect2(c.x - ex.x, c.z - ex.z, ex.x * 2.0, ex.z * 2.0))
	return out

static func _xform_to(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
