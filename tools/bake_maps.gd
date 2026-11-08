@tool
extends EditorScript
## Creates the editable map scenes (res://maps/*.tscn) from the original map generator.
## Open this file in the Script editor and use File > Run (Ctrl+Shift+X).
## Maps that already exist are SKIPPED so your edits are safe. To regenerate one, delete its
## .tscn first (or set OVERWRITE = true - that throws away your edits to it).

const OVERWRITE := false

func _run() -> void:
	for mode in MapBuilder.MAP_FILES:
		var path: String = MapBuilder.MAP_FILES[mode]
		if FileAccess.file_exists(path) and not OVERWRITE:
			print("[bake_maps] %s exists - skipped" % path)
			continue
		var err := MapBuilder.bake(mode, path)
		print("[bake_maps] %s -> %s" % [path, "OK" if err == OK else error_string(err)])
	EditorInterface.get_resource_filesystem().scan()
