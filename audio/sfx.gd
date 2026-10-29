extends RefCounted
## Lane B's sounds (the sound pass: docs/lane-b/sound-picks.md): one table from event name to the bank's files, cut by
## assets/world/sounds/build_sounds.py into assets/world/sounds/bank/. Sfx.play("ui.tick") for the flat ones (menus,
## the sheets), Sfx.play_at(node, "ui.glass_open") for the ones that sit somewhere in the world, Sfx.loop(...) for beds
## and engines (one player that keeps going, its loudness set by level()). An event with several files plays one at
## random, never the same twice running; `gain` is its mix trim in dB on top of the file's own level (the bank brings
## them to their levels already, so this is the place to turn one thing up or down); `vary` detunes each play by up to
## that fraction (a clank twice in a row isn't the same clank); `unit` and `range` are a 3D sound's full-volume radius
## and its cut-off (metres); `loop` marks a bed (its files are only ever looped). `alt` is the event's second cut: it
## plays instead while `second_cuts` is on (the dev panels' Sounds section), to compare.
const DIR := "res://audio/bank/"
const EVENTS := {
	# Menus: the crew terminal (title, lobby, settings, saves, TACKLE, LOCKER, the game menu), the night debrief, the
	# run report; the tackle wall's print and tray and the lockers' glass are in the ship (play_at).
	"ui.tick": {"files": ["u_tick"], "alt": ["u_tick_2"]},
	"ui.confirm": {"files": ["u_confirm"], "alt": ["u_confirm_2"]},
	"ui.back": {"files": ["u_back"]},
	"ui.buy": {"files": ["u_buy"]},
	"ui.check": {"files": ["u_check"]},
	"ui.cross": {"files": ["u_cross"]},
	"ui.ready": {"files": ["u_ready"]},
	"ui.unready": {"files": ["u_unready"]},
	"ui.join": {"files": ["u_join"]},
	"ui.leave": {"files": ["u_leave"]},
	"ui.page": {"files": ["u_page"]},
	"ui.stamp": {"files": ["u_stamp"]},
	"ui.reveal": {"files": ["u_reveal"]},
	"ui.crt_on": {"files": ["u_crt_on"], "alt": ["u_crt_on_2"]},
	"ui.crt_off": {"files": ["u_crt_off"], "alt": ["u_crt_off_2"]},
	"ui.start": {"files": ["u_start"], "alt": ["u_start_2"]},
	"ui.print": {"files": ["u_print"], "alt": ["u_print_2"]},
	"ui.drop": {"files": ["u_drop_1", "u_drop_2", "u_drop_3"]},
	"ui.glass_open": {"files": ["u_glass_open"], "alt": ["u_glass_open_2"]},
	"ui.glass_close": {"files": ["u_glass_close"], "alt": ["u_glass_close_2"]},
	# The hull and its machinery (the ship's ramp and doors, the dock, the rigs).
	"kit.thud": {"files": ["k_thud"], "vary": 0.05, "unit": 5.0, "range": 40.0},
	"kit.jolt": {"files": ["k_jolt"], "vary": 0.05},
	"kit.clank": {"files": ["k_clank_1", "k_clank_2", "k_clank_3"], "vary": 0.06},
	"kit.steam": {"files": ["k_steam_1", "k_steam_2"], "vary": 0.06},
	"kit.hydraulic": {"files": ["k_hydraulic"], "alt": ["k_hydraulic_2"], "vary": 0.03, "unit": 5.0, "range": 40.0},
	"kit.chain": {"files": ["k_chain_1", "k_chain_2"], "vary": 0.05},
	"kit.denied": {"files": ["k_denied"], "alt": ["k_denied_2"]},
	"kit.switch": {"files": ["k_switch_1", "k_switch_2"], "vary": 0.04},
	"kit.bodyfall": {"files": ["k_bodyfall_1", "k_bodyfall_2"], "vary": 0.06},
	"kit.rumble": {"files": ["k_rumble"], "alt": ["k_rumble_2"], "loop": true},
	"kit.flicker": {"files": ["k_flicker"], "alt": ["k_flicker_2"], "loop": true, "unit": 4.0, "range": 25.0},
	# Inside the Mudskipper.
	"ship.cabin": {"files": ["s_cabin"], "alt": ["s_cabin_2"], "loop": true, "unit": 12.0, "range": 45.0},
	"ship.button": {"files": ["s_button_1", "s_button_2", "s_button_3", "s_button_4"], "vary": 0.04},
	# The trip: engines at the nozzles, the jump, the air.
	"trip.burn": {"files": ["t_burn"], "alt": ["t_burn_2"], "loop": true, "unit": 8.0, "range": 80.0},
	"trip.over": {"files": ["t_over"], "alt": ["t_over_2"], "unit": 8.0, "range": 80.0},
	"trip.backfire": {"files": ["t_backfire_1", "t_backfire_2", "t_backfire_3"], "vary": 0.08, "unit": 8.0, "range": 80.0},
	"trip.ignite": {"files": ["t_ignite"], "vary": 0.04, "unit": 8.0, "range": 80.0},
	"trip.spool": {"files": ["t_spool"], "alt": ["t_spool_2"], "loop": true},
	"trip.boom": {"files": ["t_boom"], "alt": ["t_boom_2"]},
	"trip.tunnel": {"files": ["t_tunnel"], "alt": ["t_tunnel_2"], "loop": true},
	"trip.dropout": {"files": ["t_dropout"], "alt": ["t_dropout_2"]},
	"trip.reentry": {"files": ["t_reentry"], "alt": ["t_reentry_2"], "loop": true},
	"trip.wind": {"files": ["t_wind"], "alt": ["t_wind_2"], "loop": true},
	"trip.door": {"files": ["t_door"], "alt": ["t_door_2"], "unit": 5.0, "range": 40.0},
	# The ship's PA and alarms.
	"pa.chime": {"files": ["a_chime"], "alt": ["a_chime_2"]},
	"pa.click": {"files": ["a_click_1", "a_click_2"], "alt": ["a_click_3"]},
	"pa.klaxon": {"files": ["a_klaxon"], "loop": true},
	"pa.warning": {"files": ["a_warning"], "alt": ["a_warning_2"]},
	# The bomb collars (on your own neck: flat; the pop is heard in 3D by the others).
	"collar.arm": {"files": ["c_arm"], "alt": ["c_arm_2"]},
	"collar.beep": {"files": ["c_beep"]},
	"collar.disarm": {"files": ["c_disarm"]},
	"collar.pop": {"files": ["c_pop"], "alt": ["c_pop_2"], "unit": 6.0, "range": 60.0},
	"collar.static": {"files": ["c_static"], "alt": ["c_static_2"], "loop": true},
	"collar.thump": {"files": ["c_thump_1", "c_thump_2"], "vary": 0.03},
	# Dock 07: the hangar's air, the force field, the termination alarm, the weigh-in, the boards.
	"dock.hangar": {"files": ["d_hangar"], "alt": ["d_hangar_2"], "loop": true, "unit": 15.0, "range": 90.0},
	"dock.field": {"files": ["d_field"], "loop": true, "unit": 6.0, "range": 50.0},
	"dock.alarm": {"files": ["d_alarm"], "loop": true, "unit": 15.0, "range": 90.0},
	"dock.sag": {"files": ["d_sag"], "alt": ["d_sag_2"], "unit": 15.0, "range": 90.0},
	"dock.reel": {"files": ["d_reel"], "vary": 0.03, "unit": 5.0, "range": 40.0},
	"dock.tube": {"files": ["d_tube"], "vary": 0.08, "unit": 5.0, "range": 35.0},
	"dock.pop": {"files": ["d_pop"], "alt": ["d_pop_2"], "vary": 0.06, "unit": 4.0, "range": 30.0},
	"dock.slap": {"files": ["d_slap_1", "d_slap_2", "d_slap_3"], "vary": 0.08, "unit": 4.0, "range": 30.0},
	"dock.ok": {"files": ["d_ok"], "unit": 8.0, "range": 60.0},
	"dock.no": {"files": ["d_no"], "unit": 8.0, "range": 60.0},
	"dock.scan": {"files": ["d_scan"]},
	"dock.arc": {"files": ["k_arc_1", "k_arc_2", "k_arc_3"], "alt": ["k_arc_4", "k_arc_5"], "vary": 0.1, "unit": 6.0,
		"range": 60.0},
	"dock.flaps": {"files": ["k_flap"], "loop": true, "unit": 5.0, "range": 40.0},
	"kit.motor": {"files": ["k_motor"], "alt": ["k_motor_2"], "loop": true, "unit": 8.0, "range": 50.0},
	"kit.coins": {"files": ["k_coins"], "alt": ["k_coins_2"], "unit": 5.0, "range": 40.0},
	# Glimmer (world/planets/planet_sounds.gd): the meadow by day and by night, the creek's fall, the lake's lapping.
	"glim.day": {"files": ["g_day"], "alt": ["g_day_2"], "loop": true},
	"glim.night": {"files": ["g_night"], "alt": ["g_night_2"], "loop": true},
	"glim.fall": {"files": ["g_fall"], "alt": ["g_fall_2"], "loop": true, "unit": 14.0, "range": 120.0},
	"glim.lake": {"files": ["g_lake"], "alt": ["g_lake_2"], "loop": true, "unit": 6.0, "range": 45.0},
	# Brine: the flats' wind, the dust storm, a gust, a vent boiling up and blowing.
	"brine.bed": {"files": ["b_bed"], "alt": ["b_bed_2"], "loop": true},
	"brine.dust": {"files": ["b_dust"], "alt": ["b_dust_2"], "loop": true},
	"brine.gust": {"files": ["b_gust"], "alt": ["b_gust_2"]},
	"brine.boil": {"files": ["b_warn_1", "b_warn_2"], "alt": ["b_warn_3"], "vary": 0.08, "unit": 4.0, "range": 40.0},
	"brine.vent": {"files": ["b_geyser"], "alt": ["b_geyser_2"], "vary": 0.06, "unit": 10.0, "range": 90.0},
	# Fathom: the sea, the gale, the rain (on the ground, on steel over you, on the visor), the rig's legs and deck.
	"sea.swell": {"files": ["f_sea"], "alt": ["f_sea_2"], "loop": true, "gain": 2.0},
	"sea.wind": {"files": ["f_wind"], "alt": ["f_wind_2"], "loop": true, "gain": 3.5},
	"sea.rain": {"files": ["f_rain"], "alt": ["f_rain_2"], "loop": true, "gain": 4.5},
	"sea.rain_steel": {"files": ["f_rain_steel"], "alt": ["f_rain_steel_2"], "loop": true},
	"sea.rain_visor": {"files": ["f_rain_glass"], "alt": ["f_rain_glass_2"], "loop": true},
	"sea.gust": {"files": ["f_gust"], "alt": ["f_gust_2"], "gain": 3.5},
	"sea.slam": {"files": ["f_slam_1"], "vary": 0.1, "unit": 15.0, "range": 120.0, "gain": 2.0},
	"sea.spray": {"files": ["f_spray_1", "f_spray_2"], "vary": 0.1, "unit": 6.0, "range": 50.0},
	"sea.wave": {"files": ["f_wave_1", "f_wave_2", "f_wave_3"], "vary": 0.08, "unit": 8.0, "range": 60.0},
	"sea.back": {"files": ["f_back"], "alt": ["f_back_2"], "unit": 8.0, "range": 60.0},
	"sea.alarm": {"files": ["f_alarm"], "loop": true, "unit": 10.0, "range": 80.0},
	"sea.crack": {"files": ["f_crack_1", "f_crack_2"], "vary": 0.05},
	"sea.roll": {"files": ["f_roll_1", "f_roll_2", "f_roll_3"], "vary": 0.05},
}
## The ship's sounds (play_at): full up to this many metres, then fading; gone past MAX_DISTANCE.
const UNIT_SIZE := 3.0
const MAX_DISTANCE := 30.0

