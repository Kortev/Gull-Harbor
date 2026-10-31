extends Node
## Landing a fish: from boatside to the deck. A fish fought to the boat (tuna/fight.gd's boatside) comes up beaten
## and circles slowly near the surface, still on the line: astern of the sportfisher's transom, or along the skiff's
## side by her stern quarter. Someone sticks it with the harpoon (E on the harpoon along the port side; hold left
## mouse to wind up, let go to throw; Q puts it back), then it's hauled aboard: through the sportfisher's tuna door in
## the transom, over the skiff's gunwale (hold E there: one person can, slowly; two or three make short work of a
## giant). Then it's on deck (boat/fish_hold.gd). Leave it alongside too long without sticking it and the hook pulls.
## Where all of that is comes from the boat's kind (boat/kinds.gd).
##
## The throw is a skill. The harpoon flies from your hands where it's pointing, as hard as you wound it, and falls as
## it goes (a dotted arc shows where it'll come down while you wind); it sticks only if its point passes through the
## fish's back, and the fish keeps swimming its slow circle while it's in the air, so you lead it. Hold it wound too
## long and your arm shakes. A miss splashes in beside it and spooks it: each miss is a chance it tears the hook out
## and goes (ESCAPE: more each time), and the HUD says the odds. Hit or miss, the harpoon comes back to its rack on
## its line, hand over hand; stuck, the dart stays in the fish, its orange float on the water beside it.
##
## Someone has to hold it there: the angler keeping the rod (or the wireman on the leader). Left on a rod in its
## holder it isn't held: every SHEER_EVERY s it kicks, sheers off and goes down out of reach for SHEER_FOR s, the rod
## bending over, then wallows back up. You can still stick it alone between kicks; with a mate on the rod it lies
## quiet for the harpoon. All worked out from the shared clock and who holds the rod, so every peer sees the same.
##
## The host decides (who has the harpoon, a stick, a miss's roll, how far the haul has got) and tells everyone. A
## throw is flown and judged on the thrower's machine (it's their aim) and the host takes their word for it; everyone
## else flies the same throw from what the thrower let go.

const Tuna := preload("res://tuna/tuna.gd")
const Action := preload("res://core/action.gd")
const Sfx := preload("res://audio/sfx.gd")
const Splash := preload("res://sea/splash.gd")

## Seconds a fish lies alongside before the hook pulls, if nobody sticks it.
const HOOK_HOLDS := 90.0
## On a boat whose kind says `wire` (the sportfisher's high transom), someone has to wire the fish (E at the transom:
## grab the leader) before it can be stuck; the wire holds it this long (s), then it's thrashing free again.
const WIRE_HOLD := 15.0
## The throw: DRAW s of holding left mouse winds it all the way; let go and it leaves your hands at THROW_SPEED m/s
## (a flick .. all you've got) and falls at GRAVITY. It sticks a fish if its point passes within HIT x the fish's
## length of the line of its back (snout to the root of its tail). Held wound more than SWAY_AFTER s, the point starts
## to wander (SWAY radians at worst). REACH: the farthest a throw from your eyes can count (m).
const DRAW := 0.7
const THROW_SPEED := Vector2(7.0, 19.0)
const GRAVITY := 9.8
const HIT := 0.2
const SWAY_AFTER := 1.2
const SWAY := 0.06
const REACH := 12.0
## The harpoon: its point, m ahead of where you hold it; after a throw it lies a moment, then comes back to the rack
## on its line in RETURN s.
const TIP := 1.92
const RETURN := 1.4
## How far under the top its point gets before a throw that's found nothing is a miss (m).
const SINK := 0.7
## Each miss spooks it: the chance it tears the hook out and goes, on the first miss, the second, the third, and every
## one after that.
const ESCAPE := [0.25, 0.4, 0.55, 0.7]
## Getting away (the hook pulled, torn free): it swims off out and down for LEAVE s, the line going with it, then it's
## gone. Coming up alongside it swims from where the fight left it into its circle over ARRIVE s (longer from farther
## off: ARRIVE_SPEED m/s).
const LEAVE := 2.5
const ARRIVE := 2.0
const ARRIVE_SPEED := 2.5
const ARRIVE_FROM := 20.0
## Beaten alongside it still swims: a slow lap LAP s round, an oval LAP_R m (along, out) beside her, its back near
## the top on one side and a little deeper on the other; a kick of its tail now and then speeds it up a moment.
## Stuck, it wallows in a smaller, slower one; a miss spooks it into a quick bolt out and back (SPOOK s).
const LAP := 9.0
const LAP_R := Vector2(0.9, 0.4)
const SPOOK := 1.6
## The haul: seconds for one person to haul a fish aboard, HAUL_BASE + kg * HAUL_PER_KG (a giant about 20 s);
## each extra hand on it adds the same again.
const HAUL_BASE := 2.0
const HAUL_PER_KG := 0.05
## How far from the door you can stand and keep hauling (m).
const HAUL_REACH := 3.5
## Not held: how often it kicks off (s), how long it's down each time (s), how far it goes out from her and down (m),
## and how fast it goes and comes back (0..1 a second). Down past half of that, the harpoon can't reach it.
const SHEER_EVERY := 9.0
const SHEER_FOR := 4.0
const SHEER_OUT := Vector2(2.2, 1.4)
const SHEER_RATE := 1.2

var sea: Node                 # sea/sea.gd
## Fish alongside, by the rod they came up on: {kg, side (1 starboard, -1 port), hook_t (sea clock), t (s alongside),
## stuck, haul (0..1), node (the Tuna), misses, leave_t (sea clock it started going; -1: not), and how it swims}.
var fish := {}
## Who's got the harpoon (peer id; 0: in its rack).
var harpoon_holder := 0
## Your wind-up, 0..1 (ui/hotbar.gd shows it), while you hold left mouse with the harpoon.
var draw := 0.0
## The chance a miss loses it, by misses so far (ESCAPE; the tests set their own), and the host's dice.
var escape_odds: Array = ESCAPE.duplicate()
var rng := RandomNumberGenerator.new()
var _pulling := {}            # host: peer id -> the fish they're hauling
var _my_pull := -1
var _harpoon: Node3D
var _doors: Array[Action] = []      # [starboard, port]
var _rack: Action
## The boat's spots for all this (boat/kinds.gd).
var spec: Dictionary = {}
var _drawing := false
var _full_t := 0.0                  # s held wound all the way
## A throw in the air, in her frame (she may be under way): {p (where it's held), v, t, mine, end (-1 flying; else
## s since it came down)}; and the harpoon coming home after it (0 .. 1: back).
var _flight := {}
var _home := 1.0
var _home_from := Transform3D.IDENTITY
var _tip_gone := false
## Host: who let the harpoon go (their word on it is still to come).
var _thrown_by := 0
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _arc: MultiMeshInstance3D
var _send_in := 0.0
## Host: fish whose hook clock stands still (rod index -> the peer who asked): the first fish someone ever lands,
## while ui/fight_tutor.gd walks them through it one step at a time. It never runs the other way.
var _clock_held := {}


