extends RefCounted
## What the music wants now, worked out from a plain picture of the game (audio/music.gd reads the sea into one each
## frame: world(); the tests hand it their own). No nodes, no sound: section, stem levels and events, all testable
## headless. docs/MUSIC_SYSTEM.md is the design.
##
## After the title it's one song (tools/music.py's sea(): eight-bar passages, every layer on every one), and nothing
## here changes the song: what's happening (the section: sea, harbour, hunt, fight, tired, leader, gaff, afterglow,
## race) is only which of its layers are up, and how bright a passage to play next; what happens (the events) is a
## cue the band plays over it on the beat.
##
## It only hears what you could: the rod's bend against what the line will take, the spool, the line on her, his moves.
## Never the hook's hold or how tired he is: the music never tells you what you couldn't feel.
##
## The world, every key optional:
##   title, card, docked, paused, underwater: bool
##   counting: s into Rivals' countdown (-1: not counting); card_result: "win"/"lose"/"tie" once the stamp's down
##   race_left: s left in the race home (-1: no race on); standing: 1 ahead, -1 behind, 0 level/none (Rivals)
##   lbs: [yours, theirs] (Rivals, out there); their_on: how many fish they've got on
##   condition: the weather (sea.gd's CONDITIONS); night: bool; day: day fraction (0 dawn .. 1 dusk)
##   birds: 0..1, how near feeding birds are (1 right there); speed: 0..1 of her top speed ahead
##   flash: the lightning's (sea/sea_fx.gd: 1 as it strikes); past_mouth: m she's out past the harbour mouth
##   fights: [{id, kg, tension (bend / what the line takes), spool (0..1 of the reel gone), depth, line_out, move,
##            slack, airborne, surging, contact (0..1 of the line worn on her), props (s under her props), tangled}]
##   alongside: [ids up alongside]; draw: the harpoon's wind-up 0..1; flying: the harpoon's in the air
##   landed: fish aboard (it going up: one landed)

const Cues := preload("res://audio/music_cues.gd")

const FIGHT := ["fight", "tired", "leader"]
const FRESH_MOVES := ["run", "sound", "dog", "jump"]
const TIRED_MOVES := ["circle", "spiral"]
## The leader's up at the rod tip under this much line (tuna/fight.gd's LEADER); it stays the leader till he's taken
## this much back out.
const LEADER := 16.0
const LEADER_OUT := 40.0
## A fight section holds at least this long (s: two bars at 112) before it changes (the leader doesn't wait).
const SECTION_HOLD := 4.3
## The bend against what the line takes (tuna/fight.gd: the drag holds at most DRAG_MAX 0.55 of it, past HOOK_T 0.5
## the hook tears; a played fish sits round 0.1, a heavy moment 0.3): the rod loaded (the tension stem coming in),
## and near going (danger).
const LOADED := Vector2(0.18, 0.4)
const NEAR := Vector2(0.4, 0.6)
## The line about to part: danger past PARTING, over till it's back under PARTED.
const PARTING := 0.85
const PARTED := 0.72
## The fast masks (him in the air, the line about to part, the harpoon flying): down over MASK_DOWN s, back over
## MASK_UP s: quick, but the band's hands, never a switch; and how far down him in the air takes it (a share).
const MASK_DOWN := 0.25
const MASK_UP := 0.5
const AIR := 0.25
## Each stem: [attack s (0 to full), release s (full to 0), hold s (once up, it stays at least this long)].
const SMOOTH := {
	"pad": [3.0, 4.0, 0.0], "bass": [2.0, 4.0, 0.0], "pick": [2.5, 3.0, 0.0], "lead": [2.5, 3.0, 4.3],
	"alt": [2.5, 3.0, 4.3],
	"high": [1.0, 4.0, 8.6], "rain": [4.0, 5.0, 0.0], "storm": [4.0, 6.0, 0.0], "night": [5.0, 5.0, 0.0],
	"run": [2.0, 4.0, 4.3], "fill": [0.01, 0.01, 0.0], "pulse": [1.5, 3.0, 0.0], "glint": [2.0, 4.0, 0.0],
	"beat": [0.2, 0.3, 0.0], "drive": [0.25, 3.0, 4.3], "tension": [0.5, 2.5, 4.3], "deep": [1.5, 4.0, 4.3],
	"heavy": [2.0, 4.0, 0.0], "gale": [4.0, 6.0, 0.0], "pound": [0.25, 3.0, 4.3], "main": [0.01, 0.01, 0.0],
	"counter": [2.0, 3.0, 0.0], "guitar": [2.0, 3.0, 0.0],
	"drums": [2.0, 3.0, 0.0], "low": [3.0, 3.0, 0.0],
}
const SMOOTH_ELSE := [1.0, 2.0, 0.0]
## The sea's stems by mood (an endless song: the pad and the bass always, the guitar and the lead in fair weather, the
## rain's patter, the storm's drums and drone, the night's bells), and how bright a passage it leans to (0 dark .. 1
## bright: audio/music.gd picks each next one by it).
const SEA := {
	"calm": {"pad": 0.8, "bass": 0.7, "pick": 1.0, "lead": 0.9},
	"fog": {"pad": 1.0, "bass": 0.35, "pick": 0.7, "lead": 0.6, "night": 0.3},
	"rain": {"pad": 0.8, "bass": 0.8, "pick": 0.6, "lead": 0.35, "rain": 1.0},
	"storm": {"pad": 1.0, "bass": 1.0, "rain": 0.6, "storm": 1.0, "gale": 1.0, "lead": 0.45, "tension": 0.3,
			"deep": 0.4, "pound": 0.35},
	"night": {"pad": 0.75, "bass": 0.45, "pick": 0.8, "lead": 0.7, "night": 1.0},
}
const SEA_STEMS := ["pad", "bass", "pick", "lead", "alt", "high", "rain", "storm", "night", "run", "fill", "pulse",
		"glint",
		"beat", "drive", "tension", "deep", "heavy", "gale", "pound"]
