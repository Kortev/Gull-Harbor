extends RefCounted
## One bluefin on one rod, from the hookup to boatside. It runs on the machine of whoever holds the rod, so it feels
## instant (rods.gd sends the others how it's going, and tells the host when it ends); no nodes, so a test can run a
## whole fight headless.
##
## The needle first: keep it in the green. The needle is the line's tension, T (0 slack .. 1 and past: parting).
## Hold left mouse and you reel, and the needle climbs; let go and it falls back to what the fish alone puts on it.
## - In the green (GREEN_LO .. GREEN_HI) while you reel, you win line and the fish tires. Nowhere else does either.
## - Too slack (under SLACK) for SLACK_HOLD s and the hook falls out; too tight (over RED) for BREAK_HOLD s and the line
##   parts. Both warn first (the HUD's words), and both forgive a moment.
## - The fish's moves speak the same language: on a run it puts the needle high by itself and takes line (let go, or
##   it's in the red); on a jump, reeling spikes it (let go); circling and sulking it's light (reel); beaten near the
##   boat, in its death spiral, it comes up as you reel.
## Then three things the green alone doesn't fix, each on the HUD the moment it matters:
## - The angle. He swims where he likes round the boat (his runs and circles swing him wide) and she doesn't follow
##   by herself. Dead astern you can lift him; off to the side you win less, abeam next to nothing, under her none at
##   all (angle_k), and forward of her house the line's on the hull, wearing. The captain keeps her stern to him
##   (A/D); alone, the rod goes in its holder while you steer.
## - Your arms (`arms`, 1 fresh .. 0 gone). Reeling drains them, the harder he's pulling and the bigger he is the
##   faster; heaving the rod up drains them too; hands off they come back. Spent (under TIRED) you reel slow and he
##   barely tires. A crewmate taking the rod (E on it) has fresh arms; alone, rest them with the rod in its holder,
##   where he takes line on the drag and gets his breath back. rods.gd keeps your arms between fights and rods.
## - He gets his breath back whenever the line's light (RECOVER), so resting costs you; once he's beaten
##   (under BEATEN) he stays beaten.
## A big fish takes minutes (GOAL_BASE + GOAL_PER_KG x kg of working him in the green): a schoolie is one pair of arms,
## a giant is the whole crew swapping on the rod while the captain swings her. The ways to lose him: the line parts
## (the red), the hook pulls (slack), thrown on a jump (reeling while he's in the air), chafed through on the hull,
## cut on the props, sawn through by another line tangled in it, spooled.
##
## You: `crank` 0..1 (left mouse) and `rod_pitch` (heaving it up, past HEAVE, tires your arms). `side` and `drag_set`
## are taken and ignored (kept so rods.gd and the bots needn't change).

signal move_started(move: String)
## broke (the line parted), broke_rail (parted where it lay on her), pulled (the hook pulled out), thrown (thrown on
## a jump), spooled (it took every metre), chafed (worn through on the hull), cut (it went under the boat with her
## props turning), tangle (another line sawed through it)
signal lost(reason: String)
## Played out and up alongside: the crew's turn (the harpoon, the tuna door).
signal boatside

