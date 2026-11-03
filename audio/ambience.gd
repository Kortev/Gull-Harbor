extends Node3D
## The world heard: everything round you that isn't the music, following what's going on (sea/sea.gd adds it, and
## every peer runs its own from what it already has: the weather, the clock, where the boat and the camera are).
## The sounds are tools/ambience.py's (audio/sfx.gd's "amb." events) and the bank's sea, gale and gust; all on the
## Effects bus, and where they come from somewhere, from there.
## - The sea: a calm sea's chuckles, the open sea's wash as it gets up, the heavy sea in a blow; less of it in the
##   harbour, in the lee of the breakwaters.
## - The wind by its strength (a breeze, a gale whistling), a howl as each gust slams in, the wind singing in her
##   rigging (higher the harder it blows, and the faster she goes).
## - The rain on the sea and the deck round you; drumming on the T-top when you're under it.
## - Her hull: the water lapping at her lying still, rushing past her under way, a sea slapping her bow as she comes
##   down off one; her hull groaning and her gear knocking about as she rolls; her wet exhaust burbling with the
##   throttle; her bilge pump kicking in now and then (and running while there's water aboard).
## - The harbour: the town over the water (far traffic, an engine, voices, a clank), the water lapping the quay and the
##   pier, gulls on the pilings calling, halyards slapping in the wind, her lines creaking on their cleats and her
##   fenders squeaking, a voice across the water, a boat going by.
## - Out there: birds far off (and the feeding flocks' own: tuna/schools.gd), a whale blowing or dolphins now and
##   then, the bell buoys rolling (more the rougher it is), the lighthouse's horn when you can't see far.
## - Night: quieter (the wind drops, no gulls, crickets along the shore), so the odd bell carries.
## All of it fades in and out (nothing snaps): the beds move toward their levels, the one-shots come on their own time.

const Sfx := preload("res://audio/sfx.gd")
const Landmarks := preload("res://sea/landmarks.gd")
const Harbour := preload("res://sea/harbour.gd")
## How fast the beds follow (a share a second), and how fast it all comes up at the start.
const EASE := 0.8
const START := 0.4
## The harbour: within IN m of its middle you're in it, past OUT you're out at sea.
const HARBOUR_IN := 220.0
const HARBOUR_OUT := 700.0
## The bell buoys (world x, z): the fairway buoy off the harbour mouth (landmarks.gd's, FAIRWAY m out from the shore)
## and the weather buoy offshore.
const FAIRWAY := 1710.0
const WEATHER_BUOY := Vector2(1500.0, -1700.0)
## The lighthouse's horn sounds every HORN s while you can see less than HORN_SEEING m.
const HORN := 30.0
const HORN_SEEING := 700.0
## A gust past this howls (once per gust, at most every GUST_GAP s).
const GUST_HOWL := 0.3
const GUST_GAP := 3.0
## Her rolling: a swing this big (rad) knocks her gear about; this big groans her hull (in a seaway). Back this far
## (rad) from the furthest she went, she's turned.
const KNOCK_ROLL := 0.02
const GROAN_ROLL := 0.05
const TURN_ROLL := 0.004
## Her bow coming down this far (m) off a sea slaps her; back up TURN_BOW m from the bottom, it's turned.
const SLAP_DROP := 0.12
const TURN_BOW := 0.02

var sea: Node3D          # sea/sea.gd
## -1: on its own; 0..1 a test's own share of the whole (0 silent).
var live := -1.0
## -1: under a roof or not from the visor's look up (sea/visor_rain.gd); 0 or 1: a test's.
var under := -1.0
## The state as heard, for tests and the dev panel: 0..1 each.
var harbour_k := 0.0
var night_k := 0.0
var wind_k := 0.0
var under_k := 0.0
var aboard := false
var _on := 0.0
var _beds := {}               # name -> its loop player
var _bed_at := {}             # name -> where it sits (Node3D), for the ones that come from somewhere
var _next := {}               # one-shot name -> seconds till the next
var _gust_was := 0.0
var _howl_at := -100.0
var _pump := 0.0              # the bilge pump's run left (s)
var _roll_ext := 0.0          # the furthest she's rolled this way, and where she turned last
var _roll_from := 0.0
var _roll_dir := 1.0
var _bow_ext := 0.0           # her bow's height the same way
var _bow_from := 0.0
var _bow_dir := 1.0
var _have_motion := false
var _bells: Array[Vector2] = []
var _t := 0.0


