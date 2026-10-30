extends Node3D
## A light jig rod in a gunwale holder (her kind's `jig`), its string of little feathered hooks over the side: hold E
## on it and jig, and every few seconds a mackerel comes up, wriggling, into the live well (boat/fish_hold.gd's well:
## you need the well, bought at the dock, to keep them). A live mackerel's the best bait there is (rods.gd).
## Not while she's under way (JIG_SPEED): the jig streams out behind her.
##
## The jigging is yours (your hand on it, the rod bobbing as you work it); each mackerel is the host's to give
## (_ask_mackerel), and everyone sees it come up (_caught).

const Action := preload("res://core/action.gd")
const Sfx := preload("res://audio/sfx.gd")
const ROD := preload("res://rods/rod.glb")
const FishHold := preload("res://boat/fish_hold.gd")
const SCALE := 0.7
## Seconds between mackerel while you keep at it, the quickest the host gives one peer another, and the fastest she
## can be going (m/s).
const BITE := Vector2(3.0, 7.0)
const EVERY := 2.0
const JIG_SPEED := 1.5

var sea: Node                 # sea/sea.gd
var _rod: Node3D
var _act: Area3D
var _tip_local := Vector3(0.0, 0.0, 1.76)
var _line_mesh: ImmediateMesh
var _line: MeshInstance3D
var _mackerel: Node3D
var _show_fish := 0.0
var _jigging := false
var lift := 0.0
var _bite_in := 0.0
var _jig_t := 0.0
var _side := 1.0
var _at := Vector3.ZERO
var _last := {}               # (host: peer -> when they last got one)


func _ready() -> void:
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.85, 0.86, 0.78)
	_line.material_override = lm
	add_child(_line)
	_mackerel = _make_mackerel()
	_mackerel.top_level = true
	_mackerel.visible = false
	add_child(_mackerel)
	_attach()
	(sea.get("boat") as Node).connect("rebuilt", _attach)


## The jig rod, in the holder her kind keeps it in (again whenever she's rebuilt as another).
func _attach() -> void:
	var boat := sea.get("boat") as Node3D
	_jigging = false
	for n: Node in [_rod, _act]:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	var holders: Array = boat.get("holders")
	var i := int((boat.get("spec") as Dictionary).get("jig", 4))
	_at = (holders[i] as Transform3D).origin if i < holders.size() else Vector3(1.5, 1.2, 2.0)
	_side = signf(_at.x) if _at.x != 0.0 else 1.0
	_rod = ROD.instantiate() as Node3D
	_rod.name = "JigRod"
	boat.add_child(_rod)
	var tip := _rod.find_child("tip", true, false) as Node3D
	if tip:
		_tip_local = tip.transform.origin
	_act = Action.new(Vector3(0.5, 0.6, 0.6))
	_act.name = "Jig"
	_act.position = _at + Vector3(-_side * 0.2, 0.0, 0.0)
	_act.use = func(_p: Node) -> void: _start()
	_act.prompt = _prompt
	boat.add_child(_act)
	_pose(0.0)


## The rod out over the side and up; `bob` works it up and down (a jig).
func _pose(bob: float) -> void:
	var out := Vector3(_side * 0.75, 0.62 + bob, -0.1).normalized()
	_rod.transform = Transform3D(Basis.looking_at(-out, Vector3.UP).scaled(Vector3.ONE * SCALE), _at)


func tip_position() -> Vector3:
	return _rod.global_transform * _tip_local


func _prompt() -> String:
	var hold: Node = sea.get("fish_hold")
	if hold == null or bool(hold.get("docked")):
		return ""
	if _jigging:
		return "Jigging... (keep holding E)"
	if not bool(hold.call("has_gear", "bait")):
		return "A jig for mackerel: you need a live-bait well to keep them (the dock)"
	if int(hold.get("well")) >= FishHold.WELL_MAX:
		return "The live well's full (%d mackerel)" % int(hold.get("well"))
	if absf(_speed()) > JIG_SPEED:
		return "Slow her down to jig for mackerel"
	return "Hold E: jig for mackerel (live bait %d/%d)" % [int(hold.get("well")), FishHold.WELL_MAX]


func _start() -> void:
	var hold: Node = sea.get("fish_hold")
	if hold == null or bool(hold.get("docked")) or not bool(hold.call("has_gear", "bait")):
		return
	_jigging = true
	_bite_in = randf_range(BITE.x, BITE.y)


