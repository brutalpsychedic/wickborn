extends SceneTree
## Procedural audio: renders every sound effect and music loop used by the game into
## res://audio/sfx/*.wav and res://audio/music/*.wav (22.05 kHz mono, 16-bit).
## Nothing is sampled from anywhere: oscillators, noise, envelopes, FM bells and a small
## Schroeder reverb. Music files carry a 'smpl' loop chunk so Godot loops them seamlessly.
##   godot --headless --path . --script res://tools/gen_audio.gd [-- --only=sfx|music]

const SR := 22050
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			only = String(a).split("=")[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio/sfx"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio/music"))
	if only != "music":
		_sfx()
	if only != "sfx":
		_music()
	quit()


# ============================================================ primitives

func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * SR))
	b.fill(0.0)
	return b


static func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


## Tone with a pitch sweep and exponential decay. wave: 0 sine, 1 triangle, 2 saw, 3 square
func tone(b: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, amp: float, wave: int = 0,
		attack: float = 0.005, decay: float = 6.0, vib: float = 0.0, vib_rate: float = 5.0) -> void:
	var i0 := int(t0 * SR)
	var n := int(dur * SR)
	var ph := 0.0
	var lp := 0.0
	for k in n:
		var i := i0 + k
		if i >= b.size():
			break
		var t := float(k) / SR
		var p := float(k) / n
		var f := f0 * pow(f1 / f0, p)
		if vib > 0.0:
			f *= 1.0 + vib * sin(TAU * vib_rate * t)
		ph += f / SR
		ph -= floorf(ph)
		var s := 0.0
		match wave:
			0:
				s = sin(TAU * ph)
			1:
				s = 4.0 * absf(ph - 0.5) - 1.0
			2:
				s = 2.0 * ph - 1.0
				lp += 0.35 * (s - lp)
				s = lp
			3:
				s = 1.0 if ph < 0.5 else -1.0
				lp += 0.3 * (s - lp)
				s = lp
		var env := minf(1.0, t / attack) * exp(-decay * t)
		if p > 0.9:
			env *= (1.0 - p) * 10.0
		b[i] += s * env * amp


## Low-passed noise burst. Cutoff moves from c0 to c1 (0..1 filter coefficient).
func noise(b: PackedFloat32Array, t0: float, dur: float, amp: float, c0: float, c1: float,
		attack: float = 0.003, decay: float = 10.0, highpass: bool = false) -> void:
	var i0 := int(t0 * SR)
	var n := int(dur * SR)
	var lp := 0.0
	var lp2 := 0.0
	for k in n:
		var i := i0 + k
		if i >= b.size():
			break
		var t := float(k) / SR
		var p := float(k) / n
		var c := lerpf(c0, c1, p)
		lp += c * (rng.randf_range(-1.0, 1.0) - lp)
		lp2 += c * (lp - lp2)
		var s := lp2
		if highpass:
			s = lp - lp2
		var env := minf(1.0, t / attack) * exp(-decay * t)
		if p > 0.85:
			env *= (1.0 - p) / 0.15
		b[i] += s * env * amp


## FM bell: inharmonic shimmer that decays to a pure tone.
func bell(b: PackedFloat32Array, t0: float, f: float, amp: float, dur: float = 2.0, ratio: float = 3.5,
		index: float = 2.2, decay: float = 2.6) -> void:
	var i0 := int(t0 * SR)
	var n := int(dur * SR)
	for k in n:
		var i := i0 + k
		if i >= b.size():
			break
		var t := float(k) / SR
		var ii := index * exp(-t * 5.0)
		var s := sin(TAU * f * t + ii * sin(TAU * f * ratio * t))
		var env := minf(1.0, t / 0.004) * exp(-decay * t)
		var p := float(k) / n
		if p > 0.9:
			env *= (1.0 - p) * 10.0
		b[i] += s * env * amp


