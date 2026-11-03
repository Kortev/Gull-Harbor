extends Node
## The music's state (audio/music_state.gd), no sound at all: game pictures in, section, stems and events out. The quiet
## sea's endless song by the weather; birds working bring in the hunt; the strike; a fresh fish's runs drive it,
## his sounding takes it deep, a slack line drops the pulse, him in the air all but stops it, the line about to part
## strips it to the heartbeat and one note; tiring, the tune; the leader; boatside, the harpoon; landed, the
## afterglow; lost, silence. It never hears the hook's hold. Rivals: their fish on, the lead, the race home behind.
## Run: godot --headless --path . res://tests/music_state_test.tscn

const State := preload("res://audio/music_state.gd")
const DT := 1.0 / 30.0

var fails: Array[String] = []


func _ready() -> void:
	_sea()
	_hunt()
	_fight()
	_fair()
	_flap()
	_ends()
	_rivals()
	_done()


## Runs a world for `secs`, returns every event seen.
func _run(s: State, w: Dictionary, secs: float) -> Array:
	var seen: Array = []
	for i in maxi(1, int(round(secs / DT))):
		s.step(w, DT)
		seen.append_array(s.events)
	return seen


func _fish(more := {}) -> Dictionary:
	var f := {"id": "0:1.00", "tension": 0.2, "spool": 0.2, "depth": 10.0, "line_out": 120.0, "move": "run"}
	f.merge(more, true)
	return f


func _sea() -> void:
	var s := State.new(7)
	_run(s, {"condition": "calm", "docked": false, "day": 0.3}, 6.0)
	_check(s.section == "sea" and s.level("pick") > 0.95 and s.level("lead") > 0.85 and s.level("storm") == 0.0,
			"at sea, nothing on: the sea's song, fair weather's guitar and lead (%s)" % s.section)
	_check(s.bright > 0.7, "leaning to the bright passages (%.2f)" % s.bright)
	_run(s, {"condition": "storm", "docked": false, "day": 0.3}, 1.0)
	_check(s.level("storm") > 0.1 and s.level("storm") < 0.9 and s.level("pick") > 0.1,
			"the storm coming on: its drums rising as the guitar goes, not switched (%.2f, %.2f)"
			% [s.level("storm"), s.level("pick")])
	_run(s, {"condition": "storm", "docked": false, "day": 0.3}, 7.0)
	_check(s.level("storm") > 0.95 and s.level("pick") == 0.0 and s.level("lead") == 0.0 and s.bright == 0.0,
			"a storm: the drums and the drone, no tune, the dark passages")
	_run(s, {"condition": "rain", "docked": false, "day": 0.3}, 8.0)
	_check(s.level("rain") > 0.95 and s.level("storm") < 0.05, "rain: the patter")
	_run(s, {"condition": "calm", "docked": false, "night": true}, 8.0)
	_check(s.mood == "night" and s.level("night") > 0.95, "dark: the night's bells")
	_run(s, {"condition": "calm", "docked": false, "day": 0.98}, 0.1)
	_check(s.bright < 0.45, "dusk: darker (%.2f)" % s.bright)
	_run(s, {"condition": "calm", "docked": false, "day": 0.3, "speed": 0.95}, 4.0)
	_check(s.level("run") > 0.95 and s.level("bass") > 0.95, "running hard: the drums' eighths, the bass pushing")
	_run(s, {"condition": "calm", "docked": false, "day": 0.3, "speed": 0.0}, 9.0)
	_check(s.level("run") < 0.05, "drifting: gone again (%.2f)" % s.level("run"))
	var dn := State.new(1)
	_run(dn, {"docked": true}, 1.0)
	var ev := _run(dn, {"docked": false, "day": 0.02, "condition": "rain"}, DT)
	_check(ev.has("dawn") and dn.bright == 1.0, "heading out at first light: a bright passage next (%s)" % [ev])
	ev = _run(dn, {"docked": false, "day": 0.03, "condition": "rain"}, 1.0)
	_check(not ev.has("dawn"), "once a trip")
	# never quiet at sea, whatever happens, but for the hush
	var n := State.new(2)
	var quiet := 0.0
	for w: Dictionary in [{"docked": false}, {"docked": false, "birds": 0.5}, {"docked": true},
			{"docked": true, "condition": "storm"}, {"docked": false, "race_left": 100.0}, {"docked": false}]:
		for i in int(6.0 / DT):
			n.step(w, DT)
			if n.section == "rest":
				quiet += DT
	_check(quiet == 0.0, "never quiet, out or in, birds or none, any weather (%.1f s quiet)" % quiet)


