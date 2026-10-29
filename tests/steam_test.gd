extends Node
## Playing over Steam, with a stand-in for Steam (tests/fake/): one copy hosts a Steam lobby, the other finds "Jack"
## with a boat out in its friends list and joins. Run both with tools/steam_test.sh.

const FakeSteam := preload("res://tests/fake/fake_steam.gd")
const FakePeer := preload("res://tests/fake/fake_steam_peer.gd")


func _ready() -> void:
	var role := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
	var fake := FakeSteam.new()
	fake.me = FakeSteam.HOST_ID if role == "host" else 2002
	Net.steam.make_peer = func() -> MultiplayerPeer: return FakePeer.new()
	Net.steam.start(fake)
	print("STEAM available=%s" % Net.steam.available)
	add_child((load("res://sea/sea.tscn") as PackedScene).instantiate())
	if role == "host":
		Net.host_steam()
		await Net.hosted
		print("STEAM hosting mode=%s calls=%s" % [Net.mode, fake.calls])
	else:
		await get_tree().create_timer(1.5).timeout
		var friends: Array[Dictionary] = Net.steam.friends_out()
		print("STEAM friends with a boat out: %s" % [friends])
		if not friends.is_empty():
			Net.join_steam(int(friends[0]["lobby"]))
			await Net.joined
			print("STEAM joined mode=%s calls=%s" % [Net.mode, fake.calls])
