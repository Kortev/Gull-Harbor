extends Node
## The harbour on foot and by hand (sea/quay.gd, boat/lines.gd, sea/places.gd, sea/tow.gd), headless: the sportfisher
## lying on her lines at her berth; you sprint and jump over her rail onto the float, walk the float, up the gangway,
## along the pier to the broker's board and use it, and back down the gangway to a boarding step and a jump aboard.
## Her lines let go, she drifts off; thrown and made fast again, she's hauled in on them and tied up, the trip over
## and nothing sold. Two fish hoisted out of her box by the crank onto the buyer's scale, graded, priced and sold a
## fish at a time. The dock prep: the pump fills her tank, a scoop of ice into her box, a tote of mackerel into her
## well. Late, out in the harbour: the launch comes out, takes her in alongside and ties her up, the cannery's half.
## And nothing teleports the whole way: her, or you.
## Run: godot --headless --fixed-fps 30 --path . res://tests/harbour_walk_test.tscn

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")
const Lines := preload("res://boat/lines.gd")
const Quay := preload("res://sea/quay.gd")

## Most she or you may move in a frame (m): her way at the launch's tow, your sprint, a fall.
const STEP := 0.45

var fails: Array[String] = []
var sea: Sea
var _track := false
var _was := Vector2.INF
var _jump := 0.0
var _pwas := Vector3.INF
var _pjump := 0.0


func _ready() -> void:
	Settings.prep["career"] = "full"
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	sea.lines_rule = true
	await _run()
	_done()


func _process(_delta: float) -> void:
	if not _track or sea == null:
		return
	var at: Vector2 = sea.boat.helm.at
	if _was != Vector2.INF:
		_jump = maxf(_jump, at.distance_to(_was))
	_was = at
	var me: Node3D = sea.crew.me
	if me != null:
		var p := me.global_position
		if _pwas != Vector3.INF:
			_pjump = maxf(_pjump, p.distance_to(_pwas))
		_pwas = p


