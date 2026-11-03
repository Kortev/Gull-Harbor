extends RefCounted
## One bluefin on one rod, from the hookup to boatside. It runs on the machine of whoever holds the rod, so it feels
## instant (rods.gd sends the others how it's going, and tells the host when it ends); no nodes, so a test can run a
## whole fight headless.
##
## Big-game tackle, as it really works. Everything is in the line's own terms: a tension of 1 parts it.
## - **The line is a spring.** Between your hands and the fish there's `line_out` of line and the rod's own bend, and it
##   stretches (`stretch`, m: below 0 it's slack, a belly lying in the water). Its tension is the stretch over its give,
##   `give()`: lots of line is soft (a pump barely touches him at 300 m), a short line is stiff (every kick goes
##   straight to the hook). The rod's bend is that tension.
## - **The drag** is a lever you set by hand (`drag`, 0 free .. STRIKE_DRAG the strike detent .. 1 full: the scroll
##   wheel, a notch at a time). Past what it's set to, the spool slips and he takes line (the reel screams). It sticks a
##   little harder before it starts to slip than once it's going (STATIC, more on a short line), and the spool takes a
##   moment to spin up (SPOOL_ACC): a fish that bolts against a heavy drag puts a jolt through the line past the drag.
##   It climbs by itself as the spool empties (spool_gain: the line's coming off a smaller and smaller spool), and all
##   the line he drags through the water on a long fast run adds its own pull at his end (BELLY). Too light and he
##   takes everything; too heavy and the hook tears out (over HOOK_T) or a kick parts the line. On a long run, ease it.
## - **Line capacity.** CAPACITY m on the reel. On a run the spool empties; past half the backing shows, near the end
##   the bare arbor, and the drag's doubled. The skipper must chase (back down on him, S) or he spools you.
## - **Pump and wind.** The reel can only wind against so much (CRANK_MAX): against a fish that's pulling, cranking
##   just grinds (and against a slipping drag it twists the line, `twist`, gaining nothing). So you lift the rod (mouse
##   up: it stretches the line, up to the drag) and he comes toward you, and drop it winding as you go (the line's
##   light on the way down, the reel spins). Lift on his tired moments (`lull`: the bend eases, he's stopped pulling)
##   and you move him; lift into his run and the drag just slips.
## - **He tires working against the line** (energy: the harder the tension he's pulling against, and running against
##   the drag), and gets his breath back when nobody's on him. Off the stern your pressure's sideways and moves him
##   less (angle_k).
## - **He's a character** (`nature`): a runner, a sounder, a bulldog or a jumper, and the fight comes in phases: the
##   first blistering run off the strike; runs, sounding deep, dogging and shaking his head while he's fresh; tiring,
##   he circles deep, then close in his death spiral round under the boat (wind as he comes up, hold as he goes down);
##   near the boat, sudden surges; and when the leader comes up to the rod tip (LEADER m: `leader`), one last run.
## - **The hook** (`hold`, 1 .. 0 gone): torn out by too much tension held too long, worked loose by a head shake (on a
##   slack line most of all), thrown if the line's tight while he's in the air (drop the tip).
## - **The boat**: where the line lies on her it rubs (chafe: the real line against her real hull from rods.gd, or
##   her outline from above here), and wear weakens it; under her with the props turning it's cut. Backing down on
##   him closes the gap (the line goes light: wind like mad); running ahead pulls it tight.
## - **Your arms** (`arms` 1 .. 0): winding against a load, lifting and just holding a heavy fish take them; spent, you
##   wind and lift slow. Swap on the rod (fresh arms), or alone rest it in its holder (it fights on its drag).
## The ways to lose him: the line parts (broke, broke_rail: worn on her, twisted), the hook tears out (pulled) or
## falls out (shaken), thrown on a jump, spooled, chafed through on the hull, cut on the props, sawn through by
## another line tangled in it. Every one of them is something somebody could have done something about.
##
## You: step(dt, crank 0..1 (left mouse), rod_pitch (the rod's elevation, mouse up and down), side, drag lever 0..1).

signal move_started(move: String)
## broke (the line parted), broke_rail (parted where it was worn on her), twisted (parted, twisted from winding
## against the drag), pulled (the hook tore out: too much tension), shaken (it fell out: slack while he shook), thrown
## (thrown on a jump), spooled (it took every metre), chafed (worn through on the hull), cut (it went under the boat
## with her props turning), tangle (another line sawed through it)
signal lost(reason: String)
## Played out and up alongside: the crew's turn (the harpoon, the tuna door).
signal boatside
## The leader's up at the rod tip: the moment (rods/fight_fx.gd, the crew's shout). His last run comes with it.
signal leader_up

