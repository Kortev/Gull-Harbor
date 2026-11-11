extends Node
## The QA playthrough: the game itself from its title (the sea at the tree's root, as it boots), driven by a bot with
## real keys and clicks where a player would use them, a screenshot at every step (docs/shots/play/<part>_NN_*.png)
## and a line for each. Parts (-- --part=):
##   menus    the title's every page, the settings' tabs, FISH, the intro, on the dock, the pause card's harbour board,
##            its manual and settings
##   trip     FISH, her lines let go, out the harbour mouth at the wheel, the birds, the troll, the bite, the fight, the
##            harpoon, the haul, bleeding and icing, the pause card, home through the mouth, alongside the float, her
##            lines thrown and made fast, the hoist and the buyer's scale, the slip, day two
##   host / join   co-op on one machine: two windows, the host's boat and a friend aboard her, through a catch
##   demo     the music's demo reel (tools/music_demo.sh records it, the music panel on, a caption for each part):
##            the title, FISH, casting off and out through the mouth, the sea's song in each weather in turn (fair,
##            rain, a storm, night, fog), then fair again and a whole fish, the birds to the landed hit
## The bank's a test file, never yours. Run (needs a window):
##   godot --path . --resolution 1600x900 res://tests/play_shot.tscn -- --part=trip [--fast] [--out=<dir>]

const Sea := preload("res://sea/sea.gd")
const FightBot := preload("res://tests/fight_bot.gd")
const Rig := preload("res://rods/rig.gd")
const PixFont := preload("res://ui/pixfont.gd")
const Landing := preload("res://tuna/landing.gd")
var OUT := "res://docs/shots/play/"
## The port the boat's hosted on (--port=: another, so two runs side by side don't meet).
var PORT := 7824
const SAVE := "user://bluefin_qa.cfg"

var sea: Sea
var part := "menus"
var fast := false
var shot_n := 0
var fails: Array[String] = []


## Out there, the bot's window keeps the mouse (another window taking the focus would bring the pause card up, and
## alone that stops the world): off only while it's testing the pause card itself.
var live := true

## The demo: the wall clock last frame (the sea's runs on it, the movie maker's frames don't), the time into the
## recording, the caption up and how long it's been, the weather easing from one to the next ([from, to, s in, s]).
var _wall := 0.0
var _clock := 0.0
var _caption := ""
var _caption_t := 0.0
var _caption_box: Control
var _blend: Array = []
## The demo's weathers: [condition, night, s], each a song's way in and on; and how long a caption stays.
const DEMO_WEATHER := [["calm", false, 75.0], ["rain", false, 75.0], ["storm", false, 75.0], ["calm", true, 75.0],
		["fog", false, 75.0]]
## The demo's catch: the chase to the birds at most this long (s), a bite put on after this long trolling without
## one, and that fish's kilos.
const DEMO_CHASE := 60.0
const DEMO_BITE := 40.0
const DEMO_KG := 180.0
## The demo's throws at most, before it's left to the old way.
const DEMO_THROWS := 4
const CAPTION_S := 6.0
const BLEND_S := 8.0


func _process(delta: float) -> void:
	if live and sea != null and is_instance_valid(sea) and sea.fish_hold != null and not sea.fish_hold.docked 			and (sea.title == null or not sea.title.busy()) and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if part != "demo" or sea == null or not is_instance_valid(sea):
		return
	# (the sea's clock is the wall clock; the movie maker's frames aren't: held to the game's pace, frame for frame)
	var wall := Time.get_ticks_msec() / 1000.0
	if _wall > 0.0:
		sea.ocean.clock_offset -= (wall - _wall) - delta
	_wall = wall
	_clock += delta
	_caption_t += delta
	if _caption_box != null:
		_caption_box.queue_redraw()
	if not _blend.is_empty():
		# (after the sea's own pinned weather each frame: process_priority)
		_blend[2] = float(_blend[2]) + delta
		var m := smoothstep(0.0, 1.0, float(_blend[2]) / float(_blend[3]))
		if m >= 1.0:
			sea.set_condition(str(_blend[1]))
			_blend.clear()
		else:
			sea.set_weather(str(_blend[0]), str(_blend[1]), m)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.trim_prefix("--part=")
		elif a.begins_with("--out="):         # (somewhere else for the shots, a folder)
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
		elif a.begins_with("--port="):
			PORT = int(a.trim_prefix("--port="))
	fast = OS.get_cmdline_user_args().has("--fast")
	if part == "demo":
		process_priority = 100         # (the weather's ease after the sea's own each frame)
		var layer := CanvasLayer.new()
		layer.layer = 119
		_caption_box = Control.new()
		_caption_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption_box.draw.connect(_draw_caption)
		layer.add_child(_caption_box)
		add_child(layer)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	sea = (load("res://sea/sea.tscn") as PackedScene).instantiate() as Sea
	# (the game's own scene, as it boots: BACK TO THE TITLE reloads it, and this bot stays)
	get_tree().root.add_child.call_deferred(sea)
	get_tree().set_deferred("current_scene", sea)
	await get_tree().process_frame
	await get_tree().process_frame
	sea.fish_hold.save_path = SAVE
	if part != "join":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	sea.fish_hold.call("_load")
	sea.fish_hold.call("_host_changed")
	await _wait(2.5)
	await call("_" + part)
	_done()


# ---- the menus ---------------------------------------------------------------------------------------------------

