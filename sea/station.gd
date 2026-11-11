extends Node3D
## A berth's hoist, pump and ice bin (sea/places.gd makes one for each of the harbour's four berths: the career's and
## Rivals' A on the fish pier's west float, B on its east, C and D down the town float's west and east sides; the same
## kit at the same reach, mirrored): the buyer's davit and hanging scale and his tote, the buyer; the fuel dock's pump;
## the ice plant's bin. Each serves the boat alongside it (her fish box under the davit's arm, her filler in the hose's
## reach): her own books (boat/fish_hold.gd), her own sale. With nobody alongside one (the career's one boat, a Rivals
## of fewer than four) it stands there as a working harbour's does, and does nothing: no fish in its reach, no filler
## in its hose's.
##
## The hoist: hold E on its crank and the arm swings out over her and the hook goes down to the next fish (one on deck,
## else one out of her open fish box), up out of her, over onto the scale. The buyer cores it, grades it
## (tuna/handling.gd, fish_hold.gd's host_sell), calls the price, her slip gets its line, and the fish goes down into
## his tote. The pump: hold E and the hose runs into her, her tank filling (the gauge on her dash), paid as it runs.
## The bin: the scoop on it takes a scoop of ice; the scoop on her open fish box tips it in.
##
## The host keeps it (the books are the boats'); the arm, hook and fish are drawn the same on every peer from the
## host's word (_hoist), ~10 a second.

const Tuna := preload("res://tuna/tuna.gd")
const Kinds := preload("res://boat/kinds.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const Sfx := preload("res://audio/sfx.gd")
const Quay := preload("res://sea/quay.gd")

## The hoist: how quickly the crank goes round (of a phase a second); its arm's height over the float, how far out it
## reaches (a sportfisher's box is 4.5 to 4.8 m from her berth's davit lying snug, and she rides up to a good half
## metre further off on her lines); the buyer's grading (coring, the call, the fish into the tote).
const CRANK := 0.85
const ARM_Y := 4.6
const REACH := 6.0
const CORE := 1.4
const CALLED := 3.0
const STOWED := 3.6
## The pump: a tank a this many s holding E (quicker with the quick prep); how far its hose runs to her filler (m: a
## skiff at the pier's east float has hers 8.8 m from the pump, and she rides about on her lines).
const PUMP_S := 24.0
const HOSE := 10.0

var places: Node              # sea/places.gd
var sea: Node                 # sea/sea.gd
## Which berth (sea/harbour.gd's berth_at: 0 and 2 lie west of their float, 1 and 3 east), and so which way it all
## faces.
var index := 0
var _side := 1.0
var _turn := 0.0
## The hoist (the host's): its phase (0 hook up over the scale .. 1 down at the fish .. 2 up clear of her .. 3 hung
## on the scale), the fish on it ({} none: its record off her books), grading (s since it was hung; -1 not), the
## price called ([kg, grade, $, why] or []), and whose books it came off (the boat it came out of).
var h_t := 0.0
var h_fish := {}
var h_grade := -1.0
var h_call: Array = []
var _from: Node3D = null
var _crank_at := -100000
var _send := 0.0
## Where it all is (world).
var davit := Vector3.ZERO
var scale_at := Vector3.ZERO
var pump_at := Vector3.ZERO
var bin_at := Vector3.ZERO
## Where the buyer stands and which way he faces (INF: by his tote's inboard corner, as on the pier), and the ice
## plant's pipe to the bin's chute if it's to be seen (world points, from the chute's head back ashore; on the pier
## the chute comes down off the pier's own).
var buyer_at := Vector3.INF
var buyer_yaw := 0.0
var ice_pipe: Array[Vector3] = []
var _hoist_root: Node3D
var _pump_root: Node3D
var _arm: Node3D
var _trolley: Node3D
var _hook: Node3D
var _fall: MeshInstance3D
var _fish_mesh: Node3D
var _call_label: Label3D
var _dial: Label3D
var _buyer: Node3D
var _hose: ImmediateMesh
var _hose_mat: StandardMaterial3D
var _pumping_t := 0.0
var _pump_acc := 0.0


func _ready() -> void:
	_side = 1.0 if index % 2 == 0 else -1.0
	_turn = 0.0 if index % 2 == 0 else PI
	_build_hoist()
	_build_pump()
	_build_bin()
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_hoist.rpc_id(id, h_t, h_fish, h_grade, h_call))