func _ready() -> void:
	name = "Ambience"
	for k: String in ["sea_open", "sea_calm", "wind_low", "wind_high", "rain", "rain_roof"]:
		_beds[k] = Sfx.loop(self, "amb." + k)
	_beds["swell"] = Sfx.loop(self, "sea.swell")
	_beds["gale"] = Sfx.loop(self, "sea.wind")
	for k: String in ["harbour", "night", "quay_lap", "pier_lap"]:
		var at := Node3D.new()
		at.name = k.capitalize().replace(" ", "")
		at.top_level = true
		add_child(at)
		_bed_at[k] = at
		_beds[k] = Sfx.loop(at, "amb.quay_lap" if k.ends_with("lap") else "amb." + k, true)
	for k: String in ["lap", "rush", "rigging", "exhaust", "pump"]:
		var at := Node3D.new()
		at.name = k.capitalize()
		add_child(at)
		_bed_at[k] = at
		_beds[k] = Sfx.loop(at, "amb." + k, true)
	for k: String in ["gull", "bird", "halyard", "moored", "voice", "engine", "bell0", "bell1", "horn", "life", "pump",
			"chop"]:
		_next[k] = randf_range(1.0, 6.0)
	_next["life"] = randf_range(60.0, 150.0)
	_next["pump"] = randf_range(60.0, 180.0)
	_next["horn"] = 4.0
	_bells = [Vector2(Landmarks.HARBOUR_X, _shore(Landmarks.HARBOUR_X) - FAIRWAY), WEATHER_BUOY]


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var ocean: Node = sea.get("ocean") if sea != null else null
	var boat: Node3D = sea.get("boat") if sea != null else null
	if cam == null or ocean == null or boat == null:
		return
	var want := live if live >= 0.0 else 1.0
	_on = move_toward(_on, want, delta * START)
	var eye := cam.global_position
	var w := float(ocean.get("weather"))
	var gust := float(ocean.get("gust"))
	var rain := float(ocean.get("rain"))
	var fx: Node = sea.get("sea_fx")
	var dark := float(fx.get("night")) if fx != null else 0.0
	var helm: Node = boat.get("helm")
	var v := float(helm.get("speed")) if helm != null else 0.0
	var top := maxf(float(helm.get("ahead")) if helm != null else 10.0, 1.0)
	var gas := absf(float(helm.get("throttle"))) if helm != null else 0.0
	var visor: Node = sea.get("visor")
	var out := bool(visor.get("out")) if visor != null else true
	if under >= 0.0:
		out = under < 0.5
	# where you are: in the harbour or out, aboard her or not, under her T-top or out in it
	var mouth := Vector2(Landmarks.HARBOUR_X, _shore(Landmarks.HARBOUR_X) - 90.0)
	var harb := 1.0 - smoothstep(HARBOUR_IN, HARBOUR_OUT, Vector2(eye.x, eye.z).distance_to(mouth))
	harbour_k = move_toward(harbour_k, harb, delta * EASE)
	night_k = move_toward(night_k, smoothstep(0.45, 0.9, dark), delta * EASE * 0.5)
	under_k = move_toward(under_k, 0.0 if out else 1.0, delta * 3.0)
	var local := boat.global_transform.affine_inverse() * eye
	var half := Vector2(float(boat.get("beam")), float(boat.get("length"))) * 0.5 + Vector2(0.6, 0.6)
	aboard = absf(local.x) < half.x and absf(local.z) < half.y and local.y > -1.5 and local.y < 9.0
	var a := _on
	var shelter := lerpf(1.0, 0.25, harbour_k)
	var hush := lerpf(1.0, 0.7, night_k)
	# the sea
	_level("sea_calm", a * (1.0 - smoothstep(0.25, 0.7, w)) * lerpf(0.75, 0.35, harbour_k))
	_level("sea_open", a * smoothstep(0.05, 0.55, w) * shelter * lerpf(1.0, 0.85, under_k))
	_level("swell", a * smoothstep(0.55, 1.0, w) * shelter * 0.9)
	# the wind: the weather's, its gusts, and what she makes going (quieter at night, unless it's blowing)
	var calm_night := lerpf(1.0, hush, 1.0 - smoothstep(0.3, 0.6, w))
	wind_k = clampf(0.12 + 0.62 * w + 0.4 * gust, 0.0, 1.3) * calm_night * lerpf(1.0, 0.75, harbour_k * (1.0 - w))
	var apparent := wind_k + 0.35 * clampf(absf(v) / top, 0.0, 1.0)
	var lee := lerpf(1.0, 0.7, under_k)
	_level("wind_low", a * clampf(0.25 + 0.7 * apparent, 0.0, 1.0) * (1.0 - 0.5 * smoothstep(0.8, 1.2, apparent)) * lee,
			0.9 + 0.2 * gust)
	_level("wind_high", a * smoothstep(0.4, 0.95, apparent) * 0.9 * lee, 0.92 + 0.14 * gust)
	_level("gale", a * smoothstep(0.75, 1.0, w) * lerpf(0.6, 1.0, gust) * lee * 0.8, 0.92 + 0.16 * gust)
	var now := Time.get_ticks_msec() / 1000.0
	if gust >= GUST_HOWL and _gust_was < GUST_HOWL and now - _howl_at > GUST_GAP and a > 0.01:
		_howl_at = now
		Sfx.play("sea.gust", a * lerpf(0.5, 1.0, w) * lee)
	_gust_was = gust
	# the rain: round you out in it, on the T-top over you (and heard from beside it when you're aboard)
	var wet := rain * lerpf(0.85, 1.15, gust)
	_level("rain", a * wet * lerpf(1.0, 0.35, under_k))
	_level("rain_roof", a * wet * maxf(under_k, 0.2 if aboard else 0.0))
	# the harbour: the town over the water, the water at the quay and the pier
	_place_at("harbour", Vector3(mouth.x, 4.0, _shore(mouth.x) + 40.0))
	var town := 1.0 - smoothstep(900.0, 1800.0, Vector2(eye.x, eye.z).distance_to(mouth))
	_level("harbour", a * town * lerpf(1.0, 0.35, night_k) * (1.0 - 0.5 * smoothstep(0.5, 1.0, w)))
	_place_at("night", Vector3(eye.x, 2.0, _shore(eye.x) + 15.0))
	_level("night", a * night_k * (1.0 - smoothstep(0.2, 0.5, rain + w * 0.4)) * 0.7)
	var qx := clampf(eye.x, Landmarks.FRONT_X.x, Landmarks.FRONT_X.y)
	_place_at("quay_lap", Vector3(qx, 0.2, _shore(qx) - 2.5))
	_level("quay_lap", a * smoothstep(0.1, 0.6, harbour_k) * lerpf(0.8, 1.2, w))
	var pier := _pier_point(eye)
	_place_at("pier_lap", pier)
	_level("pier_lap", a * smoothstep(0.1, 0.6, harbour_k) * 0.7)
	# her hull: the water lapping at her side nearest you lying still, rushing past under way
	var side := 1.0 if local.x >= 0.0 else -1.0
	var beside := Vector3(side * float(boat.get("beam")) * 0.5, 0.0, clampf(local.z, -half.y + 1.0, half.y - 1.0))
	(_bed_at["lap"] as Node3D).position = beside
	(_bed_at["rush"] as Node3D).position = beside
	var going := clampf((absf(v) - 0.4) / (top * 0.7), 0.0, 1.0)
	_level("lap", a * (1.0 - smoothstep(0.1, 0.5, going)) * lerpf(0.6, 1.0, w) * hush)
	_level("rush", a * smoothstep(0.0, 0.6, going) * lerpf(0.85, 1.15, w), 0.8 + 0.45 * going)
	var spec: Dictionary = boat.get("spec")
	(_bed_at["rigging"] as Node3D).position = spec.get("crown", Vector3(0.0, 3.0, 0.0))
	_level("rigging", a * smoothstep(0.35, 1.1, apparent) * 0.8, 0.8 + 0.45 * clampf(apparent, 0.0, 1.2))
	var transom: Vector3 = spec.get("transom", Vector3(0.0, 0.0, 6.0))
	(_bed_at["exhaust"] as Node3D).position = Vector3(transom.x + 0.6, 0.2, transom.z)
	_level("exhaust", a * (0.35 + 0.65 * gas) * 0.8, 0.8 + 0.5 * gas)
	_bilge(delta, boat, transom)
	_motion(delta, boat, w, v, top)
	_harbour_life(delta, boat, eye, w)
	_sea_life(delta, eye, w, dark)


