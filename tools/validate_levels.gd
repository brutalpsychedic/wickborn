extends SceneTree
## Level QA: checks every level can be finished and every collectible can be reached,
## by simulating the player's real movement physics (run, variable jump, double jump, dash)
## from the start position and flood-filling reachable standing spots.
##   godot --headless --path . --script res://tools/validate_levels.gd [-- --level=N]
## Breakable walls and boss gates count as open; enemies are ignored.
## Approximations: one input direction per jump (optionally delayed), moving platforms are
## treated as standable anywhere along their track.

const T := 32.0
const DT := 1.0 / 60.0
const HW := 8.0
const HH := 14.0

var _ran := false
var rows: Array = []
var w := 0
var h := 0
var oneway: Dictionary = {}
var touched: Dictionary = {}
var P: Dictionary = {}   # player physics constants, read from player.gd at runtime


func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_validate_all()
		quit()
	return false


func _validate_all() -> void:
	var ps: Script = load("res://scripts/player/player.gd")
	P = ps.get_script_constant_map()
	var only := 0
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--level="):
			only = int(String(a).split("=")[1])
	var problems := 0
	for n in range(1, 11):
		if only != 0 and n != only:
			continue
		problems += _validate(n)
	print("VALIDATION DONE problems=%d" % problems)


func _validate(n: int) -> int:
	var d := LevelData.load_file("res://levels/level_%02d.txt" % n)
	rows = d.rows
	w = d.w
	h = d.h
	_find_movers()
	var start := Vector2i(-1, -1)
	var targets: Dictionary = {}
	var upgrade_cells: Array = []
	for cy in h:
		for cx in w:
			var ch := String.chr(rows[cy][cx])
			if ch == "P":
				start = Vector2i(cx, cy)
			elif ch in ["E", "C", "o", "*", "H", "D", "J", "Q"]:
				targets[Vector2i(cx, cy)] = ch
				if ch in ["D", "J", "Q"]:
					upgrade_cells.append(Vector2i(cx, cy))
	var base_dash := n > 2
	var base_dj := n > 4
	var problems := 0
	# pass 1: the in-level upgrade must be reachable without it
	if not upgrade_cells.is_empty():
		touched.clear()
		_flood(start, base_dash, base_dj)
		for uc in upgrade_cells:
			if not _touched_near(uc):
				print("  L%d PROBLEM: upgrade %s at %s unreachable without it" % [n, targets[uc], uc])
				problems += 1
	# pass 2: everything with all abilities available by the end of this level
	var dash := base_dash or n == 2
	var dj := base_dj or n == 4
	touched.clear()
	var states := _flood(start, dash, dj)
	var missing := []
	for c in targets:
		if not _touched_near(c):
			missing.append("%s@%d,%d" % [targets[c], c.x, c.y])
			if targets[c] in ["E", "C"]:
				problems += 1
	print("L%d: %d standing spots, %d targets, unreachable: %s" % [n, states, targets.size(), "none" if missing.is_empty() else ", ".join(missing)])
	if not missing.is_empty():
		problems += 0
	return problems + (1 if missing.size() > 0 else 0)


func _touched_near(c: Vector2i) -> bool:
	# pickups have ~13-18 px radius, so touching an adjacent cell edge usually collects them;
	# require the cell itself to be overlapped to stay conservative
	return touched.has(c)


func _find_movers() -> void:
	oneway.clear()
	for cy in h:
		for cx in w:
			var ch := String.chr(rows[cy][cx])
			if ch == "=" or ch == "x":
				oneway[Vector2i(cx, cy)] = true
			elif ch == "M":
				var n := 0
				while cx + n + 1 < w and String.chr(rows[cy][cx + n + 1]) == "-":
					n += 1
				if n > 0:
					for x in range(cx - 1, cx + n + 2):
						oneway[Vector2i(x, cy)] = true
					continue
				var up := 0
				while cy - up - 1 >= 0 and String.chr(rows[cy - up - 1][cx]) == "|":
					up += 1
				for y in range(cy - up, cy + 1):
					for x in range(cx - 1, cx + 2):
						oneway[Vector2i(x, y)] = true


func _ch(cx: int, cy: int) -> String:
	if cy < 0:
		return "."
	if cy >= h:
		return "."
	if cx < 0 or cx >= w:
		return "#"
	return String.chr(rows[cy][cx])


func _solid(cx: int, cy: int) -> bool:
	return _ch(cx, cy) == "#"


func _overlaps_solid(x: float, y: float) -> bool:
	for cy in range(floori((y - HH) / T), floori((y + HH - 0.01) / T) + 1):
		for cx in range(floori((x - HW) / T), floori((x + HW - 0.01) / T) + 1):
			if _solid(cx, cy):
				return true
	return false


func _hazard(x: float, y: float) -> bool:
	for cy in range(floori((y - HH) / T), floori((y + HH - 0.01) / T) + 1):
		for cx in range(floori((x - HW) / T), floori((x + HW - 0.01) / T) + 1):
			var ch := _ch(cx, cy)
			if ch == "^" and y + HH > cy * T + T - 14.0:
				return true
			if ch == "v" and y - HH < cy * T + 14.0:
				return true
			if ch == "~":
				var surface := _ch(cx, cy - 1) != "~"
				if not surface or y + HH > cy * T + 12.0:
					return true
	return false


