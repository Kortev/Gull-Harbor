"""Bluefin's world sounds (not the music): the sea, the wind, the rain, the harbour, the birds, the boat's creaks and
knocks, made here from noise and sines (no samples) and written to ../audio/bank/e_*.ogg for audio/sfx.gd's table
(the "amb." events) and audio/ambience.gd to play on the Effects bus.

The sound: lo-fi but real. Mono at 22 kHz, everything low-passed round 7 kHz with a touch of saturation, the far
things darker and wetter (a made-up outdoor tail), so it sits with the PS1 look and the band in the fish shed and is
never chiptune-bright.

Beds (loops, made round: shaped in the frequency domain, so the end runs into the start with no seam; every event in
them wraps past the end back to the start):
  e_sea_open   the open sea's wash, swells and the odd crest breaking
  e_sea_calm   a calm sea's chuckles and bubbles
  e_lap        water lapping and gurgling at her hull (or a quay) when she's lying still
  e_rush       water rushing past her hull under way
  e_wind_low   a breeze;  e_wind_high  a gale, whistling
  e_rigging    the wind singing in her stays and outriggers
  e_rain       rain on the sea and an open deck;  e_rain_roof  drumming on the T-top over you, dripping off its edge
  e_harbour    a small town over the water: far traffic, an engine or two, voices, a clank
  e_night      the shore at night: crickets, the water
  e_pump       the bilge pump: its motor and the water spurting over the side
  e_exhaust    her wet exhaust burbling at the transom
One-shots:
  e_gull_1..4 herring gulls; e_tern_1..2 far seabirds; e_halyard_1..3 a halyard slapping a mast;
  e_creak_1..3 a mooring line creaking on its cleat; e_fender_1..2 a fender squeaking; e_bell_1..3 the bell buoy;
  e_voice_1..3 a voice across the harbour; e_engine_far a boat going by out there; e_knock_1..4 gear knocking about;
  e_clink_1..3 metal clinking; e_groan_1..3 her hull groaning in a seaway; e_slap_1..4 a sea slapping her hull;
  e_blow_1..2 a whale blowing, far off; e_dolphin_1..2 dolphins; e_foghorn the lighthouse's horn

Run: python tools/ambience.py   (numpy, scipy, soundfile; under a minute). Then import them (the editor, or
godot --headless --path . --import)."""
import os

import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loudness  # noqa: E402  (tools/loudness.py: BS.1770, the same yardstick the game's mix is checked by)

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "bank")
RNG = np.random.default_rng(1983)
## Every file's loudness (LUFS): a bed at the bank's own median, a one-shot a little over it (it's heard alone, short);
## no peak over CEILING dBFS (a bed's softly limited under it, a one-shot turned down to it).
BED_LUFS = -20.0
SHOT_LUFS = -18.0
CEILING = -3.0       # (Vorbis overshoots a sharp edge by a dB or so: room for it under -1)


# --- tools --------------------------------------------------------------------------------------------------------

def secs(s):
    return int(round(s * SR))


def t_axis(n):
    return np.arange(n) / SR


def shaped(n, shape):
    """Noise n samples long, its spectrum `shape(freqs)` (magnitude): circular, so it loops with no seam."""
    spec = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    x = np.fft.irfft(spec * shape(f), n)
    return x / max(1e-9, np.std(x))


