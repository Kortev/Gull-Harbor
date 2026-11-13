extends RefCounted
## One minigame of the arcade fight (docs/FIGHT_ARCADE.md): a few seconds on two buttons, its rules and its drawing
## in one small file. tuna/fight_arcade.gd runs them back to back and turns what each says it's doing to the fish
## into line, tiring, hook and wear; ui/fight_arcade_hud.gd gives each the stage to draw on. A new one is a new file
## here that extends this, and one line in all.gd.
##
## What to write (see spool.gd for a short example, ride.gd for a held one):
## - `_init()`: who you are: `id`, `title` (two or three words over the stage), `moves` (the fish's moves you can
##   stand for: run, surge, sound, dog, shake, circle, spiral, jump, charge; [] for any), `from` (how far through the
##   fight, 0..1, before you may appear), `only` (you come up exactly when he does one of `moves`: the jump), `boss`
##   (you're only ever a stage's last game), `can_boss` (an ordinary game that can also be one), `length` (s, 3-7),
##   `hitstop` (off if you keep time with the music: a perfect's hit-stop would put you out of step).
## - `_begin()`: set up a round from `tier` (0 easy .. 1 hard), `rng` (use nothing else random: the same seed must
##   play the same game), and the variant flags `mirror`, `fast` (1 or more: x speed), `twist` (your own extra rule),
##   `big` (a boss: make it longer), `beat` and `to_beat` (the music's beat, s, and s to its next one).
## - `_step(dt, a, b, a_hit, b_hit)`: the rules. Every frame say what's being done to the fish, all normalised:
##   `gain` (-1 he's taking line as he likes .. 0 holding him .. 1 you're winning it), `tire` (0..1 how hard he's being
##   worked), `hook` (0..1 the hook being torn, a second), `fray` (0..1 the line being hurt), `tension` (0..1: the rod's
##   bend; over 0.9 reads as danger), `pose` (0..1: the rod low .. high). For one-off things call `_hit(q)` (2 perfect,
##   1 good), `_miss()`, `_near()`; add to `_pts` and `_max` (`score` is their ratio) or set `score` yourself; set
##   `done` when it's over (or let `length` run out). Nothing is judged before `lead` s: give hands time to arrive.
## - `cue()`: what each button's asked to do right now, [A, B] of Kit.NONE / HOLD / TAP / MASH / RELEASE / OFF: the
##   HUD's button glyphs act it out, so nobody has to read a rule.
## - `hint()`: what a perfect player holds down right now, {a, b} (tests only: tests/fight_arcade_bot.gd).
## - `draw(ci, rect, kit, time)`: draw yourself in `rect` from your own state with the kit, as a ship's instrument:
##   read DRAWING A GAME at the top of ui/kit.gd first, and copy ride.gd, beats.gd, spool.gd or lanes.gd. Three inks
##   (Kit.PAPER, Kit.YELLOW reward, Kit.ORANGE danger and the fish), scales, brackets and hatching, small solid markers.

const Kit := preload("res://ui/kit.gd")

## --- what it is
var id := ""
var title := ""
var moves: Array = []
var from := 0.0
var only := false
var boss := false
var can_boss := false
var length := 5.0
## Nothing's judged before this (s).
var lead := 0.7
## A perfect may hold the fight a beat (ui/juice.gd's hit-stop). Off for games in time with the music.
var hitstop := true

## --- this round
var tier := 0.0
var rng: RandomNumberGenerator
var variant := {}
var mirror := false
var fast := 1.0
var twist := false
var big := false
var beat := 0.5357
var to_beat := 0.0
var t := 0.0
var done := false
var score := 0.0

## --- what it's doing to the fish this frame
var gain := 0.0
var tire := 0.0
var hook := 0.0
var fray := 0.0
var tension := 0.3
var pose := 0.4
## He's out of the water; he's coming up to the top; he's about to leave it (the jump).
var air := false
var surface := false
var leap := false
## A belly of slack in the line, 0..1 (the charge).
var slack := 0.0
## One-offs, taken by the fight: perfect hits' worth of a little extra, and hurts to the hook.
var burst := 0.0
var hurt := 0.0
## Raised this frame, for the juice: ["hit", 1 or 2], ["miss"], ["near"], and a game's own.
var events: Array = []

