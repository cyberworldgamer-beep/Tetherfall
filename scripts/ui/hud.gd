class_name GameHUD
extends Control
## In-game HUD: reticle, gauges, objective markers, warnings and score popups.

@onready var _score_label: Label = $TopLeft/ScoreLabel
@onready var _combo_label: Label = $TopLeft/ComboLabel
@onready var _timer_label: Label = $TopCenter/TimerLabel
@onready var _mode_label: Label = $TopCenter/ModeLabel
@onready var _cargo_label: Label = $TopRight/CargoLabel
@onready var _warning_label: Label = $WarningLabel
@onready var _objective_label: Label = $BottomCenter/ObjectiveLabel
@onready var _hint_label: Label = $BottomCenter/HintLabel
@onready var _popup_layer: Control = $PopupLayer
@onready var _intro_fade: ColorRect = $IntroFade
@onready var _heat_overlay: ColorRect = $HeatOverlay
@onready var _damage_overlay: ColorRect = $DamageOverlay

var player: Node3D
var gate: Node3D
var camera: Camera3D
var game: Node

var _hull: int = 3
var _max_hull: int = 3
var _cores: int = 0
var _capacity: int = 3
var _boost: float = 1.0
var _combo: int = 1
var _combo_ratio: float = 0.0
var _time_left: float = 120.0
var _display_score: float = 0.0
var _target_score: int = 0
var _time: float = 0.0
var _nearest_core: Node3D
var _core_scan: float = 0.0
var _aim: Dictionary = {"valid": false, "distance": 0.0, "attached": false}
var _warning_tween: Tween
var _damage_tween: Tween
var _heat_material: ShaderMaterial
var _damage_material: ShaderMaterial
var _intro_played: bool = false


func _ready() -> void:
	UITheme.apply(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_material = _heat_overlay.material as ShaderMaterial
	_damage_material = _damage_overlay.material as ShaderMaterial
	_warning_label.modulate.a = 0.0
	_intro_fade.color = UITheme.DEEP_BG
	_set_combo_visual()
	_score_label.text = "0000000"
	_timer_label.text = "02:00"


func bind(game_node: Node, player_node: Node3D, gate_node: Node3D, camera_node: Camera3D) -> void:
	game = game_node
	player = player_node
	gate = gate_node
	camera = camera_node


func play_intro() -> void:
	if _intro_played:
		return
	_intro_played = true
	_intro_fade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_intro_fade, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_OUT)


func set_mode(text: String) -> void:
	_mode_label.text = text


func set_score(value: int) -> void:
	_target_score = value
	if _display_score < 1.0:
		_display_score = float(value)


func set_combo(multiplier: int, ratio: float) -> void:
	var changed := multiplier != _combo
	_combo = multiplier
	_combo_ratio = clampf(ratio, 0.0, 1.0)
	if changed:
		_set_combo_visual()
		var tw := create_tween()
		_combo_label.pivot_offset = _combo_label.size * 0.5
		tw.tween_property(_combo_label, "scale", Vector2(1.14, 1.14), 0.08)
		tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT)


func _set_combo_visual() -> void:
	_combo_label.text = "CHAIN x%d" % _combo
	var col := UITheme.HOT if _combo > 1 else UITheme.MUTED
	_combo_label.add_theme_color_override("font_color", col)


func set_hull(value: int, maximum: int) -> void:
	_hull = value
	_max_hull = maximum


func set_boost(ratio: float) -> void:
	_boost = clampf(ratio, 0.0, 1.0)


func set_cores(count: int, capacity: int) -> void:
	_cores = count
	_capacity = capacity
	_cargo_label.text = "CARGO  %d / %d" % [count, capacity]
	_cargo_label.add_theme_color_override("font_color", UITheme.ACCENT if count > 0 else UITheme.MUTED)


