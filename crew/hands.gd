extends Node3D
## What's in your hands (crew/kit.gd: the knife, the gaff, the jig rod, the scoop, a bait), picked on the hotbar with
## 1-4 or the mouse wheel (the same key again: empty hands). You see it in first person, held out in front in your own
## gloves (both of them on the gaff and the scoop, your left on the jig reel's crank, your sleeves going back to your
## elbows); everyone else sees it in your right glove (crew/player.gd sends which it is with your spot).
##
## A bait (slot 5) is a real fish: netted out of the live well (E on its open lid: boat/live_well.gd), a live one
## kicking in your fist or a dead one limp, and it stays in your hand till it's hooked on a rod (rods/rig.gd) or put
## back in the well; you can't put it in your pocket and pick up a knife.
##
## Left mouse uses it. On something that takes it (anything with use_item(player, item, pressed) -> bool: a fish on
## deck takes the knife and the gaff, the chum bucket the scoop) that thing does the work; otherwise the item does its
## own: the jig rod jigs (boat/jig.gd), a full scoop winds up while you hold it and throws when you let go
## (boat/chum.gd). A trolling rod, the harpoon or the wheel in your hands, and the kit's put away.
##
## The tin whistle (slot 6): hold left mouse and it sounds, up to your lips; look higher for a higher note. Every note
## is one of the chord the band's playing (audio/music.gd's whistle_note()) and starts on its next eighth, so whatever
## you play sits in the music; everyone aboard hears it, from where you're standing.
##
## Empty-handed, left mouse is your bare hands on what you look at (a fish's tail to pump it, its body to pin it down):
## your gloves come up into view to do it.
##
## In your own view each thing moves the way the job goes (a fish on deck says what you're doing to it in your player's
## "work" meta: tuna/handling.gd): the knife's point pushed down into the brain and twisted, the blade sinking into the
## cut as deep as you hold it, drawn along the belly; your gloves pressing a fish down, shoving its tail over; the
## gaff's swing and its hook dug in as you drag, the jig rod snatched up and let fall (and jerked down by a knock),
## the jig swinging off its tip till you let it go, the scoop dipped, drawn back and flung, the mackerel kicking in
## your fist. It all bobs with your steps, lags your look a touch and rides the boat's lurches, and changing it is a
## move: the old thing goes down out of sight, the new one comes up.

const Kit := preload("res://crew/kit.gd")
const Hotbar := preload("res://ui/hotbar.gd")
const Sfx := preload("res://audio/sfx.gd")
## A scoop of chum: how long to wind it all the way up (s), and how far it goes from a flick to all you've got (m).
const WIND := 0.8
const SCOOP_THROW := Vector2(4.0, 22.0)
## How each item's held in your own view: where (from player.hand, m) and turned how (euler: + x tips its working end
## up, + y swings it left, + z rolls it), and the two-handed ones (your left glove on its "grip_l", rolled `LEFT_ROLL`).
const HOLDS := {
	"knife": [Vector3(-0.1, 0.08, -0.08), Vector3(0.35, 0.4, -0.1)],
	"gaff": [Vector3(0.0, -0.05, 0.1), Vector3(0.3, 0.62, 0.05)],
	"jig": [Vector3(-0.05, 0.05, 0.08), Vector3(0.75, 0.16, -0.12)],
	"scoop": [Vector3(0.0, -0.02, 0.1), Vector3(-0.12, 0.32, 0.0)],
	"bait": [Vector3(-0.1, 0.09, -0.12), Vector3(0.12, 1.3, 0.05)],
	"dead": [Vector3(-0.1, 0.09, -0.12), Vector3(0.12, 1.3, 0.05)],
	"bare": [Vector3(-0.08, -0.04, -0.1), Vector3(-0.5, 0.15, 0.0)],
	"whistle": [Vector3(-0.04, -0.02, -0.06), Vector3(0.25, 0.55, -0.2)],
}
const TWO_HANDED: Array[String] = ["gaff", "scoop"]
const LEFT_ROLL := {"gaff": -1.2, "scoop": -0.9}
## Where your elbows are, from your eyes (m): your sleeves go back to them.
const ELBOWS := {"r": Vector3(0.42, -0.72, 0.06), "l": Vector3(-0.42, -0.72, 0.02)}
## How each item sits in the others' view of you, in your right glove: tipped up from along your forearm (radians),
## so the knife and the jig rod point out and up, the gaff and the scoop down toward the deck ahead, the bait hanging
## by its tail.
const IN_GLOVE := {"knife": 0.5, "gaff": -0.35, "jig": 0.95, "scoop": -0.2, "bait": -1.3, "dead": -1.3,
		"whistle": 0.4}