var _splash: Splash


func _ready() -> void:
	rng.randomize()
	_splash = Splash.new()
	_splash.name = "Splash"
	add_child(_splash)
	_harpoon = _make_harpoon()
	_harpoon.name = "Harpoon"
	add_child(_harpoon)
	_line = MeshInstance3D.new()
	_line.name = "HarpoonLine"
	_line_mesh = ImmediateMesh.new()
	_line.mesh = _line_mesh
	_line.material_override = _unshaded(Color(0.86, 0.83, 0.7))
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_arc = _make_arc()
	add_child(_arc)
	_attach()
	(sea.get("boat") as Node).connect("rebuilt", _attach)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_sync.rpc_id(id, harpoon_holder, _states()))
	Net.peer_left.connect(func(id: int) -> void:
		_pulling.erase(id)
		for i: int in _clock_held.keys():
			if int(_clock_held[i]) == id:
				_clock_held.erase(i)
		if Net.is_host() and harpoon_holder == id:
			_host_set_harpoon(0))
	Net.dropped.connect(func(_reason: String) -> void: _clear())
	Net.left.connect(func(was_host: bool) -> void:
		if not was_host:
			_clear()       # (those were the host's fish)
			return
		# our own boat: our fish stay; crewmates' hands come off the harpoon and the door
		if harpoon_holder != Net.my_id():
			harpoon_holder = 0
		for peer: int in _pulling.keys():
			if peer != Net.my_id():
				_pulling.erase(peer))


## The harpoon's rack and the haul spots, where her kind has them (again whenever she's rebuilt as another kind).
func _attach() -> void:
	var boat := sea.get("boat") as Node3D
	spec = boat.get("spec")
	_clear()
	for n: Node in [_rack] + _doors:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_doors.clear()
	_rack = Action.new(Vector3(0.45, 0.45, 2.5))
	_rack.name = "HarpoonRack"
	_rack.position = rack_at() + Vector3(0.0, 0.0, -0.6)
	_rack.use = func(_p: Node) -> void: _request_harpoon(true)
	_rack.prompt = func() -> String: return _rack_prompt()
	boat.add_child(_rack)
	var haul: Vector3 = spec["haul"]
	for side: float in [1.0, -1.0]:
		var door := Action.new(spec["haul_box"])
		door.name = ("TunaDoor" if bool(spec["door"]) else "Gunwale") + ("Starboard" if side > 0.0 else "Port")
		door.position = Vector3(haul.x * side, haul.y, haul.z)
		door.use = func(_p: Node) -> void: _start_pull(side)
		door.prompt = func() -> String: return _door_prompt(side)
		if bool(spec["door"]):
			door.add_child(_make_door())
		boat.add_child(door)
		_doors.append(door)


func rack_at() -> Vector3:
	return spec.get("rack", Vector3(-2.02, 1.2, 4.4))


# ------------------------------------------------------------------ what everyone sees

func _process(delta: float) -> void:
	var boat := sea.get("boat") as Node3D
	var ocean := sea.get("ocean") as Node
	var crew := sea.get("crew") as Node
	if harpoon_holder != Net.my_id():
		_drawing = false
	draw = move_toward(draw, 1.0, delta / DRAW) if _drawing else 0.0
	_full_t = _full_t + delta if _drawing and draw >= 1.0 else 0.0
	_place_harpoon(delta, boat, ocean, crew)
	var rods := sea.get("rods") as Node
	for i: int in fish:
		var f: Dictionary = fish[i]
		var node := f["node"] as Tuna
		# held, it lies there; not held, it kicks off and down now and then, the rod in its holder bending over
		var goal := sheer_goal(i)
		if goal > 0.5 and float(f["sheer"]) <= 0.0:
			_splash.burst(node.global_position + Vector3(0.0, 0.2, 0.0), 1.4, true)
			node.effort = 1.0
			f["surge"] = 1.0
			if i < (rods.get("rods") as Array).size():
				Sfx.play_point(self, (rods.get("rods")[i] as Node3D).global_position, "dock.reel", 1.0, 1.4)
		f["sheer"] = move_toward(float(f["sheer"]), goal, delta * SHEER_RATE)
		if goal > 0.5:
			node.effort = maxf(node.effort, 0.8)
		if i < (rods.get("rods") as Array).size():
			var rod: Node = rods.get("rods")[i]
			if bool(rod.get("alongside")):
				rod.set("strain", 0.35 + 0.6 * float(f["sheer"]))
		_swim(f, delta)
		node.global_transform = _fish_transform(f, boat, ocean)
		_ride_float(f, boat, ocean, delta)
		# not stuck yet, it's still got some kick: a tail thrashing the water now and then, a surge round its lap
		if not bool(f.get("stuck", false)) and float(f.get("haul", 0.0)) <= 0.0 and float(f["leave_t"]) < 0.0:
			var due := float(f.get("thrash_in", randf_range(1.0, 3.0))) - delta
			if due <= 0.0:
				due = randf_range(1.8, 4.0)
				_splash.burst(node.global_position + Vector3(0.0, 0.2, 0.0), 1.1, true)
				node.effort = 1.0
				f["surge"] = maxf(float(f["surge"]), 0.7)
			f["thrash_in"] = due
			node.effort = move_toward(node.effort, 0.15, delta * 0.8)
		elif float(f["leave_t"]) >= 0.0:
			node.effort = 1.0
			f["going"] = minf(float(f["going"]) + delta / LEAVE, 1.0)
	# hauling: let go of E, or walk away from the door, and you've stopped (the crosshair can drift as she rolls:
	# you're still holding the line)
	if _my_pull >= 0:
		var me := crew.get("me") as Node3D
		var f: Dictionary = fish.get(_my_pull, {})
		var door: Node3D = null
		if not f.is_empty():
			door = _doors[0 if float(f["side"]) > 0.0 else 1]
		if f.is_empty() or me == null or door == null or not Input.is_action_pressed("interact") 				or me.global_position.distance_to(door.global_position) > HAUL_REACH:
			_stop_pull()
	if Net.is_host():
		_host_tick(delta)


