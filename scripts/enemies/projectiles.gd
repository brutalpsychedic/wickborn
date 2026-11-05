class_name Projectile
extends Area2D
## Slow glowing orb. Hurts the player on touch, pops on walls, and can be slashed away.

var level: Level = null
var velocity := Vector2.ZERO
var color := Color("#8fe3ff")
var damage := 1
var life := 4.5
var radius := 6.0
var gravity_y := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Phys.PLAYER
	monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = Phys.circle_shape(radius)
	add_child(cs)
	add_child(Hurtbox.create(self, Vector2(radius * 2.6, radius * 2.6)))
	var g := FX.make_glow(Color(color.r, color.g, color.b, 0.5), radius * 6.0)
	add_child(g)
	body_entered.connect(_on_body)
	z_index = 15


func _physics_process(delta: float) -> void:
	_t += delta
	velocity.y += gravity_y * delta
	position += velocity * delta
	life -= delta
	if life <= 0.0 or (level != null and level.blocks_at(global_position)):
		pop()
	queue_redraw()


func _on_body(b: Node) -> void:
	if b is Player:
		(b as Player).take_damage(damage, global_position)
		pop()


func take_hit(_dmg: int, _dir: int, _attacker: Node) -> bool:
	pop()
	return true


func pop() -> void:
	if is_queued_for_deletion():
		return
	FX.burst(get_parent(), global_position, color, 8, 120.0, 0.3, 0.0, 3.0, true)
	queue_free()


func _draw() -> void:
	var r := radius * (1.0 + 0.12 * sin(_t * 14.0))
	draw_circle(Vector2.ZERO, r * 1.6, Color(color.r, color.g, color.b, 0.3))
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2.ZERO, r * 0.45, Color(1, 1, 1, 0.95))