## pull: how high it puts the needle by itself (x its size, a little less as it tires); take: m/s of line it takes
## (a run, x its freshness); turn: how fast it swings round the boat (rad/s at 20 m); depth: where it heads (m);
## dur: how long (s). A charge: he turns and comes at the boat, under her (CHARGE_TURN rad/s round toward her bow,
## till he's past UNDER): the line goes light (reel, fast: winding CHARGE_WIN x as fast, green or not, to keep it
## tight), and then he's under her and it's the captain's.
const MOVES := {
	"run":    {"pull": 0.70, "take": 5.5, "turn": 0.26, "depth": 20.0,  "dur": [5.0, 11.0]},
	"sound":  {"pull": 0.32, "take": 0.0, "turn": 0.06, "depth": 110.0, "dur": [6.0, 10.0]},
	"dog":    {"pull": 0.24, "take": 0.0, "turn": 0.08, "depth": 60.0,  "dur": [4.0, 8.0]},
	"shake":  {"pull": 0.28, "take": 0.0, "turn": 0.06, "depth": 15.0,  "dur": [1.5, 2.5]},
	"circle": {"pull": 0.18, "take": 0.0, "turn": 0.28, "depth": 50.0,  "dur": [6.0, 10.0]},
	"surge":  {"pull": 0.66, "take": 4.0, "turn": 0.3,  "depth": 10.0,  "dur": [1.5, 3.0]},
	"jump":   {"pull": 0.30, "take": 0.0, "turn": 0.0,  "depth": 0.0,   "dur": [1.6, 1.6]},
	"spiral": {"pull": 0.10, "take": 0.0, "turn": 0.3,  "depth": 0.0,   "dur": [6.0, 9.0]},
	"charge": {"pull": 0.04, "take": 0.0, "turn": 0.0,  "depth": 30.0,  "dur": [3.0, 5.0]},
}
## The needle: the green band, slack under SLACK, red over RED; how much reeling puts on it, how fast it climbs and
## falls (per s), and how long it forgives being too slack or too tight (s).
const GREEN_LO := 0.35
const GREEN_HI := 0.7
const SLACK := 0.18
const RED := 0.86
const REEL := 0.45
const RISE := 0.9
const FALL := 1.1
const SLACK_HOLD := 2.0
const BREAK_HOLD := 1.5
## Beaten (under BEATEN of its fight left) it's forgiving: this much longer before slack or the red loses it, and the
## hull wears its line this much slower. Fresh, it never goes QUIET s without a run or a surge.
const BEATEN := 0.25
const BEATEN_HOLD := 3.0
const BEATEN_WEAR := 0.25
const QUIET := 22.0
## m/s of line won in the green, flat out (x the dock's two-speed reel), and how long a fish fights in the green
## before it's beaten: GOAL_BASE + GOAL_PER_KG x its weight (s).
const WIN := 2.2
const GOAL_BASE := 35.0
const GOAL_PER_KG := 0.4
## He gets his breath back while nobody's working him (the needle low, under EASY, and not running against the drag):
## this fraction of the rate working him tires him. Not once he's beaten.
const RECOVER := 0.3
const EASY := 0.26
## The angle: inside SQUARE rad of dead astern you lift him with everything; it falls away to nothing by WIDE (a bit
## forward of abeam). How much a deep fish's steep line spares you of it (0..1).
const SQUARE := 0.6
const WIDE := 1.9
const STEEP := 0.7
## Your arms: s of reeling flat out against a middling fish (x its size) before they're gone, and s to get them all
## back hands off with the line easy (ARM_HOLDER with the rod in its holder: no weight on them at all). Under TIRED
## the reel comes slow: at nothing left you wind SPENT_WIN of the line and put SPENT_PULL of the pressure on. Heaving
## the rod up past HEAVE costs them too.
const ARM_LIFE := 60.0
const ARM_REST := 24.0
const ARM_HOLDER := 12.0
const TIRED := 0.3
const SPENT_WIN := 0.25
const SPENT_PULL := 0.35
const HEAVE := 0.9
const EASY_ARMS := 0.6
## Fresh, it won't come in closer than this (m): you tire it before you can bring it to the boat.
const SPIRAL_IN := 30.0
const CHARGE_TURN := 0.55
const CHARGE_WIN := 1.6
const TIP_H := 2.0               # m the tip's above the water (for the line's angle)
const DETENTS := [0.0, 0.45, 0.72, 0.95]     # the old drag lever's notches (the wheel still clicks it; it does nothing)
const STRIKE_DRAG := 0.72
const CAPACITY := 500.0          # m of line on the reel
const BOATSIDE := 7.0            # m of line out: alongside
## The boat. Where the line from the rod tip to the fish lies on her (rods.gd ray-casts it: rub_now) it wears
## (CHAFE_LIFE s of full rubbing parts it); under her with the props turning, it's cut in PROP_GRACE s. Backing down
## on a fish astern runs the boat back over it at BACK_SPEED (line won). Left alone, a big fish tows her stern round
## to it, but only a little (TOW): never enough to do the captain's job for her.
const CLEAR := 1.0               # m of line from the tip that never rubs (leaning out, the rod held up)
const RUB_ALL := 2.0             # m of line over her house and bow for a full rub
const HULL_MARGIN := 0.5         # m: a line grazing her side rubs too (the outline estimate, for the plotter)
const CHAFE_LIFE := 10.0
## Forward of the beam (past SIDE_FROM rad) the line's along her side: it rubs this hard (side_rub).
const SIDE_FROM := 1.75
const SIDE_RUB := 0.8
## Another rod's line tangled in this one (rods.gd): the lines saw at each other and it parts in TANGLE_LIFE s unless
## someone winds the other line in.
const TANGLE_LIFE := 20.0
const UNDER := 2.5
const PROP_GRACE := 2.5
const BACK_SPEED := 2.2
const TOW := 0.01