## The song's layers that are the weather's (the rest are what's happening).
const WEATHER := ["rain", "storm", "night", "gale"]
## How bright a passage each section leans to (0 dark .. 1 bright; -1: the weather's own), and the theme's halves
## asked for at the leader and for landing him (audio/music.gd jumps to sea_t1 on the bar).
const SECTION_BRIGHT := {"fight": 0.1, "tired": 0.4, "gaff": 0.3, "race": 0.6, "afterglow": 1.0}
## Under way: the sea's run stem (and the bass with it) from this share of her top speed to that.
const RUN := Vector2(0.25, 0.8)
## A fish this heavy (kg) to that: the fight's heavy stem in (a giant's weight, felt on the rod).
const HEAVY := Vector2(120.0, 320.0)
const BRIGHT := {"calm": 0.75, "fog": 0.35, "rain": 0.3, "storm": 0.0, "night": 0.35}
## Dusk: past this far through the day the sea leans darker (to half as bright by its end).
const DUSK := 0.75
## Landed: the song lifted (the afterglow) this long (s: eight bars at 112).
const AFTER := 17.1
## How hard the band plays for what's happening (heat), up quickly, down slowly (s).
const HEAT := {"fight": 1.0, "tired": 0.9, "leader": 1.0, "gaff": 0.7, "afterglow": 0.6, "hunt": 0.15}
const HEAT_UP := 0.8
const HEAT_DOWN := 6.0
## The fight builds the longer it goes (s since the strike): the drums never right down after BUILD_DRIVE, the drum
## section in after BUILD_POUND, the tension never off after BUILD_TENSION; while he sounds deep it backs off (and his
## next run hits all the harder).
const BUILD_DRIVE := Vector2(20.0, 40.0)
const BUILD_POUND := Vector2(60.0, 120.0)
const BUILD_TENSION := Vector2(90.0, 150.0)
## The scenic silences: casting off, the band lets the song go and you sail out to the sea and the harbour alone, till
## she's SCENIC_PAST m out past the harbour mouth (or SCENIC_OUT s), and the song comes back in on the theme; and on
## a long quiet stretch at sea in fair weather (SCENIC_EVERY s, between, of nothing happening), the band rests for
## SCENIC_REST s. Never in a storm (the storm's music is its own weather); birds or a fish break it at once.
const SCENIC_PAST := 150.0
const SCENIC_OUT := 90.0
const SCENIC_EVERY := Vector2(180.0, 300.0)
const SCENIC_REST := 20.0
const SCENIC_MOODS := ["calm", "fog", "night"]
## A fish lost: dead silence this long (s), then the sea again.
const HUSH := 6.0
## A fish gone from alongside: this long to see it in the hold (landed) before it counts as got away.
const LANDED_WAIT := 1.2
## Birds: in at this near, out under this; once in, the hunt holds at least this long (s: four bars at 112), so birds
## at the edge of sight don't flicker it.
const HUNT_HOLD := 8.6
const BIRDS_IN := 0.12
const BIRDS_OUT := 0.05
## The race home's length (s: sea.gd's and vs.gd's HOME), and the last chance (s left, trailing).
const HOME := 360.0
const LAST := 90.0
## Lead changes: no more than one sting in this long (s).
const LEAD_GAP := 30.0

