class_name Dimming
extends Boss
## The Dimming (final boss, level 10): a vast shadow-heart. Patterns:
##  rain - rises and marks the floor; orbs of darkness fall on the marks
##  wave - sweeps low to one side and sends rolling shockwaves at the player
##  dive - tracks the player from above, slams into the floor and is stuck (open eye) - punish it
## Phase 2: faster, more orbs, and calls shade wisps once.

var _waves := 0
var _goal := Vector2.ZERO
var _rain_left := 0


func setup() -> void:
	boss_name = "The Dimming"
	max_hp = 40
	body_size = Vector2(64, 56)
	flying = true
	eye_color = Color("#c9a6ff")
	patterns = ["rain", "wave", "dive", "dive"]


func _high_y() -> float:
	return floor_y - 180.0


func _low_y() -> float:
	return floor_y - body_size.y * 0.5 - 2.0


func _move_to(goal: Vector2, speed: float) -> void:
	velocity = ((goal - global_position) * 3.0).limit_length(speed)


func ai(delta: float) -> void:
	st_t -= delta
	var fast := phase == 2
	match st:
		"dormant":
			velocity = Vector2.ZERO
		"intro":
			_move_to(Vector2(arena.get_center().x, _high_y()), 160.0)
			if st_t <= 0.0:
				goto_state("idle", 1.0)
		"idle":
			face_player()
			var p := player()
			var px := p.global_position.x if p != null else arena.get_center().x
			_move_to(Vector2(lerpf(arena.get_center().x, px, 0.4), _high_y() + sin(t * 1.5) * 14.0), 140.0)
			if st_t <= 0.0:
				_begin(pick_pattern())
		"rain_wind":
			_move_to(Vector2(arena.get_center().x, _high_y() - 30.0), 160.0)
			if st_t <= 0.0:
				_rain()
				_rain_left -= 1
				if _rain_left > 0:
					goto_state("rain_wind", 0.9)
				else:
					goto_state("idle", 1.4 if fast else 1.7)
		"wave_move":
			_move_to(_goal, 360.0)
			face_player()
			if global_position.distance_to(_goal) < 12.0 or st_t <= 0.0:
				_waves = 4 if fast else 3
				goto_state("wave_fire", 0.35)
		"wave_fire":
			velocity = Vector2.ZERO
			face_player()
			if st_t <= 0.0:
				spawn_shockwave(global_position.x + facing * 40.0, facing, 330.0 if fast else 280.0)
				Audio.play("slam", 0.1, -4.0)
				_waves -= 1
				if _waves > 0:
					goto_state("wave_fire", 0.5 if fast else 0.65)
				else:
					goto_state("idle", 1.0)
		"dive_track":
			var p2 := player()
			var tx := p2.global_position.x if p2 != null else global_position.x
			_move_to(Vector2(tx, _high_y()), 300.0)
			if st_t <= 0.0:
				goto_state("dive_wind", 0.35)
				Audio.play("swoop", 0.0)
		"dive_wind":
			velocity = Vector2.ZERO
			if st_t <= 0.0:
				goto_state("dive", 2.0)
		"dive":
			velocity = Vector2(0, 760.0)
			if is_on_floor() or global_position.y >= _low_y() or st_t <= 0.0:
				velocity = Vector2.ZERO
				Audio.play("slam", 0.0)
				FX.shake(self, 9.0, 0.4)
				spawn_shockwave(global_position.x - 36.0, -1, 240.0)
				spawn_shockwave(global_position.x + 36.0, 1, 240.0)
				goto_state("stuck", 1.3 if fast else 1.7)
		"stuck":
			velocity = Vector2.ZERO
			if st_t <= 0.0:
				goto_state("rise", 0.8)
		"rise":
			_move_to(Vector2(global_position.x, _high_y()), 260.0)
			if st_t <= 0.0:
				goto_state("idle", 0.7 if fast else 1.0)
	clamp_to_arena(6.0)


