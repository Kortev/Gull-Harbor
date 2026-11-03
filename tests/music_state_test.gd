extends Node
## The music's state (audio/music_state.gd), no sound at all: game pictures in, section, stems and events out. It's
## one song whatever's happening (the same layers always), the weather playing it; birds working bring in the pulse
## and the bells; the strike; a fresh fish's runs drive it, his sounding takes it deep, a slack line drops the
## heartbeat, him in the air all but stops it, the line about to part strips it to the heartbeat and one note; tiring,
## the song's tune comes back; the leader, the climax; boatside, the harpoon; landed, the song lifted; lost, silence.
## It never hears the hook's hold. Rivals: their fish on, the lead, the race home behind. The cues: birds, casting
## off, boatside, the race called, home made.
## Run: godot --headless --path . res://tests/music_state_test.tscn

const State := preload("res://audio/music_state.gd")
const DT := 1.0 / 30.0

var fails: Array[String] = []


func _ready() -> void:
	_sea()
	_hunt()
	_storm()
	_scenic()
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
	_check(s.level("storm") > 0.95 and s.level("pick") == 0.0 and s.level("lead") < 0.5 and s.bright == 0.0,
			"a storm: the drums and the drone, no guitar, only the concertina's low line, the dark passages")
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
	# one song: whatever's happening, the same layers
	var o := State.new(3)
	var same := true
	for w: Dictionary in [{"docked": true}, {"docked": false}, {"docked": false, "birds": 0.6},
			{"docked": false, "fights": [_fish()]}, {"docked": false, "fights": [_fish({"move": "circle"})]},
			{"docked": false, "fights": [_fish({"line_out": 10.0})]}, {"docked": false, "alongside": ["0:1.00"]},
			{"docked": false, "landed": 1}, {"docked": false, "race_left": 100.0}]:
		_run(o, w, 5.0)
		var keys: Array = o.gains.keys()
		keys.sort()
		var want: Array = State.SEA_STEMS.duplicate()
		want.sort()
		same = same and keys == want
		if keys != want:
			print("  %s: %s" % [o.section, keys])
	_check(same, "one song: the dock, the sea, birds, a fish on, tiring, the leader, boatside, landed, the race "
			+ "home, all the same song's layers")


## A storm: its own layers (the gale's strings, drums rolling, the wind's howl; the drum section; the tension never
## quite off; the deep), and each lightning strike a cue.
func _storm() -> void:
	var s := State.new(41)
	_run(s, {"docked": false, "condition": "storm", "day": 0.4}, 8.0)
	_check(s.level("gale") > 0.95 and s.level("pound") > 0.3 and s.level("tension") > 0.25 and s.level("pick") == 0.0,
			"a storm: the gale, the drums, the tension never quite off, no guitar (gale %.2f, pound %.2f, tension %.2f)"
			% [s.level("gale"), s.level("pound"), s.level("tension")])
	var ev := _run(s, {"docked": false, "condition": "storm", "flash": 1.0}, DT)
	_check(ev.has("lightning"), "lightning: its cue")
	ev = _run(s, {"docked": false, "condition": "storm", "flash": 0.95}, 0.2)
	_check(not ev.has("lightning"), "once a strike")
	_run(s, {"docked": false, "condition": "storm", "flash": 0.0}, 0.2)
	ev = _run(s, {"docked": false, "condition": "storm", "flash": 1.0}, DT)
	_check(ev.has("lightning"), "and the next")
	var c := State.new(42)
	ev = _run(c, {"docked": false, "condition": "calm", "flash": 1.0}, DT)
	_check(not ev.has("lightning"), "no storm, no cue")
	var f := State.new(43)
	_run(f, {"docked": false, "fights": [_fish({"move": "run"})]}, 2.0)
	_check(f.level("pound") > 0.6, "his run: the whole drum section in (%.2f)" % f.level("pound"))
	_run(f, {"docked": false, "fights": [_fish({"move": "spiral", "line_out": 10.0})]}, 2.0)
	_check(f.level("pound") > 0.95, "the leader: all of it")