## The section wanted ("sea", "title", "harbour", "hunt", "fight", "tired", "leader", "gaff", "afterglow", "race",
## or "rest": quiet, only under Rivals' countdown and card, and the hush after a fish is lost).
var section := "sea"
## Each of its stems' level now (0..1), smoothed; and the fast mask over the fight's (the jump, the line parting).
var gains := {}
var masks := {}
## What happened this step: "strike", "lost", "landed", "leader", "boatside", "birds" (first working near), "away"
## (cast off), "race" (the race home called), "home" (made it), "their_on", "lead_up", "lead_down", "countdown",
## "card:win" (lose, tie), "dawn", "lightning" (a strike in a storm), "scenic" (the band lets the song go), "return"
## (it comes back in on the bar, with a lead-in), "return_theme" (on the theme: out of the harbour), "wake" (broken at
## once: birds, a fish, the storm).
var events: Array[String] = []
## The mood at sea, and the worst fight's danger (0..1) and its id ("" none).
var mood := "calm"
var danger := 0.0
var fight_id := ""
var parting := false
## Meant to be all but silent now: the hush after a loss, him in the air, the harpoon flying, the quiet under Rivals'
## countdown and card, a scenic silence, the pause card (tools/music_check.py leaves these out of "never quiet").
var still := false
## s of the loss's silence left (music.gd drops everything at once while it's on).
var hush := 0.0
## A scenic silence on ("out": sailing out of the harbour; "rest": a quiet stretch), and how long it's been.
var scenic := ""
var _scenic_t := 0.0
var _plain_t := 0.0
var _rest_due := 240.0
var _flash_armed := true
## How bright a sea passage to pick next (0 dark .. 1 bright).
var bright := 0.75
## How hard the band's playing (0 .. 1: a fish on is 1; audio/music.gd plays the whole song up to HEAT_DB louder for
## it), and how long this fight's been going (s).
var heat := 0.0
var fight_t := 0.0
var _deep_was := false