## Warm pad voice: two detuned soft saws through a gentle low-pass, slow attack/release.
func pad(b: PackedFloat32Array, t0: float, dur: float, f: float, amp: float, attack: float = 1.2,
		release: float = 1.6, bright: float = 0.12) -> void:
	var i0 := int(t0 * SR)
	var n := int((dur + release) * SR)
	var ph1 := rng.randf()
	var ph2 := rng.randf()
	var lp := 0.0
	var lp2 := 0.0
	var f1 := f * 1.004
	var f2 := f * 0.996
	for k in n:
		var i := i0 + k
		if i >= b.size():
			i -= b.size()   # wrap so loops stay seamless
		var t := float(k) / SR
		ph1 += f1 / SR
		ph1 -= floorf(ph1)
		ph2 += f2 / SR
		ph2 -= floorf(ph2)
		var s := (ph1 - 0.5) + (ph2 - 0.5)
		lp += bright * (s - lp)
		lp2 += bright * (lp - lp2)
		var env := minf(1.0, t / attack)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / release)
		b[i] += lp2 * env * amp


## Organ-ish additive voice.
func organ(b: PackedFloat32Array, t0: float, dur: float, f: float, amp: float) -> void:
	var i0 := int(t0 * SR)
	var rel := 1.2
	var n := int((dur + rel) * SR)
	for k in n:
		var i := i0 + k
		if i >= b.size():
			i -= b.size()
		var t := float(k) / SR
		var w := TAU * f * t
		var s := sin(w) + 0.5 * sin(2.0 * w) + 0.25 * sin(3.0 * w) + 0.12 * sin(4.0 * w)
		var env := minf(1.0, t / 0.6)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / rel)
		b[i] += s * env * amp * (1.0 + 0.04 * sin(TAU * 5.5 * t))


func kick(b: PackedFloat32Array, t0: float, amp: float) -> void:
	tone(b, t0, 0.32, 130.0, 42.0, amp, 0, 0.002, 9.0)
	noise(b, t0, 0.02, amp * 0.3, 0.6, 0.3, 0.001, 40.0)


func snare(b: PackedFloat32Array, t0: float, amp: float) -> void:
	noise(b, t0, 0.2, amp, 0.7, 0.5, 0.001, 18.0, true)
	tone(b, t0, 0.12, 190.0, 150.0, amp * 0.4, 1, 0.001, 20.0)


func hat(b: PackedFloat32Array, t0: float, amp: float) -> void:
	noise(b, t0, 0.05, amp, 0.95, 0.9, 0.001, 60.0, true)


## Simple Schroeder reverb (4 damped combs + 2 allpasses), mixed in place.
func reverb(b: PackedFloat32Array, mix: float, size: float = 1.0, wrap: bool = false) -> void:
	var combs := [int(778 * size), int(808 * size), int(745 * size), int(711 * size)]
	var out := PackedFloat32Array()
	out.resize(b.size())
	out.fill(0.0)
	var passes := 2 if wrap else 1
	for d in combs:
		var line := PackedFloat32Array()
		line.resize(d)
		line.fill(0.0)
		var idx := 0
		var damp := 0.0
		for pass_i in passes:
			for i in b.size():
				var y := line[idx]
				damp += 0.45 * (y - damp)
				line[idx] = b[i] + damp * 0.83
				idx = (idx + 1) % d
				if pass_i == passes - 1:
					out[i] += y * 0.25
	for d2 in [int(278 * size), int(112 * size)]:
		var ap := PackedFloat32Array()
		ap.resize(d2)
		ap.fill(0.0)
		var j := 0
		for i in out.size():
			var bufv := ap[j]
			var inp := out[i]
			out[i] = -inp * 0.5 + bufv
			ap[j] = inp + bufv * 0.5
			j = (j + 1) % d2
	for i in b.size():
		b[i] = b[i] * (1.0 - mix * 0.5) + out[i] * mix


func finish(b: PackedFloat32Array, peak: float = 0.85) -> void:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in b.size():
		var x := b[i] * g
		# soft knee to tame occasional overs
		b[i] = x if absf(x) < 0.8 else signf(x) * (0.8 + 0.2 * tanh((absf(x) - 0.8) * 5.0))


