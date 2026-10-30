extends Node
## The kit in your hands (crew/hands.gd): picking things on the hotbar; the jig rod's little game (boat/jig.gd);
## the knife, the gaff and the fish box (boat/fish_hold.gd); the scoop and a throw of chum (boat/chum.gd).
## Run: godot --headless --fixed-fps 30 --path . res://tests/hands_test.tscn

const Sea := preload("res://sea/sea.gd")
const Jig := preload("res://boat/jig.gd")
const FishHold := preload("res://boat/fish_hold.gd")

var fails: Array[String] = []
var sea: Sea
var me: Node3D


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _wait(0.3)
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.gear = ["bait"]
	hold.head_out("skiff")
	await _wait(0.3)
	me = sea.crew.me
	me.force_input = true
	# the hotbar
	me.hands.pick("knife")
	_check(me.hands.item == "knife", "1: the knife in your hands")
	me.hands.pick("knife")
	_check(me.hands.item == "", "the same again: empty-handed")
	sea.rods.request_grab(0)
	await _frames(2)
	_check(me.hands.stowed(), "a rod in your hands: the kit's put away")
	sea.rods.request_return(0)
	await _frames(2)
	await _jig()
	await _catch()
	await _chum()
	for f in fails:
		print("FAIL ", f)
	print("HANDS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## At the starboard rail facing out over the water (or in the middle of her deck), `item` in your hands.
func _stand(item: String, at_rail := true) -> void:
	var beam := float(sea.boat.spec["beam"])
	me.place(Vector3(beam * 0.5 - 0.55 if at_rail else 0.0, float(sea.boat.spec["deck"]) + 0.05, 1.0), -PI * 0.5)
	me.set("_pitch", -0.2)
	if me.hands.item != item:
		me.hands.pick(item)
	await _frames(4)


func _jig() -> void:
	var jig: Jig = sea.jig
	var hold := sea.fish_hold
	await _stand("jig", false)
	me.hands.press(true)
	me.hands.press(false)
	_check(jig.state == "up", "the jig won't go over her deck: get to the rail")
	await _stand("jig")
	me.hands.press(true)
	me.hands.press(false)
	_check(jig.state == "down", "at the rail, left mouse lets the jig go")
	await _wait(1.5)
	_check(jig.depth > Jig.KNOCK_DEEP, "it sinks (%.1f m)" % jig.depth)
	# a knock, too slow to strike
	jig.set("_knock_in", 0.01)
	await _frames(3)
	_check(jig.state == "knock" and jig.lift < -0.5 and float(me.get("shake")) > 0.3,
			"a knock: the tip jerks down and you feel it")
	await _wait(Jig.STRIKE + 0.2)
	_check(jig.state == "down", "too slow: it's gone")
	# a knock, struck
	jig.set("_knock_in", 0.01)
	await _frames(3)
	me.hands.press(true)
	me.hands.press(false)
	_check(jig.state == "on", "a tap on the knock sets the hook")
	# wind it up: hold left mouse
	var well := hold.well
	Input.action_press("use_primary")
	me.hands.press(true)
	await _wait(Jig.DEEP / Jig.WIND + 0.8)
	Input.action_release("use_primary")
	me.hands.press(false)
	await _frames(2)
	_check(jig.state == "up" and jig.depth == 0.0, "held: wound all the way up")
	_check(hold.well == well + 1, "a mackerel swung aboard, into the well (%d)" % hold.well)
	me.hands.pick("")


func _catch() -> void:
	pass


func _chum() -> void:
	pass
