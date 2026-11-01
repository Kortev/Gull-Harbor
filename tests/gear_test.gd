extends Node
## Nothing snaps, headless: the gear moves the whole way, every frame. The jig (boat/jig.gd) leaves the rod tip from
## where it hangs, drops, sinks, is thumbed, worked, and wound back up to the tip with no jump in its position from one
## frame to the next, and the jig reel's crank turns by exactly the line wound in; a trolling rod (rods/rod.gd) comes
## up out of its holder and goes back without jumping, its bait flies out and lands, is wound back over the water and
## up to the tip with no jump, the crank turning PER_TURN a turn of line wound and still while it pays out; a bait let
## back falls off the tip onto the water; and a crewmate's winding turns their crank between their words, the line
## eased to their word, never jumped. Run: godot --headless --fixed-fps 30 --path . res://tests/gear_test.tscn

const Sea := preload("res://sea/sea.gd")
const Jig := preload("res://boat/jig.gd")
const Rods := preload("res://rods/rods.gd")
const Rod := preload("res://rods/rod.gd")

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
	sea.fish_hold.head_out("skiff")
	await _wait(0.3)
	sea.boat.helm.set("speed", 0.0)
	me = sea.crew.me
	me.force_input = true
	await _jig()
	await _rod()
	await _crewmate()
	for f in fails:
		print("FAIL ", f)
	print("GEAR TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


## The jig, start to finish, watched every frame.
func _jig() -> void:
	var jig: Jig = sea.jig
	var beam := float(sea.boat.spec["beam"])
	me.place(Vector3(beam * 0.5 - 0.55, float(sea.boat.spec["deck"]) + 0.05, 1.0), -PI * 0.5)
	me.set("_pitch", -0.2)
	me.hands.pick("jig")
	await _frames(20)
	var rig := me.hands._view.find_child("rig", true, false) as Node3D
	var hung: Vector3 = me.hands.rig_end()
	me.hands.press(true)
	me.hands.press(false)
	await get_tree().process_frame
	var first := jig.jig_point()
	_check(first != Vector3.INF and first.distance_to(hung) < 0.35,      # (a frame of its swing and its fall)
			"it leaves the tip from where it hung (%.2f m off)" % first.distance_to(hung))
	# down, thumbed, worked: every frame
	var worst := 0.0
	var last := first
	var t := 0.0
	while jig.depth < Jig.SCHOOL.x + 1.0 and t < 12.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var p := jig.jig_point()
		worst = maxf(worst, p.distance_to(last))
		last = p
	me.hands.press(true)
	me.hands.press(false)
	for i in 3:
		await _wait(0.5)
		me.hands.press(true)       # (a jig: the tip snatched up)
		me.hands.press(false)
		jig.set("_knock_in", INF)  # (nothing on it: tests/hands_test has the knock)
		for k in 12:
			await get_tree().process_frame
			var p := jig.jig_point()
			worst = maxf(worst, p.distance_to(last))
			last = p
	# (in a frame at 30 fps it falls no more than 9 m/s's worth, the jig's snatch eased)
	_check(worst < 0.45, "down and worked, never a jump (worst %.2f m in a frame)" % worst)
	_check(jig.state == "down", "thumbed at %.1f m" % jig.depth)
	# wound up: the crank turns with every bit of it, and it comes the whole way up to the tip
	var c0 := jig.crank
	var l0 := jig.line
	Input.action_press("use_primary")
	me.hands.press(true)
	worst = 0.0
	var steps := 0
	var bad_crank := 0.0
	while jig.state != "up" and steps < 600:
		var lb := jig.line
		var cb := jig.crank
		await get_tree().process_frame
		steps += 1
		bad_crank = maxf(bad_crank, absf((jig.crank - cb) - (lb - jig.line) / Jig.PER_TURN * TAU))
		var p := jig.jig_point()
		if p != Vector3.INF:
			worst = maxf(worst, p.distance_to(last))
			last = p
	Input.action_release("use_primary")
	me.hands.press(false)
	_check(jig.state == "up" and absf((jig.crank - c0) - (l0 - Jig.RIG) / Jig.PER_TURN * TAU) < 0.05,
			"the crank's turn is the line wound in (%.1f turns, %.1f m)" % [(jig.crank - c0) / TAU, l0 - Jig.RIG])
	_check(bad_crank < 0.01, "frame by frame too (worst %.3f rad off)" % bad_crank)
	_check(worst < 0.3, "up the whole way, never a jump (worst %.2f m in a frame)" % worst)
	await get_tree().process_frame
	var back: Vector3 = me.hands.rig_end()
	_check(last.distance_to(back) < 0.25, "and it's back on the tip where it ends (%.2f m off)" % last.distance_to(back))
	me.hands.pick("")
	await _frames(10)


## A trolling rod: out of its holder, the cast, the wind back in, back in the holder, a bait let back.
func _rod() -> void:
	var rods: Rods = sea.rods
	var r: Rod = rods.rods[0]
	rods._baited(0, rods._now(), true)
	me.place(Vector3(0.0, float(sea.boat.spec["deck"]) + 0.05, float(rods.stern.z) - 1.5), 0.0)
	me.set("_yaw", -PI * 0.75)
	await _frames(5)
	var last := r.global_position
	rods.request_grab(0)
	var worst := 0.0
	for i in 20:
		await get_tree().process_frame
		worst = maxf(worst, r.global_position.distance_to(last))
		last = r.global_position
	_check(rods.held_by(1) == r and worst < 0.35, "out of its holder into your hands, carried (worst %.2f m a frame)"
			% worst)
	# the cast, every frame: the crank still while it pays out, the spool going
	var c0 := r.crank
	var s0 := r.spool_turn
	rods.cast_mine(0.6)
	await get_tree().process_frame
	var end := r.line_end
	worst = 0.0
	var dt := 1.0 / 30.0
	while rods.flying(0) or r.get_meta("splash", false):
		await get_tree().process_frame
		worst = maxf(worst, r.line_end.distance_to(end))
		end = r.line_end
	await _frames(3)
	worst = maxf(worst, r.line_end.distance_to(end))
	end = r.line_end
	_check(worst < Rods.FLY * dt * 2.5, "out through the air and onto the water, never a jump (worst %.2f m)" % worst)
	_check(absf(r.crank - c0) < 0.001 and absf(r.spool_turn - s0) > TAU, "a cast: the spool spins, the crank's still "
			+ "(%.1f spool turns)" % (absf(r.spool_turn - s0) / TAU))
	# wound back in: the crank going round with the line, the bait over the water and up to the tip
	c0 = r.crank
	var out0 := rods.line_out(r)
	Input.action_press("use_primary")
	worst = 0.0
	var steps := 0
	while not r.bait_in and steps < 900:
		await get_tree().process_frame
		steps += 1
		worst = maxf(worst, r._lure.global_position.distance_to(end) if r._lure.visible else 0.0)
		end = r._lure.global_position
	Input.action_release("use_primary")
	await get_tree().process_frame
	worst = maxf(worst, r._lure.global_position.distance_to(end))
	_check(r.bait_in, "wound all the way in")
	_check(worst < 0.45, "the bait the whole way back to the tip, never a jump (worst %.2f m a frame)" % worst)
	var turns := (r.crank - c0) / TAU
	_check(absf(turns - out0 / Rod.PER_TURN) < 1.0, "the crank's turns are the line wound (%.1f turns, %.0f m)"
			% [turns, out0])
	# back in the holder, carried
	last = r.global_position
	rods.request_return(0)
	worst = 0.0
	for i in 20:
		await get_tree().process_frame
		worst = maxf(worst, r.global_position.distance_to(last))
		last = r.global_position
	_check(r.holder == 0 and worst < 0.35, "back in its holder, carried there (worst %.2f m a frame)" % worst)
	# let back: off the tip onto the water
	rods.request_grab(0)
	await _wait(0.5)
	Input.action_press("use_secondary")
	await get_tree().process_frame
	await get_tree().process_frame
	var p := r.bait_p
	worst = 0.0
	for i in 60:
		await get_tree().process_frame
		worst = maxf(worst, r.bait_p.distance_to(p))
		p = r.bait_p
	Input.action_release("use_secondary")
	_check(worst < 0.5, "let back: it falls off the tip onto the water, never a jump (worst %.2f m)" % worst)
	await _wait(0.3)
	rods.request_return(0)
	await _wait(0.5)


## A crewmate's rod winding in: their crank turns between their words, their line eased to their word.
func _crewmate() -> void:
	var rods: Rods = sea.rods
	var r: Rod = rods.rods[1]
	rods.host_cast(1)
	while rods.flying(1):
		await get_tree().process_frame
	await _frames(5)
	r.holder = 77          # (a crewmate: their word comes ten times a second)
	r.out = rods.line_out(r)
	var c0 := r.crank
	var o0 := r.out
	var jumps := 0.0
	for i in 30:
		if i % 3 == 0:
			r.set_meta("out_goal", maxf(o0 - (i + 3) / 30.0 * Rods.REEL_SPEED, 0.5))
			r.set_meta("reel_t", rods._now())
		var was := r.out
		await get_tree().process_frame
		jumps = maxf(jumps, absf(r.out - was))
	_check(r.crank - c0 > TAU * 0.5, "their crank turns while they wind (%.1f turns in a second)" % ((r.crank - c0) / TAU))
	_check(jumps < Rods.REEL_SPEED * 3.0 / 30.0, "their line eased, never jumped (worst %.2f m a frame)" % jumps)
	r.holder = 0
