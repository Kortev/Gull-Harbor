extends Node
## The trip and the catch: the dock, the day, the boat, the gear, fish on deck and in the hold, and what it's worth.
##
## A game starts at the dock (ui/menu.gd shows it): the bank, which boat (the skiff's yours; the sportfisher can be
## bought, or chartered for the day), gear for sale, and Head out. Out there the day runs from dawn (DAWN_H) to dusk
## (DUSK_H) in DAY seconds, then it's night; head in whenever you like (Esc) and the catch is sold, the fuel and any
## charter taken off, and you're back at the dock.
##
## A fish hauled aboard (tuna/landing.gd) lies across the cockpit, alive: its tail slapping the deck every few seconds
## till it's bled. Bleed it: the knife in your hands (crew/hands.gd), left mouse held on it BLEED_HOLD s (a ring fills
## round your sight, the knife working, the fish thrashing); let go early and nothing's done. Then the blood: a spurt
## at the gills and a pool spreading out over the deck under it, and a last few kicks fading to still. Words under
## your sight say what it wants next (the knife, then the gaff and the box). Then into the fish box (her kind's `box`, a hatch in her sole): E on the lid opens it, the gaff in
## your hands and left mouse on the fish hooks it, and you drag it across the deck (slow going with a big one) and
## let go over the open box: it drops in on the ice. A bluefin's price is all in how it was handled, so the sooner
## the better. Heading in (the Esc menu)
## sells the lot by the kilo at its grade, #1, #2 or #3, worked out from how fast it was landed and how soon it was
## bled and iced; one still on deck sells as it is, warm. The money goes in the bank (kept between games on the
## host's machine) and she heads back out with an empty hold.
##
## The run (Lethal Company's quota): the crew owes the bank for the boat. Each quota is a sum to sell within DAYS
## trips (one a day). Every fish sold counts toward it and goes in the bank to spend at the dock. Make the quota by
## the last day's sale and there's a bigger one (quota_for); miss it and the bank takes the boat: the run's over,
## its story on the slip, and a new one starts from the skiff and START_CASH.
##
## The host keeps the books and tells everyone after every change (_sync).

const Tuna := preload("res://tuna/tuna.gd")
const Action := preload("res://core/action.gd")
const Kinds := preload("res://boat/kinds.gd")
const Sfx := preload("res://audio/sfx.gd")
const SAVE := "user://bluefin.cfg"
const TEST_SAVE := "user://bluefin_test.cfg"
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
	"bait": {"name": "A live-bait well", "blurb": "Keeps mackerel alive: four aboard each trip, and the ones you jig. "
			+ "A live bait gets half as many bites again and lasts twice as long.", "price": 1500},
}
## Bait for the trip: live mackerel in the well (with the well: WELL_START each trip, WELL_MAX jigged), and scoops
## of chum in the bucket (CHUM each trip: boat/chum.gd).
const WELL_START := 4
const WELL_MAX := 8
const CHUM := 24
## Where fish lie on deck comes from the boat's kind (boat/kinds.gd's spots: x, y, z, and 1 across her or 0 along
## her), in turn; more than that and they're piled on top. Her fish box takes her kind's `hold` iced.

var sea: Node                 # sea/sea.gd
## This trip's fish: {id, kg, fight_s (hooked to aboard), aboard_t (sea clock), bled_s and iced_s (s after it came
## aboard; -1: not yet), spot}.
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
## This trip's live mackerel in the well, and scoops of chum left.
var well := 0
var chum := 0
var _dusk_noted := 0
## The last sale, shown till she heads back out: {lines: [[kg, grade, dollars]], total, bank, best}; empty: none.
var sale := {}
var _next_id := 1
var _deck := {}               # fish id -> its Tuna on deck
var _sold_noted := false
var _heard := {}              # fish id -> [bled, iced] last time (_hear_work)
## Bleeding: how long the knife's held on a fish (s); the one you're bleeding (-1 none) and how far through.
const BLEED_HOLD := 1.1
var _bleeding := -1
var _bleed_t := 0.0
var _bleed_ring: Control
## Each fish on deck's life: when its next kick is (s), and when it was bled (the sea clock, -1 not yet) for its last.
var _kick_in := {}
var _bled_at := {}
## The fish box's lid, open or shut (the host's word), as drawn (0 shut .. 1 open); and the fish being dragged on the
## gaff: yours (its id, -1 none) and everyone's, as their peers last said ({id: [at (boat-local), yaw]}).
var box_open := false
var _lid_k := 0.0
var _lid: Node3D
var _inside: Node3D
var _dragging := -1
var _drag_send := 0.0
var _dragged := {}
## The last game ended out at sea (quit, or the host dropped): that day's gone, settled as an empty trip (_ready).
var _abandoned := false
## Where the bank's kept (tests point it somewhere else so they don't touch yours).
var save_path := SAVE


