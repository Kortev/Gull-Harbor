extends Node
## The trip and the catch: the dock, the day, the boat, the gear, fish on deck and in the hold, and what it's worth.
##
## A game starts at the dock (ui/menu.gd shows it): the bank, which boat (the skiff's yours; the sportfisher can be
## bought, or chartered for the day), gear for sale, and Head out. Out there the day runs from dawn (DAWN_H) to dusk
## (DUSK_H) in DAY seconds, then it's night. You bring her home yourself and tie her up alongside the float with her
## lines (boat/lines.gd): the trip's over, the fuel and any charter are taken off, and the catch is still aboard. Each
## fish is hoisted out of her onto the buyer's scale by hand (sea/places.gd's hoist) and sold there, one at a time.
##
## A fish hauled aboard (tuna/landing.gd) slides off the door onto the deck, alive, and you work it there with your
## own hands (tuna/handling.gd has the spots, the numbers and the grade): the knife's point into its brain (spike it:
## it shivers and goes still), the knife into the cut under its pectoral fin (bleed it: hold for the depth, then pump
## its tail with your bare hands to run it out), along its belly (gut it), a mate's bare hands pinning it down so it
## can't flop while you do; then the gaff, dragged across the deck (slow going with a big one) and let go over the
## open fish box (her kind's `box`, a hatch in her sole; E on its lid): it drops in, and the scoop on the open box
## packs ice over it. What you're on says itself under your sight; how it went shows in the fish (a shiver, a flop,
## the blood running, the ice heaping up). A live fish loose on deck thrashes its meat to mush, so the sooner and
## cleaner the better. The buyer pays by the kilo at its grade, #1, #2 or #3, with why on the slip (a line a fish, as
## each comes off the scale); one still on deck sells as it is, warm. The money goes in the bank as each is sold.
##
## Dock prep (core/settings.gd's prep, the host's for the mode: career "full", Rivals "off"): with it on, what she goes
## out with is what you put aboard: her tank (`fuel`, 0..1: the pump on the float, paid as it runs, burned as she runs:
## burn()), scoops of ice in her box (`ice`: the ice bin on the float, a scoop at a time) and live mackerel in her
## well (the bait shop's totes, carried aboard). Off, she's fuelled, iced and baited as she casts off.
##
## The career (the bank, the boats and gear, the run, the bests) is kept between games on the host's machine, in
## user://career.cfg (VERSION in it; missing, unreadable or from a newer game: a fresh start). Written after a sale,
## a purchase, a boat picked, casting off, and as the game closes or goes back to the title. A crewmate's own career
## is never touched by the host's (`_borrowed`), and Rivals (vs/vs.gd: set_career(false)) plays from an even fresh
## start that's never saved. Tests and screenshots (headless, a scene under tests/, a sea not at the root, --shot)
## never read or write it (`save_path` is "" there, unless a test sets it).
##
## The run (Lethal Company's quota): the crew owes the bank for the boat. Each quota is a sum to sell within DAYS
## trips (one a day). Every fish sold counts toward it and goes in the bank to spend at the dock. Make the quota by
## the last day's sale and there's a bigger one (quota_for); miss it and the bank takes the boat: the run's over,
## its story on the slip, and a new one starts from the skiff and START_CASH.
##
## The host keeps the books and tells everyone after every change (_sync).

const Tuna := preload("res://tuna/tuna.gd")
const Handling := preload("res://tuna/handling.gd")
const Action := preload("res://core/action.gd")
const Kinds := preload("res://boat/kinds.gd")
const Sfx := preload("res://audio/sfx.gd")
const Achievements := preload("res://core/achievements.gd")
const SAVE := "user://career.cfg"
## The bank's file before the career had a version (read once, if there's no career yet).
const OLD_SAVE := "user://bluefin.cfg"
const VERSION := 1
## Dollars a kilo for a fish of quality 1 is 0.35 + 0.9 = 1.25 times this; quality 0, 0.35 times.
const PRICE_PER_KG := 18.0
## The day out there: real seconds from dawn to dusk, and the hours they stand for.
const DAY := 1200.0
const DAWN_H := 5.5
const DUSK_H := 19.5
## A boat you don't own, for the day (taken off the sale).
const CHARTER := 2500
## The run: trips to make each quota in, and the money a new run starts with.
const DAYS := 3
const START_CASH := 1000
## Gear for sale at the dock, once each (tuna/fight.gd and tuna/schools.gd ask has_gear()).
const GEAR := {
	"reel": {"name": "A two-speed reel", "blurb": "Winds line in a quarter faster.", "price": 3000},
	"line": {"name": "Heavier line", "blurb": "Takes half as much again rubbing the hull, and holds a moment longer "
			+ "at full strain.", "price": 2000},
}
## Bait for the trip: live mackerel in the well (every boat has one: WELL_START in it each trip on top of one on every
## hook, WELL_MAX with what you jig; tuna take nothing else, rods.gd), and scoops of chum in the bucket (CHUM each
## trip: boat/chum.gd). The same for every boat and every crew, so a Rivals day starts even.
const WELL_START := 4
const WELL_MAX := 8
const CHUM := 24
## Dock prep: a tote of live mackerel (how many, what it costs), a scoop of ice (what it costs; how many her box
## takes for each fish it holds), a tank's burn (of a full tank, each second flat out).
const TOTE := 4
const TOTE_PRICE := 30
const ICE_PRICE := 4
const ICE_PER_FISH := 2
const BURN := 1.0 / 900.0
## Where fish lie on deck comes from the boat's kind (boat/kinds.gd's spots: x, y, z, and 1 across her or 0 along
## her), in turn; more than that and they're piled on top. Her fish box takes her kind's `hold` iced.

var sea: Node                 # sea/sea.gd
## This trip's fish: {id, kg, fight_s (hooked to aboard), aboard_t (sea clock), bled_s and iced_s (s after it came
## aboard; -1: not yet), spot, and its handling (tuna/handling.gd's fresh(): spiked_s, misses, thrash, cut_q, cut_d,
## cut_t, pumps, drain, gutted, packed, packed_s, pins); `land`: where it came over the side (boat-local).
var fish: Array = []
var bank := 0
var best := 0
## At the dock (between trips), when she headed out (sea clock), which boat she takes, the boats and gear you own.
var docked := true
var trip_t0 := 0.0
var kind := "skiff"
var owned: Array = ["skiff"]
var gear: Array = []
## The run: which quota (1, 2, ...), what it is, what's been sold toward it, which day of it this is (1..DAYS), the
## run's fish and its biggest, and the most quotas any run has made.
var quota_n := 1
var quota := 0
var earned := 0
var day := 1
var run_fish := 0
var run_biggest := 0.0
var best_run := 0
## This trip's live mackerel in the well, the dead ones on ice in the bait box beside it (a mackerel that died on the
## hook or was swung aboard with the well full: still bait, a poor one), and scoops of chum left.
var well := 0
var dead := 0
var chum := 0
## Her tank (0..1) and the scoops of ice in her box; the dock prep in force ("full", "quick", "off": the host's).
var fuel := 0.6
var ice := 0
var prep := "full"
var _dusk_noted := 0
## The last sale, shown till she heads back out: {lines: [[kg, grade, dollars]], total, bank, best}; empty: none.
var sale := {}
var _next_id := 1
var _deck := {}               # fish id -> its Tuna on deck
var _sold_noted := -1
var _met_noted := false
## In or out as this peer last saw it (the dock screen, the fade in): the host's head_in() and head_out() change
## `docked` before their word comes back round, so it's this, not `docked`, the word's checked against.
var _docked_seen := true
var _heard := {}              # fish id -> what was done to it last time (_hear_work)
## A cut no better than this can be cut again.
const RECUT := 0.7
## Your hands on a fish: what you're doing ("spike", "cut", "gut", "pin"; "" nothing), to which, for how long (s),
## where along it you went in, and whether it kicked while you were at it; the ring round your sight; since your last
## pump of a tail (s).
var _act := ""
var _act_id := -1
var _act_t := 0.0
var _act_u := 0.0
var _act_kicked := false
var _ring: Control
var _pump_t := 9.0
## Each fish on deck: when its next kick is (s); its blood running from the cut (GPUParticles3D).
var _kick_in := {}
var _streams := {}
## Host: who's pinning which fish down (peer -> id).
var _pins := {}
## The fish box's lid, open or shut (the host's word), as drawn (0 shut .. 1 open); and the fish being dragged on the
## gaff: yours (its id, -1 none) and everyone's, as their peers last said ({id: [at (boat-local), yaw]}).
var box_open := false
## The live well's lid, held open (E on it: boat/live_well.gd draws it; the host's word, like the box's).
var well_open := false
var _lid_k := 0.0
var _lid: Node3D
var _inside: Node3D
var _dragging := -1
var _drag_send := 0.0
var _dragged := {}
## The last game ended out at sea (quit, or the host dropped): that day's gone, settled as an empty trip (_ready).
var _abandoned := false
## Where the career's kept ("": nowhere, in tests and screenshots, unless a test points it somewhere).
var save_path := SAVE
## Off in Rivals (and on boat B's hold, set before _ready): an even fresh start, never saved.
var career := true
## The books are a host's we're crewing for (their _sync), not ours: never saved over ours.
var _borrowed := false
## Fish ids already looked at for achievements (core/achievements.gd: _achieve).
var _seen := {}