## k: how hard he pulls away (x his strength); sp: how fast he swims doing it (x his speed, with nothing on him;
## below 0 toward the boat); turn: how fast he swings round the boat (rad/s at 25 m); depth: where he heads (m);
## dur: how long (s); lull: he has tired moments in it (his pull comes and goes).
const MOVES := {
	"run":    {"k": 1.0,  "sp": 1.0,   "turn": 0.4,  "depth": 25.0,  "dur": [5.0, 10.0], "lull": false},
	"surge":  {"k": 1.0,  "sp": 0.85,  "turn": 0.3,  "depth": 10.0,  "dur": [1.5, 3.0],  "lull": false},
	"sound":  {"k": 0.8,  "sp": 0.35,  "turn": 0.06, "depth": 120.0, "dur": [8.0, 14.0], "lull": true},
	"dog":    {"k": 0.7,  "sp": 0.06,  "turn": 0.08, "depth": 60.0,  "dur": [5.0, 9.0],  "lull": true},
	"shake":  {"k": 0.55, "sp": 0.05,  "turn": 0.05, "depth": 15.0,  "dur": [1.5, 2.5],  "lull": false},
	"circle": {"k": 0.45, "sp": 0.03,  "turn": 0.34, "depth": 50.0,  "dur": [6.0, 10.0], "lull": true},
	"spiral": {"k": 0.35, "sp": 0.04,  "turn": 0.3,  "depth": 0.0,   "dur": [6.0, 9.0],  "lull": true},
	"jump":   {"k": 0.6,  "sp": 0.4,   "turn": 0.0,  "depth": 0.0,   "dur": [1.6, 1.6],  "lull": false},
	"charge": {"k": 0.0,  "sp": -0.55, "turn": 0.0,  "depth": 30.0,  "dur": [2.5, 4.0],  "lull": false},
}
## His nature (picked from the fish's own seed, so it's the same whoever's got the rod): what he does more of.
const NATURES := ["runner", "sounder", "bulldog", "jumper"]

## The reel: line on it (m), alongside (m of line out), and where the leader comes up to the rod tip (m).
const CAPACITY := 500.0
const BOATSIDE := 7.0
const LEADER := 16.0
## The drag: at full (the lever all the way) what it holds against at a full spool (x the line's breaking strain);
## the strike detent where it sits by default; how much harder it sticks before it starts slipping (more on a short
## line: no stretch in it); how fast the spool spins up for each metre the line's stretched past the drag (m/s each
## second: a long line soaks up his kick, a short one doesn't).
const DRAG_MAX := 0.55
const STRIKE_DRAG := 0.6
const STATIC := 1.2
const SHORT_STATIC := 0.5
const SPOOL_ACC := 100.0
## The lever's notches (the wheel steps it STEP at a time; the strike detent clicks).
const STEP := 0.1
## The line's give: the rod's bend (m of stretch for a tension of 1) and each metre of line's (m per m).
const ROD_GIVE := 1.2
const STRETCH := 0.025
## A long fast run drags line through the water: BELLY of tension at his end per (line out / CAPACITY) at his full
## speed.
const BELLY := 0.22
## m of line one radian of lifting the rod takes back (the tip going back over your head).
const ROD_LEVER := 2.2
## The reel: m/s flat out with nothing on it (x the dock's two-speed reel), and the tension it can't wind against.
const WIN := 3.0
const CRANK_MAX := 0.15
## A tension of 1 parts new line; worn line parts sooner (WORN_K of its strength gone when it's worn through).
const STRENGTH := 1.0
const WORN_K := 0.5
## How long the line takes being over its strength (s) before it parts (a jolt well past it parts it at once).
const PART_T := 0.06
## The hook: what he's been pulling against these last HELD_T s, over HOOK_T, tears its hole bigger (HOOK_TEAR of its
## hold a second for each unit over); slack, it works loose (SLACK_LOOSE a second, x SHAKE_LOOSE while he shakes his
## head); tight on a jump (over JUMP_T), it's thrown; and every head shake on a tight line works it (SHAKE_TEAR a
## second at a tension of 0.3, more the tighter).
const HOOK_T := 0.5
const HOOK_TEAR := 1.3
const HELD_T := 0.8
const SLACK_LOOSE := 0.02
const SHAKE_LOOSE := 12.0
const JUMP_T := 0.2
const JUMP_TEAR := 30.0
const SHAKE_TEAR := 0.025
## Fresh, he's this much under BEATEN when he's done; beaten, he stays beaten. Fresh, he never goes QUIET s without a
## run or a surge.
const BEATEN := 0.25
const QUIET := 22.0
## How long a fish takes to beat: GOAL_BASE + GOAL_PER_KG x kg seconds of steady pressure (PRESSURE of his pull), and
## how fast he gets his breath back with nobody on him (x that, under EASY of his pull).
const GOAL_BASE := 15.0
const GOAL_PER_KG := 0.12
const PRESSURE := 0.55
const RECOVER := 0.3
const EASY := 0.2
## How fast he comes to you with the line pulling him harder than he's pulling (m/s at a full unit over his pull).
const V_PULL := 4.0
## The strike: for BURST s he bolts harder and faster than he'll ever go again. Taking off again, his first strokes
## are a kick: KICK more pull for KICK_T s, and he's going whatever's on the line.
const BURST := 5.0
const KICK := 0.8
const KICK_T := 0.6
## The angle: inside SQUARE rad of dead astern you lift him with everything; it falls away to nothing by WIDE (a bit
## forward of abeam). How much a deep fish's steep line spares you of it (0..1).
const SQUARE := 0.6
const WIDE := 1.9
const STEEP := 0.7
## Your arms: s of winding flat out against a middling load before they're gone, s to get them back hands off
## (ARM_HOLDER with the rod in its holder); under TIRED they're going (you wind SPENT_WIN as fast and a lift does
## SPENT_LIFT of the good at nothing left).
const ARM_LIFE := 45.0
const ARM_REST := 40.0
const ARM_HOLDER := 30.0
const TIRED := 0.3
const SPENT_WIN := 0.3
const SPENT_LIFT := 0.45
## Close in: inside CLOSE m a fresh fish won't be brought (he bolts); beaten, inside SPIRAL_IN he circles under her in
## his death spiral.
const CLOSE := 40.0
const SPIRAL_IN := 45.0
const CHARGE_TURN := 0.55
const TIP_H := 2.0               # m the tip's above the water (for the line's angle)
## The boat. Where the line from the rod tip to the fish lies on her (rods.gd ray-casts it: rub_now) it wears
## (CHAFE_LIFE s of full rubbing parts it); under her with the props turning, it's cut in PROP_GRACE s. Backing down
## on a fish astern closes on it at BACK_SPEED. Left alone, a big fish tows her stern round to it, a little (TOW).
const CLEAR := 1.0               # m of line from the tip that never rubs (leaning out, the rod held up)
const RUB_ALL := 2.0             # m of line over her house and bow for a full rub
const HULL_MARGIN := 0.5         # m: a line grazing her side rubs too (the outline estimate, for the plotter)
const CHAFE_LIFE := 14.0
## Forward of the beam (past SIDE_FROM rad) the line's along her side: it rubs this hard (side_rub).
const SIDE_FROM := 1.75
const SIDE_RUB := 0.8
## Winding against a slipping drag twists the line (TWIST_RATE a second, cranking flat out): twisted all the way it
## has lost TWIST_K of its strength, and parts on the next hard pull.
const TWIST_RATE := 0.05
const TWIST_K := 0.6
## Another rod's line tangled in this one (rods.gd): the lines saw at each other and it parts in TANGLE_LIFE s unless
## someone winds the other line in.
const TANGLE_LIFE := 20.0
const UNDER := 2.5
const PROP_GRACE := 2.5
const BACK_SPEED := 2.2
const TOW := 0.01
## A beaten fish kept tight is led round off the stern this fast (rad/s, at full pressure).
const LEAD := 0.35
## A rod left in its holder: how much faster he takes line on a run, with nobody on it.
const HOLDER_RUN := 2.0