func _ready() -> void:
	if sea.get_parent() != get_tree().root or "--shot" in " ".join(OS.get_cmdline_user_args()):
		# (a test, which builds the sea under its own node, or a screenshot: a clean bank of its own, never yours)
		save_path = TEST_SAVE
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_load()
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
	Net.dropped.connect(func(_reason: String) -> void: _own_boat())
	Net.left.connect(func(was_host: bool) -> void:
		if not was_host:
			_own_boat())
	_rebuild()
	if _abandoned and Net.is_host():
		# (no ducking a quota by quitting before the last day's sale: the day counts, the fuel's owed, nothing sold)
		_abandoned = false
		docked = false
		head_in()
		sale["abandoned"] = true
		_host_changed()
	if docked:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE     # (a game starts at the dock: its screen's up)


## Back on your own boat after crewing for someone: your own bank and gear, an empty hold (theirs stays theirs),
## at the dock.
func _own_boat() -> void:
	_load()
	fish = []
	sale = {}
	docked = true
	_rebuild()
	_dock_changed(true)
	(sea.get("boat") as Node).call("use_kind", kind)


func _process(delta: float) -> void:
	_drag(delta)
	_show_box(delta)
	_knife(delta)
	_throes(delta)
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

## How well a fish was handled, 0..1: landed fast (for its size), bled soon, iced soon.
static func quality(kg: float, fight_s: float, bled_s: float, iced_s: float) -> float:
	var q := 0.5
	var goal := 40.0 + kg * 0.38            # (tuna/fight.gd: how long it takes to tire, fought right)
	q += 0.2 * clampf((5.0 * goal - fight_s) / (3.5 * goal), 0.0, 1.0)
	if bled_s >= 0.0:
		q += 0.15 if bled_s <= 60.0 else (0.08 if bled_s <= 180.0 else 0.03)
	if iced_s >= 0.0:
		q += 0.15 if iced_s <= 180.0 else (0.07 if iced_s <= 600.0 else 0.02)
	else:
		q -= 0.1                             # (sold off the deck, warm)
	return clampf(q, 0.0, 1.0)


static func grade(q: float) -> String:
	return "#1" if q >= 0.85 else ("#2" if q >= 0.65 else "#3")


static func price(kg: float, q: float) -> int:
	return roundi(kg * PRICE_PER_KG * (0.35 + 0.9 * q))


func _quality_of(f: Dictionary) -> float:
	return quality(float(f["kg"]), float(f["fight_s"]), float(f["bled_s"]), float(f["iced_s"]))


## What the catch would fetch if she headed in now.
func worth() -> int:
	var total := 0
	for f: Dictionary in fish:
		total += price(float(f["kg"]), _quality_of(f))
	return total


# ------------------------------------------------------------------ the host

## Host: a fish came aboard (tuna/landing.gd): `fight_s` from the bite to on deck.
func host_add(kg: float, fight_s: float) -> void:
	var used := []
	for f: Dictionary in fish:
		if float(f["iced_s"]) < 0.0:
			used.append(int(f["spot"]))
	var spot := 0
	while used.has(spot):
		spot += 1
	fish.append({"id": _next_id, "kg": kg, "fight_s": fight_s, "aboard_t": _now(), "bled_s": -1.0, "iced_s": -1.0,
			"spot": spot})
	_next_id += 1
	_host_changed()


@rpc("any_peer", "call_remote", "reliable")
func _ask_work(id: int) -> void:
	_work(id)


## Bleeds fish `id` if it isn't yet, else ices it (host).
func _work(id: int) -> void:
	for f: Dictionary in fish:
		if int(f["id"]) != id:
			continue
		var since := _now() - float(f["aboard_t"])
		if float(f["bled_s"]) < 0.0:
			f["bled_s"] = since
		elif float(f["iced_s"]) < 0.0 and iced() < capacity():
			f["iced_s"] = since
		_host_changed()
		return