func _hunt() -> void:
	var s := State.new(2)
	_run(s, {"docked": false, "birds": 0.05}, 1.0)
	_check(s.section == "sea", "birds far off: the sea")
	_run(s, {"docked": false, "birds": 0.6}, 3.0)
	_check(s.section == "hunt" and s.level("pulse") > 0.9 and s.level("tick") > 0.4,
			"birds working near: the hunt (pulse %.2f, tick %.2f)" % [s.level("pulse"), s.level("tick")])
	_run(s, {"docked": false, "birds": 0.08}, 1.0)
	_check(s.section == "hunt", "it holds as they drift off a little")
	var e := State.new(22)
	_run(e, {"docked": false, "birds": 0.2}, 1.0)
	_run(e, {"docked": false, "birds": 0.0}, 3.0)
	_check(e.section == "hunt", "birds at the edge of sight, gone again: the hunt holds its four bars")
	_run(e, {"docked": false, "birds": 0.0}, 6.0)
	_check(e.section == "sea", "then the sea")
	_run(s, {"docked": true}, 1.0)
	_check(s.section == "harbour", "tied up: the harbour")
	var h := State.new(21)
	_run(h, {"docked": true, "condition": "storm"}, 8.0)
	_check(h.section == "sea" and h.level("storm") > 0.95, "tied up in a thunderstorm: no waltz, the sea's storm (%s)"
			% h.section)
	_run(h, {"docked": true, "condition": "heavy"}, 1.0)
	_check(h.section == "sea", "a downpour at the dock: no waltz either")
	_run(h, {"docked": true, "condition": "rain"}, 3.0)
	_check(h.section == "harbour" and h.level("reed") == 0.0 and h.level("guitar") < 0.7,
			"rain: the guitar alone, quieter (%.2f)" % h.level("guitar"))
	_run(h, {"docked": true, "condition": "fog"}, 5.0)
	_check(h.level("reed") > 0.7 and h.level("guitar") < 0.3, "fog: the concertina far off, the guitar barely")


func _fight() -> void:
	var s := State.new(4)
	_run(s, {"docked": false, "birds": 0.6}, 2.0)
	var ev := _run(s, {"docked": false, "fights": [_fish()]}, DT)
	_check(ev.has("strike") and s.section == "fight", "fish on: the strike, the fight (%s)" % s.section)
	_run(s, {"docked": false, "fights": [_fish()]}, 1.0)
	_check(s.level("drive") > 0.95 and s.level("pulse") > 0.95 and s.level("tension") < 0.3 and s.level("tune") == 0.0,
			"his first run: drive %.2f, pulse %.2f, tension %.2f, no tune" % [s.level("drive"), s.level("pulse"),
			s.level("tension")])
	_check(s.level("shaker") > 0.9 and s.level("click") == 0.0, "by day the shaker")
	# sounding
	_run(s, {"docked": false, "fights": [_fish({"move": "sound", "depth": 90.0})]}, 3.0)
	_check(s.level("deep") > 0.9, "sounding deep: the deep comes in (%.2f)" % s.level("deep"))
	_run(s, {"docked": false, "fights": [_fish({"move": "sound", "depth": 90.0})]}, 6.0)
	_check(s.level("drive") < 0.5, "and the drive eases off once it's held its bars (%.2f)" % s.level("drive"))
	# slack, he shakes
	_run(s, {"docked": false, "fights": [_fish({"move": "shake", "slack": true})]}, 0.4)
	_check(s.level("pulse") < 0.05, "a slack line: the pulse drops out (%.2f)" % s.level("pulse"))
	_run(s, {"docked": false, "fights": [_fish({"move": "run"})]}, 0.4)
	_check(s.level("pulse") > 0.95, "tight again: back")
	# in the air
	_run(s, {"docked": false, "fights": [_fish({"move": "jump", "airborne": true})]}, 0.2)
	_check(s.level("drive") <= 0.16 and s.level("bed") <= 0.16 and s.level("pulse") <= 0.16,
			"him in the air: all but silence (drive %.2f)" % s.level("drive"))
	_run(s, {"docked": false, "fights": [_fish({"move": "run"})]}, 0.3)
	_check(s.level("drive") > 0.9, "back in: everything back (%.2f)" % s.level("drive"))
	# about to part
	_run(s, {"docked": false, "fights": [_fish({"tension": 0.62})]}, 0.25)
	_check(s.parting and s.level("drive") < 0.02 and s.level("deep") < 0.02 and s.level("tension") > 0.99
			and s.level("pulse") > 0.95 and absf(s.level("bed") - 0.3) < 0.05,
			"the line about to part: the heartbeat and one note (drive %.2f, tension %.2f, bed %.2f)"
			% [s.level("drive"), s.level("tension"), s.level("bed")])
	_run(s, {"docked": false, "fights": [_fish({"tension": 0.42})]}, 0.8)
	_check(not s.parting and s.level("drive") > 0.5 and s.level("tension") > 0.9,
			"eased, still loaded: the band back, the tension stem with it (%.2f)" % s.level("drive"))
	_run(s, {"docked": false, "fights": [_fish({"spool": 0.8, "tension": 0.2})]}, 2.0)
	_check(s.level("tension_hi") > 0.6 and s.level("drive") > 0.8,
			"the spool emptying: the high tremolo, the drive held (%.2f)" % s.level("tension_hi"))
	# tiring
	_run(s, {"docked": false, "fights": [_fish({"move": "circle", "spool": 0.2})]}, 5.0)
	_check(s.section == "tired" and s.level("tune") > 0.8, "circling: tired, the tune (%s, %.2f)"
			% [s.section, s.level("tune")])
	_run(s, {"docked": false, "fights": [_fish({"move": "circle", "spool": 0.2})]}, 4.0)
	_check(s.level("tension") < 0.5, "a played fish, the rod easy: the tension eases (%.2f)" % s.level("tension"))
	_run(s, {"docked": false, "fights": [_fish({"move": "surge", "spool": 0.2})]}, 1.0)
	_check(s.section == "tired", "a surge near her doesn't undo it")
	ev = _run(s, {"docked": false, "fights": [_fish({"move": "spiral", "line_out": 12.0})]}, DT)
	_check(s.section == "leader" and ev.has("leader"), "the leader up: the leader (%s)" % s.section)
	_run(s, {"docked": false, "fights": [_fish({"move": "run", "line_out": 30.0})]}, 2.0)
	_check(s.section == "leader", "his last run off the leader: still the leader")
	# night, storm
	var n := State.new(6)
	_run(n, {"docked": false, "night": true, "condition": "storm", "fights": [_fish({"depth": 5.0})]}, 2.0)
	_check(n.level("click") > 0.9 and n.level("shaker") == 0.0 and n.level("deep") >= 0.5,
			"a storm at night: the click not the shaker, the deep under it")
	var g := State.new(6)
	_run(g, {"docked": false, "fights": [_fish({"kg": 380.0})]}, 3.0)
	var sm := State.new(6)
	_run(sm, {"docked": false, "fights": [_fish({"kg": 40.0})]}, 3.0)
	_check(g.level("heavy") > 0.95 and sm.level("heavy") == 0.0 and g.level("deep") >= 0.5,
			"a giant on: his weight in it (the heavy stem, the deep); a little one, not")
	var c := State.new(6)
	_run(c, {"docked": false, "condition": "calm", "fights": [_fish({"depth": 5.0})]}, 2.0)
	_check(is_equal_approx(c.level("drive"), n.level("drive")) and c.level("drive") > 0.9,
			"flat calm drives a fight just as hard (%.2f)" % c.level("drive"))