func _menus() -> void:
	var title := sea.title
	_check(title != null and title.up, "the title's up")
	await _shot("title")
	for i in 4:
		await _key(KEY_DOWN)
		await _shot("title_down%d" % (i + 1))
	await _key(KEY_UP)
	await _key(KEY_UP)
	await _key(KEY_UP)
	await _key(KEY_ENTER)        # RIVALS
	await _shot("rivals_host_join")
	await _key(KEY_ESCAPE)
	await _shot("rivals_esc")
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)        # JOIN A FRIEND
	await _shot("join")
	for c in "ABC123":
		await _key(OS.find_keycode_from_string(c), c.unicode_at(0))
	await _shot("join_typed")
	await _key(KEY_ESCAPE)
	await _shot("join_esc")
	_check(title.get("_page") == "main", "Esc on JOIN A FRIEND goes back to the title's first page (%s)" % title.get("_page"))
	title.call("_go", "main")
	await _wait(0.2)
	for i in 3:
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)        # ACHIEVEMENTS
	await _shot("achievements")
	await _key(KEY_ESCAPE)
	_check(title.get("_page") == "main" and title.get("_pick") == 3, "Esc on ACHIEVEMENTS: back to the title, on it")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)        # SETTINGS
	await _shot("settings_0")
	for t in 4:
		await _key(KEY_TAB)
		await _shot("settings_%d" % (t + 1))
	await _key(KEY_TAB)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _shot("settings_row2")
	await _key(KEY_ESCAPE)
	await _shot("settings_closed")
	await _fish()
	await _shot("on_the_dock")
	live = false
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	await _shot("dock_pause")
	await _click_text("THE HARBOUR BOARD")
	await _shot("board")
	await _click_text("THE OWNER'S MANUAL")
	await _shot("board_manual")
	await _click_text("CLOSE THE MANUAL")
	await _shot("board_manual_closed")
	await _click_text("SETTINGS")
	await _shot("board_settings")
	await _key(KEY_ESCAPE)
	await _shot("board_settings_closed")
	await _click_text("NEW CAREER")
	await _shot("board_new_career_ask")


## FISH from the title: the boat hosted on the test port, the intro played (shots along it), the glide to the dock.
func _fish() -> void:
	var title := sea.title
	title.call("_go", "main")
	title.set("_mode", "fish")
	Net.host(PORT)
	await _wait(0.3)
	title.call("_go", "main")
	await _shot("fish_picked")
	await _key(KEY_ENTER)        # FISH
	for i in 4:
		await _wait(1.5)
		await _shot("intro_%d" % i)
	while title.busy():
		await get_tree().process_frame
	await _shot("glided_in")
	await _wait(1.0)


# ---- a whole trip ------------------------------------------------------------------------------------------------

func _trip() -> void:
	await _fish()
	await _shot("on_the_dock")
	var hold := sea.fish_hold
	_check(hold.docked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "on your feet at the dock, no board")
	await _cast_off()
	await _shot("cast_off")
	await _wait(1.0)
	await _shot("at_the_wheel")
	# out of the harbour, through its mouth, at the wheel with the keys
	var mouth: float = sea.harbour.call("_shore", 0.0) - 210.0
	await _drive([Vector2(sea.boat.helm.at.x - 6.0, sea.boat.helm.at.y - 40.0), Vector2(0.0, mouth + 60.0),
			Vector2(0.0, mouth - 120.0)], 0.7, "leaving")
	_check(not hold.docked, "her lines aboard and off the floats: the day's begun")
	await _shot("the_mouth")
	await _drive([Vector2(0.0, mouth - 700.0)], 1.0, "")
	await _shot("open_sea")
	# the pause card out there (Esc), then back to the deck
	live = false
	await _key(KEY_ESCAPE)
	await _wait(0.4)
	var held_at: float = sea.ocean.wave_time
	var her_at: Vector2 = sea.boat.helm.at
	await _shot("pause")
	_check(get_tree().paused, "alone, the pause card holds the world still")
	await _click_text("THE OWNER'S MANUAL")
	await _shot("pause_manual")
	await _click_text("CLOSE THE MANUAL")
	await _wait(2.0)
	_check(sea.boat.helm.at == her_at and sea.ocean.wave_time == held_at, "nothing moved under it")
	await _click_text("BACK TO THE DECK")
	await _wait(0.4)
	_check(not get_tree().paused, "back to the deck: the world going again")
	_check(sea.ocean.wave_time - held_at < 1.0, "the sea's clock carried on from where it stopped (+%.2f s)"
			% (sea.ocean.wave_time - held_at))
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "back to the deck: the mouse is the look again")
	live = true
	await _shot("pause_resumed")
	await _catch()
	await _home(mouth)
	await _sell()
	_check(hold.docked and not (hold.sale.get("lines", []) as Array).is_empty(), "sold: %s" % str(hold.sale.get("lines", [])))
	var bank := int(hold.bank)
	var day := int(hold.day)
	# the career: written at the sale; read back it's the same books
	var cfg := ConfigFile.new()
	_check(cfg.load(SAVE) == OK, "the career's written (%s)" % SAVE)
	# back to the title: the scene's reloaded, the books read again
	print("QA bank $%d, day %d: back to the title" % [bank, day])
	var old := sea
	live = false
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	await _click_text("BACK TO THE TITLE")
	live = true
	var t := 0.0
	while (get_tree().current_scene == old or get_tree().current_scene == null) and t < 10.0:
		await _wait(0.1)
		t += 0.1
	_check(get_tree().current_scene != old, "BACK TO THE TITLE reloaded the game")
	sea = get_tree().current_scene as Sea
	await get_tree().process_frame
	sea.fish_hold.save_path = SAVE
	sea.fish_hold.call("_load")
	sea.fish_hold.call("_host_changed")
	await _wait(2.0)
	_check(int(sea.fish_hold.bank) == bank and int(sea.fish_hold.day) == day,
			"the career read back: bank $%d day %d" % [sea.fish_hold.bank, sea.fish_hold.day])
	await _after_title()