func _ready() -> void:
	if _testing():
		save_path = ""
	if career:
		_load()
	else:
		_new_run()
	(sea.get("boat") as Node).connect("rebuilt", func() -> void:
		# (another boat: lay what's on deck out again on her, and her fish box)
		for id: int in _deck.keys():
			(_deck[id] as Node).queue_free()
		_deck.clear()
		_dragging = -1
		_attach_box()
		_rebuild())
	_attach_box()
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, _state()))
	Net.peer_left.connect(func(id: int) -> void:
		if Net.is_host() and _pins.has(id):
			_pins.erase(id)       # (their hands come off the fish they were pinning)
			_count_pins()
			_host_changed())
	Net.dropped.connect(func(_reason: String) -> void: _own_boat())
	Net.left.connect(func(was_host: bool) -> void:
		if not was_host:
			_own_boat())
	_rebuild()
	if _abandoned and Net.is_host():
		# (no ducking a quota by quitting before the last day's sale: the day counts, the fuel's owed, nothing sold)
		_abandoned = false
		docked = false
		fish = []
		head_in()
		sale["abandoned"] = true
		_host_changed()

	_achieve_career()


## Back on your own boat after crewing for someone: your own bank and gear, an empty hold (theirs stays theirs),
## at the dock.
func _own_boat() -> void:
	_borrowed = false
	_load()
	fish = []
	_seen = {}
	sale = {}
	docked = true
	_docked_seen = true
	_rebuild()
	_dock_changed(true)
	(sea.get("boat") as Node).call("use_kind", kind)


func _process(delta: float) -> void:
	_drag(delta)
	_show_box(delta)
	_work_on(delta)
	_throes(delta)
	if Net.is_host() and not docked:
		_host_life(delta)
	if Net.is_host() and docked and not _borrowed:
		# (the host's dock prep for the game being played; only ever changed at the dock, never mid-trip)
		var real: Node = sea.get("sea") if sea.get("sea") != null else sea
		var vs: Node = real.get("vs")
		var want := Settings.prep_for("rivals" if vs != null and bool(vs.get("on")) else "career")
		if want != prep:
			prep = want
			_host_changed()
	# the light going: once at dusk, once at dark
	if docked:
		return
	var t := day_fraction()
	if t > 0.85 and _dusk_noted < 1:
		_dusk_noted = 1
		_note("Sun's going down")
	_tally()


# ------------------------------------------------------------------ the day

## How far through the day she is: 0 at dawn, 1 at dusk, more into the night (0 at the dock).
func day_fraction() -> float:
	return 0.0 if docked else maxf(_now() - trip_t0, 0.0) / DAY


## How light it is, 0 (night) .. 1 (full day): first light at the dock, up with the sun, down at dusk.
func daylight() -> float:
	if docked:
		return 0.55
	return daylight_at(day_fraction())


## How light it is at day fraction t (0 dawn .. 1 dusk; past 1 it's getting dark).
static func daylight_at(t: float) -> float:
	if t < 0.08:
		return lerpf(0.4, 1.0, t / 0.08)
	if t < 0.85:
		return 1.0
	return clampf(lerpf(1.0, 0.0, (t - 0.85) / 0.2), 0.0, 1.0)


## The time of day, "6:42 am".
func clock_text() -> String:
	var h := DAWN_H + (DUSK_H - DAWN_H) * day_fraction()
	var hh := int(floorf(h)) % 24
	var mm := int(floorf((h - floorf(h)) * 60.0))
	return "%d:%02d %s" % [(hh + 11) % 12 + 1, mm, "am" if hh < 12 else "pm"]


func has_gear(item: String) -> bool:
	return gear.has(item)


# ------------------------------------------------------------------ grading

## How well a fish was handled, 0..1 (tuna/handling.gd: landed fast, killed clean and quick, bled out, chilled fast).
static func quality(f: Dictionary, now: float) -> float:
	return Handling.quality(f, now)


static func grade(q: float) -> String:
	return Handling.grade(q)


static func price(kg: float, q: float) -> int:
	return roundi(kg * PRICE_PER_KG * (0.35 + 0.9 * q))


func _quality_of(f: Dictionary) -> float:
	return Handling.quality(f, _now())


## What the catch would fetch if she headed in now.
func worth() -> int:
	var total := 0
	for f: Dictionary in fish:
		total += price(float(f["kg"]), _quality_of(f))
	return total


# ------------------------------------------------------------------ the host

## Host: a fish came aboard (tuna/landing.gd): `fight_s` from the bite to on deck; `land`, where it came over the
## side (boat-local; it slides from there to the free spot nearest it).
func host_add(kg: float, fight_s: float, land: Variant = null) -> void:
	var used := []
	for f: Dictionary in fish:
		if float(f["iced_s"]) < 0.0:
			used.append(int(f["spot"]))
	var spot := 0
	while used.has(spot):
		spot += 1
	var spots: Array = ((sea.get("boat") as Node).get("spec") as Dictionary).get("spots", [])
	if land is Transform3D and not spots.is_empty():
		var best := INF
		for n in spots.size():
			var at: Vector4 = spots[n]
			var d := Vector2(at.x, at.z).distance_to(Vector2((land as Transform3D).origin.x, (land as Transform3D).origin.z))
			if not used.has(n) and d < best:
				best = d
				spot = n
	var f := {"id": _next_id, "kg": kg, "fight_s": fight_s, "aboard_t": _now(), "bled_s": -1.0, "iced_s": -1.0,
			"spot": spot}
	f.merge(Handling.fresh())
	if land is Transform3D:
		f["land"] = land
	fish.append(f)
	_next_id += 1
	_host_changed()


@rpc("any_peer", "call_remote", "reliable")
func _ask_work(id: int) -> void:
	_work(id)


## Host, a shortcut for the tests and screenshots: fish `id` spiked clean, cut right and run out if it isn't yet,
## else iced and packed.
func _work(id: int) -> void:
	for f: Dictionary in fish:
		if int(f["id"]) != id:
			continue
		var since := _now() - float(f["aboard_t"])
		if float(f["bled_s"]) < 0.0:
			f["spiked_s"] = since
			f["bled_s"] = since
			f["cut_t"] = _now()
			f["cut_q"] = 1.0
			f["cut_d"] = 0.6
			f["pumps"] = Handling.PUMPS
		elif float(f["iced_s"]) < 0.0 and iced() < capacity():
			f["iced_s"] = since
			f["drain"] = Handling.drain(f, _now())
			f["packed"] = 1.0
			f["packed_s"] = since
		_host_changed()
		return


## Asks the host to do `act` to fish `id` (tuna/handling.gd; a and b say how it went, as this machine saw it).
func _send_act(id: int, act: String, a := 0.0, b := 0.0) -> void:
	if Net.is_host():
		_act_on(Net.my_id(), id, act, a, b)
	else:
		_ask_act.rpc_id(1, id, act, a, b)


@rpc("any_peer", "call_remote", "reliable")
func _ask_act(id: int, act: String, a: float, b: float) -> void:
	_act_on(multiplayer.get_remote_sender_id(), id, act, a, b)


## Host: `who` did `act` to fish `id`: spike (a: how far off the brain; b 1: it kicked), cut (a: depth, b: how far
## off the artery), gut, pump, pin (a 1 on, 0 off), pack (a scoop of ice over the newest in the box not packed).
func _act_on(who: int, id: int, act: String, a: float, b: float) -> void:
	var now := _now()
	if act == "ice_in":
		host_ice_in()
		return
	if act == "pack":
		if prep != "off" and ice <= 0:
			return
		for k in range(fish.size() - 1, -1, -1):
			var g: Dictionary = fish[k]
			if float(g["iced_s"]) >= 0.0 and float(g.get("packed", 1.0)) < 1.0:
				g["packed"] = minf(float(g["packed"]) + Handling.PACK, 1.0)
				if prep != "off":
					ice -= 1
				if float(g["packed"]) >= 1.0:
					g["packed_s"] = now - float(g["aboard_t"])
				_host_changed()
				return
		return
	if act == "pin":
		if a > 0.0:
			_pins[who] = id
		else:
			_pins.erase(who)
		_count_pins()
		_host_changed()
		return
	for f: Dictionary in fish:
		if int(f["id"]) != id or float(f["iced_s"]) >= 0.0:
			continue
		var since := now - float(f["aboard_t"])
		match act:
			"spike":
				if float(f["spiked_s"]) >= 0.0:
					return
				if a <= Handling.SPIKE_OK and b < 0.5:
					f["spiked_s"] = since
				else:
					f["misses"] = int(f["misses"]) + 1
					f["thrash"] = float(f["thrash"]) + Handling.MISS_THRASH
			"cut":
				var q := Handling.cut_quality(a, b)
				if q <= float(f["cut_q"]):
					return
				if float(f["cut_t"]) < 0.0:
					f["cut_t"] = now
					f["bled_s"] = since
				f["cut_q"] = q
				f["cut_d"] = a
			"gut":
				if float(f["spiked_s"]) < 0.0 or bool(f["gutted"]):
					return
				f["gutted"] = true
			"pump":
				if float(f["cut_t"]) < 0.0 or int(f["pumps"]) >= Handling.PUMPS:
					return
				f["pumps"] = int(f["pumps"]) + 1
			_:
				return
		_host_changed()
		return


## Host: how many hands are on each fish, from who's pinning what.
func _count_pins() -> void:
	for f: Dictionary in fish:
		f["pins"] = _pins.values().count(int(f["id"]))


