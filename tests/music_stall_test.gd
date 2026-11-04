extends Node
## The song never runs out, whatever the frame rate does (Kortev: "it turned off the second i moved the boat"): a
## passage plays once (its tail after), so its next has to be asked for in its last bar, and Godot's interactive
## stream left with nothing after it stops for good. Here, through the real mixer at the real pace:
##   - the game freezes (2.6 s, a whole bar and more) in a passage's last bar: the next passage still comes in, on
##     the tail's next beat, and the song plays on;
##   - the bed stopped outright: it's started again and the song comes back within a couple of seconds.
## The real audio driver, so it needs a window (no --headless):
##   godot --path . --resolution 160x90 res://tests/music_stall_test.tscn

const Cues := preload("res://audio/music_cues.gd")
const STALL_MS := 2600

var fails: Array[String] = []
var m: Node
var _t := 0.0


func _ready() -> void:
	m = get_node("/root/Music")
	if DisplayServer.get_name() == "headless":
		print("MUSIC STALL TEST needs a window (the real audio driver): skipped")
		get_tree().quit(0)
		return
	m.world_test = {"docked": false, "condition": "calm", "day": 0.3}
	await _until(func() -> bool: return str(m.sounding).begins_with("sea_"), 20.0)
	_check(str(m.sounding).begins_with("sea_"), "the song's playing (%s)" % m.sounding)
	# just short of a passage's last bar (its next not asked for yet), then a frame that takes 2.6 s: the whole last bar
	# gone by in it, the end too
	await _until(func() -> bool:
		var s := str(m.sounding)
		if not s.begins_with("sea_") or not (m.get("_landing") as Dictionary).is_empty():
			return false
		var c: Dictionary = Cues.CUES[s]
		var bar := 60.0 / float(c["bpm"]) * int(c["bar_beats"])
		var left := float(m.get("_start")) + float(c["length"]) - float(m.get("_t"))
		return left > bar + 0.02 and left < bar + 0.3, 60.0)
	var was: String = m.sounding
	_check(m.get("_asked") == was, "a frame short of %s's last bar, its next not asked for yet" % was)
	OS.delay_msec(STALL_MS)
	await _secs(6.0)
	_check(m.sounding != was and _played("late:"), "a frame of 2.6 s over its end: the next came in late, on the tail (%s, was %s)"
			% [m.sounding, was])
	var heard := await _level(6.0)
	_check(heard > -45.0, "and the song plays on (%.1f dB)" % heard)
	# the bed stopped outright
	(m.get("_bed") as AudioStreamPlayer).stop()
	await _secs(3.0)
	_check(_played("revived") and (m.get("_bed") as AudioStreamPlayer).playing and str(m.sounding).begins_with("sea_"),
			"the bed stopped outright: started again, the song back (%s)" % m.sounding)
	heard = await _level(4.0)
	_check(heard > -45.0, "and heard (%.1f dB)" % heard)
	for f in fails:
		print("FAIL ", f)
	print("MUSIC STALL TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## The bed's loudest over `secs` s (dB).
func _level(secs: float) -> float:
	var i := AudioServer.get_bus_index(&"MusicBed")
	var best := -200.0
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		best = maxf(best, maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0)))
	return best


func _played(prefix: String) -> bool:
	for p: Array in m.played:
		if str(p[1]).begins_with(prefix):
			return true
	return false


func _until(ok: Callable, secs: float) -> void:
	var t := 0.0
	while t < secs and not ok.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _secs(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
