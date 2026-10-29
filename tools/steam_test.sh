#!/bin/sh
# Playing over Steam, with a stand-in for Steam (tests/steam_test.tscn): a host makes a Steam lobby, a client finds
# the host in its Steam friends list and joins. Passes when both see two crew, the host's weather, one sea clock.
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
timeout 90 $G --headless --path . res://tests/steam_test.tscn -- --role=host --weather=storm --net-report=10 > /tmp/bluefin_steam_host.log 2>&1 &
sleep 2
timeout 90 $G --headless --path . res://tests/steam_test.tscn -- --role=join --weather=calm --net-report=7 > /tmp/bluefin_steam_client.log 2>&1
wait
grep "^STEAM" /tmp/bluefin_steam_host.log /tmp/bluefin_steam_client.log
grep -E "SCRIPT ERROR|Parse Error" -A2 /tmp/bluefin_steam_host.log /tmp/bluefin_steam_client.log | head -10
H=$(grep "^NET" /tmp/bluefin_steam_host.log)
C=$(grep "^NET" /tmp/bluefin_steam_client.log)
echo "host:   $H"
echo "client: $C"
python3 - "$H" "$C" <<'PY'
import re, sys
h, c = sys.argv[1], sys.argv[2]
ok = True
def get(s, k):
    m = re.search(k + r"=(\S+)", s)
    return m.group(1) if m else None
for who, s in (("host", h), ("client", c)):
    crew = re.search(r"crew=\[(.*?)\]", s)
    n = len(crew.group(1).split(",")) if crew and crew.group(1) else 0
    if n != 2: print("FAIL %s sees %d crew" % (who, n)); ok = False
if get(c, "cond") != "storm": print("FAIL client weather", get(c, "cond")); ok = False
skew = abs(float(get(h, "skew")) - float(get(c, "skew"))) if get(h, "skew") and get(c, "skew") else 99
if skew > 0.15: print("FAIL sea clocks apart by %.3f s" % skew); ok = False
print("STEAM TEST PASSED" if ok else "STEAM TEST FAILED")
sys.exit(0 if ok else 1)
PY
