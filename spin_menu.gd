class_name SpinMenu
extends CanvasLayer
## Shinobi Life style bloodline customization (press B).
## - 4 bloodline slots on two scrolls (1 & 3 left, 2 & 4 right). Slots 1-2 are open, 3-4 cost spins.
## - "CLICK TO SPIN" rolls THAT slot only and replaces what it held (Epic+ asks for a second click).
## - EQUIP picks which slot's bloodline you use in combat.
## - Auto-spin rerolls the active slot until it hits the chosen rarity or you run out of spins.
## Bloodline odds/stats live in bloodline.gd, slot data and pity in gamedata.gd.

const INK := Color(0.12, 0.1, 0.07)
const PAPER := Color(0.86, 0.82, 0.66)
const GREEN := Color(0.05, 0.5, 0.24)
const AUTO_TARGETS := ["Rare", "Epic", "Legendary"]
const SLOT_TITLES := ["BLOODLINE SLOT #1", "BLOODLINE SLOT #2", "BLOODLINE SLOT #3", "BLOODLINE SLOT #4"]

## Octagon badge for a bloodline (or a red padlock for a locked slot).
class Emblem extends Control:
	const RARITY_COLORS := {
		"Common": Color(0.78, 0.78, 0.78), "Rare": Color(0.35, 0.62, 1.0),
		"Epic": Color(0.72, 0.4, 1.0), "Legendary": Color(1.0, 0.8, 0.2)}
	var id := "none":
		set(v):
			id = v
			queue_redraw()
	var locked := false:
		set(v):
			locked = v
			queue_redraw()
	var active := false:
		set(v):
			active = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _oct(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 8:
			var a := deg_to_rad(22.5 + 45.0 * k)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 4.0
		if locked:
			var red := Color(0.78, 0.18, 0.15)
			var dark := Color(0.45, 0.06, 0.05)
			draw_arc(c + Vector2(0, -r * 0.18), r * 0.42, PI, TAU, 24, dark, r * 0.18)
			draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 0.2), Vector2(r * 1.32, r * 1.05)), red)
			draw_colored_polygon(_oct(c + Vector2(0, r * 0.3), r * 0.3), dark)
			return
		var rc: Color = RARITY_COLORS.get(str(Bloodline.get_def(id)["rarity"]), Color.GRAY) if id != "none" else Color(0.4, 0.4, 0.4)
		var fill: Color = Bloodline.get_def(id)["color"] if id != "none" else Color(0.25, 0.24, 0.22)
		if active:
			var glow := _oct(c, r + 3.0)
			glow.append(glow[0])
			draw_polyline(glow, Color(1.0, 0.92, 0.4), 4.0)
		draw_colored_polygon(_oct(c, r), Color(0.07, 0.06, 0.05))
		draw_colored_polygon(_oct(c, r * 0.8), fill.darkened(0.2))
		var ring := _oct(c, r * 0.9)
		ring.append(ring[0])
		draw_polyline(ring, rc, 3.0)
		var letter := "?" if id == "none" else str(Bloodline.get_def(id)["name"]).substr(0, 1)
		var f := ThemeDB.fallback_font
		var fs := int(r * 0.95)
		var pos := Vector2(0, c.y + fs * 0.36)
		draw_string_outline(f, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 6, Color.BLACK)
		draw_string(f, pos, letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)

var p: Player
var root: Control
var spins_label: Label
var pity_label: Label
var info_name: Label
var info_desc: Label
var element_label: Label
var element_btn: Button
var auto_pick: OptionButton
var auto_btn: Button
var odds_panel: Panel
var banner: Label
var flash: ColorRect
var close_btn: Button
var slot_ui: Array = []          # one Dictionary per slot
var preview_viewport: SubViewport
var preview_model: Node3D

