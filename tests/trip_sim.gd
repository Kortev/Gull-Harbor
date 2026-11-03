extends Node
## A whole day's fishing, estimated headless, for one aboard, two and four (tests/trip_test.gd plays one real trip in
## a window; this one plays many, quickly, to see what a day's worth). Each day is the real day (boat/fish_hold.gd's
## DAY) less the dock and the runs out and home; in it the crew hunt (flocks turn up SPAWN m off, tuna/schools.gd; one
## in BAIT_ONLY is just gulls; down between spells; you know what one's on inside the spotter's read range, crew/
## spotter.gd: from the deck, or from the tower with someone up it), troll a pass across a school's head, and hook up.
## The weather turns through the day (sea/weather.gd: a 300 s spell at a time, wandering from fair to foul; sea/sea.gd's
## CONDITIONS: how big the sea, how far you can see). In a big sea a small open boat is thrown about so a line with a fish on is snatched and dropped (her stern's heave,
## measured in the game, x her "lively": tuna/fight.gd's heave) and fills with the seas over her rail (boat/
## green_water.gd), so in heavy weather and storms the skiff's skipper runs for shelter and waits it out; the
## sportfisher fishes on. Her tank's range (kinds' "tank") keeps the skiff inshore; the
## sportfisher can run out to the shelf edge (tuna/schools.gd's OFFSHORE: more schools, nearer, giants) if that's the
## better day (the skipper picks: both plans are run, the better one counts).
## Every fight is played out for real (tuna/fight.gd, tests/fight_bot.gd's good angler, alone with the rod holder or
## with a crew); a second bait in the school goes at DOUBLE the rate while one's on, till the other lines are in (a
## double header: the second fish waits in its holder on the drag till someone's free for it); then boatside, the fish
## worked on deck and iced, the baits back out (a mackerel each, from the well), and the well pumped now and then.
## What's estimated rather than played (the hunt, boatside, the deck work, baiting up) is in the constants below, from
## the game's own numbers where it has them. Prints fish a day for each crew; checks nothing.
## Run: godot --headless --fixed-fps 30 --path . res://tests/trip_sim.tscn (after --: --days=N)

