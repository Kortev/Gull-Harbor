extends Node
## Water for people (crew/player.gd, boat/ladder.gd), headless, in the skiff:
## - over the side: Space at her rail (a step off it, looking at it) and you're over it and in, a splash; afloat at
##   the waves' own height (the height the boats float on), your eyes at the water, not sinking, a beat behind the
##   swell; strokes (a slap of water each); a sprint's quicker than a swim; Ctrl dives you under (the murk) and you
##   come up gasping; swim to her boarding ladder and E by its foot (no crosshair on it) and you've hold of it: W up
##   a step at a time (neither and you hang there), S back down and into the water at the foot, E again, up W over
##   her transom onto her deck, never a jump in where you are (in her frame); from her deck, E at its top takes you
##   down it;
## - the shove (a stand-in crewmate, the host deciding): the windup first, then the push; near the rail it puts you
##   over, a braced fighter goes half as far and over the rail leaves the rod in its holder with the fish still on,
##   and the cooldown holds.
## Run: godot --headless --fixed-fps 30 --path . res://tests/swim_test.tscn

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.save_path = "user://bluefin_test.cfg"
	hold.head_out("skiff")
	await get_tree().create_timer(0.5).timeout
	await _swim()
	await _shove()
	_done()


func _swim() -> void:
	var boat := sea.boat
	var me := sea.crew.me
	me.force_input = true
	var deck := float(boat.deck)
	# at her starboard side amidships, a step off it, looking at it: jump
	me.place(Vector3(0.5, deck + 0.02, 2.0), -PI / 2.0)
	await _wait(0.4)
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	_check(me.mode == Player.HOP, "Space at the rail: over it (mode %d)" % me.mode)
	await _until(func() -> bool: return me.mode == Player.SWIM, 2.0)
	_check(me.mode == Player.SWIM and me.frame == null, "and into the sea")
	await _until(func() -> bool: return me.splashes > 0, 3.0)
	_check(me.splashes == 1, "a splash going in")
	await _until(func() -> bool: return me.gasps > 0, 3.0)
	_check(me.gasps >= 1, "under, and up with a gasp")
	# afloat: at the waves' height, eyes out, a beat behind them; not sinking
	await _wait(2.0)
	var off := 0.0
	var dry := 0
	var n := 0
	var lows: Array[float] = []
	var t0 := Time.get_ticks_msec()
	for i in 240:
		await get_tree().process_frame
		var at := me.global_position
		var water := float(sea.ocean.height_at(at))
		off = maxf(off, absf(at.y - (water - Player.FLOAT)))
		lows.append(at.y - water)
		n += 1
		if at.y + 1.62 > water:
			dry += 1
	var first := 0.0
	var last := 0.0
	for i in 60:
		first += lows[i] / 60.0
		last += lows[lows.size() - 1 - i] / 60.0
	_check(off < 0.7, "afloat at the waves' height (at most %.2f m off)" % off)
	_check(dry > n * 0.9, "eyes out of the water (%d of %d)" % [dry, n])
	_check(absf(last - first) < 0.3 and last > -Player.FLOAT - 0.35, "not sinking (%.2f then %.2f under)" % [first, last])
	var cam := me.cam.global_position
	_check(absf(cam.y - float(sea.ocean.height_at(cam))) < 0.6, "the camera at the water (%.2f over it)"
			% (cam.y - float(sea.ocean.height_at(cam))))
	print("(swum in %.1f s)" % ((Time.get_ticks_msec() - t0) * 0.001))
	# strokes: a swim, then a sprint, each over 3 s
	var swum := []
	for sprint: bool in [false, true]:
		var from := me.global_position
		var s0 := me.strokes
		if sprint:
			Input.action_press("sprint")
		Input.action_press("move_forward")
		await _wait(3.0)
		Input.action_release("move_forward")
		Input.action_release("sprint")
		swum.append(Vector2(me.global_position.x - from.x, me.global_position.z - from.z).length())
		_check(me.strokes - s0 >= 2, "strokes, a slap of water each (%d)" % (me.strokes - s0))
		await _wait(1.5)
	_check(swum[0] > 2.5 and swum[1] > swum[0] * 1.3, "a swim (%.1f m in 3 s), a sprint quicker (%.1f m)" % swum)
	# under: Ctrl held, down into the murk; let go, up with a gasp
	await _wait(2.0)
	var g0 := me.gasps
	Input.action_press("swim_down")
	await _wait(1.5)
	var cam_under := me.cam.global_position.y - float(sea.ocean.height_at(me.cam.global_position))
	_check(cam_under < -0.3 and me.get("_murk").visible, "diving: under, in the murk (%.2f m)" % cam_under)
	Input.action_release("swim_down")
	await _until(func() -> bool: return me.gasps > g0, 4.0)
	_check(me.gasps > g0, "up again, with a gasp")
	await _wait(1.0)
	# swim round to her ladder
	var ladder := boat.ladder
	var near := false
	t0 = Time.get_ticks_msec()
	Input.action_press("move_forward")
	for i in 30 * 60:
		await get_tree().physics_frame
		var goal := ladder.global_transform * Vector3(0.0, 0.0, 0.9)
		var d := goal - me.global_position
		d.y = 0.0
		if d.length() < 0.9:
			near = true
			break
		me.set("_yaw", atan2(-d.x, -d.z))
	Input.action_release("move_forward")
	_check(near, "swum round to her ladder")
	_check(str(ladder.interact_prompt()) == "Climb aboard", "the ladder says: %s" % ladder.interact_prompt())
	# E by its foot, looking away from it: hold of it
	me.set("_yaw", float(me.get("_yaw")) + PI * 0.6)
	_check(me.call("_target") == ladder, "E by the ladder's foot finds it, crosshair or not")
	ladder.interact(me)
	_check(me.mode == Player.CLIMB and me.frame == boat, "hold of the ladder")
	# a bit up, then S back down and into the water at its foot
	Input.action_press("move_forward")
	await _wait(1.2)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _until(func() -> bool: return me.mode == Player.SWIM, 4.0)
	Input.action_release("move_back")
	_check(me.mode == Player.SWIM, "S down it and back into the water at the foot")
	await _wait(0.6)
	ladder.interact(me)
	_check(me.mode == Player.CLIMB, "E: hold of it again")
	# W: up it, a step at a time, over the transom onto her deck
	Input.action_press("move_forward")
	var step := 0.0
	var prev := boat.global_transform.affine_inverse() * me.global_position
	var climbing := 0.0
	var hung := -1.0
	var hang_moved := 0.0
	while me.mode == Player.CLIMB and climbing < 8.0:
		await get_tree().process_frame
		climbing += 1.0 / 30.0
		var here := boat.global_transform.affine_inverse() * me.global_position
		step = maxf(step, here.distance_to(prev))
		if hung > 0.05 and hung < 0.5:
			hang_moved = maxf(hang_moved, here.distance_to(prev))
		prev = here
		if hung < 0.0 and climbing > 0.7:
			# let go of W: you hang on the ladder
			Input.action_release("move_forward")
			hung = 0.0
		elif hung >= 0.0 and hung < 0.5:
			hung += 1.0 / 30.0
			if hung >= 0.5:
				Input.action_press("move_forward")
				hung = 1.0
	Input.action_release("move_forward")
	var aboard := boat.global_transform.affine_inverse() * me.global_position
	_check(me.mode == Player.DECK and me.boat == boat and me.frame == boat, "up the ladder and aboard her")
	_check(absf(aboard.y - deck) < 0.15 and aboard.z < float(boat.spec["ladder"].z), "on her deck, inside her transom "
			+ "(%.2f, %.2f, %.2f)" % [aboard.x, aboard.y, aboard.z])
	_check(climbing > 1.4 and climbing < 4.0, "a climb, not a jump (%.1f s held and let go)" % climbing)
	_check(step < 0.13, "nothing jumps on the way (at most %.3f m a frame, in her frame)" % step)
	_check(hang_moved < 0.01, "let go of W, you hang there (%.3f m)" % hang_moved)
	await _wait(0.5)
	_check(me.body.is_on_floor(), "standing on her deck")
	# from her deck, at its top, facing aft: E takes you over and down it; E again on it lets go, into the sea
	var stood: Vector3 = me.local_position()
	me.set("_yaw", 0.0)
	await get_tree().process_frame
	_check(me.call("_target") == null, "facing forward, no ladder")
	me.set("_yaw", PI)
	await get_tree().process_frame
	_check(me.call("_target") == ladder and str(ladder.interact_prompt()) == "Climb down",
			"facing aft at the top: \"%s\"" % ladder.interact_prompt())
	ladder.interact(me)
	var jump := (boat.global_transform.affine_inverse() * me.global_position).distance_to(stood)
	_check(me.mode == Player.CLIMB and jump < 0.05, "hold of it from her deck, nothing moving (%.3f m)" % jump)
	Input.action_press("move_back")
	await _wait(1.6)
	Input.action_release("move_back")
	var down := boat.global_transform.affine_inverse() * me.global_position
	_check(me.mode == Player.CLIMB and down.y < deck - 0.2, "S: down it, over her transom (%.2f m)" % down.y)
	me.call("_let_go_ladder")
	await _until(func() -> bool: return me.splashes > 1, 3.0)
	_check(me.mode == Player.SWIM and me.splashes == 2, "E lets go: into the sea, a splash")
	me.place(stood, PI, boat)
	await _wait(0.5)