func save_wav(path: String, b: PackedFloat32Array, loop: bool = false) -> void:
	var n := b.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	var smpl_size := 60 if loop else 0
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(4 + (8 + 16) + (8 + data.size()) + ((8 + smpl_size) if loop else 0))
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)        # PCM
	f.store_16(1)        # mono
	f.store_32(SR)
	f.store_32(SR * 2)
	f.store_16(2)
	f.store_16(16)
	if loop:
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(smpl_size)
		for v in [0, 0, int(1000000000.0 / SR), 60, 0, 0, 0, 1, 0]:
			f.store_32(v)
		for v in [0, 0, 0, n - 1, 0, 0]:   # cue id, forward loop, start, end, fraction, infinite
			f.store_32(v)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	print("wrote %s (%.2fs)" % [path, float(n) / SR])


# ============================================================ sound effects

func _sfx() -> void:
	rng.seed = 1234
	var d := "res://audio/sfx/"
	var b: PackedFloat32Array

	b = buf(0.22)
	tone(b, 0.0, 0.18, 280.0, 620.0, 0.6, 3, 0.003, 12.0)
	noise(b, 0.0, 0.1, 0.25, 0.3, 0.15, 0.002, 30.0)
	finish(b, 0.6)
	save_wav(d + "jump.wav", b)

	b = buf(0.3)
	tone(b, 0.0, 0.12, 480.0, 820.0, 0.45, 3, 0.002, 14.0)
	tone(b, 0.07, 0.18, 640.0, 1150.0, 0.45, 1, 0.002, 12.0)
	bell(b, 0.05, 1760.0, 0.15, 0.25, 2.0, 1.0, 12.0)
	finish(b, 0.6)
	save_wav(d + "djump.wav", b)

	b = buf(0.18)
	tone(b, 0.0, 0.12, 140.0, 55.0, 0.8, 0, 0.001, 22.0)
	noise(b, 0.0, 0.1, 0.5, 0.25, 0.08, 0.001, 30.0)
	finish(b, 0.5)
	save_wav(d + "land.wav", b)

	b = buf(0.2)
	noise(b, 0.0, 0.18, 1.0, 0.15, 0.6, 0.03, 14.0, true)
	noise(b, 0.0, 0.16, 0.5, 0.4, 0.15, 0.02, 16.0)
	finish(b, 0.55)
	save_wav(d + "swing.wav", b)

	b = buf(0.2)
	noise(b, 0.0, 0.1, 1.0, 0.8, 0.2, 0.0005, 35.0)
	tone(b, 0.0, 0.14, 220.0, 90.0, 0.8, 1, 0.001, 18.0)
	tone(b, 0.0, 0.03, 2200.0, 1400.0, 0.3, 0, 0.0005, 60.0)
	finish(b, 0.75)
	save_wav(d + "hit.wav", b)

	b = buf(0.5)
	noise(b, 0.0, 0.35, 0.9, 0.6, 0.05, 0.001, 9.0)
	tone(b, 0.0, 0.4, 420.0, 70.0, 0.6, 2, 0.002, 6.0)
	for k in 6:
		noise(b, 0.05 + k * 0.05, 0.03, 0.3, 0.9, 0.6, 0.001, 50.0, true)
	finish(b, 0.7)
	save_wav(d + "enemy_die.wav", b)

	b = buf(0.35)
	tone(b, 0.0, 0.3, 240.0, 150.0, 0.5, 3, 0.002, 7.0)
	tone(b, 0.0, 0.3, 254.0, 158.0, 0.5, 3, 0.002, 7.0)
	noise(b, 0.0, 0.12, 0.6, 0.5, 0.2, 0.001, 25.0)
	finish(b, 0.75)
	save_wav(d + "hurt.wav", b)

	b = buf(1.6)
	tone(b, 0.0, 1.4, 440.0, 70.0, 0.6, 1, 0.01, 1.8, 0.03, 9.0)
	noise(b, 0.0, 1.4, 0.35, 0.5, 0.05, 0.02, 2.5, true)
	reverb(b, 0.35)
	finish(b, 0.7)
	save_wav(d + "death.wav", b)

	b = buf(0.35)
	bell(b, 0.0, 1318.5, 0.5, 0.32, 2.0, 1.6, 9.0)
	bell(b, 0.03, 1975.5, 0.3, 0.3, 2.0, 1.2, 10.0)
	finish(b, 0.5)
	save_wav(d + "ember.wav", b)

	b = buf(1.4)
	var notes := [84, 88, 91, 96]
	for k in notes.size():
		bell(b, k * 0.09, midi(notes[k]), 0.35, 1.2, 3.5, 2.0, 3.0)
	reverb(b, 0.4)
	finish(b, 0.65)
	save_wav(d + "secret.wav", b)

	b = buf(2.0)
	var fan := [67, 72, 76, 79, 84]
	for k in fan.size():
		bell(b, k * 0.1, midi(fan[k]), 0.32, 1.6, 2.0, 1.5, 2.4)
		pad(b, k * 0.1, 0.9, midi(fan[k] - 12), 0.18, 0.05, 0.8, 0.2)
	noise(b, 0.0, 1.2, 0.12, 0.9, 0.7, 0.3, 2.0, true)
	reverb(b, 0.45)
	finish(b, 0.7)
	save_wav(d + "upgrade.wav", b)

	b = buf(1.6)
	for nn in [57, 64, 69, 73]:
		pad(b, 0.0, 0.7, midi(nn), 0.25, 0.08, 0.8, 0.18)
	noise(b, 0.0, 0.5, 0.35, 0.2, 0.5, 0.05, 5.0)
	bell(b, 0.05, midi(81), 0.2, 1.2, 3.5, 1.2, 3.0)
	reverb(b, 0.4)
	finish(b, 0.65)
	save_wav(d + "checkpoint.wav", b)

	b = buf(0.25)
	noise(b, 0.0, 0.22, 1.0, 0.3, 0.8, 0.005, 12.0, true)
	tone(b, 0.0, 0.15, 180.0, 90.0, 0.4, 0, 0.002, 15.0)
	finish(b, 0.6)
	save_wav(d + "dash.wav", b)

	b = buf(0.6)
	for k in 7:
		noise(b, k * 0.06 + rng.randf() * 0.03, 0.12, 0.7, 0.4, 0.1, 0.001, 20.0)
	tone(b, 0.0, 0.3, 110.0, 50.0, 0.6, 0, 0.001, 9.0)
	finish(b, 0.75)
	save_wav(d + "break.wav", b)

	b = buf(0.3)
	tone(b, 0.0, 0.25, 980.0, 380.0, 0.5, 1, 0.002, 9.0)
	noise(b, 0.0, 0.12, 0.25, 0.6, 0.3, 0.002, 20.0)
	finish(b, 0.55)
	save_wav(d + "shoot.wav", b)

	b = buf(1.3)
	tone(b, 0.0, 1.2, 72.0, 58.0, 0.8, 2, 0.08, 1.6, 0.04, 7.0)
	tone(b, 0.0, 1.2, 108.0, 86.0, 0.4, 2, 0.1, 1.8, 0.05, 6.0)
	noise(b, 0.0, 1.1, 0.5, 0.12, 0.05, 0.06, 2.0)
	reverb(b, 0.3)
	finish(b, 0.8)
	save_wav(d + "roar.wav", b)

	b = buf(0.6)
	tone(b, 0.0, 0.5, 95.0, 38.0, 1.0, 0, 0.001, 6.5)
	noise(b, 0.0, 0.4, 0.7, 0.3, 0.05, 0.001, 9.0)
	finish(b, 0.85)
	save_wav(d + "slam.wav", b)

	b = buf(0.05)
	tone(b, 0.0, 0.04, 1250.0, 1100.0, 0.5, 0, 0.0005, 70.0)
	finish(b, 0.4)
	save_wav(d + "click.wav", b)

	b = buf(0.06)
	tone(b, 0.0, 0.05, 700.0, 520.0, 0.5, 0, 0.0005, 60.0)
	finish(b, 0.4)
	save_wav(d + "back.wav", b)

	b = buf(0.8)
	bell(b, 0.0, 310.0, 0.6, 0.7, 1.41, 4.0, 5.0)
	bell(b, 0.0, 467.0, 0.4, 0.6, 1.73, 3.0, 6.0)
	noise(b, 0.0, 0.08, 0.5, 0.7, 0.4, 0.001, 40.0)
	finish(b, 0.7)
	save_wav(d + "gate.wav", b)

	b = buf(2.0)
	var mel := [67, 72, 76, 79, 76, 84]
	var tm := [0.0, 0.14, 0.28, 0.42, 0.62, 0.78]
	for k in mel.size():
		bell(b, tm[k], midi(mel[k]), 0.32, 1.1, 2.0, 1.4, 3.0)
	for nn in [60, 64, 67]:
		pad(b, 0.6, 0.8, midi(nn), 0.15, 0.1, 0.9, 0.15)
	reverb(b, 0.4)
	finish(b, 0.65)
	save_wav(d + "complete.wav", b)

	b = buf(0.5)
	tone(b, 0.0, 0.45, 520.0, 1040.0, 0.35, 0, 0.05, 4.0)
	tone(b, 0.05, 0.4, 780.0, 1560.0, 0.2, 0, 0.05, 5.0)
	finish(b, 0.45)
	save_wav(d + "heal.wav", b)

	b = buf(0.4)
	for k in 10:
		noise(b, k * 0.03, 0.05, 0.4, 0.8, 0.5, 0.001, 40.0, true)
	noise(b, 0.0, 0.3, 0.4, 0.2, 0.05, 0.01, 8.0)
	finish(b, 0.55)
	save_wav(d + "crumble.wav", b)

	b = buf(0.6)
	noise(b, 0.0, 0.5, 0.9, 0.5, 0.05, 0.003, 6.0)
	for k in 5:
		tone(b, 0.08 + k * 0.07, 0.05, 900.0 + rng.randf() * 600.0, 400.0, 0.2, 0, 0.002, 30.0)
	finish(b, 0.6)
	save_wav(d + "splash.wav", b)

	b = buf(0.5)
	noise(b, 0.0, 0.45, 0.9, 0.1, 0.5, 0.15, 3.0, true)
	tone(b, 0.0, 0.45, 300.0, 520.0, 0.15, 1, 0.1, 3.0)
	finish(b, 0.5)
	save_wav(d + "swoop.wav", b)

	b = buf(2.6)
	noise(b, 0.0, 2.2, 1.0, 0.5, 0.03, 0.002, 1.8)
	tone(b, 0.0, 2.2, 300.0, 40.0, 0.6, 2, 0.01, 1.4)
	for k in 8:
		noise(b, 0.1 + k * 0.2, 0.15, 0.5, 0.7, 0.2, 0.001, 15.0)
	bell(b, 0.6, midi(76), 0.25, 1.8, 3.5, 2.0, 2.0)
	reverb(b, 0.45, 1.3)
	finish(b, 0.85)
	save_wav(d + "boss_die.wav", b)

	b = buf(0.45)
	tone(b, 0.0, 0.4, 300.0, 1400.0, 0.4, 1, 0.01, 3.0, 0.05, 25.0)
	noise(b, 0.0, 0.3, 0.2, 0.9, 0.8, 0.02, 6.0, true)
	finish(b, 0.5)
	save_wav(d + "teleport.wav", b)


