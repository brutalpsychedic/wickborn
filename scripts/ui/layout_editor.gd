class_name LayoutEditor
extends Control
## Drag the on-screen buttons where your thumbs like them. Positions are stored relative to
## the nearest bottom corner so they survive different screen widths.

signal closed

var _tc: TouchControls
var _saved_layout: Dictionary = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	_saved_layout = (Game.settings.get("layout", {}) as Dictionary).duplicate(true)
	var bg := UIKit.dimmer(0.9)
	add_child(bg)
	var guide := UIKit.label("Drag any button to move it.\nThe layout is saved when you press Done.", 26)
	UIKit.place(guide, Vector2(0.5, 0), Vector2(-450, 40), Vector2(900, 90))
	add_child(guide)
	_tc = TouchControls.new()
	_tc.edit_mode = true
	_tc.force_visible = true
	add_child(_tc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	UIKit.place(hb, Vector2(0.5, 0), Vector2(-420, 150), Vector2(840, 62))
	add_child(hb)
	hb.add_child(UIKit.button("Done", _done, 260))
	hb.add_child(UIKit.button("Defaults", _defaults, 260))
	hb.add_child(UIKit.button("Cancel", _cancel, 260))


func _done() -> void:
	Game.save_settings()
	closed.emit()


func _defaults() -> void:
	Game.settings["layout"] = {}
	_tc.reload()


func _cancel() -> void:
	Game.settings["layout"] = _saved_layout
	Game.save_settings()
	closed.emit()


func on_back() -> void:
	_cancel()
