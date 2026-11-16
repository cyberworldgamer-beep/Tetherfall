class_name PauseMenu
extends Control
## Pause overlay. Runs while the scene tree is paused and owns the settings
## modal so audio/visual options stay reachable mid-run.

signal resumed
signal restart_requested
signal abandon_requested

@onready var _panel: PanelContainer = $Center/Panel
@onready var _mode_label: Label = $Center/Panel/VBox/ModeLabel
@onready var _score_value: Label = $Center/Panel/VBox/StatsGrid/ScoreValue
@onready var _run_value: Label = $Center/Panel/VBox/StatsGrid/RunValue
@onready var _resume_button: Button = $Center/Panel/VBox/Buttons/ResumeButton
@onready var _settings_panel: Control = $SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply(self)
	UITheme.wire_buttons(self)
	_settings_panel.hide()
	if _settings_panel.has_signal("closed"):
		_settings_panel.closed.connect(_on_settings_closed)
	_resume_button.pressed.connect(_on_resume_pressed)
	$Center/Panel/VBox/Buttons/SettingsButton.pressed.connect(_on_settings_pressed)
	$Center/Panel/VBox/Buttons/RestartButton.pressed.connect(_on_restart_pressed)
	$Center/Panel/VBox/Buttons/AbandonButton.pressed.connect(_on_abandon_pressed)
	hide()


func show_panel(score: int, mode_text: String) -> void:
	_mode_label.text = mode_text
	_score_value.text = str(score).pad_zeros(7)
	_run_value.text = "PAUSED"
	show()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.96, 0.96)
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_resume_button.grab_focus()


func hide_panel() -> void:
	_settings_panel.hide()
	hide()


func is_settings_open() -> bool:
	return _settings_panel.visible


func _on_resume_pressed() -> void:
	if _settings_panel.visible:
		return
	AudioManager.play_ui("ui_click")
	hide_panel()
	resumed.emit()


func _on_settings_pressed() -> void:
	_settings_panel.call("show_panel")


func _on_settings_closed() -> void:
	_resume_button.grab_focus()


func _on_restart_pressed() -> void:
	hide_panel()
	restart_requested.emit()


func _on_abandon_pressed() -> void:
	hide_panel()
	abandon_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _settings_panel.visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_panel()
		resumed.emit()