# ============================================================ music

## Renders a loop of `bars` bars; anything that rings past the end wraps to the start.
func _track(name: String, bpm: float, bars: int, seed_v: int, writer: Callable, rev: float = 0.35, rev_size: float = 1.2) -> void:
	rng.seed = seed_v
	var beat := 60.0 / bpm
	var length := bars * 4 * beat
	var b := buf(length + 4.0)
	writer.call(b, beat, bars)
	# fold the tail back onto the start so the loop point is seamless
	var n := int(length * SR)
	for i in range(n, b.size()):
		b[i - n] += b[i]
	b.resize(n)
	reverb(b, rev, rev_size, true)
	finish(b, 0.8)
	save_wav("res://audio/music/%s.wav" % name, b, true)


func _music() -> void:
	_track("calm", 66.0, 16, 11, _w_calm, 0.4)
	_track("deep", 60.0, 16, 22, _w_deep, 0.5, 1.4)
	_track("ruins", 72.0, 16, 33, _w_ruins, 0.35)
	_track("throne", 64.0, 16, 44, _w_throne, 0.45, 1.3)
	_track("boss", 132.0, 16, 55, _w_boss, 0.2, 0.9)
	_track("sanctuary", 70.0, 16, 66, _w_sanctuary, 0.45, 1.3)


