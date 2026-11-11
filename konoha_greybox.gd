class_name KonohaGreybox
extends RefCounted
## Builds the Konoha greybox map (plain blocks with a 1 m / 4 m grid) as a GameMap.
## Saved to res://maps/konoha_greybox.tscn by tools/build_konoha.tscn - after that, edit the scene
## in Godot like any level (move / resize / duplicate the blocks). -Z is north.
##
## Layout: Hokage Rock with six faces on the north edge (ramp up its west side), Hokage Tower at
## the end of the main street, the A-Un main gate in the south wall, Academy, Hospital, Ichiraku,
## Hyuga and Uchiha compounds, Training Ground 3, a river with a bridge, and forest outside the wall.

const OUT := "res://maps/konoha_greybox.tscn"
const WALL_R := 175.0
const HALF := 250.0

# greybox palette: greys for generic blocks, a light tint marks landmarks
const C_GROUND := Color(0.42, 0.43, 0.42)
const C_ROAD := Color(0.33, 0.33, 0.34)
const C_PLAZA := Color(0.5, 0.5, 0.5)
const C_BLOCK := Color(0.68, 0.68, 0.68)
const C_BLOCK2 := Color(0.6, 0.6, 0.61)
const C_ROOF := Color(0.52, 0.52, 0.54)
const C_WALL := Color(0.55, 0.54, 0.52)
const C_ROCK := Color(0.5, 0.48, 0.46)
const C_FACE := Color(0.62, 0.59, 0.56)
const C_LANDMARK := Color(0.78, 0.62, 0.55)
const C_WATER := Color(0.35, 0.52, 0.7)
const C_TRUNK := Color(0.45, 0.4, 0.36)
const C_LEAF := Color(0.45, 0.56, 0.45)

var root: GameMap
var rng := RandomNumberGenerator.new()
var _mats := {}
var _reserved: Array[Rect2] = []   # x/z areas kept free of filler buildings

static func build() -> GameMap:
	var b := KonohaGreybox.new()
	b._build()
	return b.root

func _build() -> void:
	rng.seed = 4242
	root = GameMap.new()
	root.name = "KonohaGreybox"
	root.play_half = HALF - 10.0
	root.spawn_area = Rect2(-150, -120, 300, 270)
	_environment()
	_ground()
	_roads()
	_hokage_rock()
	_hokage_tower()
	_gate_and_wall()
	_academy()
	_hospital()
	_ichiraku()
	_hyuga()
	_uchiha()
	_training_ground()
	_river()
	_filler_buildings()
	_forest()
	_bounds()
	_npcs()
	var markers := _group("Markers")
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 1, 150)
	markers.add_child(spawn)

# ------------------------------------------------------------------ helpers
func _group(n: String) -> Node3D:
	var g := root.get_node_or_null(n) as Node3D
	if g == null:
		g = Node3D.new()
		g.name = n
		root.add_child(g)
	return g

func _mat(c: Color, grid := 1.0) -> ShaderMaterial:
	var key := "%s_%s" % [c.to_html(), grid]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/greybox.gdshader")
		m.set_shader_parameter("color", c)
		m.set_shader_parameter("grid_strength", grid)
		_mats[key] = m
	return _mats[key]