var spinning := false            # a reel is animating
var auto_running := false
var auto_stop := false
var confirm_slot := -1           # slot waiting for a second click before replacing an Epic+
var confirm_token := 0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dojo-ish backdrop: dark wood with a lighter floor band.
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.11, 0.08, 0.98)
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var floor_band := ColorRect.new()
	floor_band.color = Color(0.42, 0.34, 0.25, 0.9)
	root.add_child(floor_band)
	floor_band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floor_band.anchor_top = 0.62
	for k in 7:
		var plank := ColorRect.new()
		plank.color = Color(0.3, 0.23, 0.16, 0.6)
		root.add_child(plank)
		plank.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plank.anchor_top = 0.62 + k * 0.055
		plank.anchor_bottom = plank.anchor_top
		plank.offset_bottom = 2

	# Top bar: spins (left) and odds (right).
	spins_label = _ribbon_label(root, "", 22)
	spins_label.position = Vector2(20, 12)
	spins_label.size = Vector2(230, 40)
	var odds_btn := _ribbon_button(root, "[ ODDS ]", 16)
	odds_btn.anchor_left = 1
	odds_btn.anchor_right = 1
	odds_btn.offset_left = -250
	odds_btn.offset_right = -20
	odds_btn.offset_top = 12
	odds_btn.offset_bottom = 52
	odds_btn.pressed.connect(func(): odds_panel.visible = not odds_panel.visible)

	# The two scrolls: slots 1 & 3 on the left, 2 & 4 on the right.
	var left := _make_scroll(false)
	var right := _make_scroll(true)
	slot_ui.resize(GameData.SLOT_COUNT)
	slot_ui[0] = _build_slot(left, 0, 24)
	slot_ui[2] = _build_slot(left, 2, 322)
	slot_ui[1] = _build_slot(right, 1, 24)
	slot_ui[3] = _build_slot(right, 3, 322)

	# Centre: character preview.
	var char_tag := _ribbon_label(root, "[ CHARACTER ]", 15)
	_center_h(char_tag, 180, 64)
	char_tag.size.y = 28
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(480, 380)
	preview_viewport.transparent_bg = true
	preview_viewport.own_world_3d = true
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.add_child(preview_viewport)
	root.add_child(vpc)
	_center_h(vpc, 480, 96)
	vpc.size.y = 380
	_setup_preview()

	# Active bloodline card under the character.
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", _box(Color(0.05, 0.04, 0.03, 0.88), Color(0.75, 0.62, 0.3), 2))
	root.add_child(card)
	_center_h(card, 560, 478)
	card.size.y = 92
	info_name = _label(card, "", 24, Color.WHITE)
	info_name.position = Vector2(10, 6)
	info_name.size = Vector2(540, 32)
	info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_desc = _label(card, "", 13, Color(0.92, 0.88, 0.78))
	info_desc.position = Vector2(14, 38)
	info_desc.size = Vector2(532, 50)
	info_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Elements + auto-spin row.
	element_label = _label(root, "", 14, Color(1.0, 0.92, 0.7))
	_center_h(element_label, 560, 578)
	element_label.size.y = 22
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	element_btn = _ribbon_button(root, "", 13)
	_center_h(element_btn, 180, 604, -190)
	element_btn.size.y = 34
	element_btn.pressed.connect(_on_element_spin)
	auto_pick = OptionButton.new()
	for t in AUTO_TARGETS:
		auto_pick.add_item("Stop at %s%s" % [t, "" if t == "Legendary" else "+"])
	auto_pick.select(AUTO_TARGETS.size() - 1)
	auto_pick.add_theme_font_size_override("font_size", 13)
	root.add_child(auto_pick)
	_center_h(auto_pick, 170, 604, 0)
	auto_pick.size.y = 34
	auto_btn = _ribbon_button(root, "", 13)
	_center_h(auto_btn, 180, 604, 190)
	auto_btn.size.y = 34
	auto_btn.pressed.connect(_on_auto)
	pity_label = _label(root, "", 13, Color(0.95, 0.85, 0.6))
	_center_h(pity_label, 560, 642)
	pity_label.size.y = 20
	pity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	close_btn = _ribbon_button(root, "COMPLETE CUSTOMIZATION", 17)
	_center_h(close_btn, 340, 668)
	close_btn.size.y = 42
	close_btn.pressed.connect(toggle)

	_build_odds_panel()

	# Reveal effects (on top of everything, never block clicks).
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner = _label(root, "", 40, Color.WHITE)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("outline_size", 10)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_h(banner, 900, 250)
	banner.size.y = 110
	banner.pivot_offset = Vector2(450, 55)
	banner.modulate.a = 0.0

	root.visible = false

