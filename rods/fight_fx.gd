extends Node3D
## How big a bluefin on the line feels (rods.gd's): pure presentation, worked out on every peer from the rods' own
## state, the same for every boat, and never touching the fight or the clock (Engine.time_scale stays 1: the host's
## sim runs on untouched).
## - The strike (struck): a hit-stop, the white water hanging for HITSTOP s and then let go (eased, flecks and splash
##   only); the rod slammed over into a deep bend and springing back (rod.slam); the clicker screaming (rod.gd feeds
##   the slam into it); your view kicked if it's your boat (player.kick); and an explosion of white water where the
##   line goes in.
## - The fight: drips shaken off the line when it's bar-tight, a spray thrown where it slices into the water while he
##   runs or swings.
## - Late, close and tiring (under CLOSE m of line, energy under TIRED): now and then he shows himself, coming up
##   under the top and rolling over on his side (a flash of his flank), his tail thrashing white water, throwing it
##   onto her deck if he's close in.

const Spray := preload("res://rods/spray.gd")
const HITSTOP := 0.13
## The flecks' time at the very hit (then eased back to 1 over HITSTOP).
const HIT_SLOW := 0.06
const KICK_LEN := 0.6
const SHOW_LEN := 2.6
const SHOW_EVERY := Vector2(4.5, 8.0)
const CLOSE := 32.0
const TIRED := 0.45
## Within DECK_NEAR m of her transom his thrashing throws water aboard.
const DECK_NEAR := 9.0
const WATER := Color(0.92, 0.96, 0.98)
const DRIP := Color(0.78, 0.88, 0.95)

var spread: Node              # rods.gd
var spray: Spray
var _thud: AudioStreamPlayer3D
var _patter: AudioStreamPlayer3D
## rod index -> s since its strike
var _struck := {}
## rod index -> [s into a show (-1: none), s till the next, which way he rolls, s till the next thrash, the next
## splash sound, whether he's flashed yet]
var _shows := {}
var _drip_acc := {}
var _kicking := false


func _ready() -> void:
	spray = Spray.new()
	spray.name = "Spray"
	add_child(spray)
	_thud = AudioStreamPlayer3D.new()
	_thud.stream = preload("res://audio/fish/thud.wav")
	_thud.unit_size = 6.0
	_thud.top_level = true
	add_child(_thud)
	_patter = AudioStreamPlayer3D.new()
	_patter.stream = preload("res://audio/fish/slap.wav")
	_patter.unit_size = 3.0
	_patter.top_level = true
	add_child(_patter)


## Rod r's just been hit (rods.gd's _strike, on every peer).
func struck(r: Node3D) -> void:
	_struck[r.get("index")] = 0.0
	_shows.erase(r.get("index"))
	_thud.global_position = r.global_position
	_thud.pitch_scale = 0.55
	_thud.volume_db = 4.0
	_thud.play()
	var bait: Vector3 = r.get("bait_p")
	var at: Vector3 = bait if bait != Vector3.INF else r.get("line_end")
	var kg := float(r.get("fish_kg"))
	var big := clampf(0.8 + kg / 300.0, 0.8, 1.7)
	# the water blown up off him: a column, a skirt flung wide, and heavy gobs
	for i in int(110 * big):
		var a := randf() * TAU
		var out := randf_range(0.0, 2.6) * big
		spray.emit(at + Vector3(cos(a), 0.0, sin(a)) * randf() * 0.9,
				Vector3(cos(a) * out, randf_range(6.0, 14.0) * big, sin(a) * out),
				randf_range(0.15, 0.45), randf_range(1.4, 2.4), at.y - 0.1, WATER)
	for i in int(70 * big):
		var a := randf() * TAU
		var out := randf_range(3.5, 8.0) * big
		spray.emit(at + Vector3(cos(a), 0.1, sin(a)) * 0.7, Vector3(cos(a) * out, randf_range(1.5, 5.0), sin(a) * out),
				randf_range(0.1, 0.3), randf_range(0.8, 1.5), at.y - 0.1, WATER)
	for i in 14:
		spray.emit(at, Vector3(randf_range(-2.0, 2.0), randf_range(8.0, 15.0) * big, randf_range(-2.0, 2.0)),
				randf_range(0.45, 0.7), 2.0, at.y - 0.1, WATER)
	var ocean := (spread.get("sea") as Node).get("ocean") as Node
	if ocean != null:
		ocean.call("add_splash", at, 2.5 * big)


## The hit-stop's time rate now (1: none running).
func slow() -> float:
	var s := 1.0
	for t: float in _struck.values():
		if t < HITSTOP:
			s = minf(s, lerpf(HIT_SLOW, 1.0, ease(t / HITSTOP, 2.4)))
	return s


