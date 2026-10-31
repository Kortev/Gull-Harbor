"""Bluefin's music, made here from nothing but sums of sines and a little noise (no samples), and written to
../music/*.ogg for audio/music.gd to play on the Music bus.

The sound: a lo-fi folk band in a fish shed. Plucked guitar and ukulele (each harmonic decaying on its own, faster
the higher it is, with a pick's scratch), an upright-ish plucked bass, a tin whistle, a concertina (two reeds a hair
apart), soft pads, a frame drum and a shaker. All of it through a warm room (a made-up reverb tail), a touch of tape
wow, a gentle saturation and a low-pass round 8 kHz: warm and a bit worn, never chiptune-bright.

The cues (audio/music.gd picks between them):
  title          the title theme, a 6/8 shanty in D, 32 bars, loops
  calm_1..4      calm at sea: short low phrases (one-shots), the game leaves long silences between them
  fish_on        a tense pulse in B minor, 16 bars of 4/4, loops; layered in while a fish is on
  race_a/b/c     the race home at dusk: a driving 6/8 jig in D dorian, three stems the same length played together
                 (a: the rhythm, b: the tune, c: the urgency), brought in as the time runs out; loop
  countdown      Rivals' countdown: COUNT (10) s building to the hit on GO, then its tail
  win, lose, tie the results card's stamp

Loops are made round: every note's tail and the reverb's wrap past the end back to the start, and the filters run
over the loop twice and keep the second time through, so the end runs into the start with no seam.

Run: python tools/music.py   (numpy, scipy, soundfile; about a minute). Writes ../music/<cue>.ogg."""
import os

import numpy as np
import soundfile as sf
from scipy import signal

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "music")
RNG = np.random.default_rng(1977)


def hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def _lp(x, cut, order=2):
    b, a = signal.butter(order, cut / (SR * 0.5), "low")
    return signal.lfilter(b, a, x, axis=-1)


def _hp(x, cut, order=2):
    b, a = signal.butter(order, cut / (SR * 0.5), "high")
    return signal.lfilter(b, a, x, axis=-1)


def _bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR * 0.5), hi / (SR * 0.5)], "band")
    return signal.lfilter(b, a, x, axis=-1)


def _peak(x):
    p = float(np.max(np.abs(x)))
    return x / p if p > 1e-9 else x


# --- the instruments (each returns a mono signal, its peak at 1) ---------------------------------------------------

_cache = {}


def pluck(m, dur, bright=0.5, pos=0.2, decay=1.4, mute=0.0, var=0):
    """A plucked string: harmonics from where it's plucked (pos), each its own decay, a pick's scratch."""
    key = (m, round(dur, 3), bright, pos, decay, mute, var)
    if key in _cache:
        return _cache[key]
    f = hz(m)
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    rng = np.random.default_rng(int(m * 31 + var * 7))
    kmax = max(1, min(28, int(SR * 0.42 / f)))
    for k in range(1, kmax + 1):
        fk = f * k * np.sqrt(1.0 + 0.00012 * k * k)
        a = abs(np.sin(np.pi * k * pos)) / k ** (1.75 - 0.9 * bright)
        tau = decay * (1.0 - 0.85 * mute) / (1.0 + (k - 1) ** 1.35 * (0.4 - 0.3 * bright))
        out += a * np.sin(2 * np.pi * fk * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t / tau)
    nb = min(n, int(0.014 * SR))
    scratch = rng.standard_normal(nb) * np.exp(-np.arange(nb) / (0.0035 * SR))
    out = _peak(out)
    out[:nb] += _bp(scratch, 1400, 5200) * 0.35 * (0.3 + bright)
    out *= np.minimum(1.0, t / 0.0025)
    rel = min(n, int(0.04 * SR))
    out[n - rel:] *= np.linspace(1.0, 0.0, rel)
    out = _peak(out)
    _cache[key] = out
    return out


