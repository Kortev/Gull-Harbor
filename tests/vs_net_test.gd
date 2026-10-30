extends Node
## VS over the network (vs/vs.gd), two processes on this machine: the host and a friend who joins.
## The host turns VS on once the friend's aboard, so the friend lands on boat B; both head out, a fish is landed on
## each boat (60 kg on A, 90 on B), and the skipper heads in. The friend checks what they saw: two boats, they're on
## B and B is their sea's boat, both out apart, their tally, then both in and the result (B by 66 lb).
## Run (two shells, the host first):
##   godot --headless --fixed-fps 30 --path . res://tests/vs_net_test.tscn -- --role=host
##   godot --headless --fixed-fps 30 --path . res://tests/vs_net_test.tscn -- --role=join
## (on a port of its own, PORT, so a game already hosting on this machine doesn't get in the way)

const Sea := preload("res://sea/sea.gd")
const PORT := 7791

var fails: Array[String] = []
var sea: Sea
var _host := false


func _ready() -> void:
	_host = OS.get_cmdline_user_args().has("--role=host")
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	if _host:
		Net.host(PORT)
	else:
		Net.join("127.0.0.1", PORT)
	if _host:
		await _as_host()
	else:
		await _as_friend()
	_done()


func _as_host() -> void:
	while sea.crew.slots.size() < 2:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	sea.vs.host_set_on(true)
	await get_tree().create_timer(1.5).timeout
	_check(sea.vs.teams.values().count(1) == 1, "the friend's put on boat B (%s)" % sea.vs.teams)
	sea.fish_hold.call("head_out", "skiff")
	await get_tree().create_timer(1.0).timeout
	(sea.vs.sides[0].get("fish_hold") as Node).call("host_add", 60.0, 60.0)
	(sea.vs.sides[1].get("fish_hold") as Node).call("host_add", 90.0, 60.0)
	await get_tree().create_timer(3.0).timeout
	sea.fish_hold.call("head_in")
	await get_tree().create_timer(4.0).timeout
	_check((sea.vs.get("_verdict") as Label).text.begins_with("They won by 66 lb"), "the skipper (A) reads: %s"
			% (sea.vs.get("_verdict") as Label).text.replace("\n", " / "))


func _as_friend() -> void:
	while not sea.vs.on:
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.5).timeout
	var vs := sea.vs
	_check(vs.sides.size() == 2 and vs.my_team == 1, "VS came on: I'm on boat B")
	var b_boat := vs.sides[1].get("boat") as Node3D
	var a_boat := vs.sides[0].get("boat") as Node3D
	_check(sea.boat == b_boat and sea.crew.me != null and sea.crew.me.boat == b_boat, "aboard B, B's my sea's boat")
	_check(sea.crew.get_player(1) != null and sea.crew.get_player(1).boat == a_boat, "the skipper's on A")
	while bool(sea.fish_hold.get("docked")):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(2.5).timeout
	_check(not bool((vs.sides[0].get("fish_hold") as Node).get("docked")), "both boats out")
	var gap := a_boat.global_position.distance_to(b_boat.global_position)
	_check(gap > 40.0, "apart: %.0f m" % gap)
	var tally := (vs.get("_tally") as Label).text
	_check(tally.contains("You  198 lb") and tally.contains("Them  132 lb"), "my tally: %s" % tally.replace("\n", " / "))
	while not bool(sea.fish_hold.get("docked")):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var verdict := (vs.get("_verdict") as Label).text
	_check(verdict.begins_with("You won by 66 lb"), "the result: %s" % verdict.replace("\n", " / "))


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("VS NET TEST (%s) " % ("host" if _host else "friend"), "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