## The bilge pump: it kicks in now and then on its own (her float switch: oftener the rougher it is) and runs while
## there's water aboard; the motor whirring and the water spurting over her side, coming up and going away.
func _bilge(delta: float, boat: Node3D, transom: Vector3) -> void:
	var green: Node = boat.get("green")
	var water := float(green.get("water")) if green != null else 0.0
	_next["pump"] = float(_next["pump"]) - delta * lerpf(1.0, 3.0, float(sea.get("ocean").get("weather")))
	if float(_next["pump"]) <= 0.0:
		_next["pump"] = randf_range(120.0, 260.0)
		_pump = randf_range(5.0, 9.0)
	if water > 0.02:
		_pump = maxf(_pump, 2.0)
	_pump = maxf(_pump - delta, 0.0)
	var at := _bed_at["pump"] as Node3D
	at.position = Vector3(float(boat.get("beam")) * 0.5 - 0.1, 0.1, transom.z - 1.5)
	var p := _beds.get("pump") as Node
	var was := float(p.get_meta("sfx_amount", 0.0)) if p != null else 0.0
	Sfx.level(p, move_toward(was, _on * 0.9 if _pump > 0.0 else 0.0, delta * (3.0 if _pump > 0.0 else 1.5)))


## Her rolling and pitching as felt aboard: at the end of each roll her gear knocks (and in a seaway her hull groans),
## and at the bottom of each fall her bow slaps the sea (spray off it, going fast into it); in a blow the chop slaps
## her between the swells too, oftener going into it. (The ends of a roll or a fall are where she's come back past a
## little dead band from the furthest she went, so a still frame or a tremble isn't one.)
func _motion(delta: float, boat: Node3D, w: float, v: float, top: float) -> void:
	if delta <= 0.0:
		return
	var b := boat.global_basis
	var roll := asin(clampf(b.x.y, -1.0, 1.0))
	var length := float(boat.get("length"))
	var bow := boat.global_position.y - b.z.y * length * 0.5
	if not _have_motion:
		_have_motion = true
		_roll_ext = roll
		_roll_from = roll
		_bow_ext = bow
		_bow_from = bow
		return
	if (roll - _roll_ext) * _roll_dir > 0.0:
		_roll_ext = roll
	elif absf(roll - _roll_ext) > TURN_ROLL:
		# the end of a roll: how far she swung
		var swing := absf(_roll_ext - _roll_from)
		_roll_from = _roll_ext
		_roll_ext = roll
		_roll_dir = -_roll_dir
		if randf() < smoothstep(KNOCK_ROLL, KNOCK_ROLL * 3.0, swing):
			var k := clampf(swing / (KNOCK_ROLL * 4.0), 0.3, 1.0)
			Sfx.play_point(self, boat.global_transform * _gear_spot(boat), "amb.knock", _on * k)
			if randf() < 0.35:
				Sfx.play_point(self, boat.global_transform * _gear_spot(boat), "amb.clink", _on * k, randf_range(0.9, 1.15))
		if swing > GROAN_ROLL and w > 0.3 and randf() < 0.5:
			Sfx.play_point(self, boat.global_transform * Vector3(0.0, 0.0, randf_range(-1.0, 1.5)), "amb.groan",
					_on * clampf(swing / (GROAN_ROLL * 2.5), 0.4, 1.0), randf_range(0.85, 1.1))
	var going := clampf(absf(v) / top, 0.0, 1.0)
	var slap := -1.0
	if (bow - _bow_ext) * _bow_dir > 0.0:
		_bow_ext = bow
	elif absf(bow - _bow_ext) > TURN_BOW:
		# her bow at the top or the bottom of its fall: at the bottom, the sea slapping her
		var drop := _bow_from - _bow_ext
		if _bow_dir < 0.0 and drop > SLAP_DROP:
			slap = clampf(drop / (SLAP_DROP * 4.0), 0.35, 1.0)
		_bow_from = _bow_ext
		_bow_ext = bow
		_bow_dir = -_bow_dir
	if _tick("chop", delta, smoothstep(0.2, 0.8, w) * (1.0 + 2.0 * going), 2.0, 7.0):
		slap = maxf(slap, randf_range(0.3, 0.7) * lerpf(0.7, 1.0, w))
	if slap > 0.0:
		var at: Vector3 = (boat.get("spec") as Dictionary).get("bow", Vector3(1.0, 0.5, -length * 0.4))
		var p := boat.global_transform * Vector3(at.x * (1.0 if randf() < 0.5 else -1.0), 0.0,
				lerpf(at.z, 0.0, randf() * (1.0 - going)))
		Sfx.play_point(self, p, "amb.slap", _on * slap)
		if going > 0.4 and w > 0.35:
			Sfx.play_point(self, p + Vector3.UP, "sea.spray", _on * slap * 0.7, randf_range(0.9, 1.2))