var kg := 150.0
var nature := "runner"
## Line off the reel (m): from the rod tip to the fish, give or take its stretch. And how fresh he is (1 .. 0).
var line_out := 40.0
var energy := 1.0
## Where it is: its bearing round the boat (radians, 0 dead astern, + to starboard) and its depth (m).
var bearing := 0.0
var depth := 5.0
## The tension at the rod: the bend (0 slack .. 1 parting). (Called strain so rods.gd's plumbing keeps it.)
var strain := 0.0
## The tension at his end (the rod's, and the line he's dragging through the water): what parts it and tears the hook.
var t_fish := 0.0
## How hard he's pulling away right now (x the line's strength), for the rod and the fish's look; and how fast he's
## going away from you (m/s, - coming in).
var pull := 0.0
var speed := 0.0
var move := ""
## The drag lever (0 free .. 1 full) and what it holds right now (x the line's strength, the spool and all).
var drag := STRIKE_DRAG
var drag_now := 0.0
## The helm: -1 backing down hard .. 0 neutral .. 1 ahead (rods.gd sets it from the captain): the props turning.
var throttle := 0.0
## Her velocity (m/s, her own x across and z astern: her bow's -z) when `moving` (rods.gd, from boat/helm.gd): the
## fish stays where it is in the water, so she closes on it backing down or pulls away from it under way. Without
## `moving` (the headless tests), the throttle stands in.
var boat_vel := Vector2.ZERO
var moving := false
## Without `moving` (the headless tests): how fast she closes on him backing down hard (m/s: her kind's "astern").
var back_speed := BACK_SPEED
## The sea throwing her about (m/s a rod tip over her transom is thrown up and forward, - down and aft: rods.gd, x
## how much reaches the line in her, boat/kinds.gd's "lively"): a small boat thrown up a big sea snatches the line
## tight, then drops it.
var heave := 0.0
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
## The rod's in its holder with nobody on it (rods.gd): nobody winds or lifts; the drag as it was set plays him, and on
## his runs he takes line HOLDER_RUN times as fast as he would off a rod someone's on (it just bows to him).
var in_holder := false
## Gear from the dock (boat/fish_hold.gd, rods.gd sets these): a two-speed reel winds faster, heavier line takes more
## rubbing and is a little stronger.
var crank_mul := 1.0
var chafe_mul := 1.0
var grace_add := 0.0
var tangled := false
## The angler's arms, 1 fresh .. 0 gone (rods.gd hands them in when you take the rod and keeps them after).
var arms := 1.0
## How worn the line is from rubbing her hull, 0..1 (1: it parts; past halfway it starts to weaken), and how hard
## it's rubbing right now (0..1).
var wear := 0.0
var chafe := 0.0
## How twisted the line is from winding against the drag (0..1: it weakens it).
var twist := 0.0
## How hard the line's rubbing on her right now from the real line against her real hull (rods.gd: rub_on_hull);
## below 0 (the headless tests), worked out from her outline seen from above instead.
var rub_now := -1.0
var move_t := 0.0
var done := false
var rng := RandomNumberGenerator.new()

