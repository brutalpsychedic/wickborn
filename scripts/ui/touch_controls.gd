class_name TouchControls
extends Control
## Multitouch on-screen controls. Each finger is tracked by its touch index, so moving,
## jumping and attacking at the same time all work. Buttons feed the normal input actions
## (Input.action_press), so gameplay code doesn't know touch exists.
##
## Left side: Left/Right buttons (slide between them) or a fixed/floating joystick.
## Right side: Jump, Attack, Dash (Dash appears once unlocked).
## Layout, size and opacity come from Game.settings; edit_mode lets players drag them.

signal layout_edited

const ACTIONS := {"left": "move_left", "right": "move_right", "jump": "jump", "attack": "attack", "dash": "dash"}
const RADIUS := {"left": 60.0, "right": 60.0, "jump": 70.0, "attack": 64.0, "dash": 52.0, "joystick": 88.0}
const LABELS := {"left": "", "right": "", "jump": "JUMP", "attack": "ATTACK", "dash": "DASH"}

var edit_mode := false
var force_visible := false
var buttons: Dictionary = {}      # id -> {pos, r, visible, pressed}
var _touches: Dictionary = {}     # touch index -> id
var _drag: Dictionary = {}        # edit mode: touch index -> id
var _stick_center := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _scale := 1.0
var _opacity := 0.5
var _scheme := "buttons"


static func default_layout(id: String, jump_side: String) -> Array:
	# [anchor (0 = bottom-left, 1 = bottom-right), dx, dy] in base-resolution pixels
	var right := {"left": [0, 100, -118], "right": [0, 252, -118], "joystick": [0, 175, -150],
		"jump": [1, -112, -122], "attack": [1, -272, -104], "dash": [1, -200, -268]}
	var left := {"left": [0, 92, -112], "right": [0, 232, -112], "joystick": [0, 165, -150],
		"jump": [0, 384, -136], "attack": [1, -122, -120], "dash": [1, -150, -282]}
	var src: Dictionary = left if jump_side == "left" else right
	return src.get(id, [0, 0, 0])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.settings_changed.connect(reload)
	resized.connect(reload)
	reload()


func reload() -> void:
	var s := Game.settings
	_scale = float(s.get("button_scale", 1.0))
	_opacity = float(s.get("button_opacity", 0.5))
	_scheme = String(s.get("control_scheme", "buttons"))
	var layout: Dictionary = s.get("layout", {})
	var jump_side := String(s.get("jump_side", "right"))
	for id in ["left", "right", "joystick", "jump", "attack", "dash"]:
		var l: Array = layout.get(id, default_layout(id, jump_side))
		var pos := _resolve(l)
		var vis := true
		if id == "joystick":
			vis = _scheme == "joystick"
		elif id == "left" or id == "right":
			vis = _scheme == "buttons"
		elif id == "dash":
			vis = Game.has_upgrade("dash") or edit_mode
		var pressed := false
		if buttons.has(id):
			pressed = bool(buttons[id]["pressed"])
		buttons[id] = {"pos": pos, "r": float(RADIUS[id]) * _scale, "visible": vis, "pressed": pressed}
	_stick_center = buttons["joystick"]["pos"]
	visible = force_visible or edit_mode or Game.touch_controls_visible()
	queue_redraw()


func _resolve(l: Array) -> Vector2:
	var sz := size
	if sz.x < 10.0:
		sz = get_viewport_rect().size
	var p := Vector2((sz.x if int(l[0]) == 1 else 0.0) + float(l[1]), sz.y + float(l[2]))
	return Vector2(clampf(p.x, 40.0, sz.x - 40.0), clampf(p.y, 40.0, sz.y - 40.0))


