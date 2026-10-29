extends Node3D
## A planet's own sounds (the sound pass: docs/lane-b/sound-picks.md), every peer on its own. planet.gd adds it in
## _ready ("Sounds"); it watches the planet (by its planet_id) and plays world/sounds/sfx.gd's events. The beds come up
## as the ship lands (is_live) and go as it leaves, and they're muffled while the camera's aboard the ship (more with
## its doors shut: outside()).
## - Glimmer: the meadow by day, fading into the night's insects as it gets dark; the creek's fall, at its splash; the
##   water lapping at the shore nearest you (the LAPS nearest bodies of water).
## - Brine: the flats' wind; the dust storm's roar over it as the storm rolls in. A vent boiling and blowing and a
##   gust front are brine_hazards.gd's.
## - Fathom: the sea; the gale, harder in a gust, a howl as each gust slams in; the rain on the deck round you, on the
##   steel over you when you're under a roof (the rig's decks, the ship), and on your visor while it's wet. A leg's
##   slam, the crests' spray and the thunder are sea_fx.gd's; the storm lamp's alarm and the wash fathom_hazards.gd's;
##   the lift rig_lift.gd's.

const Sfx := preload("res://audio/sfx.gd")
## The outside heard from aboard the ship: doors open, doors shut.
const ABOARD := Vector2(0.35, 0.12)
## How fast the beds come up as the ship lands and go as it leaves, and follow the muffling (a share a second).
const FADE := 0.5
const MUFFLE_RATE := 1.5
## Glimmer's lapping: this many of the nearest bodies of water lap at once, each heard out to LAP_RANGE m.
const LAPS := 2
const LAP_RANGE := 45.0
## Fathom: a gust past this howls (once per gust, at most every GUST_GAP s).
const GUST_HOWL := 0.3
const GUST_GAP := 3.0

## -1: the beds follow the planet's is_live(); 0..1: a test's own.
var live := -1.0
var planet: Node3D
var _id := ""
var _on := 0.0
var _muffle := 1.0
var _beds := {}  # name -> its loop player
# Glimmer
var _waters: Array[AABB] = []  # each body of water's surface box, in the planet's space (it's moved after loading)
var _laps: Array[Node3D] = []
# Fathom
var _ocean: Node
var _visor: Node
var _out := 1.0
var _gust_was := 0.0
var _howl_at := -100.0


## The outside heard from where the camera is: 1 out in it, less aboard the ship (ABOARD). For one-shots too.
static func outside(tree: SceneTree) -> float:
	var cam := tree.root.get_camera_3d() if tree != null else null
	var ship := tree.get_first_node_in_group("ship") if tree != null else null
	if cam == null or ship == null or not ship.has_method("is_aboard") or not bool(ship.call("is_aboard", cam)):
		return 1.0
	return ABOARD.x if bool(ship.get("doors_open")) else ABOARD.y


func _ready() -> void:
	planet = get_parent() as Node3D
	_id = String(planet.get_meta("planet_id", "")) if planet != null else ""
	match _id:
		"glimmer":
			_bed("day", "glim.day")
			_bed("night", "glim.night")
			var fall := planet.get_node_or_null("Fx/FallSplash") as Node3D
			if fall != null:
				_beds["fall"] = Sfx.loop(fall, "glim.fall", true)
			for area: Node in get_tree().get_nodes_in_group("water"):
				var surface := area.get_node_or_null("Surface") as MeshInstance3D
				if surface != null and planet.is_ancestor_of(area):
					_waters.append(planet.global_transform.affine_inverse() * surface.global_transform * surface.get_aabb())
			for k: int in mini(LAPS, _waters.size()):
				var lap := Node3D.new()
				lap.name = "Lap%d" % k
				add_child(lap)
				lap.top_level = true
				_laps.append(lap)
				_beds["lap%d" % k] = Sfx.loop(lap, "glim.lake", true)
		"brine":
			_bed("bed", "brine.bed")
			_bed("dust", "brine.dust")
		"fathom":
			_ocean = planet.get_node_or_null("Ocean")
			_visor = planet.get_node_or_null("Fx/VisorRain")
			_bed("swell", "sea.swell")
			_bed("wind", "sea.wind")
			_bed("rain", "sea.rain")
			_bed("steel", "sea.rain_steel")
			_bed("visor", "sea.rain_visor")
	set_process(not _beds.is_empty())


