#!/bin/sh
# A release build of Bluefin for Windows, ready to upload to Steam: the third-party notices brought up to date
# (tools/third_party.gd), the exe exported (export_presets.cfg's "Windows": icon, version, company), and the notices put
# beside it in export/. steam_appid.txt is left out of export/ on purpose: Steam starts the game with the right app id
# (and core/steam_link.gd hands steamInitEx its own APP_ID).
# Run from the project root: GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe tools/release.sh
set -e
G="${GODOT:-godot}"
"$G" --headless --path . --script res://tools/third_party.gd
mkdir -p export
"$G" --headless --path . --export-release "Windows" export/Bluefin.exe
cp THIRD_PARTY_NOTICES.txt export/
rm -f export/steam_appid.txt
echo "release: export/ is ready (Bluefin.exe, the GodotSteam and Steam API dlls, THIRD_PARTY_NOTICES.txt)"
