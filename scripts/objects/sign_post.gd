class_name SignPost
extends Area2D
## Stone tablet. When the player is near, its text shows in the HUD hint banner
## (screen-space, so it stays readable on small phones). Origin is at ground level.

var text := ""
var level: Level = null
var _near := false


func _ready() -> void:
	collision_layer = Phys.TRIGGER
	collision_mask = Phys.PLAYER
	monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(Vector2(150, 110))
	cs.position = Vector2(0, -40)
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	z_index = 2


func _on_enter(b: Node) -> void:
	if b is Player and level != null:
		_near = true
		level.on_sign(self, true)
		queue_redraw()


func _on_exit(b: Node) -> void:
	if b is Player and level != null:
		_near = false
		level.on_sign(self, false)
		queue_redraw()


func _draw() -> void:
	var stone := Color(0.32, 0.3, 0.36)
	var dark := Color(0.17, 0.15, 0.2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 0), Vector2(13, 0), Vector2(12, -26), Vector2(8, -32),
		Vector2(-8, -32), Vector2(-12, -26)]), stone)
	draw_polyline(PackedVector2Array([Vector2(-13, 0), Vector2(-12, -26), Vector2(-8, -32),
		Vector2(8, -32), Vector2(12, -26), Vector2(13, 0)]), dark, 1.5)
	var rune := Color(1.0, 0.8, 0.45, 0.95) if _near else Color(0.55, 0.5, 0.6)
	draw_line(Vector2(-6, -24), Vector2(6, -24), rune, 2.0)
	draw_line(Vector2(-6, -17), Vector2(3, -17), rune, 2.0)
	draw_line(Vector2(-6, -10), Vector2(5, -10), rune, 2.0)
