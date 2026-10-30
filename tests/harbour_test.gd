extends Node
## The harbour (sea/harbour.gd): her berth is open water alongside the fish pier, the piers and breakwaters are in
## the way, and there's a clear way out from the berth through the harbour mouth to sea; the water in there is still.
## Run: godot --headless --path . res://tests/harbour_test.tscn

const Sea := preload("res://sea/sea.gd")

var sea: Sea
var failed := 0


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	var marks := sea.landmarks
	for kind: String in ["skiff", "sportfisher"]:
		sea.boat.use_kind(kind)
		var berth: Vector2 = sea.harbour.berth(sea.boat.beam * 0.5, sea.boat.length)
		var half := sea.boat.length * 0.5
		_check(not marks.blocked(berth + Vector2(0, -half)) and not marks.blocked(berth + Vector2(0, half)),
				"%s: her berth is open water, bow and stern (%.0f, %.0f)" % [kind, berth.x, berth.y])
		# the way out: ahead off the berth, round into the middle of the harbour, out through the mouth
		var mouth := marks.shore_z(0.0) - 210.0
		var path := [berth, Vector2(berth.x, berth.y - 40.0), Vector2(0.0, mouth + 60.0), Vector2(0.0, mouth - 80.0)]
		var clear := true
		for i in path.size() - 1:
			for k in 41:
				var p: Vector2 = (path[i] as Vector2).lerp(path[i + 1], k / 40.0)
				for side: float in [-1.0, 1.0]:
					clear = clear and not marks.blocked(p + Vector2(side * sea.boat.beam * 0.5, 0.0))
		_check(clear, "%s: a clear way out from the berth through the mouth" % kind)
	_check(marks.blocked(Vector2(sea.harbour.PIER_X, marks.shore_z(sea.harbour.PIER_X) - 30.0)), "the pier's in the way")
	var arm: Array = marks.breakwater_arms()[0]
	_check(marks.blocked((arm[0] as Vector2).lerp(arm[1], 0.5)), "the breakwater's in the way")
	# still water inside, the open sea's swell outside
	sea.ocean.weather = 0.9
	# (how far the water goes up and down there: the curve of the sea away from the middle stays put)
	var a := []
	var b := []
	for k in 40:
		var t := k * 0.7
		a.append(sea.ocean.height_at(Vector3(0.0, 0.0, marks.shore_z(0.0) - 70.0), t))
		b.append(sea.ocean.height_at(Vector3(0.0, 0.0, 600.0), t))
	var inside: float = a.max() - a.min()
	var outside: float = b.max() - b.min()
	_check(inside < outside * 0.45 and inside > 0.0, "quieter in the harbour (%.2f m) than the sea outside (%.2f m), "
			% [inside, outside] + "but not dead flat")
	print("HARBOUR TEST %s" % ("PASSED" if failed == 0 else "FAILED"))
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL ", what)