## Somewhere on her deck where gear's stowed (boat-local): along her sides and her transom.
func _gear_spot(boat: Node3D) -> Vector3:
	var beam := float(boat.get("beam"))
	var length := float(boat.get("length"))
	return Vector3(randf_range(-0.42, 0.42) * beam, float(boat.get("deck")) + 0.4, randf_range(-0.1, 0.42) * length)


## The harbour going about its day: gulls on the pilings, halyards slapping in the wind, her lines and fenders when
## she's lying alongside, a voice across the water, a boat going by.
func _harbour_life(delta: float, boat: Node3D, eye: Vector3, w: float) -> void:
	var harbour: Node = sea.get("harbour")
	if harbour == null:
		return
	var h := harbour_k
	var day := 1.0 - night_k
	if _tick("gull", delta, h * day * (1.0 - smoothstep(0.6, 0.95, w)), 3.0, 9.0):
		var gulls: Array = harbour.get("_gulls")
		var at := eye + Vector3(randf_range(-60.0, 60.0), randf_range(8.0, 25.0), randf_range(-60.0, 60.0))
		if not gulls.is_empty() and randf() < 0.6:
			at = (gulls[randi() % gulls.size()] as Node3D).global_position + Vector3(0, 0.3, 0)
		Sfx.play_point(self, at, "amb.gull", _on * randf_range(0.5, 1.0), randf_range(0.92, 1.08))
	if _tick("halyard", delta, h * smoothstep(0.05, 0.5, wind_k), lerpf(7.0, 1.2, wind_k), lerpf(14.0, 3.0, wind_k)):
		var moored: Array = harbour.get("_moored")
		var at := Vector3(eye.x + randf_range(-40.0, 40.0), 6.0, _shore(eye.x) - 4.0)
		if not moored.is_empty() and randf() < 0.7:
			at = (moored[randi() % moored.size()] as Node3D).global_position + Vector3(0, randf_range(3.0, 6.0), 0)
		Sfx.play_point(self, at, "amb.halyard", _on * randf_range(0.4, 0.9) * lerpf(0.6, 1.0, wind_k))
	var lines: Node = boat.get("lines")
	var tied := lines != null and bool(lines.call("tied"))
	if _tick("moored", delta, (1.0 if tied else 0.0), lerpf(5.0, 1.5, w), lerpf(11.0, 4.0, w)):
		var beam := float(boat.get("beam"))
		var length := float(boat.get("length"))
		var deck := float(boat.get("deck"))
		var end := 1.0 if randf() < 0.5 else -1.0
		if randf() < 0.6:
			Sfx.play_point(self, boat.global_transform * Vector3(-beam * 0.5, deck + 0.3, end * length * 0.38), "amb.creak",
					_on * randf_range(0.5, 1.0))
		else:
			Sfx.play_point(self, boat.global_transform * Vector3(-beam * 0.5 - 0.2, 0.3, randf_range(-0.3, 0.3) * length),
					"amb.fender", _on * randf_range(0.5, 1.0), randf_range(0.9, 1.1))
	if _tick("voice", delta, h * smoothstep(0.0, 0.6, day) * (1.0 - smoothstep(0.5, 0.9, w)), 18.0, 45.0):
		var x := randf_range(Landmarks.FRONT_X.x, Landmarks.FRONT_X.y)
		Sfx.play_point(self, Vector3(x, 3.5, _shore(x) + randf_range(5.0, 40.0)), "amb.voice", _on * randf_range(0.5, 1.0),
				randf_range(0.9, 1.1))
	if _tick("engine", delta, smoothstep(0.0, 0.5, h + 0.2) * lerpf(1.0, 0.3, night_k) * (1.0 - smoothstep(0.6, 0.9, w)),
			60.0, 160.0):
		_boat_by(eye)