# ------------------------------------------------------------------ building blocks
func _make_scroll(right_side: bool) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _box(PAPER, Color(0.55, 0.45, 0.25), 3))
	root.add_child(panel)
	if right_side:
		panel.anchor_left = 1
		panel.anchor_right = 1
		panel.offset_left = -250
		panel.offset_right = -20
	else:
		panel.offset_left = 20
		panel.offset_right = 250
	panel.offset_top = 64
	panel.offset_bottom = 700
	for y in [4.0, 610.0]:
		var band := ColorRect.new()
		band.color = GREEN
		band.position = Vector2(4, y)
		band.size = Vector2(222, 18)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(band)
	return panel

func _build_slot(panel: Panel, i: int, y: float) -> Dictionary:
	var title := _ribbon_label(panel, SLOT_TITLES[i], 12)
	title.position = Vector2(15, y + 6)
	title.size = Vector2(200, 26)
	var em := Emblem.new()
	em.position = Vector2(69, y + 38)
	em.size = Vector2(92, 92)
	em.pivot_offset = em.size / 2.0
	panel.add_child(em)
	var nm := _label(panel, "", 18, INK, 0)
	nm.position = Vector2(5, y + 132)
	nm.size = Vector2(220, 26)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rar := _label(panel, "", 14, INK, 0)
	rar.position = Vector2(5, y + 156)
	rar.size = Vector2(220, 20)
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spin := _ribbon_button(panel, "", 12)
	spin.position = Vector2(20, y + 182)
	spin.size = Vector2(190, 34)
	spin.pressed.connect(_on_slot_pressed.bind(i))
	var eq := _ribbon_button(panel, "", 12)
	eq.position = Vector2(45, y + 222)
	eq.size = Vector2(140, 28)
	eq.pressed.connect(_on_equip.bind(i))
	return {"emblem": em, "name": nm, "rarity": rar, "spin": spin, "equip": eq}

func _build_odds_panel() -> void:
	odds_panel = Panel.new()
	odds_panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.04, 0.03, 0.96), Color(0.75, 0.62, 0.3), 2))
	root.add_child(odds_panel)
	odds_panel.anchor_left = 1
	odds_panel.anchor_right = 1
	odds_panel.offset_left = -560
	odds_panel.offset_right = -260
	odds_panel.offset_top = 12
	var total := 0.0
	var by_rarity := {}
	for id in Bloodline.DEFS:
		var w := float(Bloodline.DEFS[id]["weight"])
		total += w
		var r: String = Bloodline.DEFS[id]["rarity"]
		by_rarity[r] = float(by_rarity.get(r, 0.0)) + w
	var lines: Array[String] = ["BLOODLINE ODDS", ""]
	for r in GameData.RARITY_ORDER:
		lines.append("%s  -  %.1f%%" % [r, 100.0 * float(by_rarity.get(r, 0.0)) / total])
	lines.append("")
	for id in Bloodline.DEFS:
		var w2 := float(Bloodline.DEFS[id]["weight"])
		if w2 > 0.0:
			lines.append("%s  (%s)  %.1f%%" % [Bloodline.DEFS[id]["name"], Bloodline.DEFS[id]["rarity"], 100.0 * w2 / total])
	lines.append("")
	lines.append("Guaranteed Legendary within %d spins." % GameData.PITY_LIMIT)
	lines.append("Pity is shared by all slots.")
	var l := _label(odds_panel, "\n".join(PackedStringArray(lines)), 13, Color(0.95, 0.9, 0.78))
	l.position = Vector2(14, 10)
	l.size = Vector2(272, 20)
	odds_panel.offset_bottom = 12 + 24 + lines.size() * 21
	odds_panel.visible = false

func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(3)
	return s