## Bleeds fish `id` (the knife), or drops it in the fish box (`ice`: it was let go over the open box) (host).
func _bleed(id: int) -> void:
	for f: Dictionary in fish:
		if int(f["id"]) == id and float(f["bled_s"]) < 0.0:
			f["bled_s"] = _now() - float(f["aboard_t"])
			_host_changed()
			return


@rpc("any_peer", "call_remote", "reliable")
func _ask_bleed(id: int) -> void:
	_bleed(id)


## Host: fish `id` let go off the gaff at `at` (boat-local), lying `yaw`: in the fish box if it's open and that's
## over it (and there's room), else on the deck there.
@rpc("any_peer", "call_remote", "reliable")
func _ask_drop(id: int, at: Vector3, yaw: float) -> void:
	for f: Dictionary in fish:
		if int(f["id"]) != id or float(f["iced_s"]) >= 0.0:
			continue
		if box_open and over_box(at) and iced() < capacity():
			f["iced_s"] = _now() - float(f["aboard_t"])
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


## Host: heads in and sells the catch, the fuel and any charter taken off; back at the dock with the slip up.
## `late`: she missed the race home at dusk (sea/sea.gd) and was towed in: the buyers have gone, the cannery pays half.
func head_in(late := false) -> void:
	if not Net.is_host() or docked:
		return
	var lines := []
	var total := 0
	for f: Dictionary in fish:
		var q := _quality_of(f)
		var dollars := price(float(f["kg"]), q) / (2 if late else 1)
		lines.append([float(f["kg"]), grade(q), dollars])
		total += dollars
	var costs := []
	var spec: Dictionary = Kinds.spec(kind)
	costs.append(["Fuel", int(spec.get("fuel", 0))])
	if not owned.has(kind):
		costs.append(["Charter, %s" % str(spec.get("name", "her")), CHARTER])
	for c: Array in costs:
		total -= int(c[1])
	(sea.get("rods") as Node).call("host_clear")
	(sea.get("landing") as Node).call("host_clear")
	var gross := 0
	for l: Array in lines:
		gross += int(l[2])
		run_fish += 1
		run_biggest = maxf(run_biggest, float(l[0]))
	bank += total
	best = maxi(best, total)
	earned += gross
	sale = {"lines": lines, "costs": costs, "total": total, "bank": bank, "best": best,
			"quota": [quota_n, earned, quota, day], "verdict": "", "late": late}
	fish = []
	docked = true
	_settle()
	_save()
	if sea.has_method("moor"):
		sea.call("moor")      # (VS: each side's own hold has no pier to tie up at)
	_host_changed()


## Host, after a sale: the quota's last day done, it's made (a bigger one, three more days) or the bank takes the boat
## (the run's story on the slip, and a new run). Otherwise just the next day.
func _settle() -> void:
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
	sale = {}
	docked = false
	trip_t0 = _now()
	well = WELL_START if has_gear("bait") else 0
	chum = CHUM
	(sea.get("boat") as Node).call("use_kind", kind)
	_save()
	_host_changed()
	(sea.get("rods") as Node).call("host_baits_out")


## Host, at the dock: the boat she'll take.
func pick(k: String) -> void:
	if Net.is_host() and docked:
		kind = k
		(sea.get("boat") as Node).call("use_kind", kind)      # (there she is, alongside the dock)
		if sea.has_method("moor"):
			sea.call("moor")
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


## Host: a live mackerel out of the well for a bait (false: none, or no well).
func host_take_live() -> bool:
	if docked or not has_gear("bait") or well <= 0:
		return false
	well -= 1
	_host_changed()
	return true


## Host: a jigged mackerel into the well (false: no well, or it's full).
func host_add_live() -> bool:
	if docked or not has_gear("bait") or well >= WELL_MAX:
		return false
	well += 1
	_host_changed()
	return true


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
	return {"fish": fish, "bank": bank, "best": best, "sale": sale, "next": _next_id, "docked": docked, "box": box_open,
			"trip_t0": trip_t0, "kind": kind, "owned": owned, "gear": gear, "well": well, "chum": chum,
			"quota_n": quota_n, "quota": quota, "earned": earned, "day": day, "run_fish": run_fish,
			"run_biggest": run_biggest, "best_run": best_run}


