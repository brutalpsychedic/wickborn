class_name Level
extends Node2D
## Builds a playable level from LevelData: merged collision, cached terrain art, hazards,
## dynamic platforms, pickups, enemies and the boss. Also answers grid queries for AI
## (solid cells, line of sight, safe ground) without physics raycasts.

signal pickup_collected(p: Pickup)
signal checkpoint_reached(cp: Checkpoint)
signal exit_reached
signal sign_changed(text: String, visible: bool)

const T := Phys.TILE

var data: LevelData
var level_num := 1
var grid: Array[PackedByteArray] = []
var depth: Array[PackedByteArray] = []
var w := 0
var h := 0
var theme: Dictionary = {}
var player: Player = null
var player_start := Vector2.ZERO
var checkpoints: Dictionary = {}     # id -> Checkpoint
var exit_gate: ExitGate = null
var boss: Boss = null
var gates: Array = []
var arena := Rect2()
var ember_total := 0
var secret_count := 0
var overlay_cells: Dictionary = {}   # Vector2i -> true, cells hidden under fake walls
var backdrop: Backdrop

var terrain_layer: Node2D
var object_layer: Node2D
var enemy_layer: Node2D
var fx_layer: Node2D


func build(d: LevelData, num: int) -> void:
	data = d
	level_num = num
	w = d.w
	h = d.h
	for r in d.rows:
		grid.append(r.duplicate())
	theme = Palettes.get_theme(d.get_meta_str("theme", "path"))
	for r in d.overlays:
		for cy in range(r.position.y, r.end.y):
			for cx in range(r.position.x, r.end.x):
				if cell(cx, cy) != Phys.CH_SOLID:
					overlay_cells[Vector2i(cx, cy)] = true
	terrain_layer = _layer("Terrain", 0)
	object_layer = _layer("Objects", 5)
	enemy_layer = _layer("Enemies", 10)
	fx_layer = _layer("FX", 30)
	_find_player_start()
	_compute_depth()
	backdrop = Backdrop.new()
	backdrop.setup(self)
	add_child(backdrop)
	move_child(backdrop, 0)
	_build_terrain_collision()
	_build_terrain_visuals()
	_build_oneway()
	_build_hazards()
	_build_dynamic()
	_spawn_entities()
	_build_overlays()
	_build_bounds()


func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	add_child(l)
	return l


# ------------------------------------------------------------------ grid queries

func cell(cx: int, cy: int) -> int:
	if cy < 0 or cy >= h:
		return Phys.CH_AIR
	if cx < 0 or cx >= w:
		return Phys.CH_SOLID
	return grid[cy][cx]


func set_cells(cells: Array, ch: int) -> void:
	for c in cells:
		if c.y >= 0 and c.y < h and c.x >= 0 and c.x < w:
			grid[c.y][c.x] = ch


func clear_cells(cells: Array) -> void:
	set_cells(cells, Phys.CH_AIR)


## Walls: block movement and line of sight.
func blocks(cx: int, cy: int) -> bool:
	var c := cell(cx, cy)
	return c == Phys.CH_SOLID or c == Phys.CH_BREAK or c == Phys.CH_GATE


## Anything a walker can stand on.
func standable(cx: int, cy: int) -> bool:
	var c := cell(cx, cy)
	return c == Phys.CH_SOLID or c == Phys.CH_BREAK or c == Phys.CH_GATE or c == Phys.CH_ONEWAY or c == Phys.CH_CRUMBLE


func blocks_at(p: Vector2) -> bool:
	return blocks(floori(p.x / T), floori(p.y / T))


func standable_at(p: Vector2) -> bool:
	return standable(floori(p.x / T), floori(p.y / T))


func is_hazard_cell(cx: int, cy: int) -> bool:
	var c := cell(cx, cy)
	return c == Phys.CH_SPIKE or c == Phys.CH_WATER or c == 118