func _begin(p: String) -> void:
	match p:
		"rain":
			_rain_left = 2 if phase == 2 else 1
			goto_state("rain_wind", 0.6)
			Audio.play("roar", 0.1, -8.0)
		"wave":
			var pp := player()
			var px := pp.global_position.x if pp != null else arena.get_center().x
			var left := arena.position.x + 70.0
			var right := arena.end.x - 70.0
			_goal = Vector2(left if absf(px - left) > absf(px - right) else right, _low_y() - 10.0)
			goto_state("wave_move", 2.0)
		_:
			goto_state("dive_track", 1.0 if phase == 2 else 1.3)


func _rain() -> void:
	var n := 8 if phase == 2 else 6
	var xs: Array[float] = []
	var p := player()
	if p != null:
		xs.append(p.global_position.x)
	var tries := 0
	while xs.size() < n and tries < 60:
		tries += 1
		var x := randf_range(arena.position.x + 30.0, arena.end.x - 30.0)
		var ok := true
		for o in xs:
			if absf(o - x) < 56.0:
				ok = false
		if ok:
			xs.append(x)
	for x in xs:
		var m := Boss.Marker.new()
		m.color = eye_color
		m.life = 0.85
		m.position = Vector2(x, floor_y)
		level.enemy_layer.add_child(m)
		_drop_later(x, 0.6)


func _drop_later(x: float, delay: float) -> void:
	await get_tree().create_timer(delay, false).timeout
	if dead or not is_inside_tree():
		return
	spawn_orb(Vector2(x, floor_y - 260.0), Vector2(0, 380.0), eye_color, 0.0, 8.0)


func on_phase2() -> void:
	super.on_phase2()
	for i in 2:
		var wsp := Wisp.new()
		wsp.position = global_position + Vector2((i * 2 - 1) * 80.0, 20.0)
		wsp.leash = 420.0
		wsp.heal_drop_chance = 0.6
		level.add_enemy(wsp)


func draw_body() -> void:
	var col := body_color()
	var pulse := 1.0 + 0.05 * sin(t * 3.0)
	var open := st == "stuck" or st == "dive_wind"
	# tendrils
	for i in 7:
		var a := PI * 0.15 + PI * 0.7 * float(i) / 6.0
		var base := Vector2(cos(a) * 26.0, sin(a) * 20.0)
		var tip := base + Vector2(cos(a) * 18.0 + sin(t * 2.0 + i) * 6.0, 26.0 + sin(t * 3.0 + i * 1.7) * 8.0)
		draw_line(base, tip, col, 5.0)
		draw_line(base, tip, Color(eye_color.r, eye_color.g, eye_color.b, 0.25), 1.5)
	# heart mass
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		var r := 30.0 * pulse + sin(a * 5.0 + t * 2.0) * 3.0
		pts.append(Vector2(cos(a) * r * 1.1, sin(a) * r * 0.9))
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(eye_color.r, eye_color.g, eye_color.b, 0.6) if flash <= 0.0 else Color.WHITE, 2.0)
	# the great eye
	var ey := 0.5 if not open else 9.0
	if st == "dive_wind" and fmod(t, 0.12) < 0.06:
		ey = 6.0
	draw_colored_polygon(ellipse(Vector2(0, 0), 15.0, ey + 1.0, 18), Color(0.05, 0.02, 0.08))
	if open:
		draw_colored_polygon(ellipse(Vector2(0, 0), 12.0, ey, 18), Color(0.9, 0.85, 1.0))
		draw_circle(Vector2(3, 0), 5.0, eye_color)
		draw_circle(Vector2(3, 0), 2.2, Color(0.05, 0.02, 0.08))
	else:
		draw_line(Vector2(-14, 0), Vector2(14, 0), eye_color, 2.0)
	if st == "rain_wind":
		draw_circle(Vector2(0, -40), 10.0 + 4.0 * sin(t * 12.0), Color(eye_color.r, eye_color.g, eye_color.b, 0.4))
