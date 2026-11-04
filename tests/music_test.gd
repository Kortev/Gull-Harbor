extends Node
## The music (audio/music.gd) follows the real game, and everything lands on the grid: the title theme while the
## title's up; SOLO, and once the glide's done the song, the title's chord ringing into it; casting off, its lead-in;
## one passage into the next on the bar; the race home called, home made, a fish on: cues on the song's beat, never
## another song; the radio ducks it. Rivals: the countdown's sting (nothing else under it), and the results card's as
## its stamp lands (your boat won: win). And each weather's song as the conductor walks it (_forms()).
## audio/music_state.gd's own test has the music's mind; this is it playing.
## Run: godot --headless --fixed-fps 30 --path . res://tests/music_test.tscn

const Sea := preload("res://sea/sea.gd")
const Title := preload("res://ui/title.gd")
const Card := preload("res://vs/card.gd")
const Cues := preload("res://audio/music_cues.gd")
const MusicScript := preload("res://audio/music.gd")
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
	sea.set_condition("calm")          # (the weather's dice: a storm at the dock has no waltz)
	var t := Title.new()
	t.name = "Title"
	t.sea = sea
	sea.title = t
	sea.add_child(t)
	await _frames(3)
	_check(m.cue == "title" and m.sounding == "title", "the title's up: the title theme (%s)" % m.sounding)
	# SOLO: the title theme through the intro and the glide, then the quiet at sea
	t.call("_solo")
	await _frames(2)
	_check(m.cue == "title", "the intro and the glide: still the title")
	var waited := 0.0
	while t.busy() and waited < 20.0:
		await get_tree().process_frame
		waited += DT
	await _frames(2)
	_check(m.cue == "harbour", "the title down: tied up, the harbour (%s)" % m.cue)
	await _secs(2.5)
	_check(str(m.sounding).begins_with("sea_") and _on_grid("clip:" + m.sounding, "bar"),
			"the song, on the title's bar (%s)" % m.sounding)
	_check(_played("sting:title_end"), "the title's last chord ringing over it")
	var song: String = m.sounding
	sea.fish_hold.head_out()
	await _frames(2)
	_check(m.cue == "sea", "heading out: the sea (%s)" % m.cue)
	await _secs(2.5)
	_check(_played("sting:away_in") and _on_grid("sting:away_in", "beat"), "casting off: its lead-in, on the beat")
	await _secs(17.0)
	_check(str(m.sounding).begins_with("sea_") and m.sounding != song and _on_grid("clip:" + m.sounding, "bar"),
			"and on, one passage into another on the bar (%s, %s)" % [song, m.sounding])
	# dusk: the race home (time's up in Sea.HOME s)
	sea.call("_set_home", float(sea.ocean.wave_time) + Sea.HOME)
	await _frames(2)
	_check(m.cue == "race", "dusk, still out: the race home (%s)" % m.cue)
	await _secs(2.5)
	_check(_played("sting:race_in"), "its lead-in")
	_check(m.level("run") > 0.5, "under way")
	sea.home_by = float(sea.ocean.wave_time) + 30.0
	await _secs(6.0)
	_check(m.level("drive") > 0.9, "30 s left: the drums all the way (%.2f)" % m.level("drive"))
	# home: tied up, the race is over
	var playing: String = m.sounding
	sea.fish_hold.set("docked", true)
	await _frames(2)
	_check(m.cue == "harbour", "tied up: the harbour (%s)" % m.cue)
	await _secs(2.0)
	_check(_played("sting:race_end") and str(m.sounding).begins_with("sea_"), "home made: its hit, the same song on")
	# the radio ducks it
	m.duck_test = 1.0
	await _secs(0.5)
	_check(m.duck() < 0.65, "the radio on: the music ducks (%.2f)" % m.duck())
	await _secs(3.0)
	_check(m.duck() > 0.9, "and comes back up once it's off (%.2f)" % m.duck())
	# out again, a fish on
	sea.home_by = -1.0
	sea.fish_hold.head_out()
	await _secs(1.0)
	var before: String = m.sounding
	sea.rods.host_cast(0)
	sea.rods.strike(0, 150.0)
	await _frames(3)
	_check(m.cue == "fight", "fish on: the fight (%s)" % m.cue)
	await _secs(1.0)
	_check(_played("sting:strike") and _on_grid("sting:strike", "beat"), "the strike's hit, on the song's beat")
	await _secs(2.5)
	_check(_played("sting:fight_in") and bool(Cues.CUES.get(m.sounding, {}).get("fight", false))
			and _on_grid("clip:" + m.sounding, "bar"),
			"the bar after: the song turned dark, into the fight's own (%s, was %s), its break driving in"
			% [m.sounding, before])
	_check(m.level("beat") > 0.9 and m.level("drive") > 0.5, "the heartbeat and the drums on it")
	var bb: Vector2 = m.bar_beat()
	_check(bb.x >= 0.0, "the song's clock running (bar %d, beat %d)" % [bb.x, bb.y])
	# Rivals (tied up, all of them): the countdown's sting, then the card's
	sea.fish_hold.set("docked", true)
	sea.vs.host_set_on(true)
	await _frames(5)
	_check(float(sea.vs.count_end) > 0.0 and m.sting == "countdown" and m.cue == "rest",
			"Rivals: the countdown, its sting, quiet under it (%s, %s)" % [m.sting, m.cue])
	sea.vs.card.open({"decided": false, "winner": 0, "day": 1, "wins": [1, 0], "crewed": [true, true],
			"day_lb": [220.0, 110.0], "boats": [{"fish": 2, "kg": 100.0, "big": 60.0, "money": 900, "late": 0, "lb": 220.0},
			{"fish": 2, "kg": 100.0, "big": 60.0, "money": 450, "late": 1, "lb": 110.0}]}, 0)
	await _secs(Card.T_STAMP + Card.STAMP + 0.2)
	_check(m.sting == "win" and m.cue == "rest", "the card's stamp lands, your boat's: the win sting (%s)" % m.sting)
	sea.vs.card.close()
	_forms()
	_done()


