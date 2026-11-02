extends Node3D
## Her live well in the transom (every boat has one: boat/fish_hold.gd's `well`, the live mackerel for bait), its lid
## the model's own piece ("well_lid", hinged at its after edge: art/boat.py, art/skiff.py). E on the lid opens it (the
## host's word, like the fish box's, so everyone sees the same); open, E nets a mackerel out into your fist (a live one;
## none left, a dead one off the ice in the bait box: fish_hold's `dead`), E with one in your fist puts it back (either
## way the lid goes down after it, to keep the water cool), and E with nothing to take or give shuts it. It swings up on its own for a moment whenever a mackerel goes in (swung
## aboard off the jig, boat/jig.gd) or comes out. Open, you see into it: dark water and the mackerel circling, as many
## as there are (up to SHOWN), and the dead ones lying still on the ice at its end. It swings, never jumps (SPEED).
## Built by boat/boat.gd as a child of the boat, so it rides her.

const Action := preload("res://core/action.gd")
const Kit := preload("res://crew/kit.gd")
const Sfx := preload("res://audio/sfx.gd")
## How far it swings open (rad), how fast (rad/s), how long a mackerel in or out keeps it up (s), and the most
## mackerel drawn in there.
const OPEN := 1.25
const SPEED := 3.0
const HOLD_OPEN := 1.6
const SHOWN := 6

var boat: Node3D              # boat/boat.gd
var lid: Node3D               # the model's well_lid
## How far open it is now (rad), and how long the last mackerel in or out keeps it up (s).
var open := 0.0
var _for := 0.0
var _base := Basis.IDENTITY
var _sign := 1.0
var _well := -1
var _water: Node3D
var _fish: Array[Node3D] = []
var _dead: Array[Node3D] = []
var _act: Action
var _half := Vector2(0.4, 0.4)


func setup(on: Node3D) -> void:
	lid = on
	_base = lid.basis
	var mi := lid as MeshInstance3D
	var box := mi.get_aabb() if mi != null else AABB(Vector3(-0.45, -0.03, -0.5), Vector3(0.9, 0.03, 0.5))
	# (which way round the hinge lifts its free edge: the lid lies ahead of its hinge)
	var c := lid.basis * box.get_center()
	_sign = -1.0 if c.z > 0.0 else 1.0
	var centre := lid.position + c
	var size := (lid.basis * box.size).abs()
	# the water in it, just over the well's top where the shut lid sits on it (the model's well is solid under there),
	# and the mackerel swimming round at the top of it
	_water = Node3D.new()
	_water.name = "WellWater"
	_water.position = Vector3(centre.x, lid.position.y - size.y + 0.004, centre.z)
	_water.visible = false
	add_child(_water)
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x * 0.95, size.z * 0.95)
	surface.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.16, 0.18)
	wm.roughness = 0.1
	surface.material_override = wm
	_water.add_child(surface)
	for i in SHOWN:
		var f := Kit._mackerel()
		f.scale = Vector3.ONE * 0.8
		f.visible = false
		_water.add_child(f)
		_fish.append(f)
	for i in 3:
		var d := Kit.make("dead")
		d.scale = Vector3.ONE * 0.8
		d.visible = false
		_water.add_child(d)
		_dead.append(d)
	_half = Vector2(size.x, size.z) * 0.5
	# E on the lid
	_act = Action.new(Vector3(size.x, 0.25, size.z))
	_act.name = "LiveWell"
	_act.position = centre + Vector3(0.0, 0.08, 0.0)
	_act.use = func(p: Node) -> void:
		var hold := _hold()
		var places := _places()
		if places != null and p != null and bool(places.call("carrying", p)):
			# a tote of mackerel off the bait shop's counter tipped in (sea/places.gd)
			places.call("ask_tote", false)
			p.call("gesture", "reach")
			Sfx.play_point(self, global_position, "dock.slap", 0.6, 1.2)
			return
		if hold == null or bool(hold.get("docked")):
			return
		if not bool(hold.get("well_open")):
			hold.call("request_well_lid", true)
			return
		var hands: Node = p.get("hands") if p else null
		var rods: Node = boat.get("sea").get("rods") if boat.get("sea") else null
		var carrying := str(hands.call("carrying")) if hands else ""
		if not carrying.is_empty() and rods != null:
			rods.call("request_put_back", carrying)       # (back in, and the lid down after it)
			hands.call("carry", "")
			p.call("gesture", "reach")
			hold.call("request_well_lid", false)
		elif hands != null and rods != null and not bool(hands.call("stowed")) \
				and int(hold.get("well")) + int(hold.get("dead")) > 0:
			rods.call("request_take_bait")                # (netted out: the host hands it over; the lid down)
			p.call("gesture", "reach")
			hold.call("request_well_lid", false)
		else:
			hold.call("request_well_lid", false)
	_act.prompt = func() -> String:
		var hold := _hold()
		var places := _places()
		var carrier: Node = boat.get("sea").get("crew").get("me") if boat.get("sea") else null
		if places != null and carrier != null and bool(places.call("carrying", carrier)):
			return "Tip the mackerel in (%d in her well)" % int(hold.get("well"))
		if hold == null or bool(hold.get("docked")):
			return "Live well: %d mackerel" % int(hold.get("well")) if hold != null else ""
		var live := int(hold.get("well"))
		var dead := int(hold.get("dead"))
		if not bool(hold.get("well_open")):
			return "Live well: %d mackerel%s" % [live, (", %d dead" % dead) if dead > 0 else ""]
		var me: Node = boat.get("sea").get("crew").get("me") if boat.get("sea") else null
		var hands: Node = me.get("hands") if me else null
		if hands != null and not str(hands.call("carrying")).is_empty():
			return "Put it back"
		if hands != null and not bool(hands.call("stowed")) and live > 0:
			return "Net a mackerel (%d)" % live
		if hands != null and not bool(hands.call("stowed")) and dead > 0:
			return "A dead one off the ice (%d)" % dead
		return "Shut the live well"
	add_child(_act)


