extends Node
## The music on the real sound card, at the real pace (every other music test runs headless or under the movie
## maker, where nothing's mixed as it would be): the song heard; a strike heard at once (the hit within a tenth of a
## second), its intro running on into the fight's loop; he's in: the flourish, then the song again; and never silent
## but where it's meant to be. The game's pictures handed to it (world_test).
## The real audio driver, so it needs a window (no --headless):
##   godot --path . --resolution 160x90 res://tests/music_live_test.tscn

const Cues := preload("res://audio/music_cues.gd")
const State := preload("res://audio/music_state.gd")

var fails: Array[String] = []
var m: Node
var _quiet := 0.0           # (the longest the music bus went silent while it was meant to play, s)
var _q := 0.0               # (how long it's been silent now)


func _ready() -> void:
	m = get_node("/root/Music")
	if DisplayServer.get_name() == "headless":
		print("MUSIC LIVE TEST needs a window (the real audio driver): skipped")
		get_tree().quit(0)
		return
	var fish := {"id": "0:1.00", "kg": 200.0, "tension": 0.25, "spool": 0.2, "line_out": 150.0, "move": "run"}
	m.world_test = {"docked": false, "condition": "calm", "landed": 0}
	var heard := await _level(6.0)
	_check(m.cue == "song_fair" and heard > -40.0, "out there: the song, heard (%.1f dB)" % heard)
	var before := _bus()
	m.world_test = {"docked": false, "condition": "calm", "landed": 0, "fights": [fish]}
	var t0 := Time.get_ticks_msec()
	var hit := -1.0
	while Time.get_ticks_msec() - t0 < 600:
		await get_tree().process_frame
		if hit < 0.0 and _bus() > maxf(before + 6.0, -14.0):
			hit = (Time.get_ticks_msec() - t0) / 1000.0
	_check(hit >= 0.0 and hit <= 0.1, "the strike: its hit heard at once (%.3f s; before %.1f dB)" % [hit, before])
	await _wall(float(Cues.CUES["fight_intro"]["length"]) + 1.5)
	var pb := (m.get("_pieces")["fight"]["player"] as AudioStreamPlayer).get_stream_playback() as AudioStreamPlaybackInteractive
	heard = await _level(3.0)
	_check(pb != null and pb.get_current_clip_index() == 1 and heard > -40.0,
			"the intro run on into the fight's loop, heard (%.1f dB)" % heard)
	m.world_test = {"docked": false, "condition": "calm", "landed": 0, "alongside": ["0:1.00"]}
	await _wall(1.0)
	m.world_test = {"docked": false, "condition": "calm", "landed": 1}
	await _wall(0.5)
	_check(m.sting == "landed", "he's in: the flourish (%s)" % m.sting)
	await _wall(State.AFTER + m.BACK_IN + 0.5)
	heard = await _level(3.0)
	_check(m.cue == "song_fair" and heard > -40.0, "then the song again, heard (%.1f dB)" % heard)
	_check(_quiet < 0.5, "never silent where it's meant to play (the longest %.2f s)" % _quiet)
	m.world_test = {}
	for f in fails:
		print("FAIL ", f)
	print("MUSIC LIVE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _process(delta: float) -> void:
	if m == null or m.state == null:
		return
	var on: bool = m.state.place in ["song", "fight", "title"] and float(m.get("_duck")) > 0.9
	_q = _q + delta if on and _bus() < -60.0 else 0.0
	_quiet = maxf(_quiet, _q)


## The Music bus's loudest over `secs` s (dB).
func _level(secs: float) -> float:
	var best := -200.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().process_frame
		best = maxf(best, _bus())
	return best


func _bus() -> float:
	var i := AudioServer.get_bus_index(&"Music")
	return maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))


func _wall(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
