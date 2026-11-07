extends Node3D
## One scene, three modes (chosen in the menu through GameData.mode):
##   "kurama" - boss arena with Kurama      "fight" - village arena, endless trickle of shinobi
##   "world"  - empty open world with NPCs that hand out quests

const FIGHT_ENEMIES := 6      # how many shinobi are kept alive in "fight" mode

var player: Player
var hud: HUD
var spin: SpinMenu = null   # spins are on the main menu now (Customize)
var gmenu: GameMenu
var play_half := 246.0     # half-size of the playable area, used to keep teleports in bounds
var dialog: DialogBox
var quests: Quests
var kurama: Kurama
var mode := "fight"
var rng := RandomNumberGenerator.new()
var awarded_kills := 0
var respawn_timer := 1.0
var npcs := {}
var solids: Array[Rect2] = []  # building footprints (x/z) to keep spawns clear

func _ready() -> void:
	rng.seed = 1234
	Fx.setup_inputs()
	GameData.load_data()
	Enemy.time_scale = 1.0
	mode = GameData.mode
	play_half = 46.0 if mode == "fight" else (96.0 if mode == "kurama" else 246.0)
	match mode:
		"kurama":
			_build_kurama_arena()
		"world":
			_build_open_world()
		_:
			mode = "fight"
			_build_world()
	player = Player.new()
	player.position = Vector3(0, 1, 30) if mode == "kurama" else Vector3(0, 1, 0)
	add_child(player)
	hud = HUD.new()
	hud.mode = mode
	add_child(hud)
	hud.bind(player)
	gmenu = GameMenu.new()
	add_child(gmenu)
	gmenu.bind(player, self)
	if mode == "kurama":
		_start_kurama()
	elif mode == "world":
		_start_world()

func _process(delta: float) -> void:
	var over := player.is_dead or (mode == "kurama" and hud.victory)
	if over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if player.is_dead:
		return
	if mode != "kurama":
		while player.kills - awarded_kills >= 8:
			awarded_kills += 8
			_give_spins(1, "8 kills")
	if mode == "fight":
		_fight_spawner(delta)
	elif mode == "world":
		_world_interact()

func _give_spins(n: int, why: String) -> void:
	GameData.spins += n
	GameData.save()
	hud.toast("+%d Spin (%s) - spin at the main menu (Customize)" % [n, why])

# ---------------------------------------------------------------- Mode: FIGHT
func _fight_spawner(delta: float) -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= FIGHT_ENEMIES:
		respawn_timer = 1.5
		return
	respawn_timer -= delta
	if respawn_timer <= 0.0:
		respawn_timer = 1.5
		_spawn_enemy()

func _spawn_enemy() -> void:
	var e := Enemy.new()
	e.health = 60.0
	e.speed = 4.8
	e.damage = 8.0
	var pos := Vector3.ZERO
	for _t in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(18.0, 28.0)
		pos = player.global_position + Vector3(cos(a), 0, sin(a)) * r
		pos.x = clampf(pos.x, -45.0, 45.0)
		pos.z = clampf(pos.z, -36.0, 45.0)
		if not _blocked(pos, 1.0):
			break
	pos.y = 0.5
	e.position = pos
	add_child(e)

# ---------------------------------------------------------------- Mode: KURAMA
func _start_kurama() -> void:
	kurama = Kurama.new()
	kurama.position = Vector3(0, 0, -34)
	add_child(kurama)
	hud.boss = kurama
	kurama.defeated.connect(_on_kurama_defeated)
	kurama.enraged.connect(_on_kurama_enraged)
	player.spring.spring_length = 12.0      # pull the camera back for the giant
	hud.toast("KURAMA, THE NINE-TAILED BEAST")

func _on_kurama_enraged(phase: int) -> void:
	hud.toast("KURAMA IS ENRAGED!" if phase == 3 else "Kurama is getting serious...")

func _on_kurama_defeated() -> void:
	GameData.kurama_defeated = true
	GameData.spins += 5
	GameData.save()
	hud.victory = true
	hud.toast("Kurama defeated!  +5 spins")

