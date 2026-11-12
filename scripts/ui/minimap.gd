class_name Minimap
extends Control
## Round minimap, top-right. The map is photographed once from above when the world has loaded
## (no second live render - cheap on the GPU); the minimap shows a circle of it around you,
## turning with your camera, with dots on top: you (arrow), other players (blue), enemies (red),
## villagers with errands (yellow !) and your quest target (gold star, pinned to the rim when far).

const SIZE := 190.0
const VIEW := 70.0          # metres from the centre to the rim
const SHOT := 1024          # snapshot resolution

var player: Player
var world: Node3D
var half := 246.0           # the map's half-size (metres)
var _tex: Texture2D
var _vp: SubViewport
var _mat: ShaderMaterial
var _map: ColorRect

const SHADER := """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform vec2 center = vec2(0.5);   // you, in map uv
uniform float span = 0.2;          // circle diameter in map uv
uniform float turn = 0.0;          // camera yaw
uniform bool has_map = false;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	if (r > 0.5) discard;
	vec4 col = vec4(0.16, 0.22, 0.16, 1.0);
	if (has_map) {
		float c = cos(turn), s = sin(turn);
		vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * span;
		vec2 uv = center + q;
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0)
			col = texture(map_tex, uv);
		col.rgb = col.rgb * 0.85 + 0.05;
	}
	float rim = smoothstep(0.455, 0.47, r);   // ink ring
	col.rgb = mix(col.rgb, vec3(0.08, 0.06, 0.05), rim);
	col.a *= 1.0 - smoothstep(0.49, 0.5, r);
	COLOR = col;
}
"""

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map = ColorRect.new()
	_map.size = size
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_map.material = _mat
	add_child(_map)
	get_tree().create_timer(1.5).timeout.connect(_snapshot)   # once the world has built itself

## One top-down picture of the whole map.
func _snapshot() -> void:
	if world == null or not is_instance_valid(world):
		return
	_vp = SubViewport.new()
	_vp.size = Vector2i(SHOT, SHOT)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.world_3d = world.get_world_3d()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = half * 2.0
	cam.far = 900.0
	_vp.add_child(cam)
	add_child(_vp)
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), Vector3(0, 400, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(_vp):
		return
	var img := _vp.get_texture().get_image()
	_vp.queue_free()
	_tex = ImageTexture.create_from_image(img)
	_mat.set_shader_parameter("map_tex", _tex)
	_mat.set_shader_parameter("has_map", true)

func _uv(p: Vector3) -> Vector2:   # world -> map uv (top-down camera: x right, -z up)
	return Vector2((p.x + half) / (half * 2.0), (p.z + half) / (half * 2.0))

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_mat.set_shader_parameter("center", _uv(player.global_position))
	_mat.set_shader_parameter("span", VIEW * 2.0 / (half * 2.0))
	_mat.set_shader_parameter("turn", -player.yaw)
	queue_redraw()

## World position -> minimap point (rotated with the camera), clamped to the rim if `pin`.
func _pt(p: Vector3, pin := false) -> Vector2:
	var d := Vector2(p.x - player.global_position.x, p.z - player.global_position.z)
	d = d.rotated(player.yaw) / VIEW * (SIZE * 0.5)
	var lim := SIZE * 0.5 - 10.0
	if d.length() > lim:
		if not pin:
			return Vector2.INF
		d = d.normalized() * lim
	return size * 0.5 + d

func _dot(p: Vector3, col: Color, r := 3.5, pin := false) -> void:
	var q := _pt(p, pin)
	if q != Vector2.INF:
		draw_circle(q, r + 1.2, Color(0, 0, 0, 0.7))
		draw_circle(q, r, col)

func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and is_instance_valid(e):
			_dot(e.global_position, Color(0.95, 0.25, 0.2))
	for av in NetworkSession._avatars.values():
		if is_instance_valid(av):
			_dot((av as Node3D).global_position, Color(0.35, 0.65, 1.0), 4.0)
	for v in Villager._all:
		if is_instance_valid(v) and v.get("_marker") != null and (v._marker as Label3D).visible and (v._marker as Label3D).text != "":
			var q := _pt((v as Node3D).global_position)
			if q != Vector2.INF:
				draw_string(GameMenu.font(), q + Vector2(-3, 5), (v._marker as Label3D).text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.85, 0.2))
	var main := player.get_parent()
	var qs = main.get("quests") if main != null else null
	if qs != null and not (qs.active_def() as Dictionary).is_empty():
		var tp: Vector3 = qs.target_position()
		if tp == Vector3.INF:
			tp = Quests.giver_info(qs.active_def()["giver"])["pos"]
		_dot(tp, Color(1.0, 0.8, 0.15), 5.0, true)
	# you: an arrow pointing where you face (the map turns with the camera)
	var c := size * 0.5
	var f := Vector2(player.facing.x, player.facing.z).rotated(player.yaw)
	if f.length() < 0.1:
		f = Vector2(0, -1)
	f = f.normalized()
	var side := Vector2(-f.y, f.x)
	var tri := PackedVector2Array([c + f * 9.0, c - f * 6.0 + side * 6.0, c - f * 3.0, c - f * 6.0 - side * 6.0])
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.8), 1.5)
	draw_string(GameMenu.font(), Vector2(c.x - 5, 16), "N" if absf(wrapf(player.yaw, -PI, PI)) < 0.4 else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