## Host, every frame: a live fish loose on deck burning itself up (pinned, a lot slower). Said to everyone with the
## next change.
func _host_life(delta: float) -> void:
	for f: Dictionary in fish:
		if float(f["iced_s"]) < 0.0 and float(f.get("spiked_s", 0.0)) < 0.0:
			f["thrash"] = float(f["thrash"]) + delta * (Handling.PINNED if int(f.get("pins", 0)) > 0 else 1.0)


## Host: fish `id` let go off the gaff at `at` (boat-local), lying `yaw`: in the fish box if it's open and that's
## over it (and there's room), else on the deck there.
@rpc("any_peer", "call_remote", "reliable")
func _ask_drop(id: int, at: Vector3, yaw: float) -> void:
	for f: Dictionary in fish:
		if int(f["id"]) != id or float(f["iced_s"]) >= 0.0:
			continue
		if box_open and over_box(at) and iced() < capacity():
			f["iced_s"] = _now() - float(f["aboard_t"])
			f["drain"] = Handling.drain(f, _now())       # (on ice, what's still in it stays in it)
			for peer: int in _pins.keys():
				if int(_pins[peer]) == id:
					_pins.erase(peer)
			_count_pins()
		else:
			f["at"] = at
			f["yaw"] = yaw
		_host_changed()
		return


## Host: the fish box's lid opened or shut.
@rpc("any_peer", "call_remote", "reliable")
func _ask_lid(open: bool) -> void:
	box_open = open
	_host_changed()


## The live well's lid held open or shut (boat/live_well.gd: E on it).
func request_well_lid(open: bool) -> void:
	if Net.is_host():
		_ask_well_lid(open)
	else:
		_ask_well_lid.rpc_id(1, open)


@rpc("any_peer", "call_remote", "reliable")
func _ask_well_lid(open: bool) -> void:
	well_open = open
	_host_changed()


## Whether a spot on deck (boat-local) is over the fish box, near enough to drop a fish in.
func over_box(at: Vector3) -> bool:
	var spec: Dictionary = (sea.get("boat") as Node).get("spec")
	var c: Vector3 = spec.get("box", Vector3.INF)
	var size: Vector2 = spec.get("box_size", Vector2.ZERO)
	return c != Vector3.INF and absf(at.x - c.x) < size.x * 0.5 + 0.45 and absf(at.z - c.z) < size.y * 0.5 + 0.45


## How many are iced in the fish box, and how many it takes (her kind's).
func iced() -> int:
	var n := 0
	for f: Dictionary in fish:
		n += 1 if float(f["iced_s"]) >= 0.0 else 0
	return n


func capacity() -> int:
	return int(((sea.get("boat") as Node).get("spec") as Dictionary).get("hold", 12))


## Host: the trip's over, she's tied up (boat/lines.gd both fast: sea/sea.gd hears it) or towed in; the fuel (with
## no dock prep: it was paid at the pump) and any charter taken off. The catch stays aboard to be hoisted onto the
## buyer's scale and sold a fish at a time (host_sell). `late`: she missed the race home at dusk and was towed in:
## the buyers have gone, the cannery pays half.
func head_in(late := false) -> void:
	if not Net.is_host() or docked:
		return
	var costs := []
	var spec: Dictionary = Kinds.spec(kind)
	if prep == "off":
		costs.append(["Fuel", int(spec.get("fuel", 0))])
	if not owned.has(kind):
		costs.append(["Charter, %s" % str(spec.get("name", "her")), CHARTER])
	var total := 0
	for c: Array in costs:
		total -= int(c[1])
	bank += total
	sale = {"lines": [], "costs": costs, "total": total, "bank": bank, "best": best,
			"quota": [quota_n, earned, quota, day], "verdict": "", "late": late, "settled": false}
	docked = true
	if fish.is_empty():
		_settle_day()
	_save()
	_host_changed()


## Host: fish `f` (taken off her by the hoist: host_unship) sold on the buyer's scale: its line on the slip, the money
## in the bank. The last of the catch sold, the day's settled.
func host_sell(f: Dictionary) -> Array:
	var q := _quality_of(f)
	var dollars := price(float(f["kg"]), q) / (2 if bool(sale.get("late", false)) else 1)
	var line := [float(f["kg"]), grade(q), dollars, Handling.reasons(f, _now())]
	if sale.is_empty():
		sale = {"lines": [], "costs": [], "total": 0, "bank": bank, "best": best,
				"quota": [quota_n, earned, quota, day], "verdict": "", "late": false, "settled": true}
	(sale["lines"] as Array).append(line)
	sale["total"] = int(sale["total"]) + dollars
	bank += dollars
	earned += dollars
	run_fish += 1
	run_biggest = maxf(run_biggest, float(f["kg"]))
	sale["bank"] = bank
	sale["quota"] = [quota_n, earned, quota, day]
	if fish.is_empty():
		_settle_day()
	_save()
	_host_changed()
	return line


## Host: fish `id` off her (onto the hoist's hook): out of the books aboard, its record handed over ({} if none).
func host_unship(id: int) -> Dictionary:
	for k in fish.size():
		if int(fish[k]["id"]) == id:
			var f: Dictionary = fish[k]
			fish.remove_at(k)
			_host_changed()
			return f
	return {}


## Host: dev and tests: every fish aboard sold where it lies, as the scale would.
func host_sell_all() -> void:
	while not fish.is_empty():
		host_sell(host_unship(int(fish[0]["id"])))


## Host: the day's done with (the catch sold, or she's casting off with some still aboard): the quota's day counted.
func _settle_day() -> void:
	if sale.is_empty() or bool(sale.get("settled", true)):
		return
	sale["settled"] = true
	best = maxi(best, int(sale.get("total", 0)))
	sale["best"] = best
	_settle()
	sale["bank"] = bank


## Host, after a sale: the quota's last day done, it's made (a bigger one, three more days) or the bank takes the boat
## (the run's story on the slip, and a new run). Otherwise just the next day. Not in Rivals: no quota there, the
## match is days won (vs/vs.gd), and nobody's boat is taken off them halfway through it.
func _settle() -> void:
	var real: Node = sea.get("sea") if sea.get("sea") != null else sea
	var vs: Node = real.get("vs")
	if vs != null and bool(vs.get("on")):
		return
	if day < DAYS:
		day += 1
		return
	if earned >= quota:
		sale["verdict"] = "met"
		quota_n += 1
		best_run = maxi(best_run, quota_n - 1)
		quota = quota_for(quota_n)
		sale["next"] = quota
		earned = 0
		day = 1
		return
	sale["verdict"] = "lost"
	sale["run"] = {"quotas": quota_n - 1, "fish": run_fish, "biggest": run_biggest}
	best_run = maxi(best_run, quota_n - 1)
	_new_run()
	(sea.get("boat") as Node).call("use_kind", kind)      # (back in the skiff)
	sale["bank"] = bank


## A fresh run: the skiff, START_CASH, no gear, the first quota.
func _new_run() -> void:
	bank = START_CASH
	owned = ["skiff"]
	gear = []
	kind = "skiff"
	quota_n = 1
	quota = quota_for(1)
	earned = 0
	day = 1
	run_fish = 0
	run_biggest = 0.0


## Quota n: $5,000 for the first, half as much again each time (to the nearest $500).
static func quota_for(n: int) -> int:
	return roundi(5000.0 * pow(1.5, n - 1) / 500.0) * 500


## Host: off the dock and out to the grounds in boat `k` (or the one picked), at dawn.
func head_out(k := "") -> void:
	if not Net.is_host():
		return
	if not k.is_empty():
		kind = k
	_settle_day()
	sale = {}
	docked = false
	trip_t0 = _now()
	if prep == "off":
		well = WELL_START
		fuel = 1.0
		ice = ice_room()
	dead = 0
	chum = CHUM
	(sea.get("boat") as Node).call("use_kind", kind)
	_save()
	_host_changed()
	(sea.get("rods") as Node).call("host_baits_out", prep == "off")


## How many scoops of ice her box takes.
func ice_room() -> int:
	return capacity() * ICE_PER_FISH


## How long a hold at the dock takes (the pump, a scoop): quicker with the "quick" prep.
func prep_rate() -> float:
	return 3.0 if prep == "quick" else 1.0


## Host: running her engines `throttle` (-1..1) for `delta` s burns her tank (not with no dock prep: she's never short).
## False: it's dry.
func burn(throttle: float, delta: float) -> bool:
	if prep == "off":
		return true
	if fuel <= 0.0:
		return false
	var was := fuel
	fuel = maxf(fuel - BURN * pow(absf(throttle), 1.5) * delta, 0.0)
	if floori(was * 50.0) != floori(fuel * 50.0) or fuel <= 0.0:
		_host_changed()
	return fuel > 0.0


## Host, the pump on the float: `amount` of a tank in (0..1), paid for as it goes (her kind's fuel price a tank). The
## amount it took.
func host_fill(amount: float) -> float:
	var price_tank := float(Kinds.spec(kind).get("fuel", 60))
	var room := 1.0 - fuel
	var afford := float(bank) / maxf(price_tank, 1.0)
	var took := clampf(minf(amount, room), 0.0, maxf(afford, 0.0))
	if took <= 0.0:
		return 0.0
	_fuel_owed += took * price_tank
	fuel += took
	var whole := floori(_fuel_owed)
	if whole > 0:
		bank -= whole
		_fuel_owed -= whole
	if floori((fuel - took) * 50.0) != floori(fuel * 50.0) or fuel >= 1.0:
		_host_changed()
	return took


