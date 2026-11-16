class_name TetherfallRun
extends Node3D
## Run director for TETHERFALL. Owns scoring, the contract clock, solar flare
## cycle, pickups/hazards, and the flow between play, pause and results.

enum State { PLAYING, PAUSED, GAMEOVER }

const CORE_SCENE := preload("res://scenes/core.tscn")
const MINE_SCENE := preload("res://scenes/mine.tscn")

const RUN_TIME := 120.0
const MAX_TIME := 180.0
const TIME_PER_CORE := 12.0
const CHAIN_WINDOW := 22.0
const MAX_CHAIN := 8
const BASE_POINTS := 110
const CORE_TARGET := 6
const MINE_START := 4
const MINE_MAX := 12
const STAR_HEAT_RADIUS := 27.0

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var star_node: DyingStar = $Star
@onready var asteroid_field: AsteroidField = $AsteroidField
@onready var gate: SalvageGate = $Gate
@onready var player: PlayerDrone = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var cores_root: Node3D = $Cores
@onready var mines_root: Node3D = $Mines
@onready var fx_root: Node3D = $FX
@onready var hud: GameHUD = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var game_over: GameOverScreen = $GameOver

var state: State = State.PLAYING
var _mode_text: String = "FREE RUN"
var _daily: bool = false
var _rng := RandomNumberGenerator.new()

var _time_left: float = RUN_TIME
var _elapsed: float = 0.0
var _score: int = 0
var _chain: int = 1
var _chain_timer: float = 0.0
var _best_chain: int = 1
var _cores_collected: int = 0
var _deposits: int = 0

var _heat: float = 0.0
var _heat_warn_cooldown: float = 0.0
var _next_flare: float = 26.0
var _flare_warned: bool = false
var _flare_active: float = 0.0

var _core_spawn_timer: float = 0.0
var _mine_spawn_timer: float = 0.0
var _mine_target: int = MINE_START
var _context_timer: float = 0.0
var _run_ended: bool = false


func _ready() -> void:
	get_tree().paused = false
	_daily = GameConfig.pending_daily
	_mode_text = "DAILY CONTRACT  ·  %s" % GameConfig.today_string() if _daily else "FREE RUN  //  SECTOR 7"
	_rng.seed = GameConfig.run_seed
	_apply_quality()

	asteroid_field.generate(GameConfig.run_seed)
	player.setup(star_node, camera_rig)
	camera_rig.setup(player)
	hud.bind(self, player, gate, camera_rig.get_node("SpringArm3D/Camera3D"))

	hud.set_mode(_mode_text)
	hud.set_score(0)
	hud.set_combo(1, 0.0)
	hud.set_hull(player.hull, player.MAX_HULL)
	hud.set_boost(1.0)
	hud.set_cores(0, player.CARRY_CAPACITY)
	hud.set_objective("SCAVENGE AETHER CORES")
	hud.set_hint("LMB / F tethers to any rock or the gate. Momentum is free.")
	hud.play_intro()

	player.hull_changed.connect(hud.set_hull)
	player.boost_changed.connect(hud.set_boost)
	player.cores_changed.connect(hud.set_cores)
	player.tether_changed.connect(_on_tether_changed)
	player.damage_taken.connect(_on_damage_taken)
	player.core_collected.connect(_on_core_collected)
	player.death.connect(_on_player_death)
	player.boundary_returned.connect(_on_boundary_returned)
	gate.deposit_requested.connect(_on_deposit_requested)

	pause_menu.resumed.connect(_on_resume_requested)
	pause_menu.restart_requested.connect(_restart)
	pause_menu.abandon_requested.connect(_to_menu)
	game_over.retry_requested.connect(_restart)
	game_over.menu_requested.connect(_to_menu)

	_spawn_initial_world()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioManager.play_music("game", 1.6)
	state = State.PLAYING


func _apply_quality() -> void:
	get_viewport().msaa_3d = GameConfig.msaa_level()
	var env := world_env.environment if world_env != null else null
	if env != null:
		env.glow_enabled = GameConfig.quality > 0
		env.ssao_enabled = GameConfig.quality >= 2
		env.volumetric_fog_enabled = false
		if GameConfig.quality == 0:
			env.glow_intensity = 0.5
	star_node.set_quality_shadows(GameConfig.quality >= 2)


