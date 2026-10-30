extends Node3D
## Jigging for mackerel with the light jig rod in your hands (crew/hands.gd's kit, key 3): a string of little feathered
## hooks over the side. Stand at the rail, rod out over the water:
##   - left mouse: let the jig go; it sinks (the reel ticking as line goes)
##   - tap left mouse: work it, the rod tip snatched up and let fall
##   - a knock on the fall: the tip jerks down and your view with it. Tap again, quick, to set the hook; too slow and
##     it's gone
##   - hold left mouse: wind it up; with a mackerel on, it comes up wriggling and you swing it aboard, into the live
##     well (boat/fish_hold.gd: you need the well, bought at the dock, to keep them; without it it goes back)
## Not while she's under way (JIG_SPEED): the jig streams out behind her and nothing takes it. A live mackerel's the
## best bait there is (rods.gd).
##
## The jigging is yours (on your machine: what you see and feel); each mackerel is the host's to give
## (_ask_mackerel), and everyone sees it come up on your rod (_caught). The others see your line go down and you
## working the rod (crew/player.gd's ACT_JIG).

const Sfx := preload("res://audio/sfx.gd")
const Kit := preload("res://crew/kit.gd")
const FishHold := preload("res://boat/fish_hold.gd")
## The fastest she can be going (m/s), and the quickest the host gives one peer another mackerel (s).
const JIG_SPEED := 1.5
const EVERY := 2.0
## How deep the jig goes (m), how fast it sinks and comes up (m/s); how long a hold is a wind, not a jig (s).
const DEEP := 14.0
const SINK := 5.0
const WIND := 3.5
const HOLD := 0.28
## After a jig: the chance something knocks it on the fall, how deep it has to be for that, and how long you have to
## strike (s).
const KNOCK := 0.4
const KNOCK_DEEP := 5.0
const STRIKE := 0.55

var sea: Node                 # sea/sea.gd
## Your jig: "up" (at the tip), "down" (sinking or there), "knock" (a fish on it, strike now), "on" (hooked).
var state := "up"
var depth := 0.0
## The rod tip snatched up (1) or jerked down by a knock (-1), easing back to 0; crew/hands.gd poses the rod with it.
var lift := 0.0
var _held := 0.0
var _pressed := false
var _knock_in := INF
var _knock_left := 0.0
var _wriggle := 0.0
var _last := {}               # (host: peer -> when they last got one)
## Everyone's jig lines (drawn from their rod tips) and the mackerel coming up on one (peer -> s left showing).
var _lines: ImmediateMesh
var _caught_on := {}
var _fish: Node3D


func _ready() -> void:
	_lines = ImmediateMesh.new()
	var line := MeshInstance3D.new()
	line.mesh = _lines
	line.top_level = true
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.85, 0.86, 0.78)
	line.material_override = lm
	add_child(line)
	_fish = Kit._mackerel()
	_fish.top_level = true
	_fish.visible = false
	add_child(_fish)
	(sea.get("boat") as Node).connect("rebuilt", func() -> void: _reset())


func _reset() -> void:
	state = "up"
	depth = 0.0
	lift = 0.0


## Whether you're jigging (your line's in the water).
func active() -> bool:
	return state != "up" or depth > 0.0


## Left mouse went down with the jig rod in your hands (crew/hands.gd).
func work(player: Node) -> void:
	_pressed = true
	_held = 0.0
	if state == "up":
		if not _over_water(player):
			return
		state = "down"
		Sfx.play_point(self, _tip(player), "dock.reel", 0.6, 1.6)
		return
	# a jig: the tip snatched up; on a knock, that's the strike
	lift = 1.0
	if state == "knock":
		state = "on"
		_wriggle = 1.0
		Sfx.play_point(self, _tip(player), "kit.jolt", 0.5, 1.5)
	elif state == "down" and depth >= KNOCK_DEEP and absf(_speed()) <= JIG_SPEED and randf() < KNOCK:
		_knock_in = randf_range(0.35, 1.1)      # (on the fall)


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
	_draw(crew, delta)


