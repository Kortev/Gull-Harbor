extends Node
## The first fish, taught in the moment (ui/fight_tutor.gd, ui/tips.gd, rods/fight_calls.gd), headless: the fight is
## never held still behind a card, he keeps fighting while Dale says what to do on the VHF the first time each thing
## comes up (the bend, the drag slipping, half the spool gone, the leader); and the landing, step by step (rod back,
## harpoon, aboard), its hook clock held meanwhile. Run: godot --headless --path . res://tests/tutor_test.tscn

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
	# a fish on, the rod in your hands: no card, no freeze; he's off and the line's going
	rods.host_cast(0)
	rods.strike(0, 120.0)
	rods.request_grab(0)
	await _frames(3)
	var r: Node = rods.rods[0]
	var f := r.get("fight") as Fight
	var out := f.line_out if f != null else 0.0
	await _wait(1.5)
	_check(f != null and not tutor.busy() and not f.done and f.line_out > out + 3.0,
			"fish on: no card, nothing held still, he's running (%.0f -> %.0f m)" % [out, f.line_out if f else 0.0])
	_check(sea.tips.get("_seen").has("fight"), "Dale on the VHF, in the moment: the bend, the pump, hands off on a run")
	_check(not sea.tips.get("_seen").has("leader") and not sea.tips.get("_seen").has("spool"),
			"and nothing he hasn't come to yet")
	# the drag slipping in your hands a while: Dale's line on the drag lever
	var slipped := 0.0
	f.carry_on("run", f.stretch, 1.0, 1.0)
	f.grace = 999.0
	while slipped < 6.0 and not sea.tips.get("_seen").has("drag"):
		if f.move != "run":
			f.carry_on("run", f.stretch, 1.0, 1.0)
			f.grace = 999.0
		await get_tree().process_frame
		slipped += get_process_delta_time()
	_check(sea.tips.get("_seen").has("drag"), "the drag slipping a while: Dale on the lever (%.1f s)" % slipped)
	# half the spool gone: the tip for it, and nobody was frozen for any of it
	f.line_out = Fight.CAPACITY * 0.55
	await _frames(4)
	_check(sea.tips.get("_seen").has("spool"), "half the spool gone: Dale says back her down")
	f.line_out = Fight.LEADER - 2.0
	f.energy = 0.1
	await _frames(4)
	_check(sea.tips.get("_seen").has("leader") and str(rods.calls.last).contains("LEADER"),
			"the leader up: Dale, and the shout (%s)" % rods.calls.last)
	_check(not tutor.busy(), "and still no card: it was all said while he fought")
	rods._host_off(0, "")
	await _frames(2)
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
	# the radio needn't say the landing all over again (the fight's his to say)
	_check(not bool(tutor.covers("fight")) and bool(tutor.covers("alongside")), "Dale's landing tip stands down; the fight's is his")

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