const Fight := preload("res://tuna/fight.gd")
const Bot := preload("res://tests/fight_bot.gd")
const Schools := preload("res://tuna/schools.gd")
const Spotter := preload("res://crew/spotter.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Kinds := preload("res://boat/kinds.gd")
const DT := 1.0 / 30.0
## The day out there (s): the dock prep; the run out to the grounds inshore (m: out of the harbour and in-close), and
## on out from there to the shelf edge (m).
const DOCK := 90.0
const RUN_DIST := 1300.0
const EDGE_RUN := 1800.0
## The weather's spell (s), and the share of the wander each kind starts at (sea/weather.gd), and each kind's sea and
## how far you can see (sea/sea.gd's CONDITIONS).
const SPELL := 300.0
const KINDS := ["sunny", "calm", "fog", "rain", "heavy", "storm"]
const FROM := [0.0, 0.26, 0.42, 0.52, 0.66, 0.8]
const SEAS := [0.25, 0.12, 0.08, 0.5, 0.75, 1.0]
const SEEING := [4500.0, 2600.0, 200.0, 1300.0, 800.0, 450.0]
## The sea throwing a line with a fish on about in each (m/s, rods.gd's heave at the line, her "lively" and all, as
## tests/boats_test measures it in the game: the skiff rides every sea, the sportfisher's long heavy hull bridges them),
## every HEAVE_T s.
const HEAVE := {"skiff": [0.12, 0.1, 0.08, 0.18, 0.27, 0.38], "sportfisher": [0.03, 0.03, 0.02, 0.04, 0.06, 0.04]}
const HEAVE_T := 7.0
## Of a spell of heavy weather, how much the skiff spends in shelter (a storm: all of it).
const HEAVY_IN := 0.85
## The hunt: flocks out there at once, a pass set up across a school's head (s), a spell down waited out (s, the share
## of spells that are down), the read from the tower (Spotter's read range up there, m).
const FLOCKS := 4
const PASS := 35.0
const DOWN_WAIT := 25.0
const DOWN := 0.22
const TOWER_READ := 1800.0
## The bite on a pass: a second's odds for a bait across a school's head (schools.gd: 0.3 x how keen x the bait), and
## how many of the spread's baits are in among it then.
const BITE := 0.3 * 0.7 * 0.85
## Winding the other lines in after a hookup: the first one in (s), each after (s), per pair of hands free for it.
const CLEAR_FIRST := Vector2(8.0, 4.0)
const CLEAR_EVERY := Vector2(6.0, 4.0)
## Boatside (s, alone .. with hands to spare): the skiff's low gunwale, the harpoon and over it; the sportfisher's high
## transom, the leader wired before the stick and the haul through the tuna door (alone: the rod back in its holder,
## the fish kicking off on it, wire, stick, haul, and now and then he's off at the side: SIDE_LOST). The deck work
## (spike, bleed, ice: s), baiting each rod back up and sending it out (s a rod).
const BOATSIDE := {"skiff": [45.0, 28.0, 18.0], "sportfisher": [100.0, 32.0, 18.0]}
const SIDE_LOST := 0.15
## From the rods to the wheel and back (s, alone): the skiff's console a step forward of them, the sportfisher's helm
## up forward in her house.
const WALK := {"skiff": 1.8, "sportfisher": 3.4}
const DECK := [45.0, 25.0, 12.0]
const BAIT_UP := 12.0
## The well: a stroke of the pump every so often (boat/fish_hold.gd's WELL_STALE), s of pumping each time.
const PUMP_S := 5.0
## A fish's quality at the sale (tuna/handling.gd: 1 perfect), handled alone and by a crew.
const QUALITY_ALONE := 0.7
const QUALITY_CREW := 0.8

var _rng := RandomNumberGenerator.new()
## Where the day went, over every day of a crew: s hunting, s fighting, s boatside, on deck and baiting up; hookups.
var _spent := {}


func _ready() -> void:
	var days := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.substr(7))
	_rng.seed = 4242
	# one, two and four aboard, each boat
	for setup: Array in [[1, "skiff"], [2, "skiff"], [4, "skiff"], [1, "sportfisher"], [2, "sportfisher"],
			[4, "sportfisher"]]:
		var n := int(setup[0])
		var kind := str(setup[1])
		var fish := 0
		var lost := 0
		var doubles := 0
		var kg := 0.0
		var dollars := 0.0
		var edge_days := 0
		_spent = {"hunt": 0.0, "pass": 0.0, "fight": 0.0, "after": 0.0, "hookups": 0, "sheltered": 0.0}
		var seed0 := _rng.seed
		for d in days:
			# the day's weather, the same for every boat and crew (its wander's level, and each spell's)
			var w := RandomNumberGenerator.new()
			w.seed = 1000 + d
			var level := w.randf()
			var spells: Array[int] = []
			for i in int(ceil(FishHold.DAY / SPELL)) + 1:
				var u := clampf(level + w.randf_range(-0.12, 0.12), 0.0, 0.999)
				var k := 0
				for j in KINDS.size():
					if u >= float(FROM[j]):
						k = j
				spells.append(k)
			# inshore, or (her range allowing) out to the shelf edge: the better day of the two
			var spent0 := _spent.duplicate()
			_rng.seed = seed0 + d * 7919
			var day := _day(n, kind, spells, false)
			if float(Kinds.spec(kind).get("tank", 0.0)) * float(Kinds.spec(kind)["ahead"]) > 2.0 * (RUN_DIST + EDGE_RUN) * 1.3:
				var spent1 := _spent.duplicate()
				_spent = spent0.duplicate()
				_rng.seed = seed0 + d * 7919
				var edge := _day(n, kind, spells, true)
				if float(edge["dollars"]) > float(day["dollars"]):
					day = edge
					edge_days += 1
				else:
					_spent = spent1
			fish += int(day["fish"])
			lost += int(day["lost"])
			doubles += int(day["doubles"])
			kg += float(day["kg"])
			dollars += float(day["dollars"])
		var shares := maxi(n - 2, 0) * FishHold.SHARE
		var fuel := float(Kinds.spec(kind)["fuel"])
		var net := dollars / days * (1.0 - shares) - fuel
		print("TRIP %d aboard (%s): %.2f fish a day (%d landed, %d lost, %d double headers over %d days), %.0f kg a fish, %.0f%% kept after shares"
				% [n, kind, float(fish) / days, fish, lost, doubles, days, kg / maxf(fish, 1.0), 100.0 * (1.0 - shares)])
		print("TRIP   $%.0f a day sold, $%.0f a day to the boat after shares and fuel ($%.0f a 3-day payment period); out to the edge %d days of %d; %.0f s a day sheltering"
				% [dollars / days, net, net * FishHold.DAYS, edge_days, days, float(_spent["sheltered"]) / days])
		var hk := maxf(float(_spent["hookups"]), 1.0)
		print("TRIP   a hookup: %.0f s hunting, %.0f s on the pass, %.0f s fighting, %.0f s boatside, on deck and baiting up; %.1f hookups a day"
				% [float(_spent["hunt"]) / hk, float(_spent["pass"]) / hk, float(_spent["fight"]) / hk, float(_spent["after"]) / hk,
				hk / days])
	get_tree().quit()


