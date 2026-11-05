extends Node
## Global game state (autoload "Game").
## Owns: input map, settings, save/progress, the current level session, and screen flow.

signal settings_changed
signal progress_changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_VERSION := 1
const BASE_MAX_HP := 5

const LEVELS: Array[Dictionary] = [
	{"name": "The Forgotten Path", "file": "res://levels/level_01.txt"},
	{"name": "Mossy Caverns", "file": "res://levels/level_02.txt"},
	{"name": "The Abandoned Village", "file": "res://levels/level_03.txt"},
	{"name": "Whispering Woods", "file": "res://levels/level_04.txt"},
	{"name": "Crystal Depths", "file": "res://levels/level_05.txt"},
	{"name": "The Sunken Passage", "file": "res://levels/level_06.txt"},
	{"name": "The Shadowed Ruins", "file": "res://levels/level_07.txt"},
	{"name": "The Hollow Fortress", "file": "res://levels/level_08.txt"},
	{"name": "The Forgotten Throne", "file": "res://levels/level_09.txt"},
	{"name": "The Last Sanctuary", "file": "res://levels/level_10.txt"},
]

const DEFAULT_SETTINGS := {
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"control_scheme": "buttons",     # "buttons" | "joystick"
	"joystick_mode": "fixed",        # "fixed" | "floating"
	"jump_side": "right",            # "right" | "left"  (layout preset)
	"button_scale": 1.0,
	"button_opacity": 0.5,
	"joystick_deadzone": 0.2,
	"joystick_sensitivity": 0.6,     # fraction of the stick radius needed for full speed
	"touch_controls": "auto",        # "auto" | "on" | "off"
	"screen_shake": true,
	"vibration": true,
	"show_fps": false,
	"layout": {},                    # control id -> [anchor_right(0/1), dx, dy]
}

const DEFAULT_PROGRESS := {
	"version": SAVE_VERSION,
	"unlocked": 1,
	"levels": {},                    # "n" -> {done, embers, embers_total, secret, best_time}
	"upgrades": {"dash": false, "double_jump": false, "quick_blade": false},
	"hearts": [],                    # ids of collected heart wicks
	"story_seen": false,
	"game_complete": false,
}

var settings: Dictionary = {}
var progress: Dictionary = {}
## Per-attempt state for the level being played. Survives death/retry, reset on a fresh start.
var session: Dictionary = {}
var main: Node = null
## Set by command-line test modes so tools can drive the game.
var test_mode := ""

var _hitstop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	load_progress()


# ---------------------------------------------------------------- input map

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("jump", [KEY_SPACE, KEY_Z, KEY_K], [JOY_BUTTON_A], -1, 0.0)
	_add_action("attack", [KEY_X, KEY_J], [JOY_BUTTON_X], -1, 0.0)
	_add_action("dash", [KEY_C, KEY_L, KEY_SHIFT], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], -1, 0.0)


func _add_action(action: String, keys: Array, buttons: Array, axis: int, axis_dir: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_dir
		InputMap.action_add_event(action, jm)


# ---------------------------------------------------------------- settings

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	var loaded: Variant = _read_json(SETTINGS_PATH)
	if loaded is Dictionary:
		for k in loaded:
			if settings.has(k):
				settings[k] = loaded[k]
	_apply_settings()


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)
	_apply_settings()
	settings_changed.emit()


## Apply settings live (e.g. while a slider is dragged) without writing to disk.
func preview_settings() -> void:
	_apply_settings()
	settings_changed.emit()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()


func _apply_settings() -> void:
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_volumes()


func touch_controls_visible() -> bool:
	match String(settings.get("touch_controls", "auto")):
		"on":
			return true
		"off":
			return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


# ---------------------------------------------------------------- progress

func load_progress() -> void:
	progress = DEFAULT_PROGRESS.duplicate(true)
	var loaded: Variant = _read_json(SAVE_PATH)
	if loaded is Dictionary:
		for k in loaded:
			progress[k] = loaded[k]
		# make sure nested defaults exist after upgrades of the save format
		for u in DEFAULT_PROGRESS["upgrades"]:
			if not progress["upgrades"].has(u):
				progress["upgrades"][u] = false
	progress["unlocked"] = clampi(int(progress.get("unlocked", 1)), 1, LEVELS.size())


func save_progress() -> void:
	_write_json(SAVE_PATH, progress)
	progress_changed.emit()


func reset_progress() -> void:
	progress = DEFAULT_PROGRESS.duplicate(true)
	save_progress()


