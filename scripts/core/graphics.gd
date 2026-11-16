class_name Graphics
extends RefCounted
## Graphics presets (Settings in the main menu): Low / Medium / High, or Auto (picked from the GPU).
## Applies render scale, anti-aliasing, shadow quality and the heavy environment effects
## (SSAO, SSIL, SDFGI, volumetric fog, glow) to every map as it loads. High = the maps as authored.

const PRESETS := ["auto", "low", "medium", "high"]

## Called on startup (menu) and whenever the preset changes. Also watches the tree so every
## map / environment / sun that loads later gets the same treatment.
static func apply(tree: SceneTree) -> void:
	var q := resolved()
	var vp := tree.root
	match q:
		"low":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.67
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.mesh_lod_threshold = 4.0
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 2, 50, 300)
		"medium":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.mesh_lod_threshold = 2.0
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50, 300)
		_:   # high
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.mesh_lod_threshold = 1.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50, 300)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	_walk(tree.root)

## The preset actually in use ("auto" resolved from the graphics card).
static func resolved() -> String:
	var g := str(GameData.graphics)
	return auto_pick() if g == "auto" else g

## Auto: a dedicated graphics card gets High, a modern integrated chip Medium, anything else Low.
static func auto_pick() -> String:
	var name := RenderingServer.get_video_adapter_name().to_lower()
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return "high"
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			for good in ["radeon", "iris xe", "arc", "apple"]:
				if name.contains(good):
					return "medium"
			return "low"
	return "low"

static func label(preset: String) -> String:
	if preset == "auto":
		return "AUTO (%s)" % auto_pick().to_upper()
	return preset.to_upper()

static func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment or n is DirectionalLight3D or n is Camera3D:
		_tune(n)

static func _walk(n: Node) -> void:
	_tune(n)
	for c in n.get_children():
		_walk(c)

static func _tune(n: Node) -> void:
	var q := resolved()
	if n is WorldEnvironment:
		_tune_env((n as WorldEnvironment).environment, q)
	elif n is Camera3D and (n as Camera3D).environment != null:
		_tune_env((n as Camera3D).environment, q)
	elif n is DirectionalLight3D:
		var l := n as DirectionalLight3D
		if not l.has_meta("gfx_orig_dist"):
			l.set_meta("gfx_orig_dist", l.directional_shadow_max_distance)
		var orig: float = l.get_meta("gfx_orig_dist")
		l.directional_shadow_max_distance = minf(orig, 50.0) if q == "low" else (minf(orig, 90.0) if q == "medium" else orig)

## Turns the expensive effects off (low) / partly off (medium); High restores what the map had.
static func _tune_env(env: Environment, q: String) -> void:
	if env == null:
		return
	if not env.has_meta("gfx_orig"):
		env.set_meta("gfx_orig", {"ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "sdfgi": env.sdfgi_enabled,
			"vfog": env.volumetric_fog_enabled, "glow": env.glow_enabled, "ssr": env.ssr_enabled})
	var o: Dictionary = env.get_meta("gfx_orig")
	var low := q == "low"
	var med := q == "medium"
	env.ssao_enabled = o["ssao"] and not low
	env.ssil_enabled = o["ssil"] and not (low or med)
	env.sdfgi_enabled = o["sdfgi"] and not (low or med)
	env.volumetric_fog_enabled = o["vfog"] and not (low or med)
	env.ssr_enabled = o["ssr"] and not (low or med)
	env.glow_enabled = o["glow"] and not low
