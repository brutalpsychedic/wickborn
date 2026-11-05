class_name Brute
extends Enemy
## Stonebound Brute (heavy): slow, tough, barely flinches. Raises both fists, then slams the
## ground sending shockwaves both ways - jump over them.


func setup() -> void:
	max_hp = 9
	body_size = Vector2(40, 46)
	eye_color = Color("#ffcf5a")
	knock_resist = 0.18
	contact_damage = 1
	heal_drop_chance = 0.6


func _ready() -> void:
	super._ready()
	st = "patrol"


func ai(delta: float) -> void:
	st_t -= delta
	match st:
		"patrol":
			patrol(35.0)
			if can_see_player(280.0, 90.0):
				goto_state("chase", 3.0)
		"chase":
			approach(62.0)
			var d := to_player()
			if absf(d.x) < 115.0 and absf(d.y) < 70.0:
				goto_state("windup", 0.75)
				velocity.x = 0.0
			elif st_t <= 0.0 and not can_see_player(320.0, 100.0):
				goto_state("patrol", 0.0)
		"windup":
			velocity.x = 0.0
			if st_t <= 0.0:
				_slam()
				goto_state("recover", 1.1)
		"recover":
			velocity.x = 0.0
			if st_t <= 0.0:
				goto_state("chase", 3.0)


func _slam() -> void:
	Audio.play("slam", 0.05)
	FX.shake(self, 6.0, 0.25)
	var ground_y := global_position.y + body_size.y * 0.5
	FX.burst(get_parent(), Vector2(global_position.x + facing * 20.0, ground_y), Color(0.7, 0.65, 0.6, 0.7), 14, 160.0, 0.5, 300.0, 4.0)
	for dir in [-1, 1]:
		var sw := Shockwave.new()
		sw.level = level
		sw.dir = dir
		sw.color = eye_color
		sw.position = Vector2(global_position.x + dir * 26.0, ground_y - 11.0)
		level.enemy_layer.add_child(sw)


func draw_body() -> void:
	var col := body_color()
	var rim := rim_color()
	var stone := Color(1, 1, 1) if flash > 0.0 else Color("#3a3442")
	var step := sin(t * 5.0) * 2.0 if absf(velocity.x) > 5.0 else 0.0
	draw_rect(Rect2(-14, 12 + step * 0.3, 10, 11), col)
	draw_rect(Rect2(4, 12 - step * 0.3, 10, 11), col)
	# boulder torso
	var torso := PackedVector2Array([Vector2(-20, 14), Vector2(-22, -4), Vector2(-15, -20), Vector2(0, -24), Vector2(15, -19), Vector2(21, -3), Vector2(19, 14)])
	draw_colored_polygon(torso, stone)
	var closed := torso.duplicate()
	closed.append(torso[0])
	draw_polyline(closed, rim, 2.0)
	draw_line(Vector2(-8, -16), Vector2(-2, -6), col, 2.0)
	draw_line(Vector2(6, 2), Vector2(12, 9), col, 2.0)
	# eye slit
	glow_eye(Vector2(10, -10), 2.4)
	# fists: raised during wind-up
	var raise := 0.0
	if st == "windup":
		raise = (1.0 - clampf(st_t / 0.75, 0.0, 1.0)) * 26.0
	elif st == "recover" and st_t > 0.8:
		raise = -4.0
	draw_circle(Vector2(22, 4 - raise), 8.0, stone)
	draw_circle(Vector2(-20, 6 - raise * 0.8), 7.0, stone)
	draw_arc(Vector2(22, 4 - raise), 8.0, 0, TAU, 14, rim, 1.5)
