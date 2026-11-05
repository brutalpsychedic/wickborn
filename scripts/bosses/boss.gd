class_name Boss
extends Enemy
## Boss base: dormant until the arena seals, a health bar, phase 2 under half health,
## and a pattern picker that avoids repeating the same attack too often.

signal boss_hp_changed(hp: int, max_hp: int)
signal defeated

var boss_name := "Boss"
var active := false
var arena := Rect2()
var home := Vector2.ZERO
var phase := 1
var patterns: Array[String] = []
var _last_pattern := ""
var floor_y := 0.0


static func create(kind: String) -> Boss:
	match kind:
		"warden":
			return Warden.new()
		"king":
			return AshenKing.new()
		"dimming":
			return Dimming.new()
	push_warning("Unknown boss kind '%s'" % kind)
	return null


func _ready() -> void:
	_use_enabler = false
	knock_resist = 0.0
	heal_drop_chance = 0.0
	super._ready()
	floor_y = home.y + body_size.y * 0.5
	st = "dormant"


func activate() -> void:
	if active:
		return
	active = true
	Audio.play("roar", 0.0)
	FX.shake(self, 6.0, 0.5)
	boss_hp_changed.emit(hp, max_hp)
	goto_state("intro", 1.0)


func pick_pattern() -> String:
	var options := patterns.duplicate()
	if options.size() > 1:
		options.erase(_last_pattern)
	var p: String = options[randi() % options.size()]
	_last_pattern = p
	return p


func take_hit(dmg: int, dir: int, attacker: Node) -> bool:
	if not active or dead:
		return false
	hp -= dmg
	flash = 0.1
	Audio.play("hit", 0.08)
	boss_hp_changed.emit(maxi(hp, 0), max_hp)
	if phase == 1 and hp <= max_hp / 2:
		phase = 2
		on_phase2()
	if hp <= 0:
		_boss_die()
	return true


func on_phase2() -> void:
	Audio.play("roar", 0.05)
	FX.shake(self, 5.0, 0.4)


func _boss_die() -> void:
	dead = true
	active = false
	contact.enabled = false
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	velocity = Vector2.ZERO
	Audio.play("boss_die", 0.0)
	Game.hitstop(0.25)
	FX.shake(self, 10.0, 0.8)
	for i in 4:
		FX.burst(get_parent(), global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), eye_color, 20, 260.0, 0.9, 100.0, 5.0, true)
	defeated.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	tw.tween_callback(queue_free)


## Keep inside the arena horizontally.
func clamp_to_arena(margin: float = 24.0) -> void:
	if arena.size.x <= 0.0:
		return
	var lo := arena.position.x + margin + body_size.x * 0.5
	var hi := arena.end.x - margin - body_size.x * 0.5
	if global_position.x < lo:
		global_position.x = lo
		velocity.x = maxf(velocity.x, 0.0)
	elif global_position.x > hi:
		global_position.x = hi
		velocity.x = minf(velocity.x, 0.0)


func at_arena_wall(dir: int, margin: float = 30.0) -> bool:
	if dir > 0:
		return global_position.x >= arena.end.x - margin - body_size.x * 0.5
	return global_position.x <= arena.position.x + margin + body_size.x * 0.5


func spawn_shockwave(x: float, dir: int, spd: float = 270.0) -> void:
	var sw := Shockwave.new()
	sw.level = level
	sw.dir = dir
	sw.speed = spd
	sw.color = eye_color
	sw.position = Vector2(x, floor_y - 11.0)
	level.enemy_layer.add_child(sw)


func spawn_orb(pos: Vector2, vel: Vector2, col: Color, grav: float = 0.0, r: float = 7.0) -> void:
	var pr := Projectile.new()
	pr.level = level
	pr.velocity = vel
	pr.color = col
	pr.gravity_y = grav
	pr.radius = r
	pr.life = 6.0
	pr.position = pos
	level.enemy_layer.add_child(pr)


## Telegraph: a pulsing glow on the floor, then a column of damaging thorns.
class Eruption extends Node2D:
	var level: Level = null
	var delay := 0.55
	var up_time := 0.45
	var color := Color(1, 0.6, 0.3)
	var height := 64.0
	var _t := 0.0
	var _dmg: DamageArea

	func _ready() -> void:
		z_index = 14
		_dmg = DamageArea.create(Vector2(22, height - 8), 1, false, Vector2(0, -height * 0.5))
		_dmg.enabled = false
		add_child(_dmg)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= delay and not _dmg.enabled and _t < delay + up_time:
			_dmg.enabled = true
			Audio.play("break", 0.15, -10.0)
		if _t >= delay + up_time:
			_dmg.enabled = false
		if _t >= delay + up_time + 0.25:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if _t < delay:
			var k := _t / delay
			draw_rect(Rect2(-14, -4, 28, 4), Color(color.r, color.g, color.b, 0.3 + 0.5 * k))
			draw_circle(Vector2(0, -2), 6.0 + 8.0 * k, Color(color.r, color.g, color.b, 0.15 + 0.2 * k))
		else:
			var rise := clampf((_t - delay) / 0.08, 0.0, 1.0)
			var fall := clampf((_t - delay - up_time) / 0.25, 0.0, 1.0)
			var hh := height * rise * (1.0 - fall)
			draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(-3, -hh), Vector2(0, -hh - 6), Vector2(4, -hh * 0.8), Vector2(11, 0)]), color.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(0, -hh), Vector2(5, 0)]), Color(1, 0.95, 0.85, 0.9))


## Floor marker before something falls from above.
class Marker extends Node2D:
	var life := 0.8
	var color := Color(0.8, 0.5, 1.0)
	var _t := 0.0

	func _ready() -> void:
		z_index = 13

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		draw_arc(Vector2.ZERO, 18.0 - 10.0 * k, 0.0, TAU, 20, Color(color.r, color.g, color.b, 0.4 + 0.5 * k), 2.5)
		draw_rect(Rect2(-12, -3, 24, 3), Color(color.r, color.g, color.b, 0.5 * k))