## Box whose bottom-centre sits at `pos`. solid = gets a collider.
func box(group: String, n: String, pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO, solid := true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _piece(group, n, pos, rot, mesh, c, _box_shape(size) if solid else null, size.y)

func cyl(group: String, n: String, pos: Vector3, r: float, h: float, c: Color, top_r := -1.0, solid := true) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r if top_r < 0.0 else top_r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 24
	var shape: Shape3D = null
	if solid:
		var cs := CylinderShape3D.new()
		cs.radius = r
		cs.height = h
		shape = cs
	return _piece(group, n, pos, Vector3.ZERO, mesh, c, shape, h)

func _box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s

func _piece(group: String, n: String, pos: Vector3, rot: Vector3, mesh: Mesh, c: Color, shape: Shape3D, h: float) -> Node3D:
	var body: Node3D = StaticBody3D.new() if shape != null else Node3D.new()
	body.name = n
	body.position = pos + Vector3(0, h / 2.0, 0)
	body.rotation = rot
	_group(group).add_child(body, true)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = _mat(c)
	body.add_child(mi)
	if shape != null:
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = shape
		body.add_child(cs)
	return body

func _reserve(x0: float, z0: float, x1: float, z1: float) -> void:
	_reserved.append(Rect2(x0, z0, x1 - x0, z1 - z0))

func _free_spot(r: Rect2) -> bool:
	for q in _reserved:
		if q.intersects(r):
			return false
	return true

# ------------------------------------------------------------------ pieces
func _environment() -> void:
	# same sky / sun / fog as the arena village, so the greybox is lit like the real game
	var village := load("res://maps/village.tscn") as PackedScene
	if village == null:
		return
	var v := village.instantiate()
	var env := v.get_node_or_null("Environment")
	if env != null:
		var copy := env.duplicate()
		root.add_child(copy)
		for c in copy.get_children():
			if c is DirectionalLight3D:
				(c as DirectionalLight3D).directional_shadow_max_distance = 220.0
			elif not (c is WorldEnvironment):
				c.free()   # keep only the sky and the sun (no fireflies etc.)
	v.free()

func _ground() -> void:
	box("Ground", "Floor", Vector3(0, -1, 0), Vector3(HALF * 2.0, 1, HALF * 2.0), C_GROUND)

func _roads() -> void:
	# flat strips (no collision) so they never snag the player
	box("Roads", "MainStreet", Vector3(0, 0, 35), Vector3(14, 0.04, 270), C_ROAD, Vector3.ZERO, false)
	box("Roads", "CrossStreet", Vector3(0, 0, 40), Vector3(300, 0.04, 10), C_ROAD, Vector3.ZERO, false)
	box("Roads", "NorthStreet", Vector3(0, 0, -40), Vector3(250, 0.04, 8), C_ROAD, Vector3.ZERO, false)
	box("Roads", "SouthStreet", Vector3(0, 0, 110), Vector3(240, 0.04, 8), C_ROAD, Vector3.ZERO, false)
	box("Roads", "CrossPlaza", Vector3(0, 0, 40), Vector3(34, 0.06, 26), C_PLAZA, Vector3.ZERO, false)
	_reserve(-7, -100, 7, 175)       # main street
	_reserve(-150, 35, 150, 45)      # cross street
	_reserve(-125, -44, 125, -36)    # north street
	_reserve(-120, 106, 120, 114)    # south street
	_reserve(-17, 27, 17, 53)        # plaza

func _hokage_rock() -> void:
	# a cliff along the north edge; six carved faces look south over the village
	box("HokageRock", "Cliff", Vector3(0, 0, -188), Vector3(300, 62, 46), C_ROCK)
	box("HokageRock", "CliffBack", Vector3(0, 0, -228), Vector3(500, 40, 40), C_ROCK)
	for i in 6:
		var x := -90.0 + i * 36.0
		box("HokageRock", "Face%d" % (i + 1), Vector3(x, 24, -163), Vector3(22, 28, 6), C_FACE)
		box("HokageRock", "Face%dNose" % (i + 1), Vector3(x, 34, -159.5), Vector3(4, 7, 3), C_FACE)
		box("HokageRock", "Face%dBrow" % (i + 1), Vector3(x, 43, -159.5), Vector3(18, 2, 3), C_FACE)
	# ramp up the west end of the cliff (30 degrees) - top lands at y 62 on the cliff edge
	var run := 104.0
	var rise := 62.0
	var ang := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	var ramp := box("HokageRock", "Ramp", Vector3(-120, 0, -165 + run / 2.0), Vector3(10, 1.0, length), C_WALL, Vector3(ang, 0, 0))
	ramp.position.y = rise / 2.0
	box("HokageRock", "RampSupport", Vector3(-120, 0, -150), Vector3(10, 20, 6), C_ROCK)
	_reserve(-130, -170, -110, -55)
	# lookout on top of the faces
	box("HokageRock", "Lookout", Vector3(0, 62, -180), Vector3(16, 0.6, 10), C_LANDMARK)
	for t in 10:
		_tree(Vector3(rng.randf_range(-130, 120), 62, rng.randf_range(-205, -175)))
	_reserve(-160, -260, 160, -150)

func _hokage_tower() -> void:
	box("HokageTower", "Plaza", Vector3(0, 0, -78), Vector3(56, 0.08, 36), C_PLAZA, Vector3.ZERO, false)
	cyl("HokageTower", "Tower", Vector3(0, 0, -105), 17, 22, C_LANDMARK)
	cyl("HokageTower", "Roof", Vector3(0, 22, -105), 20, 7, C_ROOF, 9.0, false)
	cyl("HokageTower", "Top", Vector3(0, 29, -105), 7, 6, C_LANDMARK)
	box("HokageTower", "Entrance", Vector3(0, 0, -87), Vector3(10, 6, 4), C_ROOF)
	box("HokageTower", "Annex", Vector3(-28, 0, -110), Vector3(18, 12, 22), C_BLOCK)
	box("HokageTower", "Annex2", Vector3(28, 0, -110), Vector3(18, 12, 22), C_BLOCK)
	_reserve(-40, -125, 40, -58)

func _gate_and_wall() -> void:
	# A-Un gate: two pillars + crossbeam, guard booth just inside
	box("Gate", "PillarW", Vector3(-11, 0, WALL_R), Vector3(5, 24, 5), C_LANDMARK)
	box("Gate", "PillarE", Vector3(11, 0, WALL_R), Vector3(5, 24, 5), C_LANDMARK)
	box("Gate", "Beam", Vector3(0, 24, WALL_R), Vector3(30, 4, 6), C_LANDMARK)
	box("Gate", "DoorW", Vector3(-15, 0, WALL_R + 4), Vector3(8, 18, 1), C_ROOF, Vector3(0, deg_to_rad(-60), 0))
	box("Gate", "DoorE", Vector3(15, 0, WALL_R + 4), Vector3(8, 18, 1), C_ROOF, Vector3(0, deg_to_rad(60), 0))
	box("Gate", "GuardBooth", Vector3(20, 0, 158), Vector3(10, 4, 6), C_BLOCK)
	box("Gate", "GuardRoof", Vector3(20, 4, 158), Vector3(12, 0.6, 8), C_ROOF)
	_reserve(-25, 150, 30, 190)
	# village wall: a ring with the gate gap; the Hokage Rock closes the north side
	var segs := 72
	for i in segs:
		var a := TAU * float(i) / segs
		var p := Vector3(sin(a), 0, cos(a)) * WALL_R
		var seg_len := TAU * WALL_R / segs + 1.0
		if p.z > 0.0 and absf(p.x) < 14.0 + seg_len * 0.5:
			continue   # gate opening (closed up to the pillars below)
		if p.z < -120.0:
			continue   # Hokage Rock closes the north side (joined by the two walls below)
		box("Wall", "Wall%02d" % i, p, Vector3(seg_len, 14, 3), C_WALL, Vector3(0, a, 0))
	# short straight pieces joining the gate pillars to the ring
	var seg := TAU * WALL_R / segs + 1.0
	var reach := 14.0 + seg * 0.5   # first ring segment kept starts beyond this
	var a2 := asin((reach + seg * 0.5) / WALL_R)
	var x_end := WALL_R * sin(a2) - seg * 0.5 * cos(a2)
	for sx in [-1.0, 1.0]:
		var x0 := 13.5
		var mid := (x0 + x_end) * 0.5
		box("Wall", "GateWall%s" % ("W" if sx < 0 else "E"), Vector3(sx * mid, 0, sqrt(WALL_R * WALL_R - mid * mid)),
			Vector3(x_end - x0 + 1.0, 14, 3), C_WALL, Vector3(0, sx * asin(mid / WALL_R), 0))
	var jx := sqrt(WALL_R * WALL_R - 120.0 * 120.0)   # where the ring stops, straight walls to the cliff
	for sx in [-1.0, 1.0]:
		box("Wall", "CliffWall%s" % ("W" if sx < 0 else "E"), Vector3(sx * jx, 0, -143), Vector3(3, 14, 48), C_WALL)

func _academy() -> void:
	box("Academy", "Main", Vector3(-62, 0, -78), Vector3(42, 13, 14), C_LANDMARK)
	box("Academy", "Wing", Vector3(-88, 0, -66), Vector3(12, 11, 34), C_LANDMARK)
	box("Academy", "Roof", Vector3(-62, 13, -78), Vector3(44, 1, 16), C_ROOF)
	box("Academy", "Yard", Vector3(-62, 0, -56), Vector3(40, 0.06, 26), C_PLAZA, Vector3.ZERO, false)
	_tree(Vector3(-46, 0, -52))
	box("Academy", "SwingBranch", Vector3(-46, 4.5, -49.5), Vector3(0.3, 0.3, 4), C_TRUNK, Vector3.ZERO, false)
	box("Academy", "Swing", Vector3(-46, 1.2, -48.5), Vector3(1.2, 0.15, 0.5), C_ROOF, Vector3.ZERO, false)
	for i in 3:
		box("Academy", "Target%d" % i, Vector3(-75 + i * 6, 0, -48), Vector3(1.5, 1.8, 0.3), C_FACE)
	_reserve(-96, -88, -38, -44)

func _hospital() -> void:
	box("Hospital", "Main", Vector3(66, 0, -80), Vector3(40, 24, 22), C_LANDMARK)
	box("Hospital", "Wing", Vector3(66, 0, -62), Vector3(16, 10, 14), C_BLOCK)
	box("Hospital", "CrossA", Vector3(66, 24, -80), Vector3(12, 0.6, 3.5), C_ROOF)
	box("Hospital", "CrossB", Vector3(66, 24, -80), Vector3(3.5, 0.6, 12), C_ROOF)
	_reserve(42, -94, 90, -52)

func _ichiraku() -> void:
	box("Ichiraku", "Stall", Vector3(14, 0, 58), Vector3(8, 3.5, 5), C_LANDMARK)
	box("Ichiraku", "Awning", Vector3(14, 3.5, 56), Vector3(9, 0.4, 3), C_ROOF, Vector3(deg_to_rad(-12), 0, 0), false)
	box("Ichiraku", "Counter", Vector3(14, 0, 54.8), Vector3(8, 1.1, 1), C_ROOF)
	for i in 4:
		cyl("Ichiraku", "Stool%d" % i, Vector3(11 + i * 2, 0, 53.2), 0.35, 0.7, C_ROOF)
	box("Ichiraku", "House", Vector3(14, 0, 64), Vector3(12, 8, 8), C_BLOCK)
	_reserve(7, 52, 22, 69)

func _compound(group: String, c: Vector3, s: float, gate_south: bool) -> void:
	var h := s / 2.0
	var gap := 8.0
	box(group, "WallN", c + Vector3(0, 0, -h), Vector3(s, 4, 1), C_WALL)
	box(group, "WallW", c + Vector3(-h, 0, 0), Vector3(1, 4, s), C_WALL)
	box(group, "WallE", c + Vector3(h, 0, 0), Vector3(1, 4, s), C_WALL)
	var side := (s - gap) / 2.0
	box(group, "WallS1", c + Vector3(-h + side / 2.0, 0, h), Vector3(side, 4, 1), C_WALL)
	box(group, "WallS2", c + Vector3(h - side / 2.0, 0, h), Vector3(side, 4, 1), C_WALL)
	box(group, "GateBeam", c + Vector3(0, 4.5, h), Vector3(gap + 2, 1, 1.4), C_LANDMARK, Vector3.ZERO, false)
	_reserve(c.x - h - 2, c.z - h - 2, c.x + h + 2, c.z + h + 4)

func _hyuga() -> void:
	var c := Vector3(-112, 0, -6)
	_compound("Hyuga", c, 44.0, true)
	box("Hyuga", "MainHall", c + Vector3(0, 0, -8), Vector3(28, 7, 14), C_LANDMARK)
	box("Hyuga", "Roof", c + Vector3(0, 7, -8), Vector3(32, 1, 18), C_ROOF)
	box("Hyuga", "Dojo", c + Vector3(-12, 0, 12), Vector3(12, 5, 10), C_BLOCK)
	box("Hyuga", "Garden", c + Vector3(8, 0, 10), Vector3(16, 0.06, 12), C_LEAF, Vector3.ZERO, false)

func _uchiha() -> void:
	var c := Vector3(112, 0, 74)
	_compound("Uchiha", c, 54.0, true)
	box("Uchiha", "MainHouse", c + Vector3(0, 0, -14), Vector3(22, 8, 14), C_LANDMARK)
	box("Uchiha", "House1", c + Vector3(-16, 0, 8), Vector3(10, 6, 10), C_BLOCK)
	box("Uchiha", "House2", c + Vector3(16, 0, 8), Vector3(10, 6, 10), C_BLOCK)
	box("Uchiha", "Shrine", c + Vector3(18, 0, -18), Vector3(8, 5, 8), C_BLOCK2)
	box("Uchiha", "Pond", c + Vector3(-14, 0, -14), Vector3(10, 0.06, 8), C_WATER, Vector3.ZERO, false)

func _training_ground() -> void:
	var c := Vector3(-108, 0, 82)
	box("TrainingGround3", "Clearing", c, Vector3(46, 0.06, 40), Color(0.48, 0.53, 0.46), Vector3.ZERO, false)
	for i in 3:
		cyl("TrainingGround3", "Post%d" % (i + 1), c + Vector3(-6 + i * 6, 0, -4), 0.45, 2.2, C_TRUNK)
	box("TrainingGround3", "Memorial", c + Vector3(10, 0, -10), Vector3(2.5, 2.4, 0.8), C_FACE)
	cyl("TrainingGround3", "Stream", c + Vector3(-18, 0, 6), 5.0, 0.06, C_WATER, -1.0, false)
	for i in 14:
		var a := TAU * i / 14.0
		_tree(c + Vector3(cos(a) * 26.0, 0, sin(a) * 22.0) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)))
	_reserve(c.x - 30, c.z - 26, c.x + 30, c.z + 26)

