extends AudioStreamPlayer3D
## A voice on the VHF, from the radio on the dash: a squelch of static, then a man talking (made up as it plays:
## syllables of buzzing vowels, his pitch wandering, through a radio's thin band and hiss), and the squelch as he lets
## go of the key. You can't make out a word, the way you can't over a boat's radio; the card on screen
## (ui/tips.gd) says what he said. Further from the dash he's quieter, like a real radio.

const RATE := 22050.0
const TABLE := 256
## A vowel's two formants (Hz): ah, eh, ee, oh, oo.
const VOWELS := [Vector2(730, 1090), Vector2(530, 1840), Vector2(290, 2250), Vector2(570, 840), Vector2(320, 900)]
## His voice: the pitch he talks round (Hz), syllables a second.
const PITCH := 112.0
const SYLLABLES := 4.6

var _tables: Array[PackedFloat32Array] = []
## What's left to say: [kind, seconds, pitch, vowel] ("squelch", "syllable", "gap"), and where we are in the first.
var _plan: Array = []
var _t := 0.0
var _phase := 0.0
var _playback: AudioStreamGeneratorPlayback
var _lp := 0.0
var _hp := 0.0
var _prev := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	stream = gen
	unit_size = 3.0
	max_distance = 30.0
	volume_db = -3.0
	# one period of each vowel, built from its harmonics weighted round the formants (and a little buzz under them)
	for v: Vector2 in VOWELS:
		var tab := PackedFloat32Array()
		tab.resize(TABLE)
		var peak := 0.0
		for k in range(1, 34):
			var f := PITCH * k
			var a := exp(-pow((f - v.x) / 110.0, 2.0)) + 0.6 * exp(-pow((f - v.y) / 160.0, 2.0)) + 0.05 / k
			for i in TABLE:
				tab[i] += a * sin(TAU * k * i / TABLE)
		for i in TABLE:
			peak = maxf(peak, absf(tab[i]))
		for i in TABLE:
			tab[i] /= peak
		_tables.append(tab)


## Talks for about `words` words (and keys the mike, and lets go).
func say(words: int) -> void:
	_plan = [["squelch", 0.14, 0.0, 0]]
	var n := clampi(int(words * 1.4), 4, 60)
	for i in n:
		var f0 := PITCH * randf_range(0.85, 1.25) * (1.0 - 0.15 * float(i % 7) / 7.0)      # (falling through a phrase)
		_plan.append(["syllable", randf_range(0.6, 1.4) / SYLLABLES, f0, randi() % VOWELS.size()])
		if i % 7 == 6:
			_plan.append(["gap", randf_range(0.2, 0.35), 0.0, 0])        # (a breath between phrases)
		elif randf() < 0.3:
			_plan.append(["gap", randf_range(0.03, 0.08), 0.0, 0])
	_plan.append(["squelch", 0.1, 0.0, 0])
	_t = 0.0
	if not playing:
		play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


## Still on the air.
func talking() -> bool:
	return not _plan.is_empty()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	for i in n:
		var s := _sample() if not _plan.is_empty() else 0.0
		_playback.push_frame(Vector2(s, s))


func _sample() -> float:
	var seg: Array = _plan[0]
	var dur := float(seg[1])
	var k := _t / dur
	var s := 0.0
	var hiss := randf_range(-1.0, 1.0)
	match str(seg[0]):
		"squelch":
			s = hiss * 0.5
		"syllable":
			var env := smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.75, 1.0, k))
			var f0 := float(seg[2]) * (1.0 + 0.04 * sin(_t * 30.0)) * (1.05 - 0.1 * k)
			_phase = fmod(_phase + f0 / RATE, 1.0)
			var tab: PackedFloat32Array = _tables[int(seg[3])]
			s = tab[int(_phase * TABLE) % TABLE] * env * 0.8 + hiss * 0.04
		_:
			s = hiss * 0.04
	_t += 1.0 / RATE
	if _t >= dur:
		_t = 0.0
		_plan.pop_front()
	# the radio: no lows, no highs, a bit overdriven
	_lp += (s - _lp) * 0.45
	_hp = 0.93 * (_hp + _lp - _prev)
	_prev = _lp
	var o := _hp * 1.6
	return o / (1.0 + absf(o))
