extends Node3D
## The harbour's places, where the dock's business is done by walking up to it (sea/quay.gd is what's walked on):
##
##   the hoist   a davit on the west float abeam her fish box, the buyer's hanging scale and his tote on the pier by
##               it. Hold E on its crank: the arm swings out over her and the hook goes down to the next fish (one on
##               deck, else one out of her open fish box), up out of her, over onto the scale. The buyer cores it,
##               grades it (tuna/handling.gd's grade and why, boat/fish_hold.gd's host_sell), calls the price, the
##               slip gets its line, and the fish goes down into his tote. The next.
##   the pump    the fuel dock's pump on the float: hold E and the hose runs into her, her tank filling (the gauge on
##               her dash), the money going as it runs.
##   the ice     the ice plant's bin on the float, kept full down its chute: the scoop (4) on it takes a scoop of ice,
##               the scoop on her open fish box tips it in.
##   counters    on the street, each with its keeper: the CHANDLERY (gear), BAIT & TACKLE (a tote of live mackerel to
##               carry aboard and tip into her well: E on her live well), the HARBOR MASTER (the quota, the run's
##               record, the dock prep, a new career); the broker's board on the quay (the boats); the buyer's slip
##               pinned up at his shed's door. E at one: its card, small, in the pixel font (ui's), till you walk off or
##               Esc.
##
## The host keeps it all (the books are boat/fish_hold.gd's); the hoist's arm, hook and fish are drawn the same on
## every peer from the host's word (_hoist), ~10 a second.

const Action := preload("res://core/action.gd")
const Tuna := preload("res://tuna/tuna.gd")
const Kinds := preload("res://boat/kinds.gd")
const FishHold := preload("res://boat/fish_hold.gd")
const PixFont := preload("res://ui/pixfont.gd")
const Sfx := preload("res://audio/sfx.gd")
const Handling := preload("res://tuna/handling.gd")
const CREW := preload("res://crew/crew.glb")
const Quay := preload("res://sea/quay.gd")

## The hoist: how quickly the crank goes round (of a phase a second); its arm's height over the float, how far out it
## reaches; the buyer's grading (coring, the call, the fish into the tote).
const CRANK := 0.85
const ARM_Y := 4.6
const REACH := 5.4
const CORE := 1.4
const CALLED := 3.0
const STOWED := 3.6
## The pump: a tank a this many s holding E (quicker with the quick prep).
const PUMP_S := 24.0
## How far from a counter you can be served (m).
const SERVE := 3.2

var sea: Node                 # sea/sea.gd
var quay: Node                # sea/quay.gd
## The hoist (the host's): its phase (0 hook up over the scale .. 1 down at the fish .. 2 up clear of her .. 3 hung
## on the scale), the fish on it ({} none: its record off fish_hold.gd's books), grading (s since it was hung; -1 not),
## the price called ([kg, grade, $, why] or []).
var h_t := 0.0
var h_fish := {}
var h_grade := -1.0
var h_call: Array = []
var _crank_at := -100000
var _send := 0.0
## Who's carrying a tote of mackerel (peer id -> true).
var carriers := {}
## Where it all is (world).
var davit := Vector3.ZERO
var scale_at := Vector3.ZERO
var pump_at := Vector3.ZERO
var bin_at := Vector3.ZERO
var counters := {}            # name -> {at, face, fill (Callable), keeper}
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
var _tote_meshes := {}
var _folk: Array[Node3D] = []
var _t := 0.0
## The card at a counter (yours, on your screen: nobody else's business).
var _card: CanvasLayer
var _card_box: VBoxContainer
var _serving := ""
var _wipe := false


func _ready() -> void:
	var harbour: Node = sea.get("harbour")
	quay = harbour.get("quay")
	var px := float(harbour.get("PIER_X"))
	var face := float(quay.call("face"))
	var dz := face - 17.3
	davit = Vector3(px - 2.9, Quay.FLOAT_Y, dz)
	scale_at = Vector3(px - 1.0, float(harbour.get("DECK_Y")), dz)
	pump_at = Vector3(px - 2.9, Quay.FLOAT_Y, face - 22.3)
	bin_at = Vector3(px - 2.9, Quay.FLOAT_Y, face - 19.8)
	_build_hoist()
	_build_pump()
	_build_bin()
	_build_counters(harbour)
	_build_card()
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			_carriers.rpc_id(id, carriers)
			_hoist.rpc_id(id, h_t, h_fish, h_grade, h_call))
	Net.peer_left.connect(func(id: int) -> void:
		if Net.is_host() and carriers.has(id):
			carriers.erase(id)
			_say_carriers())


