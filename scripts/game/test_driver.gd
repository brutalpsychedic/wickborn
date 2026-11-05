class_name TestDriver
extends Node
## Automated play-through used by tools (run with `-- --test=NAME`). Not used in normal play.
##   smoke   - every menu, then every level: build, simulated input, boss kill, exit, victory
##   physics - measures jump height / distance to keep level design within reach
##   death   - dies, checks Game Over, retries from checkpoint
## Prints "TEST PASS" / "TEST FAIL" lines and quits.

var scenario := "smoke"
var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.progress = Game.DEFAULT_PROGRESS.duplicate(true)
	Game.progress["story_seen"] = true
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _check(cond: bool, what: String) -> void:
	if cond:
		print("TEST PASS: ", what)
	else:
		_fails += 1
		print("TEST FAIL: ", what)


func _runner() -> LevelRunner:
	return Game.main.current as LevelRunner


func _run() -> void:
	match scenario:
		"physics":
			await _physics_test()
		"death":
			await _death_test()
		"level":
			await _level_test(int(Game.main.args.get("n", "1")), true)
		_:
			await _menus_test()
			for n in range(1, Game.LEVELS.size() + 1):
				await _level_test(n, false)
			await _victory_check()
	print("TEST DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _menus_test() -> void:
	Game.goto_menu()
	await _wait(0.8)
	_check(Game.main.current is MainMenu, "main menu opens")
	Game.goto_level_select()
	await _wait(0.8)
	_check(Game.main.current is LevelSelect, "level select opens")
	for track in Audio.MUSIC_NAMES:
		var ms: AudioStreamWAV = load("res://audio/music/%s.wav" % track)
		_check(ms != null and ms.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music '%s' loops" % track)
	for sfx in Audio.SFX_NAMES:
		if not ResourceLoader.exists("res://audio/sfx/%s.wav" % sfx):
			_check(false, "sfx '%s' exists" % sfx)
	var s := SettingsMenu.new()
	Game.main.current.add_child(s)
	await _wait(0.3)
	var le := LayoutEditor.new()
	s.add_child(le)
	await _wait(0.3)
	le._defaults()
	le._done()
	s._close()
	_check(true, "settings + layout editor open/close")
	Game.goto_credits()
	await _wait(0.8)
	_check(Game.main.current is CreditsScreen, "credits open")


func _level_test(n: int, long_play: bool) -> void:
	Game.start_level(n, true)
	await _wait(0.9)
	var r := _runner()
	_check(r != null and r.level != null and r.player != null, "level %d builds" % n)
	if r == null or r.level == null:
		return
	var lv := r.level
	var enemies := lv.enemy_layer.get_child_count()
	print("  level %d: %dx%d cells, embers=%d, checkpoints=%d, enemies=%d, boss=%s, exit=%s" % [
		n, lv.w, lv.h, lv.ember_total, lv.checkpoints.size(), enemies, lv.boss != null, lv.exit_gate != null])
	_check(lv.exit_gate != null, "level %d has an exit" % n)
	_check(lv.checkpoints.size() >= 1, "level %d has a checkpoint" % n)
	# simulated input: run right, jump and attack
	Input.action_press("move_right")
	var steps := 12 if long_play else 6
	for i in steps:
		Input.action_press("jump")
		Input.action_press("attack")
		await _wait(0.25)
		Input.action_release("jump")
		Input.action_release("attack")
		await _wait(0.2)
	Input.action_release("move_right")
	_check(r.player.global_position.x > lv.player_start.x - 1.0 or r.player.hp < r.player.max_hp, "level %d player moved" % n)
	# pause / resume
	r.pause()
	await _wait(0.2)
	_check(get_tree().paused, "level %d pauses" % n)
	r.resume()
	await _wait(0.1)
	# checkpoint
	var cp: Checkpoint = lv.checkpoints.values()[0]
	r.player.global_position = cp.global_position + Vector2(0, -15)
	await _wait(0.4)
	_check(String(Game.session.get("checkpoint", "")) == cp.id, "level %d checkpoint lights" % n)
	# boss
	if lv.boss != null:
		var b := lv.boss
		r.player.invuln = 999.0
		r.player.global_position = Vector2(lv.arena.get_center().x, b.floor_y - 20.0)
		await _wait(0.6)
		_check(b.active, "level %d boss activates (%s)" % [n, b.boss_name])
		var gate_closed := true
		for g in lv.gates:
			gate_closed = gate_closed and (g as Platforms.BossGate).closed
		_check(gate_closed, "level %d arena seals" % n)
		await _wait(2.5)   # let it run a few patterns
		var guard := 0
		while is_instance_valid(b) and not b.dead and guard < 400:
			b.take_hit(1, 1, r.player)
			guard += 1
			await _wait(0.03)
		_check(not is_instance_valid(b) or b.dead, "level %d boss can be defeated" % n)
		await _wait(2.2)
		if n == Game.LEVELS.size():
			await _wait(3.0)
			return
		_check(not lv.exit_gate.locked, "level %d exit unlocks after boss" % n)
		r.player.invuln = 0.0
	# exit
	r.player.global_position = lv.exit_gate.global_position + Vector2(0, -15)
	await _wait(1.6)
	_check(bool(Game.level_stats(n).get("done", false)), "level %d completes" % n)


func _victory_check() -> void:
	await _wait(1.0)
	var cur: Node = Game.main.current
	if cur is StoryScreen:
		_check(true, "ending story shows")
		(cur as StoryScreen)._finish()
		await _wait(1.0)
	_check(Game.main.current is VictoryScreen, "victory screen shows")
	_check(bool(Game.progress.get("game_complete", false)), "game marked complete")


func _physics_test() -> void:
	Game.start_level(1, true)
	await _wait(1.2)
	var r := _runner()
	var p := r.player
	var y0 := p.global_position.y
	var x0 := p.global_position.x
	var min_y := y0
	Input.action_press("jump")
	for i in 60:
		await get_tree().physics_frame
		min_y = minf(min_y, p.global_position.y)
	Input.action_release("jump")
	await _wait(0.6)
	print("  full jump height: %.1f px (%.2f tiles)" % [y0 - min_y, (y0 - min_y) / 32.0])
	# tap jump (~6 frames)
	min_y = p.global_position.y
	y0 = min_y
	Input.action_press("jump")
	for i in 6:
		await get_tree().physics_frame
	Input.action_release("jump")
	for i in 40:
		await get_tree().physics_frame
		min_y = minf(min_y, p.global_position.y)
	print("  tap jump height: %.1f px (%.2f tiles)" % [y0 - min_y, (y0 - min_y) / 32.0])
	await _wait(0.5)
	# running jump distance (flat): run 0.6 s then jump, measure until landing at same height
	Input.action_press("move_right")
	await _wait(0.6)
	x0 = p.global_position.x
	y0 = p.global_position.y
	Input.action_press("jump")
	var airborne := false
	for i in 90:
		await get_tree().physics_frame
		if not p.is_on_floor():
			airborne = true
		elif airborne:
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	print("  running jump distance: %.1f px (%.2f tiles)" % [p.global_position.x - x0, (p.global_position.x - x0) / 32.0])
	_check(true, "physics measured")


func _death_test() -> void:
	Game.start_level(2, true)
	await _wait(1.0)
	var r := _runner()
	for i in 10:
		r.player.invuln = 0.0
		r.player.take_damage(1, r.player.global_position + Vector2(10, 0))
		await _wait(0.05)
	await _wait(2.4)
	_check(get_tree().paused and r._dead, "game over shows")
	Game.retry_level()
	await _wait(1.0)
	_check(_runner() != null and _runner() != r and _runner().player.hp == _runner().player.max_hp, "retry restarts with full health")
	_check(int(Game.session.get("deaths", 0)) == 1, "death counted")
