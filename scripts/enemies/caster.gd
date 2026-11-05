class_name Caster
extends Enemy
## Gloom Caster (ranged): keeps its distance and lobs slow, glowing orbs at the player.
## Orbs can be slashed out of the air.

var _cooldown := 1.0
var _patrol_origin := Vector2.ZERO


func setup() -> void:
	max_hp = 3
	body_size = Vector2(22, 30)
	eye_color = Color("#8fe3ff")
	knock_resist = 0.8


func _ready() -> void:
	super._ready()
	_patrol_origin = position
	st = "idle"


func ai(delta: float) -> void:
	_cooldown -= delta
	st_t -= delta
	match st:
		"idle":
			# short pacing around its spot
			if absf(position.x - _patrol_origin.x) > 40.0:
				facing = -1 if position.x > _patrol_origin.x else 1
			patrol(25.0)
			if can_see_player(400.0, 240.0):
				goto_state("aware", 0.0)
		"aware":
			face_player()
			var d := to_player()
			if absf(d.x) < 90.0 and ground_ahead(-facing) and not wall_ahead(-facing):
				velocity.x = -facing * 70.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _cooldown <= 0.0:
				goto_state("windup", 0.55)
			if not can_see_player(460.0, 280.0):
				goto_state("idle", 0.0)
		"windup":
			face_player()
			velocity.x = 0.0
			if st_t <= 0.0:
				_fire()
				_cooldown = 1.9
				goto_state("aware", 0.0)


func _fire() -> void:
	var p := player()
	if p == null:
		return
	var origin := global_position + Vector2(facing * 12.0, -14.0)
	var dir := (p.global_position + Vector2(0, -4) - origin).normalized()
	var pr := Projectile.new()
	pr.level = level
	pr.velocity = dir * 175.0
	pr.color = eye_color
	pr.position = origin
	level.enemy_layer.add_child(pr)
	Audio.play("shoot", 0.1)


func draw_body() -> void:
	var col := body_color()
	var rim := rim_color()
	# hooded robe
	draw_colored_polygon(PackedVector2Array([Vector2(-11, 15), Vector2(-7, -8), Vector2(0, -16), Vector2(7, -8), Vector2(11, 15)]), col)
	draw_polyline(PackedVector2Array([Vector2(-11, 15), Vector2(-7, -8), Vector2(0, -16), Vector2(7, -8), Vector2(11, 15)]), rim, 1.5)
	draw_colored_polygon(ellipse(Vector2(1, -8), 5.0, 5.0, 10), Color(0.02, 0.02, 0.03))
	glow_eye(Vector2(3, -9), 1.6)
	# floating orb in front: swells during wind-up
	var orb_r := 4.0
	if st == "windup":
		orb_r = 4.0 + (1.0 - clampf(st_t / 0.55, 0.0, 1.0)) * 5.0
	var op := Vector2(13, -14 + sin(t * 3.0) * 2.0)
	draw_circle(op, orb_r * 2.2, Color(eye_color.r, eye_color.g, eye_color.b, 0.25))
	draw_circle(op, orb_r, eye_color)
	draw_circle(op, orb_r * 0.45, Color(1, 1, 1, 0.9))
