class_name TerrainChunk
extends Node2D
## Draws a 16x16-cell block of terrain once (Godot caches the draw commands), so the cost is
## a few hundred cached primitives per chunk and nothing per frame. Off-screen chunks are culled.

const SIZE := 16

var level: Level = null
var cx0 := 0
var cy0 := 0


func _draw() -> void:
	var cells: Array = []
	for cy in range(cy0, mini(cy0 + SIZE, level.h)):
		for cx in range(cx0, mini(cx0 + SIZE, level.w)):
			if level.grid[cy][cx] == Phys.CH_SOLID:
				cells.append(Vector2i(cx, cy))
	draw_cells(self, level, cells, false)
	_draw_decor()


## Shared by terrain chunks and secret overlays so both look identical.
static func draw_cells(ci: CanvasItem, level: Level, cells: Array, overlay: bool) -> void:
	var T := float(Phys.TILE)
	var th := level.theme
	var cols: Array = th["ground"]
	var outline: Color = th["outline"]
	var surf: Color = th["surface"]
	var surf2: Color = th["surface2"]
	var style: String = th["surface_style"]
	var rng := RandomNumberGenerator.new()
	var r := 9.0
	# pass 1: fills
	for c in cells:
		var cx: int = c.x
		var cy: int = c.y
		var d := level.depth_at(cx, cy)
		var col: Color = cols[mini(d, 3)]
		var top := not level.vis_solid(cx, cy - 1)
		var bot := not level.vis_solid(cx, cy + 1)
		var lft := not level.vis_solid(cx - 1, cy)
		var rgt := not level.vis_solid(cx + 1, cy)
		var x := cx * T
		var y := cy * T
		if not (top or bot or lft or rgt):
			ci.draw_rect(Rect2(x, y, T, T), col)
			continue
		var pts := PackedVector2Array()
		if top and lft:
			pts.append(Vector2(x, y + r))
			pts.append(Vector2(x + r, y))
		else:
			pts.append(Vector2(x, y))
		if top and rgt:
			pts.append(Vector2(x + T - r, y))
			pts.append(Vector2(x + T, y + r))
		else:
			pts.append(Vector2(x + T, y))
		if bot and rgt:
			pts.append(Vector2(x + T, y + T - r))
			pts.append(Vector2(x + T - r, y + T))
		else:
			pts.append(Vector2(x + T, y + T))
		if bot and lft:
			pts.append(Vector2(x + r, y + T))
			pts.append(Vector2(x, y + T - r))
		else:
			pts.append(Vector2(x, y + T))
		ci.draw_colored_polygon(pts, col)
		# edge outlines on exposed sides
		if lft:
			ci.draw_line(Vector2(x + 1, y + (r if top else 0.0)), Vector2(x + 1, y + T - (r if bot else 0.0)), outline, 2.0)
		if rgt:
			ci.draw_line(Vector2(x + T - 1, y + (r if top else 0.0)), Vector2(x + T - 1, y + T - (r if bot else 0.0)), outline, 2.0)
		if bot:
			ci.draw_line(Vector2(x + (r if lft else 0.0), y + T - 1), Vector2(x + T - (r if rgt else 0.0), y + T - 1), outline, 2.0)
	# pass 2: details (stones, bricks) and surface trims
	for c in cells:
		var cx: int = c.x
		var cy: int = c.y
		var x := cx * T
		var y := cy * T
		rng.seed = (cx * 73856093) ^ (cy * 19349663) ^ level.level_num
		var d := level.depth_at(cx, cy)
		var top := not level.vis_solid(cx, cy - 1)
		var bot := not level.vis_solid(cx, cy + 1)
		var lft := not level.vis_solid(cx - 1, cy)
		var rgt := not level.vis_solid(cx + 1, cy)
		if style == "brick" and d >= 1:
			var mortar: Color = (cols[mini(d, 3)] as Color).darkened(0.25)
			ci.draw_line(Vector2(x, y + 16), Vector2(x + T, y + 16), mortar, 1.5)
			var off := 0.0 if cy % 2 == 0 else 16.0
			ci.draw_line(Vector2(x + off + 8, y), Vector2(x + off + 8, y + 16), mortar, 1.5)
			ci.draw_line(Vector2(x + fmod(off + 24.0, 32.0), y + 16), Vector2(x + fmod(off + 24.0, 32.0), y + T), mortar, 1.5)
		elif d >= 1 and rng.randf() < 0.16:
			var sc: Color = (cols[mini(d, 3)] as Color).lightened(0.08)
			ci.draw_circle(Vector2(x + rng.randf_range(6, 26), y + rng.randf_range(6, 26)), rng.randf_range(2.0, 4.5), sc)
		if top:
			var x0 := x + (r if lft else 0.0)
			var x1 := x + T - (r if rgt else 0.0)
			match style:
				"grass", "moss":
					ci.draw_rect(Rect2(x0, y - 1, x1 - x0, 5), surf)
					var blades := rng.randi_range(2, 4)
					for i in blades:
						var bx := rng.randf_range(x0 + 2, x1 - 2)
						var bh := rng.randf_range(4.0, 10.0) if style == "grass" else rng.randf_range(2.0, 5.0)
						var bw := rng.randf_range(2.0, 3.5)
						var lean := rng.randf_range(-2.5, 2.5)
						ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - bw, y + 1), Vector2(bx + lean, y - bh), Vector2(bx + bw, y + 1)]), surf2 if i % 2 == 0 else surf)
					if style == "moss" and rng.randf() < 0.5:
						ci.draw_circle(Vector2(rng.randf_range(x0 + 4, x1 - 4), y + 1), rng.randf_range(3.0, 5.0), surf)
				"crystal":
					ci.draw_rect(Rect2(x0, y - 1, x1 - x0, 4), surf)
					if rng.randf() < 0.3:
						var bx2 := rng.randf_range(x0 + 4, x1 - 4)
						var hh := rng.randf_range(6.0, 14.0)
						ci.draw_colored_polygon(PackedVector2Array([Vector2(bx2 - 3, y + 1), Vector2(bx2, y - hh), Vector2(bx2 + 3, y + 1)]), surf2)
				"stone":
					ci.draw_rect(Rect2(x0, y - 1, x1 - x0, 4), surf)
					ci.draw_line(Vector2(x0, y + 4), Vector2(x1, y + 4), (cols[0] as Color).darkened(0.2), 1.0)
				"brick":
					ci.draw_rect(Rect2(x0, y - 2, x1 - x0, 6), surf)
					ci.draw_line(Vector2(x0, y + 4), Vector2(x1, y + 4), surf.darkened(0.45), 1.5)
		if bot and not overlay:
			match style:
				"moss", "grass":
					if rng.randf() < 0.45:
						var vx := rng.randf_range(x + 4, x + T - 4)
						var vl := rng.randf_range(6.0, 18.0)
						ci.draw_line(Vector2(vx, y + T - 1), Vector2(vx + rng.randf_range(-2, 2), y + T + vl), surf.darkened(0.25), 2.0)
				"stone", "crystal", "brick":
					if rng.randf() < 0.3:
						var sx := rng.randf_range(x + 6, x + T - 6)
						var sl := rng.randf_range(5.0, 12.0)
						var scol: Color = cols[0]
						ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 4, y + T - 1), Vector2(sx + 4, y + T - 1), Vector2(sx, y + T + sl)]), scol)