func _shove() -> void:
	var boat := sea.boat
	var me := sea.crew.me
	var deck := float(boat.deck)
	# a stand-in crewmate (peer 2: nobody's machine moves it here; the host's word does the shoving)
	var mate := Player.new()
	mate.name = "2"
	mate.boat = boat
	sea.crew.add_child(mate)
	await get_tree().physics_frame
	# near the starboard rail, the mate inboard of you, facing out
	me.place(Vector3(0.8, deck + 0.02, 2.0), -PI / 2.0)
	mate.place(Vector3(-0.15, deck + 0.02, 2.0), -PI / 2.0)
	await _wait(0.3)
	mate._host_shove()
	_check(mate.shoves == 1 and str(mate.get("_gesture")) == "shove", "the windup: everyone sees it coming")
	await _wait(0.2)
	_check(float(me.get("_knock")) <= 0.0, "nothing yet, in the windup")
	await _until(func() -> bool: return me.mode != Player.DECK, 2.0)
	_check(me.mode == Player.HOP or me.mode == Player.SWIM, "shoved near the rail: over it you go (mode %d)" % me.mode)
	await _until(func() -> bool: return me.mode == Player.SWIM, 2.0)
	mate._host_shove()
	_check(mate.shoves == 1, "and not again straight away")
	# out in the middle, pushed aft: how far, unbraced and braced
	var far := await _push_aft(me, mate, deck)
	var rods := sea.rods
	rods.host_cast(0)
	rods.strike(0, 150.0)
	await get_tree().process_frame
	rods.request_grab(0)
	var rod: Node = rods.rods[0]
	_check(rod.get("holder") == 1 and bool(rod.get("hooked")) and me.braced(), "a fish on the rod in your hands: braced")
	var held := await _push_aft(me, mate, deck)
	_check(held < far * 0.6, "a braced fighter's pushed less (%.2f m against %.2f)" % [held, far])
	_check(far > 1.0, "an unbraced one staggers well off (%.2f m)" % far)
	# braced at the rail, a hard one: over, the rod left in its holder, the fish still on it
	me.place(Vector3(1.02, deck + 0.02, 2.0), -PI / 2.0)
	mate.place(Vector3(0.1, deck + 0.02, 2.0), -PI / 2.0)
	await _wait(0.3)
	mate.set("_host_shove_at", -INF)        # (the test's own clock: skipping the cooldown)
	mate._host_shove()
	await _until(func() -> bool: return me.mode != Player.DECK, 2.0)
	if me.mode != Player.DECK:
		await _wait(0.5)
		_check(int(rod.get("holder")) == 0 and bool(rod.get("hooked")), "over the side: the rod in its holder, the fish "
				+ "still on (holder %d, hooked %s)" % [int(rod.get("holder")), rod.get("hooked")])
	else:
		print("(braced at the rail: stayed aboard)")


## You out in her cockpit, the mate behind you, shoved aft: how far you went (m).
func _push_aft(me: Node, mate: Node, deck: float) -> float:
	me.call("place", Vector3(0.8, deck + 0.02, 1.7), PI, sea.boat)
	mate.call("place", Vector3(0.8, deck + 0.02, 0.8), PI)
	await _wait(0.4)
	var from: Vector3 = me.call("local_position")
	mate.set("_host_shove_at", -INF)        # (skipping the cooldown)
	mate.call("_host_shove")
	await _wait(2.0)
	var to: Vector3 = me.call("local_position")
	_check(int(me.get("mode")) == Player.DECK, "pushed aft, still aboard")
	return Vector2(to.x - from.x, to.z - from.z).length()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(ok: Callable, s: float) -> void:
	var t := 0.0
	while not ok.call() and t < s:
		await get_tree().physics_frame
		t += 1.0 / 30.0


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("SWIM TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