func _w_calm(b: PackedFloat32Array, beat: float, bars: int) -> void:
	var chords := [[50, 57, 62, 65], [46, 58, 62, 65], [41, 57, 60, 65], [48, 55, 60, 64]]
	for bar in bars:
		var ch: Array = chords[(bar / 2) % 4]
		var t := bar * 4 * beat
		if bar % 2 == 0:
			for nn in ch:
				pad(b, t, 8 * beat - 0.3, midi(nn), 0.055)
			tone(b, t, 8 * beat, midi(ch[0] - 12), midi(ch[0] - 12), 0.18, 1, 0.3, 0.25)
		for q in 8:
			if rng.randf() < (0.35 if bar < 4 else 0.6):
				var nn2: int = ch[rng.randi() % ch.size()] + 12 * (1 + rng.randi() % 2)
				bell(b, t + q * beat * 0.5, midi(nn2), 0.07, 1.8, 3.5, 1.2, 2.2)
	# a simple melody in the second half
	var mel := [74, 72, 69, 70, 69, 65, 67, 69]
	for k in mel.size():
		var t2 := (8 + k) * 4 * beat
		tone(b, t2, beat * 2.5, midi(mel[k]), midi(mel[k]), 0.07, 1, 0.08, 0.9, 0.006, 5.0)


