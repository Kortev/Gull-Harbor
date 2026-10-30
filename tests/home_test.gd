extends Node
## Rivals' race home (vs/vs.gd): at dusk the clock starts (HOME s); a boat brought alongside her own berth and held
## there slow is tied up and her catch sold there, no cut; once time's up the one still out is towed in and her catch
## weighs half. A lands 100 kg and comes home; B lands 100 kg and stays out: A wins, B's counted at half.
## Run: godot --headless --fixed-fps 30 --path . res://tests/home_test.tscn

const Sea := preload("res://sea/sea.gd")
const Vs := preload("res://vs/vs.gd")

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	var vs := sea.vs
	vs.host_set_on(true)
	await get_tree().process_frame
	var holds: Array = vs.sides.map(func(s: Node) -> Node: return s.get("fish_hold"))
	(holds[0] as Node).call("head_out")
	await get_tree().create_timer(0.3).timeout
	_check(not bool(holds[0].get("docked")) and not bool(holds[1].get("docked")), "both out")
	holds[0].call("host_add", 100.0, 60.0)
	holds[1].call("host_add", 100.0, 60.0)
	# both run out a way, then dusk falls
	for side: Node in vs.sides:
		var helm: Node = (side.get("boat") as Node).get("helm")
		helm.set("at", (helm.get("at") as Vector2) + Vector2(0.0, -600.0))
	await get_tree().process_frame
	for h: Node in holds:
		h.set("trip_t0", float(h.get("trip_t0")) - h.get("DAY"))
	await get_tree().create_timer(0.3).timeout
	_check(vs.home_by > vs._now(), "dusk: the race home's on (%.0f s)" % (vs.home_by - vs._now()))
	# A comes in alongside her berth and holds there
	var ha: Node = (vs.sides[0].get("boat") as Node).get("helm")
	ha.set("at", vs._berth(0))
	ha.set("speed", 0.0)
	await get_tree().create_timer(Vs.TIE + 0.6).timeout
	_check(vs.came_home(0) and bool(holds[0].get("docked")), "A alongside her berth, held there: tied up, home")
	_check(not vs.came_home(1) and not bool(holds[1].get("docked")), "B still out")
	# time's up
	vs._homeward(vs._now() + 0.1, vs.home)
	await get_tree().create_timer(0.5).timeout
	_check(vs.result.size() == 2, "time's up: the weigh-in")
	if vs.result.size() == 2:
		_check(roundi(vs.result[0]) == 220 and roundi(vs.result[1]) == 110,
				"A's 220 lb whole, B late: 110 lb, half (%d, %d)" % [roundi(vs.result[0]), roundi(vs.result[1])])
	_check(vs.wins == [1, 0], "the day to A, who came home (%s)" % [vs.wins])
	_done()


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("HOME TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
