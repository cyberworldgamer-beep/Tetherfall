class_name GameOverScreen
extends Control
## End-of-run report card: score, deliveries, chain, record status and restart.

signal retry_requested
signal menu_requested

@onready var _panel: PanelContainer = $Center/Panel
@onready var _status_label: Label = $Center/Panel/VBox/StatusLabel
@onready var _new_best_label: Label = $Center/Panel/VBox/NewBestLabel
@onready var _score_value: Label = $Center/Panel/VBox/StatsGrid/ScoreValue
@onready var _cores_value: Label = $Center/Panel/VBox/StatsGrid/CoresValue
@onready var _deliveries_value: Label = $Center/Panel/VBox/StatsGrid/DeliveriesValue
@onready var _chain_value: Label = $Center/Panel/VBox/StatsGrid/ChainValue
@onready var _time_value: Label = $Center/Panel/VBox/StatsGrid/TimeValue
@onready var _record_label: Label = $Center/Panel/VBox/RecordLabel
@onready var _retry_button: Button = $Center/Panel/VBox/Buttons/RetryButton

var _shown: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply(self)
	UITheme.wire_buttons(self)
	_retry_button.pressed.connect(_on_retry_pressed)
	$Center/Panel/VBox/Buttons/MenuButton.pressed.connect(_on_menu_pressed)
	hide()


func show_result(data: Dictionary) -> void:
	_shown = true
	_status_label.text = str(data.get("reason", "SIGNAL LOST"))
	_score_value.text = str(int(data.get("score", 0))).pad_zeros(7)
	_cores_value.text = str(int(data.get("cores", 0)))
	_deliveries_value.text = str(int(data.get("deposits", 0)))
	_chain_value.text = "x%d" % int(data.get("chain", 1))
	_time_value.text = "%d s" % int(data.get("time", 0.0))
	var new_best := bool(data.get("new_best", false))
	_new_best_label.visible = new_best
	_record_label.text = "CONTRACT BEST  %s   ·   DAILY BEST  %s" % [
		str(int(data.get("best", 0))).pad_zeros(7),
		str(int(data.get("daily_best", 0))).pad_zeros(7),
	]
	show()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.94, 0.94)
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	_retry_button.grab_focus()
	if new_best:
		AudioManager.play_sfx("new_best", -2.0)


func _on_retry_pressed() -> void:
	AudioManager.play_ui("ui_click")
	retry_requested.emit()


func _on_menu_pressed() -> void:
	AudioManager.play_ui("ui_click")
	menu_requested.emit()