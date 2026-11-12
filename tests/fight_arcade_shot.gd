extends Node
## Screenshots of the arcade fight's set-pieces in the real game, a test angler (tests/fight_arcade_bot.gd) on the
## buttons: godot --path . tests/fight_arcade_shot.tscn  (windowed; saves docs/shots/fight_arcade_<piece>.png)

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")
const Arcade := preload("res://tuna/fight_arcade.gd")
const Bot := preload("res://tests/fight_arcade_bot.gd")


func _ready() -> void:
	Fight.arcade = true
	var sea := (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	sea.fish_hold.head_out("skiff")
	await get_tree().process_frame
	sea.schools.set("_next", 9999.0)
	sea.rods.host_cast(0)
	while sea.rods.flying(0):
		await get_tree().process_frame
	sea.rods.strike(0, 180.0)
	sea.crew.me.force_input = true
	sea.rods.request_grab(0)
	var rod = sea.rods.rods[0]
	var mem := {}
	var style := "sloppy" if "--sloppy" in OS.get_cmdline_user_args() else "good"
	for p: String in ["run", "shake", "jump", "sound", "dog", "charge", "circle", "spiral"]:
		Arcade.force_piece = p
		var waited := 0.0
		var shot := false
		while waited < 40.0 and not shot and rod.hooked:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			waited += dt
			var f := rod.fight as Arcade
			if f == null:
				continue
			if p == "charge":
				f.line_out = maxf(f.line_out, 90.0)
			f.hold = 1.0
			var v := f.view()
			var act := Bot.act(v, dt, style, mem)
			_hold("use_primary", float(act["a"]) > 0.5)
			_hold("use_secondary", float(act["b"]) > 0.5)
			var at := {"jump": f.j_up + 0.25, "dog": 0.0, "charge": f.intro + 1.2}.get(p, 3.4) as float
			var ready := f.piece == p and f.piece_t > at and f.intro <= 0.0
			if p == "dog":
				ready = f.piece == p and f.kick_t > 0.0 and f.kick_t < Arcade.KICK_LEN + 0.2
			if ready:
				await RenderingServer.frame_post_draw
				var path := ProjectSettings.globalize_path("res://docs/shots/fight_arcade_%s.png" % p)
				get_viewport().get_texture().get_image().save_png(path)
				print("SHOT ", path)
				shot = true
		if p == "jump":
			await get_tree().create_timer(2.0).timeout
	_hold("use_primary", false)
	_hold("use_secondary", false)
	get_tree().quit()


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)
