class_name LevelRunner
extends Node2D
## One play session of one level: builds the Level, spawns the player at the start or the
## last lit checkpoint, wires HUD/touch controls/pause, runs boss encounters and handles
## death (Game Over -> retry from checkpoint) and completion.

const UPGRADE_TEXT := {
	"dash": ["Ember Dash", "Tap DASH to burst forward - even in mid-air."],
	"double_jump": ["Twin Flame", "Press JUMP again in mid-air to jump a second time."],
	"quick_blade": ["Quickened Blade", "Your sword swings faster."],
}

var level_num := 1
var level: Level
var player: Player
var camera: GameCamera
var hud: HUD
var touch: TouchControls
var ui_layer: CanvasLayer
var menu_layer: CanvasLayer
var _overlay: Control = null
var _boss_started := false
var _finished := false
var _dead := false
var _ambient: CPUParticles2D
var _music := "calm"


func _ready() -> void:
	var info: Dictionary = Game.LEVELS[level_num - 1]
	var data := LevelData.load_file(String(info["file"]))
	if data == null:
		push_error("Could not load level %d" % level_num)
		Game.goto_menu.call_deferred()
		return
	level = Level.new()
	level.name = "Level"
	add_child(level)
	level.build(data, level_num)
	_music = data.get_meta_str("music", "calm")

	player = Player.new()
	player.level = level
	level.player = player
	var cp_id := String(Game.session.get("checkpoint", ""))
	if cp_id != "" and level.checkpoints.has(cp_id):
		player.position = (level.checkpoints[cp_id] as Checkpoint).position + Vector2(0, -15)
	else:
		player.position = level.player_start
	if Game.main != null and Game.main.args.has("at"):
		var at := String(Game.main.args["at"]).split(",")
		if at.size() == 2:
			player.position = Vector2(int(at[0]) * Phys.TILE + 16, (int(at[1]) + 1) * Phys.TILE - 15)
	level.add_child(player)

	camera = GameCamera.new()
	camera.target = player
	add_child(camera)
	camera.set_bounds(level.pixel_size())
	camera.snap_to_target()
	_build_ambient()
	_build_vignette()

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	touch = TouchControls.new()
	ui_layer.add_child(touch)
	hud = HUD.new()
	ui_layer.add_child(hud)
	hud.level_text = "%d  %s" % [level_num, String(info["name"])]
	hud.set_hp(player.hp, player.max_hp)
	hud.set_embers(int(Game.session.get("embers", 0)), level.ember_total)
	hud.pause_pressed.connect(pause)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)

	player.hp_changed.connect(hud.set_hp)
	player.died.connect(_on_player_died)
	level.pickup_collected.connect(_on_pickup)
	level.checkpoint_reached.connect(_on_checkpoint)
	level.exit_reached.connect(_complete)
	level.sign_changed.connect(hud.show_hint)

	if level.boss != null:
		if bool(Game.session.get("boss_dead", false)):
			level.boss.queue_free()
			level.boss = null
		else:
			level.boss.boss_hp_changed.connect(_on_boss_hp)
			level.boss.defeated.connect(_on_boss_defeated)
			if level.exit_gate != null:
				level.exit_gate.set_locked(true)

	Audio.play_music(_music)
	var first_time := cp_id == "" and int(Game.session.get("deaths", 0)) == 0
	if first_time:
		hud.banner(String(info["name"]), "Level %d" % level_num, 2.0)


func _build_ambient() -> void:
	var th := level.theme
	var style := String(th.get("particles", "dust"))
	var p := CPUParticles2D.new()
	p.amount = 36
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.texture = FX.dot_texture()
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(560, 320)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector2(0, 0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.4
	p.color_ramp = FX.fade_ramp()
	var acc: Color = th["accent"]
	match style:
		"embers":
			p.color = Color(1.0, 0.55, 0.25, 0.8)
			p.gravity = Vector2(0, -10)
			p.material = FX.add_material()
		"spores":
			p.color = Color(acc.r, acc.g, acc.b, 0.6)
			p.material = FX.add_material()
		"sparkle":
			p.color = Color(acc.r, acc.g, acc.b, 0.9)
			p.material = FX.add_material()
			p.scale_amount_max = 0.3
		"bubbles":
			p.color = Color(0.7, 0.95, 1.0, 0.35)
			p.gravity = Vector2(0, -14)
		"motes":
			p.color = Color(1.0, 0.95, 0.8, 0.8)
			p.gravity = Vector2(0, -6)
			p.material = FX.add_material()
		_:
			p.color = Color(0.85, 0.8, 0.75, 0.35)
	p.z_index = 35
	camera.add_child(p)
	_ambient = p


func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var tr := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.62)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 72
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.08, 0.5)
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)


