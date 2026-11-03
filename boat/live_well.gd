extends Node3D
## Her live well in the transom (every boat has one: boat/fish_hold.gd's `well`, the live mackerel for bait), its lid
## the model's own piece ("well_lid", hinged at its after edge: art/boat.py, art/skiff.py). E on the lid opens it (the
## host's word, like the fish box's, so everyone sees the same); open, E nets a mackerel out into your fist (a live one;
## none left, a dead one off the ice in the bait box: fish_hold's `dead`), E with one in your fist puts it back (either
## way the lid goes down after it, to keep the water cool), and E with nothing to take or give shuts it. It swings up on its own for a moment whenever a mackerel goes in (swung
## aboard off the jig, boat/jig.gd) or comes out. Open, you see into it: dark water and the mackerel circling, as many
## as there are (up to SHOWN), and the dead ones lying still on the ice at its end. It swings, never jumps (SPEED).
## Built by boat/boat.gd as a child of the boat, so it rides her.
##
## The pump beside it: the water in a live well goes stale and the mackerel in it die, one every few minutes
## (boat/fish_hold.gd's WELL_STALE), unless someone pumps fresh sea water in. Hold E on the pump's handle and you work
## it, up and down (STROKE s a stroke): each stroke gulps and a gush of water spouts into the well, buying a while more
## (fish_hold's PUMP_STROKE). The water shows how it is: clear and dark when it's fresh, going murky green as it goes
## stale. Everyone sees the handle going and the water pouring when anyone pumps.

const Action := preload("res://core/action.gd")
const Kit := preload("res://crew/kit.gd")
const Sfx := preload("res://audio/sfx.gd")
## How far it swings open (rad), how fast (rad/s), how long a mackerel in or out keeps it up (s), and the most
## mackerel drawn in there.
const OPEN := 1.25
const SPEED := 3.0
const HOLD_OPEN := 1.6
const SHOWN := 6
## The pump: s for one stroke of its handle (down and back up), and how far the handle swings (rad).
const STROKE := 0.7
const THROW := 0.55
## The water in the well: fresh, and gone stale.
const FRESH := Color(0.05, 0.16, 0.18)
const STALE := Color(0.17, 0.19, 0.08)

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
var _water_mat: StandardMaterial3D
## The pump: its E, its handle (pivoting at the top of its barrel), which way it swings, the spout's mouth (boat-local
## to this node), the gush out of it.
var pump_act: Action
var _handle: Node3D
var _swing := 1.0
var _mouth := Vector3.ZERO
var _gush: MeshInstance3D
var _gush_mat: StandardMaterial3D
## (tests) the pump's handle worked as if E were held on it.
var hold_pump := false
## The stroke under way (0..1 round), the gush still coming (0..1), whether it's being worked here, and the staleness
## last frame (it dropping is someone's stroke: shown on every peer).
var _phase := 0.0
var _flow := 0.0
var _pumping := false
var _was_stale := 0.0
## Strokes worked here (the tests count them).
var strokes := 0


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
	wm.albedo_color = FRESH
	wm.roughness = 0.1
	surface.material_override = wm
	_water_mat = wm
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
	_build_pump(centre, size)