## The harpoon: flying from a throw, lying where it came down, coming home on its line, in someone's hands, or in its
## rack; and its line back to the rack whenever it's out of it, and your aim while you wind up.
func _place_harpoon(delta: float, boat: Node3D, ocean: Node, crew: Node) -> void:
	var p: Node3D = crew.call("get_player", harpoon_holder) if harpoon_holder != 0 else null
	var goal := boat.global_transform.affine_inverse() * (_in_hands(p) if p != null 			else boat.global_transform * Transform3D(Basis.IDENTITY, rack_at()))
	var local: Transform3D
	if not _flight.is_empty():
		local = _fly(delta, boat, ocean)
	elif _home < 1.0:
		# home on its line, hand over hand: up out of the water and in, its point coming round
		_home = minf(_home + delta / RETURN, 1.0)
		var k := smoothstep(0.0, 1.0, _home)
		var at := _home_from.origin.lerp(goal.origin, k) + Vector3.UP * sin(k * PI) * 1.1
		local = Transform3D(_home_from.basis.slerp(goal.basis, k).orthonormalized(), at)
		if _home >= 1.0:
			_tip_gone = false
			Sfx.play_point(self, boat.global_transform * goal.origin, "kit.chain", 0.7, 1.2)
	else:
		local = goal
	_harpoon.global_transform = boat.global_transform * local
	var mine := harpoon_holder == Net.my_id() and _flight.is_empty() and _home >= 1.0
	# (stuck, the dart stays in the fish: the pole comes home bare, and gets a new one in the rack)
	(_harpoon.get_node("Tip") as Node3D).visible = not _tip_gone
	_draw_line(boat, local)
	_draw_arc(ocean, mine and _drawing)


## The harpoon in someone's hands: at the shoulder, pointing where they look (a touch up). Yours draws back and up as
## you wind it, and shakes if you hold it there too long.
func _in_hands(p: Node3D) -> Transform3D:
	var cam := p.get("cam") as Node3D
	if cam == null:
		return p.global_transform
	var d := draw if p == (sea.get("crew") as Node).get("me") else 0.0
	var b := cam.global_basis * Basis(Vector3.RIGHT, 0.05 + 0.08 * d)
	var wobble := clampf((_full_t - SWAY_AFTER) / 1.5, 0.0, 1.0) * SWAY if d >= 1.0 else 0.0
	if wobble > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		b = b * Basis.from_euler(Vector3(sin(t * 7.0) + 0.5 * sin(t * 17.0), cos(t * 5.0) + 0.5 * sin(t * 13.0), 0.0) 				* wobble)
	var ease := smoothstep(0.0, 1.0, d)
	return Transform3D(b, cam.global_transform * Vector3(0.22 + 0.04 * ease, -0.3 + 0.08 * ease, 0.1 + 0.25 * ease))


## A throw in the air: falling as it flies, its point along its way. On the thrower's machine it's judged as it goes:
## its point through a fish's back sticks it (the host's told), into the water first it's a miss. Then it lies a
## moment where it came down and comes home.
func _fly(delta: float, boat: Node3D, ocean: Node) -> Transform3D:
	var f := _flight
	var bt := boat.global_transform
	if float(f["end"]) >= 0.0:
		f["end"] = float(f["end"]) + delta
		var lie := Transform3D(_look(f["v"]), f["p"])
		if float(f["end"]) > 0.45:
			_home_from = lie
			_tip_gone = bool(f.get("hit", false))
			_home = 0.0
			_flight = {}
		return lie
	var was: Vector3 = f["p"]
	var was_tip: Vector3 = was + (f["v"] as Vector3).normalized() * (TIP if float(f["t"]) > 0.0 else 0.0)
	f["v"] = (f["v"] as Vector3) + boat.global_basis.inverse() * Vector3(0.0, -GRAVITY, 0.0) * delta
	f["p"] = was + (f["v"] as Vector3) * delta
	f["t"] = float(f["t"]) + delta
	var v: Vector3 = f["v"]
	var tip: Vector3 = (f["p"] as Vector3) + v.normalized() * TIP
	var a := bt * was_tip
	var b := bt * tip
	var hit := _hit_along(a, b)
	if not hit.is_empty():
		var node := fish[int(hit["i"])]["node"] as Node3D
		# it stops in the fish: the dart in its back, the pole falling away
		f["p"] = bt.affine_inverse() * (hit["at"] as Vector3) - v.normalized() * TIP
		f["end"] = 0.0
		f["hit"] = true
		_splash.burst(hit["at"], 1.6, true)
		Sfx.play_point(self, hit["at"], "collar.thump", 1.0, 0.75)
		if bool(f["mine"]):
			var inv := node.global_transform.affine_inverse()
			_report(int(hit["i"]), inv * (hit["at"] as Vector3), inv.basis * (bt.basis * v).normalized())
	else:
		# into the water: a splash where it goes in, and it slows; it can still find a fish just under the top, but
		# past SINK it's a miss
		var under := float(ocean.call("height_at", b)) - b.y
		if under > 0.0 and not bool(f.get("wet", false)):
			f["wet"] = true
			_splash.burst(b, 0.9)
			Sfx.play_point(self, b, "sea.spray", 0.9, 1.3)
		if under > 0.0:
			f["v"] = v * exp(-4.0 * delta)
		if under > SINK or float(f["t"]) > 2.0:
			f["end"] = 0.0
			if bool(f["mine"]):
				_report(-1, Vector3.ZERO, Vector3.FORWARD)
	return Transform3D(_look(v), f["p"])


## The fish a point moving from `a` to `b` (world) goes into, and where: {i, at}; empty: none. Only a fish up
## within reach (not down, not stuck, not going).
func _hit_along(a: Vector3, b: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for i: int in fish:
		var f: Dictionary = fish[i]
		if bool(f["stuck"]) or down(i) or float(f["leave_t"]) >= 0.0:
			continue
		var node := f["node"] as Tuna
		var snout := node.global_transform * Vector3(0.0, 0.0, -0.42 * node.length)
		var root := node.global_transform * Vector3(0.0, 0.0, 0.32 * node.length)
		var near := Geometry3D.get_closest_points_between_segments(a, b, snout, root)
		var d := near[0].distance_to(near[1])
		if d < node.length * HIT and a.distance_to(near[0]) < best_d:
			best = {"i": i, "at": near[1] + (near[0] - near[1]) * 0.5}
			best_d = a.distance_to(near[0])
	return best


## The fish alongside a throw from `from` along `dir` (all you've got) would stick (-1: none), flown out as it would
## go against where the fish are now.
func aimed_at(from: Vector3, dir: Vector3, power := 1.0) -> int:
	var v := dir.normalized() * lerpf(THROW_SPEED.x, THROW_SPEED.y, power)
	var p := from
	var dt := 1.0 / 60.0
	var t := 0.0
	var ocean := sea.get("ocean") as Node
	while t < 2.0 and p.distance_to(from) < REACH:
		var q := p + v * dt
		v.y -= GRAVITY * dt
		var under := float(ocean.call("height_at", q)) - q.y
		if under > 0.0:
			v *= exp(-4.0 * dt)
		if under > SINK:
			return -1
		var hit := _hit_along(p, q)
		if not hit.is_empty():
			return int(hit["i"])
		p = q
		t += dt
	return -1


## The line from the rack to the harpoon's butt while it's out of the rack (sagging a little, a straight pull on a
## throw).
func _draw_line(boat: Node3D, local: Transform3D) -> void:
	_line_mesh.clear_surfaces()
	var out := not _flight.is_empty() or _home < 1.0
	if not out:
		return
	var a := boat.global_transform * (rack_at() + Vector3(0.0, 0.05, 0.25))
	var b := boat.global_transform * (local * Vector3(0.0, 0.0, 0.55))
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := 0.08 * a.distance_to(b) * (0.4 if float(_flight.get("end", 0.0)) < 0.0 else 1.0)
	for k in 13:
		var f := k / 12.0
		_line_mesh.surface_add_vertex(a.lerp(b, f) + Vector3.DOWN * sag * 4.0 * f * (1.0 - f))
	_line_mesh.surface_end()


## Your aim while you wind up: dots along where the point would go if you let go now, and a ring where it comes
## down on the water.
func _draw_arc(ocean: Node, show: bool) -> void:
	_arc.visible = show
	if not show:
		return
	var mm := _arc.multimesh
	var dir := -_harpoon.global_basis.z
	var v := dir * lerpf(THROW_SPEED.x, THROW_SPEED.y, maxf(draw, 0.15))
	var p := _harpoon.global_position + dir * TIP
	var dt := 0.035
	var n := 0
	var down_at := Vector3.INF
	var dots := mm.instance_count - 10
	while n < dots:
		var q := p + v * dt
		v.y -= GRAVITY * dt
		if q.y < float(ocean.call("height_at", q)):
			down_at = q
			break
		p = q
		mm.set_instance_transform(n, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (1.0 - 0.4 * n / dots)), p))
		n += 1
	for k in range(n, dots):
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), p))
	for k in 10:
		var ring := Vector3.INF if down_at == Vector3.INF else down_at + Vector3(cos(k * TAU / 10.0), 0.0, 			sin(k * TAU / 10.0)) * 0.5
		if ring == Vector3.INF:
			mm.set_instance_transform(dots + k, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), p))
		else:
			ring.y = float(ocean.call("height_at", ring)) + 0.03
			mm.set_instance_transform(dots + k, Transform3D(Basis.IDENTITY, ring))