## The line's stretch (m; below 0 slack), and a passing jolt (vs/horn.gd's blast through her lines).
var stretch := 0.0
var shock := 0.0
## The drag slipping (the reel screams) and how fast it's paying out (m/s); line wound (m/s); cranking against a
## slipping drag (grinding: gaining nothing, twisting it); cranking at all.
var slipping := false
var paying := 0.0
var wind := 0.0
var grinding := false
var reeling := false
## How long the line's been slack (s), and over its strength (s).
var slack_t := 0.0
var _over_t := 0.0
## How well the hook's holding, 1 .. 0 (gone).
var hold := 1.0
var airborne := false
## His pull coming and going in a lull-y move (1 pulling .. 0 a tired moment), and where it's heading.
var lull := 1.0
var _lull_to := 1.0
var _lull_t := 0.0
## The leader's been up (his last run's been had).
var leader := false
## After it changes hands: nothing lost for this long (s).
var grace := 0.0

var _len := 1.0
var _turn_sign := 1.0
var _turn_v := 0.0
var _dive_v := 0.0
const TURN_EASE := 0.2
const DIVE_EASE := 4.0
var _prop_t := 0.0
var _goal_s := 90.0
var _jit := 0.0
var _thrown_t := 0.0
var _sweep := 0.0
var _going_under := false
var _quiet_t := 0.0
var _pitch_was := NAN
## s left of the strike's first burst.
var _burst := 0.0
## His last run at the leader (once: `leader` stays set through the rod changing hands).
var _last_run := false
## The tension he's been pulling against these last HELD_T s (the hook tears on that; a passing kick parts the line).
var _t_held := 0.0
var _shock_was := 0.0


func _init(weight_kg: float, out: float, fresh := 1.0, seed_value := -1) -> void:
	kg = weight_kg
	line_out = out
	energy = fresh
	if seed_value >= 0:
		rng.seed = seed_value
	nature = nature_of(seed_value, kg)
	_goal_s = GOAL_BASE + GOAL_PER_KG * kg
	_turn_sign = 1.0 if rng.randf() < 0.5 else -1.0
	stretch = drag_at(STRIKE_DRAG) * give()
	strain = drag_at(STRIKE_DRAG)
	if fresh > 0.8:
		_set_move("run")
		# the first run: a blistering one. A schoolie's a few seconds; a giant's takes a good part of the spool.
		_len = rng.randf_range(4.0, 7.0) if kg < 100.0 else rng.randf_range(12.0, 18.0) * (1.0 + minf(kg, 300.0) / 600.0)
		if nature == "runner":
			_len *= 1.3
		_burst = BURST
		speed = v_free() * 0.8
		slipping = true          # (the reel's already screaming: the strike's on the drag)
		paying = speed
	else:
		_set_move(_pick())


## His nature, from the fish's seed and weight: the same fish is the same whoever holds the rod.
static func nature_of(seed_value: int, w: float) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = absi(seed_value) * 7919 + 13
	var x := r.randf()
	if w < 90.0:
		return "jumper" if x < 0.5 else ("runner" if x < 0.8 else "bulldog")
	# (a giant doesn't jump: runner, sounder or bulldog)
	return NATURES[mini(int(x * (3.0 if w >= 200.0 else 4.0)), 3)]


## How hard he can pull (x the line's strength), fresh.
static func strength_of(w: float) -> float:
	return 0.30 + 0.0011 * w


func f_max() -> float:
	return strength_of(kg)


## How fast he swims away with nothing on him (m/s).
func v_free() -> float:
	return 4.5 + minf(kg, 300.0) / 45.0       # (past 300 kg he's no faster, only stronger)


## How strong it is for its weight (the rod's heft): a schoolie barely loads the rod, a giant leans on it.
static func size_of(w: float) -> float:
	return minf(0.35 + w / 285.0, 1.9)


## The line's give (m of stretch for a tension of 1): the rod's bend and every metre of line out.
func give() -> float:
	return ROD_GIVE + STRETCH * line_out


## How much harder the drag holds as the spool empties (1 full .. ~2.5 at the arbor).
func spool_gain() -> float:
	var fill := clampf(1.0 - line_out / CAPACITY, 0.0, 1.0)
	return 1.0 / (0.4 + 0.6 * fill)


## What the lever holds at a full spool (x the line's strength).
static func drag_at(lever: float) -> float:
	return DRAG_MAX * pow(clampf(lever, 0.0, 1.0), 1.4)


## What the line takes before it parts right now: less, worn or twisted.
func strength() -> float:
	return (STRENGTH + 0.06 * grace_add) * (1.0 - WORN_K * smoothstep(0.4, 1.0, wear)) * (1.0 - TWIST_K * twist)


