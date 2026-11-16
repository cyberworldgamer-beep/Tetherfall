class_name AetherCore
extends Area3D
## Aether core pickup. Drifts in place, pulls toward a nearby carrier, and
## reports collection once.

signal collected(core: Node3D)

var player: Node3D
var magnet_range: float = 9.0
var pickup_radius: float = 2.0

var _visual: Node3D
var _rings: Array[Node3D] = []
var _halo: MeshInstance3D
var _taken: bool = false
var _phase: float = 0.0
var _base_position: Vector3 = Vector3.ZERO
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group("cores")
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	_phase = randf() * TAU
	_base_position = global_position
	_build()
	body_entered.connect(_on_body_entered)


func _build() -> void:
	var shape := SphereShape3D.new()
	shape.radius = pickup_radius
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)

	_visual = Node3D.new()
	add_child(_visual)

	var gem := SphereMesh.new()
	gem.radius = 0.72
	gem.height = 1.55
	gem.radial_segments = 4
	gem.rings = 2
	var gem_mesh := MeshInstance3D.new()
	gem_mesh.mesh = gem
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.18, 0.8, 0.76)
	gem_mat.metallic = 0.35
	gem_mat.roughness = 0.18
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.25, 1.0, 0.88)
	gem_mat.emission_energy_multiplier = 2.0
	gem_mesh.material_override = gem_mat
	gem_mesh.rotation = Vector3(0.3, 0.0, 0.4)
	_visual.add_child(gem_mesh)

	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 1.55
	halo_mesh.height = 3.1
	halo_mesh.radial_segments = 20
	halo_mesh.rings = 10
	_halo = MeshInstance3D.new()
	_halo.mesh = halo_mesh
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.albedo_color = Color(0.1, 0.9, 0.8, 0.07)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.15, 1.0, 0.85)
	halo_mat.emission_energy_multiplier = 0.6
	halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo.material_override = halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_halo)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(0.3, 1.0, 0.9, 0.55)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.3, 1.0, 0.9)
	ring_mat.emission_energy_multiplier = 1.6
	for i in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = 1.02 + i * 0.12
		torus.outer_radius = 1.09 + i * 0.12
		torus.rings = 32
		torus.ring_segments = 4
		var ring := Node3D.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = torus
		mesh.material_override = ring_mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.add_child(mesh)
		ring.rotation = Vector3(PI * 0.5 if i == 0 else 0.2, i * 0.8, 0.3)
		_visual.add_child(ring)
		_rings.append(ring)


func _physics_process(delta: float) -> void:
	if _taken:
		return
	if player != null and is_instance_valid(player) and player.can_collect():
		var distance := global_position.distance_to(player.global_position)
		if distance < magnet_range and distance > 1.2:
			var speed := 6.0 + (magnet_range - distance) * 3.4
			var target := player.global_position
			global_position = global_position.move_toward(target, speed * delta)
	# Gentle drift if not magnetized.
	if global_position.distance_to(_base_position) < 0.05:
		global_position = _base_position


func _process(delta: float) -> void:
	if _taken:
		return
	_phase += delta
	var bob := sin(_phase * 1.7) * 0.28
	_visual.position = Vector3(0, bob, 0)
	_visual.rotate_y(delta * 1.4)
	for i in _rings.size():
		_rings[i].rotate_z(delta * (0.8 if i == 0 else -1.1))
	var pulse := 0.9 + sin(_phase * 2.6) * 0.1
	_visual.scale = Vector3.ONE * pulse


func _on_body_entered(body: Node3D) -> void:
	if _taken or body == null:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("collect_core"):
		return
	if body.collect_core(global_position):
		_taken = true
		collected.emit(self)
		queue_free()