func _build_kurama_arena() -> void:
	Vfx.build_environment(self, "inferno", Vector3(-32, -40, 0), 160.0)
	_ground(220.0, 400.0, Color(0.36, 0.28, 0.22))
	_boundary(100.0)
	var disc := CylinderMesh.new()   # scorched arena floor
	disc.top_radius = 55.0; disc.bottom_radius = 55.0; disc.height = 0.04
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc
	disc_mi.material_override = Vfx.ground_mat(Color(0.14, 0.1, 0.09), Color(0.22, 0.16, 0.13), Color(0.08, 0.05, 0.05), 1.3, 0.5)
	disc_mi.position = Vector3(0, 0.02, 0)
	add_child(disc_mi)
	Vfx.lava_cracks(self, 52.0, 46, 5)
	Vfx.ambient(self, "embers", Vector3(0, 0.5, 0), Vector3(70, 0.5, 70))
	var rr := RandomNumberGenerator.new()
	rr.seed = 31
	for i in 22:   # boulders to hide behind, none near the two start points
		var a := rr.randf() * TAU
		var r := rr.randf_range(30.0, 92.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < 14.0 and absf(p.z) > 22.0:
			continue
		var sz := Vector3(rr.randf_range(3, 8), rr.randf_range(2, 7), rr.randf_range(3, 8))
		_box(p + Vector3(0, sz.y / 2.0, 0), sz, Color(0.38, 0.32, 0.3).lerp(Color(0.25, 0.2, 0.2), rr.randf()))

# ---------------------------------------------------------------- Mode: OPEN WORLD
func _build_open_world() -> void:
	Vfx.build_environment(self, "day", Vector3(-48, -35, 0), 80.0)
	_ground(500.0, 800.0, Color(0.42, 0.62, 0.3))
	_boundary(250.0)
	Vfx.grass(self, 22000, 70.0, 11, Callable(), Color(0.1, 0.3, 0.1), Color(0.55, 0.8, 0.3))
	Vfx.flowers(self, 700, 70.0, 12, Callable())
	Vfx.ambient(self, "fireflies", Vector3(0, 1.6, 0), Vector3(60, 1.5, 60))

func _start_world() -> void:
	dialog = DialogBox.new()
	add_child(dialog)
	dialog.bind(player)
	quests = Quests.new()
	add_child(quests)
	for id in Quests.NPCS:
		var d: Dictionary = Quests.NPCS[id]
		var n := Npc.new()
		n.npc_id = id
		n.display_name = d["name"]
		n.body_color = d["color"]
		n.band_color = d["band"]
		n.greeting = d["greet"]
		n.position = d["pos"]
		add_child(n)
		npcs[id] = n
	quests.setup(player, hud, self)
	quests.changed.connect(_refresh_markers)
	_refresh_markers()

func _refresh_markers() -> void:
	var act := quests.active_def()
	for id in npcs:
		var n: Npc = npcs[id]
		var m := ""
		var col := Color(1.0, 0.9, 0.2)
		if not act.is_empty():
			if GameData.quest_state == "ready" and act["giver"] == id:
				m = "?"
			elif GameData.quest_state == "active" and act["type"] == "deliver" and act["target"] == id:
				m = "!"
				col = Color(0.4, 0.9, 1.0)
		elif quests.available_for(id) != "":
			m = "!"
		n.set_marker(m, col)

func _world_interact() -> void:
	if dialog.is_open:
		return
	var near: Npc = null
	var best := 4.5
	for id in npcs:
		var n: Npc = npcs[id]
		var d := player.global_position.distance_to(n.global_position)
		if d < best:
			best = d
			near = n
	hud.prompt_text = "[E]  Talk to %s" % near.display_name if near != null else ""
	if near != null and Input.is_action_just_pressed("interact") and not Input.is_action_pressed("kunai"):
		hud.prompt_text = ""
		_talk(near)

func _talk(npc: Npc) -> void:
	var id := npc.npc_id
	var act := quests.active_def()
	var none := Callable()
	if not act.is_empty():
		var is_ready := GameData.quest_state == "ready"
		if is_ready and act["giver"] == id:
			var rw := int(act["reward"])
			dialog.open(npc.display_name, str(act["turn"]),
				[["Complete quest  (+%d spin%s)" % [rw, "" if rw == 1 else "s"], quests.turn_in]])
		elif not is_ready and act["type"] == "deliver" and act["target"] == id:
			dialog.open(npc.display_name, str(act["deliver_text"]), [["Deliver the message", quests.deliver_done]])
		elif act["giver"] == id:
			dialog.open(npc.display_name, str(act["remind"]), [["Okay, I'm on it", none], ["Abandon quest", quests.abandon]])
		else:
			dialog.open(npc.display_name, npc.greeting, [["Goodbye", none]])
		return
	var qid := quests.available_for(id)
	if qid != "":
		var q: Dictionary = Quests.DEFS[qid]
		var rw2 := int(q["reward"])
		var txt := "%s\n\n[Quest: %s   Reward: %d spin%s]" % [q["offer"], q["title"], rw2, "" if rw2 == 1 else "s"]
		dialog.open(npc.display_name, txt, [["Accept quest", quests.accept.bind(qid)], ["Not now", none]])
	else:
		dialog.open(npc.display_name, npc.greeting + "\n\n(I have no more work for you right now.)", [["Goodbye", none]])

# ---------------------------------------------------------------- Shared world helpers
func _ground(collider: float, visual: float, col: Color) -> void:
	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(collider, 1, collider)
	gcol.shape = gshape
	gcol.position.y = -0.5
	ground.add_child(gcol)
	var plane := PlaneMesh.new()
	plane.size = Vector2(visual, visual)
	var gmi := MeshInstance3D.new()
	gmi.mesh = plane
	gmi.material_override = _ground_material(col)
	ground.add_child(gmi)
	add_child(ground)

func _ground_material(col: Color) -> ShaderMaterial:
	if mode == "kurama":
		return Vfx.ground_mat(Color(0.2, 0.15, 0.13), Color(0.3, 0.22, 0.18), Color(0.12, 0.08, 0.07), 1.0, 0.7)
	return Vfx.ground_mat(col.darkened(0.2), col.lightened(0.05), Color(0.62, 0.52, 0.34), 1.0, 0.45)

## Invisible walls so nobody walks off the map. `half` = half the playable size.
func _boundary(half: float) -> void:
	for w in [Vector3(0, 5, half + 1), Vector3(0, 5, -half - 1), Vector3(half + 1, 5, 0), Vector3(-half - 1, 5, 0)]:
		var wall := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = Vector3(half * 2.0, 30, 2) if absf(w.z) > 1.0 else Vector3(2, 30, half * 2.0)
		wc.shape = ws
		wall.position = w
		wall.add_child(wc)
		add_child(wall)

# ---------------------------------------------------------------- Village map
# A leaf-village style arena: walled ring of forest, main gate, red council
# tower, cliffs to the north, tiled-roof houses, water tower, market stalls.
const WALL_COL := Color(0.86, 0.8, 0.64)
const STONE := Color(0.63, 0.56, 0.49)
const WOOD := Color(0.45, 0.3, 0.18)
const ROOFS := [Color(0.85, 0.42, 0.18), Color(0.72, 0.2, 0.15), Color(0.25, 0.55, 0.55), Color(0.55, 0.62, 0.3), Color(0.9, 0.6, 0.25)]
const WALLS := [Color(0.95, 0.92, 0.84), Color(0.9, 0.84, 0.7), Color(0.82, 0.86, 0.88)]

func _build_world() -> void:
	Vfx.build_environment(self, "sunset", Vector3(-17, -35, 0), 70.0)

	# Ground, plaza and dirt roads (flat, no outline, one collider)
	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(100, 1, 100)
	gcol.shape = gshape
	gcol.position.y = -0.5
	ground.add_child(gcol)
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	var vg := MeshInstance3D.new()
	vg.mesh = plane
	vg.material_override = Vfx.ground_mat(Color(0.24, 0.46, 0.18), Color(0.42, 0.66, 0.24), Color(0.6, 0.5, 0.32), 1.0, 0.4)
	ground.add_child(vg)
	add_child(ground)
	var dirt := Color(0.76, 0.64, 0.46)
	var disc := CylinderMesh.new()
	disc.top_radius = 13.0; disc.bottom_radius = 13.0; disc.height = 0.04
	disc.radial_segments = 48
	var dmi := MeshInstance3D.new()
	dmi.mesh = disc
	dmi.material_override = _dirt_mat()
	dmi.position = Vector3(0, 0.02, 0)
	add_child(dmi)
	# paved inner plaza ring
	var paved := CylinderMesh.new()
	paved.top_radius = 6.5; paved.bottom_radius = 6.5; paved.height = 0.06
	paved.radial_segments = 48
	add_child(Fx._part(paved, Color(0.7, 0.66, 0.6), Vector3(0, 0.03, 0), false))
	var paved_ring := TorusMesh.new()
	paved_ring.inner_radius = 6.3; paved_ring.outer_radius = 6.7
	paved_ring.rings = 48; paved_ring.ring_segments = 4
	var pr := Fx._part(paved_ring, Color(0.45, 0.4, 0.36), Vector3(0, 0.06, 0), false)
	pr.scale = Vector3(1, 0.1, 1)
	add_child(pr)
	_flat(Vector3(0, 0, 31), Vector3(7, 0, 38), dirt)
	_flat(Vector3(0, 0, 4), Vector3(98, 0, 6), dirt)
	_flat(Vector3(0, 0, -14), Vector3(6, 0, 10), dirt)

	# Invisible outer boundary (kept from the original arena)
	for w in [Vector3(0, 5, 51), Vector3(0, 5, -51), Vector3(51, 5, 0), Vector3(-51, 5, 0)]:
		var wall := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = Vector3(100, 30, 2) if absf(w.z) > 1.0 else Vector3(2, 30, 100)
		wc.shape = ws
		wall.position = w
		wall.add_child(wc)
		add_child(wall)

	# Village wall with the main gate on the south side
	_box(Vector3(-27.5, 3.5, 49), Vector3(45, 7, 1.5), WALL_COL)
	_box(Vector3(27.5, 3.5, 49), Vector3(45, 7, 1.5), WALL_COL)
	_box(Vector3(49, 3.5, 0), Vector3(1.5, 7, 100), WALL_COL)
	_box(Vector3(-49, 3.5, 0), Vector3(1.5, 7, 100), WALL_COL)
	for x in [-6.0, 6.0]:
		_box(Vector3(x, 7, 49), Vector3(2.2, 14, 2.2), Color(0.3, 0.42, 0.3))
	_box(Vector3(0, 14.5, 49), Vector3(16, 1.6, 3), Color(0.3, 0.42, 0.3), false)
	_box(Vector3(0, 12.6, 49), Vector3(11, 2.2, 0.4), Color(0.92, 0.88, 0.75), false)
	_deco(BoxMesh.new(), Vector3(4.6, 11, 0.2), Color(0.25, 0.32, 0.25), Vector3(-3.2, 5.5, 46.5), 0.9)
	_deco(BoxMesh.new(), Vector3(4.6, 11, 0.2), Color(0.25, 0.32, 0.25), Vector3(3.2, 5.5, 46.5), -0.9)

	# Cliffs behind the village (north)
	var cr := RandomNumberGenerator.new()
	cr.seed = 77
	for i in 9:
		var x := -44.0 + i * 11.0 + cr.randf_range(-2, 2)
		var h := cr.randf_range(16, 24) - absf(x) * 0.12
		_box(Vector3(x, h / 2.0, -45.5 + cr.randf_range(-1, 1)), Vector3(13, h, 9), STONE.lerp(Color(0.5, 0.45, 0.4), cr.randf()))
	for i in 6:
		_box(Vector3(-30.0 + i * 12.0 + cr.randf_range(-2, 2), 2.0, -40.0), Vector3(7, 4, 4), STONE.darkened(0.1))

	# Red council tower
	_cyl(Vector3(0, 0, -24), 6.5, 10.0, Color(0.78, 0.2, 0.14))
	_cyl(Vector3(0, 10.0, -24), 7.2, 0.7, Color(0.55, 0.12, 0.1))
	_cyl(Vector3(0, 10.7, -24), 4.5, 3.0, Color(0.78, 0.2, 0.14))
	_cyl(Vector3(0, 13.7, -24), 5.0, 0.5, Color(0.55, 0.12, 0.1))
	_deco(BoxMesh.new(), Vector3(3, 4, 0.3), Color(0.3, 0.2, 0.12), Vector3(0, 2, -17.4))
	_deco(BoxMesh.new(), Vector3(2.4, 2.4, 0.3), Color(0.95, 0.92, 0.8), Vector3(0, 7.5, -17.5))

	# Houses in four districts, avoiding the plaza, roads and tower
	var hr := RandomNumberGenerator.new()
	hr.seed = 2024
	var tries := 0
	while tries < 400 and solids.size() < 42:
		tries += 1
		var p := Vector3(hr.randf_range(-44, 44), 0, hr.randf_range(-36, 44))
		var sz := Vector3(hr.randf_range(5, 9), hr.randf_range(3.5, 6), hr.randf_range(5, 8))
		if p.length() < 17.0 or absf(p.z - 4.0) < 5.5 + sz.z / 2.0 or (p.z > 0 and absf(p.x) < 5.5 + sz.x / 2.0):
			continue
		if absf(p.x) < 11.0 + sz.x / 2.0 and p.z < -12.0:
			continue
		if _blocked(p, maxf(sz.x, sz.z) / 2.0 + 1.5):
			continue
		_house(p, sz, hr)

	# Water tower, training posts, market stalls
	_water_tower(Vector3(-24, 0, -18))
	for i in 3:
		_cyl(Vector3(30.0 + i * 3.0, 0, 13.0), 0.35, 1.8, WOOD)
	_stall(Vector3(-10, 0, 15), Color(0.9, 0.3, 0.2))
	_stall(Vector3(10, 0, 15), Color(0.95, 0.85, 0.3))
	_stall(Vector3(16, 0, -6), Color(0.3, 0.6, 0.9))

	# The "leaves": a dense ring of huge trees outside the walls + a few inside
	var tr := RandomNumberGenerator.new()
	tr.seed = 9
	for i in 70:
		var a := TAU * i / 70.0 + tr.randf_range(-0.04, 0.04)
		var r := tr.randf_range(56, 72)
		_big_tree(Vector3(cos(a) * r, 0, sin(a) * r), tr.randf_range(14, 24), tr, false)
	var placed := 0
	while placed < 14:
		var p := Vector3(tr.randf_range(-45, 45), 0, tr.randf_range(-34, 45))
		if p.length() < 16.0 or absf(p.z - 4.0) < 5.0 or (p.z > 0 and absf(p.x) < 6.0) or _blocked(p, 3.0):
			continue
		_big_tree(p, tr.randf_range(6, 10), tr, true)
		placed += 1

	_decorate_village()

# Lanterns, torii, bushes, grass, flowers and drifting petals / fireflies (all purely visual)
func _decorate_village() -> void:
	var dr := RandomNumberGenerator.new()
	dr.seed = 404
	# lantern posts along the main roads
	for x in [-40.0, -30.0, -20.0, 20.0, 30.0, 40.0]:
		Vfx.lantern(self, Vector3(x, 0, 4.0 - 3.4))
		Vfx.lantern(self, Vector3(x + 6.0, 0, 4.0 + 3.4))
	for z in [14.0, 24.0, 34.0, 44.0]:
		Vfx.lantern(self, Vector3(-4.2, 0, z))
		Vfx.lantern(self, Vector3(4.2, 0, z - 5.0))
	# stone lanterns around the plaza
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		Vfx.stone_lantern(self, Vector3(cos(a) * 12.0, 0, sin(a) * 12.0))
	# torii in front of the council tower
	Vfx.torii(self, Vector3(0, 0, -10.5))
	# bushes next to buildings / walls
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 600:
		tries += 1
		var p := Vector3(dr.randf_range(-46, 46), 0, dr.randf_range(-38, 46))
		if p.length() < 14.0 or absf(p.z - 4.0) < 4.5 or (p.z > 0 and absf(p.x) < 5.0) or _blocked(p, 0.8):
			continue
		Vfx.bush(self, p, dr, dr.randf() < 0.3)
		placed += 1
	# grass + flowers everywhere except plaza, roads and buildings
	var keep := func(p: Vector3) -> bool:
		if p.length() < 12.5:
			return false
		if absf(p.z - 4.0) < 3.4:
			return false
		if p.z > 0.0 and absf(p.x) < 3.6:
			return false
		if p.z < -9.0 and p.z > -19.0 and absf(p.x) < 3.2:
			return false
		return not _blocked(p, 0.5)
	Vfx.grass(self, 20000, 47.0, 21, keep, Color(0.1, 0.3, 0.1), Color(0.58, 0.82, 0.3))
	Vfx.flowers(self, 900, 46.0, 22, keep)
	Vfx.ambient(self, "petals", Vector3(0, 16, 0), Vector3(50, 0.5, 50))
	Vfx.ambient(self, "fireflies", Vector3(0, 1.6, 0), Vector3(45, 1.5, 45))

func _blocked(p: Vector3, pad: float) -> bool:
	for r in solids:
		if r.grow(pad).has_point(Vector2(p.x, p.z)):
			return true
	return false

func _solid(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	add_child(b)
	solids.append(Rect2(pos.x - size.x / 2.0, pos.z - size.z / 2.0, size.x, size.z))
	return b

func _box(pos: Vector3, size: Vector3, col: Color, collide := true) -> void:
	var m := BoxMesh.new()
	m.size = size
	if collide:
		_solid(pos, size).add_child(Fx._part(m, col, Vector3.ZERO))
	else:
		add_child(Fx._part(m, col, pos))

var _dirt: ShaderMaterial = null

func _dirt_mat() -> ShaderMaterial:
	if _dirt == null:
		_dirt = Vfx.ground_mat(Color(0.66, 0.54, 0.38), Color(0.8, 0.68, 0.5), Color(0.55, 0.47, 0.36), 2.2, 0.8)
	return _dirt

func _flat(pos: Vector3, size: Vector3, _col: Color) -> void:
	var m := PlaneMesh.new()
	m.size = Vector2(size.x, size.z)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _dirt_mat()
	mi.position = pos + Vector3(0, 0.03, 0)
	add_child(mi)

func _deco(m: BoxMesh, size: Vector3, col: Color, pos: Vector3, yaw := 0.0) -> void:
	m.size = size
	var mi := Fx._part(m, col, pos)
	mi.rotation.y = yaw
	add_child(mi)

func _cyl(base: Vector3, r: float, h: float, col: Color) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r; m.bottom_radius = r; m.height = h
	m.radial_segments = 24 if r > 2.0 else 10
	var b := StaticBody3D.new()
	b.position = base + Vector3(0, h / 2.0, 0)
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r; s.height = h
	c.shape = s
	b.add_child(c)
	b.add_child(Fx._part(m, col, Vector3.ZERO))
	add_child(b)
	solids.append(Rect2(base.x - r, base.z - r, r * 2.0, r * 2.0))

func _house(p: Vector3, sz: Vector3, r: RandomNumberGenerator) -> void:
	var wall: Color = WALLS[r.randi() % WALLS.size()]
	var roof: Color = ROOFS[r.randi() % ROOFS.size()]
	var b := _solid(p + Vector3(0, sz.y / 2.0, 0), sz)
	var body := BoxMesh.new()
	body.size = sz
	b.add_child(Fx._part(body, wall, Vector3.ZERO))
	# Rounded barrel roof = a cylinder half-sunk into the top of the walls
	var rm := CylinderMesh.new()
	rm.top_radius = sz.z * 0.55; rm.bottom_radius = sz.z * 0.55; rm.height = sz.x + 0.6
	rm.radial_segments = 14
	var roof_mi := Fx._part(rm, roof, Vector3(0, sz.y / 2.0 - sz.z * 0.25, 0))
	roof_mi.rotation.z = PI / 2.0
	roof_mi.scale = Vector3(0.55, 1, 1)  # flatten the barrel (local X = up after rotation)
	b.add_child(roof_mi)
	var face := 1.0 if p.z < 4.0 else -1.0  # doors face the main road
	var door := BoxMesh.new()
	door.size = Vector3(1.2, 2.0, 0.1)
	b.add_child(Fx._part(door, WOOD, Vector3(r.randf_range(-sz.x * 0.3, sz.x * 0.3), 1.0 - sz.y / 2.0, face * (sz.z / 2.0 + 0.05))))
	var win := BoxMesh.new()
	win.size = Vector3(sz.x * 0.6, 0.7, 0.1)
	b.add_child(Fx._part(win, Color(0.3, 0.45, 0.55), Vector3(0, sz.y * 0.2, face * (sz.z / 2.0 + 0.05)), false))
	var band := BoxMesh.new()
	band.size = Vector3(sz.x + 0.1, 0.35, sz.z + 0.1)
	b.add_child(Fx._part(band, roof.darkened(0.25), Vector3(0, sz.y / 2.0 - 0.2, 0), false))
	if r.randf() < 0.35:  # second storey
		var up := BoxMesh.new()
		up.size = sz * Vector3(0.55, 0.7, 0.6)
		b.add_child(Fx._part(up, wall, Vector3(-sz.x * 0.15, sz.y / 2.0 + up.size.y / 2.0, 0)))
		var cap := BoxMesh.new()
		cap.size = up.size * Vector3(1.15, 0.12, 1.15)
		b.add_child(Fx._part(cap, roof, Vector3(-sz.x * 0.15, sz.y / 2.0 + up.size.y, 0)))
		var uc := CollisionShape3D.new()
		var us := BoxShape3D.new()
		us.size = up.size
		uc.shape = us
		uc.position = Vector3(-sz.x * 0.15, sz.y / 2.0 + up.size.y / 2.0, 0)
		b.add_child(uc)

func _water_tower(p: Vector3) -> void:
	for o in [Vector3(-1.6, 0, -1.6), Vector3(1.6, 0, -1.6), Vector3(-1.6, 0, 1.6), Vector3(1.6, 0, 1.6)]:
		_cyl(p + o, 0.25, 9.0, WOOD)
	var tank := CylinderMesh.new()
	tank.top_radius = 3.0; tank.bottom_radius = 3.0; tank.height = 4.0
	add_child(Fx._part(tank, Color(0.82, 0.78, 0.7), p + Vector3(0, 11, 0)))
	var top := CylinderMesh.new()
	top.top_radius = 0.2; top.bottom_radius = 3.4; top.height = 1.6
	add_child(Fx._part(top, Color(0.72, 0.2, 0.15), p + Vector3(0, 13.8, 0)))

func _stall(p: Vector3, cloth: Color) -> void:
	_box(p + Vector3(0, 0.55, 0), Vector3(4, 1.1, 1.6), WOOD)
	for x in [-1.9, 1.9]:
		var post := BoxMesh.new()
		post.size = Vector3(0.15, 2.8, 0.15)
		add_child(Fx._part(post, WOOD, p + Vector3(x, 1.4, -0.7)))
	var awn := BoxMesh.new()
	awn.size = Vector3(4.6, 0.15, 2.4)
	var a := Fx._part(awn, cloth, p + Vector3(0, 2.8, 0.1))
	a.rotation.x = 0.25
	add_child(a)
	for i in 4:  # hanging cloth strips
		var strip := BoxMesh.new()
		strip.size = Vector3(1.0, 0.8, 0.04)
		add_child(Fx._part(strip, cloth.lightened(0.3), p + Vector3(-1.65 + i * 1.1, 2.25, 1.3), false))

func _big_tree(pos: Vector3, h: float, r: RandomNumberGenerator, collide: bool) -> void:
	var tree: Node3D = StaticBody3D.new() if collide else Node3D.new()
	tree.position = pos
	var rad := h * 0.06
	if collide:
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = rad; cs.height = h
		col.shape = cs
		col.position.y = h / 2.0
		tree.add_child(col)
		solids.append(Rect2(pos.x - rad, pos.z - rad, rad * 2.0, rad * 2.0))
	var trunk := CylinderMesh.new()
	trunk.top_radius = rad * 0.7; trunk.bottom_radius = rad; trunk.height = h
	trunk.radial_segments = 8
	tree.add_child(Fx._part(trunk, Color(0.42, 0.28, 0.16), Vector3(0, h / 2.0, 0)))
	var blossom := collide and r.randf() < 0.55   # cherry-blossom tree
	for i in 4:  # stacked leaf clumps
		var crown := SphereMesh.new()
		var cr := h * (0.34 - i * 0.06)
		crown.radius = cr; crown.height = cr * 1.5
		crown.radial_segments = 12; crown.rings = 7
		var g := Color(0.16, 0.45, 0.2).lerp(Color(0.3, 0.6, 0.22), r.randf())
		if blossom:
			g = Color(0.96, 0.62, 0.74).lerp(Color(1.0, 0.82, 0.88), r.randf())
		tree.add_child(Fx._part(crown, g, Vector3(r.randf_range(-0.9, 0.9), h * (0.6 + i * 0.13), r.randf_range(-0.9, 0.9))))
	add_child(tree)
