extends Node
## The music (audio/music.gd) playing the real game: every piece's files there and as long as its bars; the title's
## piece while the title's up; SOLO, and once the glide's done the weather's song, soft tied up, the title's last chord
## ringing into it; out there, the song up; a fish on: the fight from its intro at once, the song gone under the hit,
## the intro running on into the fight's loop by itself. Then the music handed pictures of the game (world_test): the
## weather turning (one song into the next, slowly); he's in (the flourish, the song back); he's gone (the fight let
## go, quiet, the song back); Rivals' countdown and card; the radio ducking it. audio/music_state.gd's own test has the
## music's mind; this is it playing.
## Run: godot --headless --fixed-fps 30 --path . res://tests/music_test.tscn

const Sea := preload("res://sea/sea.gd")
const Title := preload("res://ui/title.gd")
const Cues := preload("res://audio/music_cues.gd")
const State := preload("res://audio/music_state.gd")
const DT := 1.0 / 30.0

var fails: Array[String] = []
var sea: Sea
var m: Node


func _ready() -> void:
	m = get_node("/root/Music")
	_manifest()
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	sea.schools.set("_next", 9999.0)
	sea.schools.set_process(false)     # (no stray bites: only the test hooks a fish)
	sea.set_condition("calm")
	var t := Title.new()
	t.name = "Title"
	t.sea = sea
	sea.title = t
	sea.add_child(t)
	await _frames(3)
	_check(m.state.place == "title" and m.level("title") > m.TITLE - 0.05, "the title's up: its piece (%s)" % m.cue)
	t.call("_solo")
	var waited := 0.0
	while t.busy() and waited < 20.0:
		await get_tree().process_frame
		waited += DT
	await _secs(3.0)
	_check(m.cue == "song_fair" and absf(m.level("song_fair") - m.HARBOUR) < 0.05 and m.level("title") < 0.01,
			"the title down, tied up: the fair song, softer (%s %.2f)" % [m.cue, m.level("song_fair")])
	_check(_played("sting:title_end"), "the title's last chord ringing into it")
	sea.fish_hold.head_out()
	await _secs(m.BACK_IN + 0.5)
	_check(m.level("song_fair") > m.SEA - 0.01, "out there: the song up (%.2f)" % m.level("song_fair"))
	# a fish on
	sea.rods.host_cast(0)
	sea.rods.strike(0, 150.0)
	await _frames(2)
	_check(m.state.place == "fight" and m.level("fight") > 0.99 and _played("strike"),
			"fish on: the fight from its intro, at once (%.2f)" % m.level("fight"))
	await _secs(m.STRIKE_OUT + 0.1)
	_check(m.level("song_fair") < 0.01, "the song gone under the hit (%.2f)" % m.level("song_fair"))
	var pb := (m.get("_pieces")["fight"]["player"] as AudioStreamPlayer).get_stream_playback() as AudioStreamPlaybackInteractive
	var wall := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < int((float(Cues.CUES["fight_intro"]["length"]) + 1.0) * 1000.0):
		await get_tree().process_frame
	_check(pb != null and pb.get_current_clip_index() == 1, "the intro run on into the fight's loop by itself (clip %d)"
			% (pb.get_current_clip_index() if pb != null else -9))
	_check(m.state.level("pulse") > 0.99, "the fight's pulse under it")
	await _worlds()
	_done()