func _spawn_initial_world() -> void:
	# Guaranteed first core hanging just off the approach lane.
	var first := CORE_SCENE.instantiate() as AetherCore
	first.position = Vector3(22, 16, 64)
	first.player = player
	cores_root.add_child(first)
	for i in CORE_TARGET - 1:
		_spawn_core()
	for i in MINE_START:
		_spawn_mine()
	_mine_target = MINE_START


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return

	_elapsed += delta
	_time_left = maxf(0.0, _time_left - delta)
	hud.set_timer(_time_left)

	if _chain_timer > 0.0:
		_chain_timer = maxf(0.0, _chain_timer - delta)
		if _chain_timer <= 0.0 and _chain > 1:
			_chain = 1
			hud.set_combo(_chain, 0.0)
	hud.set_combo(_chain, _chain_timer / CHAIN_WINDOW)

	_update_heat(delta)
	_update_flare(delta)
	_maintain_world(delta)
	_update_context()

	if _time_left <= 0.0 and not _run_ended:
		player.stand_down()
		player.freeze = true
		_end_run("CONTRACT EXPIRED  ·  CLOCK EMPTY")


func _update_heat(delta: float) -> void:
	var distance := player.global_position.length()
	var ratio := 0.0
	if distance < STAR_HEAT_RADIUS:
		ratio = clampf(1.0 - distance / STAR_HEAT_RADIUS, 0.0, 1.0)
	if ratio > 0.0 and player.is_alive():
		_heat = minf(1.0, _heat + delta * (0.35 + ratio * 1.5))
		if _heat >= 1.0:
			_heat = 0.35
			_heat_warn_cooldown = 1.5
			var away := (player.global_position - star_node.global_position).normalized()
			player.take_damage(1, away, 5.0, "heat")
			hud.show_warning("HULL SCORCHED  ·  STELLAR HEAT", 1.8, UITheme.DANGER)
			camera_rig.add_shake(0.45)
			_break_chain()
	else:
		_heat = maxf(0.0, _heat - delta * 0.55)

	if _heat_warn_cooldown > 0.0:
		_heat_warn_cooldown -= delta
	elif ratio > 0.32 and _heat > 0.15:
		_heat_warn_cooldown = 4.0
		hud.show_warning("STELLAR HEAT RISING  ·  PULL AWAY", 1.8, UITheme.HOT)
	hud.set_heat(_heat)


func _update_flare(delta: float) -> void:
	_next_flare -= delta
	if _flare_active > 0.0:
		_flare_active -= delta
	if _next_flare <= 4.0 and not _flare_warned:
		_flare_warned = true
		AudioManager.play_sfx("warning", -4.0)
		hud.show_warning("SOLAR FLARE INBOUND  ·  BRACE", 3.0, UITheme.HOT)
	if _next_flare <= 4.0 and _next_flare > 0.0:
		star_node.set_flare_charge(clampf(1.0 - _next_flare / 4.0, 0.0, 1.0))
	if _next_flare <= 0.0:
		_fire_flare()


func _fire_flare() -> void:
	_flare_warned = false
	_flare_active = 1.0
	_next_flare = _rng.randf_range(32.0, 44.0)
	star_node.set_flare_charge(0.0)
	star_node.flare_pulse()
	AudioManager.play_sfx("flare", -2.0)
	camera_rig.add_shake(0.55)
	if player.is_alive():
		var outward := player.global_position.normalized()
		player.apply_central_impulse(outward * 15.0 + Vector3(0, 3.5, 0))
	hud.show_warning("FLARE RELEASE  ·  RIDE THE WAVE", 2.4, UITheme.HOT)


func _maintain_world(delta: float) -> void:
	var core_count := get_tree().get_nodes_in_group("cores").size()
	_core_spawn_timer -= delta
	if core_count < CORE_TARGET and _core_spawn_timer <= 0.0:
		_spawn_core()
		_core_spawn_timer = 1.2

	_mine_spawn_timer -= delta
	_mine_target = mini(MINE_START + _deposits, MINE_MAX)
	var mine_count := get_tree().get_nodes_in_group("mines").size()
	if mine_count < _mine_target and _mine_spawn_timer <= 0.0:
		_spawn_mine()
		_mine_spawn_timer = 3.0


