extends Node
## A whole day's fishing, estimated headless, for one aboard, two and four (tests/trip_test.gd plays one real trip in
## a window; this one plays many, quickly, to see what a day's worth). Each day is the real day (boat/fish_hold.gd's
## DAY) less the dock and the runs out and home; in it the crew hunt (flocks turn up SPAWN m off, tuna/schools.gd; one
## in BAIT_ONLY is just gulls; down between spells; you know what one's on inside the spotter's read range, crew/
## spotter.gd: from the deck, or from the tower with someone up it), troll a pass across a school's head, and hook up.
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
## The day out there (s): the dock prep and the runs out to the grounds and home, off it.
const DOCK := 90.0
const RUN_OUT := 120.0
const RUN_HOME := 120.0
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
## Boatside (wiring, the harpoon, the haul through the tuna door: s, alone .. with hands to spare), the deck work
## (spike, bleed, ice: s), baiting each rod back up and sending it out (s a rod).
const BOATSIDE := [55.0, 30.0, 18.0]
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
		_spent = {"hunt": 0.0, "pass": 0.0, "fight": 0.0, "after": 0.0, "hookups": 0}
		for d in days:
			var day := _day(n, kind)
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
		print("TRIP   $%.0f a day sold, $%.0f a day to the boat after shares and fuel ($%.0f a 3-day payment period)"
				% [dollars / days, net, net * FishHold.DAYS])
		var hk := maxf(float(_spent["hookups"]), 1.0)
		print("TRIP   a hookup: %.0f s hunting, %.0f s on the pass, %.0f s fighting, %.0f s boatside, on deck and baiting up; %.1f hookups a day"
				% [float(_spent["hunt"]) / hk, float(_spent["pass"]) / hk, float(_spent["fight"]) / hk, float(_spent["after"]) / hk,
				hk / days])
	get_tree().quit()


## One day: {fish, lost, doubles, kg}.
func _day(n: int, kind: String) -> Dictionary:
	var spec: Dictionary = Kinds.spec(kind)
	var rods := (spec["rods"] as Array).size()
	# alone, a sensible skipper trolls what he can tend: the skiff's two
	var baits := rods if n >= 2 else mini(rods, 2)
	var room := int(spec["hold"]) + 1
	var speed := float(spec["ahead"])
	var tower := spec.has("tower") and n >= 2
	var hands := 0 if n == 1 else 1           # (the ones not on the fish's rod, for the lines and the second fish)
	if n >= 4:
		hands = 2
	var k := mini(n - 1, 2)                    # (0 alone, 1 two aboard, 2 four)
	var left := FishHold.DAY - DOCK - RUN_OUT - RUN_HOME
	var out := {"fish": 0, "lost": 0, "doubles": 0, "kg": 0.0, "dollars": 0.0}
	# (what a fish fetches: handled well, bled and iced; a crew gets it on ice quicker)
	var q := QUALITY_ALONE if n == 1 else QUALITY_CREW
	var since_pump := 0.0
	while left > 0.0 and int(out["fish"]) < room:
		# the hunt
		var hunt := _hunt(speed, tower)
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
		var kg := _school_kg()
		# a second one while the lines are still out
		var others := maxf((baits - 1) * 0.5, 0.0)
		var first := CLEAR_FIRST.x if n == 1 else CLEAR_FIRST.y
		var every := (CLEAR_EVERY.x if n == 1 else CLEAR_EVERY.y) / maxf(hands, 1.0)
		var exposed := first + every * maxf(baits - 2, 0.0) * 0.5
		var double := baits > 1 and _rng.randf() < 1.0 - exp(-BITE * Schools.DOUBLE * others * exposed)
		var a := _fight(kg * _rng.randf_range(0.8, 1.2), n, 0.0)
		var t := float(a[1])
		var landed := 1 if a[0] == "boatside" else 0
		var lost := 1 - landed
		var kgs := float(a[2]) * landed
		var paid := float(FishHold.price(float(a[2]), q)) * landed
		if double:
			out["doubles"] = int(out["doubles"]) + 1
			# the second fish: on its drag in its holder till someone's free for it (alone: till the first's done)
			var wait := t if n == 1 else (minf(t, 60.0) if n == 2 else 12.0)
			var b := _fight(kg * _rng.randf_range(0.8, 1.2), 1 if n <= 2 else 2, wait)
			t = maxf(t, float(b[1])) if n >= 4 else (t + maxf(float(b[1]) - wait, 0.0) if n == 1 else maxf(t, float(b[1])))
			if b[0] == "boatside":
				landed += 1
				kgs += float(b[2])
				paid += float(FishHold.price(float(b[2]), q))
			else:
				lost += 1
		var after: float = landed * (BOATSIDE[k] + DECK[k]) + baits * BAIT_UP / float(maxi(n, 1))
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


## s to find a flock with bluefin feeding under it and run her to it.
func _hunt(speed: float, tower: bool) -> float:
	var read := TOWER_READ if tower else Spotter.READ
	var t := 0.0
	for tries in 6:
		# the nearest flock out there of FLOCKS (a new one each try: they come and go)
		var d := 1e9
		for i in FLOCKS:
			d = minf(d, _rng.randf_range(Schools.SPAWN.x, Schools.SPAWN.y))
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


## The schools' weights (tuna/schools.gd's _host_start).
func _school_kg() -> float:
	return _rng.randf_range(60.0, 330.0) if _rng.randf() < 0.85 else _rng.randf_range(330.0, 400.0)


## A fight played out: [how it ended, s, kg]. `n`: hands on it (1: alone with the holder); `wait`: s it spends on its
## drag in its holder first (the second fish of a double).
func _fight(kg: float, n: int, wait: float) -> Array:
	kg = clampf(kg, 30.0, 400.0)
	var f := Fight.new(kg, 45.0, 1.0, _rng.randi_range(1, 1 << 30))
	var end := ["timeout", 0.0, kg]
	f.lost.connect(func(why: String) -> void: end[0] = why)
	f.boatside.connect(func() -> void: end[0] = "boatside")
	var t := 0.0
	var mem := {}
	var boat := {}
	f.in_holder = wait > 0.0
	while not f.done and t < 1500.0:
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
