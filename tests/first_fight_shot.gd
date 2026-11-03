extends Node
## A first-timer's first fish, start to end, shot every 2 s (and at the moments): at the wheel when it strikes, off the
## wheel and down to the rod, picking it up, then fighting him doing only what the screen says to (ui/fight_coach.gd's
## keys), with a first-timer's mistake or two (cranking into his first run). Each shot's line printed with what the
## coach said, so the stills can be read against it: could you tell he's on, and do you know what to press?
## Run (needs a window):
##   godot --fixed-fps 30 --resolution 1280x720 --path . res://tests/first_fight_shot.tscn -- --out=<dir> [--kind=skiff]
##   [--kg=110] [--every=2]

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")

var sea: Sea
var out := "user://first_fight/"
var kind := "skiff"
var kg := 110.0
var every := 2.0
var _n := 0
var _t := 0.0
var _next := 0.0
var _notch := 0.0
var _pitch := 0.6
var pad := false
var _bad := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6).trim_suffix("/") + "/"
		elif a.begins_with("--kind="):
			kind = a.substr(7)
		elif a.begins_with("--kg="):
			kg = float(a.substr(5))
		elif a.begins_with("--every="):
			every = float(a.substr(8))
		elif a == "--pad":
			pad = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out(kind)
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.3
	sea.set_condition("sunny")
	sea.schools.set("_next", 9999.0)
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if pad:
		Settings.pad = true          # (as if the pad's what's in your hands: its buttons named)
	var me: Node = sea.crew.me
	me.force_input = true
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	for r in sea.rods.rods:
		while sea.rods.flying(r.index):
			await get_tree().process_frame
	# at the wheel, trolling, nothing on
	var helm: Node = sea.boat.get("helm")
	helm.call("request", true)
	await _wait(3.0)
	await _shot("wheel")
	# the strike, on the far rod
	var i := sea.rods.rods.size() - 1 if kind == "sportfisher" else 0
	var rod: Node = sea.rods.rods[i]
	sea.rods.strike(i, kg)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("strike_0")
	await _wait(0.5)
	await _shot("strike_1")
	await _wait(1.5)
	await _shot("strike_2")
	# off the wheel, turn to the rod, walk to it
	helm.call("request", false)
	await _wait(0.4)
	var walked := 0.0
	while walked < 10.0:
		var b := sea.boat as Node3D
		var d: Vector3 = b.global_basis.inverse() * (rod.global_position - (me as Node3D).global_position)
		me.set("_yaw", atan2(-d.x, -d.z))
		me.set("_pitch", -0.25)
		if Vector2(d.x, d.z).length() < 1.1:
			break
		Input.action_press("move_forward")
		await get_tree().process_frame
		walked += get_process_delta_time()
		_t += get_process_delta_time()
		if _t >= _next:
			_next = _t + 1.0
			await _shot("walk")
	Input.action_release("move_forward")
	await _wait(0.3)
	await _shot("at_rod")
	# (Dale's said to: the other lines in first)
	for r in sea.rods.rods:
		if r.index != i and not r.bait_in:
			sea.rods._host_line(r.index, true)
	sea.rods.request_grab(i)
	await _wait(0.3)
	await _shot("grabbed")
	# the fight: doing what it says
	var fight_t := 0.0
	_next = _t + every
	var mistakes := 0
	while rod.hooked and not rod.alongside and fight_t < 600.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		fight_t += dt
		_t += dt
		var hud: Node = sea.rods.get("_fight_hud")
		var coach: RefCounted = hud.get("coach") if hud != null else null
		var crank := false
		if coach != null and rod.fight != null:
			var keys := str(coach.get("keys"))
			match keys:
				"none":
					_pitch = move_toward(_pitch, 0.9, 0.8 * dt)
				"lift":
					_pitch += 0.7 * dt
				"wind":
					_pitch -= 1.0 * dt
					crank = true
				"drop":
					_pitch = move_toward(_pitch, 0.3, 2.5 * dt)
				"drag_down", "drag_up":
					_notch -= dt
					if _notch <= 0.0:
						_notch = 1.0
						sea.rods.set_drag(rod, float(rod.drag) + (Fight.STEP if keys == "drag_up" else -Fight.STEP))
			if str(coach.get("word")) == "SLACK":
				crank = true
			# a first-timer's mistake: winding into his first run (till it's said, in red, and a beat more)
			if mistakes == 0 and keys == "none":
				crank = true
				if str(coach.get("tone")) == "bad":
					mistakes = 1
			_pitch = clampf(_pitch, maxf(float(rod.aim_pitch) - 0.2, 0.15), minf(float(rod.aim_pitch) + 0.2, 1.35))
		# (through the mouse, the way a player's hand moves the rod: the look follows the line as it would)
		me.set("fight_mouse", Vector2(0.0, -(_pitch - float(rod.aim_pitch)) / 0.0035))
		if coach != null and (str(coach.get("tone")) == "bad") != _bad:
			_bad = not _bad
			if _bad:
				print("COACH t=%.1f RED: %s" % [_t, coach.get("say")])
		if crank:
			Input.action_press("use_primary")
		else:
			Input.action_release("use_primary")
		# (and once, a notch off the drag and back, the way you'd try the wheel: what it does, by the reel)
		if fight_t >= 30.0 and fight_t - dt < 30.0:
			sea.rods.set_drag(rod, float(rod.drag) - Fight.STEP)
			await _wait(0.4)
			await _shot("drag")
			sea.rods.set_drag(rod, float(rod.drag) + Fight.STEP)
		if _t >= _next:
			_next = _t + every
			await _shot("fight")
	Input.action_release("use_primary")
	sea.rods.bot_aim = Vector3(NAN, 0.0, 0.0)
	print("END fight %.0f s: %s" % [fight_t, "alongside" if rod.alongside else ("lost" if not rod.hooked else "still on")])
	await _wait(0.6)
	await _shot("end_0")
	await _wait(2.0)
	await _shot("end_1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
		_t += get_process_delta_time()


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var path := "%s%03d_%s.png" % [out, _n, what]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	var hud: Node = sea.rods.get("_fight_hud")
	var coach: RefCounted = hud.get("coach") if hud != null else null
	var rod: Node = sea.rods.held_by(Net.my_id())
	var f: RefCounted = rod.get("fight") if rod != null else null
	var said := ""
	if coach != null:
		said = "%s | %s%s | keys %s a %.2f caps %.2f" % [coach.get("word"), coach.get("say"),
				(" > " + str(coach.get("then"))) if str(coach.get("then")) != "" else "", coach.get("keys"),
				float(coach.get("a")), float(coach.get("caps_a"))]
	var state := ""
	if f != null:
		state = "out %.0f m bend %.2f move %s energy %.2f drag %.1f pitch %.2f" % [float(f.get("line_out")),
				float(f.get("strain")), f.get("move"), float(f.get("energy")), float(f.get("drag")), _pitch]
	print("SHOT %03d %s t=%.1f  %s  %s  tell=%s" % [_n, what, _t, said, state,
			str((sea.crew.hud as Node).get("_tell").get("text")) if sea.crew.hud != null else ""])