## The weather's songs as the conductor walks them (its own pick, no time passing, nothing awaited so nothing else
## plays meanwhile): each weather's from its intro through its form to its outro, then round again from its first
## verse; the weather turning mid-song heads for the outro, and the new weather's song comes in from its top; back
## from a fight, the weather's first verse; the theme's first half, its second.
func _forms() -> void:
	var forms: Dictionary = Cues.CUES.get("songs", {}).get("forms", {})
	_check(forms.size() == MusicScript.MOOD_SONG.size(), "a song for each weather (%s)" % ", ".join(forms.keys()))
	m.set("_jump", "")
	m.state.section = "sea"
	for mood: String in MusicScript.MOOD_SONG:
		var form: Array = forms.get(MusicScript.MOOD_SONG[mood], [])
		m.state.mood = mood
		m.set("_song", "")
		m.sounding = "title"
		var heard: Array = []
		for i in form.size() + 1:
			m.sounding = m._pick_sea()
			heard.append(m.sounding)
		var once := heard.slice(0, form.size()) == form
		var files := form.all(func(n: String) -> bool: return Cues.CUES.has(n))
		_check(once and files and heard[-1] == form[1], "%s: its song through, intro to outro, then round from its first verse (%s)"
				% [mood, ", ".join(heard)])
	m.state.mood = "calm"
	m.set("_song", "")
	m.sounding = "title"
	var fair: Array = forms.get("fair", [])
	m.sounding = m._pick_sea()
	m.sounding = m._pick_sea()
	m.state.mood = "rain"
	var turned: String = m._pick_sea()
	_check(turned == forms.get("rain", [""])[0],
			"the rain coming on mid-song: the rain's song from its top as this passage ends (%s)" % turned)
	var twice := ""
	for song: String in forms:
		var form: Array = forms[song]
		for k in range(1, form.size()):
			if form[k] == form[k - 1]:
				twice += " %s:%s" % [song, form[k]]
	_check(twice == "", "no part straight after itself (the bed would go quiet till the bar)%s" % twice)
	var mixed := ""
	for n: String in Cues.CUES:
		if bool(Cues.CUES[n].get("fight", false)) and str(Cues.CUES[n].get("song", "")) != "":
			mixed += " " + n
	_check(mixed == "", "the fight's own passages are none of the weather songs' parts%s" % mixed)
	m.state.mood = "calm"
	m.sounding = "sea_f1"
	var back: String = m._pick_sea()
	_check(back == fair[1], "back from a fight: fair's first verse (%s)" % back)
	m.set("_song", "")
	m.sounding = "sea_t1"
	var t2: String = m._pick_sea()
	_check(t2 == "sea_t2", "the theme's first half, then its second (%s)" % t2)


## Every cue's files are there, and a section's stems are all its bars long.
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
			if str(c["kind"]) == "bed":
				# (a loop exactly its bars; a passage its bars and then its tail)
				var want := int(c["bars"]) * int(c["bar_beats"]) * 60.0 / float(c["bpm"]) \
						+ (0.0 if bool(c["loop"]) else float(c.get("tail", 0.0)))
				if absf(s.get_length() - want) > 0.002:
					ok = false
					print("  %s: %.4f s, its bars (and tail) %.4f" % [f, s.get_length(), want])
	_check(ok, "every cue's there, every stem exactly its bars long (a passage's and then its tail)")


func _played(what: String) -> bool:
	for p: Array in m.played:
		if p[1] == what:
			return true
	return false


## `what` (the last of it played) landed on a grid line (beat/bar) of the clip that was sounding before it (from the
## clip log: when that one started). The quiet has no grid: anything goes.
func _on_grid(what: String, grid: String) -> bool:
	var at := -1.0
	var k := -1
	for i in m.played.size():
		if str(m.played[i][1]) == what:
			at = float(m.played[i][0])
			k = i
	var prev := ""
	var prev_at := -1.0
	for i in range(k - 1, -1, -1):
		var p: String = m.played[i][1]
		if p.begins_with("clip:") and float(m.played[i][0]) < at - 0.001:
			prev = p.substr(5)
			prev_at = float(m.played[i][0])
			break
	if k < 0 or prev == "":
		print("  (not found: %s, or what was before it)" % what)
		return false
	if prev == "rest":
		return true
	var c: Dictionary = Cues.CUES[prev]
	var unit := 60.0 / float(c["bpm"]) * (1 if grid == "beat" else int(c["bar_beats"]))
	var off := fposmod(at - prev_at, unit)
	var ok := off < 0.002 or unit - off < 0.002
	print("  %s at %.3f, on %s's %s from %.3f (%.4f s off)" % [what, at, prev, grid, prev_at, minf(off, unit - off)])
	return ok


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
