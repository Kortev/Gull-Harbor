extends RefCounted
## Every minigame of the arcade fight (docs/FIGHT_ARCADE.md). To add one: write tuna/minigames/<yours>.gd (extends
## minigame.gd) and add its line here. Nothing else knows the list: the fight (tuna/fight_arcade.gd) deals them out of
## a shuffled bag, the tests (tests/fight_arcade_test.gd) play every one of them.

const Minigame := preload("res://tuna/minigames/minigame.gd")

const LIST: Array = [
	preload("res://tuna/minigames/ride.gd"),        # the run: a needle held in his band
	preload("res://tuna/minigames/beats.gd"),       # head shakes: taps on a beat
	preload("res://tuna/minigames/jump.gd"),        # the jump: hands off, then a tap as he lands
	preload("res://tuna/minigames/pump.gd"),        # the pump: lift to the gold, wind down
	preload("res://tuna/minigames/dog.gd"),         # the pump with his kicks in it
	preload("res://tuna/minigames/charge.gd"),      # the charge: hammer the handle
	preload("res://tuna/minigames/laps.gd"),        # his laps: wind on the green, brace on the red
	preload("res://tuna/minigames/spool.gd"),       # thumbing the spool: stop it on the gold tooth
	preload("res://tuna/minigames/mimic.gd"),       # follow my leader: his darts, repeated
	preload("res://tuna/minigames/lanes.gd"),       # two lanes of notes on the music's beat
	preload("res://tuna/minigames/heave.gd"),       # the power heave: hold, let go in the gold
	preload("res://tuna/minigames/duel.gd"),        # the duel: wait... NOW
	preload("res://tuna/minigames/steady.gd"),      # the rod tip kept steady with knocks left and right
	preload("res://tuna/minigames/tug.gd"),         # the tug of war: hand over hand
	preload("res://tuna/minigames/twohands.gd"),    # (boss) two at once, one a hand
]

static var _about := {}
static var _scripts := {}


## One of each, to read what it is (id, moves, from, only, boss...): never begun, never stepped.
static func about() -> Dictionary:
	if _about.is_empty():
		for s: GDScript in LIST:
			var g := s.new() as Minigame
			_about[g.id] = g
			_scripts[g.id] = s
	return _about


static func ids() -> Array:
	return about().keys()


## A fresh one to play (null: no such game).
static func make(id: String) -> Minigame:
	if not about().has(id):
		return null
	return (_scripts[id] as GDScript).new() as Minigame
