class_name SalvageGate
extends Node3D
## Salvage gate: a physical ring with a deposit sensor in its aperture.

signal deposit_requested

const RING_RADIUS := 10.4
const DEPOSIT_RADIUS := 8.0

var _holder: Node3D
var _deco_ring: Node3D
var _energy_disc: MeshInstance3D
var _energy_material: ShaderMaterial
var _light: OmniLight3D
var _deposit_area: Area3D
var _cooldown: float = 0.0
var _pulse: float = 0.0
var _label: Label3D


func _ready() -> void:
	add_to_group("gate")
	add_to_group("tetherable")
	_build()


func _build() -> void:
	_holder = Node3D.new()
	_holder.rotation.x = PI * 0.5
	add_child(_holder)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.055, 0.075, 0.1)
	metal.metallic = 0.85
	metal.roughness = 0.28
	metal.rim_enabled = true
	metal.rim = 0.35
	metal.rim_tint = 0.55

	var accent := StandardMaterial3D.new()
	accent.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	accent.albedo_color = Color(0.25, 1.0, 0.88)
	accent.emission_enabled = true
	accent.emission = Color(0.2, 1.0, 0.84)
	accent.emission_energy_multiplier = 2.6

	var main_torus := TorusMesh.new()
	main_torus.inner_radius = 9.7
	main_torus.outer_radius = 11.2
	main_torus.rings = 72
	main_torus.ring_segments = 14
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = main_torus
	ring_mesh.material_override = metal
	_holder.add_child(ring_mesh)

	var inner_torus := TorusMesh.new()
	inner_torus.inner_radius = 9.55
	inner_torus.outer_radius = 9.68
	inner_torus.rings = 72
	inner_torus.ring_segments = 6
	var inner_mesh := MeshInstance3D.new()
	inner_mesh.mesh = inner_torus
	inner_mesh.material_override = accent
	_holder.add_child(inner_mesh)

	# Clamps around the ring.
	var clamp_mesh := BoxMesh.new()
	clamp_mesh.size = Vector3(1.9, 3.0, 2.4)
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.34, 2.2, 0.2)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var clamp := MeshInstance3D.new()
		clamp.mesh = clamp_mesh
		clamp.material_override = metal
		clamp.position = Vector3(cos(angle) * RING_RADIUS, 0.0, sin(angle) * RING_RADIUS)
		clamp.rotation.y = -angle
		_holder.add_child(clamp)
		var strip := MeshInstance3D.new()
		strip.mesh = strip_mesh
		strip.material_override = accent
		strip.position = Vector3(cos(angle) * (RING_RADIUS - 1.15), 0.0, sin(angle) * (RING_RADIUS - 1.15))
		strip.rotation.y = -angle
		_holder.add_child(strip)

	# Rotating beacon ring with marker lights.
	_deco_ring = Node3D.new()
	_holder.add_child(_deco_ring)
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.22
	marker_mesh.height = 0.44
	marker_mesh.radial_segments = 8
	marker_mesh.rings = 4
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.material_override = accent
		marker.position = Vector3(cos(angle) * 12.35, 0.0, sin(angle) * 12.35)
		_deco_ring.add_child(marker)

	# Energy aperture.
	var plane := PlaneMesh.new()
	plane.size = Vector2(19.1, 19.1)
	_energy_disc = MeshInstance3D.new()
	_energy_disc.mesh = plane
	_energy_material = ShaderMaterial.new()
	_energy_material.shader = preload("res://shaders/gate_field.gdshader")
	_energy_material.set_shader_parameter("color", Color(0.2, 1.0, 0.86))
	_energy_material.set_shader_parameter("intensity", 0.95)
	_energy_disc.material_override = _energy_material
	_energy_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder.add_child(_energy_disc)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.35, 1.0, 0.88)
	_light.light_energy = 2.2
	_light.omni_range = 34.0
	_light.shadow_enabled = false
	add_child(_light)

	_label = Label3D.new()
	_label.text = "SALVAGE GATE  //  DELIVER"
	_label.font = UITheme.title_font
	_label.font_size = 56
	_label.pixel_size = 0.022
	_label.modulate = Color(0.55, 1.0, 0.94, 0.82)
	_label.outline_modulate = Color(0.0, 0.15, 0.16, 0.9)
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = false
	_label.position = Vector3(0, 17.5, 0)
	add_child(_label)

	# Physical ring segments (the aperture itself stays open).
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("tetherable")
	body.add_to_group("gate_body")
	var box := BoxMesh.new()
	box.size = Vector3(4.2, 1.0, 1.6)
	var seg_count := 14
	for i in seg_count:
		var angle := TAU * float(i) / float(seg_count)
		var shape := BoxShape3D.new()
		shape.size = Vector3(4.4, 1.2, 1.8)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(cos(angle) * RING_RADIUS, sin(angle) * RING_RADIUS, 0.0)
		collider.rotation.z = angle + PI * 0.5
		body.add_child(collider)
	add_child(body)

	_deposit_area = Area3D.new()
	_deposit_area.collision_layer = 0
	_deposit_area.collision_mask = 2
	_deposit_area.monitoring = true
	var area_shape := SphereShape3D.new()
	area_shape.radius = DEPOSIT_RADIUS
	var area_collider := CollisionShape3D.new()
	area_collider.shape = area_shape
	_deposit_area.add_child(area_collider)
	add_child(_deposit_area)
	_deposit_area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _deco_ring != null:
		_deco_ring.rotate_y(delta * 0.25)
	_pulse = maxf(0.0, _pulse - delta * 1.6)
	if _energy_material != null:
		_energy_material.set_shader_parameter("intensity", 0.95 + _pulse * 0.9 + sin(Time.get_ticks_msec() * 0.001) * 0.1)
	if _light != null:
		_light.light_energy = 2.0 + _pulse * 7.0
	_label.modulate.a = 0.72 + sin(Time.get_ticks_msec() * 0.002) * 0.18


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0:
		return
	if body.is_in_group("player"):
		_cooldown = 0.9
		deposit_requested.emit()


func play_deposit() -> void:
	_pulse = 1.0
	var tw := create_tween()
	tw.tween_property(_energy_disc, "scale", Vector3(1.18, 1.18, 1.18), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(_energy_disc, "scale", Vector3.ONE, 0.5).set_ease(Tween.EASE_IN_OUT)
	FXLibrary.deposit(get_parent(), global_position)


func marker_position() -> Vector3:
	return global_position + Vector3(0, 0.5, 0)


func is_player_inside() -> bool:
	if _deposit_area == null:
		return false
	for body in _deposit_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false