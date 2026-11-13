extends Node
## Screenshots of the arcade fight's minigames in the real game, a test angler (tests/fight_arcade_bot.gd) on the
## buttons: godot --resolution 1920x1080 --path . tests/fight_arcade_shot.tscn [-- --only=<id>[,<id>] --tag=<name>
## --prefix=<name> --sloppy --night --weather=storm]  (windowed; saves docs/shots/<prefix>_<id>[_<tag>].png (prefix:
## minigame): one for each game in the registry, the BIG PULL waiting (pull), going off (bigpull), a perfect's stamp
## (grade) and a miss's (miss))

const Sea := preload("res://sea/sea.gd")
const Fight := preload("res://tuna/fight.gd")
const Arcade := preload("res://tuna/fight_arcade.gd")
const Games := preload("res://tuna/minigames/all.gd")
const Bot := preload("res://tests/fight_arcade_bot.gd")

## When each is worth a look: s into it (the rest by what they're doing: _ready_for).
const AT := {"ride": 2.6, "beats": 1.9, "charge": 1.6, "laps": 2.2, "lanes": 2.3, "steady": 2.4, "tug": 1.5, "twohands": 3.2,
		"pump": 2.3}


func _ready() -> void:
	Fight.arcade = true
	var only: Array = []
	var tag := ""
	var prefix := "minigame"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
		if a.begins_with("--tag="):
			tag = "_" + a.trim_prefix("--tag=")
		if a.begins_with("--prefix="):
			prefix = a.trim_prefix("--prefix=")
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
	var shots: Array = Games.ids() + ["pull", "bigpull", "grade", "miss"]
	var total := 0.0          # (the strike's own banners are let go by before the first)
	for p: String in shots:
		if not only.is_empty() and not only.has(p):
			continue
		Arcade.force_piece = "pull" if p == "bigpull" else ("spool" if p in ["grade", "miss"] else p)
		var waited := 0.0
		var shot := false
		var graded := -1.0
		var fired := -1.0
		while waited < 60.0 and not shot and rod.hooked:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED      # (the window losing focus mustn't bring the pause card up)
			waited += dt
			total += dt
			var f := rod.fight as Arcade
			if f == null:
				continue
			f.line_out = clampf(f.line_out, 60.0, 160.0)
			f.hold = 1.0
			f.wear = 0.0
			f.energy = maxf(f.energy, 0.55)
			if p in ["pull", "bigpull", "grade"]:
				f.combo = maxi(f.combo, 9)
			var act := Bot.act(f, dt, style, mem)
			if p == "pull" or (p == "duel" and f.game != null and str(f.game.get("phase")) == "now" and int(f.game.get("n")) >= 1):
				act = {"a": 0.0, "b": 0.0}       # (left alone a moment, to be looked at)
			if p == "miss":
				act = {"a": 0.0, "b": 0.0}       # (hands off: it's missed)
			_hold("use_primary", float(act["a"]) > 0.5)
			_hold("use_secondary", float(act["b"]) > 0.5)
			var g := f.game
			var ready := false
			match p:
				"grade", "miss":
					if f.grade_t < 0.1 and f.grade == ("perfect" if p == "grade" else "miss") and graded < 0.0:
						graded = 0.0
					if graded >= 0.0:
						graded += dt
					ready = graded > 0.22
				"bigpull":
					if g != null and g.id == "pull" and bool(g.get("fired")) and fired < 0.0:
						fired = 0.0
					if fired >= 0.0:
						fired += dt
					ready = fired > 0.3
				_:
					ready = g != null and g.id == p and _ready_for(g)
			if ready and total > 7.0:
				await RenderingServer.frame_post_draw
				var path := ProjectSettings.globalize_path("res://docs/shots/%s_%s%s.png" % [prefix, p, tag])
				get_viewport().get_texture().get_image().save_png(path)
				print("SHOT ", path)
				shot = true
		if not shot:
			print("NO SHOT ", p)
	_hold("use_primary", false)
	_hold("use_secondary", false)
	get_tree().quit()


func _ready_for(g: Object) -> bool:
	var t := float(g.get("t"))
	match str(g.get("id")):
		"jump":
			return t > float(g.get("up")) + 0.28
		"dog":
			return int(g.get("kick")) == 2
		"spool":
			return float(g.get("show_t")) <= 0.0 and int(g.get("spin")) >= 1 and absf(float(g.call("off"))) < 0.2
		"mimic":
			return str(g.get("phase")) == "go" and int(g.get("idx")) >= 2
		"heave":
			return str(g.get("phase")) == "fill" and float(g.get("power")) > 0.45 and int(g.get("n")) >= 1
		"duel":
			return str(g.get("phase")) == "now" and int(g.get("n")) >= 1
		"pull":
			return t > 0.7 and not bool(g.get("fired"))
	return t > float(AT.get(str(g.get("id")), 2.5))


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)
