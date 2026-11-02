extends Node3D
## Her dock lines, bow and stern, each coiled on her own cleats till someone throws it. The host keeps them; every
## peer draws them and works them out the same.
##
## Aboard, at a cleat on her bow or her quarter (E): throw that line to the nearest cleat on the float alongside,
## if it's within REACH (it's in the air FLY s, a loop dropped over the float's cleat; further than that and it
## falls short in the water and comes back aboard wet). Then hold E at her cleat to make it fast: you haul her in on
## it as you take your turns (HAUL m/s, MAKE_FAST s), and it's fast at what's left. Holding E on a fast line hauls
## her in some more. E on a fast (or looped) line, at her cleat or at the float's, lets it go: it comes back aboard.
##
## A fast line's a spring that only pulls (K, damped by C): she rides on her lines, surging and swinging on them,
## never put anywhere. Whoever's moving her (boat/helm.gd: the captain, or the host with nobody at the wheel) adds
## their pull to her way, her drift and her turn (tug), and the fenders on the floats' edges push her off them.
##
## Both fast (on any of the floats' cleats) and she's tied up: boat/fish_hold.gd hears it (tied()).

const Action := preload("res://core/action.gd")
const Sfx := preload("res://audio/sfx.gd")
const REACH := 6.0
const FLY := 0.7
const MISS := 1.8
const MAKE_FAST := 1.0
const HAUL := 1.5
const K := 3.0
const C := 1.6
const FENDER := 26.0
## How near a float's outer edge her side lies on its fenders (m).
const OFF := 0.35
const ROPE := Color(0.82, 0.74, 0.5)
enum { ABOARD, OUT, FAST, BACK, SHORT }

var boat: Node3D          # boat/boat.gd
## Each line (0 bow, 1 stern): [state, the float's cleat (quay.cleats), rest length (m), since (sea clock), side
## (1 starboard, -1 port)].
var lines: Array = [[ABOARD, -1, 0.0, 0.0, 1.0], [ABOARD, -1, 0.0, 0.0, 1.0]]
## Line being hauled in by someone holding E (host: line -> s held).
var _hauling := {}
var _mesh: ImmediateMesh
var _mat: StandardMaterial3D
var _acts: Array[Node] = []
var _held := [0.0, 0.0]       # (your own hold on each line's E, s)


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Ropes"
	mi.mesh = _mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (lit like everything else: a rope doesn't glow at dusk; matt, no shine)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = ROPE
	_mat.roughness = 1.0
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = _mat
	add_child(mi)
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_set_all.rpc_id(id, lines))
	_place_acts()


## Her cleats moved (another boat: boat.gd's rebuilt).
func rebuilt() -> void:
	_place_acts()


func _quay() -> Node:
	var sea: Node = boat.get("sea")
	var real: Node = sea.get("sea") if sea != null and sea.get("sea") != null else sea
	var h: Node = real.get("harbour") if real else null
	return h.get("quay") if h else null


func _now() -> float:
	var sea: Node = boat.get("sea")
	return float((sea.get("ocean") as Node).get("wave_time")) if sea and sea.get("ocean") else 0.0


## Her cleat for line `i` on side `s` (boat-local): on her gunwale's cap, forward and aft.
func fair(i: int, s: float) -> Vector3:
	var spec: Dictionary = boat.get("spec")
	var rail: Array = spec.get("rail", [])
	var length := float(boat.get("length"))
	var beam := float(boat.get("beam"))
	var p: Vector3
	if rail.size() >= 5:
		p = rail[4] if i == 0 else rail[1]      # (her bow, and her quarter forward of the rod holders)
	else:
		p = Vector3(beam * 0.5, 1.1, (-0.32 if i == 0 else 0.4) * length)
	return Vector3(s * (absf(p.x) - 0.22), p.y + 0.04, p.z)


