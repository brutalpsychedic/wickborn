class_name Platforms
## Dynamic terrain pieces: moving platforms, crumbling slabs, breakable walls and boss gates.


## Platform that eases back and forth between two points. Origin = centre of its top surface.
class MovingPlatform extends AnimatableBody2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var speed := 75.0
	var width := 96.0
	var color := Color(0.4, 0.35, 0.3)
	var accent := Color(1, 0.8, 0.5)
	var _t := 0.0
	var _dur := 1.0

	func _ready() -> void:
		sync_to_physics = true
		collision_layer = Phys.WORLD
		collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.shape = Phys.rect_shape(Vector2(width, 14))
		cs.position = Vector2(0, 7)
		add_child(cs)
		_dur = maxf(0.5, from.distance_to(to) / speed)
		position = from
		z_index = 2

	func _physics_process(delta: float) -> void:
		_t += delta
		var k := 0.5 - 0.5 * cos(_t / _dur * PI)
		position = from.lerp(to, k)

	func _draw() -> void:
		var hw := width * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw - 6, 14), Vector2(-hw + 6, 14)]), color)
		draw_rect(Rect2(-hw, 0, width, 3), color.lightened(0.25))
		draw_line(Vector2(-hw + 6, 14), Vector2(hw - 6, 14), color.darkened(0.5), 2.0)
		for i in 3:
			draw_circle(Vector2(-hw * 0.6 + i * hw * 0.6, 8), 2.5, Color(accent.r, accent.g, accent.b, 0.85))


## Slab that cracks a moment after being stood on, falls away, then returns.
## Origin = top-left of the run of 'x' cells.
class CrumblePlatform extends StaticBody2D:
	var cells := 1
	var color := Color(0.4, 0.35, 0.3)
	var _state := 0   # 0 solid, 1 shaking, 2 gone
	var _t := 0.0
	var _shape: CollisionShape2D
	var _sensor: Area2D
	var _art: Node2D

	func _ready() -> void:
		collision_layer = Phys.WORLD
		collision_mask = 0
		var wpx := float(cells * Phys.TILE)
		_shape = CollisionShape2D.new()
		_shape.shape = Phys.rect_shape(Vector2(wpx, 16))
		_shape.position = Vector2(wpx * 0.5, 8)
		add_child(_shape)
		_sensor = Phys.make_area(Vector2(wpx - 4, 8), 0, Phys.PLAYER, Vector2(wpx * 0.5, -4))
		add_child(_sensor)
		_art = Slab.new()
		_art.wpx = wpx
		_art.color = color
		add_child(_art)
		z_index = 1

	func _physics_process(delta: float) -> void:
		match _state:
			0:
				for b in _sensor.get_overlapping_bodies():
					if b is Player and (b as Player).is_on_floor():
						_state = 1
						_t = 0.5
						Audio.play("crumble", 0.1, -6.0)
			1:
				_t -= delta
				_art.position = Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
				if _t <= 0.0:
					_state = 2
					_t = 2.6
					_shape.set_deferred("disabled", true)
					FX.burst(get_parent(), global_position + Vector2(cells * Phys.TILE * 0.5, 8), color.lightened(0.2), 14, 90.0, 0.6, 500.0, 4.0)
					var tw := create_tween().set_parallel(true)
					tw.tween_property(_art, "position:y", 40.0, 0.35)
					tw.tween_property(_art, "modulate:a", 0.0, 0.35)
			2:
				_t -= delta
				if _t <= 0.0 and _sensor.get_overlapping_bodies().is_empty():
					_state = 0
					_shape.set_deferred("disabled", false)
					_art.position = Vector2.ZERO
					var tw2 := create_tween()
					tw2.tween_property(_art, "modulate:a", 1.0, 0.3)

	class Slab extends Node2D:
		var wpx := 32.0
		var color := Color.GRAY
		func _draw() -> void:
			draw_rect(Rect2(0, 0, wpx, 14), color)
			draw_rect(Rect2(0, 0, wpx, 3), color.lightened(0.2))
			draw_rect(Rect2(0, 12, wpx, 2), color.darkened(0.45))
			var x := 7.0
			while x < wpx - 4.0:
				draw_line(Vector2(x, 3), Vector2(x + 4, 9), color.darkened(0.5), 1.2)
				draw_line(Vector2(x + 4, 9), Vector2(x + 1, 13), color.darkened(0.5), 1.2)
				x += 15.0