var _t := 0.0
var _section_t := 0.0
var _fight_ids := {}          # id -> true, last step
var _along_ids := {}
var _gone := {}               # alongside id -> when it went (waiting to see it in the hold)
var _landed := -1
var _their := -1
var _lead := 0
var _lead_t := -INF
var _counting := false
var _card := ""
var _dawned := false
var _after := 0.0             # s of the afterglow left
var _held := {}               # stem -> [level held, s left]
var _rng := RandomNumberGenerator.new()


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func step(w: Dictionary, dt: float) -> void:
	events.clear()
	_t += dt
	_section_t += dt
	hush = maxf(hush - dt, 0.0)
	_after = maxf(_after - dt, 0.0)
	mood = _mood(w)
	var fights: Array = w.get("fights", [])
	var f := _worst(fights)
	danger = _danger(f) if not f.is_empty() else 0.0
	fight_id = str(f.get("id", ""))
	_edges(w, fights)
	var want := _section(w, f)
	if want != section:
		if not (section in FIGHT and want in FIGHT and want != "leader" and _section_t < SECTION_HOLD):
			if want == "leader" and section in FIGHT:
				events.append("leader")
			if want == "gaff" and section in FIGHT:
				events.append("boatside")
			if want == "hunt" and section == "sea":
				events.append("birds")
			if want == "race" and not section in FIGHT and section != "race":
				events.append("race")
			if section == "race" and want == "harbour":
				events.append("home")
			if section == "harbour" and want in ["sea", "hunt", "race"]:
				events.append("away")
			section = want
			_section_t = 0.0
	var wants := _wants(w, f)
	_smooth(wants, dt)
	_mask(w, f, dt)
	_scenic(w, dt)
	still = still or scenic != "" or bool(w.get("paused", false))
	# the heat, and the fight's clock
	fight_t = fight_t + dt if section in FIGHT or section == "gaff" else 0.0
	var h := float(HEAT.get(section, 0.0))
	if section == "race":
		h = 0.6 * smoothstep(0.6, 0.95, clampf(1.0 - float(w.get("race_left", HOME)) / HOME, 0.0, 1.0))
	if mood == "storm":
		h = maxf(h, 0.3)
	heat = move_toward(heat, h, dt / (HEAT_UP if h > heat else HEAT_DOWN))
	_lightning(w)
	bright = float(BRIGHT.get(mood, 0.5)) * lerpf(1.0, 0.5, smoothstep(DUSK, 1.0, float(w.get("day", 0.0))))
	if SECTION_BRIGHT.has(section):
		bright = float(SECTION_BRIGHT[section])
	if events.has("dawn"):
		bright = 1.0


## The fight that's worst off (the most danger; the newest of equals).
func _worst(fights: Array) -> Dictionary:
	var best := {}
	var d := -1.0
	for f: Dictionary in fights:
		var k := _danger(f)
		if k > d + 0.001 or (absf(k - d) <= 0.001 and str(f.get("id", "")) > str(best.get("id", ""))):
			best = f
			d = k
	return best


## A fight's feel from its own cues (tuna/fight.gd's cues(), on the machine holding the rod; `strength` what the
## line takes now): the bend against it, the spool, slack, in the air, a run (the reel screaming), the line on her.
static func feel(c: Dictionary, strength: float) -> Dictionary:
	return {"tension": float(c["tension"]) / maxf(strength, 0.05), "spool": float(c["spool"]), "slack": bool(c["slack"]),
			"airborne": bool(c["airborne"]), "surging": bool(c["surging"]) or float(c["paying"]) > 1.5,
			"contact": float(c["contact"]), "props": float(c["props"])}


## How near the line is to going, from what you could see and feel: the bend against what the line takes, the backing
## showing, the line worn on her, under her props, tangled.
static func _danger(f: Dictionary) -> float:
	var d := smoothstep(NEAR.x, NEAR.y, float(f.get("tension", 0.0)))
	d = maxf(d, smoothstep(0.5, 0.9, float(f.get("spool", 0.0))))
	d = maxf(d, smoothstep(0.4, 0.9, float(f.get("contact", 0.0))))
	d = maxf(d, clampf(float(f.get("props", 0.0)) / 2.5, 0.0, 1.0))
	if bool(f.get("tangled", false)):
		d = maxf(d, 0.7)
	return d


func _mood(w: Dictionary) -> String:
	var c := str(w.get("condition", "calm"))
	if c == "storm":
		return "storm"
	if c == "fog":
		return "fog"
	if bool(w.get("night", false)):
		return "night"
	if c == "rain" or c == "heavy":
		return "rain"
	return "calm"


