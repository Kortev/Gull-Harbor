"""Bluefin's music, made here from nothing but sums of sines and a little noise (no samples), and written to
../music/*.ogg for audio/music.gd to play on the Music bus.

The sound: a lo-fi folk band in a fish shed. Plucked guitar and ukulele (each harmonic decaying on its own, faster
the higher it is, with a pick's scratch), an upright-ish plucked bass, a tin whistle, a concertina (two reeds a hair
apart), soft pads, a frame drum and a shaker. All of it through a warm room (a made-up reverb tail), a touch of tape
wow, a gentle saturation and a low-pass round 8 kHz: warm and a bit worn, never chiptune-bright.

The cues (audio/music.gd plays them as docs/MUSIC_SYSTEM.md describes; audio/music_cues.gd, written here, says what
each is and its timing):
  title              the theme (THEME: the game's own tune) whole, 4/4 in D at 112, 40 bars, loops; 10 stems, the
                     weather's among them (the title's own sea plays it)
  sea_a..j, sea_t1/t2, sea_s1..3
                     the song: everything after the title is one endless song of eight-bar passages played one after
                     another (never the same twice running; t1 and t2 the theme's halves, t2 always after t1; s1-s3
                     the storm's own, dark; f1-f3 the fight's, a chord a bar over a driving bass riff), 19 stems
                     each, every layer the game has on the same chords (sea())
  strike, fight_in, leader_in, landed, thunder
                     moments over the song: the hookup's hit, the fill into the theme for the leader, the hit when
                     he's landed, a lightning strike
  hunt_in, race_in, away_in, boatside_end, race_end, title_end
                     cues over the song: lead-ins two beats long into a downbeat, endings that ring on
  countdown          Rivals' countdown: COUNT (10) s building to the hit on GO, then its tail
  win, lose, tie     the results card's stamp; their_on, lead_up, lead_down Rivals' stings out there
  note_62..90        the deck tin whistle's notes

A section's stems are mastered alike and by the whole mix's peak (stems()), so they keep their balance and sum back
to the whole; every stem of it is exactly as long as its bars.

Loops are made round: every note's tail and the reverb's wrap past the end back to the start, and the filters run
over the loop twice and keep the second time through, so the end runs into the start with no seam.

Run: python tools/music.py   (numpy, scipy, soundfile; a few minutes). Writes ../music/*.ogg and
../audio/music_cues.gd."""
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


def bowed(m, dur, attack=0.5, release=0.6, bright=0.4, vib=0.004, seed=0):
    """A bowed string, low (a cello-ish drone): a sawtooth's harmonics through a body (two formants), the bow's
    hiss, a slow vibrato coming in, a swell into the note."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(int(m * 13 + seed))
    f = hz(m) * (1.0 + vib * np.sin(2 * np.pi * 4.6 * t + rng.uniform(0, 6.3)) * np.clip((t - 0.4) / 0.8, 0.0, 1.0))
    ph = np.cumsum(2 * np.pi * f / SR)
    v = np.zeros(n)
    for k in range(1, 24):
        if hz(m) * k > 6000:
            break
        v += np.sin(k * ph + rng.uniform(0, 6.3)) / k ** (1.25 - 0.4 * bright)
    v = _bp(v, 70.0, 900.0 + 1800.0 * bright) + 0.35 * _bp(v, 1800.0, 3200.0)
    v += _bp(rng.standard_normal(n), 1500, 6000) * 0.04 * (0.5 + bright)
    env = 0.5 - 0.5 * np.cos(np.pi * np.clip(t / attack, 0.0, 1.0))
    env *= 1.0 + 0.12 * np.sin(np.pi * np.clip(t / max(dur, 0.01), 0, 1))
    d = int(dur * SR)
    env[d:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n - d))
    return _peak(v * env)


def war_drum(strength=1.0, low=1.0):
    """A big low drum (a bodhrán's bigger brother, beaten hard): a deep skin dropping in pitch, a long boom, the
    stick's knock."""
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = (38.0 + 70.0 * np.exp(-t / 0.035)) * low
    body = np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t / 0.32)
    body += 0.4 * np.sin(np.cumsum(2 * np.pi * f * 1.52 / SR)) * np.exp(-t / 0.12)
    knock = _bp(RNG.standard_normal(n) * np.exp(-t / 0.006), 300, 2600) * 0.45
    return _peak((body + knock) * np.minimum(1.0, t / 0.0015)) * strength


def stomp(strength=1.0):
    """A boot on the deck boards: a thud, the planks' rattle."""
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 70.0 + 60.0 * np.exp(-t / 0.015)
    body = np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t / 0.07)
    wood = _bp(RNG.standard_normal(n) * np.exp(-t / 0.03), 180, 900) * 0.6
    return _peak(body + wood) * strength


def clap(strength=1.0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    v = np.zeros(n)
    for k, d in enumerate((0.0, 0.009, 0.017)):
        i = int(d * SR)
        v[i:] += np.exp(-(t[:n - i]) / (0.008 if k < 2 else 0.06))
    return _peak(_bp(RNG.standard_normal(n), 900, 4200) * v) * strength


def line_sing(m, dur, beat=3.0, attack=0.8, release=1.0):
    """The line singing in the wind under load: a thin high sine, a second a few Hz off so it beats, a slow wobble."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1.0 + 0.003 * np.sin(2 * np.pi * 0.7 * t))
    v = np.sin(np.cumsum(2 * np.pi * f / SR)) + 0.8 * np.sin(np.cumsum(2 * np.pi * (f + beat) / SR))
    v += 0.15 * np.sin(np.cumsum(2 * np.pi * 2 * f / SR))
    env = np.minimum(1.0, t / attack)
    d = int(dur * SR)
    env[d:] *= np.linspace(1.0, 0.0, n - d)
    return _peak(v * env)


def bell(m, dur=3.0):
    """A soft high bell-ish ping (a guitar harmonic, struck): a sine and a few inharmonic partials ringing off."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    v = np.zeros(n)
    for r, a, tau in ((1.0, 1.0, 1.6), (2.0, 0.25, 0.7), (2.76, 0.12, 0.4), (5.4, 0.05, 0.15)):
        v += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / tau)
    return _peak(v * np.minimum(1.0, t / 0.003))


def sub_swell(dur, m=26, strength=1.0):
    """A sub-bass swell: a low sine rising and falling (felt more than heard)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    v = np.sin(2 * np.pi * hz(m) * t) * np.sin(np.pi * t / dur) ** 2
    return v * strength


def crash(dur=2.4, strength=1.0):
    """A splash of noise like a cymbal (or white water): bright, decaying."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    v = _hp(RNG.standard_normal(n), 3000) * np.exp(-t / (dur * 0.3)) + _bp(RNG.standard_normal(n), 600, 3000) * \
        np.exp(-t / 0.08) * 0.5
    return _peak(v * np.minimum(1.0, t / 0.002)) * strength


