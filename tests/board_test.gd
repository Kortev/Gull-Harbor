extends Node
## Boat to boat (crew/player.gd), headless, Rivals (vs/vs.gd), two sportfishers, a calm sea and a heavy one: you up
## on B's rail (a walk at it and a jump) and a leap off it, A lying alongside, then lying 2 m off, B to A and back:
## in her frame once you're over her, and down on her deck, in her deck space (nothing jumping as you go into it,
## nor anywhere on the way); 6 m off, it's too far: into the sea.
## Run: godot --headless --fixed-fps 30 --path . res://tests/board_test.tscn [-- --trace]

const Sea := preload("res://sea/sea.gd")
const Player := preload("res://crew/player.gd")

var fails: Array[String] = []
var sea: Sea


func _ready() -> void:
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	add_child(sea)
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		_check(false, "finished in time")
		_done())
	await get_tree().create_timer(0.3).timeout
	sea.schools.set("_next", 9999.0)
	sea.fish_hold.save_path = "user://bluefin_test.cfg"
	await _board()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sea.fish_hold.save_path))
	_done()


## Rivals: from B's rail onto A lying alongside, and lying 2 m off (both ways), nothing jumping as you go into her
## deck space; 6 m off, into the sea.
func _board() -> void:
	var vs := sea.vs
	vs.host_set_on(true)
	await get_tree().process_frame
	vs.ask_team(1)
	await get_tree().process_frame
	sea.fish_hold.call("head_out", "sportfisher")
	var a_boat := vs.sides[0].get("boat") as Node3D
	var b_boat := vs.sides[1].get("boat") as Node3D
	var me := sea.crew.me
	me.force_input = true
	await get_tree().create_timer(0.3).timeout
	var ha: Node = a_boat.get("helm")
	var hb: Node = b_boat.get("helm")
	var at := Vector2(300.0, -600.0)
	for h: Node in [ha, hb]:
		h.set("speed", 0.0)
		h.set("drift", Vector2.ZERO)
		h.set("spin", 0.0)
		h.set("heading", 0.0)
	for sea_is: String in ["calm", "heavy"]:
		sea.set_condition(sea_is)
		await get_tree().create_timer(0.5).timeout
		print("(%s)" % sea_is)
		await _leaps(me, a_boat, b_boat, ha, hb, at)


## The leaps, B to A and back, alongside, 2 m off and 6 m off.
func _leaps(me: Node3D, a_boat: Node3D, b_boat: Node3D, ha: Node, hb: Node, at: Vector2) -> void:
	for gap: float in [0.05, 2.0, 6.0]:
		for way: int in [1, -1]:
			var from := b_boat if way > 0 else a_boat
			var to := a_boat if way > 0 else b_boat
			hb.set("at", at)
			ha.set("at", at + Vector2(float(b_boat.get("beam")) + gap, 0.0))     # (to B's starboard)
			await get_tree().create_timer(0.3).timeout
			var deck := float(from.get("deck"))
			me.place(Vector3((float(from.get("beam")) * 0.5 - 0.7) * way, deck + 0.02, 3.5), -PI * 0.5 * way, from)
			await get_tree().create_timer(0.3).timeout
			var w := {"t": 0.0, "step": 0.0, "prev": me.global_position, "handed": INF}
			# up on her rail (a walk at it and a jump), then Shift, W and Space off it
			Input.action_press("move_forward")
			Input.action_press("jump")
			await _watch_leap(me, to, w)
			Input.action_release("jump")
			while me.on_rail() == Vector3.ZERO and float(w["t"]) < 1.5:
				await _watch_leap(me, to, w)
				if float(w["t"]) > 0.25:
					Input.action_release("move_forward")
			Input.action_release("move_forward")
			for k in 6:
				await _watch_leap(me, to, w)
			Input.action_press("sprint")
			Input.action_press("move_forward")
			Input.action_press("jump")
			await _watch_leap(me, to, w)
			Input.action_release("jump")
			while not (me.mode == Player.DECK and me.frame == to and me.body.is_on_floor()) \
					and me.mode != Player.SWIM and float(w["t"]) < 5.0:
				await _watch_leap(me, to, w)
			Input.action_release("move_forward")
			Input.action_release("sprint")
			var where := "%s %s" % ["A" if me.boat == a_boat else "B", ["deck", "sea", "ladder", "air"][me.mode]]
			if gap < 3.0:
				_check(me.boat == to and me.mode == Player.DECK and me.frame == to,
						"%.0f m gap, %s: the leap lands you on her deck (%s, %.1f s)"
						% [gap, "B to A" if way > 0 else "A to B", where, float(w["t"])])
				_check(float(w["step"]) < 0.3 and float(w["handed"]) < 0.3,
						"and into her deck space, nothing jumping (%.2f m a frame at most, %.2f landing)"
						% [float(w["step"]), float(w["handed"])])
			else:
				_check(me.mode == Player.SWIM, "%.0f m gap: too far, into the sea (%s)" % [gap, where])


## A frame of a leap: how long (t), the biggest step (m) and the step the frame you came into `to`'s space (handed).
func _watch_leap(me: Node3D, to: Node3D, w: Dictionary) -> void:
	var was_frame: Node3D = me.get("frame")
	await get_tree().process_frame
	var d := me.global_position.distance_to(w["prev"])
	w["step"] = maxf(float(w["step"]), d)
	if me.get("frame") != was_frame and me.get("frame") == to:
		w["handed"] = d
	w["prev"] = me.global_position
	w["t"] = float(w["t"]) + 1.0 / 30.0
	if OS.get_cmdline_user_args().has("--trace"):
		var l: Vector3 = (to.global_transform.affine_inverse() * me.global_position)
		print("  t %.2f mode %d rail %s frame %s  in her: %.2f %.2f %.2f" % [float(w["t"]), me.get("mode"),
				me.on_rail(), me.get("frame").name if me.get("frame") else "-", l.x, l.y, l.z])


func _done() -> void:
	for f in fails:
		print("FAIL ", f)
	print("BOARD TEST ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)
