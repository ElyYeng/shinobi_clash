extends Node3D
## "WorldTerrain" stand-in for StreamedMap: the main scene asks it for ground heights and to get
## the spawn area ready, like it does with the procedural terrain.

func height_at(x: float, z: float) -> float:
	return (get_parent() as StreamedMap).height_at(x, z)

func prepare_spawn(pos: Vector3) -> void:
	(get_parent() as StreamedMap).load_around_now(pos)
