extends Control
## Modal settings page shared by the main menu and the pause menu.

signal closed

@onready var _music_slider: HSlider = $Center/Panel/VBox/AudioGrid/MusicBox/MusicSlider
@onready var _music_value: Label = $Center/Panel/VBox/AudioGrid/MusicBox/MusicValue
@onready var _sfx_slider: HSlider = $Center/Panel/VBox/AudioGrid/SfxBox/SfxSlider
@onready var _sfx_value: Label = $Center/Panel/VBox/AudioGrid/SfxBox/SfxValue
@onready var _sens_slider: HSlider = $Center/Panel/VBox/ControlsGrid/SensBox/SensSlider
@onready var _sens_value: Label = $Center/Panel/VBox/ControlsGrid/SensBox/SensValue
@onready var _invert_check: CheckButton = $Center/Panel/VBox/ControlsGrid/InvertCheck
@onready var _quality_option: OptionButton = $Center/Panel/VBox/VideoGrid/QualityOption
@onready var _fullscreen_check: CheckButton = $Center/Panel/VBox/VideoGrid/FullscreenCheck
@onready var _hints_check: CheckButton = $Center/Panel/VBox/VideoGrid/HintsCheck
@onready var _done_button: Button = $Center/Panel/VBox/Footer/DoneButton

var _loading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply(self)
	UITheme.wire_buttons(self)
	_quality_option.clear()
	_quality_option.add_item("LOW  ·  PERFORMANCE")
	_quality_option.add_item("MEDIUM  ·  BALANCED")
	_quality_option.add_item("HIGH  ·  FULL EFFECTS")
	_quality_option.item_selected.connect(_on_quality_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_hints_check.toggled.connect(_on_hints_toggled)
	_invert_check.toggled.connect(_on_invert_toggled)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_sens_slider.value_changed.connect(_on_sens_changed)
	_sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	$Center/Panel/VBox/Footer/DoneButton.pressed.connect(close)
	$Center/Panel/VBox/Footer/ResetButton.pressed.connect(_reset_defaults)
	hide()


func show_panel() -> void:
	_sync_from_config()
	visible = true
	_done_button.grab_focus()


func close() -> void:
	GameConfig.save_settings()
	hide()
	closed.emit()


func _sync_from_config() -> void:
	_loading = true
	_music_slider.value = GameConfig.music_volume * 100.0
	_sfx_slider.value = GameConfig.sfx_volume * 100.0
	_sens_slider.value = GameConfig.mouse_sensitivity
	_invert_check.button_pressed = GameConfig.invert_y
	_quality_option.selected = GameConfig.quality
	_fullscreen_check.button_pressed = GameConfig.fullscreen
	_hints_check.button_pressed = GameConfig.show_hints
	_update_value_labels()
	_loading = false


func _update_value_labels() -> void:
	_music_value.text = "%d%%" % int(round(_music_slider.value))
	_sfx_value.text = "%d%%" % int(round(_sfx_slider.value))
	_sens_value.text = "%.2fx" % _sens_slider.value


func _on_music_changed(value: float) -> void:
	GameConfig.music_volume = clampf(value / 100.0, 0.0, 1.0)
	_update_value_labels()
	if not _loading:
		AudioManager.settings_changed()


func _on_sfx_changed(value: float) -> void:
	GameConfig.sfx_volume = clampf(value / 100.0, 0.0, 1.0)
	_update_value_labels()
	if not _loading:
		AudioManager.settings_changed()


func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed:
		AudioManager.play_sfx("tether_attach", -6.0, 1.2)


func _on_sens_changed(value: float) -> void:
	GameConfig.mouse_sensitivity = value
	_update_value_labels()


func _on_invert_toggled(pressed: bool) -> void:
	GameConfig.invert_y = pressed


func _on_quality_selected(index: int) -> void:
	GameConfig.quality = clampi(index, 0, 2)
	if not _loading:
		GameConfig.settings_changed.emit()


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameConfig.fullscreen = pressed
	GameConfig.save_settings()


func _on_hints_toggled(pressed: bool) -> void:
	GameConfig.show_hints = pressed


func _reset_defaults() -> void:
	GameConfig.music_volume = 0.62
	GameConfig.sfx_volume = 0.85
	GameConfig.mouse_sensitivity = 1.0
	GameConfig.invert_y = false
	GameConfig.quality = 2
	GameConfig.fullscreen = false
	GameConfig.show_hints = true
	GameConfig.save_settings()
	_sync_from_config()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()