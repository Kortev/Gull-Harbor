extends Node3D
## Jigging for mackerel with the light jig rod in your hands (crew/hands.gd's kit, key 3): a string of little feathered
## hooks and a chrome sinker over the side. Stand at the rail, rod out over the water, and it's all on the line:
##   - click: open the spool. The jig drops off the tip, hits the water and sinks, line pouring off the reel with the
##     clicker going; the line's metered, a colour every 10 m (white, green, red, blue), so what's coming off the
##     spool says how deep it is. The mackerel are SCHOOL m down: in the green.
##   - click again: thumb the spool. It stops there.
##   - tap: work it, the rod tip snatched up and the jig with it, let fall; a knock on the fall jerks the tip down and
##     your view with it. Tap again, quick, to set the hook; too slow and it's gone
##   - hold: wind. The crank turns with the line coming in (PER_TURN a turn), your left hand on it, and the jig comes up
##     the whole way: through the water, out, up to the tip. A mackerel on comes up kicking and hangs there off the tip.
##   - with one hanging off the tip, click at the live well (boat/live_well.gd): it's swung over and shaken off the hook
##     into it (the well full, it goes in the bait box beside it, dead: still bait, a poor one).
## Not while she's under way (JIG_SPEED): the jig streams out behind her and nothing takes it. A live mackerel's the
## bait a tuna takes best (rods.gd): this is where they come from once the few you went out with are used.
##
## The jigging is yours (on your machine); each mackerel is the host's to give (_ask_mackerel). The others see all of
## it from your word ten times a second (_jig_state: line out, what it's doing, the tip): the jig going down and coming
## up, the crank turning, the fish swung aboard.

