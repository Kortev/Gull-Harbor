extends Node
## The trip and the catch: the dock, the day, the boat, the gear, fish on deck and in the hold, and what it's worth.
##
## A game starts at the dock (ui/menu.gd shows it): the bank, which boat (the skiff's yours; the sportfisher can be
## bought, or chartered for the day), gear for sale, and Head out. Out there the day runs from dawn (DAWN_H) to dusk
## (DUSK_H) in DAY seconds, then it's night; head in whenever you like (Esc) and the catch is sold, the fuel and any
## charter taken off, and you're back at the dock.
##
## A fish hauled aboard (tuna/landing.gd) lies across the cockpit. Bleed it (E on it), then ice it (E again: into the
## fish box). A bluefin's price is all in how it was handled, so the sooner the better. Heading in (the Esc menu)
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
	"harness": {"name": "A fighting harness", "blurb": "Your back takes the load: your arms tire a third slower.",
			"price": 2500},
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
## Where the bank's kept (tests point it somewhere else so they don't touch yours).
var save_path := SAVE


func _ready() -> void:
	if sea.get_parent() != get_tree().root:
		# (a test, which builds the sea under its own node: a clean bank of its own, never yours)
		save_path = TEST_SAVE
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_load()
	(sea.get("boat") as Node).connect("rebuilt", func() -> void:
		# (another boat: lay what's on deck out again on her)
		for id: int in _deck.keys():
			(_deck[id] as Node).queue_free()
		_deck.clear()
		_rebuild())
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, _state()))
	Net.dropped.connect(func(_reason: String) -> void: _own_boat())
	Net.left.connect(func(was_host: bool) -> void:
		if not was_host:
			_own_boat())
	_rebuild()
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


func _process(_delta: float) -> void:
	# the light going: once at dusk, once at dark
	if docked:
		return
	var t := day_fraction()
	if t > 0.85 and _dusk_noted < 1:
		_dusk_noted = 1
		_note("The sun's getting low. Head in to sell before dark (Esc), or fish on into the night")
	elif t > 1.0 and _dusk_noted < 2:
		_dusk_noted = 2
		_note("Night. Head in when you're ready (Esc)")
	_tally()


# ------------------------------------------------------------------ the day

## How far through the day she is: 0 at dawn, 1 at dusk, more into the night (0 at the dock).
func day_fraction() -> float:
	return 0.0 if docked else maxf(_now() - trip_t0, 0.0) / DAY


## How light it is, 0 (night) .. 1 (full day): first light at the dock, up with the sun, down at dusk.
func daylight() -> float:
	if docked:
		return 0.55
	var t := day_fraction()
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


## How many are iced in the fish box, and how many it takes (her kind's).
func iced() -> int:
	var n := 0
	for f: Dictionary in fish:
		n += 1 if float(f["iced_s"]) >= 0.0 else 0
	return n


func capacity() -> int:
	return int(((sea.get("boat") as Node).get("spec") as Dictionary).get("hold", 12))


## Host: heads in and sells the catch, the fuel and any charter taken off; back at the dock with the slip up.
func head_in() -> void:
	if not Net.is_host() or docked:
		return
	var lines := []
	var total := 0
	for f: Dictionary in fish:
		var q := _quality_of(f)
		var dollars := price(float(f["kg"]), q)
		lines.append([float(f["kg"]), grade(q), dollars])
		total += dollars
	var costs := []
	var spec: Dictionary = (sea.get("boat") as Node).get("spec")
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
			"quota": [quota_n, earned, quota, day], "verdict": ""}
	fish = []
	docked = true
	_settle()
	_save()
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
	return {"fish": fish, "bank": bank, "best": best, "sale": sale, "next": _next_id, "docked": docked,
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
		_note("Sold: %d fish for $%s." % [(sale["lines"] as Array).size(), _money(int(sale["total"]))])


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
		if not _deck.has(id):
			_deck[id] = _lay(f, boat)
		var blood := (_deck[id] as Node).get_node_or_null("Blood") as Node3D
		if blood:
			blood.visible = float(f["bled_s"]) >= 0.0
	for id: int in _deck.keys():
		if not keep.has(id):
			(_deck[id] as Node).queue_free()
			_deck.erase(id)
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
	# on its side: across her, head to starboard, or along her, head forward
	var head := Vector3.RIGHT if at.w > 0.5 else Vector3.FORWARD
	t.transform = Transform3D(Basis.looking_at(head, Vector3.UP) * Basis(Vector3(0, 0, 1), PI * 0.5),
			spot + Vector3(0.0, t.length * 0.07, 0.0))
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
	act.use = func(_p: Node) -> void:
		if Net.is_host():
			_work(id)
		else:
			_ask_work.rpc_id(1, id)
	act.prompt = func() -> String: return _prompt(id)
	t.add_child(act)
	return t


func _prompt(id: int) -> String:
	for f: Dictionary in fish:
		if int(f["id"]) == id:
			if float(f["bled_s"]) < 0.0:
				return "Bleed it (%d kg)" % roundi(float(f["kg"]))
			if float(f["iced_s"]) < 0.0:
				return "Ice it: into the fish box" if iced() < capacity() else "The fish box is full: head in and sell"
	return ""


## What to do now, for the HUD (rods.gd shows it when nothing else needs doing).
func hint() -> String:
	for f: Dictionary in fish:
		if float(f["bled_s"]) < 0.0:
			return "A fish on deck: bleed it (E on it), the sooner the better"
	for f: Dictionary in fish:
		if float(f["iced_s"]) < 0.0:
			if iced() >= capacity():
				return "The fish box is full: head in and sell (Esc), or it sells warm off the deck"
			return "Ice it: E on the fish puts it in the fish box"
	return ""


func _tally() -> void:
	var crew := sea.get("crew") as Node
	if crew == null or crew.get("hud") == null:
		return
	var hud := crew.get("hud") as Node
	var held := 0
	var kg := 0.0
	var deck := 0
	for f: Dictionary in fish:
		if float(f["iced_s"]) >= 0.0:
			held += 1
		else:
			deck += 1
		kg += float(f["kg"])
	var text := "Fish box %d/%d" % [held, capacity()]
	if not docked:
		text = "Day %d of %d   %s   %s" % [day, DAYS, clock_text(), text]
	if deck > 0:
		text += "   Deck %d" % deck
	if not fish.is_empty():
		text += "   %d kg, worth about $%s" % [roundi(kg), _money(worth())]
	if not docked:
		text += "\nChum %d" % chum + ("   Live bait %d/%d" % [well, WELL_MAX] if has_gear("bait") else "")
	text += "\nQuota $%s / $%s" % [_money(earned), _money(quota)]
	if not fish.is_empty() and earned < quota:
		text += "  (+$%s aboard)" % _money(worth())
	text += "   Bank $%s" % _money(bank)
	hud.call("tally", text)


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
			_new_run()        # (a save from before the quota: a run from the start)
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
	cfg.save(save_path)


## 12345 -> "12,345".
static func _money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
