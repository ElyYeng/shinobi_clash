class_name UiPause
## Opening a menu / dialog: single player pauses the game; online the world can't pause (the
## others keep playing and voice chat must keep running), so only your own character is frozen
## (no moving or attacking while you click around). Counted, so menus can stack.

static var _open := {}   # menu instance id -> true (each menu counts once, however often it re-opens)

static func set_open(from: Node, open: bool) -> void:
	if from == null or not from.is_inside_tree():
		return
	if open:
		_open[from.get_instance_id()] = true
	else:
		_open.erase(from.get_instance_id())
	var n := _open.size()
	var online := NetworkSession.is_active()
	var tree := from.get_tree()
	if online:
		tree.paused = false
		var p := tree.get_first_node_in_group("player")
		if p != null:
			p.process_mode = Node.PROCESS_MODE_DISABLED if n > 0 else Node.PROCESS_MODE_INHERIT
	else:
		tree.paused = n > 0

## Close everything (scene change, back to the main menu).
static func reset(from: Node) -> void:
	_open.clear()
	if from != null and from.is_inside_tree():
		from.get_tree().paused = false
		var p := from.get_tree().get_first_node_in_group("player")
		if p != null:
			p.process_mode = Node.PROCESS_MODE_INHERIT
