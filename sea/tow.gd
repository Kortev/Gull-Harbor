extends Node3D
## The harbour launch: a workboat that lies at the quay west of the finger pier, and when a boat's not home by the
## end of the race home (sea/sea.gd, vs/vs.gd), or her tank's run dry, goes out for her. The host runs it and tells
## everyone where it is (_state); every peer draws it.
##
## Out through the harbour mouth to her, alongside her on the hip (lashed to her side away from the float she's going
## to), and in again with her the same way, slowing as they come up the float: then her lines are thrown and made fast
## for her (boat/lines.gd's host_tie_up_for_her), the launch lets go, and goes back to where it lies. Under tow her
## wheel's no use (boat/helm.gd's towed_by): she goes where the launch takes her, every metre of it.

const Kinds := preload("res://boat/kinds.gd")
const Sfx := preload("res://audio/sfx.gd")
const RUN := 13.0             # m/s going out to her (and back, alone)
const TOW := 6.5              # m/s with her alongside
const TURN := 0.55            # rad/s
const HIP := 1.4              # m between her side and the launch's
enum { IDLE, OUT, LASH, TOW_IN, TIE, HOME }

var sea: Node                 # sea/sea.gd
var index := 0
var state := IDLE
var at := Vector2.ZERO
var heading := 0.0
var speed := 0.0
var target: Node3D = null     # the boat she's after (boat/boat.gd)
var _rest := Vector2.ZERO     # where the launch lies
var _rest_heading := 0.0
var _route: Array = []        # waypoints (world x, z)
var _lash_t := 0.0
var _from_at := Vector2.ZERO
var _from_heading := 0.0
var _side := 1.0              # which of her sides the launch is on (1 starboard)
var _model: Node3D
var _net := [Vector2.ZERO, 0.0, 0.0]
var _net_age := 0.0
var _send := 0.0
var _engine: AudioStreamPlayer3D


func _ready() -> void:
	var harbour: Node = sea.get("harbour")
	var fx := float(harbour.get("FINGER_X"))
	var face := float(harbour.call("_shore", fx - 16.0 - index * 11.0)) - 2.0
	_rest = Vector2(fx - 16.0 - index * 11.0, face - 4.2)
	_rest_heading = PI * 0.5            # (alongside the quay face, bow west)
	at = _rest
	heading = _rest_heading
	_net = [at, heading, 0.0]
	var spec: Dictionary = Kinds.spec("skiff")
	var scene := load(str(spec["model"])) as PackedScene
	if scene != null:
		_model = scene.instantiate() as Node3D
		for mi: Node in _model.find_children("*", "MeshInstance3D", true, false):
			var keep := false
			var up: Node = mi
			while up != null and up != _model:
				keep = keep or up.name == "boat" or up.name == "wheel"
				up = up.get_parent()
			(mi as MeshInstance3D).visible = keep
			if keep:
				# (the harbour's colours: a red launch, HARBOR on her side, not a boat you could take)
				var m := mi as MeshInstance3D
				for s in m.mesh.get_surface_count():
					var mat := m.mesh.surface_get_material(s)
					if mat is BaseMaterial3D and str(mat.resource_name).contains("hull"):
						var own := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
						own.albedo_color = Color(0.62, 0.14, 0.1)
						m.set_surface_override_material(s, own)
		add_child(_model)
	var name_plate := Label3D.new()
	name_plate.text = "HARBOR"
	name_plate.font_size = 48
	name_plate.pixel_size = 0.006
	name_plate.modulate = Color(0.95, 0.93, 0.85)
	name_plate.position = Vector3(1.48, 0.75, 0.6)
	name_plate.rotation.y = PI * 0.5
	add_child(name_plate)
	_engine = AudioStreamPlayer3D.new()
	_engine.unit_size = 6.0
	_engine.max_distance = 220.0
	add_child(_engine)
	_pose()


## Whether it's out (gone for a boat, or on its way back).
func busy() -> bool:
	return state != IDLE


## Host: out for boat `b` (she's late, or dry).
func host_send(b: Node3D) -> void:
	if state != IDLE and state != HOME:
		return
	target = b
	state = OUT
	_route = _out_route(b)
	Sfx.play_point(self, global_position, "kit.motor", 0.5, 0.9)


## Out through the mouth if she's outside it.
func _out_route(b: Node3D) -> Array:
	var r := []
	var mouth := _mouth()
	r.append(Vector2(_rest.x, _rest.y - 30.0))
	var her: Vector2 = (b.get("helm") as Node).get("at")
	if her.y < mouth.y:
		r.append(mouth + Vector2(0.0, 25.0))
		r.append(mouth - Vector2(0.0, 30.0))
	return r


