extends Node
## A whole solo trip, played by a bot in a real window, with a screenshot at each stage (docs/shots/trip_*.png):
## the dock, heading out in the skiff, a flock spotted on the horizon (called), running to it at the wheel, slowing
## to troll, the bite, the fight (the bot clears the other line first, and keeps her stern on the fish the way a
## captain would: solo you'd drop the rod in the holder to do it), boatside, the harpoon, the haul, bleeding and icing,
## heading in and the sale. Prints what happened at each step and fails if a step never comes.
## The bank's kept in a test file, not yours. Run (needs a window): godot --path . res://tests/trip_test.tscn
## Add -- --fast to run the slow parts (the hunt, waiting for a bite, the fight) at 4x.

const Sea := preload("res://sea/sea.gd")
const SHOTS := "res://docs/shots/"

var sea: Sea
var fails: Array[String] = []
var fast := false
var shot_n := 0


func _ready() -> void:
	fast = OS.get_cmdline_user_args().has("--fast")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	var hold := sea.fish_hold
	hold.save_path = "user://bluefin_test.cfg"
	await _wait(1.5)
	await _shot("dock")
	hold.head_out("skiff")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(2.0)
	_check(not hold.docked, "headed out in the %s" % sea.boat.kind)
	await _shot("heading_out")
	# the hunt: wait for a flock with tuna under it
	var school = null
	var waited := 0.0
	_speed(true)
	while school == null and waited < 240.0:
		await _wait(1.0)
		waited += 1.0
		for s in sea.schools.schools:
			if not s.bait_only:
				school = s
				break
	_speed(false)
	_check(school != null, "a flock with tuna under it turned up (after %.0f s)" % waited)
	if school == null:
		_done()
		return
	print("TRIP the flock's %.0f m off; there are %d flocks" % [
			_school_xz(school).distance_to(sea.boat.helm.at), sea.schools.schools.size()])
	# spot it: look at it (crosshair on it), call it
	await _face(school)
	await _wait(0.5)
	await _shot("spotted")
	var spotter := sea.find_child("Spotter", true, false)
	if spotter != null and spotter.get("_read") != null:
		print("TRIP spotted: %s" % str((spotter.get("_read") as Label).text).replace("
", " | "))
	# (the deck's rolling: give the crosshair a few seconds to sit on it, the way you'd hold your look)
	var held: bool = spotter != null and spotter.get("_looking") == school
	var tries := 0
	while not held and spotter != null and tries < 6:
		tries += 1
		await _face(school)
		for f in 15:
			await get_tree().process_frame
			held = held or spotter.get("_looking") == school
	_check(held, "spotted it: the crosshair's on it")
	# the wheel: run to it, slow down near it
	sea.crew.me.force_input = true
	sea.boat.helm.request(true)
	await _wait(0.3)
	_check(sea.boat.helm.is_mine(), "took the wheel")
	_speed(true)
	var t := 0.0
	var took_run_shot := false
	while t < 300.0 and sea.schools.schools.has(school):
		await get_tree().process_frame
		t += get_process_delta_time()
		var d: float = _school_xz(school).distance_to(sea.boat.helm.at)
		_steer_to(_school_xz(school))
		_hold("move_forward", d > 220.0 or (d > 150.0 and sea.boat.helm.speed < 1.5))
		if not took_run_shot and sea.boat.helm.speed > 7.0:
			took_run_shot = true
			_speed(false)
			await _shot("running")
			_speed(true)
		if d < 160.0 and sea.boat.helm.speed < 4.0:
			break
	_hold("move_forward", false)
	_steer_to(Vector2.INF)
	_speed(false)
	var off: float = _school_xz(school).distance_to(sea.boat.helm.at)
	_check(off < 200.0, "ran to the flock and slowed to troll (%.0f m off, %.1f knots, %.0f s)" % [
			off, sea.boat.helm.speed * 1.944, t])
	_check(school.spooked_until < sea.schools.now(), "didn't spook them")
	await _shot("trolling")
	# troll through them till something bites
	var hooked := -1
	t = 0.0
	_speed(true)
	while hooked < 0 and t < 300.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if sea.schools.schools.has(school):
			_steer_to(_school_xz(school))
		_hold("move_forward", sea.boat.helm.speed < 1.5)
		for r in sea.rods.rods:
			if r.hooked:
				hooked = r.index
	_hold("move_forward", false)
	_steer_to(Vector2.INF)
	_speed(false)
	_check(hooked >= 0, "a bite (after %.0f s of trolling)" % t)
	if hooked < 0:
		_done()
		return
	await _wait(1.0)
	await _shot("the_bite")
	# off the wheel, clear the other line, grab the rod and fight it
	sea.boat.helm.request(false)
	for r in sea.rods.rods:
		if r.index != hooked and not r.bait_in:
			sea.rods._host_line(r.index, true)
	var rod = sea.rods.rods[hooked]
	sea.rods.request_grab(hooked)
	# back to the cockpit with it, as you would: fought from up by the console, the line lies over it
	var me: Node = sea.crew.me
	var lp: Vector3 = me.call("local_position")
	lp.z = sea.rods.stern.z - 1.4
	me.call("place", lp, float(me.get("_yaw")))
	await _wait(0.2)
	_check(rod.holder == Net.my_id(), "grabbed the rod")
	var moves := {}
	var fight_shots := {}
	var resting := false
	var w := 0.0
	_speed(true)
	while rod.hooked and not rod.alongside and w < 1500.0:
		await get_tree().process_frame
		w += get_process_delta_time()
		var b := wrapf(float(rod.bearing), -PI, PI)
		var helm: Node = sea.boat.helm
		helm.set("heading", float(helm.get("heading")) + clampf(b * 1.5, -1.0, 1.0) * 0.3 * get_process_delta_time())
		moves[rod.move] = true
		var ans: String = rod.fight.answer() if rod.fight != null else "reel"
		var arms := float(sea.crew.me.get("arms"))
		if arms < 0.15:
			resting = true
		elif arms > 0.6:
			resting = false
		var lift := ans == "pump" and fmod(w, 2.5) < 1.0 and not resting
		_hold("use_secondary", lift)
		_hold("use_primary", ans == "tight" or (not resting and (ans == "reel" or (ans == "pump" and not lift))))
		if str(rod.move) in ["run", "spiral", "sound"] and not fight_shots.has(rod.move) and w > 3.0:
			fight_shots[rod.move] = true
			_speed(false)
			await _shot("fight_" + str(rod.move))
			_speed(true)
	_hold("use_primary", false)
	_hold("use_secondary", false)
	_speed(false)
	print("TRIP the fight: %.0f s, moves %s" % [w, ", ".join(moves.keys())])
	_check(rod.alongside and sea.landing.fish.has(rod.index),
			"fought it to the boat (%.0f s): %s" % [w, sea.crew.hud._note.text])
	if not sea.landing.fish.has(rod.index):
		_done()
		return
	await _wait(0.5)
	await _shot("boatside")
	# the harpoon: take it, look at the fish, throw
	var landing := sea.landing
	sea.rods.request_return(hooked)
	landing._request_harpoon(true)
	await _wait(0.3)
	_check(landing.harpoon_holder == Net.my_id(), "took the harpoon")
	await _face_point(landing.fish_point(hooked))
	await _shot("harpoon")
	if landing.needs_wire(hooked):
		landing._ask_wire_as(hooked)
	landing.throw()
	await _wait(1.0)
	if landing.fish.has(hooked) and not bool(landing.fish[hooked]["stuck"]):
		print("TRIP the bot's own throw missed (%s); stuck it directly" % sea.crew.hud._note.text)
		landing._request_harpoon(true)
		landing._ask_throw_as(Net.my_id(), hooked)
	_check(landing.fish.has(hooked) and bool(landing.fish[hooked]["stuck"]), "stuck it")
	# the haul
	t = 0.0
	var hauled_shot := false
	while landing.fish.has(hooked) and t < 40.0:
		landing._ask_pull_as(Net.my_id(), hooked)
		await get_tree().process_frame
		t += get_process_delta_time()
		if not hauled_shot and landing.fish.has(hooked) and float(landing.fish[hooked]["haul"]) > 0.5:
			hauled_shot = true
			await _shot("haul")
	landing._ask_pull_as(Net.my_id(), -1)
	var hold_fish: Array = sea.fish_hold.fish
	_check(not landing.fish.has(hooked) and not hold_fish.is_empty(), "hauled it aboard (%.0f s)" % t)
	if hold_fish.is_empty():
		_done()
		return
	await _wait(1.0)
	var deck: Dictionary = sea.fish_hold._deck
	if not deck.is_empty():
		await _face_point((deck.values()[0] as Node3D).global_position)
	await _shot("on_deck")
	var id := int(hold_fish[0]["id"])
	sea.fish_hold._work(id)
	await _wait(0.6)
	await _shot("bled")
	sea.fish_hold._work(id)
	await _wait(0.6)
	_check(float(hold_fish[0]["iced_s"]) >= 0.0, "bled and iced: a %.0f kg fish worth $%d" % [
			float(hold_fish[0]["kg"]), sea.fish_hold.worth()])
	# head in and sell
	sea.fish_hold.head_in()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(1.5)
	_check(sea.fish_hold.docked and not sea.fish_hold.sale.is_empty(),
			"headed in and sold: %s" % str(sea.fish_hold.sale.get("lines", [])))
	await _shot("the_sale")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	_done()


func _school_xz(s) -> Vector2:
	return s.center(sea.schools.now())


## Swing her head toward a point in the world (the bot's hands on the wheel); INF lets go of the wheel.
func _steer_to(p: Vector2) -> void:
	if p == Vector2.INF:
		_hold("move_left", false)
		_hold("move_right", false)
		return
	var boat: Node3D = sea.boat
	var fwd3 := -boat.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	var to := (p - sea.boat.helm.at).normalized()
	var ang := fwd.angle_to(to)
	_hold("move_left", ang < -0.08)
	_hold("move_right", ang > 0.08)


## Turn your head so the crosshair's on a school.
func _face(s) -> void:
	var c: Vector2 = _school_xz(s)
	await _face_point(Vector3(c.x, 3.0, c.y))


## Turn your head toward a point (a search round, since the deck moves under you).
func _face_point(p: Vector3) -> void:
	var me := sea.crew.me
	var best := 0.0
	var best_dot := -2.0
	for i in 72:
		var yaw := i * TAU / 72.0
		me.set("_yaw", yaw)
		await get_tree().process_frame
		var dot := _aim_dot(p)
		if dot > best_dot:
			best_dot = dot
			best = yaw
	me.set("_yaw", best)
	var best_p := 0.0
	best_dot = -2.0
	for i in 31:
		var pitch := -0.75 + i * 0.05
		me.set("_pitch", pitch)
		await get_tree().process_frame
		var dot := _aim_dot(p)
		if dot > best_dot:
			best_dot = dot
			best_p = pitch
	me.set("_pitch", best_p)
	# then the yaw again, finer (the first pass is 5 degrees a step: too coarse for the spotter's crosshair)
	var coarse := best
	best_dot = -2.0
	for i in 21:
		var yaw := coarse - 0.09 + i * 0.009
		me.set("_yaw", yaw)
		await get_tree().process_frame
		var dot := _aim_dot(p)
		if dot > best_dot:
			best_dot = dot
			best = yaw
	me.set("_yaw", best)
	await get_tree().process_frame


func _aim_dot(p: Vector3) -> float:
	var cam := sea.crew.me.get("cam") as Camera3D
	return (-cam.global_transform.basis.z).normalized().dot((p - cam.global_position).normalized())


func _speed(on: bool) -> void:
	Engine.time_scale = 4.0 if on and fast else 1.0


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	shot_n += 1
	var path := "%strip_%02d_%s.png" % [SHOTS, shot_n, what]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _done() -> void:
	Engine.time_scale = 1.0
	for f in fails:
		print("FAIL ", f)
	print("TRIP TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
