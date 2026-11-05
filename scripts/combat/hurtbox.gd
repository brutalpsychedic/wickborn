class_name Hurtbox
extends Area2D
## An area the player's sword can strike. Forwards hits to `target.take_hit(damage, dir, attacker)`,
## which returns true if the hit "connected" (for hit-stop, sparks and recoil).

var target: Node = null


static func create(owner_node: Node, size: Vector2, offset: Vector2 = Vector2.ZERO) -> Hurtbox:
	var a := Hurtbox.new()
	a.target = owner_node
	a.collision_layer = Phys.HITTABLE
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(size)
	cs.position = offset
	a.add_child(cs)
	return a


func hit(damage: int, dir: int, attacker: Node) -> bool:
	if target != null and is_instance_valid(target) and target.has_method("take_hit"):
		return bool(target.take_hit(damage, dir, attacker))
	return false