## The scenic silences: casting off in fair weather the band lets go till she's out past the harbour mouth, then
## back on the theme; a long quiet stretch, a rest; birds or a fish break them at once; never in a storm.
func _scenic() -> void:
	var s := State.new(44)
	_run(s, {"docked": true, "condition": "calm"}, 1.0)
	var ev := _run(s, {"docked": false, "condition": "calm", "past_mouth": -200.0}, DT)
	_check(ev.has("away") and ev.has("scenic") and s.scenic == "out" and s.still,
			"casting off: the band lets the song go (%s)" % [ev])
	ev = _run(s, {"docked": false, "condition": "calm", "past_mouth": 0.0}, 20.0)
	_check(s.scenic == "out" and not ev.has("return_theme"), "through the harbour: still the sea alone")
	ev = _run(s, {"docked": false, "condition": "calm", "past_mouth": 160.0}, DT)
	_check(ev.has("return_theme") and s.scenic == "", "out past the mouth: back in, on the theme")
	var st := State.new(45)
	_run(st, {"docked": true, "condition": "storm"}, 1.0)
	ev = _run(st, {"docked": false, "condition": "storm", "past_mouth": -200.0}, DT)
	_check(ev.has("away") and st.scenic == "", "casting off into a storm: no silence, its music")
	var b := State.new(46)
	_run(b, {"docked": true, "condition": "fog"}, 1.0)
	_run(b, {"docked": false, "condition": "fog", "past_mouth": -100.0}, 5.0)
	ev = _run(b, {"docked": false, "condition": "fog", "past_mouth": -50.0, "birds": 0.7}, DT)
	_check(ev.has("wake") and b.scenic == "", "birds while she's still going out: it breaks at once")
	var r := State.new(47)
	_run(r, {"docked": false, "condition": "calm"}, 1.0)
	r.set("_rest_due", 30.0)
	ev = _run(r, {"docked": false, "condition": "calm"}, 31.0)
	_check(ev.has("scenic") and r.scenic == "rest", "a long quiet stretch: the band rests")
	ev = _run(r, {"docked": false, "condition": "calm"}, 21.0)
	_check(ev.has("return") and r.scenic == "", "and comes back in")


func _hunt() -> void:
	var s := State.new(2)
	_run(s, {"docked": false, "birds": 0.05}, 1.0)
	_check(s.section == "sea", "birds far off: the sea")
	_run(s, {"docked": false, "birds": 0.6}, 3.0)
	_check(s.section == "hunt" and s.level("pulse") > 0.9 and s.level("glint") > 0.4 and s.level("pad") > 0.5,
			"birds working near: the pulse ticking, the bells, the song on under them (pulse %.2f, glint %.2f)"
			% [s.level("pulse"), s.level("glint")])
	var bi := State.new(31)
	_run(bi, {"docked": false}, 1.0)
	var bev := _run(bi, {"docked": false, "birds": 0.6}, DT)
	_check(bev.has("birds"), "the first sight of them: the bells' cue")
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
	_check(s.level("pick") < 0.75 and s.level("drive") == 0.0, "the song quiet, the guitar soft, no drums")
	var h := State.new(21)
	_run(h, {"docked": true, "condition": "storm"}, 8.0)
	_check(h.section == "harbour" and h.level("storm") > 0.95 and h.level("pick") == 0.0,
			"tied up in a thunderstorm: the song's storm, no guitar (%s)" % h.section)
	_run(h, {"docked": true, "condition": "rain"}, 8.0)
	_check(h.level("rain") > 0.9 and h.level("pick") < 0.5, "rain at the dock: the patter, the guitar quieter")
	var aw := _run(h, {"docked": false, "condition": "rain"}, DT)
	_check(aw.has("away"), "casting off: its cue")


