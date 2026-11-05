extends Node
## Audio manager (autoload "Audio").
## SFX play through a small round-robin pool of players; music crossfades between two players.
## All sounds are generated offline by tools/gen_audio.gd into res://audio (no third-party assets).

const SFX_NAMES := [
	"jump", "djump", "land", "swing", "hit", "enemy_die", "hurt", "death", "ember", "secret",
	"upgrade", "checkpoint", "dash", "break", "shoot", "roar", "slam", "click", "back", "gate",
	"complete", "heal", "crumble", "splash", "swoop", "boss_die", "teleport",
]
const MUSIC_NAMES := ["calm", "deep", "ruins", "throne", "boss", "sanctuary"]
const POOL_SIZE := 12

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _current_music := ""
var _music_tween: Tween
var _duck := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for n in SFX_NAMES:
		var p := "res://audio/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			_sfx[n] = load(p)
	for i in POOL_SIZE:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_players.append(pl)
	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.volume_db = -80.0
		add_child(mp)
		_music_players.append(mp)
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")


func apply_volumes() -> void:
	var g := get_node_or_null("/root/Game")
	if g == null or g.settings.is_empty():
		return
	_set_bus_volume("Music", float(g.settings["music_volume"]) * _duck)
	_set_bus_volume("SFX", float(g.settings["sfx_volume"]))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))


## Lowers music while paused so menus feel calmer.
func set_duck(on: bool) -> void:
	_duck = 0.45 if on else 1.0
	apply_volumes()


func play(sfx_name: String, pitch_var: float = 0.06, volume_db: float = 0.0) -> void:
	if not _sfx.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	# The same sound triggered several times in one frame just gets louder and clips; skip repeats.
	if int(_last_play.get(sfx_name, -1000)) > now - 35:
		return
	_last_play[sfx_name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sfx[sfx_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


func _music_stream(track: String) -> AudioStream:
	if _music.has(track):
		return _music[track]
	var p := "res://audio/music/%s.wav" % track
	if not ResourceLoader.exists(p):
		return null
	var s: AudioStream = load(p)
	_music[track] = s
	return s


func play_music(track: String, fade: float = 1.2) -> void:
	if track == _current_music:
		return
	_current_music = track
	var stream := _music_stream(track)
	var old := _music_players[_active_music]
	_active_music = 1 - _active_music
	var cur := _music_players[_active_music]
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", -60.0, fade)
	if stream != null:
		cur.stream = stream
		cur.volume_db = -40.0
		cur.play()
		_music_tween.tween_property(cur, "volume_db", 0.0, fade)
	_music_tween.chain().tween_callback(old.stop)


func stop_music(fade: float = 1.0) -> void:
	_current_music = ""
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	for mp in _music_players:
		if mp.playing:
			_music_tween.tween_property(mp, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(_stop_all_music)


func _stop_all_music() -> void:
	for mp in _music_players:
		mp.stop()