func _w_deep(b: PackedFloat32Array, beat: float, bars: int) -> void:
	var chords := [[45, 52, 57, 60], [41, 53, 57, 60], [40, 52, 55, 59], [45, 52, 57, 64]]
	var length := bars * 4 * beat
	tone(b, 0.0, length, midi(33), midi(33), 0.16, 0, 2.0, 0.0, 0.004, 0.2)
	tone(b, 0.0, length, midi(40), midi(40), 0.07, 0, 2.0, 0.0, 0.003, 0.13)
	var penta := [69, 72, 74, 76, 79, 81, 84]
	for bar in bars:
		var ch: Array = chords[(bar / 2) % 4]
		var t := bar * 4 * beat
		if bar % 2 == 0:
			for nn in ch:
				pad(b, t, 8 * beat - 0.5, midi(nn), 0.045, 2.0, 2.0, 0.08)
		for q in 4:
			if rng.randf() < 0.45:
				bell(b, t + q * beat + rng.randf() * 0.1, midi(penta[rng.randi() % penta.size()] + 12), 0.06, 2.4, 2.76, 1.5, 1.6)
		if rng.randf() < 0.5:
			# water drip
			tone(b, t + rng.randf() * 3.0 * beat, 0.09, 1800.0, 700.0, 0.05, 0, 0.001, 30.0)


func _w_ruins(b: PackedFloat32Array, beat: float, bars: int) -> void:
	var chords := [[40, 47, 52, 55], [41, 48, 53, 57], [40, 47, 52, 55], [38, 50, 53, 57]]
	for bar in bars:
		var ch: Array = chords[(bar / 2) % 4]
		var t := bar * 4 * beat
		if bar % 2 == 0:
			for nn in ch:
				pad(b, t, 8 * beat - 0.3, midi(nn), 0.05, 1.0, 1.4, 0.1)
		for e in 8:
			var acc := 1.0 if e % 4 == 0 else 0.6
			tone(b, t + e * beat * 0.5, beat * 0.45, midi(ch[0] - 12), midi(ch[0] - 12), 0.12 * acc, 1, 0.01, 6.0)
		if bar % 4 == 3:
			tone(b, t + 3.5 * beat, 0.4, 110.0, 70.0, 0.25, 0, 0.002, 7.0)
	var mel := [64, 65, 67, 65, 64, 62, 64, 59]
	for k in mel.size():
		var t2 := (8 + k) * 4 * beat + beat
		tone(b, t2, beat * 2.8, midi(mel[k] - 12), midi(mel[k] - 12), 0.09, 2, 0.15, 0.6, 0.008, 4.5)