## The whistle: how loud (dB), how far it carries (m to half), how far up or down you look for its lowest and highest
## notes (radians), and how long it takes to bring it up to your lips (s).
const PIPE_DB := -6.0
const PIPE_UNIT := 5.0
const PIPE_LOOK := Vector2(-0.5, 0.8)
const PIPE_UP := 0.12
## The one-off moves (s): a stab at nothing, the gaff's strike, a dip of the scoop, a throw.
const MOVES := {"knife": 0.3, "gaff": 0.5, "scoop": 0.55, "throw": 0.5}
## The jig hanging off the rod tip on its bit of line (m), swinging.
const RIG := 0.38

var player: Node3D            # crew/player.gd
## What you've picked (Kit.ITEMS, "" empty-handed), and whether there's chum in your scoop.
var item := ""
var scoop_full := false
## A scoop of ice in the scoop, off the bin on the float (sea/places.gd), for her fish box.
var scoop_ice := false
## The mackerel in your fist with `item` "bait": "live" or "dead" ("" none), and whether you're hooking it onto a rod
## right now (rods/rig.gd has it then: your view of it's put away).
var bait := ""
var rigging := false
## How far a throw's wound up, 0..1 (the scoop; rods.gd winds a cast the same way on its own).
var wind := 0.0
var _winding := false
## The thing that took your last press (it gets the release too), and the move you're making with the item (s left).
var _target: Node
var _swing := 0.0
var _swing_kind := ""
## The kit as you see it (first person) and as the others do (in the glove), rebuilt when the item changes.
var _view: Node3D
var _glove: Node3D
var _shown := "-"
var _bar: Control
## Changing what's in your hands: the old thing goes down out of sight, then the new one comes up (SWAP s each way).
const SWAP := 0.16
var _lower := 0.0             # 0 held up .. 1 out of sight
## Your steps (a phase, and how fast you're going 0..1), and the hand lagging your look and riding her lurches:
## turned (`_lag`, radians) and pushed about on a spring (`_sway`, m, and its speed).
var _step := 0.0
var _pace := 0.0
var _lag := Vector3.ZERO
var _sway := Vector3.ZERO
var _sway_v := Vector3.ZERO
var _acc := Vector3.ZERO
var _was_local := Vector3.INF
var _was_cam: Transform3D
var _was_vel := Vector3.ZERO
## Each hanging jig's end (its sinker, global) this frame and last (rig node -> [now, before]).
var _rigs := {}
## The whistle: blowing it (left mouse held), the note sounding (midi, 0: none), the next one and when it's due
## (Music's time), how far up to your lips it is (0..1), and its sound.
var blowing := false
var note := 0
var _next_note := 0
var _next_at := INF
var _blow := 0.0
var _pipe: AudioStreamPlayer3D


func _ready() -> void:
	if player.is_multiplayer_authority():
		_bar = Hotbar.new()
		_bar.hands = self
		var crew := player.get_parent()
		var hud: Node = crew.get("hud") if crew else null
		if hud:
			hud.add_child(_bar)


func _exit_tree() -> void:
	if is_instance_valid(_bar):
		_bar.queue_free()


## The item you're seen with (yours, or what a crewmate's peer last said): a dead bait's its own thing.
func shown_item() -> String:
	return net_item() if player.is_multiplayer_authority() else str(player.get("_net_item"))


func net_item() -> String:
	return "dead" if item == "bait" and bait == "dead" else item


## The mackerel in your fist ("live", "dead"; "" none).
func carrying() -> String:
	return bait if item == "bait" else ""


