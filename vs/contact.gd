extends Node
## Where the two boats in VS (vs/vs.gd) meet: they're solid to each other and the one's wake rocks the other. (Running
## across the other's lines doesn't cut them: it did, and it made a stalemate where nobody got a fish.)
##
## Bumping: each hull's a capsule on the water (her length and beam, along her heading, where the helm has her).
## Whoever moves a boat (her captain, or the host with nobody at her wheel: boat/helm.gd) keeps her out of the other
## (fend): out of the overlap, and if they're closing, shoved apart by their speeds (an even split between two boats
## of a kind), part of it on her way ahead or astern, the rest sideways (the helm's drift), and a slew round from where
## she was hit (its spin). Every peer hears and feels it on its own: the thud where they met, both boats knocked over
## and rocking back (boat/boat.gd's rock), and anyone standing on deck staggering in a hard one.
##
## Wakes: each boat leaves a trail (where she was, which way she was going, how fast); her V's arms spread from it at
## the Kelvin angle, so the other boat crossing an arm gets a roll (crossing it side on) or a pitch (head on), fading
## as it ages. Two arms, two knocks. Every peer works it out from the helms' word. The wake bomb: a hull throws its
## biggest wake ploughing along at 10 to 14 knots (WAKE_SPEED), not up on the plane flat out, so slowing to bury the
## other boat costs you time. Taken beam on, close, it's a hard roll, the sea slopping in over her transom, everyone
## standing staggering and their view jolted; her captain turning her bow into it takes it as a pitch, softer.

const Helm := preload("res://boat/helm.gd")
const Sfx := preload("res://audio/sfx.gd")
## The capsule is this far in from her length and beam (m): her bow's fine and her sides flare.
const SKIN := 0.25
## How lively a bump is (0 dead .. 1 a rubber ball): fibreglass and rubbing strakes.
const BOUNCE := 0.35
## Bumps closer together than this (s) are the one bump.
const AGAIN := 0.6
## Her rocking back: how fast (rad/s) and how soon it dies (a fraction of critical); never past ROCK_MAX (rad).
const ROCK_W := TAU / 2.6
const ROCK_DAMP := 0.22
const ROCK_MAX := 0.22
## The kick (rad/s of rocking) for each m/s two boats meet at, and for a hard wake.
const BUMP_KICK := 0.05
const WAKE_KICK := 0.32
## Meeting harder than this (m/s), anyone standing on deck staggers.
const STAGGER := 2.5
## The trail: a point every TRAIL_EVERY s she's going faster than TRAIL_SPEED (m/s), kept WAKE_LIFE s. The arms go out
## at KELVIN (tan 19.5 deg) of how far she's gone since, ARM m wide.
const TRAIL_EVERY := 0.3
const TRAIL_SPEED := 1.5
const WAKE_LIFE := 30.0
const KELVIN := 0.354
const ARM := 2.5
## Her wake's biggest between these speeds (m/s); up on the plane flat out it's this much of that.
const WAKE_SPEED := Vector2(5.5, 7.0)
const PLANED := 0.45
## A wake this hard (0..1, beam on) buries her: the sea over her transom, the crew staggering, their view jolted.
const BOMB := 0.45

var vs: Node                  # vs/vs.gd
var _rock: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _rock_v: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _touching := false
var _thud_t := -INF
var _closing := 0.0           # how fast they were coming together, lately (m/s)
var _shoved := {}             # helm instance id -> when it was last shoved (s)
var _trails: Array = [[], []] # per boat: [at, way, speed, t], the newest first
var _trail_in := 0.0
var _in_arm: Array[bool] = [false, false]
var _clock := 0.0
var _jolt := 0.0              # your view shaken (0..1), dying away
## Wake bombs each boat's taken (A, B).
var bombs := [0, 0]


