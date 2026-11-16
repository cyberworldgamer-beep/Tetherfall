extends Node3D
## Builds and animates KITE-7's hull, engine flames, cargo pods and lights.

var _body: Node3D
var _flames: Array[MeshInstance3D] = []
var _flame_glows: Array[MeshInstance3D] = []
var _engine_particles: Array[CPUParticles3D] = []
var _engine_material: StandardMaterial3D
var _flame_material: StandardMaterial3D
var _flame_core_material: StandardMaterial3D
var _cargo_pods: Array[MeshInstance3D] = []
var _cargo_materials: Array[StandardMaterial3D] = []
var _filled_count: int = 0
var _spool_ring: MeshInstance3D
var _engine_light: OmniLight3D
var _headlight: SpotLight3D
var _thrust: float = 0.0
var _boosting: bool = false
var _time: float = 0.0
var _yaw: float = 0.0
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _target_bank: float = 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.17, 0.21, 0.27)
	hull_mat.metallic = 0.72
	hull_mat.roughness = 0.34
	hull_mat.rim_enabled = true
	hull_mat.rim = 0.9
	hull_mat.rim_tint = 0.8

	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.24, 0.3, 0.37)
	plate_mat.metallic = 0.65
	plate_mat.roughness = 0.4

	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.07, 0.35, 0.34)
	accent.metallic = 0.5
	accent.roughness = 0.2
	accent.emission_enabled = true
	accent.emission = Color(0.25, 1.0, 0.9)
	accent.emission_energy_multiplier = 3.4

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.02, 0.08, 0.1)
	glass.metallic = 0.9
	glass.roughness = 0.05
	glass.emission_enabled = true
	glass.emission = Color(0.12, 0.7, 0.68)
	glass.emission_energy_multiplier = 0.85

	_engine_material = StandardMaterial3D.new()
	_engine_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_engine_material.albedo_color = Color(0.7, 1.0, 0.95)
	_engine_material.emission_enabled = true
	_engine_material.emission = Color(0.3, 1.0, 0.9)
	_engine_material.emission_energy_multiplier = 3.0

	_flame_material = StandardMaterial3D.new()
	_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_material.albedo_color = Color(0.1, 0.7, 0.9, 0.28)
	_flame_material.emission_enabled = true
	_flame_material.emission = Color(0.2, 0.9, 1.0)
	_flame_material.emission_energy_multiplier = 1.4
	_flame_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_flame_core_material = StandardMaterial3D.new()
	_flame_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_core_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_core_material.albedo_color = Color(0.85, 1.0, 1.0, 0.85)
	_flame_core_material.emission_enabled = true
	_flame_core_material.emission = Color(0.6, 1.0, 0.98)
	_flame_core_material.emission_energy_multiplier = 2.2

	_body = Node3D.new()
	add_child(_body)

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.5
	capsule.height = 2.3
	capsule.radial_segments = 16
	capsule.rings = 6
	_add_mesh(_body, capsule, hull_mat, Vector3(0, 0, 0.05), Vector3(PI * 0.5, 0, 0), Vector3(1.0, 1.0, 0.9))

	var nose := SphereMesh.new()
	nose.radius = 0.42
	nose.height = 0.84
	nose.radial_segments = 16
	nose.rings = 8
	_add_mesh(_body, nose, plate_mat, Vector3(0, 0.02, -1.03), Vector3.ZERO, Vector3(0.92, 0.72, 1.15))

	var cockpit := BoxMesh.new()
	cockpit.size = Vector3(0.4, 0.16, 0.62)
	var cockpit_mesh := _add_mesh(_body, cockpit, glass, Vector3(0, 0.42, -0.38), Vector3(-0.16, 0, 0))
	cockpit_mesh.rotation.x = -0.18

	# Accent hoops.
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.53
	hoop.outer_radius = 0.59
	hoop.rings = 32
	hoop.ring_segments = 6
	_add_mesh(_body, hoop, accent, Vector3(0, 0, -0.82), Vector3(PI * 0.5, 0, 0))
	var hoop2 := TorusMesh.new()
	hoop2.inner_radius = 0.58
	hoop2.outer_radius = 0.63
	hoop2.rings = 32
	hoop2.ring_segments = 6
	_add_mesh(_body, hoop2, accent, Vector3(0, 0, 0.35), Vector3(PI * 0.5, 0, 0))

	# Wing struts and side pods.
	var strut := BoxMesh.new()
	strut.size = Vector3(0.85, 0.09, 0.32)
	var pod := CylinderMesh.new()
	pod.top_radius = 0.19
	pod.bottom_radius = 0.23
	pod.height = 1.55
	pod.radial_segments = 12
	for side in [-1.0, 1.0]:
		_add_mesh(_body, strut, plate_mat, Vector3(0.6 * side, 0.02, 0.2), Vector3(0, 0, 0.05 * side))
		_add_mesh(_body, pod, plate_mat, Vector3(0.74 * side, 0.02, 0.08), Vector3(PI * 0.5, 0, 0))
		var cap := SphereMesh.new()
		cap.radius = 0.22
		cap.height = 0.44
		cap.radial_segments = 12
		cap.rings = 6
		_add_mesh(_body, cap, hull_mat, Vector3(0.74 * side, 0.02, -0.7), Vector3.ZERO)
		var nozzle := CylinderMesh.new()
		nozzle.top_radius = 0.16
		nozzle.bottom_radius = 0.2
		nozzle.height = 0.32
		nozzle.radial_segments = 12
		_add_mesh(_body, nozzle, accent, Vector3(0.74 * side, 0.02, 0.86), Vector3(PI * 0.5, 0, 0))
		var nav := SphereMesh.new()
		nav.radius = 0.055
		nav.height = 0.11
		nav.radial_segments = 8
		nav.rings = 4
		var nav_mat := StandardMaterial3D.new()
		nav_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		nav_mat.albedo_color = Color(1.0, 0.2, 0.12) if side < 0 else Color(0.15, 1.0, 0.4)
		nav_mat.emission_enabled = true
		nav_mat.emission = nav_mat.albedo_color
		nav_mat.emission_energy_multiplier = 2.5
		_add_mesh(_body, nav, nav_mat, Vector3(0.86 * side, 0.11, -0.2), Vector3.ZERO)

	# Tether spool.
	var spool := CylinderMesh.new()
	spool.top_radius = 0.24
	spool.bottom_radius = 0.24
	spool.height = 0.22
	spool.radial_segments = 12
	_add_mesh(_body, spool, plate_mat, Vector3(0, 0.46, 0.32), Vector3.ZERO)
	var spool_ring := TorusMesh.new()
	spool_ring.inner_radius = 0.29
	spool_ring.outer_radius = 0.33
	spool_ring.rings = 24
	spool_ring.ring_segments = 4
	_spool_ring = _add_mesh(_body, spool_ring, accent, Vector3(0, 0.46, 0.32), Vector3.ZERO)
	var antenna := CylinderMesh.new()
	antenna.top_radius = 0.015
	antenna.bottom_radius = 0.025
	antenna.height = 0.55
	antenna.radial_segments = 6
	_add_mesh(_body, antenna, plate_mat, Vector3(0, 0.82, 0.38), Vector3(0, 0, 0.12))
	var antenna_tip := SphereMesh.new()
	antenna_tip.radius = 0.045
	antenna_tip.height = 0.09
	antenna_tip.radial_segments = 8
	antenna_tip.rings = 4
	_add_mesh(_body, antenna_tip, accent, Vector3(-0.033, 1.09, 0.38), Vector3.ZERO)

	# Cargo pods on the spine.
	var pod_sphere := SphereMesh.new()
	pod_sphere.radius = 0.155
	pod_sphere.height = 0.31
	pod_sphere.radial_segments = 12
	pod_sphere.rings = 6
	var pod_positions := [Vector3(-0.43, 0.25, 0.52), Vector3(0, 0.28, 0.62), Vector3(0.43, 0.25, 0.52)]
	for i in 3:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.06, 0.1, 0.11)
		material.metallic = 0.6
		material.roughness = 0.25
		material.emission_enabled = true
		material.emission = Color(0.25, 1.0, 0.9)
		material.emission_energy_multiplier = 0.0
		_cargo_materials.append(material)
		var cargo := _add_mesh(_body, pod_sphere, material, pod_positions[i], Vector3.ZERO)
		_cargo_pods.append(cargo)
		var cage := TorusMesh.new()
		cage.inner_radius = 0.21
		cage.outer_radius = 0.235
		cage.rings = 20
		cage.ring_segments = 4
		_add_mesh(_body, cage, accent, pod_positions[i], Vector3(PI * 0.5, 0, 0))

	# Engine flames.
	var flame := CylinderMesh.new()
	flame.top_radius = 0.02
	flame.bottom_radius = 0.17
	flame.height = 1.0
	flame.radial_segments = 10
	flame.rings = 3
	var flame_core := CylinderMesh.new()
	flame_core.top_radius = 0.01
	flame_core.bottom_radius = 0.07
	flame_core.height = 0.8
	flame_core.radial_segments = 8
	flame_core.rings = 2
	for side in [-1.0, 1.0]:
		var outer := _add_mesh(_body, flame, _flame_material, Vector3(0.74 * side, 0.02, 1.4), Vector3(PI * 0.5, 0, 0))
		outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outer.visible = false
		_flames.append(outer)
		var inner := _add_mesh(_body, flame_core, _flame_core_material, Vector3(0.74 * side, 0.02, 1.35), Vector3(PI * 0.5, 0, 0))
		inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inner.visible = false
		_flames.append(inner)
		var glow := SphereMesh.new()
		glow.radius = 0.24
		glow.height = 0.48
		glow.radial_segments = 10
		glow.rings = 5
		var glow_mesh := _add_mesh(_body, glow, _engine_material, Vector3(0.74 * side, 0.02, 0.96), Vector3.ZERO)
		glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame_glows.append(glow_mesh)
		# Exhaust particles.
		var particles := CPUParticles3D.new()
		particles.amount = 18
		particles.lifetime = 0.4
		particles.explosiveness = 0.0
		particles.direction = Vector3(0, 0, 1)
		particles.spread = 9.0
		particles.initial_velocity_min = 5.0
		particles.initial_velocity_max = 9.0
		particles.gravity = Vector3.ZERO
		particles.scale_amount_min = 0.35
		particles.scale_amount_max = 1.0
		particles.local_coords = false
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
		var quad := QuadMesh.new()
		quad.size = Vector2(0.12, 0.12)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pm.albedo_color = Color(0.35, 1.0, 0.95, 0.6)
		pm.emission_enabled = true
		pm.emission = Color(0.3, 1.0, 0.9)
		pm.emission_energy_multiplier = 1.5
		quad.material = pm
		particles.mesh = quad
		particles.emitting = false
		particles.position = Vector3(0.74 * side, 0.02, 1.05)
		_body.add_child(particles)
		_engine_particles.append(particles)

	_engine_light = OmniLight3D.new()
	_engine_light.light_color = Color(0.35, 1.0, 0.9)
	_engine_light.light_energy = 0.0
	_engine_light.omni_range = 5.0
	_engine_light.shadow_enabled = false
	_engine_light.position = Vector3(0, 0, 1.0)
	_body.add_child(_engine_light)

	_headlight = SpotLight3D.new()
	_headlight.light_color = Color(0.75, 0.95, 1.0)
	_headlight.light_energy = 2.0
	_headlight.spot_range = 55.0
	_headlight.spot_angle = 28.0
	_headlight.spot_attenuation = 1.0
	_headlight.shadow_enabled = false
	_headlight.position = Vector3(0, 0.1, -1.0)
	_body.add_child(_headlight)


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rot
	instance.scale = scale
	parent.add_child(instance)
	return instance


