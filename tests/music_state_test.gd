extends Node
## audio/music_state.gd on its own (no sound, no sea): the title; the weather's song (a passing shower doesn't swap
## it, a weather that stays does), softer tied up, her speed bringing the run up; the strike into the fight, its three
## layers with how hard he fights (a run hits at once, the lull comes slowly, the fight building, the leader the whole
## band, boatside the pulse); landed and lost; a double's second fish no new strike; Rivals' countdown and card; and
## nothing else cues anything (thunder, birds).
## Run: godot --headless --path . res://tests/music_state_test.tscn

const State := preload("res://audio/music_state.gd")
const DT := 1.0 / 30.0

var fails: Array[String] = []


func _ready() -> void:
	_songs()
	_fight()
	_ends()
	_rivals()
	for f in fails:
		print("FAIL ", f)
	print("MUSIC STATE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _run(s: State, w: Dictionary, secs: float) -> Array:
	var seen: Array = []
	for i in maxi(1, int(round(secs / DT))):
		s.step(w, DT)
		seen.append_array(s.events)
	return seen


func _fish(more := {}) -> Dictionary:
	var f := {"id": "0:1.00", "kg": 200.0, "tension": 0.25, "spool": 0.2, "depth": 10.0, "line_out": 150.0, "move": "run"}
	f.merge(more, true)
	return f


func _songs() -> void:
	var s := State.new()
	_run(s, {"title": true, "condition": "calm"}, 1.0)
	_check(s.place == "title", "the title's up: its piece (%s)" % s.place)
	_run(s, {"docked": true, "condition": "calm"}, 1.0)
	_check(s.place == "song" and s.song == "fair" and s.docked, "tied up in fair weather: the fair song, softer (%s, %s)"
			% [s.place, s.song])
	_run(s, {"docked": false, "condition": "calm", "speed": 0.0}, 3.0)
	_check(s.level("run") < 0.05 and s.level("band") > 0.99, "out there, drifting: the band, no run")
	_run(s, {"docked": false, "condition": "calm", "speed": 1.0}, 3.0)
	_check(s.level("run") > 0.95, "under way flat out: the run up (%.2f)" % s.level("run"))
	_run(s, {"docked": false, "condition": "rain"}, 3.0)
	_check(s.song == "fair", "a passing shower: the same song")
	_run(s, {"docked": false, "condition": "rain"}, State.SONG_HOLD)
	_check(s.song == "rain", "rain that stays: the rain's song (%s)" % s.song)
	var ev := _run(s, {"docked": false, "condition": "storm", "flash": 1.0}, State.SONG_HOLD + 1.0)
	_check(s.song == "storm" and ev.is_empty(), "a storm: its song, and the lightning cues nothing (%s)" % [ev])
	_run(s, {"docked": false, "condition": "calm", "night": true}, State.SONG_HOLD + 1.0)
	_check(s.song == "night", "dark: the night's song (%s)" % s.song)
	_run(s, {"docked": false, "condition": "fog"}, State.SONG_HOLD + 1.0)
	_check(s.song == "fog", "fog: its song (%s)" % s.song)
	ev = _run(s, {"docked": false, "condition": "fog", "birds": 1.0}, 5.0)
	_check(s.place == "song" and ev.is_empty(), "birds working: nothing cued, the song plays on")


func _fight() -> void:
	var s := State.new()
	_run(s, {"docked": false, "condition": "calm"}, 1.0)
	var ev := _run(s, {"docked": false, "condition": "calm", "fights": [_fish()]}, DT)
	_check(ev.has("strike") and s.place == "fight", "a fish on: the strike, the fight (%s)" % [ev])
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish()]}, 1.0)
	_check(s.level("pulse") > 0.99 and s.level("drums") > 0.99 and s.level("full") > 0.99,
			"his run: everything at once (drums %.2f, full %.2f)" % [s.level("drums"), s.level("full")])
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish({"move": "sound"})]}, 1.0)
	_check(s.level("full") > 0.3, "sounding: the band lets go slowly, not all at once (full %.2f)" % s.level("full"))
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish({"move": "sound"})]}, State.LAYER_HOLD + State.LAYER_OUT)
	_check(s.level("full") < 0.05 and s.level("drums") > 0.2 and s.level("pulse") > 0.99,
			"sounding a while: the pulse and some drums (drums %.2f, full %.2f)" % [s.level("drums"), s.level("full")])
	var ev2 := _run(s, {"docked": false, "condition": "calm", "fights": [_fish({"move": "sound"}),
			_fish({"id": "1:5.00", "move": "run"})]}, 1.0)
	_check(not ev2.has("strike"), "a double: the second fish rides the same fight, no new strike")
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish({"move": "sound", "tension": 0.9})]}, 1.0)
	_check(s.level("full") > 0.9, "the line near going: everything (danger %.2f)" % s.danger)
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish({"move": "circle"})]}, 100.0)
	_check(s.level("drums") > 0.5, "a long fight, him circling: the drums never right down (%.2f)" % s.level("drums"))
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish({"move": "circle", "line_out": 10.0})]}, 1.0)
	_check(s.level("full") > 0.9, "on the leader: the whole band (%.2f)" % s.level("full"))
	_run(s, {"docked": false, "condition": "calm", "alongside": ["0:1.00"], "landed": 0},
			State.LAYER_HOLD + State.LAYER_OUT + 0.5)
	_check(s.place == "fight" and s.level("pulse") > 0.99 and s.level("full") < 0.05,
			"alongside, the harpoon: the pulse, the band let go (full %.2f)" % s.level("full"))


func _ends() -> void:
	var s := State.new()
	_run(s, {"docked": false, "condition": "calm", "landed": 0}, 1.0)
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish()], "landed": 0}, 2.0)
	_run(s, {"docked": false, "condition": "calm", "alongside": ["0:1.00"], "landed": 0}, 2.0)
	var ev := _run(s, {"docked": false, "condition": "calm", "alongside": [], "landed": 1}, DT)
	_check(ev.has("landed") and s.place == "after", "he's in: landed, the flourish (%s)" % s.place)
	_run(s, {"docked": false, "condition": "calm", "landed": 1}, State.AFTER + 0.1)
	_check(s.place == "song", "then the song back (%s)" % s.place)
	_run(s, {"docked": false, "condition": "calm", "fights": [_fish({"id": "0:9.00"})], "landed": 1}, 2.0)
	ev = _run(s, {"docked": false, "condition": "calm", "landed": 1}, DT)
	_check(ev.has("lost") and s.place == "quiet" and s.still, "the line goes: lost, the quiet (%s)" % s.place)
	_run(s, {"docked": false, "condition": "calm", "landed": 1}, State.HUSH + 0.1)
	_check(s.place == "song", "then the song back (%s)" % s.place)


func _rivals() -> void:
	var s := State.new()
	_run(s, {"docked": true, "condition": "calm"}, 1.0)
	var ev := _run(s, {"docked": true, "condition": "calm", "counting": 0.5}, DT)
	_check(ev.has("countdown") and s.place == "quiet", "Rivals' countdown: its cue, quiet under it")
	_run(s, {"docked": false, "condition": "calm", "counting": -1.0}, 1.0)
	_check(s.place == "song", "GO: the song")
	ev = _run(s, {"docked": true, "condition": "calm", "card": true, "card_result": "win"}, DT)
	_check(ev.has("card:win") and s.place == "quiet", "the card's stamp: its cue, quiet under it (%s)" % [ev])


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
