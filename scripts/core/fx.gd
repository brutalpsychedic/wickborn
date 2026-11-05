class_name FX
## Small visual-effect helpers: cached glow/dot textures, additive glow sprites,
## one-shot particle bursts, camera shake and the shared flame shape.

static var _glow: Texture2D
static var _dot: Texture2D
static var _add_mat: CanvasItemMaterial
static var _fade_ramp: Gradient


static func glow_texture() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	return _glow


static func dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 16
		t.height = 16
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_dot = t
	return _dot


static func add_material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func fade_ramp() -> Gradient:
	if _fade_ramp == null:
		_fade_ramp = Gradient.new()
		_fade_ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		_fade_ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	return _fade_ramp


## Additive radial glow, the cheap stand-in for 2D lights. `radius` in pixels.
static func make_glow(color: Color, radius: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_texture()
	s.material = add_material()
	s.modulate = color
	s.scale = Vector2.ONE * (radius / 64.0)
	return s


## One-shot particle burst that frees itself.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12, speed: float = 160.0,
		life: float = 0.5, gravity: float = 300.0, size: float = 3.0, additive: bool = false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.texture = dot_texture()
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = size * 0.6 / 8.0
	p.scale_amount_max = size / 8.0
	p.color = color
	p.color_ramp = fade_ramp()
	if additive:
		p.material = add_material()
	p.z_index = 30
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.emitting = true


static func shake(node: Node, amount: float, duration: float = 0.25) -> void:
	if node == null or not node.is_inside_tree():
		return
	if not bool(Game.settings.get("screen_shake", true)):
		return
	var cam := node.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(amount, duration)


## Teardrop flame outline. `base` is the bottom-centre, `h` the height, `r` the bulb radius.
## Kept convex-ish so triangulation never fails.
static func flame_points(base: Vector2, r: float, h: float, t: float, lean: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 7
	for i in steps + 1:
		var a := PI * float(i) / float(steps)   # 0 -> PI sweeps the bottom half (right to left)
		pts.append(base + Vector2(cos(a) * r, sin(a) * r * 0.85 - r * 0.2))
	var f1 := sin(t * 11.0) * 0.08 + sin(t * 17.3) * 0.05
	var f2 := sin(t * 13.7 + 1.3) * 0.08
	pts.append(base + Vector2(-r * 0.92, -h * (0.30 + f2 * 0.5)))
	pts.append(base + Vector2(-r * 0.55 + lean * 0.35, -h * (0.66 + f1)))
	pts.append(base + Vector2(lean + sin(t * 9.0) * r * 0.12, -h * (1.0 + f1 * 1.2)))
	pts.append(base + Vector2(r * 0.55 + lean * 0.35, -h * (0.66 + f2)))
	pts.append(base + Vector2(r * 0.92, -h * (0.30 + f1 * 0.5)))
	return pts


## Draws a layered flame (outer, mid, core) on any CanvasItem.
static func draw_flame(ci: CanvasItem, base: Vector2, size: float, t: float, lean: float, alpha: float = 1.0) -> void:
	if size <= 0.5:
		return
	ci.draw_colored_polygon(flame_points(base, size * 0.55, size * 1.5, t, lean), Color(1.0, 0.45, 0.12, 0.95 * alpha))
	ci.draw_colored_polygon(flame_points(base + Vector2(0, -size * 0.05), size * 0.38, size * 1.05, t + 0.7, lean * 0.8), Color(1.0, 0.75, 0.25, alpha))
	ci.draw_colored_polygon(flame_points(base + Vector2(0, -size * 0.08), size * 0.2, size * 0.6, t + 1.9, lean * 0.6), Color(1.0, 0.97, 0.8, alpha))