## The boats that could be alongside it, each with her books: [[boat, fish_hold], ...] (Rivals: every one).
func _pairs() -> Array:
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		return (vs.get("sides") as Array).map(func(s: Node) -> Array: return [s.get("boat"), s.get("fish_hold")])
	return [[sea.get("boat"), sea.get("fish_hold")]]


## The boat it's serving: the one whose fish box is nearest the davit (and her books).
func _pair() -> Array:
	var best: Array = []
	var d := INF
	for p: Array in _pairs():
		var b: Node3D = p[0]
		if b == null:
			continue
		var box := b.to_global((b.get("spec") as Dictionary).get("box", Vector3.ZERO) as Vector3)
		var e := Vector2(box.x - davit.x, box.z - davit.z).length()
		if e < d:
			d = e
			best = p
	return best


func _boat() -> Node3D:
	var p := _pair()
	return p[0] if not p.is_empty() else null


func _hold() -> Node:
	if _from != null and is_instance_valid(_from) and not h_fish.is_empty():
		return (_from.get("sea") as Node).get("fish_hold")
	var p := _pair()
	return p[1] if not p.is_empty() else null


func _me() -> Node:
	var crew: Node = sea.get("crew")
	return crew.get("me") if crew else null


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _live(me: Node) -> bool:
	return me != null and (bool(me.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	if Net.is_host():
		_host_hoist(delta)
	_crank_held(delta)
	_pump_held(delta)
	_show_hoist()
	_show_hose()


func _build_hoist() -> void:
	var steel := Color(0.25, 0.35, 0.5)
	var root := Node3D.new()
	root.name = "Hoist"
	_hoist_root = root
	root.position = davit
	add_child(root)
	# the post, its foot plate on the float, the crank on its side
	places._boxm(root, Vector3(0, 0.03, 0), Vector3(0.7, 0.06, 0.7), steel.darkened(0.3))
	places._boxm(root, Vector3(0, ARM_Y * 0.5, 0), Vector3(0.22, ARM_Y, 0.22), steel)
	places.quay.call("add_box", davit + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4))
	var crank := Node3D.new()
	crank.position = Vector3(0.2 * _side, 1.05, 0.0)
	root.add_child(crank)
	places._boxm(crank, Vector3(0.06, 0, 0), Vector3(0.12, 0.3, 0.3), Color(0.3, 0.3, 0.32))
	places._boxm(crank, Vector3(0.16, 0.12, 0), Vector3(0.05, 0.05, 0.22), Color(0.75, 0.15, 0.1))
	crank.name = "Crank"
	places._act(root, Vector3(0.2 * _side, 1.05, 0.0), Vector3(0.7, 0.9, 0.9), func(_p: Node) -> void: pass, _hoist_prompt)
	# the arm (turns), the trolley along it, the fall and the hook
	_arm = Node3D.new()
	_arm.position = Vector3(0, ARM_Y, 0)
	root.add_child(_arm)
	places._boxm(_arm, Vector3(0, 0.1, -REACH * 0.5), Vector3(0.18, 0.2, REACH + 0.3), steel)
	places._boxm(_arm, Vector3(0, -0.4, -0.6), Vector3(0.08, 0.9, 0.08), steel.darkened(0.2))
	_trolley = Node3D.new()
	_arm.add_child(_trolley)
	places._boxm(_trolley, Vector3(0, -0.06, 0), Vector3(0.3, 0.12, 0.3), Color(0.3, 0.3, 0.32))
	_hook = Node3D.new()
	_hook.top_level = true
	root.add_child(_hook)
	places._boxm(_hook, Vector3(0, 0.1, 0), Vector3(0.22, 0.2, 0.1), Color(0.85, 0.85, 0.82))       # (the load cell)
	places._boxm(_hook, Vector3(0, -0.08, 0), Vector3(0.04, 0.16, 0.04), Color(0.6, 0.6, 0.6))
	_dial = places._label(_hook, Vector3(0, 0.1, 0.06), "", 12, Color(0.9, 0.3, 0.2), 0.004)
	_fall = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.02, 1.0, 0.02)
	_fall.mesh = cm
	_fall.material_override = places._mat(Color(0.5, 0.5, 0.5))
	_fall.top_level = true
	root.add_child(_fall)
	# the buyer's tote under the scale (on the pier's deck; on the town float's own), and the buyer
	var tote := Node3D.new()
	tote.position = scale_at
	add_child(tote)
	places._tote_box(tote, Vector3(1.2, 0.75, 2.0), Color(0.2, 0.42, 0.62))
	places._boxm(tote, Vector3(0, 0.6, 0), Vector3(1.1, 0.05, 1.9), Color(0.78, 0.86, 0.9))         # (its ice)
	places.quay.call("add_box", scale_at + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 2.0))
	if buyer_at == Vector3.INF:
		buyer_at = scale_at + Vector3(0.95 * _side, 0.0, 1.0)
		buyer_yaw = PI * 0.65 * _side
	_buyer = places._person(buyer_at, buyer_yaw, Color(0.86, 0.86, 0.84), "THE BUYER")
	_call_label = places._label(self, scale_at + Vector3(0.0, 2.9, 0.0), "", 24, Color(1.0, 0.86, 0.5), 0.006)
	_call_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var sign: Label3D = places._label(self, scale_at + Vector3(-0.62 * _side, 1.2, 0.0), "FISH CO.\nSCALE", 24, Color(0.95, 0.93, 0.85), 0.004)
	sign.rotation.y = -PI * 0.5 + _turn


