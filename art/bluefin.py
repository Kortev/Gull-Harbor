"""The bluefin tuna (Thunnus thynnus), PS1-style: a low-poly torpedo, a painted 128 x 64 skin, flat-coloured fins.

Run: cd art && python3 bluefin.py  (bpy from pip). Writes ../tuna/bluefin.glb (the skin, textures/bluefin_skin.png, goes inside it).

Unit length (snout to the tips of the tail, 1.0): the game scales it to the fish's fork length. Godot axes after
export: snout toward -Z at z = -0.5, tail tips at +0.5, back up (+Y), so tuna/tuna_swim.gdshader can bend it by z.
Blender: snout toward +Y, back +Z.

What makes it a bluefin: deepest a third of the way back and pointed at both ends; a short pectoral fin (shorter than
an albacore's); a low, dark first dorsal that folds into a groove; a sickle second dorsal and anal fin; a row of
yellow finlets edged in black above and below the tail stalk; a big black keel on each side of the stalk; a stiff,
tall crescent tail. Navy-black back with a blue sheen, silver flanks with rows of pale spots, a white belly.
Original work, from field-guide proportions."""
import math
import os
import sys

import bpy  # noqa: F401  (bmesh only exists once bpy is loaded)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import psx  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "tuna")
SKIN = os.path.join(HERE, "textures", "bluefin_skin.png")

N = 12                  # vertices round the body
STATIONS = [0.0, 0.025, 0.06, 0.11, 0.17, 0.25, 0.34, 0.44, 0.54, 0.63, 0.71, 0.77, 0.82, 0.855]
PEAK = 0.36             # deepest here (fraction of the length from the snout)
DEPTH = 0.29            # body depth / length
WIDTH = 0.19
STALK = 0.855           # the tail stalk ends here and the tail begins