var _fuel_owed := 0.0


## Host: a scoop of ice into her box (the bin on the float, ICE_PRICE). False: the box is full, or the bank's empty.
func host_ice_in() -> bool:
	if ice >= ice_room() or bank < ICE_PRICE:
		return false
	ice += 1
	bank -= ICE_PRICE
	_host_changed()
	return true


## Host: a tote of mackerel off the bait shop's counter (TOTE_PRICE). False: no money.
func host_buy_tote() -> bool:
	if bank < TOTE_PRICE:
		return false
	bank -= TOTE_PRICE
	Sfx.play("ui.buy")
	_save()
	_host_changed()
	return true


## Host: a tote tipped into her well: its mackerel in (as many as there's room for).
func host_tote_in() -> void:
	well = mini(well + TOTE, WELL_MAX)
	_host_changed()


## Host, at the dock: the boat she'll take.
func pick(k: String) -> void:
	if Net.is_host() and docked:
		kind = k
		(sea.get("boat") as Node).call("use_kind", kind)      # (there she is, alongside the dock)
		if sea.has_method("moor"):
			sea.call("moor")
		_save()
		_host_changed()


## Host, at the dock: buys a boat or a piece of gear if the bank has it. False if not.
func buy(item: String) -> bool:
	if not Net.is_host() or not docked:
		return false
	var cost := 0
	if GEAR.has(item) and not gear.has(item):
		cost = int(GEAR[item]["price"])
	elif Kinds.KINDS.has(item) and not owned.has(item):
		cost = int(Kinds.KINDS[item]["price"])
	else:
		return false
	if bank < cost:
		return false
	bank -= cost
	if GEAR.has(item):
		gear.append(item)
	else:
		owned.append(item)
	Sfx.play("ui.buy")
	_save()
	_host_changed()
	return true


## Host: a live mackerel out of the well for a bait (false: it's empty).
func host_take_live() -> bool:
	if docked or well <= 0:
		return false
	well -= 1
	_host_changed()
	return true


## Host: a jigged mackerel into the well (false: it's full).
func host_add_live() -> bool:
	if docked or well >= WELL_MAX:
		return false
	well += 1
	_host_changed()
	return true


## Host: a dead mackerel out of the bait box (false: none), or one into it.
func host_take_dead() -> bool:
	if docked or dead <= 0:
		return false
	dead -= 1
	_host_changed()
	return true


func host_add_dead() -> void:
	if not docked:
		dead += 1
		_host_changed()


## Host: the trip's bait stocked: `n` more live ones in the well (the rods go out bare: the crew bait them).
func host_stock(n: int) -> void:
	well = mini(well + n, WELL_MAX)
	_host_changed()


## Host: a scoop of chum out of the bucket (false: it's empty).
func host_take_chum() -> bool:
	if docked or chum <= 0:
		return false
	chum -= 1
	_host_changed()
	return true


func _host_changed() -> void:
	if Net.in_session():
		_sync.rpc(_state())
	else:
		_sync(_state())


func _state() -> Dictionary:
	return {"fish": fish, "bank": bank, "best": best, "sale": sale, "next": _next_id, "docked": docked, "box": box_open, "well_open": well_open,
			"fuel": fuel, "ice": ice, "prep": prep,
			"trip_t0": trip_t0, "kind": kind, "owned": owned, "gear": gear, "well": well, "dead": dead, "chum": chum,
			"quota_n": quota_n, "quota": quota, "earned": earned, "day": day, "run_fish": run_fish,
			"run_biggest": run_biggest, "best_run": best_run}


@rpc("authority", "call_local", "reliable")
func _sync(state: Dictionary) -> void:
	var first := not multiplayer.is_server() and not _borrowed      # (just aboard someone's boat: what's there was theirs)
	if not multiplayer.is_server():
		_borrowed = true
	fish = state["fish"]
	bank = int(state["bank"])
	best = int(state["best"])
	sale = state["sale"]
	_next_id = int(state["next"])
	var was := _docked_seen
	_hear_work()
	docked = bool(state.get("docked", docked))
	_docked_seen = docked
	fuel = float(state.get("fuel", fuel))
	ice = int(state.get("ice", ice))
	prep = str(state.get("prep", prep))
	box_open = bool(state.get("box", box_open))
	well_open = bool(state.get("well_open", well_open))
	trip_t0 = float(state.get("trip_t0", trip_t0))
	kind = str(state.get("kind", kind))
	owned = state.get("owned", owned)
	gear = state.get("gear", gear)
	well = int(state.get("well", well))
	dead = int(state.get("dead", dead))
	chum = int(state.get("chum", chum))
	quota_n = int(state.get("quota_n", quota_n))
	quota = int(state.get("quota", quota))
	earned = int(state.get("earned", earned))
	day = int(state.get("day", day))
	run_fish = int(state.get("run_fish", run_fish))
	run_biggest = float(state.get("run_biggest", run_biggest))
	best_run = int(state.get("best_run", best_run))
	_rebuild()
	if docked != was:
		_dock_changed(docked)
	_achieve(first)
	var sold_n := (sale.get("lines", []) as Array).size() if not sale.is_empty() else -1
	if sold_n < 0:
		_sold_noted = -1
	elif sold_n > maxi(_sold_noted, 0) or (str(sale.get("verdict", "")) == "met" and not _met_noted):
		if sold_n > maxi(_sold_noted, 0):
			Sfx.play("kit.coins")
		var from := maxi(_sold_noted, 0)
		_sold_noted = sold_n
		if not first:
			_achieve_sale(from)
	else:
		_sold_noted = maxi(_sold_noted, sold_n)
	if sale.is_empty():
		_met_noted = false


## What's newly done to each fish since last time, seen and heard by everyone (before the deck's rebuilt, while an
## iced fish still lies there): a clean spike's shiver, a miss's flop, the cut's spurt, the guts, a pump of the tail,
## the box's clank as one goes in, a scoop of ice tipped over one.
func _hear_work() -> void:
	for f: Dictionary in fish:
		var id := int(f["id"])
		var now := {"spiked": float(f.get("spiked_s", -1.0)) >= 0.0, "misses": int(f.get("misses", 0)),
				"cut": float(f["bled_s"]) >= 0.0, "gutted": bool(f.get("gutted", false)),
				"pumps": int(f.get("pumps", 0)), "iced": float(f["iced_s"]) >= 0.0,
				"packed": float(f.get("packed", 0.0))}
		var was: Dictionary = _heard.get(id, {})
		var node := _deck.get(id) as Tuna
		if not was.is_empty():
			if node != null:
				if bool(now["spiked"]) and not bool(was["spiked"]):
					_spiked(node)
				elif int(now["misses"]) > int(was["misses"]):
					_glanced(node)
				if bool(now["cut"]) and not bool(was["cut"]):
					_spurt(node)
				if bool(now["gutted"]) and not bool(was["gutted"]):
					_gutted(node)
				if int(now["pumps"]) > int(was["pumps"]):
					_pumped(node)
				if bool(now["iced"]) and not bool(was["iced"]):
					Sfx.play_point(self, node.global_position, "kit.clank")
			if float(now["packed"]) > float(was["packed"]):
				_iced_over()
		_heard[id] = now


## A clean spike: the point in, a crack, a shiver running through it, and still.
func _spiked(t: Tuna) -> void:
	t.shiver = 1.0
	t.effort = 0.0
	Handling.play(self, _on_fish(t, Handling.BRAIN), "spike", 0.9)
	Sfx.play_point(self, t.global_position, "dock.slap", 0.35, 1.5)


## A spike that glanced off: it flops hard and fights you.
func _glanced(t: Tuna) -> void:
	t.kick(1.8)
	Sfx.play_point(self, t.global_position, "dock.slap", 1.0, 0.9)
	Handling.pixels(self, _on_fish(t, Handling.BRAIN), Handling.BLOOD, 6, 0.025, Vector2(0.4, 1.0))


## A point on fish `t`'s upper flank (it lies on its side) at `u` along it.
func _on_fish(t: Tuna, u: float) -> Vector3:
	return t.global_transform * Vector3(t.length * 0.06, 0.0, u * t.length)


## The deck right under a point (world).
func _on_deck(at: Vector3) -> Vector3:
	var boat := sea.get("boat") as Node3D
	var local := boat.global_transform.affine_inverse() * at
	local.y = float((boat.get("spec") as Dictionary).get("deck", 0.5)) + 0.003
	return boat.global_transform * local


## In to the dock, or out to the grounds: the dusk notes start over; tied up after a trip, said so (only the boat
## you're on: in Rivals the other boat tying up is nothing to you). Nothing else changes: you're where you are.
func _dock_changed(now_docked: bool) -> void:
	_dusk_noted = 0
	var real: Node = sea.get("sea") if sea.get("sea") != null else sea
	if real.get("fish_hold") != self:
		return
	if now_docked and not sale.is_empty() and _mine():
		_note("Tied up at the fish pier")


# ------------------------------------------------------------------ on deck