## In with her: through the mouth if she's outside it, round the pier's end if her berth's on its east side, up the
## float she's going to, slowing.
func _in_route(b: Node3D) -> Array:
	var r := []
	var her: Vector2 = (b.get("helm") as Node).get("at")
	var mouth := _mouth()
	if her.y < mouth.y - 5.0:
		r.append(mouth - Vector2(0.0, 30.0))
		r.append(mouth + Vector2(0.0, 30.0))
	var berth := _berth_for(b)
	var harbour: Node = sea.get("harbour")
	var px := float(harbour.get("PIER_X"))
	var far := float(harbour.call("_shore", px)) - 2.0 - float(harbour.get("PIER_OUT"))
	if berth.x > px:
		r.append(Vector2(berth.x + 6.0, far - 18.0))
	r.append(Vector2(berth.x, minf(berth.y - 30.0, far - 6.0) if berth.x > px else berth.y - 34.0))
	r.append(berth)
	return r


## Where she's going: her own berth (the career's, or in Rivals whichever of the harbour's is hers), bow in toward the
## quay.
func _berth_for(b: Node3D) -> Vector2:
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		var sides: Array = vs.get("sides")
		for i in sides.size():
			if (sides[i] as Node).get("boat") == b:
				return vs.call("_berth", i)
	var harbour: Node = sea.get("harbour")
	return harbour.call("berth", float(b.get("beam")) * 0.5, float(b.get("length")))


func _mouth() -> Vector2:
	var arms: Array = (sea.get("landmarks") as Node).call("breakwater_arms")
	return ((arms[0][1] as Vector2) + (arms[1][1] as Vector2)) * 0.5


func _process(delta: float) -> void:
	if Net.is_host():
		_host(delta)
		_send -= delta
		if Net.in_session() and _send <= 0.0:
			_send = 0.1
			_state.rpc(at, heading, speed, state)
	else:
		_net_age += delta
		heading += wrapf(float(_net[1]) - heading, -PI, PI) * minf(delta * 8.0, 1.0)
		var guess: Vector2 = (_net[0] as Vector2) + Vector2(-sin(float(_net[1])), -cos(float(_net[1]))) \
				* float(_net[2]) * _net_age
		at = at.lerp(guess, minf(delta * 5.0, 1.0))
		speed = float(_net[2])
	_pose()
	if _engine.stream == null:
		_engine.stream = Sfx.stream("kit.motor")
	if _engine.stream != null:
		var going := state != IDLE
		if going and not _engine.playing:
			_engine.play()
		elif not going and _engine.playing:
			_engine.stop()
		_engine.pitch_scale = 0.7 + absf(speed) / RUN * 0.5


@rpc("authority", "call_remote", "unreliable_ordered")
func _state(where: Vector2, h: float, v: float, st: int) -> void:
	_net = [where, h, v]
	_net_age = 0.0
	state = st


func _pose() -> void:
	var ocean: Node = sea.get("ocean")
	var y := float(ocean.call("height_at", Vector3(at.x, 0.0, at.y))) if ocean else 0.0
	global_transform = Transform3D(Basis(Vector3.UP, heading), Vector3(at.x, y - 0.05, at.y))


## Host: steer for `goal` at up to `top` m/s (easing in to it), turning no faster than TURN. True: there.
func _steer(goal: Vector2, top: float, delta: float, ease_in := 20.0) -> bool:
	var to := goal - at
	var d := to.length()
	if d < 1.5:
		return true
	var want := atan2(-to.x, -to.y)
	heading = wrapf(heading + clampf(wrapf(want - heading, -PI, PI), -TURN * delta, TURN * delta), -PI, PI)
	var aim := minf(top, maxf(d / ease_in * top, 1.2))
	speed = move_toward(speed, aim, 3.0 * delta)
	at += Vector2(-sin(heading), -cos(heading)) * speed * delta
	return false


func _host(delta: float) -> void:
	match state:
		OUT:
			var goal: Vector2
			if not _route.is_empty():
				goal = _route[0]
				if _steer(goal, RUN, delta, 6.0):
					_route.pop_front()
				return
			# up to her side: the one away from the float she's going to
			var her: Vector2 = (target.get("helm") as Node).get("at")
			var hh := float((target.get("helm") as Node).get("heading"))
			_side = _away_side(target)
			var hip := her + _offset(Vector3(_side * (float(target.get("beam")) * 0.5 + HIP + 1.45), 0.0, 0.0), hh)
			if _steer(hip, RUN, delta, 25.0) or at.distance_to(hip) < 3.0:
				state = LASH
				_lash_t = 0.0
				_from_at = at
				_from_heading = heading
				var helm: Node = target.get("helm")
				if int(helm.get("captain")) != 0:
					helm.call("_host_set", 0)
				helm.set("towed_by", self)
				_tell_towed(true)
		LASH:
			# lashed alongside her, eased in over a few seconds (both stopping)
			_lash_t += delta
			var helm: Node = target.get("helm")
			helm.set("speed", move_toward(float(helm.get("speed")), 0.0, 2.0 * delta))
			var k := smoothstep(0.0, 1.0, _lash_t / 3.0)
			var hip := _hip_spot()
			at = _from_at.lerp(hip[0], k)
			heading = lerp_angle(_from_heading, hip[1], k)
			speed = 0.0
			if _lash_t >= 3.0:
				state = TOW_IN
				_route = _in_route(target)
		TOW_IN, TIE, HOME:
			pass
	if state == HOME:
		if not _route.is_empty():
			if _steer(_route[0], RUN, delta, 6.0):
				_route.pop_front()
			return
		if _steer(_rest + Vector2(0.0, -12.0) if at.distance_to(_rest) > 14.0 else _rest, RUN, delta, 8.0) \
				and at.distance_to(_rest) < 1.6:
			heading = lerp_angle(heading, _rest_heading, minf(delta, 1.0))
			speed = 0.0
			if absf(wrapf(heading - _rest_heading, -PI, PI)) < 0.05:
				heading = _rest_heading
				state = IDLE