def pad(ms, dur, attack=1.5, release=2.0, bright=0.3, seed=0):
    """A soft pad: each note three voices a few cents apart (left, middle, right), triangle-ish, a slow shimmer."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    lr = np.zeros((2, n))
    rng = np.random.default_rng(seed + 5)
    for m in ms:
        f = hz(m)
        for j, cents in enumerate((-7.0, 0.0, 7.0)):
            fd = f * 2.0 ** (cents / 1200.0)
            v = np.zeros(n)
            for k in range(1, 7):
                if fd * k > 4500:
                    break
                v += np.sin(2 * np.pi * fd * k * t + rng.uniform(0, 6.3)) / k ** (2.3 - bright)
            v *= 1.0 + 0.18 * np.sin(2 * np.pi * (0.17 + 0.06 * j) * t + rng.uniform(0, 6.3))
            if j == 0:
                lr[0] += v
            elif j == 2:
                lr[1] += v
            else:
                lr += v * 0.7
    env = np.ones(n)
    a = int(attack * SR)
    env[:a] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    d = int(dur * SR)
    env[d:] = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n - d))
    return _peak(lr * env)


def whistle(m, dur, vib=0.004, breath=0.05):
    """A tin whistle: nearly a sine, scooped up into the note, vibrato coming in late, breath round it."""
    rel = 0.08
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    f = hz(m) * 2.0 ** (-28.0 / 1200.0 * np.exp(-t / 0.025))
    f = f * (1.0 + vib * np.sin(2 * np.pi * 5.3 * t) * np.clip((t - 0.2) / 0.35, 0.0, 1.0))
    ph = np.cumsum(2 * np.pi * f / SR)
    v = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.035 * np.sin(3 * ph)
    env = np.minimum(1.0, t / 0.03)
    d = int(dur * SR)
    env[d:] *= np.linspace(1.0, 0.0, n - d)
    noise = _bp(RNG.standard_normal(n), 1800, 6500) * breath
    noise *= np.exp(-t / 0.08) * 2.0 + 0.6
    return _peak((v + noise) * env)


def reed(m, dur, attack=0.06, release=0.12, swell=0.15):
    """A concertina: two reeds a few cents apart, bright-ish harmonics softened, the bellows' swell."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    v = np.zeros(n)
    for cents in (0.0, 5.0):
        f = hz(m) * 2.0 ** (cents / 1200.0)
        ph = 2 * np.pi * f * t + RNG.uniform(0, 6.3)
        for k in range(1, 11):
            if f * k > 5500:
                break
            v += np.sin(k * ph) / k * (0.55 if k % 2 == 0 else 1.0)
    v = _lp(v, 2600)
    env = np.minimum(1.0, t / attack) * (1.0 + swell * np.sin(np.pi * np.clip(t / max(dur, 0.01), 0, 1)))
    d = int(dur * SR)
    env[d:] *= np.linspace(1.0, 0.0, n - d)
    return _peak(v * env)


def frame_drum(strength=1.0):
    """A bodhran: a low skin dropping in pitch, the slap of the hand."""
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    f = 54.0 + 46.0 * np.exp(-t / 0.028)
    body = np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t / 0.2)
    slap = _lp(RNG.standard_normal(n) * np.exp(-t / 0.01), 1700) * 0.5
    return _peak(body + slap) * strength


def heartbeat(strength=1.0):
    """A soft low thump, no slap (the fight's pulse)."""
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 46.0 + 50.0 * np.exp(-t / 0.02)
    body = np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t / 0.14) * np.minimum(1.0, t / 0.002)
    return _peak(body) * strength


def shaker(strength=1.0):
    n = int(0.1 * SR)
    t = np.arange(n) / SR
    env = np.minimum(1.0, t / 0.012) * np.exp(-t / 0.035)
    return _peak(_bp(RNG.standard_normal(n), 4200, 9500) * env) * strength


def woodblock(strength=1.0, f=880.0):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    v = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.48 * t)) * np.exp(-t / 0.028)
    return _peak(v * np.minimum(1.0, t / 0.001)) * strength