def howl(dur, lo=380.0, hi=900.0, seed=0):
    """Wind howling: noise through a narrow band that slides up and down, swelling and dying."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(300 + seed)
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    seg = int(0.05 * SR)
    phase = rng.uniform(0, 6.3)
    for i in range(0, n, seg):
        c = lo + (hi - lo) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.23 * (i / SR) + phase))
        out[i:i + seg] = _bp(noise[max(0, i - 2048):i + seg], c * 0.85, c * 1.15, order=2)[-len(out[i:i + seg]):]
    env = np.sin(np.pi * np.clip(t / dur, 0.0, 1.0)) ** 1.5
    return _peak(out * env)


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


def master(tr, wet=0.22, rt=1.8, wow=0.0012, lp=8000.0, drive=1.6, norm=0.0, peak=False):
    """The room, the tape and the warmth over a whole track; returns (2, n). Everything up to the warmth is linear,
    so stems mastered alike sum to the whole: `norm` scales by a fixed amount instead of to this track's own peak
    (every stem of a cue by the whole mix's), and `peak` only returns that peak."""
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
    if peak:
        return float(np.max(np.abs(x)))
    x = x * norm if norm > 0.0 else x / max(1e-9, np.max(np.abs(x)))
    x = np.tanh(drive * x) / np.tanh(drive)
    if not tr.loop and norm <= 0.0:
        # trim the silence after the tail, fade the last of it
        e = np.max(np.abs(x), axis=0)
        last = int(np.nonzero(e > 10 ** (-66 / 20))[0][-1]) if np.any(e > 10 ** (-66 / 20)) else n - 1
        x = x[:, :min(n, last + int(0.1 * SR))]
        f = min(x.shape[1], int(0.25 * SR))
        x[:, -f:] *= np.linspace(1.0, 0.0, f)
    return x


# A sting's (and the leader's fill's) silent pre-roll (s): audio/music.gd starts it a frame early, this far into the
# silence that its hit lands on the beat.
PRE = 0.06
STINGS = {"strike", "fight_in", "thunder", "leader_in", "landed", "their_on", "lead_up", "lead_down", "countdown",
          "win", "lose", "tie",
          "hunt_in", "race_in", "away_in", "boatside_end", "race_end", "title_end"}


def write(name, x, level=0.0, comp=0.62):
    """To ../music/<name>.ogg, its peak at `level` (0: as it is); a sting with PRE s of silence in front. In short
    blocks: libsndfile's Vorbis encoder overflows the stack given a long one at once."""
    os.makedirs(OUT, exist_ok=True)
    if level > 0.0:
        x = x / max(1e-9, np.max(np.abs(x))) * level
    if name in STINGS:
        x = np.concatenate([np.zeros((2, int(round(PRE * SR)))), x], axis=1)
    path = os.path.join(OUT, name + ".ogg")
    data = np.ascontiguousarray(x.T.astype(np.float32))
    for tries in range(20):
        try:
            with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=comp) as f:
                for i in range(0, data.shape[0], 4096):
                    f.write(data[i:i + 4096])
            break
        except sf.LibsndfileError:
            # (an open Godot editor reimporting it holds it a moment)
            if tries == 19:
                raise
            import time
            time.sleep(0.5)
    print("%-18s %5.1f s  %4d KB" % (name, x.shape[1] / SR, os.path.getsize(path) // 1024))


# --- the manifest: what audio/music.gd needs to know of each cue (its timing above all) -----------------------------

CUES = {}
GD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music_cues.gd")


def cue(name, kind, files, bpm=0.0, bar_beats=4, bars=0, loop=False, **more):
    """kind: bed (a section: its stems played together, looped), sting (a one-shot over whatever's playing), filler
    (between two sections, exactly its length), notes (the deck whistle's, one file a note from `low` up)."""
    d = {"kind": kind, "files": files, "bpm": bpm, "bar_beats": bar_beats, "bars": bars, "loop": loop}
    if name in STINGS:
        d["pre"] = PRE
    d.update(more)
    CUES[name] = d


def seam_ok(x):
    """A loop's end runs into its start no harder than the music itself moves sample to sample."""
    jump = float(np.max(np.abs(x[:, 0] - x[:, -1])))
    moves = float(np.percentile(np.abs(np.diff(x, axis=1)), 99.9))
    return jump <= max(moves, 1e-3), jump, moves


# The clock's tick on each bar (a stem of its own: "mark"): how high (Hz: above the music, which is low-passed round 8
# kHz, below what the Vorbis encoder drops), how long (s) and how loud.
MARK_HZ = 12000.0
MARK_S = 0.006
MARK_LEVEL = 0.03


def stems(name, tracks, bpm, bar_beats, bars, level=0.85, kind="bed", chords=None, chord_beats=0, **mk):
    """A section as stems (dict name -> Track, all one length): each mastered just like the whole mix (by the whole
    mix's peak, so they keep their balance), written ../music/<name>_<stem>.ogg, checked: the stems sum back to the
    whole (the warmth's the only bend in it, light), and each loop's seam is clean."""
    ts = list(tracks.values())
    n = ts[0].n
    assert all(t.n == n and t.loop == ts[0].loop for t in ts), name + ": stems of different lengths"
    want = bars * bar_beats * 60.0 / bpm
    assert abs(n / SR - want) < 1.5 / SR, "%s: %.5f s, its bars make %.5f" % (name, n / SR, want)
    whole = Track(n / SR, ts[0].loop)
    whole.buf = sum(t.buf for t in ts)
    mk.setdefault("drive", 1.15)
    p = master(whole, peak=True, **mk)
    full = master(whole, norm=1.0 / p, **mk)
    xs = {k: master(t, norm=1.0 / p, **mk) for k, t in tracks.items()}
    s = sum(xs.values())
    err = 20 * np.log10(np.sqrt(np.mean((s - full) ** 2)) / max(1e-9, np.sqrt(np.mean(full ** 2))))
    assert err < -18.0, "%s: the stems don't sum to the whole (%.1f dB)" % (name, err)
    g = level / max(float(np.max(np.abs(s))), float(np.max(np.abs(full))))
    for k, x in xs.items():
        if ts[0].loop:
            ok, jump, moves = seam_ok(x)
            assert ok, "%s_%s: the loop's seam jumps %.4f (the music moves %.4f)" % (name, k, jump, moves)
        write("%s_%s" % (name, k), x * g, comp=0.8)       # (a stem's heard with the rest: fewer bits)
    print("  %s: %d stems, sum vs whole %.1f dB" % (name, len(xs), err))
    # mark: the clock's tick, a little MARK_HZ blip on each bar's downbeat, never mastered (no room on it, sharp):
    # audio/music.gd hears the section through it as it plays (its grid as the mixer really has it), and filters it
    # out before anyone else does
    mark = np.zeros((2, n))
    blip = np.sin(2 * np.pi * MARK_HZ * np.arange(int(MARK_S * SR)) / SR) * np.hanning(int(MARK_S * SR)) * MARK_LEVEL
    for b in range(bars):
        i = int(round(b * bar_beats * 60.0 / bpm * SR))
        mark[:, i:i + len(blip)] += blip[:n - i]
    write("%s_mark" % name, mark, comp=0.6)
    cue(name, kind, ["%s_%s" % (name, k) for k in tracks] + ["%s_mark" % name], bpm, bar_beats, bars, ts[0].loop,
        stems=list(tracks) + ["mark"], length=n / SR, mark_hz=MARK_HZ, mark_s=MARK_S)
    if chords:
        # (what's playing when: one chord each chord_beats beats, a bar each by default; the deck whistle's notes)
        CUES[name]["chords"] = list(chords)
        CUES[name]["chord_beats"] = chord_beats or bar_beats


class Stems(dict):
    """A passage's tracks: a layer it hasn't got takes what's put in it and drops it."""
    class _Nothing:
        def add(self, *a, **k):
            pass

        def strum(self, *a, **k):
            pass

    def __missing__(self, key):
        return Stems._Nothing()


def write_cues():
    """audio/music_cues.gd: a script (it goes in the export as it is) holding CUES."""
    CUES["songs"] = {"kind": "songs", "files": [], "forms": {k: ["sea_" + n for n in v] for k, v in SONGS.items()}}
    import json
    body = json.dumps(CUES, indent=1, sort_keys=True).replace("\n", "\n\t")
    with open(GD, "w", encoding="utf-8", newline="\n") as f:
        f.write("extends RefCounted\n## Made by tools/music.py (don't edit by hand): each cue in res://music/, what kind it is, its files, its\n"
                "## timing (bpm: beats a minute, bar_beats, bars), whether it loops, its stems; stings their hit (s in).\n\n"
                "const CUES := %s\n" % body)
    print("audio/music_cues.gd: %d cues" % len(CUES))


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


# --- THE SONG'S TIME AND ITS CHORDS' NOTES ---------------------------------------------------------------------
# Everything at sea is one song at 112, in D and its B minor (sea()); the title's the theme in the same time and key.

FIGHT_BPM = 112.0
ROOT = {"Bm": 35, "G": 31, "Em": 28, "F#": 30, "D": 38, "A": 33, "C": 36, "F": 29, "Dsus": 38, "Gadd9": 31,
        "Asus": 33}
# over each chord, the note the tremolo worries at (a ninth, or the flat ninth over F#)
TENSE = {"Bm": 73, "G": 69, "Em": 66, "F#": 67, "D": 76, "A": 71, "C": 73, "F": 66, "Dsus": 76, "Gadd9": 69,
         "Asus": 71}


def _runs(prog):
    """[(chord, first bar, bars)] for each run of one chord."""
    out = []
    for i, c in enumerate(prog):
        if out and out[-1][0] == c:
            out[-1][2] += 1
        else:
            out.append([c, i, 1])
    return out


# --- THE THEME: Bluefin's own tune, everywhere --------------------------------------------------------------------
# One tune to know the game by: in D, sixteen bars, rising A-D-F# to open, a climb to its high B near the end and home.
# The title plays it whole; the sea carries it now and then (sea_t1, sea_t2: its two halves); the hunt's bells pick out
# its first three notes; the leader is its second half, soaring; landing him, its first half comes home (afterglow);
# winning Rivals, its opening. In eighths at 112, a bar to each chord.

THEME = [(69, 2), (74, 2), (78, 4), (79, 3), (78, 1), (76, 4), (78, 2), (74, 2), (69, 4), (71, 2), (73, 2), (76, 4),
         (69, 2), (74, 2), (78, 4), (83, 4), (81, 2), (79, 2), (79, 3), (78, 1), (76, 2), (74, 2), (76, 8),
         (78, 2), (76, 2), (74, 2), (78, 2), (71, 4), (74, 4), (81, 3), (78, 1), (74, 4), (76, 2), (78, 2), (76, 4),
         (83, 2), (81, 2), (79, 2), (83, 2), (81, 4), (78, 4), (76, 3), (74, 1), (73, 2), (76, 2), (74, 8)]
THEME_CHORDS = ["D", "G", "D", "A", "D", "G", "Em", "A", "Bm", "G", "D", "A", "G", "D", "A", "D"]


def theme_bars(a, b):
    """The theme's notes from bar a to bar b (0-based, b not included)."""
    out, t = [], 0
    for m, ln in THEME:
        if a * 8 <= t < b * 8:
            out.append((m, ln))
        t += ln
    return out


def theme_check():
    t = 0
    for m, ln in THEME:
        t += ln
    assert t == 16 * 8, "the theme's %d eighths, not sixteen bars" % t


# --- TITLE: the theme, 4/4 at 112, 40 bars ------------------------------------------------------------------------

def title():
    """Four bars of the guitar (the bells ringing its first three notes), the theme on the whistle, the theme again
    with the concertina under it an octave down and the drums in, a tag home. Loops. In stems, so the title's sea
    plays it (audio/music_state.gd): the whistle and the band in fair weather; in rain the patter under it and the
    whistle softer; in a storm no whistle at all, the theme low on the bow over the storm's drums; at night the
    bells; in fog almost only the pad and a far whistle."""
    theme_check()
    q = 60.0 / FIGHT_BPM
    e, s16, bar = q / 2, q / 4, 4 * q
    prog = ["D", "G", "D", "A"] + THEME_CHORDS + THEME_CHORDS + ["G", "A", "D", "D"]
    names = ("lead", "counter", "guitar", "bass", "pad", "drums", "rain", "storm", "night", "low")
    T = {k: Track(len(prog) * bar, True) for k in names}
    arp = [0, 2, 3, 4, 3, 2, 3, 2]
    for b, c in enumerate(prog):
        t = b * bar
        v = CH[c]
        second = 20 <= b < 36
        for i, j in enumerate(arp):
            T["guitar"].add(pluck(v[min(j, len(v) - 1)], 1.5, bright=0.42, decay=1.3, var=i % 3),
                            t + i * e + RNG.uniform(0, 0.006), -0.25, 0.3 if i in (0, 4) else 0.22)
        root = v[0] - 12 if v[0] >= 45 else v[0]
        T["bass"].add(pluck(root, 2.0, bright=0.15, pos=0.3, decay=1.6), t, 0.0, 0.52)
        T["bass"].add(pluck(root + 7, 1.2, bright=0.15, pos=0.3, decay=1.2), t + 2.5 * q, 0.0, 0.3)
        T["pad"].add(pad(PAD[c], bar, attack=0.6, release=1.0, seed=b), t, 0.0, 0.16)
        if 12 <= b < 36:
            for i in range(8):
                T["drums"].add(shaker(), t + i * e, 0.4, 0.1 if i % 2 == 0 else 0.06)
        if second:
            T["drums"].add(frame_drum(), t, 0.0, 0.5)
            T["drums"].add(frame_drum(), t + 2 * q, 0.0, 0.38)
            T["drums"].add(stomp(), t + q, 0.05, 0.22)
            T["drums"].add(stomp(), t + 3 * q, 0.05, 0.22)
            if b % 4 == 3:
                for i in range(4):
                    T["drums"].add(frame_drum(), t + 3 * q + i * q / 4, 0.0, 0.18 + 0.06 * i)
            for k in (1, 3):
                T["guitar"].strum([x + 12 for x in v[-3:]], t + k * q, spread=0.008, dur=0.25, gain=0.2, pan=0.35,
                                  bright=0.7, pos=0.25, decay=0.5, mute=0.6)
        # the weather's: rain's patter, the storm's drums half-time, the night's bells on the chord
        for i in range(16):
            T["rain"].add(shaker(), t + i * s16, 0.4 if i % 2 else -0.3, 0.07 if i % 4 == 2 else 0.04)
        T["storm"].add(war_drum(low=0.9), t, 0.0, 0.5)
        T["storm"].add(war_drum(low=0.9), t + 2.5 * q, 0.0, 0.32)
        for k, at in ((b % 3, 0.5), ((b + 1) % 3, 2.5)):
            T["night"].add(bell(v[-1 - k] + 12 if v[-1 - k] + 24 >= 96 else v[-1 - k] + 24, 3.0), t + at * q,
                           0.35 if k % 2 else -0.35, 0.1)
    for c, b0, n in _runs(prog):
        T["storm"].add(bowed(ROOT[c] + 12, n * bar * 0.97, attack=1.0, release=1.0, bright=0.2, seed=b0), b0 * bar,
                       -0.1, 0.3)
        T["storm"].add(sub_swell(n * bar, ROOT[c] if ROOT[c] < 36 else ROOT[c] - 12, 1.0), b0 * bar, 0.0, 0.3)
    # the bells: its first three notes, ringing out in the intro
    for b in (0, 2):
        for k, m in enumerate((81, 86, 90)):
            T["lead"].add(bell(m, 3.0), b * bar + k * q, 0.3, 0.14)
    melody(T["lead"], THEME, 4 * bar, e, whistle, 0.1, 0.5, legato=0.93)
    melody(T["lead"], THEME, 20 * bar, e, whistle, 0.1, 0.48, legato=0.93)
    melody(T["counter"], THEME, 20 * bar, e, reed, -0.15, 0.3, legato=0.96, octave=-1)
    melody(T["lead"], [(None, 8), (None, 8), (69, 2), (74, 2), (78, 12)], 36 * bar, e, whistle, 0.1, 0.32)
    # low: the theme on the bow, an octave and more down (the storm's, in place of the whistle)
    for at in (4, 20):
        t0 = at * bar
        for m, ln in THEME:
            if m is not None:
                T["low"].add(bowed(m - 24, ln * e * 0.98, attack=0.12, release=0.4, bright=0.45, vib=0.006), t0,
                             -0.05, 0.3)
            t0 += ln * e
    stems("title", T, FIGHT_BPM, 4, len(prog), level=0.82, wet=0.26, rt=2.0, chords=prog)


def exact(x, n):
    """Exactly n samples (cut or padded), the last few ms faded so a filler never clicks off."""
    if x.shape[1] >= n:
        x = x[:, :n].copy()
    else:
        x = np.concatenate([x, np.zeros((2, n - x.shape[1]))], axis=1)
    f = int(0.004 * SR)
    x[:, -f:] *= np.linspace(1.0, 0.0, f)
    return x


def moments():
    """The song's moments, played over it on its grid: the fill into the leader (two beats, ending on the bar), and
    the hit when he's landed (the whole band's D, the drum, the splash, the whistle high: on the downbeat)."""
    q = 60.0 / FIGHT_BPM
    tr = Track(2 * q, False)
    for i in range(8):
        tr.add(war_drum(low=1.0 + 0.09 * i), i * q / 4, 0.0, 0.35 + 0.08 * i)
    tr.add(swell_noise(2 * q), 0.0, 0.0, 0.18)
    tr.add(pluck(33, 1.0, bright=0.2, pos=0.3, decay=0.8), 0.0, 0.0, 0.4)
    write("leader_in", exact(master(tr, wet=0.12, rt=1.2), int(round(2 * q * SR))), 0.8)
    cue("leader_in", "sting", ["leader_in"], length=2 * q, lead_in=True)
    tr = Track(5.0, False)
    tr.strum(CH["D"] + [74], 0.0, spread=0.01, dur=3.0, gain=1.25, pan=-0.15, bright=0.7, decay=1.8)
    tr.add(war_drum(), 0.0, 0.0, 0.9)
    tr.add(crash(2.6), 0.0, 0.2, 0.22)
    tr.add(pluck(38, 3.0, bright=0.2, pos=0.3, decay=1.8), 0.0, 0.0, 0.8)
    tr.add(whistle(86, 1.6, vib=0.006), 0.02, 0.1, 0.38)
    write("landed", master(tr, wet=0.26, rt=2.0), 0.85)
    cue("landed", "sting", ["landed"], hit=0.0)


def fight_in():
    """The break after the strike: two bars of the drums alone driving into the fight (the song's turned dark under
    it on the same bar): the war drums on the eighths building, toms rolling down the end of each bar, boots."""
    q = 60.0 / FIGHT_BPM
    e, s16, bar = q / 2, q / 4, 4 * q
    tr = Track(2 * bar + 2.0, False)
    for b in range(2):
        t = b * bar
        for i in range(8):
            tr.add(war_drum(low=0.95), t + i * e, 0.0, (0.35 + 0.05 * i + 0.2 * b) * (1.0 if i % 2 == 0 else 0.7))
        for k in (1, 3):
            tr.add(stomp(), t + k * q, 0.05, 0.4)
            tr.add(clap(), t + k * q + 0.003, 0.3, 0.18)
        for i in range(8 if b == 1 else 4):
            tr.add(war_drum(low=1.2 + 0.05 * i), t + (4 - (8 if b == 1 else 4) * 0.25) * q + i * s16, 0.3 - 0.08 * i,
                   0.25 + 0.05 * i)
    tr.add(crash(2.0), 2 * bar, 0.2, 0.25)
    tr.add(war_drum(low=0.7), 2 * bar, 0.0, 0.8)
    write("fight_in", master(tr, wet=0.18, rt=1.5), 0.85)
    cue("fight_in", "sting", ["fight_in"], hit=0.0)


def thunder():
    """Lightning: the biggest drums twice, the splash, the bow on a grinding semitone low down, the sub falling."""
    tr = Track(4.0, False)
    tr.add(war_drum(low=0.65), 0.0, 0.0, 1.0)
    tr.add(war_drum(low=0.75), 0.27, 0.0, 0.7)
    tr.add(crash(3.0), 0.0, 0.25, 0.3)
    tr.add(bowed(35, 2.2, attack=0.04, release=1.2, bright=0.5), 0.0, -0.2, 0.42)
    tr.add(bowed(36, 2.2, attack=0.04, release=1.2, bright=0.5), 0.0, 0.2, 0.36)
    tr.add(sub_swell(2.0, 23, 1.0), 0.0, 0.0, 0.6)
    write("thunder", master(tr, wet=0.3, rt=2.4), 0.8)
    cue("thunder", "sting", ["thunder"], hit=0.0)


def strike():
    """The hookup: the war drum and the low B hit on the reel's scream, the band's chord, a splash, the bow
    digging in. The fight's first bar starts under it, so it's all front."""
    tr = Track(4.0, False)
    tr.add(war_drum(), 0.0, 0.0, 1.0)
    tr.add(war_drum(low=0.8), 0.012, 0.0, 0.7)
    tr.add(pluck(35, 3.0, bright=0.25, pos=0.3, decay=2.0), 0.0, 0.0, 0.9)
    tr.strum(CH["Bm"], 0.0, spread=0.008, dur=2.4, gain=1.1, pan=-0.15, bright=0.75, decay=1.4)
    tr.add(crash(2.2), 0.0, 0.2, 0.28)
    tr.add(bowed(47, 1.4, attack=0.06, release=0.8, bright=0.6), 0.0, -0.2, 0.42)
    tr.add(bowed(54, 1.3, attack=0.25, release=1.0, bright=0.6), 0.45, 0.2, 0.38)
    tr.add(sub_swell(1.6, 23, 1.0), 0.0, 0.0, 0.5)
    write("strike", master(tr, wet=0.2, rt=1.6), 0.85)
    cue("strike", "sting", ["strike"], hit=0.0)


# --- LEAD-INS AND ENDINGS: the song's cues, the way a band would play them --------------------------------------
# Lead-ins are two beats long, ending exactly on a downbeat (birds sighted, the race home called, casting off);
# endings are a hit and its ring on a downbeat (boatside, home made, the title giving way to the song). Played over
# the song, never instead of it.

def handoffs():
    q = 60.0 / FIGHT_BPM
    s16 = q / 4
    # lead-ins: exactly two beats long, the downbeat after them
    def lead_in(name, tr):
        write(name, exact(master(tr, wet=0.2, rt=1.6), int(round(2 * q * SR))), 0.7)
        cue(name, "sting", [name], length=2 * q, lead_in=True)
    # into the hunt: the bells climbing the theme's first three notes, the shaker swelling
    tr = Track(2 * q, False)
    for k, m in enumerate((69, 74, 78, 81)):
        tr.add(bell(m + 12, 2.0), k * q / 2, 0.3 - 0.2 * k, 0.12 + 0.03 * k)
    for i in range(8):
        tr.add(shaker(), i * s16, 0.4, 0.03 + 0.012 * i)
    lead_in("hunt_in", tr)
    # into the race: the drum rolling up, the whistle's pickup into the jig
    tr = Track(2 * q, False)
    for i in range(8):
        tr.add(frame_drum(), i * s16, 0.0, 0.2 + 0.07 * i)
    tr.add(swell_noise(2 * q), 0.0, 0.0, 0.12)
    melody(tr, [(76, 1), (79, 1), (83, 1), (86, 1)], q, q / 4, whistle, 0.1, 0.35, legato=0.85)
    lead_in("race_in", tr)
    # away from the dock: a strum up and the whistle's A-D, into the sea
    tr = Track(2 * q, False)
    tr.strum(CH["A"], 0.0, down=False, spread=0.03, dur=1.2, gain=0.5, bright=0.45, decay=1.0)
    melody(tr, [(69, 2), (74, 2)], q, q / 2, whistle, 0.1, 0.35, legato=0.9)
    lead_in("away_in", tr)
    # into the fight is the strike itself; into the leader, leader_in (moments())
    # tails: a last hit and its ring
    def tail(name, tr):
        write(name, master(tr, wet=0.3, rt=2.2), 0.7)
        cue(name, "sting", [name], hit=0.0, tail=True)
    # the fight to boatside: a big drum and a splash, the bow swelling and gone
    tr = Track(4.0, False)
    tr.add(war_drum(), 0.0, 0.0, 0.9)
    tr.add(crash(2.4), 0.0, 0.2, 0.25)
    tr.add(bowed(42, 1.8, attack=0.05, release=1.2, bright=0.5), 0.0, -0.1, 0.4)
    tail("boatside_end", tr)
    # the race home, made: the jig's last chord, the drum, the ring
    tr = Track(4.5, False)
    tr.strum(CH["Em"], 0.0, spread=0.012, dur=3.2, gain=1.0, bright=0.6, decay=1.8)
    tr.add(frame_drum(), 0.0, 0.0, 0.7)
    tr.add(whistle(83, 1.4, vib=0.006), 0.02, 0.1, 0.3)
    tail("race_end", tr)
    # the title gone (FISH): the theme's last chord ringing out under the harbour
    tr = Track(5.0, False)
    tr.strum(CH["D"] + [74], 0.0, spread=0.03, dur=4.0, gain=0.8, bright=0.45, decay=2.4)
    for k, m in enumerate((81, 86, 90)):
        tr.add(bell(m, 3.5), k * q, 0.3, 0.12)
    tail("title_end", tr)


# --- THE SONG: one endless song in D and B minor at 112, eight-bar passages, every layer on every one -----------
# audio/music.gd plays one passage after another, picking the next as each ends (never the same twice running; bright
# ones in fair weather, dark ones in foul, at dusk and in a fight; the theme's halves for the leader and for landing
# him), so it never goes round the same way twice. It never changes song: what happens brings its layers up and down
# (audio/music_state.gd) on the same chords: the weather's (the pad and the bass always, the guitar and the lead in
# fair weather, the rain's patter, the storm's drums and drone, the night's bells), her speed (run), birds working
# (pulse, glint), a fish on (beat: the heartbeat and the muted bass; drive: the war drums; tension: the tremolo and
# the singing line, as the line nears going; deep: while he sounds; heavy: a giant), the climax (high: the lead an
# octave up), and a fill into the next passage now and then.

SEA_STEMS = ("pad", "bass", "pick", "lead", "high", "rain", "storm", "night", "run", "fill", "pulse", "glint",
             "beat", "drive", "tension", "deep", "heavy", "gale", "pound")
SEA = {
    # name: (chords: four, two bars each, or eight, a bar each), the lead's instrument, the lead [(midi, eighths)],
    # bright. The weather's songs are made of them (SONGS: their forms; PARTS: each part's song, role and sound)
    "fair_v1": (["D", "A", "Bm", "G"], "whistle", [(None, 4), (74, 4), (76, 2), (78, 6), (None, 2), (76, 4), (73, 4), (76, 6),
                                             (None, 4), (74, 4), (73, 2), (71, 6), (None, 2), (74, 4), (71, 2), (67, 8)],
          True),
    "fair_out": (["G", "D", "A", "D"], "whistle", [(None, 4), (71, 4), (74, 8), (None, 2), (78, 4), (76, 2), (74, 8),
                                             (None, 4), (73, 4), (76, 4), (73, 4), (74, 10), (None, 6)], True),
    "fair_br": (["Bm", "G", "Em", "F#"], "reed", [(None, 6), (66, 2), (71, 8), (None, 4), (67, 4), (71, 4), (74, 4),
                                            (None, 4), (71, 4), (67, 8), (None, 2), (66, 4), (64, 2), (61, 8)], False),
    "rain_in": (["Bm", "Bm", "G", "A"], "reed", [(None, 8), (66, 4), (69, 4), (71, 12), (None, 4), (None, 4), (67, 4),
                                           (66, 4), (64, 4), (61, 8), (None, 8)], False),
    "fair_v2": (["Em", "G", "D", "A"], "whistle", [(None, 4), (67, 4), (71, 8), (None, 2), (74, 6), (71, 8), (None, 4),
                                              (78, 4), (76, 4), (74, 4), (73, 12), (None, 4)], True),
    "rain_v": (["G", "Em", "Bm", "F#"], "reed", [(None, 4), (71, 4), (74, 4), (71, 4), (67, 12), (None, 4), (None, 4),
                                            (66, 4), (71, 4), (73, 4), (70, 12), (None, 4)], False),
    "fair_in": (["D", "Bm", "G", "A"], "whistle", [(None, 4), (78, 4), (76, 4), (74, 4), (71, 8), (None, 8), (None, 4),
                                              (74, 4), (79, 4), (78, 4), (76, 12), (None, 4)], True),
    "rain_br": (["Em", "Bm", "G", "F#"], "reed", [(None, 8), (71, 4), (67, 4), (66, 12), (None, 4), (None, 4), (71, 4),
                                            (74, 4), (73, 4), (70, 12), (None, 4)], False),
    "rain_out": (["G", "A", "D", "D"], "whistle", [(None, 4), (74, 4), (76, 4), (79, 4), (78, 8), (76, 8), (None, 4),
                                             (73, 4), (74, 4), (76, 4), (74, 12), (None, 4)], True),
    "rain_ch": (["Bm", "F#", "Em", "Bm"], "reed", [(None, 6), (73, 2), (74, 8), (None, 4), (73, 4), (70, 8), (None, 4),
                                             (67, 4), (71, 4), (74, 4), (73, 4), (71, 8), (None, 4)], False),
    # the storm's own: dark, the flat second and the flat ninth grinding (audio/music.gd plays them in a storm)
    "s1": (["Bm", "C", "Bm", "F#"], "reed", [(None, 8), (66, 4), (67, 4), (66, 12), (None, 4), (None, 8), (62, 4),
                                            (61, 4), (59, 16)], False),
    "s2": (["Em", "F", "Bm", "F#"], "reed", [(None, 8), (71, 4), (72, 4), (71, 12), (None, 4), (None, 4), (66, 4),
                                            (65, 4), (66, 4), (61, 16)], False),
    "s3": (["Bm", "G", "C", "F#"], "reed", [(None, 4), (71, 4), (74, 4), (72, 4), (71, 16), (None, 8), (66, 4),
                                           (67, 4), (66, 4), (61, 12)], False),
    # the theme's two halves, a chord a bar (audio/music.gd plays t2 straight after t1)
    # the fight's own: a chord every bar, a driving bass riff under them (audio/music.gd turns the song into one on
    # the bar after the strike, and keeps to them till he's tiring)
    "f1": (["Bm", "Bm", "G", "A", "Bm", "Bm", "F#", "F#"], "reed", [(None, 8), (71, 2), (74, 2), (73, 4), (71, 8),
                                                                   (None, 8), (66, 4), (67, 4), (66, 8), (61, 8),
                                                                   (None, 8)], False),
    "f2": (["Em", "C", "Bm", "F#", "Em", "C", "F#", "F#"], "reed", [(None, 4), (76, 4), (74, 4), (71, 4), (72, 8),
                                                                   (71, 8), (None, 4), (69, 4), (67, 4), (66, 4),
                                                                   (66, 8), (None, 8)], False),
    "f3": (["Bm", "G", "Em", "F#", "Bm", "G", "C", "F#"], "reed", [(None, 8), (74, 4), (73, 4), (71, 8), (67, 8),
                                                                  (None, 4), (71, 4), (72, 4), (71, 4), (70, 16)],
           False),
    # fog: suspended, far, almost still (a far whistle, bells for a guitar)
    "fog_in": (["D", "D", "Gadd9", "Gadd9", "D", "D", "Asus", "Asus"], "whistle", None, True),
    "fog_v": (["Bm", "Bm", "Gadd9", "Gadd9", "D", "D", "Asus", "A"], "whistle", None, False),
    "fog_br": (["Em", "Em", "G", "G", "D", "D", "A", "A"], "whistle", None, False),
    "fog_out": (["Gadd9", "Gadd9", "D", "D", "Asus", "Asus", "D", "D"], "whistle", None, True),
    # night: a lullaby, the bells singing, a harp of high plucks
    "night_in": (["Dsus", "Dsus", "D", "D", "Gadd9", "Gadd9", "D", "D"], "bell", None, True),
    "night_v": (["D", "Bm", "G", "A", "D", "Bm", "Gadd9", "Asus"], "bell", None, True),
    "night_ch": (["G", "D", "Em", "A", "G", "D", "Asus", "D"], "bell", None, True),
    "night_br": (["Bm", "G", "Bm", "G", "Em", "Em", "Asus", "A"], "bell", None, False),
    "night_out": (["Gadd9", "D", "Gadd9", "D", "Asus", "Asus", "D", "D"], "bell", None, True),
    # the storm's way in and out
    "storm_in": (["Bm", "Bm", "C", "C", "Bm", "Bm", "F#", "F#"], "reed", None, False),
    "storm_out": (["Em", "Em", "C", "C", "Bm", "Bm", "F#", "Bm"], "reed", None, False),
    "t1": (THEME_CHORDS[:8], "whistle", theme_bars(0, 8), True),
    "t2": (THEME_CHORDS[8:], "whistle", theme_bars(8, 16), True),
}


# The weather's songs, each played through in its form, then the next (audio/music.gd: the weather turning, the band
# heads for the song's outro and the next song's the new weather's). All in D and its B minor at 112, so a strike
# can turn any of them into the fight on the beat.
SONGS = {
    "fair": ["fair_in", "fair_v1", "fair_v2", "t1", "t2", "fair_v1", "fair_br", "t1", "t2", "fair_out"],
    "rain": ["rain_in", "rain_v", "rain_v", "rain_ch", "rain_v", "rain_br", "rain_ch", "rain_ch", "rain_out"],
    "fog": ["fog_in", "fog_v", "fog_v", "fog_br", "fog_v", "fog_out"],
    "night": ["night_in", "night_v", "night_ch", "night_v", "night_br", "night_ch", "night_out"],
    "storm": ["storm_in", "s1", "s2", "s3", "s1", "s2", "storm_out"],
}
# Each song's sound: how the guitar's played ("arp" picked, "muted" in the rain, "bells" in the fog, "harp" at night),
# the second melody's instrument, and the weather's own layers it carries (the rest of the song's layers it has
# all: the pad, the bass, the guitar, the lead and its counter-melody, the climax, her speed's drums, the fill, the
# birds'). The theme's halves, the storm's middle and the fight's passages have every layer.
STYLE = {
    "fair": ("arp", "reed", []),
    "rain": ("muted", "whistle", ["rain"]),
    "fog": ("bells", "bell", ["night"]),
    "night": ("harp", "whistle", ["night"]),
    "storm": ("arp", "reed", ["rain", "storm", "gale", "pound", "tension", "deep"]),
}
SONG_STEMS = ("pad", "bass", "pick", "lead", "alt", "high", "run", "fill", "pulse", "glint")


def _song_of(name):
    for song, form in SONGS.items():
        if name in form and not name.startswith("t") and not (song == "storm" and name in ("s1", "s2", "s3")):
            return song
    return ""


def _role(name):
    for r in ("in", "out", "br", "ch"):
        if name.endswith("_" + r):
            return {"in": "intro", "out": "outro", "br": "bridge", "ch": "chorus"}[r]
    return "verse"


SCALE = (2, 4, 6, 7, 9, 11, 1)      # D major (and B minor): the notes a tune walks on between chord tones


def tune(prog, seed, lo, hi, density=1, rest_first=True):
    """A melody over `prog` (a chord a bar): chord tones on the strong beats, steps between, a two-bar rhythm said and
    answered, home on the last chord's root. density 0 sparse (long notes, rests), 1 a tune, 2 busier. In eighths."""
    rng = np.random.default_rng(seed)
    rhythms = {0: [[8], [-4, 4], [6, 2], [-2, 6], [4, -4]],
               1: [[2, 2, 4], [3, 1, 4], [-2, 2, 2, 2], [4, 2, 2], [2, 6], [-4, 2, 2]],
               2: [[1, 1, 2, 2, 2], [2, 1, 1, 4], [2, 2, 2, 2], [3, 1, 2, 2], [1, 1, 1, 1, 4]]}[density]
    motif = [rhythms[rng.integers(len(rhythms))], rhythms[rng.integers(len(rhythms))]]
    out = []
    prev = (lo + hi) // 2
    for b, c in enumerate(prog):
        tones = sorted({m % 12 for m in CH[c]})
        if b == len(prog) - 1:
            pattern = [8]
        elif b in (0, 1, 4, 5):
            pattern = motif[b % 2]
        else:
            pattern = rhythms[rng.integers(len(rhythms))]
        if b == 0 and rest_first and pattern[0] > 0:
            pattern = [-pattern[0]] + pattern[1:]
        for k, ln in enumerate(pattern):
            if ln < 0:
                out.append((None, -ln))
                continue
            strong = k == 0 or b == len(prog) - 1
            pool = tones if strong else SCALE
            if b == len(prog) - 1:
                pool = [ROOT[c] % 12]
            cands = [m for m in range(lo, hi + 1) if m % 12 in pool]
            if not cands:
                cands = [prev]
            step = int(rng.integers(-3, 4))
            target = prev + step
            m = min(cands, key=lambda x: (abs(x - target), rng.random()))
            out.append((m, ln))
            prev = m
    return out


def sea():
    q = 60.0 / FIGHT_BPM
    e, s, bar = q / 2, q / 4, 4 * q
    arp = [0, 2, 3, 4, 3, 2, 3, 2]
    for name, (chords, lead_inst, lead, bright) in SEA.items():
        prog = chords if len(chords) == 8 else [c for c in chords for _ in (0, 1)]
        song = _song_of(name)
        style, alt_inst, colors = STYLE.get(song, ("arp", "reed", []))
        has = SEA_STEMS if not song else SONG_STEMS + tuple(colors)
        T = Stems({k: Track(len(prog) * bar, True) for k in has})
        seed = sum(ord(ch) for ch in name)
        if lead is None:
            lo, hi = (69, 86) if lead_inst != "reed" else (62, 79)
            lead = tune(prog, seed, lo, hi, density=0 if song == "fog" or _role(name) in ("intro", "outro") else 1)
        for b, c in enumerate(prog):
            t = b * bar
            v = CH[c]
            root = ROOT[c] + 12
            # pick: the guitar, eighths, leaning on 1 and 3 (a slow sway); muted in the rain; bells in the fog; a harp
            # of high plucks at night
            if style == "muted":
                for i, j in enumerate(arp):
                    T["pick"].add(pluck(v[min(j, len(v) - 1)], 0.5, bright=0.2, decay=0.8, mute=0.45, var=i % 3),
                                  t + i * e, -0.25, 0.3 if i in (0, 4) else 0.22)
            elif style == "bells":
                for k, at in ((0, 0.0), (1, 2.0)):
                    tone = v[-1 - (b + k) % 3]
                    T["pick"].add(bell(tone + 12 if tone + 12 < 90 else tone, 3.5), t + at * q, 0.3 - 0.6 * k, 0.16)
            elif style == "harp":
                for i, j in enumerate((0, 2, 3, 4)):
                    tone = v[min(j, len(v) - 1)] + 12
                    T["pick"].add(pluck(tone, 2.2, bright=0.25, pos=0.15, decay=2.0, var=i % 3), t + i * q, -0.2,
                                  0.22 if i == 0 else 0.16)
            else:
                for i, j in enumerate(arp):
                    T["pick"].add(pluck(v[min(j, len(v) - 1)], 1.4, bright=0.35, decay=1.3, var=i % 3), t + i * e,
                                  -0.25, 0.28 if i in (0, 4) else 0.2)
            # bass: the root long on 1, the fifth on the and of 3; in the fight's own, a riff driving the eighths
            if name.startswith("f"):
                for i, iv in enumerate((0, 0, 12, 0, 7, 0, 12, 7)):
                    T["bass"].add(pluck(root + iv, 0.32, bright=0.3, pos=0.22, decay=0.8, mute=0.35, var=i % 3),
                                  t + i * e, 0.0, 0.42 if i in (0, 4) else 0.32)
            else:
                T["bass"].add(pluck(root, 2.2, bright=0.12, pos=0.3, decay=1.8), t, 0.0, 0.5)
                T["bass"].add(pluck(root + 7, 1.2, bright=0.12, pos=0.3, decay=1.2), t + 2.5 * q, 0.0, 0.28)
            # rain: the patter (sixteenths, soft) and a muted low pulse under it
            for i in range(16):
                T["rain"].add(shaker(), t + i * s, 0.4 if i % 2 else -0.3, 0.07 if i % 4 == 2 else 0.04)
            for i in range(8):
                T["rain"].add(pluck(root, 0.25, bright=0.1, pos=0.25, decay=0.6, mute=0.65, var=i % 3), t + i * e,
                              -0.05, 0.16 if i % 2 == 0 else 0.1)
            # storm: the war drum half-time (1, the and of 3), ghosts between
            T["storm"].add(war_drum(low=0.9), t, 0.0, 0.5)
            T["storm"].add(war_drum(low=0.9), t + 2.5 * q, 0.0, 0.35)
            T["storm"].add(frame_drum(), t + 3.5 * q, 0.1, 0.12)
            # run: under way, running hard: the frame drum's eighths, the shaker, the bass pushing
            for i in range(8):
                T["run"].add(frame_drum(), t + i * e, 0.0, 0.32 if i in (0, 4) else (0.2 if i in (2, 6) else 0.1))
                T["run"].add(shaker(), t + i * e, 0.4, 0.08 if i % 2 else 0.05)
                T["run"].add(pluck(root, 0.3, bright=0.15, pos=0.25, decay=0.7, mute=0.55, var=i % 3), t + i * e,
                             -0.05, 0.22 if i % 2 == 0 else 0.14)
            # night: a bell on a chord tone, high, twice a bar
            for k, at in ((b % 4, 0.5), ((b + 2) % 4, 2.5)):
                T["night"].add(bell(v[-1 - k % 3] + 24 if v[-1 - k % 3] + 24 < 96 else v[-1 - k % 3] + 12, 3.0),
                               t + at * q, 0.35 if k % 2 else -0.35, 0.1)
        for c, b0, n in _runs(prog):
            t, d = b0 * bar, n * bar
            T["pad"].add(pad(PAD[c], d, attack=1.2, release=1.6, bright=0.25, seed=110 + b0), t, 0.0, 0.24)
            T["storm"].add(bowed(ROOT[c] + 12, d * 0.97, attack=1.0, release=1.0, bright=0.2, seed=b0), t, -0.1, 0.3)
            T["storm"].add(sub_swell(d, ROOT[c] if ROOT[c] < 36 else ROOT[c] - 12, 1.0), t, 0.0, 0.3)
        lead_play = {"whistle": whistle, "reed": reed, "bell": lambda m, d: bell(m, max(d * 1.6, 1.2))}[lead_inst]
        melody(T["lead"], lead, 0.0, e, lead_play, 0.1, 0.32 if lead_inst != "bell" else 0.2,
               legato=0.94, octave=1 if lead_inst == "bell" and lead and max(m or 0 for m, ln in lead) < 80 else 0)
        # alt: a second melody (the arrangement trades it with the lead from one time through to the next)
        alt_play = {"whistle": whistle, "reed": reed, "bell": lambda m, d: bell(m, max(d * 1.6, 1.2))}[alt_inst]
        alo, ahi = (62, 76) if alt_inst == "reed" else (71, 88)
        melody(T["alt"], tune(prog, seed + 97, alo, ahi, density=0 if song in ("fog", "night") else 1), 0.0, e,
               alt_play, -0.15, 0.26 if alt_inst != "bell" else 0.18, legato=0.95)
        # high: the lead an octave up on the whistle, the concertina an octave under it (the climax)
        melody(T["high"], lead, 0.0, e, whistle, 0.15, 0.26, legato=0.92, octave=1 if lead_inst == "reed" else 0)
        melody(T["high"], lead, 0.0, e, reed, -0.2, 0.22, legato=0.96, octave=-1 if lead_inst == "whistle" else 0)
        # the fish's layers, on these same chords
        for b, c in enumerate(prog):
            t = b * bar
            r = ROOT[c] + 12
            # pulse (birds working): the bass ticking over muted, soft; glint: the theme's first notes in the bells
            for i in range(8):
                T["pulse"].add(pluck(r + (12 if i == 5 else 0), 0.28, bright=0.15, pos=0.25, decay=0.8, mute=0.6,
                                     var=i % 3), t + i * e, -0.05, 0.36 if i in (0, 3) else 0.22)
                T["pulse"].add(shaker(), t + i * e, 0.45, 0.07 if i % 2 else 0.045)
            if b % 2 == 0:
                for k, m in enumerate((81, 86, 90) if b % 4 == 0 else (83, 86, 88)):
                    T["glint"].add(bell(m, 3.0), t + (1.5 + k) * q, 0.4 if k % 2 else -0.3, 0.11)
            # beat: the heartbeat on 1 and 3, the muted bass eighths, the last up a step
            for k in range(2):
                T["beat"].add(heartbeat(), t + k * 2 * q, 0.0, 0.8 if k == 0 else 0.55)
                T["beat"].add(heartbeat(), t + k * 2 * q + 0.16, 0.0, 0.5 if k == 0 else 0.34)
            for i in range(8):
                T["beat"].add(pluck(r + (12 if i in (3, 6) else 0), 0.3, bright=0.2, pos=0.25, decay=0.9, mute=0.55,
                                    var=i % 3), t + i * e, -0.05, 0.4 if i % 2 == 0 else 0.28)
            # drive: the war drum on 1, the and of 2 and 3; boots on 2 and 4 with a clap; the shaker's sixteenths;
            # a fill every other bar
            for i, g in [(0, 1.0), (3, 0.6), (4, 0.85), (7, 0.45)]:
                T["drive"].add(war_drum(), t + i * e, 0.0, 0.5 * g)
            for k in (1, 3):
                T["drive"].add(stomp(), t + k * q, 0.05, 0.38)
                T["drive"].add(clap(), t + k * q + 0.004, 0.25, 0.14)
            for i in range(16):
                T["drive"].add(shaker(), t + i * s, 0.45, 0.1 if i % 4 == 2 else 0.05)
            if b % 2 == 1:
                for i in range(4):
                    T["drive"].add(war_drum(low=1.25 + 0.12 * i), t + 3 * q + i * s, 0.15 - 0.1 * i, 0.2 + 0.07 * i)
            # tension: one high note picked fast over the chord (its ninth, the flat ninth over F#)
            for i in range(16):
                T["tension"].add(pluck(TENSE[c], 0.2, bright=0.6, pos=0.22, decay=0.4, mute=0.4, var=i % 3),
                                 t + i * s, 0.4, 0.12 + 0.06 * (i % 4 == 0))
            # pound: the whole drum section (his runs, the leader, the race's last minute, a storm): the war drums on
            # every eighth, the toms falling down the last beat, boots and claps, a crash every fourth bar
            for i, g in enumerate((1.0, 0.5, 0.7, 0.5, 0.9, 0.5, 0.75, 0.6)):
                T["pound"].add(war_drum(low=0.95), t + i * e, 0.0, 0.42 * g)
            T["pound"].add(war_drum(low=0.7), t, 0.0, 0.45)
            for i in range(4):
                T["pound"].add(war_drum(low=1.3 + 0.1 * i), t + 3 * q + i * s, 0.3 - 0.2 * i, 0.24 + 0.05 * i)
            for k in (1, 3):
                T["pound"].add(stomp(), t + k * q, -0.05, 0.42)
                T["pound"].add(clap(), t + k * q + 0.003, 0.3, 0.2)
            if b % 4 == 0:
                T["pound"].add(crash(2.0), t, 0.25, 0.16)
            # gale: the storm's: the drums rolling up to each second bar, the strings' tremolo grinding a semitone
            if b % 2 == 1:
                for i in range(16):
                    T["gale"].add(frame_drum(), t + i * s, 0.1 * (i % 2 - 0.5), 0.08 + 0.022 * i)
                T["gale"].add(war_drum(low=0.8), t + 4 * q - 0.01, 0.0, 0.0)
            # heavy: a giant's: the biggest drum on 1 and the and of 3
            T["heavy"].add(war_drum(low=0.72), t, 0.0, 0.5)
            T["heavy"].add(war_drum(low=0.72), t + 2.5 * q, 0.0, 0.3)
        for c, b0, n in _runs(prog):
            t, d = b0 * bar, n * bar
            T["tension"].add(line_sing(TENSE[c] + 12, d * 0.95, attack=0.6, release=0.6), t, 0.2, 0.07)
            T["deep"].add(bowed(ROOT[c] + 12, d * 0.97, attack=0.7, release=0.8, bright=0.25, seed=b0 + 3), t, -0.15,
                          0.4)
            T["deep"].add(sub_swell(d, ROOT[c] - 12 if ROOT[c] >= 36 else ROOT[c], 1.0), t, 0.0, 0.3)
            T["heavy"].add(bowed(ROOT[c], d * 0.97, attack=0.9, release=0.9, bright=0.15, seed=b0 + 7), t, 0.0, 0.42)
            # the gale's strings: a tremolo (the bow sawing sixteenths) on the chord's ninth and a semitone over it
            trem = 0.55 + 0.45 * np.abs(np.sin(np.pi * 2.0 * FIGHT_BPM / 60.0 * np.arange(int((d + 0.8) * SR)) / SR))
            for k, m in enumerate((TENSE[c] - 12, TENSE[c] - 11)):
                v = bowed(m, d * 0.97, attack=0.5, release=0.8, bright=0.6, vib=0.008, seed=b0 + 11 + k)
                T["gale"].add(v * trem[:len(v)], t, -0.3 + 0.6 * k, 0.16)
            T["gale"].add(howl(d, seed=b0), t, 0.0, 0.2)
        # fill: a drum fill over the passage's last two beats, into the next (audio/music.gd opens it now and then)
        t = (len(prog) - 1) * bar + 2 * q
        for i in range(8):
            T["fill"].add(frame_drum() if i < 4 else war_drum(low=1.3 - 0.06 * i), t + i * s, 0.15 * (i % 2 - 0.5),
                          0.18 + 0.05 * i)
        stems("sea_" + name, dict(T), FIGHT_BPM, 4, len(prog), level=0.95, wet=0.26 if song != "fog" else 0.36,
              rt=2.0 if song != "fog" else 2.8, chords=prog)
        if song:
            CUES["sea_" + name]["song"] = song
            CUES["sea_" + name]["role"] = _role(name)
        CUES["sea_" + name]["bright"] = bright
        if name.startswith("s") and len(name) == 2 or name.startswith("storm_"):
            CUES["sea_" + name]["storm"] = True
        if name.startswith("f"):
            CUES["sea_" + name]["fight"] = True
        if name == "t1":
            CUES["sea_" + name]["then"] = "sea_t2"
        if name == "t2":
            CUES["sea_" + name]["after_only"] = True


# --- THE DECK WHISTLE: a tin whistle you play by hand (crew/hands.gd), every note it can sound -------------------

WHISTLE = (62, 90)


def deck_whistle():
    """One note each, D4 to F#6, a few seconds held (you hold the mouse, it sounds; you let go, it stops short)."""
    files = []
    for m in range(WHISTLE[0], WHISTLE[1] + 1):
        tr = Track(3.2, False)
        tr.add(whistle(m, 3.0, vib=0.005, breath=0.06), 0.0, 0.0, 1.0)
        name = "note_%d" % m
        write(name, master(tr, wet=0.12, rt=1.2, wow=0.0), 0.7, comp=0.8)
        files.append(name)
    cue("whistle", "notes", files, low=WHISTLE[0], high=WHISTLE[1])


def rivals_stings():
    # THEIR FISH ON: low, two notes falling a third, a far drum (somebody else's luck)
    tr = Track(3.5, False)
    tr.add(bowed(38, 0.5, attack=0.05, release=0.5, bright=0.35), 0.0, -0.1, 0.5)
    tr.add(bowed(35, 1.2, attack=0.05, release=1.0, bright=0.35), 0.54, -0.1, 0.55)
    tr.add(war_drum(low=0.8), 0.0, 0.0, 0.35)
    tr.add(war_drum(low=0.8), 0.54, 0.0, 0.45)
    write("their_on", master(tr, wet=0.3, rt=2.0), 0.55)
    cue("their_on", "sting", ["their_on"], hit=0.0)
    # TOOK THE LEAD: D, A, a whistle up
    tr = Track(3.5, False)
    tr.strum(CH["D"], 0.0, spread=0.01, dur=0.5, gain=0.8, bright=0.6, decay=1.0)
    tr.strum(CH["A"], 0.29, spread=0.01, dur=1.6, gain=0.8, bright=0.6, decay=1.4)
    tr.add(frame_drum(), 0.0, 0.0, 0.6)
    melody(tr, [(74, 1), (78, 1), (81, 1), (86, 6)], 0.0, 0.1, whistle, 0.1, 0.4)
    write("lead_up", master(tr, wet=0.24), 0.65)
    cue("lead_up", "sting", ["lead_up"], hit=0.0)
    # LOST IT: Dm sinking to B flat, the concertina falling
    tr = Track(4.0, False)
    tr.strum(CH["Dm"], 0.0, spread=0.03, dur=0.8, gain=0.7, bright=0.35, decay=1.2)
    tr.strum([46, 53, 58, 62, 65], 0.45, spread=0.04, dur=2.2, gain=0.65, bright=0.3, decay=1.6)
    melody(tr, [(69, 3), (65, 3), (62, 8)], 0.0, 0.14, reed, -0.1, 0.32, legato=0.97)
    write("lead_down", master(tr, wet=0.28, rt=2.0), 0.6)
    cue("lead_down", "sting", ["lead_down"], hit=0.0)


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
    cue("countdown", "sting", ["countdown"], hit=COUNT)


def stings():
    # WIN: G, A, D, and the theme's first notes on the whistle up to the top A
    tr = Track(6.0, False)
    for t, c in [(0.0, "G"), (0.42, "A"), (0.84, "D")]:
        tr.strum(CH[c], t, spread=0.014, dur=2.6 if c == "D" else 0.6, gain=1.0, bright=0.6, decay=1.6)
    tr.add(frame_drum(), 0.84, 0.0, 0.8)
    tr.add(pad(PAD["D"], 2.4, attack=0.1, release=2.0, bright=0.4, seed=11), 0.84, 0.0, 0.35)
    melody(tr, [(69, 2), (74, 2), (78, 4), (81, 10)], 0.0, 0.105, whistle, 0.1, 0.5)     # (the theme's opening)
    write("win", master(tr, wet=0.25), 0.8)
    cue("win", "sting", ["win"], hit=0.0)
    # LOSE: down through Bm, G, Em, F# and home to Bm, soft
    tr = Track(6.5, False)
    for t, c, d in [(0.0, "Bm", 0.9), (0.8, "G", 0.9), (1.6, "Em", 0.9), (2.4, "F#", 0.9), (3.3, "Bm", 2.8)]:
        tr.strum(CH[c], t, spread=0.03, dur=d + 0.6, gain=0.75, bright=0.35, decay=1.6)
    melody(tr, [(66, 6), (64, 6), (62, 6), (61, 6), (59, 14)], 0.0, 0.135, reed, -0.1, 0.4, legato=0.97)
    tr.add(pad(PAD["Bm"], 2.2, attack=0.4, release=2.0, seed=12), 3.3, 0.0, 0.3)
    write("lose", master(tr, wet=0.28, rt=2.0), 0.7)
    cue("lose", "sting", ["lose"], hit=0.0)
    # TIE: Dsus, Gadd9, and left hanging on Asus with a two-note shrug
    tr = Track(5.5, False)
    for t, c, d in [(0.0, "Dsus", 0.9), (0.75, "Gadd9", 0.9), (1.5, "Asus", 2.8)]:
        tr.strum(CH[c], t, spread=0.02, dur=d + 0.5, gain=0.85, bright=0.5, decay=1.6)
    tr.add(pluck(81, 0.8, bright=0.6, pos=0.25, decay=0.8), 2.1, 0.35, 0.35)
    tr.add(pluck(79, 1.6, bright=0.6, pos=0.25, decay=1.0), 2.45, 0.35, 0.35)
    tr.add(pad(PAD["Asus"], 2.4, attack=0.4, release=2.0, seed=13), 1.5, 0.0, 0.3)
    write("tie", master(tr, wet=0.26), 0.72)
    cue("tie", "sting", ["tie"], hit=0.0)


if __name__ == "__main__":
    title()
    sea()
    moments()
    strike()
    fight_in()
    thunder()
    handoffs()
    rivals_stings()
    deck_whistle()
    countdown()
    stings()
    write_cues()