func _physics_process(delta: float) -> void:
	if _finished or _dead or level == null:
		return
	Game.session["time"] = float(Game.session.get("time", 0.0)) + delta
	if level.boss != null and not _boss_started and not level.boss.dead:
		var a := level.arena
		var px := player.global_position.x
		if px > a.position.x + 3.0 * Phys.TILE and px < a.end.x - 3.0 * Phys.TILE and absf(player.global_position.y - level.boss.floor_y) < 7.0 * Phys.TILE and player.is_on_floor():
			_start_boss()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused and _overlay != null and _overlay.has_meta("pause_menu"):
			resume()
		elif not get_tree().paused:
			pause()


# ---------------------------------------------------------------- boss

func _start_boss() -> void:
	_boss_started = true
	for g in level.gates:
		(g as Platforms.BossGate).close()
	var b := level.boss
	hud.show_boss(b.boss_name, b.hp, b.max_hp)
	hud.banner(b.boss_name, "", 1.6)
	Audio.play_music("boss", 0.6)
	camera.frame_rect(level.arena)
	b.activate()


func _on_boss_hp(h: int, m: int) -> void:
	if level.boss != null and is_instance_valid(level.boss):
		hud.show_boss(level.boss.boss_name, h, m)


func _on_boss_defeated() -> void:
	Game.session["boss_dead"] = true
	hud.hide_boss()
	camera.frame_rect(Rect2())
	player.full_heal()
	# the boss frees itself after its death fade, so keep what we need now
	var boss_floor := level.boss.floor_y
	level.boss = null
	await get_tree().create_timer(1.4).timeout
	if _dead:
		return
	for g in level.gates:
		(g as Platforms.BossGate).open()
	if level.exit_gate != null:
		level.exit_gate.set_locked(false)
	var reward := level.data.get_meta_str("boss_reward", "")
	if reward == "heart":
		var hid := "L%d_boss" % level_num
		if not Game.has_heart(hid):
			var p := Pickup.new()
			p.kind = "heart"
			p.id = hid
			p.level = level
			p.position = Vector2(level.arena.get_center().x, boss_floor - 40.0)
			level.object_layer.add_child(p)
	if level_num == Game.LEVELS.size():
		_final_ending()
	else:
		Audio.play_music(_music)
		hud.banner("Victory", "The way forward is open.", 2.0)


func _final_ending() -> void:
	player.freeze(true)
	touch.release_all()
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.85, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(flash)
	Audio.play("upgrade", 0.0)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 1.0, 2.2)
	await tw.finished
	_complete()


# ---------------------------------------------------------------- pickups / checkpoints

func _on_pickup(p: Pickup) -> void:
	var collected: Dictionary = Game.session["collected"]
	match p.kind:
		"ember":
			collected[p.id] = true
			Game.session["embers"] = int(Game.session.get("embers", 0)) + 1
			hud.set_embers(int(Game.session["embers"]), level.ember_total)
			Audio.play("ember", 0.12, -4.0)
		"secret":
			collected[p.id] = true
			Game.record_secret(level_num)
			Audio.play("secret", 0.0)
			hud.banner("Memory Wick", level.data.get_meta_str("lore", "A faint memory flickers."), 3.2)
		"heart":
			if p.has_meta("cell_id"):
				collected[String(p.get_meta("cell_id"))] = true
			Game.collect_heart(p.id)
			player.raise_max_hp()
			Audio.play("upgrade", 0.0)
			hud.banner("Heart Wick", "Your flame grows stronger. +1 max health.", 2.6)
		"dash", "double_jump", "quick_blade":
			Game.grant_upgrade(p.kind)
			var tx: Array = UPGRADE_TEXT[p.kind]
			Audio.play("upgrade", 0.0)
			hud.banner(String(tx[0]), String(tx[1]), 3.4)
			touch.reload()
			FX.shake(self, 3.0, 0.3)
		"heal":
			player.heal(1)