func _hold() -> Node:
	return sea.get("fish_hold")


func _boat() -> Node3D:
	return sea.get("boat")


func _me() -> Node:
	var crew: Node = sea.get("crew")
	return crew.get("me") if crew else null


func _now() -> float:
	return float((sea.get("ocean") as Node).get("wave_time"))


func _live(me: Node) -> bool:
	return me != null and (bool(me.get("force_input")) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


# ------------------------------------------------------------------ building

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _boxm(parent: Node3D, at: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = at
	parent.add_child(mi)
	return mi


func _label(parent: Node3D, at: Vector3, text: String, size: int, col: Color, px := 0.004) -> Label3D:
	var l := Label3D.new()
	l.font = PixFont.font()
	l.font_size = size
	l.pixel_size = px
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.modulate = col
	l.outline_size = 0
	l.text = text
	l.position = at
	parent.add_child(l)
	return l


func _act(parent: Node3D, at: Vector3, size: Vector3, use: Callable, prompt: Callable, use_with := Callable()) -> Action:
	var a := Action.new(size)
	a.position = at
	a.use = use
	a.prompt = prompt
	if use_with.is_valid():
		a.use_with = use_with
	parent.add_child(a)
	return a


func _build_hoist() -> void:
	var steel := Color(0.25, 0.35, 0.5)
	var root := Node3D.new()
	root.name = "Hoist"
	root.position = davit
	add_child(root)
	# the post, its foot plate on the float, the crank on its side
	_boxm(root, Vector3(0, 0.03, 0), Vector3(0.7, 0.06, 0.7), steel.darkened(0.3))
	_boxm(root, Vector3(0, ARM_Y * 0.5, 0), Vector3(0.22, ARM_Y, 0.22), steel)
	quay.call("add_box", davit + Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4))
	var crank := Node3D.new()
	crank.position = Vector3(0.2, 1.05, 0.0)
	root.add_child(crank)
	_boxm(crank, Vector3(0.06, 0, 0), Vector3(0.12, 0.3, 0.3), Color(0.3, 0.3, 0.32))
	_boxm(crank, Vector3(0.16, 0.12, 0), Vector3(0.05, 0.05, 0.22), Color(0.75, 0.15, 0.1))
	crank.name = "Crank"
	_act(root, Vector3(0.2, 1.05, 0.0), Vector3(0.7, 0.9, 0.9), func(_p: Node) -> void: pass, _hoist_prompt)
	# the arm (turns), the trolley along it, the fall and the hook
	_arm = Node3D.new()
	_arm.position = Vector3(0, ARM_Y, 0)
	root.add_child(_arm)
	_boxm(_arm, Vector3(0, 0.1, -REACH * 0.5), Vector3(0.18, 0.2, REACH + 0.3), steel)
	_boxm(_arm, Vector3(0, -0.4, -0.6), Vector3(0.08, 0.9, 0.08), steel.darkened(0.2))
	_trolley = Node3D.new()
	_arm.add_child(_trolley)
	_boxm(_trolley, Vector3(0, -0.06, 0), Vector3(0.3, 0.12, 0.3), Color(0.3, 0.3, 0.32))
	_hook = Node3D.new()
	_hook.top_level = true
	root.add_child(_hook)
	_boxm(_hook, Vector3(0, 0.1, 0), Vector3(0.22, 0.2, 0.1), Color(0.85, 0.85, 0.82))       # (the load cell)
	_boxm(_hook, Vector3(0, -0.08, 0), Vector3(0.04, 0.16, 0.04), Color(0.6, 0.6, 0.6))
	_dial = _label(_hook, Vector3(0, 0.1, 0.06), "", 12, Color(0.9, 0.3, 0.2), 0.004)
	_fall = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.02, 1.0, 0.02)
	_fall.mesh = cm
	_fall.material_override = _mat(Color(0.5, 0.5, 0.5))
	_fall.top_level = true
	root.add_child(_fall)
	# the buyer's tote on the pier under the scale, and the buyer
	var tote := Node3D.new()
	tote.position = scale_at
	add_child(tote)
	_tote_box(tote, Vector3(1.2, 0.75, 2.0), Color(0.2, 0.42, 0.62))
	_boxm(tote, Vector3(0, 0.6, 0), Vector3(1.1, 0.05, 1.9), Color(0.78, 0.86, 0.9))         # (its ice)
	quay.call("add_box", scale_at + Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 2.0))
	_buyer = _person(scale_at + Vector3(0.95, 0.0, 1.0), PI * 0.65, Color(0.86, 0.86, 0.84), "THE BUYER")
	_call_label = _label(self, scale_at + Vector3(0.0, 2.9, 0.0), "", 24, Color(1.0, 0.86, 0.5), 0.006)
	_call_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var sign := _label(self, scale_at + Vector3(-0.62, 1.2, 0.0), "FISH CO.\nSCALE", 24, Color(0.95, 0.93, 0.85), 0.004)
	sign.rotation.y = -PI * 0.5


