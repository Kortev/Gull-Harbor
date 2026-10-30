extends RefCounted
## One bluefin on one rod, from the hookup to boatside. It runs on the machine of whoever holds the rod, so it feels
## instant (rods.gd sends the others how it's going, and tells the host when it ends); no nodes, so a test can run a
## whole fight headless.
##
## One spring between your hands and the fish (docs/FIGHT_DESIGN.md, the brainstorm's "Loaded Rod"). The line
## stretches when the fish swims away, when you raise the rod and when you wind; it goes slack when the fish comes
## at you, when you drop the rod and when the boat closes on it. Its stretch is the tension T, 0 .. 1 of what the
## line takes: past the drag setting the drag slips and pays out line (the reel screams), past 1 for a moment the
## line parts. There's no right answer per move and no text: you read the rod's bend, the reel and the line.
##
## - Cranking only wins line while the rod isn't loaded (REEL_STALL): against a heavy fish the reel just grinds.
##   So you pump: raise the rod (it hauls the fish toward you, the reel silent), then drop it, winding the slack.
## - Lifting the fish toward you is what tires it (LIFT), a tight line a little; a slack one lets it get its breath.
## - Lay the rod over against the way it's swinging round (side pressure) and it turns slower, its effort goes into
##   fighting the turn rather than going away (line for you), and held hard it turns its head, comes at you for a
##   moment and sulks.
## - The hook only holds so much: shock (a head shake against a stiff rod, a jump landing on a tight line) and slack
##   while it thrashes tear it out. When it jumps, drop the rod tip (bow to it).
##
## You: `crank` 0..1 (left mouse), `rod_pitch` (the rod's elevation, 0.15 tip at the water .. 1.35 near upright),
## `side` (-1..1, the rod laid over: + toward increasing bearing), `drag_set` (the drag lever, DETENTS).

signal move_started(move: String)
## broke (the line parted), broke_rail (parted where it lay on her), pulled (the hook pulled out), thrown (thrown on
## a jump), spooled (it took every metre), chafed (worn through on the hull), cut (it went under the boat with her
## props turning), tangle (another line sawed through it)
signal lost(reason: String)
## Played out and up alongside: the crew's turn (the harpoon, the tuna door).
signal boatside

