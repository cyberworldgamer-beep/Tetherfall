class_name CameraRig
extends Node3D
## Third-person camera rig: mouse look, spring-arm collision, speed FOV,
## screen shake and space dust.

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D
var yaw: float = 0.0
var pitch: float = -0.06
var trauma: float = 0.0

var _base_fov: float = 82.0
var _dust: CPUParticles3D
var _initialized: bool = false


func _ready() -> void:
	_build_dust()
	_build_lights()


func _build_lights() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "UtilityLamp"
	lamp.light_color = Color(0.5, 0.85, 1.0)
	lamp.light_energy = 0.9
	lamp.omni_range = 20.0
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = false
	add_child(lamp)

	var fill := SpotLight3D.new()
	fill.name = "CameraFill"
	fill.light_color = Color(0.72, 0.93, 1.0)
	fill.light_energy = 2.0
	fill.spot_range = 80.0
	fill.spot_angle = 44.0
	fill.spot_attenuation = 0.8
	fill.shadow_enabled = false
	camera.add_child(fill)


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "SpaceDust"
	_dust.amount = 90
	_dust.lifetime = 3.0
	_dust.explosiveness = 0.0
	_dust.direction = Vector3(0, 0, 1)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 0.0
	_dust.initial_velocity_max = 0.4
	_dust.gravity = Vector3.ZERO
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 1.2
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(16.0, 12.0, 22.0)
	_dust.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.75, 0.92, 0.95, 0.4)
	quad.material = mat
	_dust.mesh = quad
	_dust.emitting = true
	add_child(_dust)


func setup(target_node: Node3D) -> void:
	target = target_node
	if target is CollisionObject3D:
		spring_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	global_position = target.global_position
	rotation = Vector3(pitch, yaw, 0.0)
	_initialized = true


func _unhandled_input(event: InputEvent) -> void:
	if target == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var sens := 0.0022 * GameConfig.mouse_sensitivity
		yaw -= motion.relative.x * sens
		var direction := 1.0 if GameConfig.invert_y else -1.0
		pitch += motion.relative.y * sens * direction
		pitch = clampf(pitch, -1.45, 1.45)
		yaw = wrapf(yaw, -PI, PI)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not _initialized:
		return
	var follow := 1.0 - exp(-11.0 * delta)
	global_position = global_position.lerp(target.global_position, follow)
	rotation = Vector3(pitch, yaw, 0.0)

	var speed_ratio := 0.0
	var boosting := false
	if target.has_method("get_speed"):
		speed_ratio = clampf(float(target.call("get_speed")) / 66.0, 0.0, 1.0)
	if target.has_method("is_boosting"):
		boosting = bool(target.call("is_boosting"))
	var target_fov := _base_fov + speed_ratio * 9.0 + (3.0 if boosting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 3.0, 0.0, 1.0))

	trauma = maxf(0.0, trauma - delta * 1.7)
	var shake := trauma * trauma
	if shake > 0.001:
		camera.h_offset = randf_range(-0.75, 0.75) * shake
		camera.v_offset = randf_range(-0.75, 0.75) * shake
		camera.rotation.z = randf_range(-0.02, 0.02) * shake
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0


func add_shake(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)