extends Node
## The music (an autoload, `Music`), on the Music bus (core/settings.gd's slider). tools/music.py renders it into
## res://music/: a lo-fi folk band, plucked strings, a whistle, a concertina, pads, a frame drum. It watches the sea
## (sea/sea.gd, in the "sea" group) and picks what's wanted:
## - the title theme while the title's between you and the game (ui/title.gd's busy(): up, its intro, its glide);
## - calm at sea the rest of the time: a short low phrase now and then, long silences between (CALM_GAP), never the
##   same phrase twice running;
## - fish on (rods.gd's fighting()): a tense pulse layered in over it, the calm phrase pushed down under it;
## - the race home at dusk (sea.gd's home_by; Rivals', vs/vs.gd's): a driving jig, its rhythm first, its tune coming
##   in and then its urgency as the clock runs down (race_mix());
## - Rivals: the countdown's sting, started where the countdown's got to so its hit lands on GO, the bed quiet under
##   it; the results card's (vs/card.gd: win, lose or tie, for your boat) as its stamp lands, and nothing else while
##   the card's up.
## Every layer moves to where it's wanted over FADES s (nothing starts, stops or switches at full loudness), and all of
## it ducks a little (DUCK) while anything's coming over the radio or the voice bus.

const DIR := "res://music/"
const BUS := &"Music"
const CALM := ["calm_1", "calm_2", "calm_3", "calm_4"]
## Silence after a calm phrase before the next (s, a random length between).
const CALM_GAP := Vector2(30.0, 75.0)
## Into calm from something else: the first phrase after this long (s, between).
const CALM_FIRST := Vector2(8.0, 16.0)
## Under a fight, the calm phrase at this share.
const UNDER_FISH := 0.3
## Each layer's fades (s, in and out) and its level (a share).
const FADES := {"title": Vector2(2.0, 3.5), "calm": Vector2(2.5, 3.0), "fish": Vector2(1.5, 4.0),
		"race": Vector2(3.0, 4.0), "sting": Vector2(0.05, 1.5)}
const LEVEL := {"title": 1.0, "calm": 0.85, "fish": 0.8, "race": 1.0, "sting": 1.0}
## While the radio or a voice is on: everything down to this share; how long it holds after they stop (s); the
## level (dB) on their bus that counts as on.
const DUCK := 0.55
const DUCK_HOLD := 0.6
const DUCK_AT := -42.0
const DUCK_BUSES := [&"Radio", &"Voice"]
## Rivals' countdown (vs/vs.gd's COUNT, s): the sting's hit is this far in.
const COUNT := 10.0
## The race home's length (s: sea.gd's and vs.gd's HOME): how far through it the jig's built.
const HOME := 360.0

## What's wanted now: the bed ("title", "calm", "race" or "": quiet), and the fight layered over it.
var cue := ""
var fish := false
## The last calm phrase started ("" none yet).
var phrase := ""
## The sting playing ("countdown", "win", "lose", "tie"; "" none).
var sting := ""
## Tests: >0 holds the duck on this many s more, as if the radio were on.
var duck_test := 0.0
var _layers := {}           # name -> {player, gain, target}
var _phrases := {}          # calm name -> AudioStream
var _stings := {}
var _race: AudioStreamSynchronized
var _race_gain := [1.0, 0.0, 0.0]
var _calm_wait := 0.0
var _calm_last := ""
var _duck := 1.0
var _duck_for := 0.0
var _sea: Node
var _counting := false
var _stamped := false
var _rng := RandomNumberGenerator.new()
var _dummy := false         # (no sound card, headless: a bus nothing's mixed through reads 0 dB)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_dummy = AudioServer.get_driver_name() == "Dummy"
	for n: String in CALM:
		_phrases[n] = _load(n, false)
	for n: String in ["countdown", "win", "lose", "tie"]:
		_stings[n] = _load(n, false)
	_race = AudioStreamSynchronized.new()
	_race.stream_count = 3
	for i in 3:
		_race.set_sync_stream(i, _load(["race_a", "race_b", "race_c"][i], true))
	_layer("title", _load("title", true))
	_layer("calm", null)
	_layer("fish", _load("fish_on", true))
	_layer("race", _race)
	_layer("sting", null)