## Back on the title after BACK TO THE TITLE: the books as they were, FISH again, day two, CAST OFF.
func _after_title() -> void:
	var was := FileAccess.get_file_as_string(SAVE)
	var hold := sea.fish_hold
	await _shot("title_again")
	_check(sea.title != null and sea.title.up, "the title's up again")
	print("QA after the title: bank $%d day %d" % [hold.bank, hold.day])
	_check(not was.is_empty(), "the save's there")
	await _fish()
	await _shot("dock_day2")
	_check(hold.docked, "at the dock again")
	await _cast_off()
	await _wait(2.0)
	await _shot("day2_cast_off")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


## The music's demo reel, as it'd be played: the title, FISH, the dock, casting off and out past the mouth, then the
## sea's song in each weather (eased from one to the next, cruising slowly), then fair again and a whole fish. Each
## part's caption and its time into the recording printed ("DEMO <s> <caption>"), for the video's chapters.
func _demo() -> void:
	_say("THE TITLE")
	await _wait(6.0)
	await _fish()
	_say("TIED UP IN THE HARBOUR")
	await _wait(4.0)
	await _cast_off()
	_say("CASTING OFF")
	var mouth: float = sea.harbour.call("_shore", 0.0) - 210.0
	await _drive([Vector2(sea.boat.helm.at.x - 6.0, sea.boat.helm.at.y - 40.0), Vector2(0.0, mouth + 60.0),
			Vector2(0.0, mouth - 120.0)], 0.7, "")
	_say("OUT PAST THE MOUTH")
	await _drive([Vector2(0.0, mouth - 500.0)], 1.0, "")
	var names := {"calm": "FAIR WEATHER", "rain": "RAIN", "storm": "A STORM", "fog": "FOG"}
	# (-- --catch: straight to the fish, the weathers left out: for trying the catch)
	for w: Array in ([] if OS.get_cmdline_user_args().has("--catch") else DEMO_WEATHER):
		var was := str(sea.condition)
		if str(w[0]) != was:
			sea.weather.pinned = was
			_blend = [was, str(w[0]), 0.0, BLEND_S]
		else:
			sea.set_condition(was)         # (held: the sea's own weather doesn't turn meanwhile)
		sea.set_night(bool(w[1]))
		_say("NIGHT" if bool(w[1]) else str(names.get(str(w[0]), str(w[0]).to_upper())))
		await _cruise(float(w[2]))
	if str(sea.condition) != "calm":
		sea.weather.pinned = str(sea.condition)
		_blend = [str(sea.condition), "calm", 0.0, BLEND_S]
	_say("FAIR AGAIN: LOOKING FOR BIRDS")
	await _catch()
	await _wait(16.0)


## At the wheel a while, slowly on (her speed's drums only just in), holding her course.
func _cruise(s: float) -> void:
	if not sea.boat.helm.is_mine():
		await _interact_wheel()
	var h := atan2(_fwd().x, -_fwd().y)
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
		_steer_heading(h)
		_hold("move_forward", sea.boat.helm.speed < 4.0)
	_hold("move_forward", false)
	_steer_to(Vector2.INF)


## What the demo's caption says of each of his moves, the first time it shows.
const MOVE_SAID := {"run": "HE RUNS", "surge": "A SURGE", "sound": "HE SOUNDS DEEP", "dog": "DOGGING DEEP",
		"shake": "HE SHAKES HIS HEAD", "jump": "HE JUMPS", "charge": "HE CHARGES THE BOAT",
		"circle": "TIRING: HE CIRCLES", "spiral": "SPIRALLING UP"}


## Your look turned onto p (world) over about s seconds, eased, as a hand on the mouse would turn it.
func _look_to(p: Vector3, s: float) -> void:
	var me := sea.crew.me
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var e := _look_err(p)
		var k := 1.0 - exp(-dt * 8.0)
		me.set("_yaw", float(me.get("_yaw")) + e.x * k)
		me.set("_pitch", clampf(float(me.get("_pitch")) + e.y * k, -1.4, 1.4))


## How far your look is off p (world): [yaw, pitch] to turn by, in the boat's frame (yaw up turns you left).
func _look_err(p: Vector3) -> Vector2:
	var cam := sea.crew.me.get("cam") as Camera3D
	var inv := sea.boat.global_basis.inverse()
	var f := inv * -cam.global_basis.z
	var d := inv * (p - cam.global_position)
	var yaw := wrapf(atan2(-d.x, -d.z) - atan2(-f.x, -f.z), -PI, PI)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length()) - atan2(f.y, Vector2(f.x, f.z).length())
	return Vector2(yaw, pitch)