func set_timer(seconds: float) -> void:
	_time_left = maxf(seconds, 0.0)
	var total := int(ceil(_time_left))
	_timer_label.text = "%02d:%02d" % [total / 60, total % 60]
	if seconds <= 20.0:
		_timer_label.add_theme_color_override("font_color", UITheme.DANGER)
	else:
		_timer_label.add_theme_color_override("font_color", Color(0.93, 1.0, 1.0))


func set_heat(ratio: float) -> void:
	if _heat_material != null:
		_heat_material.set_shader_parameter("intensity", clampf(ratio, 0.0, 1.0) * 0.55)


func flash_damage() -> void:
	if _damage_material == null:
		return
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_material.set_shader_parameter("intensity", 0.8)
	_damage_tween = create_tween()
	var fade := func(v: float) -> void:
		_damage_material.set_shader_parameter("intensity", v)
	_damage_tween.tween_method(fade, 0.8, 0.0, 0.55)


func show_warning(text: String, duration: float = 2.0, color: Color = UITheme.HOT) -> void:
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_label.text = text
	_warning_label.add_theme_color_override("font_color", color)
	_warning_label.modulate.a = 0.0
	_warning_tween = create_tween()
	_warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.12)
	_warning_tween.tween_interval(duration)
	_warning_tween.tween_property(_warning_label, "modulate:a", 0.0, 0.45)


func set_objective(text: String) -> void:
	if _objective_label.text != text:
		_objective_label.text = text


func set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.visible = text != ""


func spawn_popup(text: String, color: Color, world_position: Vector3) -> void:
	if camera == null or _popup_layer == null:
		return
	var screen := camera.unproject_position(world_position)
	if camera.is_position_behind(world_position):
		screen = size * 0.5 + Vector2(0, -80)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UITheme.body_bold)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(260, 44)
	label.position = screen - Vector2(130, 22)
	_popup_layer.add_child(label)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 70.0, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(label.queue_free)


func _process(delta: float) -> void:
	_time += delta
	if _display_score < float(_target_score):
		_display_score = minf(float(_target_score), _display_score + maxf(60.0, absf(_target_score - _display_score) * 2.4) * delta)
	else:
		_display_score = float(_target_score)
	_score_label.text = str(int(_display_score)).pad_zeros(7)

	_core_scan -= delta
	if _core_scan <= 0.0:
		_core_scan = 0.25
		_find_nearest_core()

	if player != null and is_instance_valid(player) and player.has_method("get_aim_data"):
		_aim = player.call("get_aim_data")

	if _time_left <= 20.0:
		_timer_label.modulate.a = 0.75 + 0.25 * sin(_time * 7.0)
	else:
		_timer_label.modulate.a = 1.0

	if _hull <= 1 and _hull > 0:
		_damage_material.set_shader_parameter("intensity", 0.05 + 0.04 * sin(_time * 4.0))
	queue_redraw()


func _find_nearest_core() -> void:
	_nearest_core = null
	if player == null or not is_instance_valid(player) or _cores >= _capacity:
		return
	var best := 1.0e20
	for node in get_tree().get_nodes_in_group("cores"):
		if not (node is Node3D):
			continue
		var distance := player.global_position.distance_to((node as Node3D).global_position)
		if distance < best:
			best = distance
			_nearest_core = node as Node3D


func _draw() -> void:
	if size.x < 10.0:
		return
	_draw_frame()
	_draw_gauges()
	_draw_reticle()
	_draw_markers()
	_draw_control_hint()


