extends Node
## Rivals played through, seen (QA): two windowed processes, the host and a friend, the game itself (the sea the
## scene, the title over it) driven by scripted keys, screenshots of both screens at every step into --out=<dir>.
## The title -> RIVALS -> HOST / JOIN -> the lobby -> START -> the intro -> the countdown -> both crews take their
## wheels and run out through the harbour mouth (keys: W, A/D) -> a fish on B (the host sees their dot) -> B brought
## alongside A, the friend leaps aboard A, shoves the host in -> dusk, the race home (each skipper brings her in to
## her berth) -> the weigh-in -> the card -> NEXT DAY. Day 2: the friend's line drops mid-day, back to their title,
## REJOIN; A's day. Day 3: B's, the match -> REMATCH -> a fresh match's day 1 -> the friend quits at the card ->
## the host back to the title. Each side's log (<dir>/host_log.txt, join_log.txt) has both boats' state at every shot,
## to set side by side. Shortcuts where a player's hands would take minutes: the wheel's given (not walked to), the
## catch is put aboard, and the day's run on to dusk. The leap, the shove and the look at the rival are rough.
## Run (two shells, the host first; needs windows):
##   godot --path . --resolution 1280x720 res://tests/rivals_shot.tscn -- --role=host --out=<dir>
##   godot --path . --resolution 1280x720 res://tests/rivals_shot.tscn -- --role=join --out=<dir>

const PORT := 7811