# ------------------------------------------------------------------ how a fish alongside swims

## The dart's float, stuck: bobbing on the water a little out from the fish on her outside, dragged along after it on
## its short line; hauled, it comes aboard with it.
func _ride_float(f: Dictionary, boat: Node3D, ocean: Node, delta: float) -> void:
	var ball := f.get("float") as Node3D
	if ball == null or not is_instance_valid(ball):
		return
	var side := float(f["side"])
	var out := (Vector3(0.35 * side, 0.0, 1.0) if bool(spec.get("fish_across", true)) 			else Vector3(side, 0.0, 0.3)).normalized()
	var fish_at := (f["node"] as Node3D).global_position
	var want := fish_at + boat.global_basis * out * 1.1
	want.y = float(ocean.call("height_at", want)) + 0.05
	var k := smoothstep(0.0, 1.0, float(f["haul"]))
	want = want.lerp(fish_at + boat.global_basis.y * 0.25, k)
	ball.global_position = ball.global_position.lerp(want, minf(1.0, delta * 4.0))

## Its lap round its oval (faster in a surge, slower and smaller stuck), its spook after a miss, and arriving from where
## the fight left it.
func _swim(f: Dictionary, delta: float) -> void:
	var stuck := bool(f["stuck"])
	f["surge"] = move_toward(float(f["surge"]), 0.0, delta * 0.6)
	var rate := TAU / LAP * (0.35 if stuck else 1.0 + 1.6 * float(f["surge"]))
	f["lap"] = float(f["lap"]) + rate * delta * float(f["spin"])
	f["size"] = move_toward(float(f["size"]), 0.0 if float(f["haul"]) > 0.0 else (0.45 if stuck else 1.0), delta * 0.5)
	f["spook"] = maxf(float(f["spook"]) - delta / SPOOK, 0.0)
	f["arrive"] = minf(float(f["arrive"]) + delta / maxf(ARRIVE, float(f.get("arrive_s", 0.0))), 1.0)


## Where a fish alongside is, in the water on its side of her (across the sportfisher's stern, along the skiff's side),
## swimming its lap; hauled, it comes up aboard and rolls onto its side; going, it swims off out and down.
func _fish_transform(f: Dictionary, boat: Node3D, ocean: Node) -> Transform3D:
	var side := float(f["side"])
	var k := smoothstep(0.0, 1.0, float(f["haul"]))
	var w: Vector3 = spec.get("fish_water", Vector3(1.1, 0.0, 7.95))
	var across := bool(spec.get("fish_across", true))
	# (out from her, astern of a transom or abeam of a side; and along the way its head lies)
	var out := (Vector3(0.35 * side, 0.0, 1.0) if across else Vector3(side, 0.0, 0.3)).normalized()
	var along := Vector3(-side, 0.0, 0.0) if across else Vector3(0.0, 0.0, -1.0)
	# its lap: an oval, nudged out from her so it never swims into her
	var lap := float(f["lap"])
	var size := float(f["size"])
	var oval := (along * LAP_R.x * cos(lap) + out * LAP_R.y * (sin(lap) + 0.6)) * size
	var way := (-along * LAP_R.x * sin(lap) + out * LAP_R.y * cos(lap)) * float(f["spin"])
	way = way.lerp(along, 1.0 - size)
	# (sheering off and spooked: out from her and down)
	var s := smoothstep(0.0, 1.0, float(f.get("sheer", 0.0)))
	var spook := sin(float(f["spook"]) * PI)
	var flat := Vector3(w.x * side, 0.0, w.z) + oval + out * (SHEER_OUT.x * s + 1.2 * spook)
	var water := boat.global_transform * flat
	var rise := 0.5 + 0.5 * sin(lap + 1.2)
	water.y = float(ocean.call("height_at", water)) - 0.12 - 0.22 * (1.0 - rise) * size - SHEER_OUT.y * s 			- 0.5 * spook
	var head := (boat.global_basis * way).normalized()
	if spook > 0.0:
		head = head.lerp(boat.global_basis * out, spook * 0.8).normalized()
	# going: off out and down, picking up speed, its head coming round away from her
	var go := float(f["leave_t"])
	if go >= 0.0:
		var g := float(f["going"])
		var away := (boat.global_basis * out).normalized()
		water += away * 7.0 * g * g + Vector3.DOWN * 3.0 * g
		head = head.lerp(away + Vector3.DOWN * 0.35, smoothstep(0.0, 0.35, g)).normalized()
	# up from the fight: from where it was, round into its lap
	var arrive := smoothstep(0.0, 1.0, float(f["arrive"]))
	if arrive < 1.0 and f.has("from"):
		var was: Transform3D = boat.global_transform * (f["from"] as Transform3D)
		water = was.origin.lerp(water, arrive)
		head = (-was.basis.z).lerp(head, arrive).normalized()
	var a: Vector3 = spec.get("fish_aboard", Vector3(1.0, 0.8, 6.22))
	var aboard := boat.global_transform * Vector3(a.x * side, a.y, a.z)
	# hauled: its head across her (toward her middle) or forward along her, rolling onto its side
	var lie := -boat.global_basis.x * side if across else -boat.global_basis.z
	head = head.lerp(lie, k).normalized()
	var up := boat.global_basis.y
	if absf(head.dot(up)) > 0.98:
		up = boat.global_basis.z
	var b := Basis.looking_at(head, up) * Basis(Vector3(0, 0, 1), k * PI * 0.5)
	# (over a gunwale, not through the door: lifted up over it on the way)
	var over := float(spec.get("haul_lift", 0.0)) * sin(k * PI)
	return Transform3D(b, water.lerp(aboard, k) + boat.global_basis.y * over)