## How hard he pulls away right now (x the line's strength): his move, his strength, how fresh, his tired moments,
## the tail beating, the kick of him taking off.
func _thrust() -> float:
	var m: Dictionary = MOVES[move]
	var k := float(m["k"])
	if nature == "bulldog" and move in ["dog", "shake"]:
		k *= 1.15
	var vigor := 0.15 + 0.85 * energy
	if move == "surge":
		vigor = 0.35 + 0.65 * energy     # (a sudden surge has something left in it, even tired)
		if _last_run:
			vigor = maxf(vigor, 0.75)    # (and his last run at the leader has everything he's got left)
	var f := f_max() * k * vigor * (1.0 + 0.35 * clampf(_burst / BURST, 0.0, 1.0))
	if move in ["run", "surge"]:
		f *= 1.0 + KICK * maxf(1.0 - move_t / KICK_T, 0.0)      # (the first strokes of his tail: a kick)
	if bool(m["lull"]):
		f *= lerpf(0.3, 1.0, lull)
	if move == "shake":
		f *= 0.7 + 0.5 * sin(move_t * TAU * 1.6)
	if move == "spiral":
		f *= 0.4 if not _going_under else 1.2       # (coming up toward you he's light; going down under her he leans)
	return maxf(f * (1.0 + 0.06 * _jit), 0.0)