## Things that happen: the strike, a fish lost or landed, their fish on, the lead changing, the countdown, the card,
## the dawn.
func _edges(w: Dictionary, fights: Array) -> void:
	var now := {}
	for f: Dictionary in fights:
		now[str(f.get("id", ""))] = true
	var along := {}
	for id: Variant in w.get("alongside", []):
		along[str(id)] = true
	var landed := int(w.get("landed", 0))
	var got := _landed >= 0 and landed > _landed
	for id: String in now:
		if not _fight_ids.has(id) and not _along_ids.has(id):
			events.append("strike")
			hush = 0.0
			break
	for id: String in _fight_ids:
		if not now.has(id) and not along.has(id) and now.is_empty() and along.is_empty() and not got:
			_lost()
	for id: String in _along_ids:
		if not along.has(id) and not now.has(id):
			_gone[id] = _t
	if got:
		_gone.clear()
		events.append("landed")
		# the afterglow: the song lifts into the theme for eight bars (audio/music.gd jumps to it on the bar)
		_after = AFTER
	else:
		for id: String in _gone.keys():
			if _t - float(_gone[id]) >= LANDED_WAIT:
				_gone.erase(id)          # (not in the hold: he got away from alongside)
				if now.is_empty() and along.is_empty():
					_lost()
	_fight_ids = now
	_along_ids = along
	_landed = landed
	# Rivals
	var their := int(w.get("their_on", 0))
	if _their >= 0 and their > _their and not bool(w.get("docked", false)):
		events.append("their_on")
	_their = their
	var lbs: Array = w.get("lbs", [])
	if lbs.size() == 2:
		var lead := 0
		var gap := float(lbs[0]) - float(lbs[1])
		if absf(gap) >= 1.0:
			lead = 1 if gap > 0.0 else -1
		if lead != 0 and lead != _lead and _t - _lead_t >= LEAD_GAP and not bool(w.get("docked", false)):
			events.append("lead_up" if lead > 0 else "lead_down")
			_lead_t = _t
			_lead = lead               # (held back by LEAD_GAP, it's still a change to tell once the gap's up)
	var counting := float(w.get("counting", -1.0)) >= 0.0
	if counting and not _counting:
		events.append("countdown")
	_counting = counting
	var card := str(w.get("card_result", "")) if bool(w.get("card", false)) else ""
	if card != "" and card != _card:
		events.append("card:" + card)
	_card = card
	# the dawn: once a trip, as the first light comes
	if bool(w.get("docked", true)):
		_dawned = false
	elif not _dawned and float(w.get("day", 0.0)) > 0.015:
		_dawned = true
		if float(w.get("day", 0.0)) < 0.08:
			events.append("dawn")


func _lost() -> void:
	if events.has("lost"):
		return
	events.append("lost")
	hush = HUSH


func _section(w: Dictionary, f: Dictionary) -> String:
	if bool(w.get("title", false)):
		return "title"
	if bool(w.get("card", false)) or float(w.get("counting", -1.0)) >= 0.0:
		return "rest"
	if not f.is_empty():
		var out := float(f.get("line_out", 100.0))
		var mv := str(f.get("move", ""))
		var same := str(f.get("id", "")) == fight_id
		if out < LEADER or (section == "leader" and same and out < LEADER_OUT):
			return "leader"
		if mv in TIRED_MOVES:
			return "tired"
		if section == "tired" and not mv in FRESH_MOVES:
			return "tired"
		return "fight"
	if hush > 0.0:
		return "rest"
	if not (w.get("alongside", []) as Array).is_empty():
		return "gaff"
	if _after > 0.0:
		return "afterglow"
	if float(w.get("race_left", -1.0)) >= 0.0:
		return "race"
	if bool(w.get("docked", false)):
		return "harbour"
	var birds := float(w.get("birds", 0.0))
	if birds >= BIRDS_IN or (section == "hunt" and (birds >= BIRDS_OUT or _section_t < HUNT_HOLD)):
		return "hunt"
	return "sea"


## The scenic silences: in on casting off (in fair weather, or fog, or at night) and on a long quiet stretch, out
## past the harbour mouth or after a while (the song back on the bar), broken at once by birds, a fish or a storm.
func _scenic(w: Dictionary, dt: float) -> void:
	var plain := section == "sea" and events.is_empty()
	if scenic == "":
		if events.has("away") and mood in SCENIC_MOODS:
			_start_scenic("out")
		elif plain and mood in SCENIC_MOODS:
			_plain_t += dt
			if _plain_t >= _rest_due:
				_start_scenic("rest")
		else:
			_plain_t = 0.0
		return
	_scenic_t += dt
	if not section in ["sea", "harbour"] or not mood in SCENIC_MOODS or hush > 0.0:
		_end_scenic("wake")
	elif scenic == "out" and (float(w.get("past_mouth", -INF)) >= SCENIC_PAST or _scenic_t >= SCENIC_OUT):
		_end_scenic("return_theme")
	elif scenic == "rest" and _scenic_t >= SCENIC_REST:
		_end_scenic("return")


