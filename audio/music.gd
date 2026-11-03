extends Node
## The music (an autoload, `Music`), on the Music bus (core/settings.gd's slider): a fish-shed folk band playing one
## song that never stops, the game playing the band. docs/MUSIC_SYSTEM.md is the design; tools/music.py renders it
## into res://music/ and writes audio/music_cues.gd (each cue's files, stems, chords and timing).
##
## Each frame it reads the sea into a plain picture (world()) and hands it to audio/music_state.gd, which says what's
## happening (the section: the title, or out there the sea, the harbour, birds, the fight's three, boatside, landed,
## the race home), each layer's level, and what just happened. Here's the band playing it:
## - the title is its own piece (the theme, its stems by the weather on it); everything after is ONE song: eight-bar
##   passages (sea_a..j, and the theme's halves sea_t1, sea_t2) of one AudioStreamInteractive, each an
##   AudioStreamSynchronized of the same 17 layers, played one after another (each next one picked as the last's
##   final bar begins: never the same twice running, bright or dark by what's happening). What happens never changes
##   the song: it brings its layers up and down on the same chords (a fish on: the heartbeat, the drums, the
##   tension...), and the band plays cues over it on the beat (cue()): the strike's hit, the birds' bells, a fill and
##   the theme for the leader, the hit and the theme when he's in, the race called, home made, casting off.
## - the switches between passages land on the bar in the mixer itself (sample-locked), a half-beat's crossfade at
##   most: never a slow smear; cues start on our own clock (a silent player's position: the mixer's time), each with
##   a silent pre-roll so its hit lands on the line, lead-ins ending exactly on the downbeat. And the clock listens:
##   every bar of the song carries a tiny tick (its "mark" stem, MARK_HZ), the bed plays through a bus of its own
##   (BED_BUS) where it's captured and then filtered out, and each bar the clock's put right on where its tick really
##   was (_listen()), so however long it plays, nothing drifts off the beat.
## - the silences: the scenic ones (casting off, the band lets the song go over SCENIC_FADE s and you sail out to the
##   sea alone, till it's counted back in on the bar on the theme; a rest on a long quiet stretch), a fish lost
##   (HUSH_FADE: everything gone at once), him in the air, the harpoon flying, and the quiet under Rivals' countdown
##   and card. In a storm, its own dark passages, and each lightning strike ducks the band (DIP) into the thunder's
##   hit on the next beat.
## - the mix: all of it down a little while the radio or a voice is on (DUCK_BUSES), with a dip where voices sit (the
##   pocket) rather than more of a drop; muffled underwater; quieter and dulled under the pause card; a limiter last.

const State := preload("res://audio/music_state.gd")
const Cues := preload("res://audio/music_cues.gd")
const DIR := "res://music/"
const BUS := &"Music"
## What's happening out there that the song plays (all of it the one song).
const SONG := ["sea", "harbour", "hunt", "fight", "tired", "leader", "gaff", "afterglow", "race"]
const FIGHT := ["fight", "tired", "leader"]
## Layers that only come in at the top of a PHRASE_BARS phrase (and then over GATE_IN s): the climax's high lead.
const GATED := ["high"]
const PHRASE_BARS := 4
const GATE_IN := 0.12
## A switch asked this close (s) to the grid line it'd land on might land on the next one instead: it waits till the
## line's passed.
const GRID_SAFE := 0.04
## The leader's fill: the jump into the theme's asked this close (s past the fill's length) before the bar it lands
## on; after FILL_WAIT s of no luck (a slow frame rate), without it.
const FILL_SLOP := 0.07
const FILL_WAIT := 6.0
## The mixer takes a switch on the grid a little early (measured: 0-4 ms, 1.8 on average, tools/music_check.py), and
## the next switch counts from where it really came in: our clock takes the same off each time, or it'd drift off the
## bed a little more with every passage of the sea.
const EARLY := 0.0018
## The shortest fade in (beats): a loop coming in at full (the title into the song); and one passage into another,
## on the bar (beats: each one's first sample is its own tail wrapped round, so never a hard cut).
const ENTER := 0.1
const JOIN := 0.5
## The title's and the song's levels (a share).
const LEVEL := {"sea": 1.0, "title": 1.0}
const STING_LEVEL := {"strike": 1.0, "their_on": 0.7, "lead_up": 0.8, "lead_down": 0.8, "countdown": 1.0, "win": 1.0,
		"lose": 1.0, "tie": 1.0, "landed": 1.0, "leader_in": 1.0, "hunt_in": 0.8, "away_in": 0.8, "race_in": 0.9,
		"boatside_end": 0.9, "race_end": 0.9, "title_end": 0.8, "thunder": 1.0, "fight_in": 1.0}
## The cues that play over the others (on their own player), not cutting them.
const SMALL := ["their_on", "lead_up", "lead_down", "hunt_in", "away_in", "race_in", "boatside_end", "race_end",
		"title_end"]
## A fish lost: everything down to nothing over this long (s): quicker than you'd hear as a fade, slow enough not to
## click.
const HUSH_FADE := 0.08
## The scenic silences: the band let go over this long (s), and back in over this long (s) on its bar.
const SCENIC_FADE := 6.0
const SCENIC_IN := 0.12
## Lightning: the band ducked to this share from the flash till the thunder's hit.
const DIP := 0.25
## In a storm, its own passages this much likelier than the rest (and never out of one); in a fight, the fight's.
const STORM_K := 12.0
const FIGHT_K := 20.0
## A fish on: the whole song up to this much louder (dB, by the state's heat): the band playing harder.
const HEAT_DB := 5.0
## While the radio or a voice is on: down to these shares (by whose it is), back up DUCK_HOLD s after they stop; the
## level (dB) on their bus that counts as on; the pocket (dB) cut where voices sit (1 and 3.2 kHz) while they're on,
## and the duck halved with it.
const DUCK_BUSES := {&"Radio": 0.56, &"VoiceRadio": 0.56, &"Voice": 0.7}
const DUCK := 0.56
const DUCK_HOLD := 0.6
const DUCK_AT := -42.0
const POCKET := [-6.0, -4.0]
## Under the pause card (the world held still, ui/menu.gd): the music at this share, dulled to PAUSED_LP Hz;
## underwater, muffled to UNDER_LP Hz.
const PAUSED := 0.4
const PAUSED_LP := 2500.0
const UNDER_LP := 600.0
## Rivals' countdown (vs/vs.gd's COUNT, s): the sting's hit is this far in.
const COUNT := 10.0
## The race home's length (s: sea.gd's and vs.gd's HOME).
const HOME := 360.0
## The clock: a silent loop this long (s), its position the mixer's time.
const CLOCK_LEN := 4.0
## The clock's ear: the bed's own bus (into the Music bus); how far either side of where a bar's due its tick's
## looked for (s), in steps of how many samples, each heard over how many; how much louder than the rest round it
## counts as the tick; how much of its sound is kept (s); and the biggest put-right it trusts (s: more is a mishearing).
const BED_BUS := &"MusicBed"
const MARK_WIN := 0.03
const MARK_STEP := 24
const MARK_N := 96
const MARK_OVER := 6.0
const CAP_KEEP := 0.6
const MARK_TRUST := 0.06

