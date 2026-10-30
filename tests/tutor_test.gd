extends Node
## The first fish's lesson (ui/fight_tutor.gd), headless: off in tests unless turned on; on, the fish takes and the
## fight holds still (nothing moves, nothing's lost) while it asks you to reel, waits till you do, then waits for you
## to read why and press on; then the run, when the drag slips; a jump, the tip dropped; the pump in two steps; the
## drag eased; the spiral; and the landing step by step (rod back, harpoon, aboard), its hook clock held meanwhile.
## Run: godot --headless --path . res://tests/tutor_test.tscn

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")

var fails: Array[String] = []
var sea: Sea
var tutor: Node


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await _frames(3)
	var rods := sea.rods
	tutor = rods.tutor
	_check(tutor != null and not bool(tutor.enabled), "in a test it's off unless asked")
	tutor.enabled = true
	var me: Node = sea.crew.me
	me.force_input = true
	sea.schools.set("_next", 9999.0)
	# a fish on, the rod in your hands
	rods.host_cast(0)
	rods.strike(0, 120.0)
	rods.request_grab(0)
	await _frames(3)
	var r: Node = rods.rods[0]
	var f := r.get("fight") as Fight
	_check(f != null and tutor.busy() and str(tutor.get("_id")) == "reel", "fish on: the first lesson's up (%s)"
			% tutor.get("_id"))
	_check(f != null and f.paused, "and the fight holds still")
	var out := f.line_out
	var energy := f.energy
	var hold := f.hold
	await _wait(2.0)
	_check(is_equal_approx(f.line_out, out) and is_equal_approx(f.energy, energy) and is_equal_approx(f.hold, hold)
			and not f.done, "two seconds paused: he hasn't moved, nothing's lost")
	# REEL: it waits till you do it
	_check(str(tutor.get("_phase")) == "do", "it waits for you to reel")
	Input.action_press("use_primary")
	await _wait(1.0)
	Input.action_release("use_primary")
	_check(str(tutor.get("_phase")) == "why", "held left mouse: done, and why")
	await _wait(1.0)
	_check(f.paused, "still paused while you read")
	await _next()
	await _frames(2)
	_check(not f.paused and bool(tutor.taught("reel")), "SPACE: taught, and the fight runs on")
	# the run: as soon as the drag slips
	for k in 300:
		if str(tutor.get("_id")) == "run":
			break
		await get_tree().process_frame
	_check(str(tutor.get("_id")) == "run" and f.paused, "he runs, the drag slips: let go (%s)" % tutor.get("_id"))
	await _wait(1.3)
	_check(str(tutor.get("_phase")) == "why", "hands off the mouse: done")
	await _next()
	await _frames(2)
	_check(not f.paused and bool(tutor.taught("run")), "on again")
	# a jump: the tip dropped
	await _wait(2.2)
	f.call("_set_move", "jump")
	await _frames(2)
	_check(str(tutor.get("_id")) == "jump" and f.paused, "he jumps: paused on the way up (%s)" % tutor.get("_id"))
	rods.bot_aim = Vector3(0.2, 0.0, 0.0)
	await _wait(0.8)
	rods.bot_aim = Vector3(NAN, 0.0, 0.0)
	_check(str(tutor.get("_phase")) == "why", "rod tip down: done")
	await _next()
	await _frames(2)
	# the pump, two steps: lift, then wind as you drop
	tutor.call("_drop")
	tutor.call("_start", "pump", f, r)
	await _frames(1)
	Input.action_press("use_secondary")
	await _wait(1.2)
	Input.action_release("use_secondary")
	_check(int(tutor.get("_step")) == 1, "right mouse: the rod up, step two")
	Input.action_press("use_primary")
	for k in 60:
		me.set("fight_mouse", Vector2(0.0, 20.0))
		await get_tree().process_frame
	Input.action_release("use_primary")
	_check(str(tutor.get("_phase")) == "why", "left mouse winding as it drops: a pump")
	await _next()
	await _frames(2)
	# the drag eased
	tutor.call("_drop")
	tutor.call("_start", "ease", f, r)
	await _frames(1)
	rods.set("_notch_t", -10.0)
	rods.notch_drag(r, -1)
	await _frames(2)
	_check(str(tutor.get("_phase")) == "why", "a notch down on the wheel: eased")
	await _next()
	await _frames(2)
	# the spiral: wind as he comes up, let go as he goes under
	tutor.call("_drop")
	tutor.call("_start", "spiral", f, r)
	Input.action_press("use_primary")
	await _wait(1.0)
	Input.action_release("use_primary")
	await _wait(1.2)
	_check(str(tutor.get("_phase")) == "why", "the spiral: wound, then let go")
	await _next()
	await _frames(2)
	for id: String in ["reel", "run", "jump", "pump", "ease", "spiral"]:
		_check(bool(tutor.taught(id)), "taught: %s" % id)
	# the landing
	sea.landing.host_alongside(0, 120.0, float(r.get("bearing")), float(r.get("hook_t")))
	await _frames(3)
	_check(str(tutor.get("_id")) == "land", "alongside: the landing, step by step")
	var step: Array = tutor.get("_land_do")
	_check(not step.is_empty() and str(step[0]).contains("ROD"), "first: the rod in a holder (%s)" % [step])
	_check(sea.landing.get("_clock_held").has(0), "the hook clock held meanwhile")
	await _wait(1.0)
	_check(float(sea.landing.fish[0]["t"]) < 0.01, "and it doesn't run (%.2f s)" % float(sea.landing.fish[0]["t"]))
	rods.request_return(0)
	await _frames(2)
	step = tutor.get("_land_do")
	_check(str(step[0]).contains("HARPOON") or str(step[0]).contains("LEADER"), "then the harpoon (%s)" % [step])
	sea.landing.call("_host_aboard", 0)
	await _frames(2)
	_check(str(tutor.get("_phase")) == "why", "aboard: why it matters")
	await _wait(0.8)
	await _next()
	await _frames(2)
	_check(bool(tutor.taught("land")) and not tutor.busy(), "landed: taught")
	_check(not sea.landing.get("_clock_held").has(0), "the hook clock let go")
	# the radio needn't say it all over again
	_check(bool(tutor.covers("fight")) and bool(tutor.covers("alongside")), "Dale's radio tips for these stand down")

	for f2 in fails:
		print("FAIL: ", f2)
	print("TUTOR TEST: %s" % ("PASS" if fails.is_empty() else "%d FAILED" % fails.size()))
	get_tree().quit(0 if fails.is_empty() else 1)


## SPACE, once you've had time to read why.
func _next() -> void:
	await _wait(0.8)
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