## The harpoon thrown as you'd throw it: looked onto the fish, right mouse to steady, left held to wind it all the way,
## the crosshair worked up and down over him (he's swimming) till the throw would stick, then let go. True: stuck.
func _throw_onto(i: int) -> bool:
	var landing := sea.landing
	var me := sea.crew.me
	if landing.harpoon_holder != Net.my_id() or not landing.fish.has(i):
		return false
	await _look_to(landing.fish_point(i), 0.6)
	Input.action_press("use_secondary")
	_press_primary(true)
	var t := 0.0
	var thrown := false
	while t < 5.0 and landing.fish.has(i):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		# on him side to side; up and down over him, slowly, for where it'd come down on his back
		var off := lerpf(-0.12, 0.35, pingpong(t / 1.4, 1.0))
		var e := _look_err(landing.fish_point(i))
		var k := 1.0 - exp(-dt * 10.0)
		me.set("_yaw", float(me.get("_yaw")) + e.x * k)
		me.set("_pitch", clampf(float(me.get("_pitch")) + (e.y + off) * k, -1.4, 1.4))
		if landing.draw >= 0.99:
			var aim := landing.throw_aim()
			if landing.aimed_at(aim[0], aim[1], landing.draw) == i:
				thrown = true
				break
	_press_primary(false)
	Input.action_release("use_secondary")
	await _shot("harpoon_thrown")
	if not thrown:
		return false
	t = 0.0
	while t < 3.0 and landing.fish.has(i) and not bool(landing.fish[i]["stuck"]):
		await get_tree().process_frame
		t += get_process_delta_time()
	return landing.fish.has(i) and bool(landing.fish[i]["stuck"])


## Left mouse down or up as the game hears it (an input event: the harpoon listens for the press and the let-go).
func _press_primary(down: bool) -> void:
	var e := InputEventAction.new()
	e.action = "use_primary"
	e.pressed = down
	Input.parse_input_event(e)
	if down:
		Input.action_press("use_primary")
	else:
		Input.action_release("use_primary")


func _say_demo(text: String) -> void:
	if part == "demo":
		_say(text)


func _say(text: String) -> void:
	_caption = text
	_caption_t = 0.0
	print("DEMO %.1f %s" % [_clock, text])


func _draw_caption() -> void:
	var a := clampf(minf(_caption_t / 0.5, (CAPTION_S - _caption_t) / 0.8), 0.0, 1.0)
	if a <= 0.0 or _caption.is_empty():
		return
	var at := Vector2(28.0, 64.0)          # (top left, under the tally: Dale's radio has the bottom)
	PixFont.draw(_caption_box, at + Vector2(4, 4), _caption, Color(0, 0, 0, 0.6 * a), 4)
	PixFont.draw(_caption_box, at, _caption, Color(1.0, 0.95, 0.85, a), 4)