def filt_loop(x, shape):
    """x filtered by the magnitude `shape(freqs)`, circularly (a loop stays a loop)."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x) * shape(f), len(x))


def band(lo, hi, slope=2.0):
    """A soft band-pass magnitude: flat lo..hi, rolling off `slope` (orders) outside."""
    def shape(f):
        f = np.maximum(f, 1.0)
        return 1.0 / (1.0 + (lo / f) ** (2 * slope)) ** 0.5 / (1.0 + (f / hi) ** (2 * slope)) ** 0.5
    return shape


def peak(fc, width):
    """A narrow resonance at fc, `width` Hz wide (Gaussian, magnitude)."""
    return lambda f: np.exp(-0.5 * ((f - fc) / width) ** 2)


def env_loop(n, lo_period, hi_period, depth=1.0, k=6):
    """A slow wander 0..1 n samples long that loops: k cosines with whole numbers of cycles in the loop."""
    t = np.arange(n) / n
    e = np.zeros(n)
    length = n / SR
    for _ in range(k):
        period = RNG.uniform(lo_period, hi_period)
        cycles = max(1, int(round(length / period)))
        e += RNG.uniform(0.5, 1.0) * np.cos(2 * np.pi * cycles * t + RNG.uniform(0, 2 * np.pi))
    e = (e - e.min()) / max(1e-9, e.max() - e.min())
    return 1.0 - depth + depth * e


def put(dst, at, x, wrap=True):
    """x added into dst from sample `at` (wrapping round the end into the start for a loop)."""
    n = len(dst)
    at = int(at)
    if wrap:
        idx = (at + np.arange(len(x))) % n
        np.add.at(dst, idx, x)
    else:
        end = min(n, at + len(x))
        if end > at:
            dst[at:end] += x[:end - at]


def lp(x, cut, order=2):
    b, a = signal.butter(order, min(cut, SR * 0.49) / (SR * 0.5), "low")
    return signal.lfilter(b, a, x)


def hp(x, cut, order=2):
    b, a = signal.butter(order, cut / (SR * 0.5), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR * 0.5), min(hi, SR * 0.49) / (SR * 0.5)], "band")
    return signal.lfilter(b, a, x)


def reson(x, fc, decay):
    """x through a two-pole resonator at fc Hz ringing down 60 dB in about `decay` s."""
    r = np.exp(-6.9 / (decay * SR))
    w = 2 * np.pi * fc / SR
    return signal.lfilter([1.0 - r], [1.0, -2.0 * r * np.cos(w), r * r], x)


def adsr(n, attack, release, shape=1.0):
    """An envelope n samples long: up over `attack` s, then down exponentially over the rest (`release` s to -60)."""
    t = t_axis(n)
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0) ** shape
    d = np.exp(-6.9 * np.maximum(t - attack, 0.0) / max(release, 1e-4))
    return a * d


def bubble(f0=None, dur=None, amp=1.0):
    """A bubble's plip: a sine rising as it rings down (the classic drop in water)."""
    f0 = f0 or RNG.uniform(400, 1400)
    dur = dur or RNG.uniform(0.02, 0.08)
    n = secs(dur)
    t = t_axis(n)
    f = f0 * (1.0 + RNG.uniform(2.0, 6.0) * t / dur * 0.3)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return amp * np.sin(ph) * np.exp(-t / (dur * 0.3))


def tail(x, rt=0.9, wet=0.2, dark=3000.0):
    """x with an outdoor tail (its echo off the water and the far shore): a made-up decaying noise, darkened."""
    n = secs(rt)
    ir = RNG.standard_normal(n) * np.exp(-6.9 * t_axis(n) / rt)
    ir = lp(ir, dark)
    ir[: secs(0.012)] = 0.0       # (the first reflection a little after)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = signal.fftconvolve(np.concatenate([x, np.zeros(n)]), ir)[: len(x) + n]
    return np.concatenate([x, np.zeros(n)]) * (1.0 - wet) + y * wet * 1.4


def tail_loop(x, rt=0.9, wet=0.2, dark=3000.0):
    """The tail for a loop: the echo wraps round from the end into the start."""
    y = tail(x, rt, wet, dark)
    out = y[: len(x)].copy()
    out[: len(y) - len(x)] += y[len(x):]
    return out


def lofi(x, cut=7000.0, drive=1.3, loop=False):
    """The lo-fi finish: low-passed (circularly for a loop) and softly saturated."""
    if loop:
        x = filt_loop(x, band(20.0, cut, 1.5))
    else:
        x = lp(hp(x, 25.0), cut)
    x = x / max(1e-9, np.max(np.abs(x)))
    return np.tanh(drive * x) / np.tanh(drive)


def fade_ends(x, a=0.004, r=0.03):
    n = len(x)
    e = np.ones(n)
    na, nr = secs(a), secs(r)
    e[:na] = np.linspace(0, 1, na)
    e[n - nr:] *= np.linspace(1, 0, nr)
    return x * e