func _build_pump() -> void:
	var root := Node3D.new()
	root.name = "Pump"
	_pump_root = root
	root.position = pump_at
	add_child(root)
	places._boxm(root, Vector3(0, 0.7, 0), Vector3(0.6, 1.4, 0.45), Color(0.78, 0.16, 0.12))
	places._boxm(root, Vector3(0, 1.1, -0.23), Vector3(0.4, 0.3, 0.02), Color(0.1, 0.1, 0.1))
	places._boxm(root, Vector3(-0.32 * _side, 0.9, 0), Vector3(0.06, 0.2, 0.12), Color(0.15, 0.15, 0.15))     # (the nozzle in its holster)
	places._label(root, Vector3(0, 1.48, -0.24), "DIESEL", 12, Color(0.95, 0.93, 0.85), 0.006).rotation.y = PI
	places.quay.call("add_box", pump_at + Vector3(0, 0.7, 0), Vector3(0.6, 1.4, 0.45))
	places._act(root, Vector3(0, 1.0, 0), Vector3(0.9, 0.9, 0.9), func(_p: Node) -> void: pass, _pump_prompt)
	_hose = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _hose
	mi.top_level = true
	_hose_mat = places._mat(Color(0.08, 0.08, 0.09))
	_hose_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hose_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = _hose_mat
	add_child(mi)