## Makes the deck match the books: a fish lying in its spot for each one not iced yet, bled ones in their blood.
func _rebuild() -> void:
	var boat := sea.get("boat") as Node3D
	var keep := {}
	for f: Dictionary in fish:
		if float(f["iced_s"]) >= 0.0:
			continue
		var id := int(f["id"])
		keep[id] = true
		_dragged.erase(id)
		if not _deck.has(id):
			_deck[id] = _lay(f, boat)
		elif f.has("at") and id != _dragging:
			(_deck[id] as Node3D).transform = _lying(_deck[id] as Node3D, f["at"], float(f["yaw"]))
		var blood := (_deck[id] as Node).get_node_or_null("Blood") as Node3D
		if blood:
			blood.visible = float(f["bled_s"]) >= 0.0
	var iced_ids := {}
	for f: Dictionary in fish:
		if float(f["iced_s"]) >= 0.0:
			iced_ids[int(f["id"])] = true
	for id: int in _deck.keys():
		if not keep.has(id):
			var gone := _deck[id] as Node3D
			if iced_ids.has(id):
				_slide_in(gone, boat)
			else:
				gone.queue_free()
			_deck.erase(id)
			_streams.erase(id)
			if id == _dragging:
				_let_go(false)
	_tally()


func _lay(f: Dictionary, boat: Node3D) -> Node3D:
	var id := int(f["id"])
	var t := Tuna.new(float(f["kg"]))
	t.name = "OnDeck%d" % id
	t.posed = true
	t.effort = 0.0
	t.limp = float(f.get("spiked_s", -1.0)) >= 0.0
	var spots: Array = (boat.get("spec") as Dictionary)["spots"]
	var n := int(f["spot"])
	var at: Vector4 = spots[n % spots.size()]
	var spot := Vector3(at.x, at.y, at.z) + Vector3(0.0, 0.3 * floorf(n / float(spots.size())), 0.0)
	# on its side: across her, head to starboard, or along her, head forward (or where it was dragged to)
	var head := Vector3.RIGHT if at.w > 0.5 else Vector3.FORWARD
	t.transform = Transform3D(Basis.looking_at(head, Vector3.UP) * Basis(Vector3(0, 0, 1), PI * 0.5),
			spot + Vector3(0.0, t.length * 0.07, 0.0))
	if f.has("at"):
		t.transform = _lying(t, f["at"], float(f["yaw"]))
		spot = f["at"]
	boat.add_child(t)
	# just come over the side: it slides off the door (the gunwale) from where it came aboard, lands with a slap and
	# lies there kicking (no blink from the water to its spot)
	if f.get("land") is Transform3D and _now() - float(f["aboard_t"]) < 1.5 and not f.has("at"):
		var rest := t.transform
		var from: Transform3D = f["land"]
		t.transform = from
		var tw := t.create_tween()
		tw.tween_property(t, "transform", from.interpolate_with(rest, 0.55).translated(Vector3.UP * 0.12), 0.35) \
				.set_trans(Tween.TRANS_SINE)
		tw.tween_property(t, "transform", rest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			Sfx.play_point(self, t.global_position, "kit.bodyfall", 0.9, 0.7)
			t.kick(1.2))
	var blood := MeshInstance3D.new()
	blood.name = "Blood"
	var pool := CylinderMesh.new()
	pool.top_radius = t.length * 0.25
	pool.bottom_radius = t.length * 0.25
	pool.height = 0.004
	pool.radial_segments = 10
	blood.mesh = pool
	blood.top_level = false
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.03, 0.04)
	m.roughness = 0.3
	blood.material_override = m
	blood.visible = false
	t.add_child(blood)
	var act := Action.new(Vector3(0.6, 0.5, t.length))
	act.name = "Handle"
	act.use_with = func(p: Node, item: String, pressed: bool) -> bool: return _handle(id, p, item, pressed)
	act.prompt = func() -> String: return _fish_prompt(id)
	t.add_child(act)
	# (the blood stays where it was bled, not under a fish dragged off it: it spreads from under the cut)
	blood.top_level = true
	var cut := Vector3(spot.x, spot.y, spot.z) + Basis.looking_at(head, Vector3.UP) * Vector3(0.0, 0.0,
			Handling.CUT_AT * t.length)
	if f.has("at"):
		cut = spot
	blood.global_transform = boat.global_transform * Transform3D(Basis.IDENTITY, Vector3(cut.x, spot.y + 0.003, cut.z))
	return t


## A fish lying on its side on her deck at `at` (boat-local), its head toward `yaw` + PI (toward you, dragging it).
func _lying(t: Node3D, at: Vector3, yaw: float) -> Transform3D:
	var head := Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 1.0)
	var deck := float(((sea.get("boat") as Node).get("spec") as Dictionary).get("deck", 0.5))
	return Transform3D(Basis.looking_at(head, Vector3.UP) * Basis(Vector3(0, 0, 1), PI * 0.5),
			Vector3(at.x, deck, at.z) + Vector3(0.0, float(t.get("length")) * 0.07, 0.0))


func _fish_of(id: int) -> Dictionary:
	for f: Dictionary in fish:
		if int(f["id"]) == id:
			return f
	return {}


## Where along fish `id` (snout -0.5 .. tail 0.5) `p`'s sight is on its body (NAN: not on it).
func aim_u(id: int, p: Node) -> float:
	var node := _deck.get(id) as Tuna
	var cam: Camera3D = p.get("cam") if p != null else null
	if node == null or cam == null or node.mesh == null:
		return NAN
	# (in the model's own unit frame, flops and all: a fish 1 long; on its side its width is up, its depth across)
	var inv := node.mesh.global_transform.affine_inverse()
	var from := inv * cam.global_position
	var to := inv * (cam.global_position - cam.global_basis.z * 4.0)
	var hit: Variant = AABB(Vector3(-0.1, -0.14, -0.5), Vector3(0.2, 0.28, 1.0)).intersects_segment(from, to)
	return (hit as Vector3).z if hit != null else NAN


## Left mouse on fish `id`: the knife spikes it, cuts it or guts it (by where it goes in); bare hands pump its tail
## or pin it down; the gaff hooks it to drag (let go to drop it). Let go and what you were doing ends there.
func _handle(id: int, p: Node, item: String, pressed: bool) -> bool:
	var f := _fish_of(id)
	if f.is_empty():
		return false
	match item:
		"knife":
			if not pressed:
				_end_act()
				return true
			var u := aim_u(id, p)
			var what := _knife_act(f, u)
			if not what.is_empty():
				_act = what
				_act_id = id
				_act_t = 0.0
				_act_u = u
				_act_kicked = false
				p.call("gesture", "bleed")
			return true
		"":
			if not pressed:
				_end_act()
				return true
			var u := aim_u(id, p)
			if Handling.region(u) == "tail":
				if _pump_t >= Handling.PUMP_EVERY:
					_pump_t = 0.0
					(_deck[id] as Tuna).pump = 1.0
					p.call("gesture", "reach")
					_send_act(id, "pump")
				return true
			if float(f.get("spiked_s", -1.0)) < 0.0 and not is_nan(u):
				_act = "pin"
				_act_id = id
				_act_t = 0.0
				p.call("gesture", "reach")
				_send_act(id, "pin", 1.0)
				return true
			return false
		"gaff":
			if pressed:
				_dragging = id
				var node := _deck.get(id) as Node3D
				if node:
					Sfx.play_point(self, node.global_position, "kit.thud", 0.6, 1.4)
				p.call("gesture", "reach")
			elif _dragging == id:
				_let_go(true)
			return true
	return false


## What the knife does to fish `f` at `u` along it ("" nothing there): the brain spiked, the fin's cut made (again, if
## the first was poor), the belly opened once it's dead.
func _knife_act(f: Dictionary, u: float) -> String:
	var spiked := float(f.get("spiked_s", -1.0)) >= 0.0
	match Handling.region(u):
		"head":
			return "" if spiked else "spike"
		"fin":
			return "cut" if float(f.get("cut_q", -1.0)) < RECUT else ""
		"belly":
			return "gut" if spiked and not bool(f.get("gutted", false)) else ""
	return ""


## What you're doing to a fish this frame: the push of the spike, the knife going deeper, the long draw along the belly,
## held down; the ring round your sight; done, the host's told how it went.
func _work_on(delta: float) -> void:
	_pump_t += delta
	var me := (sea.get("crew") as Node).get("me") as Node
	if _act != "" and (not _deck.has(_act_id) or me == null or docked):
		if _act == "pin":
			_send_act(_act_id, "pin", 0.0)
		_act = ""
	if me != null:
		var work := {}
		if _act != "":
			work = {"kind": _act, "k": _act_k()}
		elif _pump_t < Handling.PUMP_EVERY:
			work = {"kind": "pump", "k": _pump_t / Handling.PUMP_EVERY}
		me.set_meta("work", work)
	_draw_ring()
	if _act == "":
		return
	var was := _act_t
	_act_t += delta
	if _act != "pin" and int(_act_t / 0.45) != int(was / 0.45):
		me.call("gesture", "bleed")
	match _act:
		"spike":
			if _act_t >= Handling.SPIKE_HOLD:
				# (where the point went in: hold still on it, and it mustn't kick while you push)
				_send_act(_act_id, "spike", absf(_act_u - Handling.BRAIN), 1.0 if _act_kicked else 0.0)
				_act = ""
		"cut":
			if _act_t >= Handling.CUT_FULL:
				_end_act()
		"gut":
			if _act_t >= Handling.GUT_HOLD:
				_send_act(_act_id, "gut")
				_act = ""


