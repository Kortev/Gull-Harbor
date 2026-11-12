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
## The host's call (the dev panel, ui/dev_panel.gd; sea/sea.gd's host_call_weather tells everyone): `called` coming in
## from `called_from` since `called_t` (the sea clock), over CALL_TURN s: it turns, it doesn't jump. Let go ("": on its
## own again), it turns back from `released_from` since `released_t` the same way.
const CALL_TURN := 25.0
var called := ""
var called_from := ""
var called_t := -1e9
var released_from := ""
var released_t := -1e9
## Which day it is (boat/fish_hold.gd's, every peer has it): each day's weather is its own stretch of the wander, so a
## new day is a new sky, and it still turns on its own through the day.
var day := 1


## The weather at sea-clock time t: [the spell now, the next one, how far it has turned 0..1].
func at(t: float) -> Array:
	if not pinned.is_empty():
		return [pinned, pinned, 0.0]
	if not called.is_empty():
		return [called_from, called, smoothstep(called_t, called_t + CALL_TURN, t)]
	var k := floori(t / SPELL)
	var into := t - k * SPELL
	var d := day * 23
	var own := [spell(k + d), spell(k + 1 + d), smoothstep(SPELL - TURN, SPELL, into)]
	if not released_from.is_empty() and t < released_t + CALL_TURN:
		return [released_from, own[1] if float(own[2]) > 0.5 else own[0],
				smoothstep(released_t, released_t + CALL_TURN, t)]
	return own


## The kind there's most of at t.
func kind_at(t: float) -> String:
	var a := at(t)
	return str(a[1]) if float(a[2]) > 0.5 else str(a[0])


## The host's call at t: `kind` coming in from what it is now ("": back to its own, the same way).
func call_weather(kind: String, t: float) -> void:
	var from := kind_at(t)
	if kind.is_empty():
		if called.is_empty():
			return
		called = ""
		released_from = from
		released_t = t
	else:
		called_from = from
		called = kind
		called_t = t
		released_from = ""


func call_state() -> Array:
	return [called, called_from, called_t, released_from, released_t]


func set_call_state(a: Array) -> void:
	called = str(a[0])
	called_from = str(a[1])
	called_t = float(a[2])
	released_from = str(a[3])
	released_t = float(a[4])


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
