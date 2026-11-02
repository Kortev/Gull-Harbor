extends Node
## Screenshots of a fish handled from alongside to the slip (tuna/landing.gd, boat/fish_hold.gd, tuna/handling.gd),
## in the sportfisher at midday, to judge how each act looks and moves: the tail rope flung and over its tail, the tuna
## door swung in, the fish sliding off the door onto the deck, the spike's push (the ring) and its shiver, the cut
## (the ring with its mark), the blood running and a pump of the tail (bare gloves), pinning it, the gut, the ice
## scooped over it in the box, and the slip with each fish's grade and why.
## Run (needs a window): godot --path . res://tests/handling_shot.tscn -- --out=<folder>

const Sea := preload("res://sea/sea.gd")
const Handling := preload("res://tuna/handling.gd")
const Landing := preload("res://tuna/landing.gd")

var sea: Sea
var out := "user://handling_shots"
var me: Node3D
var hold: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("user://") else out)
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await _wait(1.0)
	sea.schools.set("_next", 9999.0)
	hold = sea.fish_hold
	hold.owned = ["skiff", "sportfisher"]
	hold.head_out("sportfisher")
	hold.trip_t0 -= hold.DAY * 0.4            # (midday, for the light)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(2.0)
	me = sea.crew.me
	me.force_input = true
	var deck := float(sea.boat.spec["deck"])
	# alongside, stuck: the tail rope
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	sea.rods.strike(0, 170.0)
	await _wait(0.2)
	var rod = sea.rods.rods[0]
	var landing := sea.landing
	landing.host_alongside(0, 170.0, float(rod.bearing), float(rod.hook_t))
	landing.hold_clock(0, true)
	await _wait(2.5)
	landing._ask_wire_as(0)
	landing._request_harpoon(true)
	landing._ask_throw_as(1, 0)
	landing._request_harpoon(false)
	var side := float(landing.fish[0]["side"])
	var door: Node3D = landing._doors[0 if side > 0.0 else 1]
	var dl := sea.boat.global_transform.affine_inverse() * door.global_position
	me.place(Vector3(dl.x - 0.3 * side, deck + 0.05, dl.z - 1.3), PI)
	me.set("_pitch", -0.45)
	await _wait(1.0)
	while landing.tail_near(0):
		await get_tree().process_frame
	landing._throw_rope(0)
	await _wait(Landing.ROPE_FLY)
	await _grab("rope_short")
	await _wait(1.0)
	while not landing.tail_near(0):
		await get_tree().process_frame
	landing._throw_rope(0)
	await _wait(Landing.ROPE_FLY * 0.6)
	await _grab("rope_flung")
	await _wait(1.0)
	await _grab("roped_door_open")
	# hauled: off the door onto the deck
	while landing.fish.has(0):
		landing._ask_pull_as(1, 0)
		await get_tree().process_frame
	await _wait(0.25)
	await _grab("slide_on")
	await _wait(1.0)
	var f: Dictionary = hold.fish[0]
	var id := int(f["id"])
	var t: Node3D = hold._deck[id]
	hold._kick_in[id] = 999.0
	# the spike
	me.hands.pick("knife")
	await _wait(0.5)
	await _aim(t, Handling.BRAIN)
	await _grab("spike_aim")
	var h: Node = t.get_node("Handle")
	me.hands._target = h
	h.call("use_item", me, "knife", true)
	await _wait(Handling.SPIKE_HOLD * 0.7)
	await _grab("spike_push")
	await _wait(Handling.SPIKE_HOLD * 0.4)
	await _wait(0.1)
	await _grab("spike_shiver")
	me.hands.press(false)
	await _wait(0.8)
	# the cut
	await _aim(t, Handling.CUT_AT)
	await _grab("cut_aim")
	me.hands._target = h
	h.call("use_item", me, "knife", true)
	await _wait(Handling.CUT_FULL * 0.55)
	await _grab("cut_ring")
	me.hands.press(false)
	await _wait(0.4)
	await _grab("blood_running")
	# a pump of the tail, bare-handed
	me.hands.pick("")
	await _wait(0.4)
	await _aim(t, 0.4)
	me.hands.press(true)
	await _wait(0.12)
	await _grab("pump")
	me.hands.press(false)
	await _wait(0.5)
	await _grab("pool")
	# the gut
	me.hands.pick("knife")
	await _wait(0.4)
	await _aim(t, Handling.GUT_AT)
	me.hands._target = h
	h.call("use_item", me, "knife", true)
	await _wait(Handling.GUT_HOLD * 0.5)
	await _grab("gut_draw")
	await _wait(Handling.GUT_HOLD * 0.6)
	await _grab("gutted")
	me.hands.press(false)
	# a second, live one: pinned down
	hold.host_add(140.0, 60.0)
	await _wait(0.3)
	var g: Dictionary = hold.fish[hold.fish.size() - 1]
	var t2: Node3D = hold._deck[int(g["id"])]
	me.hands.pick("")
	await _wait(0.4)
	await _aim(t2, -0.1)
	me.hands.press(true)
	await _wait(0.5)
	await _grab("pin")
	me.hands.press(false)
	# into the box and iced over
	var lid: Node = hold._lid.get_node("Lid")
	lid.call("interact", me)
	await _wait(0.8)
	hold._ask_drop(id, sea.boat.spec["box"], 0.0)
	await _wait(1.0)
	var box: Vector3 = sea.boat.spec["box"]
	me.place(Vector3(box.x, deck + 0.05, box.z + 1.4), 0.0)
	me.set("_pitch", -0.9)
	me.hands.pick("scoop")
	await _wait(0.6)
	await _grab("box_loose")
	for k in 2:
		me.hands.press(true)
		me.hands.press(false)
		await _wait(0.25)
		if k == 1:
			await _grab("ice_scoop")
		await _wait(0.4)
	for k in 2:
		me.hands.press(true)
		me.hands.press(false)
		await _wait(0.6)
	await _grab("ice_packed")
	# the sale: the slip at the dock
	hold.head_in()
	await _wait(3.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(1.0)
	await _grab("slip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Stand ahead of fish `t` and put the crosshair on it at `u` along it, nudging it on till it's there.
func _aim(t: Node3D, u: float) -> void:
	var boat := sea.boat as Node3D
	var id := int(str(t.name).trim_prefix("OnDeck"))
	var local: Vector3 = boat.global_transform.affine_inverse() * hold._on_fish(t, u)
	me.place(Vector3(local.x, float(boat.spec["deck"]) + 0.05, local.z - 1.2), PI)
	var goal := u
	for k in 6:
		var at: Vector3 = hold._on_fish(t, goal)
		for j in 2:
			await get_tree().process_frame
			var cam: Camera3D = me.get("cam")
			var d := boat.global_basis.inverse() * (at - cam.global_position)
			me.set("_yaw", atan2(-d.x, -d.z))
			me.set("_pitch", atan2(d.y, Vector2(d.x, d.z).length()))
		await get_tree().process_frame
		var now: float = hold.aim_u(id, me)
		if not is_nan(now):
			goal += (u - now) * 0.8


func _grab(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(what + ".png")
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path)
	print("SHOT ", path)