## thrust: how hard it swims (x its size and freshness); away: how much of that is away from you; k: how fast it
## takes line against the tension (m/s per unit of pull over T); turn: how fast it swings round the boat (rad/s at
## 20 m); depth: where it heads (m); dur: how long (s); head: how much its head's thrashing (slack then costs hook).
const MOVES := {
	"run":    {"thrust": 1.0,  "away": 1.0,  "k": 30.0, "turn": 0.1,  "depth": 20.0,  "dur": [5.0, 12.0], "head": 0.25},
	"sound":  {"thrust": 0.8,  "away": 0.8,  "k": 6.0,  "turn": 0.04, "depth": 110.0, "dur": [6.0, 10.0], "head": 0.25},
	"dog":    {"thrust": 0.45, "away": 0.6,  "k": 3.0,  "turn": 0.03, "depth": 60.0,  "dur": [4.0, 8.0],  "head": 0.25},
	"shake":  {"thrust": 0.6,  "away": 0.5,  "k": 3.0,  "turn": 0.06, "depth": 15.0,  "dur": [1.5, 2.5],  "head": 1.0},
	"circle": {"thrust": 0.6,  "away": 0.35, "k": 3.0,  "turn": 0.25, "depth": 50.0,  "dur": [6.0, 10.0], "head": 0.25},
	"surge":  {"thrust": 1.0,  "away": 1.0,  "k": 30.0, "turn": 0.15, "depth": 10.0,  "dur": [1.0, 2.0],  "head": 1.0},
	"jump":   {"thrust": 0.0,  "away": 0.0,  "k": 3.0,  "turn": 0.0,  "depth": 0.0,   "dur": [1.6, 1.6],  "head": 1.0},
	"spiral": {"thrust": 0.35, "away": 0.25, "k": 3.0,  "turn": 0.3,  "depth": 0.0,   "dur": [6.0, 9.0],  "head": 0.25},
}
## The knobs that matter most: the tension where cranking stops winning line, how fast a fish gives line when you
## out-pull it, what tires it, and how stretchy the line is (m of stretch per unit of tension).
const REEL_STALL := 0.28
const PULL_IN := 6.0
const TIRE := 0.25
const LIFT := 5.5
const SPRING_BASE := 0.8
const SPRING_PER_M := 0.012
const E_FLOOR := 0.15            # a spent fish still pulls this much of a fresh one
const CRANK := 2.4               # m/s of line a stand-up reel winds in, flat out
const RUN_SPEED := 9.0           # m/s, a fresh bluefin flat out
const ROD_REACH := 1.7           # m the tip travels along the line from low to high
const TIP_H := 2.0               # m the tip's above the water (for the line's angle)
const DETENTS := [0.0, 0.45, 0.72, 0.95]     # the drag lever: free, light, strike, full
const STRIKE_DRAG := 0.72
const BIND_MAX := 0.4            # cranking into a slipping drag: up to this much more tension (the creak, the snap)
const BIND_RATE := 1.2
const BREAK_HOLD := 0.5          # s at full tension before the line parts
const SNAP := 1.35               # this much and it parts at once
const HOLD_SHOCK := 4.0
const HOLD_SLACK := 0.5
const AIR_WEAR := 3.0
const HOLD_HEAL := 0.05
const SHAKE_SHOCK := 0.35
const REENTRY := 0.6
const SLACK_MAX := 8.0
const SIDE_TURN := 0.7
const SIDE_TIRE := 1.2
const HEAD_TURN_T := 2.0
const CAPACITY := 500.0          # m of line on the reel
const BOATSIDE := 7.0            # m of line out: alongside
## A beaten fish only goes into its death spiral this close (m of line): further off it's tired but still fighting.
## In the spiral it circles deep under her, the same way round lap after lap, coming up as you win line.
const SPIRAL_IN := 30.0
## The boat. Where the line from the rod tip to the fish lies on her (rods.gd ray-casts it: rub_now) it wears
## (CHAFE_LIFE s of full rubbing parts it); under her with the props turning, it's cut in PROP_GRACE s. Backing down
## on a fish astern runs the boat back over it at BACK_SPEED (slack to wind). Left alone, a big fish slowly tows her
## stern round to it (TOW).
const CLEAR := 1.0               # m of line from the tip that never rubs (leaning out, the rod held up)
const RUB_ALL := 2.0             # m of line over her house and bow for a full rub
const HULL_MARGIN := 0.5         # m: a line grazing her side rubs too (the outline estimate, for the plotter)
const CHAFE_LIFE := 14.0
## Another rod's line tangled in this one (rods.gd): the lines saw at each other and it parts in TANGLE_LIFE s unless
## someone clears it, and the tension's up while they're crossed.
const TANGLE_LIFE := 45.0
const UNDER := 2.5
const PROP_GRACE := 2.5
const BACK_SPEED := 2.2
const TOW := 0.06

