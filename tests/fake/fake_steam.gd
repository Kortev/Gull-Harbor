extends Object
## A stand-in for the GodotSteam singleton, just enough for core/steam_link.gd: lobbies made and joined at once, one
## friend with a boat out. tests/steam_test.tscn.

signal lobby_created(connect: int, lobby_id: int)
signal lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int)
signal join_requested(lobby_id: int, steam_id: int)

const LOBBY := 777
const HOST_ID := 1001

var me := 0
var calls: Array[String] = []


func steamInitEx(_app_id := 0, _embed := false) -> Dictionary:
	return {"status": 0, "verbal": "ok"}


func getPersonaName() -> String:
	return "Jack" if me == HOST_ID else "Ann"


func initRelayNetworkAccess() -> void:
	pass


func run_callbacks() -> void:
	pass


func createLobby(_type: int, _max: int) -> void:
	calls.append("createLobby")
	lobby_created.emit.call_deferred(1, LOBBY)


func joinLobby(lobby: int) -> void:
	calls.append("joinLobby")
	lobby_joined.emit.call_deferred(lobby, 0, false, 1)


func leaveLobby(_lobby: int) -> void:
	calls.append("leaveLobby")


func setLobbyData(_lobby: int, _k: String, _v: String) -> bool:
	return true


func getLobbyOwner(_lobby: int) -> int:
	return HOST_ID


func getSteamID() -> int:
	return me


func activateGameOverlayInviteDialog(_lobby: int) -> void:
	calls.append("invite")


func getFriendCount(_flags: int) -> int:
	return 2


func getFriendByIndex(i: int, _flags: int) -> int:
	return [5005, HOST_ID][i]


func getFriendGamePlayed(id: int) -> Dictionary:
	return {"id": 480, "lobby": LOBBY} if id == HOST_ID else {"id": 730, "lobby": 0}


func getFriendPersonaName(id: int) -> String:
	return "Jack" if id == HOST_ID else "Someone"