func _draw_gauges() -> void:
	var width := size.x
	# Chain timer bar under the score block.
	var combo_bg := Rect2(52, 100, 220, 3)
	draw_rect(combo_bg, Color(0.1, 0.2, 0.24, 0.65), true)
	if _combo_ratio > 0.0:
		draw_rect(Rect2(52, 100, 220 * _combo_ratio, 3), _with_alpha(UITheme.HOT, 0.85), true)

	# Hull pips.
	var pip_right := width - 52.0
	var pip_y := 74.0
	for i in _max_hull:
		var center := Vector2(pip_right - 10.0 - (2 - i) * 27.0, pip_y)
		var filled := i < _hull
		var color := UITheme.ACCENT if filled else Color(0.36, 0.46, 0.52, 0.8)
		var pts := _diamond(center, 10.0)
		if filled:
			draw_colored_polygon(pts, _with_alpha(color, 0.3))
		_draw_closed(pts, color, 1.7)
	_draw_text_at("HULL", Vector2(pip_right - 136.0, pip_y + 4.0), 13, Color(0.62, 0.78, 0.84, 0.85))

	# Boost bar.
	var bar_rect := Rect2(width - 232.0, 116.0, 180.0, 7.0)
	draw_rect(bar_rect, Color(0.08, 0.14, 0.18, 0.75), true)
	var boost_color := UITheme.ACCENT if _boost > 0.24 else UITheme.DANGER
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * _boost, bar_rect.size.y)), _with_alpha(boost_color, 0.9), true)
	draw_rect(bar_rect, Color(0.25, 0.55, 0.55, 0.4), false, 1.0)
	_draw_text_at("BOOST", Vector2(bar_rect.position.x, bar_rect.position.y - 7.0), 13, Color(0.62, 0.78, 0.84, 0.85))

	# Cargo slots.
	var slots_y := 164.0
	for i in _capacity:
		var center := Vector2(width - 52.0 - 11.0 - (2 - i) * 32.0, slots_y)
		var filled := i < _cores
		var color := UITheme.ACCENT if filled else Color(0.36, 0.46, 0.52, 0.8)
		var pts := _hexagon(center, 10.0)
		if filled:
			draw_colored_polygon(pts, _with_alpha(color, 0.35))
		_draw_closed(pts, color, 1.6)
		if filled:
			draw_circle(center, 2.4, color)


func _draw_reticle() -> void:
	var center := size * 0.5
	var valid := bool(_aim.get("valid", false))
	var attached := bool(_aim.get("attached", false))
	var color := UITheme.ACCENT if valid else Color(0.78, 0.9, 0.9, 0.55)
	if attached:
		color = UITheme.HOT
	var gap := 7.0
	var length := 9.0 if not valid else 13.0
	draw_line(center + Vector2(-gap - length, 0), center + Vector2(-gap, 0), color, 1.6)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), color, 1.6)
	draw_line(center + Vector2(0, -gap - length), center + Vector2(0, -gap), color, 1.6)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), color, 1.6)
	draw_circle(center, 1.7, color)
	if valid:
		draw_arc(center, 24.0, 0.0, TAU, 40, _with_alpha(color, 0.28), 1.2)
		draw_arc(center, 30.0 + sin(_time * 6.0) * 2.0, -0.6, 0.6, 16, _with_alpha(color, 0.5), 1.5)
		var dist := float(_aim.get("distance", 0.0))
		var text := "TETHER  %d m" % int(dist)
		_draw_text_centered(text, center + Vector2(0, 58), 15, _with_alpha(color, 0.85))

	var speed := 0.0
	if player != null and is_instance_valid(player) and player.has_method("get_speed"):
		speed = float(player.call("get_speed"))
	_draw_text_centered("%d m/s" % int(speed), center + Vector2(0, 40), 14, Color(0.62, 0.78, 0.82, 0.7))