## A hull on the water: her keel line's two ends (world x, z) and how far her sides are from it.
static func hull(boat: Node3D) -> Array:
	var h: Node = boat.get("helm")
	var ahead := Helm.ahead_of(float(h.get("heading")))
	var r := float(boat.get("beam")) * 0.5 - SKIN
	var half := maxf(float(boat.get("length")) * 0.5 - SKIN - r, 0.0)
	var at: Vector2 = h.get("at")
	return [at + ahead * half, at - ahead * half, r]


## Boat `a` against boat `b`: {} when they're more than `margin` m apart, else how far apart their sides are (`gap`,
## m: below 0 they overlap), the way out for `a` (`normal`, from b to a) and where they meet (`point`, world x, z).
static func contact(a: Node3D, b: Node3D, margin := 0.0) -> Dictionary:
	var ha := hull(a)
	var hb := hull(b)
	var c := Geometry2D.get_closest_points_between_segments(ha[0], ha[1], hb[0], hb[1])
	var d: Vector2 = c[0] - c[1]
	var dist := d.length()
	var gap := dist - float(ha[2]) - float(hb[2])
	if gap > margin:
		return {}
	var n := d / dist if dist > 0.001 else Vector2.RIGHT
	return {"gap": gap, "normal": n, "point": c[1] + n * float(hb[2])}


## How a boat's going over the water (world x, z, m/s).
static func velocity(h: Node) -> Vector2:
	return Helm.ahead_of(float(h.get("heading"))) * float(h.get("speed")) + (h.get("drift") as Vector2)


func _boats() -> Array:
	return (vs.get("sides") as Array).map(func(s: Node) -> Node3D: return s.get("boat"))


## Whoever moves helm `h`'s boat, after she's moved: out of the other boat, and shoved off her if they were closing.
func fend(h: Node) -> void:
	var boats := _boats()
	var i := boats.find(h.get("boat"))
	if boats.size() != 2 or i < 0:
		return
	var c := contact(boats[i], boats[1 - i])
	if c.is_empty() or float(c["gap"]) >= 0.0:
		return
	var n: Vector2 = c["normal"]
	var oh: Node = (boats[1 - i] as Node).get("helm")
	# (half of it: whoever moves the other one takes the other half, here or on their machine, so neither boat's a wall
	# the other can't shove)
	h.set("at", (h.get("at") as Vector2) - n * float(c["gap"]) * 0.5)
	var closing := (velocity(oh) - velocity(h)).dot(n)
	if closing <= 0.05 or not _fresh(h):
		return
	# both shoved, equal and opposite: this one here, the other here too or on whoever's machine moves her (her
	# captain's, or the host's with nobody at her wheel), so it's the same bump whichever of them saw it first
	var dv := n * closing * (1.0 + BOUNCE) * 0.5
	var p: Vector2 = c["point"]
	_shove(h, dv, p)
	var driver := int(oh.get("captain"))
	if driver == 0:
		driver = 1
	if bool(oh.call("is_mine")) or (int(oh.get("captain")) == 0 and Net.is_host()) or not Net.in_session():
		if _fresh(oh):
			_shove(oh, -dv, p)
	elif driver != Net.my_id():
		_shoved_by.rpc_id(driver, 1 - i, -dv, p)


## Whether helm `h` hasn't been shoved in the last AGAIN s (and it's to be now).
func _fresh(h: Node) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_shoved.get(h.get_instance_id(), -INF)) < AGAIN:
		return false
	_shoved[h.get_instance_id()] = now
	return true


## The other machine saw the bump first: boat `i` (0 A, 1 B), which this machine moves, shoved by `dv` at `point`.
@rpc("any_peer", "call_remote", "reliable")
func _shoved_by(i: int, dv: Vector2, point: Vector2) -> void:
	var boats := _boats()
	if boats.size() != 2 or i < 0 or i > 1:
		return
	var h: Node = (boats[i] as Node).get("helm")
	if (bool(h.call("is_mine")) or (int(h.get("captain")) == 0 and Net.is_host())) and _fresh(h):
		_shove(h, dv, point)