## The hook's hold is never heard.
func _fair() -> void:
	var a := State.new(9)
	var b := State.new(9)
	var moves := ["run", "sound", "shake", "circle", "spiral", "jump"]
	var same := true
	for i in 600:
		var mv: String = moves[(i / 40) % moves.size()]
		var f := _fish({"move": mv, "tension": 0.3 + 0.35 * sin(i * 0.05), "line_out": 200.0 - i * 0.3})
		var g := f.duplicate()
		f["hold"] = 1.0
		g["hold"] = 0.05
		a.step({"docked": false, "fights": [f]}, DT)
		b.step({"docked": false, "fights": [g]}, DT)
		for k: String in a.gains:
			same = same and is_equal_approx(a.level(k), b.level(k))
		same = same and a.section == b.section
	_check(same, "the hook nearly out or set solid: the music's the same")


## A fish switching between running and dogging every half second: the drive doesn't flap with him.
func _flap() -> void:
	var s := State.new(8)
	var turns := 0
	var last := 0.0
	var dir := 0
	for i in int(20.0 / DT):
		var mv := "run" if (i / 15) % 2 == 0 else "dog"
		s.step({"docked": false, "fights": [_fish({"move": mv})]}, DT)
		var d := s.level("drive") - last
		if absf(d) > 0.001:
			var nd := 1 if d > 0.0 else -1
			if nd != dir and dir != 0:
				turns += 1
			dir = nd
		last = s.level("drive")
	_check(turns <= 2, "a fish flicking between moves: the drive holds (%d turns in 20 s)" % turns)


