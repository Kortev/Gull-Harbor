"""How loud everything is: every sound file in the game, and (given one) a recording of the game itself, measured the
way broadcast and game audio are (ITU BS.1770 / EBU R128: K-weighted loudness, LUFS, gated; and the peak, dBFS).

  - each file: its integrated loudness and its peak, against the others of its kind (its folder): one far louder or
    quieter than its fellows (OFF_BY LU) is called out, and so is a peak near clipping (CLIP dBFS);
  - a recording (the movie maker's .wav of the game: tools/music_check.sh, or the game run with --write-movie): its
    loudness through time (short-term, 3 s), how loud it is overall, how far it ranges, where it jumps (JUMP LU in a
    second: a sound that leaps out, or the mix falling away), and whether the mix ever clips.

The music's stems are measured as the song, not one by one (a layer alone is meant to be quiet): the render's own
loudness per scene is what to look at for the music (music_check prints it), and its stings are files like any other.

  - the game's own bus meters (the game run with -- --music-log=<file>: audio/music.gd writes every bus's peak level
    every quarter second): each bus's level through the trip, the music against the effects (how far under them it
    sits, and whether it ever buries them), the voices and the radio over the music, and where anything hits 0 dB.

Run: python tools/loudness.py [--wav <recording.wav>] [--log <music log .json>] [--md <report.md>]"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SKIP = (".godot", "export", ".claude", "docs", "addons", ".git")
OFF_BY = 6.0
CLIP = -1.0
JUMP = 9.0


def k_weight(x, sr):
    """BS.1770's K-weighting (its 48 kHz filters; anything else resampled to 48 kHz first)."""
    if sr != 48000:
        g = np.gcd(int(sr), 48000)
        x = signal.resample_poly(x, 48000 // g, int(sr) // g, axis=0)
    b1 = [1.53512485958697, -2.69169618940638, 1.19839281085285]
    a1 = [1.0, -1.69065929318241, 0.73248077421585]
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, -1.99004745483398, 0.99007225036621]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0), 48000


def blocks(y, sr, size, step):
    """Each block's mean square, summed over the channels."""
    n = int(size * sr)
    h = int(step * sr)
    if len(y) < n:
        return np.array([np.sum(np.mean(y ** 2, axis=0))]) if len(y) else np.array([0.0])
    out = []
    for i in range(0, len(y) - n + 1, h):
        out.append(np.sum(np.mean(y[i:i + n] ** 2, axis=0)))
    return np.array(out)


def lufs(ms):
    return -0.691 + 10.0 * np.log10(np.maximum(ms, 1e-12))


def integrated(x, sr):
    """Integrated loudness (LUFS): 400 ms blocks, gated at -70 LUFS and then 10 LU under the mean."""
    y, sr = k_weight(x, sr)
    ms = blocks(y, sr, 0.4, 0.1)
    ms = ms[lufs(ms) > -70.0]
    if len(ms) == 0:
        return -np.inf
    rel = lufs(np.mean(ms)) - 10.0
    ms = ms[lufs(ms) > rel]
    return float(lufs(np.mean(ms))) if len(ms) else -np.inf


def peak_db(x):
    return 20.0 * np.log10(max(float(np.max(np.abs(x))), 1e-9))


def files():
    for d, dirs, names in os.walk(ROOT):
        rel = os.path.relpath(d, ROOT).replace("\\", "/")
        if any(rel == s or rel.startswith(s + "/") for s in SKIP):
            dirs[:] = []
            continue
        for n in names:
            if n.lower().endswith((".wav", ".ogg")):
                yield os.path.join(rel, n).replace("\\", "/").lstrip("./")


def kind(path):
    """A file's kind: its folder (music's stems apart from its stings and notes)."""
    d, n = os.path.split(path)
    if d == "music":
        if n.startswith("note_"):
            return "music/whistle notes"
        if "_" in n and n.split("_")[0] in ("sea", "title"):
            return "music/stems (the song: see the render)"
        return "music/stings"
    return d or "."


def audit_files(out):
    rows = []
    for f in sorted(files()):
        try:
            x, sr = sf.read(os.path.join(ROOT, f), always_2d=True)
        except Exception as e:
            out.append("  ?? %s: %s" % (f, e))
            continue
        rows.append((kind(f), f, integrated(x, sr), peak_db(x), len(x) / sr))
    groups = {}
    for k, f, l, p, d in rows:
        groups.setdefault(k, []).append((f, l, p, d))
    flags = []
    out.append("## Every sound file, by kind (integrated loudness LUFS, peak dBFS, length)")
    for k in sorted(groups):
        g = groups[k]
        ls = [l for f, l, p, d in g if np.isfinite(l)]
        med = float(np.median(ls)) if ls else -np.inf
        out.append("")
        out.append("### %s: %d files, median %.1f LUFS" % (k, len(g), med))
        stems = k.startswith("music/stems")
        for f, l, p, d in sorted(g, key=lambda r: -r[1] if np.isfinite(r[1]) else 99):
            mark = ""
            if not stems and np.isfinite(l) and abs(l - med) > OFF_BY:
                mark += "  <- %+.1f LU off its kind" % (l - med)
                flags.append("%s is %+.1f LU off the rest of %s (%.1f LUFS against %.1f)" % (f, l - med, k, l, med))
            if p > CLIP:
                mark += "  <- peak %.1f dBFS" % p
                flags.append("%s peaks at %.1f dBFS: near clipping" % (f, p))
            if not np.isfinite(l):
                mark += "  <- silent"
                if not stems:
                    flags.append("%s is silent" % f)
            if not stems or mark:
                out.append("  %7s LUFS  %6.1f dBFS  %5.1f s  %s%s" % ("-inf" if not np.isfinite(l) else "%.1f" % l, p, d,
                                                                   f, mark))
        if stems:
            out.append("  (%d stems, levels set by the game as it plays: only their peaks are checked)" % len(g))
    return flags