func _draw_markers() -> void:
	if camera == null or gate == null or not is_instance_valid(gate):
		return
	var gate_world := gate.global_position + Vector3(0, 12.0, 0)
	var gate_info := _project_marker(gate_world, 92.0)
	if gate_info.get("visible", false):
		var p: Vector2 = gate_info["pos"]
		var on_edge: bool = gate_info["edge"]
		var distance := 0.0
		if player != null and is_instance_valid(player):
			distance = player.global_position.distance_to(gate.global_position)
		var carrying := _cores > 0
		var col := UITheme.ACCENT if carrying else Color(0.55, 0.8, 0.82, 0.75)
		var label := ("DELIVER  %d m" % int(distance)) if carrying else ("GATE  %d m" % int(distance))
		if on_edge:
			var center := size * 0.5
			draw_line(p + (center - p).normalized() * 16.0, p, _with_alpha(col, 0.3), 1.0)
		_draw_marker(p, col, carrying)
		_draw_text_at(label, p + Vector2(18, 7), 17, col)
		if carrying:
			draw_arc(p, 17.0 + sin(_time * 5.0) * 3.0, 0, TAU, 28, _with_alpha(col, 0.35), 1.0)

	if _nearest_core != null and is_instance_valid(_nearest_core):
		var info := _project_marker(_nearest_core.global_position, 70.0)
		if info.get("visible", false):
			var cp: Vector2 = info["pos"]
			var dist := 0.0
			if player != null and is_instance_valid(player):
				dist = player.global_position.distance_to(_nearest_core.global_position)
			var ccol := _with_alpha(Color(0.45, 1.0, 0.92), 0.8)
			_draw_closed(_hexagon(cp, 7.0), ccol, 1.4)
			draw_circle(cp, 1.6, ccol)
			_draw_text_at("CORE  %d m" % int(dist), cp + Vector2(14, 5), 14, _with_alpha(ccol, 0.75))


func _project_marker(world: Vector3, margin: float) -> Dictionary:
	if camera == null:
		return {"visible": false}
	var behind := camera.is_position_behind(world)
	var projected := camera.unproject_position(world)
	var min_x := margin
	var max_x := size.x - margin
	var min_y := margin
	var max_y := size.y - margin
	if not behind and projected.x > min_x and projected.x < max_x and projected.y > min_y and projected.y < max_y:
		return {"visible": true, "pos": projected, "edge": false}
	var center := size * 0.5
	var direction := projected - center
	if direction.length_squared() < 1.0:
		direction = Vector2(0, 1)
	if behind:
		direction = -direction
	direction = direction.normalized()
	var scale := minf(
		absf((size.x * 0.5 - margin) / direction.x) if absf(direction.x) > 0.001 else 9999.0,
		absf((size.y * 0.5 - margin) / direction.y) if absf(direction.y) > 0.001 else 9999.0
	)
	return {"visible": true, "pos": center + direction * scale, "edge": true}


func _draw_marker(center: Vector2, color: Color, carry: bool) -> void:
	var radius := 11.0 if carry else 8.0
	draw_colored_polygon(_diamond(center, radius), _with_alpha(color, 0.18))
	_draw_closed(_diamond(center, radius), color, 1.6)
	draw_circle(center, 2.0, color)


func _draw_frame() -> void:
	var margin := 30.0
	var length := 54.0
	var col := Color(0.3, 0.75, 0.72, 0.18)
	draw_line(Vector2(margin, margin), Vector2(margin + length, margin), col, 1.2)
	draw_line(Vector2(margin, margin), Vector2(margin, margin + length), col, 1.2)
	draw_line(Vector2(size.x - margin, margin), Vector2(size.x - margin - length, margin), col, 1.2)
	draw_line(Vector2(size.x - margin, margin), Vector2(size.x - margin, margin + length), col, 1.2)
	draw_line(Vector2(margin, size.y - margin), Vector2(margin + length, size.y - margin), col, 1.2)
	draw_line(Vector2(margin, size.y - margin), Vector2(margin, size.y - margin - length), col, 1.2)
	draw_line(Vector2(size.x - margin, size.y - margin), Vector2(size.x - margin - length, size.y - margin), col, 1.2)
	draw_line(Vector2(size.x - margin, size.y - margin), Vector2(size.x - margin, size.y - margin - length), col, 1.2)


func _draw_control_hint() -> void:
	if not GameConfig.show_hints:
		return
	_draw_text_at("LMB / F TETHER     RMB / X RELEASE     WHEEL REEL", Vector2(size.x - 52, size.y - 34), 13,
		Color(0.45, 0.62, 0.68, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 620.0)


func _draw_text_at(text: String, pos: Vector2, font_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(UITheme.body_font, pos, text, align, width, font_size, color)


func _draw_text_centered(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	var font := UITheme.body_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, pos - Vector2(text_size.x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	])


func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _draw_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)