def write(name, x, level=0.8, loop=False):
    """To ../audio/bank/<name>.ogg, at its loudness (BED_LUFS for a loop, SHOT_LUFS for a one-shot, measured as
    tools/loudness.py does), its peaks under CEILING; a one-shot trimmed of its silent tail. (`level` is only the
    working scale before that: the game's levels and audio/sfx.gd's gains say how loud each is in the mix.)"""
    os.makedirs(OUT, exist_ok=True)
    x = np.asarray(x, dtype=np.float64)
    x = x / max(1e-9, np.max(np.abs(x))) * level
    if not loop:
        alive = np.nonzero(np.abs(x) > 0.002)[0]
        if len(alive):
            x = x[: min(len(x), alive[-1] + secs(0.05))]
        x = fade_ends(x)
    ceiling = 10.0 ** (CEILING / 20.0)
    for _ in range(4):        # (limiting a bed takes a little loudness off it: measured again)
        x = x * 10.0 ** (((BED_LUFS if loop else SHOT_LUFS) - loudness.integrated(x, SR)) / 20.0)
        if np.max(np.abs(x)) <= ceiling:
            break
        if not loop:
            x = x / np.max(np.abs(x)) * ceiling
            break
        x = np.tanh(x / ceiling) * ceiling
    path = os.path.join(OUT, name + ".ogg")
    data = np.ascontiguousarray(x.astype(np.float32))
    for tries in range(20):
        try:
            with sf.SoundFile(path, "w", SR, 1, format="OGG", subtype="VORBIS", compression_level=0.6) as f:
                for i in range(0, len(data), 4096):
                    f.write(data[i:i + 4096])
            break
        except sf.LibsndfileError:
            if tries == 19:
                raise
            import time
            time.sleep(0.5)
    seam = abs(x[-1] - x[0]) if loop else 0.0
    print("%-14s %5.1f s %4d KB%s" % (name, len(x) / SR, os.path.getsize(path) // 1024,
                                      "  loop (seam %.3f)" % seam if loop else ""))


# --- the beds -----------------------------------------------------------------------------------------------------

def sea_open():
    n = secs(16.0)
    wash = shaped(n, lambda f: band(70, 1800, 1.5)(f) / np.maximum(f, 60) ** 0.35)
    wash *= env_loop(n, 3.5, 8.0, 0.75)
    deep = shaped(n, band(35, 160, 2.0)) * env_loop(n, 5.0, 9.0, 0.8) * 0.7
    out = wash + deep
    for _ in range(7):        # crests breaking near and far
        m = secs(RNG.uniform(1.2, 2.6))
        hiss = bp(RNG.standard_normal(m), 500, 4500) * adsr(m, RNG.uniform(0.15, 0.4), RNG.uniform(0.8, 1.8))
        put(out, RNG.integers(0, n), hiss * RNG.uniform(0.6, 1.3))
    out = tail_loop(out, 1.2, 0.15, 2500)
    write("e_sea_open", lofi(out, 6500, loop=True), 0.75, loop=True)


def sea_calm():
    n = secs(12.0)
    out = shaped(n, band(120, 900, 1.5)) * env_loop(n, 2.5, 6.0, 0.6) * 0.25
    for _ in range(70):       # little chuckles
        m = secs(RNG.uniform(0.04, 0.14))
        c = reson(RNG.standard_normal(m) * adsr(m, 0.01, 0.06), RNG.uniform(250, 900), 0.06)
        put(out, RNG.integers(0, n), c * RNG.uniform(0.05, 0.2))
    for _ in range(90):       # and bubbles
        put(out, RNG.integers(0, n), bubble(RNG.uniform(500, 1600), amp=RNG.uniform(0.1, 0.45)))
    out = tail_loop(out, 0.8, 0.2, 3000)
    write("e_sea_calm", lofi(out, 6500, loop=True), 0.6, loop=True)


def lap():
    n = secs(9.0)
    out = shaped(n, band(90, 600, 1.5)) * env_loop(n, 1.5, 3.5, 0.7) * 0.12
    k = 0.0
    while k < 9.0:
        at = secs(k)
        m = secs(0.25)
        thump = bp(RNG.standard_normal(m), 70, 320) * adsr(m, 0.02, 0.18)
        put(out, at, thump * RNG.uniform(0.6, 1.0))
        m = secs(0.5)
        wash = bp(RNG.standard_normal(m), 400, 3000) * adsr(m, 0.06, 0.35)
        put(out, at + secs(0.03), wash * RNG.uniform(0.15, 0.3))
        for _ in range(RNG.integers(3, 9)):
            put(out, at + secs(RNG.uniform(0.05, 0.6)), bubble(RNG.uniform(300, 900), amp=RNG.uniform(0.1, 0.35)))
        k += RNG.uniform(1.0, 2.4)
    out = tail_loop(out, 0.5, 0.15, 2500)
    write("e_lap", lofi(out, 6000, loop=True), 0.7, loop=True)


def rush():
    n = secs(8.0)
    hiss = shaped(n, lambda f: band(350, 5500, 1.5)(f) * (1.0 + 0.6 * peak(1400, 600)(f)))
    hiss *= env_loop(n, 0.15, 0.7, 0.35, k=12)
    wash = shaped(n, band(90, 450, 1.5)) * env_loop(n, 0.8, 2.5, 0.5) * 0.6
    out = hiss + wash
    for _ in range(60):
        put(out, RNG.integers(0, n), bubble(RNG.uniform(600, 2200), amp=RNG.uniform(0.1, 0.4)))
    write("e_rush", lofi(out, 6500, loop=True), 0.7, loop=True)