func _label(parent: Node, text: String, size: int, color: Color, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", outline)
	parent.add_child(l)
	return l

## Black "brush stroke" label like the reference UI.
func _ribbon_label(parent: Node, text: String, size: int) -> Label:
	var l := _label(parent, text, size, Color.WHITE, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var sb := _box(Color(0.03, 0.03, 0.03, 0.92), Color(0, 0, 0, 0), 0)
	sb.skew = Vector2(0.15, 0)
	l.add_theme_stylebox_override("normal", sb)
	return l

func _ribbon_button(parent: Node, text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.4))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	var normal := _box(Color(0.03, 0.03, 0.03, 0.92), Color(0, 0, 0, 0), 0)
	normal.skew = Vector2(0.15, 0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.35, 0.05, 0.05, 0.95)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.55, 0.08, 0.06, 0.95)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b

## Centres a control horizontally (width w) at a fixed top y, shifted by dx.
func _center_h(c: Control, w: float, top: float, dx := 0.0) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.offset_left = dx - w / 2.0
	c.offset_right = dx + w / 2.0
	c.offset_top = top
	c.offset_bottom = top + 30

# ------------------------------------------------------------------ preview
func _setup_preview() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.72, 0.66)
	environment.ambient_light_energy = 0.9
	env.environment = environment
	preview_viewport.add_child(env)
	var camera := Camera3D.new()
	preview_viewport.add_child(camera)
	camera.fov = 50.0
	camera.look_at_from_position(Vector3(0, 1.05, 3.1), Vector3(0, 0.9, 0), Vector3.UP)
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_energy = 1.5
	preview_viewport.add_child(key)
	_replace_preview_model()

func _replace_preview_model() -> void:
	if preview_model != null and is_instance_valid(preview_model):
		if preview_model.get_parent() == preview_viewport:
			preview_viewport.remove_child(preview_model)
		preview_model.queue_free()
	# A fresh model, not p.model.duplicate(): a duplicate would keep pointing at the
	# player's own AnimationPlayer through its metadata.
	preview_model = Hero.create()
	if preview_model == null:
		preview_model = Fx.make_ninja(Color(0.9, 0.75, 0.55), Color(0.1, 0.1, 0.16))
	preview_model.position = Vector3.ZERO
	preview_model.rotation.y = PI   # face the camera
	preview_viewport.add_child(preview_model)
	if preview_model.has_meta("anim_player"):
		Hero.play(preview_model, "idle", true)

func _process(delta: float) -> void:
	if root.visible and preview_model != null and is_instance_valid(preview_model):
		preview_model.rotate_y(delta * 0.35)

# ------------------------------------------------------------------ open / close
func bind(player: Player) -> void:
	p = player
	if preview_viewport != null:
		_replace_preview_model()

