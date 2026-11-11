extends Node
## The music (an autoload, `Music`), on the Music bus (core/settings.gd's slider). docs/MUSIC_SYSTEM.md is the design;
## tools/music.py makes it into res://music/ and writes audio/music_cues.gd (each piece's files, layers, chords and
## timing).
##
## Each frame it reads the sea into a plain picture (world()) and hands it to audio/music_state.gd, which says where
## the music is (the title, the weather's song, the fight, the quiet), which song, each layer's level, and what just
## happened. Here's the band playing it:
## - the title's piece; the weather's songs (fair, rain, fog, night, storm), each a whole song with its layers in step
##   (an AudioStreamSynchronized), looping on its own; one in for another over SONG_FADE when the weather's turned;
##   a song gone quiet is paused where it was, and taken up from there when it's back;
## - the fight: an AudioStreamInteractive of its intro (the strike: the hit on the reel's scream, two bars of drums
##   rising) running on into its loop by itself; started from the top on the strike, the song gone under the hit in
##   STRIKE_OUT; its layers (pulse, drums, full) up and down with the state's intensity;
## - he's in: the landed flourish, the fight let go over FIGHT_OUT, the song back over BACK_IN when the flourish has
##   rung; he's gone: the fight let go over LOST_OUT, quiet, the song back;
## - Rivals: quiet under the countdown and the results card, and their stings.
## Nothing here keeps time: the pieces loop and run on by themselves, and every change is a fade. The mix: down a
## little while the radio or a voice is on (DUCK_BUSES), with a dip where voices sit (the pocket) rather than more of a
## drop; muffled underwater; quieter and dulled under the pause card; a limiter last.

const State := preload("res://audio/music_state.gd")
const Cues := preload("res://audio/music_cues.gd")
const DIR := "res://music/"
const BUS := &"Music"
const SONGS := ["fair", "rain", "fog", "night", "storm"]
## Fades (s): one weather's song into another; the song gone under the strike's hit; the fight let go when he's in,
## and when he's gone; the song back after a fight or the quiet; the title giving way to the song; into the quiet
## (Rivals' countdown and card).
const SONG_FADE := 8.0
const STRIKE_OUT := 0.25
const FIGHT_OUT := 2.5
const LOST_OUT := 1.2
const BACK_IN := 4.0
const TITLE_OUT := 2.0
const QUIET_OUT := 1.0
## How loud each piece plays (a share): the weather's song out there, and tied up; the title's. The fight's at 1: the
## songs sit under it (measured through the mixer, tools/music_check.sh --render: at one level the fair song's chorus
## was 4 dB over the fight, and a strike in the middle of one had nothing to hit with).
const SEA := 0.7
const HARBOUR := 0.42
const TITLE := 0.85
## The music's tone, the EQ's six bands (dB at 32, 100, 320, 1000, 3200 and 10000 Hz): the rendered band is dark and
## heavy below (against 500 Hz: -11 dB at 2 kHz, -19 at 4 kHz, the fight's pulse +7 at 125 Hz), which is a rumble and
## no tune on small speakers; a little off the bottom and some air put back. The voices' pocket is cut from this.
const TONE := [0.0, -2.5, 0.0, 0.0, 3.0, 5.0]
## The fight's intro into its loop: the intro's tail (its downbeat's crash ringing) let go over this many beats.
const INTRO_TAIL := 4.0
## The cues' levels (a share), and how many can ring at once (each on its own player: none cuts another off).
const STING_LEVEL := {"landed": 1.0, "countdown": 1.0, "win": 1.0, "lose": 1.0, "tie": 1.0, "title_end": 0.8}
const STING_VOICES := 4
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

## What's playing loudest now ("title", "song_fair".., "fight"; "" the quiet).
var cue := ""
var sounding := ""
## The state (audio/music_state.gd): where, which song, the layers, the events.
var state: State
## The last cue played, while it rings ("" none).
var sting := ""
## Tests: >0 holds the duck on this many s more, as if the radio were on; a world to play instead of the sea's.
var duck_test := 0.0
var world_test := {}
## What's been played, for the tests and the HUD: [[game time, what]] ("in:<piece>" as one's asked in, "out:<piece>",
## "strike", "sting:<name>"), the last PLAYED_N.
var played: Array = []
const PLAYED_N := 64
var played_n := 0
## Run with -- --music-log=<file>: everything played, and when it was meant to be all but silent ("still:on"/"off"),
## and every bus's level now and then, written there as JSON when the game closes (to read a real game's music after).
var _log_to := ""
var _log: Array = []
var _buses: Array = []
var _bus_t := 0.0
const BUS_EVERY := 0.25