def wind_low():
    n = secs(16.0)
    out = shaped(n, lambda f: band(40, 650, 1.5)(f) / np.maximum(f, 40) ** 0.3) * env_loop(n, 2.5, 7.0, 0.65)
    whistle = shaped(n, peak(720, 35)) * env_loop(n, 1.5, 5.0, 1.0) * 0.15
    write("e_wind_low", lofi(out + whistle, 5000, loop=True), 0.7, loop=True)


def wind_high():
    n = secs(16.0)
    out = shaped(n, lambda f: band(60, 3200, 1.5)(f) / np.maximum(f, 60) ** 0.25) * env_loop(n, 1.0, 4.0, 0.55)
    for fc, w, g in [(430, 22, 0.5), (610, 30, 0.42), (880, 40, 0.32), (1260, 55, 0.22), (1720, 70, 0.14)]:
        out += shaped(n, peak(fc, w)) * env_loop(n, 0.8, 4.0, 1.0) ** 2 * g
    out = tail_loop(out, 0.7, 0.15, 3000)
    write("e_wind_high", lofi(out, 6000, drive=1.5, loop=True), 0.75, loop=True)


def rigging():
    n = secs(10.0)
    out = np.zeros(n)
    for fc, g in [(330, 1.0), (660, 0.3), (452, 0.7), (904, 0.2), (586, 0.35)]:
        out += shaped(n, peak(fc, 3.5)) * env_loop(n, 0.6, 3.0, 1.0) ** 1.5 * g
    out += shaped(n, band(200, 2000)) * env_loop(n, 0.5, 2.0, 0.6) * 0.15     # (the breath of it)
    out = tail_loop(out, 0.6, 0.2, 3000)
    write("e_rigging", lofi(out, 5000, loop=True), 0.6, loop=True)


def rain():
    n = secs(12.0)
    hiss = shaped(n, band(1200, 7000, 1.5)) * 0.35
    drops = np.zeros(n)
    count = 220 * 12
    idx = RNG.integers(0, n, count)
    np.add.at(drops, idx, np.minimum(RNG.exponential(1.0, count), 2.5) * RNG.choice([-1, 1], count))
    drops = filt_loop(drops, lambda f: band(1500, 7000, 1.0)(f) * 6.0)
    out = hiss + drops / max(1e-9, np.std(drops)) * 0.5
    for _ in range(400):       # the patter on the water: little plips
        put(out, RNG.integers(0, n), bubble(RNG.uniform(1200, 4000), RNG.uniform(0.01, 0.03), RNG.uniform(0.1, 0.5)))
    out *= env_loop(n, 1.5, 5.0, 0.2)
    write("e_rain", lofi(out, 7000, loop=True), 0.65, loop=True)


def rain_roof():
    n = secs(12.0)
    hits = np.zeros(n)
    count = 320 * 12
    idx = RNG.integers(0, n, count)
    np.add.at(hits, idx, np.minimum(RNG.exponential(1.0, count), 2.5))
    # (the T-top's panel ringing: a few broad modes, and the tick of each drop)
    roof = lambda f: (peak(190, 40)(f) * 1.0 + peak(430, 70)(f) * 0.8 + peak(780, 110)(f) * 0.6
                      + peak(1350, 220)(f) * 0.45 + band(2500, 6500)(f) * 0.25)
    out = filt_loop(hits, roof)
    out /= max(1e-9, np.std(out))
    out += shaped(n, band(800, 5000)) * 0.25
    k = 0.0
    while k < 12.0:            # dripping off its edge onto the deck
        m = secs(0.12)
        tok = reson(np.r_[1.0, np.zeros(m - 1)], RNG.uniform(900, 1500), 0.05) * 30
        put(out, secs(k), tok * RNG.uniform(0.4, 1.0))
        k += RNG.uniform(0.25, 0.9)
    out *= env_loop(n, 2.0, 5.0, 0.25)
    write("e_rain_roof", lofi(out, 6500, loop=True), 0.65, loop=True)


def harbour():
    n = secs(16.0)
    rumble = shaped(n, lambda f: band(35, 260, 2.0)(f)) * env_loop(n, 3.0, 8.0, 0.5)
    hum = (shaped(n, peak(52, 2.0)) * 0.5 + shaped(n, peak(104, 3.0)) * 0.3) * env_loop(n, 4.0, 8.0, 0.8)
    murmur = shaped(n, band(280, 1300, 2.0)) * env_loop(n, 0.25, 1.2, 1.0, k=14) ** 2 * 0.22
    out = rumble + hum + murmur
    for _ in range(3):         # a clank from the yard
        m = secs(1.0)
        c = sum(reson(np.r_[1.0, np.zeros(m - 1)], f, d) * g
                for f, d, g in [(620, 0.5, 1.0), (1540, 0.3, 0.6), (2790, 0.2, 0.4)])
        put(out, RNG.integers(0, n), lp(c, 1800) * 12 * RNG.uniform(0.3, 0.7))
    out = tail_loop(out, 1.6, 0.35, 1500)
    write("e_harbour", lofi(out, 3500, loop=True), 0.6, loop=True)