var kg := 150.0
## Line out from the rod tip to the fish (m), and how fresh it is (1 .. 0, played out).
var line_out := 40.0
var energy := 1.0
## Where it is: its bearing round the boat (radians, 0 dead astern, + to starboard) and its depth (m).
var bearing := 0.0
var depth := 5.0
## T: the line's tension, 0..1 of what it takes (the rod's bend). (Called strain so rods.gd's plumbing keeps it.)
var strain := 0.0
## How hard it's pulling right now (its swim, in tension units), for the rod and the fish's look.
var pull := 0.0
var move := ""
## The helm: -1 backing down hard .. 0 neutral .. 1 ahead (rods.gd sets it from the captain): the props turning.
var throttle := 0.0
## Her velocity (m/s, her own x across and z astern: her bow's -z) when `moving` (rods.gd, from boat/helm.gd): the
## fish stays where it is in the water, so she really closes on it backing down (slack to wind) or pulls away from
## it under way (the tension rises, the drag pays out). Without `moving` (the headless tests), the throttle stands in.
var boat_vel := Vector2.ZERO
var moving := false
## Her outline from above, in her frame (x across, z astern: her bow's -z): half her beam, her transom, the aft face of
## her house, her bow, and the spot the fish's bearing is measured from (rods.gd sets them from her spec).
var half_beam := 2.4
var aft := 7.3
var house := 0.4
var fore := -6.7
var from := 7.05
## The rod tip in her frame (x, z), rods.gd sets it from the rod as drawn. Left at NAN (the headless tests), the
## angler stands aft, `reach` (0..1) of the way out to the corner the fish is on.
var tip := Vector2(NAN, NAN)
var reach := 0.0
## The rod's in its holder with nobody on it (rods.gd): the drag still works the fish on its runs, but nobody winds,
## so the slack's never taken up and it gets its breath back.
var in_holder := false
## Gear from the dock (boat/fish_hold.gd, rods.gd sets these): a two-speed reel winds faster, heavier line takes more
## rubbing and holds longer at full tension.
var crank_mul := 1.0
var chafe_mul := 1.0
var grace_add := 0.0
var tangled := false
## How worn the line is from rubbing the hull, 0..1 (1: it parts), and how hard it's rubbing right now (0..1).
var wear := 0.0
var chafe := 0.0
## How hard the line's rubbing on her right now from the real line against her real hull (rods.gd: rub_on_hull);
## below 0 (the headless tests), worked out from her outline seen from above instead.
var rub_now := -1.0
var move_t := 0.0
var done := false
var rng := RandomNumberGenerator.new()

## The spring: stretch (m; below 0 it's slack), extra tension from cranking into a slipping drag, a passing shock.
var stretch := 0.0
var bind := 0.0
var shock := 0.0
## The drag slipping (line going out) and how fast it's paying out (m/s), line actually wound (m/s), the reel
## grinding (cranking under load, winning nothing).
var slipping := false
var paying := 0.0
var wind := 0.0
var grinding := false
## How well the hook's holding, 1 .. 0 (gone). Out of the water on a jump.
var hold := 1.0
var airborne := false
## The drag the angler's set (the lever), for cues.
var drag := STRIKE_DRAG

var _len := 1.0
var _turn_sign := 1.0
var _over_t := 0.0
var _prop_t := 0.0
var _goal_s := 90.0
var _fv := 0.0               # the fish's speed along the line (m/s, + away from you)
var _tip_was := NAN
var _jit := 0.0
var _low_t := 0.0
var _side_t := 0.0
var _run_cut := false
var _toward_t := 0.0
var _thrown_t := 0.0
var _jumped := false
var _sweep := 0.0
## After it changes hands: no shock, no hook lost, no break for this long (s).
var grace := 0.0
var _going_under := false


func _init(weight_kg: float, out: float, fresh := 1.0, seed_value := -1) -> void:
	kg = weight_kg
	line_out = out
	energy = fresh
	if seed_value >= 0:
		rng.seed = seed_value
	_goal_s = 40.0 + 0.25 * kg
	_turn_sign = 1.0 if rng.randf() < 0.5 else -1.0
	if fresh > 0.8:
		_set_move("run")
		# the opening run is a long one: a schoolie's a few seconds, a giant's takes most of the spool's first layer
		_len = rng.randf_range(4.0, 8.0) if kg < 100.0 else rng.randf_range(8.0, 20.0)
	else:
		_set_move(_pick())


## How strong it is for its weight (in tension units): a schoolie barely loads the rod, a giant out-pulls the drag.
static func size_of(w: float) -> float:
	return minf(0.35 + w / 285.0, 1.9)