## Where the line from rod i goes into the fish alongside (rods.gd draws it).
func fish_point(i: int) -> Vector3:
	var f: Dictionary = fish.get(i, {})
	return (f["node"] as Node3D).global_position if not f.is_empty() else Vector3.ZERO


## What to do now, for the HUD (rods.gd shows it when you're not fighting a fish).
func hint() -> String:
	var waiting := false
	var stuck := false
	for i: int in fish:
		if float(fish[i]["leave_t"]) >= 0.0:
			continue
		if bool(fish[i]["stuck"]):
			stuck = true
		else:
			waiting = true
	var unwired := false
	var wired := false
	for i: int in fish:
		if not bool(fish[i]["stuck"]) and bool(spec.get("wire", false)):
			unwired = unwired or needs_wire(i)
			wired = wired or not needs_wire(i)
	if harpoon_holder == Net.my_id():
		if waiting and unwired and not wired:
			return "Wire it first   Q put back"
		return "Hold click, let go: throw. A miss can lose it" if waiting else "Q put back"
	if waiting and (sea.get("rods") as Node).call("held_by", Net.my_id()) != null:
		# (with a mate aboard, keep it: you're holding it up for their harpoon)
		return "Hold it there" if _crew_aboard() > 1 else "Q: rod back, then the harpoon"
	if waiting and wired:
		return "Wired: harpoon it"
	if waiting and unwired:
		return "Wire it, then harpoon it"
	if waiting:
		return "Harpoon it"
	if stuck:
		return "Stuck: haul it in"
	return ""


func _rack_prompt() -> String:
	if harpoon_holder != 0:
		return ""
	if (sea.get("rods") as Node).call("held_by", Net.my_id()) != null:
		return "Q: rod back first"
	var helm: Node = (sea.get("boat") as Node).get("helm")
	if int(helm.get("captain")) == Net.my_id():
		return ""
	return "Grab the harpoon"


func _door_prompt(side: float) -> String:
	var i := _stuck_on(side)
	if i >= 0:
		return "Hold to haul  %d%%" % roundi(float(fish[i]["haul"]) * 100.0)
	var j := _waiting_on(side)
	if j >= 0:
		if needs_wire(j):
			return "Wire it"
		if bool(spec.get("wire", false)):
			return "Wired  %d s" % ceili(wire_left(j))
		return "Harpoon it first"
	return ""


## The fish alongside on that side not stuck yet (-1: none).
func _waiting_on(side: float) -> int:
	for j: int in fish:
		if not bool(fish[j]["stuck"]) and float(fish[j]["side"]) == side and float(fish[j]["leave_t"]) < 0.0:
			return j
	return -1


## Whether fish i still has to be wired before it can be stuck (her kind says so, and nobody's holding the leader).
func needs_wire(i: int) -> bool:
	return bool(spec.get("wire", false)) and fish.has(i) and wire_left(i) <= 0.0


func wire_left(i: int) -> float:
	return float(fish[i].get("wired_until", -1.0)) - _now() if fish.has(i) else 0.0


## Whether fish i's held up alongside: someone on its rod, or on its leader (wired).
func held(i: int) -> bool:
	var rods: Array = (sea.get("rods") as Node).get("rods")
	return (i < rods.size() and int(rods[i].get("holder")) != 0) or wire_left(i) > 0.0


## Where fish i wants to be: 0 lying alongside, 1 sheered off and down (not held, in a kick).
func sheer_goal(i: int) -> float:
	var f: Dictionary = fish.get(i, {})
	if f.is_empty() or bool(f["stuck"]) or held(i):
		return 0.0
	var phase := fposmod(_now() - float(f["up_t"]), SHEER_EVERY)
	return 1.0 if phase >= SHEER_EVERY - SHEER_FOR else 0.0


## Whether fish i's down out of reach (of the harpoon, of a hand on the leader).
func down(i: int) -> bool:
	return fish.has(i) and float(fish[i].get("sheer", 0.0)) > 0.5


## The chance the next miss loses fish i (0 for the first fish you're being shown how to land).
func escape_chance(i: int) -> float:
	if not fish.has(i) or _clock_held.has(i) or escape_odds.is_empty():
		return 0.0
	var n := int(fish[i]["misses"])
	return float(escape_odds[mini(n, escape_odds.size() - 1)])


## How many of the crew are aboard this boat (with you).
func _crew_aboard() -> int:
	var crew: Node = sea.get("crew")
	var slots: Variant = crew.get("slots") if crew != null else null
	if not slots is Dictionary:
		return 1
	var n := 0
	for id: int in slots:
		if crew.call("boat_of", id) == sea.get("boat"):
			n += 1
	return maxi(n, 1)


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _stuck_on(side: float) -> int:
	for i: int in fish:
		if bool(fish[i]["stuck"]) and float(fish[i]["side"]) == side:
			return i
	return -1


# ------------------------------------------------------------------ the harpoon

func _unhandled_input(event: InputEvent) -> void:
	if harpoon_holder != Net.my_id() or not _flight.is_empty():
		return
	var me := (sea.get("crew") as Node).get("me") as Node
	if not (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (me != null and bool(me.get("force_input")))):
		return
	if event.is_action_pressed("use_primary"):
		_drawing = true
		Sfx.play_point(self, _harpoon.global_position, "kit.switch", 0.5, 0.7)
	elif event.is_action_released("use_primary") and _drawing:
		throw(draw)
	elif event.is_action_pressed("drop"):
		_drawing = false
		_request_harpoon(false)


## Lets the harpoon you're holding go, `power` (0..1) of all you've got, the way it's pointing: it flies here and
## everyone's told (they fly it too). This machine says where it went.
func throw(power := 1.0) -> void:
	var me := (sea.get("crew") as Node).get("me") as Node3D
	_drawing = false
	if me == null or harpoon_holder != Net.my_id() or not _flight.is_empty():
		return
	var boat := sea.get("boat") as Node3D
	var dir := -_harpoon.global_basis.z
	var inv := boat.global_transform.affine_inverse()
	var p := inv * _harpoon.global_position
	var v := inv.basis * (dir * lerpf(THROW_SPEED.x, THROW_SPEED.y, clampf(power, 0.15, 1.0)))
	me.call("gesture", "throw")
	_start_flight(p, v, true)
	if Net.is_host():
		_ask_release_as(Net.my_id(), p, v)
	else:
		_ask_release.rpc_id(1, p, v)


