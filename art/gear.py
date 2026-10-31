"""The kit a deckhand carries (crew/kit.gd), and the gloves that hold it in first person (crew/hands.gd).

Each item is its own .glb in ../crew/gear/, its origin where the right hand grips it, its working end ahead
(Blender +Y, Godot -Z) and its top up (Blender +Z, Godot +Y):

  knife.glb    a deckhand's bleeding knife: a white grippy handle with a finger guard, a short stiff blade
  gaff.glb     a stout aluminium gaff pole with two foam grips and a big stainless hook; empties "grip_l" (where
               the left hand holds it) and "hook" (the point)
  jig.glb      a short, stiff jig rod (1.45 m): cork grips, a little blue reel on top, a thin blank with its guides; empties "tip"
               (where the line leaves) and "grip_l"; "rig" (the jig hanging off the tip on a bit of line: a string
               of feathered hooks and a chrome sinker, its origin at the tip so it can swing); "blank" (the part
               that bends, from the foregrip to the tip)
  scoop.glb    a chum scoop: a blue plastic cup on a long wooden handle; "Chum" (a scoopful in the cup, hidden
               when it's empty), empties "grip_l" and "cup"
  bait.glb     a live mackerel: "body" and "tail" (its origin at the wrist of the tail, so it can flick)
  glove.glb    "glove_r" and "glove_l": an orange rubber deck glove in a fist round a handle along +Y, its
               gauntlet going back; "sleeve", the navy hoodie's, from the wrist along +Y (first person only; the
               others see crew.glb's arms)

Textures are tiny and drawn here (64-256 px per metre is the boats'; these are hand-held, so 400-800), quantized,
no smoothing (core/psx_import.gd sets Nearest in Godot).

Run: "C:/Program Files/Blender Foundation/Blender 4.3/blender.exe" --background --python art/gear.py
Original work."""
import math
import os
import sys

import bmesh
import bpy  # noqa: F401
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import psx  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "crew", "gear")

# material -> (tile u, tile v) in metres (box UVs)
TILES = {
    "kn_handle": (0.03, 0.03), "kn_steel": (0.16, 0.03), "kn_edge": (0.16, 0.03), "black": (0.05, 0.05),
    "alu": (0.6, 0.06), "foam": (0.05, 0.05), "tape": (0.05, 0.05), "hook": (0.1, 0.1),
    "cork": (0.05, 0.05), "jblank": (0.5, 0.05), "reel": (0.06, 0.06), "line": (0.1, 0.1),
    "feather_a": (0.02, 0.02), "feather_b": (0.02, 0.02), "feather_c": (0.02, 0.02), "lead": (0.03, 0.03),
    "wood": (0.3, 0.05), "cup": (0.1, 0.1), "chum": (0.06, 0.06),
    "mk_back": (0.08, 0.08), "mk_belly": (0.1, 0.1), "mk_fin": (0.04, 0.04), "eye": (0.02, 0.02),
    "glove": (0.06, 0.06), "glove_fx": (0.088, 0.088), "glove_fz": (0.088, 0.088), "cuff": (0.06, 0.06), "sleeve": (0.1, 0.1),
}


# ---------------------------------------------------------------- textures

def _q(rgb, levels=20):
    """Crunch to a few levels per channel (the PS1's 15-bit colour, coarser)."""
    return np.round(np.clip(rgb, 0.0, 1.0) * levels) / levels


def _tex(name, rgb):
    path = os.path.join(psx.TEXTURES, "gear_" + name + ".png")
    psx.save_png(_q(rgb), path)
    return "gear_" + name


def _noisy(px, base, vary, seed, cells=4):
    n = psx.fbm(px, px, cells, 3, seed) - 0.5
    return np.array(base)[None, None, :] * (1.0 + vary * 2.0 * n[..., None])


