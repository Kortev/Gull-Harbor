extends Node3D
## Bluefin schools, anywhere round the boat. The host keeps a few working out there (MAX_SCHOOLS), each turning up
## somewhere a few hundred metres to a kilometre or so off (SPAWN), cruising slowly its own way, feeding on and off
## for a few minutes (LIFE), then the birds lift and scatter and it's gone. From the moment it starts, where it is,
## when it's feeding and where it busts are all worked out from the shared sea clock and its seed, so every peer
## sees the same birds and the same busting water.
##
## How you find them (a hunt: it takes a while): birds, far off. With the naked eye a flock's a smudge on the horizon;
## closer in (crew/spotter.gd) you can tell what they're doing: diving on bluefin busting white water, or
## working little bait with no tuna under them (BAIT_ONLY of flocks: not worth the run), or sitting on the water
## because the tuna have gone down (they feed in spells, SPELL s at a time: wait and they'll come up). Call a flock
## and it's marked on the radar for everyone (call_out); the radar itself paints birds in the air within its range
## (tuna/radar.gd), and the sonar marks what's right under her. Run her to them, then troll the baits through: a feeding school over a bait eats it now
## and then (rods.gd hooks the fish, host only, strike()), but not with the baits skipping behind her at speed
## (BITE_SPEED), and run her right through a school fast and it goes down (SPOOK).
##
## Get near one and slow down, and it finds your baits: a school within FIND of the spread while she's going slow enough
## to fish comes to it (DRAW m/s) and works round it, following as she trolls.
##
## Or bring them to you: chum (boat/chum.gd) lays a slick back through the baits, and while it's fresh (SLICK) a
## school within SLICK_PULL of it comes up it (DRAW m/s) and stays on it, working, as long as the chum keeps coming;
## and new schools turn up nearer it (SLICK_SPAWN).

const Tuna := preload("res://tuna/tuna.gd")
const GULLS: Array[AudioStream] = [preload("res://audio/fish/gull_1.wav"), preload("res://audio/fish/gull_2.wav"),
		preload("res://audio/fish/gull_3.wav")]
const SPLASH := preload("res://audio/fish/splash.wav")
const PUFF := preload("res://sea/textures/steam_puff.png")
## How many work at once, how far off they turn up (m: the first one quickly and closer), how long one lasts (s),
## the last of which its birds spend lifting and scattering, and how fast it cruises (m/s).
const MAX_SCHOOLS := 6
const SPAWN := Vector2(800.0, 2600.0)
const FIRST := Vector2(600.0, 1000.0)
const LIFE := Vector2(360.0, 720.0)
const SCATTER := 25.0
const CRUISE := Vector2(0.8, 2.2)
## Of the flocks, how many are only birds over little bait (no bluefin), and how long a feeding spell or a spell down
## lasts (s: a spell's up or down by the seed's dice).
const BAIT_ONLY := 0.35
const SPELL := 40.0
## Faster than this (m/s) the baits skip and nothing bites; run her through a school faster than SPOOK_SPEED and it
## goes down for SPOOK s.
const BITE_SPEED := 6.0
const SPOOK_SPEED := 5.0
const SPOOK := 40.0
## The chum slick: how long a scoop keeps it fresh (s), how far off a school smells it (m), how fast it comes up it
## (m/s), where new ones turn up while it's fresh (m from it), and how long one stays on it after the last scoop (s).
const SLICK := 90.0
const SLICK_PULL := 450.0
const DRAW := 3.0
const SLICK_SPAWN := Vector2(250.0, 500.0)
const STAY := 60.0
## How near the spread (m) a school has to be to find the baits on its own.
const FIND := 160.0
## (tests and screenshots: the next school this close, m; 0: as usual)
const FAR := 0.0

var sea: Node                       # sea/sea.gd
var schools: Array[School] = []
## Seconds until the host starts the next school (the first comes quickly).
var _next := 6.0
## How far out the next school shows up (m; 0: as usual), for screenshots and tests.
var start_far := FAR
var _ids := 0
var _first := true
## Host: the chum slick's heart (world x, z) and when the last scoop went in (sea clock).
var slick := Vector2.ZERO
var slick_t := -1e9
var _chum_in := 0.0
## The flocks someone's called (school id -> who: crew/crew.gd's call sign), marked on the radar for everyone.
var marks := {}
## The birds' look, shared: dark, and only lightly hazed by distance (the sea's fog would wipe them out past a few
## hundred metres; a flock on the horizon is what you're looking for).
var bird_mat: ShaderMaterial


