class_name PlayerDrone
extends RigidBody3D
## KITE-7 salvage drone. Physics-driven flight, momentum-preserving tether,
## cargo handling, hull/boost management and aiming.

signal hull_changed(hull: int, maximum: int)
signal boost_changed(ratio: float)
signal cores_changed(count: int, capacity: int)
signal tether_changed(attached: bool)
signal aim_changed(valid: bool, distance: float)
signal damage_taken(cause: String, amount: int)
signal core_collected(world_position: Vector3)
signal death
signal boundary_returned

const MAX_HULL := 3
const CARRY_CAPACITY := 3
const THRUST := 34.0
const BOOST_MULTIPLIER := 1.85
const MAX_SPEED := 54.0
const MAX_BOOST_SPEED := 66.0
const BOOST_DRAIN := 36.0
const BOOST_REGEN := 17.0
const BOOST_UNLOCK := 24.0
const MAX_TETHER_RANGE := 88.0
const MIN_ROPE := 5.0
const MAX_ROPE := 86.0
const STAR_GRAVITY := 21000.0
const BOUNDARY := 138.0
const HARSH_BOUNDARY := 176.0

var star: Node3D
var camera_rig: Node3D

var hull: int = MAX_HULL
var boost: float = 100.0
var cores: int = 0
var attached: bool = false

var _alive: bool = true
var _thrust_dir: Vector3 = Vector3.ZERO
var _input_strafe: float = 0.0
var _input_forward: float = 0.0
var _boosting: bool = false
var _boost_lock: bool = false
var _boost_rest: float = 0.0
var _invuln: float = 0.0
var _tether_anchor: Vector3 = Vector3.ZERO
var _rope_length: float = 20.0
var _aim_valid: bool = false
var _aim_distance: float = 0.0
var _aim_point: Vector3 = Vector3.ZERO
var _last_aim_distance: float = -1.0
var _last_boost_emit: float = -1.0

var _shield: MeshInstance3D
var _shield_material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	add_to_group("player")
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	$TetherLine.visible = false
	$TetherGlow.visible = false
	$AnchorMarker.visible = false
	_build_shield()
	$Visual.set_cargo(0)
	call_deferred("_emit_initial_state")


func _emit_initial_state() -> void:
	hull_changed.emit(hull, MAX_HULL)
	boost_changed.emit(boost / 100.0)
	cores_changed.emit(cores, CARRY_CAPACITY)
	tether_changed.emit(false)


func setup(star_node: Node3D, rig: Node3D) -> void:
	star = star_node
	camera_rig = rig


func _build_shield() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.55
	sphere.height = 3.1
	sphere.radial_segments = 20
	sphere.rings = 10
	_shield = MeshInstance3D.new()
	_shield.mesh = sphere
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_material = StandardMaterial3D.new()
	_shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shield_material.albedo_color = Color(0.2, 0.9, 1.0, 0.0)
	_shield_material.emission_enabled = true
	_shield_material.emission = Color(0.25, 1.0, 0.9)
	_shield_material.emission_energy_multiplier = 2.0
	_shield_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield.material_override = _shield_material
	add_child(_shield)
	_shield.visible = false


func _process(delta: float) -> void:
	_time += delta
	if _invuln > 0.0:
		_invuln -= delta
		if _shield != null:
			_shield.visible = true
			var a := 0.08 + 0.05 * sin(_time * 26.0)
			_shield_material.albedo_color = Color(0.2, 0.9, 1.0, a)
			_shield.scale = Vector3.ONE * (1.0 + 0.04 * sin(_time * 18.0))
	elif _shield != null and _shield.visible:
		_shield.visible = false

	if _alive:
		_update_flight_input(delta)
		_update_aim()
		_update_tether_input(delta)
		_update_tether_visual(delta)
		_update_visual(delta)
		_check_boundary()
	else:
		$Visual.set_thrust(0.0, false)
		_update_tether_visual(delta)

	if absf(boost / 100.0 - _last_boost_emit) > 0.01:
		_last_boost_emit = boost / 100.0
		boost_changed.emit(boost / 100.0)


