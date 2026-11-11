extends Node
## A hoist, a pump and an ice bin at each of the harbour's four berths (sea/station.gd, sea/places.gd), headless.
## Where the kit stands, for a skiff and for a sportfisher at each berth: her fish box under the davit's arm, her filler
## in the hose's reach, and on the town float (C's and D's, the float between them) a clear walk down each edge past
## it. Then Rivals with four boats, in each kind: each station finds its own boat and her books, a fish in each boat's
## box goes up on her own hoist and onto her own slip and nobody else's, each pump fills its own boat's tank, each bin
## gives a scoop of ice that goes into her box. And back in the career the four of them leave the one boat's alone.
## Run: godot --headless --fixed-fps 30 --path . res://tests/stations_n_test.tscn

const Sea := preload("res://sea/sea.gd")
const Quay := preload("res://sea/quay.gd")
const Kinds := preload("res://boat/kinds.gd")
const Station := preload("res://sea/station.gd")
const Action := preload("res://core/action.gd")
const NAMES := "ABCD"

var sea: Sea
var fails: Array[String] = []


func _ready() -> void:
	Settings.prep["rivals"] = "full"
	Settings.prep["career"] = "full"
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var stations: Array = sea.places.stations
	_check(stations.size() == 4, "a station at each of the four berths (%d)" % stations.size())
	if stations.size() != 4:
		_done()
		return
	_places(stations)
	for kind: String in ["skiff", "sportfisher"]:
		await _rivals(stations, kind)
	await _career(stations)
	_done()


## Where it all stands, by the numbers: each kind of boat at each berth.
func _places(stations: Array) -> void:
	var harbour := sea.harbour
	var q: Quay = harbour.quay
	for kind: String in ["skiff", "sportfisher"]:
		var spec := Kinds.spec(kind)
		var half := float(spec["beam"]) * 0.5
		for i in 4:
			var st: Station = stations[i]
			var at: Vector2 = harbour.berth_at(i, half, float(spec["length"]))
			var way: float = harbour.berth_way(at)
			var box: Vector3 = spec["box"]
			var d := Vector2(at.x + box.x - st.davit.x, at.y + box.z - st.davit.z).length()
			_check(d > 1.5 and d < Station.REACH - 1.0, "%s at %s: her fish box under the davit's arm (%.1f m of %.1f)" % [
					kind, NAMES[i], d, Station.REACH])
			# (her filler: the second point of her rail, on the float's side)
			var rail: Vector3 = (spec["rail"] as Array)[1]
			var fill := Vector3(at.x - way * (absf(rail.x) - 0.15), rail.y, at.y + rail.z)
			_check(fill.distance_to(st.pump_at) < Station.HOSE - 1.0, "%s at %s: her filler in the hose's reach (%.1f m of %.0f)" % [
					kind, NAMES[i], fill.distance_to(st.pump_at), Station.HOSE])
			# her side of her float: the kit nearer her than any other boat's
			_check((st.davit.x - at.x) * way < 0.0 and absf(st.davit.x - at.x) < half + 6.0,
					"%s at %s: the davit on her own float, on her side of it" % [kind, NAMES[i]])
	# the town float's two: on the float (not in the water, not on the brow), a walk clear down each edge past the
	# davit and the tote, the pump and the bin out of the way beside the brow
	var foot: Vector3 = q.brows[0][0]
	for i in [2, 3]:
		var st: Station = stations[i]
		var edge := Quay.TOWN_X + (-1.0 if i == 2 else 1.0) * Quay.TOWN_W * 0.5
		var on_it := true
		for p: Vector3 in [st.davit, st.scale_at, st.pump_at, st.bin_at, st.buyer_at]:
			on_it = on_it and absf(p.x - Quay.TOWN_X) < Quay.TOWN_W * 0.5 - 0.3 and p.z < q.town_face() - Quay.FLOAT_GAP \
					and p.z > q.town_face() - Quay.TOWN_OUT and absf(p.y - Quay.FLOAT_Y) < 0.01
		_check(on_it, "%s's kit stands on the town float" % NAMES[i])
		var lane := minf(absf(edge - st.davit.x) - 0.2, absf(edge - st.scale_at.x) - 0.6)
		_check(lane >= 1.2 and st.davit.z < foot.z - 2.0 and st.scale_at.z + 1.0 < foot.z - 2.0,
				"%s's hoist and tote leave %.1f m of deck along her edge, and stand clear of the brow's foot" % [NAMES[i], lane])
		_check(st.pump_at.z > foot.z + 0.4 and st.bin_at.z > foot.z + 0.4 and absf(st.pump_at.x - foot.x) > Quay.FLOAT_W * 0.25 + 0.3
				and absf(st.bin_at.x - foot.x) > Quay.FLOAT_W * 0.25 + 0.5,
				"%s's pump and bin beside the brow, not on it nor in the way off its foot" % NAMES[i])
		var clear := true
		for k in q.steps.size():
			if q.step_ways[k] == (-1.0 if i == 2 else 1.0) and absf(q.steps[k].x - edge) < 1.0:
				for p: Vector3 in [st.davit, st.scale_at, st.pump_at, st.bin_at]:
					clear = clear and Vector2(p.x - q.steps[k].x, p.z - q.steps[k].z).length() > 1.2
		for c: Vector3 in q.cleats:
			for p: Vector3 in [st.davit, st.scale_at, st.pump_at, st.bin_at]:
				clear = clear and Vector2(p.x - c.x, p.z - c.z).length() > 0.8
		_check(clear, "%s's kit clear of the boarding steps and the cleats" % NAMES[i])
	_check((stations[2] as Station).scale_at.distance_to((stations[3] as Station).scale_at) > 3.0,
			"C's tote and D's each have their own room")
	# the same kit as A's: the same parts, mesh for mesh
	var a := _census(stations[0])
	for i in [1, 2, 3]:
		var b := _census(stations[i])
		var same := true
		for k: String in a:
			same = same and int(b.get(k, 0)) >= int(a[k])
		_check(same and b.has("TheBuyer") and b.has("Hoist") and b.has("Pump") and b.has("IceBin"),
				"%s's is the kit A has: the hoist, the buyer and his tote, the pump, the bin (%s)" % [NAMES[i], b])