## The slam's shape over time: over in three frames, held through the hit-stop, then a damped spring back (a touch
## past straight and back).
static func slam_at(t: float) -> float:
	if t < 0.05:
		return ease(t / 0.05, 0.4)
	if t < HITSTOP + 0.04:
		return 1.0
	var u := t - HITSTOP - 0.04
	return exp(-u * 3.2) * cos(u * 11.0)


## The camera's kick: in at once, out over KICK_LEN.
static func kick_at(t: float) -> float:
	if t < 0.03:
		return t / 0.03
	return maxf(1.0 - (t - 0.03) / (KICK_LEN - 0.03), 0.0) ** 2


func _process(delta: float) -> void:
	if spread == null:
		return
	var rods: Array = spread.get("rods")
	var s := slow()
	spray.slow = s
	var splash: Node = spread.get("_splash")
	if splash != null:
		splash.set("slow", s)
	# the strikes: the rod's slam, your view's kick
	var kick := 0.0
	var crew: Node = (spread.get("sea") as Node).get("crew")
	var me: Node3D = crew.get("me") if crew != null else null
	var boat: Node = (spread.get("sea") as Node).get("boat")
	for i: int in _struck.keys():
		var t: float = _struck[i] + delta
		_struck[i] = t
		if i >= rods.size():
			_struck.erase(i)
			continue
		var r: Node3D = rods[i]
		r.set("slam", slam_at(t) if r.get("hooked") else 0.0)
		if me != null and me.get("frame") == boat:
			var d := me.global_position.distance_to(r.global_position)
			kick = maxf(kick, kick_at(t) * clampf(1.0 - (d - 5.0) / 20.0, 0.0, 1.0))
		if t > 2.0:
			r.set("slam", 0.0)
			_struck.erase(i)
	if me != null and (kick > 0.0 or _kicking):
		me.set("kick", kick)
		_kicking = kick > 0.0
	for r: Node3D in rods:
		if bool(r.get("hooked")) and not bool(r.get("alongside")):
			_line_spray(r, delta)


## Drips shaken off a bar-tight line, and the spray where it slices in.
func _line_spray(r: Node3D, delta: float) -> void:
	var i: int = r.get("index")
	var tip: Vector3 = r.call("tip_position")
	var end: Vector3 = r.get("line_end")
	var strain := float(r.get("strain"))
	var speed := maxf(float(r.get("paying")), 0.0) + float(r.get("cutting"))
	var tight := clampf((strain - 0.55) / 0.35, 0.0, 1.0)
	var cut := clampf((speed - 1.0) / 7.0, 0.0, 1.0)
	var acc: float = _drip_acc.get(i, 0.0) + delta * (tight * 30.0 + cut * 70.0) * spray.slow
	var away := Vector3(end.x - tip.x, 0.0, end.z - tip.z).normalized()
	while acc >= 1.0:
		acc -= 1.0
		if randf() < tight / maxf(tight + cut, 0.01):
			# (off the line itself: it hums, and the water on it shakes off and falls)
			var p := tip.lerp(end, randf_range(0.2, 0.97))
			spray.emit(p, Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.9), randf_range(-0.4, 0.4)),
					0.05 if randf() < 0.7 else 0.1, randf_range(0.6, 1.0), end.y - 0.05, DRIP)
		else:
			# (where it goes in: a fan thrown up the line's back, away from her)
			var side := away.cross(Vector3.UP)
			spray.emit(end + Vector3(0.0, 0.05, 0.0), away * randf_range(0.5, 2.5) + side * randf_range(-1.5, 1.5)
					+ Vector3(0.0, randf_range(1.2, 3.5) * (0.5 + cut), 0.0),
					randf_range(0.05, 0.15), randf_range(0.5, 0.9), end.y - 0.05, WATER)
	_drip_acc[i] = acc


## Where rod r's fish shows (rods.gd's _show_fish, before it moves him there): late in the fight, close and tiring,
## up under the top in a show. `at` is where the fight has him (world), `top` the sea there.
func broach(r: Node3D, at: Vector3, top: float, delta: float) -> Vector3:
	var i: int = r.get("index")
	var tired := float(r.get("energy")) < TIRED and float(r.get("line_out")) < CLOSE and str(r.get("move")) != "jump"
	var sh: Array = _shows.get(i, [-1.0, randf_range(1.5, 3.0), 1.0, 0.0, 0.0, false])
	if sh[0] < 0.0:
		if tired:
			sh[1] -= delta
			if sh[1] <= 0.0:
				sh[0] = 0.0
				sh[2] = -1.0 if randf() < 0.5 else 1.0
				sh[5] = false
		_shows[i] = sh
		return at
	sh[0] += delta
	if sh[0] >= SHOW_LEN:
		sh[0] = -1.0
		sh[1] = randf_range(SHOW_EVERY.x, SHOW_EVERY.y)
		_shows[i] = sh
		return at
	_shows[i] = sh
	var p: float = sh[0] / SHOW_LEN
	var up := smoothstep(0.0, 0.22, p) * (1.0 - smoothstep(0.78, 1.0, p))
	at.y = lerpf(at.y, top - 0.15, up)
	return at