func _river() -> void:
	# river across the south-east of the village, with an arched bridge on the south street
	box("River", "Water", Vector3(95, 0, 128), Vector3(150, 0.05, 12), C_WATER, Vector3.ZERO, false)
	box("River", "BankN", Vector3(95, 0, 121.5), Vector3(150, 0.5, 1), C_WALL)
	box("River", "BankS", Vector3(95, 0, 134.5), Vector3(150, 0.5, 1), C_WALL)
	for side in [-1.0, 1.0]:
		box("River", "Ramp%s" % ("N" if side < 0 else "S"), Vector3(70, 0.6, 128 + side * 5.0), Vector3(6, 0.4, 6.4),
			C_LANDMARK, Vector3(deg_to_rad(10.0 * side), 0, 0))
	box("River", "BridgeDeck", Vector3(70, 1.2, 128), Vector3(6, 0.4, 4), C_LANDMARK)
	for side in [-1.0, 1.0]:
		box("River", "Rail%s" % ("W" if side < 0 else "E"), Vector3(70 + side * 3.0, 1.6, 128), Vector3(0.3, 1, 15), C_LANDMARK, Vector3.ZERO, false)
	_reserve(18, 120, 175, 136)

func _filler_buildings() -> void:
	var step := 20.0
	var z := -140.0
	while z <= 160.0:
		var x := -160.0
		while x <= 160.0:
			var w := rng.randf_range(9, 15)
			var d := rng.randf_range(9, 15)
			var p := Vector3(x + rng.randf_range(-2, 2), 0, z + rng.randf_range(-2, 2))
			var r := Rect2(p.x - w / 2.0 - 2.0, p.z - d / 2.0 - 2.0, w + 4.0, d + 4.0)
			var inside := Vector2(p.x, p.z - 5.0).length() < WALL_R - 16.0 and not (p.z < -110.0 and absf(p.x) > 110.0)
			if inside and _free_spot(r) and rng.randf() > 0.12:
				_house(p, w, d)
				_reserved.append(r)
			x += step
		z += step