func is_unlocked(n: int) -> bool:
	return n <= int(progress["unlocked"])


func level_stats(n: int) -> Dictionary:
	return progress["levels"].get(str(n), {})


func has_upgrade(id: String) -> bool:
	return bool(progress["upgrades"].get(id, false))


func grant_upgrade(id: String) -> void:
	if not has_upgrade(id):
		progress["upgrades"][id] = true
		save_progress()


func max_hp() -> int:
	return BASE_MAX_HP + (progress["hearts"] as Array).size()


func has_heart(id: String) -> bool:
	return (progress["hearts"] as Array).has(id)


func collect_heart(id: String) -> void:
	if not has_heart(id):
		(progress["hearts"] as Array).append(id)
		save_progress()


func total_secrets() -> int:
	var n := 0
	for k in progress["levels"]:
		if bool(progress["levels"][k].get("secret", false)):
			n += 1
	return n


func total_embers() -> int:
	var n := 0
	for k in progress["levels"]:
		n += int(progress["levels"][k].get("embers", 0))
	return n


func record_secret(n: int) -> void:
	var key := str(n)
	var st: Dictionary = progress["levels"].get(key, {})
	st["secret"] = true
	progress["levels"][key] = st
	save_progress()


func complete_level(n: int, embers: int, embers_total: int, time_sec: float) -> void:
	var key := str(n)
	var st: Dictionary = progress["levels"].get(key, {})
	st["done"] = true
	st["embers"] = maxi(int(st.get("embers", 0)), embers)
	st["embers_total"] = embers_total
	var best := float(st.get("best_time", 0.0))
	st["best_time"] = time_sec if best <= 0.0 else minf(best, time_sec)
	progress["levels"][key] = st
	if n < LEVELS.size():
		progress["unlocked"] = maxi(int(progress["unlocked"]), n + 1)
	else:
		progress["game_complete"] = true
	save_progress()


func first_unfinished_level() -> int:
	for i in range(1, LEVELS.size() + 1):
		if not bool(level_stats(i).get("done", false)):
			return mini(i, int(progress["unlocked"]))
	return int(progress["unlocked"])


# ---------------------------------------------------------------- json io

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		# a crash during an atomic save can leave only the temp file behind
		if FileAccess.file_exists(path + ".tmp"):
			path = path + ".tmp"
		else:
			return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	return JSON.parse_string(txt)


func _write_json(path: String, data: Variant) -> void:
	# Write to a temp file, then swap it in, so a killed app never leaves a half-written save.
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	dir.rename(tmp.get_file(), path.get_file())


# ---------------------------------------------------------------- screen flow

func goto_menu() -> void:
	main.show_screen(MainMenu.new())


func goto_level_select() -> void:
	main.show_screen(LevelSelect.new())


func goto_credits() -> void:
	main.show_screen(CreditsScreen.new())


func play_from_menu() -> void:
	if not bool(progress.get("story_seen", false)):
		progress["story_seen"] = true
		save_progress()
		var story := StoryScreen.new()
		story.pages = StoryScreen.INTRO
		story.finished.connect(start_level.bind(1, true))
		main.show_screen(story)
	else:
		start_level(first_unfinished_level(), true)


func start_level(n: int, fresh: bool = true) -> void:
	if fresh or session.is_empty() or int(session.get("level", 0)) != n:
		session = {
			"level": n, "checkpoint": "", "collected": {}, "embers": 0,
			"time": 0.0, "deaths": 0, "boss_dead": false,
		}
	var runner := LevelRunner.new()
	runner.level_num = n
	main.show_screen(runner)


func retry_level() -> void:
	session["deaths"] = int(session.get("deaths", 0)) + 1
	start_level(int(session["level"]), false)


func goto_victory() -> void:
	var story := StoryScreen.new()
	story.pages = StoryScreen.ENDING
	story.finished.connect(func() -> void: main.show_screen(VictoryScreen.new()))
	main.show_screen(story)


# ---------------------------------------------------------------- juice helpers

## Brief global slow-down on impactful hits. Real-time based so it never sticks.
func hitstop(duration: float) -> void:
	if get_tree().paused:
		return
	Engine.time_scale = 0.05
	_hitstop_until = Time.get_ticks_msec() + int(duration * 1000.0)
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	if Time.get_ticks_msec() >= _hitstop_until - 5:
		Engine.time_scale = 1.0


func vibrate(ms: int) -> void:
	if bool(settings.get("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
