extends RefCounted
## The crew's breath, made here as the air horn's blast is (vs/horn.gd): no words, just the noises a body makes. A
## gasp (coming up out of the sea: a sharp, rising suck of air through an open mouth, a catch in the throat at the
## end), and a grunt (winding up to shove someone: a short voiced "hnh" through the nose, the chest tightening).
## Each is breathy noise through a mouth-shaped band (two formants that move as the mouth does) over a low buzz
## from the throat, each made once and shared.

const RATE := 22050

static var _gasp: AudioStreamWAV
static var _grunt: AudioStreamWAV


## Coming up for air: 0.45 s, mostly breath, the pitch of the suck rising as the mouth opens.
static func gasp() -> AudioStreamWAV:
	if _gasp == null:
		_gasp = _make(0.45, 0.25, Vector2(700.0, 1300.0), Vector2(1700.0, 2400.0), 210.0, 260.0, 0.035, 0.18)
	return _gasp


## Winding up: 0.28 s, mostly voice, low and tight.
static func grunt() -> AudioStreamWAV:
	if _grunt == null:
		_grunt = _make(0.28, 0.8, Vector2(500.0, 430.0), Vector2(1100.0, 950.0), 135.0, 118.0, 0.02, 0.09)
	return _grunt


## `seconds` long; `voiced` 0 (all breath) .. 1 (all throat); the two formants (Hz) from x to y over it; the
## throat's pitch from `f0` to `f1`; how fast it starts and dies (s).
static func _make(seconds: float, voiced: float, f1: Vector2, f2: Vector2, f0: float, f_end: float, attack: float,
		release: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 1000.0 + seconds * 77.0)
	# two band-passes (state-variable filters), one per formant, fed the same source
	var lo := [0.0, 0.0]
	var bp := [0.0, 0.0]
	var ph := 0.0
	var peak := 0.0
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var k := float(i) / float(n)
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * minf(1.0, (seconds - t) / release)
		ph = fmod(ph + lerpf(f0, f_end, k) / RATE, 1.0)
		# the throat: a soft buzz (a pulse with its corners rounded)
		var buzz := pow(maxf(0.0, sin(ph * TAU)), 3.0) * 2.0 - 0.6
		var src := lerpf(rng.randf_range(-1.0, 1.0), buzz, voiced)
		var v := 0.0
		for j in 2:
			var fc := lerpf(f1.x, f1.y, k) if j == 0 else lerpf(f2.x, f2.y, k)
			var g := 2.0 * sin(PI * fc / RATE)
			var q := 0.18 if j == 0 else 0.25
			lo[j] = float(lo[j]) + g * float(bp[j])
			var hi := src - float(lo[j]) - q * float(bp[j])
			bp[j] = float(bp[j]) + g * hi
			v += float(bp[j]) * (1.0 if j == 0 else 0.6)
		v *= env
		out[i] = v
		peak = maxf(peak, absf(v))
	for i in n:
		data.encode_s16(i * 2, int(clampf(out[i] / maxf(peak, 0.001) * 0.8, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s
