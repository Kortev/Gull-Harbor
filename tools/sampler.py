"""The recorded instruments tools/music.py plays (tools/fetch_samples.py fetches them into tools/samples/: CC0, from
Versilian Studios' VCSL and VSCO 2 Community Edition). Each note is found in the sample nearest it, pitched to it
(read faster or slower), cut to its length with a release; held longer than its sample, the sample's steady middle is
looped round with crossfades. Drums and the like by strength (their velocity layers) and round robin, never the same
take twice running. Everything mono at the synth's rate, its peak at 1, like the synth's own instruments.

The libraries name their notes two ways: VCSL and VSCO's cello and double bass call middle C "C3" (a note sounds an
octave above its name, OCTAVE), VSCO's violin calls it "C4". Measured: every sample within a few cents of its note,
in the octave its instrument really plays."""
import os
import re

import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "samples")
NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def available():
    return os.path.isdir(ROOT)


def _label(name):
    m = re.search(r"(?:^|[_ ])([A-G]#?)(-?\d)(?=[_.])", name)
    return None if not m else 12 * (int(m.group(2)) + 1) + NOTES[m.group(1)]


class Take:
    """One sample: mono at `sr`, from its first sound (a hair before it), its peak at 1."""

    def __init__(self, path, sr, root=None):
        x, fsr = sf.read(path, always_2d=True)
        x = x.mean(axis=1)
        if fsr != sr:
            g = np.gcd(int(fsr), int(sr))
            x = signal.resample_poly(x, sr // g, fsr // g)
        pk = float(np.max(np.abs(x))) or 1.0
        start = max(0, int(np.argmax(np.abs(x) > pk * 0.02)) - int(0.002 * sr))
        x = x[start:]
        self.x = x / pk
        self.root = root
        self.name = os.path.basename(path)


class Kit:
    """An instrument: its takes (from `folder` under ROOT, the files matching `rx`). Pitched (`octave`: how far the
    libraries' names sit under the notes; None: unpitched), sustained (`hold`: loop its middle for long notes) or let
    ring (the take's own decay)."""

    def __init__(self, sr, folder, rx=r"\.wav$", octave=12, hold=False, loud=None):
        self.sr = sr
        self.hold = hold
        self.loud = loud                       # (a regex: the takes of its louder layer)
        self.takes = []
        d = os.path.join(ROOT, *folder.split("/"))
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(".wav") and re.search(rx, f):
                lab = _label(f) if octave is not None else None
                self.takes.append(Take(os.path.join(d, f), sr, None if lab is None else lab + octave))
        assert self.takes, "no samples in %s (python tools/fetch_samples.py)" % d
        self._last = {}
        self._cache = {}

    def _pick(self, m, strength, var):
        takes = self.takes
        if self.loud is not None:
            loud = [t for t in takes if re.search(self.loud, t.name)]
            soft = [t for t in takes if not re.search(self.loud, t.name)]
            takes = (loud if strength >= 0.6 else soft) or takes
        if m is not None:
            best = min(abs(t.root - m) for t in takes)
            takes = [t for t in takes if abs(t.root - m) == best]
        # round robin: a different take from last time when there's one (var picks among them, steadily)
        key = (m, strength >= 0.6)
        i = (var + self._last.get(key, -1) + 1) % len(takes)
        self._last[key] = i
        return takes[i]

    def note(self, m=None, dur=None, strength=1.0, var=0, rel=0.08, speed=1.0):
        """m (a MIDI note; None: as recorded) held `dur` s (None: let it ring out), released over `rel` s; `speed`
        on top (a drum tuned down, read slower). Peak 1."""
        key = (m, None if dur is None else round(dur, 3), round(strength, 2), var, rel, round(speed, 3))
        if key in self._cache:
            return self._cache[key]
        t = self._pick(m, strength, var)
        r = speed * (2.0 ** ((m - t.root) / 12.0) if m is not None and t.root is not None else 1.0)
        src = t.x
        n = int(round((len(src) - 1) / r)) if dur is None else int(round((dur + rel) * self.sr))
        need = n * r + 2
        if need > len(src):
            src = self._longer(src, int(need)) if self.hold else np.concatenate([src, np.zeros(int(need) - len(src))])
        out = np.interp(np.arange(n) * r, np.arange(len(src)), src)
        if dur is not None:
            k = min(n, int(rel * self.sr))
            if k > 0:
                out[n - k:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, k))
        else:
            k = min(n, int(0.05 * self.sr))
            out[n - k:] *= np.linspace(1.0, 0.0, k)
        pk = float(np.max(np.abs(out))) or 1.0
        out = out / pk
        self._cache[key] = out
        return out

    def _longer(self, x, n):
        """A sustained take made `n` samples long: its steady middle (40%-85% of it) looped, 0.25 s crossfades."""
        a, b = int(len(x) * 0.4), int(len(x) * 0.85)
        xf = int(0.25 * self.sr)
        loop = x[a:b]
        out = x[:b].copy()
        fade = np.linspace(0.0, 1.0, xf)
        while len(out) < n:
            tail = out[-xf:] * (1.0 - fade) + loop[:xf] * fade
            out = np.concatenate([out[:-xf], tail, loop[xf:]])
        return out[:n]
