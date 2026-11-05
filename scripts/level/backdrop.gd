class_name Backdrop
extends Node2D
## Sky gradient (screen-space) plus three procedurally drawn parallax silhouette layers.
## Each layer is drawn once; only its position changes per frame (scroll = fraction of camera
## movement), so parallax costs one transform update per layer.

const SCROLL := [0.12, 0.3, 0.55]

var level: Level = null
var layers: Array[ParallaxLayerDraw] = []
var _sky_layer: CanvasLayer


func setup(lv: Level) -> void:
	level = lv


func _ready() -> void:
	var th := level.theme
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -50
	add_child(_sky_layer)
	var sky := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([th["sky_top"], th["sky_bottom"]])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 128
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_layer.add_child(sky)
	var deco := SkyDeco.new()
	deco.pal = th
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_layer.add_child(deco)
	var colors := [th["far"], th["mid"], th["near"]]
	for i in 3:
		var l := ParallaxLayerDraw.new()
		l.level = level
		l.scroll = SCROLL[i]
		l.color = colors[i]
		l.index = i
		l.z_index = -90 + i * 5
		add_child(l)
		layers.append(l)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	for l in layers:
		l.position = c * (1.0 - l.scroll)


class SkyDeco extends Control:
	var pal: Dictionary = {}

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var s := size
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		if bool(pal.get("moon", false)):
			var mpos := Vector2(s.x * 0.78, s.y * 0.2)
			draw_circle(mpos, 90.0, Color(1, 0.95, 0.85, 0.04))
			draw_circle(mpos, 60.0, Color(1, 0.95, 0.85, 0.06))
			draw_circle(mpos, 34.0, Color(0.92, 0.9, 0.82, 0.75))
			draw_circle(mpos + Vector2(9, -6), 30.0, (pal["sky_top"] as Color).lerp(pal["sky_bottom"], 0.25))
			for i in 60:
				var p := Vector2(rng.randf() * s.x, rng.randf() * s.y * 0.6)
				draw_circle(p, rng.randf_range(0.6, 1.6), Color(1, 1, 1, rng.randf_range(0.15, 0.55)))
		if String(pal.get("backdrop", "")) == "sanctuary":
			for i in 6:
				var x := s.x * (0.1 + 0.16 * i)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 0), Vector2(x + 30, 0), Vector2(x + 140, s.y), Vector2(x + 40, s.y)]), Color(1, 0.95, 0.8, 0.05))


