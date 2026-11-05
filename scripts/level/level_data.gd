class_name LevelData
extends RefCounted
## Parses a level text file:
##   [meta]   key=value lines (name, theme, music, boss, upgrade, heart, secret, ...)
##   [signs]  one line per sign; map digits 1-9 refer to these lines in order
##   [map]    the ASCII grid (see levels/README.md)

var path := ""
var meta: Dictionary = {}
var signs: PackedStringArray = PackedStringArray()
var overlays: Array[Rect2i] = []   # hidden rooms: cells inside that aren't solid get covered
var rows: Array[PackedByteArray] = []
var w := 0
var h := 0


static func load_file(file_path: String) -> LevelData:
	var d := LevelData.new()
	d.path = file_path
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("Level file missing: %s" % file_path)
		return null
	var section := ""
	var map_lines: PackedStringArray = PackedStringArray()
	while not f.eof_reached():
		var line := f.get_line().rstrip("\r")
		var stripped := line.strip_edges()
		if stripped.begins_with("[") and stripped.ends_with("]") and stripped.length() > 2 and not stripped.contains("#"):
			section = stripped.substr(1, stripped.length() - 2)
			continue
		match section:
			"meta":
				if stripped == "" or stripped.begins_with(";"):
					continue
				var kv := stripped.split("=", true, 1)
				if kv.size() == 2:
					d.meta[kv[0].strip_edges()] = kv[1].strip_edges()
			"signs":
				if stripped == "" or stripped.begins_with(";"):
					continue
				d.signs.append(stripped.replace("\\n", "\n"))
			"overlay":
				var parts := stripped.split(",")
				if parts.size() == 4:
					var x0 := int(parts[0])
					var y0 := int(parts[1])
					d.overlays.append(Rect2i(x0, y0, int(parts[2]) - x0 + 1, int(parts[3]) - y0 + 1))
			"map":
				if stripped.begins_with(";"):
					continue
				map_lines.append(line)
	f.close()
	# trim empty lines at the very end of the map
	while map_lines.size() > 0 and map_lines[map_lines.size() - 1].strip_edges() == "":
		map_lines.remove_at(map_lines.size() - 1)
	for l in map_lines:
		d.w = maxi(d.w, l.length())
	d.h = map_lines.size()
	for l in map_lines:
		var row := PackedByteArray()
		row.resize(d.w)
		row.fill(Phys.CH_AIR)
		for i in l.length():
			var c := l.unicode_at(i)
			row[i] = Phys.CH_AIR if (c == 32 or c > 127) else c
		d.rows.append(row)
	return d


func get_meta_str(key: String, default: String = "") -> String:
	return String(meta.get(key, default))


func get_meta_float(key: String, default: float = 0.0) -> float:
	return float(meta.get(key, default))