## One tick of the fight.
func step(dt: float, crank: float, rod_pitch: float, side: float, drag_set: float) -> void:
	if done or dt <= 0.0:
		return
	drag = drag_set
	grace = maxf(grace - dt, 0.0)
	var m: Dictionary = MOVES[move]
	var sz := size_of(kg)
	var e := E_FLOOR + (1.0 - E_FLOOR) * energy
	var cushion := _cushion(rod_pitch, side)
	# side pressure only bites with the rod loaded and bent
	var side_eff := side * clampf(strain / 0.6, 0.0, 1.0) * cushion
	var against := absf(side_eff) > 0.05 and signf(side_eff) == -_turn_sign
	move_t += dt
	if move_t >= _len:
		_next_move()
		m = MOVES[move]

	# how hard it swims, and which way
	_jit += (rng.randf_range(-1.0, 1.0) - _jit) * minf(1.0, 2.0 * dt)
	var thrust := float(m["thrust"])
	if move == "shake":
		thrust += 0.3 * sin(move_t * TAU * 3.5)
	thrust = clampf(thrust + 0.15 * _jit, 0.0, 1.2)
	var away := float(m["away"])
	if move == "spiral":
		away = 0.8 if _going_under else 0.25
	var swim := sz * thrust * away * e
	if against:
		swim *= 1.0 - 0.5 * absf(side_eff)       # (its effort going into fighting the turn, not into going away)
	airborne = false
	if move == "jump":
		if move_t < 0.5:
			swim = -0.2 * sz             # up at you: the line goes slack
			depth = move_toward(depth, 0.0, 12.0 * dt)
		elif move_t < 1.2:
			swim = 0.0
			airborne = true
			depth = 0.0
			_thrown_t = 1.0
		elif not _jumped:
			_jumped = true               # back in: one jolt, harder the higher the rod and the tighter the line
			shock += REENTRY * sz * (rod_pitch / 1.35) * (1.3 - cushion)
	if _toward_t > 0.0:
		_toward_t -= dt
		swim = -0.15 * sz                # its head turned: coming at you
	_thrown_t = maxf(_thrown_t - dt, 0.0) if not airborne else _thrown_t

	# the boat: closing on it makes slack, pulling away loads the line
	var boat_close := 0.0
	if moving and boat_vel != Vector2.ZERO:
		var hd_was := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
		var rel := Vector2(sin(bearing), cos(bearing)) * hd_was - boat_vel * dt
		bearing = atan2(rel.x, rel.y)
		var gap := sqrt(rel.length_squared() + depth * depth) - sqrt(hd_was * hd_was + depth * depth)
		boat_close = -gap / dt
	else:
		var b0 := absf(wrapf(bearing, -PI, PI))
		var back := maxf(-throttle, 0.0) * clampf(cos(b0) * 1.5, 0.0, 1.0)     # (backing down only closes on a fish astern)
		boat_close = BACK_SPEED * back - 1.5 * maxf(throttle, 0.0)

	# the rod: raising it hauls on the fish, dropping it gives slack
	var tip_along := ROD_REACH * (rod_pitch - 0.15) / 1.2
	if is_nan(_tip_was):
		_tip_was = tip_along
	var tip_v := (tip_along - _tip_was) / dt
	_tip_was = tip_along

	# the reel: winds slack in freely, wins less and less as the rod loads, grinds against a heavy fish
	var eff := 1.0 if stretch < 0.0 else clampf((REEL_STALL - strain) / (REEL_STALL - 0.2), 0.0, 1.0)
	wind = 0.0 if slipping or in_holder else CRANK * crank_mul * crank * eff
	grinding = crank > 0.1 and eff < 0.3 and not slipping and not in_holder

	# the fish: takes line while it out-pulls the tension, gives it when you out-pull it (it's heavy: it eases)
	var vt := 0.0
	if swim > strain:
		vt = minf((swim - strain) * float(m["k"]), RUN_SPEED * e * maxf(thrust, 0.1))
	else:
		vt = -minf((strain - swim) * PULL_IN, 3.0)
	var tau := 0.4 + kg / 400.0
	_fv += (vt - _fv) * minf(1.0, dt / tau)

	# the spring
	stretch += (_fv + tip_v + wind - boat_close) * dt
	line_out -= wind * dt
	var spring := SPRING_BASE + SPRING_PER_M * line_out
	var t := maxf(stretch, 0.0) / spring
	var dx := 0.0
	if t > drag_set:
		dx = (t - drag_set) * spring
		line_out += dx
		stretch -= dx
		t = drag_set
		slipping = true
	else:
		slipping = false
	paying = lerpf(paying, dx / dt, minf(1.0, 6.0 * dt))
	stretch = maxf(stretch, -SLACK_MAX)
	bind = move_toward(bind, BIND_MAX * crank if slipping and crank > 0.1 else 0.0, (BIND_RATE if slipping else 3.0) * dt)
	strain = t

	# shocks: a head shake against a stiff rod, decaying
	if move == "shake" and grace <= 0.0:
		shock = maxf(shock, SHAKE_SHOCK * clampf(kg / 150.0, 0.5, 1.5) * absf(sin(move_t * TAU * 3.5)) * (1.3 - cushion))
	shock = move_toward(shock, 0.0, 6.0 * dt)
	if grace > 0.0:
		shock = 0.0

	# the line: where it lies on her it rubs; full tension for a moment parts it, a jolt past SNAP at once
	var hd0 := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	if rub_now >= 0.0:
		chafe = rub_now
	else:
		chafe = rub(_tip(hd0), _fish(hd0), half_beam, house, fore) * hd0 / (hd0 + depth + 1.0)
		if move == "spiral":
			chafe *= 0.5        # (deep under her, the line goes down steep and only brushes the hull)
	var t_fish := t + bind + shock + (0.15 if tangled else 0.0) + 0.25 * chafe
	if grace <= 0.0:
		_over_t = _over_t + dt if t_fish >= 1.0 else maxf(_over_t - 2.0 * dt, 0.0)
		if _over_t >= BREAK_HOLD + grace_add or t_fish >= SNAP:
			_end("broke_rail" if chafe > 0.2 else "broke")
			return
	wear += chafe * (0.4 + 0.6 * t) * dt / (CHAFE_LIFE * chafe_mul)
	if tangled:
		wear += dt / (TANGLE_LIFE * chafe_mul)
	if wear >= 1.0:
		_end("tangle" if tangled and chafe < 0.05 else "chafed")
		return

	# the hook: torn by shock, worked loose by slack while it thrashes, tested hardest in the air
	if grace <= 0.0:
		hold -= maxf(0.0, t + shock - 0.9) * HOLD_SHOCK * dt
		if stretch < 0.0 and not airborne:
			hold -= float(m["head"]) * HOLD_SLACK * dt
		if airborne:
			# out of the water it's all its weight shaking on the hook: a tight line (the rod held high, the reel winding
			# it tight) throws it; the tip dropped, the line slack, it holds
			hold -= (maxf(0.0, t - 0.15) + 0.5 * crank * rod_pitch / 1.35) * AIR_WEAR * dt
		if t > 0.2 and t < 0.85 and move != "shake":
			hold = minf(hold + HOLD_HEAL * dt, 1.0)
		if hold <= 0.0:
			_end("thrown" if _thrown_t > 0.0 else "pulled")
			return

	# under her with the props turning: cut
	var b := absf(wrapf(bearing, -PI, PI))
	if b > UNDER and absf(throttle) > 0.05 and depth < 25.0 and hd0 < 35.0:
		_prop_t += dt
		if _prop_t >= PROP_GRACE:
			_end("cut")
			return
	else:
		_prop_t = 0.0
	if line_out >= CAPACITY:
		_end("spooled")
		return

	# tiring: hauling it toward you most, a tight line a little; slack, it gets its breath back
	var side_tire := SIDE_TIRE * absf(side_eff) * thrust * e if against else 0.0
	energy -= (TIRE * t * (0.4 + thrust) + LIFT * t * maxf(0.0, -_fv) + side_tire) * dt / _goal_s
	_low_t = _low_t + dt if t < 0.15 else 0.0
	if _low_t > 1.0:
		energy += lerpf(0.02, 0.012, clampf((kg - 40.0) / 260.0, 0.0, 1.0)) * dt
	energy = clampf(energy, 0.0, 1.0)

	# where it is: swinging round the boat (slower with the rod laid over against it), heading for its depth
	var hd := maxf(hd0, 1.0)
	var turn := float(m["turn"])
	if move == "circle" and kg < 60.0:
		turn *= 1.6
	if against:
		turn *= 1.0 - SIDE_TURN * absf(side_eff)
	elif absf(side_eff) > 0.05:
		turn *= 1.0 + 0.3 * absf(side_eff)
	var was_b := bearing
	bearing += turn * _turn_sign * dt * clampf(20.0 / hd, 0.2, 1.2)
	if against and move == "run":
		bearing -= _turn_sign * 0.08 * absf(side_eff) * dt
	# held hard over against it: it turns its head (a circle or a dog), or a run's cut short
	_side_t = _side_t + dt if against and absf(side_eff) > 0.5 else 0.0
	if _side_t >= HEAD_TURN_T and move in ["circle", "dog"]:
		_side_t = 0.0
		_turn_sign = -_turn_sign
		_toward_t = 2.0
		_set_move("dog")                          # (beaten round, it sulks rather than running again)
	elif _side_t >= 1.0 and move == "run" and not _run_cut:
		_run_cut = true
		_len = move_t + (_len - move_t) * 0.7
	var c := cos(bearing)
	if c < -0.1:
		_going_under = true
	elif c > 0.1:
		_going_under = false
	# a big fish tows her stern round toward it, slowly
	bearing -= sin(wrapf(bearing, -PI, PI)) * TOW * clampf(t, 0.0, 1.0) * dt
	_sweep = lerpf(_sweep, (bearing - was_b) / dt, minf(1.0, 4.0 * dt))
	var want := minf(float(m["depth"]), line_out * 0.85)
	if move == "spiral":
		# circling deep under her, the line steep; up it comes as you win line, and it's up for the last few metres
		want = line_out * 0.8 if line_out > 12.0 else 3.0
	elif move == "jump":
		want = 0.0
	elif energy < 0.25 and line_out < SPIRAL_IN:
		want = minf(want, 3.0)
	if move != "jump":
		depth = move_toward(depth, want, dt * 6.0)
	pull = maxf(swim, 0.0)
	line_out = maxf(line_out, BOATSIDE - 1.0)

	if energy < 0.2 and line_out <= BOATSIDE:
		done = true
		boatside.emit()