@rpc("authority", "call_local", "reliable")
func _sync(state: Dictionary) -> void:
	fish = state["fish"]
	bank = int(state["bank"])
	best = int(state["best"])
	sale = state["sale"]
	_next_id = int(state["next"])
	var was := docked
	_hear_work()
	docked = bool(state.get("docked", docked))
	if docked and not was and sea.has_method("arrive") and sea.get_parent() == get_tree().root:
		sea.call("arrive")
	box_open = bool(state.get("box", box_open))
	trip_t0 = float(state.get("trip_t0", trip_t0))
	kind = str(state.get("kind", kind))
	owned = state.get("owned", owned)
	gear = state.get("gear", gear)
	well = int(state.get("well", well))
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
	if sale.is_empty():
		_sold_noted = false
	elif not _sold_noted:
		_sold_noted = true
		Sfx.play("kit.coins")


## The sounds of the work on deck, from what's newly done to each fish since last time: a bleed (a wet slap), the
## fish box lid (a clank). (Before the deck's rebuilt, while an iced fish still lies there.)
func _hear_work() -> void:
	for f: Dictionary in fish:
		var id := int(f["id"])
		var done := [float(f["bled_s"]) >= 0.0, float(f["iced_s"]) >= 0.0]
		var was: Array = _heard.get(id, [false, false])
		var node := _deck.get(id) as Node3D
		if node != null and _heard.has(id):
			if done[0] and not bool(was[0]):
				Sfx.play_point(self, node.global_position, "dock.slap", 0.8, 0.55)
			elif done[1] and not bool(was[1]):
				Sfx.play_point(self, node.global_position, "kit.clank")
		_heard[id] = done


## In to the dock, or out to the grounds: the dock screen comes up (the mouse freed for it), or goes and you're
## aboard; the dusk notes start over.
func _dock_changed(now_docked: bool) -> void:
	_dusk_noted = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if now_docked else Input.MOUSE_MODE_CAPTURED


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
			if id == _dragging:
				_let_go(false)
	_tally()


func _lay(f: Dictionary, boat: Node3D) -> Node3D:
	var id := int(f["id"])
	var t := Tuna.new(float(f["kg"]))
	t.name = "OnDeck%d" % id
	t.posed = true
	t.effort = 0.0
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
	# (the pool lies flat on the deck under the fish, whatever way the fish is turned)
	blood.global_transform = boat.global_transform * Transform3D(Basis.IDENTITY, spot + Vector3(0.0, 0.003, 0.0))
	var act := Action.new(Vector3(0.6, 0.5, t.length))
	act.name = "Handle"
	act.use_with = func(p: Node, item: String, pressed: bool) -> bool: return _handle(id, p, item, pressed)
	act.prompt = func() -> String: return _fish_prompt(id)
	t.add_child(act)
	# (the blood stays where it was bled, not under a fish dragged off it)
	blood.top_level = true
	blood.global_transform = boat.global_transform * Transform3D(Basis.IDENTITY, spot + Vector3(0.0, 0.003, 0.0))
	return t


## A fish lying on its side on her deck at `at` (boat-local), its head toward `yaw` + PI (toward you, dragging it).
func _lying(t: Node3D, at: Vector3, yaw: float) -> Transform3D:
	var head := Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 1.0)
	var deck := float(((sea.get("boat") as Node).get("spec") as Dictionary).get("deck", 0.5))
	return Transform3D(Basis.looking_at(head, Vector3.UP) * Basis(Vector3(0, 0, 1), PI * 0.5),
			Vector3(at.x, deck, at.z) + Vector3(0.0, float(t.get("length")) * 0.07, 0.0))


## Left mouse on fish `id` with something in your hands: the knife bleeds it; the gaff hooks it to drag (let go to
## drop it).
func _handle(id: int, p: Node, item: String, pressed: bool) -> bool:
	match item:
		"knife":
			if not pressed:
				_bleeding = -1          # (let go early: nothing done)
				return true
			for f: Dictionary in fish:
				if int(f["id"]) == id and float(f["bled_s"]) < 0.0:
					_bleeding = id
					_bleed_t = 0.0
					p.call("gesture", "bleed")
			return true
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


