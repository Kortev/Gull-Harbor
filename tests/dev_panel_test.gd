extends Node
## The host's dev panel (ui/dev_panel.gd): F1 opens it; a weather called from it turns in over a few seconds (never a
## jump) and can be let go again; the day moved on for a boat that's out; a fish on; birds in near.
## With -- --dev-shot=<png> and a window: a picture of it open.

const Sea := preload("res://sea/sea.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(1.0).timeout
	var dev: Node = sea.get_node("DevPanel")
	_check(dev != null and not dev.visible, "the panel's there, shut")
	var k := InputEventKey.new()
	k.keycode = KEY_F1
	k.pressed = true
	Input.parse_input_event(k)
	await get_tree().create_timer(0.2).timeout
	_check(dev.visible, "F1 opens it (the host's)")
	sea.weather.pinned = ""
	sea.host_call_weather("calm")
	await get_tree().create_timer(float(sea.weather.CALL_TURN) + 1.0).timeout
	_check(sea.condition == "calm", "calm called: calm (%s)" % sea.condition)
	dev.call("_weather", "storm")
	await get_tree().create_timer(1.0).timeout
	var early := float(sea.ocean.weather)
	_check(sea.condition == "calm", "a storm called: not there at once (%s, the sea %.2f)" % [sea.condition, early])
	var worst := 0.0
	var last := early
	var t := 0.0
	while t < float(sea.weather.CALL_TURN) + 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		worst = maxf(worst, absf(float(sea.ocean.weather) - last))
		last = float(sea.ocean.weather)
	_check(sea.condition == "storm" and worst < 0.05, "it comes in, no jump (the most in a frame %.3f): %s" % [worst, sea.condition])
	dev.call("_weather", "")
	await get_tree().create_timer(float(sea.weather.CALL_TURN) + 1.0).timeout
	_check(str(sea.weather.called) == "", "let go: on its own again (%s)" % sea.condition)
	dev.call("_day", 0.45)
	_check(sea.fish_hold.docked, "at the dock: the day's not moved")
	sea.fish_hold.head_out("skiff")
	await get_tree().create_timer(0.3).timeout
	dev.call("_day", 0.75)
	_check(absf(float(sea.fish_hold.day_fraction()) - 0.75) < 0.01, "out there: late in the day (%.2f)" % sea.fish_hold.day_fraction())
	dev.call("_fish_on")
	await get_tree().create_timer(0.5).timeout
	var on := 0
	for r: Node in sea.rods.rods:
		on += 1 if bool(r.get("hooked")) else 0
	_check(on == 1, "a fish on (%d)" % on)
	dev.call("_birds")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dev-shot=") and DisplayServer.get_name() != "headless":
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(11))
	for f in fails:
		print("FAIL ", f)
	print("DEV PANEL TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
