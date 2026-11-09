extends CanvasLayer
class_name SharinganEffect
## One-shot, semi-transparent Sharingan activation overlay in screen space.
## The emblem fills most of the short screen axis, spins once, then fades out.

const TEXTURE_PATH := "res://assets/effects/sharingan.png"
const SOUND_PATH := "res://assets/effects/sharingan_activation.mp3"
const SCREEN_COVERAGE := 0.92
const FINAL_OPACITY := 0.94
const SPIN_DURATION := 0.88

static func play_activation(scene_tree: SceneTree) -> void:
	if scene_tree == null or scene_tree.root == null:
		return
	var effect := SharinganEffect.new()
	scene_tree.root.add_child(effect)

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var texture := load(TEXTURE_PATH) as Texture2D
	if texture == null:
		push_warning("[SharinganEffect] Missing image: %s" % TEXTURE_PATH)
		queue_free()
		return
	_play_activation_sound()
	_build_screen_image(texture)
	_animate_screen_image()

func _build_screen_image(texture: Texture2D) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var icon_size := minf(viewport_size.x, viewport_size.y) * SCREEN_COVERAGE
	var screen := Control.new()
	screen.name = "SharinganFullScreenOverlay"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)

	var icon := TextureRect.new()
	icon.name = "SharinganScreenIcon"
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -icon_size * 0.5
	icon.offset_top = -icon_size * 0.5
	icon.offset_right = icon_size * 0.5
	icon.offset_bottom = icon_size * 0.5
	icon.pivot_offset = Vector2(icon_size * 0.5, icon_size * 0.5)
	icon.scale = Vector2.ONE * 0.58
	icon.rotation = deg_to_rad(-22.0)
	icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	screen.add_child(icon)
	set_meta("screen_icon", icon)

func _animate_screen_image() -> void:
	var icon := get_meta("screen_icon") as TextureRect
	if icon == null:
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	# Fast entrance, one dramatic spin, and a short fade to reveal gameplay again.
	tween.tween_property(icon, "rotation", icon.rotation + TAU * 1.0, SPIN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE * 1.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "modulate:a", FINAL_OPACITY, 0.10)
	tween.chain().tween_interval(0.02)
	tween.chain().tween_property(icon, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)

func _play_activation_sound() -> void:
	var stream := load(SOUND_PATH) as AudioStream
	if stream == null:
		push_warning("[SharinganEffect] Missing activation sound: %s" % SOUND_PATH)
		return
	# The sound lives outside this short-lived CanvasLayer so it can finish naturally.
	var audio := AudioStreamPlayer.new()
	audio.name = "SharinganActivationSound"
	audio.stream = stream
	audio.volume_db = -2.0
	get_tree().root.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
