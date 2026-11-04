extends Node
## The career's race home (sea/sea.gd's _race_home) with a crew on the line, as a co-op host has it: dusk falls out
## there and the race home's called (home_by set); tied up again, it's called off. (A host's calls go to the crew as
## RPCs, and `x.rpc() if Net.in_session() else x()` makes the call and then errors in a debug run: rpc() returns
## nothing for the `if` to hand back. Written as a plain if/else now.)
## Run: godot --headless --fixed-fps 30 --path . res://tests/dusk_test.tscn

const Sea := preload("res://sea/sea.gd")
const PORT := 7841

var fails: Array[String] = []


func _ready() -> void:
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	# (the game's own place for it: the race home only runs for the sea at the tree's root)
	get_tree().root.add_child.call_deferred(sea)
	await get_tree().process_frame
	await get_tree().process_frame
	sea.schools.set("_next", 9999.0)
	_check(Net.host(PORT) == OK and Net.in_session(), "hosting: a session, as with a crew")
	sea.fish_hold.call("head_out")
	await get_tree().create_timer(0.3).timeout
	_check(not sea.fish_hold.docked and sea.home_by < 0.0, "out there in the day: no race yet")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY
	await get_tree().create_timer(0.3).timeout
	_check(sea.home_by > float(sea.ocean.wave_time), "dusk: the race home's called (%.0f s)"
			% (sea.home_by - float(sea.ocean.wave_time)))
	sea.fish_hold.set("docked", true)
	await get_tree().create_timer(0.3).timeout
	_check(sea.home_by < 0.0, "tied up: it's called off")
	for f in fails:
		print("FAIL ", f)
	print("DUSK TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
