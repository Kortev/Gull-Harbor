extends Node
## The VHF: everything said over it (Dale's calls, ui/tips.gd) goes through a Radio bus that makes it sound like one:
## the lows and highs cut off, a bit of crunch, squashed flat. A call opens with the squelch breaking, hisses under
## the voice, and closes with the squelch tail and a roger beep.
##
## Voices: a recording at res://audio/voice/<who>/<line>.ogg (or .wav) plays through the bus when that line is said
## (docs/VOICE_LINES.md lists them, what to say and how). Record it dry, close to the mic: the bus does the radio.
## No recording yet: just the squelch, the hiss for as long as the words are up, and the tail.

const Sfx := preload("res://audio/sfx.gd")
const BUS := "Radio"
const VOICES := "res://audio/voice/"
const RATE := 22050

var _hiss: Node               # the static bed through the bus, up while a call's open
var _voice: AudioStreamPlayer
var _open := false
var _burst: AudioStreamWAV
var _tail: AudioStreamWAV


func _ready() -> void:
	_make_bus()
	_burst = _noise(0.16, 0.9, 0.0)
	_tail = _noise(0.24, 0.7, 1.0)
	_voice = AudioStreamPlayer.new()
	_voice.bus = BUS
	_voice.volume_db = 2.0
	add_child(_voice)
	_hiss = Sfx.loop(self, "collar.static")
	if _hiss:
		_hiss.set("bus", BUS)


## The Radio bus, once a run: a VHF handset's band (about 300 Hz to 3 kHz), crunch, and a hard squash.
static func _make_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Effects" if AudioServer.get_bus_index("Effects") >= 0 else "Master")   # (core/settings.gd)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 320.0
	AudioServer.add_bus_effect(i, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 2900.0
	AudioServer.add_bus_effect(i, lp)
	var mid := AudioEffectEQ6.new()        # (the honk a little speaker has, round 1.5 kHz)
	mid.set_band_gain_db(3, 5.0)
	AudioServer.add_bus_effect(i, mid)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.42
	dist.pre_gain = 4.0
	dist.post_gain = -6.0
	AudioServer.add_bus_effect(i, dist)
	var squash := AudioEffectCompressor.new()
	squash.threshold = -22.0
	squash.ratio = 8.0
	squash.gain = 6.0
	AudioServer.add_bus_effect(i, squash)


## A call: the squelch opens, `who`'s recording of `line` plays if there is one, the hiss runs `seconds` (or as long as
## the recording), then the tail. Returns how long it runs (s).
func call_in(who: String, line: String, seconds: float) -> float:
	var clip := _clip(who, line)
	var length := seconds
	if clip != null:
		length = maxf(clip.get_length() + 0.3, 1.0)
	_play(_burst, 0.0, -4.0)
	_open = true
	Sfx.fade(_hiss, 0.22, 0.12)
	if clip != null:
		_voice.stream = clip
		get_tree().create_timer(0.18).timeout.connect(_voice.play)
	get_tree().create_timer(length).timeout.connect(_close)
	return length


func _close() -> void:
	if not _open:
		return
	_open = false
	Sfx.fade(_hiss, 0.0, 0.15)
	_play(_tail, 0.0, -6.0)
	# the roger beep, just after
	get_tree().create_timer(0.2).timeout.connect(func() -> void: _play(_beep(), 0.0, -14.0))


## Whether there's a recording for `line`.
static func has_voice(who: String, line: String) -> bool:
	return _path(who, line) != ""


static func _path(who: String, line: String) -> String:
	for ext in [".ogg", ".wav", ".mp3"]:
		var p: String = VOICES + who + "/" + line + ext
		if ResourceLoader.exists(p):
			return p
	return ""


func _clip(who: String, line: String) -> AudioStream:
	var p := _path(who, line)
	return load(p) as AudioStream if p != "" else null


func _play(s: AudioStream, delay: float, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = BUS
	p.volume_db = db
	p.finished.connect(p.queue_free)
	add_child(p)
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(p.play)
	else:
		p.play()


## White noise `seconds` long at `loud`, its envelope a quick break (`fall` 0) or a long fall away (`fall` 1).
static func _noise(seconds: float, loud: float, fall: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	for i in n:
		var k := float(i) / float(n)
		var env := lerpf(1.0 - k * k * k, pow(1.0 - k, 2.0), fall) * minf(1.0, k * 60.0)
		var v := rng.randf_range(-1.0, 1.0) * loud * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## The roger beep: a short two-tone chirp.
static func _beep() -> AudioStreamWAV:
	var n := int(0.12 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var k := float(i) / float(n)
		var f := 1300.0 if k < 0.5 else 1750.0
		ph += TAU * f / RATE
		var env := minf(1.0, k * 40.0) * minf(1.0, (1.0 - k) * 40.0)
		data.encode_s16(i * 2, int(sin(ph) * 0.5 * env * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