func _build_bin() -> void:
	var root := Node3D.new()
	root.name = "IceBin"
	root.position = bin_at
	add_child(root)
	places._tote_box(root, Vector3(1.0, 0.9, 1.2), Color(0.88, 0.88, 0.85))
	places._boxm(root, Vector3(0, 0.82, 0), Vector3(0.9, 0.06, 1.1), Color(0.8, 0.88, 0.92))
	# its chute down from the ice plant's pipe along the pier (the town float's: its own pipe out from the quay)
	places._boxm(root, Vector3(0.6 * _side, 2.6, 0), Vector3(0.3, 0.3, 0.3), Color(0.6, 0.62, 0.64))
	places._boxm(root, Vector3(0.3 * _side, 1.8, 0), Vector3(0.22, 1.4, 0.22), Color(0.6, 0.62, 0.64)).rotation.z = 0.35 * _side
	for k in ice_pipe.size() - 1:
		var a := ice_pipe[k]
		var b := ice_pipe[k + 1]
		places._boxm(self, (a + b) * 0.5, (b - a).abs() + Vector3(0.22, 0.22, 0.22), Color(0.6, 0.62, 0.64))
	places._label(root, Vector3(0, 1.05, -0.62), "ICE  $%d A SCOOP" % FishHold.ICE_PRICE, 12, Color(0.15, 0.2, 0.3), 0.005) \
			.rotation.y = PI
	places.quay.call("add_box", bin_at + Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 1.2))
	places._act(root, Vector3(0, 0.9, 0), Vector3(1.0, 0.5, 1.2), func(_p: Node) -> void: pass,
			func() -> String:
				var hold := _hold()
				if hold == null or str(hold.get("prep")) == "off":
					return ""
				var me := _me()
				var hands: Node = me.get("hands") if me else null
				if hands != null and bool(hands.get("scoop_ice")):
					return "Tip it in her open fish box"
				if hands != null and str(hands.get("item")) == "scoop":
					return "LMB|A SCOOP OF ICE ($%d)" % FishHold.ICE_PRICE
				return "4|THE SCOOP: ICE FOR HER BOX (%d OF %d IN IT)" % [int(hold.get("ice")), int(hold.call("ice_room"))],
			func(p: Node, item: String, pressed: bool) -> bool:
				if item != "scoop" or not pressed:
					return false
				var hands: Node = p.get("hands")
				if hands == null or bool(hands.get("scoop_full")) or bool(hands.get("scoop_ice")):
					return false
				var hold := _hold()
				if hold == null or int(hold.get("bank")) < FishHold.ICE_PRICE:
					return false
				hands.set("scoop_ice", true)
				p.call("gesture", "scoop")
				Sfx.play_point(self, bin_at + Vector3(0, 0.9, 0), "dock.slap", 0.4, 1.8)
				return true)


# ------------------------------------------------------------------ the hoist

## Where the hook's after: the next fish aboard her (one on deck first, else one in her open box) and where it is
## (world); [] if there's none, her box shut with only iced ones in it, or she's not under the arm.
func _next_fish() -> Array:
	var hold := _hold()
	var boat := _boat()
	if hold == null or boat == null:
		return []
	var spec: Dictionary = boat.get("spec")
	var deck: Dictionary = hold.get("_deck")
	for f: Dictionary in hold.get("fish"):
		if float(f["iced_s"]) < 0.0 and deck.has(int(f["id"])):
			var at := (deck[int(f["id"])] as Node3D).global_position
			if _in_reach(at):
				return [int(f["id"]), at]
	if bool(hold.get("box_open")):
		var box := boat.to_global(spec.get("box", Vector3.ZERO) as Vector3)
		for f: Dictionary in hold.get("fish"):
			if float(f["iced_s"]) >= 0.0 and _in_reach(box):
				return [int(f["id"]), box]
	return []


func _in_reach(at: Vector3) -> bool:
	var d := Vector2(at.x - davit.x, at.z - davit.z).length()
	return d > 1.0 and d < REACH


func _hoist_prompt() -> String:
	if h_grade >= 0.0:
		return "The buyer's grading it"
	var hold := _hold()
	if hold == null or not bool(hold.get("docked")):
		return "The fish buyer's hoist: tie her up alongside it first"
	if not h_fish.is_empty():
		return "Hold E: crank him over onto the scale"
	if (hold.get("fish") as Array).is_empty():
		return "The fish buyer's hoist: nothing aboard her to sell"
	if _next_fish().is_empty():
		var iced := (hold.get("fish") as Array).any(func(f: Dictionary) -> bool: return float(f["iced_s"]) >= 0.0)
		return "Open her fish box for the hook" if iced and not bool(hold.get("box_open")) \
				else "Bring her fish box in under the hoist's arm"
	return "Hold E: crank the hook down to the next fish"