## On: the events with a second cut play it instead (listening A/B).
static var second_cuts := false
static var _last := {}       # event -> the variant it played last
## What's been heard this run, for the tests: event -> plays (a one-shot) or its loudest level (a loop).
static var heard := {}
static var _streams := {}    # path -> AudioStream (null: not imported)


## One of `event`'s files (null: no such event, or its file isn't imported).
static func stream(event: String) -> AudioStream:
	var e: Dictionary = EVENTS.get(event, {})
	var files: Array = e.get("alt", e.get("files", [])) if second_cuts else e.get("files", [])
	if files.is_empty():
		return null
	var pick := randi() % files.size()
	if files.size() > 1 and pick == int(_last.get(event, -1)):
		pick = (pick + 1) % files.size()
	_last[event] = pick
	var path := DIR + String(files[pick]) + ".ogg"
	if not _streams.has(path):
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamOggVorbis and e.get("loop", false):
			(s as AudioStreamOggVorbis).loop = true
		_streams[path] = s
	return _streams[path]


## `event` flat, on its own player (it outlives whatever asked: a menu switching off still finishes its sound).
## `volume` is linear (1 = the bank's level), `pitch` a playback rate.
static func play(event: String, volume := 1.0, pitch := 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var s := stream(event)
	if tree == null or s == null or volume <= 0.001:
		return
	var p := AudioStreamPlayer.new()
	_dress(p, event, s, volume, pitch)
	p.autoplay = true
	p.finished.connect(p.queue_free)
	tree.root.add_child.call_deferred(p)


## `event` at `at` in the world (following it), after `delay` seconds.
static func play_at(at: Node3D, event: String, delay := 0.0, volume := 1.0, pitch := 1.0) -> void:
	if at == null or volume <= 0.001:
		return
	if delay > 0.0:
		at.get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(at) and at.is_inside_tree():
				play_at(at, event, 0.0, volume, pitch))
		return
	var s := stream(event)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	_dress(p, event, s, volume, pitch)
	p.autoplay = true
	p.finished.connect(p.queue_free)
	at.add_child.call_deferred(p)