## The section wanted now ("rest": quiet), and the one sounding (a switch lands on the grid, a moment later).
var cue := "rest"
var sounding := "rest"
## The state (audio/music_state.gd): its levels, its events.
var state: State
## The sting playing ("" none).
var sting := ""
## Tests: >0 holds the duck on this many s more, as if the radio were on; a world to play instead of the sea's.
var duck_test := 0.0
var world_test := {}
## What's been played, for the tests: [[audio time, what]] ("clip:<name>" as a switch lands, "sting:<name>",
## the last PLAYED_N.
var played: Array = []
const PLAYED_N := 64
var played_n := 0           # (how many in all)
## Run with -- --music-log=<file>: everything played, and when it was meant to be all but silent ("still:on"/"off"),
## kept whole and written there as JSON when the game closes (tools/music_check.py reads it beside the movie maker's
## .wav).
var _log_to := ""
var _log: Array = []
## (and, with the log on, every bus's peak level each BUS_EVERY s, for tools/loudness.py: [time, {bus: dB}])
var _buses: Array = []
var _bus_t := 0.0
const BUS_EVERY := 0.25
var _still := false

var _bed: AudioStreamPlayer
var _it: AudioStreamInteractive
var _clips := {}            # section -> {index, sync, stems, bpm, bar_beats, loop}
var _rest := 0
var _asked := "rest"        # the clip last asked for
var _start := 0.0           # audio time the sounding clip started
var _landing := {}          # {to, at}: a switch asked, landing at audio time `at`
var _fill_wait := 0.0
var _gate := {}             # stem -> 0..1 (GATED: let in at a phrase)
var _phrase_n := -1
var _stings: Array[AudioStreamPlayer] = []
var _queue: Array = []      # [{name, at, from}]
var _streams := {}          # sting name -> AudioStream
var _seas: Array = []       # the sea's passages (sea_a ...)
var _rng := RandomNumberGenerator.new()
var _sea_was := ""
var _song := ""             # the weather's song playing ("" none: a fight, a jump, the title)
var _form_i := -1           # where in its form
var _passes := {}           # passage -> times played in this song (the arrangement changes with each)
var _arr := {}              # passage -> its arrangement this time through: {stem: share, "^stem": floor}
var _fill := 0.0            # the sounding passage's fill stem, opened for its last bar
var _jump := ""             # on the bar: "leader" (its fill, the theme), "landed" (its hit, the theme), "theme",
                            # "fight" (the strike: into the fight's own, its break)
var _jump_after := 0.0      # (a jump's bar: the first after this)
var _quiet := 1.0           # the scenic silence's gate on the song (1: open)
var _return_at := -1.0      # when the gate opens again (our clock; -1: not asked)
var _dip := 1.0
var _dip_until := -1.0
var _clock: AudioStreamPlayer
var _clock_last := 0.0
var _clock_wraps := 0
var _t := 0.0               # audio time now (s)
var _game_t := 0.0
var _duck := 1.0
var _duck_for := 0.0
var _duck_to := 1.0
var _pocket := 0.0
var _lp := 20000.0
var _hush := 0.0            # 1: hushed
var _level := 1.0           # the bed's section level (LEVEL), eased between sections
var _eq: AudioEffectEQ6
var _lpf: AudioEffectLowPassFilter
var _sea: Node
var _dummy := false         # (no sound card, headless: nothing's mixed, so the clock's the frames')
var _cap: AudioEffectCapture
var _cap_buf := PackedFloat32Array()   # the bed as heard, mono: the last CAP_KEEP s
var _cap_end := 0           # frames heard in all (the last of _cap_buf)
var _cap_c := NAN           # our clock less the ear's (s), averaged
var _mark_ref := NAN        # the offset at the first tick heard since the song came in from the quiet
var _mark_at := -1.0        # the next bar line to listen for (our clock)
## How far the ear's put the clock right, all told (s), and how many ticks it's heard (the tests read them).
var heard := 0
var put_right := 0.0
var _world := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dummy = AudioServer.get_driver_name() == "Dummy"
	state = State.new()
	_build_bed()
	for n: String in Cues.CUES:
		var c: Dictionary = Cues.CUES[n]
		if str(c["kind"]) in ["sting", "filler"]:
			_streams[n] = _ogg(str(c["files"][0]), c)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Sting%d" % i
		p.bus = BUS
		add_child(p)
		_stings.append(p)
	# the clock: silence, looping, its position read each frame
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = 8000
	w.data = PackedByteArray()
	w.data.resize(int(CLOCK_LEN * 8000))
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = int(CLOCK_LEN * 8000)
	_clock = AudioStreamPlayer.new()
	_clock.name = "Clock"
	_clock.stream = w
	_clock.volume_db = -80.0
	_clock.bus = BUS
	add_child(_clock)
	_clock.play()
	_bus_effects.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--music-log="):
			_log_to = a.substr(12)
		elif a == "--music-hud":
			var hud: CanvasLayer = preload("res://audio/music_hud.gd").new()
			hud.set("music", self)
			add_child(hud)


func _ogg(file: String, c: Dictionary) -> AudioStreamOggVorbis:
	var s := load(DIR + file + ".ogg") as AudioStreamOggVorbis
	if s == null:
		return null
	s.loop = bool(c.get("loop", false))
	if float(c.get("bpm", 0.0)) > 0.0:
		s.bpm = float(c["bpm"])
		s.bar_beats = int(c["bar_beats"])
		s.beat_count = int(c["bars"]) * int(c["bar_beats"]) if int(c["bars"]) > 0 else 0
	return s


## The bed: the title and each of the song's passages a clip (its stems in step), the quiet (rest) a clip of
## silence.
func _build_bed() -> void:
	_it = AudioStreamInteractive.new()
	_rng.randomize()
	for n: String in Cues.CUES:
		if n.begins_with("sea_"):
			_seas.append(n)
	_seas.sort()
	var names: Array = ["rest", "title"] + _seas
	_it.clip_count = names.size()
	for i in names.size():
		var n: String = names[i]
		_it.set_clip_name(i, StringName(n))
		if n == "rest":
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_8_BITS
			w.mix_rate = 8000
			w.data = PackedByteArray()
			w.data.resize(8000)
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = 8000
			_it.set_clip_stream(i, w)
			continue
		var c: Dictionary = Cues.CUES.get(n, {})
		if c.is_empty():
			continue
		var sync := AudioStreamSynchronized.new()
		var files: Array = c["files"]
		sync.stream_count = files.size()
		for k in files.size():
			sync.set_sync_stream(k, _ogg(str(files[k]), c))
			sync.set_sync_stream_volume(k, -80.0)
		_it.set_clip_stream(i, sync)
		_clips[n] = {"index": i, "sync": sync, "stems": c["stems"], "bpm": float(c["bpm"]),
				"bar_beats": int(c["bar_beats"]), "loop": bool(c["loop"])}
	_rest = 0
	_it.initial_clip = 0
	for t: Array in _transitions():
		_it.add_transition(_index(t[0]), _index(t[1]), t[2], t[3], t[4], t[5])
	_bed = AudioStreamPlayer.new()
	_bed.name = "Bed"
	_bed.bus = BUS
	_bed.stream = _it
	add_child(_bed)
	_bed.play()