func _place_acts() -> void:
	for a in _acts:
		if is_instance_valid(a):
			a.queue_free()
	_acts.clear()
	for i in 2:
		for s: float in [1.0, -1.0]:
			var act := Action.new(Vector3(0.34, 0.3, 0.4))
			act.name = "Line%d%s" % [i, "S" if s > 0.0 else "P"]
			act.position = fair(i, s) + Vector3(0.0, 0.08, 0.0)
			var li := i
			var side := s
			act.use = func(_p: Node) -> void: _press(li, side)
			act.prompt = func() -> String: return _prompt(li, side)
			boat.add_child(act)
			_acts.append(act)
			# her cleat itself: a horn cleat on the cap, galvanised
			var cleat := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.06, 0.05, 0.22)
			cleat.mesh = bm
			var steel := StandardMaterial3D.new()
			steel.albedo_color = Color(0.62, 0.64, 0.66)
			steel.metallic = 0.5
			cleat.material_override = steel
			cleat.position = Vector3(0.0, -0.05, 0.0)
			act.add_child(cleat)


## What E at her cleat (line i, side s) says.
func _prompt(i: int, s: float) -> String:
	var l: Array = lines[i]
	var what := "bow" if i == 0 else "stern"
	match int(l[0]):
		ABOARD:
			var q := _quay()
			if q == null or not _ok_to_throw():
				return ""
			var near: Array = q.call("nearest_cleat", boat.to_global(fair(i, s)))
			return "Throw the %s line" % what if float(near[1]) <= REACH else "The %s line: she's too far off to throw it" % what
		OUT:
			if float(l[4]) != s:
				return ""
			return "Hold E: haul in and make the %s line fast  %s" % [what, _bar(_held[i] / MAKE_FAST)]
		FAST:
			if float(l[4]) != s:
				return ""
			if _slack_left(i) > 0.3:
				return "Hold E: haul her in on the %s line  (Q: let it go)" % what
			return "Let go the %s line" % what
	return ""


static func _bar(k: float) -> String:
	var n := clampi(roundi(k * 6.0), 0, 6)
	return "[" + "#".repeat(n) + "-".repeat(6 - n) + "]"


## Rivals: the lines stay fast till GO (the countdown), and casting off's the same for both.
func _ok_to_throw() -> bool:
	return true


func _ok_to_let_go() -> bool:
	var sea: Node = boat.get("sea")
	var real: Node = sea.get("sea") if sea != null and sea.get("sea") != null else sea
	var vs: Node = real.get("vs") if real else null
	var hold: Node = sea.get("fish_hold") if sea else null
	return vs == null or not bool(vs.get("on")) or hold == null or not bool(hold.get("docked"))


## E pressed at her cleat: throw it (aboard), let it go (fast, unless you're holding to haul).
func _press(i: int, s: float) -> void:
	var l: Array = lines[i]
	match int(l[0]):
		ABOARD:
			request(i, "throw", s)
		FAST:
			if float(l[4]) == s and _slack_left(i) <= 0.3:
				request(i, "let_go", s)


## Asks the host to throw line `i` from side `s`, make it fast, let it go, or haul it in a bit.
func request(i: int, what: String, s := 1.0) -> void:
	if Net.is_host():
		_ask(i, what, s)
	else:
		_ask.rpc_id(1, i, what, s)


@rpc("any_peer", "call_remote", "reliable")
func _ask(i: int, what: String, s: float) -> void:
	if i < 0 or i > 1:
		return
	var l: Array = (lines[i] as Array).duplicate()
	var q := _quay()
	match what:
		"throw":
			if int(l[0]) != ABOARD or q == null:
				return
			var from := boat.to_global(fair(i, s))
			var near: Array = q.call("nearest_cleat", from)
			if int(near[0]) >= 0 and float(near[1]) <= REACH:
				l = [OUT, int(near[0]), 0.0, _now(), s]
			else:
				l = [SHORT, -1, 0.0, _now(), s]
		"make_fast":
			if int(l[0]) != OUT:
				return
			l = [FAST, l[1], maxf(length_of(i) - HAUL * MAKE_FAST, snug(i)), _now(), l[4]]
		"haul":
			if int(l[0]) != FAST:
				return
			l[2] = maxf(float(l[2]) - HAUL * 0.25, snug(i))
		"let_go":
			if int(l[0]) != OUT and int(l[0]) != FAST:
				return
			if not _ok_to_let_go():
				return
			l = [BACK, l[1], 0.0, _now(), l[4]]
		_:
			return
	_host_set(i, l)


