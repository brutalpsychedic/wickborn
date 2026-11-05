class_name Player
extends CharacterBody2D
## Wick, the candle-spirit. Tight platformer controller:
## variable-height jump, coyote time, jump buffering, optional double jump, dash,
## a horizontal sword combo with auto-repeat while held, knockback and i-frames.
## Body origin = centre of a 16x28 box (feet at +14).

signal hp_changed(hp: int, max_hp: int)
signal died

const RUN_SPEED := 230.0
const GROUND_ACCEL := 2600.0
const GROUND_DECEL := 3000.0
const AIR_ACCEL := 1900.0
const AIR_DECEL := 1200.0
const GRAVITY_UP := 1500.0
const GRAVITY_DOWN := 2500.0
const GRAVITY_CUT := 3300.0
const MAX_FALL := 720.0
const JUMP_VELOCITY := 640.0
const DOUBLE_JUMP_VELOCITY := 560.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.13
const DASH_SPEED := 640.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 0.42
const ATTACK_COOLDOWN := 0.34
const ATTACK_COOLDOWN_QUICK := 0.22
const ATTACK_ACTIVE := Vector2(0.02, 0.13)   # start/end of the hit window (seconds)
const ATTACK_DURATION := 0.24
const ATTACK_BOX := Vector2(52, 38)
const INVULN_TIME := 1.1
const HURT_STUN := 0.22
const BODY := Vector2(16, 28)

enum State { NORMAL, DASH, HURT, FROZEN, DEAD }

var state := State.NORMAL
var hp := 5
var max_hp := 5
var facing := 1
var level: Level = null
var controls_enabled := true
var last_safe := Vector2.ZERO
var visual: PlayerVisual
var hurtbox: Area2D
var attack_t := -1.0          # time into the current swing, < 0 when not swinging
var attack_dir := 1
var invuln := 0.0

var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_held := false
var _air_jumps := 0
var _air_dash := true
var _dash_t := 0.0
var _dash_cd := 0.0
var _attack_cd := 0.0
var _swing_index := 0
var _hit_this_swing: Array = []
var _hurt_t := 0.0
var _was_on_floor := true
var _prev_vy := 0.0
var _respawning := false
var _query := PhysicsShapeQueryParameters2D.new()
var _glow: Sprite2D
var _step_t := 0.0


func _ready() -> void:
	collision_layer = Phys.PLAYER
	collision_mask = Phys.WORLD
	floor_snap_length = 6.0
	floor_constant_speed = true
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(BODY)
	add_child(cs)
	hurtbox = Phys.make_area(Vector2(12, 22), 0, Phys.HURT_PLAYER)
	add_child(hurtbox)
	_glow = FX.make_glow(Color(1.0, 0.62, 0.3, 0.5), 150.0)
	_glow.position = Vector2(0, -16)
	add_child(_glow)
	visual = PlayerVisual.new()
	visual.player = self
	add_child(visual)
	_query.shape = Phys.rect_shape(ATTACK_BOX)
	_query.collision_mask = Phys.HITTABLE
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	max_hp = Game.max_hp()
	hp = max_hp
	last_safe = global_position
	z_index = 20


func has_double_jump() -> bool:
	return Game.has_upgrade("double_jump")


func has_dash() -> bool:
	return Game.has_upgrade("dash")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		velocity.y = minf(velocity.y + GRAVITY_DOWN * delta, MAX_FALL)
		move_and_slide()
		return
	if state == State.FROZEN:
		return
	_tick(delta)
	var on_floor := is_on_floor()
	var ix := 0.0
	if controls_enabled:
		ix = Input.get_axis("move_left", "move_right")
		if absf(ix) < 0.2:
			ix = 0.0
	if on_floor:
		_coyote = COYOTE
		_air_jumps = 1 if has_double_jump() else 0
		_air_dash = true
	else:
		_coyote -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	if not Input.is_action_pressed("jump"):
		_jump_held = false

	match state:
		State.DASH:
			_dash_t -= delta
			velocity = Vector2(facing * DASH_SPEED, 0.0)
			if _dash_t <= 0.0 or is_on_wall():
				state = State.NORMAL
				velocity.x = facing * RUN_SPEED
		State.HURT:
			_hurt_t -= delta
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			velocity.y = minf(velocity.y + GRAVITY_DOWN * delta, MAX_FALL)
			if _hurt_t <= 0.0:
				state = State.NORMAL
		State.NORMAL:
			_move_normal(delta, ix, on_floor)
	_prev_vy = velocity.y
	move_and_slide()
	_after_move(delta)