static func hash1(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


func ocean() -> Node:
	return sea.get("ocean") as Node


func now() -> float:
	return float(ocean().get("wave_time"))


func _ready() -> void:
	bird_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BIRD_SHADER
	bird_mat.shader = sh
	Net.peer_joined.connect(func(id: int) -> void:
		if multiplayer.is_server():
			for m: int in marks:
				_mark.rpc_id(id, m, str(marks[m]), true)
			for s in schools:
				_start.rpc_id(id, s.id, s.seed, s.t0, s.start, s.heading, s.speed, s.kg, s.life, s.run, s.born)
				if s.spooked_until > now():
					_spook.rpc_id(id, s.id, s.spooked_until))


## How many pixels across a far-off bird is drawn, at least (so a flock reads on the horizon).
const BIRD_PX := 5.0
const BIRD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(0.16, 0.15, 0.15, 1.0);
uniform vec4 haze : source_color = vec4(0.6, 0.64, 0.68, 1.0);
uniform float haze_k = 0.0006;
void fragment() {
	ALBEDO = mix(color.rgb, haze.rgb, 1.0 - exp(-haze_k * length(VERTEX)));
}
"""


## At the dock, between trips: nothing turns up, nothing bites.
func _docked() -> bool:
	var hold: Node = sea.get("fish_hold")
	return hold != null and bool(hold.get("docked"))


## Where the boat is (world x, z): the schools turn up round her.
func boat_at() -> Vector2:
	var boat := sea.get("boat") as Node
	var helm: Node = boat.get("helm") if boat else null
	return helm.get("at") if helm else Vector2.ZERO


func boat_speed() -> float:
	var boat := sea.get("boat") as Node
	var helm: Node = boat.get("helm") if boat else null
	return float(helm.get("speed")) if helm else 0.0


func _process(delta: float) -> void:
	var env := sea.get("env") as Environment
	if env != null and bird_mat != null:
		# a third the sea's haze (a storm's wall of fog hides them, though)
		var k := 0.25 if env.fog_mode == Environment.FOG_MODE_DEPTH else env.fog_density * 0.12
		var cam := get_viewport().get_camera_3d()
		if cam:
			k *= clampf(cam.fov / 75.0, 0.35, 1.0)     # (a narrower view sees through the haze better)
		bird_mat.set_shader_parameter("haze", env.fog_light_color)
		bird_mat.set_shader_parameter("haze_k", k)
	if Net.is_host() and not _docked():
		_next -= delta
		if _next <= 0.0:
			_next = randf_range(10.0, 25.0)
			if schools.size() < MAX_SCHOOLS:
				_host_start()
	for s in schools.duplicate():
		if s.done(now()):
			marks.erase(s.id)
			schools.erase(s)
			s.queue_free()
	if Net.is_host():
		_strikes(delta)
		_spooking()
		_chum_in -= delta
		if _chum_in <= 0.0:
			_chum_in = 1.0
			_drawing()


## Host: a feeding school over a bait eats it now and then (more than one rod can go: a double header); not with
## the baits skipping along behind her at speed.
func _strikes(delta: float) -> void:
	var spread := sea.get("rods") as Node
	if spread == null or absf(boat_speed()) > BITE_SPEED or _docked():
		return
	var t := now()
	# a second fish while one's on happens, but rarely: a double is a story, not the routine
	var on := 0
	for r: Node3D in spread.get("rods"):
		on += 1 if bool(r.get("hooked")) else 0
	var chance := 0.3 * (1.0 if on == 0 else 0.015)
	for s in schools:
		if s.bait_only or not s.feeding(t):
			continue
		var c := s.center(t)
		for r: Node3D in spread.get("rods"):
			if bool(r.get("hooked")) or bool(r.get("bait_in")):
				continue
			var bait: Vector3 = r.get("line_end")
			# (a fresh bait more than a washed-out one, a live mackerel most: rods.gd's bite_odds)
			var odds := chance * float(spread.call("bite_odds", int(r.get("index"))))
			if Vector2(bait.x, bait.z).distance_to(c) < s.radius + 6.0 and randf() < delta * odds:
				spread.call("strike", int(r.get("index")), clampf(s.kg * randf_range(0.8, 1.2), Tuna.MIN_KG,
						Tuna.MAX_KG))


## Host: a scoop of chum went in (boat/chum.gd); the slick's heart is back among the baits, at `at` (world x, z).
func host_chum(at: Vector2) -> void:
	slick = at
	slick_t = now()
	_drawing()


func slick_fresh() -> bool:
	return now() - slick_t < SLICK


## Host, every second: schools near her baits while she's slow find them and work round them (following her as she
## trolls); schools that smell a fresh slick come up it and stay on it while the chum keeps coming.
func _drawing() -> void:
	var t := now()
	var fishing := absf(boat_speed()) < BITE_SPEED and not _docked()
	var heart := spread_heart()
	for s in schools:
		if s.bait_only or s.scattering(t) > 0.0 or t < s.spooked_until:
			continue
		var c := s.center(t)
		# the slick first (it pulls from further off), else her baits if it's near them
		var to := Vector2.INF
		var chummed := false
		if slick_fresh() and c.distance_to(slick) < SLICK_PULL:
			to = slick
			chummed = true
		elif fishing and c.distance_to(heart) < FIND:
			to = heart
		if to == Vector2.INF:
			if s.drawn_to != Vector2.INF and not s.chummed:
				# she's gone off and left it: it cruises on its way again
				s.drawn_to = Vector2.INF
				_host_steer(s, t, c, s.heading, CRUISE.x, 1e9, s.t0 + s.life - t)
			continue
		var d := c.distance_to(to)
		if s.drawn_to.distance_to(to) > (8.0 if chummed else 15.0):
			# to it (quicker than she's trolling, so it catches her baits up), and it stays there working after
			var pace := maxf(DRAW, absf(boat_speed()) + 1.5) if not chummed else DRAW
			var travel := d / pace
			var heading := (to - c).normalized() if d > 0.5 else s.heading
			s.drawn_to = to
			s.chummed = chummed
			var life := maxf(s.t0 + s.life - t, travel + STAY) if chummed else s.t0 + s.life - t
			_host_steer(s, t, c, heading, pace, travel, life)
		elif chummed and s.chummed and t >= s.t0 + s.run and s.t0 + s.life - t < STAY:
			# there, and the chum keeps coming: it keeps working
			_host_steer(s, t, c, s.heading, 0.0, 0.0, STAY + 30.0)


## The middle of her spread of baits (world x, z).
func spread_heart() -> Vector2:
	var boat := sea.get("boat") as Node3D
	if boat == null:
		return Vector2.ZERO
	var baits: Array = (boat.get("spec") as Dictionary).get("baits", [])
	var heart := Vector3.ZERO
	for b: Vector3 in baits:
		heart += b / float(maxi(baits.size(), 1))
	var h := boat.global_transform * heart
	return Vector2(h.x, h.z)


## Host: school s from where it is now (`c` at sea clock t) on a new path: `heading` at `speed` m/s for `run` s, then
## working where it got to; `life` s more of it.
func _host_steer(s: School, t: float, c: Vector2, heading: Vector2, speed: float, run: float, life: float) -> void:
	var side := Vector2(-heading.y, heading.x)
	var start := c - side * sin(float(s.seed)) * 6.0      # (so it doesn't jump: its weave starts where it is)
	var args := [s.id, t, start, heading, speed, run, life]
	if Net.in_session():
		_steer.rpc.callv(args)
	else:
		_steer.callv(args)


@rpc("authority", "call_local", "reliable")
func _steer(id: int, t0: float, start: Vector2, heading: Vector2, speed: float, run: float, life: float) -> void:
	for s in schools:
		if s.id == id:
			s.t0 = t0
			s.start = start
			s.heading = heading.normalized()
			s.speed = speed
			s.run = run
			s.life = life


## Host: run her fast right through a school and it goes down.
func _spooking() -> void:
	if absf(boat_speed()) < SPOOK_SPEED:
		return
	var t := now()
	var at := boat_at()
	for s in schools:
		if s.spooked_until < t and not s.bait_only and s.center(t).distance_to(at) < s.radius + 15.0:
			var until := t + SPOOK
			if Net.in_session():
				_spook.rpc(s.id, until)
			else:
				_spook(s.id, until)


@rpc("authority", "call_local", "reliable")
func _spook(id: int, until: float) -> void:
	for s in schools:
		if s.id == id:
			var fresh := s.spooked_until < now()
			s.spooked_until = until
			if fresh and sea.get("crew") != null:
				((sea.get("crew") as Node).get("hud") as Node).call("notify",
						"Too fast: they've gone deep")


## Host: a new school somewhere round her, cruising its own way.
func _host_start() -> void:
	_ids += 1
	var ring := FIRST if _first else SPAWN
	_first = false
	var round_at := boat_at()
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		round_at = vs.call("spawn_anchor")      # (two boats, vs/vs.gd: round each, and between them)
	if slick_fresh():
		ring = SLICK_SPAWN       # (the slick's spreading: they turn up nearer it, and come up it)
		round_at = slick
	var far := start_far if start_far > 0.0 else randf_range(ring.x, ring.y)
	start_far = FAR
	var bearing := randf_range(-PI, PI)
	var start := round_at + Vector2(cos(bearing), sin(bearing)) * far
	var heading := Vector2.from_angle(randf_range(-PI, PI))
	var speed := randf_range(CRUISE.x, CRUISE.y)
	var life := randf_range(LIFE.x, LIFE.y)
	# never on land, never cruising ashore (sea/landmarks.gd): another spot round her, or another way to go
	var marks: Node = sea.get("landmarks") if sea != null else null
	if marks != null:
		for i in 24:
			if bool(marks.call("at_sea", start, 150.0)) and bool(marks.call("at_sea", start + heading * speed * life, 150.0)):
				break
			if i % 2 == 0:
				heading = Vector2.from_angle(randf_range(-PI, PI))
			else:
				bearing = randf_range(-PI, PI)
				start = round_at + Vector2(cos(bearing), sin(bearing)) * far
	var kg := randf_range(60.0, 330.0) if randf() < 0.85 else randf_range(330.0, 400.0)
	var args := [_ids, randi(), now() + 0.5, start, heading, speed, kg, life]
	if Net.in_session():
		_start.rpc.callv(args)
	else:
		_start.callv(args)


@rpc("authority", "call_local", "reliable")
func _start(id: int, seed: int, t0: float, start: Vector2, heading: Vector2, speed: float, kg: float,
		life := 240.0, run := 1e9, born := -1.0) -> void:
	var s := School.new()
	s.id = id
	s.seed = seed
	s.t0 = t0
	s.start = start
	s.heading = heading.normalized()
	s.speed = speed
	s.kg = kg
	s.life = life
	s.run = run
	s.born = born if born >= 0.0 else t0
	s.bait_only = hash1(float(seed % 977), 3.7) < BAIT_ONLY
	s.owner_node = self
	add_child(s)
	schools.append(s)


## Calling a flock (crew/spotter.gd): marked on the radar for everyone, and the crew told where it is.
func call_out(id: int) -> void:
	if Net.is_host():
		_ask_mark_as(Net.my_id(), id)
	else:
		_ask_mark.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _ask_mark(id: int) -> void:
	_ask_mark_as(multiplayer.get_remote_sender_id(), id)


func _ask_mark_as(who: int, id: int) -> void:
	if marks.has(id) or find(id) == null:
		return
	var crew: Node = sea.get("crew")
	var caller := str(crew.call("call_sign", who)) if crew else "Someone"
	if Net.in_session():
		_mark.rpc(id, caller, false)
	else:
		_mark(id, caller, false)


@rpc("authority", "call_local", "reliable")
func _mark(id: int, who: String, quiet: bool) -> void:
	marks[id] = who
	var s := find(id)
	if quiet or s == null or sea.get("crew") == null:
		return
	((sea.get("crew") as Node).get("hud") as Node).call("notify", "%s: birds, %s"
			% [who, where(s.center(now()))])


func find(id: int) -> School:
	for s in schools:
		if s.id == id:
			return s
	return null


## Where a point is from her, the way the crew'd call it: "about 1.2 km off the port bow".
func where(p: Vector2) -> String:
	var boat := sea.get("boat") as Node3D
	var at := boat_at()
	var d := p.distance_to(at)
	var local := boat.global_transform.basis.inverse() * Vector3(p.x - at.x, 0.0, p.y - at.y)
	var ang := rad_to_deg(atan2(local.x, -local.z))     # 0 dead ahead, + to starboard
	var side := "starboard" if ang > 0.0 else "port"
	var a := absf(ang)
	var dir := "dead ahead" if a < 15.0 else ("off the %s bow" % side if a < 60.0 else ("off the %s beam" % side
			if a < 120.0 else ("off the %s quarter" % side if a < 165.0 else "dead astern")))
	var far := "%d m" % (roundi(d / 50.0) * 50) if d < 1000.0 else "%.1f km" % (d / 1000.0)
	return "about %s %s" % [far, dir]


## What you'd make of a flock close enough to tell (crew/spotter.gd).
func spot_text(s: School) -> String:
	var lead := Leads.near_text(s.lead) if s.lead != null else ""
	return (lead + " " if lead != "" else "") + _birds_text(s)


func _birds_text(s: School) -> String:
	var t := now()
	if s.scattering(t) > 0.0:
		return "Scattering: moved on"
	if s.bait_only:
		if s.feeding(t):
			return "Just gulls"
		return "Just gulls"
	if t < s.spooked_until:
		return "Tuna down: wait"
	if s.feeding(t):
		return "BLUEFIN!"
	return "Tuna down: wait"


## The schools within `reach` m of a point (world), for the sonar and the strikes.
func near(p: Vector3, reach: float) -> Array[School]:
	var out: Array[School] = []
	var t := now()
	for s in schools:
		var c := s.center(t)
		if Vector2(p.x, p.z).distance_to(c) < reach:
			out.append(s)
	return out


## One school: its path, its birds, its busting. Purely a function of the clock (and its seed) after it starts.
class School extends Node3D:
	var id := 0
	var seed := 0
	var t0 := 0.0
	var start := Vector2.ZERO
	var heading := Vector2.ZERO
	var speed := 4.0
	var kg := 150.0
	var radius := 14.0
	## The birds' last SCATTER s, and a feeding spell (the outer script's, kept here too).
	const SCATTER_S := 25.0
	const SPELL_S := 40.0
	## When it turned up (sea clock): t0 moves when it's steered, this doesn't.
	var born := 0.0
	## How long it works (s), and till when it's down after a boat ran through it (sea clock).
	var life := 240.0
	var spooked_until := -1.0
	## It travels `run` s along its heading, then stays working where it got to (a chum slick); and the slick it was
	## drawn to (host only; INF: none).
	var run := 1e9
	var drawn_to := Vector2.INF
	## Birds over little bait, no bluefin under them (from its seed: everyone agrees).
	var bait_only := false
	## (host) Drawn to a chum slick rather than her baits.
	var chummed := false
	var owner_node: Node
	## A whale or a pod of dolphins on it too, or none (tuna/leads.gd, from its seed: everyone agrees).
	var lead: Node3D
	var _birds: Array[MeshInstance3D] = []
	var _bird_seed: Array[Vector4] = []
	var _jumpers: Array[Node3D] = []
	var _jump_v: Array[Vector3] = []
	var _splashes: Array[GPUParticles3D] = []
	var _sounds: Array[AudioStreamPlayer3D] = []
	var _gull: AudioStreamPlayer3D
	var _bust_slot := -1
	var _next_splash := 0
	var _gull_in := 2.0

	func center(t: float) -> Vector2:
		var d := maxf(t - t0, 0.0)
		var side := Vector2(-heading.y, heading.x)
		return start + heading * speed * minf(d, run) + side * sin(d * 0.07 + seed) * 6.0

	## Feeding: in spells of a few seconds, more often than not; not once its birds are scattering, nor while it's
	## down after a boat ran through it.
	func feeding(t: float) -> bool:
		if t < spooked_until or scattering(t) > 0.0:
			return false
		# (spells counted from when it turned up, not from a steer: a chum slick doesn't reset them)
		var spell := floorf((t - born) / SPELL_S)
		return (owner_node as Node).call("hash1", float(seed % 1000), spell) > 0.38

	## 0 while it works; 0 .. 1 over its last SCATTER s, as the birds lift and go.
	func scattering(t: float) -> float:
		return clampf((t - t0 - (life - SCATTER_S)) / SCATTER_S, 0.0, 1.0)

	func done(t: float) -> bool:
		return t - t0 > life

	func _ready() -> void:
		var bird_mesh := _bird_mesh()
		var n := 12 + seed % 9
		for i in n:
			var b := MeshInstance3D.new()
			b.mesh = bird_mesh
			b.material_override = owner_node.get("bird_mat")
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(b)
			_birds.append(b)
			var h := func(k: float) -> float: return owner_node.call("hash1", float(seed % 997) + i, k)
			# radius, height, speed (rad/s, signed), phase
			_bird_seed.append(Vector4(5.0 + 12.0 * h.call(1.0), 3.0 + 7.0 * h.call(2.0),
					(0.5 + 0.6 * h.call(3.0)) * (1.0 if h.call(4.0) > 0.5 else -1.0), TAU * h.call(5.0)))
		for i in 3:
			var j := Tuna.new(kg * randf_range(0.75, 1.25))
			j.visible = false
			add_child(j)
			_jumpers.append(j)
			_jump_v.append(Vector3.ZERO)
		for i in 4:
			var p := _splash_particles()
			add_child(p)
			_splashes.append(p)
			var a := AudioStreamPlayer3D.new()
			a.stream = SPLASH
			a.unit_size = 18.0
			a.max_distance = 300.0
			a.volume_db = 2.0
			add_child(a)
			_sounds.append(a)
		_gull = AudioStreamPlayer3D.new()
		_gull.unit_size = 25.0
		_gull.max_distance = 350.0
		add_child(_gull)
		lead = Leads.make(seed)
		if lead != null:
			lead.set("school", self)
			lead.set("ocean", owner_node.get("sea").get("ocean"))
			add_child(lead)

	func _process(delta: float) -> void:
		var o := owner_node.get("sea").get("ocean") as Node
		var t := float(o.get("wave_time"))
		var c2 := center(t)
		var c := Vector3(c2.x, 0.0, c2.y)
		var feed := feeding(t)
		# the birds: wheeling over the school, low and diving when it feeds; sitting on the water while the tuna are
		# down (high and circling if a boat ran them down); at the end lifting, spreading and gone
		var going := scattering(t)
		var sitting := not feed and going <= 0.0 and t >= spooked_until
		# a bird far off is drawn no smaller than a few pixels on the screen: a cluster of dots you can pick out on the
		# horizon with the naked eye (at its true size a bird a kilometre off would be under a pixel, and invisible)
		var cam := get_viewport().get_camera_3d()
		var speck := 1.0
		if cam:
			var dist := cam.global_position.distance_to(c)
			var px := 2.0 * tan(deg_to_rad(cam.fov) * 0.5) * dist / maxf(get_viewport().get_visible_rect().size.y, 1.0)
			speck = maxf(1.0, BIRD_PX * px / 0.5)
		for i in _birds.size():
			var bs := _bird_seed[i]
			var b := _birds[i]
			if sitting:
				# rafted up on the water, bobbing
				var a0 := bs.w * 3.0
				var p0 := c + Vector3(cos(a0) * bs.x * 0.6, 0.0, sin(a0) * bs.x * 0.6)
				p0.y = float(o.call("height_at", p0)) + 0.15
				b.position = p0
				b.basis = Basis(Vector3.UP, a0).scaled(Vector3(0.5, 0.5, 0.5) * speck)
				continue
			var a := bs.w + t * bs.z
			var low := 1.0 if feed else 0.0
			var high := 25.0 if t < spooked_until else 0.0
			var h := lerpf(bs.y, 1.2 + bs.y * 0.25, low * (0.5 + 0.5 * sin(t * 1.3 + i))) + going * going * 60.0 + high
			# feeding, each bird now and then folds its wings and plunges into the water, then beats back up
			var dive := 0.0
			if feed:
				var cyc := fposmod(t + bs.w * 3.0, 5.0 + 3.0 * absf(bs.z))
				dive = smoothstep(0.0, 0.5, cyc) * (1.0 - smoothstep(0.5, 1.4, cyc)) if cyc < 1.4 else 0.0
			var spread := bs.x * (1.0 + going * 6.0)
			var p := c + Vector3(cos(a) * spread, 0.0, sin(a) * spread)
			p.y = float(o.call("height_at", p)) + lerpf(h, -0.2, dive)
			b.position = p
			var fwd := Vector3(-sin(a), 0.0, cos(a)) * signf(bs.z)
			# gliding mostly (wings held out, a little up), flapping in bursts and climbing out of a dive; folded in it
			var burst := sin(t * 0.7 + bs.w * 5.0) > 0.55 or (dive > 0.0 and dive < 0.6)
			var flap := (0.4 + 0.6 * absf(sin(t * 10.0 + i * 1.7))) if burst else 0.8
			var fold := lerpf(1.0, 0.35, smoothstep(0.3, 0.8, dive))
			var tip := -0.5 * signf(bs.z) * (1.0 - dive) + dive * 1.2          # (banked round, or nose down)
			b.basis = Basis.looking_at(fwd, Vector3.UP).rotated(fwd, tip * (0.0 if dive > 0.3 else 1.0)) \
					.rotated(fwd.cross(Vector3.UP).normalized(), -1.1 * dive) \
					.scaled(Vector3(fold, flap, 1.0) * speck)
		_gull_in -= delta
		if _gull_in <= 0.0:
			_gull_in = randf_range(2.0, 6.0) if feed else randf_range(6.0, 14.0)
			_gull.stream = GULLS[randi() % GULLS.size()]
			_gull.pitch_scale = randf_range(0.85, 1.15)
			_gull.position = _birds[randi() % _birds.size()].position
			_gull.play()
		# busting: a burst of white water every half second or so while it feeds; every third, a tuna clears it
		# (over little bait, only now and then, small, and nothing clears the water)
		var slot := int(floorf((t - t0) / (1.4 if bait_only else 0.45)))
		if feed and slot != _bust_slot:
			_bust_slot = slot
			var r := radius * sqrt(owner_node.call("hash1", float(seed % 991), float(slot)))
			var ang := TAU * float(owner_node.call("hash1", float(slot), float(seed % 983)))
			var p := c + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			p.y = float(o.call("height_at", p))
			_bust(p, slot % 3 == 0 and not bait_only)
		for i in _jumpers.size():
			var j := _jumpers[i]
			if not j.visible:
				continue
			_jump_v[i].y -= 9.8 * delta
			j.velocity = _jump_v[i]
			if j.position.y < float(o.call("height_at", j.position)) - 0.5 and _jump_v[i].y < 0.0:
				j.visible = false
				_bust(j.position, false)

	func _bust(p: Vector3, leap: bool) -> void:
		var k := _next_splash % _splashes.size()
		_next_splash += 1
		var s := _splashes[k]
		s.global_position = p
		s.restart()
		s.emitting = true
		_sounds[k].global_position = p
		_sounds[k].pitch_scale = randf_range(0.7, 1.1)
		_sounds[k].play()
		if leap:
			for i in _jumpers.size():
				var j := _jumpers[i]
				if j.visible:
					continue
				var dir := Vector3(heading.x, 0.0, heading.y).rotated(Vector3.UP, randf_range(-1.2, 1.2))
				j.position = p
				_jump_v[i] = dir * randf_range(4.0, 7.0) + Vector3.UP * randf_range(4.0, 6.0)
				j.velocity = _jump_v[i]
				j.effort = 1.0
				j.visible = true
				break

	func _splash_particles() -> GPUParticles3D:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.8
		pm.direction = Vector3.UP
		pm.spread = 35.0
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 9.0
		pm.gravity = Vector3(0, -9.8, 0)
		pm.scale_min = 0.8
		pm.scale_max = 2.2
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0.95))
		fade.set_color(1, Color(1, 1, 1, 0.0))
		var ft := GradientTexture1D.new()
		ft.gradient = fade
		pm.color_ramp = ft
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = PUFF
		mat.albedo_color = Color(0.92, 0.95, 0.97)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var q := QuadMesh.new()
		q.size = Vector2(1.4, 1.4)
		q.material = mat
		var p := GPUParticles3D.new()
		p.amount = 60
		p.lifetime = 1.3
		p.one_shot = true
		p.explosiveness = 0.9
		p.emitting = false
		p.local_coords = false
		p.process_material = pm
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 20, 20))
		return p

	## A shearwater (they work the bluefin schools): a shallow W, dark, a metre and a half across, bigger than life so
	## it reads against a grey sky from the boat.
	static func _bird_mesh() -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(-0.8, 0.12, 0.08), Vector3(-0.36, 0.0, -0.12), Vector3(0, 0.03, -0.36),
				Vector3(0.36, 0.0, -0.12), Vector3(0.8, 0.12, 0.08), Vector3(0, -0.03, 0.3)]
		for tri: Array in [[0, 1, 5], [1, 2, 5], [2, 3, 5], [3, 4, 5]]:
			for k: int in tri:
				st.add_vertex(pts[k])
			for k: int in [tri[2], tri[1], tri[0]]:
				st.add_vertex(pts[k])
		st.generate_normals()
		var m := st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.19, 0.18)
		mat.roughness = 1.0
		m.surface_set_material(0, mat)
		return m