func _run() -> void:
	var boat := sea.boat
	var helm := boat.helm
	var q: Quay = sea.harbour.quay
	var lines: Lines = boat.get("lines")
	var hold := sea.fish_hold
	var px: float = sea.harbour.PIER_X
	var face: float = q.face()
	# her berth, her lines made fast where she lies (the game's start: sea.gd's moor)
	helm.at = sea.harbour.berth(boat.beam * 0.5, boat.length)
	helm.heading = 0.0
	await get_tree().process_frame
	boat.global_transform = boat.pose()
	lines.host_make_fast_here()
	await get_tree().create_timer(1.5).timeout
	_check(lines.tied() and hold.docked, "at her berth on her lines, tied up")
	var me: Player = sea.crew.me
	me.force_input = true
	_track = true
	# ashore: a walk at her starboard rail (the float's side) and a jump, up on it, and a step off it onto the float
	me.place(Vector3(0.2, boat.deck + 0.02, 2.0), -PI * 0.5, boat)
	await get_tree().create_timer(0.3).timeout
	_pwas = Vector3.INF
	_pjump = 0.0
	Input.action_press("move_forward")
	var t := 0.0
	var last_x := -INF
	while not (me.boat == q and me.mode == Player.DECK and me.body.is_on_floor()) and t < 5.0:
		# (at her side: up against her liner, going no further)
		if me.mode == Player.DECK and me.boat == boat:
			var x := me.local_position().x
			if t > 0.4 and x <= last_x + 0.01:
				Input.action_press("jump")
			elif x > last_x + 0.05:
				Input.action_release("jump")
			last_x = maxf(last_x, x)
		if OS.get_cmdline_user_args().has("--trace"):
			print("  %.2f %s %s frame=%s at=%s local=%s" % [t, ["deck", "sea", "ladder", "air"][me.mode], me.boat.name,
					me.frame.name if me.frame else "world", me.global_position, me.get("_local")])
		await get_tree().process_frame
		t += 1.0 / 30.0
	Input.action_release("jump")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await get_tree().create_timer(0.3).timeout
	_check(me.boat == q and me.mode == Player.DECK, "over her rail and down on the float (%s, %s)" % [me.boat.name,
			["deck", "sea", "ladder", "air"][me.mode]])
	_check(absf(me.global_position.y - Quay.FLOAT_Y) < 0.2, "on the float's deck (y %.2f)" % me.global_position.y)
	# along the float, up the gangway, along the pier, onto the quay, to the broker's board
	var gx: float = (q.gangways[0][0] as Vector3).x
	var foot: Vector3 = q.gangways[0][0]
	var top: Vector3 = q.gangways[0][1]
	var board: Vector3 = (sea.places.counters["BROKER"] as Dictionary)["at"]
	var root := Vector3(px, 0, face + 3.0)
	await _walk(me, [Vector3(gx, 0, foot.z - 1.5), Vector3(gx, 0, top.z), Vector3(px, 0, top.z), root,
			Vector3(board.x, 0, board.z - 0.3)])
	_check(absf(me.global_position.y - sea.harbour.QUAY_Y) < 0.25 and Vector2(me.global_position.x - board.x,
			me.global_position.z - board.z + 0.3).length() < 0.8, "up the gangway, along the pier, on the quay at the "
			+ "board (%s)" % me.global_position)
	sea.places.open("BROKER")
	_check(sea.places.serving(), "the broker's board: its card")
	sea.places.close()
	_check(not sea.places.serving(), "and walked off it")
	# back down to the float, to the boarding step abeam her cockpit, and a jump aboard
	var step := _step_near(q, boat)
	var outer := step.x - 0.4
	await _walk(me, [root, Vector3(px, 0, face - 1.0), Vector3(px, 0, top.z), Vector3(gx, 0, top.z),
			Vector3(gx, 0, foot.z - 1.0), Vector3(outer + 1.3, 0, step.z)])
	_check(me.boat == q and me.mode == Player.DECK and absf(me.global_position.y - Quay.FLOAT_Y) < 0.2,
			"back along the pier and down the gangway onto the float (%s)" % me.global_position)
	me.set("_yaw", PI * 0.5)       # (facing west, at her)
	Input.action_press("move_forward")
	t = 0.0
	while not (me.boat == boat and me.mode == Player.DECK and me.body.is_on_floor()) and me.mode != Player.SWIM and t < 4.0:
		if me.boat == q and me.global_position.x < outer + 0.35:
			Input.action_press("jump")
		if OS.get_cmdline_user_args().has("--trace"):
			print("  b %.2f %s %s frame=%s at=%s outer=%.2f" % [t, ["deck", "sea", "ladder", "air"][me.mode], me.boat.name,
					me.frame.name if me.frame else "world", me.global_position, outer])
		await get_tree().process_frame
		t += 1.0 / 30.0
	Input.action_release("jump")
	Input.action_release("move_forward")
	await get_tree().create_timer(0.3).timeout
	_check(me.boat == boat and me.mode == Player.DECK, "up the boarding step and a jump aboard her (%s, %s)" % [
			me.boat.name, ["deck", "sea", "ladder", "air"][me.mode]])
	_check(_pjump < STEP, "you never jumped anywhere, walking ashore and back (%.2f m a frame at most)" % _pjump)
	# her lines let go: aboard, the trip starts once she's off (here: the host says), she drifts off the float
	_jump = 0.0
	lines.request(0, "let_go")
	lines.request(1, "let_go")
	await _until(func() -> bool: return lines.all_aboard(), 6.0)
	_check(lines.all_aboard(), "both lines let go and back aboard")
	hold.head_out()
	helm.drift = Vector2(-1.4, 0.0)
	await get_tree().create_timer(2.5).timeout
	var off := _off(q, boat)
	_check(off > 0.8, "she's drifted off the float (%.1f m)" % off)
	# thrown and made fast again: hauled in on them, she's tied up and the trip's over, the catch still aboard
	hold.host_add(120.0, 60.0)
	hold.host_add(80.0, 50.0)
	for f: Dictionary in hold.fish:
		f["iced_s"] = 1.0
		f["packed"] = 1.0
	hold.call("_host_changed")
	lines.request(0, "throw", 1.0)
	lines.request(1, "throw", 1.0)
	await get_tree().create_timer(0.3).timeout
	_check(int(lines.lines[0][0]) == Lines.OUT and int(lines.lines[1][0]) == Lines.OUT, "both lines thrown over the float's cleats")
	var bank := hold.bank
	lines.request(0, "make_fast")
	lines.request(1, "make_fast")
	await get_tree().create_timer(0.5).timeout
	for k in 8:
		lines.request(0, "haul")
		lines.request(1, "haul")
		await get_tree().create_timer(0.4).timeout
	await get_tree().create_timer(4.0).timeout
	_check(lines.tied() and hold.docked, "made fast: tied up, the trip's over")
	_check(hold.fish.size() == 2 and (hold.sale.get("lines", []) as Array).is_empty(), "and nothing sold by tying up")
	off = _off(q, boat)
	_check(off < 0.9, "hauled in alongside the float on her lines (%.2f m off it)" % off)
	_check(_jump < STEP, "she rode in on her lines, nothing put anywhere (%.3f m a frame at most)" % _jump)
	# selling: the crank on the hoist, each fish up out of her box onto the scale, graded and sold
	hold.call("_ask_lid", true)
	t = 0.0
	var seen_hung := false
	while (hold.sale.get("lines", []) as Array).size() < 2 and t < 60.0:
		sea.places.host_crank()
		seen_hung = seen_hung or sea.places.h_grade >= 0.0
		await get_tree().process_frame
		t += 1.0 / 30.0
	var sold: Array = hold.sale.get("lines", [])
	_check(sold.size() == 2, "both fish cranked up onto the scale and sold (%d, %.0f s)" % [sold.size(), t])
	_check(seen_hung, "each hung on the scale while the buyer graded it")
	_check(hold.fish.is_empty() and hold.bank > bank, "out of her, the money in the bank ($%d)" % (hold.bank - bank))
	if sold.size() == 2:
		_check(str(sold[0][1]).begins_with("#") and (sold[0][3] as Array).size() > 0, "graded with why (%s %s)" % [
				sold[0][1], sold[0][3]])
	_check(bool(hold.sale.get("settled", false)), "the last one sold, the day's done")
	# the dock prep: the pump, a scoop of ice, a tote of mackerel
	var f0 := hold.fuel
	var b0 := hold.bank
	for k in 60:
		sea.places.call("_ask_fill", 1.0 / 30.0)
		await get_tree().process_frame
	_check(hold.fuel > f0 + 0.05 and hold.bank < b0, "the pump: her tank filling (%.2f > %.2f), paid as it runs" % [
			hold.fuel, f0])
	var i0 := hold.ice
	hold.call("_ask_lid", true)
	await get_tree().create_timer(0.5).timeout
	me.hands.set("scoop_ice", true)
	hold.call("_scoop_ice", me, "scoop", true)
	_check(hold.ice == i0 + 1, "a scoop of ice off the bin into her box (%d)" % hold.ice)
	var w0 := hold.well
	sea.places.call("_ask_tote", true)
	_check(sea.places.carrying(me), "a tote of mackerel in your arms off the bait shop's counter")
	(boat.live_well.get("_act") as Node).call("interact", me)
	_check(hold.well == mini(w0 + hold.TOTE, hold.WELL_MAX) and not sea.places.carrying(me),
			"tipped into her live well (%d)" % hold.well)
	# late: out in the harbour, the launch comes out for her and brings her in, ties her up; nothing jumps
	lines.request(0, "let_go")
	lines.request(1, "let_go")
	await _until(func() -> bool: return lines.all_aboard(), 6.0)
	hold.head_out()
	_track = false
	helm.at = sea.harbour.berth(boat.beam * 0.5, boat.length) + Vector2(-50.0, -120.0)
	await get_tree().create_timer(0.5).timeout
	_was = Vector2.INF
	_jump = 0.0
	_track = true
	sea.send_tow(boat)
	t = 0.0
	var under_tow := false
	while not hold.docked and t < 240.0:
		under_tow = under_tow or helm.towed_by != null
		await get_tree().process_frame
		t += 1.0 / 30.0
	_check(under_tow, "the launch came out and took her in tow")
	_check(hold.docked and lines.tied(), "brought in alongside, her lines made fast for her (%.0f s)" % t)
	_check(bool(hold.sale.get("late", false)), "late: the cannery's price")
	_check(_jump < STEP, "towed in the whole way, nothing put anywhere (%.3f m a frame at most)" % _jump)
	await get_tree().create_timer(1.0).timeout
	_check(helm.towed_by == null, "and the launch let her go")