var _pts := 0.0
var _max := 0.0
## For games of single moments: jumps to 1 on a hit and -1 on a miss, easing back toward `_rest`; gain follows it.
var mood := 0.0
var _rest := -0.25
var _a_was := false
var _b_was := false


## What to do, in a line, for someone who's never seen the game ({A}, {B}: the two buttons, named by the HUD for
## the mouse or the pad). The HUD says it big as each game starts.
const HOW := {
	"ride": "HOLD {B} TO RAISE THE MARKER, LET GO TO DROP IT: KEEP IT IN THE YELLOW",
	"beats": "TAP {B} AS EACH MARK CROSSES THE RING",
	"jump": "LET GO OF BOTH WHILE HE'S IN THE AIR, THEN TAP {A} AS HE LANDS",
	"pump": "HOLD {B} TO LIFT INTO THE YELLOW, THEN HOLD {A} TO WIND DOWN",
	"dog": "HOLD {B} TO LIFT, THEN {A} TO WIND. LET GO OF {B} WHEN IT FLARES",
	"charge": "HAMMER {A}: WIND IN THE SLACK",
	"laps": "HOLD {A} ON THE YELLOW HALF, HOLD {B} ON THE ORANGE HALF",
	"spool": "TAP {A} TO STOP THE MARK ON THE YELLOW",
	"mimic": "WATCH HIM, THEN REPEAT IT: {A} IS LEFT, {B} IS RIGHT",
	"lanes": "TAP {A} FOR THE LEFT LANE, {B} FOR THE RIGHT, AS EACH NOTE LANDS",
	"heave": "HOLD {B} TO WIND UP, LET GO IN THE YELLOW",
	"duel": "WAIT... TAP {A} THE MOMENT HE TURNS. NOT BEFORE",
	"steady": "TAP {A} TO KNOCK IT LEFT, {B} RIGHT: KEEP IT IN THE MIDDLE",
	"tug": "{A}, {B}, {A}, {B}: HAND OVER HAND, FAST",
	"twohands": "{B}: HOLD TO KEEP THE MARKER IN THE YELLOW. {A}: TAP AS MARKS CROSS THE RING",
	"pull": "TAP EITHER BUTTON",
	"clear": "{A}, {B}, {A}, {B}: WORK THE LINE OFF HER",
}


func how() -> String:
	return str(HOW.get(id, ""))


func begin(tier_now: float, r: RandomNumberGenerator, v := {}) -> void:
	tier = clampf(tier_now, 0.0, 1.0)
	rng = r
	variant = v
	mirror = bool(v.get("mirror", false))
	fast = float(v.get("fast", 1.0))
	twist = bool(v.get("twist", false))
	big = bool(v.get("boss", false))
	beat = float(v.get("beat", 0.5357))
	to_beat = float(v.get("to_beat", 0.0))
	t = 0.0
	done = false
	score = 0.0
	_pts = 0.0
	_max = 0.0
	mood = 0.0
	events = []
	_begin()


func step(dt: float, a: bool, b: bool, a_hit: bool, b_hit: bool) -> void:
	events = []
	if done:
		return
	t += dt
	mood = move_toward(mood, _rest, 0.8 * dt)
	hook = 0.0
	fray = 0.0
	_step(dt, a, b, a_hit, b_hit)
	if _max > 0.0:
		score = clampf(_pts / _max, 0.0, 1.0)
	if t >= length:
		done = true


## Is anything being judged yet?
func live() -> bool:
	return t >= lead


func _begin() -> void:
	pass


func _step(_dt: float, _a: bool, _b: bool, _a_hit: bool, _b_hit: bool) -> void:
	pass


func cue() -> Array:
	return [Kit.NONE, Kit.NONE]


func hint() -> Dictionary:
	return {"a": false, "b": false}


func draw(_ci: CanvasItem, _rect: Rect2, _kit: Kit, _time: float) -> void:
	pass


## A good moment: 2 perfect, 1 good.
func _hit(q: int) -> void:
	events.append(["hit", q])
	mood = 1.0
	if q >= 2:
		burst += 1.0


## A bad one: it works the hook.
func _miss(hurts := 1.0) -> void:
	events.append(["miss"])
	mood = -1.0
	hurt += hurts


## Nearly: nothing lost but the moment.
func _near() -> void:
	events.append(["near"])


## The stage's scale: a rect 100 tall is 1.
static func unit(rect: Rect2) -> float:
	return rect.size.y / 100.0