var _world := {}
var _t := 0.0
## "title", "song_<mood>", "fight" -> {player, syncs (its AudioStreamSynchronized(s)), stems (each sync's), gain (now),
## to, rate (a s), cue (audio/music_cues.gd's)}
var _pieces := {}
var _fight_t0 := -1.0       # (when the fight was started: its intro, then round its loop)
var _stings: Array[AudioStreamPlayer] = []
var _streams := {}
var _still := false
var _was_place := ""
var _duck := 1.0
var _duck_to := 1.0
var _duck_for := 0.0
var _pocket := 0.0
var _lp := 20000.0
var _eq: AudioEffectEQ6
var _lpf: AudioEffectLowPassFilter
var _sea: Node
var _dummy := false          # (no sound card: headless, the movie maker)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dummy = AudioServer.get_driver_name() == "Dummy"
	state = State.new()
	_piece("title", Cues.CUES["title"])
	for s: String in SONGS:
		_piece("song_" + s, Cues.CUES["song_" + s])
	_fight_piece()
	for n: String in Cues.CUES:
		if str(Cues.CUES[n]["kind"]) == "sting":
			_streams[n] = _ogg(str(Cues.CUES[n]["files"][0]), Cues.CUES[n])
	for i in STING_VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Sting%d" % i
		p.bus = BUS
		add_child(p)
		_stings.append(p)
	_bus_effects.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--music-log="):
			_log_to = a.substr(12)
		elif a == "--music-hud":
			var hud: CanvasLayer = preload("res://audio/music_hud.gd").new()
			hud.set("music", self)
			add_child(hud)


## A piece as a player: its stems in step (an AudioStreamSynchronized), silent and paused till it's wanted.
func _piece(key: String, c: Dictionary) -> void:
	var sync := _sync(c)
	var p := AudioStreamPlayer.new()
	p.name = key.capitalize().replace(" ", "")
	p.bus = BUS
	p.stream = sync
	p.volume_db = -80.0
	add_child(p)
	p.play()
	p.stream_paused = true
	_pieces[key] = {"player": p, "syncs": [sync], "stems": [c["stems"]], "gain": 0.0, "to": 0.0, "rate": 1.0, "cue": c,
			"pos": 0.0}


func _sync(c: Dictionary) -> AudioStreamSynchronized:
	var sync := AudioStreamSynchronized.new()
	var files: Array = c["files"]
	sync.stream_count = files.size()
	for k in files.size():
		sync.set_sync_stream(k, _ogg(str(files[k]), c))
		sync.set_sync_stream_volume(k, -80.0)
	return sync


## The fight: its intro (the strike) running on into its loop by itself, the intro's ring let go under the loop.
func _fight_piece() -> void:
	var intro: Dictionary = Cues.CUES["fight_intro"]
	var loop: Dictionary = Cues.CUES["fight"]
	var I := AudioStreamInteractive
	var it := AudioStreamInteractive.new()
	it.clip_count = 2
	var a := _sync(intro)
	var b := _sync(loop)
	it.set_clip_name(0, &"intro")
	it.set_clip_stream(0, a)
	it.set_clip_name(1, &"loop")
	it.set_clip_stream(1, b)
	it.set_clip_auto_advance(0, I.AUTO_ADVANCE_ENABLED)
	it.set_clip_auto_advance_next_clip(0, 1)
	it.initial_clip = 0
	it.add_transition(0, 1, I.TRANSITION_FROM_TIME_END, I.TRANSITION_TO_TIME_START, I.FADE_OUT, INTRO_TAIL)
	var p := AudioStreamPlayer.new()
	p.name = "Fight"
	p.bus = BUS
	p.stream = it
	p.volume_db = -80.0
	add_child(p)
	_pieces["fight"] = {"player": p, "syncs": [a, b], "stems": [intro["stems"], loop["stems"]], "gain": 0.0,
			"to": 0.0, "rate": 1.0, "cue": loop, "intro": intro}


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


func _bus_effects() -> void:
	var b := AudioServer.get_bus_index(BUS)
	if b < 0:
		return
	_eq = AudioEffectEQ6.new()
	_lpf = AudioEffectLowPassFilter.new()
	_lpf.cutoff_hz = 20000.0
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	for e: AudioEffect in [_eq, _lpf, lim]:
		AudioServer.add_bus_effect(b, e)


# ------------------------------------------------------------------ reading

