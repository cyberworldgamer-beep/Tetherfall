extends Control
## Procedural 2D sidebar art for the main menu: a tethered salvage drone
## drifting beside a fractured asteroid. No textures required.

var _rock: PackedVector2Array = PackedVector2Array()
var _rock_inner: PackedVector2Array = PackedVector2Array()
var _rock2: PackedVector2Array = PackedVector2Array()
var _dust: Array[Vector3] = [] # x, y, phase
var _time: float = 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.body_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 20771
	for i in 26:
		var angle := TAU * float(i) / 26.0
		var radius := rng.randf_range(0.82, 1.10)
		_rock.append(Vector2(cos(angle), sin(angle)) * radius)
	for i in 18:
		var angle := TAU * float(i) / 18.0
		var radius := rng.randf_range(0.96, 1.04)
		_rock_inner.append(Vector2(cos(angle), sin(angle)) * radius)
	for i in 14:
		var angle := TAU * float(i) / 14.0
		var radius := rng.randf_range(0.7, 1.16)
		_rock2.append(Vector2(cos(angle), sin(angle)) * radius)
	for i in 46:
		_dust.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	var base := minf(w, h)

	_draw_system_arcs(w, h, base)
	_draw_main_asteroid(w, h, base)
	_draw_second_asteroid(w, h, base)
	_draw_tether_and_drone(w, h, base)
	_draw_hud_marks(w, h, base)
	_draw_dust(w, h, base)
	_draw_corner_brackets(w, h, base)


func _draw_system_arcs(w: float, h: float, base: float) -> void:
	var c := Vector2(w * 0.79, h * 0.58)
	var r := base * 0.30
	# Dashed orbital rings.
	for ring in 2:
		var radius := r * (1.0 + ring * 0.42)
		var segments := 40
		for i in segments:
			if i % 3 == 0:
				continue
			var a0 := TAU * (float(i) / segments) + _time * (0.035 if ring == 0 else -0.02)
			var a1 := a0 + TAU / segments * 0.7
			draw_arc(c, radius, a0, a1, 4, Color(0.22, 0.85, 0.78, 0.16 - ring * 0.06), 1.2)
	# Angular marker ticks.
	for i in 12:
		var angle := TAU * float(i) / 12.0 + _time * 0.04
		var p0 := c + Vector2(cos(angle), sin(angle)) * r * 1.35
		var p1 := c + Vector2(cos(angle), sin(angle)) * r * (1.39 if i % 3 == 0 else 1.36)
		draw_line(p0, p1, Color(0.3, 0.95, 0.88, 0.28), 1.5)


func _draw_main_asteroid(w: float, h: float, base: float) -> void:
	var c := Vector2(w * 0.815, h * 0.585)
	var r := base * 0.195
	# Halo.
	for i in 5:
		draw_circle(c, r * (1.03 + i * 0.055), Color(0.05, 0.55, 0.55, 0.028))
	# Silhouette with slow rotation.
	var rot := _time * 0.012 + 0.4
	var pts := PackedVector2Array()
	for p in _rock:
		pts.append(c + p.rotated(rot) * r)
	draw_colored_polygon(pts, Color(0.035, 0.055, 0.08, 0.98))
	# Interior rim / shading.
	var inner := PackedVector2Array()
	for p in _rock_inner:
		inner.append(c + p.rotated(rot) * r * 0.97)
	draw_colored_polygon(inner, Color(0.045, 0.075, 0.10, 0.55))
	# Outline.
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.22, 0.72, 0.68, 0.22), 1.5)
	# Rim light on the star side (upper left).
	draw_arc(c, r * 0.985, PI * 0.78, PI * 1.52, 28, Color(0.55, 1.0, 0.92, 0.32), 2.0)
	# Craters.
	var crater_data := [
		[Vector2(-0.32, -0.12), 0.26], [Vector2(0.28, 0.22), 0.20],
		[Vector2(-0.02, 0.38), 0.14], [Vector2(0.40, -0.28), 0.12],
		[Vector2(-0.50, 0.22), 0.09],
	]
	for crater in crater_data:
		var cp: Vector2 = c + (crater[0] as Vector2).rotated(rot) * r
		var cr: float = float(crater[1]) * r
		draw_circle(cp, cr, Color(0.025, 0.04, 0.055, 0.85))
		draw_arc(cp, cr, PI * 1.05, PI * 1.75, 16, Color(0.2, 0.55, 0.56, 0.20), 1.0)
	# Emissive crystal veins.
	var veins := [Vector2(-0.36, 0.04), Vector2(-0.18, 0.30), Vector2(0.10, 0.20), Vector2(0.24, -0.08)]
	for i in veins.size() - 1:
		var a := c + (veins[i] as Vector2).rotated(rot) * r
		var b := c + (veins[i + 1] as Vector2).rotated(rot) * r
		draw_line(a, b, Color(0.3, 1.0, 0.9, 0.35), 1.6)
		draw_line(a, b, Color(0.4, 1.0, 0.9, 0.08), 5.0)
	# Anchor point glow.
	var anchor := c + Vector2(-0.62, -0.52).rotated(rot) * r
	draw_circle(anchor, 9.0, Color(0.35, 1.0, 0.9, 0.08))
	draw_circle(anchor, 3.2, Color(0.7, 1.0, 0.95, 0.9))
	draw_arc(anchor, 6.0 + sin(_time * 2.0) * 1.5, 0, TAU, 14, Color(0.4, 1.0, 0.92, 0.35), 1.0)


