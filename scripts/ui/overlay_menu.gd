class_name OverlayMenu
extends Control
## Dimmed full-screen overlay with a centred panel. Used for Pause, Game Over and
## Level Complete. Runs while the tree is paused.

var box: VBoxContainer
var _first_button: Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	add_child(UIKit.dimmer(0.62))
	box = UIKit.panel(self, 12, 34)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func add_title(text: String, size: int = 52) -> Label:
	var l := UIKit.title(text, size)
	box.add_child(l)
	return l


func add_text(text: String, size: int = 24, color: Color = UIKit.TEXT) -> Label:
	var l := UIKit.label(text, size, color)
	box.add_child(l)
	return l


func add_space(h: float = 8.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	box.add_child(c)


func add_button(text: String, cb: Callable) -> Button:
	var b := UIKit.button(text, cb, 380.0)
	box.add_child(b)
	if _first_button == null:
		_first_button = b
		UIKit.focus_first(b)
	return b
