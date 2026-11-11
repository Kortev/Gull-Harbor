extends Node
## The harbour's four berths (sea/harbour.gd's berth_at: 0 and 1 either side of the fish pier, 2 and 3 either side of
## the town float off the quay), for a skiff and a sportfisher: 0 is berth(), 1 the mirror set out to the same run, no
## two boats in each other's water, none in a pier or a float, each alongside a float with its cleats in reach and a
## boarding step by her, her lines made fast there and holding her (boat/lines.gd), a clear way out to the harbour
## mouth past the others, and the same run to the mouth from all four.
## Run: godot --headless --fixed-fps 30 --path . res://tests/berths_test.tscn
## (-- --berths-shot=<png>, with a window: the harbour from above as well, the four berths' floats in it)

const Sea := preload("res://sea/sea.gd")
const Quay := preload("res://sea/quay.gd")
const Lines := preload("res://boat/lines.gd")
const NAMES := "ABCD"

var sea: Sea
var failed := 0


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	var marks := sea.landmarks
	var harbour := sea.harbour
	var q: Quay = harbour.quay
	var arms: Array = marks.breakwater_arms()
	var mouth: Vector2 = ((arms[0][1] as Vector2) + (arms[1][1] as Vector2)) * 0.5
	var px: float = harbour.PIER_X
	var far := marks.shore_z(px) - 2.0 - float(harbour.PIER_OUT)
	for kind: String in ["skiff", "sportfisher"]:
		sea.boat.use_kind(kind)
		await get_tree().process_frame
		var half: float = sea.boat.beam * 0.5
		var length: float = sea.boat.length
		var at: Array[Vector2] = []
		var runs: Array[float] = []
		for i in 4:
			at.append(harbour.berth_at(i, half, length))
			runs.append(harbour.run_out_at(i, half, length))
		# 0 is her berth as ever; 1 what vs/vs.gd worked out for B: the mirror, the corner, the equal run
		_check(at[0] == harbour.berth(half, length), "%s: berth 0 is berth()" % kind)
		var b := Vector2(2.0 * px - at[0].x, at[0].y)
		var corner := Vector2(px + float(harbour.PIER_W) * 0.5 + half + 1.0, marks.shore_z(px) - float(harbour.PIER_OUT) - 1.0)
		b.y = clampf(corner.y + at[0].distance_to(mouth) - corner.distance_to(mouth), corner.y + length * 0.5, b.y)
		_check(at[1] == b, "%s: berth 1 is A's mirrored and set out along the pier, as Rivals had B" % kind)
		_check(runs[0] == at[0].distance_to(mouth) and runs[1] == maxf(b.y - corner.y, 0.0) + corner.distance_to(mouth),
				"%s: run_out_at is Rivals' run_out for A and B" % kind)
		# the ways out: straight for the mouth, but 1 down the pier's side and round its end first
		var ways := []
		for i in 4:
			ways.append([at[i], Vector2(at[i].x + 1.0, far - 10.0), mouth] if i == 1 else [at[i], mouth])
		for i in 4:
			var who := "%s: berth %s (%.1f, %.1f)" % [kind, NAMES[i], at[i].x, at[i].y]
			# her own water: nobody else's box (a metre round each) in it
			var mine := Rect2(at[i] - Vector2(half, length * 0.5), Vector2(half * 2.0, length)).grow(1.0)
			for j in range(i + 1, 4):
				var theirs := Rect2(at[j] - Vector2(half, length * 0.5), Vector2(half * 2.0, length)).grow(1.0)
				_check(not mine.intersects(theirs), "%s is clear of berth %s" % [who, NAMES[j]])
			var open := true
			for sx: float in [-1.0, 0.0, 1.0]:
				for sz: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
					open = open and not marks.blocked(at[i] + Vector2(sx * half, sz * length))
			_check(open, "%s is open water, all round her" % who)
			# alongside a float: its edge OFF from her side, its cleats in a throw of hers, a boarding step by her
			var way: float = harbour.berth_way(at[i])
			var fl: Array = q.float_near(at[i] - Vector2(way * half, 0.0), 1.0)
			_check(not fl.is_empty() and absf((at[i].x - way * half - float(fl[1])) * float(fl[2]) - Lines.OFF) < 0.01
					and float(fl[2]) == way, "%s lies on a float's fenders" % who)
			if not fl.is_empty():
				var r: Rect2 = fl[0]
				_check(at[i].y - length * 0.5 > r.position.y and at[i].y + length * 0.5 < r.end.y,
						"%s has the float alongside her whole length" % who)
			var step := INF
			for k in q.steps.size():
				if q.step_ways[k] == way and absf(q.steps[k].x - (at[i].x - way * half)) < 2.0:
					step = minf(step, absf(q.steps[k].z - at[i].y))
			_check(step < length * 0.5, "%s has a boarding step alongside (%.1f m along from her middle)" % [who, step])
			# no other boat lying in her way out
			var clear := true
			var path: Array = ways[i]
			for leg in path.size() - 1:
				for k in 81:
					var p: Vector2 = (path[leg] as Vector2).lerp(path[leg + 1], k / 80.0)
					for side: float in [-1.0, 1.0]:
						clear = clear and not marks.blocked(p + Vector2(side * half, 0.0))
					for j in 4:
						if j != i:
							clear = clear and not Rect2(at[j] - Vector2(half, length * 0.5),
									Vector2(half * 2.0, length)).grow(half + 0.5).has_point(p)
			_check(clear, "%s has a clear way out to the mouth, past the piers, the floats and the other three" % who)
			# and her lines: made fast where she lies, they hold her there
			await _lie_at(at[i])
			var lines: Lines = sea.boat.get("lines")
			lines.host_make_fast_here()
			await get_tree().create_timer(2.5).timeout
			var ok := lines.tied()
			var longest := 0.0
			for l in 2:
				var c := int((lines.lines[l] as Array)[1])
				ok = ok and c >= 0 and absf(q.cleats[c].x - (float(fl[1]) - way * 0.22)) < 0.01 if not fl.is_empty() else false
				longest = maxf(longest, lines.length_of(l))
			var moved: float = (sea.boat.helm.at as Vector2).distance_to(at[i])
			_check(ok and longest < Lines.REACH and moved < 0.6,
					"%s: both lines fast on her own float's cleats (%.1f m the longer), holding her (%.2f m moved)"
					% [who, longest, moved])
			for l in 2:
				lines._host_set(l, [Lines.ABOARD, -1, 0.0, 0.0, 1.0])
		var spread: float = runs.max() - runs.min()
		print("     %s: runs to the mouth  A %.1f  B %.1f  C %.1f  D %.1f m" % [kind, runs[0], runs[1], runs[2], runs[3]])
		_check(spread < 3.0, "%s: the same run to the mouth from all four (%.2f m between the longest and shortest)"
				% [kind, spread])
	# a way to walk ashore from each float, and the new float's in the way of a boat
	_check(q.gangways.size() == 2 and q.brows.size() == 1, "a gangway down to each of the pier's floats, a brow to the town float")
	_check(marks.blocked(Vector2(Quay.TOWN_X, q.town_face() - Quay.TOWN_OUT * 0.5)), "the town float's in the way")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--berths-shot="):
			await _shot(a.trim_prefix("--berths-shot="))
	print("BERTHS TEST %s" % ("PASSED" if failed == 0 else "FAILED"))
	get_tree().quit(1 if failed else 0)