## One day: {fish, lost, doubles, kg, dollars}. `spells`: the weather's kind for each SPELL of it; `edge`: out to the
## shelf edge.
func _day(n: int, kind: String, spells: Array[int], edge: bool) -> Dictionary:
	var spec: Dictionary = Kinds.spec(kind)
	var rods := (spec["rods"] as Array).size()
	# alone, a sensible skipper trolls what he can tend: the skiff's two
	var baits := rods if n >= 2 else mini(rods, 2)
	var room := int(spec["hold"]) + 1
	var tower := spec.has("tower") and n >= 2
	var small := float(spec.get("swamp", 0.0)) > 0.05          # (an open boat that fills in a blow)
	var hands := 0 if n == 1 else 1           # (the ones not on the fish's rod, for the lines and the second fish)
	if n >= 4:
		hands = 2
	var k := mini(n - 1, 2)                    # (0 alone, 1 two aboard, 2 four)
	var out := {"fish": 0, "lost": 0, "doubles": 0, "kg": 0.0, "dollars": 0.0}
	# (the day's clock: the dock, then the run out at her speed in the morning's sea)
	var clock := DOCK
	var run := RUN_DIST + (EDGE_RUN if edge else 0.0)
	clock += run / _speed(spec, spells, clock)
	var home := run / _speed(spec, spells, FishHold.DAY * 0.85)
	var tank := float(spec.get("tank", 900.0)) - 2.0 * run / float(spec["ahead"])      # (flat-out s left for the hunting)
	var left := FishHold.DAY - clock - home
	# (what a fish fetches: handled well, bled and iced; a crew gets it on ice quicker)
	var q := QUALITY_ALONE if n == 1 else QUALITY_CREW
	var since_pump := 0.0
	while left > 0.0 and int(out["fish"]) < room:
		clock = FishHold.DAY - home - left
		var sp: int = spells[mini(int(clock / SPELL), spells.size() - 1)]
		var into := fmod(clock, SPELL)
		if small and (KINDS[sp] == "storm" or (KINDS[sp] == "heavy" and into < SPELL * HEAVY_IN)):
			# (the skiff in a blow: every sea over her low rail filling her, heavy and slow: in under the land and wait it
			# out; in heavy weather, a good part of it, till she's bailed and it eases)
			var wait := (SPELL if KINDS[sp] == "storm" else SPELL * HEAVY_IN) - into
			left -= wait
			_spent["sheltered"] = float(_spent["sheltered"]) + wait
			continue
		# the hunt
		var speed := _speed(spec, spells, clock)
		var hunt := _hunt(speed, tower, edge, float(SEEING[sp]))
		tank -= hunt * speed / float(spec["ahead"])
		if tank < 0.0:
			break         # (her tank says home)
		left -= hunt
		since_pump += hunt
		if left <= 0.0:
			break
		# the pass, and the bite
		var in_zone := maxf(baits * 0.6, 1.0)
		var bite_t := -log(maxf(_rng.randf(), 1e-6)) / (BITE * in_zone)
		left -= PASS + bite_t
		if left <= 0.0:
			break
		_spent["hunt"] = float(_spent["hunt"]) + hunt
		_spent["pass"] = float(_spent["pass"]) + PASS + bite_t
		_spent["hookups"] = int(_spent["hookups"]) + 1
		var kg := _school_kg(edge)
		var heave: float = float(HEAVE[kind][sp])
		# a second one while the lines are still out
		var others := maxf((baits - 1) * 0.5, 0.0)
		var first := CLEAR_FIRST.x if n == 1 else CLEAR_FIRST.y
		var every := (CLEAR_EVERY.x if n == 1 else CLEAR_EVERY.y) / maxf(hands, 1.0)
		var exposed := first + every * maxf(baits - 2, 0.0) * 0.5
		var double := baits > 1 and _rng.randf() < 1.0 - exp(-BITE * Schools.DOUBLE * others * exposed)
		var a := _fight(kg * _rng.randf_range(0.8, 1.2), n, 0.0, heave, kind)
		var t := float(a[1])
		var landed := 1 if a[0] == "boatside" and not _side_lost(n, spec) else 0
		var lost := 1 - landed
		var kgs := float(a[2]) * landed
		var paid := float(FishHold.price(float(a[2]), q)) * landed
		if double:
			out["doubles"] = int(out["doubles"]) + 1
			# the second fish: on its drag in its holder till someone's free for it (alone: till the first's done)
			var wait := t if n == 1 else (minf(t, 60.0) if n == 2 else 12.0)
			var b := _fight(kg * _rng.randf_range(0.8, 1.2), 1 if n <= 2 else 2, wait, heave, kind)
			t = maxf(t, float(b[1])) if n >= 4 else (t + maxf(float(b[1]) - wait, 0.0) if n == 1 else maxf(t, float(b[1])))
			if b[0] == "boatside" and not _side_lost(n, spec):
				landed += 1
				kgs += float(b[2])
				paid += float(FishHold.price(float(b[2]), q))
			else:
				lost += 1
		var after: float = landed * (float(BOATSIDE[kind][k]) + DECK[k]) + baits * BAIT_UP / float(maxi(n, 1))
		left -= t + after
		_spent["fight"] = float(_spent["fight"]) + t
		_spent["after"] = float(_spent["after"]) + after
		since_pump += t
		if left < -FishHold.DAY * 0.25:
			break         # (still on him long after dusk: cut loose, home with what's aboard)
		if left < 0.0:
			paid *= 0.5   # (landed after dusk: towed in late, the cannery's half price)
		out["fish"] = int(out["fish"]) + landed
		out["lost"] = int(out["lost"]) + lost
		out["kg"] = float(out["kg"]) + kgs
		out["dollars"] = float(out["dollars"]) + paid
		while since_pump > FishHold.WELL_STALE:
			since_pump -= FishHold.WELL_STALE
			left -= PUMP_S / float(maxi(n, 1)) if n == 1 else 0.0       # (a crew pumps it in the quiet stretches)
	return out


