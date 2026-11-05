class_name AshenKing
extends Boss
## The Ashen King (boss, level 9). Hovers just above the floor of his throne room. Patterns:
##  fan     - vanishes, reappears on the far side, fires a fan of ember orbs (two volleys in phase 2)
##  summon  - calls shade wisps (max 3 alive)
##  thorns  - a line of thorns erupts from him toward the player (from both sides in phase 2)

var _wisps: Array = []
var _volleys := 0


func setup() -> void:
	boss_name = "The Ashen King"
	max_hp = 30
	body_size = Vector2(36, 64)
	flying = true
	eye_color = Color("#ffd36a")
	patterns = ["fan", "summon", "thorns", "fan", "thorns"]


func ai(delta: float) -> void:
	st_t -= delta
	var fast := phase == 2
	var hover_y := floor_y - body_size.y * 0.5 - 6.0 + sin(t * 2.0) * 4.0
	match st:
		"dormant":
			velocity = Vector2.ZERO
		"intro":
			velocity = Vector2(0, (hover_y - global_position.y) * 3.0)
			face_player()
			if st_t <= 0.0:
				goto_state("idle", 0.8)
		"idle":
			face_player()
			var drift := facing * 30.0 if absf(to_player().x) > 140.0 else -facing * 20.0
			velocity = Vector2(drift, (hover_y - global_position.y) * 3.0)
			if st_t <= 0.0:
				_begin(pick_pattern())
		"tp_out":
			velocity = Vector2.ZERO
			modulate.a = clampf(st_t / 0.3, 0.0, 1.0)
			if st_t <= 0.0:
				var p := player()
				var px := p.global_position.x if p != null else arena.get_center().x
				var left := arena.position.x + 70.0
				var right := arena.end.x - 70.0
				global_position.x = left if absf(px - left) > absf(px - right) else right
				global_position.y = hover_y
				Audio.play("teleport", 0.05)
				goto_state("tp_in", 0.3)
		"tp_in":
			velocity = Vector2.ZERO
			modulate.a = 1.0 - clampf(st_t / 0.3, 0.0, 1.0)
			face_player()
			if st_t <= 0.0:
				modulate.a = 1.0
				_volleys = 2 if fast else 1
				goto_state("fan_wind", 0.45)
		"fan_wind":
			velocity = Vector2.ZERO
			face_player()
			if st_t <= 0.0:
				_fire_fan(7 if fast else 5)
				_volleys -= 1
				if _volleys > 0:
					goto_state("fan_wind", 0.55)
				else:
					goto_state("idle", 1.0 if fast else 1.3)
		"summon_wind":
			velocity = Vector2(0, (hover_y - 30.0 - global_position.y) * 3.0)
			if st_t <= 0.0:
				_summon(2)
				goto_state("idle", 1.4)
		"thorn_wind":
			velocity = Vector2(0, (hover_y - global_position.y) * 3.0)
			if st_t <= 0.0:
				_thorns(global_position.x, facing)
				if fast:
					var other := arena.end.x - 40.0 if facing < 0 else arena.position.x + 40.0
					_thorns(other, -facing, 0.5)
				goto_state("idle", 1.9 if fast else 2.2)
	clamp_to_arena(10.0)


func _begin(p: String) -> void:
	match p:
		"fan":
			goto_state("tp_out", 0.3)
			Audio.play("teleport", 0.05)
		"summon":
			if _alive_wisps() >= 3:
				goto_state("thorn_wind", 0.6)
			else:
				goto_state("summon_wind", 0.8)
				Audio.play("roar", 0.1, -6.0)
		_:
			goto_state("thorn_wind", 0.6)


func _fire_fan(n: int) -> void:
	var p := player()
	if p == null:
		return
	var origin := global_position + Vector2(facing * 14.0, -18.0)
	var base := (p.global_position - origin).angle()
	var spread := deg_to_rad(60.0 if n > 5 else 48.0)
	for i in n:
		var a := base - spread * 0.5 + spread * float(i) / float(n - 1)
		spawn_orb(origin, Vector2(cos(a), sin(a)) * 205.0, eye_color)
	Audio.play("shoot", 0.05)


