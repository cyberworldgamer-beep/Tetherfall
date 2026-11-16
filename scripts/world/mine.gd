class_name IonMine
extends Area3D
## Drifting ion mine. Detonates when the player enters its trigger radius.

signal detonated(mine: Node3D, at: Vector3)

const TRIGGER_RADIUS := 3.2

var _visual: Node3D
var _core_material: StandardMaterial3D
var _base_position: Vector3
var _phase: float = 0.0
var _armed: bool = false
var _exploded: bool = false
var _cooldown: float = 0.7


func _ready() -> void:
	add_to_group("mines")
	add_to_group("hazards")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	_phase = randf() * TAU
	_base_position = global_position
	_build()
	body_entered.connect(_on_body_entered)


func _build() -> void:
	var shape := SphereShape3D.new()
	shape.radius = TRIGGER_RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)

	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * 1.35
	add_child(_visual)

	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.06, 0.07, 0.085)
	hull_mat.metallic = 0.9
	hull_mat.roughness = 0.35
	hull_mat.rim_enabled = true
	hull_mat.rim = 0.3
	hull_mat.rim_tint = 0.3

	var hull := SphereMesh.new()
	hull.radius = 1.0
	hull.height = 2.0
	hull.radial_segments = 16
	hull.rings = 8
	var hull_mesh := MeshInstance3D.new()
	hull_mesh.mesh = hull
	hull_mesh.material_override = hull_mat
	_visual.add_child(hull_mesh)

	var spike := CylinderMesh.new()
	spike.top_radius = 0.02
	spike.bottom_radius = 0.20
	spike.height = 1.2
	spike.radial_segments = 6
	for i in 8:
		var p_dir := Vector3(_dir_for_index(i))
		var cone := MeshInstance3D.new()
		cone.mesh = spike
		cone.material_override = hull_mat
		cone.position = p_dir * 1.05
		cone.basis = Basis(Quaternion(Vector3.UP, p_dir))
		_visual.add_child(cone)

	_core_material = StandardMaterial3D.new()
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material.albedo_color = Color(1.0, 0.2, 0.18)
	_core_material.emission_enabled = true
	_core_material.emission = Color(1.0, 0.16, 0.12)
	_core_material.emission_energy_multiplier = 3.0
	var core_sphere := SphereMesh.new()
	core_sphere.radius = 0.48
	core_sphere.height = 0.96
	core_sphere.radial_segments = 12
	core_sphere.rings = 6
	for i in 2:
		var core := MeshInstance3D.new()
		core.mesh = core_sphere
		core.material_override = _core_material
		core.position = Vector3(0, 0, 0.9) if i == 0 else Vector3(0, 0, -0.9)
		_visual.add_child(core)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.18, 0.12)
	light.light_energy = 1.2
	light.omni_range = 8.0
	light.shadow_enabled = false
	add_child(light)

	# Orbit alarm ring.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.3
	torus.outer_radius = 2.36
	torus.rings = 40
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.16)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.15, 0.1)
	ring_mat.emission_energy_multiplier = 1.0
	ring.rotation.x = PI * 0.5
	_visual.add_child(ring)


func _dir_for_index(index: int) -> Vector3:
	var angle := TAU * float(index) / 8.0
	return Vector3(cos(angle), sin(angle * 2.0) * 0.45, sin(angle)).normalized()


func _process(delta: float) -> void:
	_phase += delta
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_armed = true
	if _visual != null:
		_visual.rotate_y(delta * 0.45)
		_visual.rotate_x(delta * 0.12)
	if _core_material != null:
		var blink := 0.5 + 0.5 * sin(_phase * 5.0)
		_core_material.emission_energy_multiplier = 1.2 + blink * 2.4
	# Slow creepy drift around its anchor point.
	var drift := Vector3(sin(_phase * 0.4) * 1.6, cos(_phase * 0.33) * 1.2, sin(_phase * 0.27 + 1.0) * 1.6)
	global_position = _base_position + drift


func _on_body_entered(body: Node3D) -> void:
	if _exploded or not _armed:
		return
	if not body.is_in_group("player"):
		return
	_exploded = true
	var at := global_position
	detonated.emit(self, at)
	queue_free()