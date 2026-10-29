extends Node3D
## Her fish box's hatch and her live well's lid (the models' box_lid and well_lid, each hinged at one edge): the
## hatch swings up as a fish goes in on ice, the well's lid as a mackerel goes in or comes out; and E on the well
## opens it to look in, at the mackerel swimming round in there. All from the fish hold's word (boat/fish_hold.gd:
## the fish iced, the mackerel in the well), so everyone sees the same.

const Jig := preload("res://boat/jig.gd")
## How far each swings open (rad), how fast (rad/s), and how long it stays open (s).
const OPEN := 1.25
const SPEED := 3.5
const HOLD_OPEN := 2.0
const LOOK_OPEN := 6.0

var boat: Node3D          # boat/boat.gd
var box_lid: Node3D
var well_lid: Node3D
## How open each is now (rad) and how long till it closes (s).
var box_open := 0.0
var well_open := 0.0
var _box_for := 0.0
var _well_for := 0.0
var _box_base := Basis.IDENTITY
var _well_base := Basis.IDENTITY
var _box_sign := 1.0
var _well_sign := 1.0
var _iced := -1
var _well := -1
var _look: Area3D
var _water: Node3D
var _fish: Array[Node3D] = []


func setup(box: Node3D, well: Node3D) -> void:
	box_lid = box
	well_lid = well
	if box_lid:
		_box_base = box_lid.basis
		_box_sign = _lift_sign(box_lid)
	if well_lid:
		_well_base = well_lid.basis
		_well_sign = _lift_sign(well_lid)
		_build_well()


## Which way round the hinge lifts its free edge (the lid lies to one side of its hinge, fore or aft).
static func _lift_sign(lid: Node3D) -> float:
	var mi := lid as MeshInstance3D
	var c := mi.get_aabb().get_center() if mi != null else Vector3(0, 0, 1)
	c = lid.basis * c
	return -1.0 if c.z > 0.0 else 1.0


## The water in the well (seen with its lid up), the mackerel in it, and the lid to press E on.
func _build_well() -> void:
	var mi := well_lid as MeshInstance3D
	var box := mi.get_aabb() if mi != null else AABB(Vector3(-0.45, -0.03, -0.45), Vector3(0.9, 0.03, 0.45))
	var centre := well_lid.position + well_lid.basis * box.get_center()
	var size := Vector3(absf((well_lid.basis * box.size).x), 0.0, absf((well_lid.basis * box.size).z))
	_water = Node3D.new()
	_water.name = "WellWater"
	# (just over the well's top, where the shut lid sits on it: the lid's thickness under its hinge)
	_water.position = Vector3(centre.x, well_lid.position.y - absf((well_lid.basis * box.size).y) + 0.006, centre.z)
	add_child(_water)
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x * 0.95, size.z * 0.95)
	surface.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.16, 0.18)
	wm.roughness = 0.08
	wm.metallic = 0.2
	surface.material_override = wm
	_water.add_child(surface)
	for i in 6:
		var f := Jig._make_mackerel()
		f.scale = Vector3.ONE * 0.8
		f.visible = false
		_water.add_child(f)
		_fish.append(f)
	_look = Area3D.new()
	_look.name = "LiveWell"
	_look.set_script(preload("res://boat/live_well.gd"))
	_look.set("lids", self)
	_look.position = centre + Vector3(0.0, 0.05, 0.0)
	add_child(_look)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.25, size.z)
	cs.shape = shape
	_look.add_child(cs)


## E on the well: up with its lid for a look.
func look_in() -> void:
	_well_for = LOOK_OPEN


## Mackerel in the well now (the fish hold's count; none without the well).
func mackerel() -> int:
	var hold: Node = boat.get("sea").get("fish_hold") if boat.get("sea") else null
	if hold == null or not bool(hold.call("has_gear", "bait")):
		return 0
	return int(hold.get("well"))


func _process(delta: float) -> void:
	var hold: Node = boat.get("sea").get("fish_hold") if boat.get("sea") else null
	if hold != null:
		var iced := 0
		for f: Dictionary in hold.get("fish"):
			if float(f.get("iced_s", -1.0)) >= 0.0:
				iced += 1
		if _iced >= 0 and iced > _iced:
			_box_for = HOLD_OPEN        # (a fish going in on ice)
		_iced = iced
		var w := mackerel()
		if _well >= 0 and w != _well:
			_well_for = maxf(_well_for, HOLD_OPEN)       # (a mackerel in, or one out for a bait)
		_well = w
	_box_for -= delta
	_well_for -= delta
	box_open = move_toward(box_open, OPEN if _box_for > 0.0 else 0.0, SPEED * delta)
	well_open = move_toward(well_open, OPEN if _well_for > 0.0 else 0.0, SPEED * delta)
	if box_lid:
		box_lid.basis = Basis(Vector3.RIGHT, box_open * _box_sign) * _box_base
	if well_lid:
		well_lid.basis = Basis(Vector3.RIGHT, well_open * _well_sign) * _well_base
	# the mackerel, circling the well while you can see in
	if _water != null:
		var n := mini(_well if _well > 0 else 0, _fish.size())
		var t := Time.get_ticks_msec() * 0.001
		for i in _fish.size():
			var f := _fish[i]
			f.visible = i < n and well_open > 0.2
			if f.visible:
				var a := t * (0.9 + 0.13 * i) + i * TAU / maxf(n, 1)
				var r := 0.16 + 0.05 * sin(t * 0.7 + i)
				f.position = Vector3(cos(a) * r * 1.2, 0.02 + 0.01 * i, sin(a) * r * 0.8)
				f.basis = Basis(Vector3.UP, -a)
