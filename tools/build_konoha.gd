extends Node
## Writes res://maps/konoha_greybox.tscn from konoha_greybox.gd. Run:
##   godot --headless --path . res://tools/build_konoha.tscn
## (overwrites the scene - only re-run it if you want to throw away edits made in the editor)
func _ready() -> void:
	await get_tree().process_frame
	var err := KonohaGreybox.save_scene()
	print("[konoha] %s -> %s" % [KonohaGreybox.OUT, error_string(err)])
	get_tree().quit()
