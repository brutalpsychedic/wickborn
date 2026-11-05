class_name DamageArea
extends Area2D
## Anything that hurts the player: enemy bodies, attacks, projectiles, spikes, water.
## The player polls its hurtbox for these each physics frame (so standing in one keeps hurting
## once invulnerability ends). `hazard` areas also send the player back to safe ground.

var damage := 1
var hazard := false
var enabled := true


static func create(size: Vector2, dmg: int = 1, is_hazard: bool = false, offset: Vector2 = Vector2.ZERO) -> DamageArea:
	var a := DamageArea.new()
	a.damage = dmg
	a.hazard = is_hazard
	a.collision_layer = Phys.HURT_PLAYER
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(size)
	cs.position = offset
	a.add_child(cs)
	return a


func set_size(size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	var cs := get_child(0) as CollisionShape2D
	(cs.shape as RectangleShape2D).size = size
	cs.position = offset