func _on_checkpoint(cp: Checkpoint) -> void:
	var was := String(Game.session.get("checkpoint", ""))
	if not cp.lit:
		cp.light()
	if was != cp.id:
		Game.session["checkpoint"] = cp.id
		hud.banner("Checkpoint", "Your flame is restored.", 1.2)
	player.full_heal()


# ---------------------------------------------------------------- end states

func _complete() -> void:
	if _finished:
		return
	_finished = true
	player.freeze(true)
	touch.release_all()
	var up := level.data.get_meta_str("upgrade", "")
	if up != "":
		Game.grant_upgrade(up)
	var embers := int(Game.session.get("embers", 0))
	var time_sec := float(Game.session.get("time", 0.0))
	Game.complete_level(level_num, embers, level.ember_total, time_sec)
	if level_num == Game.LEVELS.size():
		Game.goto_victory()
		return
	Audio.play("complete", 0.0)
	await get_tree().create_timer(0.6).timeout
	var m := OverlayMenu.new()
	_show_overlay(m)
	m.add_title("Level Complete", 54)
	m.add_text(String(Game.LEVELS[level_num - 1]["name"]), 26, UIKit.DIM)
	m.add_space(6)
	m.add_text("Embers   %d / %d" % [embers, level.ember_total], 28)
	var secret := bool(Game.level_stats(level_num).get("secret", false))
	m.add_text("Memory Wick   %s" % ("found" if secret else "not found"), 28, UIKit.TEXT if secret else UIKit.DIM)
	m.add_text("Time   %s      Deaths   %d" % [UIKit.format_time(time_sec), int(Game.session.get("deaths", 0))], 24, UIKit.DIM)
	m.add_space(8)
	m.add_button("Continue", Game.start_level.bind(level_num + 1, true))
	m.add_button("Replay Level", Game.start_level.bind(level_num, true))
	m.add_button("Level Select", Game.goto_level_select)
	get_tree().paused = true


func _on_player_died() -> void:
	_dead = true
	touch.release_all()
	hud.hide_boss()
	Audio.stop_music(1.0)
	var m := OverlayMenu.new()
	_show_overlay(m)
	m.add_title("Your Flame Fades", 54)
	m.add_text("The last lantern you lit still remembers you.", 24, UIKit.DIM)
	m.add_space(10)
	m.add_button("Rekindle (Retry)", Game.retry_level)
	m.add_button("Level Select", Game.goto_level_select)
	m.add_button("Main Menu", Game.goto_menu)
	get_tree().paused = true


func pause() -> void:
	if _finished or _dead or get_tree().paused:
		return
	touch.release_all()
	get_tree().paused = true
	Audio.set_duck(true)
	var m := OverlayMenu.new()
	m.set_meta("pause_menu", true)
	_show_overlay(m)
	m.add_title("Paused", 56)
	m.add_text(hud.level_text, 22, UIKit.DIM)
	m.add_space(6)
	m.add_button("Resume", resume)
	m.add_button("Restart from Checkpoint", _restart_checkpoint)
	m.add_button("Settings", _open_settings)
	m.add_button("Level Select", _quit_to.bind("select"))
	m.add_button("Main Menu", _quit_to.bind("menu"))


func resume() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	Audio.set_duck(false)
	get_tree().paused = false


func _restart_checkpoint() -> void:
	Audio.set_duck(false)
	Game.start_level(level_num, false)


func _quit_to(where: String) -> void:
	Audio.set_duck(false)
	if where == "select":
		Game.goto_level_select()
	else:
		Game.goto_menu()


func _open_settings() -> void:
	var s := SettingsMenu.new()
	menu_layer.add_child(s)
	s.closed.connect(func() -> void:
		s.queue_free()
		touch.reload()
	)


func _show_overlay(m: Control) -> void:
	if _overlay != null:
		_overlay.queue_free()
	_overlay = m
	menu_layer.add_child(m)


func on_back() -> void:
	# Android back: close settings, else toggle pause
	for c in menu_layer.get_children():
		if c is SettingsMenu:
			(c as SettingsMenu).on_back()
			return
	if _overlay != null and _overlay.has_meta("pause_menu"):
		resume()
	elif _overlay == null:
		pause()


func on_app_paused() -> void:
	Game.save_progress()
	if not _finished and not _dead:
		pause()