## How much give the rod's got: the angle between the rod and the line (a rod pointed down the line is a stiff
## stick; one held up at right angles to it is all spring), 0.15 .. 1.
func _cushion(rod_pitch: float, side: float) -> float:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	var line_el := -atan2(depth + TIP_H, maxf(hd, 0.5))
	var ang := sqrt(pow(rod_pitch - line_el, 2.0) + pow(side * 0.9, 2.0))
	return clampf(ang / 1.2, 0.15, 1.0)


## What the rod, the reel and the line are doing: all you get to read (and all the test anglers read).
func cues() -> Dictionary:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	return {"bend": strain + shock, "slipping": slipping, "paying": paying, "grinding": grinding,
			"airborne": airborne, "thrash": float(MOVES[move]["head"]) >= 1.0,
			"line_pitch": -atan2(depth + TIP_H, maxf(hd, 0.5)), "sweep": _sweep,
			"spool": line_out / CAPACITY, "contact": chafe, "visible": (line_out < 30.0 and depth < 10.0) or airborne,
			"drag": drag, "slack": stretch < 0.0, "line_out": line_out, "bearing": bearing}


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
		_set_move("dog" if move == "circle" and rng.randf() < 0.5 else "circle")
	else:
		_set_move(_pick())


func _pick() -> String:
	# fresh, it runs and sounds; as it tires it circles under the boat. Never two runs in a row; a small fish near the
	# top jumps.
	var w := {"run": 0.0 if move == "run" else 2.0 * energy, "sound": 3.0,
			"shake": 1.2 * (2.0 if kg < 60.0 else 1.0), "circle": 3.0 * (1.0 - energy), "dog": 0.8, "surge": 0.6,
			"jump": (1.6 if kg < 60.0 else (0.5 if kg < 150.0 else 0.0)) if depth < 25.0 else 0.0}
	var total := 0.0
	for k: String in w:
		total += float(w[k])
	var r := rng.randf() * total
	for k: String in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "dog"


