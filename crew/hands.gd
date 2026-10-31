extends Node3D
## What's in your hands (crew/kit.gd: the knife, the gaff, the jig rod, the scoop, a bait), picked on the hotbar with
## 1-5 or the mouse wheel (the same key again: empty hands). You see it in first person, held out in front in your own
## gloves (both of them on the gaff and the scoop, your sleeves going back to your elbows); everyone else sees it in
## your right glove (crew/player.gd sends which it is with your spot).
##
## Left mouse uses it. On something that takes it (anything with use_item(player, item, pressed) -> bool: a fish on
## deck takes the knife and the gaff, the chum bucket the scoop) that thing does the work; otherwise the item does its
## own: the jig rod jigs (boat/jig.gd), a full scoop winds up while you hold it and throws when you let go
## (boat/chum.gd). A trolling rod, the harpoon or the wheel in your hands, and the kit's put away.
##
## In your own view each thing moves the way the job goes: the knife's stroke in and out while you bleed a fish, the
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
}
const TWO_HANDED: Array[String] = ["gaff", "scoop"]
const LEFT_ROLL := {"gaff": -1.2, "scoop": -0.9}
## Where your elbows are, from your eyes (m): your sleeves go back to them.
const ELBOWS := {"r": Vector3(0.42, -0.72, 0.06), "l": Vector3(-0.42, -0.72, 0.02)}
## How each item sits in the others' view of you, in your right glove: tipped up from along your forearm (radians),
## so the knife and the jig rod point out and up, the gaff and the scoop down toward the deck ahead, the bait hanging
## by its tail.
const IN_GLOVE := {"knife": 0.5, "gaff": -0.35, "jig": 0.95, "scoop": -0.2, "bait": -1.3}
## The one-off moves (s): a stab at nothing, the gaff's strike, a dip of the scoop, a throw.
const MOVES := {"knife": 0.3, "gaff": 0.5, "scoop": 0.55, "throw": 0.5}
## The jig hanging off the rod tip on its bit of line (m), swinging.
const RIG := 0.38

var player: Node3D            # crew/player.gd
## What you've picked (Kit.ITEMS, "" empty-handed), and whether there's chum in your scoop.
var item := ""
var scoop_full := false
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


## The item you're seen with (yours, or what a crewmate's peer last said).
func shown_item() -> String:
	return item if player.is_multiplayer_authority() else str(player.get("_net_item"))


## Your hands are full of something bigger (a rod, the harpoon, the wheel), you're in the sea or up a ladder, or
## you're ashore: the kit's put away.
func stowed() -> bool:
	var sea: Node = _sea()
	if sea == null:
		return true
	var id := str(player.name).to_int()
	var rods: Node = sea.get("rods")
	var landing: Node = sea.get("landing")
	var hold: Node = sea.get("fish_hold")
	return bool(player.get("steering")) or int(player.get("mode")) != 0 \
			or (rods != null and rods.call("held_by", id) != null) \
			or (landing != null and int(landing.get("harpoon_holder")) == id) \
			or (hold != null and bool(hold.get("docked")))


func pick(which: String) -> void:
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
		at = wrapi(at + (1 if event.is_action_pressed("slot_next") else -1), 0, Kit.ITEMS.size() + 1)
		pick("" if at == 0 else Kit.ITEMS[at - 1])
		return
	if stowed() or item.is_empty():
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


func _move(kind: String) -> void:
	_swing_kind = kind
	_swing = float(MOVES.get(kind, 0.35))


func _release() -> void:
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


func _process(delta: float) -> void:
	var want := "" if stowed() else shown_item()
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
	var hold: Node = _sea().get("fish_hold") if _sea() else null
	return hold != null and bool(hold.get("docked"))


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
	match _shown:
		"knife":
			if working:
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
			# snatched up (and the tip drawn back to you), let fall; a knock jerks it down
			rot.x += 0.6 * lift
			at += Vector3(0.0, 0.04 * lift, 0.05 * maxf(lift, 0.0))
			if jig and float(jig.get("_held")) > 0.28 and str(jig.get("state")) != "up":
				at += Vector3(sin(t * 24.0), cos(t * 31.0), 0.0) * 0.003      # (winding in: the rod shivers)
		"scoop":
			# wound up: drawn back and up over your shoulder
			var w := smoothstep(0.0, 1.0, wind)
			at += Vector3(0.08, 0.14, 0.22) * w
			rot += Vector3(0.9, -0.25, -0.35) * w
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
			out = bool(jig.call("active")) if player.is_multiplayer_authority() \
					else (int(player.get("_net_act")) & 2) != 0         # (player.gd's ACT_JIG)
		rig.visible = not out
		if not out:
			_hang(rig, delta)
	var tail := held.find_child("tail", true, false) as Node3D
	if tail:
		var kick := 0.25 + 0.75 * maxf(0.0, sin(t * 1.3))
		tail.rotation = Vector3(0.0, sin(t * 17.0) * 0.55 * kick, 0.0)


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


## The jig rod's tip as drawn (boat/jig.gd hangs its line off it): in your first-person hands, or in the glove
## everyone else sees. Null if the jig rod isn't in your hands.
func tip() -> Node3D:
	if _shown != "jig":
		return null
	var held: Node3D = _view if _view else _glove
	return held.find_child("tip", true, false) as Node3D if held else null


func _sea() -> Node:
	var boat: Node = player.get("boat")
	return boat.get("sea") if boat else null
