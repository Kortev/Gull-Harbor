extends Node
## The harpoon, headless, thrown for real: holding left mouse winds it up (the aim's dots show) and letting go throws
## it; it flies, falling, and a throw led onto the fish's back sticks it (the dart stays in it) while one into the
## water misses. A miss spooks the fish and rolls its odds: with the odds against it, it tears free and swims off out
## and down, then it's gone and the rod's clear; with them for it, it stays and the HUD gives the next miss's odds.
## The first fish you're shown how to land (its hook clock held) never goes on a miss, and says so. Hit or miss the
## harpoon comes home to its rack on its line, and nothing (harpoon, fish) ever jumps from one place to another.
## Run: godot --headless --fixed-fps 30 --path . res://tests/harpoon_test.tscn

const Sea := preload("res://sea/sea.gd")
const Landing := preload("res://tuna/landing.gd")

var fails: Array[String] = []
var sea: Sea
## The biggest step anything watched took in one frame (m), and what.
var _jump := 0.0
var _jump_what := ""
var _was := {}
var _swam_up := false


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var landing := sea.landing
	var hold := sea.fish_hold
	hold.save_path = "user://bluefin_test.cfg"
	hold.owned = ["skiff"]
	hold.head_out("skiff")
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	await get_tree().process_frame
	var me := sea.crew.me
	me.set("force_input", true)
	me.call("place", Vector3(0.0, 0.6, 3.0), 0.0)

	# a fish up alongside, held quiet (wired: nobody needs to be on the rod for this)
	var i := await _alongside(0, 150.0)
	_check(landing.fish.has(i), "a fish up alongside")
	_check(_swam_up, "it swims up from where the fight left it, not popping in")
	var p0 := sea.boat.global_transform.affine_inverse() * (landing.fish[i]["node"] as Node3D).global_position
	await _frames(45)
	var p1 := sea.boat.global_transform.affine_inverse() * (landing.fish[i]["node"] as Node3D).global_position
	_check(p0.distance_to(p1) > 0.2, "alongside it keeps swimming (%.2f m in 1.5 s)" % p0.distance_to(p1))
	landing._request_harpoon(true)
	await _frames(2)
	_check(landing.harpoon_holder == 1, "the harpoon's yours")
	_check(landing.hint().contains("miss can lose it"), "the HUD says a miss can lose it: %s" % landing.hint())
	# winding up: hold left mouse (looking up and away: this one's just to see it go)
	landing.escape_odds = [0.0]
	me.set("_pitch", 0.5)
	_press(true)
	await get_tree().create_timer(Landing.DRAW + 0.2).timeout
	_check(landing.draw >= 0.99, "holding left mouse winds it all the way (%.2f)" % landing.draw)
	_check((landing.get("_arc") as Node3D).visible, "and the aim's dots show where it'll come down")
	_press(false)
	await _frames(2)
	_check(landing.harpoon_holder == 0 and not (landing.get("_flight") as Dictionary).is_empty(),
			"let go: it's out of your hands and flying")
	_check(not (landing.get("_arc") as Node3D).visible, "the dots gone with it")
	await _settle(2.0)
	_check(int(landing.fish[i]["misses"]) == 1 and not bool(landing.fish[i]["stuck"]), "into the sea: a miss")
	await _settle(Landing.RETURN + 0.5)
	landing._request_harpoon(true)
	await _frames(2)
	_check(landing.harpoon_holder == 1, "home on its line, and taken again")
	# led onto its back: aim where it'll be, let go
	_watch_reset()
	var aimed := await _aim_onto(i)
	_check(aimed, "found a way to lead it")
	landing.throw(1.0)
	var t := 0.0
	while not bool(landing.fish[i]["stuck"]) and t < 3.0:
		await _frames(1)
		t += 1.0 / 30.0
	_check(bool(landing.fish[i]["stuck"]), "it flew and stuck it (%.2f s)" % t)
	_check((landing.fish[i]["node"] as Node).has_node("Dart"), "the dart's in its back")
	_check(sea.crew.hud._note.text.begins_with("Stuck"), "the HUD says so: %s" % sea.crew.hud._note.text)
	# home on its line
	await _settle(Landing.RETURN + 1.0)
	var rack: Vector3 = sea.boat.global_transform * landing.rack_at()
	_check((landing.get("_harpoon") as Node3D).global_position.distance_to(rack) < 0.05, "and the harpoon's home in its rack")
	_check(_jump < 1.0, "nothing jumped: the most anything moved in a frame was %.2f m (%s)" % [_jump, _jump_what])
	landing.host_clear()
	await _frames(2)

	# a miss with the odds against it: it tears free, swims off, and it's gone
	landing.escape_odds = [1.0]
	i = await _alongside(1, 120.0)
	landing._request_harpoon(true)
	await _frames(2)
	_watch_reset()
	await _throw_into_water()
	_check(landing.fish.has(i) and float(landing.fish[i]["leave_t"]) >= 0.0, "missed: it tore free")
	_check(sea.crew.hud._note.text.contains("tore the hook out"), "the HUD says so: %s" % sea.crew.hud._note.text)
	_check(landing.hint() == "" or not landing.hint().contains("Harpoon"), "nothing left to harpoon: %s" % landing.hint())
	var going_from := (landing.fish[i]["node"] as Node3D).global_position
	await _settle(Landing.LEAVE * 0.5)
	if landing.fish.has(i):
		var now_at := (landing.fish[i]["node"] as Node3D).global_position
		_check(now_at.distance_to(going_from) > 1.0 and now_at.y < going_from.y,
				"it swims off out and down (%.1f m)" % now_at.distance_to(going_from))
	await _settle(Landing.LEAVE)
	_check(not landing.fish.has(i) and not sea.rods.rods[1].hooked, "then it's gone, and the rod's clear")
	_check(_jump < 1.0, "nothing jumped: %.2f m (%s)" % [_jump, _jump_what])

	# a miss with the odds for it: it stays on, spooked; the HUD gives the next miss's odds
	landing.escape_odds = [0.0, 0.4]
	i = await _alongside(0, 100.0)
	landing._request_harpoon(true)
	await _frames(2)
	_check(is_equal_approx(landing.escape_chance(i), 0.0), "first miss: no chance here")
	await _throw_into_water()
	_check(landing.fish.has(i) and float(landing.fish[i]["leave_t"]) < 0.0 and int(landing.fish[i]["misses"]) == 1,
			"missed, and it stayed on (one miss)")
	_check(sea.crew.hud._note.text.contains("Next miss: 40%"), "the HUD gives the next one's odds: %s"
			% sea.crew.hud._note.text)
	_check(float(landing.fish[i]["spook"]) > 0.0, "spooked by it")
	_check(is_equal_approx(landing.escape_chance(i), 0.4), "the next miss is likelier to lose it")
	landing.host_clear()
	await _settle(Landing.RETURN + 0.5)

	# the first fish you're shown: never lost on a miss, and it says so
	landing.escape_odds = [1.0]
	i = await _alongside(1, 100.0)
	landing.hold_clock(i, true)
	landing._request_harpoon(true)
	await _frames(2)
	await _throw_into_water()
	_check(landing.fish.has(i) and float(landing.fish[i]["leave_t"]) < 0.0, "the lesson's fish stays on a miss")
	_check(sea.crew.hud._note.text.contains("a miss can lose it"), "and it tells you a miss can lose the next: %s"
			% sea.crew.hud._note.text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(hold.save_path))
	_done()