func _draw_second_asteroid(w: float, h: float, base: float) -> void:
	var c := Vector2(w * 0.925, h * 0.28)
	var r := base * 0.045
	var rot := -_time * 0.03
	var pts := PackedVector2Array()
	for p in _rock2:
		pts.append(c + p.rotated(rot) * r)
	draw_colored_polygon(pts, Color(0.04, 0.06, 0.09, 0.95))
	draw_arc(c, r, PI * 0.7, PI * 1.5, 12, Color(0.45, 0.95, 0.88, 0.25), 1.2)


func _draw_tether_and_drone(w: float, h: float, base: float) -> void:
	var bob := sin(_time * 0.7) * base * 0.011
	var sway := sin(_time * 0.35 + 1.2) * base * 0.008
	var drone := Vector2(w * 0.675 + sway, h * 0.315 + bob)
	var anchor := Vector2(w * 0.815, h * 0.585) + Vector2(-0.62, -0.52).rotated(_time * 0.012 + 0.4) * base * 0.195
	var mid := (drone + anchor) * 0.5 + Vector2(-base * 0.02, base * 0.045)
	var curve := _quadratic(drone, mid, anchor, 28)
	# Tether glow.
	for layer in 3:
		var width := [7.0, 3.2, 1.2][layer] as float
		var alpha := [0.035, 0.16, 0.65][layer] as float
		var col := Color(0.3, 1.0, 0.92, alpha)
		draw_polyline(curve, col, width)

	# Drone glow.
	draw_circle(drone, base * 0.035, Color(0.2, 0.9, 0.95, 0.045))
	draw_circle(drone, base * 0.018, Color(0.3, 1.0, 1.0, 0.08))
	var angle := (anchor - drone).angle() + PI * 0.5
	# Hull.
	var hull_local := PackedVector2Array([
		Vector2(0, -20), Vector2(13, -5), Vector2(9, 12), Vector2(-9, 12), Vector2(-13, -5)
	])
	var hull := PackedVector2Array()
	for p in hull_local:
		hull.append(drone + p.rotated(angle) * (base / 900.0))
	draw_colored_polygon(hull, Color(0.75, 0.97, 0.95, 0.95))
	# Cockpit stripe.
	var stripe := PackedVector2Array()
	for p in [Vector2(-2, -12), Vector2(4, -12), Vector2(6, 6), Vector2(0, 8)]:
		stripe.append(drone + (p as Vector2).rotated(angle) * (base / 900.0))
	draw_colored_polygon(stripe, Color(0.2, 0.9, 0.85, 0.9))
	# Side pods.
	for side in [-1.0, 1.0]:
		var p0: Vector2 = drone + Vector2(18.0 * side, -2.0).rotated(angle) * (base / 900.0)
		var p1: Vector2 = drone + Vector2(18.0 * side, 9.0).rotated(angle) * (base / 900.0)
		draw_line(p0, p1, Color(0.6, 0.95, 0.92, 0.8), 3.0)
		draw_circle(p0, 2.0, Color(1.0, 0.7, 0.35, 0.9))
	# Engine glow opposite the tether.
	var back: Vector2 = drone + Vector2(0, 18).rotated(angle) * (base / 900.0)
	var flame_tip: Vector2 = drone + Vector2(0, 34 + sin(_time * 8.0) * 4).rotated(angle) * (base / 900.0)
	draw_line(back, flame_tip, Color(0.55, 1.0, 0.95, 0.7), 3.0)
	draw_line(back, flame_tip, Color(0.35, 0.95, 1.0, 0.14), 10.0)


