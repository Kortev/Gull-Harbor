extends RefCounted
## One bluefin on one rod, from the hookup to boatside. It runs on the machine of whoever holds the rod, so it feels
## instant (rods.gd sends the others how it's going, and tells the host when it ends); no nodes, so a test can run a
## whole fight headless.
##
## Arcade, not a simulation (from Gull Harbor's fish fight): the tuna plays a string of MOVES, each with a tell (the
## line under the crosshair, the reel, the rod) and one right answer. Fight a move the wrong way and the strain
## climbs; hold it at the top for STRAIN_GRACE seconds and the line parts. Every bluefin opens with the screaming run.
##
## You: `crank` (hold left mouse: wind line in) and `lift` (hold right mouse: heave the rod up; a pump is a lift,
## then cranking as you drop it back, which wins line a heavy fish won't give you to cranking alone).

signal move_started(move: String)
## broke (the line parted), pulled (the hook pulled out), spooled (it took every metre), chafed (worn through on
## the hull), cut (it went under the boat with her props turning)
signal lost(reason: String)
## Played out and up alongside: the crew's turn (the harpoon, the tuna door).
signal boatside

## answer: hold (don't crank: let the drag tire it), pump (lift, then crank down), tight (keep cranking or lifting,
## or the hook pulls), reel (crank). out: how fast it takes line (x the fish's run speed); pull: how hard;
## turn: how fast it swings round the boat (rad/s at 20 m: a circling giant's 5 m/s, slower than the boat turns, so
## a captain can always catch it up); depth: where it heads (m); dur: how long (s).
const MOVES := {
	"run":    {"answer": "hold",  "out": 1.0,  "pull": 1.0,  "turn": 0.1,  "depth": 20.0,  "dur": [5.0, 9.0]},
	"sound":  {"answer": "pump",  "out": 0.25, "pull": 0.85, "turn": 0.04, "depth": 110.0, "dur": [6.0, 10.0]},
	"shake":  {"answer": "tight", "out": 0.0,  "pull": 0.55, "turn": 0.06, "depth": 15.0,  "dur": [1.6, 2.6]},
	"circle": {"answer": "pump",  "out": 0.0,  "pull": 0.6,  "turn": 0.25, "depth": 50.0,  "dur": [6.0, 10.0]},
	"rest":   {"answer": "reel",  "out": 0.0,  "pull": 0.3,  "turn": 0.03, "depth": 25.0,  "dur": [2.5, 4.0]},
	"spiral": {"answer": "reel",  "out": 0.0,  "pull": 0.35, "turn": 0.3,  "depth": 2.0,   "dur": [6.0, 9.0]},
}
const TELLS := {
	"run": "It's running! Let it go", "sound": "It's sounding deep! Pump: heave, then crank down",
	"shake": "Head shakes! Keep it tight", "circle": "It's circling! Pump: heave, then crank down",
	"rest": "It's resting! Crank", "spiral": "Death spiral! Crank!",
}
const STRAIN_GRACE := 1.2       # s at full strain before the line parts
const SLACK_GRACE := 1.6        # s of slack in a headshake before the hook pulls
const CRANK := 2.4              # m/s of line a stand-up reel winds in, flat out
const CAPACITY := 500.0         # m of line on the reel
const BOATSIDE := 7.0           # m of line out: alongside
## A beaten fish only goes into its death spiral this close (m of line): further off it's tired but still fighting,
## weaker. In the spiral it circles deep under her, the same way round lap after lap, coming up as you win line:
## crank while it's astern coming up to you, ease off while it's forward going under her (cranking then strains).
const SPIRAL_IN := 30.0
const RUN_SPEED := 9.0          # m/s, a fresh bluefin's first run
## The boat (the captain at the wheel turns her and sets `throttle`). Swung forward of her beam, the line lies along
## the hull and wears (CHAFE_LIFE s of full rubbing parts it); under her with the props turning, it's cut in
## PROP_GRACE s (long enough to hear "out of gear!" and do it). Backing down on a fish astern runs the boat back over it at BACK_SPEED, takes the strain off and
## slows a run. Left alone, a big fish slowly tows her stern round to it (TOW).
const CHAFE_FROM := 1.6
const CHAFE_ALL := 2.4
const CHAFE_LIFE := 14.0
const UNDER := 2.5
const PROP_GRACE := 1.5
const BACK_SPEED := 2.2
const TOW := 0.06
const ARMS_CRANK := 0.0075      # per s cranking, x (0.2 + how outgunned, squared)
const ARMS_HEAVE := 0.012       # per s heaving
const ARMS_REST := 0.015        # per s back, easing off with the rod