func _host_set(i: int, l: Array) -> void:
	if Net.in_session():
		_put.rpc(i, l)
	else:
		_put(i, l)


@rpc("authority", "call_local", "reliable")
func _put(i: int, l: Array) -> void:
	var was := int((lines[i] as Array)[0])
	lines[i] = l
	_held[i] = 0.0
	var at := boat.to_global(fair(i, float(l[4])))
	match int(l[0]):
		OUT, SHORT:
			if was == ABOARD:
				Sfx.play_point(boat, at, "dock.slap", 0.4, 1.6)
		FAST:
			if was == OUT:
				Sfx.play_point(boat, at, "kit.thud", 0.35, 1.5)


@rpc("authority", "call_remote", "reliable")
func _set_all(all: Array) -> void:
	lines = all


## Host (the start of a game, Rivals' berths): both lines made fast where she lies, no slack.
func host_make_fast_here() -> void:
	var q := _quay()
	if q == null:
		return
	var s := _float_side()
	for i in 2:
		var near: Array = q.call("nearest_cleat", boat.to_global(fair(i, s)))
		if int(near[0]) < 0:
			continue
		var c: Vector3 = (q.get("cleats") as Array)[int(near[0])]
		var p := boat.to_global(fair(i, s))
		_host_set(i, [FAST, int(near[0]), Vector2(c.x - p.x, c.z - p.z).length(), _now() - FLY, s])


## Host (the tow's crew, the harbour's): both lines thrown and made fast where she lies, one after the other.
func host_tie_up_for_her() -> void:
	var s := _float_side()
	for i in 2:
		if int((lines[i] as Array)[0]) == FAST:
			continue
		_ask(i, "throw", s)
		await get_tree().create_timer(FLY + 0.4).timeout
		if int((lines[i] as Array)[0]) == OUT:
			_ask(i, "make_fast", s)
		await get_tree().create_timer(0.5).timeout


## Which of her sides is toward the float she's alongside (1 starboard, -1 port).
func _float_side() -> float:
	var q := _quay()
	if q == null:
		return 1.0
	var near: Array = q.call("nearest_cleat", boat.global_position)
	if int(near[0]) < 0:
		return 1.0
	var c: Vector3 = (q.get("cleats") as Array)[int(near[0])]
	return 1.0 if boat.to_local(c).x > 0.0 else -1.0


## Both fast: she's tied up.
func tied() -> bool:
	return int((lines[0] as Array)[0]) == FAST and int((lines[1] as Array)[0]) == FAST


## Both aboard: she's free.
func all_aboard() -> bool:
	return int((lines[0] as Array)[0]) == ABOARD and int((lines[1] as Array)[0]) == ABOARD


func any_out() -> bool:
	return not all_aboard()


## Line i's length now, her cleat to the float's (m, flat).
func length_of(i: int) -> float:
	var l: Array = lines[i]
	var q := _quay()
	if q == null or int(l[1]) < 0:
		return 0.0
	var c: Vector3 = (q.get("cleats") as Array)[int(l[1])]
	var p := boat.to_global(fair(i, float(l[4])))
	return Vector2(c.x - p.x, c.z - p.z).length()


## How short line i can be hauled: with her alongside the float on her fenders.
func snug(i: int) -> float:
	var l: Array = lines[i]
	var q := _quay()
	if q == null or int(l[1]) < 0:
		return 0.0
	var c: Vector3 = (q.get("cleats") as Array)[int(l[1])]
	var p := boat.to_global(fair(i, float(l[4])))
	return Vector2(OFF + 0.5, c.z - p.z).length()