## A layer's loudness now (0..1, before the duck): a piece by name ("title", "song" (whichever's loudest), "fight":
## how far it's faded in), or a layer of what's playing ("pulse", "drums", "full", "run", ...).
func level(n: String) -> float:
	if n == "song":
		var best := 0.0
		for s: String in SONGS:
			best = maxf(best, float(_pieces["song_" + s]["gain"]))
		return best
	if _pieces.has(n):
		return float(_pieces[n]["gain"])
	return state.level(n)


## The duck now (1: none, DUCK: under the radio).
func duck() -> float:
	return _duck


## Where the piece playing loudest is: [bar, beat in it] (from 0; -1 when nothing's playing).
func bar_beat() -> Vector2:
	var pos := _pos(cue)
	var c: Dictionary = _cue_of(cue)
	if pos < 0.0 or float(c.get("bpm", 0.0)) <= 0.0:
		return Vector2(-1, -1)
	var beats := floorf(pos / (60.0 / float(c["bpm"])) + 0.0001)
	return Vector2(floorf(beats / int(c["bar_beats"])), fposmod(beats, int(c["bar_beats"])))


## Time now (s, the game's).
func now() -> float:
	return _t


## A fish lost (rods.gd says so too; the state sees it for itself).
func hush(seconds: float) -> void:
	state.hush = maxf(state.hush, minf(seconds, State.HUSH))


## How far into piece `key` it is (s; -1 when it's not playing): a song's or the title's from its player (with no
## sound card, from the game's frames: nothing's mixed at the game's pace then), the fight's from when it started (its
## intro, then round its loop).
func _pos(key: String) -> float:
	if key == "" or not _pieces.has(key):
		return -1.0
	if key == "fight":
		if _fight_t0 < 0.0:
			return -1.0
		var into := _t - _fight_t0 - float(_pieces["fight"]["intro"]["length"])
		return fposmod(into, float(_pieces["fight"]["cue"]["length"])) if into >= 0.0 else -1.0
	var p: AudioStreamPlayer = _pieces[key]["player"]
	if not p.playing or p.stream_paused:
		return -1.0
	return float(_pieces[key]["pos"]) if _dummy else p.get_playback_position()


func _cue_of(key: String) -> Dictionary:
	return _pieces[key]["cue"] if _pieces.has(key) else {}


# ------------------------------------------------------------------ the deck whistle (crew/hands.gd)

## Each chord's own notes (pitch classes), and D major's pentatonic for when nothing's playing.
const CHORD_TONES := {"D": [2, 6, 9], "G": [7, 11, 2], "A": [9, 1, 4], "Bm": [11, 2, 6], "Em": [4, 7, 11],
		"F#": [6, 10, 1], "C": [0, 4, 7], "Dm": [2, 5, 9], "Am": [9, 0, 4], "F": [5, 9, 0], "Dsus": [2, 7, 9],
		"Asus": [9, 2, 4], "Gadd9": [7, 11, 2, 9]}
const PENTATONIC := [2, 4, 6, 9, 11]
## The whistle's notes picked from (midi): its sweet two octaves.
const WHISTLE_RANGE := Vector2i(69, 88)


## The chord playing now ("" with nothing playing): from the piece's chords (audio/music_cues.gd), a bar each; the
## strike's own B minor under the fight's intro.
func chord_now() -> String:
	var c: Dictionary = _cue_of(cue)
	var chords: Array = c.get("chords", [])
	var pos := _pos(cue)
	if chords.is_empty() or pos < 0.0:
		return "Bm" if cue == "fight" and _fight_t0 >= 0.0 else ""
	var span := 60.0 / float(c["bpm"]) * int(c.get("chord_beats", 4))
	return str(chords[posmod(int(floorf(pos / span + 0.0001)), chords.size())])


## The note the deck whistle sounds at `k` (0 .. 1: how far up you're looking): always one of the chord's own notes,
## so whatever you play sits in the band.
func whistle_note(k: float) -> int:
	var tones: Array = CHORD_TONES.get(chord_now(), PENTATONIC)
	var notes: Array[int] = []
	for m in range(WHISTLE_RANGE.x, WHISTLE_RANGE.y + 1):
		if posmod(m, 12) in tones:
			notes.append(m)
	return notes[clampi(int(k * notes.size()), 0, notes.size() - 1)]


