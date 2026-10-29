#!/bin/sh
# Two copies on this machine: a host and a client. Both report who's aboard and their sea clock, then quit.
# Passes when the client sees both crew members, the host's conditions, and a sea clock within 0.15 s; and the
# client takes the wheel and swings her round, and the host sees the same captain and heading. Then a hand-off:
# the host holds a fish on rod 2 and a second friend takes the rod over.
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
timeout 90 $G --headless --path . -- --host --weather=storm --net-report=9 > /tmp/bluefin_host.log 2>&1 &
sleep 2
timeout 90 $G --headless --path . -- --join=3ZJ2-223 --weather=calm --helm --net-report=6 > /tmp/bluefin_client.log 2>&1
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
hcap, ccap = get(h, "captain"), get(c, "captain")
if hcap != get(c, "me") or ccap != hcap: print("FAIL captain: host says", hcap, "client says", ccap); ok = False
hh, ch = float(get(h, "heading") or 0), float(get(c, "heading") or 0)
if ch < 0.2 or abs(hh - ch) > 0.05: print("FAIL heading: host %.2f client %.2f" % (hh, ch)); ok = False
else: print("the client steered her to %.2f rad; the host sees %.2f" % (ch, hh))
print("NET TEST PASSED" if ok else "NET TEST FAILED")
sys.exit(0 if ok else 1)
sys.exit(0 if ok else 1)
PY

timeout 90 $G --headless --path . -- --host --strike=1 --hold=1 --net-report=9 > /tmp/bluefin_host2.log 2>&1 &
sleep 2
timeout 90 $G --headless --path . -- --join=3ZJ2-223 --take=1 --net-report=6 > /tmp/bluefin_client2.log 2>&1
wait
python3 - "$(grep '^NET rods' /tmp/bluefin_host2.log)" "$(grep '^NET fps' /tmp/bluefin_client2.log)" "$(grep '^NET rods' /tmp/bluefin_client2.log)" <<'PY'
import re, sys
host_rods, client, client_rods = sys.argv[1:4]
me = re.search(r"me=(\d+)", client).group(1) if client else "?"
h = host_rods.split("=")[-1].split(",") if host_rods else []
c = client_rods.split("=")[-1].split(",") if client_rods else []
ok = len(h) > 2 and len(c) > 2 and h[2] == me and c[2] == me
print("hand-off: the friend (%s) took over rod 2: host says %s, friend says %s" % (me, h[2:3], c[2:3]))
print("HANDOFF TEST PASSED" if ok else "HANDOFF TEST FAILED")
PY