func _start_scenic(kind: String) -> void:
	scenic = kind
	_scenic_t = 0.0
	_plain_t = 0.0
	_rest_due = _rng.randf_range(SCENIC_EVERY.x, SCENIC_EVERY.y)
	events.append("scenic")


func _end_scenic(how: String) -> void:
	scenic = ""
	_plain_t = 0.0
	events.append(how)


## Lightning in a storm: a strike as the flash comes (sea_fx's flash jumping up), once each.
func _lightning(w: Dictionary) -> void:
	var f := float(w.get("flash", 0.0))
	if f >= 0.9 and _flash_armed:
		_flash_armed = false
		if mood == "storm" and section != "title":
			events.append("lightning")
	elif f < 0.3:
		_flash_armed = true


## Each stem's level wanted (before smoothing): the title's own, or the song's layers for what's happening.
func _wants(w: Dictionary, f: Dictionary) -> Dictionary:
	if section == "title":
		return _title()
	if section == "rest":
		return {}
	var want := {}
	var m: Dictionary = SEA.get(mood, SEA["calm"])
	for k: String in SEA_STEMS:
		want[k] = float(m.get(k, 0.0))
	var run := smoothstep(RUN.x, RUN.y, float(w.get("speed", 0.0)))
	match section:
		"sea":
			# under way: the drums' eighths and the bass pushing; the faster she goes, the more
			want["run"] = run * (0.5 if mood == "storm" else 1.0)
			want["bass"] = maxf(float(want["bass"]), 0.6 + 0.4 * run)
		"harbour":
			# tied up: the song quiet, the guitar and the lead soft, no drums (but the weather's)
			want["pick"] = float(want["pick"]) * 0.7
			want["lead"] = float(want["lead"]) * 0.5
			want["bass"] = float(want["bass"]) * 0.6
		"hunt":
			# birds working: the bass ticking over, the bells; the lead holding back a little, the run still on
			var b := float(w.get("birds", 0.0))
			want["pulse"] = smoothstep(0.05, 0.6, b)
			want["glint"] = 0.8 * smoothstep(0.05, 0.4, b)
			want["lead"] = float(want["lead"]) * 0.6
			want["run"] = run * 0.6
		"fight", "tired", "leader":
			_fight(w, f, want)
		"gaff":
			# boatside: the heartbeat, the drums down, the tension rising with the harpoon's wind-up
			want["beat"] = 1.0
			want["drive"] = 0.25
			want["tension"] = maxf(float(w.get("draw", 0.0)), 0.15)
			want["deep"] = 0.3
			want["lead"] = 0.2
			want["pick"] = 0.3
		"afterglow":
			# he's in: the song lifted, the theme up high, the drums carrying on and easing
			want["lead"] = 1.0
			want["high"] = 0.85
			want["pick"] = 1.0
			want["bass"] = 1.0
			want["drive"] = 0.5 * clampf(_after / AFTER, 0.0, 1.0)
			want["pound"] = 0.6 * smoothstep(AFTER * 0.5, AFTER, _after)
		"race":
			_race(w, want, run)
	# (the counter-melody wants what the lead does: audio/music.gd's arrangement trades them pass to pass)
	want["alt"] = float(want.get("lead", 0.0))
	return want