## The hunt, the troll, the bite, the fight, the harpoon, the haul, the bleed and ice (tests/trip_test.gd's bot, on
## the game itself).
func _catch() -> void:
	var school = null
	var waited := 0.0
	_speed(true)
	sea.schools.set("_next", minf(float(sea.schools.get("_next")), sea.schools.now() + 5.0))
	_hold("move_forward", true)
	while school == null and waited < 300.0:
		await _wait(1.0)
		waited += 1.0
		_steer_heading(0.0)
		for s in sea.schools.schools:
			if not s.bait_only:
				school = s
				break
	_hold("move_forward", false)
	_steer_to(Vector2.INF)
	_speed(false)
	_check(school != null, "a flock with tuna under it (after %.0f s)" % waited)
	if school == null:
		return
	# let go of the wheel to look round for it, the way you'd stand and look
	sea.boat.helm.request(false)
	await _wait(0.5)
	await _face_point(Vector3(_xz(school).x, 3.0, _xz(school).y))
	_say_demo("BIRDS WORKING")
	await _wait(0.6)
	await _shot("birds")
	await _interact_wheel()
	var t := 0.0
	var shot_run := false
	_speed(true)
	while t < 300.0 and sea.schools.schools.has(school):
		await get_tree().process_frame
		t += get_process_delta_time()
		var d: float = _xz(school).distance_to(sea.boat.helm.at)
		_steer_to(_xz(school))
		_hold("move_forward", d > 220.0 or (d > 150.0 and sea.boat.helm.speed < 1.5))
		if not shot_run and sea.boat.helm.speed > 7.0:
			shot_run = true
			_speed(false)
			await _shot("running_to_them")
			_speed(true)
		if d < 160.0 and sea.boat.helm.speed < 4.0:
			break
		if part == "demo" and (d < 200.0 or t > DEMO_CHASE):
			break                       # (the reel's: off the throttle once near them, or after a minute)
	_hold("move_forward", false)
	_steer_to(Vector2.INF)
	_speed(false)
	await _shot("slowed")
	_say_demo("BAITS OUT")
	await _cast_all()
	await _interact_wheel()
	_say_demo("TROLLING THROUGH THEM")
	await _shot("trolling")
	var hooked := -1
	t = 0.0
	_speed(true)
	while hooked < 0 and t < 360.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var want := 1.3
		if is_instance_valid(school) and sea.schools.schools.has(school):
			want = maxf(float(school.speed), 1.0) + 0.3
			var spot := _alongside(school)
			_steer_to(spot)
			if spot.distance_to(sea.boat.helm.at) > 45.0:
				want = 4.5
		_hold("move_forward", sea.boat.helm.speed < want)
		for r in sea.rods.rods:
			if r.hooked:
				hooked = r.index
		if part == "demo" and hooked < 0 and t > DEMO_BITE:
			# (the reel's: no bite yet, so one's put on a line that's out, a fish of DEMO_KG)
			for r in sea.rods.rods:
				if not r.bait_in:
					sea.rods.strike(r.index, DEMO_KG)
					break
	_hold("move_forward", false)
	_steer_to(Vector2.INF)
	_speed(false)
	_check(hooked >= 0, "a bite (after %.0f s trolling)" % t)
	if hooked < 0:
		return
	_say_demo("FISH ON: THE STRIKE")
	await _shot("the_bite")
	await _wait(1.0)
	await _shot("the_bite_2")
	# off the wheel (E), clear the other lines, take the rod
	await _key(KEY_E)
	await _wait(0.3)
	await _shot("off_the_wheel")
	for r in sea.rods.rods:
		if r.index != hooked and not r.bait_in:
			sea.rods._host_line(r.index, true)
	var rod = sea.rods.rods[hooked]
	sea.rods.request_grab(hooked)
	await _wait(0.6)
	_check(rod.holder == Net.my_id(), "took the rod")
	await _shot("rod_in_hand")
	var mem := {}
	var w := 0.0
	var shots := {}
	_speed(true)
	while rod.hooked and not rod.alongside and w < 1500.0:
		await get_tree().process_frame
		w += get_process_delta_time()
		var b := wrapf(float(rod.bearing), -PI, PI)
		var helm: Node = sea.boat.helm
		helm.set("heading", float(helm.get("heading")) + clampf(b * 1.5, -1.0, 1.0) * 0.3 * get_process_delta_time())
		if float(sea.rods.arms) < 0.15:
			sea.rods.arms = 1.0
		if rod.fight != null:
			var act := FightBot.act(rod.fight.cues(), get_process_delta_time(), "good", mem)
			sea.rods.bot_aim = Vector3(float(act["pitch"]), float(act["side"]), 0.0)
			_hold("use_primary", float(act["crank"]) > 0.5)
		var key := str(rod.move)
		if part == "demo" and w > 4.0 and _caption_t > CAPTION_S + 2.0:
			if not shots.has("leader") and rod.fight != null and bool(rod.fight.cues().get("leader", false)):
				shots["leader"] = true
				_say("ON THE LEADER")
			elif not shots.has("said_" + key) and MOVE_SAID.has(key):
				shots["said_" + key] = true
				_say(str(MOVE_SAID[key]))
		if not shots.has(key) and w > 2.0:
			shots[key] = true
			_speed(false)
			await _shot("fight_" + key)
			_speed(true)
	_hold("use_primary", false)
	sea.rods.bot_aim = Vector3(NAN, 0.0, 0.0)
	_speed(false)
	_check(rod.alongside and sea.landing.fish.has(rod.index), "fought it to the boat (%.0f s)" % w)
	if not sea.landing.fish.has(rod.index):
		return
	_say_demo("BOATSIDE: THE HARPOON")
	await _wait(0.5)
	await _shot("boatside")
	var landing := sea.landing
	sea.rods.request_return(hooked)
	landing._request_harpoon(true)
	await _wait(0.4)
	_check(landing.harpoon_holder == Net.my_id(), "took the harpoon")
	if landing.needs_wire(hooked):
		landing._ask_wire_as(hooked)
	if part == "demo":
		landing.escape_odds = [0.0]          # (the reel's: a miss doesn't lose him)
		for k in DEMO_THROWS:
			if await _throw_onto(hooked):
				break
			print("QA the throw missed: %s" % sea.crew.hud._note.text)
			await _wait(Landing.RETURN + 0.6)        # (home on its line, hand over hand)
			landing._request_harpoon(true)
			await _wait(0.4)
	else:
		await _face_point(landing.fish_point(hooked))
		await _shot("harpoon_aim")
		landing.throw()
		await _wait(0.4)
		await _shot("harpoon_thrown")
		await _wait(0.6)
	if landing.fish.has(hooked) and not bool(landing.fish[hooked]["stuck"]):
		print("QA the throw missed: %s" % sea.crew.hud._note.text)
		landing._request_harpoon(true)
		landing._ask_throw_as(Net.my_id(), hooked)
	_check(landing.fish.has(hooked) and bool(landing.fish[hooked]["stuck"]), "stuck it")
	await _shot("stuck")
	landing.host_rope(hooked)        # (its tail roped: tests/landing_test.tscn throws it)
	t = 0.0
	var mid := false
	while landing.fish.has(hooked) and t < 40.0:
		landing._ask_pull_as(Net.my_id(), hooked)
		await get_tree().process_frame
		t += get_process_delta_time()
		if not mid and landing.fish.has(hooked) and float(landing.fish[hooked]["haul"]) > 0.5:
			mid = true
			await _shot("haul")
	landing._ask_pull_as(Net.my_id(), -1)
	_check(not sea.fish_hold.fish.is_empty(), "hauled aboard")
	_say_demo("LANDED")
	await _wait(1.2)
	var deck: Dictionary = sea.fish_hold._deck
	if not deck.is_empty():
		await _face_point((deck.values()[0] as Node3D).global_position)
	await _shot("on_deck")
	if sea.fish_hold.fish.is_empty():
		return
	var id := int(sea.fish_hold.fish[0]["id"])
	sea.fish_hold._work(id)
	await _wait(0.8)
	await _shot("bled")
	sea.fish_hold._work(id)
	await _wait(0.8)
	await _shot("iced")


