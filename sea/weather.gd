extends RefCounted
## The weather. Nobody picks it: it comes and goes on its own, a spell of one kind, then it turns into the next.
## It wanders rather than jumps (a calm can go to rain and build to a storm, a storm blows through and clears), and
## it's worked out from the sea clock and a seed, so every peer with the host's seed sees the same sky with nothing
## sent while it changes.

const Schools := preload("res://tuna/schools.gd")

## From fair to foul: the order it wanders along, and where each starts on the 0..1 wander.
const KINDS: Array[String] = ["sunny", "calm", "fog", "rain", "heavy", "storm"]
const FROM: Array[float] = [0.0, 0.26, 0.42, 0.52, 0.66, 0.8]
## How long a spell lasts (s), and how long it takes to turn into the next one (its last part).
const SPELL := 300.0
const TURN := 90.0

var seed := 0
## Dev and screenshots (--weather=storm): this weather only.
var pinned := ""
## Which day it is (boat/fish_hold.gd's, every peer has it): each day's weather is its own stretch of the wander, so a
## new day is a new sky, and it still turns on its own through the day.
var day := 1


## The weather at sea-clock time t: [the spell now, the next one, how far it has turned 0..1].
func at(t: float) -> Array:
	if not pinned.is_empty():
		return [pinned, pinned, 0.0]
	var k := floori(t / SPELL)
	var into := t - k * SPELL
	var d := day * 23
	return [spell(k + d), spell(k + 1 + d), smoothstep(SPELL - TURN, SPELL, into)]


## The kind of spell number k: a slow wander over 0..1 (a fresh value every fifth spell, a straight line between:
## at most a fifth of the way from fair to foul in one spell).
func spell(k: int) -> String:
	var a := floori(k / 5.0)
	var n := lerpf(_h(a), _h(a + 1), (k - a * 5) / 5.0)
	var kind := KINDS[0]
	for i in KINDS.size():
		if n >= FROM[i]:
			kind = KINDS[i]
	return kind


func _h(i: int) -> float:
	return Schools.hash1(float(i % 100000), float(seed % 9973) + 0.5)