## The title's stems by the weather on it: the whistle and the band in fair weather; in rain the patter under it,
## the whistle softer; in a storm no whistle, the theme low on the bow over the storm's drums; at night the bells; in
## fog almost only the pad and a far whistle.
func _title() -> Dictionary:
	var t := {"lead": 1.0, "counter": 1.0, "guitar": 1.0, "bass": 1.0, "pad": 1.0, "drums": 1.0, "rain": 0.0,
			"storm": 0.0, "night": 0.0, "low": 0.0}
	match mood:
		"rain":
			t.merge({"lead": 0.55, "counter": 0.8, "guitar": 0.7, "drums": 0.6, "rain": 1.0}, true)
		"storm":
			t.merge({"lead": 0.0, "counter": 0.4, "guitar": 0.25, "drums": 0.0, "storm": 1.0, "low": 1.0}, true)
		"fog":
			t.merge({"lead": 0.5, "counter": 0.2, "guitar": 0.3, "bass": 0.5, "drums": 0.0, "night": 0.4}, true)
		"night":
			t.merge({"lead": 0.6, "counter": 0.6, "guitar": 0.6, "bass": 0.7, "pad": 0.9, "drums": 0.3, "night": 1.0},
					true)
	return t


## The race home: under way, the drums building as the time runs out; ahead, the tune up high; behind at the end,
## the tension and everything.
func _race(w: Dictionary, want: Dictionary, run: float) -> void:
	var left := float(w.get("race_left", HOME))
	var p := clampf(1.0 - left / HOME, 0.0, 1.0)
	var st := int(w.get("standing", 0))
	want["run"] = maxf(run, 0.6)
	want["drive"] = smoothstep(0.3, 0.85, p)
	want["beat"] = smoothstep(0.5, 0.9, p)
	want["lead"] = maxf(float(want["lead"]), 0.6)
	if st > 0:
		want["high"] = smoothstep(0.4, 0.8, p)
	want["pound"] = maxf(float(want["pound"]), 0.7 * smoothstep(0.8, 0.95, p))
	if st < 0:
		want["drive"] = maxf(float(want["drive"]), smoothstep(LAST + 30.0, LAST, left))
		want["tension"] = smoothstep(LAST, LAST - 60.0, left)
		want["pound"] = maxf(float(want["pound"]), smoothstep(LAST, LAST - 45.0, left))


## A fish on: the heartbeat (gone on a slack line), the drums on his runs, the tension as the line nears going, the
## deep while he sounds, a giant's weight; the song's own melody stepping back for it (and coming back as he tires:
## the hope), the lead up high at the leader.
func _fight(w: Dictionary, f: Dictionary, want: Dictionary) -> void:
	var mv := str(f.get("move", ""))
	var spool := float(f.get("spool", 0.0))
	var drive := 0.6
	match mv:
		"run", "surge", "charge":
			drive = 1.0
		"jump":
			drive = 0.8
		"shake":
			drive = 0.55
		"sound", "dog":
			drive = 0.25
		"circle", "spiral":
			drive = 0.6               # (tiring, circling: the drums stay up under the tune, the end's not won yet)
	if bool(f.get("surging", false)):
		drive = 1.0
	if section == "leader":
		drive = maxf(drive, 0.8)
	if spool > 0.5:
		drive = maxf(drive, 0.85)
	var depth := float(f.get("depth", 0.0))
	var deep := 1.0 if mv in ["sound", "dog"] or depth > 40.0 else (0.3 if depth > 20.0 else 0.0)
	if str(w.get("condition", "")) == "storm":
		deep = maxf(deep, 0.5)
	var heavy := smoothstep(HEAVY.x, HEAVY.y, float(f.get("kg", 0.0)))
	deep = maxf(deep, 0.5 * heavy)
	want["beat"] = 0.0 if bool(f.get("slack", false)) else 1.0
	want["drive"] = drive
	want["tension"] = maxf(maxf(smoothstep(LOADED.x, LOADED.y, float(f.get("tension", 0.0))),
			maxf(smoothstep(0.2, 0.8, danger), 0.6 * smoothstep(0.5, 0.85, spool))),
			0.35 * smoothstep(BUILD_TENSION.x, BUILD_TENSION.y, fight_t))
	want["deep"] = deep
	want["heavy"] = heavy
	# the whole drum section: on his runs, the backing showing, the leader, a storm; tiring, a little
	var pound := 0.7 if drive >= 0.99 else 0.0
	if spool > 0.5:
		pound = maxf(pound, smoothstep(0.5, 0.8, spool))
	# the fight building: the drums never right down, the drum section in, the tension never off; sounding deep it
	# backs off, and his next run after it hits with everything
	var deep_now := mv in ["sound", "dog"]
	drive = maxf(drive, 0.5 * smoothstep(BUILD_DRIVE.x, BUILD_DRIVE.y, fight_t))
	pound = maxf(pound, 0.6 * smoothstep(BUILD_POUND.x, BUILD_POUND.y, fight_t) * (0.4 if deep_now else 1.0))
	if _deep_was and not deep_now and mv in ["run", "surge", "charge"] and fight_t > 30.0:
		pound = 1.0
	_deep_was = deep_now if mv != "" else _deep_was
	want["drive"] = drive
	if section == "leader":
		pound = 1.0
	elif section == "tired":
		pound = maxf(pound, 0.3)
	if mood == "storm":
		pound = maxf(pound, 0.6)
	want["pound"] = pound
	want["run"] = 0.0
	want["pick"] = float(want["pick"]) * 0.5
	want["lead"] = {"fight": 0.25, "tired": 0.7, "leader": 1.0}.get(section, 0.25)
	want["high"] = 1.0 if section == "leader" else 0.0