var kg := 150.0
## Line out from the rod tip to the fish (m), and how fresh it is (1 .. 0, played out).
var line_out := 40.0
var energy := 1.0
## Where it is: its bearing round the boat (radians, 0 dead astern, + to starboard) and its depth (m).
var bearing := 0.0
var depth := 5.0
## 0..1: how hard you're fighting it wrong (the rod's bend, the ring round the crosshair).
var strain := 0.0
## How hard it pulls right now, 0..1 (the rod).
var pull := 0.0
var move := ""
## The helm: -1 backing down hard .. 0 neutral .. 1 ahead (rods.gd sets it from the captain): the props turning.
var throttle := 0.0
## Her velocity (m/s, her own x across and z astern) when `moving` (rods.gd, from boat/helm.gd): the fish stays where
## it is in the water, so she really closes on it backing down (the slack's wound in, if anyone's on the rod) or
## pulls away from it under way (the line pays out against the drag). Without `moving` (the headless tests), the
## throttle stands in for it.
var boat_vel := Vector2.ZERO
var moving := false
## How far the angler's got the rod out over the side the fish is on, 0..1 (standing at that corner, leaning out):
## buys a little room before the line touches the hull, never as much as swinging the boat. rods.gd sets it from
## where the angler stands.
var reach := 0.0
## The rod's in its holder with nobody on it (rods.gd): the drag still works the fish on its runs (it takes line and
## tires), but nobody cranks or pumps, so between runs it neither tires nor gives line. Backing down on it wins no
## line either (nobody's winding in the slack): the slack only lets a headshake throw the hook.
var in_holder := false
## Gear from the dock (boat/fish_hold.gd, rods.gd sets these): a two-speed reel winds faster, heavier line takes more
## rubbing and holds longer at full strain, a harness spares your arms.
var crank_mul := 1.0
var chafe_mul := 1.0
var grace_add := 0.0
var arms_mul := 1.0
## The angler's arms, 1 fresh .. 0 spent (rods.gd keeps them on the person, so they carry over and rest up
## between fights). Cranking and heaving wear them, the heavier the fish the faster, and fighting it the wrong way
## (cranking against a run, cranking a deep fish without pumping) much faster than the right way. Tired arms only
## reel slower and pump weaker: they never stop you. Easing off rests them; so does handing the rod to a crewmate.
var arms := 1.0
## How worn the line is from rubbing the hull, 0..1 (1: it parts), and how hard it's rubbing right now (0..1).
var wear := 0.0
var chafe := 0.0
var move_t := 0.0
var done := false
var rng := RandomNumberGenerator.new()

var _len := 1.0
var _turn_sign := 1.0
var _over_t := 0.0
var _slack_t := 0.0
var _prop_t := 0.0
var _pump := 0.0
var _lift_low := true
var _goal_s := 90.0
## In a spiral: the half of the lap it's on (forward, going under her), with a little give either side of the beam
## so the hint doesn't flicker as it crosses.
var _going_under := false