func _unhandled_input(event: InputEvent) -> void:
	var gm = get_parent().get("gmenu")
	if gm != null and gm.is_open:
		return
	if event.is_action_pressed("spin_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif root.visible and event.is_action_pressed("pause"):
		if odds_panel.visible:
			odds_panel.visible = false
		else:
			toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if spinning or auto_running:
		return
	root.visible = not root.visible
	get_tree().paused = root.visible
	odds_panel.visible = false
	confirm_slot = -1
	if root.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh()
	else:
		if p and not p.is_dead:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ------------------------------------------------------------------ refresh
func _rarity_color(id: String) -> Color:
	if id == "none":
		return INK
	return Emblem.RARITY_COLORS.get(str(Bloodline.get_def(id)["rarity"]), INK)

## Darker rarity tints that stay readable on the paper scrolls.
func _paper_color(id: String) -> Color:
	match str(Bloodline.get_def(id)["rarity"]) if id != "none" else "":
		"Common": return Color(0.32, 0.3, 0.27)
		"Rare": return Color(0.1, 0.3, 0.78)
		"Epic": return Color(0.45, 0.14, 0.72)
		"Legendary": return Color(0.72, 0.48, 0.0)
	return INK

func _refresh() -> void:
	var busy := spinning or auto_running
	spins_label.text = "[ %d Spin%s ]" % [GameData.spins, "" if GameData.spins == 1 else "s"]
	for i in GameData.SLOT_COUNT:
		var ui: Dictionary = slot_ui[i]
		var em: Emblem = ui["emblem"]
		var nm: Label = ui["name"]
		var rar: Label = ui["rarity"]
		var spin: Button = ui["spin"]
		var eq: Button = ui["equip"]
		if not GameData.slot_unlocked[i]:
			var cost: int = GameData.SLOT_UNLOCK_COST[i]
			em.locked = true
			em.active = false
			nm.text = "LOCKED"
			rar.text = "Costs %d spins to open" % cost
			rar.add_theme_color_override("font_color", Color(0.75, 0.2, 0.15))
			spin.text = "[ UNLOCK - %d SPINS ]" % cost
			spin.disabled = busy or GameData.spins < cost
			eq.visible = false
			continue
		var id := str(GameData.slots[i])
		var d := Bloodline.get_def(id)
		em.locked = false
		em.id = id
		em.active = i == GameData.active_slot
		nm.text = "EMPTY" if id == "none" else str(d["name"])
		rar.text = "Spin to awaken" if id == "none" else str(d["rarity"]).to_upper()
		rar.add_theme_color_override("font_color", _paper_color(id))
		spin.text = "[ CLICK TO SPIN ]" if confirm_slot != i else "[ REPLACE %s? ]" % str(d["name"]).to_upper()
		spin.disabled = busy or GameData.spins <= 0
		eq.visible = true
		eq.text = "ACTIVE" if i == GameData.active_slot else "EQUIP"
		eq.disabled = busy or i == GameData.active_slot
	var a := GameData.equipped
	var ad := Bloodline.get_def(a)
	info_name.text = "Slot #%d  -  %s" % [GameData.active_slot + 1, "No Bloodline" if a == "none" else str(ad["name"])]
	info_name.add_theme_color_override("font_color", Color.WHITE if a == "none" else _rarity_color(a))
	info_desc.text = ad["desc"] if a == "none" else "[%s]  %s" % [ad["rarity"], ad["desc"]]
	element_label.text = "[ ELEMENTS ]   Equipped: %s   •   Owned: %s" % [
		GameData.equipped_element, ", ".join(PackedStringArray(GameData.owned_elements))]
	element_btn.text = "SPIN ELEMENT (%d)" % GameData.element_spins
	element_btn.disabled = busy or GameData.element_spins <= 0
	auto_pick.disabled = auto_running or spinning
	if auto_running:
		auto_btn.text = "STOP AUTO"
		auto_btn.disabled = false
	else:
		auto_btn.text = "AUTO SPIN SLOT #%d" % (GameData.active_slot + 1)
		auto_btn.disabled = spinning or GameData.spins <= 0
	close_btn.disabled = busy
	pity_label.text = "Legendary pity: %d / %d   •   Lifetime spins: %d" % [
		GameData.pity, GameData.PITY_LIMIT, GameData.total_spins_used]

# ------------------------------------------------------------------ actions
func _on_equip(i: int) -> void:
	if spinning or auto_running:
		return
	if GameData.set_active_slot(i):
		confirm_slot = -1
		if p:
			p.apply_bloodline()
		Sfx.play(self, "poof", -6.0)
		_refresh()

func _on_slot_pressed(i: int) -> void:
	if spinning or auto_running:
		return
	if not GameData.slot_unlocked[i]:
		if GameData.unlock_slot(i):
			Sfx.play(self, "power")
			_show_banner("SLOT #%d UNLOCKED!" % (i + 1), Color(1.0, 0.9, 0.5), false)
		_refresh()
		return
	if GameData.spins <= 0:
		_show_banner("NO SPINS LEFT", Color(0.9, 0.3, 0.25), false)
		return
	# Protect good rolls: Epic / Legendary need a second click within 2.5s.
	if GameData.rarity_rank(str(GameData.slots[i])) >= 2 and confirm_slot != i:
		confirm_slot = i
		confirm_token += 1
		var token := confirm_token
		_refresh()
		await get_tree().create_timer(2.5, true, false, true).timeout
		if confirm_token == token and confirm_slot == i:
			confirm_slot = -1
			_refresh()
		return
	confirm_slot = -1
	await _spin_slot(i, false)

## Rolls slot i with the reel animation. Returns the id won ("" if nothing was spun).
func _spin_slot(i: int, fast: bool) -> String:
	var id := GameData.roll_slot(i)
	if id == "":
		return ""
	var is_new := GameData.last_new
	spinning = true
	_refresh()
	var ui: Dictionary = slot_ui[i]
	var em: Emblem = ui["emblem"]
	var nm: Label = ui["name"]
	var rar: Label = ui["rarity"]
	var pool: Array = Bloodline.DEFS.keys()
	pool.erase("none")
	var steps := 9 if fast else 24
	var last := ""
	for k in steps:
		var rid: String = pool[randi() % pool.size()]
		if rid == last:
			rid = pool[(pool.find(rid) + 1) % pool.size()]
		last = rid
		em.id = rid
		nm.text = str(Bloodline.get_def(rid)["name"])
		rar.text = "..."
		rar.add_theme_color_override("font_color", INK)
		if k % 2 == 0:
			Sfx.play(self, "throw", -16.0)
		var t := (0.025 + k * 0.004) if fast else (0.035 + k * k * 0.0007)
		await get_tree().create_timer(t, true, false, true).timeout
	spinning = false
	if i == GameData.active_slot and p:
		p.apply_bloodline()
	_refresh()
	_reveal(i, id, is_new, fast)
	return id

func _reveal(i: int, id: String, is_new: bool, fast: bool) -> void:
	var ui: Dictionary = slot_ui[i]
	var em: Emblem = ui["emblem"]
	var rar: Label = ui["rarity"]
	var d := Bloodline.get_def(id)
	var rank := GameData.rarity_rank(id)
	var col := _rarity_color(id)
	if is_new:
		rar.text += "  •  NEW!"
	em.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(em, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "power" if rank >= 2 else "poof", 0.0 if rank >= 2 else -6.0)
	if rank >= 2:
		flash.color = Color(col.r, col.g, col.b, 0.55 if rank == 3 else 0.35)
		var ft := create_tween()
		ft.tween_property(flash, "color:a", 0.0, 0.6 if rank == 3 else 0.4)
	if rank >= 1 and not fast:
		var head := "LEGENDARY!" if rank == 3 else ("EPIC!" if rank == 2 else "RARE")
		_show_banner("%s\n%s%s" % [head, d["name"], "  (NEW)" if is_new else ""], col, rank == 3)

func _show_banner(text: String, col: Color, big: bool) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.add_theme_font_size_override("font_size", 46 if big else 34)
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4 if big else 0.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)