var kg := 150.0
## Line out from the rod tip to the fish (m), and how fresh it is (1 .. 0, played out).
var line_out := 40.0
var energy := 1.0
## Where it is: its bearing round the boat (radians, 0 dead astern, + to starboard) and its depth (m).
var bearing := 0.0
var depth := 5.0
## T: the needle, 0..1 of what the line takes. (Called strain so rods.gd's plumbing keeps it.)
var strain := 0.0
## How hard it's pulling right now (in tension units), for the rod and the fish's look.
var pull := 0.0
var move := ""
## The helm: -1 backing down hard .. 0 neutral .. 1 ahead (rods.gd sets it from the captain): the props turning.
var throttle := 0.0
## Her velocity (m/s, her own x across and z astern: her bow's -z) when `moving` (rods.gd, from boat/helm.gd): the
## fish stays where it is in the water, so she closes on it backing down (line won) or pulls away from it under way
## (line given). Without `moving` (the headless tests), the throttle stands in.
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
## The rod's in its holder with nobody on it (rods.gd): the holder's drag keeps it right, nobody reels; it takes line
## on its runs and can't be lost to slack or the red.
var in_holder := false
## Gear from the dock (boat/fish_hold.gd, rods.gd sets these): a two-speed reel winds faster, heavier line takes more
## rubbing and forgives the red a little longer.
var crank_mul := 1.0
var chafe_mul := 1.0
var grace_add := 0.0
var tangled := false
## The angler's arms, 1 fresh .. 0 gone (rods.gd hands them in when you take the rod and keeps them after).
var arms := 1.0
## How worn the line is from rubbing the hull, 0..1 (1: it parts), and how hard it's rubbing right now (0..1).
var wear := 0.0
var chafe := 0.0
## How hard the line's rubbing on her right now from the real line against her real hull (rods.gd: rub_on_hull);
## below 0 (the headless tests), worked out from her outline seen from above instead.
var rub_now := -1.0
var move_t := 0.0
var done := false
var rng := RandomNumberGenerator.new()

## How the line lies (below 0 it's slack: the drawn line droops), and a passing jolt (none now: kept for rods.gd).
var stretch := 0.0
var shock := 0.0
## Line going out on a run (the reel screams) and how fast (m/s), line won (m/s), the reel grinding (reeling in the
## red).
var slipping := false
var paying := 0.0
var wind := 0.0
var grinding := false
var reeling := false
## How long it's been too slack and too tight (s): the warnings, and past SLACK_HOLD / BREAK_HOLD the loss.
var slack_t := 0.0
var _over_t := 0.0
## How well the hook's holding, 1 .. 0 (gone): what's left of the slack it'll forgive.
var hold := 1.0
var airborne := false
var drag := STRIKE_DRAG