func set_thrust(amount: float, boosting: bool) -> void:
	_thrust = clampf(amount, 0.0, 1.0)
	_boosting = boosting


func set_cargo(count: int) -> void:
	_filled_count = count
	for i in _cargo_materials.size():
		var material := _cargo_materials[i]
		var filled := i < count
		material.emission_energy_multiplier = 2.6 if filled else 0.0
		material.albedo_color = Color(0.16, 0.75, 0.68) if filled else Color(0.06, 0.1, 0.11)
		_cargo_pods[i].scale = Vector3.ONE * (1.15 if filled else 1.0)


func update_flight(camera_forward: Vector3, camera_pitch: float, strafe: float) -> void:
	_target_yaw = atan2(-camera_forward.x, -camera_forward.z)
	_target_pitch = camera_pitch * 0.22
	_target_bank = -strafe * 0.48
	var t := get_process_delta_time()
	_yaw = lerp_angle(_yaw, _target_yaw, clampf(t * 8.0, 0.0, 1.0))
	rotation.y = _yaw
	if _body != null:
		_body.rotation.x = lerpf(_body.rotation.x, _target_pitch, clampf(t * 6.0, 0.0, 1.0))
		_body.rotation.z = lerpf(_body.rotation.z, _target_bank, clampf(t * 7.0, 0.0, 1.0))