func _on_auto() -> void:
	if auto_running:
		auto_stop = true
		return
	if spinning:
		return
	var slot := GameData.active_slot
	var target := GameData.RARITY_ORDER.find(AUTO_TARGETS[auto_pick.selected])
	var current := str(GameData.slots[slot])
	if GameData.rarity_rank(current) >= target:
		_show_banner("Slot #%d already has %s\nspin it by hand to replace it" % [slot + 1, Bloodline.get_def(current)["name"]],
			Color(1.0, 0.85, 0.5), false)
		return
	auto_running = true
	auto_stop = false
	confirm_slot = -1
	_refresh()
	var got := ""
	while not auto_stop and GameData.spins > 0:
		got = await _spin_slot(slot, true)
		if got == "" or GameData.rarity_rank(got) >= target:
			break
		await get_tree().create_timer(0.18, true, false, true).timeout
	auto_running = false
	_refresh()
	if got != "" and GameData.rarity_rank(got) >= target:
		var d := Bloodline.get_def(got)
		_show_banner("%s!\n%s" % [str(d["rarity"]).to_upper(), d["name"]], _rarity_color(got), d["rarity"] == "Legendary")
	elif GameData.spins <= 0:
		_show_banner("OUT OF SPINS", Color(0.9, 0.3, 0.25), false)

func _on_element_spin() -> void:
	if spinning or auto_running or GameData.element_spins <= 0:
		return
	spinning = true
	_refresh()
	var result := GameData.roll_element()
	for k in 12:
		var e: String = GameData.ELEMENTS[randi() % GameData.ELEMENTS.size()]
		element_label.text = "[ ELEMENTS ]   %s ..." % e
		element_label.add_theme_color_override("font_color", GameData.get_element_color(e))
		await get_tree().create_timer(0.04 + k * 0.01, true, false, true).timeout
	element_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	spinning = false
	_refresh()
	Sfx.play(self, "fire", -4.0)
	_show_banner("%s STYLE!" % result.to_upper(), GameData.get_element_color(result), false)
