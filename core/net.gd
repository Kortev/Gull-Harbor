extends Node
## Networking: a listen server (the host plays too), up to four on one boat, two ways, neither needing a server of
## our own or port forwarding:
## - Steam (the main way, core/steam_link.gd): a friends-only Steam lobby, the traffic through Steam's relays; friends
##   join from the menu's list or an invite. Needs the GodotSteam add-on and Steam running.
## - A join code (the backup): ENet; hosting asks the router to open the port itself (UPnP, on by default on most
##   home routers) and hands you a short code (your address, spelled out) for your friend to type in; joining never
##   needs anything opened. The host owns the truth: a client asks the
## host with rpc_id(1, ...), the host checks, applies and broadcasts. The crew roster and the shared sea clock live in sea/sea.gd, which listens to the signals here.

const PORT := 7777
const MAX_CREW := 4

## We're hosting now (the crew can join).
signal hosted
## We joined someone's boat (connected; the host's welcome follows).
signal joined
## Joining failed, or the host went away.
signal dropped(reason: String)
## We left the crew ourselves (the menu's Leave), hosting or not: back to our own boat.
signal left(was_host: bool)
signal peer_joined(id: int)
signal peer_left(id: int)
## After hosting: whether the router opened the port, and the join code for friends (over the internet if it did,
## on your own network only if it didn't).
signal opened(ok: bool, code: String)

## The join code alphabet: no 0/O or 1/I to mix up.
const CODE_ABC := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

## The join code for this boat ("" until hosting has worked it out).
var code := ""
var _upnp: UPNP
var _upnp_thread: Thread
## Steam (core/steam_link.gd): `steam.available` says whether it's there.
var steam: Node
## How this session runs: "", "steam" or "code".
var mode := ""


func _ready() -> void:
	steam = preload("res://core/steam_link.gd").new()
	steam.name = "Steam"
	steam.hosting.connect(func(peer: MultiplayerPeer) -> void:
		mode = "steam"
		multiplayer.multiplayer_peer = peer
		hosted.emit())
	steam.joining.connect(func(peer: MultiplayerPeer) -> void:
		mode = "steam"
		multiplayer.multiplayer_peer = peer)
	steam.failed.connect(func(reason: String) -> void:
		_close()
		dropped.emit(reason))
	add_child(steam)
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: joined.emit())
	multiplayer.connection_failed.connect(func() -> void:
		_close()
		dropped.emit("Couldn't reach that boat."))
	multiplayer.server_disconnected.connect(func() -> void:
		_close()
		dropped.emit("The host left."))


## Hosting over Steam (the answer comes as `hosted`, or `dropped` with why not).
func host_steam() -> void:
	_close()
	steam.call("host")


## Joining a Steam friend's boat (their lobby, from the menu's list).
func join_steam(lobby: int) -> void:
	_close()
	steam.call("join", lobby)


func host(port := PORT) -> Error:
	_close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CREW - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	code = ""
	mode = "code"
	hosted.emit()
	# asking the router takes a second or two: off the main thread
	_finish_upnp()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_open_port.bind(port))
	return OK


func join(address: String, port := PORT) -> Error:
	_close()
	var peer := ENetMultiplayerPeer.new()
	var to := address.strip_edges()
	if to.is_empty():
		to = "127.0.0.1"
	elif not decode(to).is_empty():
		to = decode(to)
	var err := peer.create_client(to, port)
	if err != OK:
		return err
	mode = "code"
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	var was_host := in_session_or_hosting() and multiplayer.is_server()
	_close()
	left.emit(was_host)


func in_session() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) \
			and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## True when we decide things: hosting, or playing alone.
func is_host() -> bool:
	return not in_session() or multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if in_session() else 1


## Round trip to the host in seconds (0 when we are the host).
func ping() -> float:
	var p := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if p == null or multiplayer.is_server():
		return 0.0
	var host_peer := p.get_peer(1)
	return host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME) / 1000.0 if host_peer else 0.0


## An IPv4 address as a join code ("K7Q2-M9X"), and back ("" if it isn't one).
static func encode(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var n := 0
	for part in parts:
		n = n * 256 + clampi(part.to_int(), 0, 255)
	var out := ""
	for i in 7:
		out = CODE_ABC[n % 32] + out
		n /= 32
	return out.substr(0, 4) + "-" + out.substr(4)


static func decode(text: String) -> String:
	var t := text.to_upper().replace("-", "").replace(" ", "")
	if t.length() != 7:
		return ""
	var n := 0
	for ch in t:
		var v := CODE_ABC.find(ch)
		if v < 0:
			return ""
		n = n * 32 + v
	if n >= 1 << 32:
		return ""
	return "%d.%d.%d.%d" % [(n >> 24) & 255, (n >> 16) & 255, (n >> 8) & 255, n & 255]


## (On its own thread.) Asks the router to forward the port to us, and finds our address on the internet.
func _open_port(port: int) -> void:
	var u := UPNP.new()
	var ok := u.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() != null \
			and u.get_gateway().is_valid_gateway()
	var ip := ""
	if ok:
		ok = u.add_port_mapping(port, port, "Bluefin", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
		ip = u.query_external_address()
		ok = ok and not ip.is_empty()
	_opened.call_deferred(ok, ip, u if ok else null)


func _opened(ok: bool, ip: String, u: UPNP) -> void:
	if not in_session_or_hosting():
		if u != null:
			u.delete_port_mapping(PORT, "UDP")    # (we stopped hosting while it asked)
		return
	_upnp = u
	if not ok:
		ip = _lan_address()
	code = encode(ip)
	opened.emit(ok, code)


## Our address on the home network (for friends on the same Wi-Fi).
static func _lan_address() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "127.0.0.1"


## Hosting (even with nobody aboard yet).
func in_session_or_hosting() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer)


func _finish_upnp() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null


func _exit_tree() -> void:
	_close()
	_finish_upnp()


func _close() -> void:
	mode = ""
	if steam != null:
		steam.call("leave")
	if _upnp != null:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null
	code = ""
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
