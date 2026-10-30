extends Node
## Playing over Steam: no ports, no codes. The host makes a friends-only Steam lobby and the game's traffic goes
## through Steam's relays (SteamMultiplayerPeer), so it works from any home whatever the router; friends join from
## the Esc menu (your Steam friends with a boat out are listed) or from an invite (Shift+Tab, a friend, Invite).
##
## The GodotSteam GDExtension (4.23.2, Steamworks 1.65, for Godot 4.4 and up) sits in addons/godotsteam with its
## Windows, Linux and Mac libraries; an export copies them next to the game. With Steam not running (or headless, as
## the tests run) `available` stays false and the menu only offers the join code (core/net.gd). Everything here goes
## through the Steam singleton by name, so the game runs without the add-on too.
## App id 480 is Valve's free test app ("Spacewar"): fine for friends; a Steam page of our own would change it. The
## id goes to steamInitEx itself, so neither the editor nor an export needs steam_appid.txt beside it (it's kept in
## the project root anyway, which is where Steam's own fallback looks when running from the editor).
## Steam shows you as playing "Spacewar". Both players start the game first, then invite or join (an invite can't
## start the game for you on app 480; if Steam does pass +connect_lobby on the command line, we join it).

const APP_ID := 480
const LOBBY_FRIENDS_ONLY := 1
const RESULT_OK := 1
const ENTER_SUCCESS := 1
const FRIEND_IMMEDIATE := 4
## Marks our lobbies (every app-480 game shares the same lobby space).
const TAG := "bluefin"

## We're hosting over Steam: hand this peer to the multiplayer API.
signal hosting(peer: MultiplayerPeer)
## We're joining a friend's boat over Steam.
signal joining(peer: MultiplayerPeer)
signal failed(reason: String)

var available := false
var lobby := 0
## The Steam singleton (or a test's stand-in, through start()); tests swap make_peer too.
var steam: Object
var make_peer: Callable = func() -> MultiplayerPeer: return ClassDB.instantiate("SteamMultiplayerPeer")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return      # (the headless tests never touch the real Steam; they hand start() a stand-in)
	if Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer"):
		start(Engine.get_singleton("Steam"))


## Starts up Steam (the singleton, or a test's stand-in) and listens for lobbies and invites.
func start(singleton: Object) -> void:
	steam = singleton
	var r: Variant = steam.call("steamInitEx", APP_ID, false)
	available = (int((r as Dictionary).get("status", 1)) == 0) if r is Dictionary else bool(r)
	if not available:
		print("Steam: not available (", r, "): playing with join codes only")
		return
	print("Steam: on as ", steam.call("getPersonaName"), " (app ", APP_ID, ")")
	steam.connect("lobby_created", _on_lobby_created)
	steam.connect("lobby_joined", _on_lobby_joined)
	steam.connect("join_requested", _on_join_requested)
	steam.call("initRelayNetworkAccess")      # (warms up the relay network now, not on the first connection)
	var args := OS.get_cmdline_args()
	var at := args.find("+connect_lobby")
	if at >= 0 and at + 1 < args.size() and int(args[at + 1]) != 0:
		join.call_deferred(int(args[at + 1]))


func _process(_delta: float) -> void:
	if available:
		steam.call("run_callbacks")


func host() -> void:
	leave()
	steam.call("createLobby", LOBBY_FRIENDS_ONLY, 4)


func join(lobby_id: int) -> void:
	leave()
	steam.call("joinLobby", lobby_id)


func invite() -> void:
	if lobby != 0:
		steam.call("activateGameOverlayInviteDialog", lobby)


func leave() -> void:
	if available and lobby != 0:
		steam.call("leaveLobby", lobby)
	lobby = 0


## Steam friends with a boat out right now: [{"name": ..., "lobby": ...}].
func friends_out() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not available:
		return out
	for i in int(steam.call("getFriendCount", FRIEND_IMMEDIATE)):
		var id := int(steam.call("getFriendByIndex", i, FRIEND_IMMEDIATE))
		var game: Dictionary = steam.call("getFriendGamePlayed", id)
		if int(game.get("id", 0)) == APP_ID and int(game.get("lobby", 0)) != 0:
			out.append({"name": str(steam.call("getFriendPersonaName", id)), "lobby": int(game["lobby"])})
	return out


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != RESULT_OK:
		failed.emit("Steam couldn't make a lobby (%d)." % result)
		return
	lobby = lobby_id
	steam.call("setLobbyData", lobby_id, "game", TAG)
	var peer: MultiplayerPeer = make_peer.call()
	var err := int(_call_flexible(peer, "create_host", [0]))
	if err != OK:
		failed.emit("Steam couldn't host (%d)." % err)
		return
	hosting.emit(peer)


func _on_join_requested(lobby_id: int, _friend: int) -> void:
	join(lobby_id)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_SUCCESS:
		failed.emit("Couldn't get into that Steam lobby (%d)." % response)
		return
	var owner_id := int(steam.call("getLobbyOwner", lobby_id))
	if owner_id == int(steam.call("getSteamID")):
		return      # (our own lobby: we're the host)
	lobby = lobby_id
	var peer: MultiplayerPeer = make_peer.call()
	var err := int(_call_flexible(peer, "create_client", [owner_id, 0]))
	if err != OK:
		failed.emit("Steam couldn't reach that boat (%d)." % err)
		return
	joining.emit(peer)


## Calls a method whose extra arguments differ between GodotSteam versions (some take an options array at the end):
## pads with empty arrays to the method's own argument count.
static func _call_flexible(obj: Object, method: String, args: Array) -> Variant:
	for m in obj.get_method_list():
		if str(m["name"]) == method:
			var n: int = (m["args"] as Array).size() - (m["default_args"] as Array).size()
			while args.size() < n:
				args.append([])
			break
	return obj.callv(method, args)
