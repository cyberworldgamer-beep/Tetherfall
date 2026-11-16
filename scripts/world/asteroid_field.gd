class_name AsteroidField
extends Node3D
## Procedurally generates the asteroid belt: faceted rock meshes, convex
## collision, emissive crystal veins and guaranteed anchor rocks.

const FIELD_MIN_RADIUS := 28.0
const FIELD_MAX_RADIUS := 108.0

var _rock_material: StandardMaterial3D
var _crystal_materials: Array[StandardMaterial3D] = []
var _rock_meshes: Array[ArrayMesh] = []
var _crystal_mesh: Mesh
var _asteroids: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func generate(world_seed: int) -> void:
	_rng.seed = world_seed
	_build_materials()
	_build_meshes()
	for child in get_children():
		child.queue_free()
	_asteroids.clear()

	# Hand-placed anchors near the approach lane so the first swing is readable.
	var fixed := [
		[Vector3(34.0, 9.0, 74.0), 4.6],
		[Vector3(-23.0, 21.0, 79.0), 5.4],
		[Vector3(-2.0, 24.0, 97.0), 3.4],
		[Vector3(-30.0, 8.0, 47.0), 6.2],
		[Vector3(35.0, -8.0, 55.0), 4.0],
	]
	for item in fixed:
		_add_asteroid(item[0] as Vector3, float(item[1]), Vector3(1.0, _rng.randf_range(0.75, 1.05), 1.0))

	var spawned := fixed.size()
	var attempts := 0
	var lane_start := Vector3(12, 12, 88)
	var lane_end := Vector3(24, 10, 46)
	while spawned < 36 and attempts < 600:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(FIELD_MIN_RADIUS, FIELD_MAX_RADIUS)
		var pos := Vector3(cos(angle) * radius, _rng.randf_range(-24.0, 30.0), sin(angle) * radius)
		var size := _rng.randf_range(2.2, 7.4)
		if _rng.randf() < 0.08:
			size = _rng.randf_range(8.0, 10.5)
		if pos.length() < 27.0 + size:
			continue
		if pos.distance_to(Vector3(24, 10, 46)) < 34.0 + size:
			continue
		if pos.distance_to(lane_start) < 24.0 + size:
			continue
		# Keep the opening sightline from the drone to the gate clear.
		var lane_point := Geometry3D.get_closest_point_to_segment(pos, lane_start, lane_end)
		if pos.distance_to(lane_point) < 15.0 + size * 0.5:
			continue
		var blocked := false
		for rock in _asteroids:
			var other_pos: Vector3 = rock["position"]
			var other_size: float = rock["radius"]
			if pos.distance_to(other_pos) < size + other_size + 2.0:
				blocked = true
				break
		if blocked:
			continue
		var squash := Vector3(_rng.randf_range(0.85, 1.15), _rng.randf_range(0.65, 1.05), _rng.randf_range(0.85, 1.15))
		_add_asteroid(pos, size, squash)
		spawned += 1


func _build_materials() -> void:
	_rock_material = StandardMaterial3D.new()
	_rock_material.vertex_color_use_as_albedo = true
	_rock_material.roughness = 0.9
	_rock_material.metallic = 0.08
	_rock_material.metallic_specular = 0.34
	_rock_material.rim_enabled = true
	_rock_material.rim = 0.3
	_rock_material.rim_tint = 0.6

	var colors := [
		Color(0.18, 0.92, 0.82), Color(1.0, 0.52, 0.22), Color(0.55, 0.4, 1.0)
	]
	for color in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.07, 0.09)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.2
		mat.roughness = 0.35
		mat.metallic = 0.2
		_crystal_materials.append(mat)


func _build_meshes() -> void:
	_rock_meshes.clear()
	var seed_values := [11, 29, 47, 83, 127, 211, 307]
	for i in seed_values.size():
		_rock_meshes.append(_make_rock_mesh(seed_values[i]))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 4
	sphere.rings = 2
	_crystal_mesh = sphere


func _make_rock_mesh(mesh_seed: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 22
	sphere.rings = 12
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var noise := FastNoiseLite.new()
	noise.seed = mesh_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.15
	noise.fractal_octaves = 4
	var detail := FastNoiseLite.new()
	detail.seed = mesh_seed + 13
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 4.6
	detail.fractal_octaves = 2

	for i in verts.size():
		var dir := verts[i].normalized()
		var n := noise.get_noise_3dv(dir * 1.7)
		var d := detail.get_noise_3dv(dir * 3.2)
		var radius := 1.0 + n * 0.30 + d * 0.065
		verts[i] = dir * radius

	var palettes := [
		[Color(0.62, 0.64, 0.69), Color(0.29, 0.32, 0.38)],
		[Color(0.7, 0.57, 0.48), Color(0.31, 0.25, 0.23)],
		[Color(0.5, 0.62, 0.64), Color(0.21, 0.31, 0.34)],
		[Color(0.57, 0.54, 0.68), Color(0.27, 0.25, 0.36)],
	]
	var palette: Array = palettes[mesh_seed % palettes.size()]
	var light_col: Color = palette[0]
	var dark_col: Color = palette[1]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]
		var a := verts[ia]
		var b := verts[ib]
		var c := verts[ic]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.0001:
			continue
		normal = normal.normalized()
		var center := (a + b + c) / 3.0
		if normal.dot(center) < 0.0:
			normal = -normal
		var shade := clampf(0.45 + normal.y * 0.22 + center.length() * 0.15, 0.0, 1.0)
		var face_noise := noise.get_noise_3dv(center * 2.3)
		var col := light_col.lerp(dark_col, clampf(shade + face_noise * 0.18, 0.0, 1.0))
		col = col * (0.88 + detail.get_noise_3dv(center * 5.0) * 0.12)
		for v in [a, b, c]:
			st.set_color(col)
			st.set_normal(normal)
			st.add_vertex(v)
	return st.commit()


func _add_asteroid(pos: Vector3, size: float, squash: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.scale = Vector3(size, size, size) * squash
	body.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0, TAU), _rng.randf_range(-0.25, 0.25))
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("asteroids")
	body.add_to_group("tetherable")
	body.set_meta("radius", size)

	var mesh_index := _rng.randi_range(0, _rock_meshes.size() - 1)
	var mesh := _rock_meshes[mesh_index]
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _rock_material
	body.add_child(visual)

	var shape := mesh.create_convex_shape(true, true)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

	# Sparse glowing crystal veins.
	if _rng.randf() < 0.55:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		var crystal := MeshInstance3D.new()
		crystal.mesh = _crystal_mesh
		crystal.material_override = _crystal_materials[_rng.randi_range(0, _crystal_materials.size() - 1)]
		var world_pos := body.global_transform * (dir * 0.94)
		crystal.position = world_pos
		var crystal_scale := _rng.randf_range(0.7, 1.9) * clampf(size / 5.0, 0.55, 1.8)
		crystal.scale = Vector3(crystal_scale, crystal_scale * _rng.randf_range(1.2, 2.1), crystal_scale)
		crystal.rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0, TAU), _rng.randf_range(-0.4, 0.4))
		add_child(crystal)

	_asteroids.append({"position": pos, "radius": size})


func get_asteroid_spots() -> Array[Dictionary]:
	return _asteroids


func asteroid_count() -> int:
	return _asteroids.size()