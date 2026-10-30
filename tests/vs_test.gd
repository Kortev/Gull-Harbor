extends Node
## VS (vs/vs.gd): two boats on one sea, a crew each, racing for the same birds. The skipper turns it on at the dock and
## there's a second boat with her own rods, landing and fish hold; cross to her and she's the sea's boat (your camera,
## your screens, the sea round her). Head out and both go from the harbour, side by side, in the same kind of boat. A fish on one boat's rod
## is hers alone, and her things keep their notes off the other crew's screens. Schools turn up round one, the other
## and between. Out there they meet (_meet): solid to each other, wakes (a wake bomb beam on, softer bow into it),
## lines cut across a stern, the air horn; boarding her (_board: over both rails alongside, up her ladder). Head in
## and both come in alongside the fish pier: the fish read off, the pounds weighed, the winner told by how much, a day to them. Back to one boat and it's the sea as it always was.
## Run: godot --headless --fixed-fps 30 --path . res://tests/vs_test.tscn

const Sea := preload("res://sea/sea.gd")
const Vs := preload("res://vs/vs.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var vs := sea.vs
	var a_boat := sea.boat
	vs.host_set_on(true)
	await get_tree().process_frame
	_check(vs.on and vs.sides.size() == 2, "two boats")
	var a: Node = vs.sides[0]
	var b: Node = vs.sides[1]
	var b_boat := b.get("boat") as Node3D
	_check(b_boat != a_boat and b_boat.is_inside_tree() and b.get("fish_hold") != a.get("fish_hold")
			and b.get("rods") != a.get("rods"), "boat B has her own boat, rods and fish hold")
	_check(sea.crew.me.boat == a_boat and sea.boat == a_boat, "the skipper starts on boat A")
	# cross to B: she's the sea's boat now
	vs.ask_team(1)
	await get_tree().process_frame
	var me := sea.crew.me
	_check(me != null and me.boat == b_boat, "crossed to boat B, aboard her")
	_check(sea.boat == b_boat and sea.fish_hold == b.get("fish_hold") and sea.ocean.follow == b_boat,
			"B is the sea's boat for you (the sea under her, her fish hold)")
	_check(a.get("crew").get("me") == null and b.get("crew") == sea.crew, "A's things don't see you aboard; B's do")
	# at the dock the countdown runs; its end lets both go together (here the skipper's let go early, in the boat
	# the test wants)
	await get_tree().process_frame
	_check(vs.count_end > 0.0, "at the dock, the countdown to casting off runs (%.0f s)" % (vs.count_end - vs._now()))
	_check(absf(vs.run_out(0) - vs.run_out(1)) < 1.0, "the same run to the harbour mouth from both berths (A %.0f m, B %.0f m)"
			% [vs.run_out(0), vs.run_out(1)])
	var held_helm: Node = a_boat.get("helm")
	_check(bool(held_helm.call("held")), "and her engines won't turn over till GO")
	sea.fish_hold.call("head_out", "sportfisher")
	await get_tree().create_timer(0.3).timeout
	var a_hold: Node = a.get("fish_hold")
	var a_rods: Node = a.get("rods")
	var b_hold: Node = b.get("fish_hold")
	_check(not bool(a_hold.get("docked")) and not bool(b_hold.get("docked")), "one heads out, both do")
	_check(str(a_boat.get("kind")) == "sportfisher" and str(b_boat.get("kind")) == "sportfisher",
			"in the same kind of boat")
	var ax := (a_boat.get("helm").get("at") as Vector2).x
	var bx := (b_boat.get("helm").get("at") as Vector2).x
	_check(ax < sea.harbour.PIER_X and bx > sea.harbour.PIER_X,
			"they set out from their own berths, either side of the fish pier (%.0f, %.0f)" % [ax, bx])
	for boat: Node3D in [a_boat, b_boat]:
		var at: Vector2 = boat.get("helm").get("at")
		_check(at.y > sea.landmarks.shore_z(at.x) - 300.0 and not sea.landmarks.blocked(at),
				"from the harbour, afloat (%.0f, %.0f)" % [at.x, at.y])
	_check(me.boat == b_boat and me.global_position.distance_to(b_boat.global_position) < 12.0,
			"you're on B's deck, where she is")
	# a fish on B's rod is B's
	(b.get("rods") as Node).call("host_cast", 0)       # (the crew cast it out: tests/cast_test.tscn)
	(b.get("rods") as Node).call("strike", 0, 150.0)
	await get_tree().create_timer(0.2).timeout
	var b_on := ((b.get("rods") as Node).get("rods") as Array).any(func(r: Node) -> bool: return bool(r.get("hooked")))
	var a_on := ((a.get("rods") as Node).get("rods") as Array).any(func(r: Node) -> bool: return bool(r.get("hooked")))
	_check(b_on and not a_on, "a strike on B's rod is B's alone")
	# the other boat's notes stay off your screen
	(a_hold as Node).call("_note", "VS TEST NOTE")
	var note := sea.crew.hud.get("_note") as Label
	_check(note.text != "VS TEST NOTE", "A's notes don't show on B's screens")
	# the schools turn up round A, round B and between
	var anchors: Array = [vs.spawn_anchor(), vs.spawn_anchor(), vs.spawn_anchor()]
	var pa: Vector2 = a_boat.get("helm").get("at")
	var pb: Vector2 = b_boat.get("helm").get("at")
	var near := func(p: Vector2, q: Vector2) -> bool: return p.distance_to(q) < 1.0
	_check(anchors.any(func(p: Vector2) -> bool: return near.call(p, pa))
			and anchors.any(func(p: Vector2) -> bool: return near.call(p, pb))
			and anchors.any(func(p: Vector2) -> bool: return near.call(p, (pa + pb) * 0.5)),
			"schools turn up round A, round B and between them")
	sea.schools.call("_host_start")
	_check(sea.schools.schools.size() > 0, "and they do turn up")
	# the catch: A lands 100 kg, B 60 + 50
	a_hold.call("host_add", 100.0, 60.0)
	b_hold.call("host_add", 60.0, 60.0)
	b_hold.call("host_add", 50.0, 60.0)
	await get_tree().create_timer(0.2).timeout
	_check((vs.get("_race") as Control).visible and vs.shown == [243, 220],
			"the tally, top left: yours and theirs (%s)" % [vs.shown])
	await _meet(sea, vs, b, a_boat, b_boat)
	await _board(sea, a_boat, b_boat)
	# home: both in alongside the fish pier (the race home run for them), weighed a fish at a time
	vs.host_bring_home()
	await get_tree().create_timer(0.3).timeout
	_check(bool(a_hold.get("docked")) and bool(b_hold.get("docked")), "both home, tied up")
	_check(vs.result.size() == 2 and roundi(vs.result[0]) == 220 and roundi(vs.result[1]) == 243,
			"weighed: A %s lb, B %s lb" % vs.result.map(func(x: float) -> int: return roundi(x)) if vs.result.size() == 2
			else "weighed")
	var pier := Vector2(sea.harbour.PIER_X, sea.landmarks.shore_z(sea.harbour.PIER_X))
	var pa_in: Vector2 = a_boat.get("helm").get("at")
	var pb_in: Vector2 = b_boat.get("helm").get("at")
	_check(pa_in.distance_to(pier) < 80.0 and pb_in.distance_to(pier) < 80.0 and pa_in.x < pier.x and pb_in.x > pier.x,
			"in alongside the fish pier, either side of it")
	var verdict := vs.get("_verdict") as Label
	_check(vs.weighing and not verdict.visible, "the fish read off first, the verdict after")
	await get_tree().create_timer(2.6).timeout
	var a_col := (vs.get("_board") as Node).get_node_or_null("Boat0")
	_check(a_col != null and a_col.get_node("Fish").get_child_count() >= 1, "A's fish going up on the board")
	while vs.weighing:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.1).timeout
	var b_col := (vs.get("_board") as Node).get_node_or_null("Boat1")
	_check(b_col != null and b_col.get_node("Fish").get_child_count() == 2
			and (b_col.get_node("Sum") as Label).text == "243 lb", "B's two read off, 243 lb")
	_check(verdict.visible and verdict.text.begins_with("You won by 23 lb"), "the result: %s"
			% verdict.text.replace("\n", " / "))
	_check(vs.wins == [0, 1], "a day to B (%s)" % [vs.wins])
	# A's crew would read it the other way round
	vs.ask_team(0)
	await get_tree().create_timer(0.2).timeout
	_check(verdict.text.begins_with("They won by 23 lb"), "on A: %s" % verdict.text.replace("\n", " / "))
	_check(sea.crew.me.boat == a_boat and sea.boat == a_boat, "crossed back to A")
	# back to one boat
	vs.host_set_on(false)
	await get_tree().create_timer(0.2).timeout
	_check(not vs.on and vs.sides.is_empty() and not is_instance_valid(b_boat), "back to one boat (B's gone)")
	_check(sea.boat == a_boat and sea.crew.me.boat == a_boat and a_hold.get("sea") == sea
			and a_rods.get("sea") == sea, "and the sea's as it always was")
	_done()


