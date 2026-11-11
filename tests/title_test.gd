extends Node
## The title (ui/title.gd): it's up as the game starts, the dock menu waits under it; SOLO takes it down and the
## camera glides into your eyes (no cut: the title's camera moves a little every frame and hands over to yours at
## the end); RIVALS, HOST opens the crew list (a column a boat; the host's BOATS and AGAINST / TOGETHER, everyone's CHANGE BOAT),
## and START puts the boats on the water and takes the title down.
## Run: godot --headless --fixed-fps 30 --path . res://tests/title_test.tscn

const Sea := preload("res://sea/sea.gd")
const Title := preload("res://ui/title.gd")
var PORT := 7795       ## (--port=: another)

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			PORT = int(a.trim_prefix("--port="))
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	await get_tree().process_frame
	sea.title = _title()
	await get_tree().process_frame
	var t := sea.title
	_check(t.up and get_viewport().get_camera_3d() == t.get("_cam"), "the title's up, its camera drifting")
	var menu: Node = sea.get_children().filter(func(n: Node) -> bool: return n.get_script() == load("res://ui/menu.gd"))[0]
	await get_tree().process_frame
	_check(not (menu.get("_panel") as Control).visible, "the dock menu waits under it")
	# the version in the corner is the exe's (core/version.gd, export_presets.cfg)
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var v := str(load("res://core/version.gd").get("VERSION"))
	_check(Title.version_text() == "V" + v and str(presets.get_value("preset.0.options", "application/file_version"))
			== v + ".0" and str(presets.get_value("preset.0.options", "application/product_version")) == v + ".0",
			"the corner says %s, the exe's file and product version %s.0" % [Title.version_text(), v])
	_check(FileAccess.file_exists(str(presets.get_value("preset.0.options", "application/icon"))),
			"the exe's icon is there")
	# the credits, and back
	t.call("_go", "credits")
	_check(str(t.get("_page")) == "credits" and (t.get("_items") as Array).size() == 1, "CREDITS: the credits, BACK")
	t.call("_press")
	_check(str(t.get("_page")) == "main", "BACK to the title's choices")
	# solo: off the title, the camera gliding down into your eyes
	t.call("_solo")
	var cam := t.get("_cam") as Camera3D
	var me_cam := sea.crew.me.get("cam") as Camera3D
	var gaps: Array[float] = []
	var last := cam.global_position
	var steps := 0
	while get_viewport().get_camera_3d() == cam and steps < 500:
		await get_tree().process_frame
		gaps.append(cam.global_position.distance_to(last))
		last = cam.global_position
		steps += 1
	_check(not t.up, "SOLO takes the title down")
	_check(get_viewport().get_camera_3d() == me_cam, "and hands over to your own eyes (%d frames)" % steps)
	_check(gaps.max() < 4.0, "the intro and the glide, with no jump on the way (biggest step %.2f m)" % gaps.max())
	# rivals, hosted: the crew list, then START, two boats
	t.queue_free()
	sea.title = _title()
	await get_tree().process_frame
	t = sea.title
	t.call("_choose", "rivals")
	_check(str(t.get("_page")) == "host_join", "RIVALS asks host or join")
	Net.host(PORT)
	await get_tree().process_frame
	_check(str(t.get("_page")) == "lobby", "hosting opens the crew list")
	# alone, START won't go, and says why (vs/vs.gd's team_problem)
	t.call("_start_pressed")
	await get_tree().process_frame
	_check(t.up and str(t.get("_note")).begins_with("CAN'T START: ") and str(t.get("_note")).length() > 16,
			"alone: START won't go: %s" % t.get("_note"))
	var labels := func() -> Array: return (t.get("_items") as Array).map(func(i: Array) -> String: return str(i[0]))
	var cols: Array = t.call("crew_columns")
	_check(cols.size() == 2 and str(cols[0]["head"]) == "BOAT A" and str(cols[1]["head"]) == "BOAT B"
			and (cols[0]["crew"] as Array).size() == 1 and (cols[1]["crew"] as Array).is_empty()
			and cols[0]["colour"] != cols[1]["colour"], "two boats: a column each, you on A, nobody aboard B")
	_check(labels.call().has("SWAP BOATS") and not labels.call().has("CHANGE BOAT"), "with two boats the way across is SWAP BOATS")
	_check(not "
".join(labels.call()).contains("EVEN") and not str((t.get("_items") as Array)[0][1]).contains("EVEN"),
			"nothing in the lobby asks for even teams")
	var slots: Dictionary = sea.crew.slots
	if not sea.vs.has_method("host_set_boats"):
		print("skip the lobby's BOATS and AGAINST / TOGETHER: vs/vs.gd has no host_set_boats yet")
	else:
		# the host's BOATS: three, a column each, and round to two again past four
		_check(labels.call().has("BOATS: 2") and labels.call().has("AGAINST"), "the host's rows: %s" % [labels.call()])
		t.set("_pick", labels.call().find("BOATS: 2"))
		t.call("_press")
		await get_tree().process_frame
		cols = t.call("crew_columns")
		var hues := {}
		for c: Dictionary in cols:
			hues[c["colour"]] = true
		_check(int(sea.vs.get("boats")) == 3 and cols.size() == 3 and str(cols[2]["head"]) == "BOAT C" and hues.size() == 3,
				"BOATS stepped to 3: three columns, each her own colour (%s)" % [cols.map(func(c: Dictionary) -> String:
				return str(c["head"]))])
		_check(labels.call().has("BOATS: 3") and labels.call().has("CHANGE BOAT") and not labels.call().has("SWAP BOATS")
				and int(t.get("_pick")) == labels.call().find("BOATS: 3"),
				"the row says BOATS: 3 and is still the one picked; the way across is CHANGE BOAT")
		# CHANGE BOAT: the next one along, and round to A again
		var went: Array[int] = []
		for i in 3:
			t.call("_swap")
			await get_tree().process_frame
			went.append(int(sea.vs.my_team))
		_check(went == [1, 2, 0], "CHANGE BOAT steps you B, C and back to A (%s)" % [went])
		# anyone aboard every boat can start, however uneven; an empty boat can't
		slots[2] = 1
		slots[3] = 2
		slots[4] = 3
		sea.vs.teams = {1: 0, 2: 1, 3: 2, 4: 2}
		_check(str(sea.vs.call("team_problem", 1)).is_empty(), "1 v 1 v 2: it can start")
		cols = t.call("crew_columns")
		_check((cols[2]["crew"] as Array).size() == 2 and (cols[0]["crew"] as Array) == ["YELLOW  (YOU)"],
				"and the list has two aboard C, you on A (%s)" % [cols.map(func(c: Dictionary) -> Array: return c["crew"])])
		sea.vs.teams = {1: 0, 2: 0, 3: 1, 4: 1}
		var empty := str(sea.vs.call("team_problem", 1))
		_check(not empty.is_empty(), "nobody aboard C: %s" % empty)
		t.call("_start_pressed")
		await get_tree().process_frame
		_check(t.up and str(t.get("_note")) == "CAN'T START: " + empty, "and START won't go: %s" % t.get("_note"))
		slots.erase(4)
		slots.erase(3)
		slots.erase(2)
		sea.vs.teams = {1: 0}
		t.set("_pick", labels.call().find("BOATS: 3"))
		t.call("_press")
		await get_tree().process_frame
		_check(int(sea.vs.get("boats")) == 4 and (t.call("crew_columns") as Array).size() == 4, "BOATS: 4, four columns")
		t.call("_press")
		await get_tree().process_frame
		_check(int(sea.vs.get("boats")) == 2 and (t.call("crew_columns") as Array).size() == 2
				and labels.call().has("SWAP BOATS"), "and round to two again")
		# AGAINST / TOGETHER
		t.set("_pick", labels.call().find("AGAINST"))
		t.call("_press")
		await get_tree().process_frame
		_check(bool(sea.vs.get("together")) and labels.call().has("TOGETHER")
				and str((t.get("_items") as Array)[int(t.get("_pick"))][1]).begins_with("ONE FLEET."),
				"AGAINST pressed: TOGETHER, one fleet")
		t.call("_press")
		await get_tree().process_frame
		_check(not bool(sea.vs.get("together")) and labels.call().has("AGAINST"), "and back to AGAINST")
		# two boats, uneven: fine
		slots[2] = 1
		slots[3] = 2
		sea.vs.teams = {1: 0, 2: 1, 3: 0}
		_check(str(sea.vs.call("team_problem", 3)).is_empty(), "2 v 1: it can start")
		slots.erase(3)
		sea.vs.teams = {1: 0, 2: 1}
		_check(str(sea.vs.call("team_problem", 1)).is_empty(), "1 v 1: it can start")
	slots.erase(2)
	sea.vs.teams = {1: 0}
	t.call("_start")
	await get_tree().process_frame
	_check(bool(sea.vs.on) and not t.up, "START: two boats on the water, the title down")
	Net.leave()
	_done()


func _title() -> Title:
	var t := Title.new()
	t.name = "Title"
	t.sea = sea
	sea.add_child(t)
	return t


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("TITLE TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