func _smooth(wants: Dictionary, dt: float) -> void:
	for k: String in gains.keys():
		if not wants.has(k):
			gains.erase(k)
			_held.erase(k)
	for k: String in wants:
		var want := clampf(float(wants[k]), 0.0, 1.0)
		var sm: Array = SMOOTH.get(k, SMOOTH_ELSE)
		if not gains.has(k):
			gains[k] = want          # (a section's stems start where they're wanted: it comes in by its own fade)
			continue
		var g := float(gains[k])
		var h: Array = _held.get(k, [0.0, 0.0])
		# up, it holds; and as long as it's wanted that high again within the hold, the hold starts over
		if float(sm[2]) > 0.0 and want > 0.05 and (want > g + 0.05 or (float(h[1]) > 0.0 and want >= float(h[0]) - 0.05)):
			h = [maxf(want, float(h[0]) if float(h[1]) > 0.0 else 0.0), float(sm[2])]
		h[1] = maxf(float(h[1]) - dt, 0.0)
		if float(h[1]) > 0.0:
			want = maxf(want, float(h[0]))
		_held[k] = h
		g = move_toward(g, want, dt / maxf(float(sm[0] if want > g else sm[1]), 0.01))
		gains[k] = g


## The fast masks over the fight: him in the air (everything all but gone till he's back in), the line about to part
## (only the heartbeat and one shaking note: the barest music in the game), the harpoon flying (silence).
func _mask(w: Dictionary, f: Dictionary, dt: float) -> void:
	if danger >= PARTING:
		parting = true
	elif danger < PARTED:
		parting = false
	parting = parting and section in FIGHT
	var air := section in FIGHT and bool(f.get("airborne", false))
	var flying := section == "gaff" and bool(w.get("flying", false))
	for k: String in gains:
		var m := 1.0
		if parting:
			m = {"pad": 0.3, "beat": 1.0, "tension": 1.0, "heavy": 0.5}.get(k, 0.0)
		if (air or parting) and k in WEATHER:
			m = 0.5 * AIR if air else 0.3
		if air:
			m = minf(m, AIR)
		if flying:
			m = 0.12 if k == "pad" else 0.0
		var cur := float(masks.get(k, 1.0))
		masks[k] = move_toward(cur, m, dt / (MASK_DOWN if m < cur else MASK_UP))
		if parting and k == "tension":
			gains[k] = maxf(float(gains[k]), 1.0)
	for k: String in masks.keys():
		if not gains.has(k):
			masks.erase(k)
	still = hush > 0.0 or air or flying or section == "rest" or scenic != ""


## A stem's level as it should sound (its gain under its mask).
func level(k: String) -> float:
	return float(gains.get(k, 0.0)) * float(masks.get(k, 1.0))