func _index(n: String) -> int:
	if n == "*":
		return AudioStreamInteractive.CLIP_ANY
	for i in _it.clip_count:
		if str(_it.get_clip_name(i)) == n:
			return i
	return AudioStreamInteractive.CLIP_ANY


## [from, to, leave (when), enter (where), fade, fade beats]: the most particular wins. One passage into the next,
## and the jumps into the theme, on the bar with a half-beat's crossfade (JOIN); the title into the song on its bar
## (its ending rings over: title_end); out to the quiet on the beat; back from it over a bar.
func _transitions() -> Array:
	var I := AudioStreamInteractive
	var t: Array = [
		["*", "*", I.TRANSITION_FROM_TIME_NEXT_BAR, I.TRANSITION_TO_TIME_START, I.FADE_CROSS, JOIN],
		["*", "rest", I.TRANSITION_FROM_TIME_NEXT_BEAT, I.TRANSITION_TO_TIME_START, I.FADE_OUT, 2.0],
		["title", "rest", I.TRANSITION_FROM_TIME_NEXT_BEAT, I.TRANSITION_TO_TIME_START, I.FADE_OUT, 4.0],
		["*", "title", I.TRANSITION_FROM_TIME_IMMEDIATE, I.TRANSITION_TO_TIME_START, I.FADE_CROSS, 2.0],
		["rest", "title", I.TRANSITION_FROM_TIME_IMMEDIATE, I.TRANSITION_TO_TIME_START, I.FADE_IN, 2.0],
	]
	for a: String in _seas:
		t.append(["rest", a, I.TRANSITION_FROM_TIME_IMMEDIATE, I.TRANSITION_TO_TIME_START, I.FADE_IN, 4.0])
		t.append(["title", a, I.TRANSITION_FROM_TIME_NEXT_BAR, I.TRANSITION_TO_TIME_START, I.FADE_CROSS, ENTER])
	return t


## (Each transition's leave, for the clock.)
func _leave(from: String, to: String) -> int:
	var best: Array = []
	var score := -1
	for t: Array in _transitions():
		var s := (2 if t[0] == from else (0 if t[0] == "*" else -9)) + (1 if t[1] == to else (0 if t[1] == "*" else -9))
		if s > score:
			score = s
			best = t
	return best[2]


## The Music bus's own effects: the pocket (an EQ), the muffle (a low-pass), a limiter; and the bed's bus into it, with
## the ear on it (a capture) and the tick filtered out after (a notch and two low-passes: the music's low-passed at
## 8 kHz already).
func _bus_effects() -> void:
	var b := AudioServer.get_bus_index(BUS)
	if b < 0:
		return
	if AudioServer.get_bus_index(BED_BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BED_BUS)
		AudioServer.set_bus_send(i, BUS)
		_cap = AudioEffectCapture.new()
		_cap.buffer_length = 0.5
		AudioServer.add_bus_effect(i, _cap)
		var notch := AudioEffectNotchFilter.new()
		notch.cutoff_hz = float(Cues.CUES.get("sea_a", {}).get("mark_hz", 12000.0))
		AudioServer.add_bus_effect(i, notch)
		for k in 2:
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 9000.0
			AudioServer.add_bus_effect(i, lp)
		_bed.bus = BED_BUS
	_eq = AudioEffectEQ6.new()
	_lpf = AudioEffectLowPassFilter.new()
	_lpf.cutoff_hz = 20000.0
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	for e: AudioEffect in [_eq, _lpf, lim]:
		AudioServer.add_bus_effect(b, e)


# ------------------------------------------------------------------ reading

## A layer's loudness now (0..1, before the duck): a stem of the section sounding ("pulse", "drive", ...), or a whole
## section by name (its level while it's the one wanted).
func level(n: String) -> float:
	if _clips.has(n):
		return 1.0 if sounding == n else 0.0
	if n == "sea":
		return 1.0 if sounding.begins_with("sea_") else 0.0
	return state.level(n) * float(_gate.get(n, 1.0))


## The duck now (1: none, DUCK: under the radio).
func duck() -> float:
	return _duck


## Where the sounding clip is: [bar, beat in it] (from 0; -1 when there's no grid: the quiet).
func bar_beat() -> Vector2:
	var c: Dictionary = _clips.get(sounding, {})
	if not c.has("bpm"):
		return Vector2(-1, -1)
	var beat := 60.0 / float(c["bpm"])
	var beats := floorf((_t - _start) / beat + 0.0001)
	return Vector2(floorf(beats / int(c["bar_beats"])), fposmod(beats, int(c["bar_beats"])))


## Audio time now (s).
func now() -> float:
	return _t


## A fish lost (rods.gd says so too; the state sees it for itself): the silence after the line goes.
func hush(seconds: float) -> void:
	state.hush = maxf(state.hush, seconds)


# ------------------------------------------------------------------ the deck whistle (crew/hands.gd)

## Each chord's own notes (pitch classes), and D major's pentatonic for when nothing's on a grid.
const CHORD_TONES := {"D": [2, 6, 9], "G": [7, 11, 2], "A": [9, 1, 4], "Bm": [11, 2, 6], "Em": [4, 7, 11],
		"F#": [6, 10, 1], "C": [0, 4, 7], "Dm": [2, 5, 9], "Am": [9, 0, 4], "F": [5, 9, 0]}
const PENTATONIC := [2, 4, 6, 9, 11]
## The whistle's notes picked from (midi): its sweet two octaves.
const WHISTLE_RANGE := Vector2i(69, 88)


## The chord playing now ("" with nothing on a grid): from the sounding section's chords (audio/music_cues.gd).
func chord_now() -> String:
	var c: Dictionary = Cues.CUES.get(sounding, {})
	var chords: Array = c.get("chords", [])
	if chords.is_empty() or float(c.get("bpm", 0.0)) <= 0.0:
		return ""
	var span := 60.0 / float(c["bpm"]) * int(c.get("chord_beats", 4))
	return str(chords[posmod(int(floorf((_t - _start) / span + 0.0001)), chords.size())])


