class_name AnimePost
extends RefCounted
## Adds the anime ink-outline post effect (shaders/anime_outline_post.gdshader) to a scene: a
## full-screen quad that is always drawn. Needs the Forward+ renderer (it reads the depth and
## normal buffers); does nothing on Compatibility / Mobile.

static func add_to(parent: Node) -> MeshInstance3D:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return null
	var mi := MeshInstance3D.new()
	mi.name = "AnimeOutlines"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/anime_outline_post.gdshader")
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0   # never culled
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