## A boat going by out there: heard from somewhere that moves, across the water in front of the harbour.
func _boat_by(eye: Vector3) -> void:
	var mover := Node3D.new()
	mover.name = "BoatBy"
	mover.top_level = true
	add_child(mover)
	var dir := Vector3(1.0 if randf() < 0.5 else -1.0, 0.0, 0.0)
	var off := randf_range(150.0, 450.0)
	var mid := Vector3(eye.x, 1.0, minf(eye.z - off, _shore(eye.x) - 120.0))
	mover.global_position = mid - dir * 45.0
	var tw := mover.create_tween()
	tw.tween_property(mover, "global_position", mid + dir * 45.0, 14.5)
	tw.tween_callback(mover.queue_free)
	Sfx.play_at(mover, "amb.engine_far", 0.0, _on * randf_range(0.6, 1.0))


## Out there: birds far off, a whale or dolphins now and then, the bell buoys rolling, the lighthouse's horn.
func _sea_life(delta: float, eye: Vector3, w: float, dark: float) -> void:
	var open := 1.0 - harbour_k
	var day := 1.0 - night_k
	if _tick("bird", delta, open * day * (1.0 - smoothstep(0.5, 0.8, w)), 20.0, 60.0):
		var a := randf() * TAU
		var at := eye + Vector3(cos(a), 0.0, sin(a)) * randf_range(60.0, 220.0) + Vector3.UP * randf_range(5.0, 20.0)
		Sfx.play_point(self, at, "amb.tern" if randf() < 0.5 else "amb.gull", _on * randf_range(0.4, 0.8),
				randf_range(0.95, 1.12))
	if _tick("life", delta, open * (1.0 - smoothstep(0.4, 0.7, w)) * lerpf(1.0, 0.4, dark), 90.0, 240.0):
		var a := randf() * TAU
		if randf() < 0.55:
			Sfx.play_point(self, eye + Vector3(cos(a), 0.0, sin(a)) * randf_range(150.0, 450.0), "amb.blow",
					_on * randf_range(0.7, 1.0), randf_range(0.85, 1.05))
		else:
			Sfx.play_point(self, eye + Vector3(cos(a), 0.0, sin(a)) * randf_range(35.0, 110.0), "amb.dolphin",
					_on * randf_range(0.6, 1.0))
	# the bell buoys: the clapper swinging as the buoy rolls on the swell, once in a while in a calm, every roll in a blow
	for i in _bells.size():
		var b := _bells[i]
		var at := Vector3(b.x, 2.5, b.y)
		var gap := lerpf(16.0, 2.0, smoothstep(0.05, 0.8, w))
		if _tick("bell%d" % i, delta, 1.0 if eye.distance_to(at) < 3600.0 else 0.0, gap * 0.5, gap * 1.4):
			Sfx.play_point(self, at, "amb.bell", _on * lerpf(0.5, 1.0, w) * randf_range(0.7, 1.0), randf_range(0.99, 1.01))
	var seeing := float(sea.get("seeing"))
	if _tick("horn", delta, 1.0 if seeing < HORN_SEEING else 0.0, HORN, HORN):
		var lx := Landmarks.LIGHTHOUSE_X
		Sfx.play_point(self, Vector3(lx, 25.0, _shore(lx) + 20.0), "amb.foghorn", _on)