## Helm `h`'s boat shoved by `dv` (m/s, world x, z) where she was hit: part on her way, the rest sideways (her drift),
## and a slew round from off her middle (a +heading turns her bow the way a - cross product goes).
func _shove(h: Node, dv: Vector2, point: Vector2) -> void:
	var ahead := Helm.ahead_of(float(h.get("heading")))
	var along := dv.clampf(-6.0, 6.0).dot(ahead)
	h.set("speed", float(h.get("speed")) + along)
	h.set("drift", (h.get("drift") as Vector2) + dv.clampf(-6.0, 6.0) - ahead * along)
	var arm: Vector2 = point - (h.get("at") as Vector2)
	var length := float((h.get("boat") as Node).get("length"))
	var turn := -arm.cross(dv) / (length * length / 12.0) * 0.5
	h.set("spin", clampf(float(h.get("spin")) + turn, -0.35, 0.35))


func _process(delta: float) -> void:
	if not bool(vs.get("on")):
		return
	var boats := _boats()
	if boats.size() != 2:
		return
	_clock += delta
	_bumps(boats)
	_wakes(boats, delta)
	for i in 2:
		var a := -ROCK_W * ROCK_W * _rock[i] - 2.0 * ROCK_DAMP * ROCK_W * _rock_v[i]
		_rock_v[i] += a * delta
		_rock[i] = (_rock[i] + _rock_v[i] * delta).clampf(-ROCK_MAX, ROCK_MAX)
		(boats[i] as Node).set("rock", _rock[i])
	if _jolt > 0.0:
		_jolt = move_toward(_jolt, 0.0, delta * 1.6)
		var me: Node = vs.get("sea").get("crew").get("me")
		if me != null:
			me.set("shake", _jolt)


## Every peer: the two coming together, heard and felt.
func _bumps(boats: Array) -> void:
	var c := contact(boats[0], boats[1], 3.0)
	if c.is_empty():
		_touching = false
		_closing = 0.0
		return
	var n: Vector2 = c["normal"]
	var ha: Node = (boats[0] as Node).get("helm")
	var hb: Node = (boats[1] as Node).get("helm")
	# (how fast they were closing just before: by the time this peer sees them touch, whoever moves them may have
	# shoved them apart already)
	_closing = maxf(_closing * 0.9, (velocity(hb) - velocity(ha)).dot(n))
	var touching := float(c["gap"]) < 0.35
	if touching and not _touching and _clock - _thud_t > AGAIN and _closing > 0.4:
		_thud_t = _clock
		_thud(boats, c, _closing)
	_touching = touching


func _thud(boats: Array, c: Dictionary, hard: float) -> void:
	var p: Vector2 = c["point"]
	var ocean: Node = vs.get("sea").get("ocean")
	var y := float(ocean.call("height_at", Vector3(p.x, 0.0, p.y))) + 0.8 if ocean != null else 0.8
	var loud := clampf(hard / 3.0, 0.35, 1.0)
	Sfx.play_point(self, Vector3(p.x, y, p.y), "kit.thud", loud, 0.55)
	if hard > 1.5:
		Sfx.play_point(self, Vector3(p.x, y, p.y), "sea.slam", loud * 0.6, 1.2)
	var n: Vector2 = c["normal"]
	_knock(boats, 0, n, hard * BUMP_KICK)
	_knock(boats, 1, -n, hard * BUMP_KICK)
	var me: Node = vs.get("sea").get("crew").get("me")
	if hard > STAGGER and me != null and boats.has(me.get("boat")) and not bool(me.get("steering")):
		me.call("gesture", "stumble")


## Boat i pushed toward `push` (world x, z) with `kick` rad/s: she heels away from the side it came from.
func _knock(boats: Array, i: int, push: Vector2, kick: float) -> void:
	var b := boats[i] as Node3D
	var local := b.global_basis.inverse() * Vector3(push.x, 0.0, push.y)
	_rock_v[i] += Vector2(local.z * 0.6, -local.x) * minf(kick, 0.4)