## One silhouette layer. Local coordinates: the screen centre sits at local (cam * scroll).
class ParallaxLayerDraw extends Node2D:
	var level: Level = null
	var scroll := 0.3
	var color := Color.BLACK
	var index := 0

	func _draw() -> void:
		var th := level.theme
		var style: String = th["backdrop"]
		var lw := level.w * Phys.TILE
		var lh := level.h * Phys.TILE
		var x_min := -1400.0
		var x_max := lw * scroll + 1400.0
		# horizon: where the player usually is (start height), mapped into this layer's space
		var ref_y := level.player_start.y
		var hy := ref_y * scroll + 40.0 + index * 30.0
		var bottom := lh * scroll + 900.0
		var top := -900.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + index * 77 + level.level_num * 13
		var fog: Color = th["fog"]
		match style:
			"hills", "village":
				_hills(x_min, x_max, hy, bottom, 90.0 + index * 30.0, 0.004 + index * 0.002, rng)
				if style == "village" and index >= 1:
					_houses(x_min, x_max, hy, rng)
				elif index == 0:
					_tower(rng.randf_range(200, 900), hy - 60.0)
				if index >= 1:
					_trees(x_min, x_max, hy + 20.0, rng, 0.25)
			"forest":
				_hills(x_min, x_max, hy + 60.0, bottom, 40.0, 0.006, rng)
				_trunks(x_min, x_max, top, hy + 80.0, rng)
			"cave", "crystal":
				_cave(x_min, x_max, hy, top, bottom, rng, style == "crystal")
			"ruins", "sanctuary":
				_hills(x_min, x_max, hy + 30.0, bottom, 50.0, 0.004, rng)
				_pillars(x_min, x_max, hy + 30.0, rng, style == "sanctuary")
			"fortress", "throne":
				_hills(x_min, x_max, hy + 40.0, bottom, 30.0, 0.003, rng)
				_castle(x_min, x_max, hy + 40.0, rng, style == "throne")
		# fog band to separate layers
		var fc := Color(fog.r, fog.g, fog.b, fog.a * (0.6 + index * 0.2))
		draw_polygon(PackedVector2Array([Vector2(x_min, hy - 60), Vector2(x_max, hy - 60), Vector2(x_max, hy + 70), Vector2(x_min, hy + 70)]),
			PackedColorArray([Color(fc, 0.0), Color(fc, 0.0), fc, fc]))

	func _profile(x_min: float, x_max: float, base: float, amp: float, freq: float, rng: RandomNumberGenerator) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var p1 := rng.randf() * TAU
		var p2 := rng.randf() * TAU
		var x := x_min
		while x <= x_max:
			var y := base - amp * (0.55 + 0.3 * sin(x * freq + p1) + 0.15 * sin(x * freq * 2.7 + p2))
			pts.append(Vector2(x, y))
			x += 48.0
		pts.append(Vector2(x_max, base - amp * 0.5))
		return pts

	func _hills(x_min: float, x_max: float, base: float, bottom: float, amp: float, freq: float, rng: RandomNumberGenerator) -> void:
		var pts := _profile(x_min, x_max, base, amp, freq, rng)
		pts.append(Vector2(x_max, bottom))
		pts.append(Vector2(x_min, bottom))
		draw_colored_polygon(pts, color)

	func _trees(x_min: float, x_max: float, base: float, rng: RandomNumberGenerator, density: float) -> void:
		var x := x_min
		while x < x_max:
			x += rng.randf_range(80.0, 260.0) / density * 0.25
			var hgt := rng.randf_range(40.0, 110.0) * (0.6 + index * 0.3)
			draw_line(Vector2(x, base), Vector2(x, base - hgt), color, 4.0 + index * 2.0)
			for k in 3:
				var by := base - hgt * (0.45 + k * 0.18)
				var dir := -1.0 if k % 2 == 0 else 1.0
				draw_line(Vector2(x, by), Vector2(x + dir * hgt * 0.3, by - hgt * 0.2), color, 2.0 + index)

	func _houses(x_min: float, x_max: float, base: float, rng: RandomNumberGenerator) -> void:
		var x := x_min
		while x < x_max:
			x += rng.randf_range(160.0, 420.0)
			var wd := rng.randf_range(50.0, 90.0)
			var hgt := rng.randf_range(40.0, 70.0)
			var roof := rng.randf_range(25.0, 45.0)
			var broken := rng.randf() < 0.5
			var tip := Vector2(x + wd * 0.5, base - hgt - roof)
			if broken:
				tip = Vector2(x + wd * 0.3, base - hgt - roof * 0.6)
			draw_colored_polygon(PackedVector2Array([Vector2(x, base + 20), Vector2(x, base - hgt), tip, Vector2(x + wd, base - hgt), Vector2(x + wd, base + 20)]), color)
			if rng.randf() < 0.35:
				var wc := Color(1.0, 0.6, 0.3, 0.35)
				draw_rect(Rect2(x + wd * 0.3, base - hgt * 0.7, 8, 10), wc)

	func _tower(x: float, base: float) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 18, base + 60), Vector2(x - 14, base - 120), Vector2(x - 22, base - 130), Vector2(x, base - 170), Vector2(x + 20, base - 128), Vector2(x + 14, base - 118), Vector2(x + 18, base + 60)]), color)

	func _trunks(x_min: float, x_max: float, top: float, base: float, rng: RandomNumberGenerator) -> void:
		var x := x_min
		while x < x_max:
			x += rng.randf_range(90.0, 220.0) * (1.0 - index * 0.2)
			var wd := rng.randf_range(14.0, 28.0) * (0.7 + index * 0.45)
			draw_colored_polygon(PackedVector2Array([Vector2(x - wd * 0.5, top), Vector2(x + wd * 0.5, top), Vector2(x + wd * 0.6, base), Vector2(x + wd * 1.3, base + 30), Vector2(x - wd * 1.3, base + 30), Vector2(x - wd * 0.6, base)]), color)
			for k in 2:
				var by := base - rng.randf_range(120.0, 420.0)
				var dir := -1.0 if rng.randf() < 0.5 else 1.0
				draw_line(Vector2(x, by), Vector2(x + dir * rng.randf_range(40, 90), by - rng.randf_range(20, 60)), color, 4.0 + index * 2.0)

	func _cave(x_min: float, x_max: float, hy: float, top: float, bottom: float, rng: RandomNumberGenerator, crystal: bool) -> void:
		var ceil := hy - 260.0 + index * 40.0
		var floor_y := hy + 60.0 - index * 10.0
		# ceiling mass with stalactites
		var pts := PackedVector2Array()
		pts.append(Vector2(x_min, top))
		pts.append(Vector2(x_max, top))
		var x := x_max
		while x >= x_min:
			var depth := rng.randf_range(10.0, 40.0)
			pts.append(Vector2(x, ceil + depth))
			if rng.randf() < 0.35:
				pts.append(Vector2(x - 14.0, ceil + depth + rng.randf_range(40.0, 110.0)))
			x -= 34.0
		draw_colored_polygon(pts, color)
		# floor mass with stalagmites
		var fl := PackedVector2Array()
		x = x_min
		while x <= x_max:
			var d2 := rng.randf_range(0.0, 25.0)
			fl.append(Vector2(x, floor_y - d2))
			if rng.randf() < 0.25:
				fl.append(Vector2(x + 14.0, floor_y - d2 - rng.randf_range(30.0, 80.0)))
			x += 34.0
		fl.append(Vector2(x_max, bottom))
		fl.append(Vector2(x_min, bottom))
		draw_colored_polygon(fl, color)
		# columns joining floor and ceiling on the far layer
		if index == 0:
			x = x_min
			while x < x_max:
				x += rng.randf_range(250.0, 600.0)
				var wd := rng.randf_range(30.0, 60.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - wd * 0.4, ceil), Vector2(x + wd * 0.4, ceil), Vector2(x + wd * 0.2, (ceil + floor_y) * 0.5), Vector2(x + wd * 0.5, floor_y), Vector2(x - wd * 0.5, floor_y), Vector2(x - wd * 0.2, (ceil + floor_y) * 0.5)]), color)
		if crystal:
			var acc: Color = level.theme["accent"]
			x = x_min
			while x < x_max:
				x += rng.randf_range(120.0, 320.0)
				var hgt := rng.randf_range(30.0, 80.0) * (0.6 + index * 0.3)
				var cc := Color(acc.r, acc.g, acc.b, 0.12 + index * 0.08)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 10, floor_y), Vector2(x - 2, floor_y - hgt), Vector2(x + 10, floor_y)]), cc)
				draw_colored_polygon(PackedVector2Array([Vector2(x + 4, floor_y), Vector2(x + 14, floor_y - hgt * 0.6), Vector2(x + 20, floor_y)]), cc)

	func _pillars(x_min: float, x_max: float, base: float, rng: RandomNumberGenerator, bright: bool) -> void:
		var x := x_min
		while x < x_max:
			x += rng.randf_range(140.0, 360.0)
			var wd := rng.randf_range(22.0, 40.0) * (0.7 + index * 0.3)
			var hgt := rng.randf_range(120.0, 320.0)
			var broken := rng.randf() < 0.55 and not bright
			var top_y := base - hgt
			if broken:
				draw_colored_polygon(PackedVector2Array([Vector2(x - wd * 0.5, base + 30), Vector2(x - wd * 0.5, top_y + 20), Vector2(x - wd * 0.1, top_y), Vector2(x + wd * 0.2, top_y + 26), Vector2(x + wd * 0.5, top_y + 10), Vector2(x + wd * 0.5, base + 30)]), color)
			else:
				draw_rect(Rect2(x - wd * 0.5, top_y, wd, hgt + 30), color)
				draw_rect(Rect2(x - wd * 0.75, top_y - 10, wd * 1.5, 12), color)
				if rng.randf() < 0.4:
					# arch to the next pillar
					var span := rng.randf_range(80.0, 160.0)
					var arc := PackedVector2Array()
					for i in 11:
						var a := PI + PI * float(i) / 10.0
						arc.append(Vector2(x + span * 0.5 + cos(a) * span * 0.5, top_y + 20.0 + sin(a) * 40.0))
					draw_polyline(arc, color, 10.0 + index * 4.0)

	func _castle(x_min: float, x_max: float, base: float, rng: RandomNumberGenerator, throne: bool) -> void:
		var x := x_min
		while x < x_max:
			var seg := rng.randf_range(120.0, 260.0)
			var wall_h := rng.randf_range(60.0, 120.0) * (0.7 + index * 0.25)
			draw_rect(Rect2(x, base - wall_h, seg, wall_h + 40), color)
			var cx := x
			while cx < x + seg - 10.0:
				draw_rect(Rect2(cx, base - wall_h - 12, 12, 12), color)
				cx += 22.0
			if rng.randf() < 0.6:
				var tw := rng.randf_range(30.0, 50.0)
				var th := wall_h + rng.randf_range(60.0, 150.0)
				var tx := x + seg * rng.randf_range(0.2, 0.8)
				draw_rect(Rect2(tx - tw * 0.5, base - th, tw, th), color)
				draw_colored_polygon(PackedVector2Array([Vector2(tx - tw * 0.65, base - th), Vector2(tx, base - th - tw * (1.6 if throne else 1.1)), Vector2(tx + tw * 0.65, base - th)]), color)
				if rng.randf() < 0.5:
					var acc: Color = level.theme["accent"]
					draw_rect(Rect2(tx - 3, base - th + 18, 6, 10), Color(acc.r, acc.g, acc.b, 0.3))
			x += seg