def night():
    n = secs(16.0)
    out = shaped(n, band(100, 700, 1.5)) * env_loop(n, 2.0, 6.0, 0.6) * 0.12
    for carrier, rate, g in [(4300, 0.55, 0.3), (4650, 0.8, 0.2), (3900, 0.45, 0.14), (4950, 1.1, 0.1)]:
        k = RNG.uniform(0, rate)
        while k < 16.0:
            for p in range(int(RNG.integers(2, 5))):     # a chirp: a few pulses
                m = secs(0.016)
                tt = t_axis(m)
                put(out, secs(k + p * 0.032), np.sin(2 * np.pi * carrier * tt) * np.sin(np.pi * tt / 0.016) ** 2 * g)
            k += rate * RNG.uniform(0.85, 1.15)
    out = tail_loop(out, 1.2, 0.35, 5000)
    write("e_night", lofi(out, 6500, loop=True), 0.5, loop=True)


def pump():
    n = secs(6.0)
    t = t_axis(n)
    f0 = round(116.0 * 6.0) / 6.0        # (whole cycles in the loop)
    motor = sum(np.sin(2 * np.pi * f0 * h * t + RNG.uniform(0, 6.28)) / h for h in range(1, 14))
    motor += 0.03 * np.sin(2 * np.pi * round(1750 * 6) / 6 * t)
    motor *= 1.0 + 0.1 * env_loop(n, 0.3, 1.0, 1.0)
    gush = shaped(n, band(200, 1800, 1.5)) * env_loop(n, 0.12, 0.5, 0.6, k=12)
    out = motor * 0.35 + gush * 0.6
    write("e_pump", lofi(out, 5000, loop=True), 0.6, loop=True)


def exhaust():
    n = secs(6.0)
    out = np.zeros(n)
    k = 0.0
    while k < 6.0:             # the burble: puffs of exhaust through water
        m = secs(0.09)
        puff = bp(RNG.standard_normal(m), 70, 500) * adsr(m, 0.008, 0.06)
        put(out, secs(k), puff * RNG.uniform(0.5, 1.0))
        if RNG.random() < 0.3:
            put(out, secs(k + 0.02), bubble(RNG.uniform(200, 500), 0.06, 0.4))
        k += RNG.uniform(0.06, 0.12)
    out += shaped(n, band(300, 1800)) * env_loop(n, 0.2, 0.8, 0.7, k=10) * 0.15
    write("e_exhaust", lofi(out, 4500, loop=True), 0.6, loop=True)


# --- one-shots ----------------------------------------------------------------------------------------------------