## The next line of what's playing, `div` to a beat (2: the next eighth), in now()'s time; now if nothing's playing.
func next_tick(div := 2) -> float:
	var c: Dictionary = _cue_of(cue)
	var pos := _pos(cue)
	if pos < 0.0 or float(c.get("bpm", 0.0)) <= 0.0:
		return _t
	var unit := 60.0 / float(c["bpm"]) / float(div)
	var into := fposmod(pos, unit)
	return _t + (unit - into) if into > 0.002 else _t


## The whistle's note `m` (midi), as a sound.
func note_stream(m: int) -> AudioStream:
	var n := "note_%d" % m
	if not _streams.has(n):
		_streams[n] = load(DIR + n + ".ogg") if ResourceLoader.exists(DIR + n + ".ogg") else null
	return _streams[n]


# ------------------------------------------------------------------ the frame

func _process(delta: float) -> void:
	_t += delta
	_world = world(_find_sea()) if world_test.is_empty() else world_test.duplicate()
	_world["talking"] = _duck_for > 0.0
	state.step(_world, delta)
	for e: String in state.events:
		_on(e)
	_targets()
	_fade(delta)
	_layers()
	if state.still != _still:
		_still = state.still
		_note("still:" + ("on" if _still else "off"))
	if sting != "" and not _stings.any(func(v: AudioStreamPlayer) -> bool: return v.playing):
		sting = ""
	_mix(delta)
	if _log_to != "":
		_bus_t -= delta
		if _bus_t <= 0.0:
			_bus_t = BUS_EVERY
			var b := {}
			for i in AudioServer.bus_count:
				b[AudioServer.get_bus_name(i)] = snappedf(maxf(AudioServer.get_bus_peak_volume_left_db(i, 0),
						AudioServer.get_bus_peak_volume_right_db(i, 0)), 0.1)
			_buses.append([snappedf(_t, 0.01), b])


func _exit_tree() -> void:
	if _log_to != "":
		var f := FileAccess.open(_log_to, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"played": _log, "buses": _buses}))
			f.close()


func _on(e: String) -> void:
	match e:
		"strike":
			# the hit on the reel's scream: the fight from its top (its intro), the song gone under it
			var p: AudioStreamPlayer = _pieces["fight"]["player"]
			p.stop()
			p.stream_paused = false
			p.play()
			_fight_t0 = _t
			_note("strike")
		"landed":
			_play("landed")
		"countdown":
			var into := float(_world.get("counting", 0.0))
			if into < COUNT - 0.5:
				_play("countdown", maxf(into, 0.0))
		_:
			if e.begins_with("card:"):
				_play(e.substr(5))


## Where each piece is going, from where the state says the music is, and how fast it gets there.
func _targets() -> void:
	var place := state.place
	var want := {}
	match place:
		"title":
			want["title"] = TITLE
		"song":
			want["song_" + state.song] = HARBOUR if state.docked else SEA
		"fight":
			want["fight"] = 1.0
	for key: String in _pieces:
		var to := float(want.get(key, 0.0))
		var piece: Dictionary = _pieces[key]
		if absf(to - float(piece["to"])) < 0.001:
			continue
		var g := float(piece["gain"])
		var secs := SONG_FADE
		if key == "fight":
			secs = 0.0 if to > g else (LOST_OUT if place == "quiet" else FIGHT_OUT)
		elif key == "title":
			secs = TITLE_OUT
		elif to < g:
			if place == "fight":
				secs = STRIKE_OUT
			elif place == "quiet":
				secs = QUIET_OUT
			elif place == "title":
				secs = TITLE_OUT
		elif _was_place == "title":
			secs = TITLE_OUT
			_play("title_end")              # (the title's last chord ringing on as the song comes in)
		elif _was_place in ["fight", "after", "quiet"] or (to > 0.0 and g > 0.0):
			secs = BACK_IN                  # (back after a fight or the quiet; tied up or casting off: the same song)
		if _was_place == "" and to > g:
			secs = 0.0                      # (the first piece, as the game starts: from its first note)
		_aim(key, to, secs)
	_was_place = place


## Piece `key` to `to` (0..1) over `secs` s.
func _aim(key: String, to: float, secs: float) -> void:
	var piece: Dictionary = _pieces[key]
	var g := float(piece["gain"])
	piece["to"] = to
	piece["rate"] = absf(to - g) / secs if secs > 0.0 else INF
	if to > 0.0:
		var p: AudioStreamPlayer = piece["player"]
		if not p.playing:
			p.play()
		p.stream_paused = false
		_note("in:" + key)
	else:
		_note("out:" + key)


