class_name Checkpoint
extends Area2D
## Lantern post. Touching it lights it, heals the player and makes it the respawn point.
## Origin is at ground level (bottom centre of its map cell).

var id := ""
var lit := false
var level: Level = null
var _t := 0.0
var _glow: Sprite2D


func _ready() -> void:
	collision_layer = Phys.TRIGGER
	collision_mask = Phys.PLAYER
	monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(Vector2(44, 70))
	cs.position = Vector2(0, -35)
	add_child(cs)
	body_entered.connect(_on_body)
	z_index = 4
	_glow = FX.make_glow(Color(1.0, 0.65, 0.3, 0.0), 150.0)
	_glow.position = Vector2(0, -62)
	add_child(_glow)
	set_process(false)
	if lit:
		light(true)


func light(silent: bool = false) -> void:
	lit = true
	_glow.modulate.a = 0.55
	set_process(true)
	if not silent:
		Audio.play("checkpoint", 0.0)
		FX.burst(get_parent(), global_position + Vector2(0, -62), Color(1.0, 0.75, 0.35), 18, 150.0, 0.7, -40.0, 3.0, true)
		var tw := create_tween()
		_glow.scale = Vector2.ONE * 4.0
		tw.tween_property(_glow, "scale", Vector2.ONE * (150.0 / 64.0), 0.6)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_glow.modulate.a = 0.5 + 0.06 * sin(_t * 7.0) + 0.04 * sin(_t * 13.0)
	queue_redraw()


func _on_body(b: Node) -> void:
	if b is Player and level != null:
		level.on_checkpoint(self)


func _draw() -> void:
	var iron := Color(0.16, 0.13, 0.17)
	var iron_hi := Color(0.32, 0.27, 0.3)
	# base stone
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(9, -7), Vector2(-9, -7)]), Color(0.27, 0.24, 0.3))
	# pole
	draw_rect(Rect2(-2.5, -52, 5, 46), iron)
	draw_line(Vector2(1, -50), Vector2(1, -8), iron_hi, 1.0)
	# hook arm
	draw_rect(Rect2(-2.5, -55, 14, 3), iron)
	# lantern cage
	var lx := 0.0
	draw_rect(Rect2(lx - 9, -74, 18, 4), iron)
	draw_rect(Rect2(lx - 8, -70, 16, 16), Color(0.1, 0.08, 0.1, 0.9))
	var glass := Color(1.0, 0.7, 0.35, 0.35) if lit else Color(0.4, 0.4, 0.5, 0.25)
	draw_rect(Rect2(lx - 6, -68, 12, 12), glass)
	if lit:
		FX.draw_flame(self, Vector2(lx, -58), 5.5, _t, sin(_t * 2.0) * 0.8)
	else:
		draw_circle(Vector2(lx, -59), 2.0, Color(0.5, 0.3, 0.25))
	draw_rect(Rect2(lx - 9, -54, 18, 3), iron)
	draw_line(Vector2(lx - 8, -70), Vector2(lx - 8, -54), iron_hi, 1.5)
	draw_line(Vector2(lx + 8, -70), Vector2(lx + 8, -54), iron, 1.5)
	draw_line(Vector2(lx, -74), Vector2(lx, -79), iron, 2.0)