func _init(weight_kg: float, out: float, fresh := 1.0, seed_value := -1) -> void:
	kg = weight_kg
	line_out = out
	energy = fresh
	if seed_value >= 0:
		rng.seed = seed_value
	# how long it takes to tire, fought right: a schoolie a minute, a giant three
	_goal_s = 40.0 + kg * 0.38
	_turn_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_set_move("run" if fresh > 0.8 else _pick())


func answer() -> String:
	if move == "spiral" and _going_under:
		return "ease"
	return str(MOVES[move]["answer"])


func tell() -> String:
	# worst first: the props about to cut it, then it under her, then the line rubbing her side
	if _prop_t > 0.0:
		return "OUT OF GEAR! It's under the props!"
	# (a spiral goes under her every lap: its own hints say when)
	if move != "spiral" and b_now() > UNDER - 0.2 and depth < 25.0:
		return "It's under the boat! No throttle: steer her stern round to it (A/D)"
	# (in a spiral it brushes her every lap: only a real rub, or a worn line, outranks the spiral's own hints)
	var warn := chafe > (0.18 if move == "spiral" else 0.08) or (chafe > 0.0 and wear > 0.3)
	if warn:
		# (it's swung forward of her beam: the line's lying along her side, wearing through)
		var side := "starboard" if sin(bearing) > 0.0 else "port"
		if reach > 0.6:
			return "The line's rubbing the hull! Swing her stern to it (the wheel)"
		return "The line's rubbing the hull! Take it to the %s corner, or swing her stern to it" % side
	if arms < 0.25:
		return "Your arms are tired: you're reeling slow. Fight it right and they come back"
	if move == "spiral":
		return "Death spiral! Ease off, it's going under her" if answer() == "ease" \
				else "Death spiral! Crank, it's coming up"
	return str(TELLS.get(move, ""))