func _update_context() -> void:
	_context_timer -= get_process_delta_time()
	if _context_timer > 0.0:
		return
	_context_timer = 0.3
	var cargo := player.cores
	if cargo <= 0:
		hud.set_objective("SCAVENGE AETHER CORES")
		if _time_left < 20.0:
			hud.set_hint("CLOCK CRITICAL  ·  A DELIVERY BUYS %d MORE SECONDS" % int(TIME_PER_CORE))
		elif player.attached:
			hud.set_hint("REEL WITH THE WHEEL  ·  RELEASE TO SLING")
		elif bool(player.get_aim_data().get("valid", false)):
			hud.set_hint("TETHER LOCKED  ·  LMB / F TO SWING")
		else:
			hud.set_hint("LMB / F tethers to any rock or the gate. Momentum is free.")
	else:
		hud.set_objective("DELIVER %d / %d CORES  →  SALVAGE GATE" % [cargo, player.CARRY_CAPACITY])
		if _heat > 0.35:
			hud.set_hint("PULL AWAY FROM THE STAR  ·  HEAT IS BUILDING")
		elif _chain_timer > 0.0:
			hud.set_hint("CHAIN x%d  ·  DELIVER AGAIN IN %ds" % [_chain, int(ceil(_chain_timer))])
		else:
			hud.set_hint("THE GATE BANKS YOUR CARGO AND BUYS TIME")


func _spawn_core() -> void:
	var spots := asteroid_field.get_asteroid_spots()
	var pos := Vector3.ZERO
	var found := false
	for attempt in 30:
		if not spots.is_empty() and _rng.randf() < 0.7:
			var rock: Dictionary = spots[_rng.randi_range(0, spots.size() - 1)]
			var rock_pos: Vector3 = rock["position"]
			var radius: float = rock["radius"]
			pos = rock_pos + _random_unit() * (radius + _rng.randf_range(2.6, 4.8))
		else:
			var angle := _rng.randf_range(0.0, TAU)
			var radius := _rng.randf_range(36.0, 108.0)
			pos = Vector3(cos(angle) * radius, _rng.randf_range(-20.0, 28.0), sin(angle) * radius)
		if pos.length() < 33.0 or pos.length() > 120.0:
			continue
		if pos.distance_to(gate.global_position) < 18.0:
			continue
		if player != null and pos.distance_to(player.global_position) < 18.0:
			continue
		var clear := true
		for node in get_tree().get_nodes_in_group("cores"):
			if node is Node3D and (node as Node3D).global_position.distance_to(pos) < 9.0:
				clear = false
				break
		if clear:
			found = true
			break
	if not found:
		return
	var core := CORE_SCENE.instantiate() as AetherCore
	core.position = pos
	core.player = player
	cores_root.add_child(core)


func _spawn_mine() -> void:
	var pos := Vector3.ZERO
	var found := false
	for attempt in 24:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(34.0, 106.0)
		pos = Vector3(cos(angle) * radius, _rng.randf_range(-18.0, 26.0), sin(angle) * radius)
		if pos.length() < 32.0:
			continue
		if pos.distance_to(player.global_position) < 34.0:
			continue
		if pos.distance_to(gate.global_position) < 20.0:
			continue
		var clear := true
		for node in get_tree().get_nodes_in_group("mines"):
			if node is Node3D and (node as Node3D).global_position.distance_to(pos) < 12.0:
				clear = false
				break
		if clear:
			found = true
			break
	if not found:
		return
	var mine := MINE_SCENE.instantiate() as IonMine
	mine.position = pos
	mines_root.add_child(mine)
	mine.detonated.connect(_on_mine_detonated)


func _random_unit() -> Vector3:
	var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.01:
		return Vector3.UP
	return dir.normalized()


func _on_deposit_requested() -> void:
	if state != State.PLAYING or _run_ended:
		return
	if not player.is_alive():
		return
	if player.cores <= 0:
		hud.show_warning("NO CARGO  ·  COLLECT AETHER CORES FIRST", 1.6, UITheme.MUTED)
		return

	var carried := player.consume_cores()
	_deposits += 1
	if _chain_timer > 0.0:
		_chain = mini(_chain + 1, MAX_CHAIN)
	else:
		_chain = 1
	_chain_timer = CHAIN_WINDOW
	_best_chain = maxi(_best_chain, _chain)

	var points := BASE_POINTS * carried * _chain
	_score += points
	var gained_time := TIME_PER_CORE * carried
	if carried >= player.CARRY_CAPACITY:
		gained_time += 6.0
	_time_left = minf(MAX_TIME, _time_left + gained_time)

	var repaired := false
	if carried >= player.CARRY_CAPACITY and player.hull < player.MAX_HULL:
		player.heal(1)
		repaired = true

	gate.play_deposit()
	AudioManager.play_sfx("deposit", -1.0)
	camera_rig.add_shake(0.5)
	hud.set_score(_score)
	hud.set_combo(_chain, 1.0)
	hud.set_timer(_time_left)
	hud.spawn_popup("+%d" % points, UITheme.HOT if _chain > 1 else UITheme.ACCENT, gate.global_position + Vector3(0, 7.0, 0))
	var message := "DELIVERY x%d  ·  +%d pts  ·  +%ds" % [carried, points, int(gained_time)]
	if repaired:
		message += "  ·  HULL PATCHED"
	hud.show_warning(message, 2.2, UITheme.ACCENT)