func _process(delta: float) -> void:
	var crew := sea.get("crew") as Node
	var me: Node = crew.get("me") if crew else null
	if _jigging and (me == null or not Input.is_action_pressed("interact") or me.call("looking_at") != _act):
		_jigging = false
	if _jigging and absf(_speed()) <= JIG_SPEED:
		_jig_t += delta
		_bite_in -= delta
		if _bite_in <= 0.0:
			_bite_in = randf_range(BITE.x, BITE.y)
			if Net.is_host():
				_ask_mackerel_as(Net.my_id())
			else:
				_ask_mackerel.rpc_id(1)
	_pose(sin(_jig_t * 5.0) * 0.25 if _jigging else 0.0)
	# the line straight down from the tip into the water (a fish on it for a moment, wriggling, swung aboard)
	var a := tip_position()
	var ocean := sea.get("ocean") as Node
	var b := a + Vector3(0.0, -3.0, 0.0)
	b.y = float(ocean.call("height_at", b)) - 0.2
	_show_fish -= delta
	_mackerel.visible = _show_fish > 0.0
	if _mackerel.visible:
		b = a + Vector3(0.0, -0.5, 0.0)
		_mackerel.global_transform = Transform3D(Basis(Vector3.UP, sin(_show_fish * 25.0) * 0.6)
				* Basis(Vector3.RIGHT, PI * 0.5), b + Vector3(0.0, -0.12, 0.0))
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_line_mesh.surface_add_vertex(a)
	_line_mesh.surface_add_vertex(b)
	_line_mesh.surface_end()


@rpc("any_peer", "call_remote", "reliable")
func _ask_mackerel() -> void:
	_ask_mackerel_as(multiplayer.get_remote_sender_id())


## Host: a mackerel for whoever's jigging, if it's been long enough, she's slow enough and the well takes it.
func _ask_mackerel_as(who: int) -> void:
	var t := _now()
	if t - float(_last.get(who, -1e9)) < EVERY or absf(_speed()) > JIG_SPEED:
		return
	var hold: Node = sea.get("fish_hold")
	if hold == null or not bool(hold.call("host_add_live")):
		return
	_last[who] = t
	if Net.in_session():
		_caught.rpc(who)
	else:
		_caught(who)


@rpc("authority", "call_local", "reliable")
func _caught(who: int) -> void:
	_show_fish = 1.4
	Sfx.play_point(self, tip_position(), "dock.slap", 0.5, 1.6)
	if who == Net.my_id():
		var hold: Node = sea.get("fish_hold")
		var hud := (sea.get("crew") as Node).get("hud") as Node
		# (the hold's word with the new count comes just ahead of this one)
		hud.call("notify", "A mackerel! Into the live well (%d/%d)" % [int(hold.get("well")), FishHold.WELL_MAX])


func _speed() -> float:
	var helm: Node = (sea.get("boat") as Node).get("helm")
	return float(helm.get("speed")) if helm else 0.0


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


## A mackerel, low and chunky: green-blue back with dark bars, silver belly, forked tail; 30 cm.
static func _make_mackerel() -> Node3D:
	var root := Node3D.new()
	root.name = "Mackerel"
	var back := StandardMaterial3D.new()
	back.albedo_color = Color(0.18, 0.42, 0.4)
	back.metallic = 0.4
	back.roughness = 0.35
	var belly := StandardMaterial3D.new()
	belly.albedo_color = Color(0.82, 0.84, 0.86)
	belly.metallic = 0.6
	belly.roughness = 0.3
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	body.mesh = sm
	body.material_override = belly
	body.scale = Vector3(0.045, 0.06, 0.26)
	root.add_child(body)
	var top := MeshInstance3D.new()
	top.mesh = sm
	top.material_override = back
	top.scale = Vector3(0.04, 0.035, 0.24)
	top.position = Vector3(0.0, 0.016, 0.0)
	root.add_child(top)
	var tail := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.09, 0.06, 0.01)
	tail.mesh = pm
	tail.material_override = back
	tail.rotation = Vector3(0.0, PI * 0.5, PI)
	tail.position = Vector3(0.0, 0.0, 0.15)
	root.add_child(tail)
	return root