func _slack_left(i: int) -> float:
	return float((lines[i] as Array)[2]) - snug(i)


# ------------------------------------------------------------------ her riding on them

## Whoever moves her: the lines' pull and the fenders' push on her this frame, into her way, drift and turn.
func tug(helm: Node, delta: float) -> void:
	var q := _quay()
	if q == null or delta <= 0.0:
		return
	var at: Vector2 = helm.get("at")
	var heading := float(helm.get("heading"))
	var speed := float(helm.get("speed"))
	var drift: Vector2 = helm.get("drift")
	var spin := float(helm.get("spin"))
	var ahead := Vector2(-sin(heading), -cos(heading))
	var length := float(boat.get("length"))
	var beam := float(boat.get("beam"))
	var inertia := length * length / 12.0
	var force := Vector2.ZERO
	var torque := 0.0
	var cleats: Array = q.get("cleats")
	for i in 2:
		var l: Array = lines[i]
		if int(l[0]) != FAST:
			continue
		var r := _offset(fair(i, float(l[4])), heading)
		var p := at + r
		var c: Vector3 = cleats[int(l[1])]
		var to := Vector2(c.x, c.z) - p
		var d := to.length()
		if d <= float(l[2]) or d < 0.001 or d > 40.0:
			continue
		var dir := to / d
		var v := ahead * speed + drift + Vector2(spin * r.y, -spin * r.x)
		var pull := maxf(K * (d - float(l[2])) - C * v.dot(dir), 0.0)
		var f := dir * pull
		force += f
		torque += r.y * f.x - r.x * f.y
	# the fenders on the floats' edges: her side pushed off where it's in against one
	for z: float in [-0.35, 0.0, 0.38]:
		for s: float in [-1.0, 1.0]:
			var r := _offset(Vector3(s * beam * 0.5, 0.0, z * length), heading)
			var p := at + r
			var fl: Array = q.call("float_near", p, 3.0)
			if fl.is_empty():
				continue
			var out := float(fl[1])
			var way := float(fl[2])
			var into := OFF - (p.x - out) * way       # (how far in past where her side should lie)
			if into <= 0.0:
				continue
			var v := ahead * speed + drift + Vector2(spin * r.y, -spin * r.x)
			var push := maxf(FENDER * into - 4.0 * v.x * way, 0.0)
			var f := Vector2(way * push, 0.0)
			force += f
			torque += r.y * f.x - r.x * f.y
	if force == Vector2.ZERO and torque == 0.0:
		return
	var along := force.dot(ahead)
	helm.set("speed", speed + along * delta)
	helm.set("drift", drift + (force - ahead * along) * delta)
	helm.set("spin", spin + torque / inertia * delta)


## A boat-local point's offset from her middle (world x, z) at her heading.
static func _offset(local: Vector3, heading: float) -> Vector2:
	var w := Basis(Vector3.UP, heading) * Vector3(local.x, 0.0, local.z)
	return Vector2(w.x, w.z)


# ------------------------------------------------------------------ hands on, and drawn

func _process(delta: float) -> void:
	_hold_e(delta)
	if Net.is_host():
		_host_settle()
	_draw_ropes()