func _process(delta: float) -> void:
	var want := live if live >= 0.0 else (1.0 if bool(planet.call("is_live")) else 0.0)
	_on = move_toward(_on, want, delta * FADE)
	_muffle = move_toward(_muffle, outside(get_tree()), delta * MUFFLE_RATE)
	var a := _on * _muffle
	var dark := float(planet.get("dark"))
	match _id:
		"glimmer":
			_level("day", a * (1.0 - smoothstep(0.35, 0.85, dark)))
			_level("night", a * smoothstep(0.3, 0.8, dark))
			_level("fall", a)
			_lap(a)
		"brine":
			var dust := 0.0
			if String(planet.get("weather")) == "dust storm":
				dust = smoothstep(0.1, 0.8, float(planet.get("weather_strength")))
			_level("bed", a * (1.0 - 0.4 * dust))
			_level("dust", a * dust)
		"fathom":
			_sea(delta, a)


func _bed(key: String, event: String) -> void:
	_beds[key] = Sfx.loop(self, event)


func _level(key: String, amount: float, pitch := -1.0) -> void:
	Sfx.level(_beds.get(key) as Node, amount, pitch)


## Glimmer: each lapping emitter at the nearest shore point of one of the nearest bodies of water (on its surface,
## the point of its box nearest the camera), so the water laps wherever you walk along it.
func _lap(a: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _laps.is_empty():
		return
	var eye := planet.to_local(cam.global_position)
	var near: Array[Vector4] = []  # x, y, z, distance
	for box: AABB in _waters:
		var p := eye.clamp(box.position, box.end)
		p.y = box.end.y
		near.append(Vector4(p.x, p.y, p.z, eye.distance_to(p)))  # (the planet's never scaled)
	near.sort_custom(func(m: Vector4, n: Vector4) -> bool: return m.w < n.w)
	for k: int in _laps.size():
		var spot := near[k]
		_laps[k].global_position = planet.to_global(Vector3(spot.x, spot.y, spot.z))
		_level("lap%d" % k, a if spot.w < LAP_RANGE else 0.0)


## Fathom: the sea and the gale by the weather and the gusts; the rain by where you stand (out in it, under steel).
func _sea(delta: float, a: float) -> void:
	var weather := float(_ocean.get("weather")) if _ocean != null else 0.5
	var gust := float(_ocean.get("gust")) if _ocean != null else 0.0
	var fury := float(_ocean.get("fury")) if _ocean != null else 0.0
	_level("swell", a * lerpf(0.6, 1.0, weather))
	_level("wind", a * clampf(0.35 + 0.45 * weather + 0.4 * gust + 0.15 * fury, 0.0, 1.3), 0.92 + 0.16 * gust)
	var now := Time.get_ticks_msec() / 1000.0
	if gust >= GUST_HOWL and _gust_was < GUST_HOWL and now - _howl_at > GUST_GAP and a > 0.01:
		_howl_at = now
		Sfx.play("sea.gust", a * lerpf(0.7, 1.0, fury))
	_gust_was = gust
	var out := bool(_visor.get("out")) if _visor != null else true
	_out = move_toward(_out, 1.0 if out else 0.0, delta * 3.0)
	var rain := _on * lerpf(0.6, 1.0, weather) * lerpf(1.0, 1.2, gust)
	_level("rain", rain * _muffle * lerpf(0.3, 1.0, _out))
	_level("steel", rain * (1.0 - _out) * lerpf(0.6, 1.0, _muffle))
	var wet := float(_visor.get("wet")) if _visor != null else 0.0
	_level("visor", a * wet * _out * 0.8)