def textures():
    t = {}
    # the knife's handle: white rubber with a dimpled grip
    a = _noisy(16, (0.88, 0.88, 0.84), 0.05, 1)
    for y in range(0, 16, 4):
        for x in range((y // 4) % 2 * 2, 16, 4):
            a[y, x] *= 0.78
    t["kn_handle"] = _tex("kn_handle", a)
    # the blade: brushed steel along its length, and its edge ground bright
    a = _noisy(32, (0.62, 0.65, 0.68), 0.04, 2)
    a *= (1.0 + 0.06 * np.sin(np.arange(32) * 2.1))[:, None, None]
    t["kn_steel"] = _tex("kn_steel", a)
    t["kn_edge"] = _tex("kn_edge", _noisy(16, (0.86, 0.88, 0.9), 0.03, 3))
    t["black"] = _tex("black", _noisy(16, (0.1, 0.1, 0.11), 0.15, 4))
    # the gaff's pole: aluminium, streaked lengthwise
    a = _noisy(32, (0.7, 0.72, 0.74), 0.05, 5)
    a *= (1.0 + 0.07 * np.sin(np.arange(32) * 1.7) * np.cos(np.arange(32) * 0.6))[:, None, None]
    t["alu"] = _tex("alu", a)
    # dense black EVA foam grips, little pores
    a = _noisy(16, (0.13, 0.13, 0.14), 0.25, 6, 8)
    t["foam"] = _tex("foam", a)
    t["tape"] = _tex("tape", _noisy(16, (0.78, 0.12, 0.08), 0.08, 7))
    t["hook"] = _tex("hook", _noisy(16, (0.82, 0.84, 0.86), 0.05, 8))
    # cork: tan with dark pits
    a = _noisy(16, (0.78, 0.6, 0.4), 0.12, 9, 8)
    rng = np.random.default_rng(9)
    for _ in range(14):
        a[rng.integers(16), rng.integers(16)] *= 0.62
    t["cork"] = _tex("cork", a)
    t["jblank"] = _tex("jblank", _noisy(16, (0.08, 0.2, 0.26), 0.12, 10))
    t["reel"] = _tex("reel", _noisy(16, (0.15, 0.36, 0.72), 0.08, 11))
    t["line"] = _tex("line", _noisy(8, (0.9, 0.9, 0.82), 0.02, 12))
    t["feather_a"] = _tex("feather_a", _noisy(8, (0.95, 0.35, 0.55), 0.15, 13))
    t["feather_b"] = _tex("feather_b", _noisy(8, (0.98, 0.85, 0.2), 0.15, 14))
    t["feather_c"] = _tex("feather_c", _noisy(8, (0.35, 0.85, 0.45), 0.15, 15))
    t["lead"] = _tex("lead", _noisy(8, (0.85, 0.87, 0.9), 0.06, 16))
    # the scoop's handle: pale ash with a grain along it
    a = _noisy(32, (0.74, 0.58, 0.38), 0.06, 17)
    a *= (1.0 + 0.1 * np.sin(np.arange(32) * 1.3 + 3.0 * psx.fbm(32, 32, 2, 2, 17)))[..., None]
    t["wood"] = _tex("wood", a)
    t["cup"] = _tex("cup", _noisy(16, (0.18, 0.42, 0.78), 0.06, 18))
    # chum: minced fish, red-brown, chunky
    a = _noisy(16, (0.5, 0.17, 0.12), 0.35, 19, 6)
    rng = np.random.default_rng(19)
    for _ in range(10):
        a[rng.integers(16), rng.integers(16)] = (0.8, 0.72, 0.66)      # (bits of silver skin)
    t["chum"] = _tex("chum", a)
    # the mackerel: a green-blue back worked over with dark wavy bars; a silver belly
    n = psx.fbm(32, 32, 3, 3, 20)
    bars = (np.mod(n * 7.0, 1.0) < 0.32)
    a = _noisy(32, (0.13, 0.42, 0.42), 0.08, 21)
    a[bars] = (0.04, 0.09, 0.1)
    t["mk_back"] = _tex("mk_back", a)
    a = _noisy(16, (0.82, 0.85, 0.88), 0.05, 22)
    a[::5] *= 1.08
    t["mk_belly"] = _tex("mk_belly", a)
    t["mk_fin"] = _tex("mk_fin", _noisy(8, (0.22, 0.32, 0.3), 0.1, 23))
    t["eye"] = _tex("eye", np.full((4, 4, 3), 0.03))
    # the glove: orange rubber, a darker rolled cuff; the hoodie's navy knit
    t["glove"] = _tex("glove", _noisy(16, (0.95, 0.42, 0.1), 0.06, 24))
    # the fingers' grooves, four to a hand: across the fist seen from the side (x), and from above or below (z)
    a = _noisy(16, (0.95, 0.42, 0.1), 0.06, 24)
    a[:, ::4] *= 0.62
    t["glove_fx"] = _tex("glove_fx", a)
    t["glove_fz"] = _tex("glove_fz", np.transpose(a, (1, 0, 2)))
    t["cuff"] = _tex("cuff", _noisy(16, (0.78, 0.3, 0.06), 0.06, 25))
    a = _noisy(16, (0.13, 0.18, 0.3), 0.12, 26, 8)
    a[:, ::2] *= 0.88
    t["sleeve"] = _tex("sleeve", a)
    return t


def materials():
    tex = textures()
    for name, img in tex.items():
        psx.make_material(name, tex=img, roughness=0.9)


# ---------------------------------------------------------------- shapes

def ring(y, w, h, n=8, z=0.0, x=0.0, rot=0.0):
    """A closed ring across the item at `y` (along it): `w` half-wide, `h` half-tall, centred at (x, z)."""
    return [(x + w * math.cos(rot + 2 * math.pi * i / n), y, z + h * math.sin(rot + 2 * math.pi * i / n))
            for i in range(n)]


def slab(m, poly, x0, x1, mat, mats=None):
    """A flat shape `poly` [(y, z), ...] in the item's side plane, `x0`..`x1` thick."""
    a = [(x0, y, z) for y, z in poly]
    b = [(x1, y, z) for y, z in poly]
    m.prism(a, b, mat, mats=mats)


def finish(m, coll, origin=None, **kw):
    """Normals outward (the shapes here are closed; welded first: psx.Mesh gives every face its own corners), then
    built."""
    bmesh.ops.remove_doubles(m.bm, verts=m.bm.verts[:], dist=0.0002)
    bmesh.ops.recalc_face_normals(m.bm, faces=m.bm.faces[:])
    return m.finish(coll, origin=origin, **kw)


# ---------------------------------------------------------------- the kit

def knife(coll):
    m = psx.Mesh("knife", TILES)
    # the handle: fat in the palm, a swell for the fingers, narrowing to the guard
    stations = [(-0.078, 0.009, 0.011), (-0.07, 0.0125, 0.0155), (-0.045, 0.0125, 0.015), (-0.02, 0.0135, 0.0165),
                (0.01, 0.0128, 0.0155), (0.035, 0.0115, 0.0145), (0.043, 0.0112, 0.014)]
    m.loft([ring(y, w, h, 8, rot=math.pi / 8) for y, w, h in stations], lambda s, k, p: "kn_handle")
    # the guard: a black collar, deeper below for the forefinger
    m.box((-0.0135, 0.043, -0.024), (0.0135, 0.052, 0.017), "black")
    # the blade: the spine straight on top, the edge sweeping up to the point; a flat grind and a bright edge
    t = 0.0019
    rings = []
    for y, zt, zb in [(0.052, 0.0105, -0.0115), (0.1, 0.0105, -0.0118), (0.14, 0.01, -0.0095), (0.168, 0.0085, -0.005),
                      (0.188, 0.0058, 0.0), (0.2, 0.0035, 0.002), (0.207, 0.0028, 0.0026)]:
        zm = zb + (zt - zb) * 0.38
        k = 0.15 if y > 0.2 else 1.0
        rings.append([(-t * k, y, zt), (t * k, y, zt), (t * k, y, zm), (0.0, y, zb), (-t * k, y, zm)])
    m.loft(rings, lambda s, k, p: "kn_edge" if k in (2, 3) else "kn_steel")
    return [finish(m, coll)]


def gaff(coll):
    m = psx.Mesh("gaff", TILES)
    m.cylinder((0, -0.3, 0), (0, -0.28, 0), 0.026, "black", seg=8)           # the butt cap
    m.cylinder((0, -0.28, 0), (0, 0.13, 0), 0.025, "foam", seg=8)           # the back grip (the right hand)
    m.cylinder((0, 0.13, 0), (0, 0.4, 0), 0.0195, "alu", seg=8)
    m.cylinder((0, 0.4, 0), (0, 0.66, 0), 0.025, "foam", seg=8)             # the front grip (the left hand)
    m.cylinder((0, 0.66, 0), (0, 1.12, 0), 0.0195, "alu", seg=8)
    m.cylinder((0, 0.98, 0), (0, 1.04, 0), 0.0205, "tape", seg=8)
    m.cylinder((0, 1.12, 0), (0, 1.22, 0), 0.022, "hook", seg=8, r1=0.016)   # the ferrule
    # the hook: a straight shank out of the ferrule, round a big bend, its point coming back up at the pole
    w = 0.0085
    m.cylinder((0, 1.2, 0), (0, 1.32, 0), w, "hook", seg=6)
    cy, cz, r = 1.32, -0.08, 0.08
    pts = [(0.0, cy + r * math.sin(math.radians(a)), cz + r * math.cos(math.radians(a))) for a in range(0, 241, 20)]
    for i in range(len(pts) - 1):
        last = i == len(pts) - 2
        m.cylinder(pts[i], pts[i + 1], w, "hook", seg=6, r1=0.0015 if last else w)
    finish_obj = finish(m, coll)
    grip = psx.empty("grip_l", coll, (0.0, 0.53, 0.0))
    hook = psx.empty("hook", coll, pts[-1])
    return [finish_obj, grip, hook]


JIG_TIP = 1.05


def jig(coll):
    b = psx.Mesh("butt", TILES)
    b.cylinder((0, -0.4, 0), (0, -0.39, 0), 0.016, "black", seg=8)
    b.cylinder((0, -0.39, 0), (0, -0.04, 0), 0.0155, "cork", seg=8, r1=0.0135)   # the rear grip, under the arm
    b.cylinder((0, -0.04, 0), (0, 0.06, 0), 0.0125, "black", seg=8)              # the reel seat (the right hand)
    b.cylinder((0, 0.06, 0), (0, 0.2, 0), 0.0145, "cork", seg=8, r1=0.012)       # the foregrip
    # a little lever-drag reel on top: two blue side plates round a spool full of line, a crank on the right
    rc = (0.0, 0.01, 0.038)
    for s in (-1, 1):
        b.cylinder((s * 0.018, rc[1], rc[2]), (s * 0.024, rc[1], rc[2]), 0.026, "reel", seg=10)
    b.cylinder((-0.018, rc[1], rc[2]), (0.018, rc[1], rc[2]), 0.021, "line", seg=10)
    b.box((-0.007, -0.016, 0.008), (0.007, 0.034, 0.016), "black")
    b.beam((0.024, rc[1], rc[2]), (0.03, rc[1] - 0.024, rc[2] - 0.01), 0.007, 0.005, "black")
    b.cylinder((0.03, rc[1] - 0.024, rc[2] - 0.01), (0.044, rc[1] - 0.024, rc[2] - 0.01), 0.007, "black", seg=6)
    butt = finish(b, coll)
    k = psx.Mesh("blank", TILES)
    k.cylinder((0, 0.2, 0), (0, JIG_TIP, 0), 0.0085, "jblank", seg=6, r1=0.0028)
    # little guides on top, smaller toward the tip, the line running through them
    for i, d in enumerate((0.34, 0.5, 0.66, 0.8, 0.92, 0.99)):
        r = 0.0085 + (0.0028 - 0.0085) * (d - 0.2) / (JIG_TIP - 0.2)
        hgt = 0.018 - i * 0.0018
        k.box((-0.0018, d - 0.004, r * 0.5), (0.0018, d + 0.004, r + hgt * 0.6), "hook")
        k.torus((0, d, r + hgt), (0, 1, 0), hgt * 0.45, 0.0016, "hook", seg=6, rseg=3)
    k.cylinder((0, JIG_TIP - 0.012, 0), (0, JIG_TIP + 0.006, 0), 0.0042, "hook", seg=6)
    blank = finish(k, coll)
    # the jig, hanging off the tip on a bit of line: three feathered hooks on droppers, a chrome sinker
    g = psx.Mesh("rig", TILES)
    tip = (0.0, JIG_TIP + 0.006, 0.0)
    g.beam(tip, (0.0, tip[1], -0.36), 0.0022, 0.0022, "line")
    for i, (z, mat) in enumerate(((-0.1, "feather_a"), (-0.18, "feather_b"), (-0.26, "feather_c"))):
        s = 1 if i % 2 == 0 else -1
        g.beam((0.0, tip[1], z), (s * 0.026, tip[1], z - 0.008), 0.0018, 0.0018, "line")
        g.box((s * 0.026 - 0.004, tip[1] - 0.004, z - 0.042), (s * 0.026 + 0.004, tip[1] + 0.004, z - 0.008), mat)
        g.beam((s * 0.026, tip[1], z - 0.042), (s * 0.026, tip[1] + 0.008, z - 0.05), 0.002, 0.002, "hook")
    g.sphere((0.0, tip[1], -0.38), 0.011, "lead", seg=6, rings=4, squash=(1.0, 1.0, 1.9))
    rig = finish(g, coll, origin=tip)
    return [butt, blank, rig, psx.empty("tip", coll, tip), psx.empty("grip_l", coll, (0.0, 0.13, 0.0))]


def scoop(coll):
    m = psx.Mesh("scoop", TILES)
    m.cylinder((0, -0.16, 0), (0, -0.14, 0), 0.019, "black", seg=8)
    m.cylinder((0, -0.14, 0), (0, 0.66, 0), 0.016, "wood", seg=8)
    m.cylinder((0, 0.22, 0), (0, 0.26, 0), 0.0168, "tape", seg=8)
    m.cylinder((0, 0.64, 0), (0, 0.71, 0), 0.02, "hook", seg=8)
    cy = 0.8
    m.beam((0, 0.7, 0), (0, cy - 0.078, 0.012), 0.016, 0.012, "hook")
    # the cup: tapered, with a rolled lip, open on top
    n = 12
    ob = [(0.068 * math.cos(2 * math.pi * i / n), cy + 0.068 * math.sin(2 * math.pi * i / n), -0.045) for i in range(n)]
    ot = [(0.085 * math.cos(2 * math.pi * i / n), cy + 0.085 * math.sin(2 * math.pi * i / n), 0.035) for i in range(n)]
    it = [(0.078 * math.cos(2 * math.pi * i / n), cy + 0.078 * math.sin(2 * math.pi * i / n), 0.035) for i in range(n)]
    ib = [(0.062 * math.cos(2 * math.pi * i / n), cy + 0.062 * math.sin(2 * math.pi * i / n), -0.039) for i in range(n)]
    for i in range(n):
        j = (i + 1) % n
        m.face([ob[i], ob[j], ot[j], ot[i]], "cup")
        m.face([ot[i], ot[j], it[j], it[i]], "cup")
        m.face([it[i], it[j], ib[j], ib[i]], "cup")
    m.face(list(reversed(ob)), "cup")
    m.face(ib, "cup")
    body = finish(m, coll)
    # a scoopful, mounded in the cup
    c = psx.Mesh("Chum", TILES)
    rim = [(0.075 * math.cos(2 * math.pi * i / n), cy + 0.075 * math.sin(2 * math.pi * i / n), 0.022) for i in range(n)]
    low = [(0.062 * math.cos(2 * math.pi * i / n), cy + 0.062 * math.sin(2 * math.pi * i / n), -0.03) for i in range(n)]
    top = (0.004, cy - 0.006, 0.042)
    for i in range(n):
        j = (i + 1) % n
        c.face([rim[i], rim[j], top], "chum")
        c.face([low[i], low[j], rim[j], rim[i]], "chum")
    c.face(list(reversed(low)), "chum")
    chum = finish(c, coll)
    return [body, chum, psx.empty("grip_l", coll, (0.0, 0.4, 0.0)), psx.empty("cup", coll, (0.0, cy, 0.0))]


def mackerel(coll):
    m = psx.Mesh("body", TILES)
    stations = [(-0.118, 0.005, 0.007, 0.0), (-0.085, 0.011, 0.018, 0.0), (-0.035, 0.019, 0.031, 0.001),
                (0.015, 0.021, 0.035, 0.001), (0.065, 0.019, 0.031, 0.0), (0.105, 0.0145, 0.023, -0.002),
                (0.135, 0.009, 0.014, -0.004), (0.158, 0.002, 0.004, -0.005)]
    m.loft([ring(y, w, h, 8, z=z, rot=math.pi / 8) for y, w, h, z in stations],
           lambda s, k, p: "mk_back" if sum(q[2] for q in p) / 4 > 0.004 else "mk_belly")
    # the first dorsal fin, folded half down, and the little finlets toward the tail
    slab(m, [(-0.005, 0.03), (0.03, 0.034), (0.022, 0.05)], -0.0012, 0.0012, "mk_fin")
    for y in (-0.06, -0.075, -0.09):
        slab(m, [(y, 0.012), (y + 0.008, 0.012), (y - 0.002, 0.02)], -0.001, 0.001, "mk_fin")
        slab(m, [(y, -0.012), (y + 0.008, -0.012), (y - 0.002, -0.02)], -0.001, 0.001, "mk_fin")
    for s in (-1, 1):
        m.box((s * 0.0115 - 0.0035, 0.116, 0.0), (s * 0.0115 + 0.0035, 0.124, 0.008), "eye")
        # the pectoral fin laid back along the side
        slab(m, [(0.085, -0.004), (0.052, -0.006), (0.058, -0.015)], s * 0.0195, s * 0.0215, "mk_fin")
    body = finish(m, coll)
    t = psx.Mesh("tail", TILES)
    t.cylinder((0, -0.116, 0), (0, -0.13, 0), 0.0055, "mk_back", seg=6, r1=0.004)
    slab(t, [(-0.126, 0.004), (-0.172, 0.036), (-0.162, 0.002), (-0.162, -0.002), (-0.172, -0.036), (-0.126, -0.004)],
         -0.0013, 0.0013, "mk_fin")
    tail = finish(t, coll, origin=(0.0, -0.116, 0.0))
    return [body, tail]


def glove(coll, side):
    """A fist round a handle along +Y through the origin, one rounded lump that swallows the handle: the back of the
    hand out to the right (+X, for the right hand), the fingers wrapped round to the left and under (their grooves
    drawn on), the thumb over the top; then the gauntlet and its rolled cuff going back toward you."""
    s = 1 if side == "r" else -1
    m = psx.Mesh("glove_" + side, TILES)
    cx, cz = s * 0.005, 0.004

    def fingers(i, k, pts):
        if k < 0:
            return "glove"
        mx = sum(p[0] for p in pts) / 4 - cx
        mz = sum(p[2] for p in pts) / 4 - cz
        if mx * s > abs(mz) * 0.7:
            return "glove"                                     # (the back of the hand)
        return "glove_fx" if abs(mx) > abs(mz) else "glove_fz"

    rings = []
    for y, k in ((-0.05, 0.72), (-0.045, 0.92), (-0.025, 0.97), (0.0, 1.0), (0.025, 1.0), (0.043, 0.96),
                 (0.049, 0.78)):
        rings.append(ring(y, 0.033 * k, 0.035 * k, 10, z=cz, x=cx, rot=math.pi / 10))
    m.loft(rings, fingers)
    # the thumb, over the top and down the far side of the handle
    m.cylinder((s * 0.024, -0.03, 0.03), (s * -0.004, 0.02, 0.044), 0.012, "glove", seg=6)
    m.cylinder((s * -0.004, 0.02, 0.044), (s * -0.022, 0.036, 0.03), 0.011, "glove", seg=6, r1=0.009)
    # the gauntlet, flared, a rolled cuff
    m.cylinder((s * 0.008, -0.04, 0.002), (s * 0.012, -0.1, -0.004), 0.03, "glove", seg=8, r1=0.036)
    m.cylinder((s * 0.012, -0.098, -0.004), (s * 0.013, -0.114, -0.006), 0.039, "cuff", seg=8)
    return finish(m, coll, smooth=True)


def sleeve(coll):
    """The hoodie's sleeve, from the wrist (the origin) 0.38 m along +Y: crew/hands.gd aims it at your elbow."""
    m = psx.Mesh("sleeve", TILES)
    m.cylinder((0, -0.01, 0), (0, 0.38, 0), 0.038, "sleeve", seg=8, r1=0.047)
    m.cylinder((0, -0.012, 0), (0, 0.03, 0), 0.043, "sleeve", seg=8)
    return finish(m, coll)


def main():
    os.makedirs(OUT, exist_ok=True)
    # (a fresh scene for each, so its marks keep their names: Blender would make a second "grip_l" "grip_l.001")
    for name, build in (("knife", knife), ("gaff", gaff), ("jig", jig), ("scoop", scoop), ("bait", mackerel)):
        psx.clear_scene()
        materials()
        coll = psx.new_collection(name)
        objs = build(coll)
        psx.export_glb(os.path.abspath(os.path.join(OUT, name + ".glb")), objs)
        print("wrote", name)
    psx.clear_scene()
    materials()
    coll = psx.new_collection("glove")
    psx.export_glb(os.path.abspath(os.path.join(OUT, "glove.glb")), [glove(coll, "r"), glove(coll, "l"), sleeve(coll)])
    print("wrote glove")


main()
