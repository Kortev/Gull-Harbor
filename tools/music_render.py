"""The music as it leaves the game's mixer, measured (tools/music_check.sh --render): tests/music_render.tscn plays a
scripted trip to the music (the title, tied up, out there, a strike, the fight's moves, landed, a second strike, lost,
flat out, a storm) under the movie maker, and this reads the recording against the trip's marks ("MARK <s> <what>" in
the game's log):
  - each stretch's loudness second by second (K-weighted, tools/loudness.py);
  - nothing clips, nothing clicks (no sample leaping LEAP);
  - never silent but after a fish lost (and silent then);
  - the fight sits over the song before it, and the strike is a step up from whatever the song was doing.
Run: python tools/music_render.py <recording.wav> <the game's log>"""
import sys

import numpy as np
import soundfile as sf

import loudness as L

LEAP = 0.25
SILENT = -60.0


def main(wav, log):
    x, sr = sf.read(wav, always_2d=True)
    marks = []
    for line in open(log, encoding="utf-8", errors="replace"):
        if line.startswith("MARK "):
            _, s, what = line.split()
            marks.append((float(s), what))
    y, s2 = L.k_weight(x, sr)
    sec = L.lufs(L.blocks(y, s2, 1.0, 1.0))
    mono = x.mean(axis=1)
    at = {w: t for t, w in marks}
    span = {}
    for i, (t, w) in enumerate(marks[:-1]):
        a, b = int(t), int(marks[i + 1][0])
        span[w] = sec[a:b]
        print("%6.1f %-10s %s" % (t, w, " ".join("%3.0f" % v for v in sec[a:b])))
    fails = []

    def check(ok, what):
        print(("ok   " if ok else "FAIL ") + what)
        if not ok:
            fails.append(what)

    check(L.peak_db(x) < -0.9, "nothing clips (the peak %.1f dBFS)" % L.peak_db(x))
    leaps = int(np.sum(np.abs(np.diff(mono)) > LEAP))
    check(leaps == 0, "nothing clicks (%d samples leaping %.2f)" % (leaps, LEAP))
    quiet = [i for i, v in enumerate(sec) if v < SILENT]
    lost = at.get("lost", -1.0)
    stray = [i for i in quiet if not (lost >= 0.0 and lost <= i <= lost + 5.0)]
    check(not stray, "never silent where it's meant to play (%s)" % (stray[:5] or "none"))
    if lost >= 0.0:
        check(any(lost <= i <= lost + 5.0 for i in quiet), "a fish lost: the quiet")
    if "sea" in span and "strike" in span:
        song = float(np.median(span["sea"]))
        fight = float(np.median(np.concatenate([span[k] for k in ("strike", "sound", "circle", "run2") if k in span])))
        check(fight > song + 1.0, "the fight over the song (%.1f LUFS, the song %.1f)" % (fight, song))

    def rms(a, b):
        seg = mono[int(a * sr):int(b * sr)]
        return 20.0 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-9)

    for k in ("strike", "strike2"):
        if k in at:
            t = at[k]
            check(rms(t + 0.05, t + 0.35) > rms(t - 0.6, t - 0.05) + 3.0, "%s: a step up on the hit (%.1f dB after, %.1f before)"
                  % (k, rms(t + 0.05, t + 0.35), rms(t - 0.6, t - 0.05)))
    print("MUSIC RENDER " + ("PASSED" if not fails else "FAILED"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
