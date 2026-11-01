extends Node
## The crew on the boat: who's aboard, each one's spot, and the things every peer must share to see the same sea
## (the wave clock, the weather's seed). Players live under this node, named by peer id, so their paths match on
## every peer. Alone you're crew member 1; host and you stay 1 and friends join; join someone and you take the
## spot their host gives you.
##
## Dropped mid-game (the line went, not in the lobby): the host keeps their spot (`away`: their oilskins, their boat in
## Rivals) and every screen says who we're waiting on; the next to join is them come back (`back`), put in the same
## spot, their oilskins fading in where they stand, and everything going on synced in as for anyone joining.

const Player := preload("res://crew/player.gd")
const Hud := preload("res://ui/hud.gd")
const Talk := preload("res://crew/talk.gd")
const PixFont := preload("res://ui/pixfont.gd")
## How long a crewmate come back takes to fade in (s).
const FADE_IN := 1.2

## The local crew member changed (spawned, or gone when joining another boat).
signal me_changed(player: Player)

var sea: Node            # sea/sea.gd
var hud: Hud
## Voice: out loud and over the VHF (crew/talk.gd).
var talk: Talk
var me: Player
var slots := {}          # peer id -> spawn slot
## Host: who dropped mid-game (old peer id -> {sign, slot, team}), and who's come back (new peer id -> what they had).
var away := {}
var back := {}
## Everyone: the call signs we're waiting on (the host's word), shown top middle.
var waiting: Array = []
var _fade_until := {}         # peer id -> msec: made before then, they fade in
var _notice: Control
var _clock_in := 0.0
var _clock_asks := 0
var _best_rtt := INF


func _ready() -> void:
	hud = Hud.new()
	add_child(hud)
	talk = Talk.new()
	talk.name = "Talk"
	talk.crew = self
	add_child(talk)
	var layer := CanvasLayer.new()
	layer.layer = 17          # (over the results card, vs/card.gd)
	add_child(layer)
	_notice = Control.new()
	_notice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	_notice.draw.connect(_draw_notice)
	layer.add_child(_notice)
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
			var at: Transform3D = p.home.call("spawn_local", int(slots[id]))
			p.place(at.origin, at.basis.get_euler().y, p.home)


## Which boat crew member `id` is on: the one boat, or in VS (vs/vs.gd) their side's.
func boat_of(id: int) -> Node3D:
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		return vs.call("boat_of", id)
	return sea.get("boat") as Node3D


## Crew member `id`'s boat changed (VS): made again on her, at their spot. (Their crew's boat: aboard the other
## one, over her rail or up her ladder, they're still hers; `away` brings them home anyway: the other boat's going.)
func reseat(id: int, away := false) -> void:
	var p := get_player(id)
	if p == null or (p.home == boat_of(id) and not (away and p.boat != p.home)):
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
	_notice.visible = not waiting.is_empty()
	if _notice.visible:
		_notice.queue_redraw()


## Who we're waiting on: "ORANGE LOST CONNECTION — WAITING" ("" when nobody).
func notice_text() -> String:
	if waiting.is_empty():
		return ""
	return " & ".join(PackedStringArray(waiting.map(func(w: String) -> String: return w.to_upper()))) \
			+ " LOST CONNECTION — WAITING"


## Top middle, in the pixel font, on a dark strip, the dots counting.
func _draw_notice() -> void:
	var text := notice_text()
	if text.is_empty():
		return
	var sc := 3
	var w := PixFont.width(text + "...", sc)
	var at := Vector2(floorf((_notice.size.x - w) * 0.5), 14.0)
	text += "...".left(int(Time.get_ticks_msec() / 400) % 4)
	_notice.draw_rect(Rect2(at - Vector2(12, 8), Vector2(w + 24, 5 * sc + 16)), Color(0.02, 0.03, 0.05, 0.75))
	PixFont.draw(_notice, at + Vector2(sc, sc), text, Color(0, 0, 0, 0.85), sc)
	PixFont.draw(_notice, at, text, Color(1.0, 0.62, 0.38), sc)


# ------------------------------------------------------------------ the host

func _on_peer_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	var slot := _free_slot()
	# someone we've been waiting on: this is them back (first dropped, first back), in their own spot
	var was := {}
	if not away.is_empty():
		var old: int = away.keys()[0]
		was = away[old]
		away.erase(old)
		back[id] = was
		if not slots.values().has(int(was["slot"])):
			slot = int(was["slot"])
		var vs: Node = sea.get("vs")
		if was.has("team") and vs != null and bool(vs.get("on")):
			(vs.get("teams") as Dictionary)[id] = int(was["team"])     # (made aboard her here: vs/vs.gd tells everyone)
		_say_waiting()
	var vs: Node = sea.get("vs")
	if vs != null and bool(vs.get("on")):
		vs.call("seat_new", id)        # (someone new: their boat now, so they're made on her)
	var roster := slots.duplicate()
	roster[id] = slot
	var w: RefCounted = sea.get("weather")
	_welcome.rpc_id(id, int(w.get("seed")), str(w.get("pinned")), bool(sea.get("night")), _clock_now(), roster)
	_add_crew.rpc(id, slot, not was.is_empty())


## Host: a game going on (the title's down, or there's none): a crewmate dropping now has their spot kept.
func _mid_game() -> bool:
	var title: Node = sea.get("title")
	return title == null or not bool(title.get("up"))


func _say_waiting() -> void:
	var signs: Array = away.values().map(func(w: Dictionary) -> String: return str(w["sign"]))
	if Net.in_session_or_hosting():
		_waiting.rpc(signs)
	else:
		_waiting(signs)


@rpc("authority", "call_local", "reliable")
func _waiting(signs: Array) -> void:
	waiting = signs


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
func _add_crew(id: int, slot: int, returning := false) -> void:
	if returning:
		_fade_until[id] = Time.get_ticks_msec() + 1000
	if get_player(id) == null:
		_add(id, slot)
	if returning and id != Net.my_id():
		hud.notify("%s's back aboard" % call_sign(id))


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
	p.home = p.boat
	add_child(p)
	var at: Transform3D = p.boat.call("spawn_local", slot)
	p.place(at.origin, at.basis.get_euler().y)
	slots[id] = slot
	if int(_fade_until.get(id, 0)) > Time.get_ticks_msec():
		p.fade_in(FADE_IN)       # (and again if they're made again on their own boat straight after: vs/vs.gd)
	if p.is_multiplayer_authority():
		me = p
		hud.follow(p)
		me_changed.emit(p)


## What the crew call each other: by their oilskins.
func call_sign(id: int) -> String:
	return ["Yellow", "Orange", "Green", "Red"][int(slots.get(id, 0)) % 4]


func _remove(id: int) -> void:
	back.erase(id)
	if multiplayer.is_server() and slots.has(id) and id != 1:
		if Net.quit.has(id):
			if bool(Net.quit[id]):
				hud.notify("%s left" % call_sign(id))       # (on purpose: no spot kept; false: back already, vs/vs.gd)
		elif _mid_game():
			away[id] = {"sign": call_sign(id), "slot": int(slots[id])}
			_say_waiting()
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
	away.clear()
	back.clear()
	waiting = []
	_fade_until.clear()
