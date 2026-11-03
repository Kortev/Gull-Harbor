extends Node
## The tuna tower (the sportfisher's, boat/tower.gd): from the cockpit you can put the crosshair on its ladder; E on
## it and you climb, the whole way, a step at a time (nothing jumps: never more than a little each frame), to the
## platform five metres up, where W doesn't walk you off; from up there you can tell what a flock's on much further off
## than from the deck (crew/spotter.gd's read_range: about 1.8 km), and birds working over bluefin are called down to
## the crew by the clock ("BIRDS WORKING, TWO O'CLOCK!"); E climbs you back down the same way, to the foot of the ladder,
## and you're walking again. Not with a rod in your hands. The skiff has no tower.
## Run: godot --headless --fixed-fps 30 --path . res://tests/tower_test.tscn

const Sea := preload("res://sea/sea.gd")
const Spotter := preload("res://crew/spotter.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	sea.fish_hold.owned = ["skiff", "sportfisher"]
	sea.fish_hold.head_out("sportfisher")
	await get_tree().create_timer(0.3).timeout
	var me := sea.crew.me
	me.force_input = true
	var tower: Node = sea.boat.get("tower")
	_check(tower != null, "the sportfisher has a tower")
	if tower == null:
		_done()
		return
	var cam := me.get("cam") as Camera3D
	var deck_read := Spotter.read_range(cam)
	_check(await _can_look_at(me, Vector3(-1.2, 0.6, 3.4), tower, 0.0), "from the cockpit you can put the crosshair on the ladder")
	_check(str(tower.call("interact_prompt")) == "Climb the tower", "it says: %s" % tower.call("interact_prompt"))
	# not with a rod in your hands
	sea.rods.request_grab(0)
	tower.call("interact", me)
	_check(not bool(me.get("aloft")), "not with a rod in your hands")
	sea.rods.request_return(0)
	await get_tree().process_frame
	tower.call("interact", me)
	var worst := await _watch(me, 8.0, func() -> bool: return me.local_position().y > 5.3)
	_check(bool(me.get("aloft")) and me.local_position().y > 5.3, "E: up the tower (%.1f m up)" % me.local_position().y)
	_check(worst < 0.25, "climbed all the way, never more than %.2f m in a frame" % worst)
	await get_tree().create_timer(0.8).timeout
	var at: Vector3 = me.local_position()
	Input.action_press("move_forward")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_forward")
	_check(me.local_position().distance_to(at) < 0.05, "W doesn't walk you off it")
	var top_read := Spotter.read_range(cam)
	# (your eye rides up and down with the swell: these move a little with it)
	_check(deck_read > 500.0 and deck_read < 950.0 and top_read > 1650.0 and top_read < 2000.0,
			"you can tell what a flock's on %.0f m off from the deck, %.0f m from up here" % [deck_read, top_read])
	# a feeding school between the two, under your crosshair: what's under the birds only from up here
	var c := cam.global_position
	var fwd := -cam.global_basis.z
	var flat := Vector2(fwd.x, fwd.z).normalized()
	var dist := (deck_read + top_read) * 0.5
	sea.schools._start(1, 7, sea.schools.now(), Vector2(c.x, c.z) + flat * dist, Vector2(1, 0), 0.0, 200.0)
	var s: Node = sea.schools.schools.back()
	# (in a feeding spell: birds working)
	var t0: float = sea.schools.now()
	var k := 0
	while sea.schools.call("hash1", float(int(s.get("seed")) % 1000), float(k)) <= 0.38:
		k += 1
	s.set("born", t0 - k * 40.0 - 1.0)
	var up_text := await _spotted(sea, me, s)
	_check(up_text != "" and not up_text.begins_with("Birds"), "from the tower, %.0f m off: %s" % [dist, up_text])
	# the spotter's call: birds working over bluefin, shouted down to the crew by the clock off her bow
	_check(bool(s.call("feeding", sea.schools.now())) and not bool(s.get("bait_only")), "(birds working over bluefin)")
	if true:
		sea.spotter.call("_spotting", cam, s)
		var said := str(sea.spotter.get("last_call"))
		var clock := str(sea.spotter.call("clock_of", s.call("center", sea.schools.now())))
		_check(said == "BIRDS WORKING, %s O'CLOCK!" % clock and str(sea.rods.calls.line()) == said,
				"up the tower, the call: %s" % said)
		var n := int(sea.rods.calls.count)
		sea.spotter.call("_spotting", cam, s)
		_check(int(sea.rods.calls.count) == n, "once for a flock, not over and over")
	var ahead := sea.boat.global_transform * Vector3(0.0, 0.0, -1000.0)
	var abeam := sea.boat.global_transform * Vector3(1000.0, 0.0, 0.0)
	var astern := sea.boat.global_transform * Vector3(0.0, 0.0, 1000.0)
	_check(str(sea.spotter.call("clock_of", Vector2(ahead.x, ahead.z))) == "TWELVE"
			and str(sea.spotter.call("clock_of", Vector2(abeam.x, abeam.z))) == "THREE"
			and str(sea.spotter.call("clock_of", Vector2(astern.x, astern.z))) == "SIX",
			"the clock: twelve dead ahead, three to starboard, six astern")
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	worst = await _watch(me, 8.0, func() -> bool: return not bool(me.get("aloft")))
	_check(not bool(me.get("aloft")) and me.local_position().y < 1.0, "E: back down on deck (%.1f m up)" % me.local_position().y)
	_check(worst < 0.25, "climbed all the way down, never more than %.2f m in a frame" % worst)
	var foot: Vector3 = tower.get("foot")
	_check(Vector2(me.local_position().x - foot.x, me.local_position().z - foot.z).length() < 0.6,
			"at the foot of the ladder")
	var deck_text := await _spotted(sea, me, s)
	_check(deck_text.begins_with("Birds"), "from the deck the same flock's just birds: %s" % deck_text)
	at = me.local_position()
	me.set("_yaw", 0.0)
	Input.action_press("move_back")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("move_back")
	_check(me.local_position().distance_to(at) > 0.2, "and walking again")
	sea.fish_hold.head_in()
	await get_tree().process_frame
	sea.fish_hold.head_out("skiff")
	await get_tree().create_timer(0.3).timeout
	_check(sea.boat.get("tower") == null, "the skiff has no tower")
	_done()


## Frames till `until` (or `secs`), and the furthest you moved on her deck in one of them.
func _watch(me: Node, secs: float, until: Callable) -> float:
	var worst := 0.0
	var last: Vector3 = me.local_position()
	var t := 0.0
	while t < secs and not until.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		worst = maxf(worst, (me.local_position() as Vector3).distance_to(last))
		last = me.local_position()
	return worst


## What the spotter makes of flock `s` from where your eye is now, and whether it'd pick it out with your crosshair on
## it ("" if not).
func _spotted(sea: Sea, me: Node, s: Node) -> String:
	var cam := me.get("cam") as Camera3D
	var cen: Vector2 = s.call("center", sea.schools.now())
	var to := Vector3(cen.x, cam.global_position.y * 0.5 + 6.0, cen.y) - cam.global_position
	var local := sea.boat.global_basis.inverse() * to
	me.set("_yaw", atan2(-local.x, -local.z))
	me.set("_pitch", atan2(local.y, Vector2(local.x, local.z).length()))
	await get_tree().process_frame
	await get_tree().process_frame
	if sea.spotter.call("_aimed_at", cam) != s:
		return ""
	return str(sea.spotter.call("describe", cam, s))


## Whether, standing at `stand` (boat-local) facing `face` (yaw), some look in a fan around it puts the crosshair on
## `target`.
func _can_look_at(me: Node, stand: Vector3, target: Node, face: float) -> bool:
	me.call("place", stand, face)
	for p in 13:
		for dy in range(-6, 7):
			me.set("_yaw", face + dy * 0.08)
			me.set("_pitch", 0.4 - p * 0.1)
			await get_tree().process_frame
			if me.call("looking_at") == target:
				return true
	return false


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("TOWER TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
