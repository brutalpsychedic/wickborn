class_name MenuBackdrop
extends Control
## Animated night scene behind the menus: gradient sky, moon, layered hills, a lone lantern
## and Wick on a ridge with its flame flickering, plus drifting embers.

var mood := "night"   # "night" or "dawn" (victory)
var show_hero := true
var _t := 0.0
var _rng_seed := 11


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.texture = FX.dot_texture()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 20)
	p.position = Vector2(640, 760)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.5
	p.color = Color(1.0, 0.65, 0.3, 0.8) if mood == "night" else Color(1.0, 0.9, 0.7, 0.8)
	p.color_ramp = FX.fade_ramp()
	p.material = FX.add_material()
	add_child(p)
	resized.connect(func() -> void: p.position = Vector2(size.x * 0.5, size.y + 40); p.emission_rect_extents = Vector2(size.x * 0.6, 20))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var top := Color("#0d0f22") if mood == "night" else Color("#3a3060")
	var bot := Color("#3a2c4a") if mood == "night" else Color("#e0a878")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), PackedColorArray([top, top, bot, bot]))
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed
	for i in 70:
		var p := Vector2(rng.randf() * s.x, rng.randf() * s.y * 0.55)
		var tw := 0.35 + 0.3 * sin(_t * rng.randf_range(0.5, 2.0) + i)
		draw_circle(p, rng.randf_range(0.6, 1.7), Color(1, 1, 1, tw * (1.0 if mood == "night" else 0.3)))
	var mpos := Vector2(s.x * 0.86, s.y * 0.17)
	if mood == "night":
		draw_circle(mpos, 120.0, Color(1, 0.95, 0.85, 0.04))
		draw_circle(mpos, 76.0, Color(1, 0.95, 0.85, 0.07))
		draw_circle(mpos, 46.0, Color(0.93, 0.9, 0.82, 0.85))
		draw_circle(mpos + Vector2(13, -8), 40.0, top.lerp(bot, 0.22))
	else:
		draw_circle(Vector2(s.x * 0.5, s.y * 0.72), 260.0, Color(1, 0.9, 0.6, 0.1))
		draw_circle(Vector2(s.x * 0.5, s.y * 0.72), 120.0, Color(1, 0.95, 0.75, 0.35))
	var layers := [Color("#262640"), Color("#1a1a2e"), Color("#100f1c")]
	if mood != "night":
		layers = [Color("#8a6a8a"), Color("#5a4466"), Color("#2e2238")]
	for li in 3:
		var base := s.y * (0.62 + li * 0.1)
		var amp := 50.0 + li * 25.0
		var pts := PackedVector2Array()
		var x := -20.0
		while x <= s.x + 60.0:
			pts.append(Vector2(x, base - amp * (0.5 + 0.35 * sin(x * (0.004 + li * 0.002) + li * 2.0) + 0.15 * sin(x * 0.013 + li))))
			x += 40.0
		pts.append(Vector2(s.x + 60.0, s.y))
		pts.append(Vector2(-20.0, s.y))
		draw_colored_polygon(pts, layers[li])
	if show_hero:
		# lantern post and Wick on the front ridge
		var ridge := Vector2(s.x * 0.2, s.y * 0.82 - 30.0)
		var glow_a := 0.12 + 0.03 * sin(_t * 5.0)
		draw_circle(ridge + Vector2(0, -30), 150.0, Color(1.0, 0.6, 0.3, glow_a * 0.6))
		draw_circle(ridge + Vector2(0, -30), 70.0, Color(1.0, 0.65, 0.3, glow_a))
		var k := 2.2
		var wax := Color("#ecdfc6")
		var o := ridge
		draw_rect(Rect2(o + Vector2(-5, -7) * k, Vector2(4, 7) * k), Color("#2b2132"))
		draw_rect(Rect2(o + Vector2(2, -7) * k, Vector2(4, 7) * k), Color("#2b2132"))
		draw_colored_polygon(PackedVector2Array([o + Vector2(-10, -6) * k, o + Vector2(10, -6) * k, o + Vector2(10, -24) * k, o + Vector2(6, -27) * k, o + Vector2(1, -25.5) * k, o + Vector2(-4, -27) * k, o + Vector2(-10, -24) * k]), wax)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-10.5, -15.5) * k, o + Vector2(10.5, -16.5) * k, o + Vector2(10.5, -11.5) * k, o + Vector2(-10.5, -10.8) * k]), Color("#b8382f"))
		var sw := sin(_t * 2.5) * 2.0
		draw_colored_polygon(PackedVector2Array([o + Vector2(-10, -15) * k, o + Vector2(-22, -14 + sw) * k, o + Vector2(-20, -10 + sw) * k, o + Vector2(-10, -11) * k]), Color("#7a2421"))
		draw_circle(o + Vector2(3, -19.5) * k, 1.8 * k, Color("#1d1526"))
		draw_circle(o + Vector2(7.5, -19.5) * k, 1.8 * k, Color("#1d1526"))
		FX.draw_flame(self, o + Vector2(1, -26) * k, 11.0 * k * 0.55, _t, sin(_t) * 2.0)
		draw_line(o + Vector2(9, -9) * k, o + Vector2(24, -14) * k, Color("#e8ca70"), 2.5 * k)
