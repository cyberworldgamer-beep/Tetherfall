extends Control
## Flight manual modal (static reference content).

signal closed

@onready var _done_button: Button = $Center/Panel/VBox/Footer/DoneButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UITheme.apply(self)
	UITheme.wire_buttons(self)
	_done_button.pressed.connect(close)
	hide()


func show_panel() -> void:
	visible = true
	_done_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()