## Home: back through the mouth, up to her berth, slow alongside till she's tied up and sold.
func _home(mouth: float) -> void:
	await _interact_wheel()
	var berth: Vector2 = sea.harbour.berth(float(sea.boat.beam) * 0.5, float(sea.boat.length))
	await _drive([Vector2(0.0, mouth - 200.0), Vector2(0.0, mouth + 40.0)], 1.0, "home")
	await _shot("home_mouth")
	await _drive([Vector2(berth.x - 8.0, berth.y - 50.0)], 0.5, "")
	await _shot("home_approach")
	# in slow along the pier, and stop on her berth
	var t := 0.0
	while t < 120.0 and not sea.fish_hold.docked:
		await get_tree().process_frame
		t += get_process_delta_time()
		var d := berth.distance_to(sea.boat.helm.at)
		var ahead := (berth - sea.boat.helm.at).dot(_fwd()) > 0.0
		_steer_to(berth if d > 4.0 else Vector2.INF)
		var want := clampf(d * 0.12, 0.0, 2.0) if ahead else 0.0
		_hold("move_forward", sea.boat.helm.speed < want - 0.2)
		_hold("move_back", sea.boat.helm.speed > want + 0.4)
		if int(t * 2.0) != int((t - get_process_delta_time()) * 2.0) and int(t) % 10 == 0:
			print("QA berthing: %.1f m off, %.2f m/s" % [d, sea.boat.helm.speed])
	_hold("move_forward", false)
	_hold("move_back", false)
	_steer_to(Vector2.INF)
	await _shot("alongside")
	# her lines: thrown to the float's cleats (E at her cleats, the bot's shortcut) and made fast, hauled in on them
	var lines: Node = sea.boat.get("lines")
	var pier := Vector3(float(sea.harbour.PIER_X), 0.0, sea.boat.global_position.z)
	var side := 1.0 if sea.boat.to_local(pier).x > 0.0 else -1.0
	for i in 2:
		lines.call("request", i, "throw", side)
	await _wait(1.0)
	await _shot("lines_thrown")
	for i in 2:
		lines.call("request", i, "make_fast")
	for k in 8:
		await _wait(0.4)
		for i in 2:
			lines.call("request", i, "haul")
	t = 0.0
	while not sea.fish_hold.docked and t < 10.0:
		await _wait(0.2)
		t += 0.2
	_check(sea.fish_hold.docked and bool(lines.call("tied")), "brought her alongside and tied up on her lines")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "tied up: still on your feet, no board")
	await _shot("tied_up")


## The sale: her fish box open, the hoist's crank held (the bot's shortcut for E held on it) till her catch is up on
## the buyer's scale and sold, a fish at a time; the slip at the shed.
func _sell() -> void:
	var hold := sea.fish_hold
	hold.call("_ask_lid", true)
	# (off the wheel, looking up at the buyer's hoist on the float)
	if sea.boat.helm.is_mine():
		sea.boat.helm.request(false)
		await _wait(0.5)
	var me: Node3D = sea.crew.me
	var davit: Vector3 = sea.places.stations[0].davit
	var d := sea.boat.global_basis.inverse() * (davit - me.global_position)
	me.set("_yaw", atan2(-d.x, -d.z))
	me.set("_pitch", 0.25)
	var t := 0.0
	var shots := 0
	while (not hold.fish.is_empty() or not sea.places.stations[0].h_fish.is_empty()) and t < 120.0:
		sea.places.stations[0].host_crank()
		await get_tree().process_frame
		t += get_process_delta_time()
		if shots < 4 and sea.places.stations[0].h_t > 0.4 + shots * 0.8:
			await _shot("hoist_%d" % shots)
			shots += 1
		if sea.places.stations[0].h_grade > 1.6 and shots < 6:
			await _shot("scale_called")
			shots = 6
	await _wait(1.0)
	await _shot("sold")


## Casting off by hand: her lines let go (E at her cleats: the bot's shortcut), the wheel taken.
func _cast_off() -> void:
	var lines: Node = sea.boat.get("lines")
	for i in 2:
		lines.call("request", i, "let_go")
	await _wait(0.4)
	await _shot("lines_going")
	await _wait(1.0)
	_check(bool(lines.call("all_aboard")), "her lines let go and back aboard")
	sea.boat.helm.request(true)
	await _wait(1.5)
	print("QA cast off: at the wheel %s" % sea.boat.helm.is_mine())


# ---- co-op -------------------------------------------------------------------------------------------------------

func _host() -> void:
	var title := sea.title
	Net.host(PORT)
	title.set("_mode", "coop")
	await _wait(0.3)
	title.call("_go", "lobby")
	# wait for the friend
	var t := 0.0
	while multiplayer.get_peers().is_empty() and t < 60.0:
		await _wait(0.5)
		t += 0.5
	_check(not multiplayer.get_peers().is_empty(), "the friend's aboard (%.0f s)" % t)
	await _wait(2.0)
	title.call("_go", "lobby")
	await _wait(0.3)
	await _shot("lobby_host")
	await _key(KEY_ENTER)        # START
	while title.busy():
		await get_tree().process_frame
	await _wait(1.0)
	await _shot("host_dock")
	await _wait(2.0)
	await _cast_off()
	await _shot("host_cast_off")
	var mouth: float = sea.harbour.call("_shore", 0.0) - 210.0
	await _drive([Vector2(sea.boat.helm.at.x - 6.0, sea.boat.helm.at.y - 40.0), Vector2(0.0, mouth + 60.0),
			Vector2(0.0, mouth - 500.0)], 0.8, "host_leaving")
	await _shot("host_open_sea")
	live = false
	await _key(KEY_ESCAPE)
	await _wait(0.5)
	await _shot("host_menu_card")
	_check(not get_tree().paused, "a friend aboard: the menu card doesn't stop the sea")
	await _click_text("BACK TO THE DECK")
	await _wait(0.4)
	live = true
	await _catch()
	await _wait(3.0)
	await _shot("host_after")
	print("QA host done; fish aboard %d" % sea.fish_hold.fish.size())
	await _wait(8.0)