## Your E held on the crank: the word to the host, a few times a second.
func _crank_held(delta: float) -> void:
	var me := _me()
	if not _live(me):
		return
	var at: Node = me.call("looking_at")
	if at == null or at.get_parent() != _hoist_root:
		return
	if not Input.is_action_pressed("interact"):
		return
	_send -= delta
	if _send > 0.0:
		return
	_send = 0.1
	if Net.is_host():
		_ask_crank()
	else:
		_ask_crank.rpc_id(1)


@rpc("any_peer", "call_remote", "unreliable")
func _ask_crank() -> void:
	_crank_at = Time.get_ticks_msec()


## Host (tests, dev): someone's on the crank this frame.
func host_crank() -> void:
	_crank_at = Time.get_ticks_msec()


func _host_hoist(delta: float) -> void:
	var hold := _hold()
	var was := [h_t, h_fish.is_empty(), h_grade]
	if h_grade >= 0.0:
		h_grade += delta
		if h_call.is_empty() and h_grade >= CORE:
			h_call = hold.call("host_sell", h_fish)
			Sfx.play_point(self, scale_at, "kit.coins", 0.7, 1.0)
		if h_grade >= STOWED:
			h_grade = -1.0
			h_fish = {}
			_from = null
			h_t = 0.0
		_hoist_tell(was)
		return
	var cranking := Time.get_ticks_msec() - _crank_at < 260
	if not cranking:
		return
	var rate := CRANK * float(hold.call("prep_rate")) if hold else CRANK
	if h_fish.is_empty():
		if not bool(hold.get("docked")):
			return
		var next := _next_fish()
		if next.is_empty():
			# (back up over the scale if it was on its way out: nothing to go down for)
			h_t = maxf(h_t - rate * delta, 0.0)
		else:
			h_t = minf(h_t + rate * delta, 1.0)
			if h_t >= 1.0:
				_from = _boat()
				h_fish = hold.call("host_unship", int(next[0]))
				h_fish["hooked_at"] = next[1]
				Sfx.play_point(self, next[1], "kit.chain", 0.6, 1.0)
	else:
		h_t = minf(h_t + rate * delta, 3.0)
		if h_t >= 3.0:
			h_grade = 0.0
			h_call = []
			Sfx.play_point(self, scale_at, "kit.clank", 0.6, 0.8)
	_hoist_tell(was)


func _hoist_tell(was: Array) -> void:
	_send_h -= get_process_delta_time()
	var changed: bool = bool(was[1]) != h_fish.is_empty() or (float(was[2]) < 0.0) != (h_grade < 0.0) \
			or (float(was[2]) < CORE and h_grade >= CORE)
	if not Net.in_session():
		return
	if changed:
		_hoist.rpc(h_t, h_fish, h_grade, h_call)
	elif _send_h <= 0.0 and (float(was[0]) != h_t or h_grade >= 0.0):
		_send_h = 0.1
		_hoist_t.rpc(h_t, h_grade)


var _send_h := 0.0


@rpc("authority", "call_remote", "reliable")
func _hoist(t: float, f: Dictionary, g: float, called: Array) -> void:
	h_t = t
	h_fish = f
	h_grade = g
	h_call = called


@rpc("authority", "call_remote", "unreliable_ordered")
func _hoist_t(t: float, g: float) -> void:
	h_t = t
	if h_grade >= 0.0 or g < 0.0:
		h_grade = g