func _house(p: Vector3, w: float, d: float) -> void:
	var h := rng.randf_range(5, 10) if rng.randf() < 0.7 else rng.randf_range(12, 20)
	var n := "House_%d_%d" % [int(p.x), int(p.z)]
	var c := C_BLOCK if rng.randf() < 0.6 else C_BLOCK2
	box("Buildings", n, p, Vector3(w, h, d), c)
	box("Buildings", n + "_Roof", p + Vector3(0, h, 0), Vector3(w + 1, 0.6, d + 1), C_ROOF, Vector3.ZERO, false)
	if rng.randf() < 0.45:   # Konoha's round water tanks on the roofs
		cyl("Buildings", n + "_Tank", p + Vector3(rng.randf_range(-w, w) * 0.25, h + 0.6, rng.randf_range(-d, d) * 0.25),
			1.6, 2.6, C_ROOF, -1.0, false)

func _tree(p: Vector3) -> void:
	var n := "Tree_%d_%d_%d" % [int(p.x), int(p.y), int(p.z)]
	var h := rng.randf_range(6, 10)
	var trunk := cyl("Trees", n, p, 0.6, h, C_TRUNK)
	var leaves := SphereMesh.new()
	var r := rng.randf_range(3.2, 4.6)
	leaves.radius = r
	leaves.height = r * 1.6
	var mi := MeshInstance3D.new()
	mi.name = "Leaves"
	mi.mesh = leaves
	mi.material_override = _mat(C_LEAF)
	mi.position = Vector3(0, h / 2.0 + r * 0.4, 0)
	trunk.add_child(mi)

