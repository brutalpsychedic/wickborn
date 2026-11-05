extends Node
## Root scene. Swaps full-screen "screens" (menus, the level runner) with a fade.
## Command-line options (after `--`) let tools jump straight into content:
##   --level=N        start level N        --at=CX,CY   spawn the player at a map cell
##   --screen=NAME    open a screen (menu, select, settings, credits, story, victory)
##   --unlock-all     unlock every level and upgrade (testing)
##   --test=NAME      run an automated test scenario (see TestDriver)

var current: Node = null
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false
var _queued: Node = null
var args: Dictionary = {}


func _ready() -> void:
	Game.main = self
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 120
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.015, 0.03, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	get_tree().root.go_back_requested.connect(_on_back)

	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var parts := s.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"

	if args.has("unlock-all"):
		Game.progress["unlocked"] = Game.LEVELS.size()
		for u in Game.progress["upgrades"]:
			Game.progress["upgrades"][u] = true
		Game.progress["story_seen"] = true
	if args.has("touch"):
		Game.settings["touch_controls"] = "on"   # show on-screen controls on desktop (not saved)
	if args.has("test"):
		Game.test_mode = String(args["test"])
		var drv := TestDriver.new()
		drv.scenario = Game.test_mode
		add_child(drv)
		return
	if args.has("level"):
		Game.start_level(int(args["level"]))
	elif args.has("screen"):
		_open_named(String(args["screen"]))
	else:
		Game.goto_menu()


func _open_named(screen_name: String) -> void:
	match screen_name:
		"select":
			Game.goto_level_select()
		"settings":
			var s := SettingsMenu.new()
			s.closed.connect(Game.goto_menu)
			show_screen(s)
		"credits":
			Game.goto_credits()
		"story":
			var st := StoryScreen.new()
			st.pages = StoryScreen.INTRO
			st.finished.connect(Game.goto_menu)
			show_screen(st)
		"victory":
			show_screen(VictoryScreen.new())
		_:
			Game.goto_menu()


## Replace the current screen. Fades out, swaps, fades in. Safe to call while paused.
func show_screen(node: Node, fade_time: float = 0.25) -> void:
	if _busy:
		if _queued != null:
			_queued.queue_free()
		_queued = node
		return
	_busy = true
	if current != null:
		var tw := _fade_layer.create_tween()
		tw.tween_property(_fade, "color:a", 1.0, fade_time)
		await tw.finished
		current.queue_free()
		current = null
	else:
		_fade.color.a = 1.0
	get_tree().paused = false
	Engine.time_scale = 1.0
	add_child(node)
	move_child(_fade_layer, -1)
	current = node
	var tw2 := _fade_layer.create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, fade_time)
	await tw2.finished
	_busy = false
	if _queued != null:
		var q := _queued
		_queued = null
		show_screen(q, fade_time)


func _on_back() -> void:
	# Android back button / gesture: let the current screen decide.
	if current != null and current.has_method("on_back"):
		current.on_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Recording frames (Movie Maker) runs unfocused; don't auto-pause then.
		if "--write-movie" in OS.get_cmdline_args():
			return
		if current != null and current.has_method("on_app_paused"):
			current.on_app_paused()
