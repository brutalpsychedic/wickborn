class_name LevelSelect
extends Control
## 10 level cards (2 rows of 5). Locked levels are greyed out; finished ones show
## embers collected and whether the hidden Memory Wick was found.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bd := MenuBackdrop.new()
	bd.show_hero = false
	add_child(bd)
	add_child(UIKit.dimmer(0.35))
	var title := UIKit.title("Choose a Path", 56)
	UIKit.place(title, Vector2(0.5, 0), Vector2(-400, 28), Vector2(800, 80))
	add_child(title)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	UIKit.place(grid, Vector2(0.5, 0.5), Vector2(-615, -210), Vector2(1230, 430))
	add_child(grid)
	for i in Game.LEVELS.size():
		grid.add_child(_card(i + 1))

	var back := UIKit.button("Back", Game.goto_menu, 260)
	UIKit.place(back, Vector2(0.5, 1), Vector2(-130, -92), Vector2(260, 62))
	add_child(back)
	var totals := UIKit.label("Embers %d   Memory Wicks %d / %d   Heart Wicks %d" % [Game.total_embers(), Game.total_secrets(), Game.LEVELS.size(), (Game.progress["hearts"] as Array).size()], 22, UIKit.DIM)
	UIKit.place(totals, Vector2(0.5, 1), Vector2(-500, -136), Vector2(1000, 34))
	add_child(totals)
	UIKit.focus_first(grid)


func _card(n: int) -> Button:
	var info: Dictionary = Game.LEVELS[n - 1]
	var st := Game.level_stats(n)
	var unlocked := Game.is_unlocked(n)
	var b := Button.new()
	b.custom_minimum_size = Vector2(234, 206)
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = not unlocked
	b.add_theme_font_size_override("font_size", 20)
	var lines := "%d\n%s\n" % [n, info["name"]]
	if not unlocked:
		lines += "\nLocked"
	elif bool(st.get("done", false)):
		lines += "\nEmbers %d/%d" % [int(st.get("embers", 0)), int(st.get("embers_total", 0))]
		lines += "\nMemory Wick: %s" % ("found" if bool(st.get("secret", false)) else "-")
	else:
		lines += "\nNew"
	b.text = lines
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(UIKit._click)
	b.pressed.connect(Game.start_level.bind(n, true))
	return b


func on_back() -> void:
	Game.goto_menu()
