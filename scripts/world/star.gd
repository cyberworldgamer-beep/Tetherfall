class_name DyingStar
extends Node3D
## The dying star: animated plasma surface, corona shells, lighting, solar
## flare telegraph and a physical core the drone can crash into.

const SURFACE_RADIUS := 14.0
const CORONA_RADIUS := 16.2
const HEAT_RADIUS := 27.0

var heat_radius: float = HEAT_RADIUS

var _surface_material: ShaderMaterial
var _corona_material: ShaderMaterial
var _outer_corona_material: ShaderMaterial
var _light: OmniLight3D
var _rings: Array[Node3D] = []
var _flare_ratio: float = 0.0
var _base_energy: float = 6.0


func _ready() -> void:
	_build()


func _build() -> void:
	var surface_sphere := SphereMesh.new()
	surface_sphere.radius = SURFACE_RADIUS
	surface_sphere.height = SURFACE_RADIUS * 2.0
	surface_sphere.radial_segments = 72
	surface_sphere.rings = 36
	var surface := MeshInstance3D.new()
	surface.mesh = surface_sphere
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = preload("res://shaders/star_surface.gdshader")
	_surface_material.set_shader_parameter("brightness", 2.4)
	surface.material_override = _surface_material
	add_child(surface)

	var corona_sphere := SphereMesh.new()
	corona_sphere.radius = CORONA_RADIUS
	corona_sphere.height = CORONA_RADIUS * 2.0
	corona_sphere.radial_segments = 48
	corona_sphere.rings = 24
	var corona := MeshInstance3D.new()
	corona.mesh = corona_sphere
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corona_material = ShaderMaterial.new()
	_corona_material.shader = preload("res://shaders/star_corona.gdshader")
	_corona_material.set_shader_parameter("color", Color(1.0, 0.58, 0.2))
	_corona_material.set_shader_parameter("strength", 1.0)
	_corona_material.set_shader_parameter("power", 2.8)
	corona.material_override = _corona_material
	add_child(corona)

	var outer_sphere := SphereMesh.new()
	outer_sphere.radius = SURFACE_RADIUS * 1.42
	outer_sphere.height = SURFACE_RADIUS * 2.84
	outer_sphere.radial_segments = 40
	outer_sphere.rings = 20
	var outer := MeshInstance3D.new()
	outer.mesh = outer_sphere
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outer_corona_material = ShaderMaterial.new()
	_outer_corona_material.shader = preload("res://shaders/star_corona.gdshader")
	_outer_corona_material.set_shader_parameter("color", Color(1.0, 0.36, 0.1))
	_outer_corona_material.set_shader_parameter("strength", 0.34)
	_outer_corona_material.set_shader_parameter("power", 3.5)
	outer.material_override = _outer_corona_material
	add_child(outer)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.66, 0.4)
	_light.light_energy = _base_energy
	_light.omni_range = 620.0
	_light.omni_attenuation = 0.5
	_light.shadow_enabled = false
	_light.shadow_bias = 0.12
	_light.shadow_normal_bias = 2.0
	add_child(_light)

	# Two thin plasma rings tilt and rotate around the star.
	for i in 2:
		var ring := Node3D.new()
		ring.rotation = Vector3(PI * 0.5 + (0.38 if i == 0 else -0.24), i * 0.9, i * 0.18)
		var torus := TorusMesh.new()
		torus.inner_radius = SURFACE_RADIUS * (1.06 + i * 0.1)
		torus.outer_radius = SURFACE_RADIUS * (1.085 + i * 0.1)
		torus.rings = 96
		torus.ring_segments = 8
		var mesh := MeshInstance3D.new()
		mesh.mesh = torus
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.55, 0.18, 0.16 if i == 0 else 0.08)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.5, 0.15)
		mat.emission_energy_multiplier = 1.8
		mesh.material_override = mat
		ring.add_child(mesh)
		add_child(ring)
		_rings.append(ring)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("star")
	var shape := SphereShape3D.new()
	shape.radius = SURFACE_RADIUS * 0.98
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if _light != null:
		_light.light_energy = _base_energy + 0.25 * sin(t * 0.9) + _flare_ratio * 5.0
	if _surface_material != null:
		_surface_material.set_shader_parameter("brightness", 2.4 + _flare_ratio * 1.5)
	if _corona_material != null:
		_corona_material.set_shader_parameter("strength", 1.0 + _flare_ratio * 1.2)
	for i in _rings.size():
		var ring := _rings[i]
		ring.rotate_y(delta * (0.06 if i == 0 else -0.035))
		ring.rotate_z(delta * (0.025 if i == 0 else -0.012))


func set_quality_shadows(enabled: bool) -> void:
	if _light != null:
		_light.shadow_enabled = enabled


func set_flare_charge(ratio: float) -> void:
	_flare_ratio = clampf(ratio, 0.0, 1.0)


func flare_pulse() -> void:
	_flare_ratio = 0.0
	if _surface_material != null:
		var mat := _surface_material
		var tw := create_tween()
		var set_brightness := func(v: float) -> void:
			mat.set_shader_parameter("brightness", v)
		tw.tween_method(set_brightness, 4.0, 2.4, 1.2)
	FXLibrary.shockwave(get_parent(), global_position, Color(1.0, 0.45, 0.12), 90.0, 1.4, 0.5)
	FXLibrary.shockwave(get_parent(), global_position, Color(1.0, 0.85, 0.5), 45.0, 0.9, 0.75)
	FXLibrary.burst(get_parent(), global_position, Color(1.0, 0.55, 0.2), 6.0, 30)