def call(contour, dur, harm=10, form=(2100, 3300), rough=0.25):
    """A bird's call: a harmonic tone along a pitch contour [(time 0..1, Hz)...], through two formants, rough."""
    n = secs(dur)
    t = t_axis(n)
    u = t / dur
    ts, fs = zip(*contour)
    f = np.interp(u, ts, fs) * (1.0 + 0.01 * np.sin(2 * np.pi * 7 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(h * ph) / h ** 0.8 * (h * f < SR * 0.45) for h in range(1, harm + 1))
    x *= 1.0 + rough * np.sin(2 * np.pi * 58 * t)
    y = reson(x, form[0], 0.01) + 0.6 * reson(x, form[1], 0.008) + 0.15 * x
    return y * adsr(n, 0.02, dur * 0.9, 0.5) * np.minimum(1.0, (dur - t) / 0.03 + 0.0)


def gulls():
    v = [
        [call([(0, 900), (0.3, 1500), (1, 760)], 0.42)],
        [call([(0, 1000), (0.4, 1400), (1, 900)], 0.22), None, call([(0, 950), (0.3, 1350), (1, 700)], 0.36)],
        [call([(0, 1300 - 40 * i), (0.5, 1500 - 50 * i), (1, 1000 - 40 * i)], 0.13) for i in range(6)],
        [call([(0, 1500), (1, 1100)], 0.09), call([(0, 1450), (1, 1050)], 0.09)],
    ]
    for i, parts in enumerate(v):
        out = np.zeros(secs(2.0))
        k = 0.0
        for p in parts:
            if p is None:
                k += 0.12
                continue
            put(out, secs(k), p, wrap=False)
            k += len(p) / SR + RNG.uniform(0.05, 0.1)
        write("e_gull_%d" % (i + 1), lofi(tail(out, 0.9, 0.22, 4000), 6500), 0.8)


def terns():
    for i in range(2):
        out = np.zeros(secs(1.2))
        put(out, 0, call([(0, 2300), (0.2, 2700), (1, 1900)], 0.28, harm=6, form=(2600, 4200), rough=0.4), wrap=False)
        if i == 1:
            put(out, secs(0.4), call([(0, 2400), (1, 2000)], 0.18, harm=6, form=(2600, 4200), rough=0.4), wrap=False)
        write("e_tern_%d" % (i + 1), lofi(tail(out, 1.2, 0.35, 3000), 5000), 0.7)


def ping(freqs, decays, gains, dur, strike=0.003):
    """A struck thing: its modes ringing down, the strike's tick on top."""
    n = secs(dur)
    imp = np.zeros(n)
    m = max(2, secs(strike))
    imp[:m] = RNG.standard_normal(m) * np.hanning(m)
    imp[0] += 1.0
    return sum(reson(imp, f, d) * g for f, d, g in zip(freqs, decays, gains))


def halyards():
    for i in range(3):
        f0 = RNG.uniform(650, 900)
        out = np.zeros(secs(1.5))
        hits = [0.0] + ([RNG.uniform(0.12, 0.3)] if i != 0 else []) + ([0.55] if i == 2 else [])
        for j, k in enumerate(hits):
            x = ping([f0, f0 * 2.76, f0 * 5.4, f0 * 8.9], [0.7, 0.4, 0.2, 0.1], [1.0, 0.6, 0.35, 0.15], 1.2)
            slap = bp(RNG.standard_normal(secs(0.04)), 300, 2500) * np.hanning(secs(0.04)) * 0.4
            put(out, secs(k), x * (0.6 ** j), wrap=False)
            put(out, secs(k), slap, wrap=False)
        write("e_halyard_%d" % (i + 1), lofi(tail(out, 1.0, 0.25, 4000), 6500), 0.7)


def stick_slip(dur, rates, modes, jitter=0.15):
    """Creaks and squeaks: a train of little slips at a rate wandering along `rates` [(0..1, per s)...], each
    ringing the thing's modes [(Hz, decay s, gain)]."""
    n = secs(dur)
    imp = np.zeros(n)
    k = 0.0
    while k < dur:
        u = k / dur
        rate = np.interp(u, *zip(*rates))
        imp[min(n - 1, secs(k))] += RNG.uniform(0.5, 1.0) * np.sin(np.pi * u) ** 0.5
        k += (1.0 / rate) * RNG.uniform(1 - jitter, 1 + jitter)
    return sum(reson(imp, f, d) * g for f, d, g in modes)


def creaks():
    for i in range(3):
        d = RNG.uniform(0.6, 1.2)
        x = stick_slip(d, [(0, 25), (0.4, RNG.uniform(60, 110)), (1, 30)],
                       [(RNG.uniform(320, 420), 0.03, 1.0), (RNG.uniform(780, 900), 0.02, 0.6), (1550, 0.01, 0.3)])
        write("e_creak_%d" % (i + 1), lofi(tail(x, 0.5, 0.15, 3500), 5500), 0.7)


def fenders():
    for i in range(2):
        d = RNG.uniform(0.5, 0.9)
        x = stick_slip(d, [(0, 160), (0.5, RNG.uniform(260, 380)), (1, 180)],
                       [(650, 0.02, 1.0), (1700, 0.012, 0.5), (140, 0.05, 0.6)], jitter=0.05)
        rub = bp(RNG.standard_normal(secs(d)), 80, 400) * np.hanning(secs(d)) * 0.03
        write("e_fender_%d" % (i + 1), lofi(tail(x + rub, 0.4, 0.15, 3500), 5000), 0.6)


def bells():
    ratios = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011]
    gains = [0.5, 1.0, 0.7, 0.45, 0.6, 0.3, 0.2, 0.15]
    decays = [5.5, 4.0, 3.2, 2.6, 2.0, 1.4, 1.2, 1.0]
    prime = 405.0
    for i in range(3):
        out = np.zeros(secs(6.5))
        hits = [(0.0, 1.0)] + ([(0.32, 0.45)] if i == 1 else []) + ([(0.0, 0.0)] if i == 0 else [])
        bright = [1.0, 1.4, 0.7][i]
        for k, g in hits:
            if g <= 0.0:
                continue
            x = ping([prime * r for r in ratios], decays, [gg * (bright if r > 1.6 else 1.0) for gg, r in zip(gains, ratios)],
                     6.0, strike=0.002)
            put(out, secs(k), x * g, wrap=False)
        write("e_bell_%d" % (i + 1), lofi(tail(out, 2.2, 0.3, 2500), 5000), 0.75)


