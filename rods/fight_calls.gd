extends Node
## The fight said out loud, in the moment, instead of on cards: the crew shouting what's happening as it happens
## ("HALF THE SPOOL'S GONE! BACK DOWN ON HIM!", "LEADER!", "COLOUR!", "OUT OF GEAR!"), a word or two under the
## crosshair and a voice shouting it, and Dale on the VHF (ui/tips.gd) the first time each thing comes up, with what to
## do about it in a line. Every peer works it out from the rods' own synced state (rods.gd ticks it), so everyone
## aboard hears the same shout at the same moment. Alone, nobody shouts (only the warnings that can't wait show, and
## Dale teaches); with a crew the voices are theirs.

const Fight := preload("res://tuna/fight.gd")
const RadioVoice := preload("res://audio/radio_voice.gd")
## How long a shout stays up (s), and how long before the same one can come again.
const SHOUT_T := 2.6
const AGAIN := 9.0

var spread: Node              # rods.gd
## What's been called for each fish on (rod index -> {what: sea clock it was last called}).
var _called := {}
var _shout := ""
var _shout_t := 0.0
var _urgent := false
## (per rod) how long it's been bent hard, slack, or cranked against him; for Dale's lines.
var _hard := {}
var _slack := {}
var _stall := {}
var _slip := {}
var _voice: AudioStreamPlayer
var _t := 0.0
## The last shout, and how many there have been (the tests read them).
var last := ""
var count := 0


func _ready() -> void:
	_voice = RadioVoice.new()
	_voice.name = "Shout"
	_voice.bus = &"Effects" if AudioServer.get_bus_index(&"Effects") >= 0 else &"Master"
	_voice.pitch_scale = 1.3
	_voice.volume_db = -4.0
	add_child(_voice)


## The shout up now (the crosshair line), or "": and whether it's one that can't wait.
func line() -> String:
	return _shout if _shout_t > 0.0 else ""


func urgent() -> bool:
	return _urgent and _shout_t > 0.0


## Shouts `text` (unless it's been shouted for this fish in the last AGAIN s). `crew`: there's someone to shout it.
func shout(i: int, what: String, text: String, crew: bool, urgent_too := false) -> void:
	var c: Dictionary = _called.get(i, {})
	if _t - float(c.get(what, -INF)) < AGAIN:
		return
	c[what] = _t
	_called[i] = c
	if not crew and not urgent_too:
		return
	_shout = text
	_shout_t = SHOUT_T
	_urgent = urgent_too
	last = text
	count += 1
	if crew and _voice.is_inside_tree():
		_voice.call("say", maxi(text.split(" ", false).size() - 1, 2))


## Dale's line `id` (ui/tips.gd), the first time it comes up (only aboard: not for the other boat's fish in VS).
func dale(id: String) -> void:
	var sea := spread.get("sea") as Node
	var crew: Node = sea.get("crew")
	var tips: Node = sea.get("tips")
	if tips != null and crew != null and crew.get("me") != null:
		tips.call("show_tip", id)


## Every frame, from rods.gd: `mine` the rod in your hands (or null), `crew_n` how many aboard.
func tick(delta: float, mine: Node, crew_n: int, throttle: float) -> void:
	_t += delta
	_shout_t = maxf(_shout_t - delta, 0.0)
	var crew := crew_n > 1
	for r: Node in spread.get("rods"):
		var i := int(r.get("index"))
		if not bool(r.get("hooked")) or bool(r.get("alongside")):
			if _called.has(i):
				_called.erase(i)
			continue
		var out := float(r.get("line_out"))
		var spool := out / Fight.CAPACITY
		var c: Dictionary = _called.get(i, {})
		# the spool going
		if spool > 0.85:
			shout(i, "arbor", "SHE'S NEARLY EMPTY! CHASE HIM!", crew, true)
		elif spool > 0.65:
			shout(i, "spool", "HE'S SPOOLING US! BACK DOWN!", crew, true)
		elif spool > 0.5 and not c.has("half"):
			shout(i, "half", "HALF THE SPOOL'S GONE!", crew)
			dale("spool")
		# under her: the props, the hull
		var b := absf(wrapf(float(r.get("bearing")), -PI, PI))
		if b > Fight.UNDER - 0.2 and float(r.get("depth")) < 25.0 and absf(throttle) > 0.05:
			shout(i, "props", "OUT OF GEAR! HE'S UNDER THE PROPS!", crew, true)
		elif b > Fight.UNDER - 0.3:
			shout(i, "under", "HE'S UNDER THE BOAT!", crew, true)
		elif b > Fight.SIDE_FROM:
			shout(i, "hull", "LINE ON THE HULL!", crew, true)
		# his moves
		var m := str(r.get("move"))
		if m == "jump":
			shout(i, "jump", "JUMP! DROP THE TIP!", crew)
			if mine == r:
				dale("jump")
		if m == "spiral" and not c.has("colour"):
			shout(i, "colour", "COLOUR! HE'S UP!", crew)
		if m == "surge" and out < 60.0 and float(r.get("energy")) < 0.5:
			shout(i, "surge", "HE'S GOING AGAIN!", crew)
		if out < Fight.LEADER and not c.has("leader"):
			shout(i, "leader", "LEADER! LEADER'S UP!", crew, true)
			dale("leader")
		# the angler
		var strain := float(r.get("strain"))
		_hard[i] = float(_hard.get(i, 0.0)) + delta if strain > 0.5 else 0.0
		if float(_hard[i]) > 1.0:
			shout(i, "heavy", "EASY! YOU'LL TEAR THE HOOK OUT!", crew)
			if mine == r:
				dale("heavy")
		_slack[i] = float(_slack.get(i, 0.0)) + delta if float(r.get("stretch")) < -1.0 else 0.0
		if float(_slack[i]) > 1.0:
			shout(i, "slack", "WIND! HE'S COMING AT US!", crew)
		if crew and int(r.get("holder")) != 0 and float(r.get("arms")) < 0.15:
			shout(i, "arms", "SWAP HIM! HIS ARMS ARE GONE!", crew)
		# Dale's lines for whoever's got the rod, the first time each thing matters
		if mine == r:
			var f: Object = r.get("fight")
			dale("fight")
			if f != null:
				_slip[i] = float(_slip.get(i, 0.0)) + delta if bool(f.get("slipping")) else 0.0
				if float(_slip[i]) > 2.0:
					dale("drag")
				var stalled := bool(f.get("reeling")) and float(f.get("wind")) < 0.4 and not bool(f.get("slipping")) \
						and strain > 0.1
				_stall[i] = float(_stall.get(i, 0.0)) + delta if stalled or bool(f.get("grinding")) else 0.0
				if float(_stall[i]) > 2.0:
					dale("pump")
			if float(r.get("arms")) < Fight.TIRED:
				dale("tired")