## The well's mouth (world): where a mackerel's swung in or netted out.
func mouth() -> Vector3:
	return _water.global_position if _water else global_position


func _hold() -> Node:
	var sea: Node = boat.get("sea") if boat else null
	return sea.get("fish_hold") if sea else null


## Mackerel in the well now.
func mackerel() -> int:
	var hold := _hold()
	return int(hold.get("well")) if hold != null else 0


func _process(delta: float) -> void:
	var hold := _hold()
	if hold == null or lid == null:
		return
	var w := mackerel()
	if _well >= 0 and w != _well:
		_for = HOLD_OPEN          # (a mackerel in, or one out for a bait)
	_well = w
	_for -= delta
	var want := OPEN if bool(hold.get("well_open")) or _for > 0.0 else 0.0
	var was := open
	open = move_toward(open, want, SPEED * delta)
	if was != open and open == 0.0:
		Sfx.play_point(self, lid.global_position, "kit.clank", 0.5, 1.3)
	lid.basis = Basis(Vector3.RIGHT, open * _sign) * _base
	_water.visible = open > 0.05
	# the mackerel, circling the well while you can see in
	var n := mini(w, _fish.size())
	var t := Time.get_ticks_msec() * 0.001
	for i in _fish.size():
		var f := _fish[i]
		f.visible = _water.visible and i < n
		if f.visible:
			var a := t * (0.9 + 0.13 * i) + i * TAU / maxf(n, 1)
			var r := 0.16 + 0.05 * sin(t * 0.7 + i)
			f.position = Vector3(cos(a) * r * 1.2, 0.006 + 0.004 * i, sin(a) * r * 0.8)
			f.basis = Basis(Vector3.UP, -a)
	# the dead ones, still, on their sides at the end of it
	var hold_dead := int(hold.get("dead"))
	for i in _dead.size():
		var d := _dead[i]
		d.visible = _water.visible and i < hold_dead
		if d.visible:
			d.position = Vector3((-0.6 + 0.3 * i) * _half.x, 0.012, _half.y * 0.7)
			d.basis = Basis(Vector3.UP, 0.3 * i) * Basis(Vector3.FORWARD, PI * 0.5)


func _places() -> Node:
	var sea: Node = boat.get("sea") if boat else null
	var real: Node = sea.get("sea") if sea != null and sea.get("sea") != null else sea
	return real.get("places") if real else null