var sea: Node
var host := false
var out := ""
var _n := 0
var _pilot := Vector2.INF        # where the autopilot's taking her (world x, z); INF: off
var _slow := false               # coming in alongside: slow, stop at it
var _pilot_via: Array = []
var log_lines: PackedStringArray = []
var _planned := false
var _rejoin_in := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--role=host":
			host = true
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	get_window().position = Vector2i(0, 40) if host else Vector2i(-1600, 165)
	get_window().title = "HOST" if host else "JOIN"
	# (other games open on this machine: a window under them gets its frames held back, for half a minute at worst)
	get_window().always_on_top = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var s: Node = (load("res://sea/sea.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(s)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = s
	sea = s
	get_tree().create_timer(900.0).timeout.connect(func() -> void:
		_log("TIMED OUT")
		_quit())
	if host:
		await _as_host()
	else:
		await _as_friend()
	_quit()


func _quit() -> void:
	var f := FileAccess.open(out.path_join(("host" if host else "join") + "_log.txt"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
	get_tree().quit()


# ------------------------------------------------------------------ helpers

func _sea() -> Node:
	var s := get_tree().current_scene
	if s != null and s != sea and s.get("vs") != null:
		sea = s
	return sea


func _vs() -> Node:
	return _sea().get("vs")


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(f: Callable, limit: float) -> bool:
	var t := 0.0
	while not f.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > limit:
			_log("WAITED OUT %.0f s" % limit)
			return false
	return true


func _key(code: Key, ctrl := false) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = p
		e.ctrl_pressed = ctrl
		e.unicode = code if code >= 32 and code < 127 else 0
		Input.parse_input_event(e)
		await get_tree().process_frame


func _type(text: String) -> void:
	for ch in text:
		var e := InputEventKey.new()
		e.keycode = ch.unicode_at(0) as Key
		e.unicode = ch.unicode_at(0)
		e.pressed = true
		Input.parse_input_event(e)
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join("%s_%02d_%s.png" % ["host" if host else "join", _n, name])
	img.save_png(path)
	_log("SHOT %s  %s" % [name, _state()])


func _log(s: String) -> void:
	var line := "[%.1f] %s" % [Time.get_ticks_msec() * 0.001, s]
	log_lines.append(line)
	print(line)


## Everything both screens should agree on.
func _state() -> String:
	var vs := _vs()
	if vs == null or not bool(vs.get("on")):
		return "(vs off)"
	var sides: Array = vs.get("sides")
	var bits := []
	var now := float((_sea().get("ocean") as Node).get("wave_time"))
	bits.append("t=%.1f" % now)
	bits.append("wins=%s" % [vs.get("wins")])
	for i in 2:
		var h: Node = (sides[i].get("boat") as Node).get("helm")
		var hold: Node = sides[i].get("fish_hold")
		var kg := 0.0
		for f: Dictionary in hold.get("fish"):
			kg += float(f["kg"])
		bits.append("%s at=(%.1f,%.1f) hd=%.2f v=%.1f kg=%.0f docked=%s day=%.3f" % ["AB"[i], (h.get("at") as Vector2).x,
				(h.get("at") as Vector2).y, float(h.get("heading")), float(h.get("speed")), kg, hold.get("docked"),
				float(hold.call("day_fraction"))])
	bits.append("count=%.1f home_by=%.1f home=%s card=%s states=%s" % [float(vs.get("count_end")) - now if
			float(vs.get("count_end")) > 0 else -1.0, float(vs.get("home_by")) - now if float(vs.get("home_by")) > 0
			else -1.0, vs.get("home"), (vs.get("card") as Node).call("up"), (vs.get("card") as Node).get("states")])
	return "  ".join(bits)


func _me() -> Node:
	return (_sea().get("crew") as Node).get("me")


func _my_boat() -> Node3D:
	return _sea().get("boat")


func _their_boat() -> Node3D:
	var vs := _vs()
	return (vs.get("sides")[1 - int(vs.get("my_team"))] as Node).get("boat")


## Turns your view (the player's own look, as the mouse would) toward a world point.
func _look_toward(p: Vector3) -> void:
	for k in 4:
		var me := _me()
		if me == null:
			return
		var cam: Camera3D = me.get("cam")
		var to := p - cam.global_position
		var want := atan2(-to.x, -to.z)
		var have := atan2(-cam.global_basis.z.x, -cam.global_basis.z.z)
		var tilt := atan2(to.y, Vector2(to.x, to.z).length())
		var had := asin(clampf(-cam.global_basis.z.y, -1.0, 1.0))
		me.set("_yaw", float(me.get("_yaw")) + wrapf(want - have, -PI, PI))
		me.set("_pitch", clampf(float(me.get("_pitch")) + tilt - had, -0.8, 0.6))
		await get_tree().process_frame


## The autopilot, through the keys (W, A, D, S) like a player: toward each of `via`, then `to`.
func _process(delta: float) -> void:
	if delta > 0.4:
		_log("STALL %.2f s  %s" % [delta, _state()])
	# (the friend, dropped when nobody meant it: other games on this machine starve it for half a minute now and then.
	# REJOIN from the title, as a player would)
	_rejoin_in -= delta
	var title: Node = _sea().get("title") if _sea() != null else null
	if not host and not _planned and _rejoin_in <= 0.0 and title != null and bool(title.get("up")) 			and not Net.in_session_or_hosting() and not Net.last_join.is_empty():
		_rejoin_in = 5.0
		_log("UNPLANNED DROP: REJOIN")
		_key(KEY_ENTER)
	if _pilot == Vector2.INF or _sea() == null:
		return
	var helm: Node = _my_boat().get("helm")
	if not bool(helm.call("is_mine")):
		return
	var at: Vector2 = helm.get("at")
	var goal: Vector2 = _pilot_via[0] if not _pilot_via.is_empty() else _pilot
	var d := goal.distance_to(at)
	if not _pilot_via.is_empty() and d < 18.0:
		_pilot_via.pop_front()
		return
	var to := goal - at
	var want := atan2(-to.x, -to.y)
	var err := wrapf(want - float(helm.get("heading")), -PI, PI)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")
	if err > 0.04:
		Input.action_press("move_left", clampf(err * 2.0, 0.2, 1.0))
	elif err < -0.04:
		Input.action_press("move_right", clampf(-err * 2.0, 0.2, 1.0))
	var v := float(helm.get("speed"))
	var last := _pilot_via.is_empty() and _slow
	var target_v := 9.0 if not last else clampf(d * 0.12, 0.0, 6.0)
	if absf(err) > 1.0:
		target_v = minf(target_v, 2.0)
	if last and d < 3.0:
		target_v = 0.0
	if v < target_v - 0.3:
		Input.action_press("move_forward")
	elif v > target_v + 0.3:
		Input.action_press("move_back")


func _pilot_off() -> void:
	_pilot = Vector2.INF
	_pilot_via = []
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)


func _take_wheel() -> void:
	var me := _me()
	if me.get("boat") != _my_boat() or int(me.get("mode")) != 0:
		_log("NOT ABOARD MY OWN BOAT: no wheel")
		return
	me.set("force_input", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var helm: Node = _my_boat().get("helm")
	helm.call("request", true)
	await _until(func() -> bool: return bool(helm.call("is_mine")), 5.0)


func _leave_wheel() -> void:
	_pilot_off()
	var helm: Node = _my_boat().get("helm")
	helm.call("request", false)
	await _until(func() -> bool: return not bool(helm.call("is_mine")), 5.0)


## Out through the harbour mouth and 260 m on, bearing off to our own side.
func _run_out() -> void:
	var vs := _vs()
	var mouth: Vector2 = vs.call("_mouth")
	var team := int(vs.get("my_team"))
	var via := []
	if team == 1:
		# round the pier's end first
		var harbour: Node = _sea().get("harbour")
		var px := float(harbour.get("PIER_X"))
		var end_z := float((_sea().get("landmarks") as Node).call("shore_z", px)) - float(harbour.get("PIER_OUT"))
		via.append(Vector2(px + 14.0, end_z - 12.0))
	var lane := -7.0 if team == 0 else 7.0        # (each her own side of the mouth)
	via.append(mouth + Vector2(lane, 10))
	via.append(mouth + Vector2(lane, -60))
	_pilot_via = via
	_slow = false
	_pilot = mouth + Vector2(-90.0 if team == 0 else 90.0, -320.0)


## Home: to the mouth, inside, then alongside her berth, slow.
func _run_home() -> void:
	var vs := _vs()
	var team := int(vs.get("my_team"))
	var mouth: Vector2 = vs.call("_mouth")
	var berth: Vector2 = vs.call("_berth", team)
	var lane := -7.0 if team == 0 else 7.0
	var via := [mouth + Vector2(lane, -40), mouth + Vector2(lane, 15)]
	if team == 1:
		var harbour: Node = _sea().get("harbour")
		var px := float(harbour.get("PIER_X"))
		var end_z := float((_sea().get("landmarks") as Node).call("shore_z", px)) - float(harbour.get("PIER_OUT"))
		via.append(Vector2(px + 14.0, end_z - 12.0))
	via.append(berth + Vector2(0, -25))
	_pilot_via = via
	_slow = true
	_pilot = berth


# ------------------------------------------------------------------ the host

func _as_host() -> void:
	await _wait(3.0)
	await _shot("title")
	await _key(KEY_DOWN)
	await _wait(0.3)
	await _shot("title_rivals_picked")
	await _key(KEY_ENTER)
	await _wait(0.5)
	await _shot("rivals_host_join")
	# (HOST, on our own port: the title's HOST is Net.host() on the game's)
	Net.host(PORT)
	await _wait(1.5)
	await _shot("lobby_alone")
	await _until(func() -> bool: return ((_sea().get("crew") as Node).get("slots") as Dictionary).size() >= 2, 60.0)
	await _wait(2.0)
	await _shot("lobby_friend_in")
	# the friend presses SWAP BOATS... (they try); then START
	await _wait(3.0)
	await _shot("lobby_before_start")
	await _key(KEY_ENTER)      # START
	await _wait(1.5)
	await _shot("intro_1")
	await _wait(2.5)
	await _shot("intro_2")
	await _until(func() -> bool: return not bool((_sea().get("title") as Node).call("busy")), 20.0)
	await _day(1, 1)
	# day 2: A's (the friend drops mid-day and rejoins)
	await _day(2, 0)
	await _day(3, 1)
	# a fresh match after the rematch: its first day, and the friend quits at the card
	await _day(4, 0)
	await _wait(2.0)


## One day, the host's side: the countdown, out, fishing, home, the card, NEXT DAY. `winner`: whose day it's made.
func _day(d: int, winner: int) -> void:
	var vs := _vs()
	await _until(func() -> bool: return float(vs.get("count_end")) > 0.0, 30.0)
	await _wait(0.6)
	await _shot("d%d_countdown" % d)
	await _take_wheel()
	await _until(func() -> bool: return float(vs.get("count_end")) - float((_sea().get("ocean") as Node).get("wave_time")) < 2.5, 15.0)
	await _shot("d%d_countdown_late" % d)
	await _until(func() -> bool: return float(vs.get("count_end")) < 0.0, 15.0)
	await _wait(0.2)
	await _shot("d%d_go" % d)
	_run_out()
	await _wait(6.0)
	await _shot("d%d_running_out" % d)
	await _look_toward(_their_boat().global_position)
	await _shot("d%d_rival_in_harbour" % d)
	(_me() as Node).set("_yaw", 0.0)
	await _until(func() -> bool: return _pilot_via.is_empty(), 90.0)
	await _shot("d%d_out_of_mouth" % d)
	await _until(func() -> bool: return (_my_boat().get("helm").get("at") as Vector2).distance_to(_pilot) < 30.0, 90.0)
	await _leave_wheel()
	await _wait(2.0)
	await _shot("d%d_on_grounds" % d)
	var sides: Array = vs.get("sides")
	if d == 1:
		# B's baits out, a fish on B: the host sees their dot, hears the radio
		var b_rods: Node = sides[1].get("rods")
		b_rods.call("host_cast", 0)
		(sides[0].get("rods") as Node).call("host_cast", 0)
		await _wait(2.0)
		b_rods.call("strike", 0, 180.0)
		await _wait(1.2)
		await _shot("d1_their_fish_on")
		await _wait(6.0)
		b_rods.call("host_clear")
		# B brought alongside A (nobody at either wheel: the host's word), the friend leaps across
		var ha: Node = (sides[0].get("boat") as Node).get("helm")
		var hb: Node = (sides[1].get("boat") as Node).get("helm")
		await _until(func() -> bool: return int(hb.get("captain")) == 0, 20.0)
		var spot: Vector2 = ha.get("at")
		ha.set("speed", 0.0)
		hb.set("heading", ha.get("heading"))
		hb.set("speed", 0.0)
		# (eased in, not put there: 40 m off to 1 m off over ten s)
		var off := Vector2(float((sides[0].get("boat") as Node).get("beam")) + 1.0, 0.0).rotated(-float(ha.get("heading")))
		for i in 300:
			var k := 1.0 - pow(1.0 - i / 299.0, 2.0)
			hb.set("at", spot + off * lerpf(40.0, 1.0, k))
			hb.set("heading", ha.get("heading"))
			ha.set("at", spot)
			await get_tree().process_frame
		await _look_toward((sides[1].get("boat") as Node3D).global_position)
		await _wait(0.2)
		await _shot("d1_alongside")
		await _until(func() -> bool: return FileAccess.file_exists(out.path_join("leapt")), 40.0)
		await _wait(0.5)
		await _shot("d1_friend_aboard_A")
		# to A's far rail (port, away from B), looking out: the friend comes up behind
		var me0: Node = _me()
		var a_boat := sides[0].get("boat") as Node3D
		me0.call("place", Vector3(-(float(a_boat.get("beam")) * 0.5 - 0.75), float(a_boat.get("deck")) + 0.02, 2.0),
				PI * 0.5, a_boat)
		await _wait(0.5)
		FileAccess.open(out.path_join("host_at_rail"), FileAccess.WRITE).store_string("1")
		await _until(func() -> bool: return FileAccess.file_exists(out.path_join("shoved")), 40.0)
		await _wait(1.5)
		await _shot("d1_shoved_in")
		await _wait(4.0)
		await _shot("d1_swimming")
		# back up the ladder (the host's own, put on the ladder)
		var me: Node = _me()
		me.set("force_input", true)
		if int(me.get("mode")) == 1:
			me.call("climb", me.get("boat"))
			await _wait(1.5)
			await _shot("d1_climbing")
			await _until(func() -> bool: return int(me.get("mode")) == 0, 15.0)
		await _shot("d1_back_aboard")
		await _until(func() -> bool: return FileAccess.file_exists(out.path_join("back_on_b")), 40.0)
		# B eased back off 40 m
		for i in 200:
			hb.set("at", spot + off * lerpf(1.0, 40.0, i / 199.0))
			await get_tree().process_frame
	# the day's catch
	var kg := [[60.0, 45.0], [90.0, 30.0]] if winner == 1 else [[110.0, 50.0], [40.0]]
	for i in 2:
		for k: float in kg[i]:
			(sides[i].get("fish_hold") as Node).call("host_add", k, 60.0)
	await _wait(2.0)
	await _shot("d%d_fish_aboard" % d)
	if d == 2:
		# the friend's line drops mid-day
		# (the drop noticed in seconds, not ENet's half a minute: only for this one)
		var p := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		for id: int in multiplayer.get_peers():
			if p != null and p.get_peer(id) != null:
				p.get_peer(id).set_timeout(8, 1000, 3000)
		FileAccess.open(out.path_join("drop_ready"), FileAccess.WRITE).store_string("1")
		await _until(func() -> bool: return FileAccess.file_exists(out.path_join("dropping")), 60.0)
		await _wait(5.0)
		await _shot("d2_friend_dropped")
		await _until(func() -> bool: return FileAccess.file_exists(out.path_join("rejoined")), 120.0)
		await _wait(3.0)
		await _shot("d2_friend_back")
	# dusk: the day run on to its end
	for side: Node in sides:
		var hold: Node = side.get("fish_hold")
		hold.set("trip_t0", float(hold.get("trip_t0")) - float(hold.get("DAY")))
	await _until(func() -> bool: return float(vs.get("home_by")) > 0.0, 10.0)
	await _wait(1.0)
	await _shot("d%d_dusk" % d)
	await _take_wheel()
	_run_home()
	await _wait(12.0)
	await _shot("d%d_race_home" % d)
	var team := int(vs.get("my_team"))
	await _until(func() -> bool: return bool((vs.get("home") as Array)[team]), 150.0)
	await _shot("d%d_home_tied_up" % d)
	_pilot_off()
	if not bool((vs.get("home") as Array)[1 - team]):
		await _wait(2.0)
		await _shot("d%d_waiting_for_them" % d)
	await _until(func() -> bool: return bool(vs.get("weighing")) or (vs.get("result") as Array).size() == 2, 180.0)
	if not bool((vs.get("home") as Array)[0]) or not bool((vs.get("home") as Array)[1]):
		_log("A BOAT DIDN'T MAKE IT HOME: home=%s" % [vs.get("home")])
	await _wait(2.5)
	await _shot("d%d_weigh_in" % d)
	await _until(func() -> bool: return not bool(vs.get("weighing")), 30.0)
	await _wait(0.3)
	await _shot("d%d_verdict" % d)
	var card: Node = vs.get("card")
	await _until(func() -> bool: return bool(card.call("up")), 10.0)
	await _wait(1.0)
	await _shot("d%d_card_tally" % d)
	await _wait(3.0)
	await _shot("d%d_card" % d)
	if d == 4:
		await _until(func() -> bool: return int((card.get("states") as Array)[1]) >= 3, 30.0)
		await _wait(1.0)
		await _shot("d4_card_they_left")
		await _key(KEY_RIGHT)
		await _key(KEY_ENTER)    # BACK TO THE TITLE
		await _wait(3.0)
		await _shot("back_at_title")
		return
	await _until(func() -> bool: return int((card.get("states") as Array)[1]) == 1, 40.0)
	await _wait(0.4)
	await _shot("d%d_card_they_ready" % d)
	await _key(KEY_ENTER)
	await _wait(0.4)
	await _shot("d%d_card_fading" % d)
	await _until(func() -> bool: return not bool(card.call("up")), 10.0)
	await _wait(1.0)
	await _shot("d%d_next_fade_in" % d)


# ------------------------------------------------------------------ the friend

func _as_friend() -> void:
	await _wait(5.0)
	await _shot("title")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)     # RIVALS
	await _wait(0.4)
	await _key(KEY_DOWN)      # JOIN
	await _key(KEY_ENTER)
	await _wait(0.4)
	await _type("K7Q2")
	await _shot("join_page")
	# (JOIN BY CODE, on our own port)
	Net.join("127.0.0.1", PORT)
	await _wait(0.3)
	await _shot("joining")
	for i in 30:
		if await _until(func() -> bool: return Net.in_session(), 10.0):
			break
		Net.join("127.0.0.1", PORT)      # (the host's not up yet: again)
	await _wait(2.0)
	await _shot("lobby_joined")
	# SWAP BOATS, and back
	await _key(KEY_ENTER)
	await _wait(1.0)
	await _shot("lobby_after_swap")
	await _key(KEY_ENTER)
	await _wait(1.0)
	await _shot("lobby_swapped_back")
	await _until(func() -> bool: return bool(_vs().get("on")), 60.0)
	await _wait(0.5)
	await _shot("intro_1")
	await _wait(2.5)
	await _shot("intro_2")
	await _until(func() -> bool: return not bool((_sea().get("title") as Node).call("busy")), 20.0)
	for d in [1, 2, 3, 4]:
		await _f_day(d)


func _f_day(d: int) -> void:
	var vs := _vs()
	await _until(func() -> bool: return float(_vs().get("count_end")) > 0.0, 60.0)
	vs = _vs()
	await _wait(0.6)
	await _shot("d%d_countdown" % d)
	await _take_wheel()
	await _until(func() -> bool: return float(_vs().get("count_end")) < 0.0, 15.0)
	await _wait(0.2)
	await _shot("d%d_go" % d)
	_run_out()
	await _wait(6.0)
	await _shot("d%d_running_out" % d)
	await _look_toward(_their_boat().global_position)
	await _shot("d%d_rival_in_harbour" % d)
	(_me() as Node).set("_yaw", 0.0)
	await _until(func() -> bool: return _pilot_via.is_empty(), 90.0)
	await _shot("d%d_out_of_mouth" % d)
	await _until(func() -> bool: return (_my_boat().get("helm").get("at") as Vector2).distance_to(_pilot) < 30.0, 90.0)
	await _leave_wheel()
	await _wait(2.0)
	await _shot("d%d_on_grounds" % d)
	if d == 1:
		var rods: Node = _sea().get("rods")
		await _until(func() -> bool: return (rods.get("rods") as Array).any(func(r: Node) -> bool: return bool(r.get("hooked"))), 30.0)
		await _wait(0.6)
		await _shot("d1_our_fish_on")
		rods.call("request_grab", 0)
		await _wait(2.0)
		await _shot("d1_fighting")
		# alongside A: the leap
		var a: Node3D = _their_boat()
		await _until(func() -> bool: return _my_boat().global_position.distance_to(a.global_position) < float(a.get("beam")) + 4.0, 40.0)
		await _wait(1.0)
		var me: Node = _me()
		me.set("force_input", true)
		var b := _my_boat()
		# (B's on A's port side, A to starboard of... wherever A is: up on the rail facing her)
		var side := signf((b.global_transform.affine_inverse() * a.global_position).x)
		me.call("place", Vector3((float(b.get("beam")) * 0.5 - 0.7) * side, float(b.get("deck")) + 0.02, 3.5),
				-PI * 0.5 * side, b)
		await _wait(0.6)
		await _shot("d1_at_the_rail")
		for k in 2:
			Input.action_press("jump")
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release("jump")
			if k == 0:
				await _wait(0.6)
				await _shot("d1_up_on_rail")
		await _wait(0.25)
		await _shot("d1_leaping")
		await _until(func() -> bool: return me.get("boat") == a and int(me.get("mode")) == 0, 5.0)
		await _wait(0.5)
		await _shot("d1_landed_on_A")
		FileAccess.open(out.path_join("leapt"), FileAccess.WRITE).store_string("1")
		# the host: right behind them, by the rail, a shove
		var h: Node = (_sea().get("crew") as Node).call("get_player", 1)
		await _until(func() -> bool: return FileAccess.file_exists(out.path_join("host_at_rail")), 30.0)
		await _wait(0.5)
		var hp: Vector3 = h.call("local_position")
		me.call("place", hp + Vector3(0.65, 0.0, 0.0), PI * 0.5, a)
		await _wait(0.4)
		await _look_toward(h.get("cam").global_position - Vector3(0, 0.4, 0))
		await _wait(0.2)
		await _shot("d1_behind_the_host")
		me.call("shove")
		await _wait(0.25)
		await _shot("d1_shove_windup")
		await _wait(1.0)
		await _shot("d1_shoved")
		FileAccess.open(out.path_join("shoved"), FileAccess.WRITE).store_string("1")
		await _wait(4.0)
		await _shot("d1_host_swimming")
		# back home to B: up on A's rail, leap back
		await _wait(4.0)
		var bs := signf((a.global_transform.affine_inverse() * b.global_position).x)
		me.call("place", Vector3((float(a.get("beam")) * 0.5 - 0.7) * bs, float(a.get("deck")) + 0.02, 3.5),
				-PI * 0.5 * bs, a)
		await _wait(0.5)
		for k in 2:
			Input.action_press("jump")
			await get_tree().physics_frame
			await get_tree().physics_frame
			Input.action_release("jump")
			if k == 0:
				await _wait(0.6)
		await _until(func() -> bool: return me.get("boat") == b, 5.0)
		await _wait(0.5)
		await _shot("d1_back_on_B")
		FileAccess.open(out.path_join("back_on_b"), FileAccess.WRITE).store_string("1")
		me.set("force_input", false)
	await _until(func() -> bool: return ((_sea().get("fish_hold") as Node).get("fish") as Array).size() > 0, 60.0)
	await _wait(1.0)
	await _shot("d%d_fish_aboard" % d)
	if d == 2:
		# the line drops: nothing in or out for a few seconds, both ends give up on it
		await _until(func() -> bool: return FileAccess.file_exists(out.path_join("drop_ready")), 60.0)
		FileAccess.open(out.path_join("dropping"), FileAccess.WRITE).store_string("1")
		_planned = true
		get_tree().multiplayer_poll = false
		await _wait(6.0)
		get_tree().multiplayer_poll = true
		await _wait(1.0)
		await _shot("d2_dropped")
		await _until(func() -> bool: return _sea().get("title") != null and bool((_sea().get("title") as Node).get("up")), 30.0)
		await _wait(2.0)
		await _shot("d2_title_rejoin")
		await _key(KEY_ENTER)      # REJOIN
		await _until(func() -> bool: return Net.in_session() and bool(_vs().get("on")), 30.0)
		await _until(func() -> bool: return not bool((_sea().get("title") as Node).call("busy")), 20.0)
		await _wait(2.0)
		await _shot("d2_rejoined")
		FileAccess.open(out.path_join("rejoined"), FileAccess.WRITE).store_string("1")
		_planned = false
		vs = _vs()
	await _until(func() -> bool: return float(_vs().get("home_by")) > 0.0, 120.0)
	for side: Node in _vs().get("sides"):
		var hold: Node = side.get("fish_hold")
		hold.set("trip_t0", float(hold.get("trip_t0")) - float(hold.get("DAY")))     # (the host's warp, here too)
	await _wait(1.0)
	await _shot("d%d_dusk" % d)
	await _take_wheel()
	_run_home()
	await _wait(12.0)
	await _shot("d%d_race_home" % d)
	var team := int(_vs().get("my_team"))
	await _until(func() -> bool: return bool((_vs().get("home") as Array)[team]) or float(_vs().get("home_by")) < 0.0, 150.0)
	await _shot("d%d_home_tied_up" % d)
	_pilot_off()
	await _until(func() -> bool: return bool(_vs().get("weighing")) or (_vs().get("result") as Array).size() == 2, 180.0)
	await _wait(2.5)
	await _shot("d%d_weigh_in" % d)
	await _until(func() -> bool: return not bool(_vs().get("weighing")), 30.0)
	await _wait(0.3)
	await _shot("d%d_verdict" % d)
	var card: Node = _vs().get("card")
	await _until(func() -> bool: return bool(card.call("up")), 10.0)
	await _wait(1.0)
	await _shot("d%d_card_tally" % d)
	await _wait(3.0)
	await _shot("d%d_card" % d)
	if d == 4:
		_planned = true
		await _key(KEY_RIGHT)
		await _wait(0.3)
		await _shot("d4_card_title_picked")
		await _key(KEY_ENTER)      # BACK TO THE TITLE
		await _wait(3.0)
		await _shot("d4_back_at_title")
		return
	await _key(KEY_ENTER)          # NEXT DAY / REMATCH
	await _wait(0.4)
	await _shot("d%d_card_pressed" % d)
	await _until(func() -> bool: return not bool(card.call("up")), 60.0)
	await _wait(1.0)
	await _shot("d%d_next_fade_in" % d)