func _w_throne(b: PackedFloat32Array, beat: float, bars: int) -> void:
	var chords := [[48, 55, 60, 63], [44, 56, 60, 63], [41, 53, 56, 60], [43, 55, 59, 62]]
	for bar in bars:
		var ch: Array = chords[(bar / 2) % 4]
		var t := bar * 4 * beat
		if bar % 2 == 0:
			for nn in ch:
				organ(b, t, 8 * beat - 0.4, midi(nn), 0.03)
			tone(b, t, 8 * beat, midi(ch[0] - 12), midi(ch[0] - 12), 0.16, 1, 0.5, 0.2)
		bell(b, t, midi(ch[3] + 12), 0.06, 2.6, 1.0, 0.8, 1.4)
		if rng.randf() < 0.5:
			bell(b, t + 2 * beat, midi(ch[1] + 24), 0.04, 2.0, 3.5, 1.2, 2.0)


func _w_boss(b: PackedFloat32Array, beat: float, bars: int) -> void:
	var chords := [[49, 56, 61, 64], [45, 57, 61, 64], [47, 54, 59, 63], [44, 56, 60, 63]]
	for bar in bars:
		var ch: Array = chords[bar % 4]
		var t := bar * 4 * beat
		for q in 4:
			if q % 2 == 0:
				kick(b, t + q * beat, 0.5)
			else:
				snare(b, t + q * beat, 0.3)
			hat(b, t + q * beat + beat * 0.5, 0.18)
			hat(b, t + q * beat, 0.1)
		if bar % 4 == 3:
			kick(b, t + 3.5 * beat, 0.4)
		for e in 8:
			var root: int = ch[0] - 12 + (12 if e % 4 == 3 else 0)
			tone(b, t + e * beat * 0.5, beat * 0.42, midi(root), midi(root), 0.17, 2, 0.005, 7.0)
		for nn in ch:
			pad(b, t, 4 * beat - 0.15, midi(nn), 0.03, 0.05, 0.3, 0.2)
	var motif := [73, 76, 75, 73, 71, 73, 68, 71]
	for half in 2:
		if half == 0:
			continue
		for k in motif.size():
			var t2 := (8 + k) * 4 * beat
			tone(b, t2, beat * 1.6, midi(motif[k]), midi(motif[k]), 0.08, 3, 0.02, 1.2, 0.008, 6.0)
			tone(b, t2 + beat * 2, beat * 1.6, midi(motif[k] - 5), midi(motif[k] - 5), 0.06, 3, 0.02, 1.4)


func _w_sanctuary(b: PackedFloat32Array, beat: float, bars: int) -> void:
	var chords := [[41, 53, 57, 60, 64], [40, 52, 55, 60], [38, 50, 53, 57], [46, 53, 58, 62]]
	for bar in bars:
		var ch: Array = chords[(bar / 2) % 4]
		var t := bar * 4 * beat
		if bar % 2 == 0:
			for nn in ch:
				pad(b, t, 8 * beat - 0.3, midi(nn), 0.045, 1.5, 1.6, 0.1)
				tone(b, t, 8 * beat, midi(nn + 12), midi(nn + 12), 0.012, 0, 1.5, 0.15, 0.006, 4.8)
			tone(b, t, 8 * beat, midi(ch[0] - 12), midi(ch[0] - 12), 0.15, 1, 0.4, 0.2)
		for e in 8:
			var arp: int = ch[(e + bar) % ch.size()] + 24
			if e % 2 == 0 or rng.randf() < 0.4:
				bell(b, t + e * beat * 0.5, midi(arp), 0.05, 1.6, 2.0, 1.0, 2.4)
