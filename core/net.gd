extends Node
## Networking: an ENet listen server (the host plays too), up to four on one boat. Steam lobbies come later behind
## the same calls. The host owns the truth: a client asks the host with rpc_id(1, ...), the host checks, applies and
## broadcasts. The crew roster and the shared sea clock live in sea/sea.gd, which listens to the signals here.

const PORT := 7777
const MAX_CREW := 4

## We're hosting now (the crew can join).
signal hosted
## We joined someone's boat (connected; the host's welcome follows).
signal joined
## Joining failed, or the host went away.
signal dropped(reason: String)
signal peer_joined(id: int)
signal peer_left(id: int)


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: joined.emit())
	multiplayer.connection_failed.connect(func() -> void:
		_close()
		dropped.emit("Couldn't reach that boat."))
	multiplayer.server_disconnected.connect(func() -> void:
		_close()
		dropped.emit("The host left."))


func host(port := PORT) -> Error:
	_close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CREW - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	hosted.emit()
	return OK


func join(address: String, port := PORT) -> Error:
	_close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges() if not address.strip_edges().is_empty() else "127.0.0.1",
			port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	_close()


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


func _close() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