def audit_recording(path, out):
    x, sr = sf.read(path, always_2d=True)
    y, ksr = k_weight(x, sr)
    st = lufs(blocks(y, ksr, 3.0, 1.0))           # short-term: 3 s, every second
    mom = lufs(blocks(y, ksr, 0.4, 0.1))          # momentary: 400 ms
    flags = []
    out.append("")
    out.append("## The recording: %s (%.0f s)" % (os.path.basename(path), len(x) / sr))
    il = integrated(x, sr)
    live = st[st > -60.0]
    out.append("  integrated %.1f LUFS; short-term from %.1f to %.1f (10th to 90th percentile %.1f to %.1f); peak %.1f dBFS"
               % (il, float(np.min(live)) if len(live) else -np.inf, float(np.max(st)),
                  float(np.percentile(live, 10)) if len(live) else -np.inf,
                  float(np.percentile(live, 90)) if len(live) else -np.inf, peak_db(x)))
    if peak_db(x) > CLIP:
        flags.append("the mix peaks at %.1f dBFS: it can clip" % peak_db(x))
    # jumps: the momentary loudness a second on against a second before
    jumps = []
    for i in range(10, len(mom) - 10):
        a, b = mom[i - 10], mom[i + 10]
        if a > -50.0 and b > -50.0 and abs(b - a) >= JUMP:
            t = i * 0.1
            if not jumps or t - jumps[-1][0] > 3.0:
                jumps.append((t, b - a))
    out.append("  jumps of %.0f LU or more in two seconds: %d" % (JUMP, len(jumps)))
    for t, dl in jumps[:30]:
        out.append("    %6.1f s  %+.1f LU" % (t, dl))
    if len(jumps) > len(x) / sr / 30.0:
        flags.append("the recording jumps by %.0f LU or more %d times (more than one every 30 s)" % (JUMP, len(jumps)))
    # the timeline: a line every 30 s
    out.append("  short-term loudness, every 30 s:")
    for i in range(0, len(st), 30):
        out.append("    %5d s  %6.1f LUFS  %s" % (i, st[i], "#" * max(0, int((st[i] + 50.0) / 2.0))))
    return flags


def audit_buses(path, out):
    """The game's own meters: each bus's peak (dBFS) every quarter second."""
    log = json.load(open(path))
    rows = log.get("buses", [])
    flags = []
    out.append("")
    out.append("## The game's buses (%s: %d readings)" % (os.path.basename(path), len(rows)))
    if not rows:
        out.append("  (no bus meters in the log)")
        return flags
    names = sorted({k for t, b in rows for k in b})
    out.append("  %-12s %8s %8s %8s %8s   (peak dBFS while it's making a sound: 10th, median, 90th, loudest)"
               % ("bus", "p10", "median", "p90", "max"))
    live = {}
    for n in names:
        v = np.array([b.get(n, -200.0) for t, b in rows])
        on = v[v > -60.0]
        live[n] = v
        if len(on) == 0:
            out.append("  %-12s   (silent)" % n)
            continue
        out.append("  %-12s %8.1f %8.1f %8.1f %8.1f   %3.0f%% of the time" % (n, np.percentile(on, 10), np.median(on),
                   np.percentile(on, 90), np.max(on), 100.0 * len(on) / len(v)))
        hot = int(np.sum(v > -0.3))
        if hot:
            flags.append("the %s bus hits 0 dB %d times (%.0f s of the trip)" % (n, hot, hot * 0.25))
    if "Music" in live and "Effects" in live:
        m, fx = live["Music"], live["Effects"]
        both = (m > -60.0) & (fx > -60.0)
        if np.any(both):
            gap = m[both] - fx[both]
            out.append("  the music against the effects: median %+.1f dB (90th %+.1f): %s" % (
                np.median(gap), np.percentile(gap, 90),
                "under them" if np.median(gap) < 0 else "over them"))
            if np.percentile(gap, 90) > 3.0:
                flags.append("the music is over the effects by more than 3 dB a tenth of the time (it can bury them)")
    for v in ("Voice", "Radio", "VoiceRadio"):
        if v in live and "Music" in live:
            talk = live[v] > -42.0
            if np.any(talk):
                out.append("  while %s is on (%.0f s): the music's median peak %.1f dB, against %.1f the rest of the time"
                           % (v, np.sum(talk) * 0.25, np.median(live["Music"][talk]), np.median(live["Music"][~talk])))
    return flags


def main():
    args = sys.argv[1:]
    out = ["# Loudness: everything (tools/loudness.py)", ""]
    flags = audit_files(out)
    if "--wav" in args:
        flags += audit_recording(args[args.index("--wav") + 1], out)
    if "--log" in args:
        flags += audit_buses(args[args.index("--log") + 1], out)
    out.insert(2, "## What stands out (%d)" % len(flags))
    for i, f in enumerate(flags):
        out.insert(3 + i, "  - " + f)
    out.insert(3 + len(flags), "")
    text = "\n".join(out)
    if "--md" in args:
        with open(args[args.index("--md") + 1], "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
