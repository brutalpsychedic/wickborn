class_name Pickup
extends Area2D
## Collectibles: ember (score), secret (lore "Memory Wick"), heart (+1 max flame),
## upgrades (dash / double_jump / quick_blade) and heal motes dropped by enemies.
## Shapes are drawn once; the bob/spin is done with the node transform (no per-frame redraw).

var kind := "ember"
var id := ""
var level: Level = null
var _t := 0.0
var _base := Vector2.ZERO
var _vel := Vector2.ZERO
var _life := -1.0
var _collected := false
var _art: Node2D
var _glow: Sprite2D

const COLORS := {
	"ember": Color(1.0, 0.62, 0.22),
	"secret": Color(0.55, 0.8, 1.0),
	"heart": Color(1.0, 0.35, 0.3),
	"dash": Color(1.0, 0.8, 0.4),
	"double_jump": Color(0.7, 0.95, 1.0),
	"quick_blade": Color(1.0, 0.9, 0.55),
	"heal": Color(1.0, 0.75, 0.45),
}


func _ready() -> void:
	collision_layer = Phys.TRIGGER
	collision_mask = Phys.PLAYER
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = Phys.circle_shape(13.0 if kind == "ember" or kind == "heal" else 18.0)
	add_child(cs)
	body_entered.connect(_on_body)
	_base = position
	_t = randf() * TAU
	z_index = 8
	var col: Color = COLORS.get(kind, Color.WHITE)
	var big := is_upgrade() or kind == "heart" or kind == "secret"
	_glow = FX.make_glow(Color(col.r, col.g, col.b, 0.5 if big else 0.32), 70.0 if big else 34.0)
	add_child(_glow)
	_art = PickupArt.new()
	_art.kind = kind
	add_child(_art)
	if kind == "heal":
		_life = 9.0


func is_upgrade() -> bool:
	return kind == "dash" or kind == "double_jump" or kind == "quick_blade"


## Used for heal motes dropped by enemies: pop out, then settle.
func launch(v: Vector2) -> void:
	_vel = v


func _process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	if _life > 0.0:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		if _life < 2.0:
			modulate.a = 0.4 + 0.6 * absf(sin(_t * 10.0))
	var p: Player = level.player if level != null else null
	if _vel != Vector2.ZERO:
		_vel = _vel.move_toward(Vector2.ZERO, 500.0 * delta)
		position += _vel * delta
		_base = position
	if (kind == "ember" or kind == "heal") and p != null and p.state != Player.State.DEAD:
		var d := p.global_position - global_position
		if d.length() < 80.0:
			global_position += d.normalized() * minf(d.length(), 330.0 * delta)
			_base = position
			return
	position.y = _base.y + sin(_t * 2.6) * 3.0
	if kind == "ember":
		_art.scale.x = 0.55 + 0.45 * absf(cos(_t * 2.2))
	_glow.scale = Vector2.ONE * ((1.0 + 0.08 * sin(_t * 4.0)) * _glow_radius() / 64.0)


func _glow_radius() -> float:
	return 70.0 if (is_upgrade() or kind == "heart" or kind == "secret") else 34.0


func _on_body(b: Node) -> void:
	if _collected or not (b is Player):
		return
	if (b as Player).state == Player.State.DEAD:
		return
	_collected = true
	set_deferred("monitoring", false)
	if level != null:
		level.on_pickup(self)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.22)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)


class PickupArt extends Node2D:
	var kind := "ember"

	func _draw() -> void:
		match kind:
			"ember", "heal":
				var c := Color(1.0, 0.6, 0.2) if kind == "ember" else Color(1.0, 0.82, 0.55)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(5, 0), Vector2(0, 8), Vector2(-5, 0)]), c)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -4), Vector2(2.5, 0), Vector2(0, 4), Vector2(-2.5, 0)]), Color(1.0, 0.95, 0.7))
			"secret":
				# small lantern holding a pale blue memory flame
				draw_rect(Rect2(-8, -10, 16, 18), Color(0.12, 0.1, 0.16))
				draw_rect(Rect2(-6, -8, 12, 14), Color(0.35, 0.55, 0.75, 0.55))
				FX.draw_flame(self, Vector2(0, 3), 5.0, 0.0, 0.0)
				draw_rect(Rect2(-9, -13, 18, 3), Color(0.25, 0.22, 0.3))
				draw_line(Vector2(0, -13), Vector2(0, -18), Color(0.25, 0.22, 0.3), 2.0)
				draw_rect(Rect2(-9, 8, 18, 3), Color(0.25, 0.22, 0.3))
			"heart":
				var pts := PackedVector2Array()
				for i in 24:
					var a := TAU * float(i) / 24.0
					var x := 16.0 * pow(sin(a), 3)
					var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
					pts.append(Vector2(x, y) * 0.7)
				draw_colored_polygon(pts, Color(0.95, 0.3, 0.28))
				var inner := PackedVector2Array()
				for p in pts:
					inner.append(p * 0.55 + Vector2(0, -1))
				draw_colored_polygon(inner, Color(1.0, 0.7, 0.45))
			"dash", "double_jump", "quick_blade":
				draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.85, 0.5, 0.9))
				draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.97, 0.85))
				var ic := Color(0.45, 0.25, 0.12)
				if kind == "dash":
					for k in 2:
						var ox := -4.0 + k * 6.0
						draw_polyline(PackedVector2Array([Vector2(ox - 2, -5), Vector2(ox + 3, 0), Vector2(ox - 2, 5)]), ic, 2.2)
				elif kind == "double_jump":
					for k in 2:
						var oy := 3.0 - k * 6.0
						draw_polyline(PackedVector2Array([Vector2(-5, oy + 2), Vector2(0, oy - 3), Vector2(5, oy + 2)]), ic, 2.2)
				else:
					draw_line(Vector2(-5, 5), Vector2(5, -5), ic, 2.4)
					draw_line(Vector2(-6, 1), Vector2(-1, 6), ic, 2.0)
			"pedestal":
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -6), Vector2(12, -6), Vector2(9, 6), Vector2(-9, 6)]), Color(0.3, 0.27, 0.35))
				draw_rect(Rect2(-14, -9, 28, 4), Color(0.45, 0.4, 0.5))