## Her speed at the clock's time (boat/helm.gd's top_speed: flat out, dry).
func _speed(spec: Dictionary, _spells: Array[int], _clock: float) -> float:
	return float(spec["ahead"])


## s to find a flock with bluefin feeding under it and run her to it, at `speed`, as far as you can see (`seeing`).
func _hunt(speed: float, tower: bool, edge: bool, seeing: float) -> float:
	var read := minf(TOWER_READ if tower else Spotter.READ, seeing * 0.9)
	var ring: Vector2 = Schools.EDGE_SPAWN if edge else Schools.SPAWN
	if seeing < ring.y:
		ring = Vector2(maxf(0.35 * seeing, 150.0), maxf(0.8 * seeing, 220.0))     # (only what can be seen)
	var t := 0.0
	for tries in 6:
		# the nearest flock out there (a new one each try: they come and go)
		var d := 1e9
		for i in (Schools.EDGE_SCHOOLS if edge else FLOCKS):
			d = minf(d, _rng.randf_range(ring.x, ring.y))
		var tuna := _rng.randf() >= Schools.BAIT_ONLY
		if tower and not tuna:
			# (the spotter reads it from up there before she goes: on to the next, if it's in range)
			if d <= read:
				t += 10.0
				continue
		# run till you can tell what it's on, then the rest of the way if it's worth it
		t += maxf(d - read, 0.0) / speed
		if not tuna:
			continue
		t += minf(d, read) / speed
		if _rng.randf() < DOWN:
			t += DOWN_WAIT
		return t
	return t


## Alone at the sportfisher's high transom, the fish wired and stuck single-handed: now and then he's off at the side.
func _side_lost(n: int, spec: Dictionary) -> bool:
	return n == 1 and bool(spec.get("wire", false)) and _rng.randf() < SIDE_LOST


## The schools' weights (tuna/schools.gd's _host_start; the shelf edge's giants).
func _school_kg(edge: bool) -> float:
	if edge:
		return _rng.randf_range(Schools.EDGE_KG.x, Schools.EDGE_KG.y)
	return _rng.randf_range(60.0, 330.0) if _rng.randf() < 0.85 else _rng.randf_range(330.0, 400.0)


## A fight played out: [how it ended, s, kg]. `n`: hands on it (1: alone with the holder); `wait`: s it spends on its
## drag in its holder first (the second fish of a double); `heave`: the sea throwing her about (m/s, every HEAVE_T s).
func _fight(kg: float, n: int, wait: float, heave := 0.0, kind := "sportfisher") -> Array:
	kg = clampf(kg, 30.0, 400.0)
	var f := Fight.new(kg, 45.0, 1.0, _rng.randi_range(1, 1 << 30))
	var end := ["timeout", 0.0, kg]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var mem := {}
	var boat := {"walk_s": float(WALK[kind]), "turn": float(Kinds.spec(kind)["turn"])}
	f.back_speed = float(Kinds.spec(kind)["astern"])         # (backing down on him: her screws)
	f.in_holder = wait > 0.0
	while not f.done and t < 1500.0:
		f.heave = heave * sin(TAU * t / HEAVE_T)
		if f.in_holder and t >= wait and wait > 0.0:
			f.in_holder = false
			f.carry_on(f.move, f.stretch, f.turn_sign(), f.hold)
			wait = 0.0
		if f.in_holder and wait > 0.0:
			f.step(DT, 0.0, 0.6, 0.0, f.drag)
		else:
			var act := Bot.act(f.cues(), DT, "good", mem)
			Bot.crew(f, DT, n, boat)
			f.step(DT, float(act["crank"]), float(act["pitch"]), float(act["side"]), float(act["drag"]))
		t += DT
	end[1] = t
	return end