def ss(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def profile(t):
    """(half height, half width) at t (0 snout .. STALK)."""
    if t < PEAK:
        f = math.sin(math.pi * 0.5 * t / PEAK) ** 0.62
    else:
        g = (t - PEAK) / (STALK - PEAK)
        f = 1.0 - (1.0 - 0.1) * (g ** 1.35)
    h = DEPTH * 0.5 * f
    w = WIDTH * 0.5 * (f ** 1.1)
    if t < 0.02:
        h, w = 0.004, 0.004
    return max(h, 0.012), max(w, 0.012)


def y_of(t):
    return 0.5 - t


def ring(t):
    """N points round the section at t: k = 0 is the top of the back, going down the right flank (x+), the belly
    at N/2, up the left. The belly a bit fuller than the back; the stalk's keels stick out sideways."""
    h, w = profile(t)
    keel = 0.035 * ss(0.68, 0.8, t) if t > 0.68 else 0.0
    zc = -0.012 * math.sin(math.pi * min(t / STALK, 1.0))   # the belly line sags a touch
    pts = []
    for k in range(N):
        a = 2 * math.pi * k / N
        s, c = math.sin(a), math.cos(a)
        hh = h * (1.08 if c < 0 else 1.0)
        x = w * s * (abs(s) ** -0.15 if abs(s) > 1e-6 else 0.0)
        if k in (N // 4, 3 * N // 4):
            x += keel * (1 if s > 0 else -1)
        pts.append((x, y_of(t), zc + hh * c))
    return pts


def paint_skin():
    """128 x 64: u along the fish (0 snout .. 1 tail stalk), v round it (0 back, .25 right flank, .5 belly, .75
    left flank, 1 back again). Rows top-down."""
    W, H = 128, 64
    u = np.linspace(0, 1, W)[None, :].repeat(H, 0)
    v = np.linspace(0, 1, H)[:, None].repeat(W, 1)
    down = 1.0 - np.abs(v - 0.5) * 2.0          # 0 on the back, 1 on the belly
    back = psx.hexcol("0c1a2c")
    sheen = psx.hexcol("21507a")
    flank = psx.hexcol("8f9ba5")
    belly = psx.hexcol("dfe4e6")
    img = np.zeros((H, W, 3), np.float32)
    k1 = np.clip((down - 0.36) / 0.12, 0, 1)[..., None]    # back -> flank, a sharp line
    k2 = np.clip((down - 0.68) / 0.2, 0, 1)[..., None]     # flank -> belly
    img[:] = back
    # the metallic blue band along the top of the flank
    band = np.exp(-((down - 0.32) / 0.05) ** 2)[..., None]
    img = img * (1 - band * 0.8) + sheen * band * 0.8
    img = img * (1 - k1) + flank * k1
    img = img * (1 - k2) + belly * k2
    # rows of pale spots and short bars on the lower flank (a live bluefin's)
    rng = np.random.default_rng(7)
    for col in range(14):
        uc = 0.28 + col * 0.035
        for side in (0.25, 0.75):
            for j in range(4):
                vc = side + (0.05 + j * 0.045) * (1 if side < 0.5 else -1)
                if rng.random() < 0.8:
                    m = (np.abs(u - uc - rng.normal(0, 0.004)) < 0.006) & (np.abs(v - vc) < 0.012)
                    img[m] = img[m] * 0.4 + belly * 0.6
    # the head: the gill cover's edge, a darker cheek line, the mouth
    gill = (np.abs(u - (0.2 + 0.03 * np.cos((v - 0.5) * 2 * np.pi))) < 0.008) & (down > 0.3)
    img[gill] *= 0.55
    mouth = (u < 0.085) & (np.abs(down - 0.66) < 0.035)
    img[mouth] = psx.hexcol("1c2228")
    # the keels on the stalk, black
    keel = (u > 0.8) & (np.abs(v - 0.25) < 0.03) | (u > 0.8) & (np.abs(v - 0.75) < 0.03)
    img[keel] = psx.hexcol("15191c")
    # a little grain and the PS1 palette
    n = psx.fbm(H, W, cells=(4, 8), octaves=3, seed=3)
    img *= (0.88 + 0.24 * n)[..., None]
    rgba = np.concatenate([np.clip(img, 0, 1), np.ones((H, W, 1), np.float32)], axis=2)
    rgba = psx.quantize(rgba, n=24, dither=0.03)
    os.makedirs(OUT_DIR, exist_ok=True)
    psx.save_png(rgba, SKIN)
    psx._IMAGES.pop("bluefin_skin", None)
    img_b = bpy.data.images.load(SKIN)
    img_b.colorspace_settings.name = 'sRGB'
    img_b.name = "bluefin_skin"
    psx._IMAGES["bluefin_skin"] = img_b


def body(m):
    rings = [ring(t) for t in STATIONS]
    for i in range(len(STATIONS) - 1):
        a, b = rings[i], rings[i + 1]
        ua, ub = STATIONS[i] / STALK, STATIONS[i + 1] / STALK
        for k in range(N):
            k2 = (k + 1) % N
            va, vb = k / N, (k + 1) / N
            # wound so the normal faces out (Blender: snout +Y, going round from the back down the right side)
            m.face([a[k], b[k], b[k2], a[k2]], "skin", uvs=[(ua, 1 - va), (ub, 1 - va), (ub, 1 - vb), (ua, 1 - vb)])
    # close the stalk where the tail takes over
    end = rings[-1]
    c = tuple(sum(p[j] for p in end) / N for j in range(3))
    for k in range(N):
        k2 = (k + 1) % N
        m.face([end[k], c, end[k2]], "fin_dark", uvs=[(0.5, 0.5)] * 3)


def fin(m, pts, mat):
    """A flat fin, seen from both sides: pts a convex outline (in order)."""
    m.face(pts, mat, uvs=[(0.5, 0.5)] * len(pts))
    m.face(list(reversed(pts)), mat, uvs=[(0.5, 0.5)] * len(pts))


def fins(m):
    def top(t):
        h, _ = profile(t)
        return h - 0.004

    def bot(t):
        h, _ = profile(t)
        return -h * 1.08 - 0.008
    # the tail: a tall, stiff crescent
    r = y_of(STALK) + 0.01
    rt, tt, tr, fk = (0, r, 0.022), (0, -0.5, 0.215), (0, -0.452, 0.075), (0, -0.432, 0.0)
    rb, tb, trb = (0, r, -0.022), (0, -0.5, -0.215), (0, -0.452, -0.075)
    for tri in ((rt, tt, tr), (rt, tr, fk), (rt, fk, rb), (rb, fk, trb), (rb, trb, tb)):
        fin(m, list(tri), "fin_dark")
    # first dorsal: low and dark, it folds into a groove
    fin(m, [(0, y_of(0.29), top(0.29)), (0, y_of(0.31), top(0.31) + 0.075), (0, y_of(0.36), top(0.36) + 0.06),
            (0, y_of(0.47), top(0.47) + 0.012), (0, y_of(0.48), top(0.48))], "fin_dark")
    # second dorsal and anal fin: sickles, grey-yellow
    fin(m, [(0, y_of(0.5), top(0.5)), (0, y_of(0.545), top(0.545) + 0.105), (0, y_of(0.59), top(0.59))], "fin_second")
    fin(m, [(0, y_of(0.53), bot(0.53)), (0, y_of(0.575), bot(0.575) - 0.095), (0, y_of(0.61), bot(0.61))],
        "fin_second")
    # finlets: nine above, eight below, yellow, from the second dorsal to the tail
    for i in range(9):
        t = 0.62 + i * 0.026
        fin(m, [(0, y_of(t), top(t)), (0, y_of(t + 0.014), top(t + 0.014) + 0.022), (0, y_of(t + 0.022),
                top(t + 0.022))], "finlet")
        if i < 8:
            t += 0.01
            fin(m, [(0, y_of(t), bot(t)), (0, y_of(t + 0.014), bot(t + 0.014) - 0.02), (0, y_of(t + 0.022),
                    bot(t + 0.022))], "finlet")
    # pectoral fins: short (a bluefin's don't reach the second dorsal), swept back and a little down
    for s in (1, -1):
        t = 0.24
        h, w = profile(t)
        root = (s * w * 0.95, y_of(t), -h * 0.15)
        fin(m, [root, (s * (w + 0.02), y_of(t + 0.03), -h * 0.2), (s * (w + 0.06), y_of(t + 0.17), -h * 0.55),
                (s * w * 0.95, y_of(t + 0.05), -h * 0.3)], "fin_dark")
        # pelvic fins, small, under the chest
        t = 0.27
        h, w = profile(t)
        fin(m, [(s * w * 0.3, y_of(t), -h * 1.02), (s * w * 0.5, y_of(t + 0.07), -h * 1.25),
                (s * w * 0.25, y_of(t + 0.05), -h * 1.04)], "fin_dark")
    # eyes: small, set forward
    for s in (1, -1):
        t = 0.085
        h, w = profile(t)
        c = (s * (w * 0.93 + 0.003), y_of(t), h * 0.28)
        e = 0.014
        pts = [(c[0], c[1] + e * math.cos(a), c[2] + e * math.sin(a)) for a in
               [2 * math.pi * i / 6 for i in range(6)]]
        m.face(pts if s > 0 else list(reversed(pts)), "eye", uvs=[(0.5, 0.5)] * 6)


def main():
    psx.clear_scene()
    paint_skin()
    psx.make_material("skin", "bluefin_skin")
    psx.make_material("fin_dark", color=(0.06, 0.08, 0.1))
    psx.make_material("fin_second", color=(0.2, 0.18, 0.12))
    psx.make_material("finlet", color=(0.9, 0.72, 0.08))
    psx.make_material("eye", color=(0.02, 0.02, 0.02), roughness=0.2)
    coll = psx.new_collection("tuna")
    m = psx.Mesh("bluefin", {})
    body(m)
    fins(m)
    obj = m.finish(coll, weld=False, smooth=True)
    out = os.path.abspath(os.path.join(OUT_DIR, "bluefin.glb"))
    psx.export_glb(out, [obj])
    print("wrote", out, len(obj.data.polygons), "faces")


main()
