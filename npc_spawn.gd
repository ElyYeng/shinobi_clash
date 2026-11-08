@tool
class_name NpcSpawn
extends Marker3D
## Puts an NPC on the map. Drag it around in the 3D editor; the game spawns the NPC here.
## In the editor it shows a preview of the character (real model or placeholder ninja) with its name.
##
## To add an NPC to a map: drag prefabs/npc_spawn.tscn from the FileSystem dock into the 3D view
## (or Ctrl+D an existing one), then drag an NPC file from data/npcs onto its "Npc" field in the Inspector.
## Rotating it turns the NPC. NPCs without a spawn on the map stand at the `pos` in their NPC file.

@export var npc: NpcDef:
	set(v):
		npc = v
		_queue()

var _pending := false

## The NPC id (its file name in data/npcs), or "" if none is set.
func npc_id() -> String:
	return npc.resource_path.get_file().get_basename() if npc != null and npc.resource_path != "" else ""

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild()

func _queue() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()

## Editor-only preview (never saved: the preview nodes have no owner).
func _rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta("npc_preview"):
			remove_child(c)
			c.queue_free()
	if not Engine.is_editor_hint():
		return
	var label_y := 2.6
	var title := "(drop an NPC file\non the Npc field)"
	var model: Node3D = null
	if npc != null:
		title = npc.display_name
		model = Npc.build_model(npc.model, npc.model_height, npc.model_yaw_deg, npc.outline, npc.display_name)
		if model != null:
			label_y = float(model.get_meta("label_y", label_y))
		else:
			model = Fx.make_ninja(npc.body_color, npc.band_color)
	if model != null:
		model.set_meta("npc_preview", true)
		add_child(model)
	var l := Label3D.new()
	l.text = title
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 48
	l.outline_size = 12
	l.pixel_size = 0.006
	l.modulate = Color(1.0, 0.9, 0.4) if npc != null else Color(1.0, 0.4, 0.3)
	l.position.y = label_y
	l.set_meta("npc_preview", true)
	add_child(l)
