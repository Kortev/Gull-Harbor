extends Node
## What the fight looks like to the angler (docs/shots/fight_*.png): alone on the sportfisher with the other lines
## still out (REEL THE OTHER LINES IN!), him gone off to starboard (the little boat, NO ANGLE), arms tiring, and him
## under the boat with the line on her hull. The fish is put where each wants him; a test angler keeps the needle up.
## Run (needs a window): godot --path . res://tests/fight_shot.tscn

const Sea := preload("res://sea/sea.gd")
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sea.crew.me.force_input = true
	sea.rods.strike(0, 220.0)
	sea.rods.request_grab(0)
	var rod = sea.rods.rods[0]
	await _play(rod, 5.0, {})
	await _shot("fight_lines")
	for r in sea.rods.rods:
		if r.index != 0:
			sea.rods._host_line(r.index, true)
	await _play(rod, 3.0, {"bearing": 1.35})
	await _shot("fight_wide")
	await _play(rod, 3.0, {"bearing": 0.1, "arms": 0.2})
	await _shot("fight_arms")
	await _play(rod, 2.0, {"bearing": 2.8, "depth": 6.0})
	await _shot("fight_under")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	get_tree().quit()


## `s` seconds of the fight, a test angler on the reel, the fish held where `hold` puts him (bearing, depth) and your
## arms where it says.
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
		f.set("grace", 999.0)
		if f.get("move") in ["run", "surge", "jump", "charge"]:
			f.call("carry_on", "dog", float(f.get("stretch")), 0.0, 1.0)
		if hold.has("bearing"):
			f.set("bearing", float(hold["bearing"]))
		if hold.has("depth"):
			f.set("depth", float(hold["depth"]))
		if hold.has("arms"):
			sea.rods.arms = float(hold["arms"])
		var act := FightBot.act(f.call("cues"), dt, "good", mem)
		if float(act["crank"]) > 0.5:
			Input.action_press("use_primary")
		else:
			Input.action_release("use_primary")
	Input.action_release("use_primary")


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/shots/%s.png" % what
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)
