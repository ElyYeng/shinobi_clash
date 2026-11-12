class_name SubLog
## Substitution Jutsu: a wooden log appears where you stood (in a puff of smoke), drops and
## tumbles over, lies there a moment, then vanishes in another puff.

static func spawn(world: Node3D, pos: Vector3, yaw: float) -> void:
	if world == null or not world.is_inside_tree():
		return
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos
	root.rotation.y = yaw
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.45, 0.3, 0.17)
	var cut := StandardMaterial3D.new()   # the pale cut ends with rings
	cut.albedo_color = Color(0.82, 0.68, 0.45)
	var log := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.24
	cm.bottom_radius = 0.26
	cm.height = 1.5
	cm.radial_segments = 10
	cm.material = bark
	log.mesh = cm
	log.position.y = 0.75
	root.add_child(log)
	for end in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 0.23
		cc.bottom_radius = 0.23
		cc.height = 0.02
		cc.radial_segments = 10
		cc.material = cut
		cap.mesh = cc
		cap.position.y = 0.75 * end
		log.add_child(cap)
	var rope := MeshInstance3D.new()   # the paper-tag rope around it
	var tm := TorusMesh.new()
	tm.inner_radius = 0.25
	tm.outer_radius = 0.3
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.9, 0.86, 0.75)
	tm.material = rm
	rope.mesh = tm
	rope.position.y = 0.2
	log.add_child(rope)
	CharToon.apply(root)
	Fx.puff(world, pos + Vector3.UP * 1.0, Color(0.85, 0.85, 0.85, 0.9), 2.4)
	# stands where you were, then topples over and settles
	var tw := root.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(root, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(log, "position:y", 0.26, 0.45)
	tw.tween_interval(2.2)
	tw.tween_callback(func() -> void:
		Fx.puff(world, root.global_position + Vector3.UP * 0.4, Color(0.85, 0.85, 0.85, 0.8), 1.6)
		root.queue_free())
