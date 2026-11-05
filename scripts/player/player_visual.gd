class_name PlayerVisual
extends Node2D
## Procedural, vector-drawn animation for Wick: a small wax-candle knight in a red scarf
## with a living flame on its head (the flame shrinks as health drops).
## States read from the Player: idle (breathing), run (leg cycle + lean), jump/fall (stretch),
## attack (two alternating sword arcs + slash trail), hurt (white flash), dash (afterimages), death.

const WAX := Color("#ecdfc6")
const WAX_SHADE := Color("#c9b597")
const OUTLINE := Color("#1b1422")
const SCARF := Color("#b8382f")
const SCARF_DARK := Color("#7a2421")
const LEG := Color("#2b2132")
const BLADE := Color("#e8ca70")
const BLADE_HI := Color("#fff6d0")
const HILT := Color("#5b3b2a")
const EYE := Color("#1d1526")

var player: Player
var t := 0.0
var squash := Vector2.ONE
var _run_phase := 0.0
var _flash := 0.0
var _heal := 0.0
var _death := -1.0
var _blink := 2.5
var _swing_style := 0
var _dash_ghosts: Array = []   # [global_pos, age]
var _scarf_wave := 0.0


func flash() -> void:
	_flash = 0.12


func heal_flash() -> void:
	_heal = 0.35


func start_swing(style: int) -> void:
	_swing_style = style


func start_dash() -> void:
	_dash_ghosts.clear()


func start_death() -> void:
	_death = 0.0