## Waits (frames) till `ok` says so, or `secs` (game time) have gone.
func _until(ok: Callable, secs: float) -> void:
	var t := 0.0
	while not bool(ok.call()) and t < secs:
		await get_tree().process_frame
		t += 1.0 / 30.0


## Walks you through `points` (world x, z), one after the other, facing each.
func _walk(me: Player, points: Array) -> void:
	for p: Vector3 in points:
		var t := 0.0
		Input.action_press("move_forward")
		while t < 20.0:
			var d := Vector2(p.x - me.global_position.x, p.z - me.global_position.z)
			if d.length() < 0.35:
				break
			me.set("_yaw", atan2(-d.x, -d.y))
			await get_tree().process_frame
			t += 1.0 / 30.0
		Input.action_release("move_forward")
		await get_tree().create_timer(0.2).timeout


## The boarding step on the float nearest her cockpit (aft of her cabin).
func _step_near(q: Quay, boat: Node3D) -> Vector3:
	var best := Vector3.ZERO
	var d := INF
	var cockpit := boat.to_global(Vector3(0.0, 0.0, boat.length * 0.25))
	for s: Vector3 in q.steps:
		var e := Vector2(s.x - cockpit.x, s.z - cockpit.z).length()
		if e < d:
			d = e
			best = s
	return best


## How far her side is off the float's edge (m).
func _off(q: Quay, boat: Node3D) -> float:
	var fl: Array = q.float_near(Vector2(boat.global_position.x + boat.beam * 0.5, boat.global_position.z), 30.0)
	if fl.is_empty():
		return INF
	return (float(fl[1]) - (boat.global_position.x + boat.beam * 0.5)) * -float(fl[2])


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("HARBOUR WALK TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
