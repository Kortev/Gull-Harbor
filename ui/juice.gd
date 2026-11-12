extends RefCounted
## The fight's juice (tuna/fight_arcade.gd's events, on the angler's own screen and nobody else's): the sounds, a
## beat of hit-stop, the rod's kick and the view's punch, the pad's rumble. ui/fight_arcade_hud.gd feeds it every
## event; the pictures (pops, sparks, the BIG PULL's moment) are the HUD's own.
##
## - **Sound**: every hit a short bright tick whose pitch climbs a ladder (a pentatonic scale: it always sounds
##   right), a rung for each hit in a row and starting higher the bigger the combo; a perfect rings on top of it. A miss
##   a soft dull one, and the ladder starts again. A grade, a stage, a boss and the BIG PULL each their own. All out of
##   the bank (audio/sfx.gd); nothing new.
## - **Hit-stop**: a perfect holds the minigame a few hundredths of a second (the fight's `freeze`; not in games
##   that keep time with the music: their `hitstop` is off).
## - **The kick**: the rod bucks and the view punches in through rods/fight_fx.gd's own jolt (the one his runs give),
##   small for a hit, the whole thing for a BIG PULL.

const Sfx := preload("res://audio/sfx.gd")
const Arcade := preload("res://tuna/fight_arcade.gd")

## The ladder: semitones up from the bottom rung.
const LADDER := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
const BASE_PITCH := 0.8

## rods/rods.gd (for the rod's kick; null: none).
var rods: Node
## Hits in a row (the rung), and what's been played this run, for the tests: [[event, pitch]].
var rung := 0
var played: Array = []


func pitch_of(n: int) -> float:
	return BASE_PITCH * pow(2.0, float(LADDER[clampi(n, 0, LADDER.size() - 1)]) / 12.0)


func _play(event: String, gain: float, pitch := 1.0) -> void:
	played.append([event, pitch])
	if played.size() > 64:
		played = played.slice(-32)
	Sfx.play(event, gain, pitch)


## One of the fight's events.
func on_event(e: Array, f: Arcade) -> void:
	var combo := f.combo if f != null else 0
	match str(e[0]):
		"hit":
			var perfect := int(e[1]) >= 2
			var n := mini(combo, 10) / 2 + rung
			_play("ui.tick", 0.6, pitch_of(n))
			if perfect:
				_play("ui.check", 0.45, pitch_of(n))
				if f != null and f.game != null and f.game.hitstop:
					f.freeze = 0.045
			rung = mini(rung + 1, 8)
			_kick(f, 0.24 if perfect else 0.1)
			Settings.buzz(0.0, 0.5 if perfect else 0.3, 0.06)
		"stroke":
			_play("ui.tick", 0.4, BASE_PITCH * (0.8 + 0.6 * float(e[1])))
		"miss":
			rung = 0
			_play("ui.cross", 0.4, 0.7)
			_kick(f, 0.14)
			Settings.buzz(0.6, 0.0, 0.12)
		"near":
			_play("ui.back", 0.2, 0.9)
		"game":
			rung = 0
			if bool(e[2]):
				_play("pa.chime", 0.6, 0.9)
				Settings.buzz(0.4, 0.4, 0.3)
		"grade":
			match str(e[1]):
				"perfect":
					_play("ui.confirm", 0.55, 1.0 + 0.025 * mini(int(e[2]), 20))
				"great":
					_play("ui.check", 0.45, 1.0 + 0.025 * mini(int(e[2]), 20))
				"miss":
					_play("kit.denied", 0.3, 0.8)
		"pull_ready":
			_play("ui.reveal", 0.7, 1.0)
			Settings.buzz(0.3, 0.3, 0.25)
		"pull":
			_play("ui.stamp", 0.9, 0.75)
			_play("kit.coins", 0.7, 1.0)
			_play("sea.wave", 0.6, 1.1)
			_play("ui.confirm", 0.7, 1.5)
			if f != null:
				f.freeze = 0.1
			_kick(f, 1.0)
			Settings.buzz(0.9, 1.0, 0.5)
		"stage":
			_play("ui.stamp", 0.6, 1.0)
			Settings.buzz(0.3, 0.6, 0.2)
		"boss":
			if bool(e[1]):
				_play("dock.ok", 0.6, 1.0)
				_kick(f, 0.6)


## The rod bucks, the view punches in: rods/fight_fx.gd's jolt on your rod, `k` of it (0..1).
func _kick(f: Arcade, k: float) -> void:
	if rods == null or f == null or not is_instance_valid(rods):
		return
	var fx: Node = rods.get("fx")
	if fx == null:
		return
	var jolts: Dictionary = fx.get("_jolts")
	for r: Node in rods.get("rods"):
		if r.get("fight") == f:
			var i: int = r.get("index")
			# (never cutting short a bigger one that's still going)
			if jolts.has(i) and float(jolts[i][1]) > k and float(jolts[i][0]) < 0.25:
				return
			jolts[i] = [0.0, clampf(k, 0.0, 1.0)]
			return