## The hand pump at the well's side: a short steel barrel standing on the deck by it, its handle, and a spout bent
## over the well's edge.
func _build_pump(centre: Vector3, size: Vector3) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.64, 0.64)
	steel.metallic = 0.5
	steel.roughness = 0.45
	var side := -1.0       # (to port of it on her transom: clear of the tuna door and the haul, starboard)
	var base := Vector3(centre.x + side * (size.x * 0.5 + 0.09), lid.position.y - 0.02, centre.z)
	var pump := Node3D.new()
	pump.name = "Pump"
	pump.position = base
	add_child(pump)
	pump.add_child(_box(Vector3(0.07, 0.34, 0.07), Vector3(0.0, 0.17, 0.0), steel))       # (the barrel)
	pump.add_child(_box(Vector3(0.11, 0.025, 0.11), Vector3(0.0, 0.012, 0.0), steel))     # (its foot)
	# the spout: out of the barrel's top and over the well's edge, its mouth looking down into it
	var reach := side * -0.16
	pump.add_child(_box(Vector3(absf(reach) + 0.03, 0.035, 0.035), Vector3(reach * 0.5, 0.3, 0.0), steel))
	pump.add_child(_box(Vector3(0.035, 0.07, 0.035), Vector3(reach, 0.27, 0.0), steel))
	_mouth = base + Vector3(reach, 0.235, 0.0)
	# the handle, pivoting on the barrel's top, out the other way, a red grip on its end
	_handle = Node3D.new()
	_handle.position = Vector3(0.0, 0.35, 0.0)
	pump.add_child(_handle)
	var arm := side * 0.26
	_swing = side
	_handle.add_child(_box(Vector3(absf(arm), 0.025, 0.025), Vector3(arm * 0.5, 0.0, 0.0), steel))
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.6, 0.12, 0.08)
	grip.roughness = 0.8
	_handle.add_child(_box(Vector3(0.07, 0.04, 0.04), Vector3(arm, 0.0, 0.0), grip))
	# the gush: a column of sea water from the mouth down into the well, while it's coming
	_gush = MeshInstance3D.new()
	var col := BoxMesh.new()
	col.size = Vector3(0.028, 1.0, 0.028)
	_gush.mesh = col
	_gush_mat = StandardMaterial3D.new()
	_gush_mat.albedo_color = Color(0.72, 0.86, 0.9, 0.85)
	_gush_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gush_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gush.material_override = _gush_mat
	_gush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gush.visible = false
	add_child(_gush)
	# hold E on it
	pump_act = Action.new(Vector3(0.36, 0.45, 0.3))
	pump_act.name = "WellPump"
	pump_act.position = base + Vector3(side * 0.08, 0.25, 0.0)
	pump_act.use = func(_p: Node) -> void:
		pass         # (held, not pressed: _pump works it while E's down on it)
	pump_act.prompt = func() -> String:
		var hold := _hold()
		if hold == null or bool(hold.get("docked")):
			return ""
		var k := float(hold.call("well_staleness"))
		return "Pump the well (hold)" + ("" if k < 0.4 else (": it's going stale" if k < 0.75
				else ": stale, they're dying"))
	add_child(pump_act)


static func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = at
	mi.material_override = mat
	return mi


## The pump, a frame on: worked while you hold E on it (or a test does), a stroke at a time; each stroke's gush on
## every peer (the host's staleness dropping says someone's pumping), the water's colour from how stale it is.
func _pump(delta: float, hold: Node) -> void:
	if _handle == null:
		return
	var sea: Node = boat.get("sea")
	var crew: Node = sea.get("crew") if sea != null else null
	var me: Node = crew.get("me") if crew != null else null
	var mine := hold_pump
	if not mine and me != null and pump_act != null:
		var live := bool(me.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		mine = live and me.call("looking_at") == pump_act and Input.is_action_pressed("interact")
	mine = mine and not bool(hold.get("docked"))
	var stale := float(hold.get("well_stale"))
	var theirs := stale < _was_stale - 1.0 and not _pumping      # (someone else's stroke: their gush)
	_was_stale = stale
	if mine or _pumping:
		var was := _phase
		_phase += delta / STROKE
		if was < 0.5 and _phase >= 0.5:
			# the handle's down: the stroke's gulp and the gush into the well
			strokes += 1
			_flow = 1.0
			hold.call("request_pump")
			Sfx.play_point(self, global_transform * _mouth, "dock.slap", -2.0, 1.4)
			if me != null and not hold_pump:
				me.call("gesture", "reach")
		if _phase >= 1.0:
			_phase = 0.0
			_pumping = mine
		else:
			_pumping = true
	elif theirs:
		_flow = 1.0
		_phase = 0.5
		Sfx.play_point(self, global_transform * _mouth, "dock.slap", -2.0, 1.4)
	elif _phase > 0.0:
		_phase = move_toward(_phase, 0.0, delta / STROKE)       # (their handle easing back up)
	_handle.rotation = Vector3(0.0, 0.0, -THROW * sin(_phase * PI) * _swing)
	_flow = maxf(_flow - delta * 1.8, 0.0)
	_gush.visible = _flow > 0.02
	if _gush.visible:
		# (a column from the mouth down to the water, thinning as it eases off; a fresh gush full)
		var bottom := Vector3(_mouth.x, _water.position.y, _mouth.z)
		var h := maxf(_mouth.y - bottom.y, 0.05)
		_gush.position = (_mouth + bottom) * 0.5
		_gush.scale = Vector3(lerpf(0.4, 1.0, _flow), h, lerpf(0.4, 1.0, _flow))
		_gush_mat.albedo_color.a = 0.85 * smoothstep(0.0, 0.3, _flow)
	_water_mat.albedo_color = FRESH.lerp(STALE, float(hold.call("well_staleness")))


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
	_pump(delta, hold)
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