var _len := 1.0
var _turn_sign := 1.0
## How fast it's swinging round her and going up or down right now (rad/s, m/s): they ease toward the move's
## (TURN_EASE rad/s a second, DIVE_EASE m/s a second), so the fish you see turns and dives smoothly.
var _turn_v := 0.0
var _dive_v := 0.0
const TURN_EASE := 0.2
const DIVE_EASE := 4.0
var _prop_t := 0.0
var _goal_s := 90.0
var _jit := 0.0
var _thrown_t := 0.0
var _sweep := 0.0
## After it changes hands: nothing lost for this long (s).
var grace := 0.0
var _going_under := false
var _quiet_t := 0.0
## Held still (ui/fight_tutor.gd, the first fish you ever hook): the fish doesn't move, no line won or lost, nothing
## lost; only the needle answers your hand (against `pause_pull`, or the fish's move when that's below 0), so you can
## see what reeling does. It runs where the fight runs (the holder's machine): the fish waits, not the game.
var paused := false
var pause_pull := -1.0


func _init(weight_kg: float, out: float, fresh := 1.0, seed_value := -1) -> void:
	kg = weight_kg
	line_out = out
	energy = fresh
	if seed_value >= 0:
		rng.seed = seed_value
	_goal_s = GOAL_BASE + GOAL_PER_KG * kg
	_turn_sign = 1.0 if rng.randf() < 0.5 else -1.0
	if fresh > 0.8:
		_set_move("run")
		# the opening run is a long one: a schoolie's a few seconds, a giant's takes a good bit of line
		_len = rng.randf_range(4.0, 7.0) if kg < 100.0 else rng.randf_range(7.0, 12.0)
	else:
		_set_move(_pick())
	strain = 0.5


## How strong it is for its weight: a schoolie barely loads the rod, a giant leans on it.
static func size_of(w: float) -> float:
	return minf(0.35 + w / 285.0, 1.9)


## How high the fish alone puts the needle right now (its move, its size, a little less tired, a wander).
func _fish_pull() -> float:
	var p := float(MOVES[move]["pull"])
	var big := clampf((kg - 40.0) / 260.0, 0.0, 1.0)
	if move in ["run", "surge"]:
		p += 0.08 * big - 0.08 * (1.0 - energy)          # (a run never quite reaches the red by itself)
	else:
		p *= (0.8 + 0.4 * big) * (0.7 + 0.3 * energy)
	if move == "shake":
		p += 0.12 * sin(move_t * TAU * 1.5)
	return clampf(p + 0.06 * _jit, 0.0, 0.84)


## The needle toward where your hand and the fish put it, at its own pace.
func _needle(dt: float, crank: float, fish: float) -> void:
	var want := fish + REEL * crank * lerpf(SPENT_PULL, 1.0, power())
	if airborne and crank > 0.1:
		want = 1.3                       # reeling with him in the air: all his weight on the line at once
	var rate := (RISE * (3.0 if airborne else 1.0)) if want > strain else FALL
	strain = move_toward(strain, want, rate * dt)


