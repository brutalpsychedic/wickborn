class_name MainMenu
extends Control
## Title screen: Play (continues where you left off), Level Select, Settings, Credits.

var _overlay: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	add_child(MenuBackdrop.new())
	Audio.play_music("calm")

	var title := UIKit.title("WICKBORN", 104)
	UIKit.place(title, Vector2(0.5, 0), Vector2(-480, 60), Vector2(960, 130))
	add_child(title)
	var sub := UIKit.label("The Last Ember", 30, Color(1.0, 0.85, 0.6, 0.9))
	UIKit.place(sub, Vector2(0.5, 0), Vector2(-300, 186), Vector2(600, 40))
	add_child(sub)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	UIKit.place(vb, Vector2(0.5, 0.5), Vector2(-190, -60), Vector2(380, 340))
	add_child(vb)
	var play_text := "Play"
	if bool(Game.progress.get("story_seen", false)):
		play_text = "Continue - Level %d" % Game.first_unfinished_level()
	vb.add_child(UIKit.button(play_text, Game.play_from_menu, 380))
	vb.add_child(UIKit.button("Level Select", Game.goto_level_select, 380))
	vb.add_child(UIKit.button("Settings", _open_settings, 380))
	vb.add_child(UIKit.button("Credits", Game.goto_credits, 380))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		vb.add_child(UIKit.button("Quit", func() -> void: get_tree().quit(), 380))
	UIKit.focus_first(vb)

	var ver := UIKit.label("v%s" % ProjectSettings.get_setting("application/config/version", "1.0"), 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	UIKit.place(ver, Vector2(1, 1), Vector2(-220, -40), Vector2(200, 30))
	add_child(ver)


func _open_settings() -> void:
	var s := SettingsMenu.new()
	s.closed.connect(_close_overlay)
	_overlay = s
	add_child(s)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	UIKit.focus_first(self)


func on_back() -> void:
	if _overlay != null and _overlay.has_method("on_back"):
		_overlay.on_back()
	elif not OS.has_feature("mobile"):
		pass
	else:
		get_tree().quit()
