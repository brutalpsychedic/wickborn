class_name Phys
## Shared physics layer bits and grid constants.

const TILE := 32

# Collision layer bits (layer N = 1 << (N - 1)).
const WORLD := 1          # terrain, platforms, gates, breakable walls
const PLAYER := 2         # the player's body
const ENEMY := 4          # enemy bodies (collide with world only)
const HURT_PLAYER := 16   # areas that damage the player (contact, projectiles, hazards)
const HITTABLE := 32      # areas the player's sword can hit (enemy hurtboxes, walls, projectiles)
const TRIGGER := 64       # pickups, checkpoints, exits, signs (detect the player body)

# Map characters (see levels/README.md for the full legend).
const CH_AIR := 46        # .
const CH_SOLID := 35      # #
const CH_ONEWAY := 61     # =
const CH_SPIKE := 94      # ^
const CH_WATER := 126     # ~
const CH_CRUMBLE := 120   # x
const CH_BREAK := 37      # %
const CH_GATE := 71       # G  (closed gate)
const CH_GATE_OPEN := 103 # g  (open gate, runtime only)
const CH_OVERLAY := 38    # &  (fake wall hiding a secret)
const CH_MOVER := 77      # M
const CH_TRACK_H := 45    # -
const CH_TRACK_V := 124   # |


static func rect_shape(size: Vector2) -> RectangleShape2D:
	var s := RectangleShape2D.new()
	s.size = size
	return s


static func circle_shape(radius: float) -> CircleShape2D:
	var s := CircleShape2D.new()
	s.radius = radius
	return s


## Builds an Area2D with one rectangle shape.
static func make_area(size: Vector2, layer: int, mask: int, offset: Vector2 = Vector2.ZERO) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = layer
	a.collision_mask = mask
	a.monitorable = layer != 0
	a.monitoring = mask != 0
	var cs := CollisionShape2D.new()
	cs.shape = rect_shape(size)
	cs.position = offset
	a.add_child(cs)
	return a