func _start_flight(p: Vector3, v: Vector3, mine: bool) -> void:
	_flight = {"p": p, "v": v, "t": 0.0, "mine": mine, "end": -1.0}
	_home = 1.0
	Sfx.play_point(self, _harpoon.global_position, "brine.gust", 0.8, 1.7)


@rpc("any_peer", "call_remote", "reliable")
func _ask_release(p: Vector3, v: Vector3) -> void:
	_ask_release_as(multiplayer.get_remote_sender_id(), p, v)


## Host: `who` let the harpoon go: out of their hands, and everyone else sees it fly.
func _ask_release_as(who: int, p: Vector3, v: Vector3) -> void:
	if who != harpoon_holder:
		return
	_thrown_by = who
	_host_set_harpoon(0)
	if Net.in_session():
		_flown.rpc(who, p, v)


@rpc("authority", "call_remote", "reliable")
func _flown(who: int, p: Vector3, v: Vector3) -> void:
	if who != Net.my_id():
		_start_flight(p, v, false)


## The thrower's word on where it went: into fish i (at, dir: where and which way, in the fish's frame), or -1 a miss.
func _report(i: int, at: Vector3, dir: Vector3) -> void:
	if Net.is_host():
		_ask_throw_as(Net.my_id(), i, at, dir)
	else:
		_ask_throw.rpc_id(1, i, at, dir)


func _request_harpoon(take: bool) -> void:
	if Net.is_host():
		_ask_harpoon_as(Net.my_id(), take)
	else:
		_ask_harpoon.rpc_id(1, take)


@rpc("any_peer", "call_remote", "reliable")
func _ask_harpoon(take: bool) -> void:
	_ask_harpoon_as(multiplayer.get_remote_sender_id(), take)


func _ask_harpoon_as(who: int, take: bool) -> void:
	if not take:
		if harpoon_holder == who:
			_host_set_harpoon(0)
		return
	if harpoon_holder != 0:
		return
	if (sea.get("rods") as Node).call("held_by", who) != null:
		return        # (your hands are full)
	var helm: Node = (sea.get("boat") as Node).get("helm")
	if int(helm.get("captain")) == who:
		return        # (and the captain's are on the wheel)
	_host_set_harpoon(who)


func _host_set_harpoon(who: int) -> void:
	if Net.in_session():
		_set_harpoon.rpc(who)
	else:
		_set_harpoon(who)


@rpc("authority", "call_local", "reliable")
func _set_harpoon(who: int) -> void:
	harpoon_holder = who


@rpc("any_peer", "call_remote", "reliable")
func _ask_throw(i: int, at: Vector3, dir: Vector3) -> void:
	_ask_throw_as(multiplayer.get_remote_sender_id(), i, at, dir)


## Host: how `who`'s throw went (i: the fish it went into, -1 a miss). A hit on a fish that wants wiring bounces off
## (no harm done); a miss spooks whatever's alongside, and maybe loses it.
func _ask_throw_as(who: int, i: int, at := Vector3.ZERO, dir := Vector3.FORWARD) -> void:
	if who != harpoon_holder and who != _thrown_by:
		return
	_thrown_by = 0
	if harpoon_holder == who:
		_host_set_harpoon(0)
	var ok := fish.has(i) and not bool(fish[i]["stuck"]) and float(fish[i]["leave_t"]) < 0.0
	if ok and needs_wire(i):
		if Net.in_session():
			_missed.rpc(who, "Bounced off: too lively. Wire it first")
		else:
			_missed(who, "Bounced off: too lively. Wire it first")
	elif ok:
		if at == Vector3.ZERO:
			at = Vector3(0.0, (fish[i]["node"] as Tuna).length * 0.1, -0.05)
		# (off the rod first, its line lying back to be wound in; then stuck, which says what's next)
		(sea.get("rods") as Node).call("host_off", i, "Stuck!")
		if Net.in_session():
			_stuck.rpc(i, at, dir)
		else:
			_stuck(i, at, dir)
	else:
		_host_miss(who)


## Host: a miss. Every fish alongside not stuck is spooked by it, and each rolls against its odds (escape_chance):
## torn free, it goes.
func _host_miss(who: int) -> void:
	var any := false
	for i: int in fish.keys():
		var f: Dictionary = fish[i]
		if bool(f["stuck"]) or float(f["leave_t"]) >= 0.0:
			continue
		any = true
		var chance := escape_chance(i)
		var gone := rng.randf() < chance
		var n := int(f["misses"]) + 1
		if Net.in_session():
			_miss_on.rpc(i, n, gone, chance, _clock_held.has(i))
		else:
			_miss_on(i, n, gone, chance, _clock_held.has(i))
		if gone:
			_host_leave(i)
	if not any:
		if Net.in_session():
			_missed.rpc(who, "Missed")
		else:
			_missed(who, "Missed")


## Everyone: fish i was missed (its n-th): spooked, a bolt and a thrash; torn free or not, and the odds, said on
## screen for everyone aboard.
@rpc("authority", "call_local", "reliable")
func _miss_on(i: int, n: int, gone: bool, chance: float, lesson: bool) -> void:
	if not fish.has(i):
		return
	var f: Dictionary = fish[i]
	f["misses"] = n
	f["spook"] = 1.0
	f["surge"] = 1.0
	var node := f["node"] as Tuna
	node.effort = 1.0
	_splash.burst(node.global_position + Vector3(0.0, 0.2, 0.0), 1.5, true)
	Sfx.play_point(self, node.global_position, "dock.slap", 1.0, 0.9)
	if gone:
		_note("Missed! It tore the hook out and it's gone (%d%% chance)" % roundi(chance * 100.0))
	elif lesson:
		_note("Missed! This one stays. From now on a miss can lose it")
	elif escape_chance(i) <= 0.0:
		_note("Missed! It stayed on")
	else:
		_note("Missed! It stayed on. Next miss: %d%% it tears free" % roundi(escape_chance(i) * 100.0))


@rpc("authority", "call_local", "reliable")
func _stuck(i: int, at := Vector3.ZERO, dir := Vector3.FORWARD) -> void:
	if not fish.has(i):
		return
	var f: Dictionary = fish[i]
	f["stuck"] = true
	f["surge"] = 1.0
	var node := f["node"] as Tuna
	node.effort = 1.0
	if at == Vector3.ZERO:
		at = Vector3(0.0, node.length * 0.1, -0.05)
	_note("Stuck! Hold E at the %s to haul it aboard" % ("tuna door" if bool(spec.get("door", false)) else "gunwale"))
	# the dart in its back, its shaft standing out the way it came in, and the float on its line
	var dart := Node3D.new()
	dart.name = "Dart"
	var d := dir.normalized() if dir.length_squared() > 1e-4 else Vector3.FORWARD
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	dart.transform = Transform3D(Basis.looking_at(d, up), at)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.014
	cyl.bottom_radius = 0.014
	cyl.height = 0.42
	cyl.radial_segments = 5
	cyl.rings = 1
	shaft.mesh = cyl
	shaft.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	shaft.position = Vector3(0.0, 0.0, 0.17)        # (most of it standing out behind the point)
	shaft.material_override = _flat(Color(0.62, 0.64, 0.66))
	dart.add_child(shaft)
	node.add_child(dart)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 8
	sphere.rings = 4
	ball.mesh = sphere
	ball.name = "Float%d" % i
	ball.material_override = _flat(Color(1.0, 0.45, 0.1))
	add_child(ball)
	f["float"] = ball
	ball.global_position = node.global_position