## Props on top surfaces. Only cosmetic; glow sprites for some are added by Level.
func _draw_decor() -> void:
	var T := float(Phys.TILE)
	var th := level.theme
	var rng := RandomNumberGenerator.new()
	var bd: String = th["backdrop"]
	var near: Color = (th["ground"][0] as Color).lightened(0.05)
	var acc: Color = th["accent"]
	for cy in range(cy0, mini(cy0 + SIZE, level.h)):
		for cx in range(cx0, mini(cx0 + SIZE, level.w)):
			if not level.is_decor_spot(cx, cy):
				continue
			rng.seed = (cx * 2654435761) ^ (cy * 40503) ^ (level.level_num * 977)
			if rng.randf() > 0.13:
				continue
			var base := Vector2(cx * T + rng.randf_range(6, 26), (cy + 1) * T)
			var kind := rng.randi_range(0, 2)
			match bd:
				"hills", "village":
					if kind == 0:
						_grave(base, near)
					elif kind == 1:
						_dead_tree(base, near.darkened(0.2), rng)
					else:
						_rock(base, near, rng)
				"cave", "forest":
					if kind == 0:
						_mushroom(base, acc, near, rng)
					elif kind == 1:
						_fern(base, (th["surface"] as Color).darkened(0.1), rng)
					else:
						_rock(base, near, rng)
				"crystal":
					if kind <= 1:
						_crystal(base, acc, rng)
					else:
						_rock(base, near, rng)
				"ruins", "sanctuary":
					if kind == 0:
						_column_stub(base, near.lightened(0.1), rng)
					else:
						_rock(base, near, rng)
				"fortress", "throne":
					if kind == 0:
						_candle(base, acc)
					else:
						_rock(base, near, rng)