## A mackerel into your fist (`kind`: "live", "dead"), out of the well; "" and it's gone (hooked on, or back in).
func carry(kind: String) -> void:
	_release()
	bait = kind
	item = "bait" if not kind.is_empty() else ""
	wind = 0.0
	_winding = false
	if not kind.is_empty():
		Sfx.play_point(self, player.global_position + Vector3.UP, "dock.slap", 0.3, 2.0)


## Your hands are full of something bigger (a rod, the harpoon, the wheel), or you're in the sea or up a ladder:
## the kit's put away.
func stowed() -> bool:
	var sea: Node = _sea()
	if sea == null:
		return true
	var id := str(player.name).to_int()
	var rods: Node = sea.get("rods")
	var landing: Node = sea.get("landing")
	return bool(player.get("steering")) or int(player.get("mode")) != 0 \
			or (rods != null and rods.call("held_by", id) != null) \
			or (landing != null and int(landing.get("harpoon_holder")) == id)


func pick(which: String) -> void:
	if not carrying().is_empty():
		# (a fish in your fist: it goes on a hook or back in the well, not in your pocket)
		_note("A mackerel in your hand: hook it on a rod, or back in the live well")
		return
	if which == "bait":
		_note("Net one out of the live well: E on its lid")
		return
	if which == item:
		which = ""            # (the same again: put it away)
	if which != item:
		_release()
		item = which
		wind = 0.0
		_winding = false
		Sfx.play_point(self, player.global_position + Vector3.UP, "kit.switch", 0.6, 1.4)