func _draw_hud_marks(w: float, h: float, base: float) -> void:
	var font := _font
	if font == null:
		return
	var alpha := 0.55 + 0.15 * sin(_time * 1.2)
	var labels := [
		["ANCHOR 04 // LOCKED", Vector2(w * 0.70, h * 0.695), UITheme.ACCENT, 15],
		["MASS 8.7 t     SPIN 0.02 r/s", Vector2(w * 0.70, h * 0.715), UITheme.MUTED, 13],
		["TETHER TENSION  42.0 m", Vector2(w * 0.70, h * 0.735), UITheme.MUTED, 13],
	]
	for item in labels:
		var text: String = item[0]
		var pos: Vector2 = item[1]
		var col: Color = item[2]
		var fs: int = item[3]
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, alpha))
	# Target bracket around drone.
	var drone := Vector2(w * 0.675, h * 0.315)
	var box := base * 0.062
	var c := Color(0.5, 1.0, 0.95, 0.28)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = drone + (corner as Vector2) * box
		draw_line(p, p - Vector2(corner.x * 12.0, 0), c, 1.2)
		draw_line(p, p - Vector2(0, corner.y * 12.0), c, 1.2)
	# Scale legend right side.
	var ticks_start := Vector2(w * 0.955, h * 0.70)
	draw_line(ticks_start, ticks_start + Vector2(0, base * 0.14), Color(0.3, 0.8, 0.78, 0.3), 1.0)
	for i in 5:
		var y := ticks_start.y + base * 0.14 * i / 4.0
		draw_line(Vector2(ticks_start.x - 6, y), Vector2(ticks_start.x, y), Color(0.3, 0.8, 0.78, 0.3), 1.0)


func _draw_dust(w: float, h: float, base: float) -> void:
	for d in _dust:
		var drift := fmod(d.x - _time * 0.004 + 1.0, 1.0)
		var x := drift * w
		var y := d.y * h + sin(_time * 0.5 + d.z) * base * 0.012
		var a := 0.05 + 0.14 * (0.5 + 0.5 * sin(_time * 1.5 + d.z * 3.0))
		draw_circle(Vector2(x, y), 1.2 if d.z > 2.0 else 0.8, Color(0.55, 0.9, 0.92, a))


func _draw_corner_brackets(w: float, h: float, base: float) -> void:
	var margin := base * 0.035
	var length := base * 0.045
	var col := Color(0.3, 0.7, 0.68, 0.22)
	# Top right.
	draw_line(Vector2(w - margin, margin), Vector2(w - margin - length, margin), col, 1.5)
	draw_line(Vector2(w - margin, margin), Vector2(w - margin, margin + length), col, 1.5)
	# Bottom right.
	draw_line(Vector2(w - margin, h - margin), Vector2(w - margin - length, h - margin), col, 1.5)
	draw_line(Vector2(w - margin, h - margin), Vector2(w - margin, h - margin - length), col, 1.5)
	if _font != null:
		draw_string(_font, Vector2(w - margin - 210, margin + 18), "SECTOR 7 // KESSLER BELT",
			HORIZONTAL_ALIGNMENT_RIGHT, 210, 13, Color(0.35, 0.7, 0.72, 0.4))


func _quadratic(a: Vector2, control: Vector2, b: Vector2, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		out.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return out