## What a station's made of: its parts by name, and how many meshes and labels in all.
func _census(st: Node) -> Dictionary:
	var r := {"meshes": 0, "labels": 0}
	for n: Node in st.find_children("*", "", true, false):
		if n is MeshInstance3D:
			r["meshes"] += 1
		elif n is Label3D:
			r["labels"] += 1
		elif n.get_parent() == st and not str(n.name).begins_with("@"):
			r[str(n.name)] = 1
	# (the buyer's the places': one a station)
	if st.get("_buyer") != null:
		r["TheBuyer"] = 1
	return r


## Rivals, four boats of `kind`: every station at its own boat's work, and nobody else's.
func _rivals(stations: Array, kind: String) -> void:
	var vs := sea.vs
	sea.fish_hold.kind = kind
	sea.boat.use_kind(kind)
	await get_tree().process_frame
	vs.host_set_boats(4)
	vs.host_set_on(true)
	await get_tree().create_timer(1.5).timeout
	_check(vs.on and vs.sides.size() == 4, "%s: Rivals with four boats" % kind)
	if not vs.on or vs.sides.size() != 4:
		return
	# (the countdown to GO held off: this is the dock's business, and on GO every boat lets go)
	vs.count_end = 1.0e9
	var boats: Array[Node3D] = []
	var holds: Array[Node] = []
	for i in 4:
		boats.append(vs.sides[i].get("boat"))
		holds.append(vs.sides[i].get("fish_hold"))
		holds[i].set("bank", 5000)
		holds[i].set("fuel", 0.3)
		_check(str(boats[i].get("kind")) == kind and bool(holds[i].get("docked")) and bool((boats[i].get("lines") as Node).call("tied")),
				"%s: boat %s on her lines at her berth" % [kind, NAMES[i]])
	for i in 4:
		var st: Station = stations[i]
		_check(st.call("_boat") == boats[i] and st.call("_hold") == holds[i], "%s: station %d serves boat %s and her books" % [
				kind, i, NAMES[i]])
		_check(st.call("_hose_end") != Vector3.INF, "%s: its hose reaches %s's filler" % [kind, NAMES[i]])
	# a fish in each boat's box; each hoist in turn takes its own boat's and sells it on her slip, the others' untouched
	for i in 4:
		holds[i].call("host_add", 80.0 + 10.0 * i, 40.0)
		for f: Dictionary in holds[i].get("fish"):
			f["iced_s"] = 1.0
			f["packed"] = 1.0
		holds[i].call("_host_changed")
		holds[i].call("_ask_lid", true)
	await get_tree().create_timer(0.5).timeout
	for i in 4:
		var st: Station = stations[i]
		_check(not (st.call("_next_fish") as Array).is_empty(), "%s: %s's fish in reach of her hoist's hook" % [kind, NAMES[i]])
		var before: Array = []
		for j in 4:
			before.append([_sold(holds[j]), (holds[j].get("fish") as Array).size()])
		var t := 0.0
		var hung := false
		var far := 0.0
		while _sold(holds[i]) == int(before[i][0]) and t < 40.0:
			st.host_crank()
			hung = hung or st.h_grade >= 0.0
			if not st.h_fish.is_empty() and st.get("_fish_mesh") != null:
				var fm: Node3D = st.get("_fish_mesh")
				far = maxf(far, Vector2(fm.global_position.x - st.davit.x, fm.global_position.z - st.davit.z).length())
			await get_tree().process_frame
			t += get_process_delta_time()
		var others := true
		for j in 4:
			if j != i:
				others = others and _sold(holds[j]) == int(before[j][0]) and (holds[j].get("fish") as Array).size() == int(before[j][1])
		_check(_sold(holds[i]) == int(before[i][0]) + 1 and hung and (holds[i].get("fish") as Array).is_empty(),
				"%s: %s's fish up on her own hoist, hung on its scale, sold on her slip (%.0f s)" % [kind, NAMES[i], t])
		_check(others, "%s: and on nobody else's slip, nobody else's fish touched" % kind)
		_check(far < Station.REACH + 0.2, "%s: the fish never further from the davit than its arm (%.1f m)" % [kind, far])
		# (the hook back up and the buyer done before the next)
		await get_tree().create_timer(2.5).timeout
		_check(st.h_fish.is_empty() and st.h_grade < 0.0, "%s: %s's hoist free again" % [kind, NAMES[i]])
	# each pump fills its own boat's tank, only hers
	for i in 4:
		var st: Station = stations[i]
		var was: Array = holds.map(func(h: Node) -> float: return float(h.get("fuel")))
		var bank := int(holds[i].get("bank"))
		for k in 60:
			st.call("_ask_fill", 1.0 / 30.0)
			await get_tree().process_frame
		var only := true
		for j in 4:
			if j != i:
				only = only and float(holds[j].get("fuel")) == float(was[j])
		_check(float(holds[i].get("fuel")) > float(was[i]) + 0.05 and int(holds[i].get("bank")) < bank and only,
				"%s: %s's pump fills her tank and only hers (%.2f > %.2f), on her bank" % [kind, NAMES[i],
				float(holds[i].get("fuel")), float(was[i])])
	# each bin: a scoop of ice off it (the scoop in your hands), tipped into its boat's open box, on her bank
	var me: Node = sea.crew.me
	me.set("force_input", true)
	for i in 4:
		var st: Station = stations[i]
		var act: Action = null
		for c: Node in st.get_node("IceBin").get_children():
			if c is Action:
				act = c
		me.hands.pick("scoop")
		me.hands.set("scoop_ice", false)
		await get_tree().process_frame
		var prompt := str(act.prompt.call()) if act != null else ""
		var took := act != null and bool(act.use_with.call(me, "scoop", true))
		_check(took and bool(me.hands.get("scoop_ice")) and prompt.contains("ICE"), "%s: a scoop of ice off %s's bin (\"%s\")" % [
				kind, NAMES[i], prompt])
		var ice: Array = holds.map(func(h: Node) -> int: return int(h.get("ice")))
		var bank := int(holds[i].get("bank"))
		holds[i].call("_ask_lid", true)
		await get_tree().create_timer(0.3).timeout
		holds[i].call("_scoop_ice", me, "scoop", true)
		await get_tree().create_timer(0.3).timeout
		var only := true
		for j in 4:
			if j != i:
				only = only and int(holds[j].get("ice")) == int(ice[j])
		_check(int(holds[i].get("ice")) == int(ice[i]) + 1 and int(holds[i].get("bank")) < bank and only
				and not bool(me.hands.get("scoop_ice")), "%s: tipped into %s's box and only hers (%d), on her bank" % [
				kind, NAMES[i], int(holds[i].get("ice"))])
	me.hands.pick("")
	vs.host_set_on(false)
	await get_tree().create_timer(1.0).timeout
	_check(not vs.on, "%s: and Rivals off again" % kind)