## One tick of the fight: what you're doing (cranking, how far the rod is lifted 0..1) against what it's doing.
func step(dt: float, crank: bool, lift: float) -> void:
	if done or dt <= 0.0:
		return
	move_t += dt
	if move_t >= _len:
		_next_move()
	var m: Dictionary = MOVES[move]
	var e := 0.35 + 0.65 * energy
	var big := clampf(kg / 250.0, 0.4, 1.6)        # how outgunned your tackle is
	var ans := answer()
	var back := 0.0
	var ahead := 0.0
	if moving and boat_vel != Vector2.ZERO:
		var hd_was := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
		var rel := Vector2(sin(bearing), cos(bearing)) * hd_was - boat_vel * dt
		bearing = atan2(rel.x, rel.y)
		var gap := sqrt(rel.length_squared() + depth * depth) - sqrt(hd_was * hd_was + depth * depth)
		back = clampf(-gap / dt / BACK_SPEED, 0.0, 1.0)
		ahead = clampf(gap / dt / 1.5, 0.0, 1.0)
		# closing: the slack's wound in (nobody winds it in a holder); pulling away: the line pays out
		line_out += maxf(gap, 0.0) if in_holder else gap
	else:
		var b0 := absf(wrapf(bearing, -PI, PI))
		back = maxf(-throttle, 0.0) * clampf(cos(b0) * 1.5, 0.0, 1.0)     # (backing down only helps on a fish astern)
		ahead = maxf(throttle, 0.0)
		line_out += (1.5 * ahead - (0.0 if in_holder else BACK_SPEED * back)) * dt
	var b := absf(wrapf(bearing, -PI, PI))
	var power := 0.35 + 0.65 * arms
	var heavy := 0.2 + big * big
	# fighting it the wrong way wears you out: cranking against its run, or a deep fish without pumping it
	var waste := 3.0 if ans == "hold" else (2.0 if (ans == "pump" and _pump <= 0.0) or ans == "ease" else 0.7)
	if crank:
		arms -= ARMS_CRANK * heavy * dt * waste * arms_mul
	if lift > 0.3:
		arms -= ARMS_HEAVE * heavy * dt * (1.0 if ans == "pump" else 1.5) * arms_mul
	if not crank and lift <= 0.3:
		arms += ARMS_REST * dt
	arms = clampf(arms, 0.0, 1.0)

	# Line: the move takes it (the drag and the boat backing down slow it), the reel brings it back if the move lets
	# you, and so does the boat coming back over it.
	line_out += RUN_SPEED * float(m["out"]) * e * dt * (1.0 - 0.7 * back)
	var gain := 0.0
	if crank:
		match ans:
			"hold":
				gain = 0.0
			"pump":
				gain = minf(_pump, CRANK * crank_mul * dt * 1.3 * power)
				_pump -= gain
				gain += CRANK * crank_mul * dt * 0.12
			"ease":
				gain = CRANK * crank_mul * dt * 0.15 * power
			_:
				gain = CRANK * crank_mul * dt * (1.0 - float(m["pull"]) * 0.45 * e) * power
	# a heave of the rod banks line to crank back on the way down (less, the heavier the fish)
	if lift > 0.7 and _lift_low:
		_pump += (3.2 / (0.6 + kg / 150.0) + 0.8) * power
		_lift_low = false
	elif lift < 0.3:
		_lift_low = true
	line_out = maxf(line_out - gain, BOATSIDE - 1.0)

	# Strain: cranking against a run, cranking a deep fish without pumping, the bigger the fish the worse.
	var target := 0.0
	match ans:
		"hold":
			target = 2.0 * big if crank else 0.0
		"pump":
			target = 0.45 * big if crank and _pump <= 0.0 else 0.0
		"tight":
			target = 0.0
		"ease":
			target = 0.6 * big if crank else 0.0
		_:
			target = 0.25 * big * float(m["pull"]) if crank else 0.0
	target = target * (1.0 - 0.6 * back) + 0.5 * ahead
	# Off the stern and forward of the beam the line lies along the hull: it rubs, harder the flatter it lies.
	var hd0 := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	chafe = smoothstep(CHAFE_FROM + 0.35 * reach, CHAFE_ALL + 0.35 * reach, b) * hd0 / (hd0 + depth + 1.0)
	if move == "spiral":
		chafe *= 0.5        # (deep under her, the line goes down steep and only brushes the hull)
	target = maxf(target, 0.6 * chafe)
	wear += chafe * (0.4 + 0.6 * pull) * dt / (CHAFE_LIFE * chafe_mul)
	if wear >= 1.0:
		_end("chafed")
		return
	# Under her with the props turning: cut.
	if b > UNDER and absf(throttle) > 0.05 and depth < 25.0 and hd0 < 35.0:
		_prop_t += dt
		if _prop_t >= PROP_GRACE:
			_end("cut")
			return
	else:
		_prop_t = 0.0
	strain = move_toward(strain, minf(target, 1.0), dt * (2.2 if target > strain else 1.0))
	if strain >= 0.999:
		_over_t += dt
		if _over_t >= STRAIN_GRACE + grace_add:
			_end("broke")
			return
	else:
		_over_t = maxf(_over_t - dt * 2.0, 0.0)
	if ans == "tight":
		var slack: bool = back > 0.05 if in_holder else (not crank and lift < 0.4)
		_slack_t = _slack_t + dt if slack else 0.0
		if _slack_t > SLACK_GRACE:
			_end("pulled")
			return
	else:
		_slack_t = 0.0
	if line_out >= CAPACITY:
		_end("spooled")
		return

	# Tiring: working against the drag and your pumping wears it down. With the line tight it never gets its wind
	# back; doing nothing just doesn't tire it.
	var drain := 1.0 / _goal_s
	match ans:
		"hold":
			drain *= 1.5 if not crank else 0.6
		"pump":
			drain *= 1.2 if lift > 0.5 or _pump > 0.0 else 0.3
		_:
			drain *= 1.0 if crank or lift > 0.5 else 0.0
	if in_holder and ans != "hold":
		drain = 0.0
	energy = clampf(energy - drain * dt, 0.0, 1.0)

	# Where it is: swinging round the boat, heading for its depth (never deeper than the line reaches).
	var hd := maxf(sqrt(maxf(line_out * line_out - depth * depth, 0.0)), 1.0)
	bearing += float(m["turn"]) * _turn_sign * dt * clampf(20.0 / hd, 0.2, 1.2)
	var c := cos(bearing)
	if c < -0.1:
		_going_under = true
	elif c > 0.1:
		_going_under = false
	# a big fish tows her stern round toward it, slowly
	bearing -= sin(wrapf(bearing, -PI, PI)) * TOW * pull * dt
	var want := minf(float(m["depth"]), line_out * 0.85)
	if move == "spiral":
		# circling deep under her, the line steep; up it comes as you win line, and it's up for the last few metres
		want = line_out * 0.8 if line_out > 12.0 else 3.0
	elif energy < 0.25 and line_out < SPIRAL_IN:
		want = minf(want, 3.0)
	depth = move_toward(depth, want, dt * 6.0)
	pull = clampf(float(m["pull"]) * e + strain * 0.4, 0.15, 1.0)

	if energy < 0.25 and line_out <= BOATSIDE:
		done = true
		boatside.emit()


