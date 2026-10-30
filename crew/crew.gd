extends Node
## The crew on the boat: who's aboard, each one's spot, and the things every peer must share to see the same sea
## (the wave clock, the weather's seed). Players live under this node, named by peer id, so their paths match on
## every peer. Alone you're crew member 1; host and you stay 1 and friends join; join someone and you take the
## spot their host gives you.

const Player := preload("res://crew/player.gd")
const Hud := preload("res://ui/hud.gd")

## The local crew member changed (spawned, or gone when joining another boat).
signal me_changed(player: Player)

var sea: Node            # sea/sea.gd
var hud: Hud
var me: Player
var slots := {}          # peer id -> spawn slot
var _clock_in := 0.0
var _clock_asks := 0
var _best_rtt := INF


func _ready() -> void:
	hud = Hud.new()
	add_child(hud)
	(sea.get("boat") as Node).connect("rebuilt", _on_rebuilt)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_remove)
	Net.joined.connect(_on_joined)
	Net.dropped.connect(_on_dropped)


## The boat was rebuilt as another kind (boat/boat.gd): everyone back to their spot on her new deck.
func _on_rebuilt() -> void:
	for id: int in slots:
		var p := get_player(id)
		if p:
			var at: Transform3D = p.boat.call("spawn_local", int(slots[id]))
			p.place(at.origin, at.basis.get_euler().y)


## Which boat crew member `id` is on: the one boat, or in VS (vs/vs.gd) their side's.
func boat_of(id: int) -> Node3D:
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		return vs.call("boat_of", id)
	return sea.get("boat") as Node3D


## Crew member `id`'s boat changed (VS): made again on her, at their spot.
func reseat(id: int) -> void:
	var p := get_player(id)
	if p == null or p.boat == boat_of(id):
		return
	remove_child(p)
	p.queue_free()
	if me == p:
		me = null
	_add(id, int(slots[id]))


func start_solo() -> void:
	_clear()
	(sea.get("ocean") as Node).set("clock_offset", 0.0)
	_add(1, 0)


func get_player(id: int) -> Player:
	return get_node_or_null(str(id)) as Player


func _process(delta: float) -> void:
	# a crewmate keeps their sea in step with the host's: ask its clock now and then (often at first)
	if Net.in_session() and not multiplayer.is_server():
		_clock_in -= delta
		if _clock_in <= 0.0:
			_clock_in = 0.25 if _clock_asks < 8 else 4.0
			_clock_asks += 1
			_ask_clock.rpc_id(1, Time.get_ticks_msec() / 1000.0)


# ------------------------------------------------------------------ the host

func _on_peer_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	var slot := _free_slot()
	var roster := slots.duplicate()
	roster[id] = slot
	var w: RefCounted = sea.get("weather")
	_welcome.rpc_id(id, int(w.get("seed")), str(w.get("pinned")), bool(sea.get("night")), _clock_now(), roster)
	_add_crew.rpc(id, slot)


func _free_slot() -> int:
	for s in 4:
		if not slots.values().has(s):
			return s
	return slots.size()


# ------------------------------------------------------------------ everyone

@rpc("authority", "call_remote", "reliable")
func _welcome(weather_seed: int, pinned: String, is_night: bool, clock: float, roster: Dictionary) -> void:
	_clear()
	_set_clock(clock, true)       # (rough: the asks that follow tighten it)
	_clock_asks = 0
	_best_rtt = INF
	_clock_in = 0.0
	# the weather: the host's, from here on worked out from the shared clock
	var w: RefCounted = sea.get("weather")
	w.set("seed", weather_seed)
	w.set("pinned", pinned)
	sea.call("set_night", is_night)
	for id: int in roster:
		_add(id, int(roster[id]))


@rpc("authority", "call_local", "reliable")
func _add_crew(id: int, slot: int) -> void:
	if get_player(id) == null:
		_add(id, slot)


@rpc("any_peer", "call_remote", "unreliable")
func _ask_clock(sent: float) -> void:
	if multiplayer.is_server():
		_tell_clock.rpc_id(multiplayer.get_remote_sender_id(), sent, _clock_now())


## The host's clock, answering our ask: the round trip tells how stale it is. The quickest answers are the truest,
## so a slow one only counts if it's all we've had for a while.
@rpc("authority", "call_remote", "unreliable")
func _tell_clock(sent: float, host_clock: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var rtt := now - sent
	_best_rtt = minf(_best_rtt * 1.02 + 0.001, rtt)
	if rtt <= _best_rtt * 1.2 + 0.004:
		_set_clock(host_clock + rtt * 0.5, _clock_asks <= 1)


## The sea's clock this instant (ocean.wave_time is from the start of the frame).
func _clock_now() -> float:
	return Time.get_ticks_msec() / 1000.0 + float((sea.get("ocean") as Node).get("clock_offset"))


## Matches our wave clock to the host's, which reads `host_clock` right now.
func _set_clock(host_clock: float, snap: bool) -> void:
	var ocean := sea.get("ocean") as Node
	var target := host_clock - Time.get_ticks_msec() / 1000.0
	var now := float(ocean.get("clock_offset"))
	ocean.set("clock_offset", target if snap or absf(target - now) > 0.5 else lerpf(now, target, 0.3))


func _on_joined() -> void:
	_clear()     # the host's welcome brings the roster


func _on_dropped(reason: String) -> void:
	start_solo()
	hud.notify(reason)


func _add(id: int, slot: int) -> void:
	slots[id] = slot          # (first: the player's oilskins take their colour from it as it's made)
	var p := Player.new()
	p.name = str(id)
	p.boat = boat_of(id)
	add_child(p)
	var at: Transform3D = p.boat.call("spawn_local", slot)
	p.place(at.origin, at.basis.get_euler().y)
	slots[id] = slot
	if p.is_multiplayer_authority():
		me = p
		hud.follow(p)
		me_changed.emit(p)


## What the crew call each other: by their oilskins.
func call_sign(id: int) -> String:
	return ["Yellow", "Orange", "Green", "Red"][int(slots.get(id, 0)) % 4]


func _remove(id: int) -> void:
	var p := get_player(id)
	if p:
		p.queue_free()
	slots.erase(id)


func _clear() -> void:
	for c in get_children():
		if c is Player:
			remove_child(c)
			c.queue_free()
	slots.clear()
	me = null
