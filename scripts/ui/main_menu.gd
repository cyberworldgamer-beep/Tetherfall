extends Control
## Main menu: animated nebula backdrop, art panel, run selection and modals.

@onready var _background: ColorRect = $Background
@onready var _title: Label = $Content/VBox/Title
@onready var _best_label: Label = $Content/VBox/FooterBlock/BestLabel
@onready var _stats_label: Label = $Content/VBox/FooterBlock/StatsLabel
@onready var _fade: ColorRect = $FadeOverlay
@onready var _settings_panel: Control = $SettingsPanel
@onready var _controls_panel: Control = $ControlsPanel
@onready var _launch_button: Button = $Content/VBox/Buttons/LaunchButton
@onready var _daily_button: Button = $Content/VBox/Buttons/DailyButton

var _transitioning: bool = false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UITheme.apply(self)
	UITheme.wire_buttons(self)
	_fit_shader()
	resized.connect(_fit_shader)
	_settings_panel.hide()
	_controls_panel.hide()
	if _settings_panel.has_signal("closed"):
		_settings_panel.closed.connect(_on_modal_closed)
	if _controls_panel.has_signal("closed"):
		_controls_panel.closed.connect(_on_modal_closed)
	_update_profile_text()
	AudioManager.play_music("menu", 1.4)
	_fade_in()
	_start_title_pulse()


func _fit_shader() -> void:
	if _background.material is ShaderMaterial:
		(_background.material as ShaderMaterial).set_shader_parameter("resolution", size)


func _fade_in() -> void:
	_fade.modulate.a = 1.0
	_fade.color = UITheme.DEEP_BG
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _start_title_pulse() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(_title, "modulate", Color(0.92, 1.0, 1.0, 0.82), 2.6).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_title, "modulate", Color(1, 1, 1, 1), 2.6).set_ease(Tween.EASE_IN_OUT)


func _update_profile_text() -> void:
	if GameConfig.runs <= 0:
		_best_label.text = "NO RUNS LOGGED YET"
		_stats_label.text = "YOUR FIRST CONTRACT IS WAITING"
	else:
		var best := GameConfig.current_best()
		if GameConfig.pending_daily:
			best = GameConfig.daily_best
		_best_label.text = "BEST SCORE  %s" % _format_score(GameConfig.best_score)
		_stats_label.text = "RUNS %d   ·   CORES %d   ·   BEST CHAIN x%d   ·   DAILY %s" % [
			GameConfig.runs, GameConfig.total_cores, GameConfig.best_combo,
			_format_score(GameConfig.daily_best)
		]
	_daily_button.text = "DAILY CONTRACT  ·  %s" % GameConfig.today_string()


func _format_score(value: int) -> String:
	return str(value).pad_zeros(7)


func _on_launch_pressed() -> void:
	_begin_run(false)


func _on_daily_pressed() -> void:
	_begin_run(true)


func _begin_run(daily: bool) -> void:
	if _transitioning:
		return
	_transitioning = true
	GameConfig.start_run(daily)
	_set_buttons_disabled(true)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	)


func _set_buttons_disabled(disabled: bool) -> void:
	for child in $Content/VBox/Buttons.get_children():
		if child is Button:
			(child as Button).disabled = disabled


func _on_settings_pressed() -> void:
	_settings_panel.call("show_panel")


func _on_controls_pressed() -> void:
	_controls_panel.call("show_panel")


func _on_quit_pressed() -> void:
	_transitioning = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.4)
	tw.tween_callback(get_tree().quit)


func _on_modal_closed() -> void:
	_update_profile_text()
	_launch_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if _settings_panel.visible or _controls_panel.visible:
		return
	if event.is_action_pressed("ui_accept"):
		_begin_run(false)
		get_viewport().set_input_as_handled()