## Rod `r`'s fish (kg) fought out and up alongside, held quiet on its leader; its index.
func _alongside(r: int, kg: float) -> int:
	sea.rods.strike(r, kg)
	var rod = sea.rods.rods[r]
	rod.line_out = 9.0         # (fought in close: tests/strike_test.tscn has the fight)
	if rod.fight != null:
		rod.fight.line_out = 9.0
		rod.fight.depth = 2.0
	await _frames(3)
	sea.landing.host_alongside(r, kg, float(rod.bearing), float(rod.hook_t))
	await _frames(1)
	sea.landing.fish[r]["wired_until"] = sea.landing._now() + 9999.0
	_swam_up = float(sea.landing.fish[r]["arrive"]) < 1.0
	await _settle(maxf(float(sea.landing.fish[r].get("arrive_s", 0.0)), Landing.ARRIVE) + 0.3)
	return r


## Looks about till a full throw from the harpoon in your hands, the way it's pointing, would go into fish i where
## it'll be (the throw's flown against the fish as they swim: _hit_along each frame). True if it found one.
func _aim_onto(i: int) -> bool:
	var me := sea.crew.me
	var landing := sea.landing
	var at := landing.fish_point(i)
	var best_yaw := 0.0
	var best := -2.0
	for k in 72:
		me.set("_yaw", k * TAU / 72.0)
		await _frames(1)
		var cam := me.get("cam") as Node3D
		var d := -cam.global_basis.z
		var to := (at - cam.global_position)
		var dot := Vector2(d.x, d.z).normalized().dot(Vector2(to.x, to.z).normalized())
		if dot > best:
			best = dot
			best_yaw = k * TAU / 72.0
	for dy in range(-6, 7):
		me.set("_yaw", best_yaw + dy * 0.02)
		for k in 30:
			me.set("_pitch", -1.0 + k * 0.05)
			await _frames(1)
			var h := landing.get("_harpoon") as Node3D
			if landing.aimed_at(h.global_position, -h.global_basis.z, 1.0) == i:
				return true
	return false