## One tick of the fight.
func step(dt: float, crank: float, rod_pitch: float, _side: float, drag_set: float) -> void:
	if done or dt <= 0.0:
		return
	drag = drag_set
	if in_holder:
		crank = 0.0
	reeling = crank > 0.1
	if paused:
		# the first fish's lesson: he waits; only the needle answers your hand
		_needle(dt, crank, pause_pull if pause_pull >= 0.0 else _fish_pull())
		wind = 0.0
		paying = 0.0
		grinding = false
		slack_t = 0.0
		_over_t = 0.0
		stretch = (strain - SLACK) * 4.0
		return
	_tire_arms(dt, crank, rod_pitch)
	grace = maxf(grace - dt, 0.0)
	move_t += dt
	_quiet_t = 0.0 if move in ["run", "surge"] else _quiet_t + dt
	if move_t >= _len:
		_next_move()
	var m: Dictionary = MOVES[move]
	_jit += (rng.randf_range(-1.0, 1.0) - _jit) * minf(1.0, 1.5 * dt)
	airborne = move == "jump" and move_t >= 0.5 and move_t < 1.2
	if move == "jump":
		depth = move_toward(depth, 0.0, 12.0 * dt) if move_t < 0.5 else 0.0
		if airborne:
			_thrown_t = 1.0
	_thrown_t = maxf(_thrown_t - dt, 0.0) if not airborne else _thrown_t
	var fish := _fish_pull()
	_needle(dt, crank, fish)
	var t := strain
	var green := t >= GREEN_LO and t <= GREEN_HI

	# the line: a run takes it (the reel screams), the green wins it, the boat closing on it wins it too
	# (the more line he's dragging through the water, the shorter his runs: he never quite strips the reel)
	var take := float(m["take"]) * (0.45 + 0.55 * energy) * clampf(1.3 - line_out / 250.0, 0.1, 1.0)
	slipping = take > 0.0
	paying = lerpf(paying, take, minf(1.0, 6.0 * dt))
	var lift := angle_k() * lerpf(SPENT_WIN, 1.0, power())
	wind = WIN * crank_mul * crank * lift if green and not slipping else 0.0
	if move == "charge":
		wind = WIN * crank_mul * crank * CHARGE_WIN * lerpf(SPENT_WIN, 1.0, power())    # (catching up the belly)
	grinding = reeling and t > RED
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
	# (fresh, it won't be brought in closer than SPIRAL_IN: tire it first. Only stops line being won, never moves it.)
	var was_out := line_out
	line_out += (take - wind - boat_close) * dt
	var floor_out := lerpf(BOATSIDE - 1.0, SPIRAL_IN, clampf((energy - 0.2) / 0.15, 0.0, 1.0))
	if line_out < floor_out:
		line_out = maxf(line_out, minf(was_out, floor_out))
	line_out = maxf(line_out, BOATSIDE - 1.0)
	stretch = (t - SLACK) * 4.0

	# too slack, too tight: a moment's warning, then lost (not in its holder: the holder's drag keeps it right)
	var beaten := energy < BEATEN
	if grace <= 0.0 and not in_holder:
		var slack := t < SLACK and move != "jump"
		slack_t = slack_t + dt if slack else maxf(slack_t - 2.0 * dt, 0.0)
		hold = clampf(1.0 - slack_t / slack_limit(), 0.0, 1.0)
		_over_t = _over_t + dt if t > RED else maxf(_over_t - 2.0 * dt, 0.0)
		if _over_t >= break_limit() or (airborne and t > 1.05):
			_end("thrown" if _thrown_t > 0.0 else ("broke_rail" if chafe > 0.2 else "broke"))
			return
		if slack_t >= slack_limit():
			_end("pulled")
			return
	else:
		slack_t = 0.0
		_over_t = 0.0

	# the captain's part: where the line lies on her it rubs; under her with the props turning it's cut
	var hd0 := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	if rub_now >= 0.0:
		chafe = rub_now
	else:
		chafe = rub(_tip(hd0), _fish(hd0), half_beam, house, fore) * hd0 / (hd0 + depth + 1.0)
		if move == "spiral":
			chafe *= 0.5        # (deep under her, the line goes down steep and only brushes the hull)
	chafe = maxf(chafe, side_rub())
	wear += chafe * (0.4 + 0.6 * t) * dt / (CHAFE_LIFE * chafe_mul) * (BEATEN_WEAR if beaten else 1.0)
	if tangled:
		wear += dt / (TANGLE_LIFE * chafe_mul)
	if wear >= 1.0:
		_end("tangle" if tangled and chafe < 0.05 else "chafed")
		return
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

	# tiring: only in the green while you reel, as square on him as you are and as fresh as your arms (a little on its
	# runs, against the drag); left be, he gets his breath back
	if green and reeling and lift > 0.05:
		energy -= dt / _goal_s * lift
	elif slipping:
		energy -= 0.25 * dt / _goal_s
	elif not beaten and t < EASY:
		energy = minf(energy + RECOVER * dt / _goal_s, 1.0)
	energy = clampf(energy, 0.0, 1.0)

	# where it is: swinging round the boat, heading for its depth
	var hd := maxf(hd0, 1.0)
	var turn := float(m["turn"])
	if move == "circle" and kg < 60.0:
		turn *= 1.6
	if move != "spiral":
		turn *= 0.35 + 0.65 * energy       # (tired, he swings round her slow and wide)
	var was_b := bearing
	# (it swings round at the move's pace, but eases into it and out of it: a fish turning back the other way slows,
	# comes round and picks up again, never flicks)
	_turn_v = move_toward(_turn_v, turn * _turn_sign, TURN_EASE * dt)
	bearing += _turn_v * dt * clampf(20.0 / hd, 0.2, 1.2)
	if move == "charge":
		var wb := wrapf(bearing, -PI, PI)
		bearing += (signf(wb) if absf(wb) > 0.05 else _turn_sign) * CHARGE_TURN * dt
		if b_now() > UNDER + 0.15:
			_next_move()
	var c := cos(bearing)
	if c < -0.1:
		_going_under = true
	elif c > 0.1:
		_going_under = false
	# a big fish tows her stern round toward it, slowly
	bearing -= sin(wrapf(bearing, -PI, PI)) * TOW * clampf(t, 0.0, 1.0) * dt
	_sweep = lerpf(_sweep, (bearing - was_b) / dt, minf(1.0, 4.0 * dt))
	var goal_d := minf(float(m["depth"]), line_out * 0.85)
	if move == "spiral":
		goal_d = line_out * 0.8 if line_out > 12.0 else 3.0
	elif energy < 0.25 and line_out < SPIRAL_IN:
		goal_d = minf(goal_d, 3.0)
	if move != "jump":
		# (diving and rising with way on it: it gathers speed down, and slows as it comes to its depth)
		_dive_v = move_toward(_dive_v, clampf((goal_d - depth) * 0.9, -6.0, 6.0), DIVE_EASE * dt)
		depth = maxf(depth + _dive_v * dt, 0.0)
	else:
		_dive_v = 0.0
	pull = fish

	if energy < 0.2 and line_out <= BOATSIDE:
		done = true
		boatside.emit()