@rpc("authority", "call_local", "reliable")
func _missed(who: int, why: String) -> void:
	if who == Net.my_id():
		_note(why)


# ------------------------------------------------------------------ the haul

func _start_pull(side: float) -> void:
	var i := _stuck_on(side)
	if i < 0:
		# not stuck yet: on a boat that wants it, E here wires it (grabs the leader)
		var j := _waiting_on(side)
		if j >= 0 and needs_wire(j) and not down(j):
			if Net.is_host():
				_ask_wire_as(j)
			else:
				_ask_wire.rpc_id(1, j)
		return
	_my_pull = i
	if Net.is_host():
		_ask_pull_as(Net.my_id(), i)
	else:
		_ask_pull.rpc_id(1, i)


func _stop_pull() -> void:
	_my_pull = -1
	if Net.is_host():
		_ask_pull_as(Net.my_id(), -1)
	else:
		_ask_pull.rpc_id(1, -1)


@rpc("any_peer", "call_remote", "reliable")
func _ask_wire(i: int) -> void:
	_ask_wire_as(i)


func _ask_wire_as(i: int) -> void:
	if not fish.has(i) or bool(fish[i]["stuck"]):
		return
	var until := _now() + WIRE_HOLD
	if Net.in_session():
		_wired.rpc(i, until)
	else:
		_wired(i, until)


@rpc("authority", "call_local", "reliable")
func _wired(i: int, until: float) -> void:
	if fish.has(i):
		fish[i]["wired_until"] = until
		Sfx.play_point(self, (fish[i]["node"] as Node3D).global_position, "kit.chain")


@rpc("any_peer", "call_remote", "reliable")
func _ask_pull(i: int) -> void:
	_ask_pull_as(multiplayer.get_remote_sender_id(), i)


func _ask_pull_as(who: int, i: int) -> void:
	if i < 0 or not fish.has(i) or not bool(fish[i]["stuck"]):
		_pulling.erase(who)
	else:
		_pulling[who] = i


## How many are hauling on fish i right now (host).
func hands_on(i: int) -> int:
	var n := 0
	for peer: int in _pulling:
		if int(_pulling[peer]) == i:
			n += 1
	return n


func _host_tick(delta: float) -> void:
	_send_in -= delta
	var send := _send_in <= 0.0 and Net.in_session()
	if send:
		_send_in = 0.1
	for i: int in fish.keys():
		var f: Dictionary = fish[i]
		if float(f["leave_t"]) >= 0.0:
			if float(f["going"]) >= 1.0:
				_host_gone(i, "")
			continue
		if not _clock_held.has(i):
			f["t"] = float(f["t"]) + delta
		if not bool(f["stuck"]):
			if float(f["t"]) > HOOK_HOLDS:
				_host_leave(i, "The hook pulled")
			continue
		var hands := hands_on(i)
		if hands == 0:
			continue
		f["haul"] = minf(float(f["haul"]) + delta * hands / (HAUL_BASE + float(f["kg"]) * HAUL_PER_KG), 1.0)
		if float(f["haul"]) >= 1.0:
			_host_aboard(i)
		elif send:
			_haul_state.rpc(i, float(f["haul"]))


@rpc("authority", "call_remote", "unreliable_ordered")
func _haul_state(i: int, haul: float) -> void:
	if fish.has(i):
		fish[i]["haul"] = haul


## The hook clock on fish i held still (`on`) or let run again: asked of the host by whoever's being shown how to land
## their first fish (ui/fight_tutor.gd).
func hold_clock(i: int, on: bool) -> void:
	if Net.is_host():
		_ask_hold_as(Net.my_id(), i, on)
	else:
		_ask_hold.rpc_id(1, i, on)


@rpc("any_peer", "call_remote", "reliable")
func _ask_hold(i: int, on: bool) -> void:
	_ask_hold_as(multiplayer.get_remote_sender_id(), i, on)


func _ask_hold_as(who: int, i: int, on: bool) -> void:
	if on and fish.has(i):
		_clock_held[i] = who
	elif not on and int(_clock_held.get(i, -1)) == who:
		_clock_held.erase(i)


# ------------------------------------------------------------------ comes alongside, comes aboard, gets away

## Host: rod i's fish is beaten and up alongside (rods.gd, when its fight comes boatside).
func host_alongside(i: int, kg: float, bearing: float, hook_t: float) -> void:
	var side := 1.0 if sin(bearing) >= 0.0 else -1.0
	if Net.in_session():
		_alongside.rpc(i, kg, side, hook_t)
	else:
		_alongside(i, kg, side, hook_t)


@rpc("authority", "call_local", "reliable")
func _alongside(i: int, kg: float, side: float, hook_t: float) -> void:
	_add(i, kg, side, hook_t)


## A fish up alongside, off rod i. `on_rod`: still on the line (not yet stuck), so the rod shows it. It swims in from
## where the fight's fish was, if there's one to see.
func _add(i: int, kg: float, side: float, hook_t: float, on_rod := true) -> void:
	_drop(i)
	var node := Tuna.new(kg)
	node.name = "Alongside%d" % i
	node.posed = true
	node.swimming = true
	node.effort = 0.35
	add_child(node)
	fish[i] = {"kg": kg, "side": side, "hook_t": hook_t, "t": 0.0, "stuck": false, "haul": 0.0, "node": node,
			"wired_until": -1.0, "up_t": _now(), "sheer": 0.0, "misses": 0, "leave_t": -1.0, "going": 0.0,
			"lap": float(i) * 2.1, "spin": 1.0 if i % 2 == 0 else -1.0, "size": 1.0, "surge": 0.0, "spook": 0.0,
			"arrive": 1.0}
	var rods: Array = (sea.get("rods") as Node).get("rods")
	var boat := sea.get("boat") as Node3D
	if on_rod and i < rods.size():
		var was: Variant = rods[i].get("fish_node")
		var w: Vector3 = spec.get("fish_water", Vector3(1.1, 0.0, 7.95))
		var spot := boat.global_transform * Vector3(w.x * side, 0.0, w.z)
		# (from where you could see it: a fish fought to the boat is a few metres off)
		if was is Node3D and is_instance_valid(was) and (was as Node3D).global_position.distance_to(spot) < ARRIVE_FROM:
			fish[i]["from"] = boat.global_transform.affine_inverse() * (was as Node3D).global_transform
			fish[i]["arrive"] = 0.0
			# (no faster than a tired fish swims: ARRIVE_SPEED)
			fish[i]["arrive_s"] = (was as Node3D).global_position.distance_to(spot) / ARRIVE_SPEED
	node.global_transform = _fish_transform(fish[i], boat, sea.get("ocean") as Node)
	if on_rod:
		(sea.get("rods") as Node).call("set_alongside", i)


