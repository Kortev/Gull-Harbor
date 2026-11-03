extends RefCounted
## What every one of the crew carries (crew/hands.gd): a knife, a gaff, a light jig rod, a chum scoop, a bait, a tin
## whistle. One's
## in your hands at a time (the hotbar, keys 1-5 or the wheel). The models are art/gear.py's (crew/gear/*.glb), low
## and chunky with tiny crunchy textures like everything else; each one's origin is where your right hand grips it,
## its working end along -z (ahead of your hand), its top up. Some have marks hands.gd poses by: "grip_l" (where the
## left hand goes on the two-handed ones), "tip" (the jig rod's, where the line leaves), "hook" (the gaff's point),
## "rig" (the jig hanging off the tip, swinging), "tail" (the mackerel's, flicking), "Chum" (a scoopful).

const ITEMS: Array[String] = ["knife", "gaff", "jig", "scoop", "bait", "whistle"]
const MODELS := {
	"knife": preload("res://crew/gear/knife.glb"),
	"gaff": preload("res://crew/gear/gaff.glb"),
	"jig": preload("res://crew/gear/jig.glb"),
	"scoop": preload("res://crew/gear/scoop.glb"),
	"bait": preload("res://crew/gear/bait.glb"),
	"dead": preload("res://crew/gear/bait.glb"),
}
const GLOVES := preload("res://crew/gear/glove.glb")


static func make(item: String) -> Node3D:
	var root := Node3D.new()
	root.name = item.capitalize()
	var scene := MODELS.get(item) as PackedScene
	if item == "whistle":
		root.add_child(_whistle())
	if scene:
		var model := scene.instantiate() as Node3D
		model.name = "Model"
		if item == "bait" or item == "dead":
			model.position = Vector3(0.0, 0.0, -0.1)       # (a live bait's held by the wrist of its tail)
		root.add_child(model)
		if item == "dead":
			# (a dead one: gone dull and grey, its colours faded off it)
			var dull := StandardMaterial3D.new()
			dull.albedo_color = Color(0.7, 0.68, 0.66)
			dull.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			dull.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = dull
		var chum := model.find_child("Chum", true, false) as Node3D
		if chum:
			chum.visible = false
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## A tin whistle (made here, it's that simple): a thin tin tube along -z from where your hand holds it, its green
## mouthpiece toward you (+z), three finger holes on top.
static func _whistle() -> Node3D:
	var m := Node3D.new()
	m.name = "Model"
	var tin := StandardMaterial3D.new()
	tin.albedo_color = Color(0.66, 0.68, 0.7)
	tin.metallic = 0.6
	tin.roughness = 0.45
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.2, 0.42, 0.28)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	for part: Array in [[0.008, 0.22, -0.05, tin], [0.0095, 0.06, 0.09, green]]:
		var c := CylinderMesh.new()
		c.top_radius = float(part[0])
		c.bottom_radius = float(part[0]) * 0.92
		c.height = float(part[1])
		c.radial_segments = 6
		c.rings = 1
		c.material = part[3]
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)          # (a cylinder's along y: along -z)
		mi.position = Vector3(0.0, 0.0, float(part[2]))
		m.add_child(mi)
	for z: float in [-0.04, -0.075, -0.11]:
		var b := BoxMesh.new()
		b.size = Vector3(0.007, 0.004, 0.007)
		b.material = dark
		var hole := MeshInstance3D.new()
		hole.mesh = b
		hole.position = Vector3(0.0, 0.0075, z)
		m.add_child(hole)
	return m


## Your own gloved hand in first person, `side` "r" or "l": an orange rubber deck glove in a fist round a handle along
## -z through its origin, and the hoodie's "Sleeve" from its wrist (along -z; crew/hands.gd aims it at your elbow).
static func glove(side: String) -> Node3D:
	var all := GLOVES.instantiate() as Node3D
	var out := Node3D.new()
	out.name = "Glove" + side.to_upper()
	for part: String in ["glove_" + side, "sleeve"]:
		var mi := all.find_child(part, true, false) as MeshInstance3D
		if mi == null:
			continue
		mi.owner = null
		mi.get_parent().remove_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if part == "sleeve":
			mi.name = "Sleeve"
			mi.position = Vector3(0.013 if side == "r" else -0.013, -0.006, 0.112)
		out.add_child(mi)
	all.free()
	return out


## A mackerel, 30 cm, nose along -z (boat/jig.gd swings one aboard on the jig line).
static func _mackerel() -> Node3D:
	var fish := make("bait")
	fish.name = "Mackerel"
	(fish.get_node("Model") as Node3D).position = Vector3.ZERO
	return fish