## Picking up a fight where it was (the rod changing hands, or going into its holder): the fish carries on with what
## it was doing, the same way round, the line as stretched as it was and the hook as worked as it was. A moment's
## grace either side of the handover.
func carry_on(m: String, stretch_was := 0.0, turn := 0.0, hold_was := 1.0) -> void:
	if m == "rest":
		m = "dog"
	if MOVES.has(m) and m != move:
		_set_move(m)
	stretch = stretch_was
	hold = hold_was
	if turn != 0.0:
		_turn_sign = signf(turn)
	_going_under = cos(bearing) < 0.0
	grace = 0.5


## Which way round it's swinging (+1 or -1), for carry_on when the rod changes hands.
func turn_sign() -> float:
	return _turn_sign


func _set_move(m: String) -> void:
	var again := m == move
	move = m
	move_t = 0.0
	_run_cut = false
	_jumped = false
	var d: Array = MOVES[m]["dur"]
	_len = rng.randf_range(float(d[0]), float(d[1])) * (1.0 if m == "jump" else 0.6 + 0.4 * energy)
	# (a spiral carries on the same way round; anything else that swings may swing back)
	if m in ["run", "circle", "spiral"] and not (again and m == "spiral") and rng.randf() < 0.5:
		_turn_sign = -_turn_sign
	move_started.emit(m)