## Your arms, a tick on: reeling drains them (harder the more he's pulling and the bigger he is), heaving the rod up
## too; hands off they come back, but only with the line easy (under EASY_ARMS: holding the rod against him while he
## leans on it is no rest, a run's work), and fast with the rod in its holder.
func _tire_arms(dt: float, crank: float, rod_pitch: float) -> void:
	var heft := 0.4 + 0.6 * size_of(kg)
	var use := crank * (0.5 + 0.7 * strain) * heft + maxf(rod_pitch - HEAVE, 0.0) * 1.5 * strain
	if in_holder:
		arms += dt / ARM_HOLDER
	elif use > 0.01:
		arms -= use * dt / ARM_LIFE
	else:
		arms += (EASY_ARMS - clampf(strain, 0.0, 1.0)) * 1.6 * dt / ARM_REST     # (holding him against a run: no rest)
	arms = clampf(arms, 0.0, 1.0)


## How much your arms have left to give, 0 (spent) .. 1: all of it down to TIRED, falling away to nothing below it.
func power() -> float:
	return smoothstep(0.0, TIRED, arms)


## Forward of her beam the line from the stern lies along her side, whatever the ray-cast makes of it: 0 abeam,
## SIDE_RUB by the time he's well forward of it (the plotter's red arc), less for a deep fish.
func side_rub() -> float:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	return SIDE_RUB * smoothstep(SIDE_FROM, SIDE_FROM + 0.55, b_now()) * hd / (hd + depth * 0.5 + 1.0)