def voice(syll, f0s, dur):
    """A shout across the water: a glottal buzz through the vowels' formants, syllable by syllable."""
    forms = {"a": (750, 1200, 2500), "o": (500, 850, 2400), "e": (450, 1900, 2600), "u": (350, 750, 2400)}
    out = []
    for s, (fa, fb), d in zip(syll, f0s, dur):
        n = secs(d)
        t = t_axis(n)
        f = np.linspace(fa, fb, n) * (1.0 + 0.02 * np.sin(2 * np.pi * 5.5 * t))
        ph = np.cumsum(f) / SR
        buzz = (ph % 1.0) * 2 - 1           # (a saw: the glottis)
        buzz = buzz + 0.05 * RNG.standard_normal(n)
        F = forms[s]
        y = reson(buzz, F[0], 0.03) + 0.6 * reson(buzz, F[1], 0.025) + 0.25 * reson(buzz, F[2], 0.02)
        out.append(y * adsr(n, 0.04, d * 0.8, 0.6))
        out.append(np.zeros(secs(0.06)))
    return np.concatenate(out)


def voices():
    lines = [(["e", "o"], [(170, 210), (200, 150)], [0.22, 0.45]),
             (["a", "o"], [(150, 165), (165, 140)], [0.3, 0.38]),
             (["e", "a", "u"], [(190, 200), (200, 220), (210, 160)], [0.16, 0.18, 0.3])]
    for i, (s, f, d) in enumerate(lines):
        x = voice(s, f, d)
        write("e_voice_%d" % (i + 1), lofi(tail(lp(x, 1600), 1.6, 0.45, 1500), 2500), 0.6)