## Cracked section of wall. Three sword hits break it (often hiding a secret).
## Origin is the world origin; cells are absolute.
class BreakableWall extends StaticBody2D:
	var cells: Array[Vector2i] = []
	var level: Level = null
	var hp := 3
	var color := Color(0.3, 0.28, 0.35)
	var outline := Color(0.1, 0.1, 0.1)
	var _shake := 0.0

	func _ready() -> void:
		collision_layer = Phys.WORLD
		collision_mask = 0
		var T := float(Phys.TILE)
		var r := Rect2()
		for i in cells.size():
			var c := cells[i]
			var cs := CollisionShape2D.new()
			cs.shape = Phys.rect_shape(Vector2(T, T))
			cs.position = Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5)
			add_child(cs)
			var cr := Rect2(c.x * T, c.y * T, T, T)
			r = cr if i == 0 else r.merge(cr)
		var hb := Hurtbox.create(self, r.size + Vector2(10, 4), r.get_center())
		add_child(hb)
		z_index = 1

	func take_hit(_dmg: int, dir: int, _attacker: Node) -> bool:
		hp -= 1
		_shake = 0.15
		Audio.play("hit", 0.1, -4.0)
		var T := float(Phys.TILE)
		var c := cells[0]
		FX.burst(get_parent(), Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5), color.lightened(0.3), 6, 120.0, 0.4, 400.0, 3.0)
		if hp <= 0:
			for cc in cells:
				FX.burst(get_parent(), Vector2(cc.x * T + T * 0.5, cc.y * T + T * 0.5), color.lightened(0.2), 8, 160.0, 0.7, 600.0, 5.0)
			Audio.play("break", 0.05)
			FX.shake(self, 5.0, 0.2)
			if level != null:
				level.clear_cells(cells)
			queue_free()
		queue_redraw()
		return true

	func _process(delta: float) -> void:
		if _shake > 0.0:
			_shake -= delta
			position = Vector2(randf_range(-2, 2), 0) if _shake > 0.0 else Vector2.ZERO

	func _draw() -> void:
		var T := float(Phys.TILE)
		for c in cells:
			var o := Vector2(c.x * T, c.y * T)
			draw_rect(Rect2(o, Vector2(T, T)), color)
			draw_rect(Rect2(o, Vector2(T, T)), outline, false, 1.0)
			var k := (c.x * 13 + c.y * 7) % 3
			var crack := color.darkened(0.55)
			draw_line(o + Vector2(6 + k * 4, 4), o + Vector2(14 + k * 2, 15), crack, 1.5)
			draw_line(o + Vector2(14 + k * 2, 15), o + Vector2(10, 27), crack, 1.5)
			if hp < 3:
				draw_line(o + Vector2(20, 6), o + Vector2(26, 18), crack, 2.0)
			if hp < 2:
				draw_line(o + Vector2(4, 20), o + Vector2(18, 24), crack, 2.0)


## Iron portcullis that seals a boss arena while the fight is on. Origin = world origin.
class BossGate extends StaticBody2D:
	var cells: Array[Vector2i] = []
	var level: Level = null
	var closed := false
	var _shape: CollisionShape2D
	var _art: Node2D
	var _rect := Rect2()

	func _ready() -> void:
		collision_layer = Phys.WORLD
		collision_mask = 0
		var T := float(Phys.TILE)
		for i in cells.size():
			var cr := Rect2(cells[i].x * T, cells[i].y * T, T, T)
			_rect = cr if i == 0 else _rect.merge(cr)
		_shape = CollisionShape2D.new()
		_shape.shape = Phys.rect_shape(Vector2(T * 0.6, _rect.size.y))
		_shape.position = _rect.get_center()
		_shape.disabled = true
		add_child(_shape)
		_art = Bars.new()
		_art.rect = _rect
		_art.position = Vector2(0, -_rect.size.y)
		_art.modulate.a = 0.0
		add_child(_art)
		z_index = 3

	func close() -> void:
		if closed:
			return
		closed = true
		_shape.set_deferred("disabled", false)
		if level != null:
			level.set_cells(cells, Phys.CH_GATE)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_art, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_art, "modulate:a", 1.0, 0.15)
		Audio.play("gate", 0.0)
		FX.shake(self, 4.0, 0.2)

	func open() -> void:
		if not closed:
			return
		closed = false
		_shape.set_deferred("disabled", true)
		if level != null:
			level.set_cells(cells, Phys.CH_GATE_OPEN)
		var tw := create_tween()
		tw.tween_property(_art, "position:y", -_rect.size.y, 0.8)
		tw.tween_property(_art, "modulate:a", 0.0, 0.2)
		Audio.play("gate", 0.0)

	class Bars extends Node2D:
		var rect := Rect2()
		func _draw() -> void:
			var iron := Color(0.22, 0.2, 0.24)
			var hi := Color(0.42, 0.38, 0.44)
			var n := 3
			for i in n:
				var x := rect.position.x + 6.0 + i * (rect.size.x - 12.0) / float(n - 1)
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), iron, 4.0)
				draw_line(Vector2(x - 1, rect.position.y), Vector2(x - 1, rect.end.y), hi, 1.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 4, rect.end.y - 6), Vector2(x + 4, rect.end.y - 6), Vector2(x, rect.end.y + 2)]), iron)
			var y := rect.position.y + 10.0
			while y < rect.end.y - 10.0:
				draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y), iron, 3.0)
				y += 28.0


## Terrain-looking cover over a hidden room. Fades out once the player steps inside it.
class SecretOverlay extends Node2D:
	var cells: Dictionary = {}
	var level: Level = null
	var _revealed := false

	func _ready() -> void:
		z_index = 45

	func _process(_delta: float) -> void:
		if _revealed or level == null or level.player == null:
			return
		var p := level.player.global_position
		var c := Vector2i(floori(p.x / Phys.TILE), floori(p.y / Phys.TILE))
		var c2 := Vector2i(floori(p.x / Phys.TILE), floori((p.y - 12.0) / Phys.TILE))
		if cells.has(c) or cells.has(c2):
			_revealed = true
			Audio.play("secret", 0.0, -8.0)
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.45)
			tw.tween_callback(queue_free)

	func _draw() -> void:
		if level != null:
			TerrainChunk.draw_cells(self, level, cells.keys(), true)
