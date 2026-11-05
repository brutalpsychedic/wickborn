class_name StoryScreen
extends Control
## Short story cards (intro and ending). Tap / press to advance, Skip to jump ahead.

signal finished

const INTRO := [
	"Long ago, the Sanctuary Flame lit every hollow of Cindral.",
	"Then came the Dimming - a hunger for light that crept up from below.\nOne by one, the lanterns of the kingdom went out.",
	"In a forgotten corner, the last spark fell onto a stub of wax.\nAnd a small wick woke up.",
	"Find the Last Sanctuary.\nKeep your flame alive.",
]

const ENDING := [
	"The Dimming unravels into a thousand drifting cinders.",
	"It was never a monster. It was the grief of the Flame's last keeper,\nwho could not bear to watch the light grow old.",
	"Wick climbs the cold altar and gives the Sanctuary its flame.\nThe hollows of Cindral glow again, one lantern at a time.",
	"Somewhere below, a new spark settles onto wax...",
]

var pages: Array = []
var _i := -1
var _label: Label
var _hint: Label
var _busy := false
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow := FlameGlow.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glow)
	_label = UIKit.label("", 34, UIKit.TEXT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.place(_label, Vector2(0.5, 0.5), Vector2(-560, -150), Vector2(1120, 260))
	add_child(_label)
	_hint = UIKit.label("Tap to continue", 22, UIKit.DIM)
	UIKit.place(_hint, Vector2(0.5, 1), Vector2(-300, -80), Vector2(600, 40))
	add_child(_hint)
	var skip := UIKit.button("Skip", _finish, 160)
	UIKit.place(skip, Vector2(1, 0), Vector2(-190, 24), Vector2(160, 56))
	add_child(skip)
	Audio.play_music("sanctuary" if pages == ENDING else "calm")
	_next()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		_next()


func _next() -> void:
	if _busy or _done:
		return
	_i += 1
	if _i >= pages.size():
		_finish()
		return
	_busy = true
	var tw := create_tween()
	if _i > 0:
		tw.tween_property(_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: _label.text = String(pages[_i]))
	tw.tween_property(_label, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func() -> void: _busy = false)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func on_back() -> void:
	_finish()


class FlameGlow extends Control:
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.82)
		draw_circle(c, 120.0, Color(1.0, 0.55, 0.25, 0.05))
		draw_circle(c, 60.0, Color(1.0, 0.6, 0.3, 0.08))
		FX.draw_flame(self, c + Vector2(0, 10), 16.0, _t, sin(_t * 0.7) * 3.0)