## Throws the harpoon you're holding off over the water away from anything, full, and waits for it to come down.
func _throw_into_water() -> void:
	var me := sea.crew.me
	var landing := sea.landing
	var at := landing.fish_point(landing.fish.keys()[0])
	var cam := me.get("cam") as Node3D
	# (the other way from the fish, and down at the water close by)
	var away := cam.global_position - at
	me.set("_pitch", -0.9)
	var best := -2.0
	var best_yaw := 0.0
	for k in 36:
		me.set("_yaw", k * TAU / 36.0)
		await _frames(1)
		var d := -cam.global_basis.z
		var dot := Vector2(d.x, d.z).normalized().dot(Vector2(away.x, away.z).normalized())
		if dot > best:
			best = dot
			best_yaw = k * TAU / 36.0
	me.set("_yaw", best_yaw)
	await _frames(1)
	landing.throw(0.3)
	var t := 0.0
	while not (landing.get("_flight") as Dictionary).is_empty() and t < 4.0:
		await _frames(1)
		t += 1.0 / 30.0
	await _frames(2)


func _press(down: bool) -> void:
	var e := InputEventAction.new()
	e.action = "use_primary"
	e.pressed = down
	Input.parse_input_event(e)
	if down:
		Input.action_press("use_primary")
	else:
		Input.action_release("use_primary")


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
		_watch()


func _settle(s: float) -> void:
	await _frames(ceili(s * 30.0))


## Keeps the biggest one-frame step the harpoon (in her frame: she's moving on the swell) and every fish alongside
## (likewise) have taken.
func _watch() -> void:
	var boat := sea.boat as Node3D
	var inv := boat.global_transform.affine_inverse()
	var now := {"harpoon": inv * (sea.landing.get("_harpoon") as Node3D).global_position}
	for i: int in sea.landing.fish:
		now["fish %d" % i] = inv * (sea.landing.fish[i]["node"] as Node3D).global_position
	for k: String in now:
		if _was.has(k):
			var step := (now[k] as Vector3).distance_to(_was[k])
			# (a flying harpoon covers ground fast: count it against its own speed)
			var allow := 0.7 if k == "harpoon" and not (sea.landing.get("_flight") as Dictionary).is_empty() else 0.0
			if step - allow > _jump:
				_jump = step - allow
				_jump_what = k
	_was = now


func _watch_reset() -> void:
	_was = {}
	_jump = 0.0
	_jump_what = ""


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("HARPOON TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
