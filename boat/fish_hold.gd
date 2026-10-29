extends Node
## The catch: fish on deck, fish in the hold, and what the trip's worth.
##
## A fish hauled aboard (tuna/landing.gd) lies across the cockpit. Bleed it (E on it), then ice it (E again: into the
## fish box). A bluefin's price is all in how it was handled, so the sooner the better. Heading in (the Esc menu)
## sells the lot by the kilo at its grade, #1, #2 or #3, worked out from how fast it was landed and how soon it was
## bled and iced; one still on deck sells as it is, warm. The money goes in the bank (kept between games on the
## host's machine) and she heads back out with an empty hold.
##
## The host keeps the books and tells everyone after every change (_sync).

const Tuna := preload("res://tuna/tuna.gd")
const Action := preload("res://core/action.gd")
const SAVE := "user://bluefin.cfg"
## Dollars a kilo for a fish of quality 1 is 0.35 + 0.9 = 1.25 times this; quality 0, 0.35 times.
const PRICE_PER_KG := 18.0
## Where fish lie on deck, in turn (boat-local: across the cockpit, between the chair's footrest and the live well,
## then forward of the chair, over the fish box). More than that and they're piled on top.
const SPOTS: Array[Vector3] = [Vector3(0.0, 0.55, 5.75), Vector3(0.0, 0.55, 3.45), Vector3(0.0, 0.55, 2.55),
		Vector3(0.0, 0.55, 1.85)]

var sea: Node                 # sea/sea.gd
## This trip's fish: {id, kg, fight_s (hooked to aboard), aboard_t (sea clock), bled_s and iced_s (s after it came
## aboard; -1: not yet), spot}.
var fish: Array = []
var bank := 0
var best := 0
## The last sale, shown till she heads back out: {lines: [[kg, grade, dollars]], total, bank, best}; empty: none.
var sale := {}
var _next_id := 1
var _deck := {}               # fish id -> its Tuna on deck
var _sold_noted := false
## Where the bank's kept (tests point it somewhere else so they don't touch yours).
var save_path := SAVE


func _ready() -> void:
	_load()
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, _state()))
	Net.dropped.connect(func(_reason: String) -> void: _own_boat())
	Net.left.connect(func(was_host: bool) -> void:
		if not was_host:
			_own_boat())
	_rebuild()


## Back on your own boat after crewing for someone: your own bank, an empty hold (theirs stays theirs).
func _own_boat() -> void:
	_load()
	fish = []
	sale = {}
	_rebuild()


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
		elif float(f["iced_s"]) < 0.0:
			f["iced_s"] = since
		_host_changed()
		return


## Host: heads in and sells the catch; the slip stays up till she heads back out.
func head_in() -> void:
	if not Net.is_host():
		return
	var lines := []
	var total := 0
	for f: Dictionary in fish:
		var q := _quality_of(f)
		var dollars := price(float(f["kg"]), q)
		lines.append([float(f["kg"]), grade(q), dollars])
		total += dollars
	bank += total
	best = maxi(best, total)
	sale = {"lines": lines, "total": total, "bank": bank, "best": best}
	fish = []
	_save()
	_host_changed()


## Host: the slip's read, back out to the grounds.
func head_out() -> void:
	if not Net.is_host():
		return
	sale = {}
	_host_changed()


func _host_changed() -> void:
	if Net.in_session():
		_sync.rpc(_state())
	else:
		_sync(_state())


func _state() -> Dictionary:
	return {"fish": fish, "bank": bank, "best": best, "sale": sale, "next": _next_id}


@rpc("authority", "call_local", "reliable")
func _sync(state: Dictionary) -> void:
	fish = state["fish"]
	bank = int(state["bank"])
	best = int(state["best"])
	sale = state["sale"]
	_next_id = int(state["next"])
	_rebuild()
	if sale.is_empty():
		_sold_noted = false
	elif not _sold_noted:
		_sold_noted = true
		_note("Sold: %d fish for $%s. The slip's in the Esc menu." % [(sale["lines"] as Array).size(),
				_money(int(sale["total"]))])


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
	var n := int(f["spot"])
	var spot: Vector3 = SPOTS[n % SPOTS.size()] + Vector3(0.0, 0.3 * floorf(n / float(SPOTS.size())), 0.0)
	# across the cockpit on its side, head to starboard
	t.transform = Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP) * Basis(Vector3(0, 0, 1), PI * 0.5),
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
				return "Ice it: into the fish box"
	return ""


## What to do now, for the HUD (rods.gd shows it when nothing else needs doing).
func hint() -> String:
	for f: Dictionary in fish:
		if float(f["bled_s"]) < 0.0:
			return "A fish on deck: bleed it (E on it), the sooner the better"
	for f: Dictionary in fish:
		if float(f["iced_s"]) < 0.0:
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
	var text := "Hold %d" % held
	if deck > 0:
		text += "   Deck %d" % deck
	if not fish.is_empty():
		text += "   %d kg, worth about $%s" % [roundi(kg), _money(worth())]
	text += "\nBank $%s" % _money(bank)
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
	else:
		bank = 0
		best = 0


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("trips", "bank", bank)
	cfg.set_value("trips", "best", best)
	cfg.save(save_path)


## 12345 -> "12,345".
static func _money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
