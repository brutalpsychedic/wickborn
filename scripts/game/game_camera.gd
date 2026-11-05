class_name GameCamera
extends Camera2D
## Follows the player with look-ahead in the facing direction. Runs in the physics step so
## the player and camera move in lockstep (no jitter on 90/120 Hz screens). Supports shake.

const ZOOM := 1.6
const LOOK_AHEAD := 56.0

var target: Player = null
var _look := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _shake_dur := 0.0
var focus_override: Variant = null   # Vector2 to frame something else (e.g. a boss arena)
var target_zoom := ZOOM


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	zoom = Vector2(ZOOM, ZOOM)
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Zoom out so a rect (e.g. a boss arena) fits on screen; call frame_rect(Rect2()) to reset.
func frame_rect(r: Rect2) -> void:
	if r.size.x <= 0.0:
		focus_override = null
		target_zoom = ZOOM
		return
	var vp := get_viewport_rect().size
	target_zoom = clampf(minf(vp.x / (r.size.x + 80.0), vp.y / (r.size.y + 40.0)), 1.0, ZOOM)
	focus_override = r.get_center()


func _physics_process(delta: float) -> void:
	if absf(zoom.x - target_zoom) > 0.001:
		var zz := move_toward(zoom.x, target_zoom, 0.8 * delta)
		zoom = Vector2(zz, zz)
	if target != null and is_instance_valid(target):
		_look = move_toward(_look, target.facing * LOOK_AHEAD, 170.0 * delta)
		var goal := target.global_position + Vector2(_look, -26.0)
		if focus_override != null:
			var fo: Vector2 = focus_override
			goal = Vector2(lerpf(goal.x, fo.x, 0.8), lerpf(goal.y, fo.y, 0.45))
		global_position = goal
	if _shake_t > 0.0:
		_shake_t -= delta
		var k := _shake * (_shake_t / maxf(_shake_dur, 0.001))
		offset = Vector2(randf_range(-k, k), randf_range(-k, k))
	else:
		offset = Vector2.ZERO


func shake(amount: float, duration: float) -> void:
	_shake = maxf(_shake if _shake_t > 0.0 else 0.0, amount)
	_shake_t = duration
	_shake_dur = duration


func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position + Vector2(_look, -26.0)
	reset_smoothing()


func set_bounds(size: Vector2) -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(size.x)
	limit_bottom = int(size.y)
