class_name UIKit
## Shared UI look (one Theme built in code) and small builders so every menu matches.
## Buttons are at least 64 px tall at the 720p base resolution for comfortable touch.

const GOLD := Color("#e8b45a")
const TEXT := Color("#efe6d6")
const DIM := Color("#9c92a8")
const PANEL := Color(0.055, 0.045, 0.075, 0.94)

static var _theme: Theme
static var _title_font: FontVariation


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 26
	t.set_stylebox("normal", "Button", _box(Color(0.09, 0.075, 0.12, 0.92), Color(0.85, 0.62, 0.35, 0.45)))
	t.set_stylebox("hover", "Button", _box(Color(0.15, 0.11, 0.15, 0.96), Color(1.0, 0.76, 0.42, 0.9)))
	t.set_stylebox("pressed", "Button", _box(Color(0.42, 0.24, 0.12, 0.96), Color(1.0, 0.82, 0.5, 1.0)))
	t.set_stylebox("disabled", "Button", _box(Color(0.07, 0.065, 0.09, 0.75), Color(0.4, 0.38, 0.45, 0.35)))
	var focus := _box(Color(0, 0, 0, 0), Color(1.0, 0.85, 0.5, 1.0), 12, 3)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_focus_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(0.85, 0.62, 0.35, 0.35), 16, 2))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.17, 0.24)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.55, 0.28)
	fill.set_corner_radius_all(6)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _grabber_icon(false))
	t.set_icon("grabber_highlight", "HSlider", _grabber_icon(true))
	_theme = t
	return t


static func _grabber_icon(hi: bool) -> Texture2D:
	var img := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1.0, 0.9, 0.7) if hi else Color(0.95, 0.8, 0.6)
	for y in 30:
		for x in 30:
			var d := Vector2(x - 14.5, y - 14.5).length()
			if d < 13.5:
				img.set_pixel(x, y, c if d < 11.0 else Color(0.3, 0.2, 0.15))
	return ImageTexture.create_from_image(img)


static func _box(bg: Color, border: Color, radius: int = 12, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func title_font() -> Font:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = ThemeDB.fallback_font
		_title_font.variation_embolden = 0.8
		_title_font.spacing_glyph = 8
	return _title_font


static func button(text: String, cb: Callable, min_w: float = 340.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 62)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(_click)
	b.pressed.connect(cb)
	return b


static func _click() -> void:
	Audio.play("click", 0.02, -3.0)


static func label(text: String, size: int = 26, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.horizontal_alignment = align
	return l


static func title(text: String, size: int = 64) -> Label:
	var l := label(text, size, GOLD)
	l.add_theme_font_override("font", title_font())
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02, 0.9))
	return l


## Full-screen dimmer.
static func dimmer(alpha: float = 0.65) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.01, 0.01, 0.02, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## Centered panel with a vertical box inside. Returns the box.
static func panel(parent: Control, sep: int = 14, pad: int = 30) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var pc := PanelContainer.new()
	cc.add_child(pc)
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, pad)
	pc.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_child(vb)
	return vb


## A button that cycles through options; shows "Label: Value".
static func cycle_button(caption: String, values: Array, names: Array, current: Variant, on_change: Callable, min_w: float = 300.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(min_w, 56)
	b.focus_mode = Control.FOCUS_ALL
	var idx := maxi(0, values.find(current))
	b.text = "%s: %s" % [caption, names[idx]]
	b.set_meta("idx", idx)
	b.pressed.connect(func() -> void:
		var i: int = (int(b.get_meta("idx")) + 1) % values.size()
		b.set_meta("idx", i)
		b.text = "%s: %s" % [caption, names[i]]
		_click()
		on_change.call(values[i])
	)
	return b


static func focus_first(c: Control) -> void:
	if OS.has_feature("mobile"):
		return
	if c is BaseButton:
		c.grab_focus.call_deferred()
		return
	for ch in c.get_children():
		if ch is Control:
			var found := _first_button(ch)
			if found != null:
				found.grab_focus.call_deferred()
				return


static func _first_button(c: Node) -> BaseButton:
	if c is BaseButton and (c as BaseButton).visible and not (c as BaseButton).disabled:
		return c
	for ch in c.get_children():
		var f := _first_button(ch)
		if f != null:
			return f
	return null


## Anchor a control to a point of its parent (0..1 on each axis) with a pixel offset and size.
## Robust regardless of whether the parent has been laid out yet.
static func place(c: Control, anchor: Vector2, offset: Vector2, sz: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + sz.x
	c.offset_bottom = offset.y + sz.y


static func format_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 60, s % 60]