func _live() -> bool:
	return bool(player.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not player.is_multiplayer_authority() or not _live():
		return
	for i in Kit.ITEMS.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			pick(Kit.ITEMS[i])
			return
	# (with a fish on, the wheel's the drag: rods.gd)
	if (event.is_action_pressed("slot_next") or event.is_action_pressed("slot_prev")) and not _fighting():
		var at := Kit.ITEMS.find(item) + 1           # (0: empty-handed)
		var step := 1 if event.is_action_pressed("slot_next") else -1
		at = wrapi(at + step, 0, Kit.ITEMS.size() + 1)
		if at > 0 and Kit.ITEMS[at - 1] == "bait":
			at = wrapi(at + step, 0, Kit.ITEMS.size() + 1)      # (a bait's netted out of the well, not picked)
		pick("" if at == 0 else Kit.ITEMS[at - 1])
		return
	if stowed() or rigging:          # (empty-handed too: your bare hands on a fish)
		return
	if event.is_action_pressed("use_primary"):
		press(true)
	elif event.is_action_released("use_primary"):
		press(false)


## Whether you've a rod in your hands with a fish on it.
func _fighting() -> bool:
	var rods: Node = _sea().get("rods") if _sea() != null else null
	var r: Node = rods.call("held_by", str(player.name).to_int()) if rods != null else null
	return r != null and bool(r.get("hooked"))


## Left mouse down (`down`) or up with the item in your hands (tests call it too).
func press(down: bool) -> void:
	if not down:
		_release()
		return
	var t: Node = player.call("looking_at")
	if t != null and t.has_method("use_item") and bool(t.call("use_item", player, item, true)):
		_target = t
		if not item.is_empty():
			_move(item)
		return
	match item:
		"jig":
			var jig: Node = _sea().get("jig")
			if jig:
				jig.call("work", player)
		"scoop":
			if scoop_full:
				_winding = true
		"knife", "gaff":
			_move(item)           # (a swing at nothing)
			player.call("gesture", "reach")
		"whistle":
			blowing = true


func _move(kind: String) -> void:
	_swing_kind = kind
	_swing = float(MOVES.get(kind, 0.35))


func _release() -> void:
	if blowing:
		blowing = false
		_next_at = INF
		_play_note(0)
	if is_instance_valid(_target):
		_target.call("use_item", player, item, false)
	_target = null
	if _winding:
		_winding = false
		var chum: Node = _sea().get("chum") if _sea() else null
		if chum and scoop_full:
			var cam := player.get("cam") as Camera3D
			var look := -cam.global_basis.z
			chum.call("throw", player, Vector3(look.x, 0.0, look.z).normalized(),
					lerpf(SCOOP_THROW.x, SCOOP_THROW.y, wind))
			scoop_full = false
			player.call("gesture", "throw")
			_move("throw")
		wind = 0.0


## What a fish on deck says you're doing to it with your hands ({kind, k}: tuna/handling.gd's acts; empty: nothing).
func _work() -> Dictionary:
	return player.get_meta("work", {}) if player.has_meta("work") else {}


func _process(delta: float) -> void:
	_pipe_tick(delta)
	var want := "" if stowed() else shown_item()
	if want.is_empty() and player.is_multiplayer_authority() and str(_work().get("kind", "")) in ["pin", "pump"]:
		want = "bare"          # (your gloves up to do it)
	# (in your own view the change is a move: down with the old, up with the new; the others see it in the glove)
	if want != _shown:
		if not player.is_multiplayer_authority() or _view == null or _shown == "-":
			_lower = 1.0 if player.is_multiplayer_authority() and not want.is_empty() else 0.0
			_show(want)
		else:
			_lower = minf(_lower + delta / SWAP, 1.0)
			if _lower >= 1.0:
				_show(want)
	elif _lower > 0.0:
		_lower = maxf(_lower - delta / SWAP, 0.0)
	if _winding:
		wind = minf(wind + delta / WIND, 1.0)
	_swing = maxf(_swing - delta, 0.0)
	if player.is_multiplayer_authority():
		_motion(delta)
	if _view:
		_view.transform = _view.transform.interpolate_with(_goal(), minf(1.0, delta * 22.0))
		_view.visible = not rigging        # (rods/rig.gd holds it up to hook it)
		_aim_sleeves()
		var chum := _view.find_child("Chum", true, false) as Node3D
		if chum:
			chum.visible = scoop_full
	if _glove:
		var chum := _glove.find_child("Chum", true, false) as Node3D
		if chum:
			chum.visible = scoop_full if player.is_multiplayer_authority() else false
	for held: Node3D in [_view, _glove]:
		if held:
			_alive(held, delta)
	if is_instance_valid(_bar):
		_bar.visible = not _hold_docked() and not bool(player.get("steering"))
		_bar.queue_redraw()


func _hold_docked() -> bool:
	return false        # (the kit's yours at the dock too: the scoop for the ice)


## How you're moving, for the bob: your steps over her deck (a dip each step, a sway each stride), your look turning
## (the thing in your hands a touch behind it), and her lurches (it swings against them on a spring and settles).
func _motion(delta: float) -> void:
	if delta <= 0.0:
		return
	var cam := player.get("cam") as Camera3D
	if cam == null:
		return
	var local: Vector3 = player.call("local_position")
	var g := cam.global_transform
	if _was_local == Vector3.INF:
		_was_local = local
		_was_cam = g
	var walked := local - _was_local
	walked.y = 0.0
	var speed := walked.length() / delta if walked.length() < 0.5 else 0.0          # (a jump: placed somewhere)
	_was_local = local
	_pace = move_toward(_pace, clampf(speed / 4.0, 0.0, 1.0), delta * 5.0)
	_step += delta * speed / 0.7 * PI                                               # (a step every 0.7 m)
	# the look turning: the hand behind it
	var turn := (_was_cam.basis.orthonormalized().inverse() * g.basis.orthonormalized()).get_euler() / delta
	turn = turn.clamp(Vector3.ONE * -8.0, Vector3.ONE * 8.0)
	_lag = _lag.lerp(Vector3(-turn.x * 0.012, -turn.y * 0.018, 0.0), 1.0 - exp(-delta * 9.0))
	# her lurches (and your own stops and starts): the hand swings the other way and springs back
	var vel := (g.origin - _was_cam.origin) / delta
	_was_cam = g
	var acc := g.basis.orthonormalized().inverse() * ((vel - _was_vel) / delta)
	_was_vel = vel
	if acc.length() > 40.0:
		acc = Vector3.ZERO                    # (placed somewhere: no lurch)
	_acc = _acc.lerp(acc, 1.0 - exp(-delta * 8.0))
	const K := 70.0
	_sway_v += (-_acc * 0.012 * K - _sway * K - _sway_v * 12.0) * delta
	_sway += _sway_v * delta
	_sway = _sway.limit_length(0.05)


## Where the item in your view should be this frame: its hold, the bob and sway, what you're doing with it, a move,
## and how far it's gone down for a change.
func _goal() -> Transform3D:
	var t := Time.get_ticks_msec() * 0.001
	var hold: Array = HOLDS.get(_shown, [Vector3.ZERO, Vector3.ZERO])
	var at: Vector3 = hold[0]
	var rot: Vector3 = hold[1]
	# a step's dip and a stride's sway as you walk; a breath standing
	at += Vector3(sin(_step) * 0.014, -absf(cos(_step)) * 0.018 + 0.009, 0.0) * _pace
	at.y += sin(t * 1.6) * 0.003 * (1.0 - _pace)
	rot.z += sin(_step) * 0.035 * _pace
	at += _sway + Vector3(_lag.y * -0.25, _lag.x * 0.25, 0.0)
	rot += _lag
	var working := is_instance_valid(_target) and _swing <= 0.0
	var work := _work()
	var wk := clampf(float(work.get("k", 0.0)), 0.0, 1.0)
	match _shown:
		"knife":
			if str(work.get("kind", "")) == "spike":
				# the point brought down onto his head and pushed in, a twist at the end
				var push := smoothstep(0.0, 1.0, wk)
				at += Vector3(0.02, 0.02 - 0.09 * push, -0.12 - 0.05 * push)
				rot += Vector3(-1.25, 0.1, 0.3 + 0.7 * smoothstep(0.75, 1.0, wk))
			elif str(work.get("kind", "")) == "cut":
				# the blade in under the fin, sinking as deep as you hold it, sawing a little
				at += Vector3(-0.02, 0.0 - 0.1 * wk, -0.12 - 0.05 * wk) + Vector3(sin(t * 15.0), 0.0, 0.0) * 0.006
				rot += Vector3(-0.95 - 0.25 * wk, 0.45, 0.9)
			elif str(work.get("kind", "")) == "gut":
				# drawn along the belly, tip down, from his head toward his tail
				at += Vector3(0.12 - 0.26 * wk, -0.07, -0.14)
				rot += Vector3(-1.0, 1.1, 0.6)
			elif working:
				# down at the fish, the blade worked in and drawn out, again and again
				var k := fmod(t, 0.4) / 0.4
				var stab := smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.5, 1.0, k))
				at += Vector3(0.0, 0.04, -0.1) + Vector3(-0.02, -0.06, -0.12) * stab
				rot += Vector3(-0.8 - 0.4 * stab, 0.25, 0.4 + 0.2 * stab)
		"gaff":
			if working:
				# the hook dug in down on her deck, hauled back toward you, tugging
				at += Vector3(-0.04, 0.0, 0.06)
				rot += Vector3(-0.32 + sin(t * 6.5) * 0.04, -0.3, -0.05)
		"jig":
			var jig: Node = _sea().get("jig") if _sea() else null
			var lift := float(jig.get("lift")) if jig else 0.0
			# with it over the side, the rod brought in across you, the reel up where you can see your hand on the crank
			if jig and bool(jig.call("out_for", player)):
				at += Vector3(-0.1, 0.06, -0.06)
				rot += Vector3(-0.2, 0.25, 0.25)
			# snatched up (and the tip drawn back to you), let fall; a knock jerks it down
			rot.x += 0.6 * lift
			at += Vector3(0.0, 0.04 * lift, 0.05 * maxf(lift, 0.0))
			if jig and float(jig.get("_held")) > 0.28 and str(jig.get("state")) != "up":
				at += Vector3(sin(t * 24.0), cos(t * 31.0), 0.0) * 0.003      # (winding in: the rod shivers)
		"bare":
			if str(work.get("kind", "")) == "pin":
				# both hands flat on him, leaning your weight on, holding against his kicks
				at += Vector3(0.0, -0.08, -0.08) + Vector3(sin(t * 9.0), cos(t * 7.0), 0.0) * 0.004
				rot += Vector3(-0.35, 0.0, 0.0)
			else:
				# a shove of his tail over, and let go
				var shove := sin(wk * PI)
				at += Vector3(-0.12 * shove, -0.04 - 0.05 * shove, -0.1)
				rot += Vector3(-0.2, 0.3 * shove, 0.0)
		"scoop":
			# wound up: drawn back and up over your shoulder
			var w := smoothstep(0.0, 1.0, wind)
			at += Vector3(0.08, 0.14, 0.22) * w
			rot += Vector3(0.9, -0.25, -0.35) * w
		"whistle":
			# up to your lips, the end pointed down ahead, your fingers working the holes
			var b := smoothstep(0.0, 1.0, _blow)
			# (your hand from low on the right to just under your chin in the middle: the mouthpiece at your lips)
			at += Vector3(-0.19, 0.17, 0.18) * b + Vector3(0.0, sin(t * 7.0), 0.0) * 0.002 * b
			rot += Vector3(-0.75, -0.55, 0.25) * b
		"bait":
			# it kicks in your fist now and then
			var kick := maxf(0.0, sin(t * 1.3))
			rot.y += sin(t * 13.0) * 0.12 * kick
			rot.x += sin(t * 9.0) * 0.04 * kick
	if _swing > 0.0:
		var p := 1.0 - _swing / float(MOVES.get(_swing_kind, 0.35))
		var arc := sin(p * PI)
		match _swing_kind:
			"knife":
				# a quick stab out ahead
				at += Vector3(-0.03, -0.03, -0.2) * arc
				rot += Vector3(-0.3, 0.1, 0.2) * arc
			"gaff":
				# up, then the hook brought down hard and in, then back
				var up := smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.3, 0.55, p))
				var down := smoothstep(0.3, 0.55, p) * (1.0 - smoothstep(0.6, 1.0, p))
				rot.x += 0.45 * up - 0.75 * down
				at += Vector3(0.0, 0.05 * up, -0.14 * down)
			"scoop":
				# down into the bucket and up full
				at += Vector3(0.0, -0.18, -0.06) * arc
				rot += Vector3(-0.85, 0.0, 0.0) * arc
			"throw":
				# flung out, the cup tipped over to send it all, and back
				var out := sin(minf(p * 1.6, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.55, 1.0, p))
				var tip := smoothstep(0.15, 0.45, p) * (1.0 - smoothstep(0.65, 1.0, p))
				at += Vector3(-0.04, 0.06, -0.26) * out
				rot += Vector3(0.35 * out - 0.4 * tip, 0.1 * out, 1.5 * tip)
	# (going down out of sight or coming back up)
	var low := smoothstep(0.0, 1.0, _lower)
	at += Vector3(0.06, -0.4, 0.12) * low
	rot += Vector3(-0.9, -0.2, -0.3) * low
	return Transform3D(Basis.from_euler(rot), at)


