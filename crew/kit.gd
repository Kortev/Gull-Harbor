extends RefCounted
## What every one of the crew carries (crew/hands.gd): a knife, a gaff, a light jig rod, a chum scoop, a bait. One's
## in your hands at a time (the hotbar, keys 1-5 or the wheel); each is built here from a few boxes and cylinders,
## the PS1 way, held with its working end along -z (ahead of your hand).

const ROD := preload("res://rods/rod.glb")

const ITEMS: Array[String] = ["knife", "gaff", "jig", "scoop", "bait"]


static func make(item: String) -> Node3D:
	var root := Node3D.new()
	root.name = item.capitalize()
	match item:
		"knife":
			_box(root, Vector3(0.028, 0.032, 0.12), Vector3(0, 0, 0.0), _mat(Color(0.12, 0.12, 0.13), 0.7))
			_box(root, Vector3(0.006, 0.03, 0.16), Vector3(0, 0.004, -0.14), _mat(Color(0.78, 0.8, 0.82), 0.25, 0.8))
		"gaff":
			# a stout aluminium pole, a big stainless hook on the end, a rubber grip
			_cyl(root, 0.018, 1.3, Vector3(0, 0, -0.45), _mat(Color(0.72, 0.74, 0.76), 0.35, 0.7))
			_cyl(root, 0.024, 0.3, Vector3(0, 0, 0.05), _mat(Color(0.1, 0.1, 0.1), 0.9))
			var steel := _mat(Color(0.85, 0.86, 0.88), 0.2, 0.9)
			_box(root, Vector3(0.012, 0.012, 0.12), Vector3(0, 0, -1.15), steel)
			_box(root, Vector3(0.012, 0.13, 0.012), Vector3(0, -0.06, -1.21), steel)
			_box(root, Vector3(0.012, 0.012, 0.07), Vector3(0, -0.12, -1.17), steel)
		"jig":
			var rod := ROD.instantiate() as Node3D
			rod.name = "Rod"
			rod.scale = Vector3.ONE * 0.62
			rod.rotation = Vector3(0, PI, 0)        # (rod.glb's blank runs along +z)
			rod.position = Vector3(0, 0, 0.2)
			root.add_child(rod)
		"scoop":
			var white := _mat(Color(0.86, 0.85, 0.8), 0.8)
			_box(root, Vector3(0.025, 0.025, 0.42), Vector3(0, 0, -0.1), white)
			var cup := _cyl(root, 0.075, 0.08, Vector3(0, -0.02, -0.36), white)
			cup.rotation = Vector3.ZERO
			var chum := _cyl(root, 0.068, 0.01, Vector3(0, 0.02, -0.36), _mat(Color(0.38, 0.14, 0.1), 0.4))
			chum.rotation = Vector3.ZERO
			chum.name = "Chum"
			chum.visible = false
		"bait":
			var fish := _mackerel()
			fish.position = Vector3(0, 0.02, -0.08)
			root.add_child(fish)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(to: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	to.add_child(mi)
	return mi


## A cylinder along z (its length), centred at `at`.
static func _cyl(to: Node3D, r: float, length: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 6
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	mi.rotation = Vector3(PI * 0.5, 0, 0)
	to.add_child(mi)
	return mi


## A mackerel, low and chunky: green-blue back with dark bars, silver belly, forked tail; 30 cm, nose along -z.
static func _mackerel() -> Node3D:
	var root := Node3D.new()
	root.name = "Mackerel"
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var body := MeshInstance3D.new()
	body.mesh = sm
	body.material_override = _mat(Color(0.82, 0.84, 0.86), 0.3, 0.6)
	body.scale = Vector3(0.045, 0.06, 0.26)
	root.add_child(body)
	var top := MeshInstance3D.new()
	top.name = "Back"
	top.mesh = sm
	top.material_override = _mat(Color(0.18, 0.42, 0.4), 0.35, 0.4)
	top.scale = Vector3(0.04, 0.035, 0.24)
	top.position = Vector3(0.0, 0.016, 0.0)
	root.add_child(top)
	var tail := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.09, 0.06, 0.01)
	tail.mesh = pm
	tail.material_override = top.material_override
	tail.rotation = Vector3(0.0, PI * 0.5, PI)
	tail.position = Vector3(0.0, 0.0, 0.15)
	root.add_child(tail)
	return root