func _forest() -> void:
	var placed := 0
	var tries := 0
	while placed < 170 and tries < 2000:
		tries += 1
		var p := Vector3(rng.randf_range(-HALF + 6, HALF - 6), 0, rng.randf_range(-150, HALF - 6))
		var dist := Vector2(p.x, p.z).length()
		if dist < WALL_R + 8.0:
			continue
		if absf(p.x) < 16.0 and p.z > WALL_R:
			continue   # keep the road out of the gate clear
		_tree(p)
		placed += 1
	box("Roads", "GateRoad", Vector3(0, 0, WALL_R + 38), Vector3(12, 0.04, 76), C_ROAD, Vector3.ZERO, false)

func _bounds() -> void:
	for w in [[Vector3(HALF, 0, 0), Vector3(1, 120, HALF * 2)], [Vector3(-HALF, 0, 0), Vector3(1, 120, HALF * 2)],
			[Vector3(0, 0, HALF), Vector3(HALF * 2, 120, 1)], [Vector3(0, 0, -HALF), Vector3(HALF * 2, 120, 1)]]:
		var body := StaticBody3D.new()
		body.name = "Bound"
		body.position = (w[0] as Vector3) + Vector3(0, 60, 0)
		_group("Bounds").add_child(body, true)
		var cs := CollisionShape3D.new()
		cs.shape = _box_shape(w[1])
		body.add_child(cs)

