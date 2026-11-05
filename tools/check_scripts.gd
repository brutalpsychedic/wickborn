extends SceneTree
## Loads every script under res://scripts and res://tools so parse errors surface in CI/headless.
## Run: godot --headless --path . --script res://tools/check_scripts.gd


var _ran := false


func _process(_delta: float) -> bool:
	# autoloads (Game, Audio) only exist once the main loop is running
	if not _ran:
		_ran = true
		_check()
	return false


func _check() -> void:
	var bad := 0
	var n := 0
	for dir in ["res://scripts", "res://tools"]:
		for p in _scan(dir):
			n += 1
			var s: Script = load(p)
			if s == null or not s.can_instantiate():
				bad += 1
				print("BROKEN: ", p)
	print("checked %d scripts, %d broken" % [n, bad])
	quit(1 if bad > 0 else 0)


func _scan(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scan(dir.path_join(sub)))
	return out