## The hoist drawn from its phase: the arm's swing, the trolley out along it, the hook up or down, the fish on it.
func _show_hoist() -> void:
	var boat := _boat()
	var spec: Dictionary = boat.get("spec") if boat else {}
	var box := boat.to_global(spec.get("box", Vector3.ZERO) as Vector3) if boat else davit
	var target: Vector3 = box
	if h_fish.is_empty() and h_t > 0.0:
		var next := _next_fish()
		if not next.is_empty():
			target = next[1]
	elif not h_fish.is_empty() and h_fish.has("hooked_at"):
		target = h_fish["hooked_at"]
	var s_yaw := _yaw_to(scale_at)
	var b_yaw := _yaw_to(target)
	var s_r := Vector2(scale_at.x - davit.x, scale_at.z - davit.z).length()
	var b_r := clampf(Vector2(target.x - davit.x, target.z - davit.z).length(), 0.5, REACH)
	var high := davit.y + ARM_Y - 0.9
	var t := h_t
	var yaw: float
	var r: float
	var y: float
	if t < 0.5:
		var k := smoothstep(0.0, 1.0, t / 0.5)
		yaw = lerp_angle(s_yaw, b_yaw, k)
		r = lerpf(s_r, b_r, k)
		y = high
	elif t < 1.0:
		yaw = b_yaw
		r = b_r
		y = lerpf(high, target.y + 0.35, smoothstep(0.0, 1.0, (t - 0.5) / 0.5))
	elif t < 1.5:
		yaw = b_yaw
		r = b_r
		y = lerpf(target.y + 0.35, high, smoothstep(0.0, 1.0, (t - 1.0) / 0.5))
	elif t < 2.5:
		var k := smoothstep(0.0, 1.0, (t - 1.5) / 1.0)
		yaw = lerp_angle(b_yaw, s_yaw, k)
		r = lerpf(b_r, s_r, k)
		y = high
	else:
		yaw = s_yaw
		r = s_r
		y = lerpf(high, scale_at.y + 1.0 + _fish_len() * 0.5 + 0.3, smoothstep(0.0, 1.0, (t - 2.5) / 0.5))
	if h_grade >= 0.0:
		# hung on the scale; once he's called it, down into his tote, and the hook back up
		yaw = s_yaw
		r = s_r
		var hung := scale_at.y + 1.0 + _fish_len() * 0.5 + 0.3
		var down := scale_at.y + 0.5 + _fish_len() * 0.5
		if h_grade < CALLED:
			y = hung
		elif h_grade < CALLED + 0.4:
			y = lerpf(hung, down, smoothstep(0.0, 1.0, (h_grade - CALLED) / 0.4))
		else:
			y = lerpf(down, high, smoothstep(0.0, 1.0, (h_grade - CALLED - 0.4) / (STOWED - CALLED - 0.4)))
	_arm.rotation.y = yaw
	_trolley.position = Vector3(0, 0, -r)
	var top := _trolley.global_position
	var hook := Vector3(top.x, y, top.z)
	_hook.global_position = hook
	_fall.global_position = (top + hook) * 0.5
	_fall.scale = Vector3(1.0, maxf(top.y - hook.y, 0.05), 1.0)
	# the fish on the hook, tail up
	var carrying := not h_fish.is_empty() and (h_grade < 0.0 or h_grade < CALLED + 0.4)
	if carrying and _fish_mesh == null:
		_fish_mesh = Tuna.new(float(h_fish.get("kg", 100.0)))
		_fish_mesh.set("posed", true)
		_fish_mesh.set("limp", true)
		add_child(_fish_mesh)
	elif not carrying and _fish_mesh != null:
		_fish_mesh.queue_free()
		_fish_mesh = null
	if _fish_mesh != null:
		var len := float(_fish_mesh.get("length"))
		_fish_mesh.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5),
				hook - Vector3(0, 0.12 + len * 0.5, 0))
	_dial.text = "%d KG" % roundi(float(h_fish.get("kg", 0.0))) if not h_fish.is_empty() and h_t >= 1.2 else ""
	# the buyer at it, and his call
	_buyer.set_meta("busy", 1.0 if h_grade >= 0.0 and h_grade < CORE else 0.0)
	if h_grade >= CORE and not h_call.is_empty():
		_call_label.text = "%d KG  %s  $%s" % [roundi(float(h_call[0])), str(h_call[1]).to_upper(),
				FishHold._money(int(h_call[2]))]
		_call_label.modulate.a = clampf((STOWED + 1.5 - h_grade) / 1.0, 0.0, 1.0)
	elif h_grade < 0.0 and _call_label.modulate.a > 0.0:
		_call_label.modulate.a = maxf(_call_label.modulate.a - get_process_delta_time(), 0.0)


