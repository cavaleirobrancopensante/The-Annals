class_name Synth
extends RefCounted
## Makes sound from nothing: each track is rendered from its recipe (data/music/tracks.json), and each
## sound effect from a short description here. Mono, 22050 Hz, 16 bit. Rendering is done once per play.

const RATE := 22050
const FADE := 0.6

## How long each sound effect is, so its buffer is big enough before it is written.
const EFFECT_SECONDS := {"click": 0.1, "chime": 2.0, "bell": 3.2, "page": 0.5, "thunder": 3.0,
		"clash": 0.6, "horn": 1.3, "snuff": 0.5, "door": 1.0, "error": 0.4}

const MODES := {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"phrygian": [0, 1, 3, 5, 7, 8, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10],
}


static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## A looping music stream for a track recipe.
static func track(recipe: Dictionary) -> AudioStreamWAV:
	return stream(track_pcm(recipe), true)


## The raw 16-bit sound of a track. Safe to call on another thread: it creates no engine objects.
static func track_pcm(recipe: Dictionary) -> PackedByteArray:
	var seconds := float(recipe.get("seconds", 40))
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(recipe.get("seed", 1))
	var root := int(recipe.get("root", 50))
	var mode: Array = MODES.get(str(recipe.get("mode", "major")), MODES["major"])
	var beat := 60.0 / float(recipe.get("tempo", 72))

	_texture(buf, str(recipe.get("texture", "none")), root, rng)
	_bed(buf, root, mode, beat, seconds, str(recipe.get("voice", "harp")), rng)
	_melody(buf, root, mode, beat, seconds, str(recipe.get("voice", "harp")), rng)
	return _pcm(buf, true)


## A short sound effect by name. Unknown names give silence.
static func effect(name: String) -> AudioStreamWAV:
	return stream(effect_pcm(name), false)


static func effect_pcm(name: String) -> PackedByteArray:
	var buf := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = name.hash()
	buf.resize(int(EFFECT_SECONDS.get(name, 0.1) * RATE))
	match name:
		"click":
			_tone(buf, 0.0, 0.05, 1480.0, 0.25, 0.0, rng)
		"chime":
			_tone(buf, 0.0, 1.6, hz(81), 0.35, 0.6, rng)
			_tone(buf, 0.18, 1.4, hz(88), 0.25, 0.6, rng)
		"bell":
			for k in 3:
				_bell(buf, k * 0.9, hz(45), 0.55, rng)
		"page":
			_noise(buf, 0.0, 0.35, 0.18, 0.02, rng)
		"thunder":
			_noise(buf, 0.0, 2.8, 0.7, 0.002, rng)
		"clash":
			_noise(buf, 0.0, 0.12, 0.5, 0.5, rng)
			_tone(buf, 0.0, 0.5, hz(96), 0.25, 0.2, rng)
		"horn":
			_tone(buf, 0.0, 1.2, hz(38), 0.35, 0.0, rng)
			_tone(buf, 0.0, 1.2, hz(45), 0.2, 0.0, rng)
		"snuff":
			_noise(buf, 0.0, 0.4, 0.3, 0.05, rng)
		"door":
			_sweep(buf, 0.0, 0.9, 190.0, 120.0, 0.2, rng)
			_noise(buf, 0.0, 0.9, 0.06, 0.01, rng)
		"error":
			_tone(buf, 0.0, 0.32, 110.0, 0.4, 0.0, rng)
		_:
			buf.resize(RATE / 10)
	return _pcm(buf, false)


# --- Music ----------------------------------------------------------------

