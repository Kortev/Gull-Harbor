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
Run: python tools/music_check.py <dir with f.wav and f.json>   (tools/music_check.sh renders and runs it)
     python tools/music_check.py --real <dir>   (a real game's: the movie maker's audio as f.wav, the game run with
     -- --music-log=<dir>/f.json; the grid, clicks and never-quiet checks only)"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
MUSIC = os.path.join(HERE, "..", "music")
sys.path.insert(0, HERE)


# How far into a section it's lined up (s): past the longest fade in (four beats at 112) and the strike's tail.
INTO = 4.0
# Stems not up in the rendered scene (calm, day, a fresh fish): left out of what a switch is lined up against.
REAL = False
# The song's layers that play whatever's happening (a passage is lined up against these alone: the rest come and go).
ALWAYS = {"pad", "bass"}
EXTRAS = {"mark", "rain", "storm", "night", "click", "tension_hi", "tune"}


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
    log = json.load(open(os.path.join(d, "f.json")))
    if "heard" in log:
        print("     the clock's ear: %d ticks heard, put right by %+.1f ms in all" % (int(log["heard"]),
              float(log["put_right"]) * 1000))
    # 1. on time: where each switch (and sting) really started, from the render against its own stems; then each
    # against the clip before it: the gap between them as they said (the movie maker's frames and its sound sit a
    # few ms apart, the same for everything, so it's the gaps that tell)
    real = []
    clips = [float(p[0]) for p in played if p[1].startswith("clip:")]
    for at, what in played:
        kind, name = what.split(":", 1)
        if name == "rest" or kind not in ("clip", "sting") or name not in C:
            real.append((at, what, None))
            continue
        skip = int(round(C[name].get("pre", 0.0) * sr))         # (a sting's silent pre-roll)
        # (against the stems that are up in the scene: the weather's and the fight's extras are down in it)
        files = [f for f, st in zip(C[name]["files"], C[name].get("stems", C[name]["files"]))
                 if (st in ALWAYS if name.startswith("sea_") else st not in EXTRAS)]
        # (a sea passage against its first two bars: they all share the guitar's pattern, and a second of it could
        # line up with the one before)
        span = int((4.0 if name.startswith("sea_") else 1.0) * sr)
        # (a section's lined up from INTO s in, past its fade in and any sting over its start: its grid's the same)
        into = 0 if kind == "sting" else int(INTO * sr)
        # (all of it inside this clip's own time: the next one's crossfade isn't it)
        if kind == "clip":
            life = min([c for c in clips if c > at + 0.01] + [len(mono) / sr]) - at - 0.3
            if life < 2.7:
                print("     %s at %.3f s: too short to line up (%.1f s, its fade in)" % (what, at, life + 0.3))
                continue
            span = max(min(span, int(life * sr)), int(0.5 * sr))
            into = max(min(into, int(life * sr) - span), 0)
        ref = sum(load(f, sr)[skip + into:skip + into + span] for f in files)
        pre = int(0.25 * sr)
        i0 = int(round(at * sr)) + into - pre
        seg = mono[max(i0, 0):i0 + pre + span + int(0.25 * sr)]
        if i0 < 0 or len(seg) < pre + len(ref):
            real.append((at, what, None))
            continue
        c = signal.fftconvolve(seg, ref[::-1], "valid")
        real.append((at, what, (i0 - into + int(np.argmax(np.abs(c)))) / sr))
    # each run of the song from where it last came in from the quiet: every switch's and sting's offset (where it
    # really started, against where it said) against the run's median. A real slip moves everything after it, so
    # it's three clips in a row out the same way; one or two out and the next back (passages whose first seconds
    # don't line up with their stems: a quiet one, the theme's slow swells) is the measuring, not the music. The cues'
    # are the sharp test: they're the clock's own.
    runs, cur = [], []
    for at, what, got in real:
        if what.startswith("clip:rest") or (what.startswith("clip:") and got is not None and not cur):
            if cur:
                runs.append(cur)
            cur = []
        if got is not None:
            cur.append((at, what, got - at))
    if cur:
        runs.append(cur)
    for run in runs:
        med = float(np.median([o for at, what, o in run if what.startswith("clip:")] or [0.0]))
        clips = [(at, what, o - med) for at, what, o in run if what.startswith("clip:")]
        stings = [(at, what, o - med) for at, what, o in run if what.startswith("sting:")]
        out = [abs(e) >= 0.004 for at, what, e in clips]
        for i, (at, what, e) in enumerate(clips):
            slip = out[i] and i + 2 < len(clips) and all(out[j] and (e > 0) == (clips[j][2] > 0) for j in (i + 1, i + 2))
            if out[i] and not slip:
                print("     %s at %.3f s: %+.1f ms, alone (the ones after are back on: the measuring)" % (what, at, e * 1000))
            elif i > 0:
                check(not slip, "%s at %.3f s: %+.1f ms against the song's grid" % (what, at, e * 1000))
        for at, what, e in stings:
            # (a sting's started from the frame: within a mix block, about 10 ms)
            check(abs(e) < 0.012, "%s at %.3f s: %+.1f ms against the song's grid" % (what, at, e * 1000))
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
    # (a real game's recording is the whole mix: a mark where the Effects bus leaps (the game's bus meters, in the
    # log) is a sound effect's edge, the harpoon striking home, not the music's)
    fx = [(float(t), float(b.get("Effects", -200.0))) for t, b in json.load(open(os.path.join(d, "f.json"))).get(
        "buses", [])]
    def fx_leap(t):
        near = [v for u, v in fx if abs(u - t) <= 0.35]
        before = [v for u, v in fx if t - 1.0 <= u < t - 0.35]
        return bool(near) and bool(before) and max(near) - max(before) >= 6.0
    skipped = 0
    for t in list(marks):
        if fx and fx_leap(t):
            marks.remove(t)
            skipped += 1
    if skipped:
        print("     (%d marks left out: a sound effect leaping at the same moment)" % skipped)
    for t in marks:
        i = int(t * sr)
        w = hf[max(i - int(0.05 * sr), 0):i + int(0.05 * sr)]
        if len(w) and float(w.max()) > worst:
            worst, wat = float(w.max()), t
    check(worst <= max(floor * 3.0, 0.0015), "no clicks round %d switches, stings and seams (worst %.4f at %.2f s; the "
          "music's own 99.9%% %.4f)" % (len(marks), worst, wat, floor))
    def win(a, b):
        return mono[int(a * sr):int(b * sr)]
    # (a real game's recording, --real: only what holds for any of it, the quiet times from its own "still" marks)
    hush = []
    if not REAL:
        # 3. the line about to part (24 s on), him in the air (27 s), against his first run (12 s)
        before = rms_db(win(12.0, 16.0))
        part = rms_db(win(24.4, 26.9))
        air = rms_db(win(27.2, 28.5))
        check(part < before - 3.0, "the line about to part: thinner (%.1f dB, before %.1f)" % (part, before))
        check(air < before - 10.0, "him in the air: all but silence (%.1f dB)" % air)
        # 4. lost (96 s): silence, but for the strike's tail that went before it
        lost = rms_db(win(96.3, 101.5))
        check(lost < -60.0, "a fish lost: silence (%.1f dBFS)" % lost)
        # 5. never quiet but where it should be: him in the air (27-28.6 s), the harpoon flying (56-57), the hush
        # after the loss (96-102.5)
        hush = [(26.9, 28.9), (55.9, 57.3), (95.9, 102.6)]
    # (a log with its own "still" marks, as the game writes it: those are the quiet times, and the few s after)
    stills = [float(p[0]) for p in played if p[1] in ("still:on", "still:off")]
    if stills:
        marks_on = [float(p[0]) for p in played if p[1] == "still:on"]
        marks_off = [float(p[0]) for p in played if p[1] == "still:off"]
        hush = []
        for a in marks_on:
            b = min([x for x in marks_off if x > a] + [len(mono) / sr])
            hush.append((a - 0.1, b + 2.5))
    gaps = []
    t = 0.5
    while t + 1.0 < len(mono) / sr - 0.5:
        if not any(a - 1.0 < t < b for a, b in hush) and rms_db(win(t, t + 1.0)) < -45.0:
            gaps.append(round(t, 1))
        t += 0.5
    check(not gaps, "never quiet anywhere else (quiet at: %s)" % gaps[:10])
    scenes = [] if REAL else [(0.5, 3, "sea"), (110, 135, "sea after"), (4, 10, "hunt"), (12, 16, "fight"),
                              (37, 40, "tired"), (42, 50, "leader"), (51, 55, "gaff"), (58, 70, "afterglow")]
    for a, b, what in scenes:
        print("     %-9s %.1f dBFS" % (what, rms_db(win(a, b))))
    print("MUSIC CHECK", "PASSED" if not fails else "FAILED")
    return 1 if fails else 0


if __name__ == "__main__":
    REAL = "--real" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--real"]
    sys.exit(main(args[0] if args else "."))