## Your jig, this frame: sinking, winding up while you hold the button, the knock and the strike.
func _play(me: Node3D, delta: float) -> void:
	var live := bool(me.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var held := live and Input.is_action_pressed("use_primary") and _pressed
	if not held:
		_pressed = false
	_held = _held + delta if held else 0.0
	var winding := _held > HOLD and state != "up"
	if winding:
		depth = maxf(depth - WIND * delta, 0.0)
		lift = maxf(lift, 0.35)
		if depth <= 0.0:
			_landed(me)
	elif state in ["down", "knock"]:
		depth = minf(depth + SINK * delta, DEEP)
	# a knock on the fall: the tip jerks down, your view with it; strike within STRIKE s or it's gone
	_knock_in -= delta
	if _knock_in <= 0.0:
		_knock_in = INF
		if state == "down":
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
	if state == "on":
		# a mackerel on: the tip nodding to its kicks
		_wriggle += delta
		lift = minf(lift, -0.25 + sin(_wriggle * 17.0) * 0.2)
		me.set("shake", 0.15)
	elif state != "knock" and float(me.get("shake")) > 0.0 and not _rod_in_hands(me):
		me.set("shake", 0.0)
	if absf(_speed()) > JIG_SPEED and state in ["knock", "on"]:
		state = "down"      # (under way: torn off)


## Wound all the way up: a mackerel on comes aboard; either way the jig's back at the tip.
func _landed(me: Node3D) -> void:
	var had := state == "on"
	state = "up"
	depth = 0.0
	me.set("shake", 0.0)
	if not had:
		return
	if Net.is_host():
		_ask_mackerel_as(Net.my_id())
	else:
		_ask_mackerel.rpc_id(1)


func _rod_in_hands(me: Node) -> bool:
	var rods: Node = sea.get("rods")
	return rods != null and rods.call("held_by", str(me.name).to_int()) != null


@rpc("any_peer", "call_remote", "reliable")
func _ask_mackerel() -> void:
	_ask_mackerel_as(multiplayer.get_remote_sender_id())


## Host: a mackerel swung aboard by `who`, if it's been long enough and she's slow enough: into the well if it takes
## it, else back over the side.
func _ask_mackerel_as(who: int) -> void:
	var t := _now()
	if t - float(_last.get(who, -1e9)) < EVERY or absf(_speed()) > JIG_SPEED:
		return
	var hold: Node = sea.get("fish_hold")
	if hold == null:
		return
	_last[who] = t
	var kept := bool(hold.call("host_add_live"))
	if Net.in_session():
		_caught.rpc(who, kept)
	else:
		_caught(who, kept)


@rpc("authority", "call_local", "reliable")
func _caught(who: int, kept := true) -> void:
	_caught_on[who] = 1.2
	var p := ((sea.get("crew") as Node).call("get_player", who)) as Node3D
	var at := _tip(p) if p else global_position
	Sfx.play_point(self, at, "dock.slap", 0.5, 1.6)
	if not kept:
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			Sfx.play_point(self, at, "dock.slap", 0.3, 2.2))       # (back over the side)


## Everyone's jig lines: from each jigger's rod tip down into the water (streaming astern if she's moving), and a
## mackerel wriggling on the end of one being swung aboard.
func _draw(crew: Node, delta: float) -> void:
	_lines.clear_surfaces()
	var ocean := sea.get("ocean") as Node
	var boat := sea.get("boat") as Node3D
	var any := false
	_fish.visible = false
	for id: int in _caught_on.keys():
		_caught_on[id] = float(_caught_on[id]) - delta
		if float(_caught_on[id]) <= 0.0:
			_caught_on.erase(id)
	for p: Node in crew.get_children():
		if not p is Node3D or not p.has_method("gesture"):
			continue
		var id := str(p.name).to_int()
		var mine: bool = p == crew.get("me")
		var jigging: bool = active() if mine else (int(p.get("_net_act")) & 2) != 0       # (player.gd's ACT_JIG)
		var showing := _caught_on.has(id)
		if not jigging and not showing:
			continue
		var tip := _tip(p)
		if tip == Vector3.INF:
			continue
		var b := tip + Vector3(0.0, -2.5, 0.0)
		if showing:
			b = tip + Vector3(0.0, -0.45, 0.0)
			_fish.visible = true
			var k := float(_caught_on[id])
			_fish.global_transform = Transform3D(Basis(Vector3.UP, sin(k * 25.0) * 0.6) * Basis(Vector3.RIGHT, PI * 0.5),
					b + Vector3(0.0, -0.14, 0.0))
		else:
			b.y = float(ocean.call("height_at", b))
			b -= boat.global_basis.z * clampf(absf(_speed()) * 1.5, 0.0, 6.0) * -1.0
		if not any:
			_lines.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		_lines.surface_add_vertex(tip)
		_lines.surface_add_vertex(b)
	if any:
		_lines.surface_end()


## The jig rod's tip in someone's hands (INF: they're not holding it).
func _tip(p: Node) -> Vector3:
	if p == null:
		return Vector3.INF
	var hands: Node = p.get("hands")
	var tip: Node3D = hands.call("tip") if hands else null
	return tip.global_position if tip else Vector3.INF


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