## A tote: a box open at the top (four walls and a floor).
func _tote_box(parent: Node3D, s: Vector3, c: Color) -> void:
	_boxm(parent, Vector3(0, 0.03, 0), Vector3(s.x, 0.06, s.z), c.darkened(0.2))
	for side: float in [-1.0, 1.0]:
		_boxm(parent, Vector3(side * (s.x - 0.06) * 0.5, s.y * 0.5, 0), Vector3(0.06, s.y, s.z), c)
		_boxm(parent, Vector3(0, s.y * 0.5, side * (s.z - 0.06) * 0.5), Vector3(s.x, s.y, 0.06), c)


func _build_pump() -> void:
	var root := Node3D.new()
	root.name = "Pump"
	root.position = pump_at
	add_child(root)
	_boxm(root, Vector3(0, 0.7, 0), Vector3(0.6, 1.4, 0.45), Color(0.78, 0.16, 0.12))
	_boxm(root, Vector3(0, 1.1, -0.23), Vector3(0.4, 0.3, 0.02), Color(0.1, 0.1, 0.1))
	_boxm(root, Vector3(-0.32, 0.9, 0), Vector3(0.06, 0.2, 0.12), Color(0.15, 0.15, 0.15))     # (the nozzle in its holster)
	_label(root, Vector3(0, 1.48, -0.24), "DIESEL", 12, Color(0.95, 0.93, 0.85), 0.006).rotation.y = PI
	quay.call("add_box", pump_at + Vector3(0, 0.7, 0), Vector3(0.6, 1.4, 0.45))
	_act(root, Vector3(0, 1.0, 0), Vector3(0.9, 0.9, 0.9), func(_p: Node) -> void: pass, _pump_prompt)
	_hose = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _hose
	mi.top_level = true
	_hose_mat = _mat(Color(0.08, 0.08, 0.09))
	_hose_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hose_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = _hose_mat
	add_child(mi)