## One tick of the fight.
func step(dt: float, crank: float, rod_pitch: float, _side: float, drag_set: float) -> void:
	if done or dt <= 0.0:
		return
	drag = clampf(drag_set, 0.0, 1.0)
	if in_holder:
		crank = 0.0
		rod_pitch = 0.6
	if is_nan(_pitch_was):
		_pitch_was = rod_pitch
	var dpitch := rod_pitch - _pitch_was
	_pitch_was = rod_pitch
	reeling = crank > 0.1
	_tire_arms(dt, crank, dpitch)
	grace = maxf(grace - dt, 0.0)
	move_t += dt
	_quiet_t = 0.0 if move in ["run", "surge"] else _quiet_t + dt
	if move_t >= _len:
		_next_move()
	var m: Dictionary = MOVES[move]
	_jit += (rng.randf_range(-1.0, 1.0) - _jit) * minf(1.0, 1.5 * dt)
	_lulls(dt)
	airborne = move == "jump" and move_t >= 0.5 and move_t < 1.2
	if move == "jump":
		depth = move_toward(depth, 0.0, 12.0 * dt) if move_t < 0.5 else 0.0
		if airborne:
			_thrown_t = 1.0
	_thrown_t = maxf(_thrown_t - dt, 0.0) if not airborne else _thrown_t
	var f := _thrust()
	pull = f

	# him: away at his pace against what the line's putting on him; the line harder than he's pulling and he comes
	# (as square on him as you are)
	var fm := f_max()
	var want := 0.0
	var sp := float(m["sp"])
	if sp < 0.0:
		want = sp * v_free()                 # (coming at the boat, whatever's on him)
	elif t_fish < f:
		var lulled := lerpf(0.2, 1.0, lull) if bool(m["lull"]) else 1.0
		want = sp * v_free() * sqrt(clampf((f - t_fish) / maxf(f, 0.01), 0.0, 1.0)) * lulled
	else:
		var square := angle_k()
		want = -V_PULL * sqrt(clampf((t_fish - f) / fm, 0.0, 1.0)) * lerpf(0.05, 1.0, square * square) \
				* (1.25 - 0.5 * clampf(kg / 400.0, 0.0, 1.0))
	var resp := (5.0 if move == "surge" else 2.5) * (1.3 - 0.5 * clampf(kg / 400.0, 0.0, 1.0))
	if move in ["run", "surge"] and move_t < KICK_T:
		resp *= 2.0
		want = sp * v_free() * 1.3          # (his first strokes: he's going, whatever's on the line)
	if in_holder and want > 0.0 and move in ["run", "surge"]:
		# (nobody on the rod: nobody to lean back on him, ease the rod over or thumb the spool, the rod just bows to
		# him and the drag renders; on a run he takes line HOLDER_RUN times as fast)
		want *= HOLDER_RUN
	if _burst > 0.0:
		want *= 1.0 + 0.5 * _burst / BURST
		_burst = maxf(_burst - dt, 0.0)
	if airborne:
		want = 0.6 * sp * v_free()          # (up in the air, his weight and his head shaking on the line)
	speed += (want - speed) * minf(1.0, resp * dt)

	# the boat: closing on him backing down, pulling away from him under way
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
		boat_close = back_speed * back - 1.5 * maxf(throttle, 0.0)

	# the line: his going stretches it, her closing slackens it, lifting the rod stretches it, winding takes line in
	var pw := power()
	var lift := ROD_LEVER * dpitch * (lerpf(SPENT_LIFT, 1.0, pw) if dpitch > 0.0 else 1.0)
	stretch += (speed - boat_close + heave) * dt + lift
	var tens := maxf(stretch, 0.0) / give()
	wind = WIN * crank_mul * crank * lerpf(SPENT_WIN, 1.0, pw) * clampf(1.0 - tens / CRANK_MAX, 0.0, 1.0)
	if stretch < 0.0:
		wind = WIN * crank_mul * crank * lerpf(SPENT_WIN, 1.0, pw)      # (slack: it spins)
	var taken := minf(wind * dt, maxf(line_out - BOATSIDE + 1.0, 0.0))
	line_out -= taken
	stretch += taken
	# a jolt (the other boat's horn through her lines): a snatch on the line, once, then it dies away
	if shock > _shock_was:
		stretch += (shock - _shock_was) * give()
	shock = move_toward(shock, 0.0, dt * 0.5)
	_shock_was = shock

	# the drag: past what it holds, the spool slips and pays out, spinning up as hard as the line's over it
	drag_now = drag_at(drag) * spool_gain()
	# (it sticks harder before it starts slipping, and a short line has no stretch in it to ease the kick of him)
	var holds := drag_now * ((STATIC + SHORT_STATIC * clampf(1.0 - line_out / 50.0, 0.0, 1.0)) if not slipping else 1.0)
	tens = maxf(stretch, 0.0) / give()
	var pay := 0.0
	if tens > holds or slipping:
		pay = maxf((paying if slipping else 0.0) + SPOOL_ACC * (tens - drag_now) * give() * dt, 0.0)
		pay = minf(pay, maxf(stretch, 0.0) / dt)
	if drag <= 0.001:
		pay = maxf(stretch, 0.0) / dt        # (free spool: it pays out as fast as he takes it)
	slipping = pay > 0.0
	paying = pay
	line_out += pay * dt
	stretch -= pay * dt
	grinding = reeling and slipping
	strain = maxf(stretch, 0.0) / give()
	var belly := BELLY * (line_out / CAPACITY) * pow(clampf(maxf(speed, 0.0) / v_free(), 0.0, 1.2), 2.0)
	t_fish = strain + belly if strain > 0.0 else 0.0
	# (a slack line drifts in the water: it doesn't pile up past a few metres of belly)
	stretch = maxf(stretch, -maxf(8.0, line_out * 0.25))

	# where it is: swinging round the boat, heading for its depth
	var hd0 := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	var hd := maxf(hd0, 1.0)
	var turn := float(m["turn"])
	if move == "circle" and kg < 60.0:
		turn *= 1.6
	if move != "spiral":
		turn *= 0.35 + 0.65 * energy
	var was_b := bearing
	_turn_v = move_toward(_turn_v, turn * _turn_sign, TURN_EASE * dt)
	bearing += _turn_v * dt * clampf(25.0 / hd, 0.3, 0.7 if move == "spiral" else 1.2)
	if move == "charge":
		var wb := wrapf(bearing, -PI, PI)
		bearing += (signf(wb) if absf(wb) > 0.05 else _turn_sign) * CHARGE_TURN * dt
		if b_now() > UNDER + 0.15:
			_next_move()
	var c := cos(bearing)
	if move == "spiral":
		# (the lap: half of it he's going away down under her, half coming up toward you)
		_going_under = sin(move_t * 0.9) > 0.0
	elif c < -0.1:
		_going_under = true
	elif c > 0.1:
		_going_under = false
	bearing -= sin(wrapf(bearing, -PI, PI)) * TOW * clampf(strain, 0.0, 1.0) * dt
	if move == "spiral" or (energy < BEATEN and line_out < SPIRAL_IN):
		# (beaten, he goes where he's led: kept tight, his laps come round off the stern; left slack, they wander
		# under her)
		bearing -= sin(wrapf(bearing, -PI, PI)) * LEAD * clampf(strain / 0.2, 0.0, 1.0) * angle_k() * dt
	_sweep = lerpf(_sweep, (bearing - was_b) / dt, minf(1.0, 4.0 * dt))
	var goal_d := minf(float(m["depth"]) * (1.4 if nature == "sounder" and move == "sound" else 1.0), line_out * 0.85)
	if move == "spiral":
		goal_d = line_out * (0.85 if _going_under else 0.6) if line_out > 12.0 else 3.0
	elif energy < BEATEN and line_out < SPIRAL_IN:
		goal_d = minf(goal_d, 3.0)
	if move != "jump":
		_dive_v = move_toward(_dive_v, clampf((goal_d - depth) * 0.9, -6.0, 6.0), DIVE_EASE * dt)
		depth = maxf(depth + _dive_v * dt, 0.0)
	else:
		_dive_v = 0.0

	# the leader at the rod tip: the moment, and his last run at it
	if not leader and line_out < LEADER:
		leader = true
		leader_up.emit()
		_set_move("surge")
		_len = rng.randf_range(2.5, 4.0)
		_last_run = true

	# losing him (not in the moment after the rod changes hands)
	if grace <= 0.0:
		if _lose(dt):
			return
	else:
		slack_t = 0.0
		_over_t = 0.0

	# the boat: where the line lies on her it rubs; under her with the props turning it's cut
	if rub_now >= 0.0:
		chafe = rub_now
	else:
		chafe = rub(_tip(hd0), _fish(hd0), half_beam, house, fore) * hd0 / (hd0 + depth + 1.0)
		if move == "spiral":
			chafe *= 0.5
	chafe = maxf(chafe, side_rub())
	var beaten := energy < BEATEN
	wear += chafe * (0.4 + 0.6 * clampf(strain, 0.0, 1.0)) * dt / (CHAFE_LIFE * chafe_mul) * (0.4 if beaten else 1.0)
	if grinding:
		twist = minf(twist + TWIST_RATE * crank * dt, 1.0)
	if tangled:
		wear += dt / (TANGLE_LIFE * chafe_mul)
	if wear >= 1.0:
		_end("tangle" if tangled and chafe < 0.05 else "chafed")
		return
	var b := b_now()
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

	# tiring: working against the line (harder the more tension, more running against the drag), square on him;
	# left be, he gets his breath back
	var work := clampf(t_fish / (PRESSURE * fm), 0.0, 2.2) * (1.0 + (0.5 if slipping else 0.0))
	if t_fish > EASY * fm:
		energy -= dt / _goal_s * work * lerpf(0.45, 1.0, angle_k())
	elif not beaten:
		energy += RECOVER * dt / _goal_s
	energy = clampf(energy, 0.0, 1.0)

	if energy < 0.2 and line_out <= BOATSIDE:
		done = true
		boatside.emit()