func _load(n: String, loop: bool) -> AudioStream:
	var s := load(DIR + n + ".ogg") as AudioStreamOggVorbis
	if s != null:
		s.loop = loop
	return s


func _layer(n: String, stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.name = n.capitalize()
	p.bus = BUS
	p.stream = stream
	p.volume_db = -80.0
	add_child(p)
	_layers[n] = {"player": p, "gain": 0.0, "target": 0.0}


## A layer's loudness now (0..1, before the duck).
func level(n: String) -> float:
	return float(_layers[n]["gain"]) if _layers.has(n) else 0.0


## The race home's stems now: [rhythm, tune, urgency], each 0..1.
func race_mix() -> Array:
	return _race_gain.duplicate()


## The duck now (1: none, DUCK: under the radio).
func duck() -> float:
	return _duck


func _process(delta: float) -> void:
	var sea := _find_sea()
	var was := cue
	var left := -1.0
	cue = ""
	fish = false
	var title: Node = sea.get("title") if sea != null else null
	var vs: Node = sea.get("vs") if sea != null else null
	var rivals := vs != null and bool(vs.get("on"))
	var now := _now(sea)
	if sea == null:
		pass
	elif title != null and is_instance_valid(title) and bool(title.call("busy")):
		cue = "title"
	elif rivals and (vs.get("card") as Node).call("up"):
		cue = ""
	elif rivals and float(vs.get("count_end")) >= 0.0:
		cue = ""
	elif rivals and float(vs.get("home_by")) > 0.0 and not bool(vs.call("came_home", int(vs.get("my_team")))):
		cue = "race"
		left = float(vs.get("home_by")) - now
	elif not rivals and float(sea.get("home_by")) > 0.0 and not bool((sea.get("fish_hold") as Node).get("docked")):
		cue = "race"
		left = float(sea.get("home_by")) - now
	else:
		cue = "calm" if sting == "" or not _playing("sting") else ""
		var rods: Node = sea.get("rods")
		fish = rods != null and bool(rods.call("fighting"))
	_stings_for(vs if rivals else null, now)
	# the beds
	_aim("title", 1.0 if cue == "title" else 0.0)
	_aim("race", 1.0 if cue == "race" else 0.0)
	_aim("fish", 1.0 if fish else 0.0)
	_aim("sting", 0.0 if cue == "title" or sting == "" else 1.0)
	_calm(delta, was)
	if cue == "race":
		var p := clampf(1.0 - left / HOME, 0.0, 1.0)
		_stem(1, 0.3 + 0.7 * smoothstep(0.05, 0.4, p), delta)
		_stem(2, smoothstep(0.5, 0.88, p), delta)
	elif level("race") <= 0.0:
		_race_gain = [1.0, 0.0, 0.0]
	for i in 3:
		_race.set_sync_stream_volume(i, linear_to_db(maxf(_race_gain[i], 0.0001)))
	_ducking(delta)
	for n: String in _layers:
		_fade(n, delta)


func _find_sea() -> Node:
	if _sea == null or not is_instance_valid(_sea) or not _sea.is_inside_tree():
		_sea = get_tree().get_first_node_in_group("sea")
	return _sea


func _now(sea: Node) -> float:
	var ocean: Node = sea.get("ocean") if sea != null else null
	return float(ocean.get("wave_time")) if ocean != null else 0.0


func _aim(n: String, target: float) -> void:
	_layers[n]["target"] = target


func _playing(n: String) -> bool:
	return (_layers[n]["player"] as AudioStreamPlayer).playing


## Calm at sea: a phrase now and then, a long silence between; down under a fight; gone for anything else.
func _calm(delta: float, was: String) -> void:
	if cue != "calm":
		_aim("calm", 0.0)
		return
	if was != "calm":
		_calm_wait = maxf(_calm_wait, _rng.randf_range(CALM_FIRST.x, CALM_FIRST.y))
	_aim("calm", UNDER_FISH if fish else 1.0)
	_calm_wait -= delta
	if _calm_wait > 0.0 or fish:
		return
	var pick: Array = CALM.filter(func(n: String) -> bool: return n != _calm_last)
	var n: String = pick[_rng.randi() % pick.size()]
	_calm_last = n
	phrase = n
	var p := _layers["calm"]["player"] as AudioStreamPlayer
	p.stream = _phrases[n]
	if p.stream != null:
		p.play()
	var length := p.stream.get_length() if p.stream != null else 20.0
	_calm_wait = length + _rng.randf_range(CALM_GAP.x, CALM_GAP.y)


## Rivals' stings: the countdown as it starts (from where it's got to), the card's as its stamp lands.
func _stings_for(vs: Node, now: float) -> void:
	var counting := vs != null and float(vs.get("count_end")) >= 0.0
	if counting and not _counting:
		var into := COUNT - (float(vs.get("count_end")) - now)
		if into < COUNT - 0.5:
			_play_sting("countdown", maxf(into, 0.0))
	_counting = counting
	var card: Node = vs.get("card") if vs != null else null
	var stamped := card != null and bool(card.call("up")) and bool(card.call("stamped"))
	if stamped and not _stamped:
		var d: Dictionary = card.get("data")
		var winner := int(d.get("winner", -1))
		_play_sting("tie" if winner < 0 else ("win" if winner == int(card.get("mine")) else "lose"), 0.0)
	_stamped = stamped
	if sting != "" and not _playing("sting") and level("sting") > 0.0:
		sting = ""


func _play_sting(n: String, from: float) -> void:
	sting = n
	var l: Dictionary = _layers["sting"]
	var p := l["player"] as AudioStreamPlayer
	p.stream = _stings.get(n)
	l["gain"] = 1.0             # (a sting starts on its own soft note or its count-in: it's the music, not a cut)
	l["target"] = 1.0
	p.volume_db = linear_to_db(LEVEL["sting"] * _duck)
	if p.stream != null:
		p.play(from)


func _stem(i: int, want: float, delta: float) -> void:
	_race_gain[i] = move_toward(_race_gain[i], want, delta * 0.25)


## Down a little while the radio or a voice is on, back up slowly once they stop.
func _ducking(delta: float) -> void:
	var on := duck_test > 0.0
	duck_test = maxf(duck_test - delta, 0.0)
	for b: StringName in DUCK_BUSES if not _dummy else []:
		var i := AudioServer.get_bus_index(b)
		if i >= 0 and maxf(AudioServer.get_bus_peak_volume_left_db(i, 0),
				AudioServer.get_bus_peak_volume_right_db(i, 0)) > DUCK_AT:
			on = true
	_duck_for = DUCK_HOLD if on else maxf(_duck_for - delta, 0.0)
	var want := DUCK if _duck_for > 0.0 else 1.0
	_duck = move_toward(_duck, want, delta * (1.6 if want < _duck else 0.4))


func _fade(n: String, delta: float) -> void:
	var l: Dictionary = _layers[n]
	var g := float(l["gain"])
	var target := float(l["target"])
	var f: Vector2 = FADES[n]
	g = move_toward(g, target, delta / (f.x if target > g else f.y))
	l["gain"] = g
	var p := l["player"] as AudioStreamPlayer
	if g <= 0.0 and target <= 0.0:
		if p.playing:
			p.stop()
		return
	if not p.playing and p.stream != null and n != "calm" and n != "sting":
		p.play()
	p.volume_db = linear_to_db(maxf(g * float(LEVEL[n]) * _duck, 0.0001))