func _fish_len() -> float:
	return float(_fish_mesh.get("length")) if _fish_mesh != null else 1.6


func _yaw_to(p: Vector3) -> float:
	var d := p - davit
	return atan2(-d.x, -d.z)


# ------------------------------------------------------------------ the pump

func _pump_prompt() -> String:
	var hold := _hold()
	if hold == null or str(hold.get("prep")) == "off":
		return "The fuel dock: she's filled as she casts off"
	if _hose_end() == Vector3.INF:
		return "The fuel dock: bring her alongside the pump"
	var f := float(hold.get("fuel"))
	if f >= 0.999:
		return "Her tank's full"
	return "Hold E: fill her up  (%d%%, $%s a tank)" % [roundi(f * 100.0),
			FishHold._money(int(Kinds.spec(str(hold.get("kind"))).get("fuel", 60)))]


## Her filler, if the hose reaches it from the pump (world), else INF.
func _hose_end() -> Vector3:
	var boat := _boat()
	if boat == null:
		return Vector3.INF
	var side := 1.0 if boat.to_local(pump_at).x > 0.0 else -1.0
	var spec: Dictionary = boat.get("spec")
	var rail: Array = spec.get("rail", [])
	var p: Vector3 = rail[1] if rail.size() > 1 else Vector3(float(boat.get("beam")) * 0.5, 1.1, 0.0)
	var fill := boat.to_global(Vector3(side * (absf(p.x) - 0.15), p.y, p.z))
	return fill if fill.distance_to(pump_at) < HOSE else Vector3.INF


func _pump_held(delta: float) -> void:
	var me := _me()
	_pumping_t = maxf(_pumping_t - delta, 0.0)
	if not _live(me):
		return
	var at: Node = me.call("looking_at")
	if at == null or at.get_parent() != _pump_root or not Input.is_action_pressed("interact"):
		return
	var hold := _hold()
	if hold == null or str(hold.get("prep")) == "off" or _hose_end() == Vector3.INF:
		return
	_pumping_t = 0.3
	if Net.is_host():
		_ask_fill(delta)
	else:
		_pump_acc += delta
		if _pump_acc >= 0.1:
			_ask_fill.rpc_id(1, _pump_acc)
			_pump_acc = 0.0


@rpc("any_peer", "call_remote", "unreliable")
func _ask_fill(secs: float) -> void:
	var hold := _hold()
	if hold == null or _hose_end() == Vector3.INF:
		return
	hold.call("host_fill", minf(secs, 0.5) / PUMP_S * float(hold.call("prep_rate")))
	_say_pumping()


func _say_pumping() -> void:
	_pumping_t = 0.3
	if Net.in_session():
		_pumping.rpc()


@rpc("authority", "call_remote", "unreliable")
func _pumping() -> void:
	_pumping_t = 0.3


func _show_hose() -> void:
	_hose.clear_surfaces()
	var end := _hose_end()
	var cam := get_viewport().get_camera_3d()
	if _pumping_t <= 0.0 or end == Vector3.INF or cam == null:
		return
	_hose.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _hose_mat)
	var a := pump_at + Vector3(-0.32 * _side, 0.9, 0)
	var n := 10
	var prev := a
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(end, t) + Vector3.DOWN * 0.6 * 4.0 * t * (1.0 - t)
		var side := (p - prev).normalized().cross((cam.global_position - p).normalized()).normalized() * 0.025
		for v: Vector3 in [prev - side, prev + side, p + side, prev - side, p + side, p - side]:
			_hose.surface_add_vertex(v)
		prev = p
	_hose.surface_end()


