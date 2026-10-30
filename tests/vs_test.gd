extends Node
## VS (vs/vs.gd): two boats on one sea, a crew each, racing for the same birds. The skipper turns it on at the dock and
## there's a second boat with her own rods, landing and fish hold; cross to her and she's the sea's boat (your camera,
## your screens, the sea round her). Head out and both go from the harbour, side by side, in the same kind of boat. A fish on one boat's rod
## is hers alone, and her things keep their notes off the other crew's screens. Schools turn up round one, the other
## and between. Head in and both come in: the pounds aboard are weighed, and the winner's told by how much. Back to
## one boat and it's the sea as it always was.
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
	# head out: both go, apart, the same kind
	sea.fish_hold.call("head_out", "sportfisher")
	await get_tree().create_timer(0.3).timeout
	var a_hold: Node = a.get("fish_hold")
	var a_rods: Node = a.get("rods")
	var b_hold: Node = b.get("fish_hold")
	_check(not bool(a_hold.get("docked")) and not bool(b_hold.get("docked")), "one heads out, both do")
	_check(str(a_boat.get("kind")) == "sportfisher" and str(b_boat.get("kind")) == "sportfisher",
			"in the same kind of boat")
	var gap := a_boat.global_position.distance_to(b_boat.global_position)
	_check(gap > Vs.APART * 1.5, "they set out apart (%.0f m)" % gap)
	for boat: Node3D in [a_boat, b_boat]:
		var at: Vector2 = boat.get("helm").get("at")
		_check(at.y > sea.landmarks.shore_z(at.x) - 300.0 and not sea.landmarks.blocked(at),
				"from the harbour, afloat (%.0f, %.0f)" % [at.x, at.y])
	_check(me.boat == b_boat and me.global_position.distance_to(b_boat.global_position) < 12.0,
			"you're on B's deck, where she is")
	# a fish on B's rod is B's
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
	var tally := vs.get("_tally") as Label
	_check(tally.visible and tally.text.contains("You  243 lb") and tally.text.contains("Them  220 lb"),
			"the tally: yours and theirs (%s)" % tally.text.replace("\n", " / "))
	# head in: both in, weighed
	sea.fish_hold.call("head_in")
	await get_tree().create_timer(0.3).timeout
	_check(bool(a_hold.get("docked")) and bool(b_hold.get("docked")), "one heads in, both do")
	_check(vs.result.size() == 2 and roundi(vs.result[0]) == 220 and roundi(vs.result[1]) == 243,
			"weighed: A %s lb, B %s lb" % vs.result.map(func(x: float) -> int: return roundi(x)) if vs.result.size() == 2
			else "weighed")
	var verdict := vs.get("_verdict") as Label
	_check(verdict.visible and verdict.text.begins_with("You won by 23 lb"), "the result: %s"
			% verdict.text.replace("\n", " / "))
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


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("VS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
