class_name CreditsScreen
extends Control
## Credits and third-party notices.

const TEXT := """WICKBORN
The Last Ember

Design, code, art direction, music and sound
generated procedurally in code for this project.
No external art or audio assets are used.

Controls
Move: Left / Right buttons or joystick (A/D, arrows, gamepad stick)
Jump: JUMP (Space / Z, gamepad A) - hold for a higher jump
Attack: ATTACK (X / J, gamepad X) - hold to keep swinging
Dash: DASH once unlocked (C / Shift, gamepad B / RB)

Made with Godot Engine
Godot Engine is (c) 2014-present Godot Engine contributors,
(c) 2007-2014 Juan Linietsky, Ariel Manzur. MIT License.

Thank you for playing."""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bd := MenuBackdrop.new()
	bd.show_hero = false
	add_child(bd)
	add_child(UIKit.dimmer(0.55))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.place(scroll, Vector2(0.5, 0), Vector2(-500, 30), Vector2(1000, 580))
	add_child(scroll)
	var l := UIKit.label(TEXT, 24)
	l.custom_minimum_size = Vector2(980, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(l)
	var back := UIKit.button("Back", Game.goto_menu, 260)
	UIKit.place(back, Vector2(0.5, 1), Vector2(-130, -90), Vector2(260, 62))
	add_child(back)
	UIKit.focus_first(back)


func on_back() -> void:
	Game.goto_menu()