## The ways he gets off: true if he's gone.
func _lose(dt: float) -> bool:
	var s := strength()
	# the line: over what it takes a moment and it parts (a jolt well past, at once)
	_over_t = _over_t + dt if t_fish > s else maxf(_over_t - 2.0 * dt, 0.0)
	if _over_t >= PART_T or t_fish > s * 1.15:
		_end("thrown" if _thrown_t > 0.0 else ("broke_rail" if wear > 0.5 else ("twisted" if twist > 0.4
				else "broke")))
		return true
	# the hook: torn by too much held too long; thrown tight on a jump; worked loose by his head shaking
	var was := hold
	_t_held = lerpf(_t_held, t_fish, minf(1.0, dt / HELD_T))
	if _t_held > HOOK_T:
		hold -= (_t_held - HOOK_T) * HOOK_TEAR * dt
	if move == "shake" and t_fish > 0.0:
		hold -= SHAKE_TEAR * clampf(t_fish / 0.3, 0.0, 2.5) * dt      # (each shake of his head on a tight line works it)
	if airborne and t_fish > JUMP_T:
		hold -= (t_fish - JUMP_T) * JUMP_TEAR * dt
	var slack := stretch < -0.3
	slack_t = slack_t + dt if slack else maxf(slack_t - 2.0 * dt, 0.0)
	if slack:
		hold -= SLACK_LOOSE * dt * (SHAKE_LOOSE if move == "shake" else 1.0) * (0.5 if energy < BEATEN else 1.0)
	if hold <= 0.0:
		hold = 0.0
		# (what took the last of it: thrown in the air, worked loose on a slack line, or torn out by the tension)
		_end("thrown" if _thrown_t > 0.0 and airborne else ("shaken" if slack and was > 0.0 else "pulled"))
		return true
	return false


## His tired moments: in a lull-y move his pull comes and goes, a second or three at a time.
func _lulls(dt: float) -> void:
	_lull_t -= dt
	if _lull_t <= 0.0:
		_lull_t = rng.randf_range(1.2, 2.8)
		_lull_to = 0.0 if rng.randf() < 0.4 else 1.0
	lull = move_toward(lull, _lull_to, 2.5 * dt)


## Your arms, a tick on: winding against a load, lifting a loaded rod and just holding a heavy fish drain them (more
## on a big fish); hands off with the line easy they come back, fast with the rod in its holder.
func _tire_arms(dt: float, crank: float, dpitch: float) -> void:
	var heft := 0.4 + 0.6 * size_of(kg)
	var t := clampf(strain, 0.0, 1.2)
	var use := crank * (0.25 + 1.4 * t) * heft + maxf(dpitch / maxf(dt, 1e-4), 0.0) * t * 1.6 + 0.35 * t * heft
	if in_holder:
		arms += dt / ARM_HOLDER
	elif crank > 0.05 or dpitch > 0.0 or t > 0.3:
		arms -= use * dt / ARM_LIFE
	else:
		arms += (0.3 - t) * 3.0 * dt / ARM_REST
	arms = clampf(arms, 0.0, 1.0)


## How much your arms have left to give, 0 (spent) .. 1: all of it down to TIRED, falling away to nothing below it.
func power() -> float:
	return smoothstep(0.0, TIRED, arms)


## Forward of her beam the line from the stern lies along her side, whatever the ray-cast makes of it: 0 abeam,
## SIDE_RUB by the time he's well forward of it (the plotter's red arc), less for a deep fish.
func side_rub() -> float:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	return SIDE_RUB * smoothstep(SIDE_FROM, SIDE_FROM + 0.55, b_now()) * hd / (hd + depth * 0.5 + 1.0)


## How square on him you are, 1 .. 0: dead astern (inside SQUARE either side) everything you put on him moves him;
## off to the side less; abeam next to nothing; past WIDE, round toward her bow or under her, none. A deep fish with
## the line going down steep spares you some of it.
func angle_k() -> float:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	var k := 1.0 - smoothstep(SQUARE, WIDE, b_now())
	return lerpf(k, 1.0, STEEP * depth / (hd + depth + 1.0))