## The note the deck whistle sounds at `k` (0 .. 1: how far up you're looking): always one of the chord's own notes,
## so whatever you play sits in the band.
func whistle_note(k: float) -> int:
	var tones: Array = CHORD_TONES.get(chord_now(), PENTATONIC)
	var notes: Array[int] = []
	for m in range(WHISTLE_RANGE.x, WHISTLE_RANGE.y + 1):
		if posmod(m, 12) in tones:
			notes.append(m)
	return notes[clampi(int(k * notes.size()), 0, notes.size() - 1)]


## The next line of what's playing, `div` to a beat (2: the next eighth), in now()'s time; now if it's off the grid.
func next_tick(div := 2) -> float:
	var c: Dictionary = _clips.get(sounding, {})
	if not c.has("bpm"):
		return _t
	var unit := 60.0 / float(c["bpm"]) / float(div)
	return _start + ceilf((_t - _start) / unit - 0.0001) * unit


## The whistle's note `m` (midi), as a sound.
func note_stream(m: int) -> AudioStream:
	var n := "note_%d" % m
	if not _streams.has(n):
		_streams[n] = load(DIR + n + ".ogg") if ResourceLoader.exists(DIR + n + ".ogg") else null
	return _streams[n]


# ------------------------------------------------------------------ the frame

func _process(delta: float) -> void:
	_game_t += delta
	_t = _audio_t()
	_world = world(_find_sea()) if world_test.is_empty() else world_test.duplicate()
	_world["talking"] = _duck_for > 0.0
	state.step(_world, delta)
	cue = state.section
	for e: String in state.events:
		_on(e)
	_listen()
	_land()
	_jumps()
	_chain()
	if _log_to != "":
		_bus_t -= delta
		if _bus_t <= 0.0:
			_bus_t = BUS_EVERY
			var b := {}
			for i in AudioServer.bus_count:
				b[AudioServer.get_bus_name(i)] = snappedf(maxf(AudioServer.get_bus_peak_volume_left_db(i, 0),
						AudioServer.get_bus_peak_volume_right_db(i, 0)), 0.1)
			_buses.append([snappedf(_t, 0.01), b])
	if state.still != _still:
		_still = state.still
		_note("still:" + ("on" if _still else "off"))
	_ask(cue)
	_apply(delta)
	_play_queue(delta)
	_mix(delta)


func _exit_tree() -> void:
	if _log_to != "":
		var f := FileAccess.open(_log_to, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"played": _log, "fps": Engine.physics_ticks_per_second, "heard": heard,
					"put_right": put_right, "buses": _buses}))
			f.close()


func _audio_t() -> float:
	if _dummy or _clock == null:
		return _game_t
	var pos := _clock.get_playback_position()
	if pos + 0.5 < _clock_last:
		_clock_wraps += 1
	_clock_last = pos
	return _clock_wraps * CLOCK_LEN + pos + AudioServer.get_time_since_last_mix()


func _find_sea() -> Node:
	if _sea == null or not is_instance_valid(_sea) or not _sea.is_inside_tree():
		_sea = get_tree().get_first_node_in_group("sea")
	return _sea


func _on(e: String) -> void:
	match e:
		"strike":
			_hush = 0.0
			var hit := _next("beat", 0.0)
			_queue.append({"name": "strike", "at": hit, "from": 0.0})
			# the song turns: on the bar after the hit, into one of the fight's own passages, the break driving in
			if not bool(Cues.CUES.get(_asked, {}).get("fight", false)):
				_jump = "fight"
				_jump_after = hit
		"leader", "landed":
			_jump = e
			_fill_wait = 0.0
		"birds":
			_lead_in("hunt_in")
		"away":
			if state.scenic == "":
				_lead_in("away_in")       # (a storm: no silence, straight out into it)
		"scenic":
			_return_at = -1.0
		"return", "return_theme":
			_lead_in("away_in")
			_return_at = float(_queue[-1]["at"]) + float(Cues.CUES.get("away_in", {}).get("length", 0.0))
			if e == "return_theme":
				_jump = "theme"
		"wake":
			_return_at = _next("beat", 0.0)
		"lightning":
			var at := _next("beat", 0.05)
			_queue.append({"name": "thunder", "at": at, "from": 0.0})
			_dip_until = at
		"race":
			_lead_in("race_in")
		"boatside":
			_sting_at("boatside_end", "beat")
		"home":
			_sting_at("race_end", "beat")
		"their_on":
			_sting_at("their_on", "beat")
		"lead_up", "lead_down":
			_sting_at(e, "bar")
		"countdown":
			var into := float(_world.get("counting", 0.0))
			if into < COUNT - 0.5:
				_queue.append({"name": "countdown", "at": _t, "from": maxf(into, 0.0)})
		"lost":
			pass                   # (the hush: _mix)
		_:
			if e.begins_with("card:"):
				_sting_at(e.substr(5), "now")


## A lead-in (two beats long): ending exactly on the next downbeat it has time for.
func _lead_in(n: String) -> void:
	var c: Dictionary = _clips.get(sounding, {})
	var length := float(Cues.CUES.get(n, {}).get("length", 0.0))
	if not c.has("bpm"):
		_queue.append({"name": n, "at": _t, "from": 0.0})
		return
	_queue.append({"name": n, "at": _next("bar", length + 0.03) - length, "from": 0.0})


## A sting on the next grid line of whatever's playing ("now", "beat", "bar").
func _sting_at(n: String, grid: String) -> void:
	_queue.append({"name": n, "at": _next(grid, 0.0), "from": 0.0})


## The next grid line ("beat", "bar", "phrase") of the sounding clip, at least `after` s from now; now if it's got
## no grid.
func _next(grid: String, after: float) -> float:
	var c: Dictionary = _clips.get(sounding, {})
	if grid == "now" or not c.has("bpm"):
		return _t
	var beats: int = {"beat": 1, "bar": int(c["bar_beats"]), "phrase": int(c["bar_beats"]) * PHRASE_BARS}.get(grid, 1)
	var unit := 60.0 / float(c["bpm"]) * beats
	return _start + ceilf((_t + after - _start) / unit - 0.0001) * unit


## A switch landing: the clip's start is where its grid begins.
func _land() -> void:
	if not _landing.is_empty() and _t >= float(_landing["at"]) - 0.001:
		sounding = str(_landing["to"])
		_start = float(_landing["at"])
		_landing = {}
		_phrase_n = -1
		_fill = 0.0                # (the fill was the last passage's, into this one)
		if str(_landing.get("from", "")) == "rest":
			_mark_ref = NAN        # (in from the quiet: a new start to hear it against)
		_mark_at = -1.0
		_note("clip:" + sounding, _start)