## How far into a show rod r's fish is (0..1; -1: not showing).
func showing(i: int) -> float:
	var sh: Array = _shows.get(i, [-1.0])
	return -1.0 if sh[0] < 0.0 else sh[0] / SHOW_LEN


## Rod r's fish in a show (rods.gd's _show_fish, once he's placed): rolled on his side, his tail thrashing, the water
## he throws (and aboard, close in).
func dress(r: Node3D, fish: Node3D, top: float, delta: float) -> void:
	var i: int = r.get("index")
	var p := showing(i)
	if p < 0.0:
		fish.set("roll", move_toward(float(fish.get("roll")), 0.0, delta * 2.0))
		return
	var sh: Array = _shows[i]
	fish.visible = true
	fish.set("effort", 1.0)
	var k := sin(PI * clampf((p - 0.12) / 0.76, 0.0, 1.0))
	fish.set("roll", float(sh[2]) * 1.3 * k)
	var length := float(fish.get("length"))
	# the flash: his flank catching the light as he goes over, a glint of silver
	if p > 0.45 and not sh[5]:
		sh[5] = true
		var flank := fish.global_position + Vector3(0.0, 0.25, 0.0)
		for n in 7:
			spray.emit(flank + fish.global_basis.x * randf_range(-0.3, 0.3) + fish.global_basis.z * randf_range(-0.4,
					0.4) * length, Vector3(0.0, randf_range(0.3, 1.0), 0.0), 0.1, 0.3, flank.y - 1.0,
					Color(1.0, 1.0, 0.92))
	if p < 0.2 or p > 0.86:
		return
	sh[3] -= delta
	sh[4] -= delta
	if sh[3] > 0.0:
		return
	sh[3] = randf_range(0.08, 0.15)
	# the tail: white water off it, flung to whichever side it's beating
	var tail := fish.global_position + fish.global_basis.z * length * 0.45
	tail.y = top
	var beat := fish.global_basis.x * (1.0 if randf() < 0.5 else -1.0)
	for n in 14:
		spray.emit(tail + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)),
				beat * randf_range(0.5, 2.5) + Vector3(randf_range(-0.8, 0.8), randf_range(1.8, 5.0), randf_range(-0.8, 0.8)),
				randf_range(0.06, 0.2), randf_range(0.6, 1.1), top - 0.1, WATER)
	var ocean := (spread.get("sea") as Node).get("ocean") as Node
	if ocean != null:
		ocean.call("add_splash", tail, 0.7)
	var splash: Node = spread.get("_splash")
	if sh[4] <= 0.0 and splash != null:
		sh[4] = randf_range(0.35, 0.55)
		splash.call("burst", tail, 0.75, true)
	# close in, over her side: some of it comes aboard, pattering on the deck
	var boat := (spread.get("sea") as Node).get("boat") as Node3D
	var stern: Vector3 = spread.get("stern")
	var aft := boat.global_transform * stern
	if Vector2(tail.x - aft.x, tail.z - aft.z).length() < DECK_NEAR and randf() < 0.6:
		var land := boat.global_transform * (stern + Vector3(randf_range(-1.6, 1.6), 0.0, -randf_range(0.6, 2.8)))
		var deck := _deck_at(land, boat)
		var fly := randf_range(0.55, 0.8)
		for n in 5:
			var to := deck + Vector3(randf_range(-0.5, 0.5), 0.05, randf_range(-0.5, 0.5))
			var v := (to - tail) / fly + Vector3(0.0, 0.5 * Spray.GRAVITY * fly, 0.0)
			spray.emit(tail + Vector3(0.0, 0.2, 0.0), v * 1.15, randf_range(0.08, 0.16), fly + 0.4, deck.y, WATER)
		get_tree().create_timer(fly).timeout.connect(func() -> void:
			if is_instance_valid(_patter):
				_patter.global_position = deck
				_patter.pitch_scale = randf_range(1.5, 1.9)
				_patter.volume_db = -8.0
				_patter.play())


## Her deck under a point (world): straight down onto whatever's there, else her waterline plus a bit.
func _deck_at(p: Vector3, boat: Node3D) -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 4.0, 0.0), p + Vector3(0.0, -3.0, 0.0))
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit["position"]
	return Vector3(p.x, boat.global_position.y + 0.8, p.z)