## Your sleeves from your wrists back to your elbows, wherever your hands have got to.
func _aim_sleeves() -> void:
	var cam := player.get("cam") as Camera3D
	if cam == null:
		return
	for g: Node in _view.find_children("Glove*", "Node3D", true, false):
		var sleeve := g.get_node_or_null("Sleeve") as Node3D
		if sleeve == null:
			continue
		var elbow := cam.global_transform * (ELBOWS["l" if g.name == "GloveL" else "r"] as Vector3)
		var from := sleeve.global_position
		if from.distance_squared_to(elbow) > 0.0001:
			var up := cam.global_basis.y
			if absf((elbow - from).normalized().dot(up)) > 0.98:
				up = cam.global_basis.z
			sleeve.look_at(elbow, up)


## The live bits of whatever's held (yours or a crewmate's): the jig swinging off the rod tip until it's let go (then
## boat/jig.gd draws the line), the mackerel's tail kicking.
func _alive(held: Node3D, delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var rig := held.find_child("rig", true, false) as Node3D
	if rig:
		var jig: Node = _sea().get("jig") if _sea() else null
		var out := false
		if jig:
			out = bool(jig.call("out_for", player))         # (off the tip: boat/jig.gd draws it from there)
		rig.visible = not out
		if not out:
			_hang(rig, delta)
	var tail := held.find_child("tail", true, false) as Node3D
	if tail and _shown != "dead":
		var kick := 0.25 + 0.75 * maxf(0.0, sin(t * 1.3))
		tail.rotation = Vector3(0.0, sin(t * 17.0) * 0.55 * kick, 0.0)
	# the jig reel's crank, turned by the line wound in (boat/jig.gd), your left glove on its knob going round with it
	var crank := held.find_child("crank", true, false) as Node3D
	if crank:
		var jig2: Node = _sea().get("jig") if _sea() else null
		crank.rotation = Vector3(-float(jig2.call("crank_of", player)) if jig2 else 0.0, 0.0, 0.0)
		var lg := held.find_child("GloveL", true, false) as Node3D
		if lg:
			lg.global_basis = held.global_basis * Basis(Vector3.UP, PI * 0.5)


## A jig hanging off the tip on RIG of line: its end a pendulum (where it was, carried on, pulled down, kept on the
## line), the rig turned to hang toward it.
func _hang(rig: Node3D, delta: float) -> void:
	var top := rig.global_position
	var was: Array = _rigs.get(rig, [])
	var end: Vector3
	if was.is_empty() or (was[0] as Vector3).distance_to(top) > RIG * 3.0:
		end = top + Vector3.DOWN * RIG
		was = [end, end]
	else:
		var now: Vector3 = was[0]
		end = now + (now - (was[1] as Vector3)) * 0.97 + Vector3.DOWN * 9.8 * delta * delta
		end = top + (end - top).normalized() * RIG
		was = [end, now]
	_rigs[rig] = was
	var down := (end - top).normalized()
	var side := down.cross(Vector3.FORWARD)
	if side.length() < 0.1:
		side = down.cross(Vector3.RIGHT)
	side = side.normalized()
	rig.global_basis = Basis(side, -down, side.cross(-down)).scaled(rig.global_basis.get_scale())


func _show(which: String) -> void:
	_shown = which
	for n: Node3D in [_view, _glove]:
		if is_instance_valid(n):
			n.queue_free()
	_view = null
	_glove = null
	_rigs.clear()
	if which.is_empty():
		return
	if player.is_multiplayer_authority() and which == "bare":
		# just your gloves, side by side, palms down
		_view = Node3D.new()
		_view.name = "Held"
		(player.get("hand") as Node3D).add_child(_view)
		var r := Kit.glove("r")
		r.rotation = Vector3(0.0, 0.0, 1.3)
		_view.add_child(r)
		var l := Kit.glove("l")
		l.position = Vector3(-0.26, 0.0, 0.02)
		l.rotation = Vector3(0.0, 0.0, -1.3)
		_view.add_child(l)
		_view.transform = _goal()
		for mi in _view.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).layers = 1 << 18
		return
	if player.is_multiplayer_authority():
		_view = Kit.make(which)
		_view.name = "Held"
		(player.get("hand") as Node3D).add_child(_view)
		_view.add_child(Kit.glove("r"))
		var grip := _view.find_child("grip_l", true, false) as Node3D
		if grip and which in TWO_HANDED:
			var left := Kit.glove("l")
			left.rotation = Vector3(0.0, 0.0, float(LEFT_ROLL.get(which, 0.0)))
			grip.add_child(left)
		# the jig rod: your left hand on the reel's crank knob, which goes round on the crank
		var knob := _view.find_child("knob", true, false) as Node3D
		var crank := _view.find_child("crank", true, false) as Node3D
		if knob and crank:
			knob.reparent(crank)
			knob.add_child(Kit.glove("l"))
		_view.transform = _goal()            # (it comes up from out of sight, not from wherever)
		for mi in _view.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).layers = 1 << 18          # (yours alone: the others see the glove)
	var fore := (player.get("_parts") as Dictionary).get("fore_r") as Node3D
	if fore:
		_glove = Kit.make(which)
		_glove.name = "InGlove"
		_glove.position = Vector3(0.0, -0.38, 0.0)
		# (the forearm hangs along -y: the item out ahead of the fist, tipped up or down from there)
		_glove.rotation = Vector3(-PI * 0.5 + float(IN_GLOVE.get(which, 0.0)), 0.0, 0.0)
		fore.add_child(_glove)
		if player.is_multiplayer_authority():
			for mi in _glove.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).layers = 1 << 19      # (your own camera leaves it out, as it does your body)