func _process(delta: float) -> void:
	t += delta
	var v := player.velocity
	var on_floor := player.is_on_floor()
	if on_floor and absf(v.x) > 20.0:
		_run_phase += delta * (absf(v.x) / Player.RUN_SPEED) * 15.0
	squash = squash.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	_flash -= delta
	_heal -= delta
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(2.0, 4.5)
	_scarf_wave += delta * (3.0 + absf(v.x) * 0.03)
	if _death >= 0.0:
		_death += delta
	if player.state == Player.State.DASH:
		_dash_ghosts.append([player.global_position, 0.0])
	for g in _dash_ghosts:
		g[1] += delta
	while _dash_ghosts.size() > 0 and float(_dash_ghosts[0][1]) > 0.22:
		_dash_ghosts.pop_front()
	# invulnerability flicker (self_modulate leaves fades on `modulate` untouched)
	if player.invuln > 0.0 and player.state != Player.State.DEAD and _flash <= 0.0:
		self_modulate.a = 0.35 if fmod(t, 0.14) < 0.07 else 1.0
	else:
		self_modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	var f := float(player.facing)
	var v := player.velocity
	var on_floor := player.is_on_floor()

	# afterimages (drawn in un-flipped space)
	for g in _dash_ghosts:
		var gp: Vector2 = (g[0] as Vector2) - player.global_position
		var a := 0.35 * (1.0 - float(g[1]) / 0.22)
		draw_set_transform(gp, 0.0, Vector2.ONE)
		draw_colored_polygon(_ellipse(Vector2(0, 0), 10.0, 13.0, 10), Color(1.0, 0.75, 0.45, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var running := on_floor and absf(v.x) > 20.0
	var bob := 0.0
	if running:
		bob = -absf(sin(_run_phase)) * 2.2
	elif on_floor:
		bob = sin(t * 2.4) * 0.7
	var sq := squash
	if not on_floor and player.state != Player.State.DASH:
		var k := clampf(-v.y / 1600.0, -0.12, 0.14)
		sq = Vector2(sq.x * (1.0 - k), sq.y * (1.0 + k))
	if player.state == Player.State.DASH:
		sq = Vector2(1.25, 0.82)
	var lean := clampf(v.x / Player.RUN_SPEED, -1.0, 1.0) * 0.12 * f
	if player.state == Player.State.HURT:
		lean = -0.35
	var rot := lean
	var hp_ratio := float(player.hp) / float(maxi(player.max_hp, 1))
	var flame_size := 5.0 + 6.0 * hp_ratio
	if _death >= 0.0:
		var dk := clampf(_death / 0.6, 0.0, 1.0)
		rot = lerpf(lean, 1.45, dk)
		sq = Vector2(1.0 + 0.15 * dk, 1.0 - 0.3 * dk)
		flame_size *= maxf(0.0, 1.0 - _death * 1.8)
		bob = 2.0 * dk

	# everything below is drawn facing right, flipped by `f`, with origin at the feet
	draw_set_transform(Vector2(0, 14.0 + bob), rot * f, Vector2(sq.x * f, sq.y))

	var base_col_mul := 1.0
	var flash_on := _flash > 0.0
	var wax := Color.WHITE if flash_on else WAX
	var wax_shade := Color(1, 0.95, 0.9) if flash_on else WAX_SHADE
	if _heal > 0.0:
		wax = WAX.lerp(Color(1.0, 0.85, 0.55), _heal / 0.35)

	# scarf tail (behind body)
	var speed_k := clampf(absf(v.x) / Player.RUN_SPEED, 0.0, 1.0)
	var tail_len := 9.0 + 7.0 * speed_k
	var wave := sin(_scarf_wave) * 2.5
	var lift := clampf(v.y / 400.0, -1.0, 1.0) * -3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -15), Vector2(-6 - tail_len * 0.5, -16 + wave * 0.5 + lift * 0.5),
		Vector2(-6 - tail_len, -14 + wave + lift), Vector2(-6 - tail_len * 0.9, -10 + wave + lift),
		Vector2(-6 - tail_len * 0.45, -11 + wave * 0.4 + lift * 0.4), Vector2(-6, -11)]), SCARF_DARK)

	# legs
	var lx1 := -3.5
	var lx2 := 3.5
	var ly1 := 0.0
	var ly2 := 0.0
	if running:
		lx1 = -1.0 + sin(_run_phase) * 5.0
		lx2 = 1.0 - sin(_run_phase) * 5.0
		ly1 = -maxf(0.0, cos(_run_phase)) * 3.0
		ly2 = -maxf(0.0, -cos(_run_phase)) * 3.0
	elif not on_floor:
		lx1 = -4.0
		lx2 = 3.0
		ly1 = -3.0
		ly2 = -1.5
	draw_rect(Rect2(lx1 - 2.5, -7 + ly1, 5, 7), LEG)
	draw_rect(Rect2(lx2 - 2.5, -7 + ly2, 5, 7), LEG.lightened(0.08))

	# candle body with wax drips along the rim
	var body := PackedVector2Array([
		Vector2(-10, -8), Vector2(-9, -5), Vector2(-6, -4), Vector2(6, -4), Vector2(9, -5),
		Vector2(10, -8), Vector2(10, -23), Vector2(7.5, -25.5), Vector2(4, -24.5), Vector2(1, -26.5),
		Vector2(-3, -25), Vector2(-7, -26), Vector2(-10, -23)])
	draw_colored_polygon(body, wax)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(-9, -5), Vector2(-6, -4),
		Vector2(-4, -4), Vector2(-5.5, -24.5), Vector2(-7, -26), Vector2(-10, -23)]), wax_shade)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, OUTLINE, 1.6, true)
	draw_line(Vector2(7, -24), Vector2(7, -19), wax_shade, 2.0)
	draw_line(Vector2(2, -25), Vector2(2, -22), wax_shade, 1.6)

	# scarf wrap
	draw_colored_polygon(PackedVector2Array([Vector2(-10.6, -15.5), Vector2(10.6, -16.5), Vector2(10.6, -11.5), Vector2(-10.6, -10.8)]), SCARF)
	draw_line(Vector2(-10.6, -10.8), Vector2(10.6, -11.5), SCARF_DARK, 1.4)

	# eyes
	var eye_h := 3.2 if _blink > 0.0 else 0.5
	if player.state == Player.State.HURT or _death >= 0.0:
		eye_h = 0.6
	draw_colored_polygon(_ellipse(Vector2(2.5, -19.5), 1.8, eye_h, 8), EYE)
	draw_colored_polygon(_ellipse(Vector2(7.2, -19.5), 1.8, eye_h, 8), EYE)
	if eye_h > 1.0:
		draw_circle(Vector2(3.0, -20.6), 0.6, Color(1, 1, 1, 0.8))
		draw_circle(Vector2(7.7, -20.6), 0.6, Color(1, 1, 1, 0.8))

	# sword
	var hand := Vector2(8.5, -9.0)
	var ang := -0.5
	var swinging := player.attack_t >= 0.0
	var p := 0.0
	if swinging:
		p = clampf(player.attack_t / Player.ATTACK_DURATION, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - minf(p * 1.8, 1.0), 3.0)
		if _swing_style == 0:
			ang = lerpf(-2.1, 0.7, e)
		else:
			ang = lerpf(1.0, -1.6, e)
		hand = Vector2(10.0, -11.0)
	elif player.state == Player.State.DASH:
		ang = 0.15
	elif not on_floor:
		ang = -0.9
	if _death < 0.0:
		_draw_sword(hand, ang)

	# slash trail
	if swinging and p < 0.65:
		var alpha := (1.0 - p / 0.65) * 0.9
		var a0 := -2.0 if _swing_style == 0 else 1.0
		var a1 := lerpf(a0, 0.7 if _swing_style == 0 else -1.6, minf(1.0, p * 2.2))
		_draw_arc_band(Vector2(4, -12), 18.0, 34.0, a0, a1, Color(1.0, 0.92, 0.7, alpha))

	# head flame
	var fl_lean := clampf(-v.x * 0.012 * f, -3.0, 3.0)
	FX.draw_flame(self, Vector2(1.0, -25.0), flame_size, t, fl_lean)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sword(hand: Vector2, ang: float) -> void:
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-dir.y, dir.x)
	var tip := hand + dir * 19.0
	draw_colored_polygon(PackedVector2Array([hand + nrm * 2.0, tip + nrm * 0.6, tip + dir * 2.5, tip - nrm * 0.6, hand - nrm * 2.0]), BLADE)
	draw_line(hand + dir * 3.0, tip, BLADE_HI, 1.0)
	draw_line(hand + nrm * 4.0, hand - nrm * 4.0, HILT, 2.5)
	draw_line(hand, hand - dir * 4.0, HILT, 2.5)
	draw_circle(hand - dir * 4.5, 1.6, BLADE)


func _draw_arc_band(c: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
	if absf(a1 - a0) < 0.05:
		return
	var n := 10
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r1)
	for i in range(n, -1, -1):
		var a := lerpf(a0, a1, float(i) / n)
		var taper := lerpf(r1 - 3.0, r0, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * taper)
	draw_colored_polygon(pts, col)


func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