func _on_core_collected(world_position: Vector3) -> void:
	if _run_ended:
		return
	_cores_collected += 1
	FXLibrary.pickup(fx_root, world_position)
	camera_rig.add_shake(0.1)
	hud.spawn_popup("CORE", UITheme.ACCENT, world_position)


func _on_tether_changed(attached: bool) -> void:
	if attached:
		hud.set_hint("TETHER ATTACHED  ·  REEL WITH THE WHEEL  ·  RMB / X TO RELEASE")
	else:
		_context_timer = 0.0


func _on_damage_taken(cause: String, _amount: int) -> void:
	_break_chain()
	hud.flash_damage()
	camera_rig.add_shake(0.5)
	match cause:
		"mine":
			hud.show_warning("ION MINE DETONATION  ·  HULL DAMAGE", 1.8, UITheme.DANGER)
		"heat":
			pass
		_:
			hud.show_warning("IMPACT  ·  HULL DAMAGE", 1.4, UITheme.DANGER)


func _break_chain() -> void:
	if _chain != 1 or _chain_timer > 0.0:
		_chain = 1
		_chain_timer = 0.0
		hud.set_combo(_chain, 0.0)


func _on_mine_detonated(_mine: Node3D, at: Vector3) -> void:
	FXLibrary.explosion(fx_root, at, 1.5)
	camera_rig.add_shake(0.65)
	if player.is_alive():
		var away := player.global_position - at
		if away.length_squared() < 0.01:
			away = Vector3.UP
		player.take_damage(1, away.normalized(), 9.0, "mine")


func _on_boundary_returned() -> void:
	_break_chain()
	hud.show_warning("BOUNDARY VIOLATION  ·  RECALLED TO SECTOR", 2.0, UITheme.HOT)
	camera_rig.add_shake(0.3)


func _on_player_death() -> void:
	FXLibrary.explosion(fx_root, player.global_position, 3.0)
	camera_rig.add_shake(0.9)
	_end_run("SIGNAL LOST  ·  HULL FAILURE")


func _end_run(reason: String) -> void:
	if _run_ended:
		return
	_run_ended = true
	state = State.GAMEOVER
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.freeze = true
	pause_menu.hide_panel()
	hud.set_timer(_time_left)
	hud.set_combo(1, 0.0)
	hud.show_warning(reason, 2.0, UITheme.DANGER)
	AudioManager.stop_music(1.2)
	AudioManager.play_sfx("game_over", -2.0)

	var new_best := GameConfig.submit_run(_score, _cores_collected, _deposits, _best_chain, _elapsed)
	await get_tree().create_timer(0.9).timeout
	game_over.show_result({
		"reason": reason,
		"score": _score,
		"cores": _cores_collected,
		"deposits": _deposits,
		"chain": _best_chain,
		"time": _elapsed,
		"best": GameConfig.best_score,
		"daily_best": GameConfig.daily_best,
		"new_best": new_best,
	})


func _pause_run() -> void:
	if state != State.PLAYING or _run_ended:
		return
	state = State.PAUSED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu.show_panel(_score, _mode_text)
	AudioManager.play_ui("ui_click")


func _resume_run() -> void:
	pause_menu.hide_panel()
	get_tree().paused = false
	state = State.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_requested() -> void:
	_resume_run()


func _restart() -> void:
	get_tree().paused = false
	var daily := GameConfig.pending_daily
	GameConfig.start_run(daily)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_music("menu", 0.8)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			_pause_run()
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED and not pause_menu.is_settings_open():
			_resume_run()
			get_viewport().set_input_as_handled()
		return

	if state == State.GAMEOVER and event.is_action_pressed("restart"):
		_restart()
		get_viewport().set_input_as_handled()
		return

	if state == State.PLAYING and event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()