def engine_far():
    dur = 14.0
    n = secs(dur)
    t = t_axis(n)
    u = t / dur
    f = np.interp(u, [0, 0.45, 0.55, 1.0], [78, 84, 76, 72]) * (1.0 + 0.01 * np.sin(2 * np.pi * 0.7 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(h * ph + RNG.uniform(0, 6)) / h ** 0.7 for h in range(1, 16))
    x += 0.4 * bp(RNG.standard_normal(n), 200, 1500)
    x *= np.sin(np.pi * u) ** 2 * (1.0 + 0.25 * np.sin(2 * np.pi * 0.35 * t))
    write("e_engine_far", lofi(tail(lp(x, 1100), 1.4, 0.3, 1200), 2000), 0.6)


def knocks():
    kinds = [([310, 720, 1300], [0.05, 0.03, 0.015], [1.0, 0.5, 0.25]),      # wood: a gaff's handle in its rack
             ([180, 560, 950], [0.08, 0.04, 0.02], [1.0, 0.6, 0.3]),         # the cooler's hollow lid
             ([420, 1050, 2300], [0.04, 0.025, 0.012], [1.0, 0.6, 0.3]),     # a plastic bucket
             ([260, 640, 1500], [0.06, 0.03, 0.015], [1.0, 0.45, 0.3])]      # a hatch lid in its frame
    for i, (f, d, g) in enumerate(kinds):
        out = np.zeros(secs(0.6))
        put(out, 0, ping(f, d, g, 0.4, strike=0.004), wrap=False)
        if i % 2 == 1:         # (a rattle: it knocks again, smaller)
            put(out, secs(RNG.uniform(0.06, 0.12)), ping(f, d, g, 0.4) * 0.4, wrap=False)
        write("e_knock_%d" % (i + 1), lofi(tail(out, 0.3, 0.12, 4000), 6000), 0.7)


def clinks():
    for i in range(3):
        f0 = RNG.uniform(1800, 2600)
        out = np.zeros(secs(0.8))
        for j in range(int(RNG.integers(1, 4))):
            x = ping([f0, f0 * 1.52, f0 * 2.33], [0.25, 0.15, 0.08], [1.0, 0.5, 0.3], 0.6, strike=0.001)
            put(out, secs(j * RNG.uniform(0.05, 0.09)), x * (0.7 ** j), wrap=False)
        write("e_clink_%d" % (i + 1), lofi(tail(out, 0.4, 0.15, 5000), 6500), 0.6)


def groans():
    for i in range(3):
        d = RNG.uniform(1.2, 2.0)
        x = stick_slip(d, [(0, 18), (0.5, RNG.uniform(35, 60)), (1, 20)],
                       [(RNG.uniform(110, 140), 0.08, 1.0), (RNG.uniform(240, 290), 0.05, 0.6), (480, 0.03, 0.3)],
                       jitter=0.25)
        write("e_groan_%d" % (i + 1), lofi(tail(lp(x, 700, 3), 0.6, 0.2, 2000), 3000), 0.75)


def slaps():
    for i in range(4):
        out = np.zeros(secs(1.6))
        m = secs(0.2)
        t = t_axis(m)
        thump = (np.sin(2 * np.pi * RNG.uniform(60, 85) * t) * 0.8 + bp(RNG.standard_normal(m), 60, 300)) \
            * adsr(m, 0.006, 0.14)
        put(out, 0, thump, wrap=False)
        m = secs(1.0)
        splash = bp(RNG.standard_normal(m), 500, 5000) * adsr(m, RNG.uniform(0.03, 0.08), RNG.uniform(0.4, 0.8))
        put(out, secs(0.02), splash * RNG.uniform(0.35, 0.6), wrap=False)
        for _ in range(int(RNG.integers(4, 10))):
            put(out, secs(RNG.uniform(0.05, 0.6)), bubble(RNG.uniform(300, 1200), amp=RNG.uniform(0.1, 0.3)), wrap=False)
        write("e_slap_%d" % (i + 1), lofi(tail(out, 0.5, 0.15, 3000), 6000), 0.8)


def blows():
    for i in range(2):
        out = np.zeros(secs(3.0))
        m = secs(RNG.uniform(1.1, 1.5))
        blow = reson(bp(RNG.standard_normal(m), 120, 2500), RNG.uniform(260, 340), 0.05) * 0.6 \
            + bp(RNG.standard_normal(m), 400, 3000) * 0.5
        blow *= adsr(m, 0.06, m / SR * 0.8, 0.5)
        put(out, 0, blow, wrap=False)
        m = secs(0.6)
        breath = bp(RNG.standard_normal(m), 150, 900) * np.hanning(m) * 0.35
        put(out, secs(1.5 + 0.2 * i), breath, wrap=False)
        write("e_blow_%d" % (i + 1), lofi(tail(out, 1.5, 0.35, 1800), 2500), 0.7)


def dolphins():
    for i in range(2):
        out = np.zeros(secs(2.5))
        for _ in range(int(RNG.integers(2, 4))):
            d = RNG.uniform(0.25, 0.6)
            n = secs(d)
            u = np.linspace(0, 1, n)
            f = np.interp(u, [0, 0.4, 1], [RNG.uniform(3500, 5000), RNG.uniform(5500, 7000), RNG.uniform(4000, 6000)])
            w = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * u) ** 0.5
            put(out, secs(RNG.uniform(0.0, 1.6)), w * 0.4, wrap=False)
        for _ in range(2):         # a chuff as one breathes, a little splash
            m = secs(0.14)
            put(out, secs(RNG.uniform(0.2, 1.8)), bp(RNG.standard_normal(m), 300, 2200) * adsr(m, 0.01, 0.1) * 0.8,
                wrap=False)
            put(out, secs(RNG.uniform(0.2, 2.0)), bubble(RNG.uniform(400, 900), 0.08, 0.5), wrap=False)
        write("e_dolphin_%d" % (i + 1), lofi(tail(out, 1.0, 0.3, 3500), 6500), 0.6)


def foghorn():
    # a diaphone's two tones: the high blast, then the grunt down
    out = np.zeros(secs(6.0))
    for k, (fa, fb), d in [(0.0, (182, 186), 1.9), (1.9, (150, 146), 0.9)]:
        n = secs(d)
        t = t_axis(n)
        f = np.linspace(fa, fb, n)
        ph = 2 * np.pi * np.cumsum(f) / SR
        x = sum(np.sin(h * ph) / h ** 0.6 for h in range(1, 18))
        x = reson(x, 420, 0.04) * 0.5 + x * 0.3
        put(out, secs(k), x * adsr(n, 0.12, d * 0.9, 0.6) * (1.0 if k == 0 else 0.8), wrap=False)
    write("e_foghorn", lofi(tail(lp(out, 1400), 3.0, 0.45, 1000), 2000), 0.8)


if __name__ == "__main__":
    for make in [sea_open, sea_calm, lap, rush, wind_low, wind_high, rigging, rain, rain_roof, harbour, night, pump,
                 exhaust, gulls, terns, halyards, creaks, fenders, bells, voices, engine_far, knocks, clinks, groans,
                 slaps, blows, dolphins, foghorn]:
        make()
