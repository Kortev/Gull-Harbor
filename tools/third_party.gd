extends SceneTree
## Writes THIRD_PARTY_NOTICES.txt (the project root): every license the shipped game owes a notice to, in full. The
## Godot engine's own (MIT) and all its parts' (from the engine itself, so it matches the build exactly), GodotSteam's
## (MIT), the Steamworks SDK's redistributable, and the CC0 sources the sounds and textures came from. tools/release.sh
## puts it beside the exe. Run again after changing Godot's version or adding anything third-party.
## Run: godot --headless --path . --script res://tools/third_party.gd

const Version := preload("res://core/version.gd")
const OUT := "res://THIRD_PARTY_NOTICES.txt"


func _init() -> void:
	var t := PackedStringArray()
	var rule := "=".repeat(78)
	t.append("Bluefin %s - third-party notices" % Version.VERSION)
	t.append("Bluefin is (c) %s %s. It's made with the software and assets below, under their own licenses." % [
			Version.YEAR, Version.STUDIO])
	t.append("")
	t.append(rule)
	t.append("Godot Engine %s" % Engine.get_version_info()["string"])
	t.append("https://godotengine.org")
	t.append(rule)
	t.append(Engine.get_license_text())
	t.append("")
	t.append(rule)
	t.append("Godot Engine's third-party components")
	t.append(rule)
	for c: Dictionary in Engine.get_copyright_info():
		t.append("")
		t.append("- " + str(c["name"]))
		for p: Dictionary in c["parts"]:
			for line: String in p["copyright"]:
				t.append("    (c) " + line)
			t.append("    License: " + str(p["license"]))
	t.append("")
	t.append(rule)
	t.append("Licenses of the components above, in full")
	t.append(rule)
	var info := Engine.get_license_info()
	var names := info.keys()
	names.sort()
	for n: String in names:
		t.append("")
		t.append("----- " + n + " -----")
		t.append(str(info[n]))
	t.append("")
	t.append(rule)
	t.append("GodotSteam 4.23 (addons/godotsteam) - https://godotsteam.com")
	t.append(rule)
	t.append(FileAccess.get_file_as_string("res://addons/godotsteam/license.md").strip_edges())
	t.append("")
	t.append(rule)
	t.append("Steamworks SDK redistributables (steam_api64.dll)")
	t.append(rule)
	t.append("(c) Valve Corporation. Redistributed under the Steamworks SDK Access Agreement,")
	t.append("https://partner.steamgames.com/documentation/sdk_access_agreement")
	t.append("")
	t.append(rule)
	t.append("Sounds and textures")
	t.append(rule)
	t.append("All public domain (CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/); no notice is required,")
	t.append("they're credited with thanks:")
	t.append("- Kenney (https://kenney.nl): interface and impact sounds.")
	t.append("- BigSoundBank, Joseph Sardin (https://bigsoundbank.com): sea, weather, machinery and deck sounds.")
	t.append("- Poly Haven (https://polyhaven.com): photo textures, crunched down to a few pixels.")
	t.append("The music, the models, the pixel font and everything else are made for the game.")
	t.append("")
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		printerr("third_party: couldn't write ", OUT)
		quit(1)
		return
	f.store_string("\n".join(t))
	f.close()
	print("third_party: wrote ", ProjectSettings.globalize_path(OUT))
	quit()
