@tool
class_name GrassPatch
extends Node3D
## Scatters grass and flowers over a square area. Shows live in the editor: change a setting in the
## Inspector and it regenerates. (The blades are generated, not saved, so map files stay small.)
## It keeps clear of solid objects in the map (houses, trees, walls...) and of the areas listed below.

@export var grass_count := 20000:
	set(v):
		grass_count = v
		_queue()
@export var flower_count := 900:
	set(v):
		flower_count = v
		_queue()
@export var half_size := 47.0:            ## grass covers -half_size..half_size around this node
	set(v):
		half_size = v
		_queue()
@export var flower_half_size := 46.0:
	set(v):
		flower_half_size = v
		_queue()
@export var seed_value := 21:
	set(v):
		seed_value = v
		_queue()
@export var base_color := Color(0.1, 0.3, 0.1):
	set(v):
		base_color = v
		_queue()
@export var tip_color := Color(0.58, 0.82, 0.3):
	set(v):
		tip_color = v
		_queue()
@export var avoid_solids := true:         ## stay off buildings, trees and walls
	set(v):
		avoid_solids = v
		_queue()
@export var solid_padding := 0.5:
	set(v):
		solid_padding = v
		_queue()
## Round areas to keep clear: x, z = centre (map coordinates), y = radius.
@export var clear_circles: Array[Vector3] = []:
	set(v):
		clear_circles = v
		_queue()
## Rectangles to keep clear (map x / z), e.g. roads.
@export var clear_rects: Array[Rect2] = []:
	set(v):
		clear_rects = v
		_queue()

var _pending := false

func _ready() -> void:
	_rebuild()

func _queue() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta("grass_generated"):
			remove_child(c)
			c.queue_free()
	var map := _map_root()
	var solids: Array[Rect2] = []
	if avoid_solids and map != null:
		solids = GameMap.footprints_of(map)
	var origin := global_position if is_inside_tree() else position
	var keep := func(p: Vector3) -> bool:
		var w := p + origin
		for c in clear_circles:
			if Vector2(w.x - c.x, w.z - c.z).length() < c.y:
				return false
		for r in clear_rects:
			if r.has_point(Vector2(w.x, w.z)):
				return false
		for r in solids:
			if r.grow(solid_padding).has_point(Vector2(w.x, w.z)):
				return false
		return true
	var before := get_child_count()
	if grass_count > 0:
		Vfx.grass(self, grass_count, half_size, seed_value, keep, base_color, tip_color)
	if flower_count > 0:
		Vfx.flowers(self, flower_count, flower_half_size, seed_value + 1, keep)
	for i in range(before, get_child_count()):
		get_child(i).set_meta("grass_generated", true)   # never saved into the scene

## The map scene root this patch belongs to.
func _map_root() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n is GameMap:
			return n
		if Engine.is_editor_hint() and n == get_tree().edited_scene_root:
			return n
		n = n.get_parent()
	return get_parent().get_parent() if get_parent() != null else null