## The knife held on a fish: the ring fills, the knife works, the fish fights it; held to the end, it's bled.
func _knife(delta: float) -> void:
	if _bleeding < 0 or not _deck.has(_bleeding):
		_bleeding = -1
		if _bleed_ring:
			_bleed_ring.visible = false
		return
	var me := (sea.get("crew") as Node).get("me") as Node
	var was := _bleed_t
	_bleed_t += delta
	if me != null and fmod(_bleed_t, 0.4) < fmod(was, 0.4):
		me.call("gesture", "bleed")
	(_deck[_bleeding] as Node).set("effort", 1.4)
	if _bleed_ring == null:
		var layer := CanvasLayer.new()
		layer.layer = 7
		add_child(layer)
		_bleed_ring = Control.new()
		_bleed_ring.set_anchors_preset(Control.PRESET_CENTER)
		_bleed_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bleed_ring.draw.connect(func() -> void:
			var k := clampf(_bleed_t / BLEED_HOLD, 0.0, 1.0)
			_bleed_ring.draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 5.0)
			_bleed_ring.draw_arc(Vector2.ZERO, 18.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, Color(0.9, 0.2, 0.15), 5.0))
		layer.add_child(_bleed_ring)
	_bleed_ring.visible = true
	_bleed_ring.queue_redraw()
	if _bleed_t >= BLEED_HOLD:
		var id := _bleeding
		_bleeding = -1
		_bleed_ring.visible = false
		if Net.is_host():
			_bleed(id)
		else:
			_ask_bleed.rpc_id(1, id)


## The fish on deck alive: a slap of the tail every few seconds till it's bled; bled, a last few kicks fading out, and
## its blood spreading from a spurt to a pool.
func _throes(delta: float) -> void:
	var now := _now()
	for f: Dictionary in fish:
		var id := int(f["id"])
		if not _deck.has(id) or id == _bleeding:
			continue
		var t := _deck[id] as Node3D
		var bled := float(f["bled_s"]) >= 0.0
		if bled and not _bled_at.has(id):
			_bled_at[id] = now
			_spurt(t)
		var since := now - float(_bled_at.get(id, now))
		var life := 1.0 if not bled else clampf(1.0 - since / 8.0, 0.0, 1.0)
		var next := float(_kick_in.get(id, randf_range(0.5, 2.5))) - delta
		var effort := float(t.get("effort"))
		if next <= 0.0 and life > 0.0:
			next = randf_range(2.0, 5.0) * (2.0 - life)
			effort = 1.2 * life
		_kick_in[id] = next
		t.set("effort", move_toward(effort, 0.0, delta * 1.6))
		var blood := t.get_node_or_null("Blood") as Node3D
		if blood and bled:
			var k := clampf(since / 5.0, 0.15, 1.0)
			blood.scale = Vector3(k, 1.0, k)


## Iced: the fish slides down through the open hatch into the box and out of sight, no blink.
func _slide_in(t: Node3D, boat: Node3D) -> void:
	var box: Vector3 = (boat.get("spec") as Dictionary).get("box", t.position)
	var blood := t.get_node_or_null("Blood")
	if blood:
		blood.reparent(boat)        # (the pool stays on deck where it was bled)
	var tw := t.create_tween()
	tw.tween_property(t, "position", Vector3(box.x, t.position.y, box.z), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t, "position", Vector3(box.x, box.y - 0.9, box.z), 0.45).set_trans(Tween.TRANS_QUAD) 			.set_ease(Tween.EASE_IN)
	tw.tween_callback(t.queue_free)


## A spurt of blood off the gills, once, as it's bled.
func _spurt(t: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.85
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.03, 0.04)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = t.global_position + t.global_basis * Vector3(0.0, 0.0, -float(t.get("length")) * 0.3)
	p.emitting = true
	Sfx.play_point(self, p.global_position, "kit.thud", 0.5, 1.6)
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## What a fish on deck wants next, in words under your sight (KEY|words: the key cap and what it does).
func _fish_prompt(id: int) -> String:
	var hands: Node = ((sea.get("crew") as Node).get("me") as Node).get("hands") if (sea.get("crew") as Node).get("me") else null
	var held := str(hands.get("item")) if hands else ""
	for f: Dictionary in fish:
		if int(f["id"]) != id:
			continue
		if float(f["bled_s"]) < 0.0:
			return "HOLD LMB|BLEED HIM, QUICK" if held == "knife" else "1|THE KNIFE: BLEED HIM"
		return "HOLD LMB|DRAG HIM TO THE FISH BOX" if held == "gaff" else "2|THE GAFF: INTO THE FISH BOX"
	return ""


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


