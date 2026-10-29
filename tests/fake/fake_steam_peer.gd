extends MultiplayerPeerExtension
## A stand-in for SteamMultiplayerPeer (its create_host / create_client by Steam id) for tests/steam_test.tscn: an
## ENet peer on this machine inside, everything handed through to it.

const PORT := 7791

var _in := ENetMultiplayerPeer.new()


func create_host(_virtual_port: int) -> Error:
	var err := _in.create_server(PORT, 3)
	_wire()
	return err


func create_client(_steam_id: int, _virtual_port: int) -> Error:
	var err := _in.create_client("127.0.0.1", PORT)
	_wire()
	return err


func _wire() -> void:
	_in.peer_connected.connect(func(id: int) -> void: peer_connected.emit(id))
	_in.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))


func _get_packet_script() -> PackedByteArray:
	return _in.get_packet()


func _put_packet_script(p: PackedByteArray) -> Error:
	return _in.put_packet(p)


func _get_available_packet_count() -> int:
	return _in.get_available_packet_count()


func _get_max_packet_size() -> int:
	return 1 << 20


func _get_packet_channel() -> int:
	return _in.get_packet_channel()


func _get_packet_mode() -> TransferMode:
	return _in.get_packet_mode()


func _set_transfer_channel(c: int) -> void:
	_in.transfer_channel = c


func _get_transfer_channel() -> int:
	return _in.transfer_channel


func _set_transfer_mode(m: TransferMode) -> void:
	_in.transfer_mode = m


func _get_transfer_mode() -> TransferMode:
	return _in.transfer_mode


func _set_target_peer(p: int) -> void:
	_in.set_target_peer(p)


func _get_packet_peer() -> int:
	return _in.get_packet_peer()


func _is_server() -> bool:
	return _in.get_unique_id() == 1


func _poll() -> void:
	_in.poll()


func _close() -> void:
	_in.close()


func _disconnect_peer(p: int, now: bool) -> void:
	_in.disconnect_peer(p, now)


func _get_unique_id() -> int:
	return _in.get_unique_id()


func _get_connection_status() -> ConnectionStatus:
	return _in.get_connection_status()


func _is_server_relay_supported() -> bool:
	return true


func _is_refusing_new_connections() -> bool:
	return _in.refuse_new_connections


func _set_refuse_new_connections(on: bool) -> void:
	_in.refuse_new_connections = on