func _summon(n: int) -> void:
	for i in n:
		if _alive_wisps() >= 3:
			return
		var wsp := Wisp.new()
		wsp.position = global_position + Vector2((i * 2 - 1) * 60.0, -70.0)
		wsp.heal_drop_chance = 0.5
		level.add_enemy(wsp)
		wsp.leash = 420.0
		_wisps.append(wsp)
		FX.burst(get_parent(), wsp.position, Color(0.7, 0.5, 1.0), 12, 120.0, 0.5, 0.0, 4.0, true)


func _alive_wisps() -> int:
	var n := 0
	for wsp in _wisps:
		if is_instance_valid(wsp) and not (wsp as Wisp).dead:
			n += 1
	return n


func _thorns(from_x: float, dir: int, extra_delay: float = 0.0) -> void:
	var x := from_x + dir * 40.0
	var i := 0
	while x > arena.position.x + 10.0 and x < arena.end.x - 10.0 and i < 14:
		var e := Boss.Eruption.new()
		e.level = level
		e.delay = 0.5 + extra_delay + i * 0.09
		e.color = eye_color
		e.position = Vector2(x, floor_y)
		level.enemy_layer.add_child(e)
		x += dir * 50.0
		i += 1


func take_hit(dmg: int, dir: int, attacker: Node) -> bool:
	if modulate.a < 0.5:
		return false
	return super.take_hit(dmg, dir, attacker)


func on_phase2() -> void:
	super.on_phase2()
	_summon(1)


func _boss_die() -> void:
	for wsp in _wisps:
		if is_instance_valid(wsp) and not (wsp as Wisp).dead:
			(wsp as Wisp).die(1)
	super._boss_die()


func draw_body() -> void:
	var col := body_color()
	var rim := rim_color()
	var gold := Color(1, 1, 1) if flash > 0.0 else Color("#b8953e")
	var robe_wave := sin(t * 3.0) * 3.0
	# tattered robe
	var robe := PackedVector2Array([Vector2(-18, 30), Vector2(-12, 26 + robe_wave), Vector2(-6, 32), Vector2(0, 27 - robe_wave),
		Vector2(6, 32), Vector2(12, 26 + robe_wave), Vector2(18, 30), Vector2(14, -12), Vector2(8, -22), Vector2(-8, -22), Vector2(-14, -12)])
	draw_colored_polygon(robe, col)
	var closed := robe.duplicate()
	closed.append(robe[0])
	draw_polyline(closed, rim, 1.5)
	# mantle
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -10), Vector2(-9, -20), Vector2(9, -20), Vector2(17, -10), Vector2(0, -4)]), gold.darkened(0.35))
	# head (hollow mask) and crown
	draw_colored_polygon(ellipse(Vector2(2, -29), 9.0, 10.0, 14), Color(1, 1, 1) if flash > 0.0 else Color("#d8cdb8"))
	draw_colored_polygon(ellipse(Vector2(0, -29), 2.2, 3.2, 8), Color(0.05, 0.03, 0.05))
	draw_colored_polygon(ellipse(Vector2(6, -29), 2.2, 3.2, 8), Color(0.05, 0.03, 0.05))
	glow_eye(Vector2(6, -29), 1.2)
	glow_eye(Vector2(0, -29), 1.2)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -36), Vector2(-9, -47), Vector2(-4, -41), Vector2(1, -50), Vector2(5, -41), Vector2(10, -47), Vector2(11, -36)]), gold)
	# sceptre hand glows during wind-ups
	var hand := Vector2(16, -6)
	draw_line(hand + Vector2(0, 16), hand + Vector2(4, -22), gold.darkened(0.2), 3.0)
	var orb_k := 1.0
	if st == "fan_wind" or st == "summon_wind" or st == "thorn_wind":
		orb_k = 1.6 + 0.4 * sin(t * 20.0)
	draw_circle(hand + Vector2(4, -25), 4.0 * orb_k * 2.0, Color(eye_color.r, eye_color.g, eye_color.b, 0.25))
	draw_circle(hand + Vector2(4, -25), 4.0 * orb_k, eye_color)