## Let go: a cut ends as deep as it got (too light and it's only a scratch); the pin comes off; a spike or the gut
## not finished is nothing done.
func _end_act() -> void:
	match _act:
		"cut":
			var d := clampf(_act_t / Handling.CUT_FULL, 0.0, 1.0)
			if d >= 0.15:
				_send_act(_act_id, "cut", d, absf(_act_u - Handling.CUT_AT) + (Handling.SLIP if _act_kicked else 0.0))
		"pin":
			_send_act(_act_id, "pin", 0.0)
	_act = ""


## How far through what you're doing you are (0..1).
func _act_k() -> float:
	match _act:
		"spike":
			return _act_t / Handling.SPIKE_HOLD
		"cut":
			return _act_t / Handling.CUT_FULL
		"gut":
			return _act_t / Handling.GUT_HOLD
	return 1.0


## The ring round your sight while the knife's in: filling as you push, cut or draw; for the cut, a pale mark on it where
## the artery is (stop there).
func _draw_ring() -> void:
	var show := _act in ["spike", "cut", "gut"]
	if _ring == null:
		if not show:
			return
		var layer := CanvasLayer.new()
		layer.layer = 7
		add_child(layer)
		_ring = Control.new()
		_ring.set_anchors_preset(Control.PRESET_CENTER)
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ring.draw.connect(func() -> void:
			var k := clampf(_act_k(), 0.0, 1.0)
			var top := -PI * 0.5
			_ring.draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 5.0)
			if _act == "cut":
				var band := Handling.CUT_BAND
				_ring.draw_arc(Vector2.ZERO, 24.0, top + TAU * band.x, top + TAU * band.y, 8,
						Color(0.95, 0.9, 0.75, 0.9), 3.0)
			var c := Color(0.9, 0.2, 0.15) if _act != "cut" or k <= Handling.CUT_BAND.y else Color(0.55, 0.05, 0.05)
			_ring.draw_arc(Vector2.ZERO, 18.0, top, top + TAU * k, 24, c, 5.0))
		layer.add_child(_ring)
	_ring.visible = show
	if show:
		_ring.queue_redraw()


## The fish on deck alive: it kicks every few seconds (flopping over, hard enough to spoil your knife) till it's spiked,
## next to nothing while someone pins it; cut, its blood running out of it and spreading under it as it drains.
func _throes(delta: float) -> void:
	var now := _now()
	for f: Dictionary in fish:
		var id := int(f["id"])
		if not _deck.has(id):
			continue
		var t := _deck[id] as Tuna
		var spiked := float(f.get("spiked_s", -1.0)) >= 0.0
		t.limp = spiked
		t.effort = move_toward(t.effort, 0.0, delta * 1.6)
		var next := float(_kick_in.get(id, randf_range(0.5, 2.5))) - delta
		if next <= 0.0 and not spiked:
			next = randf_range(1.6, 4.0)
			if int(f.get("pins", 0)) > 0:
				t.kick(0.12)
			else:
				t.kick(1.0)
				Sfx.play_point(self, t.global_position, "dock.slap", 0.55, 1.15)
				if id == _act_id and _act in ["spike", "cut", "gut"]:
					_act_kicked = true          # (it flopped under the knife)
		_kick_in[id] = next
		_bleeding(t, f, now)


## Fish `t` cut: the stream from the cut while there's blood in it, the pool under it growing as it drains.
func _bleeding(t: Tuna, f: Dictionary, now: float) -> void:
	var id := int(f["id"])
	var cut := float(f["bled_s"]) >= 0.0
	var dr := Handling.drain(f, now)
	var blood := t.get_node_or_null("Blood") as Node3D
	if blood and cut:
		var k := 0.15 + 0.85 * dr
		blood.scale = Vector3(k, 1.0, k)
	var running := cut and dr < 0.97 and float(f.get("cut_t", -1.0)) >= 0.0
	var s := _streams.get(id) as GPUParticles3D
	if running and s == null:
		s = Handling.pixels(t, _on_fish(t, Handling.CUT_AT), Handling.BLOOD, 20, 0.022, Vector2(0.25, 0.8), true)
		s.lifetime = 0.45
		_streams[id] = s
	if s != null and is_instance_valid(s):
		s.emitting = running
		s.amount_ratio = 0.25 + 0.75 * (1.0 - dr)


## Iced: the fish slides down through the open hatch into the box and out of sight, no blink.
func _slide_in(t: Node3D, boat: Node3D) -> void:
	var box: Vector3 = (boat.get("spec") as Dictionary).get("box", t.position)
	var blood := t.get_node_or_null("Blood")
	if blood:
		blood.reparent(boat)        # (the pool stays on deck where it was bled)
	var tw := t.create_tween()
	tw.tween_property(t, "position", Vector3(box.x, t.position.y, box.z), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t, "position", Vector3(box.x, box.y - 0.9, box.z), 0.45).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	tw.tween_callback(t.queue_free)


## The cut: a spurt of blood off it, a wet squelch, and the pool starts under it.
func _spurt(t: Tuna) -> void:
	var at := _on_fish(t, Handling.CUT_AT)
	Handling.pixels(self, at, Handling.BLOOD, 40, 0.03, Vector2(1.0, 2.4))
	Handling.play(self, at, "cut")
	Sfx.play_point(self, at, "kit.thud", 0.4, 1.6)
	var blood := t.get_node_or_null("Blood") as Node3D
	if blood:
		blood.global_position = _on_deck(at)


## The belly opened: the guts out onto the deck in a slither.
func _gutted(t: Tuna) -> void:
	var at := _on_fish(t, Handling.GUT_AT)
	Handling.pixels(self, at, Handling.GUTS, 18, 0.05, Vector2(0.4, 1.1))
	Handling.pixels(self, at, Handling.BLOOD, 14, 0.03, Vector2(0.3, 0.9))
	Handling.play(self, at, "gut")


## A pump of the tail: it's pushed over and springs back, a gout out of the cut.
func _pumped(t: Tuna) -> void:
	t.pump = 1.0
	var at := _on_fish(t, Handling.CUT_AT)
	Handling.pixels(self, at, Handling.BLOOD, 12, 0.026, Vector2(0.8, 1.8))
	Handling.play(self, at, "pump", 0.8)


## A scoop of ice tipped over the fish in the box: the chunks falling in, a crunch.
func _iced_over() -> void:
	if not is_instance_valid(_inside):
		return
	var at := _inside.global_position + _inside.global_basis.y * 0.5
	Handling.pixels(self, at, Handling.ICE, 24, 0.04, Vector2(0.2, 0.8))
	Handling.play(self, at, "ice")


## What a fish on deck wants next, in words under your sight (KEY|words: the key cap and what it does), from what's in
## your hands and where on it you're looking.
func _fish_prompt(id: int) -> String:
	var me := (sea.get("crew") as Node).get("me") as Node
	var hands: Node = me.get("hands") if me else null
	var held := str(hands.get("item")) if hands else ""
	var f := _fish_of(id)
	if f.is_empty():
		return ""
	var spot := Handling.region(aim_u(id, me))
	var spiked := float(f.get("spiked_s", -1.0)) >= 0.0
	var cut_q := float(f.get("cut_q", 1.0 if float(f["bled_s"]) >= 0.0 else -1.0))
	var running := float(f.get("cut_t", -1.0)) >= 0.0 and Handling.drain(f, _now()) < 0.97
	match held:
		"knife":
			var what := _knife_act(f, aim_u(id, me))
			if what == "spike":
				return "HOLD LMB|SPIKE HIM"
			if what == "cut":
				return "HOLD LMB|CUT, LET GO AT THE MARK"
			if what == "gut":
				return "HOLD LMB|GUT HIM"
			if not spiked:
				return "HOLD LMB|SPIKE: BEHIND THE EYE"
			if cut_q < RECUT:
				return "HOLD LMB|BLEED: UNDER THE FIN"
		"gaff":
			return "HOLD LMB|DRAG HIM TO THE FISH BOX"
		"":
			if spot == "tail" and running:
				return "LMB|PUMP THE TAIL"
			if not spiked and _crewed():
				return "HOLD LMB|PIN HIM DOWN"
	if not spiked:
		return "1|THE KNIFE: SPIKE HIM"
	if cut_q < 0.0:
		return "1|THE KNIFE: BLEED HIM"
	if running and held != "":
		return "1|EMPTY HANDS: PUMP THE TAIL"
	return "2|THE GAFF: INTO THE FISH BOX"


## Your fish on the gaff, this frame: it slides along the deck ahead of you, its head toward you, and slows you down
## (a giant a lot); and everyone else's, where their peers say.
func _drag(delta: float) -> void:
	var boat := sea.get("boat") as Node3D
	for id: int in _dragged.keys():
		if id != _dragging and _deck.has(id):
			var w: Array = _dragged[id]
			var node := _deck[id] as Node3D
			node.transform = node.transform.interpolate_with(_lying(node, w[0], float(w[1])), minf(1.0, delta * 12.0))
	if _dragging < 0:
		return
	var me := (sea.get("crew") as Node).get("me") as Node3D
	var node := _deck.get(_dragging) as Node3D
	if me == null or node == null or docked:
		_let_go(false)
		return
	var yaw := float(me.get("_yaw"))
	var spec: Dictionary = boat.get("spec")
	var reach := 0.5 + float(node.get("length")) * 0.5
	var at: Vector3 = me.call("local_position") + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, -reach)
	var half := float(spec["beam"]) * 0.5 - 0.45
	at.x = clampf(at.x, -half, half)
	node.transform = node.transform.interpolate_with(_lying(node, at, yaw), minf(1.0, delta * 10.0))
	var kg := float(node.get("kg")) if node.get("kg") != null else 150.0
	me.set("burden", clampf(1.15 - kg / 350.0, 0.3, 1.0))
	_drag_send -= delta
	if Net.in_session() and _drag_send <= 0.0:
		_drag_send = 0.1
		_drag_state.rpc(_dragging, at, yaw)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _drag_state(id: int, at: Vector3, yaw: float) -> void:
	_dragged[id] = [at, yaw]