func _rock(b: Vector2, c: Color, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(4.0, 8.0)
	draw_colored_polygon(PackedVector2Array([b + Vector2(-s, 0), b + Vector2(-s * 0.6, -s * 0.8), b + Vector2(s * 0.3, -s), b + Vector2(s, 0)]), c)


func _grave(b: Vector2, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([b + Vector2(-6, 0), b + Vector2(-6, -12), b + Vector2(-3, -16), b + Vector2(3, -16), b + Vector2(6, -12), b + Vector2(6, 0)]), c)
	draw_line(b + Vector2(0, -13), b + Vector2(0, -5), c.darkened(0.4), 1.5)
	draw_line(b + Vector2(-3, -10), b + Vector2(3, -10), c.darkened(0.4), 1.5)


func _dead_tree(b: Vector2, c: Color, rng: RandomNumberGenerator) -> void:
	var hgt := rng.randf_range(22.0, 40.0)
	draw_line(b, b + Vector2(0, -hgt), c, 3.0)
	draw_line(b + Vector2(0, -hgt * 0.6), b + Vector2(-9, -hgt * 0.85), c, 2.0)
	draw_line(b + Vector2(0, -hgt * 0.75), b + Vector2(8, -hgt * 1.0), c, 2.0)


func _mushroom(b: Vector2, acc: Color, stem: Color, rng: RandomNumberGenerator) -> void:
	var hgt := rng.randf_range(6.0, 12.0)
	draw_line(b, b + Vector2(0, -hgt), stem.lightened(0.3), 2.0)
	var cap := PackedVector2Array()
	for i in 9:
		var a := PI + PI * float(i) / 8.0
		cap.append(b + Vector2(0, -hgt) + Vector2(cos(a) * 6.0, sin(a) * 4.0))
	draw_colored_polygon(cap, Color(acc.r, acc.g, acc.b, 0.9))


func _fern(b: Vector2, c: Color, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var a := -PI * 0.5 + (i - 1) * 0.6
		var l := rng.randf_range(8.0, 14.0)
		draw_line(b, b + Vector2(cos(a), sin(a)) * l, c, 2.0)


func _crystal(b: Vector2, acc: Color, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var hgt := rng.randf_range(8.0, 20.0)
		var ox := (i - 1) * 5.0
		var lean := (i - 1) * 3.0
		draw_colored_polygon(PackedVector2Array([b + Vector2(ox - 3, 0), b + Vector2(ox + lean, -hgt), b + Vector2(ox + 3, 0)]), Color(acc.r, acc.g, acc.b, 0.75))


func _column_stub(b: Vector2, c: Color, rng: RandomNumberGenerator) -> void:
	var hgt := rng.randf_range(10.0, 26.0)
	draw_rect(Rect2(b.x - 6, b.y - hgt, 12, hgt), c)
	draw_rect(Rect2(b.x - 8, b.y - 3, 16, 3), c.darkened(0.2))
	draw_line(Vector2(b.x - 2, b.y - hgt), Vector2(b.x - 2, b.y - 3), c.darkened(0.3), 1.0)


func _candle(b: Vector2, acc: Color) -> void:
	draw_rect(Rect2(b.x - 2.5, b.y - 10, 5, 10), Color(0.85, 0.8, 0.7))
	draw_circle(b + Vector2(0, -13), 2.5, Color(acc.r, acc.g, acc.b, 0.95))
