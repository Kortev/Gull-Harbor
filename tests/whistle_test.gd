extends Node
## The tin whistle (crew/hands.gd, slot 6), played on deck at sea: it sounds while you blow, every note is one of the
## chord the band's playing (audio/music.gd), each starting on the music's eighth; look higher for a higher note; let
## go and it stops. And the hotbar's sixth key picks it.
## Run: godot --headless --fixed-fps 30 --path . res://tests/whistle_test.tscn

const Sea := preload("res://sea/sea.gd")
const DT := 1.0 / 30.0

var fails: Array[String] = []
var sea: Sea
var me: Node3D
var m: Node


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	m = get_node("/root/Music")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _frames(10)
	sea.schools.set("_next", 9999.0)
	sea.set_condition("calm")
	sea.fish_hold.head_out("skiff")
	await _frames(90)
	me = sea.crew.me
	me.force_input = true
	_check(InputMap.has_action("slot_6"), "a sixth key on the hotbar")
	var ev := InputEventAction.new()
	ev.action = "slot_6"
	ev.pressed = true
	me.hands._unhandled_input(ev)
	_check(me.hands.item == "whistle", "6: the tin whistle in your hands (%s)" % me.hands.item)
	_check(str(m.sounding).begins_with("sea_") and m.chord_now() != "", "at sea, the band on a chord (%s, %s)"
			% [m.sounding, m.chord_now()])
	# low, then high
	me.set("_pitch", -0.45)
	await _frames(3)
	me.hands.press(true)
	var started := -1.0
	for i in 40:
		await get_tree().process_frame
		if me.hands.note > 0:
			started = float(m.now())
			break
	var low: int = me.hands.note
	var tones: Array = m.CHORD_TONES.get(m.chord_now(), m.PENTATONIC)
	_check(low > 0 and posmod(low, 12) in tones, "blowing it: a note, one of the band's chord (%d on %s)"
			% [low, m.chord_now()])
	var c: Dictionary = m.Cues.CUES[m.sounding]
	var eighth := 30.0 / float(c["bpm"])
	var off := fposmod(started - float(m.get("_start")), eighth)
	_check(off < DT + 0.01 or eighth - off < 0.01, "it came in on the music's eighth (%.3f s past it)" % off)
	_check(me.hands.get("_pipe") != null and (me.hands.get("_pipe") as AudioStreamPlayer3D).playing,
			"and it sounds")
	me.set("_pitch", 0.75)
	await _frames(30)
	var high: int = me.hands.note
	_check(high > low, "looking up: higher (%d after %d)" % [high, low])
	var heard := true
	var chord: String = m.chord_now()
	var since := 99
	var changes := 0
	for i in 180:
		await get_tree().process_frame
		if m.chord_now() != chord:
			chord = m.chord_now()
			since = 0
			changes += 1
		since += 1
		var t: Array = m.CHORD_TONES.get(chord, m.PENTATONIC)
		if since * DT > eighth + 0.08:
			heard = heard and posmod(me.hands.note, 12) in t
	heard = heard and changes > 0
	_check(heard, "held through the chords changing, it follows them (on the next eighth)")
	me.hands.press(false)
	await _frames(2)
	_check(me.hands.note == 0 and not me.hands.blowing, "let go: it stops")
	for f in fails:
		print("FAIL ", f)
	print("WHISTLE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)