## Off the gaff: dropped where it is (`drop`), into the box if it's open under it; or just lost from your hands.
func _let_go(drop: bool) -> void:
	var id := _dragging
	_dragging = -1
	var me := (sea.get("crew") as Node).get("me") as Node3D
	if me:
		me.set("burden", 1.0)
	var node := _deck.get(id) as Node3D
	if not drop or node == null:
		return
	var boat := sea.get("boat") as Node3D
	var at := boat.global_transform.affine_inverse() * node.global_position
	at.y = 0.0
	var yaw := float(me.get("_yaw")) if me else 0.0
	Sfx.play_point(self, node.global_position, "kit.bodyfall", 0.7, 0.8)
	if Net.is_host():
		_ask_drop(id, at, yaw)
	else:
		_ask_drop.rpc_id(1, id, at, yaw)


## The fish box: its lid over the hatch in her sole (E on it to open or shut it; open, the scoop on it packs ice over
## the newest fish in), and inside, ice and the fish iced down in it: a tail up out of the ice for each, its back
## showing till it's packed under a heap of ice (again whenever she's rebuilt).
func _attach_box() -> void:
	for n: Node in [_lid, _inside]:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_lid = null
	_inside = null
	var boat := sea.get("boat") as Node3D
	var spec: Dictionary = boat.get("spec")
	if not spec.has("box"):
		return
	var c: Vector3 = spec["box"]
	var size: Vector2 = spec["box_size"]
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.88, 0.87, 0.82)
	white.roughness = 0.6
	# the lid: hinged along its forward edge
	_lid = Node3D.new()
	_lid.name = "FishBoxLid"
	_lid.position = Vector3(c.x, c.y + 0.035, c.z - size.y * 0.5)
	boat.add_child(_lid)
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.04, size.y)
	slab.mesh = bm
	slab.material_override = white
	slab.position = Vector3(0.0, 0.0, size.y * 0.5)
	_lid.add_child(slab)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.25, 0.03, 0.04)
	handle.mesh = hm
	handle.material_override = _flat(Color(0.6, 0.62, 0.64))
	handle.position = Vector3(0.0, 0.035, size.y - 0.06)
	_lid.add_child(handle)
	# (its E box stays over the hatch however far the lid's swung: _show_box turns it back)
	var act := Action.new(Vector3(size.x, 0.25, size.y))
	act.name = "Lid"
	act.position = Vector3(0.0, 0.1, size.y * 0.5)
	act.use = func(_p: Node) -> void:
		if Net.is_host():
			_ask_lid(not box_open)
		else:
			_ask_lid.rpc_id(1, not box_open)
	act.prompt = func() -> String: return _lid_prompt()
	act.use_with = func(p: Node, item: String, pressed: bool) -> bool: return _scoop_ice(p, item, pressed)
	_lid.add_child(act)
	# inside: the dark of the box, the ice, and for each fish in it a tail, its back, and the ice heaped over it
	_inside = Node3D.new()
	_inside.name = "FishBoxInside"
	_inside.position = Vector3(c.x, c.y + 0.032, c.z)
	_inside.visible = false
	boat.add_child(_inside)
	var dark := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	dark.mesh = pm
	dark.material_override = _flat(Color(0.06, 0.07, 0.08))
	_inside.add_child(dark)
	var ice := MeshInstance3D.new()
	var im := PlaneMesh.new()
	im.size = size * 0.85
	ice.mesh = im
	var ice_m := _flat(Color(0.78, 0.86, 0.9))
	ice.material_override = ice_m
	ice.position.y = 0.002
	_inside.add_child(ice)
	var tail := PrismMesh.new()
	tail.size = Vector3(0.32, 0.22, 0.02)
	var back := BoxMesh.new()
	back.size = Vector3(0.16, 0.05, size.y * 0.38)
	var heap := BoxMesh.new()
	heap.size = Vector3(size.x * 0.3, 0.1, size.y * 0.42)
	for i in 6:
		var at := Vector3((float(i % 3) - 1.0) * size.x * 0.3, 0.0, (float(i / 3) - 0.5) * size.y * 0.4)
		var t := MeshInstance3D.new()
		t.name = "Tail%d" % i
		t.mesh = tail
		t.material_override = _flat(Color(0.14, 0.18, 0.28))
		t.position = at + Vector3(0.0, 0.1, 0.0)
		t.rotation = Vector3(0.0, 0.4 * float(i % 2) - 0.2, PI)
		_inside.add_child(t)
		var b := MeshInstance3D.new()
		b.name = "Back%d" % i
		b.mesh = back
		b.material_override = _flat(Color(0.12, 0.17, 0.3))
		b.position = at + Vector3(0.0, 0.02, 0.0)
		_inside.add_child(b)
		var h := MeshInstance3D.new()
		h.name = "Heap%d" % i
		h.mesh = heap
		h.material_override = ice_m
		h.position = at
		h.scale = Vector3(1.0, 0.01, 1.0)
		_inside.add_child(h)


func _lid_prompt() -> String:
	if box_open and _unpacked() >= 0:
		var hands: Node = ((sea.get("crew") as Node).get("me") as Node).get("hands") \
				if (sea.get("crew") as Node).get("me") else null
		if hands != null and str(hands.get("item")) == "scoop":
			return "LMB|ICE OVER HIM"
		return "4|THE SCOOP: ICE HIM OVER"
	return "Shut" if box_open else "Open"


## The newest fish in the box not packed under ice yet (its index in `fish`; -1 none).
func _unpacked() -> int:
	for k in range(fish.size() - 1, -1, -1):
		if float(fish[k]["iced_s"]) >= 0.0 and float(fish[k].get("packed", 1.0)) < 1.0:
			return k
	return -1


## The scoop on the open box: a scoop of ice out of the box tipped over the newest fish in (the host's told). Not with
## chum in it.
func _scoop_ice(p: Node, item: String, pressed: bool) -> bool:
	var hands: Node = p.get("hands")
	if item == "scoop" and pressed and box_open and hands != null and bool(hands.get("scoop_ice")):
		# (a scoop of ice off the bin on the float, tipped into her box: sea/places.gd)
		hands.set("scoop_ice", false)
		_send_act(-1, "ice_in")
		p.call("gesture", "scoop")
		return true
	if item != "scoop" or not pressed or not box_open or _unpacked() < 0:
		return false
	if hands != null and bool(hands.get("scoop_full")):
		return false
	_send_act(-1, "pack")
	p.call("gesture", "scoop")
	return true


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


## The lid swinging to the host's word (a clank as it lands either way, its E box kept over the hatch), and the fish in
## the box seen when it's open: tails up out of the ice, their backs till the ice is heaped over them.
func _show_box(delta: float) -> void:
	if not is_instance_valid(_lid):
		return
	var was := _lid_k
	_lid_k = move_toward(_lid_k, 1.0 if box_open else 0.0, delta * 2.5)
	_lid.rotation.x = -1.85 * smoothstep(0.0, 1.0, _lid_k)
	var act := _lid.get_node_or_null("Lid") as Node3D
	if act:
		var size: Vector2 = ((sea.get("boat") as Node).get("spec") as Dictionary).get("box_size", Vector2.ONE)
		act.transform = Transform3D(Basis(Vector3.RIGHT, -_lid.rotation.x), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, size.y * 0.5))
	_inside.visible = _lid_k > 0.02
	if was != _lid_k and (_lid_k == 0.0 or _lid_k == 1.0):
		Sfx.play_point(self, _lid.global_position, "kit.clank", 0.7, 1.0 if _lid_k == 0.0 else 1.2)
	var in_box := []
	for f: Dictionary in fish:
		if float(f["iced_s"]) >= 0.0:
			in_box.append(f)
	for i in 6:
		var f: Dictionary = in_box[in_box.size() - 6 + i] if in_box.size() > 6 else (in_box[i] if i < in_box.size() else {})
		var packed := float(f.get("packed", 1.0))
		(_inside.get_node("Tail%d" % i) as Node3D).visible = not f.is_empty()
		(_inside.get_node("Back%d" % i) as Node3D).visible = not f.is_empty() and packed < 1.0
		var heap := _inside.get_node("Heap%d" % i) as Node3D
		heap.visible = not f.is_empty() and packed > 0.0
		# (the heap grows to each scoop, not in steps)
		var goal := maxf(0.01, packed)
		heap.scale.y = move_toward(heap.scale.y, goal, delta * 2.0)
		heap.position.y = heap.scale.y * 0.05


## What to do now, for the HUD (rods.gd shows it when nothing else needs doing): the fish on deck show it
## themselves (lying there, bled or not); only a full box wants saying.
func hint() -> String:
	for f: Dictionary in fish:
		if float(f["iced_s"]) < 0.0 and iced() >= capacity():
			return "Fish box full: bring her home to the buyer"
	return ""


