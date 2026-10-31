extends Node
## The music (audio/music.gd) follows the game, and every change is a fade: the title theme while the title's up;
## SOLO, and once the glide's done it gives way to calm at sea (a phrase soon after, then silence); a fish on, the
## pulse comes in over it and the calm goes down under it; dusk and the race home, the jig comes in and the fight's
## pulse goes, and as the time runs out its tune and its urgency come up; the radio ducks it. Rivals: the countdown's
## sting (nothing else under it), and the results card's as its stamp lands (your boat won: win).
## Run: godot --headless --fixed-fps 30 --path . res://tests/music_test.tscn

const Sea := preload("res://sea/sea.gd")
const Title := preload("res://ui/title.gd")
const Card := preload("res://vs/card.gd")
const DT := 1.0 / 30.0

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	var m: Node = get_node("/root/Music")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	sea.schools.set("_next", 9999.0)
	var t := Title.new()
	t.name = "Title"
	t.sea = sea
	sea.title = t
	sea.add_child(t)
	await _frames(3)
	_check(m.cue == "title", "the title's up: the title theme (%s)" % m.cue)
	_check(m.level("title") > 0.0 and m.level("title") < 0.2, "fading in, not all at once (%.2f)" % m.level("title"))
	await _secs(2.5)
	_check(is_equal_approx(m.level("title"), 1.0), "and up (%.2f)" % m.level("title"))
	# SOLO: the title theme through the intro and the glide, then calm at sea
	t.call("_solo")
	await _frames(2)
	_check(m.cue == "title", "the intro and the glide: still the title")
	var waited := 0.0
	while t.busy() and waited < 20.0:
		await get_tree().process_frame
		waited += DT
	await _frames(2)
	_check(m.cue == "calm", "the title down: calm at sea (%s)" % m.cue)
	_check(m.level("title") > 0.8, "the title theme still going out (%.2f)" % m.level("title"))
	var drops: Array = await _track("title", 4.0)
	_check(drops[0] <= 0.0 and drops[1] < 0.02 and m.level("title") == 0.0,
			"faded out smoothly (biggest step %.3f a frame), gone" % drops[1])
	waited = 0.0
	while m.phrase == "" and waited < 20.0:
		await get_tree().process_frame
		waited += DT
	_check(m.phrase != "", "a calm phrase soon after (%s, %.0f s in)" % [m.phrase, waited])
	_check(float(m.get("_calm_wait")) > 40.0, "and a long silence to follow it (%.0f s)" % float(m.get("_calm_wait")))
	await _secs(2.6)
	_check(is_equal_approx(m.level("calm"), 1.0), "the calm layer up (%.2f)" % m.level("calm"))
	# a fish on
	sea.rods.host_cast(0)
	sea.rods.strike(0, 150.0)
	await _frames(3)
	_check(m.fish and m.cue == "calm", "fish on: the pulse layered over calm")
	await _secs(0.8)
	var f: float = m.level("fish")
	_check(f > 0.3 and f < 0.8, "coming in over a moment (%.2f)" % f)
	_check(m.level("calm") < 0.95 and m.level("calm") > 0.3, "the calm going down under it (%.2f)" % m.level("calm"))
	# dusk: the race home (time's up in Sea.HOME s)
	sea.fish_hold.head_out()
	sea.call("_set_home", float(sea.ocean.wave_time) + Sea.HOME)
	await _frames(2)
	_check(m.cue == "race" and not m.fish, "dusk, still out: the race home (%s)" % m.cue)
	var fish_was: float = m.level("fish")
	await _secs(1.0)
	_check(m.level("fish") > 0.0 and m.level("fish") < fish_was, "the pulse going out under it, not cut (%.2f)"
			% m.level("fish"))
	_check(m.level("race") > 0.2 and m.level("race") < 0.5, "the jig coming in (%.2f)" % m.level("race"))
	await _secs(3.0)
	var mix: Array = m.race_mix()
	_check(is_equal_approx(m.level("race"), 1.0) and m.level("fish") == 0.0 and m.level("calm") == 0.0,
			"the race home's all there is")
	_check(float(mix[0]) == 1.0 and float(mix[1]) < 0.5 and float(mix[2]) == 0.0,
			"the time just started: the rhythm, the tune low, no urgency (%s)" % [mix])
	# the time running out
	sea.home_by = float(sea.ocean.wave_time) + 30.0
	await _secs(1.0)
	mix = m.race_mix()
	_check(float(mix[2]) > 0.1 and float(mix[2]) < 0.6, "30 s left: the urgency building (%.2f)" % float(mix[2]))
	await _secs(4.0)
	mix = m.race_mix()
	_check(float(mix[1]) > 0.95 and float(mix[2]) > 0.95, "built all the way (%s)" % [mix])
	# the radio ducks it
	m.duck_test = 1.0
	await _secs(0.5)
	_check(m.duck() < 0.65, "the radio on: the music ducks (%.2f)" % m.duck())
	await _secs(3.0)
	_check(m.duck() > 0.9, "and comes back up once it's off (%.2f)" % m.duck())
	# home: tied up, the race is over, calm again
	sea.fish_hold.set("docked", true)
	await _frames(2)
	_check(m.cue == "calm", "home: calm again (%s)" % m.cue)
	await _secs(1.0)
	_check(m.level("race") > 0.5 and m.level("race") < 1.0, "the jig fading out (%.2f)" % m.level("race"))
	# Rivals: the countdown's sting, then the card's
	sea.home_by = -1.0
	sea.vs.host_set_on(true)
	await _frames(5)
	_check(float(sea.vs.count_end) > 0.0 and m.sting == "countdown" and m.cue == "",
			"Rivals: the countdown, its sting, quiet under it (%s, %s)" % [m.sting, m.cue])
	sea.vs.card.open({"decided": false, "winner": 0, "day": 1, "wins": [1, 0], "crewed": [true, true],
			"day_lb": [220.0, 110.0], "boats": [{"fish": 2, "kg": 100.0, "big": 60.0, "money": 900, "late": 0, "lb": 220.0},
			{"fish": 2, "kg": 100.0, "big": 60.0, "money": 450, "late": 1, "lb": 110.0}]}, 0)
	await _secs(Card.T_STAMP + Card.STAMP + 0.2)
	_check(m.sting == "win" and m.cue == "", "the card's stamp lands, your boat's: the win sting (%s)" % m.sting)
	sea.vs.card.close()
	_done()


## How a layer moves over `secs` s: [its biggest rise a frame, its biggest drop a frame].
func _track(n: String, secs: float) -> Array:
	var m: Node = get_node("/root/Music")
	var last: float = m.level(n)
	var up := 0.0
	var down := 0.0
	for i in int(secs / DT):
		await get_tree().process_frame
		var g: float = m.level(n)
		up = maxf(up, g - last)
		down = maxf(down, last - g)
		last = g
	return [up, down]


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
