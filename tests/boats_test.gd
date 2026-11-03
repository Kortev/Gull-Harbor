extends Node
## What the bigger boat's for, in the world itself (boat/kinds.gd): the sportfisher's quicker on a run; the skiff's small
## tank won't take her out to the shelf edge and back (fish_hold's burn, her "tank"); out past the edge (tuna/schools.gd's
## OFFSHORE) schools turn up oftener, nearer, and they're giants; and in a big sea the skiff's thrown about so a line
## with a fish on is snatched (rods.gd's heave, x her "lively"), where the sportfisher's hull rides through it; and the
## seas coming over the skiff's low rail fill her (boat/green_water.gd's water), the sportfisher's cockpit bails itself.
## Run: godot --headless --fixed-fps 30 --path . res://tests/boats_test.tscn

const Sea := preload("res://sea/sea.gd")
const Kinds := preload("res://boat/kinds.gd")
const Schools := preload("res://tuna/schools.gd")

var fails: Array[String] = []
var _sea: Node
var _wall := 0.0


## (the sea's clock is the wall clock, but headless at a fixed 30 fps the frames run as fast as they can: the waves
## held to the game's pace, so the boat's heave per frame is what it would be playing, however fast this machine is)
func _process(delta: float) -> void:
	var wall := Time.get_ticks_msec() / 1000.0
	if _wall > 0.0 and _sea != null:
		var o: Node = _sea.get("ocean")
		o.set("clock_offset", float(o.get("clock_offset")) - ((wall - _wall) - delta))
	_wall = wall


func _ready() -> void:
	var skiff: Dictionary = Kinds.spec("skiff")
	var sport: Dictionary = Kinds.spec("sportfisher")
	_check(float(sport["ahead"]) > float(skiff["ahead"]) * 1.15, "flat out the sportfisher's quicker (%.1f against %.1f m/s)"
			% [sport["ahead"], skiff["ahead"]])
	# her range: out to the shelf edge and back flat out
	var there := 2.0 * (1300.0 + 2500.0)
	_check(float(skiff["tank"]) * float(skiff["ahead"]) < there and float(sport["tank"]) * float(sport["ahead"]) > there * 2.0,
			"the skiff's tank won't take her out to the edge and back (%.0f m flat out, %.0f there and back); the sportfisher's, twice over (%.0f)"
			% [float(skiff["tank"]) * float(skiff["ahead"]), there, float(sport["tank"]) * float(sport["ahead"])])
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	_sea = sea
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var hold := sea.fish_hold
	hold.owned = ["skiff", "sportfisher"]
	var tops := {}
	for kind: String in ["skiff", "sportfisher"]:
		hold.head_in()
		await get_tree().process_frame
		hold.head_out(kind)
		await get_tree().process_frame
		var helm: Node = sea.boat.helm
		sea.set_condition("sunny")
		await get_tree().create_timer(2.0).timeout
		var fair := float(helm.call("top_speed"))
		sea.set_condition("storm")
		await get_tree().create_timer(3.0).timeout
		var storm := float(helm.call("top_speed"))
		tops[kind] = [fair, storm]
		# the tank: an hour's flat out burns it all
		hold.prep = "full"
		hold.fuel = 1.0
		hold.burn(1.0, float(Kinds.spec(kind)["tank"]) * 0.5)
		_check(absf(hold.fuel - 0.5) < 0.02, "%s: half her tank's flat-out time burns half of it (%.2f left)" % [kind, hold.fuel])
		hold.fuel = 1.0
	# the shelf edge: out past it, more schools, nearer, and giants
	var shore := float(sea.landmarks.call("shore_z", 0.0))
	sea.boat.helm.set("at", Vector2(0.0, shore - Schools.OFFSHORE - 500.0))
	_check(bool(sea.schools.call("offshore")), "out past the shelf edge: offshore")
	var kgs: Array[float] = []
	var far: Array[float] = []
	for i in 12:
		sea.schools.call("_host_start")
		var s: Node = sea.schools.schools.back()
		kgs.append(float(s.get("kg")))
		far.append((s.call("center", sea.schools.now()) as Vector2).distance_to(sea.boat.helm.get("at")))
	_check(kgs.min() >= Schools.EDGE_KG.x and far.max() < Schools.EDGE_SPAWN.y + 60.0,
			"out there they're giants (%.0f..%.0f kg), and turn up near (%.0f m at most)" % [kgs.min(), kgs.max(), far.max()])
	sea.boat.helm.set("at", Vector2(0.0, shore - 1500.0))
	_check(not bool(sea.schools.call("offshore")), "inshore: not")
	# a big sea through a line with a fish on: the skiff's thrown about, the sportfisher rides it
	var heaves := {}
	var wet := {}
	for kind: String in ["skiff", "sportfisher"]:
		hold.head_in()
		await get_tree().process_frame
		hold.head_out(kind)
		# (out on the open sea, not in the harbour's shelter: she floats, boat/buoyancy.gd, and the swell's full size)
		await get_tree().process_frame
		sea.boat.helm.set("at", Vector2(0.0, -900.0))
		for cond: String in ["sunny", "rain", "heavy", "storm"]:
			sea.set_condition(cond)
			await get_tree().create_timer(6.0).timeout
			var vs: Array[float] = []
			for f in 450:
				await get_tree().process_frame
				vs.append(absf(float(sea.rods.get("heave"))))
			vs.sort()
			print("HEAVE %s %s: median %.2f, 90%% %.2f m/s at the line; %d seas aboard, water in her %.2f"
					% [kind, cond, vs[225], vs[405], int(sea.boat.green.bursts), float(sea.boat.green.water)])
			heaves[kind] = vs[405]
		# five seas over her rail in a blow: what's left in her, and her top speed with it
		var green: Node = sea.boat.green
		var top0 := float(sea.boat.helm.call("top_speed"))
		for k in 5:
			green.call("_aboard", (sea.boat.spec["rail"] as Array)[1], 0.3)
		wet[kind] = [float(green.get("water")), top0, float(sea.boat.helm.call("top_speed"))]
		green.set("water", 0.0)
	_check(float(heaves["skiff"]) > 0.25 and float(heaves["sportfisher"]) < float(heaves["skiff"]) * 0.4,
			"in a storm the sea snatches the skiff's line (%.2f m/s), the sportfisher's hardly (%.2f)"
			% [heaves["skiff"], heaves["sportfisher"]])
	_check(float(wet["skiff"][0]) > 0.3 and float(wet["sportfisher"][0]) < 0.1 and float(wet["skiff"][2]) < float(wet["skiff"][1]) * 0.85,
			"five seas over her rail: the skiff's half full (%.2f) and slow (%.1f -> %.1f m/s); the sportfisher bails herself (%.2f)"
			% [wet["skiff"][0], wet["skiff"][1], wet["skiff"][2], wet["sportfisher"][0]])
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("BOATS TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
