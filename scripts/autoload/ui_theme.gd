extends Node
## Builds the global UI theme at runtime so all screens share one visual
## language, and wires button audio feedback.

const ACCENT := Color("4ff5df")
const ACCENT_DIM := Color("1f9e9b")
const HOT := Color("ffb057")
const DANGER := Color("ff5b5b")
const TEXT := Color("d8f4f2")
const MUTED := Color("7fa3b8")
const PANEL_BG := Color("0a1420")
const DEEP_BG := Color("05070f")

var theme: Theme
var title_font: Font
var body_font: Font
var body_bold: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var orbitron: FontFile = load("res://assets/fonts/Orbitron.ttf")
	body_font = load("res://assets/fonts/Rajdhani-Medium.ttf")
	body_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	var title_variation := FontVariation.new()
	title_variation.base_font = orbitron
	title_variation.variation_opentype = {"wght": 900.0}
	title_variation.variation_embolden = 0.4
	title_font = title_variation
	_build_theme()


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)

	_setup_buttons()
	_setup_panels()
	_setup_variations()
	_setup_sliders()
	theme.set_color("separator", "HSeparator", Color(0.16, 0.42, 0.5, 0.55))
	theme.set_constant("separation", "HSeparator", 14)
	theme.set_stylebox("separator", "HSeparator", _line_box(Color(0.1, 0.3, 0.38, 0.8), 1))
	theme.set_color("font_color", "RichTextLabel", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font("normal_font", "RichTextLabel", body_font)
	theme.set_font("bold_font", "RichTextLabel", body_bold)
	theme.set_font_size("normal_font_size", "RichTextLabel", 20)


func _box(bg: Color, border: Color, width: int, radius: int, margin_h: int, margin_v: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	box.anti_aliasing = true
	return box


func _line_box(color: Color, height: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_top = height
	box.content_margin_bottom = height
	return box


func _setup_buttons() -> void:
	var normal := _box(Color(0.055, 0.11, 0.17, 0.92), Color(0.13, 0.32, 0.4, 0.9), 1, 8, 24, 12)
	var hover := _box(Color(0.08, 0.2, 0.27, 0.96), ACCENT, 2, 8, 24, 12)
	var pressed := _box(Color(0.02, 0.06, 0.1, 0.98), ACCENT_DIM, 2, 8, 24, 12)
	var focus := hover.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.07, 0.16, 0.22, 0.95)
	var disabled := _box(Color(0.04, 0.06, 0.09, 0.6), Color(0.14, 0.2, 0.24, 0.5), 1, 8, 24, 12)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("focus", type, focus)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_font("font", type, body_bold)
		theme.set_font_size("font_size", type, 22)
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, ACCENT)
		theme.set_color("font_pressed_color", type, ACCENT_DIM)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_disabled_color", type, Color(0.5, 0.6, 0.65, 0.6))
	theme.set_constant("outline_size", "Button", 0)
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", ACCENT)
	theme.set_color("font_pressed_color", "CheckButton", ACCENT)
	theme.set_font("font", "CheckButton", body_bold)
	theme.set_font_size("font_size", "CheckButton", 21)


func _setup_panels() -> void:
	var panel := _box(Color(0.035, 0.065, 0.105, 0.94), Color(0.13, 0.38, 0.45, 0.75), 1, 16, 30, 26)
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 26
	panel.shadow_offset = Vector2(0, 12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PopupMenu", _box(Color(0.035, 0.065, 0.105, 0.98), Color(0.13, 0.38, 0.45, 0.9), 1, 8, 10, 8))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)
	theme.set_font("font", "PopupMenu", body_bold)
	theme.set_stylebox("hover", "PopupMenu", _box(Color(0.08, 0.2, 0.27, 1.0), Color(0, 0, 0, 0), 0, 4, 10, 6))


func _setup_variations() -> void:
	_add_variation("TitleLabel", "Label", title_font, 112, Color(0.92, 1.0, 0.99))
	_add_variation("HeaderLabel", "Label", title_font, 34, ACCENT)
	_add_variation("SubHeaderLabel", "Label", body_bold, 20, MUTED)
	_add_variation("TaglineLabel", "Label", body_font, 26, MUTED)
	_add_variation("HudLabel", "Label", body_bold, 20, MUTED)
	_add_variation("HudValueLabel", "Label", body_bold, 40, Color(0.93, 1.0, 1.0))
	_add_variation("HudTimerLabel", "Label", body_bold, 58, Color(0.93, 1.0, 1.0))
	_add_variation("AccentLabel", "Label", body_bold, 22, ACCENT)
	_add_variation("HotLabel", "Label", body_bold, 22, HOT)
	_add_variation("DangerLabel", "Label", body_bold, 22, DANGER)
	_add_variation("HintLabel", "Label", body_font, 19, Color(0.62, 0.76, 0.82))
	_add_variation("StatLabel", "Label", body_bold, 24, TEXT)
	_add_variation("SmallLabel", "Label", body_font, 16, Color(0.5, 0.65, 0.72))

	# Filled accent button for the primary action.
	theme.set_type_variation("PrimaryButton", "Button")
	var normal := _box(Color(0.16, 0.7, 0.64, 0.94), ACCENT, 2, 8, 24, 13)
	var hover := _box(Color(0.25, 0.95, 0.85, 1.0), Color(0.85, 1.0, 0.98), 2, 8, 24, 13)
	var pressed := _box(Color(0.1, 0.5, 0.47, 1.0), Color(0.7, 1.0, 0.96), 2, 8, 24, 13)
	normal.shadow_color = Color(0, 0.8, 0.7, 0.22)
	normal.shadow_size = 16
	hover.shadow_color = Color(0.2, 1.0, 0.9, 0.38)
	hover.shadow_size = 22
	theme.set_stylebox("normal", "PrimaryButton", normal)
	theme.set_stylebox("hover", "PrimaryButton", hover)
	theme.set_stylebox("pressed", "PrimaryButton", pressed)
	theme.set_stylebox("focus", "PrimaryButton", hover)
	theme.set_color("font_color", "PrimaryButton", Color(0.01, 0.08, 0.09))
	theme.set_color("font_hover_color", "PrimaryButton", Color(0.01, 0.06, 0.07))
	theme.set_color("font_pressed_color", "PrimaryButton", Color(0.01, 0.06, 0.07))
	theme.set_font("font", "PrimaryButton", body_bold)
	theme.set_font_size("font_size", "PrimaryButton", 24)

	theme.set_type_variation("GhostButton", "Button")
	var ghost := _box(Color(0.04, 0.08, 0.12, 0.55), Color(0.12, 0.25, 0.3, 0.7), 1, 8, 20, 10)
	var ghost_hover := _box(Color(0.06, 0.15, 0.2, 0.8), ACCENT, 1, 8, 20, 10)
	theme.set_stylebox("normal", "GhostButton", ghost)
	theme.set_stylebox("hover", "GhostButton", ghost_hover)
	theme.set_stylebox("pressed", "GhostButton", pressed)
	theme.set_font("font", "GhostButton", body_bold)
	theme.set_font_size("font_size", "GhostButton", 19)


func _add_variation(name: String, base: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)


func _setup_sliders() -> void:
	var bg := _line_box(Color(0.1, 0.18, 0.24, 1.0), 5)
	bg.set_corner_radius_all(3)
	var fill := _line_box(ACCENT, 5)
	fill.set_corner_radius_all(3)
	var fill_hl := _line_box(Color(0.6, 1.0, 0.97), 5)
	fill_hl.set_corner_radius_all(3)
	theme.set_stylebox("slider", "HSlider", bg)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill_hl)
	theme.set_icon("grabber", "HSlider", _circle_texture(18, ACCENT))
	theme.set_icon("grabber_highlight", "HSlider", _circle_texture(18, Color(0.8, 1.0, 0.98)))


func _circle_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size * 0.5, size * 0.5)
	var r := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)


func apply(control: Control) -> void:
	control.theme = theme


func wire_buttons(root: Node, include_sliders: bool = true) -> void:
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or button.has_meta("ui_wired"):
			continue
		button.set_meta("ui_wired", true)
		button.mouse_entered.connect(_on_button_hover)
		button.pressed.connect(_on_button_pressed)
	if include_sliders:
		for child in root.find_children("*", "HSlider", true, false):
			var slider := child as HSlider
			if slider == null or slider.has_meta("ui_wired"):
				continue
			slider.set_meta("ui_wired", true)
			slider.drag_started.connect(func() -> void: AudioManager.play_ui("ui_hover"))


func _on_button_hover() -> void:
	AudioManager.play_sfx("ui_hover", -9.0)


func _on_button_pressed() -> void:
	AudioManager.play_ui("ui_click")