func _tick(delta: float) -> void:
	_jump_buffer -= delta
	_dash_cd -= delta
	_attack_cd -= delta
	if invuln > 0.0:
		invuln -= delta


func _move_normal(delta: float, ix: float, on_floor: bool) -> void:
	var target := ix * RUN_SPEED
	var accel: float
	if on_floor:
		accel = GROUND_ACCEL if absf(target) > 1.0 else GROUND_DECEL
	else:
		accel = AIR_ACCEL if absf(target) > 1.0 else AIR_DECEL
	# turning around is snappier than speeding up
	if signf(target) != signf(velocity.x) and absf(target) > 1.0:
		accel *= 1.6
	velocity.x = move_toward(velocity.x, target, accel * delta)
	if ix != 0.0 and attack_t < 0.0:
		facing = 1 if ix > 0.0 else -1

	var g := GRAVITY_DOWN
	if velocity.y < 0.0:
		g = GRAVITY_UP if _jump_held else GRAVITY_CUT
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_do_jump(JUMP_VELOCITY, false)
		elif _air_jumps > 0:
			_air_jumps -= 1
			_do_jump(DOUBLE_JUMP_VELOCITY, true)

	if controls_enabled and Input.is_action_just_pressed("dash") and has_dash() and _dash_cd <= 0.0 and (on_floor or _air_dash):
		if ix != 0.0:
			facing = 1 if ix > 0.0 else -1
		state = State.DASH
		_dash_t = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		if not on_floor:
			_air_dash = false
		attack_t = -1.0
		visual.start_dash()
		Audio.play("dash")
		Game.vibrate(15)

	if controls_enabled and Input.is_action_pressed("attack") and _attack_cd <= 0.0 and state == State.NORMAL:
		_start_attack()


func _do_jump(v: float, double: bool) -> void:
	velocity.y = -v
	_jump_buffer = 0.0
	_coyote = 0.0
	_jump_held = true
	visual.squash = Vector2(0.75, 1.3)
	if double:
		Audio.play("djump")
		FX.burst(get_parent(), global_position + Vector2(0, 12), Color(1.0, 0.8, 0.5), 10, 120.0, 0.35, 100.0, 3.0, true)
	else:
		Audio.play("jump")
		FX.burst(get_parent(), global_position + Vector2(0, 14), Color(0.8, 0.75, 0.7, 0.6), 6, 70.0, 0.3, 50.0, 3.0)


func _start_attack() -> void:
	attack_t = 0.0
	attack_dir = facing
	_attack_cd = ATTACK_COOLDOWN_QUICK if Game.has_upgrade("quick_blade") else ATTACK_COOLDOWN
	_hit_this_swing.clear()
	_swing_index = (_swing_index + 1) % 2
	visual.start_swing(_swing_index)
	Audio.play("swing", 0.1)


func _after_move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _prev_vy > 250.0:
		visual.squash = Vector2(1.3, 0.75)
		Audio.play("land", 0.1, -6.0)
		FX.burst(get_parent(), global_position + Vector2(0, 14), Color(0.8, 0.75, 0.7, 0.5), 8, 90.0, 0.3, 80.0, 3.0)
	_was_on_floor = on_floor
	if on_floor and absf(velocity.x) > 60.0:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.3
	if on_floor and state == State.NORMAL and level != null and level.is_safe_ground(global_position + Vector2(0, BODY.y * 0.5)):
		last_safe = global_position

	if attack_t >= 0.0:
		attack_t += delta
		if attack_t >= ATTACK_ACTIVE.x and attack_t <= ATTACK_ACTIVE.y:
			_attack_query()
		if attack_t > ATTACK_DURATION:
			attack_t = -1.0

	_check_hurt()
	if level != null and global_position.y > level.pixel_size().y + 48.0:
		take_damage(1, global_position, true)
	_glow.modulate.a = 0.22 + 0.33 * float(hp) / float(maxi(max_hp, 1))