def swell_noise(dur, strength=1.0):
    """Air rising: filtered noise growing to a peak at the end (into the countdown's hit)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    v = _bp(RNG.standard_normal(n), 2500, 8000) * (t / dur) ** 3
    return v / max(1e-9, np.max(np.abs(v))) * strength


# --- a track: where the notes go -----------------------------------------------------------------------------------


class Track:
    def __init__(self, seconds, loop):
        self.loop = loop
        self.n = int(round(seconds * SR))
        self.buf = np.zeros((2, self.n if loop else self.n + 5 * SR))

    def add(self, sig, t, pan=0.0, gain=1.0):
        if sig.ndim == 1:
            a = (pan + 1.0) * np.pi / 4.0
            sig = np.vstack([sig * np.cos(a), sig * np.sin(a)]) * np.sqrt(2.0)
        sig = sig * gain
        m = sig.shape[1]
        i = int(round(t * SR))
        if not self.loop:
            if i >= self.buf.shape[1]:
                return
            k = min(m, self.buf.shape[1] - i)
            self.buf[:, i:i + k] += sig[:, :k]
            return
        pos = i % self.n
        off = 0
        while off < m:
            k = min(m - off, self.n - pos)
            self.buf[:, pos:pos + k] += sig[:, off:off + k]
            off += k
            pos = (pos + k) % self.n

    def strum(self, chord, t, down=True, spread=0.016, dur=1.2, gain=1.0, pan=-0.2, **kw):
        notes = chord if down else list(reversed(chord))
        g = gain / np.sqrt(len(notes))
        for i, m in enumerate(notes):
            self.add(pluck(m, dur, var=i % 3, **kw), t + i * spread, pan + 0.03 * i, g * (1.0 - 0.04 * i))


def _circ(fn, x, loop):
    """A filter run round a loop: twice through, the second kept (no seam where the end meets the start)."""
    if not loop:
        return fn(x)
    n = x.shape[-1]
    return fn(np.concatenate([x, x], axis=-1))[..., n:]


def _ir(rt, seconds=2.6, bright=4500.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    pre = int(0.018 * SR)
    ir = np.zeros((2, n))
    for c in range(2):
        noise = _lp(np.random.default_rng(40 + c).standard_normal(n), bright)
        ir[c] = noise * np.exp(-6.9 * t / rt)
        ir[c, :pre] = 0.0
        ir[c, pre:] = ir[c, :n - pre].copy()
    return ir / np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))


def master(tr, wet=0.22, rt=1.8, wow=0.0012, lp=8000.0, drive=1.6):
    """The room, the tape and the warmth over a whole track; returns (2, n)."""
    x = tr.buf.copy()
    n = x.shape[1]
    ir = _ir(rt)
    send = np.vstack([x[0] + 0.3 * x[1], x[1] + 0.3 * x[0]])
    if tr.loop:
        w = np.fft.irfft(np.fft.rfft(send, axis=1) * np.fft.rfft(ir, n=n, axis=1), n=n, axis=1)
    else:
        w = signal.fftconvolve(send, ir, axes=1)[:, :n]
    x = x + w * wet * 3.0
    # the tape: a slow wow, a whole number of times round a loop
    if wow > 0.0:
        secs = n / SR
        k = max(1, round(secs / 3.1))
        d = wow * n / (2 * np.pi * k) * np.sin(2 * np.pi * k * np.arange(n) / n)
        idx = np.arange(n) + d
        if tr.loop:
            idx = np.mod(idx, n)
            i0 = np.floor(idx).astype(int)
            fr = idx - i0
            i1 = (i0 + 1) % n
        else:
            idx = np.clip(idx, 0, n - 1.001)
            i0 = np.floor(idx).astype(int)
            fr = idx - i0
            i1 = i0 + 1
        x = x[:, i0] * (1 - fr) + x[:, i1] * fr
    x = _circ(lambda v: _hp(_lp(v, lp), 35.0), x, tr.loop)
    x = x / max(1e-9, np.max(np.abs(x)))
    x = np.tanh(drive * x) / np.tanh(drive)
    if not tr.loop:
        # trim the silence after the tail, fade the last of it
        e = np.max(np.abs(x), axis=0)
        last = int(np.nonzero(e > 10 ** (-66 / 20))[0][-1]) if np.any(e > 10 ** (-66 / 20)) else n - 1
        x = x[:, :min(n, last + int(0.1 * SR))]
        f = min(x.shape[1], int(0.25 * SR))
        x[:, -f:] *= np.linspace(1.0, 0.0, f)
    return x


def write(name, x, level=0.0):
    """To ../music/<name>.ogg, its peak at `level` (0: as it is). In short blocks: libsndfile's Vorbis encoder
    overflows the stack given a long one at once."""
    os.makedirs(OUT, exist_ok=True)
    if level > 0.0:
        x = x / max(1e-9, np.max(np.abs(x))) * level
    path = os.path.join(OUT, name + ".ogg")
    data = np.ascontiguousarray(x.T.astype(np.float32))
    with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=0.62) as f:
        for i in range(0, data.shape[0], 4096):
            f.write(data[i:i + 4096])
    print("%-10s %5.1f s  %4d KB" % (name, x.shape[1] / SR, os.path.getsize(path) // 1024))


# --- chords (guitar voicings, lowest first) ------------------------------------------------------------------------

CH = {
    "D": [50, 57, 62, 66, 69], "G": [43, 47, 50, 55, 59, 67], "A": [45, 52, 57, 61, 64],
    "Bm": [47, 54, 59, 62, 66], "Em": [40, 47, 52, 55, 59, 64], "F#": [42, 49, 54, 58, 61],
    "Dm": [50, 57, 62, 65, 69], "C": [48, 52, 55, 60, 64], "Am": [45, 52, 57, 60, 64],
    "F": [41, 48, 53, 57, 60, 65], "Dsus": [50, 57, 62, 67, 69], "Asus": [45, 52, 57, 62, 64],
    "Gadd9": [43, 50, 57, 59, 62],
}
# pads (a little higher, fewer notes)
PAD = {
    "D": [50, 57, 62, 66], "G": [43, 55, 59, 62], "A": [45, 57, 61, 64], "Bm": [47, 54, 59, 62],
    "Em": [40, 55, 59, 64], "F#": [42, 54, 58, 61], "Dm": [50, 57, 62, 65], "C": [48, 55, 60, 64],
    "Am": [45, 57, 60, 64], "F": [41, 53, 57, 60], "Dsus": [50, 57, 62, 67], "Asus": [45, 57, 62, 64],
    "Gadd9": [43, 55, 57, 62],
}
REST = None


def melody(tr, notes, t0, step, inst, pan=0.1, gain=1.0, legato=0.95, octave=0):
    """notes: [(midi or None, eighths), ...] from t0, `step` s an eighth."""
    t = t0
    for m, ln in notes:
        if m is not None:
            d = ln * step * legato
            tr.add(inst(m + 12 * octave, d), t, pan, gain)
        t += ln * step
    return t


# --- TITLE: 6/8 in D, dotted quarter 66 ----------------------------------------------------------------------------

def title():
    e = 60.0 / (66 * 3)                    # an eighth (s)
    bar = 6 * e
    prog = (["D", "G", "D", "A"]
            + ["D", "D", "G", "D", "Bm", "G", "A", "D"]
            + ["G", "D", "A", "Bm", "G", "D", "A", "A"]
            + ["D", "D", "G", "D", "Bm", "G", "A", "D"]
            + ["D", "G", "Em", "A"])
    tr = Track(len(prog) * bar, True)
    arp = [0, 2, 3, 4, 3, 2]
    for b, c in enumerate(prog):
        t = b * bar
        v = CH[c]
        # the guitar picking, the bass under it
        for i, j in enumerate(arp):
            m = v[min(j, len(v) - 1)]
            tr.add(pluck(m, 1.6, bright=0.45, decay=1.3, var=i % 3), t + i * e + RNG.uniform(0, 0.008), -0.25,
                   0.32 if i else 0.4)
        root = v[0] - 12 if v[0] >= 45 else v[0]
        tr.add(pluck(root, 1.4, bright=0.15, pos=0.3, decay=1.2), t, 0.0, 0.55)
        tr.add(pluck(root + 7, 1.0, bright=0.15, pos=0.3, decay=1.0), t + 3 * e, 0.0, 0.4)
        # the pad, a bar at a time
        tr.add(pad(PAD[c], bar, attack=0.5, release=0.9, seed=b), t, 0.0, 0.16)
        # the sway: ukulele chops on 2 and 5, from the first tune on
        if 4 <= b < 28:
            for k in (1, 4):
                tr.strum([x + 12 for x in v[-3:]], t + k * e, down=(k == 1), spread=0.008, dur=0.22, gain=0.22,
                         pan=0.35, bright=0.7, pos=0.25, decay=0.5, mute=0.6)
        # the drum and the shaker, from the second half
        if 12 <= b < 29:
            tr.add(frame_drum(), t, 0.0, 0.5)
            tr.add(frame_drum(), t + 3 * e, 0.0, 0.32)
            if b % 2 == 1:
                tr.add(frame_drum(), t + 5 * e, 0.0, 0.18)
        if 4 <= b < 29:
            for i in range(6):
                tr.add(shaker(), t + i * e, 0.4, 0.12 if i in (0, 3) else 0.07)
    A = [(69, 2), (69, 1), (74, 3), (73, 2), (71, 1), (69, 3), (71, 2), (71, 1), (67, 2), (66, 1),
         (64, 2), (66, 1), (62, 3), (66, 2), (66, 1), (71, 3), (69, 2), (67, 1), (66, 2), (64, 1),
         (64, 2), (66, 1), (67, 2), (69, 1), (66, 1), (64, 1), (62, 4)]
    B = [(71, 2), (74, 1), (74, 2), (71, 1), (69, 2), (66, 1), (69, 3), (73, 2), (76, 1), (76, 2), (73, 1),
         (74, 2), (73, 1), (71, 3), (71, 2), (69, 1), (67, 2), (71, 1), (69, 2), (66, 1), (62, 2), (66, 1),
         (64, 2), (69, 1), (73, 2), (71, 1), (69, 6)]
    melody(tr, A, 4 * bar, e, whistle, 0.1, 0.5, octave=1)
    melody(tr, B, 12 * bar, e, reed, -0.1, 0.42)
    melody(tr, A, 20 * bar, e, whistle, 0.1, 0.5, octave=1)
    # the concertina under the tune the second time: long chord tones
    for b, m in enumerate([66, 66, 62, 66, 62, 62, 61, 62]):
        tr.add(reed(m, bar * 0.95, attack=0.2), (20 + b) * bar, -0.2, 0.2)
    # the tag in the last bar, leading round to the top
    melody(tr, [(None, 3), (69, 1), (71, 1), (73, 1)], 31 * bar, e, whistle, 0.1, 0.3, octave=1)
    write("title", master(tr, wet=0.24), 0.82)


# --- CALM AT SEA: four low phrases, one-shots ----------------------------------------------------------------------

def calm():
    # 1: a pad swell, slow low picking (Dmaj9, Gmaj7, back)
    tr = Track(26.0, False)
    tr.add(pad([50, 57, 64, 66], 8.0, attack=3.5, release=2.5, seed=1), 0.0, 0.0, 0.5)
    tr.add(pad([43, 54, 59, 62], 6.0, attack=2.5, release=2.5, seed=2), 8.0, 0.0, 0.45)
    tr.add(pad([50, 57, 61, 64], 6.0, attack=2.5, release=4.0, seed=3), 14.0, 0.0, 0.45)
    for t, m in [(1.0, 50), (2.3, 57), (3.5, 64), (5.0, 66), (8.0, 43), (9.1, 50), (10.3, 54), (11.8, 59),
                 (14.2, 57), (15.6, 61), (17.0, 64), (19.0, 50)]:
        tr.add(pluck(m, 3.5, bright=0.3, decay=2.2), t, -0.2, 0.55)
    write("calm_1", master(tr, wet=0.32, rt=2.4), 0.5)
    # 2: the title's tune, slowed right down, low on the guitar; the bass a long note under it
    tr = Track(24.0, False)
    tr.add(pad([47, 54, 57, 62], 9.0, attack=3.0, release=3.0, seed=4), 0.0, 0.0, 0.35)
    tr.add(pad([43, 50, 55, 59], 8.0, attack=3.0, release=4.0, seed=5), 9.0, 0.0, 0.35)
    tr.add(pluck(35, 6.0, bright=0.1, pos=0.3, decay=3.0), 0.5, 0.0, 0.45)
    tr.add(pluck(31, 6.0, bright=0.1, pos=0.3, decay=3.0), 9.0, 0.0, 0.45)
    t = 1.5
    for m, ln in [(57, 1.0), (57, 0.6), (62, 2.2), (61, 1.0), (59, 0.6), (57, 2.6), (59, 1.0), (59, 0.6),
                  (55, 1.2), (54, 0.8), (52, 1.2), (54, 0.8), (50, 3.0)]:
        tr.add(pluck(m, 3.0, bright=0.35, decay=1.8), t, -0.1, 0.6)
        t += ln
    write("calm_2", master(tr, wet=0.32, rt=2.4), 0.5)
    # 3: a far-off concertina drone moving down, a few light answers on the ukulele
    tr = Track(26.0, False)
    for t, ms, d in [(0.0, [50, 57], 6.0), (6.0, [48, 55], 5.0), (11.0, [47, 54], 5.0), (16.0, [45, 52], 6.0)]:
        for m in ms:
            tr.add(reed(m, d, attack=1.6, release=1.8, swell=0.3), t, -0.15, 0.22)
    tr.add(pad([50, 57, 62], 21.0, attack=4.0, release=4.0, seed=6), 0.0, 0.0, 0.25)
    for t, m in [(3.0, 69), (4.2, 66), (9.0, 67), (10.0, 64), (14.0, 66), (15.0, 62), (19.5, 64), (21.0, 62)]:
        tr.add(pluck(m, 2.5, bright=0.5, pos=0.25, decay=1.3), t, 0.35, 0.32)
    write("calm_3", master(tr, wet=0.34, rt=2.6), 0.45)
    # 4: slow rolled chords (Em9, A7sus, D), a last low note
    tr = Track(22.0, False)
    for t, c in [(0.5, [40, 47, 54, 55, 62]), (5.5, [45, 52, 55, 62, 64]), (10.5, [50, 57, 61, 64, 66])]:
        tr.strum(c, t, spread=0.09, dur=4.5, gain=0.9, pan=-0.15, bright=0.3, decay=2.4)
        tr.add(pad(c[1:], 4.6, attack=2.0, release=2.5, seed=int(t)), t, 0.0, 0.25)
    tr.add(pluck(38, 5.0, bright=0.15, pos=0.3, decay=3.0), 15.5, 0.0, 0.5)
    tr.add(pluck(57, 4.0, bright=0.3, decay=2.2), 16.2, -0.2, 0.35)
    write("calm_4", master(tr, wet=0.34, rt=2.6), 0.45)


# --- FISH ON: B minor, 4/4 at 112, 16 bars ------------------------------------------------------------------------

def fish_on():
    q = 60.0 / 112
    e = q / 2
    s = q / 4
    bar = 4 * q
    prog = ["Bm", "Bm", "G", "G", "Em", "Em", "F#", "F#"] * 2
    roots = {"Bm": 35, "G": 31, "Em": 28, "F#": 30}
    tr = Track(len(prog) * bar, True)
    for b, c in enumerate(prog):
        t = b * bar
        r = roots[c] + 12
        # the bass ostinato, palm-muted eighths, the last one up a step to the next
        for i in range(8):
            m = r + (12 if i in (3, 6) else 0)
            tr.add(pluck(m, 0.3, bright=0.2, pos=0.25, decay=0.9, mute=0.55, var=i % 3), t + i * e, -0.05,
                   0.5 if i % 2 == 0 else 0.38)
        # the pulse: lub-dub on 1, again on 3 (softer)
        tr.add(heartbeat(), t, 0.0, 0.75)
        tr.add(heartbeat(), t + 0.17, 0.0, 0.5)
        tr.add(heartbeat(), t + 2 * q, 0.0, 0.45)
        tr.add(heartbeat(), t + 2 * q + 0.17, 0.0, 0.3)
        # the shaker, sixteenths, leaning on the off-beats
        for i in range(16):
            tr.add(shaker(), t + i * s, 0.45, 0.1 if i % 4 == 2 else 0.05)
        # a dark pad under it all
        tr.add(pad([x - 12 if x > 60 else x for x in PAD[c]], bar, attack=0.6, release=0.8, bright=0.2, seed=b),
               t, 0.0, 0.2)
        # the tremolo: one ukulele note picked fast and quiet, a tension note over each chord
        tn = {"Bm": 73, "G": 71, "Em": 71, "F#": 70}[c]
        for i in range(16):
            tr.add(pluck(tn, 0.2, bright=0.6, pos=0.22, decay=0.4, mute=0.4, var=i % 3), t + i * s, 0.4,
                   0.11 + 0.05 * (i % 4 == 0))
    # the second time round, a concertina line climbing over it
    line = [(66, 2), (67, 2), (64, 2), (66, 1), (70, 1)]
    for k, (m, ln) in enumerate(line):
        at = 8 + sum(x[1] for x in line[:k])
        tr.add(reed(m, ln * bar * 0.96, attack=0.4, swell=0.35), at * bar, -0.25, 0.26)
    write("fish_on", master(tr, wet=0.2, rt=1.5), 0.62)


# --- THE RACE HOME: a 6/8 jig in D dorian, dotted quarter 104, 32 bars, three stems -----------------------------

def race():
    e = 60.0 / (104 * 3)
    bar = 6 * e
    half = ["Dm", "Dm", "C", "C", "Dm", "Dm", "Am", "Dm", "F", "C", "Dm", "Am", "F", "C", "Am", "Dm"]
    prog = half * 2
    secs = len(prog) * bar
    a, b, c = Track(secs, True), Track(secs, True), Track(secs, True)
    pat = [(0, True, 1.0), (2, False, 0.55), (3, True, 0.85), (5, False, 0.55)]
    for i, ch in enumerate(prog):
        t = i * bar
        v = CH[ch]
        # a: the strum and the bass and the drum
        for k, down, g in pat:
            a.strum(v, t + k * e, down=down, spread=0.011, dur=0.5, gain=0.6 * g, pan=-0.2, bright=0.5,
                    decay=0.7, mute=0.35)
        root = v[0] - 12 if v[0] >= 45 else v[0]
        a.add(pluck(root, 0.6, bright=0.15, pos=0.3, decay=0.9), t, 0.0, 0.6)
        a.add(pluck(root + 7, 0.5, bright=0.15, pos=0.3, decay=0.8), t + 3 * e, 0.0, 0.45)
        a.add(frame_drum(), t, 0.0, 0.55)
        a.add(frame_drum(), t + 3 * e, 0.0, 0.4)
        a.add(frame_drum(), t + 5 * e, 0.0, 0.16)
        # c: the urgency: the drum rolling every eighth, the shaker, a low drone pulse, the ukulele's tremolo
        for k in range(6):
            c.add(frame_drum(), t + k * e, 0.0, 0.2 + (0.12 if k in (0, 3) else 0.0))
            c.add(shaker(), t + k * e, 0.45, 0.13 if k in (0, 3) else 0.08)
            c.add(shaker(), t + (k + 0.5) * e, 0.45, 0.045)
        c.add(reed(38, bar * 0.9, attack=0.05, swell=0.5), t, -0.1, 0.18)
        top = v[-1] + (12 if v[-1] < 66 else 0)
        for k in range(12):
            c.add(pluck(top, 0.15, bright=0.6, pos=0.22, decay=0.35, mute=0.4, var=k % 3), t + k * e * 0.5, 0.4,
                  0.09)
        c.add(pad(PAD[ch], bar, attack=0.3, release=0.5, bright=0.4, seed=i), t, 0.0, 0.12)
    # b: the tune, whistle the first time, the concertina doubling it an octave down the second
    tune = [(69, 1), (74, 1), (74, 1), (69, 1), (74, 1), (76, 1), (77, 1), (76, 1), (74, 1), (72, 1), (69, 2),
            (67, 1), (72, 1), (72, 1), (67, 1), (72, 1), (74, 1), (76, 1), (74, 1), (72, 1), (69, 1), (67, 2),
            (69, 1), (74, 1), (74, 1), (76, 1), (77, 1), (79, 1), (81, 2), (79, 1), (77, 1), (76, 1), (74, 1),
            (72, 1), (69, 1), (72, 1), (76, 2), (72, 1), (74, 2), (69, 1), (74, 3),
            (69, 1), (72, 1), (77, 1), (69, 1), (72, 1), (77, 1), (67, 1), (72, 1), (76, 1), (67, 1), (72, 1),
            (76, 1), (77, 1), (76, 1), (74, 1), (76, 1), (77, 1), (79, 1), (76, 2), (72, 1), (69, 3),
            (69, 1), (72, 1), (77, 1), (81, 2), (77, 1), (79, 1), (76, 1), (72, 1), (76, 2), (79, 1),
            (76, 1), (74, 1), (72, 1), (71, 1), (72, 1), (76, 1), (74, 3), (69, 1), (74, 2)]
    melody(b, tune, 0.0, e, whistle, 0.1, 0.55, legato=0.9)
    melody(b, tune, 16 * bar, e, whistle, 0.1, 0.42, legato=0.9)
    melody(b, tune, 16 * bar, e, reed, -0.15, 0.38, legato=0.92, octave=-1)
    xs = [master(tr, wet=0.18, rt=1.4) for tr in (a, b, c)]
    k = 0.85 / max(1e-9, float(np.max(np.abs(xs[0] + xs[1] + xs[2]))))
    for name, x in zip(("race_a", "race_b", "race_c"), xs):
        write(name, x * k)


# --- STINGS --------------------------------------------------------------------------------------------------------

COUNT = 10.0      # vs/vs.gd's COUNT: the hit lands on GO


def countdown():
    tr = Track(COUNT + 4.0, False)
    # a D pad climbing in, the bass pedal, the drum each second getting harder, rolling in the last three
    tr.add(pad([50, 57, 62, 67], COUNT - 0.2, attack=COUNT - 1.0, release=0.4, bright=0.5, seed=9), 0.0, 0.0, 0.5)
    tr.add(reed(38, COUNT - 0.1, attack=COUNT * 0.8, swell=0.0), 0.0, 0.0, 0.25)
    for i in range(int(COUNT)):
        tr.add(frame_drum(), float(i), 0.0, 0.2 + 0.05 * i)
        tr.add(woodblock(f=880.0 if i < COUNT - 3 else 1180.0), float(i) + 0.5, 0.3, 0.08 + 0.01 * i)
    for k in range(12):
        tr.add(frame_drum(), COUNT - 3.0 + k * 0.25, 0.0, 0.3 + 0.03 * k)
    for k in range(8):
        tr.add(frame_drum(), COUNT - 1.0 + k * 0.125, 0.0, 0.4 + 0.04 * k)
    tr.add(swell_noise(1.5), COUNT - 1.5, 0.0, 0.12)
    # GO: the whole band's chord, the drum, the whistle up high
    tr.strum(CH["D"] + [74], COUNT, spread=0.012, dur=3.5, gain=1.3, pan=-0.15, bright=0.65, decay=1.8)
    tr.add(pluck(38, 3.0, bright=0.2, pos=0.3, decay=1.8), COUNT, 0.0, 0.8)
    tr.add(frame_drum(), COUNT, 0.0, 1.0)
    tr.add(whistle(86, 1.4, vib=0.006), COUNT + 0.02, 0.1, 0.4)
    tr.add(pad([50, 57, 62, 66], 1.0, attack=0.05, release=2.5, bright=0.5, seed=10), COUNT, 0.0, 0.35)
    write("countdown", master(tr, wet=0.25, rt=1.8), 0.8)


def stings():
    # WIN: G, A, D, and a whistle run up to the top D
    tr = Track(6.0, False)
    for t, c in [(0.0, "G"), (0.42, "A"), (0.84, "D")]:
        tr.strum(CH[c], t, spread=0.014, dur=2.6 if c == "D" else 0.6, gain=1.0, bright=0.6, decay=1.6)
    tr.add(frame_drum(), 0.84, 0.0, 0.8)
    tr.add(pad(PAD["D"], 2.4, attack=0.1, release=2.0, bright=0.4, seed=11), 0.84, 0.0, 0.35)
    melody(tr, [(74, 1), (76, 1), (78, 1), (81, 1), (86, 9)], 0.84, 0.13, whistle, 0.1, 0.5)
    write("win", master(tr, wet=0.25), 0.8)
    # LOSE: down through Bm, G, Em, F# and home to Bm, soft
    tr = Track(6.5, False)
    for t, c, d in [(0.0, "Bm", 0.9), (0.8, "G", 0.9), (1.6, "Em", 0.9), (2.4, "F#", 0.9), (3.3, "Bm", 2.8)]:
        tr.strum(CH[c], t, spread=0.03, dur=d + 0.6, gain=0.75, bright=0.35, decay=1.6)
    melody(tr, [(66, 6), (64, 6), (62, 6), (61, 6), (59, 14)], 0.0, 0.135, reed, -0.1, 0.4, legato=0.97)
    tr.add(pad(PAD["Bm"], 2.2, attack=0.4, release=2.0, seed=12), 3.3, 0.0, 0.3)
    write("lose", master(tr, wet=0.28, rt=2.0), 0.7)
    # TIE: Dsus, Gadd9, and left hanging on Asus with a two-note shrug
    tr = Track(5.5, False)
    for t, c, d in [(0.0, "Dsus", 0.9), (0.75, "Gadd9", 0.9), (1.5, "Asus", 2.8)]:
        tr.strum(CH[c], t, spread=0.02, dur=d + 0.5, gain=0.85, bright=0.5, decay=1.6)
    tr.add(pluck(81, 0.8, bright=0.6, pos=0.25, decay=0.8), 2.1, 0.35, 0.35)
    tr.add(pluck(79, 1.6, bright=0.6, pos=0.25, decay=1.0), 2.45, 0.35, 0.35)
    tr.add(pad(PAD["Asus"], 2.4, attack=0.4, release=2.0, seed=13), 1.5, 0.0, 0.3)
    write("tie", master(tr, wet=0.26), 0.72)


if __name__ == "__main__":
    title()
    calm()
    fish_on()
    race()
    countdown()
    stings()
