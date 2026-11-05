class_name Enemy
extends CharacterBody2D
## Base enemy: health, hit flash, knockback, contact damage, death burst, heal drops,
## grid-based senses (edges, walls, line of sight) and off-screen sleeping.
## Subclasses override setup(), ai(delta) and draw_body().

const BODY_DARK := Color("#1b1722")
const RIM := Color("#4d4160")

var level: Level = null
var max_hp := 2
var hp := 2
var body_size := Vector2(24, 18)
var flying := false
var facing := -1
var contact_damage := 1
var gravity := 1800.0
var knock_resist := 1.0
var heal_drop_chance := 0.22
var eye_color := Color("#ffb347")
var dead := false
var flash := 0.0
var t := 0.0
var st := "idle"
var st_t := 0.0
var knock := Vector2.ZERO
var knock_t := 0.0
var contact: DamageArea
var hurtbox: Hurtbox
var _death_t := 0.0
var _use_enabler := true


func setup() -> void:
	pass


func ai(_delta: float) -> void:
	pass


func draw_body() -> void:
	pass


func _ready() -> void:
	setup()
	hp = max_hp
	collision_layer = Phys.ENEMY
	collision_mask = Phys.WORLD
	floor_snap_length = 4.0
	var cs := CollisionShape2D.new()
	cs.shape = Phys.rect_shape(body_size)
	add_child(cs)
	contact = DamageArea.create(body_size * 0.8, contact_damage)
	add_child(contact)
	hurtbox = Hurtbox.create(self, body_size + Vector2(10, 10))
	add_child(hurtbox)
	if _use_enabler:
		# Sleep (no AI, physics or redraw) while well off-screen.
		var en := VisibleOnScreenEnabler2D.new()
		en.rect = Rect2(-760, -480, 1520, 960)
		add_child(en)
	t = randf() * 10.0
	z_index = 10
	if level != null and level.player != null:
		facing = 1 if level.player.global_position.x > global_position.x else -1


func _physics_process(delta: float) -> void:
	t += delta
	flash -= delta
	if dead:
		_death_t += delta
		queue_redraw()
		return
	ai(delta)
	if knock_t > 0.0:
		knock_t -= delta
		velocity.x = knock.x
		if flying:
			velocity.y = knock.y
		knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	if not flying:
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()
	queue_redraw()


func take_hit(dmg: int, dir: int, _attacker: Node) -> bool:
	if dead:
		return false
	hp -= dmg
	flash = 0.12
	knock = Vector2(dir * 270.0 * knock_resist, (-40.0 if flying else -90.0) * knock_resist)
	knock_t = 0.14 if knock_resist > 0.05 else 0.0
	if not flying and knock_resist > 0.05:
		velocity.y = knock.y
	Audio.play("hit", 0.08)
	on_hit(dir)
	if hp <= 0:
		die(dir)
	return true


func on_hit(_dir: int) -> void:
	pass


func die(dir: int) -> void:
	dead = true
	contact.enabled = false
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	Audio.play("enemy_die", 0.08)
	FX.burst(get_parent(), global_position, eye_color, 16, 200.0, 0.55, 200.0, 4.0, true)
	FX.burst(get_parent(), global_position, Color(0.1, 0.08, 0.12, 0.9), 12, 120.0, 0.7, -30.0, 6.0)
	if level != null and randf() < heal_drop_chance:
		level.spawn_heal(global_position + Vector2(0, -8))
	velocity = Vector2(dir * 120.0, -120.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- senses

func player() -> Player:
	if level == null or level.player == null or level.player.state == Player.State.DEAD:
		return null
	return level.player


func to_player() -> Vector2:
	var p := player()
	return p.global_position - global_position if p != null else Vector2(99999, 99999)


func can_see_player(range_x: float, range_y: float) -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position - global_position
	if absf(d.x) > range_x or absf(d.y) > range_y:
		return false
	return level.line_of_sight(global_position + Vector2(0, -4), p.global_position + Vector2(0, -6))


func face_player() -> void:
	var d := to_player()
	if absf(d.x) > 4.0:
		facing = 1 if d.x > 0.0 else -1


func ground_ahead(dir: int) -> bool:
	var p := global_position + Vector2(dir * (body_size.x * 0.5 + 4.0), body_size.y * 0.5 + 6.0)
	var cx := floori(p.x / Phys.TILE)
	var cy := floori(p.y / Phys.TILE)
	return level.standable(cx, cy) and not level.is_hazard_cell(cx, cy - 1)


func wall_ahead(dir: int) -> bool:
	return level.blocks_at(global_position + Vector2(dir * (body_size.x * 0.5 + 3.0), 0.0)) or is_on_wall()


func patrol(speed: float) -> void:
	if is_on_floor() and (not ground_ahead(facing) or wall_ahead(facing)):
		facing = -facing
	velocity.x = facing * speed


## Move toward the player but never off a ledge or into a hazard.
func approach(speed: float) -> void:
	face_player()
	if is_on_floor() and (not ground_ahead(facing) or wall_ahead(facing)):
		velocity.x = 0.0
	else:
		velocity.x = facing * speed


func goto_state(s: String, dur: float) -> void:
	st = s
	st_t = dur


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var f := float(facing)
	var sc := Vector2(f, 1.0)
	if dead:
		var k := clampf(_death_t / 0.4, 0.0, 1.0)
		sc = Vector2(f * (1.0 + k * 0.4), 1.0 - k * 0.6)
	draw_set_transform(Vector2.ZERO, 0.0, sc)
	draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func body_color() -> Color:
	return Color(1, 1, 1) if flash > 0.0 else BODY_DARK


func rim_color() -> Color:
	return Color(1, 1, 1) if flash > 0.0 else RIM


func ellipse(c: Vector2, rx: float, ry: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func glow_eye(c: Vector2, r: float, col: Color = Color(0, 0, 0, 0)) -> void:
	var ec := eye_color if col.a == 0.0 else col
	draw_circle(c, r * 2.2, Color(ec.r, ec.g, ec.b, 0.25))
	draw_circle(c, r, ec)
	draw_circle(c + Vector2(r * 0.25, -r * 0.25), r * 0.4, Color(1, 1, 0.9))
