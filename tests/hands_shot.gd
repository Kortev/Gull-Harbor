extends Node
## Screenshots of the hands-on kit (docs/shots/hands_*.png): each item in first person with the hotbar, and a
## crewmate's eye view of you holding it. Run (needs a window): godot --path . res://tests/hands_shot.tscn

const Sea := preload("res://sea/sea.gd")
const Kit := preload("res://crew/kit.gd")

var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("skiff")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(2.0).timeout
	var me := sea.crew.me
	var only := OS.get_cmdline_user_args()
	for item in Kit.ITEMS:
		me.hands.pick(item)
		await get_tree().create_timer(0.4).timeout
		await _grab("hands_" + item)
	# a cast: wound up, the bait in the air, landed
	me.hands.pick("")
	me.force_input = true
	me.set("_yaw", -PI * 0.8)
	me.set("_pitch", 0.15)
	sea.rods.request_grab(0)
	await get_tree().create_timer(0.3).timeout
	Input.action_press("use_primary")
	await get_tree().create_timer(0.8).timeout
	await _grab("cast_windup")
	Input.action_release("use_primary")
	await get_tree().process_frame
	await get_tree().process_frame
	var rod = sea.rods.rods[0]
	while sea.rods._now() - rod.cast_t < sea.rods.fly_time(0) * 0.45:
		await get_tree().process_frame
	await _grab("cast_flying")
	var side := Camera3D.new()
	side.fov = 60.0
	add_child(side)
	var mid: Vector3 = (rod.cast_from + sea.boat.global_transform * rod.land) * 0.5
	side.global_position = mid + (sea.boat.global_basis * Vector3(0.0, 4.0, -30.0))
	side.look_at(mid, Vector3.UP)
	side.make_current()
	while sea.rods._now() - rod.cast_t < sea.rods.fly_time(0) * 0.6:
		await get_tree().process_frame
	await _grab("cast_arc")
	me.cam.make_current()
	side.queue_free()
	while sea.rods.flying(0):
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _grab("cast_landed")
	sea.rods.request_return(0)
	me.force_input = false
	# jigging at the rail: the line going down, the knock
	var beam := float(sea.boat.spec["beam"])
	me.place(Vector3(beam * 0.5 - 0.55, float(sea.boat.spec["deck"]) + 0.05, 1.0), -PI * 0.5)
	me.set("_pitch", -0.45)
	me.hands.pick("jig")
	await get_tree().create_timer(0.4).timeout
	me.hands.press(true)
	me.hands.press(false)
	await get_tree().create_timer(1.5).timeout
	await _grab("jig_down")
	sea.jig.set("_knock_in", 0.01)
	await get_tree().create_timer(0.12).timeout
	await _grab("jig_knock")
	me.set("_pitch", 0.0)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	me.hands.pick("gaff")
	await get_tree().create_timer(0.4).timeout
	cam.make_current()
	for i in 20:
		var b := me.global_transform.basis
		cam.global_position = me.global_position + b * Vector3(1.2, 1.4, -1.8)
		cam.look_at(me.global_position + b.y * 1.0, b.y)
		await get_tree().process_frame
	await _grab("hands_seen")
	# the catch: a fish on deck, the fish box open, dragging it there on the gaff
	var hold = sea.fish_hold
	hold.host_add(140.0, 60.0)
	hold.host_add(60.0, 60.0)
	hold._ask_lid(true)
	await get_tree().create_timer(0.2).timeout
	var first: Dictionary = hold.fish[0]
	hold._ask_drop(int(first["id"]), sea.boat.spec["box"], 0.0)
	var f: Dictionary = hold.fish[1]
	var node: Node3D = hold._deck[int(f["id"])]
	var box: Vector3 = sea.boat.spec["box"]
	me.place(Vector3(box.x + 1.0, box.y + 0.05, box.z + 0.3), PI * 0.5 - 0.3)
	me.set("_pitch", -0.5)
	me.hands.pick("gaff")
	await get_tree().create_timer(0.3).timeout
	node.get_node("Handle").call("use_item", me, "gaff", true)
	await get_tree().create_timer(0.8).timeout
	cam.make_current()
	for i in 20:
		var t: Transform3D = sea.boat.global_transform
		cam.global_position = t * (box + Vector3(0.6, 2.6, -2.8))
		cam.look_at(t * (box + Vector3(0.2, 0.3, 0.2)), Vector3.UP)
		await get_tree().process_frame
	await _grab("catch_gaff")
	me.cam.make_current()
	await get_tree().create_timer(0.1).timeout
	await _grab("catch_gaff_fp")
	# a scoop of chum: dipped, thrown out to port
	node.get_node("Handle").call("use_item", me, "gaff", false)
	me.place(Vector3(0.0, float(sea.boat.spec["deck"]) + 0.05, 2.0), PI * 0.5)
	me.set("_pitch", 0.05)
	me.hands.pick("scoop")
	me.hands.scoop_full = true
	await get_tree().create_timer(0.3).timeout
	me.hands.press(true)
	await get_tree().create_timer(0.6).timeout
	await _grab("chum_windup")
	me.hands.press(false)
	await get_tree().create_timer(0.45).timeout
	await _grab("chum_flying")
	await get_tree().create_timer(1.5).timeout
	await _grab("chum_slick")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _grab(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