func _host_aboard(i: int) -> void:
	var f: Dictionary = fish[i]
	var now := float((sea.get("ocean") as Node).get("wave_time"))
	(sea.get("fish_hold") as Node).call("host_add", float(f["kg"]), now - float(f["hook_t"]))
	for peer: int in _pulling.keys():
		if int(_pulling[peer]) == i:
			_pulling.erase(peer)
	if Net.in_session():
		_aboard.rpc(i)
	else:
		_aboard(i)


@rpc("authority", "call_local", "reliable")
func _aboard(i: int) -> void:
	if _my_pull == i:
		_my_pull = -1
	if fish.has(i):
		Sfx.play_point(self, (fish[i]["node"] as Node3D).global_position, "dock.slap", 1.0, 0.7)
	_drop(i)


## Host, heading in: whatever's alongside is cut loose.
func host_clear() -> void:
	for i: int in fish.keys():
		_host_gone(i, "")


## Host: fish i's off (the hook pulled, torn free): it swims away, and in LEAVE s it's gone.
func _host_leave(i: int, why := "") -> void:
	if Net.in_session():
		_leave.rpc(i, _now(), why)
	else:
		_leave(i, _now(), why)


@rpc("authority", "call_local", "reliable")
func _leave(i: int, t: float, why: String) -> void:
	if not fish.has(i):
		return
	fish[i]["leave_t"] = t
	var node := fish[i]["node"] as Node3D
	_splash.burst(node.global_position + Vector3(0.0, 0.2, 0.0), 1.8, true)
	Sfx.play_point(self, node.global_position, "dock.slap", 1.0, 0.8)
	_note(why)


func _host_gone(i: int, why: String) -> void:
	(sea.get("rods") as Node).call("host_off", i, why)
	if Net.in_session():
		_gone.rpc(i)
	else:
		_gone(i)


@rpc("authority", "call_local", "reliable")
func _gone(i: int) -> void:
	_drop(i)


func _drop(i: int) -> void:
	_clock_held.erase(i)
	if fish.has(i):
		for k: String in ["node", "float"]:
			var n: Variant = fish[i].get(k)
			if n is Node and is_instance_valid(n):
				(n as Node).queue_free()
		fish.erase(i)
	if _my_pull == i:
		_my_pull = -1


func _clear() -> void:
	for i: int in fish.keys():
		_drop(i)
	_clock_held.clear()
	harpoon_holder = 0
	_thrown_by = 0
	_pulling.clear()
	_my_pull = -1
	_drawing = false


func _states() -> Array:
	var out := []
	for i: int in fish:
		var f: Dictionary = fish[i]
		out.append([i, f["kg"], f["side"], f["hook_t"], f["t"], f["stuck"], f["haul"], f.get("wired_until", -1.0),
				f.get("up_t", 0.0), f.get("misses", 0)])
	return out


## A late joiner: the harpoon, and every fish alongside.
@rpc("authority", "call_remote", "reliable")
func _sync(holder: int, states: Array) -> void:
	_clear()
	harpoon_holder = holder
	for s: Array in states:
		var i := int(s[0])
		_add(i, float(s[1]), float(s[2]), float(s[3]), not bool(s[5]))
		fish[i]["t"] = float(s[4])
		fish[i]["haul"] = float(s[6])
		fish[i]["wired_until"] = float(s[7]) if s.size() > 7 else -1.0
		if s.size() > 8:
			fish[i]["up_t"] = float(s[8])      # (kicking off when the host's does)
		if s.size() > 9:
			fish[i]["misses"] = int(s[9])
		if bool(s[5]):
			_stuck(i)


# ------------------------------------------------------------------ odds and ends

func _note(text: String) -> void:
	if text.is_empty():
		return
	var crew := sea.get("crew") as Node
	(crew.get("hud") as Node).call("notify", text)


## The harpoon: a long wooden pole with a steel dart, pointing along -Z, held a little behind its middle.
func _make_harpoon() -> Node3D:
	var root := Node3D.new()
	var pole := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.022
	shaft.bottom_radius = 0.026
	shaft.height = 2.4
	shaft.radial_segments = 6
	pole.mesh = shaft
	pole.rotation = Vector3(-PI * 0.5, 0.0, 0.0)      # (the cylinder's +Y to -Z)
	pole.position = Vector3(0.0, 0.0, -0.6)
	pole.material_override = _flat(Color(0.44, 0.36, 0.27))
	root.add_child(pole)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.04
	cone.height = 0.24
	cone.radial_segments = 6
	tip.mesh = cone
	tip.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	tip.position = Vector3(0.0, 0.0, -1.92)
	tip.name = "Tip"
	tip.material_override = _flat(Color(0.62, 0.64, 0.66))
	root.add_child(tip)
	# (a whipping of line where the dart sits on the pole, and where you hold it)
	for z: float in [-1.74, 0.0]:
		var band := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.03
		bm.bottom_radius = 0.03
		bm.height = 0.1
		bm.radial_segments = 6
		bm.rings = 1
		band.mesh = bm
		band.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		band.position = Vector3(0.0, 0.0, z)
		band.material_override = _flat(Color(0.86, 0.83, 0.7))
		root.add_child(band)
	return root


## Your aim: little square dots along the arc and a ring on the water, flat bright pixels.
func _make_arc() -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "HarpoonAim"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	mm.mesh = q
	mm.instance_count = 34
	mmi.multimesh = mm
	var m := _unshaded(Color(1.0, 0.92, 0.7, 0.85))
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = false
	return mmi


## The tuna door: a hinged panel in the transom's inside face (a frame round it), facing forward into the cockpit.
func _make_door() -> Node3D:
	var root := Node3D.new()
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.74, 0.64, 0.015)
	frame.mesh = fm
	frame.position = Vector3(0.0, 0.0, 0.06)
	frame.material_override = _flat(Color(0.32, 0.33, 0.32))
	root.add_child(frame)
	var panel := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.66, 0.56, 0.02)
	panel.mesh = pm
	panel.position = Vector3(0.0, 0.0, 0.05)
	panel.material_override = _flat(Color(0.7, 0.71, 0.66))
	root.add_child(panel)
	return root


## Pointing along `v` (a throw straight up or down too).
static func _look(v: Vector3) -> Basis:
	if v.length_squared() < 1e-6:
		return Basis.IDENTITY
	return Basis.looking_at(v, Vector3.UP if absf(v.normalized().y) < 0.98 else Vector3.FORWARD)


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m
