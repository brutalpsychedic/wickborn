class_name Crawler
extends Enemy
## Gloomcrawler: small spiked shadow that patrols ledges and hurries when the player is close.


func setup() -> void:
	max_hp = 2
	body_size = Vector2(26, 18)
	eye_color = Color("#ffb347")


func ai(_delta: float) -> void:
	var speed := 50.0
	var d := to_player()
	if absf(d.x) < 170.0 and absf(d.y) < 40.0:
		speed = 85.0
	patrol(speed)


func draw_body() -> void:
	var leg_t := t * 12.0
	for i in 3:
		var lx := -8.0 + i * 8.0
		var off := sin(leg_t + i * 2.1) * 2.5
		draw_line(Vector2(lx, 4), Vector2(lx + off, 9), rim_color(), 2.0)
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		dome.append(Vector2(cos(a) * 13.0, 6.0 + sin(a) * 14.0))
	draw_colored_polygon(dome, body_color())
	for i in 4:
		var sx := -9.0 + i * 6.0
		var by := 6.0 - sqrt(maxf(0.0, 169.0 - sx * sx)) * 14.0 / 13.0
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 3, by + 2), Vector2(sx - 1, by - 6), Vector2(sx + 3, by + 2)]), rim_color())
	glow_eye(Vector2(7, -1), 2.6)