## Asks the bed for `to` ("title", "rest", or anything of the song's: a passage of it), working out where the
## switch will land.
func _ask(to: String) -> void:
	if _hush > 0.5 and not to in FIGHT and to != "title":
		to = "rest"
	if to in SONG:
		if _asked.begins_with("sea_"):
			return                 # (the song's playing: one passage into the next, _chain; the theme, _jumps)
		to = _pick_sea()
	if to == _asked:
		return
	if not _clips.has(to) and to != "rest":
		to = "rest"
		if _asked == "rest":
			return
	if not _landing.is_empty():
		return                     # (one switch at a time: the last one lands within a bar)
	var from := sounding
	var lf: int = _leave(from, to)
	var grid: String = {AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT: "beat",
			AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR: "bar"}.get(lf, "now")
	var at := _next(grid, 0.0)
	if grid != "now" and at - _t < GRID_SAFE:
		return                     # (too near the line to know which side the mixer takes it: next frame)
	if grid != "now":
		at -= EARLY
	var pb := _bed.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return
	pb.switch_to_clip_by_name(StringName(to))
	if from == "title" and to.begins_with("sea_"):
		_queue.append({"name": "title_end", "at": at, "from": 0.0})      # (the title's last chord rings on into it)
	_asked = to
	_landing = {"to": to, "at": at, "from": from}
	if to != "rest":
		_set_volumes(to, true)


## Into the theme on the bar: for the leader, its fill over the bar's last two beats and the theme's second half on
## the downbeat... its first half, sea_t1, then its second (t2 always follows); for landing him, the hit on the
## downbeat and its first half. In the theme already, only the fill or the hit.
func _jumps() -> void:
	if _jump == "" or not _landing.is_empty() or not sounding.begins_with("sea_") or _asked != sounding:
		return
	var at := _next("bar", 0.0)
	var in_theme := sounding in ["sea_t1", "sea_t2"]
	if _jump == "fight":
		var bar := 60.0 / float(_clips[sounding]["bpm"]) * int(_clips[sounding]["bar_beats"])
		var line := _start + ceilf((_jump_after + 0.01 - _start) / bar) * bar
		if line - _t > bar or line - _t < GRID_SAFE:
			if line < _t:
				_jump = ""
			return
		var to := _pick_sea()
		_queue.append({"name": "fight_in", "at": line, "from": 0.0})
		_jump = ""
		if to == sounding or not bool(Cues.CUES.get(to, {}).get("fight", false)):
			return
		var pbf := _bed.get_stream_playback() as AudioStreamPlaybackInteractive
		if pbf == null:
			return
		pbf.switch_to_clip_by_name(StringName(to))
		_sea_was = sounding
		_asked = to
		_fill = 0.0
		_landing = {"to": to, "at": line - EARLY}
		_set_volumes(to, true)
		return
	if _jump == "theme":
		# (onto the bar the song comes back in on: ask in the bar before it)
		if _return_at < 0.0 or absf(at - _return_at) > 0.01 or at - _t < GRID_SAFE:
			if _return_at < 0.0 or at > _return_at + 0.01:
				_jump = ""
			return
	elif _jump == "leader":
		var fill := float(Cues.CUES.get("leader_in", {}).get("length", 0.0))
		_fill_wait += get_process_delta_time()
		if _fill_wait < FILL_WAIT and (at - _t < fill or at - _t > fill + FILL_SLOP):
			return
		if at - _t >= fill:
			_queue.append({"name": "leader_in", "at": at - fill, "from": 0.0})
	else:
		if at - _t < GRID_SAFE:
			return
		if _jump == "landed":
			_queue.append({"name": "landed", "at": at, "from": 0.0})
	_jump = ""
	if in_theme:
		return
	var pb := _bed.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return
	pb.switch_to_clip_by_name(&"sea_t1")
	_sea_was = sounding
	_asked = "sea_t1"
	_fill = 0.0
	_landing = {"to": "sea_t1", "at": at - EARLY}
	_set_volumes("sea_t1", true)


## The clock's ear: the bed as the mixer played it (the capture on BED_BUS), and at each bar line its tick looked for
## (a Goertzel at the mark's pitch, every MARK_STEP samples round where it's due). Where it really was against where
## the clock had it, set against the first heard since the song came in from the quiet: the difference is how far the
## clock's drifted, and it's put right (the clip's start, the switch on its way, the next bar to listen for).
func _listen() -> void:
	if _cap == null:
		return
	var n := _cap.get_frames_available()
	if n > 0:
		var f := _cap.get_buffer(n)
		var at := _cap_buf.size()
		_cap_buf.resize(at + f.size())
		for i in f.size():
			_cap_buf[at + i] = (f[i].x + f[i].y) * 0.5
		_cap_end += f.size()
	var rate := AudioServer.get_mix_rate()
	var keep := int(CAP_KEEP * rate)
	if _cap_buf.size() > keep:
		_cap_buf = _cap_buf.slice(_cap_buf.size() - keep)
	if _cap_end <= 0:
		return
	var c := _t - float(_cap_end) / rate
	_cap_c = c if is_nan(_cap_c) else lerpf(_cap_c, c, 0.05)
	var cl: Dictionary = _clips.get(sounding, {})
	if not cl.has("bpm") or not _landing.is_empty():
		_mark_at = -1.0
		return
	var bar := 60.0 / float(cl["bpm"]) * int(cl["bar_beats"])
	if _mark_at < 0.0:
		_mark_at = _next("bar", 0.0)
	if _t < _mark_at + MARK_WIN + 0.04:
		return
	var due := _mark_at
	_mark_at += bar
	# where in what's been heard: the ear's frames, from the oldest kept
	var first := _cap_end - _cap_buf.size()
	var i0 := int(roundf((due - _cap_c - MARK_WIN) * rate)) - first
	var steps := int(2.0 * MARK_WIN * rate / MARK_STEP)
	if i0 < 0 or i0 + steps * MARK_STEP + MARK_N >= _cap_buf.size():
		return
	var hz := float(cl.get("mark_hz", Cues.CUES.get("sea_a", {}).get("mark_hz", 12000.0)))
	var k := 2.0 * cos(TAU * hz / rate)
	var powers: Array[float] = []
	var best := 0.0
	var best_i := -1
	for st in steps:
		var a := 0.0
		var b := 0.0
		var o := i0 + st * MARK_STEP
		for j in MARK_N:
			var x := _cap_buf[o + j] + k * a - b
			b = a
			a = x
		var pw := a * a + b * b - k * a * b
		powers.append(pw)
		if pw > best:
			best = pw
			best_i = st
	var sorted := powers.duplicate()
	sorted.sort()
	if best_i < 0 or best < MARK_OVER * maxf(sorted[sorted.size() / 2], 1e-9) or best < 1e-6:
		return                     # (not heard: the hush, or the bar too loud up there to tell)
	# the tick's middle is where the window it fills best sits; its bar line is the start of it
	var mark_s := float(cl.get("mark_s", 0.006))
	var mid := float(i0 + best_i * MARK_STEP + MARK_N / 2 + first) / rate
	var d := (mid - mark_s * 0.5 + _cap_c) - due
	heard += 1
	if is_nan(_mark_ref):
		_mark_ref = d
		return
	var e := d - _mark_ref
	if absf(e) < 0.0006 or absf(e) > MARK_TRUST:
		return
	_start += e
	_mark_at += e
	put_right += e
	if not _landing.is_empty():
		_landing["at"] = float(_landing["at"]) + e
	for q: Dictionary in _queue:
		q["at"] = float(q["at"]) + e