## How square on him you are, 1 .. 0: dead astern (inside SQUARE either side) everything you put on him lifts him;
## off to the side less; abeam next to nothing; past WIDE, round toward her bow or under her, none. A deep fish with
## the line going down steep spares you some of it.
func angle_k() -> float:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	var k := 1.0 - smoothstep(SQUARE, WIDE, b_now())
	return lerpf(k, 1.0, STEEP * depth / (hd + depth + 1.0))


## How long too slack, and too tight, loses it right now (s): longer once it's beaten, so the end's forgiving.
func slack_limit() -> float:
	return SLACK_HOLD * (BEATEN_HOLD if energy < BEATEN else 1.0)


func break_limit() -> float:
	return (BREAK_HOLD + grace_add * 0.5) * (BEATEN_HOLD * 0.67 if energy < BEATEN else 1.0)


## How long it's been under her with the props turning (s): PROP_GRACE and it's cut.
func prop_t() -> float:
	return _prop_t


## What the rod, the reel and the line are doing: all you get to read (and all the test anglers read).
func cues() -> Dictionary:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	return {"bend": strain, "tension": strain, "slipping": slipping, "paying": paying, "grinding": grinding,
			"airborne": airborne, "jumping": move == "jump", "charging": move == "charge", "thrash": move == "shake", "slack_t": slack_t,
			"red_t": _over_t,
			"line_pitch": -atan2(depth + TIP_H, maxf(hd, 0.5)), "sweep": _sweep,
			"spool": line_out / CAPACITY, "contact": chafe, "visible": (line_out < 30.0 and depth < 10.0) or airborne,
			"drag": drag, "slack": stretch < 0.0, "line_out": line_out, "bearing": bearing, "angle": angle_k(),
			"arms": arms, "tangled": tangled, "holder": in_holder, "props": _prop_t}


## The needle, for the fight HUD: the one number that matters.
func load_now() -> float:
	return strain


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
	# Fresh and held in close, it's off again; and it never sulks long while it's got fight in it.
	if energy > 0.3 and _quiet_t > QUIET and move not in ["run", "surge"]:
		return "run" if rng.randf() < 0.65 else "surge"
	var close := 3.0 if line_out < SPIRAL_IN + 5.0 and energy > 0.35 else 0.0
	var w := {"run": 0.0 if move == "run" else 2.0 * energy + close, "sound": 3.0,
			"shake": 1.2 * (2.0 if kg < 60.0 else 1.0), "circle": 3.0 * (1.0 - energy), "dog": 0.8, "surge": 0.6,
			"jump": (1.6 if kg < 60.0 else (0.6 if kg < 150.0 else (0.3 if kg < 250.0 else 0.0))) if depth < 25.0 else 0.0,
			"charge": 1.2 * energy if energy > 0.35 and move != "charge" and line_out < 150.0 else 0.0}
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
## it was doing, the same way round, the needle where it was and the hook as worked as it was. A moment's grace to
## get your hands on it.
func carry_on(m: String, stretch_was := 0.0, turn := 0.0, hold_was := 1.0) -> void:
	if m == "rest":
		m = "dog"
	if MOVES.has(m) and m != move:
		_set_move(m)
	stretch = stretch_was
	strain = clampf(stretch_was / 4.0 + SLACK, 0.0, 1.0)      # (the needle where it was)
	hold = hold_was
	slack_t = (1.0 - hold_was) * SLACK_HOLD
	if turn != 0.0:
		_turn_sign = signf(turn)
	_turn_v = float(MOVES[move]["turn"]) * _turn_sign      # (still swinging round as it was)
	_going_under = cos(bearing) < 0.0
	grace = 1.0


## In the spiral: whether it's on the half of the lap that takes it under her (ease off) rather than coming up toward
## you (wind).
func going_under() -> bool:
	return _going_under


## Which way round it's swinging (+1 or -1), for carry_on when the rod changes hands.
func turn_sign() -> float:
	return _turn_sign


func _set_move(m: String) -> void:
	var again := m == move
	move = m
	move_t = 0.0
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