## Where each villager stands (NpcSpawn markers - drag them in the editor). `face` = direction they look.
const NPC_SPOTS := {
	"elder": [Vector3(0, 0, -72), Vector3(0, 0, 1)],          # Hokage Tower plaza
	"kakashi": [Vector3(-10, 0, 47), Vector3(1, 0, 0)],       # crossroads, across from Ichiraku
	"trainer": [Vector3(-52, 0, -46), Vector3(0, 0, 1)],      # Academy yard
	"courier": [Vector3(12, 0, 150), Vector3(-1, 0, 0)],      # inside the main gate
	"scout": [Vector3(130, 0, 38), Vector3(-1, 0, 0)],        # east end of the cross street
	"hermit": [Vector3(0, 62.3, -178), Vector3(0, 0, 1)],     # lookout on top of the Hokage Rock
}

func _npcs() -> void:
	var g := _group("NPCs")
	for id in NPC_SPOTS:
		var path := "res://data/npcs/%s.tres" % id
		if not ResourceLoader.exists(path):
			continue
		var sp := NpcSpawn.new()
		sp.name = str(id).capitalize().replace(" ", "")
		sp.npc = load(path)
		sp.position = NPC_SPOTS[id][0]
		var f: Vector3 = NPC_SPOTS[id][1]
		sp.rotation.y = atan2(-f.x, -f.z)
		g.add_child(sp, true)

# ------------------------------------------------------------------ save
static func save_scene() -> int:
	var map := build()
	_own(map, map)
	var ps := PackedScene.new()
	var err := ps.pack(map)
	if err == OK:
		err = ResourceSaver.save(ps, OUT)
	map.free()
	return err

static func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)