## The rest from pictures of the game: the weather, landing him, losing one, Rivals, the radio.
func _worlds() -> void:
	m.world_test = {"docked": false, "condition": "calm", "landed": 0}
	await _secs(m.FIGHT_OUT + m.BACK_IN + 1.0)
	_check(m.cue == "song_fair" and m.level("song_fair") > m.SEA - 0.01, "no fish: the song back (%s)" % m.cue)
	m.world_test = {"docked": false, "condition": "rain", "landed": 0}
	await _secs(State.SONG_HOLD + m.SONG_FADE * 0.5)
	_check(m.level("song_rain") > 0.3 * m.SEA and m.level("song_rain") < 0.7 * m.SEA and m.level("song_fair") > 0.3 * m.SEA,
			"the rain come to stay: its song coming in as the fair one goes, slowly (%.2f, %.2f)"
			% [m.level("song_rain"), m.level("song_fair")])
	await _secs(m.SONG_FADE * 0.5 + 0.5)
	_check(m.cue == "song_rain" and m.level("song_fair") < 0.01, "and through (%s)" % m.cue)
	# landing him
	var fish := {"id": "0:1.00", "kg": 200.0, "tension": 0.25, "spool": 0.2, "line_out": 150.0, "move": "run"}
	m.world_test = {"docked": false, "condition": "rain", "landed": 0, "fights": [fish]}
	await _secs(1.0)
	m.world_test = {"docked": false, "condition": "rain", "landed": 0, "alongside": ["0:1.00"]}
	await _secs(1.0)
	m.world_test = {"docked": false, "condition": "rain", "landed": 1}
	await _secs(0.5)
	_check(_played("sting:landed") and m.state.place == "after" and m.level("song_rain") < 0.01,
			"he's in: the flourish, the fight going, the song not back yet")
	await _secs(State.AFTER + m.BACK_IN + 0.5)
	_check(m.level("fight") < 0.01 and m.level("song_rain") > m.SEA - 0.01, "then the song back (%.2f)" % m.level("song_rain"))
	# losing one
	m.world_test = {"docked": false, "condition": "rain", "landed": 1, "fights": [fish.merged({"id": "0:7.00"})]}
	await _secs(2.0)
	m.world_test = {"docked": false, "condition": "rain", "landed": 1}
	await _secs(m.LOST_OUT + 0.2)
	_check(m.state.place == "quiet" and m.level("fight") < 0.01 and m.level("song_rain") < 0.01,
			"the line goes: the fight let go, quiet")
	await _secs(State.HUSH + m.BACK_IN + 0.3)
	_check(m.level("song_rain") > m.SEA - 0.01, "then the song back")
	# Rivals
	m.world_test = {"docked": true, "condition": "rain", "landed": 1, "counting": 0.5}
	await _secs(m.QUIET_OUT + 0.2)
	_check(_played("sting:countdown") and m.level("song_rain") < 0.01, "Rivals: the countdown, quiet under it")
	m.world_test = {"docked": true, "condition": "rain", "landed": 1, "card": true, "card_result": "win"}
	await _frames(3)
	_check(_played("sting:win"), "the card's stamp: the win")
	# the radio ducks it
	m.world_test = {"docked": false, "condition": "rain", "landed": 1}
	m.duck_test = 1.0
	await _secs(0.5)
	_check(m.duck() < 0.65, "the radio on: the music ducks (%.2f)" % m.duck())
	await _secs(3.0)
	_check(m.duck() > 0.9, "and comes back up once it's off (%.2f)" % m.duck())
	m.world_test = {}


## Every piece's files are there; a loop is exactly its bars, a one-shot its bars and then its tail.
func _manifest() -> void:
	var ok := true
	for n: String in Cues.CUES:
		var c: Dictionary = Cues.CUES[n]
		for f: String in c["files"]:
			var s := load("res://music/%s.ogg" % f) as AudioStream
			if s == null:
				ok = false
				print("  missing ", f)
				continue
			if int(c.get("bars", 0)) > 0:
				var want := int(c["bars"]) * int(c["bar_beats"]) * 60.0 / float(c["bpm"]) \
						+ (0.0 if bool(c["loop"]) else float(c.get("tail", 0.0)))
				if absf(s.get_length() - want) > 0.002:
					ok = false
					print("  %s: %.4f s, its bars (and tail) %.4f" % [f, s.get_length(), want])
	_check(ok, "every piece's there, each exactly its bars long (a one-shot's and then its tail)")
	for k: String in ["title", "fight_intro", "fight", "song_fair", "song_rain", "song_fog", "song_night",
			"song_storm"]:
		_check(Cues.CUES.has(k), "the %s's made" % k)


func _played(what: String) -> bool:
	for p: Array in m.played:
		if str(p[1]) == what:
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await _frames(int(s / DT))


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("MUSIC TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
