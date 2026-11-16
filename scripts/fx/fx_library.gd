class_name FXLibrary
extends RefCounted
## Stateless helpers that spawn short-lived, self-cleaning visual effects.

const SHOCKWAVE_SHADER := preload("res://shaders/shockwave.gdshader")


static func burst(parent: Node, pos: Vector3, color: Color, size: float = 1.0, count: int = 18) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var particles := CPUParticles3D.new()
	particles.amount = count
	particles.lifetime = 0.85
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 3.5 * size
	particles.initial_velocity_max = 10.0 * size
	particles.gravity = Vector3.ZERO
	particles.damping_min = 1.0
	particles.damping_max = 3.0
	particles.scale_amount_min = 0.4 * size
	particles.scale_amount_max = 1.3 * size
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.25 * size
	particles.local_coords = false
	particles.color = Color.WHITE

	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	quad.material = mat
	particles.mesh = quad
	particles.finished.connect(particles.queue_free)

	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0 * size
	light.omni_range = 9.0 * size
	light.shadow_enabled = false
	particles.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.45)


static func shockwave(parent: Node, pos: Vector3, color: Color, radius: float, duration: float = 0.7, opacity: float = 0.65) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	visual.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = SHOCKWAVE_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("alpha", opacity)
	mat.set_shader_parameter("power", 2.2)
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	visual.global_position = pos
	visual.scale = Vector3.ONE * 0.8
	var tw := visual.create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "scale", Vector3.ONE * radius, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var fade_out := func(v: float) -> void:
		mat.set_shader_parameter("alpha", v)
	tw.tween_method(fade_out, opacity, 0.0, duration)
	tw.chain().tween_callback(visual.queue_free)


static func pickup(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.35, 1.0, 0.92), 0.7, 12)
	shockwave(parent, pos, Color(0.25, 1.0, 0.88), 2.8, 0.45, 0.4)


static func explosion(parent: Node, pos: Vector3, size: float = 1.0) -> void:
	burst(parent, pos, Color(1.0, 0.48, 0.16), size, 26)
	burst(parent, pos, Color(1.0, 0.85, 0.4), size * 0.6, 10)
	shockwave(parent, pos, Color(1.0, 0.45, 0.15), 8.0 * size, 0.6, 0.7)


static func deposit(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.35, 1.0, 0.9), 1.3, 24)
	shockwave(parent, pos, Color(0.25, 1.0, 0.88), 14.0, 0.8, 0.55)
	shockwave(parent, pos, Color(0.9, 1.0, 0.95), 6.0, 0.45, 0.5)