func _ends() -> void:
	# boatside, the harpoon, landed
	var s := State.new(10)
	_run(s, {"docked": false, "fights": [_fish({"line_out": 10.0})]}, 1.0)
	var ev := _run(s, {"docked": false, "alongside": ["0:1.00"], "landed": 0}, 0.5)
	_check(s.section == "gaff" and not ev.has("lost"), "up alongside: the gaff, nothing lost (%s)" % s.section)
	_run(s, {"docked": false, "alongside": ["0:1.00"], "landed": 0, "draw": 1.0}, 0.5)
	_check(s.level("shimmer") > 0.95, "winding up the harpoon: the shimmer rises")
	_run(s, {"docked": false, "alongside": ["0:1.00"], "landed": 0, "flying": true}, 0.15)
	_check(s.level("pulse") < 0.05 and s.level("bed") < 0.1, "the harpoon in the air: silence")
	ev = _run(s, {"docked": false, "alongside": [], "landed": 1}, DT)
	_check(ev.has("landed") and s.section == "afterglow", "he's in: the afterglow (%s)" % s.section)
	_run(s, {"docked": false, "landed": 1}, 30.0)
	_check(s.section == "sea", "then the sea again (%s)" % s.section)
	# lost
	var l := State.new(11)
	_run(l, {"docked": false, "fights": [_fish()]}, 2.0)
	ev = _run(l, {"docked": false}, DT)
	_check(ev.has("lost") and l.hush >= 5.9 and l.section == "rest", "the line goes: lost, the hush (%.1f s)" % l.hush)
	ev = _run(l, {"docked": false, "birds": 0.9}, 3.0)
	_check(l.section == "rest", "even birds wait out the silence")
	_run(l, {"docked": false}, 3.5)
	_check(l.section == "sea", "then the sea comes back (%s)" % l.section)
	_run(l, {"docked": false, "fights": [_fish()]}, 2.0)
	_run(l, {"docked": false}, DT)
	ev = _run(l, {"docked": false, "fights": [_fish({"id": "1:9.00"})]}, DT)
	_check(ev.has("strike") and l.hush == 0.0 and l.section == "fight", "but another fish on breaks it")
	# away from alongside
	var g := State.new(12)
	_run(g, {"docked": false, "alongside": ["2:3.00"], "landed": 4}, 1.0)
	ev = _run(g, {"docked": false, "alongside": [], "landed": 4}, 1.5)
	_check(ev.has("lost"), "he gets away from alongside: lost (%s)" % [ev])
	# two on, one lost: no hush
	var t := State.new(13)
	_run(t, {"docked": false, "fights": [_fish(), _fish({"id": "1:2.00"})]}, 1.0)
	ev = _run(t, {"docked": false, "fights": [_fish({"id": "1:2.00"})]}, DT)
	_check(not ev.has("lost") and t.section == "fight", "one of two lost: the other fight plays on")


func _rivals() -> void:
	var s := State.new(14)
	_run(s, {"docked": false, "their_on": 0, "lbs": [0, 0]}, 1.0)
	var ev := _run(s, {"docked": false, "their_on": 1, "lbs": [0, 0]}, DT)
	_check(ev.has("their_on"), "their fish on: the sting")
	ev = _run(s, {"docked": false, "their_on": 1, "lbs": [220, 0]}, DT)
	_check(ev.has("lead_up"), "you take the lead")
	ev = _run(s, {"docked": false, "their_on": 0, "lbs": [220, 300]}, 5.0)
	_check(not ev.has("lead_down"), "not twice in half a minute")
	ev = _run(s, {"docked": false, "their_on": 0, "lbs": [220, 300]}, 30.0)
	_check(ev.has("lead_down"), "then they've taken it")
	var r := State.new(15)
	_run(r, {"docked": false, "race_left": 340.0, "standing": 0}, 5.0)
	_check(r.section == "race" and r.level("a") == 1.0 and r.level("c") < 0.05 and r.level("d") == 0.0,
			"the race home: the rhythm, no urgency yet")
	_run(r, {"docked": false, "race_left": 60.0, "standing": -1}, 6.0)
	_check(r.level("c") > 0.95 and r.level("d") > 0.3, "behind with a minute left: the urgency, the last chance (%.2f)"
			% r.level("d"))
	_run(r, {"docked": false, "race_left": 50.0, "standing": 1}, 6.0)
	_check(r.level("b") > 0.84 and r.level("d") < 0.5, "ahead: the tune up, the last chance going")
	var f := State.new(16)
	_run(f, {"docked": false, "race_left": 200.0}, 2.0)
	_run(f, {"docked": false, "race_left": 199.0, "fights": [_fish()]}, 1.0)
	_check(f.section == "fight", "a fish on in the race home: the fight first")
	var k := State.new(17)
	ev = _run(k, {"counting": 0.2}, DT)
	_check(ev.has("countdown") and k.section == "rest", "the countdown: its sting, quiet under it")
	ev = _run(k, {"card": true, "card_result": ""}, 1.0)
	ev = _run(k, {"card": true, "card_result": "win"}, DT)
	_check(ev.has("card:win") and k.section == "rest", "the card's stamp: yours, the win")


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("MUSIC STATE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
