extends Node
## Your look with a fish on (rods.gd's _aim): it creeps after the line while he's well off, never faster than
## CAM_TURN; a fish circling close round her (fast, 12 m off, under her and out again) doesn't turn you at all; laying
## the rod over doesn't turn you; and your own mouse, past the rod's stop, turns you at once and stays where you put it.
## Run: godot --headless --path . res://tests/fight_look_test.tscn

const Sea := preload("res://sea/sea.gd")
const Rods := preload("res://rods/rods.gd")

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	sea.fish_hold.head_out("sportfisher")
	sea.schools.set("_next", 9999.0)
	await get_tree().process_frame
	var me: Node = sea.crew.me
	me.force_input = true
	sea.rods.host_cast(0)
	while sea.rods.flying(0):
		await get_tree().process_frame
	sea.rods.strike(0, 250.0)
	sea.rods.request_grab(0)
	var rod: Node = sea.rods.rods[0]
	_check(rod.hooked and rod.holder == 1, "a fish on, the rod in your hands")
	await _hold(rod, 1.0, 12.0, 0.0, 0.0)
	# close in, circling round her fast (a full lap in ten seconds, under her and out)
	var close := await _hold(rod, 10.0, 12.0, TAU / 10.0, 0.0)
	_check(close < 0.06, "a fish circling 12 m off, a lap in 10 s: your look turns %.1f deg/s at most" % rad_to_deg(close))
	# well off, swinging wide: it follows, gently
	var far := await _hold(rod, 6.0, 70.0, 0.4, 0.0)
	_check(far <= Rods.CAM_TURN + 0.03 and far > 0.05,
			"a fish 70 m off swinging 0.4 rad/s: your look follows, %.1f deg/s at most" % rad_to_deg(far))
	# laying the rod over (inside its stop) doesn't turn you
	var yaw0 := float(me.get("_yaw"))
	var lay := await _hold(rod, 1.0, 12.0, 0.0, 250.0)
	_check(absf(rod.aim_side) > 0.5 and absf(wrapf(float(me.get("_yaw")) - yaw0, -PI, PI)) < 0.03,
			"the rod laid over (%.2f) without turning you" % rod.aim_side)
	# your mouse past the stop turns you, at once, and close in it stays where you put it
	yaw0 = float(me.get("_yaw"))
	await _hold(rod, 0.5, 12.0, 0.0, 1200.0)
	await _hold(rod, 0.6, 12.0, 0.0, 0.0)          # (your look easing round to it)
	var turned := absf(wrapf(float(me.get("_yaw")) - yaw0, -PI, PI))
	var after := float(me.get("_yaw"))
	await _hold(rod, 3.0, 12.0, 0.0, 0.0)
	_check(turned > 1.0 and absf(wrapf(float(me.get("_yaw")) - after, -PI, PI)) < 0.05,
			"your mouse turns you (%.0f deg) and it stays there (%.1f deg since)"
			% [rad_to_deg(turned), rad_to_deg(absf(wrapf(float(me.get("_yaw")) - after, -PI, PI)))])
	for f in fails:
		print("FAIL ", f)
	print("FIGHT LOOK TEST ", "PASSED" if fails.is_empty() else "FAILED")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit(1 if not fails.is_empty() else 0)


## `s` seconds with the fish held `out` m off, going round her at `swing` rad/s, nothing lost meanwhile, and the
## mouse moving `mouse_x` px a second; returns the fastest your look turned (rad/s, over half-second spans).
func _hold(rod: Node, s: float, out: float, swing: float, mouse_x: float) -> float:
	var me: Node = sea.crew.me
	var t := 0.0
	var worst := 0.0
	var span_t := 0.0
	var span_yaw := float(me.get("_yaw"))
	var b := float(rod.bearing)
	while t < s and rod.hooked:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		b += swing * dt
		var f: RefCounted = rod.fight
		if f != null:
			f.set("grace", 999.0)
			f.set("bearing", b)
			f.set("line_out", out)
			f.set("depth", 4.0)
			f.set("wear", 0.0)
		rod.bearing = b
		if mouse_x != 0.0:
			me.set("fight_mouse", Vector2(-mouse_x * dt, 0.0))
		span_t += dt
		if span_t >= 0.5:
			worst = maxf(worst, absf(wrapf(float(me.get("_yaw")) - span_yaw, -PI, PI)) / span_t)
			span_t = 0.0
			span_yaw = float(me.get("_yaw"))
	return worst


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