## The song's next passage. Out of a fight, the weather's song (its form, part by part: intro, verses, choruses, a
## bridge, the outro; then the next, the weather's by then: if it's turned, the band heads for this song's outro
## first, so the weather changes as one song ends and the next begins). In a fight (and the race home), the fight's
## own passages. The theme's first half, jumped to: its second.
func _pick_sea() -> String:
	var fighting: bool = state.section in ["fight", "tired", "gaff", "race"] or _jump == "fight"
	var forms: Dictionary = Cues.CUES.get("songs", {}).get("forms", {})
	if fighting or forms.is_empty():
		_song = ""
		return _pick_weighted()
	var form: Array = forms.get(_song, [])
	var at := _song != "" and _form_i >= 0 and _form_i < form.size() and str(form[_form_i]) == sounding
	if sounding == "sea_t1" and not at:
		return "sea_t2"
	var want := str(MOOD_SONG.get(state.mood, "fair"))
	if not forms.has(want):
		want = "fair"
	if not at:
		# into a song: the weather's, from its top (back from a fight or the theme, from its first verse)
		var back := sounding.begins_with("sea_") and (bool(Cues.CUES.get(sounding, {}).get("fight", false))
				or sounding in ["sea_t1", "sea_t2"])
		_start_song(want, 1 if back else 0)
	elif want != _song and str(Cues.CUES.get(sounding, {}).get("role", "")) != "outro":
		_form_i = form.size() - 1          # (the weather's turned: to the outro)
	else:
		_form_i += 1
		if _form_i >= form.size():
			_start_song(want, 0 if want != _song else 1)
	form = forms[_song]
	var next := str(form[_form_i])
	_arrange(next, form)
	return next


func _start_song(song: String, from: int) -> void:
	_song = song
	_form_i = from
	_passes.clear()


## A part's arrangement this time through (by its role, how many times it's come round, and a little luck): the intro
## sparse; a verse's tune the first time, its counter-melody the next (now and then an instrumental, or the guitar
## out); the chorus with the counter-melody under it and, the last time, the lead up high; the bridge the counter-
## melody alone over a lighter guitar; the outro winding down.
func _arrange(n: String, form: Array) -> void:
	var role := str(Cues.CUES.get(n, {}).get("role", "chorus" if n in ["sea_t1", "sea_t2"] else ""))
	var k := int(_passes.get(n, 0))
	_passes[n] = k + 1
	var a := {"alt": 0.0}
	var last_chorus := role == "chorus" and _form_i + 1 < form.size() and str(Cues.CUES.get(str(form[_form_i + 1]),
			{}).get("role", "")) == "outro"
	match role:
		"intro":
			a = {"lead": 0.0, "alt": 0.0, "high": 0.0, "bass": 0.6}
		"verse":
			a = {"alt": 0.0} if k % 2 == 0 else {"lead": 0.35, "alt": 1.0}
			if _rng.randf() < 0.25:
				a["pick"] = 0.3
			if k > 0 and _rng.randf() < 0.15:
				a["lead"] = 0.0
				a["alt"] = 0.0
		"chorus":
			a = {"alt": 0.5}
			if last_chorus or (n == "sea_t2" and _form_i + 1 < form.size() and str(form[_form_i + 1]).ends_with("out")):
				a["^high"] = 0.7
		"bridge":
			a = {"pick": 0.4, "lead": 0.0, "alt": 1.0}
		"outro":
			a = {"alt": 0.0, "lead": 0.7}
	_arr[n] = a


## The old way, for a fight and the race home: by how bright the weather and the hour want it (the state's `bright`),
## never the one playing nor the one before.
func _pick_weighted() -> String:
	var pick: Array = []
	var weights: Array[float] = []
	var total := 0.0
	var then := str(Cues.CUES.get(sounding, {}).get("then", ""))
	if then != "" and sounding.begins_with("sea_"):
		return then                # (the theme's first half: its second follows)
	for n: String in _seas:
		if n == sounding or n == _sea_was or n == _asked or bool(Cues.CUES[n].get("after_only", false)):
			continue
		var w := 0.1 + (state.bright if bool(Cues.CUES[n].get("bright", true)) else 1.0 - state.bright)
		if Cues.CUES[n].has("then"):
			w *= THEME_K
		if bool(Cues.CUES[n].get("storm", false)):
			if state.mood != "storm":
				continue                 # (the storm's own: only in one)
			w *= STORM_K
		var fighting: bool = state.section in ["fight", "tired", "gaff", "race"] or _jump == "fight"
		if bool(Cues.CUES[n].get("fight", false)):
			if not fighting:
				continue                 # (the fight's own: only in one)
			w *= FIGHT_K
		pick.append(n)
		weights.append(w)
		total += w
	if pick.is_empty():
		return _seas[0] if not _seas.is_empty() else "rest"
	var r := _rng.randf() * total
	for i in pick.size():
		r -= weights[i]
		if r <= 0.0:
			return pick[i]
	return pick[-1]


## The theme's first half at sea, against any other passage (its second always follows it).
const THEME_K := 1.2
## The weather's own song (audio/music_cues.gd's "songs": each one's form, intro to outro).
const MOOD_SONG := {"calm": "fair", "fog": "fog", "rain": "rain", "storm": "storm", "night": "night"}
## A drum fill into the next passage: this often (more under way), never into or out of the theme's halves.
const FILL := Vector2(0.2, 0.5)


## At sea, in a passage's last bar: the next one asked for, to come in on its end (and, now and then, its fill
## stem opened for the bar: a drum fill on its last two beats, locked to it).
func _chain() -> void:
	if not cue in SONG or _jump != "" or not _landing.is_empty() or not sounding.begins_with("sea_") \
			or _asked != sounding:
		return
	var length := float(Cues.CUES[sounding]["length"])
	var c: Dictionary = _clips[sounding]
	var bar := 60.0 / float(c["bpm"]) * int(c["bar_beats"])
	var end := _start + ceilf((_t - _start) / length - 0.0001) * length
	if end - _t > bar or end - _t < GRID_SAFE:
		return
	end -= EARLY
	var next := _pick_sea()
	var odds := lerpf(FILL.x, FILL.y, float(_world.get("speed", 0.0)))
	_fill = 1.0 if _rng.randf() < odds and not Cues.CUES[sounding].has("then") and not Cues.CUES[next].has("then") \
			and not bool(Cues.CUES[next].get("after_only", false)) else 0.0
	var pb := _bed.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return
	pb.switch_to_clip_by_name(StringName(next))
	_sea_was = sounding
	_asked = next
	_landing = {"to": next, "at": end}
	_set_volumes(next, true)