func _attack_query() -> void:
	var space := get_world_2d().direct_space_state
	_query.transform = Transform2D(0.0, global_position + Vector2(attack_dir * 28.0, -2.0))
	var results := space.intersect_shape(_query, 12)
	var connected := false
	for r in results:
		var a: Object = r["collider"]
		if a == null or _hit_this_swing.has(a):
			continue
		_hit_this_swing.append(a)
		if a is Hurtbox and (a as Hurtbox).hit(1, attack_dir, self):
			connected = true
			var hit_pos := (a as Node2D).global_position.lerp(global_position, 0.4)
			FX.burst(get_parent(), hit_pos, Color(1.0, 0.9, 0.6), 8, 220.0, 0.25, 0.0, 3.0, true)
	if connected:
		Game.hitstop(0.045)
		Game.vibrate(20)
		# small recoil away from what we struck
		if state == State.NORMAL:
			velocity.x = -attack_dir * 150.0


func _check_hurt() -> void:
	if _respawning:
		return
	for a in hurtbox.get_overlapping_areas():
		if a is DamageArea and (a as DamageArea).enabled:
			var da := a as DamageArea
			if da.hazard:
				take_damage(da.damage, da.global_position, true)
				return
			elif invuln <= 0.0:
				take_damage(da.damage, da.global_position, false)
				return


func take_damage(amount: int, source_pos: Vector2, hazard: bool = false) -> void:
	if state == State.DEAD or _respawning:
		return
	if hazard:
		if invuln <= 0.0:
			_apply_damage(amount)
		else:
			Audio.play("splash" if level != null and level.cell(floori(global_position.x / Phys.TILE), floori(global_position.y / Phys.TILE)) == Phys.CH_WATER else "hurt", 0.05, -4.0)
		if hp > 0:
			_hazard_respawn()
		return
	if invuln > 0.0:
		return
	_apply_damage(amount)
	if hp <= 0:
		return
	state = State.HURT
	_hurt_t = HURT_STUN
	attack_t = -1.0
	var dir := signf(global_position.x - source_pos.x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector2(dir * 260.0, -300.0)


func _apply_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	invuln = INVULN_TIME
	visual.flash()
	Audio.play("hurt", 0.05)
	Game.hitstop(0.09)
	FX.shake(self, 8.0, 0.3)
	Game.vibrate(70)
	if hp <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	attack_t = -1.0
	velocity = Vector2(0, -160)
	visual.start_death()
	Audio.play("death", 0.0)
	FX.burst(get_parent(), global_position + Vector2(0, -16), Color(0.6, 0.6, 0.65, 0.8), 18, 80.0, 1.2, -60.0, 5.0)
	await get_tree().create_timer(1.6).timeout
	died.emit()


func _hazard_respawn() -> void:
	_respawning = true
	state = State.FROZEN
	velocity = Vector2.ZERO
	attack_t = -1.0
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.18)
	await tw.finished
	await get_tree().create_timer(0.2).timeout
	global_position = last_safe
	velocity = Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("snap_to_target"):
		cam.snap_to_target()
	var tw2 := create_tween()
	tw2.tween_property(visual, "modulate:a", 1.0, 0.2)
	invuln = maxf(invuln, 0.9)
	state = State.NORMAL
	_respawning = false


func heal(n: int) -> void:
	if hp >= max_hp or state == State.DEAD:
		return
	hp = mini(hp + n, max_hp)
	hp_changed.emit(hp, max_hp)
	visual.heal_flash()
	Audio.play("heal", 0.05)


func full_heal() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)


func raise_max_hp() -> void:
	max_hp = Game.max_hp()
	hp = max_hp
	hp_changed.emit(hp, max_hp)


## Cutscenes, level exits and menus lock input this way.
func freeze(on: bool) -> void:
	controls_enabled = not on
	if on:
		attack_t = -1.0