## Host, from boat/helm.gd while she's under tow: her `helm` moved with the launch (the pair of them steered along the
## route as one; the launch alongside her).
func carry(helm: Node, delta: float) -> void:
	if state == TOW_IN:
		var her: Vector2 = helm.get("at")
		var hh := float(helm.get("heading"))
		if not _route.is_empty():
			var goal: Vector2 = _route[0]
			var last := _route.size() == 1
			var to := goal - her
			var d := to.length()
			if d < (0.6 if last else 4.0):
				_route.pop_front()
			else:
				var want := atan2(-to.x, -to.y)
				hh = wrapf(hh + clampf(wrapf(want - hh, -PI, PI), -TURN * 0.7 * delta, TURN * 0.7 * delta), -PI, PI)
				var top := TOW if not last else clampf(d / 25.0 * TOW, 0.5, TOW)
				var v := move_toward(float(helm.get("speed")), top, 1.2 * delta)
				her += Vector2(-sin(hh), -cos(hh)) * v * delta
				helm.set("speed", v)
		else:
			helm.set("speed", move_toward(float(helm.get("speed")), 0.0, 1.5 * delta))
			if absf(float(helm.get("speed"))) < 0.05:
				state = TIE
				_tie(helm)
		helm.set("at", her)
		helm.set("heading", hh)
		helm.set("drift", Vector2.ZERO)
		helm.set("spin", 0.0)
	var hip := _hip_spot()
	at = hip[0]
	heading = hip[1]
	speed = float(helm.get("speed"))


## Alongside her, made fast to her: her lines thrown and made fast for her, then the launch lets her go and heads home.
func _tie(helm: Node) -> void:
	var lines: Node = target.get("lines")
	if lines != null:
		await lines.call("host_tie_up_for_her")
	helm.set("towed_by", null)
	_tell_towed(false)
	_route = _home_route()
	state = HOME
	target = null


## Back to where the launch lies, from alongside whichever float she's left her at: out past the float's end on the
## side away from her, round the fish pier's end if that's between, then along outside the town float and the finger
## pier (never through one) and in to the quay.
func _home_route() -> Array:
	var harbour: Node = sea.get("harbour")
	var px := float(harbour.get("PIER_X"))
	var far := float(harbour.call("_shore", px)) - 2.0 - float(harbour.get("PIER_OUT"))
	var fx := float(harbour.get("FINGER_X"))
	var clear := float(harbour.call("_shore", fx)) - 2.0 - float(harbour.get("FINGER_OUT")) - 14.0
	var r := []
	if at.x > px:
		r.append(Vector2(at.x + 4.0, far - 14.0))
		r.append(Vector2(px - 14.0, far - 14.0))
	elif at.y > clear:
		r.append(Vector2(at.x + (-4.0 if _side > 0.0 else 4.0), clear))
	r.append(Vector2(_rest.x, minf(clear, _rest.y - 30.0)))
	return r


## Everyone: whether she's under tow (her wheel's no use).
func _tell_towed(on: bool) -> void:
	var path := target.get_path() if target else NodePath()
	if Net.in_session():
		_towed.rpc(path, on)


@rpc("authority", "call_remote", "reliable")
func _towed(path: NodePath, on: bool) -> void:
	var b := get_node_or_null(path)
	if b != null:
		(b.get("helm") as Node).set("towed_by", self if on else null)


## The launch's spot alongside her now: [where, heading].
func _hip_spot() -> Array:
	var helm: Node = target.get("helm")
	var her: Vector2 = helm.get("at")
	var hh := float(helm.get("heading"))
	return [her + _offset(Vector3(_side * (float(target.get("beam")) * 0.5 + HIP + 1.45), 0.0, 0.0), hh), hh]


## Which of her sides is away from where she's going (the float's on the other).
func _away_side(b: Node3D) -> float:
	var berth := _berth_for(b)
	var harbour: Node = sea.get("harbour")
	# coming in bow first up the float, heading in (+z): her starboard's to the west; the float's east of a boat lying
	# west of it (whichever float it is: the harbour knows)
	return 1.0 if float(harbour.call("berth_way", berth)) < 0.0 else -1.0


static func _offset(local: Vector3, heading: float) -> Vector2:
	var w := Basis(Vector3.UP, heading) * Vector3(local.x, 0.0, local.z)
	return Vector2(w.x, w.z)