func _fight() -> void:
	var s := State.new(4)
	_run(s, {"docked": false, "birds": 0.6}, 2.0)
	var ev := _run(s, {"docked": false, "fights": [_fish()]}, DT)
	_check(ev.has("strike") and s.section == "fight", "fish on: the strike, the fight (%s)" % s.section)
	_run(s, {"docked": false, "fights": [_fish()]}, 1.0)
	_check(s.level("drive") > 0.95 and s.level("beat") > 0.95 and s.level("tension") < 0.3 and s.level("high") == 0.0,
			"his first run: drive %.2f, the heartbeat %.2f, tension %.2f, no climax" % [s.level("drive"),
			s.level("beat"), s.level("tension")])
	_run(s, {"docked": false, "fights": [_fish()]}, 3.0)
	_check(s.level("pad") > 0.5 and s.level("bass") > 0.5 and s.level("lead") < 0.3,
			"the song carries on under it, its tune stepping back (lead %.2f)" % s.level("lead"))
	# sounding
	_run(s, {"docked": false, "fights": [_fish({"move": "sound", "depth": 90.0})]}, 3.0)
	_check(s.level("deep") > 0.9, "sounding deep: the deep comes in (%.2f)" % s.level("deep"))
	_run(s, {"docked": false, "fights": [_fish({"move": "sound", "depth": 90.0})]}, 6.0)
	_check(s.level("drive") < 0.5, "and the drive eases off once it's held its bars (%.2f)" % s.level("drive"))
	# slack, he shakes
	_run(s, {"docked": false, "fights": [_fish({"move": "shake", "slack": true})]}, 0.4)
	_check(s.level("beat") < 0.05, "a slack line: the heartbeat drops out (%.2f)" % s.level("beat"))
	_run(s, {"docked": false, "fights": [_fish({"move": "run"})]}, 0.4)
	_check(s.level("beat") > 0.95, "tight again: back")
	# in the air
	_run(s, {"docked": false, "fights": [_fish({"move": "jump", "airborne": true})]}, 0.2)
	_check(s.level("drive") <= 0.16 and s.level("pad") <= 0.16 and s.level("beat") <= 0.16,
			"him in the air: all but silence (drive %.2f)" % s.level("drive"))
	_run(s, {"docked": false, "fights": [_fish({"move": "run"})]}, 0.3)
	_check(s.level("drive") > 0.9, "back in: everything back (%.2f)" % s.level("drive"))
	# about to part
	_run(s, {"docked": false, "fights": [_fish({"tension": 0.62})]}, 0.25)
	_check(s.parting and s.level("drive") < 0.02 and s.level("deep") < 0.02 and s.level("tension") > 0.99
			and s.level("beat") > 0.95 and s.level("pad") < 0.35 and s.level("pick") < 0.02 and s.level("lead") < 0.02,
			"the line about to part: the heartbeat and one note (drive %.2f, tension %.2f, pad %.2f)"
			% [s.level("drive"), s.level("tension"), s.level("pad")])
	_run(s, {"docked": false, "fights": [_fish({"tension": 0.42})]}, 0.8)
	_check(not s.parting and s.level("drive") > 0.5 and s.level("tension") > 0.9,
			"eased, still loaded: the band back, the tension stem with it (%.2f)" % s.level("drive"))
	_run(s, {"docked": false, "fights": [_fish({"spool": 0.8, "tension": 0.2})]}, 2.0)
	_check(s.level("tension") > 0.45 and s.level("drive") > 0.8,
			"the spool emptying: the tension, the drive held (%.2f)" % s.level("tension"))
	# tiring
	_run(s, {"docked": false, "fights": [_fish({"move": "circle", "spool": 0.2})]}, 5.0)
	_check(s.section == "tired" and s.level("lead") > 0.6, "circling: tired, the song's tune coming back (%s, %.2f)"
			% [s.section, s.level("lead")])
	_run(s, {"docked": false, "fights": [_fish({"move": "circle", "spool": 0.2})]}, 4.0)
	_check(s.level("tension") < 0.5, "a played fish, the rod easy: the tension eases (%.2f)" % s.level("tension"))
	_run(s, {"docked": false, "fights": [_fish({"move": "surge", "spool": 0.2})]}, 1.0)
	_check(s.section == "tired", "a surge near her doesn't undo it")
	ev = _run(s, {"docked": false, "fights": [_fish({"move": "spiral", "line_out": 12.0})]}, DT)
	_check(s.section == "leader" and ev.has("leader"), "the leader up: the leader (%s)" % s.section)
	_run(s, {"docked": false, "fights": [_fish({"move": "run", "line_out": 30.0})]}, 2.0)
	_check(s.section == "leader", "his last run off the leader: still the leader")
	_check(s.level("high") > 0.9 and s.level("lead") > 0.95, "the climax: the lead up high (%.2f)" % s.level("high"))
	# night, storm
	var n := State.new(6)
	_run(n, {"docked": false, "night": true, "condition": "storm", "fights": [_fish({"depth": 5.0})]}, 2.0)
	_check(n.level("storm") > 0.5 and n.level("deep") >= 0.5 and n.level("drive") > 0.9,
			"a fight in a storm at night: the storm's drums and the deep under it")
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
	_check(s.section == "gaff" and not ev.has("lost") and ev.has("boatside"),
			"up alongside: boatside's cue, nothing lost (%s)" % s.section)
	_run(s, {"docked": false, "alongside": ["0:1.00"], "landed": 0}, 4.0)
	_check(s.level("beat") > 0.95 and s.level("drive") < 0.4, "the heartbeat, the drums down")
	_run(s, {"docked": false, "alongside": ["0:1.00"], "landed": 0, "draw": 1.0}, 1.0)
	_check(s.level("tension") > 0.95, "winding up the harpoon: the tension rises with it")
	_run(s, {"docked": false, "alongside": ["0:1.00"], "landed": 0, "flying": true}, 0.15)
	_check(s.level("beat") < 0.05 and s.level("pad") < 0.1, "the harpoon in the air: silence")
	ev = _run(s, {"docked": false, "alongside": [], "landed": 1}, DT)
	_check(ev.has("landed") and s.section == "afterglow", "he's in: the afterglow (%s)" % s.section)
	_run(s, {"docked": false, "landed": 1}, 3.0)
	_check(s.level("lead") > 0.95 and s.level("high") > 0.5, "the song lifted, the theme up high")
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
	_check(r.section == "race" and r.level("run") > 0.55 and r.level("drive") < 0.05,
			"the race home: under way, no urgency yet")
	_run(r, {"docked": false, "race_left": 60.0, "standing": -1}, 6.0)
	_check(r.level("drive") > 0.95 and r.level("tension") > 0.3,
			"behind with a minute left: the drums, the tension (%.2f)" % r.level("tension"))
	_run(r, {"docked": false, "race_left": 50.0, "standing": 1}, 10.0)
	_check(r.level("high") > 0.84 and r.level("tension") < 0.5, "ahead: the tune up high, the tension going")
	var rc := State.new(18)
	_run(rc, {"docked": false}, 1.0)
	var rev := _run(rc, {"docked": false, "race_left": 300.0}, DT)
	_check(rev.has("race"), "the race home called: its cue")
	rev = _run(rc, {"docked": true}, DT)
	_check(rev.has("home"), "home made: its cue")
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