func _to_layout(p: Vector2) -> Array:
	var sz := size
	if p.x > sz.x * 0.5:
		return [1, p.x - sz.x, p.y - sz.y]
	return [0, p.x, p.y - sz.y]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_down(st.index, st.position)
		else:
			_up(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_move(sd.index, sd.position)


func _down(idx: int, p: Vector2) -> void:
	if edit_mode:
		var best := ""
		var bd := INF
		for id in buttons:
			var b: Dictionary = buttons[id]
			if not b["visible"]:
				continue
			var d := p.distance_to(b["pos"])
			if d < float(b["r"]) * 1.4 and d < bd:
				best = id
				bd = d
		if best != "":
			_drag[idx] = best
		return
	if _scheme == "joystick":
		var jb: Dictionary = buttons["joystick"]
		var floating := String(Game.settings.get("joystick_mode", "fixed")) == "floating"
		var start := false
		if floating:
			start = p.x < size.x * 0.45 and p.y > size.y * 0.3 and not _over_action_button(p)
			if start:
				_stick_center = p
		elif p.distance_to(jb["pos"]) < float(jb["r"]) * 1.6:
			start = true
			_stick_center = jb["pos"]
		if start:
			_touches[idx] = "joystick"
			_update_stick(p)
			queue_redraw()
			return
	else:
		var dir := _dpad_hit(p, false)
		if dir != "":
			_touches[idx] = dir
			_press(dir)
			return
	for id in ["jump", "attack", "dash"]:
		var b: Dictionary = buttons[id]
		if b["visible"] and p.distance_to(b["pos"]) <= float(b["r"]) * 1.25:
			_touches[idx] = id
			_press(id)
			return


func _over_action_button(p: Vector2) -> bool:
	for id in ["jump", "attack", "dash"]:
		var b: Dictionary = buttons[id]
		if b["visible"] and p.distance_to(b["pos"]) <= float(b["r"]) * 1.3:
			return true
	return false


func _dpad_hit(p: Vector2, sliding: bool) -> String:
	var l: Dictionary = buttons["left"]
	var r: Dictionary = buttons["right"]
	var lp: Vector2 = l["pos"]
	var rp: Vector2 = r["pos"]
	var reach := float(l["r"]) * (1.9 if sliding else 1.35)
	var dl := p.distance_to(lp)
	var dr := p.distance_to(rp)
	if minf(dl, dr) > reach:
		# also accept the strip between the two buttons
		var mid := (lp + rp) * 0.5
		if not (absf(p.y - mid.y) < float(l["r"]) * 1.2 and p.x > minf(lp.x, rp.x) and p.x < maxf(lp.x, rp.x)):
			return ""
	return "left" if dl < dr else "right"


func _move(idx: int, p: Vector2) -> void:
	if edit_mode:
		if _drag.has(idx):
			buttons[_drag[idx]]["pos"] = Vector2(clampf(p.x, 50.0, size.x - 50.0), clampf(p.y, 50.0, size.y - 50.0))
			if _drag[idx] == "joystick":
				_stick_center = buttons["joystick"]["pos"]
			queue_redraw()
		return
	if not _touches.has(idx):
		return
	var id: String = _touches[idx]
	if id == "joystick":
		_update_stick(p)
	elif id == "left" or id == "right":
		var nid := _dpad_hit(p, true)
		if nid != "" and nid != id:
			_touches[idx] = nid
			_release_if_free(id)
			_press(nid)


func _up(idx: int) -> void:
	if edit_mode:
		if _drag.has(idx):
			var id: String = _drag[idx]
			_drag.erase(idx)
			var layout: Dictionary = (Game.settings.get("layout", {}) as Dictionary).duplicate()
			layout[id] = _to_layout(buttons[id]["pos"])
			Game.settings["layout"] = layout
			layout_edited.emit()
		return
	if not _touches.has(idx):
		return
	var id2: String = _touches[idx]
	_touches.erase(idx)
	if id2 == "joystick":
		_stick_knob = Vector2.ZERO
		_set_axis(0.0)
		if String(Game.settings.get("joystick_mode", "fixed")) == "floating":
			_stick_center = buttons["joystick"]["pos"]
		queue_redraw()
	else:
		_release_if_free(id2)


func _press(id: String) -> void:
	buttons[id]["pressed"] = true
	Input.action_press(ACTIONS[id])
	queue_redraw()


func _release_if_free(id: String) -> void:
	for k in _touches:
		if _touches[k] == id:
			return
	buttons[id]["pressed"] = false
	Input.action_release(ACTIONS[id])
	queue_redraw()


func _update_stick(p: Vector2) -> void:
	var r := float(buttons["joystick"]["r"])
	var d := p - _stick_center
	if d.length() > r:
		d = d.normalized() * r
	_stick_knob = d
	var sens := clampf(float(Game.settings.get("joystick_sensitivity", 0.6)), 0.2, 1.0)
	var dz := clampf(float(Game.settings.get("joystick_deadzone", 0.2)), 0.0, 0.6)
	var x := clampf(d.x / (r * sens), -1.0, 1.0)
	if absf(x) < dz:
		x = 0.0
	else:
		x = signf(x) * (absf(x) - dz) / (1.0 - dz)
	_set_axis(x)
	queue_redraw()


func _set_axis(x: float) -> void:
	if x < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left", -x)
	elif x > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right", x)
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func release_all() -> void:
	_touches.clear()
	_stick_knob = Vector2.ZERO
	for id in ACTIONS:
		if buttons.has(id) and bool(buttons[id]["pressed"]):
			buttons[id]["pressed"] = false
			Input.action_release(ACTIONS[id])
	_set_axis(0.0)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		if is_inside_tree() or what == NOTIFICATION_EXIT_TREE:
			for id in ACTIONS:
				Input.action_release(ACTIONS[id])


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for id in buttons:
		var b: Dictionary = buttons[id]
		if not b["visible"]:
			continue
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		if id == "joystick":
			var c := _stick_center
			draw_circle(c, r, Color(0.05, 0.04, 0.07, _opacity * 0.5))
			draw_arc(c, r, 0.0, TAU, 40, Color(1, 0.9, 0.75, _opacity * 0.8), 3.0, true)
			draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(-r * 0.75, 0), Color(1, 0.9, 0.75, _opacity), 3.0)
			draw_line(c + Vector2(r * 0.55, 0), c + Vector2(r * 0.75, 0), Color(1, 0.9, 0.75, _opacity), 3.0)
			draw_circle(c + _stick_knob, r * 0.42, Color(1, 0.75, 0.42, minf(1.0, _opacity * 1.4)))
			continue
		var pressed: bool = b["pressed"]
		var fill := Color(1.0, 0.68, 0.32, minf(1.0, _opacity * 1.2)) if pressed else Color(0.05, 0.04, 0.07, _opacity * 0.55)
		draw_circle(p, r * (0.94 if pressed else 1.0), fill)
		draw_arc(p, r, 0.0, TAU, 40, Color(1, 0.9, 0.75, minf(1.0, _opacity * 1.5)), 3.0, true)
		var ic := Color(1, 0.95, 0.88, minf(1.0, _opacity * 1.7))
		var s := r / 60.0
		match id:
			"left", "right":
				var f := -1.0 if id == "left" else 1.0
				draw_colored_polygon(PackedVector2Array([p + Vector2(f * 18, 0) * s, p + Vector2(-f * 12, -18) * s, p + Vector2(-f * 12, 18) * s]), ic)
			"jump":
				draw_polyline(PackedVector2Array([p + Vector2(-18, 2) * s, p + Vector2(0, -16) * s, p + Vector2(18, 2) * s]), ic, 5.0 * s, true)
				draw_polyline(PackedVector2Array([p + Vector2(-12, 14) * s, p + Vector2(0, 2) * s, p + Vector2(12, 14) * s]), Color(ic, ic.a * 0.6), 4.0 * s, true)
			"attack":
				draw_line(p + Vector2(-14, 14) * s, p + Vector2(16, -16) * s, ic, 5.0 * s, true)
				draw_line(p + Vector2(-17, 5) * s, p + Vector2(-5, 17) * s, ic, 4.0 * s, true)
				draw_line(p + Vector2(-14, 14) * s, p + Vector2(-20, 20) * s, ic, 4.0 * s, true)
			"dash":
				for k in 2:
					var ox := (-10 + k * 12) * s
					draw_polyline(PackedVector2Array([p + Vector2(ox - 5 * s, -12 * s), p + Vector2(ox + 6 * s, 0), p + Vector2(ox - 5 * s, 12 * s)]), ic, 4.0 * s, true)
		var txt: String = LABELS.get(id, "")
		if txt != "":
			var fs := int(15 * s)
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, p + Vector2(-tw * 0.5, r * 0.72), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ic, ic.a * 0.8))
		if edit_mode:
			draw_arc(p, r + 8.0, 0.0, TAU, 40, Color(1.0, 0.8, 0.4, 0.8), 2.0, true)