static func _family(n: String) -> String:
	return "sea" if n.begins_with("sea_") else n


## Each stem of the section wanted at its level (the clips going out keep theirs while they fade; one of the same
## family still sounding, the next passage or the fight's next section waiting on the grid, follows along). Under it
## all the scenic gate: let go slowly as the silence comes, opened quickly on the bar it ends on.
func _apply(delta: float) -> void:
	if _return_at >= 0.0 and _t >= _return_at - 0.005:
		_quiet = move_toward(_quiet, 1.0, delta / SCENIC_IN)
		if _quiet >= 1.0:
			_return_at = -1.0
	elif state.scenic != "":
		_quiet = move_toward(_quiet, 0.0, delta / SCENIC_FADE)
	var c: Dictionary = _clips.get(_asked, {})
	if c.is_empty():
		return
	# the gated stems: in only at the top of a phrase
	var bb := bar_beat()
	var n := int(bb.x) / PHRASE_BARS if bb.x >= 0.0 and sounding == _asked else -1
	var top := n != _phrase_n and n >= 0
	_phrase_n = n
	for s: String in GATED:
		var g := float(_gate.get(s, 0.0))
		if state.level(s) < 0.01:
			g = 0.0
		elif top or g > 0.0:
			g = minf(g + delta / GATE_IN, 1.0) if g > 0.0 else 0.01
		_gate[s] = g
	_set_volumes(_asked, false)
	if sounding != _asked and _clips.has(sounding) and _family(sounding) == _family(_asked):
		_set_volumes(sounding, false)


func _set_volumes(n: String, fresh: bool) -> void:
	var c: Dictionary = _clips[n]
	var sync: AudioStreamSynchronized = c["sync"]
	var stems: Array = c["stems"]
	for k in stems.size():
		var s: String = stems[k]
		var g := state.level(s) if not s in GATED else state.level(s) * (0.0 if fresh else float(_gate.get(s, 0.0)))
		if s == "main" or s == "mark":
			g = 1.0
		elif s == "fill":
			g = _fill if n == sounding else 0.0      # (the passage going out has it; the one coming in, not yet)
		if _arr.has(n) and s != "mark":
			var arr: Dictionary = _arr[n]
			g *= float(arr.get(s, 1.0))
			if arr.has("^" + s):
				g = maxf(g, float(arr["^" + s]) * state.level("lead"))
		if s != "mark":
			g *= _quiet
		sync.set_sync_stream_volume(k, linear_to_db(maxf(g, 0.0001)))


func _play_queue(_delta: float) -> void:
	# each sting's file starts with `pre` s of silence: started in the frame before it's due, from far enough into
	# that silence that its hit lands on the line (the mixer's next block counted in), not a frame either side
	var late := 0.0 if _dummy else AudioServer.get_time_to_next_mix()
	for q: Dictionary in _queue.duplicate():
		var n: String = q["name"]
		var pre := float(Cues.CUES.get(n, {}).get("pre", 0.0))
		var lead := float(q["at"]) - _t - late
		if lead > pre:
			continue
		_queue.erase(q)
		var p := _stings[1] if n in SMALL else _stings[0]      # (the small ones over the big ones, not cutting them)
		p.stream = _streams.get(n)
		p.set_meta("cue", n)
		if p.stream != null:
			p.play(maxf(float(q["from"]) + pre - lead, 0.0))
		sting = n
		_note("sting:" + n, float(q["at"]))
	if sting != "" and not _stings[0].playing and not _stings[1].playing:
		sting = ""


func _note(what: String, at := -1.0) -> void:
	played.append([_t if at < 0.0 else at, what])
	played_n += 1
	if played.size() > PLAYED_N:
		played.pop_front()
	if _log_to != "":
		_log.append([_t if at < 0.0 else at, what])


## The duck, the pocket, the muffle, the pause, the hush.
func _mix(delta: float) -> void:
	var on := duck_test > 0.0
	var depth := DUCK if on else 1.0
	duck_test = maxf(duck_test - delta, 0.0)
	for b: StringName in DUCK_BUSES if not _dummy else {}:
		var i := AudioServer.get_bus_index(b)
		if i >= 0 and maxf(AudioServer.get_bus_peak_volume_left_db(i, 0),
				AudioServer.get_bus_peak_volume_right_db(i, 0)) > DUCK_AT:
			on = true
			depth = minf(depth, float(DUCK_BUSES[b]))
	if on:
		_duck_to = depth
	_duck_for = DUCK_HOLD if on else maxf(_duck_for - delta, 0.0)
	_pocket = move_toward(_pocket, 1.0 if _duck_for > 0.0 else 0.0, delta / (0.15 if _duck_for > 0.0 else 0.6))
	# with the pocket in, half the drop (in dB)
	var want := sqrt(_duck_to) if _duck_for > 0.0 else 1.0
	if duck_test > 0.0:
		want = DUCK
	var paused := get_tree().paused
	if paused:
		want = minf(want, PAUSED)
	_duck = move_toward(_duck, want, delta * (1.6 if want < _duck else 0.4))
	# the hush: a fish lost, everything gone at once, then the sea alone
	_hush = move_toward(_hush, 1.0 if state.hush > 0.0 else 0.0, delta / (HUSH_FADE if state.hush > 0.0 else 1.5))
	_dip = move_toward(_dip, DIP if _t < _dip_until else 1.0, delta / (0.05 if _t < _dip_until else 0.08))
	var gain := _duck * (1.0 - _hush) * _dip
	var lv := _asked if _asked != "rest" else sounding
	var want_level := float(LEVEL.get(_family(lv) if lv.begins_with("sea_") else lv, 1.0))
	if lv.begins_with("sea_"):
		want_level *= db_to_linear(HEAT_DB * state.heat)
	_level = move_toward(_level, want_level, delta * 0.8)
	_bed.volume_db = linear_to_db(maxf(gain * _level, 0.0001))
	gain /= _dip                 # (the thunder itself isn't ducked)
	for p in _stings:
		p.volume_db = linear_to_db(maxf(gain * float(STING_LEVEL.get(str(p.get_meta("cue", "")), 1.0)), 0.0001))
	if _eq != null:
		_eq.set_band_gain_db(3, POCKET[0] * _pocket)
		_eq.set_band_gain_db(4, POCKET[1] * _pocket)
	var lp := 20000.0
	if bool(_world.get("underwater", false)):
		lp = UNDER_LP
	elif paused:
		lp = PAUSED_LP
	_lp = exp(move_toward(log(_lp), log(lp), delta * 12.0))
	if _lpf != null:
		_lpf.cutoff_hz = _lp


