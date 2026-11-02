extends Node
## What the fight feels like now, in stills (docs/shots/fight_*.png): the strike (the rod slammed over, the reel in the
## corner at the strike detent), a long run with the spool down to the backing and the drag eased, a lift in the pump,
## the leader up at the rod tip with the crew shouting, and a fish lost (the line gone, why, and what would have saved
## him). A test angler on the rod (tests/fight_bot.gd); the fish is put where each wants him.
## Run (needs a window): godot --path . res://tests/fight_feel_shot.tscn

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")
const FightBot := preload("res://tests/fight_bot.gd")

var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await get_tree().create_timer(1.0).timeout
	sea.fish_hold.head_out("sportfisher")
	sea.fish_hold.trip_t0 -= sea.fish_hold.DAY * 0.3
	sea.set_condition("sunny")
	sea.schools.set("_next", 9999.0)
	await get_tree().process_frame
	for r in sea.rods.rods:
		sea.rods.host_cast(r.index)
	for r in sea.rods.rods:
		while sea.rods.flying(r.index):
			await get_tree().process_frame
	for r in sea.rods.rods:
		if r.index != 0:
			sea.rods._host_line(r.index, true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sea.crew.me.force_input = true
	sea.rods.strike(0, 300.0)
	sea.rods.request_grab(0)
	var rod = sea.rods.rods[0]
	await get_tree().create_timer(0.35).timeout
	await _shot("fight_strike")
	# a long run: the spool down to its backing, the drag eased a notch or two
	await _play(rod, 2.0, {"move": "run", "out": 290.0, "drag": 0.4})
	await _shot("fight_spool")
	# the pump: the rod lifted high against a sulking fish
	await _play(rod, 3.0, {"move": "dog", "out": 70.0, "drag": 0.6, "bearing": 0.05})
	await _play(rod, 0.9, {"move": "dog", "out": 70.0, "drag": 0.6, "bearing": 0.05, "pitch": 1.25})
	await _shot("fight_pump")
	# the leader up at the rod tip, the crew shouting, him off on his last run
	await _play(rod, 1.2, {"move": "spiral", "out": 18.0, "energy": 0.1, "depth": 3.0, "bearing": 0.2})
	await _play(rod, 0.5, {"out": 15.0, "energy": 0.1, "depth": 2.0, "bearing": 0.2, "free": true})
	await _shot("fight_leader")
	# lost: a jolt on a full drag at the leader, the line gone
	var f: RefCounted = rod.fight
	if f != null:
		f.set("grace", 0.0)
		sea.rods.set_drag(rod, 1.0)
		f.call("carry_on", "surge", float(f.get("stretch")) + 3.0, 1.0, 1.0)
		f.set("grace", 0.0)
	for k in 60:
		await get_tree().process_frame
		if not rod.hooked:
			break
	await get_tree().create_timer(0.5).timeout
	await _shot("fight_lost")
	Input.action_release("use_primary")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


## `s` seconds of the fight, a test angler on the reel and the rod, the fish held where `hold` puts him.
func _play(rod: Node, s: float, hold: Dictionary) -> void:
	var mem := {}
	var t := 0.0
	while t < s and rod.hooked:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var f: RefCounted = rod.fight
		if f == null:
			continue
		if not hold.get("free", false):
			f.set("grace", 999.0)
		if hold.has("move") and f.get("move") != hold["move"]:
			f.call("carry_on", str(hold["move"]), float(f.get("stretch")), 1.0, 1.0)
		for k: String in ["bearing", "depth", "energy"]:
			if hold.has(k):
				f.set(k, float(hold[k]))
		if hold.has("out"):
			f.set("line_out", float(hold["out"]))
		var act := FightBot.act(f.call("cues"), dt, "good", mem)
		var pitch := float(hold.get("pitch", act["pitch"]))
		sea.rods.bot_aim = Vector3(pitch, 0.0, 0.0)
		sea.rods.set_drag(rod, float(hold.get("drag", act["drag"])))
		if float(act["crank"]) > 0.5 and not hold.has("pitch"):
			Input.action_press("use_primary")
		else:
			Input.action_release("use_primary")
	Input.action_release("use_primary")


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