func _build_bin() -> void:
	var root := Node3D.new()
	root.name = "IceBin"
	root.position = bin_at
	add_child(root)
	_tote_box(root, Vector3(1.0, 0.9, 1.2), Color(0.88, 0.88, 0.85))
	_boxm(root, Vector3(0, 0.82, 0), Vector3(0.9, 0.06, 1.1), Color(0.8, 0.88, 0.92))
	# its chute down from the ice plant's pipe along the pier
	_boxm(root, Vector3(0.6, 2.6, 0), Vector3(0.3, 0.3, 0.3), Color(0.6, 0.62, 0.64))
	_boxm(root, Vector3(0.3, 1.8, 0), Vector3(0.22, 1.4, 0.22), Color(0.6, 0.62, 0.64)).rotation.z = 0.35
	_label(root, Vector3(0, 1.05, -0.62), "ICE  $%d A SCOOP" % FishHold.ICE_PRICE, 12, Color(0.15, 0.2, 0.3), 0.005) \
			.rotation.y = PI
	quay.call("add_box", bin_at + Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 1.2))
	_act(root, Vector3(0, 0.9, 0), Vector3(1.0, 0.5, 1.2), func(_p: Node) -> void: pass,
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


func _build_counters(harbour: Node) -> void:
	var fronts: Dictionary = harbour.get("shop_fronts")
	var qy := float(harbour.get("QUAY_Y"))
	var face := float(quay.call("face"))
	var px := float(harbour.get("PIER_X"))
	var spots := [
		["CHANDLERY", Color(0.14, 0.24, 0.44), "THE CHANDLER", _fill_chandlery],
		["BAIT & TACKLE", Color(0.16, 0.38, 0.26), "THE BAIT MAN", _fill_bait],
		["HARBOR MASTER", Color(0.12, 0.2, 0.34), "THE HARBOR MASTER", _fill_master],
	]
	for s: Array in spots:
		if not fronts.has(s[0]):
			continue
		var f: Vector3 = fronts[s[0]]
		var at := f + Vector3(0, 0, -1.3)
		_counter(at, PI, s[1], s[0])
		var keeper := _person(f + Vector3(0.2, 0.0, -0.55), PI, s[1].lightened(0.3), s[2])
		counters[s[0]] = {"at": at, "fill": s[3], "keeper": keeper}
		quay.call("add_box", f + Vector3(0, 0.6, -0.8), Vector3(2.6, 1.2, 1.6))
	# the broker's board on the quay by the pier's root, its listing up on it
	var b_at := Vector3(px - 9.0, qy, float(quay.call("shore", px - 9.0)) - 2.0 + 4.5)
	var board := Node3D.new()
	board.position = b_at
	add_child(board)
	for side: float in [-1.0, 1.0]:
		_boxm(board, Vector3(side * 1.1, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color(0.3, 0.24, 0.18))
	_boxm(board, Vector3(0, 1.45, 0), Vector3(2.4, 1.2, 0.06), Color(0.16, 0.2, 0.18))
	var listing := ""
	for k: String in Kinds.KINDS:
		var spec: Dictionary = Kinds.KINDS[k]
		listing += "%s  %s\n" % [str(spec["name"]).trim_prefix("the ").to_upper(),
				"$" + FishHold._money(int(spec["price"])) if int(spec["price"]) > 0 else "YOURS"]
	_label(board, Vector3(0, 1.86, -0.04), "BOATS FOR SALE & CHARTER", 12, Color(1.0, 0.78, 0.34), 0.006).rotation.y = PI
	_label(board, Vector3(0, 1.35, -0.04), listing, 12, Color(0.95, 0.93, 0.85), 0.005).rotation.y = PI
	quay.call("add_box", b_at + Vector3(0, 0.9, 0), Vector3(2.4, 1.8, 0.2))
	counters["BROKER"] = {"at": b_at + Vector3(0, 0.0, -0.4), "fill": _fill_broker, "keeper": null}
	_act(board, Vector3(0, 1.4, -0.1), Vector3(2.4, 1.3, 0.4), func(_p: Node) -> void: open("BROKER"),
			func() -> String: return "The broker's board: the boats")
	# the buyer's slip, pinned up by his shed's door
	var s_at := Vector3(px + 9.0, qy, face + 3.4)
	var slip := Node3D.new()
	slip.position = s_at
	add_child(slip)
	_boxm(slip, Vector3(0, 1.5, 0.0), Vector3(0.6, 0.8, 0.02), Color(0.95, 0.93, 0.86))
	_label(slip, Vector3(0, 1.75, -0.02), "THE\nSLIP", 12, Color(0.15, 0.17, 0.2), 0.005).rotation.y = PI
	counters["SLIP"] = {"at": s_at + Vector3(0, 0, -0.6), "fill": _fill_slip, "keeper": null}
	_act(slip, Vector3(0, 1.5, -0.1), Vector3(0.9, 1.0, 0.4), func(_p: Node) -> void: open("SLIP"),
			func() -> String: return "The buyer's slip")


## A counter on the sidewalk in front of a shop: its top, its front panel in the shop's colour, a few things on it,
## and E on it.
func _counter(at: Vector3, yaw: float, col: Color, place: String) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	_boxm(root, Vector3(0, 0.95, 0), Vector3(2.4, 0.08, 0.7), Color(0.5, 0.38, 0.24))
	_boxm(root, Vector3(0, 0.46, 0.3), Vector3(2.4, 0.9, 0.06), col)
	for side: float in [-1.0, 1.0]:
		_boxm(root, Vector3(side * 1.15, 0.46, 0), Vector3(0.08, 0.9, 0.66), col.darkened(0.2))
	_boxm(root, Vector3(-0.7, 1.08, 0), Vector3(0.36, 0.18, 0.28), Color(0.85, 0.82, 0.7))
	_boxm(root, Vector3(0.6, 1.04, -0.05), Vector3(0.5, 0.1, 0.34), Color(0.92, 0.9, 0.84))
	_act(root, Vector3(0, 1.1, 0), Vector3(2.4, 0.5, 0.9), func(_p: Node) -> void: open(place),
			func() -> String: return _counter_prompt(place))


func _counter_prompt(place: String) -> String:
	match place:
		"CHANDLERY":
			return "The chandlery: gear"
		"BAIT & TACKLE":
			return "Bait & tackle: live mackerel"
		"HARBOR MASTER":
			return "The harbor master: the quota, the run"
	return place.capitalize()


## A townsperson: the crew's own model (crew/crew.glb) in another colour, standing about, shifting their weight.
func _person(at: Vector3, yaw: float, col: Color, who: String) -> Node3D:
	var root := Node3D.new()
	root.name = who.replace(" ", "")
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var src := CREW.instantiate() as Node3D
	var parts := {}
	for n: String in ["torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "leg_l", "leg_r", "shin_l", "shin_r"]:
		var mi := src.find_child(n, true, false) as MeshInstance3D
		if mi == null:
			continue
		var t := mi.transform
		mi.owner = null
		mi.get_parent().remove_child(mi)
		mi.transform = t
		root.add_child(mi)
		parts[n] = mi
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if not m is BaseMaterial3D:
				continue
			var own := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			own.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			if m.resource_name == "oilskin":
				own.albedo_color = col
			mi.set_surface_override_material(i, own)
	src.free()
	var where := {}
	for n: String in parts:
		where[n] = (parts[n] as Node3D).transform
	for pair: Array in [["head", "torso"], ["arm_l", "torso"], ["arm_r", "torso"], ["fore_l", "arm_l"],
			["fore_r", "arm_r"], ["shin_l", "leg_l"], ["shin_r", "leg_r"]]:
		var c := parts.get(pair[0]) as Node3D
		var to := parts.get(pair[1]) as Node3D
		if c == null or to == null:
			continue
		c.get_parent().remove_child(c)
		to.add_child(c)
		c.transform = (where[pair[1]] as Transform3D).affine_inverse() * (where[pair[0]] as Transform3D)
	root.set_meta("parts", parts)
	root.set_meta("rest", parts.keys().map(func(n: String) -> Basis: return (parts[n] as Node3D).basis))
	root.set_meta("yaw", yaw)
	root.set_meta("at", at)
	root.set_meta("busy", 0.0)
	_folk.append(root)
	return root


## The folk standing about: breathing, weight from foot to foot, a look round now and then (toward you, if you're
## near); one with work on (the buyer coring) reaching in to it.
func _idle(delta: float) -> void:
	var me := _me()
	for i in _folk.size():
		var f := _folk[i]
		var parts: Dictionary = f.get_meta("parts")
		var rest: Array = f.get_meta("rest")
		var keys := parts.keys()
		var k := _t * 1.3 + i * 2.1
		var at: Vector3 = f.get_meta("at")
		f.position = at + Vector3(0, sin(k * 1.6) * 0.008, 0)
		var look := float(f.get_meta("yaw")) + sin(floorf((_t + i * 3.7) / 4.0) * 7.31) * 0.5
		if me != null and (me as Node3D).global_position.distance_to(at) < 6.0:
			var d := (me as Node3D).global_position - at
			look = atan2(-d.x, -d.z) + PI
		for j in keys.size():
			var p := parts[keys[j]] as Node3D
			p.basis = rest[j]
		var head := parts.get("head") as Node3D
		if head:
			head.rotate_object_local(Vector3.UP, wrapf(look - f.rotation.y - PI, -PI, PI) * 0.6 if me != null
					and (me as Node3D).global_position.distance_to(at) < 6.0 else sin(k * 0.4) * 0.4)
		var torso := parts.get("torso") as Node3D
		if torso:
			torso.rotate_object_local(Vector3.FORWARD, sin(k * 0.5) * 0.03)
		var busy := float(f.get_meta("busy"))
		var arm := parts.get("arm_r") as Node3D
		if arm and busy > 0.0:
			arm.rotate_object_local(Vector3.RIGHT, 1.2 + sin(_t * 9.0) * 0.25 * busy)
			var fore := parts.get("fore_r") as Node3D
			if fore:
				fore.rotate_object_local(Vector3.RIGHT, 0.6)


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
	if at == null or at.get_parent() == null or at.get_parent().name != "Hoist":
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
	return fill if fill.distance_to(pump_at) < 9.0 else Vector3.INF


func _pump_held(delta: float) -> void:
	var me := _me()
	_pumping_t = maxf(_pumping_t - delta, 0.0)
	if not _live(me):
		return
	var at: Node = me.call("looking_at")
	if at == null or at.get_parent() == null or at.get_parent().name != "Pump" or not Input.is_action_pressed("interact"):
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
	var a := pump_at + Vector3(-0.32, 0.9, 0)
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


# ------------------------------------------------------------------ the totes

## Whether crew member `p` has a tote of mackerel in their arms.
func carrying(p: Node) -> bool:
	return carriers.has(str(p.name).to_int())


## A tote off the bait shop's counter for you (the host's books pay), or tipped into her well.
func ask_tote(buy: bool) -> void:
	if Net.is_host():
		_ask_tote(buy)
	else:
		_ask_tote.rpc_id(1, buy)


@rpc("any_peer", "call_remote", "reliable")
func _ask_tote(buy: bool) -> void:
	var who := multiplayer.get_remote_sender_id()
	if who == 0:
		who = Net.my_id()
	var hold := _hold()
	if hold == null:
		return
	if buy:
		if carriers.has(who) or not bool(hold.call("host_buy_tote")):
			return
		carriers[who] = true
	else:
		if not carriers.has(who):
			return
		carriers.erase(who)
		hold.call("host_tote_in")
	_say_carriers()


func _say_carriers() -> void:
	if Net.in_session():
		_carriers.rpc(carriers)


@rpc("authority", "call_remote", "reliable")
func _carriers(c: Dictionary) -> void:
	carriers = c


func _show_totes() -> void:
	var crew: Node = sea.get("crew")
	for id: int in _tote_meshes.keys():
		if not carriers.has(id):
			(_tote_meshes[id] as Node).queue_free()
			_tote_meshes.erase(id)
	for id: int in carriers:
		var p: Node3D = crew.call("get_player", id) if crew else null
		if p == null:
			continue
		if not _tote_meshes.has(id):
			var t := Node3D.new()
			t.top_level = true
			add_child(t)
			_tote_box(t, Vector3(0.6, 0.3, 0.42), Color(0.2, 0.42, 0.62))
			_boxm(t, Vector3(0, 0.24, 0), Vector3(0.52, 0.04, 0.36), Color(0.22, 0.3, 0.32))     # (the water, the fish in it)
			_tote_meshes[id] = t
		var yaw := float(p.get("_yaw"))
		var at := p.global_position + p.global_basis * (Basis(Vector3.UP, yaw) * Vector3(0.0, 0.85, -0.42))
		(_tote_meshes[id] as Node3D).global_transform = Transform3D(p.global_basis * Basis(Vector3.UP, yaw), at)


# ------------------------------------------------------------------ the counters' cards

func _build_card() -> void:
	_card = CanvasLayer.new()
	_card.layer = 12
	_card.visible = false
	add_child(_card)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	p.custom_minimum_size = Vector2(440, 0)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.position.x -= 60
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.93, 0.9, 0.82, 0.97)          # (a paper card, an amber edge down its left)
	box.border_color = Color(0.85, 0.55, 0.16)
	box.border_width_left = 4
	box.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", box)
	_card.add_child(p)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 8)
	p.add_child(_card_box)


## Whether a counter's card is up (your mouse is its).
func serving() -> bool:
	return not _serving.is_empty()


## Up to counter `place`: its card, the mouse free for it.
func open(place: String) -> void:
	if not counters.has(place):
		return
	_serving = place
	_wipe = false
	_fill()
	_card.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui.tick")


func close() -> void:
	if _serving.is_empty():
		return
	_serving = ""
	_card.visible = false
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("ui.back")


func _input(e: InputEvent) -> void:
	if not _serving.is_empty() and e.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


var _filled_for := []


func _fill() -> void:
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	var f: Callable = (counters[_serving] as Dictionary)["fill"]
	f.call()
	_card_box.add_child(_text("WALK AWAY OR ESC TO LEAVE", 12, Color(0.4, 0.4, 0.42)))


func _text(t: String, size := 18, col := Color(0.12, 0.13, 0.15)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	return l


func _btn(t: String, on: Callable, ok := true) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not ok
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(0, 30)
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color(0.14, 0.17, 0.2), "hover": Color(0.85, 0.55, 0.16), "pressed": Color(0.6, 0.38, 0.1),
				"disabled": Color(0.5, 0.5, 0.5, 0.5), "focus": Color(0, 0, 0, 0)}[st]
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(st, box)
	b.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	b.pressed.connect(func() -> void:
		on.call()
		Sfx.play("ui.confirm"))
	return b


func _row(what: String, b: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := _text(what, 12)
	l.custom_minimum_size = Vector2(250, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	if b != null:
		b.custom_minimum_size.x = 140
		r.add_child(b)
	return r


func _fill_chandlery() -> void:
	var hold := _hold()
	_card_box.add_child(_text("THE CHANDLERY", 24, Color(0.14, 0.24, 0.44)))
	_card_box.add_child(_text("\"WHAT'LL IT BE?\"  BANK $%s" % FishHold._money(int(hold.get("bank"))), 12))
	var gear: Array = hold.get("gear")
	for g: String in FishHold.GEAR:
		var item: Dictionary = FishHold.GEAR[g]
		var what := str(item["name"]).to_upper() + ": " + str(item["blurb"]).split(". ")[0].to_upper()
		if gear.has(g):
			_card_box.add_child(_row(what, _text("ABOARD", 12, Color(0.2, 0.5, 0.2))))
		else:
			var gg := g
			_card_box.add_child(_row(what, _btn("BUY $%s" % FishHold._money(int(item["price"])),
					func() -> void: hold.call("buy", gg), Net.is_host() and int(hold.get("bank")) >= int(item["price"]))))
	if not Net.is_host():
		_card_box.add_child(_text("THE SKIPPER BUYS THE GEAR", 12, Color(0.4, 0.4, 0.42)))


func _fill_bait() -> void:
	var hold := _hold()
	var me := _me()
	_card_box.add_child(_text("BAIT & TACKLE", 24, Color(0.16, 0.38, 0.26)))
	var prep := str(hold.get("prep"))
	_card_box.add_child(_text("LIVE MACKEREL, TONIGHT'S. HER WELL: %d OF %d." % [int(hold.get("well")),
			FishHold.WELL_MAX], 12))
	if prep == "off":
		_card_box.add_child(_text("(NO DOCK PREP: HER WELL'S STOCKED AS SHE CASTS OFF.)", 12, Color(0.4, 0.4, 0.42)))
	elif me != null and carrying(me):
		_card_box.add_child(_text("YOU'VE A TOTE IN YOUR ARMS: CARRY IT ABOARD, E ON HER LIVE WELL.", 12))
	else:
		_card_box.add_child(_row("A TOTE OF %d, IN WATER" % FishHold.TOTE, _btn("$%d" % FishHold.TOTE_PRICE,
				func() -> void:
					ask_tote(true)
					close(), int(hold.get("bank")) >= FishHold.TOTE_PRICE)))
	_card_box.add_child(_text("ICE: THE BIN ON THE FLOAT, $%d A SCOOP. BRING YOUR SCOOP." % FishHold.ICE_PRICE, 12))


func _fill_broker() -> void:
	var hold := _hold()
	var skipper := Net.is_host()
	var bank := int(hold.get("bank"))
	var owned: Array = hold.get("owned")
	var picked := str(hold.get("kind"))
	_card_box.add_child(_text("THE BROKER'S BOARD", 24, Color(0.2, 0.2, 0.22)))
	_card_box.add_child(_text("BANK $%s" % FishHold._money(bank), 12))
	for k: String in Kinds.KINDS:
		var spec: Dictionary = Kinds.KINDS[k]
		var nm := str(spec["name"]).trim_prefix("the ").to_upper()
		var kk := k
		var what := "%s: %d RODS, FUEL $%s A TANK" % [nm, (spec["rods"] as Array).size(), FishHold._money(int(spec["fuel"]))]
		if owned.has(k):
			_card_box.add_child(_row(what, _btn("TAKING HER" if k == picked else "TAKE HER",
					func() -> void: hold.call("pick", kk), skipper and k != picked)))
		else:
			_card_box.add_child(_row(what, _btn("BUY $%s" % FishHold._money(int(spec["price"])),
					func() -> void: hold.call("buy", kk), skipper and bank >= int(spec["price"]))))
			_card_box.add_child(_row("  OR FOR THE DAY", _btn("CHARTERED" if k == picked else "CHARTER $%s" %
					FishHold._money(FishHold.CHARTER), func() -> void: hold.call("pick", kk), skipper and k != picked)))


func _fill_slip() -> void:
	var hold := _hold()
	var sold: Dictionary = hold.get("sale")
	_card_box.add_child(_text("GULL HARBOR FISH CO.", 24, Color(0.12, 0.2, 0.32)))
	if sold.is_empty():
		_card_box.add_child(_text("NOTHING SOLD YET TODAY.", 12))
		return
	if bool(sold.get("late", false)):
		_card_box.add_child(_text("TOWED IN LATE: THE CANNERY'S PRICE, HALF", 12, Color(0.6, 0.15, 0.1)))
	var lines: Array = sold.get("lines", [])
	for l: Array in lines.slice(maxi(lines.size() - 8, 0)):
		var why := ""
		if l.size() > 3:
			why = "  " + ", ".join((l[3] as Array).slice(0, 2).map(func(w: Array) -> String: return str(w[0])))
		_card_box.add_child(_row("%d KG  %s%s" % [roundi(float(l[0])), str(l[1]).to_upper(), why],
				_text("$" + FishHold._money(int(l[2])), 12)))
	for c: Array in sold.get("costs", []):
		_card_box.add_child(_row(str(c[0]).to_upper(), _text("-$" + FishHold._money(int(c[1])), 12, Color(0.6, 0.15, 0.1))))
	var total := int(sold.get("total", 0))
	_card_box.add_child(_row("THE DAY SO FAR", _text(("$" if total >= 0 else "-$") + FishHold._money(absi(total)), 18)))
	var aboard := (hold.get("fish") as Array).size() + (0 if h_fish.is_empty() else 1)
	if aboard > 0:
		_card_box.add_child(_text("%d MORE ABOARD HER: THE HOIST ON THE FLOAT." % aboard, 12))


func _fill_master() -> void:
	var hold := _hold()
	_card_box.add_child(_text("THE HARBOR MASTER", 24, Color(0.12, 0.2, 0.34)))
	var quota := int(hold.get("quota"))
	var earned := int(hold.get("earned"))
	_card_box.add_child(_text("QUOTA %d: $%s OF $%s. DAY %d OF %d." % [int(hold.get("quota_n")), FishHold._money(earned),
			FishHold._money(quota), int(hold.get("day")), FishHold.DAYS], 18))
	_card_box.add_child(_text("MADE: ON TO THE NEXT." if earned >= quota else "$%s MORE BY DAY %d, OR THE BANK TAKES HER."
			% [FishHold._money(quota - earned), FishHold.DAYS], 12))
	var verdict := str((hold.get("sale") as Dictionary).get("verdict", ""))
	if verdict == "lost":
		_card_box.add_child(_text("THE BANK TOOK THE BOAT. A NEW RUN: THE SKIFF AND $%s." % FishHold._money(FishHold.START_CASH),
				12, Color(0.6, 0.15, 0.1)))
	_card_box.add_child(_text("THE RUN: %d FISH, THE BIGGEST %d KG. BEST RUN: %d QUOTAS. BEST DAY: $%s." % [
			int(hold.get("run_fish")), roundi(float(hold.get("run_biggest"))), int(hold.get("best_run")),
			FishHold._money(int(hold.get("best")))], 12))
	var skipper := Net.is_host()
	_card_box.add_child(_row("DOCK PREP: %s" % str(hold.get("prep")).to_upper(), _btn("CHANGE", func() -> void:
		Settings.next_prep("career")
		_fill.call_deferred(), skipper)))
	_card_box.add_child(_row("START OVER IN THE SKIFF", _btn("SURE? WIPE IT ALL" if _wipe else "NEW CAREER", func() -> void:
		if _wipe:
			hold.call("new_career")
		_wipe = not _wipe
		_fill.call_deferred(), skipper and bool(hold.get("docked")))))


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	_t += delta
	if Net.is_host():
		_host_hoist(delta)
	_crank_held(delta)
	_pump_held(delta)
	_show_hoist()
	_show_hose()
	_show_totes()
	_idle(delta)
	if not _serving.is_empty():
		var me := _me()
		var at: Vector3 = (counters[_serving] as Dictionary)["at"]
		if me == null or (me as Node3D).global_position.distance_to(at) > SERVE + 1.2 \
				or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			close()
		else:
			# (kept up to date: a purchase, the slip as fish are sold)
			var hold := _hold()
			var now := [hold.get("bank"), (hold.get("sale") as Dictionary).hash(), hold.get("kind"), hold.get("prep"),
					(hold.get("gear") as Array).size(), (hold.get("owned") as Array).size(), carriers.size(), hold.get("well")]
			if now != _filled_for:
				_filled_for = now
				_fill()