## `event` at a point in the world that doesn't move (a lightning strike, a splash), heard from `parent`'s world.
static func play_point(parent: Node, at: Vector3, event: String, volume := 1.0, pitch := 1.0) -> void:
	var s := stream(event)
	if parent == null or s == null or volume <= 0.001:
		return
	var p := AudioStreamPlayer3D.new()
	_dress(p, event, s, volume, pitch)
	p.top_level = true
	p.position = at
	p.autoplay = true
	p.finished.connect(p.queue_free)
	parent.add_child.call_deferred(p)


## A bed or an engine: one player under `parent` (flat, or in 3D where `parent` is) that keeps playing, from a random
## point so two beds of one file never phase. Silent and paused until level() turns it up; free it with its parent.
static func loop(parent: Node, event: String, spatial := false, amount := 0.0) -> Node:
	var s := stream(event)
	if parent == null or s == null:
		return null
	var p: Node = AudioStreamPlayer3D.new() if spatial else AudioStreamPlayer.new()
	_dress(p, event, s, 1.0, 1.0)
	p.add_to_group("sfx_loop")
	parent.add_child(p)
	level(p, amount)
	return p


## A loop's loudness, linear (0 pauses it, 1 = the bank's level; more is louder) and its pitch.
static func level(p: Node, amount: float, pitch := -1.0) -> void:
	if p == null or not is_instance_valid(p):
		return
	var event := String(p.get_meta("sfx_event", ""))
	var e: Dictionary = EVENTS.get(event, {})
	p.set_meta("sfx_amount", amount)
	if amount > float(heard.get(event, 0.0)):
		heard[event] = snappedf(amount, 0.01)
	p.set("volume_db", float(e.get("gain", 0.0)) + linear_to_db(maxf(amount, 0.0001)))
	if pitch > 0.0:
		p.set("pitch_scale", pitch)
	if amount <= 0.001:
		p.set("stream_paused", true)
	elif not bool(p.get("playing")):
		p.set("stream_paused", false)
		var s := p.get("stream") as AudioStream
		if p.is_inside_tree():
			p.call("play", randf() * maxf(s.get_length() - 0.5, 0.0) if s != null else 0.0)
	else:
		p.set("stream_paused", false)