## The career (Rivals off), the one boat at her berth on the pier's west float: station 0 is hers; the other three
## have nothing in reach and do nothing, cranked or pumped.
func _career(stations: Array) -> void:
	var hold := sea.fish_hold
	var boat := sea.boat
	await get_tree().create_timer(0.5).timeout
	_check(bool(hold.docked) and bool((boat.get("lines") as Node).call("tied")), "the career: her at her berth")
	hold.bank = 5000
	hold.fuel = 0.3
	hold.host_add(90.0, 40.0)
	for f: Dictionary in hold.fish:
		f["iced_s"] = 1.0
		f["packed"] = 1.0
	hold.call("_host_changed")
	hold.call("_ask_lid", true)
	await get_tree().create_timer(0.5).timeout
	var idle := true
	for i in [1, 2, 3]:
		var st: Station = stations[i]
		idle = idle and (st.call("_next_fish") as Array).is_empty() and st.call("_hose_end") == Vector3.INF
		for k in 45:
			st.host_crank()
			st.call("_ask_fill", 1.0 / 30.0)
			await get_tree().process_frame
		idle = idle and st.h_fish.is_empty() and st.h_t == 0.0
	_check(idle and hold.fish.size() == 1 and _sold(hold) == 0 and hold.fuel == 0.3,
			"the career: the other three, cranked and pumped, do nothing to her (her fish aboard, her tank as it was)")
	var st0: Station = stations[0]
	var t := 0.0
	while _sold(hold) == 0 and t < 40.0:
		st0.host_crank()
		await get_tree().process_frame
		t += get_process_delta_time()
	var box: Vector3 = boat.to_global(boat.spec["box"])
	_check(_sold(hold) == 1, "the career: her own hoist sells her fish (%.0f s; her box %.1f m from its davit)" % [t,
			Vector2(box.x - st0.davit.x, box.z - st0.davit.z).length()])


func _sold(hold: Node) -> int:
	return ((hold.get("sale") as Dictionary).get("lines", []) as Array).size()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("STATIONS N TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