## Out there, the two boats meeting: solid to each other (a bump shoves both apart, nobody passes through), a wake
## rocks the other, running across her lines cuts them, and her horn rattles the other crew.
## (Nobody's at either wheel: the host moves both, so the test sets their way on.)
func _meet(sea: Sea, vs: Vs, b: Node, a_boat: Node3D, b_boat: Node3D) -> void:
	var ha: Node = a_boat.get("helm")
	var hb: Node = b_boat.get("helm")
	var b_rods: Node = b.get("rods")
	b_rods.call("host_clear")
	# B lying still, A coming at her beam at 5 m/s
	var at := Vector2(300.0, -600.0)
	hb.set("at", at)
	hb.set("heading", 0.0)
	hb.set("speed", 0.0)
	ha.set("at", at + Vector2(-20.0, 0.0))
	ha.set("heading", -PI * 0.5)       # (bow to +x)
	var closest := INF
	for i in 150:
		if i < 20:
			ha.set("speed", 5.0)
		await get_tree().process_frame
		var c := Vs.Contact.contact(a_boat, b_boat, 1.0)
		if not c.is_empty():
			closest = minf(closest, float(c["gap"]))
	var moved_b := (hb.get("at") as Vector2).distance_to(at)
	_check(closest < 1.0 and closest > -0.6, "they meet, and don't pass through (overlap at most %.2f m)" % -closest)
	_check(moved_b > 1.0, "the bump shoved B off (%.1f m)" % moved_b)
	_check((ha.get("at") as Vector2).x < at.x - 3.0, "A's still on her own side (%.1f m short)"
			% (at.x - (ha.get("at") as Vector2).x))
	_check(float(vs.contact.get("_thud_t")) > -INF, "a thud")
	_check((vs.contact.get("_rock_v") as Array).all(func(v: Vector2) -> bool: return v != Vector2.ZERO)
			or ((b_boat.get("rock") as Vector2) != Vector2.ZERO and (a_boat.get("rock") as Vector2) != Vector2.ZERO),
			"both knocked over")
	# A runs past B at 9 m/s, 20 m off: her wake comes to B
	for h: Node in [ha, hb]:
		h.set("speed", 0.0)
		h.set("drift", Vector2.ZERO)
		h.set("spin", 0.0)
	hb.set("at", at)
	hb.set("heading", 0.0)
	ha.set("at", at + Vector2(-60.0, 20.0))
	ha.set("heading", -PI * 0.5)
	var slapped := false
	for i in 30 * 16:
		ha.set("speed", 9.0)
		hb.set("speed", 0.0)
		await get_tree().process_frame
		slapped = slapped or bool((vs.contact.get("_in_arm") as Array)[1])
	_check(slapped, "A's wake comes to B and rocks her")
	# the wake bomb: A ploughing past at 6 m/s, close, B beam on to it; then again with B's bow into it
	_check(Vs.Contact.wake_power(6.0) > Vs.Contact.wake_power(10.0) * 1.5,
			"the biggest wake's ploughing along, not flat out (%.2f to %.2f)"
			% [Vs.Contact.wake_power(6.0), Vs.Contact.wake_power(10.0)])
	for bow_in: bool in [false, true]:
		await get_tree().create_timer(4.0).timeout
		var before := int(vs.contact.bombs[1])
		var most := 0.0
		hb.set("at", at)
		hb.set("heading", PI * 0.5 if bow_in else 0.0)      # (bow to -x, into it; or along A's way, beam on)
		ha.set("at", at + Vector2(-15.0, 60.0))
		ha.set("heading", 0.0)
		for i in 30 * 18:
			ha.set("speed", 6.0)
			hb.set("speed", 0.0)
			hb.set("at", at)
			await get_tree().process_frame
			most = maxf(most, (b_boat.get("rock") as Vector2).length())
		ha.set("speed", 0.0)
		var bombed := int(vs.contact.bombs[1]) > before
		if bow_in:
			_check(not bombed and most < 0.06, "her bow into it, she takes it softer (%.3f rad)" % most)
		else:
			_check(bombed and most > 0.06, "beam on, it buries her: a hard roll (%.3f rad), the sea in over her transom"
					% most)
	# B's baits out astern, and A runs across her stern through her lines
	ha.set("speed", 0.0)
	ha.set("at", at + Vector2(-150.0, 0.0))
	hb.set("at", at)
	hb.set("heading", 0.0)
	for i in (b_rods.get("rods") as Array).size():
		b_rods.call("_baited", i, float(sea.ocean.wave_time), false)
		b_rods.call("host_cast", i)
	await get_tree().create_timer(3.0).timeout
	var out := (b_rods.get("rods") as Array).filter(func(r: Node) -> bool:
		return not bool(r.get("bait_in")) and bool(r.get("baited")))
	_check(out.size() >= 2, "B's baits out astern (%d)" % out.size())
	ha.set("at", at + Vector2(-45.0, 25.0))      # (25 m astern of her middle: across her lines)
	ha.set("heading", -PI * 0.5)
	for i in 30 * 10:
		ha.set("speed", 9.0)
		hb.set("speed", 0.0)
		hb.set("at", at)
		await get_tree().process_frame
	ha.set("speed", 0.0)
	var cut := (b_rods.get("rods") as Array).filter(func(r: Node) -> bool: return not bool(r.get("baited")))
	_check(cut.size() >= 2, "running across B's stern cut her lines (%d of %d)" % [cut.size(), out.size()])
	_check(float(a_boat.get("helm").get("fouled_until")) > 0.0, "and A's props took the line: her engines died a while")
	await get_tree().create_timer(10.0).timeout
	_check((b_rods.get("rods") as Array).all(func(r: Node) -> bool:
		return bool(r.get("bait_in")) or bool(r.get("baited"))), "what's left wound in")
	# the air horn: A's, 30 m off B with a fish on B's line
	hb.set("at", at)
	hb.set("heading", 0.0)
	ha.set("at", at + Vector2(-30.0, 0.0))
	b_rods.call("_baited", 0, float(sea.ocean.wave_time), false)
	b_rods.call("host_cast", 0)
	await get_tree().create_timer(2.5).timeout
	b_rods.call("strike", 0, 150.0)
	await get_tree().create_timer(1.0).timeout
	var rod: Node = (b_rods.get("rods") as Array)[0]
	var horn := a_boat.get_node_or_null("Horn")
	_check(horn != null and b_boat.get_node_or_null("Horn") != null, "a horn on each console")
	horn.call("interact", sea.crew.me)
	var fight: Object = rod.get("fight")
	_check(int(horn.get("blasts")) == 1 and float(rod.get("whip")) > 0.9 and fight != null
			and float(fight.get("shock")) >= 0.1, "A's horn: a blast, and B's fish jerked on the line")
	horn.call("interact", sea.crew.me)
	_check(int(horn.get("blasts")) == 1, "not again straight away")
	await get_tree().create_timer(0.1).timeout
	_check(float(sea.crew.me.get("shake")) > 0.3, "B's crew rattled (%.2f)" % float(sea.crew.me.get("shake")))
	await get_tree().create_timer(3.0).timeout
	_check(bool(rod.get("hooked")), "and the fish still on")
	b_rods.call("host_clear")