## Her lying at `at`, bow out, stopped.
func _lie_at(at: Vector2) -> void:
	var helm := sea.boat.helm
	helm.at = at
	helm.heading = 0.0
	helm.speed = 0.0
	helm.drift = Vector2.ZERO
	helm.spin = 0.0
	await get_tree().process_frame
	sea.boat.global_transform = sea.boat.pose()
	await get_tree().process_frame


## The harbour from above (needs a window; the sea's own --cam and --noon, set here): the pier's two floats and the town
## float, her at berth C; and close on the town float (<png>_town.png): the brow, the steps, the cleats, her lines.
func _shot(path: String) -> void:
	var harbour := sea.harbour
	await _lie_at(harbour.berth_at(2, sea.boat.beam * 0.5, sea.boat.length))
	(sea.boat.get("lines") as Lines).host_make_fast_here()
	var face: float = harbour.quay.town_face()
	sea._args["noon"] = ""
	sea.cam.far = 4000.0
	var views := {path: [Vector3(28.0, 70.0, face - 60.0), Vector3(28.0, 0.0, face - 24.0)],
			path.get_basename() + "_town.png": [Vector3(-15.0, 8.0, face - 36.0), Vector3(0.0, 0.5, face - 9.0)]}
	for to: String in views:
		var eye: Vector3 = views[to][0]
		var at: Vector3 = views[to][1]
		sea._args["cam"] = "%f,%f,%f,%f,%f,%f" % [eye.x, eye.y, eye.z, at.x, at.y, at.z]
		for k in 45:
			sea.cam.make_current()
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(to)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
	print("ok    " if ok else "FAIL  ", what)