## Your own E held on her cleat with a line looped over the float's: making it fast; on a fast one with slack left,
## hauling her in.
func _hold_e(delta: float) -> void:
	var sea: Node = boat.get("sea")
	var crew: Node = sea.get("crew") if sea else null
	var me: Node = crew.get("me") if crew else null
	if me == null:
		return
	var live := bool(me.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var at: Node = me.call("looking_at") if live else null
	for i in 2:
		var l: Array = lines[i]
		var mine := at != null and _acts.has(at) and str(at.name).begins_with("Line%d%s" % [i, "S" if float(l[4]) > 0.0 else "P"])
		if not mine or not Input.is_action_pressed("interact"):
			_held[i] = 0.0
			continue
		_held[i] += delta
		if int(l[0]) == OUT and _held[i] >= MAKE_FAST:
			_held[i] = 0.0
			me.call("gesture", "reach")
			request(i, "make_fast")
		elif int(l[0]) == FAST and _slack_left(i) > 0.3 and _held[i] >= 0.25:
			_held[i] = 0.0
			me.call("gesture", "reach")
			request(i, "haul")
	if live and Input.is_action_just_pressed("drop") and at != null and _acts.has(at):
		var i := int(str(at.name).substr(4, 1))
		request(i, "let_go")


## Host: a line in the air lands (on the float's cleat, or short in the water and back aboard), one coming back is
## aboard again.
func _host_settle() -> void:
	var now := _now()
	for i in 2:
		var l: Array = lines[i]
		var since := now - float(l[3])
		if (int(l[0]) == FAST or int(l[0]) == OUT) and length_of(i) > 40.0:
			_host_set(i, [ABOARD, -1, 0.0, now, l[4]])       # (she's been put somewhere far off: a dev's shortcut)
		elif int(l[0]) == BACK and since >= FLY:
			_host_set(i, [ABOARD, -1, 0.0, now, l[4]])
		elif int(l[0]) == SHORT and since >= MISS:
			_host_set(i, [ABOARD, -1, 0.0, now, l[4]])


func _draw_ropes() -> void:
	_mesh.clear_surfaces()
	var q := _quay()
	if q == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cleats: Array = q.get("cleats")
	var now := _now()
	var began := false
	for i in 2:
		var l: Array = lines[i]
		var st := int(l[0])
		if st == ABOARD:
			continue
		var a := boat.to_global(fair(i, float(l[4])))
		var end: Vector3
		var since := now - float(l[3])
		var sag := 0.35
		if st == SHORT:
			# out toward the float and down into the water short of it, then hauled back
			var dir := boat.global_basis * Vector3(float(l[4]), 0.0, 0.0)
			var lay := a + dir * REACH * 0.7
			lay.y = 0.0
			var k := clampf(since / FLY, 0.0, 1.0) if since < FLY else clampf(1.0 - (since - FLY) / (MISS - FLY), 0.0, 1.0)
			end = a.lerp(lay, k) + Vector3(0, sin(k * PI) * 1.2 if since < FLY else 0.0, 0)
		else:
			if int(l[1]) < 0 or int(l[1]) >= cleats.size():
				continue
			var c: Vector3 = cleats[int(l[1])] + Vector3(0, 0.12, 0)
			if st == OUT:
				var k := clampf(since / FLY, 0.0, 1.0)
				end = a.lerp(c, k) + Vector3(0, sin(k * PI) * 1.4, 0)
				sag = 0.5
			elif st == FAST:
				end = c
				sag = clampf(float(l[2]) - Vector2(c.x - a.x, c.z - a.z).length(), 0.02, 0.8)
			else:
				var k := clampf(since / FLY, 0.0, 1.0)
				end = c.lerp(a, k) + Vector3(0, sin(k * PI) * 1.0, 0)
		if not began:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
			began = true
		_rope(a, end, sag, cam.global_position)
	if began:
		_mesh.surface_end()


## A rope from a to b sagging `sag` m in its middle: a flat ribbon turned to the eye, 2 cm wide.
func _rope(a: Vector3, b: Vector3, sag: float, eye: Vector3) -> void:
	var n := 10
	var prev := a
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var along := (p - prev).normalized()
		var side := along.cross((eye - p).normalized()).normalized() * 0.012
		# (lit as a round rope's upper side would be: toward the sky and the eye)
		_mesh.surface_set_normal((Vector3.UP + (eye - p).normalized()).normalized())
		_mesh.surface_add_vertex(prev - side)
		_mesh.surface_add_vertex(prev + side)
		_mesh.surface_add_vertex(p + side)
		_mesh.surface_add_vertex(prev - side)
		_mesh.surface_add_vertex(p + side)
		_mesh.surface_add_vertex(p - side)
		prev = p