## How long it's been under her with the props turning (s): PROP_GRACE and it's cut.
func prop_t() -> float:
	return _prop_t


## What the rod, the reel and the line are doing: all you get to read (and all the test anglers read). The hook's
## hold isn't on it: you can't see that, only feel what tears it.
func cues() -> Dictionary:
	var hd := sqrt(maxf(line_out * line_out - depth * depth, 0.0))
	return {"bend": strain, "tension": strain, "slipping": slipping, "paying": paying, "grinding": grinding,
			"airborne": airborne, "jumping": move == "jump", "charging": move == "charge", "thrash": move == "shake",
			"slack": stretch < -0.3, "slack_t": slack_t, "line_pitch": -atan2(depth + TIP_H, maxf(hd, 0.5)),
			"sweep": _sweep, "spool": line_out / CAPACITY, "contact": chafe, "line_out": line_out,
			"visible": (line_out < 30.0 and depth < 10.0) or airborne, "drag": drag, "drag_now": drag_now,
			"bearing": bearing, "angle": angle_k(), "arms": arms, "tangled": tangled, "holder": in_holder,
			"props": _prop_t, "leader": line_out < LEADER, "surging": move in ["surge", "run"] and move_t < 1.0,
			"under": b_now() > UNDER - 0.3}


## The bend, for whoever wants one number.
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
	if energy < BEATEN and line_out <= SPIRAL_IN:
		# beaten, close in: round and round under her, and now and then a sudden surge
		var r := rng.randf()
		_set_move("surge" if r < 0.12 and move != "surge" else ("spiral" if r < 0.85 else "shake"))
	elif energy < BEATEN:
		# beaten but still well off: no more runs, he circles deep, slow and wide
		_set_move("dog" if move == "circle" and rng.randf() < 0.4 else "circle")
	else:
		_set_move(_pick())


func _pick() -> String:
	# fresh, he runs and sounds; as he tires he circles. Never two runs in a row; small fish and jumpers jump near the
	# top. Fresh and held in close, he's off again; and he never sulks long while he's got fight in him.
	if energy > 0.3 and _quiet_t > QUIET and move not in ["run", "surge"]:
		return "run" if rng.randf() < 0.65 else "surge"
	var close := 3.0 if line_out < CLOSE and energy > 0.35 else 0.0
	var jumper := nature == "jumper"
	var w := {"run": 0.0 if move == "run" else (2.0 * energy * (2.0 if nature == "runner" else 1.0) + close),
			"sound": 2.5 * (2.5 if nature == "sounder" else 1.0) if energy > 0.3 else 0.5,
			"dog": 1.2 * (2.5 if nature == "bulldog" else 1.0),
			"shake": 1.0 * (2.0 if nature == "bulldog" else 1.0) * (2.0 if kg < 60.0 else 1.0),
			"circle": 2.5 * (1.0 - energy), "surge": 0.6 + close * 0.6,
			"jump": ((2.4 if jumper else 0.0) + (1.0 if kg < 60.0 else 0.0)) if depth < 25.0 and kg < 250.0 else 0.0,
			"charge": 0.8 * energy if energy > 0.35 and move != "charge" and line_out < 150.0 else 0.0}
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
## it was doing, the same way round, the line stretched as it was and the hook as worked as it was. A moment's grace
## to get your hands on it. `burst`: s left of the strike's first burst (a fight picked up as he's hooked).
func carry_on(m: String, stretch_was := 0.0, turn := 0.0, hold_was := 1.0, burst := 0.0) -> void:
	if m == "rest":
		m = "dog"
	if MOVES.has(m) and m != move:
		_set_move(m)
	stretch = stretch_was
	strain = maxf(stretch, 0.0) / give()
	t_fish = strain
	_t_held = strain
	hold = hold_was
	if turn != 0.0:
		_turn_sign = signf(turn)
	_turn_v = float(MOVES[move]["turn"]) * _turn_sign
	_going_under = cos(bearing) < 0.0
	_pitch_was = NAN
	slipping = false
	paying = 0.0
	speed = 0.0
	leader = leader or line_out < LEADER
	_burst = burst
	if burst > 0.0:
		slipping = true
		paying = v_free()
		speed = v_free()
	grace = 1.0


## In the spiral: whether it's on the half of the lap that takes it down under her (hold) rather than coming up
## toward you (wind).
func going_under() -> bool:
	return _going_under


## Which way round it's swinging (+1 or -1), for carry_on when the rod changes hands.
func turn_sign() -> float:
	return _turn_sign


func _set_move(m: String) -> void:
	var again := m == move
	_last_run = false
	move = m
	move_t = 0.0
	var d: Array = MOVES[m]["dur"]
	_len = rng.randf_range(float(d[0]), float(d[1])) * (1.0 if m == "jump" else 0.6 + 0.4 * energy)
	if m == "run" and nature == "runner":
		_len *= 1.25
	if m == "sound" and nature == "sounder":
		_len *= 1.3
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