## The fish box: its lid over the hatch in her sole (E on it to open or shut it), and inside, ice and the tails of
## the fish iced down in it (again whenever she's rebuilt).
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
	var act := Action.new(Vector3(size.x, 0.25, size.y))
	act.name = "Lid"
	act.position = Vector3(0.0, 0.1, size.y * 0.5)
	act.use = func(_p: Node) -> void:
		if Net.is_host():
			_ask_lid(not box_open)
		else:
			_ask_lid.rpc_id(1, not box_open)
	act.prompt = func() -> String: return "" if docked else ("Shut" if box_open else "Open")
	_lid.add_child(act)
	# inside: the dark of the box, the ice, and a tail up out of the ice for each fish in it
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
	ice.material_override = _flat(Color(0.78, 0.86, 0.9))
	ice.position.y = 0.002
	_inside.add_child(ice)
	var tail := PrismMesh.new()
	tail.size = Vector3(0.32, 0.22, 0.02)
	for i in 6:
		var t := MeshInstance3D.new()
		t.name = "Tail%d" % i
		t.mesh = tail
		t.material_override = _flat(Color(0.14, 0.18, 0.28))
		t.position = Vector3((float(i % 3) - 1.0) * size.x * 0.3, 0.1, (float(i / 3) - 0.5) * size.y * 0.4)
		t.rotation = Vector3(0.0, 0.4 * float(i % 2) - 0.2, PI)
		_inside.add_child(t)


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m


## The lid swinging to the host's word (a clank as it lands either way), and the fish in the box seen when it's open.
func _show_box(delta: float) -> void:
	if not is_instance_valid(_lid):
		return
	var was := _lid_k
	_lid_k = move_toward(_lid_k, 1.0 if box_open else 0.0, delta * 2.5)
	_lid.rotation.x = -1.85 * smoothstep(0.0, 1.0, _lid_k)
	_inside.visible = _lid_k > 0.02
	if was != _lid_k and (_lid_k == 0.0 or _lid_k == 1.0):
		Sfx.play_point(self, _lid.global_position, "kit.clank", 0.7, 1.0 if _lid_k == 0.0 else 1.2)
	var n := iced()
	for i in 6:
		(_inside.get_node("Tail%d" % i) as Node3D).visible = i < n


## What to do now, for the HUD (rods.gd shows it when nothing else needs doing): the fish on deck show it
## themselves (lying there, bled or not); only a full box wants saying.
func hint() -> String:
	for f: Dictionary in fish:
		if float(f["iced_s"]) < 0.0 and iced() >= capacity():
			return "Fish box full   Esc to sell"
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
	hud.call("tally", {"day": day, "days": DAYS, "box": held, "cap": capacity(), "deck": deck, "earned": earned,
			"quota": quota, "aboard": worth(), "earned_text": "$" + _money(earned), "quota_text": "$" + _money(quota)})


# ------------------------------------------------------------------ odds and ends

func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _note(text: String) -> void:
	var crew := sea.get("crew") as Node
	(crew.get("hud") as Node).call("notify", text)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		bank = int(cfg.get_value("trips", "bank", 0))
		best = int(cfg.get_value("trips", "best", 0))
		owned = cfg.get_value("trips", "owned", ["skiff"])
		gear = cfg.get_value("trips", "gear", [])
		kind = str(cfg.get_value("trips", "kind", "skiff"))
		best_run = int(cfg.get_value("run", "best_run", 0))
		if cfg.has_section_key("run", "quota"):
			quota_n = int(cfg.get_value("run", "quota_n", 1))
			quota = int(cfg.get_value("run", "quota", quota_for(1)))
			earned = int(cfg.get_value("run", "earned", 0))
			day = int(cfg.get_value("run", "day", 1))
			run_fish = int(cfg.get_value("run", "run_fish", 0))
			run_biggest = float(cfg.get_value("run", "run_biggest", 0.0))
		else:
			# (a save from before the quota: keep its bank, boats and gear; the first quota starts now)
			quota_n = 1
			quota = quota_for(1)
			earned = 0
			day = 1
			run_fish = 0
			run_biggest = 0.0
		if bool(cfg.get_value("run", "at_sea", false)):
			_abandoned = true
	else:
		best = 0
		best_run = 0
		_new_run()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
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
	cfg.save(save_path)


## 12345 -> "12,345".
static func _money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
