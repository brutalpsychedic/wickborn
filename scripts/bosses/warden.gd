class_name Warden
extends Boss
## The Rust Warden (mini-boss, level 8). Patterns:
##  charge - scrapes its feet, then rushes wall to wall; stunned after hitting a wall
##  leap   - crouches, jumps at the player, landing sends shockwaves both ways
##  combo  - closes in and lunges 3 times (4 in phase 2)

var slash: DamageArea
var _lunges := 0


func setup() -> void:
	boss_name = "The Rust Warden"
	max_hp = 24
	body_size = Vector2(44, 58)
	eye_color = Color("#ff7a3a")
	gravity = 1700.0
	patterns = ["charge", "leap", "combo"]


func _ready() -> void:
	super._ready()
	slash = DamageArea.create(Vector2(58, 46), 1)
	slash.enabled = false
	add_child(slash)


func ai(delta: float) -> void:
	st_t -= delta
	var fast := phase == 2
	match st:
		"dormant":
			velocity.x = 0.0
		"intro":
			velocity.x = 0.0
			face_player()
			if st_t <= 0.0:
				goto_state("idle", 0.6)
		"idle":
			face_player()
			velocity.x = facing * 55.0 if absf(to_player().x) > 80.0 else 0.0
			if st_t <= 0.0:
				_begin(pick_pattern())
		"charge_wind":
			velocity.x = 0.0
			if st_t <= 0.0:
				goto_state("charge", 2.5)
				Audio.play("swoop", 0.0)
		"charge":
			velocity.x = facing * (540.0 if fast else 440.0)
			slash.enabled = true
			slash.position = Vector2(facing * 20.0, 0)
			if at_arena_wall(facing) or is_on_wall() or st_t <= 0.0:
				slash.enabled = false
				velocity.x = -facing * 140.0
				Audio.play("slam", 0.0)
				FX.shake(self, 7.0, 0.3)
				goto_state("stunned", 0.7 if fast else 1.0)
		"stunned":
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if st_t <= 0.0:
				goto_state("idle", 0.5 if fast else 0.8)
		"leap_wind":
			velocity.x = 0.0
			if st_t <= 0.0:
				var p := player()
				var tx := p.global_position.x if p != null else global_position.x
				tx = clampf(tx, arena.position.x + 60.0, arena.end.x - 60.0)
				velocity = Vector2((tx - global_position.x) / 0.85, -720.0)
				goto_state("leap", 3.0)
				Audio.play("jump", 0.0, 2.0)
		"leap":
			if is_on_floor() and st_t < 2.85:
				velocity.x = 0.0
				Audio.play("slam", 0.0)
				FX.shake(self, 8.0, 0.35)
				spawn_shockwave(global_position.x - 26.0, -1, 300.0 if fast else 260.0)
				spawn_shockwave(global_position.x + 26.0, 1, 300.0 if fast else 260.0)
				goto_state("recover", 0.6 if fast else 0.9)
		"combo_approach":
			approach(170.0)
			if absf(to_player().x) < 95.0 or st_t <= 0.0:
				_lunges = 4 if fast else 3
				goto_state("combo_wind", 0.35)
		"combo_wind":
			velocity.x = 0.0
			face_player()
			if st_t <= 0.0:
				slash.enabled = true
				Audio.play("swing", 0.05, 2.0)
				goto_state("combo_lunge", 0.18)
		"combo_lunge":
			velocity.x = facing * 340.0
			slash.position = Vector2(facing * 32.0, 0)
			if st_t <= 0.0:
				slash.enabled = false
				_lunges -= 1
				if _lunges > 0:
					goto_state("combo_wind", 0.16 if fast else 0.24)
				else:
					goto_state("recover", 0.9)
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st_t <= 0.0:
				goto_state("idle", 0.5 if fast else 0.8)
	clamp_to_arena(8.0)


func _begin(p: String) -> void:
	face_player()
	match p:
		"charge":
			goto_state("charge_wind", 0.45 if phase == 2 else 0.7)
		"leap":
			goto_state("leap_wind", 0.4)
		_:
			goto_state("combo_approach", 1.4)


func _boss_die() -> void:
	slash.enabled = false
	super._boss_die()


func draw_body() -> void:
	var col := body_color()
	var rim := rim_color()
	var rust := Color(1, 1, 1) if flash > 0.0 else Color("#5a3a2e")
	var rust_hi := Color("#8a5a40")
	var crouch := 0.0
	if st == "charge_wind" or st == "leap_wind":
		crouch = 6.0
	var walk := sin(t * 8.0) * 4.0 if absf(velocity.x) > 10.0 else 0.0
	# legs
	draw_rect(Rect2(-16 + walk * 0.4, 14, 11, 15), col)
	draw_rect(Rect2(5 - walk * 0.4, 14, 11, 15), col)
	# body armour
	var torso := PackedVector2Array([Vector2(-22, 16), Vector2(-24, -10 + crouch), Vector2(-14, -24 + crouch), Vector2(10, -26 + crouch), Vector2(22, -12 + crouch), Vector2(20, 16)])
	draw_colored_polygon(torso, rust)
	var closed := torso.duplicate()
	closed.append(torso[0])
	draw_polyline(closed, rim, 2.0)
	draw_line(Vector2(-18, 0 + crouch * 0.5), Vector2(18, 0 + crouch * 0.5), rust_hi, 2.0)
	draw_line(Vector2(-16, 8), Vector2(16, 8), col, 2.0)
	# horned helm
	var hy := -30.0 + crouch
	draw_colored_polygon(ellipse(Vector2(6, hy), 11.0, 9.0, 14), col)
	draw_colored_polygon(PackedVector2Array([Vector2(-2, hy - 6), Vector2(-12, hy - 20), Vector2(-4, hy - 9)]), rust_hi)
	draw_colored_polygon(PackedVector2Array([Vector2(10, hy - 7), Vector2(16, hy - 22), Vector2(14, hy - 6)]), rust_hi)
	draw_line(Vector2(3, hy), Vector2(15, hy), eye_color, 3.0)
	glow_eye(Vector2(12, hy), 2.0)
	# cleaver
	var ang := 0.3
	if st == "combo_wind" or st == "charge_wind":
		ang = -1.9
	elif st == "combo_lunge":
		ang = 0.2
	elif st == "charge":
		ang = 0.05
	var hand := Vector2(20, -4 + crouch)
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var blade := Color(1, 1, 1) if flash > 0.0 else Color("#8c8a90")
	if (st == "combo_wind" or st == "charge_wind") and fmod(t, 0.14) < 0.07:
		blade = Color("#ffd0b0")
	draw_colored_polygon(PackedVector2Array([hand - n * 3.0, hand + d * 40.0 - n * 4.0, hand + d * 46.0 + n * 6.0, hand + d * 8.0 + n * 9.0]), blade)
	draw_line(hand - d * 6.0, hand + d * 4.0, rust_hi, 4.0)
	if st == "combo_lunge" or st == "charge":
		var arc := PackedVector2Array()
		for i in 9:
			var a := -1.0 + 2.0 * float(i) / 8.0
			arc.append(Vector2(26, -4) + Vector2(cos(a), sin(a)) * 34.0)
		draw_polyline(arc, Color(1.0, 0.6, 0.4, 0.6), 4.0)