## Where the fish is from above, in her frame (x, z), hd m off.
func _fish(hd: float) -> Vector2:
	return Vector2(0.0, from) + Vector2(sin(bearing), cos(bearing)) * hd


## The rod tip (x, z): as rods.gd drew it, or for the tests the angler aft, `reach` of the way to the fish's corner,
## the rod a metre out toward the fish.
func _tip(hd: float) -> Vector2:
	if not is_nan(tip.x):
		return tip
	return corner_tip(bearing, hd, reach, half_beam, aft, from)


## A rod tip a metre out toward the fish from an angler aft, `out` (0..1) of the way over to the fish's corner.
static func corner_tip(b: float, hd: float, out: float, hb: float, stern_z: float, from_z: float) -> Vector2:
	var side := 1.0 if sin(b) >= 0.0 else -1.0
	var stand := Vector2(side * (hb - 0.3) * out, stern_z - 0.8)
	var fish := Vector2(0.0, from_z) + Vector2(sin(b), cos(b)) * hd
	return stand + (fish - stand).normalized() * 1.0


## How hard a line from `tip_at` to `fish` (her frame, from above) rubs her, 0..1: how much of it, past the first
## CLEAR m, runs over her house and her bow (from the house's aft face forward, her full beam tapering to her stem,
## grown by HULL_MARGIN). The headless stand-in for rods.gd's ray-cast against her real hull, and the captain's plotter.
static func rub(tip_at: Vector2, fish: Vector2, hb: float, house_z: float, bow_z: float) -> float:
	var g := HULL_MARGIN
	var shoulder := bow_z + 0.45 * (house_z - bow_z)
	var poly: Array[Vector2] = [Vector2(hb + g, house_z), Vector2(-hb - g, house_z),
			Vector2(-hb - g, shoulder), Vector2(0.0, bow_z - g), Vector2(hb + g, shoulder)]
	var d := fish - tip_at
	var span := d.length()
	if span < 0.01:
		return 0.0
	# clip the line to the outline (it's convex): t runs from 0 at the tip to 1 at the fish
	var t0 := 0.0
	var t1 := 1.0
	var mid := Vector2(0.0, (house_z + bow_z) * 0.5)
	for i in poly.size():
		var a: Vector2 = poly[i]
		var e: Vector2 = poly[(i + 1) % poly.size()] - a
		var n := Vector2(e.y, -e.x)
		if n.dot(mid - a) > 0.0:
			n = -n                 # (pointing out)
		var num := n.dot(a - tip_at)     # >= 0: the tip's inside this edge
		var den := n.dot(d)
		if absf(den) < 1e-6:
			if num < 0.0:
				return 0.0
			continue
		var tt := num / den
		if den > 0.0:
			t1 = minf(t1, tt)      # going out through this edge
		else:
			t0 = maxf(t0, tt)      # coming in through it
		if t0 >= t1:
			return 0.0
	var over := (t1 - maxf(t0, CLEAR / span)) * span
	return smoothstep(0.0, RUB_ALL, over)
