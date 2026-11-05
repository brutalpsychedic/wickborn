class_name ExitGate
extends Area2D
## The glowing archway that ends a level. Locked (dark, barred) while a boss is alive.
## Origin is at ground level.

var level: Level = null
var locked := false
var _t := 0.0
var _glow: Sprite2D
var _triggered := false
var accent := Color(1.0, 0.85, 0.55)


func _ready() -> void:
	collision_layer = Phys.TRIGGER
	collision_mask = Phys.PLAYER
	monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(Vector2(40, 72))
	cs.position = Vector2(0, -36)
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = 3
	_glow = FX.make_glow(Color(accent.r, accent.g, accent.b, 0.45), 120.0)
	_glow.position = Vector2(0, -40)
	add_child(_glow)
	set_locked(locked)


func set_locked(v: bool) -> void:
	locked = v
	if _glow != null:
		_glow.visible = not locked
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not locked:
		_glow.modulate.a = 0.4 + 0.08 * sin(_t * 2.5)
		queue_redraw()


func _on_body(b: Node) -> void:
	if _triggered or locked or not (b is Player):
		return
	_triggered = true
	if level != null:
		level.on_exit_reached()


func _draw() -> void:
	var stone := Color(0.3, 0.27, 0.34)
	var stone_dk := Color(0.18, 0.16, 0.21)
	# portal fill
	var inner := PackedVector2Array()
	inner.append(Vector2(-20, 0))
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		inner.append(Vector2(cos(a) * 20.0, -54.0 + sin(a) * 20.0))
	inner.append(Vector2(20, 0))
	if locked:
		draw_colored_polygon(inner, Color(0.04, 0.03, 0.06))
		for k in 5:
			var x := -16.0 + k * 8.0
			draw_line(Vector2(x, -70), Vector2(x, 0), Color(0.25, 0.22, 0.28), 2.5)
	else:
		draw_colored_polygon(inner, Color(accent.r, accent.g, accent.b, 0.35))
		var core := PackedVector2Array()
		for p in inner:
			core.append(Vector2(p.x * 0.6, p.y * 0.9 + sin(_t * 3.0 + p.x * 0.2) * 1.5))
		draw_colored_polygon(core, Color(1.0, 0.97, 0.88, 0.55))
		for k in 4:
			var yy := -fmod(_t * 22.0 + k * 18.0, 72.0)
			draw_circle(Vector2(sin(_t * 2.0 + k) * 9.0, yy), 1.5, Color(1, 1, 0.9, 0.8))
	# arch frame
	var outer := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		outer.append(Vector2(cos(a) * 28.0, -54.0 + sin(a) * 28.0))
	draw_polyline(outer, stone, 8.0)
	draw_rect(Rect2(-32, -56, 8, 56), stone)
	draw_rect(Rect2(24, -56, 8, 56), stone)
	draw_rect(Rect2(-30, -56, 3, 56), stone_dk)
	draw_rect(Rect2(-36, -4, 72, 6), stone_dk)
	draw_circle(Vector2(0, -84), 4.0, accent if not locked else stone_dk)
