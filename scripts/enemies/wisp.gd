class_name Wisp
extends Enemy
## Shade Wisp (flyer): drifts around its home point, winds up when it spots the player,
## swoops at where the player was, then drifts back. Readable telegraph: it shivers and glows.

var home := Vector2.ZERO
var _dir := Vector2.ZERO
var leash := 260.0


func setup() -> void:
	max_hp = 2
	body_size = Vector2(22, 22)
	flying = true
	eye_color = Color("#c79bff")
	heal_drop_chance = 0.25


func _ready() -> void:
	super._ready()
	home = position
	st = "hover"


func ai(delta: float) -> void:
	match st:
		"hover":
			var goal := home + Vector2(sin(t * 0.9) * 34.0, sin(t * 1.8) * 12.0)
			velocity = ((goal - position) * 2.2).limit_length(110.0)
			if can_see_player(250.0, 200.0):
				face_player()
				goto_state("windup", 0.5)
		"windup":
			face_player()
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			st_t -= delta
			if st_t <= 0.0:
				var p := player()
				if p == null:
					goto_state("hover", 0.0)
				else:
					_dir = (p.global_position - global_position).normalized()
					goto_state("swoop", 0.7)
					Audio.play("swoop", 0.1, -4.0)
		"swoop":
			velocity = _dir * 285.0
			st_t -= delta
			if st_t <= 0.0 or is_on_wall() or is_on_floor() or is_on_ceiling():
				goto_state("recover", 1.1)
		"recover":
			st_t -= delta
			var back := (home - position)
			velocity = velocity.move_toward(back.normalized() * 70.0 if back.length() > 8.0 else Vector2.ZERO, 300.0 * delta)
			if st_t <= 0.0:
				goto_state("hover", 0.0)
	if position.distance_to(home) > leash and st != "swoop":
		velocity = (home - position).normalized() * 120.0


func on_hit(_dir: int) -> void:
	if st == "windup":
		goto_state("recover", 0.6)


func draw_body() -> void:
	var shiver := Vector2(randf_range(-1.2, 1.2), 0) if st == "windup" else Vector2.ZERO
	var col := body_color()
	# tattered tail
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 4), Vector2(-15, 9 + sin(t * 6.0) * 3.0), Vector2(-8, -1)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 1), Vector2(-18, 1 + sin(t * 5.0 + 1.0) * 3.0), Vector2(-8, -5)]), col)
	draw_colored_polygon(ellipse(shiver, 11.0, 10.0, 16), col)
	draw_polyline(ellipse(shiver, 11.0, 10.0, 16) + PackedVector2Array([Vector2(11, 0) + shiver]), rim_color(), 1.5)
	var glow_k := 1.6 if st == "windup" else 1.0
	glow_eye(Vector2(3, -2) + shiver, 2.2 * glow_k)
	glow_eye(Vector2(8, -1) + shiver, 1.8 * glow_k)