## The whistle: while you blow, the note you're looking at (one of the band's chord), changed on its next eighth;
## let go and it stops.
func _pipe_tick(delta: float) -> void:
	_blow = move_toward(_blow, 1.0 if (blowing and item == "whistle") or note > 0 else 0.0, delta / PIPE_UP)
	if is_instance_valid(_glove) and _shown == "whistle":
		# (as the others see you: tipped up toward your face while it sounds)
		_glove.rotation.x = -PI * 0.5 + float(IN_GLOVE["whistle"]) - 1.5 * _blow
	if not blowing or not player.is_multiplayer_authority():
		return
	var music: Node = get_node_or_null("/root/Music")
	var cam := player.get("cam") as Camera3D
	if music == null or cam == null:
		return
	var look := asin(clampf(-cam.global_basis.z.y, -1.0, 1.0))
	var want := int(music.call("whistle_note", inverse_lerp(PIPE_LOOK.x, PIPE_LOOK.y, look)))
	if want == note:
		_next_note = 0                 # (back to the note sounding before the next one was due: it stays)
		_next_at = INF
	elif want != _next_note:
		_next_note = want
		_next_at = float(music.call("next_tick", 2))
	if float(music.call("now")) >= _next_at - 0.008:
		_next_at = INF
		_play_note(_next_note)
		_next_note = 0