func _join() -> void:
	var title := sea.title
	await _wait(2.0)
	Net.join("127.0.0.1", PORT)
	var t := 0.0
	while title.get("_page") != "lobby" and t < 30.0:
		await _wait(0.5)
		t += 0.5
	await _wait(1.0)
	await _shot("lobby_join")
	_check(title.get("_page") == "lobby", "the friend's on the lobby")
	t = 0.0
	while title.up and t < 90.0:
		await _wait(0.5)
		t += 0.5
	while title.busy():
		await get_tree().process_frame
	await _wait(1.0)
	await _shot("join_dock")
	t = 0.0
	while sea.fish_hold.docked and t < 90.0:
		await _wait(0.5)
		t += 0.5
	await _wait(2.0)
	await _shot("join_cast_off")
	# the friend looks about, then forward; shots as the skipper works
	var shots := 0
	t = 0.0
	var me: Node = sea.crew.me
	var seen_bite := false
	var seen_land := false
	while t < 1000.0 and multiplayer.has_multiplayer_peer() and Net.in_session():
		await _wait(0.5)
		t += 0.5
		if int(t * 2) % 40 == 0 and shots < 10:
			shots += 1
			me.set("_yaw", fmod(shots * 1.3, TAU))
			await _shot("join_look_%d" % shots)
		var hooked := false
		for r in sea.rods.rods:
			hooked = hooked or bool(r.hooked)
		if hooked and not seen_bite:
			seen_bite = true
			await _shot("join_bite")
		if not sea.fish_hold.fish.is_empty() and not seen_land:
			seen_land = true
			await _wait(1.0)
			var deck: Dictionary = sea.fish_hold._deck
			if not deck.is_empty():
				await _face_point((deck.values()[0] as Node3D).global_position)
			await _shot("join_fish_aboard")
			break
	_check(seen_land, "the friend saw the fish come aboard")


# ---- the bot's hands -----------------------------------------------------------------------------------------------

## Drive her through waypoints at the wheel (W, A, D), throttle at most `top` of full; shots on the way if `tag`.
func _drive(points: Array, top: float, tag: String) -> void:
	if not sea.boat.helm.is_mine():
		await _interact_wheel()
	_speed(true)
	var n := 0
	for p: Vector2 in points:
		var t := 0.0
		while t < 240.0 and sea.boat.helm.at.distance_to(p) > 12.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			_steer_to(p)
			var ang := absf(_fwd().angle_to((p - sea.boat.helm.at).normalized()))
			_hold("move_forward", ang < 1.2 and sea.boat.helm.speed < top * 14.0)
			if not tag.is_empty() and int(t) == 6 and n < 4 and int(t - get_process_delta_time()) == 5:
				n += 1
				_speed(false)
				await _shot("%s_%d" % [tag, n])
				_speed(true)
		if t >= 240.0:
			_check(false, "drove to %s (stuck %.0f m off)" % [p, sea.boat.helm.at.distance_to(p)])
	_hold("move_forward", false)
	_steer_to(Vector2.INF)
	_speed(false)


## Off the wheel, each rod baited (a mackerel netted out of the live well and hooked through the nose: the hooks go
## out bare, rods/rig.gd), picked up and cast astern (left mouse held, let go), and put back in its holder.
func _cast_all() -> void:
	if sea.boat.helm.is_mine():
		await _key(KEY_E)
		await _wait(0.4)
	var me: Node = sea.crew.me
	me.force_input = true
	for r in sea.rods.rods:
		if r.hooked or not r.bait_in:
			continue
		if not r.baited:
			await _bait(r)
		me.set("_yaw", PI + (0.35 if r.index % 2 == 0 else -0.35))
		me.set("_pitch", 0.1)
		if not r.baited:
			sea.rods.request_bait(r.index, "live", 1.0)      # (a mackerel out of the well on the hook: the bot's shortcut)
			await _wait(0.3)
		sea.rods.request_grab(r.index)
		await _wait(0.4)
		_hold("use_primary", true)
		await _wait(0.9)
		if r.index == 0:
			await _shot("casting")
		_hold("use_primary", false)
		await _wait(2.5)
		if r.index == 0:
			await _shot("cast_out")
		_check(not r.bait_in, "cast rod %d" % r.index)
		sea.rods.request_return(r.index)
		await _wait(0.5)
	await _shot("baits_out")


## Rod r baited by hand: walk to the live well, E on its lid (open), E again (one netted into your fist), walk to the
## rod, E on it and click as the hook's point comes to the fish's nose.
func _bait(r: Node) -> void:
	var me: Node = sea.crew.me
	var well: Node3D = sea.boat.live_well
	await _walk_to(_local(well.global_position), 1.2)
	var act: Node = well.get("_act")
	act.call("interact", me)
	await _wait(0.3)
	act.call("interact", me)
	await _wait(0.4)
	_check(not str(me.hands.carrying()).is_empty(), "netted a mackerel out for rod %d" % r.index)
	await _walk_to(_local(r.global_position), 1.6)
	(r.get("_grab") as Node).call("interact", me)
	var rig: Node = sea.rods.rig
	var t := 0.0
	while not r.baited and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		_hold("use_primary", rig.get("phase") == "aim" and absf(float(rig.get("point")) - Rig.NOSE) < 0.006)
	_hold("use_primary", false)
	_check(r.baited, "hooked a mackerel on rod %d (%.1f s)" % [r.index, t])


