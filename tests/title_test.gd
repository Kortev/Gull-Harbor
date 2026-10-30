extends Node
## The title (ui/title.gd): it's up as the game starts, the dock menu waits under it; SOLO takes it down and the
## camera glides into your eyes (no cut: the title's camera moves a little every frame and hands over to yours at
## the end); RIVALS, HOST opens the crew list, and START puts two boats on the water and takes the title down.
## Run: godot --headless --fixed-fps 30 --path . res://tests/title_test.tscn

const Sea := preload("res://sea/sea.gd")
const Title := preload("res://ui/title.gd")
const PORT := 7795

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
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
	# solo: off the title, the camera gliding down into your eyes
	t.call("_solo")
	var cam := t.get("_cam") as Camera3D
	var me_cam := sea.crew.me.get("cam") as Camera3D
	var gaps: Array[float] = []
	var last := cam.global_position
	var steps := 0
	while get_viewport().get_camera_3d() == cam and steps < 200:
		await get_tree().process_frame
		gaps.append(cam.global_position.distance_to(last))
		last = cam.global_position
		steps += 1
	_check(not t.up, "SOLO takes the title down")
	_check(get_viewport().get_camera_3d() == me_cam, "and hands over to your own eyes (%d frames)" % steps)
	_check(gaps.max() < 2.5, "with no jump on the way (biggest step %.2f m)" % gaps.max())
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