## A loop's loudness from where it is to `to` over `seconds`.
static func fade(p: Node, to: float, seconds: float) -> Tween:
	if p == null or not is_instance_valid(p):
		return null
	var t := p.create_tween()
	t.tween_method(func(a: float) -> void: level(p, a), float(p.get_meta("sfx_amount", 0.0)), to, seconds)
	return t


static func _dress(p: Node, event: String, s: AudioStream, volume: float, pitch: float) -> void:
	var e: Dictionary = EVENTS[event]
	if not e.get("loop", false):
		heard[event] = int(heard.get(event, 0)) + 1
	p.set("stream", s)
	p.set_meta("sfx_event", event)
	p.set("volume_db", float(e.get("gain", 0.0)) + linear_to_db(volume))
	var vary := float(e.get("vary", 0.0))
	p.set("pitch_scale", pitch * (1.0 + randf_range(-vary, vary)))
	if p is AudioStreamPlayer3D:
		var p3 := p as AudioStreamPlayer3D
		p3.unit_size = float(e.get("unit", UNIT_SIZE))
		p3.max_distance = float(e.get("range", MAX_DISTANCE))


## Every loop playing picks its file again (after the A/B switch).
static func _restream() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for p: Node in tree.get_nodes_in_group("sfx_loop"):
		var s := stream(String(p.get_meta("sfx_event", "")))
		if s != null and s != p.get("stream"):
			p.set("stream", s)
			level(p, float(p.get_meta("sfx_amount", 0.0)))


## The dev panels' Sounds section: the first cuts, or the second ones where an event has one, to compare in place.
static func add_dev_section(panel: Node) -> void:
	panel.call("add_section", "Sounds: A/B")
	panel.call("add_button", "First cuts", func() -> void:
		second_cuts = false
		_restream()
		play("ui.confirm"))
	panel.call("add_button", "Second cuts (where an event has one)", func() -> void:
		second_cuts = true
		_restream()
		play("ui.confirm"))
