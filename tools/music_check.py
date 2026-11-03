"""Listens to what tests/music_render.tscn wrote (the movie maker's .wav of everything heard, and the .json of what
audio/music.gd played when) and checks the music did what it says:
  - every section came in exactly when it said, on its grid: the render, round each switch, lined up against that
    section's own stems summed (a cross-correlation: the lag's how far off it landed; the stems summed only line up
    if they're in step with each other too);
  - the strike's sting the same;
  - no clicks: round every switch, sting and loop seam, nothing jumps sample to sample harder than the music itself
    ever does;
  - the line about to part thins it, him in the air all but stops it;
  - a fish lost: silence.
Run: python tools/music_check.py <dir with f.wav and f.json>   (tools/music_check.sh renders and runs it)"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
MUSIC = os.path.join(HERE, "..", "music")
sys.path.insert(0, HERE)


def cues():
    """audio/music_cues.gd's CUES (it's JSON after the `const CUES :=`)."""
    s = open(os.path.join(HERE, "..", "audio", "music_cues.gd"), encoding="utf-8").read()
    return json.loads(s[s.index("const CUES :=") + len("const CUES :="):])


def load(name, sr):
    x, r = sf.read(os.path.join(MUSIC, name + ".ogg"), always_2d=True)
    x = x.mean(axis=1)
    if r != sr:
        g = np.gcd(int(r), int(sr))
        x = signal.resample_poly(x, sr // g, r // g)
    return x


def rms_db(x):
    return 20 * np.log10(max(1e-9, float(np.sqrt(np.mean(x ** 2)))))


def main(d):
    x, sr = sf.read(os.path.join(d, "f.wav"), always_2d=True)
    mono = x.mean(axis=1)
    played = json.load(open(os.path.join(d, "f.json")))["played"]
    C = cues()
    fails = []

    def check(ok, what):
        print(("ok   " if ok else "FAIL ") + what)
        if not ok:
            fails.append(what)

    print("render: %.1f s at %d Hz, %d things played" % (len(mono) / sr, sr, len(played)))
    # 1. on time: where each switch (and sting) really started, from the render against its own stems; then each
    # against the clip before it: the gap between them as they said (the movie maker's frames and its sound sit a
    # few ms apart, the same for everything, so it's the gaps that tell)
    real = []
    for at, what in played:
        kind, name = what.split(":", 1)
        if name == "rest" or kind not in ("clip", "sting") or name not in C:
            real.append((at, what, None))
            continue
        skip = int(round(C[name].get("pre", 0.0) * sr))         # (a sting's silent pre-roll)
        ref = sum(load(f, sr)[skip:skip + sr] for f in C[name]["files"])
        pre = int(0.25 * sr)
        i0 = int(round(at * sr)) - pre
        seg = mono[max(i0, 0):i0 + pre + int(1.25 * sr)]
        if i0 < 0 or len(seg) < pre + len(ref):
            real.append((at, what, None))
            continue
        c = signal.fftconvolve(seg, ref[::-1], "valid")
        real.append((at, what, (i0 + int(np.argmax(np.abs(c)))) / sr))
    prev = None
    for at, what, got in real:
        if what.startswith("clip:rest"):
            prev = None
            continue
        if got is None:
            continue
        if prev is not None:
            err = (got - prev[2]) - (at - prev[0])
            check(abs(err) < 0.004, "%s at %.3f s: %+.1f ms against %s's grid" % (what, at, err * 1000, prev[1]))
        else:
            print("     %s at %.3f s: from the quiet (no grid; %+.1f ms after it was asked)"
                  % (what, at, (got - at) * 1000))
        if what.startswith("clip:"):
            prev = (at, what, got)
    # 2. clicks: the music's low-passed (8 kHz, tools/music.py), a click isn't: whatever's up past 12 kHz round each
    # switch, sting and loop seam, against the render's own
    b, a = signal.butter(4, 12000 / (sr / 2), "high")
    hf = np.sqrt(signal.lfilter(np.ones(96) / 96, 1, signal.lfilter(b, a, mono) ** 2))
    floor = float(np.percentile(hf, 99.9))
    marks = [float(p[0]) for p in played]
    starts = [(float(p[0]), p[1].split(":", 1)[1]) for p in played if p[1].startswith("clip:")]
    for k, (at, name) in enumerate(starts):
        c = C.get(name, {})
        if not c.get("loop"):
            continue
        end = starts[k + 1][0] if k + 1 < len(starts) else len(mono) / sr
        n = 1
        while at + n * c["length"] < end:
            marks.append(at + n * c["length"])
            n += 1
    worst, wat = 0.0, 0.0
    for t in marks:
        i = int(t * sr)
        w = hf[max(i - int(0.05 * sr), 0):i + int(0.05 * sr)]
        if len(w) and float(w.max()) > worst:
            worst, wat = float(w.max()), t
    check(worst <= max(floor * 3.0, 0.0015), "no clicks round %d switches, stings and seams (worst %.4f at %.2f s; the "
          "music's own 99.9%% %.4f)" % (len(marks), worst, wat, floor))
    # 3. the line about to part (24 s on), him in the air (27 s), against his first run (12 s)
    def win(a, b):
        return mono[int(a * sr):int(b * sr)]
    before = rms_db(win(12.0, 16.0))
    part = rms_db(win(24.4, 26.9))
    air = rms_db(win(27.2, 28.5))
    check(part < before - 3.0, "the line about to part: thinner (%.1f dB, before %.1f)" % (part, before))
    check(air < before - 10.0, "him in the air: all but silence (%.1f dB)" % air)
    # 4. lost (96 s): silence, but for the strike's tail that went before it
    lost = rms_db(win(96.3, 101.5))
    check(lost < -60.0, "a fish lost: silence (%.1f dBFS)" % lost)
    for a, b, what in [(4, 10, "hunt"), (12, 16, "fight"), (37, 40, "tired"), (42, 50, "leader"), (51, 55, "gaff"),
                       (58, 70, "afterglow")]:
        print("     %-9s %.1f dBFS" % (what, rms_db(win(a, b))))
    print("MUSIC CHECK", "PASSED" if not fails else "FAILED")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