## Walks on the keys to within `near` m of `spot` (on her deck, her frame): down her side, then in to it.
func _walk_to(spot: Vector3, near: float) -> void:
	var me: Node = sea.crew.me
	me.force_input = true
	var at: Vector3 = me.call("local_position")
	var lane := signf(at.x if absf(at.x) > 0.05 else 1.0) * 0.85
	for p: Vector3 in [Vector3(lane, 0, at.z), Vector3(lane, 0, spot.z), spot]:
		var t := 0.0
		while t < 6.0:
			var d: Vector3 = p - (me.call("local_position") as Vector3)
			d.y = 0.0
			var left: Vector3 = spot - (me.call("local_position") as Vector3)
			left.y = 0.0
			if d.length() < 0.25 or left.length() < near:
				break
			me.set("_yaw", atan2(-d.x, -d.z))
			_hold("move_forward", true)
			await get_tree().process_frame
			t += get_process_delta_time()
		_hold("move_forward", false)
	var off: Vector3 = spot - (me.call("local_position") as Vector3)
	off.y = 0.0
	print("QA walked to %s: %.2f m off" % [spot, off.length()])


func _local(p: Vector3) -> Vector3:
	return sea.boat.global_transform.affine_inverse() * p


func _interact_wheel() -> void:
	if sea.boat.helm.is_mine():
		return
	var me: Node = sea.crew.me
	me.force_input = true
	var spot: Vector3 = (sea.boat.get("helm_spot") as Transform3D).origin
	if not bool(me.call("can_step_to", spot)):
		# walk there on the keys, round whatever's between (down her side, then in to the wheel)
		var at: Vector3 = me.call("local_position")
		var lane := signf(at.x if absf(at.x) > 0.05 else 1.0) * 0.85
		for p: Vector3 in [Vector3(lane, 0, at.z), Vector3(lane, 0, spot.z + 0.2), spot]:
			var t := 0.0
			while t < 4.0 and not bool(me.call("can_step_to", spot)):
				var d: Vector3 = p - (me.call("local_position") as Vector3)
				d.y = 0.0
				if d.length() < 0.25:
					break
				me.set("_yaw", atan2(-d.x, -d.z))
				_hold("move_forward", true)
				await get_tree().process_frame
				t += get_process_delta_time()
			_hold("move_forward", false)
		print("QA walked to the wheel: a clear step now %s" % me.call("can_step_to", spot))
	sea.boat.helm.request(true)
	await _wait(0.4)
	_check(sea.boat.helm.is_mine(), "took the wheel")


func _fwd() -> Vector2:
	var f := -sea.boat.global_transform.basis.z
	return Vector2(f.x, f.z).normalized()


func _steer_to(p: Vector2) -> void:
	if p == Vector2.INF:
		_hold("move_left", false)
		_hold("move_right", false)
		return
	var ang := _fwd().angle_to((p - sea.boat.helm.at).normalized())
	_hold("move_left", ang < -0.06)
	_hold("move_right", ang > 0.06)


func _steer_heading(h: float) -> void:
	_steer_to(sea.boat.helm.at + Vector2(sin(h), -cos(h)) * 100.0)


func _alongside(s) -> Vector2:
	var c: Vector2 = _xz(s)
	var h: Vector2 = s.heading
	var side := Vector2(-h.y, h.x)
	if (sea.boat.helm.at - c).dot(side) < 0.0:
		side = -side
	return c + h * (float(s.radius) + 40.0) + side * (float(s.radius) + 4.0)


func _xz(s) -> Vector2:
	return s.center(sea.schools.now())


func _face_point(p: Vector3) -> void:
	if part == "demo":
		await _look_to(p, 0.8)            # (the reel's: turned onto it as a hand would, not swept round)
		return
	var me := sea.crew.me
	var best := 0.0
	var best_dot := -2.0
	for i in 72:
		me.set("_yaw", i * TAU / 72.0)
		await get_tree().process_frame
		var d := _aim_dot(p)
		if d > best_dot:
			best_dot = d
			best = i * TAU / 72.0
	me.set("_yaw", best)
	var bp := 0.0
	best_dot = -2.0
	for i in 31:
		me.set("_pitch", -0.75 + i * 0.05)
		await get_tree().process_frame
		var d := _aim_dot(p)
		if d > best_dot:
			best_dot = d
			bp = -0.75 + i * 0.05
	me.set("_pitch", bp)
	await get_tree().process_frame


func _aim_dot(p: Vector3) -> float:
	var cam := sea.crew.me.get("cam") as Camera3D
	return (-cam.global_transform.basis.z).normalized().dot((p - cam.global_position).normalized())


## A real key, down and up (a letter's unicode with it, for typing).
func _key(code: Key, uni := 0) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = uni if down else 0
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame
	await _wait(0.15)


## A real click on the visible button that says `text` (the mouse moved onto it first).
func _click_text(text: String) -> void:
	var b := _find_button(get_tree().root, text)
	if b == null:
		_check(false, "a button saying %s" % text)
		return
	var at := b.get_global_rect().get_center()
	at = b.get_viewport().get_final_transform() * (b.get_viewport().get_canvas_transform().affine_inverse()
			* b.get_global_transform_with_canvas().get_origin() + b.size * 0.5) if false else \
			b.get_viewport().get_final_transform() * b.get_global_transform_with_canvas() * (b.size * 0.5)
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await get_tree().process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = down
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e)
		await get_tree().process_frame
	await _wait(0.3)
	print("QA clicked ", text)


func _find_button(n: Node, text: String) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).is_visible_in_tree() and (c as Button).text == text:
			return c
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _speed(on: bool) -> void:
	Engine.time_scale = 4.0 if on and fast else 1.0


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	shot_n += 1
	var path := "%s%s_%02d_%s.png" % [OUT, part, shot_n, what]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SHOT ", path)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails.append(what)


func _done() -> void:
	Engine.time_scale = 1.0
	for f in fails:
		print("FAIL ", f)
	print("PLAY ", part, " ", "PASSED" if fails.is_empty() else "FAILED")
	get_tree().quit(1 if not fails.is_empty() else 0)
