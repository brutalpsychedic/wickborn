class_name HUD
extends Control
## Gameplay HUD: flames (health), ember counter, level name, pause button,
## sign hints, banners (upgrades, boss names) and the boss health bar.

signal pause_pressed

var hp := 5
var max_hp := 5
var embers := 0
var embers_total := 0
var level_text := ""
var boss_name := ""
var boss_hp := 0
var boss_max := 1
var _boss_shown := 0.0
var _t := 0.0
var _hint_panel: PanelContainer
var _hint_label: Label
var _banner: Label
var _banner_sub: Label
var _banner_tw: Tween
var _hint_tw: Tween
var _fps: Label
var _hurt_flash := 0.0
var _pause_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	_pause_btn = Button.new()
	_pause_btn.flat = false
	UIKit.place(_pause_btn, Vector2(1, 0), Vector2(-96, 16), Vector2(76, 76))
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.07, 0.45)
	sb.border_color = Color(1, 0.9, 0.75, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(38)
	for st in ["normal", "hover", "pressed", "focus"]:
		_pause_btn.add_theme_stylebox_override(st, sb)
	_pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	_pause_btn.draw.connect(_draw_pause_icon)
	add_child(_pause_btn)

	_hint_panel = PanelContainer.new()
	UIKit.place(_hint_panel, Vector2(0.5, 0), Vector2(-330, 64), Vector2(660, 0))
	_hint_panel.modulate.a = 0.0
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_panel)
	_hint_label = UIKit.label("", 24)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(620, 0)
	_hint_panel.add_child(_hint_label)

	_banner = UIKit.title("", 46)
	UIKit.place(_banner, Vector2(0.5, 0.5), Vector2(-500, -190), Vector2(1000, 60))
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_sub = UIKit.label("", 26)
	UIKit.place(_banner_sub, Vector2(0.5, 0.5), Vector2(-450, -118), Vector2(900, 40))
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub.modulate.a = 0.0
	add_child(_banner_sub)

	_fps = UIKit.label("", 18, UIKit.DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_fps.position = Vector2(30, 120)
	add_child(_fps)


func _process(delta: float) -> void:
	_t += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if boss_name != "":
		_boss_shown = minf(1.0, _boss_shown + delta * 2.0)
	else:
		_boss_shown = maxf(0.0, _boss_shown - delta * 2.0)
	_fps.visible = bool(Game.settings.get("show_fps", false))
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
	queue_redraw()


func set_hp(v: int, m: int) -> void:
	if v < hp:
		_hurt_flash = 0.4
	hp = v
	max_hp = m


func set_embers(v: int, total: int) -> void:
	embers = v
	embers_total = total


func show_hint(text: String, on: bool) -> void:
	if _hint_tw and _hint_tw.is_valid():
		_hint_tw.kill()
	_hint_tw = create_tween()
	if on:
		_hint_label.text = text
		_hint_tw.tween_property(_hint_panel, "modulate:a", 1.0, 0.25)
	else:
		_hint_tw.tween_property(_hint_panel, "modulate:a", 0.0, 0.35)


func banner(text: String, sub: String = "", hold: float = 2.4) -> void:
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner.text = text
	_banner_sub.text = sub
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.35)
	_banner_tw.tween_property(_banner_sub, "modulate:a", 1.0, 0.35).set_delay(0.15)
	_banner_tw.chain().tween_interval(hold)
	_banner_tw.chain().set_parallel(true)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.6)
	_banner_tw.tween_property(_banner_sub, "modulate:a", 0.0, 0.6)


func show_boss(n: String, h: int, m: int) -> void:
	boss_name = n
	boss_hp = h
	boss_max = maxi(m, 1)


func hide_boss() -> void:
	boss_name = ""


func _draw_pause_icon() -> void:
	var c := _pause_btn.size * 0.5
	var col := Color(1, 0.94, 0.85, 0.9)
	_pause_btn.draw_rect(Rect2(c + Vector2(-11, -14), Vector2(7, 28)), col)
	_pause_btn.draw_rect(Rect2(c + Vector2(4, -14), Vector2(7, 28)), col)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# health flames
	var x0 := 40.0
	var y0 := 52.0
	for i in max_hp:
		var p := Vector2(x0 + i * 34.0, y0)
		if i < hp:
			draw_circle(p + Vector2(0, -6), 16.0, Color(1.0, 0.5, 0.2, 0.12))
			var sz := 9.0
			if i == hp - 1 and _hurt_flash > 0.0:
				sz = 9.0 + _hurt_flash * 6.0
			FX.draw_flame(self, p + Vector2(0, 4), sz, _t + i * 0.7, 0.0)
		else:
			draw_line(p + Vector2(0, 4), p + Vector2(0, -6), Color(0.35, 0.32, 0.36, 0.9), 2.5)
			draw_circle(p + Vector2(0, -7), 2.5, Color(0.45, 0.4, 0.42, 0.9))
		draw_rect(Rect2(p + Vector2(-8, 5), Vector2(16, 5)), Color(0.85, 0.8, 0.7, 0.85))
	# embers
	var ep := Vector2(x0, y0 + 42.0)
	draw_colored_polygon(PackedVector2Array([ep + Vector2(0, -10), ep + Vector2(7, 0), ep + Vector2(0, 10), ep + Vector2(-7, 0)]), Color(1.0, 0.62, 0.22))
	draw_colored_polygon(PackedVector2Array([ep + Vector2(0, -5), ep + Vector2(3.5, 0), ep + Vector2(0, 5), ep + Vector2(-3.5, 0)]), Color(1.0, 0.95, 0.7))
	_text(font, ep + Vector2(16, 9), "%d / %d" % [embers, embers_total], 24, UIKit.TEXT)
	# level name (top centre)
	var lt := level_text
	var lw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	_text(font, Vector2(size.x * 0.5 - lw * 0.5, 40), lt, 22, Color(UIKit.TEXT, 0.75))
	# boss bar
	if _boss_shown > 0.0:
		var a := _boss_shown
		var bw := minf(620.0, size.x * 0.5)
		var bx := size.x * 0.5 - bw * 0.5
		var by := size.y - 64.0
		var nw := font.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_text(font, Vector2(size.x * 0.5 - nw * 0.5, by - 12), boss_name, 24, Color(UIKit.GOLD, a))
		draw_rect(Rect2(bx - 3, by - 3, bw + 6, 20), Color(0, 0, 0, 0.7 * a))
		draw_rect(Rect2(bx, by, bw, 14), Color(0.2, 0.08, 0.08, 0.9 * a))
		draw_rect(Rect2(bx, by, bw * float(boss_hp) / float(boss_max), 14), Color(0.85, 0.25, 0.2, a))
		draw_rect(Rect2(bx, by, bw * float(boss_hp) / float(boss_max), 4), Color(1.0, 0.6, 0.45, a))


func _text(font: Font, pos: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.7 * col.a))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