func _update_flight_input(delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var fwd := 0.0
	var strafe := 0.0
	var vert := 0.0
	if captured:
		fwd = Input.get_action_strength("thrust_forward") - Input.get_action_strength("thrust_back")
		strafe = Input.get_action_strength("strafe_right") - Input.get_action_strength("strafe_left")
		vert = Input.get_action_strength("ascend") - Input.get_action_strength("descend")
	var cam := get_viewport().get_camera_3d()
	var basis := global_transform.basis
	if cam != null:
		basis = cam.global_transform.basis
	var dir := (-basis.z * fwd) + (basis.x * strafe) + (basis.y * vert)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	_thrust_dir = dir
	_input_strafe = strafe
	_input_forward = fwd

	var wants_boost := captured and Input.is_action_pressed("boost") and dir.length() > 0.05 and boost > 0.0 and not _boost_lock
	if wants_boost:
		if not _boosting:
			AudioManager.play_sfx("boost", -5.0, 1.0)
		_boosting = true
		_boost_rest = 1.35
		boost = maxf(0.0, boost - BOOST_DRAIN * delta)
		if boost <= 0.0:
			_boost_lock = true
	else:
		_boosting = false
		if _boost_rest > 0.0:
			_boost_rest -= delta
		else:
			boost = minf(100.0, boost + BOOST_REGEN * delta)
			if _boost_lock and boost >= BOOST_UNLOCK:
				_boost_lock = false


func _update_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var to := from - cam.global_basis.z * MAX_TETHER_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var exclude: Array[RID] = [get_rid()]
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var valid := false
	var dist := 0.0
	var point := Vector3.ZERO
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider is Node and (collider as Node).is_in_group("tetherable"):
			point = hit.get("position", Vector3.ZERO)
			dist = global_position.distance_to(point)
			if dist >= 2.5 and dist <= MAX_TETHER_RANGE:
				valid = true
	_aim_valid = valid
	_aim_distance = dist
	_aim_point = point
	var last_valid := _last_aim_distance >= 0.0
	if valid != last_valid or absf(dist - _last_aim_distance) > 0.9:
		_last_aim_distance = dist if valid else -1.0
		aim_changed.emit(valid, dist)


func _update_tether_input(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed("tether"):
		_try_tether()
	if Input.is_action_just_pressed("release_tether"):
		release_tether()
	if attached:
		var reel := 0.0
		if Input.is_action_pressed("reel_in"):
			reel -= 1.0
		if Input.is_action_pressed("reel_out"):
			reel += 1.0
		if reel != 0.0:
			_rope_length = clampf(_rope_length + reel * 16.0 * delta, MIN_ROPE, MAX_ROPE)
		if global_position.distance_to(_tether_anchor) > MAX_TETHER_RANGE * 1.35:
			release_tether()


func _try_tether() -> void:
	if not _aim_valid:
		AudioManager.play_sfx("tether_fire", -10.0, 0.7)
		return
	_tether_anchor = _aim_point
	_rope_length = clampf(global_position.distance_to(_tether_anchor), MIN_ROPE, MAX_ROPE)
	if not attached:
		attached = true
		tether_changed.emit(true)
	AudioManager.play_sfx("tether_fire", -4.0, 1.15)
	AudioManager.play_sfx("tether_attach", -7.0, 1.0)
	$TetherLine.visible = true
	$TetherGlow.visible = true
	$AnchorMarker.visible = true
	$AnchorMarker.global_position = _tether_anchor


func release_tether(silent: bool = false) -> void:
	if not attached:
		return
	attached = false
	$TetherLine.visible = false
	$TetherGlow.visible = false
	$AnchorMarker.visible = false
	tether_changed.emit(false)
	if not silent:
		AudioManager.play_sfx("tether_release", -6.0, 1.0)


func _update_tether_visual(delta: float) -> void:
	if not attached:
		return
	var from := global_position
	var to := _tether_anchor
	var offset := to - from
	var dist := offset.length()
	if dist < 0.2:
		return
	var dir := offset / dist
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.985:
		up = Vector3.RIGHT
	var x_axis := dir.cross(up)
	if x_axis.length_squared() < 0.0001:
		x_axis = dir.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(dir).normalized()
	var basis := Basis(x_axis, dir, z_axis)
	var mid := from + dir * (dist * 0.5)
	var line: MeshInstance3D = $TetherLine
	var glow: MeshInstance3D = $TetherGlow
	line.global_transform = Transform3D(basis, mid)
	line.scale = Vector3(1.0, dist, 1.0)
	glow.global_transform = line.global_transform
	glow.scale = Vector3(2.6, dist, 2.6)
	$AnchorMarker.global_position = to
	$AnchorMarker.rotate_z(delta * 2.2)
	$AnchorMarker.rotate_y(delta * 0.9)


func _update_visual(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var forward := -cam.global_transform.basis.z
		var pitch := cam.global_rotation.x
		$Visual.update_flight(forward, pitch, _input_strafe)
	$Visual.set_thrust(_thrust_dir.length(), _boosting)


func _check_boundary() -> void:
	var radius := global_position.length()
	if radius > HARSH_BOUNDARY:
		global_position = Vector3(0, 10, 112)
		linear_velocity = Vector3.ZERO
		release_tether(true)
		boundary_returned.emit()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var lv := state.linear_velocity
	if _alive:
		if star != null and is_instance_valid(star):
			var to_star := star.global_position - state.transform.origin
			var distance := maxf(to_star.length(), 5.0)
			var gravity := minf(STAR_GRAVITY / (distance * distance), 62.0)
			state.apply_central_force(to_star.normalized() * gravity * mass)
		if _thrust_dir.length_squared() > 0.0001:
			var force := _thrust_dir * THRUST * (BOOST_MULTIPLIER if _boosting else 1.0)
			state.apply_central_force(force * mass)
		# Soft speed ceiling keeps control readable while allowing flare launches.
		var speed := lv.length()
		var cap := MAX_BOOST_SPEED if _boosting else MAX_SPEED
		if speed > cap:
			var excess := speed - cap
			var cut := excess * clampf(1.0 - exp(-3.5 * state.step), 0.0, 1.0)
			lv -= lv.normalized() * cut
		# Tether distance constraint (momentum preserving).
		if attached:
			var to_anchor := _tether_anchor - state.transform.origin
			var dist := to_anchor.length()
			if dist > _rope_length + 0.02 and dist > 0.001:
				var dir := to_anchor / dist
				var radial := lv.dot(dir)
				if radial < 0.0:
					lv -= dir * radial
				var excess := dist - _rope_length
				lv += dir * minf(excess * 3.0, 10.0)
		var radial_pos := state.transform.origin.length()
		if radial_pos > BOUNDARY - 18.0:
			var inward := -state.transform.origin.normalized()
			state.apply_central_force(inward * (radial_pos - (BOUNDARY - 18.0)) * 1.6 * mass)
		state.linear_velocity = lv
	else:
		state.linear_velocity = lv * 0.995


func _on_body_entered(body: Node3D) -> void:
	if not _alive or _invuln > 0.0:
		return
	if not (body is StaticBody3D):
		return
	if linear_velocity.length() < 7.0:
		return
	var direction := global_position - body.global_position
	if direction.length_squared() < 0.01:
		direction = -linear_velocity.normalized()
	take_damage(1, direction.normalized(), 7.0, "impact")


func take_damage(amount: int, impulse_direction: Vector3, impulse_strength: float = 0.0, cause: String = "impact") -> bool:
	if not _alive or _invuln > 0.0:
		return false
	hull = maxi(0, hull - amount)
	_invuln = 1.15
	if impulse_strength > 0.0:
		apply_central_impulse(impulse_direction.normalized() * impulse_strength)
	AudioManager.play_sfx("hit", -1.0, randf_range(0.92, 1.05))
	hull_changed.emit(hull, MAX_HULL)
	damage_taken.emit(cause, amount)
	if hull <= 0:
		_die()
	return true


func heal(amount: int) -> void:
	if not _alive:
		return
	var previous := hull
	hull = mini(MAX_HULL, hull + amount)
	if hull != previous:
		hull_changed.emit(hull, MAX_HULL)


func _die() -> void:
	if not _alive:
		return
	_alive = false
	release_tether(true)
	_boosting = false
	_thrust_dir = Vector3.ZERO
	$Visual.set_thrust(0.0, false)
	death.emit()


func stand_down() -> void:
	if not _alive:
		return
	_alive = false
	release_tether(true)
	_boosting = false
	_thrust_dir = Vector3.ZERO
	$Visual.set_thrust(0.0, false)


func can_collect() -> bool:
	return _alive and cores < CARRY_CAPACITY


func collect_core(world_position: Vector3) -> bool:
	if not can_collect():
		return false
	cores += 1
	$Visual.set_cargo(cores)
	cores_changed.emit(cores, CARRY_CAPACITY)
	core_collected.emit(world_position)
	AudioManager.play_sfx("pickup", -3.0, randf_range(0.97, 1.06))
	return true


func consume_cores() -> int:
	var amount := cores
	cores = 0
	$Visual.set_cargo(0)
	cores_changed.emit(cores, CARRY_CAPACITY)
	return amount


func get_aim_data() -> Dictionary:
	return {
		"valid": _aim_valid,
		"distance": _aim_distance,
		"point": _aim_point,
		"attached": attached,
	}


func get_speed() -> float:
	return linear_velocity.length()


func is_alive() -> bool:
	return _alive


func is_boosting() -> bool:
	return _boosting