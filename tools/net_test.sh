#!/bin/sh
# Two copies on this machine: a host and a client. Both report who's aboard and their sea clock, then quit.
# Passes when the client sees both crew members, the host's conditions, and a sea clock within 0.15 s.
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
timeout 90 $G --headless --path . -- --host --weather=storm --net-report=9 > /tmp/bluefin_host.log 2>&1 &
sleep 2
timeout 90 $G --headless --path . -- --join=127.0.0.1 --weather=calm --net-report=5 > /tmp/bluefin_client.log 2>&1
wait
H=$(grep "^NET" /tmp/bluefin_host.log)
C=$(grep "^NET" /tmp/bluefin_client.log)
echo "host:   $H"
echo "client: $C"
python3 - "$H" "$C" <<'PY'
import re, sys
h, c = sys.argv[1], sys.argv[2]
ok = True
def get(s, k):
    m = re.search(k + r"=(\S+)", s)
    return m.group(1) if m else None
crew = re.search(r"crew=\[(.*?)\]", c)
n = len(crew.group(1).split(",")) if crew and crew.group(1) else 0
if n != 2: print("FAIL client sees %d crew" % n); ok = False
if get(c, "cond") != "storm": print("FAIL client conditions", get(c, "cond")); ok = False
hc = re.search(r"crew=\[(.*?)\]", h)
if not hc or len(hc.group(1).split(",")) != 2: print("FAIL host crew", hc and hc.group(1)); ok = False
skew = abs(float(get(h, "skew")) - float(get(c, "skew"))) if get(h, "skew") and get(c, "skew") else 99
if skew > 0.15: print("FAIL sea clocks apart by %.3f s" % skew); ok = False
else: print("sea clocks %.3f s apart" % skew)
print("NET TEST PASSED" if ok else "NET TEST FAILED")
sys.exit(0 if ok else 1)
PY