## Sounds note `m` (0: stops it, short) here, and on everyone else's machine.
func _play_note(m: int) -> void:
	note = m
	_sound(m)
	if Net.in_session():
		_pipe_note.rpc(m)


@rpc("any_peer", "call_remote", "reliable")
func _pipe_note(m: int) -> void:
	if multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		note = m
		_sound(m)


func _sound(m: int) -> void:
	if _pipe == null:
		_pipe = AudioStreamPlayer3D.new()
		_pipe.name = "Whistle"
		_pipe.bus = &"Effects" if AudioServer.get_bus_index(&"Effects") >= 0 else &"Master"
		_pipe.unit_size = PIPE_UNIT
		_pipe.position = Vector3(0.0, 1.55, 0.0)
		player.add_child(_pipe)
	if m <= 0:
		if _pipe.playing:
			var tw := create_tween()
			tw.tween_property(_pipe, "volume_db", -40.0, 0.06)
			tw.tween_callback(_pipe.stop)
		return
	var music: Node = get_node_or_null("/root/Music")
	_pipe.stream = music.call("note_stream", m) if music != null else null
	_pipe.volume_db = PIPE_DB
	if _pipe.stream != null:
		_pipe.play()


## The jig rod's tip as drawn (boat/jig.gd hangs its line off it): in your first-person hands, or in the glove
## everyone else sees. Null if the jig rod isn't in your hands.
func tip() -> Node3D:
	if _shown != "jig":
		return null
	var held: Node3D = _view if _view else _glove
	return held.find_child("tip", true, false) as Node3D if held else null


## Where the jig hanging off the tip has swung to (global; INF: none), and set where it hangs from (boat/jig.gd: it's
## wound back up to the tip from there, and swings on from there).
func rig_end() -> Vector3:
	var held: Node3D = _view if _view else _glove
	var rig := held.find_child("rig", true, false) as Node3D if held else null
	var was: Array = _rigs.get(rig, []) if rig else []
	return was[0] if not was.is_empty() else Vector3.INF


func seed_rig(at: Vector3) -> void:
	for held: Node3D in [_view, _glove]:
		var rig := held.find_child("rig", true, false) as Node3D if held else null
		if rig:
			var end := rig.global_position + (at - rig.global_position).normalized() * RIG
			_rigs[rig] = [end, end]


func _note(text: String) -> void:
	if not player.is_multiplayer_authority():
		return
	var crew := player.get_parent()
	var hud: Node = crew.get("hud") if crew else null
	if hud:
		hud.call("notify", text)


func _sea() -> Node:
	var boat: Node = player.get("boat")
	return boat.get("sea") if boat else null
