extends Node
## Persistent configuration + player profile.
## Also registers every gameplay input action so the project does not depend on
## editor-authored input maps (layout independent physical keys are used).

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const PROFILE_PATH := "user://profile.cfg"

# --- Settings ---------------------------------------------------------------
var music_volume: float = 0.62
var sfx_volume: float = 0.85
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var quality: int = 2 # 0 = low, 1 = medium, 2 = high
var fullscreen: bool = false
var show_hints: bool = true

# --- Profile ----------------------------------------------------------------
var best_score: int = 0
var daily_best: int = 0
var daily_best_date: String = ""
var runs: int = 0
var total_cores: int = 0
var total_deposits: int = 0
var best_combo: int = 0
var longest_run: float = 0.0

# --- Run selection ----------------------------------------------------------
var pending_daily: bool = false
var run_seed: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_settings()
	_load_profile()
	_apply_display()
	AudioManager.settings_changed()


# ---------------------------------------------------------------- input ----
func _setup_input() -> void:
	_action_keys("thrust_forward", [KEY_W, KEY_UP])
	_action_keys("thrust_back", [KEY_S, KEY_DOWN])
	_action_keys("strafe_left", [KEY_A, KEY_LEFT])
	_action_keys("strafe_right", [KEY_D, KEY_RIGHT])
	_action_keys("ascend", [KEY_SPACE])
	_action_keys("descend", [KEY_CTRL])
	_action_keys("boost", [KEY_SHIFT])
	_action_keys("tether", [KEY_F], [MOUSE_BUTTON_LEFT])
	_action_keys("release_tether", [KEY_X], [MOUSE_BUTTON_RIGHT])
	_action_keys("reel_in", [], [MOUSE_BUTTON_WHEEL_UP])
	_action_keys("reel_out", [], [MOUSE_BUTTON_WHEEL_DOWN])
	_action_keys("pause", [KEY_ESCAPE])
	_action_keys("restart", [KEY_R])
	_action_keys("toggle_hints", [KEY_H])


func _action_keys(action: StringName, keys: Array, mouse_buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
	for button in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		if not InputMap.action_has_event(action, mb):
			InputMap.action_add_event(action, mb)


# ------------------------------------------------------------- settings ----
func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cf.get_value("input", "sensitivity", mouse_sensitivity)), 0.3, 2.5)
	invert_y = bool(cf.get_value("input", "invert_y", invert_y))
	quality = clampi(int(cf.get_value("video", "quality", quality)), 0, 2)
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	show_hints = bool(cf.get_value("game", "hints", show_hints))


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("input", "sensitivity", mouse_sensitivity)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("game", "hints", show_hints)
	cf.save(SETTINGS_PATH)
	_apply_display()
	AudioManager.settings_changed()
	settings_changed.emit()


func _apply_display() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and not fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func msaa_level() -> int:
	match quality:
		0:
			return Viewport.MSAA_DISABLED
		1:
			return Viewport.MSAA_2X
		_:
			return Viewport.MSAA_4X


# -------------------------------------------------------------- profile ----
func _load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(PROFILE_PATH) == OK:
		best_score = int(cf.get_value("score", "best", 0))
		daily_best = int(cf.get_value("score", "daily", 0))
		daily_best_date = str(cf.get_value("score", "daily_date", ""))
		runs = int(cf.get_value("stats", "runs", 0))
		total_cores = int(cf.get_value("stats", "cores", 0))
		total_deposits = int(cf.get_value("stats", "deposits", 0))
		best_combo = int(cf.get_value("stats", "best_combo", 0))
		longest_run = float(cf.get_value("stats", "longest_run", 0.0))
	var today := _today_string()
	if daily_best_date != today:
		daily_best_date = today
		daily_best = 0


func save_profile() -> void:
	var cf := ConfigFile.new()
	cf.set_value("score", "best", best_score)
	cf.set_value("score", "daily", daily_best)
	cf.set_value("score", "daily_date", daily_best_date)
	cf.set_value("stats", "runs", runs)
	cf.set_value("stats", "cores", total_cores)
	cf.set_value("stats", "deposits", total_deposits)
	cf.set_value("stats", "best_combo", best_combo)
	cf.set_value("stats", "longest_run", longest_run)
	cf.save(PROFILE_PATH)


func today_string() -> String:
	return _today_string()


func _today_string() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]


func daily_seed() -> int:
	return _seed_from_string(_today_string())


func random_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ (randi() << 3)


func _seed_from_string(text: String) -> int:
	var value: int = 2166136261
	for i in text.length():
		value = ((value ^ text.unicode_at(i)) * 16777619) & 0x7fffffff
	return value


func start_run(daily: bool) -> void:
	pending_daily = daily
	run_seed = daily_seed() if daily else random_seed()


## Records the finished run. Returns true when it set a new record.
func submit_run(score: int, cores: int, deposits: int, combo: int, duration: float) -> bool:
	runs += 1
	total_cores += cores
	total_deposits += deposits
	best_combo = maxi(best_combo, combo)
	longest_run = maxf(longest_run, duration)
	var new_best := false
	if pending_daily:
		if score > daily_best:
			daily_best = score
			daily_best_date = _today_string()
			new_best = true
	elif score > best_score:
		best_score = score
		new_best = true
	save_profile()
	return new_best


func current_best() -> int:
	return daily_best if pending_daily else best_score