static func _texture(buf: PackedFloat32Array, kind: String, root: int, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	match kind:
		"wind":
			var y := 0.0
			for i in n:
				y += (rng.randf() * 2.0 - 1.0 - y) * 0.02
				var swell := 0.55 + 0.45 * sin(TAU * 0.07 * i / RATE)
				buf[i] += y * 2.2 * swell * 0.5
		"rain":
			var prev := 0.0
			for i in n:
				var x := rng.randf() * 2.0 - 1.0
				buf[i] += (x - prev) * 0.12
				prev = x
		"fire":
			var crackle := 0.0
			for i in n:
				if rng.randf() < 0.0009:
					crackle = 0.25 + rng.randf() * 0.25
				buf[i] += crackle * (rng.randf() * 2.0 - 1.0) * 0.5
				crackle *= 0.996
		"sea":
			var y2 := 0.0
			for i in n:
				y2 += (rng.randf() * 2.0 - 1.0 - y2) * 0.01
				var wave := 0.5 + 0.5 * sin(TAU * 0.11 * i / RATE)
				buf[i] += y2 * 3.0 * wave * 0.5
		"bog":
			var y3 := 0.0
			for i in n:
				y3 += (rng.randf() * 2.0 - 1.0 - y3) * 0.004
				buf[i] += y3 * 2.5 * 0.5 + sin(TAU * hz(root - 24) * i / RATE) * 0.05
		"hum":
			for i in n:
				var t := float(i) / RATE
				buf[i] += (sin(TAU * 50.0 * t) * 0.07 + sin(TAU * 100.0 * t) * 0.04 + sin(TAU * 150.0 * t) * 0.02)
		"hollow":
			for i in n:
				var t2 := float(i) / RATE
				buf[i] += sin(TAU * hz(root - 29) * t2) * 0.06 + sin(TAU * hz(root - 28.4) * t2) * 0.06


## The sustained chords: a drone on the root and the fifth, and a chord each bar.
static func _bed(buf: PackedFloat32Array, root: int, mode: Array, beat: float, seconds: float,
		voice: String, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	if voice == "organ" or voice == "chant" or voice == "bells":
		var f1 := hz(root - 24)
		var f2 := hz(root - 17)
		for i in n:
			var t := float(i) / RATE
			var breath := 0.7 + 0.3 * sin(TAU * 0.05 * t)
			buf[i] += (sin(TAU * f1 * t) * 0.09 + sin(TAU * f2 * t) * 0.06) * breath
	var bar := beat * 4.0
	var t0 := 0.0
	while t0 < seconds - bar:
		var step: int = [0, 3, 4, 5][rng.randi_range(0, 3)]
		var chord := [mode[step % 7], mode[(step + 2) % 7], mode[(step + 4) % 7]]
		for k in 3:
			var midi: int = root - 12 + int(chord[k]) + (12 if k == 2 else 0)
			if voice == "harp":
				continue
			_organ(buf, t0, bar, hz(midi), 0.035)
		t0 += bar


## A line of notes over the chords, its shape set by the voice.
static func _melody(buf: PackedFloat32Array, root: int, mode: Array, beat: float, seconds: float,
		voice: String, rng: RandomNumberGenerator) -> void:
	var t := beat * 2.0
	var deg := 7
	while t < seconds - 3.0:
		var lengths := [0.5, 1.0, 1.0, 2.0]
		var dur: float = beat * lengths[rng.randi_range(0, 3)]
		deg = clampi(deg + [-2, -1, -1, 1, 1, 2][rng.randi_range(0, 5)], 0, 13)
		var midi: int = root + int(mode[deg % 7]) + 12 * (deg / 7)
		if rng.randf() > 0.2:
			match voice:
				"bells":
					_bell(buf, t, hz(midi + 12), 0.18, rng)
				"chant":
					_organ(buf, t, dur * 1.2, hz(midi + 12), 0.12)
				"harp":
					_pluck(buf, t, hz(midi + 12), 0.2, 6.0)
				_:
					_pluck(buf, t, hz(midi + 12), 0.22, 3.5)
		t += dur


static func _pluck(buf: PackedFloat32Array, at: float, f: float, amp: float, decay: float) -> void:
	var start := int(at * RATE)
	var len := int(minf(2.5, 3.0 / decay) * RATE)
	for j in len:
		var i := start + j
		if i >= buf.size():
			break
		var t := float(j) / RATE
		buf[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * exp(-decay * t) * amp


static func _organ(buf: PackedFloat32Array, at: float, dur: float, f: float, amp: float) -> void:
	var start := int(at * RATE)
	var len := int(dur * RATE)
	for j in len:
		var i := start + j
		if i >= buf.size():
			break
		var t := float(j) / RATE
		var env := minf(1.0, t / 0.4) * minf(1.0, (dur - t) / 0.4)
		buf[i] += (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t) + 0.15 * sin(TAU * f * 3.0 * t)) * env * amp


static func _bell(buf: PackedFloat32Array, at: float, f: float, amp: float, rng: RandomNumberGenerator) -> void:
	var start := int(at * RATE)
	var len := int(3.0 * RATE)
	for j in len:
		var i := start + j
		if i >= buf.size():
			break
		var t := float(j) / RATE
		buf[i] += (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.76 * t) * exp(-t * 2.0)
				+ 0.3 * sin(TAU * f * 5.4 * t) * exp(-t * 3.5)) * exp(-t * 1.6) * amp


# --- Sound effects --------------------------------------------------------

static func _tone(buf: PackedFloat32Array, at: float, dur: float, f: float, amp: float, decay: float,
		rng: RandomNumberGenerator) -> void:
	var start := int(at * RATE)
	var len := int(dur * RATE)
	for j in len:
		var i := start + j
		if i >= buf.size():
			buf.resize(i + 1)
		var t := float(j) / RATE
		var env := exp(-t * (decay if decay > 0.0 else 8.0)) * minf(1.0, t / 0.005)
		buf[i] += sin(TAU * f * t) * env * amp


static func _noise(buf: PackedFloat32Array, at: float, dur: float, amp: float, decay: float,
		rng: RandomNumberGenerator) -> void:
	var start := int(at * RATE)
	var len := int(dur * RATE)
	var y := 0.0
	for j in len:
		var i := start + j
		if i >= buf.size():
			buf.resize(i + 1)
		var t := float(j) / RATE
		y += (rng.randf() * 2.0 - 1.0 - y) * 0.3
		buf[i] += y * amp * exp(-t / maxf(decay, 0.001) * 0.5)


static func _sweep(buf: PackedFloat32Array, at: float, dur: float, f0: float, f1: float, amp: float,
		rng: RandomNumberGenerator) -> void:
	var start := int(at * RATE)
	var len := int(dur * RATE)
	var phase := 0.0
	for j in len:
		var i := start + j
		if i >= buf.size():
			buf.resize(i + 1)
		var k := float(j) / len
		phase += TAU * lerpf(f0, f1, k) / RATE
		buf[i] += sin(phase) * amp * sin(PI * k)


## Fades the ends (so a track loops without a click), scales to a safe level, and gives 16-bit bytes.
static func _pcm(buf: PackedFloat32Array, loop: bool) -> PackedByteArray:
	var n := buf.size()
	var fade := int(FADE * RATE)
	var peak := 0.0001
	for i in n:
		if loop:
			if i < fade:
				buf[i] *= float(i) / fade
			elif i > n - fade:
				buf[i] *= float(n - i) / fade
		peak = maxf(peak, absf(buf[i]))
	var gain := 0.8 / peak if loop else 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	return bytes


## The engine's stream from 16-bit bytes. A looping one plays its whole length again and again.
static func stream(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = bytes.size() / 2
	return s