## Every peer: each boat's trail, and the other's arms rocking her as she crosses them (or they pass under her).
func _wakes(boats: Array, delta: float) -> void:
	_trail_in -= delta
	var drop := _trail_in <= 0.0
	if drop:
		_trail_in = TRAIL_EVERY
	for i in 2:
		var h: Node = (boats[i] as Node).get("helm")
		var trail: Array = _trails[i]
		var v := float(h.get("speed"))
		if drop and absf(v) > TRAIL_SPEED:
			trail.push_front([h.get("at"), Helm.ahead_of(float(h.get("heading"))) * signf(v), absf(v), _clock,
					wake_power(absf(v))])
		while not trail.is_empty() and _clock - float(trail.back()[3]) > WAKE_LIFE:
			trail.pop_back()
	for i in 2:
		var h: Node = (boats[i] as Node).get("helm")
		var at: Vector2 = h.get("at")
		var power := 0.0
		var push := Vector2.ZERO
		for s: Array in _trails[1 - i]:
			var age := _clock - float(s[3])
			if age < 1.0:
				continue
			var way: Vector2 = s[1]
			var rel: Vector2 = at - (s[0] as Vector2)
			if absf(rel.dot(way)) > float(s[2]) * TRAIL_EVERY * 0.5 + 1.0:
				continue
			var off := way.cross(rel)
			var reach := 1.5 + KELVIN * float(s[2]) * age
			if absf(absf(off) - reach) > ARM:
				continue
			var p := float(s[4]) * (1.0 - age / WAKE_LIFE)
			if p > power:
				power = p
				push = Vector2(-way.y, way.x) * signf(off)      # (out from her track, toward this boat)
		var in_arm := power > 0.05
		if in_arm and not _in_arm[i]:
			# (bow into it, it's a pitch and softer; beam on, the full roll)
			var beam_on := absf(Helm.ahead_of(float(h.get("heading"))).cross(push))
			var hit := power * lerpf(0.35, 1.0, beam_on)
			_knock(boats, i, push, hit * WAKE_KICK)
			var b := boats[i] as Node3D
			var bow := b.global_transform * Vector3(0.0, 0.3, -float(b.get("length")) * 0.35)
			Sfx.play_point(self, bow, "dock.slap", clampf(power * 1.4, 0.3, 1.0), 0.8)
			if hit > BOMB:
				_bomb(boats, i, hit)
		_in_arm[i] = in_arm


## Your view shaken (0..1: the horn, vs/horn.gd), dying away.
func jolt(amount: float) -> void:
	_jolt = maxf(_jolt, amount)


## How big a wake she throws at `v` m/s (0..1): nothing slow, the most ploughing along, less up on the plane.
static func wake_power(v: float) -> float:
	return smoothstep(TRAIL_SPEED, WAKE_SPEED.x, v) * (1.0 - (1.0 - PLANED) * smoothstep(WAKE_SPEED.y, 10.0, v))


## Boat i buried by a wake (`hit` 0..1): the sea in over her transom, her crew staggering and their view jolted.
func _bomb(boats: Array, i: int, hit: float) -> void:
	bombs[i] += 1
	var b := boats[i] as Node3D
	var wake := b.get_node_or_null("Wake")
	var over: GPUParticles3D = wake.get("_over") if wake != null else null
	if over != null:
		over.restart()
		over.emitting = true
		Sfx.play_point(self, over.global_position, "sea.back", clampf(hit, 0.6, 1.0))
	Sfx.play_point(self, b.global_position, "sea.slam", clampf(hit, 0.5, 1.0), 0.9)
	var me: Node = vs.get("sea").get("crew").get("me")
	if me != null and me.get("boat") == b:
		_jolt = maxf(_jolt, clampf(hit * 1.2, 0.5, 1.0))
		if not bool(me.get("steering")):
			me.call("gesture", "stumble")

