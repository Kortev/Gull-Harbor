extends AudioStreamPlayer
## A voice on the VHF with no recording behind it (ui/radio.gd plays this through its Radio bus, between the squelch
## breaking and the tail): a man talking, made up as it plays (syllables of buzzing vowels, his pitch wandering and
## falling through each phrase, a breath between phrases), with a little hiss. You can't make out a word, the way you
## can't over a boat's radio; the card on screen (ui/tips.gd) says what he said. The bus makes it a radio: no lows, no
## highs, a crunch, squashed flat. A recording, when there is one (docs/VOICE_LINES.md), plays instead.

const RATE := 22050.0
const TABLE := 256
## A vowel's two formants (Hz): ah, eh, ee, oh, oo.
const VOWELS := [Vector2(730, 1090), Vector2(530, 1840), Vector2(290, 2250), Vector2(570, 840), Vector2(320, 900)]
## His voice: the pitch he talks round (Hz), syllables a second.
const PITCH := 112.0
const SYLLABLES := 4.6

var _tables: Array[PackedFloat32Array] = []
## What's left to say: [kind, seconds, pitch, vowel] ("syllable", "gap"), and where we are in the first.
var _plan: Array = []
var _t := 0.0
var _phase := 0.0
var _playback: AudioStreamGeneratorPlayback
var _quiet := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	stream = gen
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


## Talks for about `words` words, after `lead` s (the squelch breaking first); how long that takes, all told (s).
func say(words: int, lead := 0.0) -> float:
	_plan = []
	var n := clampi(int(words * 1.4), 4, 60)
	var length := lead
	if lead > 0.0:
		_plan.append(["gap", lead, 0.0, 0])
	for i in n:
		var f0 := PITCH * randf_range(0.85, 1.25) * (1.0 - 0.15 * float(i % 7) / 7.0)      # (falling through a phrase)
		var syl := randf_range(0.6, 1.4) / SYLLABLES
		_plan.append(["syllable", syl, f0, randi() % VOWELS.size()])
		length += syl
		var gap := 0.0
		if i % 7 == 6:
			gap = randf_range(0.2, 0.35)        # (a breath between phrases)
		elif randf() < 0.3:
			gap = randf_range(0.03, 0.08)
		if gap > 0.0:
			_plan.append(["gap", gap, 0.0, 0])
			length += gap
	_t = 0.0
	if is_inside_tree():
		if not playing:
			play()
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	return length


## Still talking.
func talking() -> bool:
	return not _plan.is_empty()


## Stops mid-word (the call's been cut off).
func hush() -> void:
	_plan.clear()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	if _plan.is_empty() and _quiet > 0.3:
		stop()                    # (said it: nothing to keep making)
		_playback = null
		return
	_quiet = _quiet + _delta if _plan.is_empty() else 0.0
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
	if str(seg[0]) == "syllable":
		var env := smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.75, 1.0, k))
		var f0 := float(seg[2]) * (1.0 + 0.04 * sin(_t * 30.0)) * (1.05 - 0.1 * k)
		_phase = fmod(_phase + f0 / RATE, 1.0)
		var tab: PackedFloat32Array = _tables[int(seg[3])]
		s = tab[int(_phase * TABLE) % TABLE] * env * 0.8 + hiss * 0.04
	else:
		s = hiss * 0.04
	_t += 1.0 / RATE
	if _t >= dur:
		_t = 0.0
		_plan.pop_front()
	return s
