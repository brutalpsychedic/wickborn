class_name VictoryScreen
extends Control
## Final victory: the Flame is rekindled. Shows totals for the whole journey.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bd := MenuBackdrop.new()
	bd.mood = "dawn"
	add_child(bd)
	Audio.play_music("sanctuary")
	var title := UIKit.title("The Flame Rekindled", 72)
	UIKit.place(title, Vector2(0.5, 0), Vector2(-600, 50), Vector2(1200, 100))
	add_child(title)
	var total_time := 0.0
	var embers := 0
	var embers_total := 0
	for i in Game.LEVELS.size():
		var st := Game.level_stats(i + 1)
		total_time += float(st.get("best_time", 0.0))
		embers += int(st.get("embers", 0))
		embers_total += int(st.get("embers_total", 0))
	var lines := "Embers gathered: %d / %d\nMemory Wicks found: %d / %d\nHeart Wicks: %d\nBest times combined: %s" % [
		embers, embers_total, Game.total_secrets(), Game.LEVELS.size(),
		(Game.progress["hearts"] as Array).size(), UIKit.format_time(total_time)]
	var stats := UIKit.label(lines, 30)
	UIKit.place(stats, Vector2(0.5, 0.5), Vector2(-450, -130), Vector2(900, 200))
	add_child(stats)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	UIKit.place(hb, Vector2(0.5, 1), Vector2(-420, -130), Vector2(840, 62))
	add_child(hb)
	hb.add_child(UIKit.button("Credits", Game.goto_credits, 260))
	hb.add_child(UIKit.button("Level Select", Game.goto_level_select, 260))
	hb.add_child(UIKit.button("Main Menu", Game.goto_menu, 260))
	UIKit.focus_first(hb)


func on_back() -> void:
	Game.goto_menu()