## Boarding her (crew/player.gd): A lying alongside B, you (B's crew) jump her rail and you're over both onto A's deck,
## riding her as she moves; her wheel isn't yours to take. In the sea, up her ladder: any boat's. Back to B the same
## way, over the rails.
func _board(sea: Sea, a_boat: Node3D, b_boat: Node3D) -> void:
	var ha: Node = a_boat.get("helm")
	var hb: Node = b_boat.get("helm")
	var at := Vector2(300.0, -600.0)
	for h: Node in [ha, hb]:
		h.set("speed", 0.0)
		h.set("drift", Vector2.ZERO)
		h.set("spin", 0.0)
		h.set("heading", 0.0)
	hb.set("at", at)
	ha.set("at", at + Vector2(float(b_boat.get("beam")) + 0.05, 0.0))     # (alongside, to B's starboard)
	await get_tree().create_timer(0.5).timeout
	var me := sea.crew.me
	me.force_input = true
	var deck := float(b_boat.get("deck"))
	me.place(Vector3(1.9, deck + 0.02, 3.5), -PI * 0.5)
	Input.action_press("move_forward")
	await get_tree().create_timer(0.4).timeout
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	var t := 0.0
	var step := 0.0
	var prev := me.global_position
	while me.boat != a_boat or int(me.get("mode")) != 0:
		await get_tree().process_frame
		step = maxf(step, me.global_position.distance_to(prev))
		prev = me.global_position
		t += 1.0 / 30.0
		if t > 3.0:
			break
	Input.action_release("move_forward")
	_check(me.boat == a_boat and int(me.get("mode")) == 0 and me.get("home") == b_boat,
			"over B's rail onto A's deck, still B's crew (%.1f s)" % t)
	_check(step < 0.25, "a hop, not a jump in where you are (at most %.2f m a frame)" % step)
	await get_tree().create_timer(0.5).timeout
	_check(me.body.is_on_floor(), "standing on A's deck")
	var on_a: Vector3 = a_boat.global_transform.affine_inverse() * me.global_position
	for i in 30:
		ha.set("at", (ha.get("at") as Vector2) + Vector2(0.0, -0.1))
		await get_tree().process_frame
	var still: Vector3 = a_boat.global_transform.affine_inverse() * me.global_position
	_check(Vector2(still.x - on_a.x, still.z - on_a.z).length() < 0.2, "and riding her as she moves")
	ha.call("request", true)
	await get_tree().process_frame
	_check(int(ha.get("captain")) == 0, "her wheel isn't B's crew's to take")
	# in the sea off A's stern: up her ladder
	var ladder: Node3D = a_boat.get("ladder")
	me.call("overboard", ladder.global_transform * Vector3(0.0, 0.0, 1.2), ladder.global_position)
	await get_tree().create_timer(1.0).timeout
	ladder.call("interact", me)
	me.set("force_climb", true)
	t = 0.0
	while int(me.get("mode")) != 0 and t < 6.0:
		await get_tree().process_frame
		t += 1.0 / 30.0
	me.set("force_climb", false)
	_check(me.boat == a_boat and int(me.get("mode")) == 0, "up A's ladder: any boat's (%.1f s)" % t)
	# home again: over A's rail onto B
	ha.set("at", at + Vector2(float(b_boat.get("beam")) + 0.05, 0.0))
	await get_tree().create_timer(0.3).timeout
	me.place(Vector3(-1.9, deck + 0.02, 3.5), PI * 0.5)
	Input.action_press("move_forward")
	await get_tree().create_timer(0.4).timeout
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	t = 0.0
	while (me.boat != b_boat or int(me.get("mode")) != 0) and t < 3.0:
		await get_tree().process_frame
		t += 1.0 / 30.0
	Input.action_release("move_forward")
	me.force_input = false
	_check(me.boat == b_boat and int(me.get("mode")) == 0, "and back over the rails to B")


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("VS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