## Counts down one-shot `key`'s wait, `rate` (0..1) as fast; at 0 it's time (and the next is lo..hi s off). Nothing
## comes while rate is 0.
func _tick(key: String, delta: float, rate: float, lo: float, hi: float) -> bool:
	if rate <= 0.001 or _on <= 0.01:
		return false
	var left := float(_next.get(key, 0.0)) - delta * rate
	if left > 0.0:
		_next[key] = left
		return false
	_next[key] = randf_range(lo, hi)
	return true


func _level(key: String, amount: float, pitch := -1.0) -> void:
	var p := _beds.get(key) as Node
	if p == null:
		return
	# (each bed eases toward where it should be: nothing jumps)
	var was := float(p.get_meta("sfx_amount", 0.0))
	Sfx.level(p, move_toward(was, maxf(amount, 0.0), get_process_delta_time() * EASE), pitch)


func _place_at(key: String, at: Vector3) -> void:
	(_bed_at[key] as Node3D).global_position = at


## The shore's line at x (landmarks.gd's): where the quay and the town are.
func _shore(x: float) -> float:
	var marks: Node = sea.get("landmarks")
	return float(marks.call("shore_z", x)) if marks != null else 2232.0


## The nearest point of the fish pier's side at the water to `eye`.
func _pier_point(eye: Vector3) -> Vector3:
	var px := Harbour.PIER_X
	var face := _shore(px) - 2.0
	var z := clampf(eye.z, face - 80.0, face)
	return Vector3(px + (2.2 if eye.x > px else -2.2), 0.2, z)


## A bed's level now (0..1, as set: tests and the dev panel).
func level_of(key: String) -> float:
	var p := _beds.get(key) as Node
	return float(p.get_meta("sfx_amount", 0.0)) if p != null else 0.0