func _process(delta: float) -> void:
	_time += delta
	var target := _thrust
	var boost_mult := 1.65 if _boosting else 1.0
	for i in _flames.size():
		var flame := _flames[i]
		var is_core := i % 2 == 1
		flame.visible = target > 0.04
		if flame.visible:
			var flicker := 0.85 + 0.15 * sin(_time * 38.0 + i * 1.7)
			var length := (0.55 + target * 1.25) * boost_mult * flicker
			flame.scale = Vector3(1.0, length * (0.65 if is_core else 1.0), 1.0)
			flame.position.z = 1.15 + length * 0.35
	for glow in _flame_glows:
		glow.visible = target > 0.04
		if glow.visible:
			glow.scale = Vector3.ONE * (0.8 + target * 0.7 + (0.2 if _boosting else 0.0))
	for particles in _engine_particles:
		particles.emitting = target > 0.04
		particles.initial_velocity_max = (11.0 if _boosting else 8.0)
	if _engine_light != null:
		_engine_light.light_energy = target * (2.6 if _boosting else 1.3)
	if _spool_ring != null:
		_spool_ring.rotate_y(delta * 1.5)
	for i in _cargo_pods.size():
		_cargo_pods[i].rotate_y(delta * (1.0 if i < _filled_count else 0.2))