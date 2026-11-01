extends Node3D
## Hooking the mackerel in your fist onto a rod (rods.gd: E on a rod in its holder, its line in, one in your hand).
## Yours alone, on your machine: the hook on its leader comes up off the rod tip to the fish, held up in front of you
## kicking, and its point works along the fish's head as it wriggles. Click as the point comes to its nose, just ahead
## of the eyes (NOSE): through there it's bridled clean and swims right; a little off and it's on, but crooked
## (swims poorly: half the bites, rods.gd's bite_odds); back into the eyes and the brain and it's dead (a dead bait
## now, still on); ahead of the nose and the point slips off: again. A dead one goes on anywhere behind the nose. Then
## it's carried over to hang off the tip, and the host's told (request_bait). Practised, it's a second or two.

const Kit := preload("res://crew/kit.gd")
const Sfx := preload("res://audio/sfx.gd")
## The hook coming up to the fish and the fish going out to the tip (s); one sweep of the point along its head and
## back (s); where the point goes (along the fish, m from its middle: - toward its nose), the bridle spot and how close
## is clean and how close is crooked (m); how far from the rod you can be (m).
const BRING := 0.35
const SEND := 0.4
const SWEEP := 1.2
const RANGE := Vector2(-0.178, -0.085)
const NOSE := -0.142
const CLEAN := 0.011
const CROOKED := 0.026
const REACH := 3.0
## Where the fish is held up to hook it, from your eyes (m), nose to your left.
const WORK := Vector3(0.02, -0.17, -0.36)

var spread: Node              # rods.gd
## The rod it's going on (-1: not hooking one), what's in your fist ("live", "dead"), what it came out as.
var rod := -1
var kind := ""
var phase := ""
var t := 0.0
var got_kind := ""
var got_q := 1.0
## Where the point is along the fish's head now (m, its frame), and the last press's.
var point := 0.0
var _ph := 0.0
var _wrig := 0.0
var _fish: Node3D
var _glove: Node3D
var _hook: Node3D
var _leader: ImmediateMesh
var _from: Transform3D
var _send_from: Transform3D
var _hook_from := Vector3.ZERO
var _was_pressed := true
var _slip := 0.0


func _ready() -> void:
	_fish = Kit._mackerel()
	_fish.top_level = true
	_fish.visible = false
	add_child(_fish)
	# your left glove round it, behind its head (the hook's in your right)
	_glove = Kit.glove("l")
	_glove.position = Vector3(0.0, -0.005, 0.02)
	_fish.add_child(_glove)
	_hook = _make_hook()
	_hook.top_level = true
	_hook.visible = false
	add_child(_hook)
	_leader = ImmediateMesh.new()
	var lm := MeshInstance3D.new()
	lm.mesh = _leader
	lm.top_level = true
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.86, 0.78)
	lm.material_override = mat
	add_child(lm)