## Terrain counted as "drawn solid" (fake walls included) for edge/depth purposes.
func vis_solid(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= w or cy < 0 or cy >= h:
		return true
	var c: int = grid[cy][cx]
	return c == Phys.CH_SOLID or c == Phys.CH_OVERLAY or overlay_cells.has(Vector2i(cx, cy))


func depth_at(cx: int, cy: int) -> int:
	if cx < 0 or cx >= w or cy < 0 or cy >= h:
		return 3
	return depth[cy][cx]


func is_decor_spot(cx: int, cy: int) -> bool:
	# air cell standing on plain ground with air above
	return cell(cx, cy) == Phys.CH_AIR and cell(cx, cy - 1) == Phys.CH_AIR and cell(cx, cy + 1) == Phys.CH_SOLID \
		and not is_hazard_cell(cx - 1, cy) and not is_hazard_cell(cx + 1, cy)


## Solid ground (not a moving/crumbling/one-way piece) under both feet and no hazard beside.
func is_safe_ground(feet: Vector2) -> bool:
	var cy := floori((feet.y + 4.0) / T)
	var cl := floori((feet.x - 8.0) / T)
	var cr := floori((feet.x + 8.0) / T)
	if cell(cl, cy) != Phys.CH_SOLID or cell(cr, cy) != Phys.CH_SOLID:
		return false
	for dx in range(-1, 2):
		if is_hazard_cell(cl + dx, cy - 1) or is_hazard_cell(cr + dx, cy - 1):
			return false
	return true


func line_of_sight(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / 12.0) + 1
	for i in range(1, steps):
		if blocks_at(a + d * (float(i) / steps)):
			return false
	return true


func pixel_size() -> Vector2:
	return Vector2(w * T, h * T)


# ------------------------------------------------------------------ build steps

func _find_player_start() -> void:
	for cy in h:
		for cx in w:
			if grid[cy][cx] == 80: # 'P'
				player_start = Vector2(cx * T + T * 0.5, (cy + 1) * T - 15.0)
				grid[cy][cx] = Phys.CH_AIR
				return
	player_start = Vector2(T * 2, T * 2)


func _compute_depth() -> void:
	# BFS distance (8-neighbour) from any non-solid cell, capped at 3.
	depth.clear()
	var q: Array[Vector2i] = []
	for cy in h:
		var row := PackedByteArray()
		row.resize(w)
		row.fill(255)
		depth.append(row)
	for cy in h:
		for cx in w:
			if not vis_solid(cx, cy):
				continue
			var edge := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not vis_solid(cx + dx, cy + dy):
						edge = true
			if edge:
				depth[cy][cx] = 0
				q.append(Vector2i(cx, cy))
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		var nd: int = depth[c.y][c.x] + 1
		if nd > 3:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := c.x + dx
				var ny := c.y + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if vis_solid(nx, ny) and depth[ny][nx] > nd:
					depth[ny][nx] = nd
					q.append(Vector2i(nx, ny))
	for cy in h:
		for cx in w:
			if depth[cy][cx] == 255:
				depth[cy][cx] = 3


## Greedy-merges '#' cells into as few rectangles as possible (fewer shapes, no seams on floors).
func _build_terrain_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "TerrainBody"
	body.collision_layer = Phys.WORLD
	body.collision_mask = 0
	terrain_layer.add_child(body)
	var used := PackedByteArray()
	used.resize(w * h)
	used.fill(0)
	for cy in h:
		var cx := 0
		while cx < w:
			if grid[cy][cx] != Phys.CH_SOLID or used[cy * w + cx] == 1:
				cx += 1
				continue
			var x1 := cx
			while x1 + 1 < w and grid[cy][x1 + 1] == Phys.CH_SOLID and used[cy * w + x1 + 1] == 0:
				x1 += 1
			var y1 := cy
			while y1 + 1 < h:
				var ok := true
				for x in range(cx, x1 + 1):
					if grid[y1 + 1][x] != Phys.CH_SOLID or used[(y1 + 1) * w + x] == 1:
						ok = false
						break
				if not ok:
					break
				y1 += 1
			for yy in range(cy, y1 + 1):
				for xx in range(cx, x1 + 1):
					used[yy * w + xx] = 1
			var cs := CollisionShape2D.new()
			var sz := Vector2((x1 - cx + 1) * T, (y1 - cy + 1) * T)
			cs.shape = Phys.rect_shape(sz)
			cs.position = Vector2(cx * T, cy * T) + sz * 0.5
			body.add_child(cs)
			cx = x1 + 1


func _build_terrain_visuals() -> void:
	var cs := TerrainChunk.SIZE
	for by in range(0, h, cs):
		for bx in range(0, w, cs):
			var any := false
			for cy in range(by, mini(by + cs, h)):
				for cx in range(bx, mini(bx + cs, w)):
					if grid[cy][cx] == Phys.CH_SOLID or is_decor_spot(cx, cy):
						any = true
						break
				if any:
					break
			if not any:
				continue
			var ch := TerrainChunk.new()
			ch.level = self
			ch.cx0 = bx
			ch.cy0 = by
			terrain_layer.add_child(ch)
	_place_decor_glows()


func _place_decor_glows() -> void:
	var bd: String = theme["backdrop"]
	if not (bd in ["cave", "forest", "crystal", "fortress", "throne"]):
		return
	var acc: Color = theme["accent"]
	var last_x := -999
	var rng := RandomNumberGenerator.new()
	for cy in h:
		for cx in w:
			if not is_decor_spot(cx, cy):
				continue
			rng.seed = (cx * 2654435761) ^ (cy * 40503) ^ (level_num * 977)
			if rng.randf() > 0.13:
				continue
			var kind := rng.randi_range(0, 2)
			var glows := (bd in ["cave", "forest"] and kind == 0) or (bd == "crystal" and kind <= 1) or (bd in ["fortress", "throne"] and kind == 0)
			if not glows or absi(cx - last_x) < 4:
				continue
			last_x = cx
			var g := FX.make_glow(Color(acc.r, acc.g, acc.b, 0.22), 44.0)
			g.position = Vector2(cx * T + 16, (cy + 1) * T - 10)
			object_layer.add_child(g)


func _runs(ch: int) -> Array:
	# horizontal runs of a character: [cx, cy, length]
	var out := []
	for cy in h:
		var cx := 0
		while cx < w:
			if grid[cy][cx] != ch:
				cx += 1
				continue
			var x1 := cx
			while x1 + 1 < w and grid[cy][x1 + 1] == ch:
				x1 += 1
			out.append([cx, cy, x1 - cx + 1])
			cx = x1 + 1
	return out


func _build_oneway() -> void:
	var col: Color = theme["platform"]
	for r in _runs(Phys.CH_ONEWAY):
		var body := StaticBody2D.new()
		body.collision_layer = Phys.WORLD
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.shape = Phys.rect_shape(Vector2(r[2] * T, 10))
		cs.position = Vector2(r[0] * T + r[2] * T * 0.5, r[1] * T + 5)
		cs.one_way_collision = true
		cs.one_way_collision_margin = 8.0
		body.add_child(cs)
		terrain_layer.add_child(body)
		var art := Plank.new()
		art.position = Vector2(r[0] * T, r[1] * T)
		art.length = r[2] * T
		art.color = col
		terrain_layer.add_child(art)


func _build_hazards() -> void:
	var spike_col: Color = theme["spike"]
	var crystal := String(theme["surface_style"]) == "crystal"
	for ch in [Phys.CH_SPIKE, 118]:
		var ceiling: bool = ch == 118
		for r in _runs(ch):
			var x0: float = r[0] * T
			var y0: float = r[1] * T
			var len: float = r[2] * T
			var a := DamageArea.create(Vector2(len - 8.0, 14.0), 1, true)
			a.position = Vector2(x0 + len * 0.5, y0 + (7.0 if ceiling else T - 7.0))
			object_layer.add_child(a)
			var art := Hazards.SpikeStrip.new()
			art.position = Vector2(x0, y0)
			art.cells = r[2]
			art.ceiling = ceiling
			art.color = spike_col
			art.crystal = crystal
			object_layer.add_child(art)
	# water: greedy rectangles of '~'
	var used := PackedByteArray()
	used.resize(w * h)
	used.fill(0)
	for cy in h:
		for cx in w:
			if grid[cy][cx] != Phys.CH_WATER or used[cy * w + cx] == 1:
				continue
			var x1 := cx
			while x1 + 1 < w and grid[cy][x1 + 1] == Phys.CH_WATER and used[cy * w + x1 + 1] == 0:
				x1 += 1
			var y1 := cy
			while y1 + 1 < h:
				var ok := true
				for x in range(cx, x1 + 1):
					if grid[y1 + 1][x] != Phys.CH_WATER or used[(y1 + 1) * w + x] == 1:
						ok = false
						break
				if not ok:
					break
				y1 += 1
			for yy in range(cy, y1 + 1):
				for xx in range(cx, x1 + 1):
					used[yy * w + xx] = 1
			var sz := Vector2((x1 - cx + 1) * T, (y1 - cy + 1) * T)
			var surface := cell(cx, cy - 1) != Phys.CH_WATER
			var top_inset := 12.0 if surface else 0.0
			var a := DamageArea.create(Vector2(sz.x - 4.0, sz.y - top_inset), 1, true)
			a.position = Vector2(cx * T, cy * T) + Vector2(sz.x * 0.5, top_inset + (sz.y - top_inset) * 0.5)
			object_layer.add_child(a)
			var wb := Hazards.WaterBody.new()
			wb.position = Vector2(cx * T, cy * T)
			wb.size = sz
			wb.has_surface = surface
			wb.water_color = theme["water"]
			wb.z_index = 25
			object_layer.add_child(wb)


func _build_dynamic() -> void:
	var plat: Color = theme["platform"]
	for r in _runs(Phys.CH_CRUMBLE):
		var cp := Platforms.CrumblePlatform.new()
		cp.cells = r[2]
		cp.color = plat.lightened(0.05)
		cp.position = Vector2(r[0] * T, r[1] * T)
		terrain_layer.add_child(cp)
	# breakable walls: flood fill connected '%' cells
	var seen := {}
	for cy in h:
		for cx in w:
			if grid[cy][cx] != Phys.CH_BREAK or seen.has(Vector2i(cx, cy)):
				continue
			var region := _flood(Vector2i(cx, cy), Phys.CH_BREAK, seen)
			var bw := Platforms.BreakableWall.new()
			bw.cells.assign(region)
			bw.level = self
			bw.color = (theme["ground"][0] as Color).lightened(0.04)
			bw.outline = theme["outline"]
			terrain_layer.add_child(bw)
	# boss gates: vertical runs of 'G'
	var gseen := {}
	for cy in h:
		for cx in w:
			if grid[cy][cx] != Phys.CH_GATE or gseen.has(Vector2i(cx, cy)):
				continue
			var cells: Array[Vector2i] = []
			var y := cy
			while y < h and grid[y][cx] == Phys.CH_GATE:
				cells.append(Vector2i(cx, y))
				gseen[Vector2i(cx, y)] = true
				y += 1
			var gate := Platforms.BossGate.new()
			gate.cells = cells
			gate.level = self
			terrain_layer.add_child(gate)
			gates.append(gate)
			set_cells(cells, Phys.CH_GATE_OPEN)
	# moving platforms: 'M' followed by '-' (horizontal) or with '|' below/above (vertical)
	for cy in h:
		for cx in w:
			if grid[cy][cx] != Phys.CH_MOVER:
				continue
			var from := Vector2(cx * T + T * 0.5, cy * T)
			var to := from
			var n := 0
			while cell(cx + n + 1, cy) == Phys.CH_TRACK_H:
				n += 1
			if n > 0:
				to = from + Vector2(n * T, 0)
			else:
				while cell(cx, cy + n + 1) == Phys.CH_TRACK_V:
					n += 1
				if n > 0:
					to = from + Vector2(0, n * T)
				else:
					while cell(cx, cy - n - 1) == Phys.CH_TRACK_V:
						n += 1
					to = from + Vector2(0, -n * T)
			var mp := Platforms.MovingPlatform.new()
			mp.from = from
			mp.to = to
			mp.color = plat
			mp.accent = theme["accent"]
			terrain_layer.add_child(mp)
			grid[cy][cx] = Phys.CH_AIR
	for cy in h:
		for cx in w:
			if grid[cy][cx] == Phys.CH_TRACK_H or grid[cy][cx] == Phys.CH_TRACK_V:
				grid[cy][cx] = Phys.CH_AIR


func _flood(start: Vector2i, ch: int, seen: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		out.append(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
				continue
			if grid[n.y][n.x] == ch:
				seen[n] = true
				stack.append(n)
	return out


func _spawn_entities() -> void:
	var collected: Dictionary = Game.session.get("collected", {})
	var lit_cp := String(Game.session.get("checkpoint", ""))
	var boss_kind := data.get_meta_str("boss", "")
	for cy in h:
		for cx in w:
			var c: int = grid[cy][cx]
			var center := Vector2(cx * T + T * 0.5, cy * T + T * 0.5)
			var ground := Vector2(cx * T + T * 0.5, (cy + 1) * T)
			var id := "%d,%d" % [cx, cy]
			var handled := true
			match c:
				67: # C checkpoint
					var cp := Checkpoint.new()
					cp.id = id
					cp.level = self
					cp.position = ground
					cp.lit = (id == lit_cp)
					object_layer.add_child(cp)
					checkpoints[id] = cp
				69: # E exit
					exit_gate = ExitGate.new()
					exit_gate.level = self
					exit_gate.position = ground
					exit_gate.accent = theme["accent"]
					object_layer.add_child(exit_gate)
				111: # o ember
					ember_total += 1
					if not collected.has(id):
						_pickup("ember", id, center)
				42: # * secret
					secret_count += 1
					if not collected.has(id):
						_pickup("secret", id, center)
				72: # H heart
					var hid := "L%d_%s" % [level_num, id]
					if not Game.has_heart(hid) and not collected.has(id):
						_pickup("heart", hid, center).set_meta("cell_id", id)
				68, 74, 81: # D J Q upgrades
					var up := {68: "dash", 74: "double_jump", 81: "quick_blade"}[c] as String
					var ped := Pickup.PickupArt.new()
					ped.kind = "pedestal"
					ped.position = ground + Vector2(0, -6)
					object_layer.add_child(ped)
					if not Game.has_upgrade(up):
						_pickup(up, up, ground + Vector2(0, -34))
				99, 102, 109, 114, 104: # c f m r h enemies
					_enemy(c, ground, center)
				66: # B boss
					boss = Boss.create(boss_kind)
					if boss != null:
						boss.level = self
						boss.position = ground + Vector2(0, -boss.body_size.y * 0.5)
						boss.home = boss.position
						enemy_layer.add_child(boss)
				76: # L decorative lantern
					var lamp := Checkpoint.new()
					lamp.id = ""
					lamp.lit = true
					lamp.position = ground
					lamp.collision_mask = 0
					lamp.level = null
					object_layer.add_child(lamp)
				_:
					if c >= 49 and c <= 57: # 1-9 signs
						var sp := SignPost.new()
						sp.level = self
						var idx := c - 49
						sp.text = data.signs[idx] if idx < data.signs.size() else ""
						sp.position = ground
						object_layer.add_child(sp)
					else:
						handled = false
			if handled:
				grid[cy][cx] = Phys.CH_AIR
	_compute_arena()


func _pickup(kind: String, id: String, pos: Vector2) -> Pickup:
	var p := Pickup.new()
	p.kind = kind
	p.id = id
	p.level = self
	p.position = pos
	object_layer.add_child(p)
	return p


func spawn_heal(pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = "heal"
	p.level = self
	p.position = pos
	object_layer.call_deferred("add_child", p)
	p.launch(Vector2(randf_range(-60, 60), -160))


func _enemy(c: int, ground: Vector2, center: Vector2) -> void:
	var e: Enemy = null
	match c:
		99:
			e = Crawler.new()
		102:
			e = Wisp.new()
		109:
			e = Sentry.new()
		114:
			e = Caster.new()
		104:
			e = Brute.new()
	if e == null:
		return
	e.level = self
	if e.flying:
		e.position = center
	else:
		e.position = ground + Vector2(0, -e.body_size.y * 0.5)
	enemy_layer.add_child(e)


func add_enemy(e: Enemy) -> void:
	e.level = self
	enemy_layer.add_child(e)


func _compute_arena() -> void:
	if boss == null:
		return
	var left := INF
	var right := -INF
	for g in gates:
		var gx: float = (g as Platforms.BossGate).cells[0].x * T
		left = minf(left, gx + T)
		right = maxf(right, gx)
	if gates.size() < 2:
		left = boss.position.x - 12 * T
		right = boss.position.x + 12 * T
	arena = Rect2(left, boss.position.y - 10 * T, right - left, 12 * T)
	boss.arena = arena


func _build_overlays() -> void:
	for r in data.overlays:
		var ov := Platforms.SecretOverlay.new()
		ov.level = self
		for cy in range(r.position.y, r.end.y):
			for cx in range(r.position.x, r.end.x):
				if cell(cx, cy) != Phys.CH_SOLID:
					ov.cells[Vector2i(cx, cy)] = true
		if not ov.cells.is_empty():
			add_child(ov)
	var seen := {}
	for cy in h:
		for cx in w:
			if grid[cy][cx] != Phys.CH_OVERLAY or seen.has(Vector2i(cx, cy)):
				continue
			var region := _flood(Vector2i(cx, cy), Phys.CH_OVERLAY, seen)
			var ov := Platforms.SecretOverlay.new()
			ov.level = self
			for c in region:
				ov.cells[c] = true
			add_child(ov)


func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Phys.WORLD
	body.collision_mask = 0
	for side in 2:
		var cs := CollisionShape2D.new()
		cs.shape = Phys.rect_shape(Vector2(64, h * T + 2000))
		cs.position = Vector2(-32 if side == 0 else w * T + 32, h * T * 0.5 - 600)
		body.add_child(cs)
	terrain_layer.add_child(body)


# ------------------------------------------------------------------ callbacks from objects

func on_pickup(p: Pickup) -> void:
	pickup_collected.emit(p)


func on_checkpoint(cp: Checkpoint) -> void:
	checkpoint_reached.emit(cp)


func on_exit_reached() -> void:
	exit_reached.emit()


func on_sign(sp: SignPost, near: bool) -> void:
	sign_changed.emit(sp.text, near)


## A plank / ledge for one-way platforms.
class Plank extends Node2D:
	var length := 32.0
	var color := Color(0.4, 0.3, 0.2)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, length, 9), color)
		draw_rect(Rect2(0, 0, length, 2), color.lightened(0.3))
		draw_rect(Rect2(0, 8, length, 2), color.darkened(0.5))
		var x := 4.0
		while x < length:
			draw_line(Vector2(x, 2), Vector2(x, 8), color.darkened(0.35), 1.0)
			draw_line(Vector2(x + 6, 9), Vector2(x + 6, 17), color.darkened(0.3), 2.0)
			x += 32.0
