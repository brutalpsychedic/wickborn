class_name Sentry
extends Enemy
## Ashen Sentry (melee): patrols, chases when it sees the player, raises its blade
## (clear wind-up), lunges with a slash, then pauses - the opening to counter-attack.

var slash: DamageArea


func setup() -> void:
	max_hp = 4
	body_size = Vector2(22, 34)
	eye_color = Color("#ff5a4a")
	knock_resist = 0.7


func _ready() -> void:
	super._ready()
	slash = DamageArea.create(Vector2(42, 30), 1)
	slash.enabled = false
	add_child(slash)
	st = "patrol"


func ai(delta: float) -> void:
	st_t -= delta
	match st:
		"patrol":
			patrol(40.0)
			if can_see_player(230.0, 60.0):
				goto_state("chase", 2.5)
		"chase":
			approach(115.0)
			var d := to_player()
			if absf(d.x) < 66.0 and absf(d.y) < 50.0:
				goto_state("windup", 0.45)
				velocity.x = 0.0
			elif can_see_player(300.0, 90.0):
				st_t = 2.5
			elif st_t <= 0.0:
				goto_state("patrol", 0.0)
		"windup":
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if st_t <= 0.0:
				goto_state("lunge", 0.2)
				slash.enabled = true
				Audio.play("swing", 0.1, -2.0)
		"lunge":
			velocity.x = facing * 320.0 if ground_ahead(facing) else 0.0
			slash.position = Vector2(facing * 24.0, -2.0)
			if st_t <= 0.0:
				slash.enabled = false
				goto_state("recover", 0.65)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st_t <= 0.0:
				goto_state("chase", 2.0)


func die(dir: int) -> void:
	slash.enabled = false
	super.die(dir)


func draw_body() -> void:
	var col := body_color()
	var rim := rim_color()
	var walk := sin(t * 9.0) * 3.0 if absf(velocity.x) > 10.0 else 0.0
	draw_line(Vector2(-5, 8), Vector2(-5 + walk, 17), rim, 3.0)
	draw_line(Vector2(4, 8), Vector2(4 - walk, 17), rim, 3.0)
	# hunched cloaked torso
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 10), Vector2(-9, -6), Vector2(-3, -14), Vector2(6, -13), Vector2(11, -4), Vector2(10, 10)]), col)
	draw_polyline(PackedVector2Array([Vector2(-11, 10), Vector2(-9, -6), Vector2(-3, -14), Vector2(6, -13), Vector2(11, -4), Vector2(10, 10)]), rim, 1.5)
	# helm
	draw_colored_polygon(ellipse(Vector2(3, -17), 7.0, 6.0, 12), col)
	draw_line(Vector2(-1, -23), Vector2(-5, -28), rim, 2.0)
	glow_eye(Vector2(6, -17), 1.8)
	# curved blade: raised during wind-up, forward during lunge
	var ang := -0.6
	if st == "windup":
		ang = -2.2
	elif st == "lunge":
		ang = 0.1
	var hand := Vector2(9, -2)
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-dir.y, dir.x)
	var blade := Color(1, 1, 1) if flash > 0.0 else Color("#9b8fa8")
	if st == "windup" and fmod(t, 0.16) < 0.08:
		blade = Color("#ffd0c0")
	draw_colored_polygon(PackedVector2Array([hand + nrm * 2.0, hand + dir * 24.0 + nrm * 4.0, hand + dir * 28.0, hand - nrm * 1.5]), blade)
	if st == "lunge":
		var arc := PackedVector2Array()
		for i in 9:
			var a := -1.2 + 2.0 * float(i) / 8.0
			arc.append(Vector2(14, -2) + Vector2(cos(a), sin(a)) * 22.0)
		draw_polyline(arc, Color(1.0, 0.6, 0.5, 0.7), 3.0)