## Returns the feet cell where the body comes to rest, or (-1,-1) on death / timeout.
func _sim(x: float, y: float, dir: int, vx0: float, hold: int, dj_frame: int, dash_frame: int, delay: int, jump: bool, record: Array) -> Vector2i:
	var vx := vx0
	var vy := -float(P["JUMP_VELOCITY"]) if jump else 0.0
	var airborne := jump
	var dash_left := 0
	var start_cell := Vector2i(floori(x / T), floori((y + HH - 1.0) / T))
	for f in 150:
		var in_dir := dir if f >= delay else 0
		if dash_frame >= 0 and f == dash_frame and in_dir != 0:
			dash_left = 10
		if dash_left > 0:
			dash_left -= 1
			vx = in_dir * float(P["DASH_SPEED"])
			vy = 0.0
		else:
			var target := in_dir * float(P["RUN_SPEED"])
			var accel := float(P["AIR_ACCEL"]) if absf(target) > 1.0 else float(P["AIR_DECEL"])
			if not airborne:
				accel = float(P["GROUND_ACCEL"]) if absf(target) > 1.0 else float(P["GROUND_DECEL"])
			vx = move_toward(vx, target, accel * DT)
			var g := float(P["GRAVITY_DOWN"])
			if vy < 0.0:
				g = float(P["GRAVITY_UP"]) if f < hold else float(P["GRAVITY_CUT"])
			vy = minf(vy + g * DT, float(P["MAX_FALL"]))
			if dj_frame >= 0 and f == dj_frame:
				vy = -float(P["DOUBLE_JUMP_VELOCITY"])
		# x movement
		var dx := vx * DT
		var steps := int(ceilf(absf(dx) / 6.0))
		for i in steps:
			var nx := x + dx / steps
			if _overlaps_solid(nx, y):
				vx = 0.0
				break
			x = nx
		# y movement
		var dy := vy * DT
		var landed := false
		var ysteps := maxi(1, int(ceilf(absf(dy) / 6.0)))
		for i in ysteps:
			var ny := y + dy / ysteps
			if _overlaps_solid(x, ny):
				if vy > 0.0:
					landed = true
				vy = 0.0
				break
			if vy > 0.0 and _oneway_hit(x, y, ny):
				landed = true
				vy = 0.0
				break
			y = ny
		if not landed and not airborne and vy >= 0.0:
			# walking: check if still supported
			if _supported(x, y):
				landed = true
		if _hazard(x, y) or y > h * T + 48.0:
			return Vector2i(-1, -1)
		record.append(Vector2(x, y))
		if landed or (airborne and _supported(x, y) and vy >= 0.0):
			if airborne or f > 0:
				var cell := Vector2i(floori(x / T), floori((y + HH - 1.0) / T))
				if not jump and cell == start_cell:
					continue
				return cell
		if not _supported(x, y):
			airborne = true
	return Vector2i(-1, -1)


func _supported(x: float, y: float) -> bool:
	var fy := y + HH + 1.0
	var cy := floori(fy / T)
	for cx in [floori((x - HW) / T), floori((x + HW - 0.01) / T)]:
		if _solid(cx, cy):
			return true
		if oneway.has(Vector2i(cx, cy)) and absf(fy - cy * T) < 2.0:
			return true
	return false


func _oneway_hit(x: float, y0: float, y1: float) -> bool:
	var b0 := y0 + HH
	var b1 := y1 + HH
	var cy := floori(b1 / T)
	var top := cy * T
	if b0 > top + 0.5 or b1 < top:
		return false
	for cx in [floori((x - HW) / T), floori((x + HW - 0.01) / T)]:
		if oneway.has(Vector2i(cx, cy)):
			return true
	return false


func _record(path: Array) -> void:
	for p in path:
		var v: Vector2 = p
		for cy in range(floori((v.y - HH) / T), floori((v.y + HH - 0.01) / T) + 1):
			for cx in range(floori((v.x - HW - 6.0) / T), floori((v.x + HW + 6.0) / T) + 1):
				touched[Vector2i(cx, cy)] = true


func _flood(start: Vector2i, dash: bool, dj: bool) -> int:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var combos: Array = []
	for dir in [-1, 0, 1]:
		var vxs := [0.0] if dir == 0 else [0.0, dir * float(P["RUN_SPEED"])]
		var delays := [0] if dir == 0 else [0, 12]
		for vx0 in vxs:
			for delay in delays:
				if delay > 0 and vx0 != 0.0:
					continue
				for hold in [6, 40]:
					for djf in ([-1, 22] if dj else [-1]):
						for dsf in ([-1, 16] if dash and dir != 0 else [-1]):
							combos.append([dir, vx0, hold, djf, dsf, delay])
	while head < queue.size():
		var s := queue[head]
		head += 1
		var x := s.x * T + T * 0.5
		var y := (s.y + 1) * T - HH
		var rec0: Array = [Vector2(x, y)]
		_record(rec0)
		var results: Array = []
		for dir in [-1, 1]:
			var rec: Array = []
			var r := _sim(x, y, dir, 0.0, 0, -1, -1, 0, false, rec)
			if r.x >= 0:
				_record(rec)
				results.append(r)
		for c in combos:
			var rec2: Array = []
			var r2 := _sim(x, y, c[0], c[1], c[2], c[3], c[4], c[5], true, rec2)
			if r2.x >= 0:
				_record(rec2)
				results.append(r2)
		for r3v in results:
			var r3: Vector2i = r3v
			# a landing on a ledge corner may leave the cell centre over air: snap to the supported side
			if not _supported(r3.x * T + T * 0.5, (r3.y + 1) * T - HH):
				if _supported((r3.x - 1) * T + T * 0.5, (r3.y + 1) * T - HH):
					r3 = Vector2i(r3.x - 1, r3.y)
				elif _supported((r3.x + 1) * T + T * 0.5, (r3.y + 1) * T - HH):
					r3 = Vector2i(r3.x + 1, r3.y)
				else:
					continue
			if not seen.has(r3):
				seen[r3] = true
				queue.append(r3)
	return seen.size()
