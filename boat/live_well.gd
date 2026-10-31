extends Node3D
## Her live well in the transom (every boat has one: boat/fish_hold.gd's `well`, the live mackerel for bait), its lid
## the model's own piece ("well_lid", hinged at its after edge: art/boat.py, art/skiff.py). E on the lid opens it, E
## again shuts it (the host's word, like the fish box's, so everyone sees the same); and it swings up on its own for a
## moment whenever a mackerel goes in (swung aboard off the jig, boat/jig.gd) or comes out (onto a hook, rods.gd).
## Open, you see into it: dark water and the mackerel circling, as many as there are (up to SHOWN). It swings, never
## jumps (SPEED). Built by boat/boat.gd as a child of the boat, so it rides her.

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
var _act: Action


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
	# E on the lid
	_act = Action.new(Vector3(size.x, 0.25, size.z))
	_act.name = "LiveWell"
	_act.position = centre + Vector3(0.0, 0.08, 0.0)
	_act.use = func(_p: Node) -> void:
		var hold := _hold()
		if hold != null and not bool(hold.get("docked")):
			hold.call("request_well_lid", not bool(hold.get("well_open")))
	_act.prompt = func() -> String:
		var hold := _hold()
		if hold == null or bool(hold.get("docked")):
			return ""
		if bool(hold.get("well_open")):
			return "Shut the live well"
		return "Live well: %d mackerel" % int(hold.get("well"))
	add_child(_act)


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
