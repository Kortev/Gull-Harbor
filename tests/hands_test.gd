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
	var hold := sea.fish_hold
	var spec: Dictionary = sea.boat.spec
	hold.host_add(150.0, 60.0)
	await _frames(2)
	var f: Dictionary = hold.fish[hold.fish.size() - 1]
	var id := int(f["id"])
	var fish: Node3D = hold._deck[id]
	var handle: Node = fish.get_node("Handle")
	_check(str(handle.call("interact_prompt")).is_empty(), "a fish on deck: no words, it's lying there")
	# the knife
	me.hands.pick("knife")
	_check(handle.call("use_item", me, "gaff", true) and hold._dragging == id, "(the gaff hooks it)")
	handle.call("use_item", me, "gaff", false)
	_check(float(f["bled_s"]) < 0.0, "the gaff doesn't bleed it")
	_check(handle.call("use_item", me, "knife", true) and float(hold.fish[0]["bled_s"]) >= 0.0, "the knife bleeds it")
	# the lid
	var lid: Node = hold._lid.get_node("Lid")
	lid.call("interact", me)
	_check(hold.box_open, "E on the lid: the fish box open")
	await _wait(0.6)
	_check(hold._lid.rotation.x < -1.5 and hold._inside.visible, "the lid's up, the ice inside")
	# drag it to the box with the gaff: you, the box straight ahead past the fish
	var box: Vector3 = spec["box"]
	var reach: float = 0.5 + float(fish.get("length")) * 0.5
	me.place(Vector3(box.x, box.y + 0.05, box.z + reach + 1.5), 0.0)
	me.hands.pick("gaff")
	await _frames(2)
	handle = hold._deck[id].get_node("Handle")
	_check(handle.call("use_item", me, "gaff", true), "the gaff in it")
	await _frames(20)
	_check(float(me.get("burden")) < 1.0, "a 150 kg fish slows you down (%.2f)" % float(me.get("burden")))
	var off: Vector3 = sea.boat.global_transform.affine_inverse() * hold._deck[id].global_position
	_check(not hold.over_box(off), "not over the box yet")
	me.place(Vector3(box.x, box.y + 0.05, box.z + reach), 0.0)
	await _frames(30)
	handle.call("use_item", me, "gaff", false)
	await _frames(2)
	_check(float(me.get("burden")) == 1.0, "let go: free again")
	_check(float(hold.fish[0]["iced_s"]) >= 0.0 and not hold._deck.has(id), "dropped over the open box: in on the ice")
	await _frames(2)
	_check((hold._inside.get_node("Tail0") as Node3D).visible, "its tail up out of the ice")
	# shut, the next one lies on the lid
	lid.call("interact", me)
	hold.host_add(80.0, 30.0)
	await _frames(2)
	var g: Dictionary = hold.fish[hold.fish.size() - 1]
	var id2 := int(g["id"])
	me.place(Vector3(box.x, box.y + 0.05, box.z + reach), 0.0)
	await _frames(2)
	hold._deck[id2].get_node("Handle").call("use_item", me, "gaff", true)
	await _frames(30)
	hold._deck[id2].get_node("Handle").call("use_item", me, "gaff", false)
	await _frames(2)
	_check(float(g["iced_s"]) < 0.0 and g.has("at") and hold._deck.has(id2), "the lid shut: it lies where you left it")
	me.hands.pick("")


func _chum() -> void:
	var hold := sea.fish_hold
	var chum: Node = sea.chum
	var bucket: Node = chum.get("_bucket").get_node("Scoop")
	var left := hold.chum
	me.place(Vector3(0.0, float(sea.boat.spec["deck"]) + 0.05, 1.5), PI * 0.5)       # (facing out to port)
	me.set("_pitch", 0.0)
	me.hands.pick("scoop")
	await _frames(2)
	_check(str(bucket.call("interact_prompt")).is_empty(), "the bucket: no words")
	_check(bucket.call("use_item", me, "knife", true) == false, "the knife does nothing in the bucket")
	_check(bucket.call("use_item", me, "scoop", true) and me.hands.scoop_full, "the scoop in the bucket: it comes up full")
	_check(hold.chum == left, "nothing gone till it's thrown")
	_check(bucket.call("use_item", me, "scoop", true) == false, "a full scoop on the bucket winds up a throw instead")
	me.hands.press(true)
	await _wait(0.5)
	_check(me.hands.wind > 0.4, "holding: winding up (%.2f)" % me.hands.wind)
	me.hands.press(false)
	_check(not me.hands.scoop_full and hold.chum == left - 1, "let go: thrown, a scoop out of the bucket")
	for i in 600:
		if (chum.get("_flying") as Array).is_empty():
			break
		await get_tree().process_frame
	var slick: Vector2 = sea.schools.slick
	var l: Vector3 = sea.boat.global_transform.affine_inverse() * Vector3(slick.x, 0.0, slick.y)
	_check(l.x < -float(sea.boat.spec["beam"]) * 0.5, "the slick's where it went: out to port, over the side (%.1f m)" % l.x)
	var shown := false
	for p: MeshInstance3D in chum.get("_patches"):
		shown = shown or (p.visible and Vector2(p.global_position.x, p.global_position.z).distance_to(slick) < 0.5)
	_check(shown, "and it's there on the water")
	me.hands.pick("")