func _fade(delta: float) -> void:
	var loud := ""
	var best := 0.001
	for key: String in _pieces:
		var piece: Dictionary = _pieces[key]
		var g := move_toward(float(piece["gain"]), float(piece["to"]), float(piece["rate"]) * delta)
		piece["gain"] = g
		var p: AudioStreamPlayer = piece["player"]
		p.volume_db = linear_to_db(maxf(g * _duck, 0.0001))
		if p.playing and not p.stream_paused and key != "fight":
			piece["pos"] = fposmod(float(piece["pos"]) + delta, float(piece["cue"]["length"]))
		if g <= 0.0 and float(piece["to"]) <= 0.0 and p.playing and not p.stream_paused:
			if key == "fight":
				p.stop()                 # (the next fish starts it from its intro)
				_fight_t0 = -1.0
			else:
				p.stream_paused = true   # (taken up from here when it's back)
		if g > best:
			best = g
			loud = key
	cue = loud
	sounding = loud


## Each piece's layers at the state's levels.
func _layers() -> void:
	for key: String in _pieces:
		var piece: Dictionary = _pieces[key]
		if float(piece["gain"]) <= 0.0 and float(piece["to"]) <= 0.0:
			continue
		var syncs: Array = piece["syncs"]
		var stems: Array = piece["stems"]
		for i in syncs.size():
			var names: Array = stems[i]
			var sync: AudioStreamSynchronized = syncs[i]
			for k in names.size():
				sync.set_sync_stream_volume(k, linear_to_db(maxf(state.level(str(names[k])), 0.0001)))


## A cue on a free player (the one that's rung longest if none is), from `from` s in.
func _play(n: String, from := 0.0) -> void:
	if not _streams.has(n) or _streams[n] == null:
		return
	var p: AudioStreamPlayer = _stings[0]
	for v in _stings:
		if not v.playing:
			p = v
			break
		if float(v.get_meta("at", 0.0)) < float(p.get_meta("at", 0.0)):
			p = v
	p.stream = _streams[n]
	p.set_meta("cue", n)
	p.set_meta("at", _t)
	p.play(from + float(Cues.CUES.get(n, {}).get("pre", 0.0)))
	sting = n
	_note("sting:" + n)


func _note(what: String) -> void:
	played.append([_t, what])
	played_n += 1
	if played.size() > PLAYED_N:
		played.pop_front()
	if _log_to != "":
		_log.append([_t, what])


## The duck, the pocket, the muffle, the pause.
func _mix(delta: float) -> void:
	var on := duck_test > 0.0
	var depth := DUCK if on else 1.0
	duck_test = maxf(duck_test - delta, 0.0)
	for b: StringName in DUCK_BUSES:
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
	for p in _stings:
		p.volume_db = linear_to_db(maxf(_duck * float(STING_LEVEL.get(str(p.get_meta("cue", "")), 1.0)), 0.0001))
	if _eq != null:
		for k in TONE.size():
			_eq.set_band_gain_db(k, float(TONE[k]) + (float(POCKET[k - 3]) * _pocket if k in [3, 4] else 0.0))
	var lp := 20000.0
	if bool(_world.get("underwater", false)):
		lp = UNDER_LP
	elif paused:
		lp = PAUSED_LP
	_lp = exp(move_toward(log(_lp), log(lp), delta * 12.0))
	if _lpf != null:
		_lpf.cutoff_hz = _lp


func _find_sea() -> Node:
	if _sea == null or not is_instance_valid(_sea) or not _sea.is_inside_tree():
		_sea = get_tree().get_first_node_in_group("sea")
	return _sea


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
		w["night"] = bool(sea.get("night")) or (not docked and float(hold.call("daylight")) < 0.2)
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		var card: Node = vs.get("card")
		w["card"] = card != null and bool(card.call("up"))
		if w["card"] and bool(card.call("stamped")):
			var d: Dictionary = card.get("data")
			var winner := int(d.get("winner", -1))
			w["card_result"] = "tie" if winner < 0 else ("win" if winner == int(card.get("mine")) else "lose")
		var ce := float(vs.get("count_end"))
		w["counting"] = COUNT - (ce - now_s) if ce >= 0.0 else -1.0
		if float(vs.get("home_by")) > 0.0 and not bool(vs.call("came_home", int(vs.get("my_team")))):
			w["race_left"] = float(vs.get("home_by")) - now_s
	elif float(sea.get("home_by")) > 0.0 and not docked:
		w["race_left"] = float(sea.get("home_by")) - now_s
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


func _sea_now(sea: Node) -> float:
	var ocean: Node = sea.get("ocean")
	return float(ocean.get("wave_time")) if ocean != null else 0.0