## A big circle hook, a few pixels of steel: shank, bend, point (its origin at the point).
static func _make_hook() -> Node3D:
	var root := Node3D.new()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.74, 0.78)
	steel.metallic = 0.6
	steel.roughness = 0.4
	for part: Array in [[Vector3(0.0, 0.016, 0.0), Vector3(0.004, 0.032, 0.004)],
			[Vector3(0.008, 0.0, 0.0), Vector3(0.016, 0.004, 0.004)], [Vector3(0.014, 0.007, 0.0),
			Vector3(0.004, 0.014, 0.004)]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[1]
		mi.mesh = box
		mi.position = part[0] - Vector3(0.014, 0.014, 0.0)
		mi.material_override = steel
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


func busy() -> bool:
	return rod >= 0


## Start hooking the mackerel in your fist (`what`: "live" or "dead") onto rod i.
func begin(i: int, what: String) -> void:
	if busy() or what.is_empty():
		return
	var me := _me()
	if me == null:
		return
	rod = i
	kind = what
	phase = "bring"
	t = 0.0
	_ph = randf() * TAU
	_was_pressed = true
	var held := me.get("hands") as Node
	var view: Node3D = held.get("_view")
	_from = view.global_transform if view else _work()
	held.set("rigging", true)
	var r: Node3D = spread.get("rods")[i]
	_hook_from = r.call("tip_position") + Vector3(0.0, -0.3, 0.0)
	me.call("gesture", "reach")


## What to do now, under your sight (rods.gd's hint).
func hint() -> String:
	if phase == "aim":
		return "CLICK: HOOK IT THROUGH THE NOSE, JUST AHEAD OF THE EYES"
	return ""


func _process(delta: float) -> void:
	_leader.clear_surfaces()
	if not busy():
		_fish.visible = false
		_hook.visible = false
		return
	var me := _me()
	var r: Node3D = spread.get("rods")[rod] if rod < (spread.get("rods") as Array).size() else null
	if me == null or r == null:
		_end(false)
		return
	# (walked off, someone took the rod, or it's no longer in with a hook on it: the fish back in your fist)
	if phase != "send" and (r.global_position.distance_to(me.global_position) > REACH or int(r.get("holder")) != 0
			or bool(r.get("hooked")) or not bool(r.get("bait_in"))):
		_end(false)
		return
	t += delta
	_wrig += delta
	var tip: Vector3 = r.call("tip_position")
	var hang := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), tip + Vector3(0.0, -0.44, 0.0))
	var work := _work()
	# the fish kicking in your fist, the harder for a live one
	var kick := (0.18 if kind == "live" else 0.0) * maxf(0.0, sin(_wrig * 1.7))
	work.basis = work.basis * Basis(Vector3.UP, sin(_wrig * 15.0) * kick)
	var point_at := work * Vector3(0.0, 0.012, point)
	match phase:
		"bring":
			var k := smoothstep(0.0, 1.0, minf(t / BRING, 1.0))
			_fish.global_transform = _from.interpolate_with(work, k)
			point = lerpf(RANGE.x, RANGE.y, 0.5)
			_hook.global_transform = Transform3D(work.basis, _hook_from.lerp(work * Vector3(0.0, 0.03, point), k))
			if t >= BRING:
				phase = "aim"
				t = 0.0
		"aim":
			_fish.global_transform = work
			# the point working along its head, back and forth, the fish's twitches throwing it about
			_ph += delta * TAU / SWEEP * (1.0 + 0.35 * sin(_wrig * 2.3))
			point = lerpf(RANGE.x, RANGE.y, 0.5 + 0.5 * sin(_ph))
			_slip = maxf(_slip - delta * 3.0, 0.0)
			_hook.global_transform = Transform3D(work.basis, point_at + work.basis.y * (0.01 + 0.02 * _slip))
			var pressed := _live(me) and Input.is_action_pressed("use_primary")
			if pressed and not _was_pressed:
				press()
			_was_pressed = pressed
		"send":
			var k := smoothstep(0.0, 1.0, minf(t / SEND, 1.0))
			var at := _send_from.interpolate_with(hang, k)
			at.origin.y += sin(k * PI) * 0.1
			_fish.global_transform = at
			_hook.global_transform = Transform3D(at.basis, at * Vector3(0.0, 0.012, NOSE))
			if t >= SEND:
				_end(true)
				return
	_fish.visible = true
	_hook.visible = true
	_glove.visible = phase != "send"
	_aim_sleeve(me)
	# its leader, from the rod tip down to the hook's eye
	_leader.surface_begin(Mesh.PRIMITIVE_LINES)
	_leader.surface_add_vertex(tip)
	_leader.surface_add_vertex(_hook.global_position + _hook.global_basis.y * 0.03)
	_leader.surface_end()


## The press, the hook's point where it is now (tests call it too): through the nose, crooked, dead, or slipped off.
func press() -> void:
	if phase != "aim":
		return
	if point < NOSE - CLEAN - 0.02:
		_slip = 1.0               # (ahead of the nose: nothing to go through)
		Sfx.play_point(self, _fish.global_position, "kit.switch", 0.3, 2.4)
		return
	var off := absf(point - NOSE)
	got_kind = kind
	got_q = 1.0
	if kind == "live":
		if off <= CLEAN:
			got_q = 1.0
		elif off <= CROOKED or point < NOSE:
			got_q = 0.5
		else:
			got_kind = "dead"     # (back through its eyes: that's killed it)
	Sfx.play_point(self, _fish.global_position, "dock.slap", 0.35, 1.9)
	_send_from = _fish.global_transform
	phase = "send"
	t = 0.0


func _end(done: bool) -> void:
	var me := _me()
	if me != null:
		var held := me.get("hands") as Node
		held.set("rigging", false)
		if done:
			held.call("carry", "")
	if done:
		spread.call("request_bait", rod, got_kind, got_q)
		if got_kind == "dead" and kind == "live":
			var hud: Node = (spread.get("sea").get("crew") as Node).get("hud")
			if hud:
				hud.call("notify", "Through the eyes: killed it. It's on, but dead")
		elif got_q < 0.9:
			var hud: Node = (spread.get("sea").get("crew") as Node).get("hud")
			if hud:
				hud.call("notify", "On crooked: it'll swim poorly")
	rod = -1
	phase = ""
	_fish.visible = false
	_hook.visible = false


## Your sleeve from the glove on the fish back to your left elbow (crew/hands.gd's ELBOWS).
func _aim_sleeve(me: Node3D) -> void:
	var cam: Camera3D = me.get("cam")
	var sleeve := _glove.get_node_or_null("Sleeve") as Node3D
	if cam == null or sleeve == null:
		return
	var elbow := cam.global_transform * Vector3(-0.42, -0.72, 0.02)
	if sleeve.global_position.distance_squared_to(elbow) > 0.0001:
		sleeve.look_at(elbow, cam.global_basis.y)


func _work() -> Transform3D:
	var me := _me()
	var cam: Camera3D = me.get("cam") if me else null
	if cam == null:
		return Transform3D.IDENTITY
	# (lying across in front of you, its nose to the left, its back up)
	return cam.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5), WORK)


func _me() -> Node3D:
	var crew: Node = spread.get("sea").get("crew") if spread else null
	return crew.get("me") if crew else null


func _live(me: Node) -> bool:
	return bool(me.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
