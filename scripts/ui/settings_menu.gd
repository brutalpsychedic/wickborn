class_name SettingsMenu
extends Control
## Settings overlay (usable from the title screen and the pause menu).
## Left column: sound and feedback. Right column: touch controls (scheme, joystick mode,
## jump side, size, opacity, joystick sensitivity/deadzone) and the layout editor.

signal closed

var _editor: LayoutEditor = null
var _confirm_reset := false
var _reset_btn: Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	add_child(UIKit.dimmer(0.8))
	var title := UIKit.title("Settings", 50)
	UIKit.place(title, Vector2(0.5, 0), Vector2(-300, 18), Vector2(600, 70))
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.place(scroll, Vector2(0.5, 0), Vector2(-620, 96), Vector2(1240, 520))
	add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)
	var left := _column(cols)
	var right := _column(cols)
	var s := Game.settings

	_header(left, "Sound")
	_slider(left, "Music", "music_volume", 0.0, 1.0)
	_slider(left, "Effects", "sfx_volume", 0.0, 1.0)
	_header(left, "Feedback")
	left.add_child(UIKit.cycle_button("Screen shake", [true, false], ["On", "Off"], s["screen_shake"], _apply_setting.bind("screen_shake"), 560))
	left.add_child(UIKit.cycle_button("Vibration", [true, false], ["On", "Off"], s["vibration"], _apply_setting.bind("vibration"), 560))
	left.add_child(UIKit.cycle_button("Show FPS", [false, true], ["Off", "On"], s["show_fps"], _apply_setting.bind("show_fps"), 560))
	_header(left, "Progress")
	_reset_btn = UIKit.button("Reset save data", _on_reset, 560)
	left.add_child(_reset_btn)

	_header(right, "Touch controls")
	right.add_child(UIKit.cycle_button("Show", ["auto", "on", "off"], ["Auto", "Always", "Never"], s["touch_controls"], _apply_setting.bind("touch_controls"), 560))
	right.add_child(UIKit.cycle_button("Movement", ["buttons", "joystick"], ["Left/Right buttons", "Joystick"], s["control_scheme"], _apply_setting.bind("control_scheme"), 560))
	right.add_child(UIKit.cycle_button("Joystick", ["fixed", "floating"], ["Fixed", "Floating"], s["joystick_mode"], _apply_setting.bind("joystick_mode"), 560))
	right.add_child(UIKit.cycle_button("Jump button", ["right", "left"], ["Right side", "Left side"], s["jump_side"], _set_jump_side, 560))
	_slider(right, "Button size", "button_scale", 0.7, 1.4)
	_slider(right, "Opacity", "button_opacity", 0.15, 0.9)
	_slider(right, "Stick sensitivity", "joystick_sensitivity", 0.3, 1.0, true)
	_slider(right, "Stick deadzone", "joystick_deadzone", 0.05, 0.45)
	right.add_child(UIKit.button("Edit control layout", _open_editor, 560))
	right.add_child(UIKit.button("Reset control layout", _reset_layout, 560))

	var back := UIKit.button("Back", _close, 280)
	UIKit.place(back, Vector2(0.5, 1), Vector2(-140, -84), Vector2(280, 62))
	add_child(back)
	UIKit.focus_first(left)


func _column(parent: Control) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(580, 0)
	parent.add_child(vb)
	return vb


func _header(parent: Control, text: String) -> void:
	var l := UIKit.label(text, 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	parent.add_child(l)


## `inverted`: the stored value means "fraction of the stick needed for full speed", so
## a higher slider position should feel *more* sensitive.
func _slider(parent: Control, caption: String, key: String, lo: float, hi: float, inverted: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UIKit.label(caption, 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.01
	sl.custom_minimum_size = Vector2(330, 48)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := float(Game.settings[key])
	sl.value = (hi + lo - v) if inverted else v
	sl.value_changed.connect(func(val: float) -> void:
		Game.settings[key] = (hi + lo - val) if inverted else val
		Game.preview_settings()
	)
	row.add_child(sl)
	parent.add_child(row)


func _apply_setting(value: Variant, key: String) -> void:
	Game.set_setting(key, value)


func _set_jump_side(value: Variant) -> void:
	Game.settings["jump_side"] = value
	Game.settings["layout"] = {}
	Game.save_settings()


func _reset_layout() -> void:
	Game.settings["layout"] = {}
	Game.save_settings()


func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = "Tap again to erase all progress"
		return
	Game.reset_progress()
	_reset_btn.text = "Progress erased"
	_reset_btn.disabled = true


func _open_editor() -> void:
	_editor = LayoutEditor.new()
	_editor.closed.connect(func() -> void:
		_editor.queue_free()
		_editor = null
	)
	add_child(_editor)


func _close() -> void:
	Game.save_settings()
	closed.emit()


func on_back() -> void:
	if _editor != null:
		_editor.on_back()
	else:
		_close()