const Sfx := preload("res://audio/sfx.gd")
const Kit := preload("res://crew/kit.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const ReelNoise := preload("res://rods/reel_noise.gd")
## The fastest she can be going (m/s), and the quickest the host gives one peer another mackerel (s).
const JIG_SPEED := 1.5
const EVERY := 2.0
## The rig hanging off the tip (m: crew/hands.gd's RIG); the most line on the little reel (m); how fast the jig sinks
## (m/s, its fall through the water; in the air it just drops); how fast it comes up wound (m/s) and the line one turn
## of the crank brings in (m); how long a hold is a wind, not a jig (s).
const RIG := 0.38
const SPOOL := 45.0
const SINK := 2.6
const WIND := 2.2
const PER_TURN := 0.7
const HOLD := 0.28
## Where the mackerel are (m down: deeper or shallower and nothing touches it), the chance something knocks it on the
## fall after a jig, and how long you have to strike (s). (KNOCK_DEEP: the top of the school.)
const SCHOOL := Vector2(9.0, 19.0)
const KNOCK_DEEP := 9.0
const KNOCK := 0.4
const STRIKE := 0.55
## How close to the live well you have to be to swing one into it (m), and how long the swing takes (s).
const WELL_REACH := 2.4
const SWING := 0.7
## The line's colours, a band every 10 m from the jig.
const METERED: Array[Color] = [Color(0.92, 0.92, 0.86), Color(0.3, 0.8, 0.35), Color(0.9, 0.25, 0.2), Color(0.25, 0.45, 0.95)]
## What the jig's doing, sent as a number.
const STATES: Array[String] = ["up", "free", "down", "knock", "on", "hang", "swing"]

var sea: Node                 # sea/sea.gd
## Your jig: "up" (hanging off the tip), "free" (the spool open: going down), "down" (thumbed: there, being worked),
## "knock" (a fish on it, strike now), "on" (hooked), "hang" (up, a mackerel kicking on it off the tip), "swing" (that
## mackerel going over into the well).
var state := "up"
## Line out from the tip to the sinker (m; RIG: hanging at the tip), and how deep the jig is under the top (m).
var line := RIG
var depth := 0.0
## The rod tip snatched up (1) or jerked down by a knock (-1), easing back to 0; crew/hands.gd poses the rod with it.
var lift := 0.0
## The crank's turn (rad, from the line wound in) and the jig going down (m/s).
var crank := 0.0
var fall := 0.0
var _held := 0.0
var _pressed := false
var _knock_in := INF
var _knock_left := 0.0
var _wriggle := 0.0
var _swing_t := 0.0
var _send_in := 0.0
var _quiet := 0
var _last := {}               # (host: peer -> when they last got one)
## Everyone's jig, as drawn (peer -> a Jigger: yours and the others', from their word).
var _jiggers := {}
var _lines: ImmediateMesh


## One jig line as drawn: where its jig is, the rig on the end of it, the mackerel on it, its reel's noise.
class Jigger:
	var state := "up"
	var line := RIG
	var goal := RIG               # (a crewmate's: their last word, eased toward)
	var lift := 0.0
	var jerk := 0.0               # (the jig's own rise on a snatch, behind the tip's: it's on a line)
	var swing := Vector3.ZERO     # (off where it hung swinging when it was let go, settling out)
	var was_out := false
	var crank := 0.0
	var at := Vector3.INF         # the sinker (world)
	var xz := Vector2.INF         # where the line goes down (world x, z: drifts behind the tip)
	var swing_t := 0.0
	var body: Node3D              # the rig (its origin where the line ties on)
	var fish: Node3D
	var noise: AudioStreamPlayer3D
	var heard := 0.0              # (s since their last word)


func _ready() -> void:
	_lines = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _lines
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (the metered braid in its colours, fading with distance like any line: rods/line_look.gd)
	mi.material_override = preload("res://rods/line_look.gd").material(0.35, 4.0, 0.95)
	add_child(mi)
	(sea.get("boat") as Node).connect("rebuilt", func() -> void: _reset())


func _reset() -> void:
	state = "up"
	line = RIG
	depth = 0.0
	lift = 0.0
	fall = 0.0


## What to do now with the jig rod in your hands, in words under your sight (rods.gd shows them; "" none).
func hint() -> String:
	var me := (sea.get("crew") as Node).get("me") as Node
	var hands: Node = me.get("hands") if me else null
	if hands == null or str(hands.get("item")) != "jig":
		return ""
	if absf(_speed()) > JIG_SPEED:
		return "STOP THE BOAT TO JIG: IT STREAMS OUT BEHIND HER"
	match state:
		"up":
			return "CLICK: OPEN THE SPOOL, DROP THE JIG" if _over_water(me) else "GO TO THE RAIL, ROD OUT OVER THE WATER"
		"free":
			return "CLICK: THUMB IT, STOP IT IN THE GREEN"
		"down":
			if depth < SCHOOL.x or depth > SCHOOL.y:
				return "NOTHING DOWN HERE: HOLD TO WIND, CLICK TO LET IT GO" if depth > SCHOOL.y \
						else "TOO SHALLOW: CLICK TO LET IT DOWN TO THE GREEN"
			return "TAP: WORK IT. WAIT FOR A KNOCK"
		"knock":
			return "KNOCK! TAP NOW TO HOOK IT!"
		"on":
			return "MACKEREL ON! HOLD: WIND IT UP"
		"hang":
			if not _near_well(me):
				return "TAKE IT TO THE LIVE WELL"
			return "CLICK: SWING IT INTO THE WELL"
	return ""


## Whether your jig's off the tip (over the side, or a mackerel on it).
func active() -> bool:
	return state != "up"


## Left mouse went down with the jig rod in your hands (crew/hands.gd).
func work(player: Node) -> void:
	_pressed = true
	_held = 0.0
	match state:
		"up":
			if _over_water(player):
				state = "free"
				fall = 0.0
				# (it goes from where it was swinging on the tip, not from straight under it)
				var j := _jigger(Net.my_id())
				var hung: Vector3 = (player.get("hands") as Node).call("rig_end")
				var tip := _tip(player)
				j.swing = hung - (tip + Vector3.DOWN * RIG) if hung != Vector3.INF and tip != Vector3.INF \
						else Vector3.ZERO
				j.at = Vector3.INF
				Sfx.play_point(self, _tip(player), "kit.switch", 0.5, 1.8)     # (the spool's catch let off)
		"free":
			state = "down"           # (thumbed)
			fall = 0.0
			Sfx.play_point(self, _tip(player), "kit.switch", 0.35, 2.2)
		"down":
			if depth < SCHOOL.x:
				state = "free"        # (let it on down)
				fall = 0.0
				return
			if depth > SCHOOL.y + 0.5:
				return
			lift = 1.0             # a jig: the tip snatched up
			if absf(_speed()) <= JIG_SPEED and randf() < KNOCK:
				_knock_in = randf_range(0.35, 1.1)      # (on the fall)
		"knock":
			lift = 1.0
			state = "on"
			_wriggle = 1.0
			Sfx.play_point(self, _tip(player), "kit.jolt", 0.5, 1.5)
		"on":
			lift = 0.6
		"hang":
			if _near_well(player):
				state = "swing"
				_swing_t = 0.0
				player.call("gesture", "reach")


func _process(delta: float) -> void:
	var crew := sea.get("crew") as Node
	var me: Node3D = crew.get("me") if crew else null
	var mine := me != null and str((me.get("hands") as Node).call("shown_item")) == "jig" \
			and not bool((me.get("hands") as Node).call("stowed"))
	if not mine and active():
		_reset()
	if mine:
		_play(me, delta)
	lift = move_toward(lift, 0.0, delta * 2.6)
	# (your word to the others ten times a second while it's off the tip, and a few more once it's back)
	_send_in -= delta
	if active():
		_quiet = 3
	if me != null and Net.in_session() and _send_in <= 0.0 and _quiet > 0:
		_send_in = 0.1
		if not active():
			_quiet -= 1
		_jig_state.rpc(line, STATES.find(state), lift)
	_draw(crew, delta)


## Your jig, this frame: going down while the spool's open, winding up while you hold the button, the jig's action, the
## knock and the strike.
func _play(me: Node3D, delta: float) -> void:
	var live := bool(me.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var held := live and Input.is_action_pressed("use_primary") and _pressed
	if not held:
		_pressed = false
	_held = _held + delta if held else 0.0
	var h := _tip_height(me)
	var winding := _held > HOLD and state in ["free", "down", "knock", "on"]
	if winding:
		if state == "free":
			state = "down"
		var was := line
		line = maxf(line - WIND * delta, RIG)
		crank += (was - line) / PER_TURN * TAU
		lift = maxf(lift, 0.3)
		if line <= RIG:
			_up(me)
	elif state == "free":
		# off the spool: dropping through the air, then sinking (the jig's weight against the water)
		fall = minf(fall + 9.8 * delta, 9.0) if line < h else move_toward(fall, SINK, 30.0 * delta)
		line = minf(line + fall * delta, SPOOL)
		if line >= SPOOL:
			state = "down"          # (the knot at the spool: that's all there is)
	depth = maxf(line - h, 0.0)
	# a knock on the fall: the tip jerks down, your view with it; strike within STRIKE s or it's gone
	_knock_in -= delta
	if _knock_in <= 0.0:
		_knock_in = INF
		if state == "down" and depth >= SCHOOL.x and depth <= SCHOOL.y:
			state = "knock"
			_knock_left = STRIKE
			lift = -1.0
			me.set("shake", 0.7)
			Sfx.play_point(self, _tip(me), "kit.thud", 0.35, 1.8)
	if state == "knock":
		_knock_left -= delta
		if _knock_left <= 0.0:
			state = "down"
			me.set("shake", 0.0)
	if state in ["on", "hang"]:
		# a mackerel on: the tip nodding to its kicks
		_wriggle += delta
		lift = minf(lift, -0.25 + sin(_wriggle * 17.0) * 0.2)
		me.set("shake", 0.15 if state == "on" else 0.06)
	elif state != "knock" and float(me.get("shake")) > 0.0 and not _rod_in_hands(me):
		me.set("shake", 0.0)
	if state == "swing":
		_swing_t += delta
		if _swing_t >= SWING:
			state = "up"
			me.set("shake", 0.0)
			if Net.is_host():
				_ask_mackerel_as(Net.my_id())
			else:
				_ask_mackerel.rpc_id(1)
	if absf(_speed()) > JIG_SPEED and state in ["knock", "on"]:
		state = "down"      # (under way: torn off)


## Wound all the way up to the tip: a mackerel on hangs there kicking; without one, the jig's back on the tip.
func _up(me: Node3D) -> void:
	line = RIG
	depth = 0.0
	if state == "on":
		state = "hang"
		Sfx.play_point(self, _tip(me), "dock.slap", 0.4, 1.8)
	else:
		state = "up"
		me.set("shake", 0.0)


func _rod_in_hands(me: Node) -> bool:
	var rods: Node = sea.get("rods")
	return rods != null and rods.call("held_by", str(me.name).to_int()) != null


## A jigger's word: how much line they've out, what it's doing, their tip's lift.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _jig_state(out: float, st: int, tip_lift: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	var j := _jigger(id)
	j.goal = out
	j.state = STATES[clampi(st, 0, STATES.size() - 1)]
	j.lift = tip_lift
	j.heard = 0.0


@rpc("any_peer", "call_remote", "reliable")
func _ask_mackerel() -> void:
	_ask_mackerel_as(multiplayer.get_remote_sender_id())


## Host: a mackerel swung aboard by `who`, if it's been long enough and she's slow enough: into the well if it takes
## it, else on ice in the bait box (dead bait).
func _ask_mackerel_as(who: int) -> void:
	var t := _now()
	if t - float(_last.get(who, -1e9)) < EVERY or absf(_speed()) > JIG_SPEED:
		return
	var hold: Node = sea.get("fish_hold")
	if hold == null:
		return
	_last[who] = t
	var kept := bool(hold.call("host_add_live"))
	if not kept:
		hold.call("host_add_dead")
	if Net.in_session():
		_caught.rpc(who, kept)
	else:
		_caught(who, kept)


@rpc("authority", "call_local", "reliable")
func _caught(who: int, kept := true) -> void:
	if kept and who == Net.my_id():
		Net.achievements.unlock("LIVE_BAIT")
	var well := _well_mouth()
	Sfx.play_point(self, well if well != Vector3.INF else global_position, "dock.slap", 0.5, 1.6 if kept else 2.2)
	if who == Net.my_id() and not kept:
		var hud: Node = (sea.get("crew") as Node).get("hud")
		if hud:
			hud.call("notify", "The well's full: that one's on ice, dead bait")


## Everyone's jig lines: from each jigger's rod tip down to their jig (in the air, through the top, down in the water),
## the rig on the end, a mackerel on it kicking, swung over into the well.
func _draw(crew: Node, delta: float) -> void:
	_lines.clear_surfaces()
	var ocean := sea.get("ocean") as Node
	var any := false
	var seen := {}
	for p: Node in crew.get_children():
		if not p is Node3D or not p.has_method("gesture"):
			continue
		var id := str(p.name).to_int()
		var mine: bool = p == crew.get("me")
		var tip := _tip(p)
		var j: Jigger = _jiggers.get(id)
		if tip == Vector3.INF or (j == null and (mine and not active())):
			continue
		if j == null:
			if mine or (int(p.get("_net_act")) & 2) != 0:       # (player.gd's ACT_JIG)
				j = _jigger(id)
			else:
				continue
		seen[id] = true
		if mine:
			j.line = line
			j.state = state
			j.crank = crank
			j.lift = lift
			j.swing_t = _swing_t
		else:
			# (their word ten times a second: eased toward, never jumped to; the crank turns with what comes in)
			j.heard += delta
			var was := j.line
			j.line = move_toward(j.line, j.goal, delta * maxf(WIND * 1.6, absf(j.goal - j.line) * 4.0))
			if j.line < was:
				j.crank += (was - j.line) / PER_TURN * TAU
			if j.state == "swing":
				j.swing_t += delta
			else:
				j.swing_t = 0.0
			if j.heard > 1.5 or (int(p.get("_net_act")) & 2) == 0 and j.state == "up":
				j.state = "up"
				j.goal = RIG
		_place(j, tip, ocean, delta)
		var out := j.state != "up"
		if not out and j.was_out:
			(p.get("hands") as Node).call("seed_rig", j.at)       # (back on the tip: it hangs on from where it came up)
		j.was_out = out
		j.body.visible = out and j.state != "swing"
		if j.noise:
			j.noise.global_position = tip
			# the clicker while it goes down (a tick every few cm), the anti-reverse ticking as it's wound
			j.noise.clicks = (fall * 30.0 if mine else 60.0) if j.state == "free" else 0.0
		if out:
			if not any:
				_lines.surface_begin(Mesh.PRIMITIVE_LINES)
				any = true
			_line_to(tip, j)
		_show_fish(j, tip, delta)
	if any:
		_lines.surface_end()
	for id: int in _jiggers.keys():
		if not seen.has(id):
			var j: Jigger = _jiggers[id]
			j.body.queue_free()
			j.fish.queue_free()
			j.noise.queue_free()
			_jiggers.erase(id)


## Jigger `j`'s sinker this frame: hanging straight off the tip on its line in the air; in the water, sunk to the line's
## length below the top, drifting in behind where she's moved off to (it doesn't follow her round at once); snatched up
## on a jig. Continuous: from the tip it goes, and back to the tip it comes.
func _place(j: Jigger, tip: Vector3, ocean: Node, delta: float) -> void:
	var sea_y := float(ocean.call("height_at", tip))
	var h := maxf(tip.y - sea_y, 0.2)
	var tip_xz := Vector2(tip.x, tip.z)
	if j.xz == Vector2.INF or j.line <= RIG + 0.02:
		j.xz = tip_xz
	var in_water := j.line > h
	# (in the air it swings in under the tip at once; in the water the line leans back as she drifts off it)
	var k := 1.0 - exp(-(9.0 if not in_water else 1.2) * delta)
	j.xz = j.xz.lerp(tip_xz, k)
	var off := j.xz - tip_xz
	var down := sqrt(maxf(j.line * j.line - off.length_squared(), 0.0))
	var at := Vector3(j.xz.x, tip.y - down, j.xz.y)
	# a jig: the tip's snatch lifts it (more of it, the shallower), and it flutters back down
	j.jerk = lerpf(j.jerk, maxf(j.lift, 0.0) if j.state in ["down", "knock", "on"] else 0.0, 1.0 - exp(-10.0 * delta))
	at.y += j.jerk * 0.7
	# (where it was swinging off the tip when it was let go, settling out; and on its line it follows the tip with a
	# lag, the water's drag on it: it never jumps after it)
	j.swing *= exp(-4.0 * delta)
	at += j.swing
	if j.at != Vector3.INF and j.at.distance_to(at) < 30.0:
		var rate := 12.0 if in_water else 30.0
		at = j.at.lerp(at, 1.0 - exp(-rate * delta))
	j.at = at
	var dir := (tip - at).normalized() if tip.distance_to(at) > 0.01 else Vector3.UP
	var side := dir.cross(Vector3.FORWARD)
	if side.length() < 0.1:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	# the rig's origin is where its line ties on, RIG up the line from the sinker
	j.body.global_transform = Transform3D(Basis(side, dir, side.cross(dir)), at + dir * RIG)


## The jig line from the tip down to the rig's tie, in its metre colours (the colour coming off the tip is how much
## is out).
func _line_to(tip: Vector3, j: Jigger) -> void:
	var tie := j.body.global_position if j.state != "swing" else j.fish.global_position
	var length := maxf(j.line - RIG, 0.0)
	var n := int(length / 10.0) + 1
	var a := tip
	for i in n:
		var from_tie := length - i * 10.0                     # (m from the tie at this end of the piece)
		var to_tie := maxf(from_tie - 10.0, 0.0)
		var f := 1.0 - to_tie / maxf(length, 0.001)
		var b := tip.lerp(tie, f) if length > 0.001 else tie
		var c := METERED[int(from_tie / 10.0 - 0.0001) % METERED.size()] if from_tie > 0.0 else METERED[0]
		_lines.surface_set_color(c)
		_lines.surface_add_vertex(a)
		_lines.surface_set_color(c)
		_lines.surface_add_vertex(b)
		a = b


## The mackerel on jigger `j`'s jig: kicking on the hook as it comes up, hanging off the tip, swung over into the well.
func _show_fish(j: Jigger, tip: Vector3, delta: float) -> void:
	var on := j.state in ["on", "hang", "swing"]
	j.fish.visible = on
	if not on:
		return
	var t := Time.get_ticks_msec() * 0.001
	var kick := Basis(Vector3.UP, sin(t * 25.0) * 0.6) * Basis(Vector3.RIGHT, PI * 0.5)
	var hooked := j.at + (j.body.global_position - j.at) * 0.45
	if j.state == "swing":
		# up off the tip and over in an arc, down into the well
		var to := _well_mouth()
		if to == Vector3.INF:
			to = tip + Vector3(0.0, -1.0, 0.0)
		var k := clampf(j.swing_t / SWING, 0.0, 1.0)
		var at := hooked.lerp(to, smoothstep(0.0, 1.0, k))
		at.y += sin(k * PI) * 0.6
		j.fish.global_transform = Transform3D(kick, at)
		j.fish.visible = k < 0.97
		return
	j.fish.global_transform = Transform3D(kick, hooked)


func _jigger(id: int) -> Jigger:
	if _jiggers.has(id):
		return _jiggers[id]
	var j := Jigger.new()
	var model := Kit.make("jig")
	var rig := model.find_child("rig", true, false) as Node3D
	j.body = Node3D.new()
	j.body.top_level = true
	add_child(j.body)
	if rig:
		rig.get_parent().remove_child(rig)
		rig.owner = null
		rig.transform = Transform3D.IDENTITY         # (it hangs along -y off its tie, as it does off the tip)
		j.body.add_child(rig)
	model.free()
	j.fish = Kit._mackerel()
	j.fish.top_level = true
	j.fish.visible = false
	j.fish.scale = Vector3.ONE * 0.8
	add_child(j.fish)
	j.noise = ReelNoise.new()
	j.noise.top_level = true
	j.noise.volume_db = -8.0
	add_child(j.noise)
	_jiggers[id] = j
	return j


## The live well's mouth (world; INF: she hasn't one): where a mackerel's swung into.
func _well_mouth() -> Vector3:
	var lw: Node = (sea.get("boat") as Node).get("live_well")
	return lw.call("mouth") if lw != null else Vector3.INF


## Whether player `p` is close enough to the live well to swing a mackerel into it.
func _near_well(p: Node) -> bool:
	var m := _well_mouth()
	return m != Vector3.INF and (p as Node3D).global_position.distance_to(m) < WELL_REACH + 1.0 \
			and Vector2(m.x - (p as Node3D).global_position.x, m.z - (p as Node3D).global_position.z).length() < WELL_REACH


## The jig rod's tip in someone's hands (INF: they're not holding it).
func _tip(p: Node) -> Vector3:
	if p == null:
		return Vector3.INF
	var hands: Node = p.get("hands")
	var tip: Node3D = hands.call("tip") if hands else null
	return tip.global_position if tip else Vector3.INF


func _tip_height(p: Node) -> float:
	var tip := _tip(p)
	if tip == Vector3.INF:
		return 1.5
	return maxf(tip.y - float((sea.get("ocean") as Node).call("height_at", tip)), 0.2)


## The crank's turn on `p`'s jig rod (rad; crew/hands.gd turns it), and whether their jig's off the tip.
func crank_of(p: Node) -> float:
	var crew := sea.get("crew") as Node
	if p == crew.get("me"):
		return crank
	var j: Jigger = _jiggers.get(str(p.name).to_int())
	return j.crank if j else 0.0


func out_for(p: Node) -> bool:
	var crew := sea.get("crew") as Node
	if p == crew.get("me"):
		return active()
	var j: Jigger = _jiggers.get(str(p.name).to_int())
	return j != null and j.state != "up"


## Your jig's sinker (world; INF: it's on the tip), for the tests.
func jig_point() -> Vector3:
	var j: Jigger = _jiggers.get(Net.my_id())
	return j.at if j != null and active() else Vector3.INF


## Whether your rod tip's out over the water (not over her deck): at the rail.
func _over_water(p: Node) -> bool:
	var tip := _tip(p)
	if tip == Vector3.INF:
		return false
	var boat := sea.get("boat") as Node3D
	var spec: Dictionary = boat.get("spec")
	var at := boat.global_transform.affine_inverse() * tip
	var aft := (spec.get("transom", Vector3(0, 0, 7.0)) as Vector3).z
	return absf(at.x) > float(spec["beam"]) * 0.5 - 0.15 or at.z > aft - 0.1 or at.z < aft - float(spec["length"])


func _speed() -> float:
	var helm: Node = (sea.get("boat") as Node).get("helm")
	return float(helm.get("speed")) if helm else 0.0


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))
