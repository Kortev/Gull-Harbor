extends Node3D
## What's in your hands (crew/kit.gd: the knife, the gaff, the jig rod, the scoop, a bait), picked on the hotbar with
## 1-5 or the mouse wheel (the same key again: empty hands). You see it in first person, held out in front; everyone
## else sees it in your right glove (crew/player.gd sends which it is with your spot).
##
## Left mouse uses it. On something that takes it (anything with use_item(player, item, pressed) -> bool: a fish on
## deck takes the knife and the gaff, the chum bucket the scoop) that thing does the work; otherwise the item does its
## own: the jig rod jigs (boat/jig.gd), a full scoop winds up while you hold it and throws when you let go
## (boat/chum.gd). A trolling rod, the harpoon or the wheel in your hands, and the kit's put away.

const Kit := preload("res://crew/kit.gd")
const Hotbar := preload("res://ui/hotbar.gd")
const Sfx := preload("res://audio/sfx.gd")
## A scoop of chum: how long to wind it all the way up (s), and how far it goes from a flick to all you've got (m).
const WIND := 0.8
const SCOOP_THROW := Vector2(4.0, 22.0)

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


## Your hands are full of something bigger (a rod, the harpoon, the wheel) or you're ashore: the kit's put away.
func stowed() -> bool:
	var sea: Node = _sea()
	if sea == null:
		return true
	var id := str(player.name).to_int()
	var rods: Node = sea.get("rods")
	var landing: Node = sea.get("landing")
	var hold: Node = sea.get("fish_hold")
	return bool(player.get("steering")) or (rods != null and rods.call("held_by", id) != null) \
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
		_swing_kind = item
		_swing = 0.35
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
			_swing_kind = item
			_swing = 0.35         # (a swing at nothing)


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
		wind = 0.0


func _process(delta: float) -> void:
	var want := "" if stowed() else shown_item()
	if want != _shown:
		_show(want)
	if _winding:
		wind = minf(wind + delta / WIND, 1.0)
	_swing = maxf(_swing - delta, 0.0)
	if _view:
		_pose_view(delta)
	if _glove:
		var chum := _glove.find_child("Chum", true, false) as Node3D
		if chum:
			chum.visible = scoop_full if player.is_multiplayer_authority() else false
	if is_instance_valid(_bar):
		_bar.visible = not _hold_docked() and not bool(player.get("steering"))
		_bar.queue_redraw()


func _hold_docked() -> bool:
	var hold: Node = _sea().get("fish_hold") if _sea() else null
	return hold != null and bool(hold.get("docked"))


## The item held out in front of you, as you see it: bobbing as you walk, and making its move (a knife's stab, the
## gaff's swing, the scoop drawn back as you wind up a throw, the jig rod worked up and down).
func _pose_view(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var bob := Vector3(sin(t * 1.7) * 0.004, sin(t * 3.4) * 0.004, 0.0)
	var at := Vector3(0.0, 0.0, 0.0)
	var rot := Vector3.ZERO
	match _shown:
		"knife":
			rot = Vector3(0.35, 0.15, 0.0)
		"gaff":
			at = Vector3(-0.05, -0.1, 0.25)
			rot = Vector3(-0.2, 0.1, 0.0)
		"jig":
			var jig: Node = _sea().get("jig") if _sea() else null
			var lift := float(jig.get("lift")) if jig else 0.0
			at = Vector3(0.06, 0.02, 0.15)
			rot = Vector3(0.35 + 0.5 * lift, -0.35, 0.0)
		"scoop":
			at = Vector3(0.0, -0.04, 0.0)
			rot = Vector3(0.1 - 1.4 * wind, 0.0, 0.0)
			at.z += 0.15 * wind
		"bait":
			at = Vector3(-0.04, 0.02, 0.05)
			rot = Vector3(0.2, 0.6, 0.0)
	if _swing > 0.0:
		var k := sin(_swing / 0.35 * PI)
		match _swing_kind:
			"knife":
				at += Vector3(0.0, -0.05, -0.2) * k
				rot.x -= 0.5 * k
			"gaff":
				rot.x -= 0.9 * k
				at += Vector3(0.0, 0.05, -0.1) * k
			"scoop":
				rot.x -= 0.8 * k
				at += Vector3(0.0, -0.15, -0.1) * k
			_:
				at += Vector3(0.0, 0.0, -0.1) * k
	var goal := Transform3D(Basis.from_euler(rot), at + bob)
	_view.transform = _view.transform.interpolate_with(goal, minf(1.0, delta * 18.0))
	var chum := _view.find_child("Chum", true, false) as Node3D
	if chum:
		chum.visible = scoop_full


func _show(which: String) -> void:
	_shown = which
	for n: Node3D in [_view, _glove]:
		if is_instance_valid(n):
			n.queue_free()
	_view = null
	_glove = null
	if which.is_empty():
		return
	if player.is_multiplayer_authority():
		_view = Kit.make(which)
		_view.name = "Held"
		(player.get("hand") as Node3D).add_child(_view)
	var fore := (player.get("_parts") as Dictionary).get("fore_r") as Node3D
	if fore:
		_glove = Kit.make(which)
		_glove.name = "InGlove"
		_glove.position = Vector3(0.0, -0.38, 0.0)
		_glove.rotation = Vector3(-PI * 0.5, 0.0, 0.0)      # (the forearm hangs along -y: the item out ahead of the fist)
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