func _tally() -> void:
	var crew := sea.get("crew") as Node
	if crew == null or crew.get("hud") == null:
		return
	var hud := crew.get("hud") as Node
	if docked:
		hud.call("tally", {})       # (the dock's menu has the lot)
		return
	var held := 0
	var deck := 0
	for f: Dictionary in fish:
		if float(f["iced_s"]) >= 0.0:
			held += 1
		else:
			deck += 1
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		# (Rivals: no quota, no career; the match's day and her box)
		hud.call("tally", {"rivals": true, "day": int(vs.get("day")), "box": held, "cap": capacity(), "deck": deck})
		return
	hud.call("tally", {"day": day, "days": DAYS, "box": held, "cap": capacity(), "deck": deck, "earned": earned,
			"quota": quota, "aboard": worth(), "earned_text": "$" + _money(earned), "quota_text": "$" + _money(quota)})


# ------------------------------------------------------------------ odds and ends

func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _note(text: String) -> void:
	var crew := sea.get("crew") as Node
	(crew.get("hud") as Node).call("notify", text)


## Tests and screenshots: never the player's career (Settings' rule, and a sea a test built under its own node).
# ------------------------------------------------------------------ achievements (core/achievements.gd)

## Whether this is the hold of the boat you're on (in Rivals the other boat's things see a crew with no `me`).
func _mine() -> bool:
	var crew := sea.get("crew") as Node if sea != null else null
	return crew != null and crew.get("me") != null


## Whether a friend's aboard your boat with you (in Rivals, on your side).
func _crewed() -> bool:
	var crew := sea.get("crew") as Node
	var vs := sea.get("vs") as Node
	if vs != null and bool(vs.get("on")):
		var mine := int(vs.get("my_team"))
		return (vs.get("teams") as Dictionary).values().count(mine) > 1
	return crew != null and (crew.get("slots") as Dictionary).size() > 1


## Everyone, as the books come in: a fish newly on your deck (`first`: just aboard someone's boat, what's on her deck
## was theirs), and the career's own (_achieve_career).
func _achieve(first: bool) -> void:
	var mine := _mine()
	for f: Dictionary in fish:
		var id := int(f["id"])
		if _seen.has(id):
			continue
		_seen[id] = true
		if first or not mine or docked:
			continue
		var a := Net.achievements
		a.unlock("FIRST_FISH")
		if float(f["kg"]) >= Achievements.GIANT_KG:
			a.unlock("GIANT")
		if _crewed():
			a.unlock("CREW")
		if day_fraction() > 1.0:
			a.unlock("NIGHT")
		if str(sea.get("condition")) == "storm":
			a.unlock("STORM")
	_achieve_career()


## Everyone, a sale on your boat: a #1, the kilos toward A Ton Ashore, a quota made.
func _achieve_sale(from := 0) -> void:
	if not _mine():
		return
	var a := Net.achievements
	var kg := 0.0
	for l: Array in (sale.get("lines", []) as Array).slice(from):
		kg += float(l[0])
		if str(l[1]) == "#1":
			a.unlock("GRADE_ONE")
	if kg > 0.0:
		a.add_sold(kg)
	if str(sale.get("verdict", "")) == "met" and not _met_noted:
		_met_noted = true
		a.unlock("QUOTA")
		if quota_n - 1 >= 3:
			a.unlock("THREE_QUOTAS")


## The host's own career: the sportfisher bought, quotas made (a career from before there were achievements too).
func _achieve_career() -> void:
	if _borrowed or not career or not Net.is_host() or not _mine():
		return
	var a := Net.achievements
	if owned.has("sportfisher"):
		a.unlock("SPORTFISHER")
	if best_run >= 1:
		a.unlock("QUOTA")
	if best_run >= 3:
		a.unlock("THREE_QUOTAS")


func _testing() -> bool:
	if DisplayServer.get_name() == "headless" or "--shot" in " ".join(OS.get_cmdline_user_args()):
		return true
	for a in OS.get_cmdline_args():
		if a.contains("tests/"):
			return true
	return sea != null and sea.get_parent() != get_tree().root


## The career from its file (or the old bank file, the first time); missing, unreadable or newer: a fresh one.
func _load() -> void:
	best = 0
	best_run = 0
	_new_run()
	if save_path.is_empty():
		return
	var from := save_path
	if save_path == SAVE and not FileAccess.file_exists(SAVE) and FileAccess.file_exists(OLD_SAVE):
		from = OLD_SAVE
	var cfg := ConfigFile.new()
	if cfg.load(from) != OK:
		if FileAccess.file_exists(from):
			push_warning("Career: %s won't read; a fresh start" % from)
		return
	var v: Variant = cfg.get_value("career", "version", 0)
	var o: Variant = cfg.get_value("trips", "owned", ["skiff"])
	var g: Variant = cfg.get_value("trips", "gear", [])
	var k := str(cfg.get_value("trips", "kind", "skiff"))
	if not (v is int) or int(v) > VERSION or (int(v) < 1 and from != OLD_SAVE) or not (o is Array) \
			or not (g is Array) or not Kinds.KINDS.has(k):
		push_warning("Career: %s isn't one this game reads; a fresh start" % from)
		return
	bank = int(_number(cfg, "trips", "bank", START_CASH))
	best = int(_number(cfg, "trips", "best", 0))
	owned = ["skiff"]
	for x: Variant in o:
		if Kinds.KINDS.has(str(x)) and not owned.has(str(x)):
			owned.append(str(x))
	gear = []
	for x: Variant in g:
		if GEAR.has(str(x)) and not gear.has(str(x)):
			gear.append(str(x))
	kind = k
	best_run = int(_number(cfg, "run", "best_run", 0))
	if cfg.has_section_key("run", "quota"):
		quota_n = maxi(int(_number(cfg, "run", "quota_n", 1)), 1)
		quota = int(_number(cfg, "run", "quota", quota_for(quota_n)))
		earned = int(_number(cfg, "run", "earned", 0))
		day = clampi(int(_number(cfg, "run", "day", 1)), 1, DAYS)
		run_fish = int(_number(cfg, "run", "run_fish", 0))
		run_biggest = float(_number(cfg, "run", "run_biggest", 0.0))
	# (else a save from before the quota: its bank, boats and gear; the first quota starts now)
	fuel = clampf(float(_number(cfg, "boat", "fuel", fuel)), 0.0, 1.0)
	ice = maxi(int(_number(cfg, "boat", "ice", 0)), 0)
	well = clampi(int(_number(cfg, "boat", "well", 0)), 0, WELL_MAX)
	var at_sea: Variant = cfg.get_value("run", "at_sea", false)
	if at_sea is bool and at_sea:
		_abandoned = true


## A number from the career's file (anything else there, from a hand-edited or broken file: `default`).
static func _number(cfg: ConfigFile, section: String, key: String, default: float) -> float:
	var v: Variant = cfg.get_value(section, key, default)
	return float(v) if (v is int or v is float) and is_finite(float(v)) else default


## Host: the career into its file (not Rivals', not a host's we're crewing for, not in tests).
func _save() -> void:
	if save_path.is_empty() or not career or _borrowed or not Net.is_host():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("career", "version", VERSION)
	cfg.set_value("trips", "bank", bank)
	cfg.set_value("trips", "best", best)
	cfg.set_value("trips", "owned", owned)
	cfg.set_value("trips", "gear", gear)
	cfg.set_value("trips", "kind", kind)
	cfg.set_value("run", "quota_n", quota_n)
	cfg.set_value("run", "quota", quota)
	cfg.set_value("run", "earned", earned)
	cfg.set_value("run", "day", day)
	cfg.set_value("run", "run_fish", run_fish)
	cfg.set_value("run", "run_biggest", run_biggest)
	cfg.set_value("run", "best_run", best_run)
	cfg.set_value("run", "at_sea", not docked)
	cfg.set_value("boat", "fuel", fuel)
	cfg.set_value("boat", "ice", ice)
	cfg.set_value("boat", "well", well)
	if cfg.save(save_path) != OK:
		push_warning("Career: couldn't write %s" % save_path)


## As the game closes or goes back to the title (the scene goes).
func _exit_tree() -> void:
	_save()


## Rivals on (false): the career saved and set aside, an even fresh start in its place (the boat picked stays).
## Off (true): the career back from its file. Everyone runs it (vs/vs.gd's _switch); the host's books are synced.
func set_career(on: bool) -> void:
	if on == career:
		return
	if not on:
		_save()
		career = false
		var k := kind
		best = 0
		best_run = 0
		_new_run()
		kind = k
	else:
		career = true
		if not _borrowed:
			_load()
			if not owned.has(kind):
				kind = "skiff"      # (a boat picked for Rivals isn't yours to keep)
	sale = {}
	fish = []
	if Net.is_host() and not _borrowed:
		_host_changed()


## Host, at the dock: the career wiped (the board's NEW CAREER): the skiff, START_CASH, the first quota, no bests.
func new_career() -> void:
	if not Net.is_host() or not docked or not career or _borrowed:
		return
	best = 0
	best_run = 0
	_new_run()
	sale = {}
	_abandoned = false
	(sea.get("boat") as Node).call("use_kind", kind)
	_save()
	_host_changed()


## 12345 -> "12,345".
static func _money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
