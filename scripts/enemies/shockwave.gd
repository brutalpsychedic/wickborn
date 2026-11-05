class_name Shockwave
extends DamageArea
## Low wave of force that rolls along the ground. Jump over it.
## Stops at walls or ledges. Origin = centre of the wave (about 11 px above the floor).

var level: Level = null
var dir := 1
var speed := 270.0
var life := 1.1
var color := Color("#ffcf5a")
var _t := 0.0


func _ready() -> void:
	damage = 1
	collision_layer = Phys.HURT_PLAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(Vector2(22, 20))
	add_child(cs)
	z_index = 12


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	position.x += dir * speed * delta
	var ahead := global_position + Vector2(dir * 12.0, 0)
	var below := global_position + Vector2(dir * 8.0, 20.0)
	if life <= 0.0 or (level != null and (level.blocks_at(ahead) or not level.standable_at(below))):
		enabled = false
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.12)
		tw.tween_callback(queue_free)
		set_physics_process(false)
	queue_redraw()


func _draw() -> void:
	var k := 1.0 + 0.15 * sin(_t * 30.0)
	var f := float(dir)
	draw_colored_polygon(PackedVector2Array([Vector2(-12 * f, 11), Vector2(-4 * f, -8 * k), Vector2(6 * f, -12 * k), Vector2(12 * f, 11)]), Color(color.r, color.g, color.b, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * f, 11), Vector2(0, -4 * k), Vector2(6 * f, -6 * k), Vector2(9 * f, 11)]), Color(1, 0.95, 0.85, 0.8))