# ------------------------------------------------------------------ the world

## The game as the state wants it (audio/music_state.gd's world): read off the sea, your boat, your rods.
func world(sea: Node) -> Dictionary:
	var w := {}
	if sea == null:
		return w
	var now_s := _sea_now(sea)
	var title: Node = sea.get("title")
	w["title"] = title != null and is_instance_valid(title) and bool(title.call("busy"))
	var hold: Node = sea.get("fish_hold")
	var docked := hold == null or bool(hold.get("docked"))
	w["docked"] = docked
	w["paused"] = get_tree().paused
	w["condition"] = str(sea.get("condition"))
	if hold != null:
		w["landed"] = (hold.get("fish") as Array).size()
		w["day"] = float(hold.call("day_fraction"))
		w["night"] = bool(sea.get("night")) or (not docked and float(hold.call("daylight")) < 0.2)
	var vs: Node = sea.get("vs")
	var rivals := vs != null and bool(vs.get("on"))
	if rivals:
		var card: Node = vs.get("card")
		w["card"] = card != null and bool(card.call("up"))
		if w["card"] and bool(card.call("stamped")):
			var d: Dictionary = card.get("data")
			var winner := int(d.get("winner", -1))
			w["card_result"] = "tie" if winner < 0 else ("win" if winner == int(card.get("mine")) else "lose")
		var ce := float(vs.get("count_end"))
		w["counting"] = COUNT - (ce - now_s) if ce >= 0.0 else -1.0
		var mine := int(vs.get("my_team"))
		var shown: Array = vs.get("shown")
		if not docked and shown.size() == 2:
			w["lbs"] = shown
		if float(vs.get("home_by")) > 0.0 and not bool(vs.call("came_home", mine)):
			w["race_left"] = float(vs.get("home_by")) - now_s
			if shown.size() == 2:
				w["standing"] = signi(int(shown[0]) - int(shown[1]))
		var sides: Array = vs.get("sides")
		if sides.size() == 2:
			var theirs := 0
			for r: Node in (sides[1 - mine].get("rods") as Node).get("rods"):
				if bool(r.get("hooked")) and not bool(r.get("alongside")):
					theirs += 1
			w["their_on"] = theirs
	elif float(sea.get("home_by")) > 0.0 and not docked:
		w["race_left"] = float(sea.get("home_by")) - now_s
	w["birds"] = _birds(sea)
	var fx: Node = sea.get("sea_fx")
	if fx != null:
		w["flash"] = float(fx.get("_flash"))
	var marks: Node = sea.get("landmarks")
	var helm0: Node = (sea.get("boat") as Node).get("helm") if sea.get("boat") != null else null
	if marks != null and marks.has_method("breakwater_arms") and helm0 != null:
		var arms: Array = marks.call("breakwater_arms")
		var mouth := ((arms[0][1] as Vector2) + (arms[1][1] as Vector2)) * 0.5
		var at: Vector2 = helm0.get("at")
		w["past_mouth"] = mouth.y - at.y          # (the open sea's toward -z)
	var boat: Node = sea.get("boat")
	var helm: Node = boat.get("helm") if boat != null else null
	if helm != null and helm.has_method("top_speed"):
		w["speed"] = clampf(float(helm.get("speed")) / maxf(float(helm.call("top_speed")), 0.1), 0.0, 1.0)
	var fights: Array = []
	var along: Array = []
	var rods: Node = sea.get("rods")
	if rods != null:
		for r: Node in rods.get("rods"):
			if not bool(r.get("hooked")):
				continue
			var id := "%d:%.2f" % [int(r.get("index")), float(r.get("hook_t"))]
			if bool(r.get("alongside")):
				along.append(id)
			else:
				fights.append(_fight_of(r, id))
	w["fights"] = fights
	var landing: Node = sea.get("landing")
	if landing != null:
		# (a fish the landing's still got, harpooned and being hauled in through the door, is still alongside:
		# its rod lets go of it before it's in the hold)
		var held: Variant = landing.get("fish")
		if held is Dictionary:
			for i: Variant in held:
				var lf: Dictionary = held[i]
				var lid := "%d:%.2f" % [int(i), float(lf.get("hook_t", 0.0))]
				if not lid in along:
					along.append(lid)
	w["alongside"] = along
	if landing != null:
		w["draw"] = float(landing.get("draw"))
		var fl: Variant = landing.get("_flight")
		var fd: Dictionary = fl if fl is Dictionary else {}
		w["flying"] = not fd.is_empty() and float(fd.get("end", 0.0)) < 0.0
	var crew: Node = sea.get("crew")
	var me: Node = crew.get("me") if crew != null else null
	w["underwater"] = me != null and bool(me.get("_under"))
	return w


## One fish on, in what you'd feel of it: on the rod's holder's machine its own fight's cues, on everyone else's the
## rod's synced state.
func _fight_of(r: Node, id: String) -> Dictionary:
	var f := {"id": id, "kg": float(r.get("fish_kg")), "line_out": float(r.get("line_out")),
			"spool": float(r.get("line_out")) / 500.0,
			"depth": float(r.get("depth")), "move": str(r.get("move")), "tangled": int(r.get("tangled")) >= 0}
	var fight: RefCounted = r.get("fight")
	if fight != null:
		f.merge(State.feel(fight.call("cues"), float(fight.call("strength"))), true)
	else:
		var strength := (1.0 - 0.5 * smoothstep(0.4, 1.0, float(r.get("wear")))) * (1.0 - 0.6 * float(r.get("twist")))
		f["tension"] = float(r.get("strain")) / maxf(strength, 0.05)
		f["slack"] = float(r.get("stretch")) < -0.3
		f["airborne"] = f["move"] == "jump"
		f["surging"] = f["move"] in ["run", "surge", "charge"]
	return f


## How near feeding birds are (1 right there, 0 past BIRDS_FAR m): what anyone on deck can see.
const BIRDS_FAR := 650.0
const BIRDS_NEAR := 150.0


func _birds(sea: Node) -> float:
	var schools: Node = sea.get("schools")
	if schools == null or not schools.has_method("boat_at"):
		return 0.0
	var at: Vector2 = schools.call("boat_at")
	var t := float(schools.call("now"))
	var best := 0.0
	for s: Object in schools.get("schools"):
		if s == null or not is_instance_valid(s) or not bool(s.call("feeding", t)) or bool(s.call("done", t)):
			continue
		var d := (s.call("center", t) as Vector2).distance_to(at)
		best = maxf(best, smoothstep(BIRDS_FAR, BIRDS_NEAR, d))
	return best


func _sea_now(sea: Node) -> float:
	var ocean: Node = sea.get("ocean")
	return float(ocean.get("wave_time")) if ocean != null else 0.0