## How far round from dead astern it is (0 .. PI: PI is right under her bow).
func b_now() -> float:
	return absf(wrapf(bearing, -PI, PI))


## How far astern and to the side it is, flat (boat-local x, z from the stern), from its bearing and line.
func flat_offset() -> Vector2:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	return Vector2(sin(bearing), cos(bearing)) * hd


func _end(reason: String) -> void:
	done = true
	lost.emit(reason)


func _next_move() -> void:
	if energy < 0.25 and line_out <= SPIRAL_IN:
		_set_move("spiral" if move != "spiral" or rng.randf() < 0.7 else "shake")
	elif energy < 0.25:
		# beaten but still well off: no more runs, it hangs and circles slow and wide, giving line to the pump
		_set_move("rest" if move == "circle" and rng.randf() < 0.5 else "circle")
	elif move != "rest" and rng.randf() < 0.25 * (1.0 - energy):
		_set_move("rest")
	else:
		var pick := _pick()
		if pick == move:
			pick = _pick()
		_set_move(pick)


func _pick() -> String:
	# fresh, it runs and sounds; as it tires it circles under the boat
	var w := {"run": 2.0 * energy, "sound": 3.0, "shake": 1.2, "circle": 3.0 * (1.0 - energy), "rest": 0.8}
	var total := 0.0
	for k: String in w:
		total += float(w[k])
	var r := rng.randf() * total
	for k: String in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "rest"


## Picking up a fight where it was (the rod changing hands, or going into its holder): the fish carries on with
## what it was doing, the same way round, and the line's as strained as it was.
## `turn`: which way round it was swinging (+1 or -1; 0: unknown).
func carry_on(m: String, strain_was := 0.0, turn := 0.0) -> void:
	if MOVES.has(m) and m != move:
		_set_move(m)
	strain = strain_was
	if turn != 0.0:
		_turn_sign = signf(turn)
	_going_under = cos(bearing) < 0.0


## Which way round it's swinging (+1 or -1), for carry_on when the rod changes hands.
func turn_sign() -> float:
	return _turn_sign


func _set_move(m: String) -> void:
	var again := m == move
	move = m
	move_t = 0.0
	var d: Array = MOVES[m]["dur"]
	_len = rng.randf_range(float(d[0]), float(d[1])) * (0.6 + 0.4 * energy)
	# (a spiral carries on the same way round; anything else that swings may swing back)
	if m in ["run", "circle", "spiral"] and not (again and m == "spiral") and rng.randf() < 0.5:
		_turn_sign = -_turn_sign
	move_started.emit(m)
