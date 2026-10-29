"""The crew lockers' suits: whole other crew models (Kevin, 2026-10-14: "i want different models not just different
textures, i dont want reskins i want ENTIRE different models the mandatory thing is that they have a face cover or
glasses cover like in a futuristic way"; the six he picked: Linesman, Sou'wester, Mantis, Warden, Freezer tech, EVA).

This is the kit every suit's script builds with: the Deckhand's (../build_deckhand.py) contract and tools, generalised.
- BodyRig's 47 bones at rest (BONES, HAND), every bone pointing up, its rest unrotated.
- The meshes Crew_Head and Crew_Upper (hidden from your own camera), Crew_Lower (hips, legs, boots, forearms: you see
  them in first person) and Crew_Gloves, skinned by bone name, each region weighted mostly to one bone and split at
  the joints (the ragdoll cuts the worn mesh by bone).
- The materials Lane A's player looks up: "Visor" (every suit's face cover: lit cyan, yellow, red with the fight,
  through the glow map) and "crew_accent" (tinted per player: paint it light); and crew (the body), crew_glow,
  crew_hivis (glows faintly, so the crew still shows at night), crew_screen.
- One 128 px atlas painted from the game's own crunched CC0 photos (assets/world/blender/textures/) and worn the way
  the world is worn, its glow map beside it; Nearest; no bevels; smooth shading. Facing Blender's Front view (-Y) =
  Godot +Z, origin on the floor, about 1.8 m.

A suit's script (build_<id>.py beside this file) defines parts() -> [head, upper, lower, gloves] and paint(p) and
calls build("<id>", parts, paint). That writes <id>_body.png and <id>_glow.png beside the script and
res://assets/world/crew/suits/<id>.glb. With `-- --preview <folder>` it also renders a sheet of Blender views
(front, three-quarter, the rod-hand side, back, the face cover close up) into <folder>/<id>_sheet.png.

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P \
        assets/world/blender/crew/suits/build_<id>.py [-- --preview <folder>]

The v2 suits (docs/lane-b/suits-v2.md, the standard Deckhand v2 set): build(..., ao=0.05) bakes the shading; seat(),
slab(), on_surface() and bolt() fit the add-on pieces to the body (-- --floatcheck lists any that stand off); every v2
suit has two variants, plain (<id>_v2) and with MAWCO's bomb collar on (-- --collar: <id>_v2_collar, variant()), the
collar being the Deckhand's own (collar(), paint_collar(), fitted to the suit's neck by collar_fit()); -- --out
<folder> sends the glb, the atlas and the looks there instead of into the game (a trial build).
"""

import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = HERE  # (Bluefin: the kit, its psx.py and textures/ all live in art/kit; from the space fishing game)
sys.path.insert(0, BLENDER_DIR)
import psx  # noqa: E402  (Lane B's toolkit: assets/world/blender/psx.py; its textures/ are the game's crunched photos)

OUT = os.path.normpath(os.path.join(BLENDER_DIR, "out"))
SKINS = os.path.normpath(os.path.join(BLENDER_DIR, "out"))
ROOT = os.path.normpath(os.path.join(BLENDER_DIR, "..", "..", ".."))
TEX = 128

# BodyRig's body bones at rest, in the rig's frame (Godot axes: +X the body's left, +Y up, +Z the way it faces).
BONES = [
    ("hips", None, (0.0, 0.92, 0.0)),
    ("torso", "hips", (0.0, 0.92, 0.0)),
    ("head", "torso", (0.0, 1.5, 0.05)),
    ("arm_l", "torso", (0.245, 1.305, 0.0)),
    ("fore_l", "arm_l", (0.245, 1.005, 0.0)),
    ("arm_r", "torso", (-0.245, 1.305, 0.0)),
    ("fore_r", "arm_r", (-0.245, 1.005, 0.0)),
    ("thigh_l", "hips", (0.115, 0.92, 0.0)),
    ("shin_l", "thigh_l", (0.115, 0.52, 0.0)),
    ("foot_l", "shin_l", (0.115, 0.11, 0.0)),
    ("thigh_r", "hips", (-0.115, 0.92, 0.0)),
    ("shin_r", "thigh_r", (-0.115, 0.52, 0.0)),
    ("foot_r", "shin_r", (-0.115, 0.11, 0.0)),
]
# BodyRig's hand bones (body_rig_hands.gd), the LEFT hand at rest: the palm faces -X, the thumb's side +Z, the
# fingers hang down -Y. The right hand is the mirror (x -> -x).
HAND = {
    "cuff": ((0.245, 0.8, 0.0), (0.241, 0.743, 0.004), None),
    "hand": ((0.241, 0.743, 0.004), (0.241, 0.662, 0.01), "cuff"),
    "index1": ((0.241, 0.665, 0.03), (0.241, 0.625, 0.033), "hand"),
    "index2": ((0.241, 0.625, 0.033), (0.241, 0.6, 0.035), "index1"),
    "index3": ((0.241, 0.6, 0.035), (0.241, 0.579, 0.036), "index2"),
    "middle1": ((0.241, 0.662, 0.01), (0.241, 0.618, 0.01), "hand"),
    "middle2": ((0.241, 0.618, 0.01), (0.241, 0.59, 0.01), "middle1"),
    "middle3": ((0.241, 0.59, 0.01), (0.241, 0.568, 0.01), "middle2"),
    "ring1": ((0.241, 0.666, -0.01), (0.241, 0.625, -0.012), "hand"),
    "ring2": ((0.241, 0.625, -0.012), (0.241, 0.599, -0.013), "ring1"),
    "ring3": ((0.241, 0.599, -0.013), (0.241, 0.578, -0.014), "ring2"),
    "pinky1": ((0.241, 0.673, -0.029), (0.241, 0.641, -0.032), "hand"),
    "pinky2": ((0.241, 0.641, -0.032), (0.241, 0.621, -0.035), "pinky1"),
    "pinky3": ((0.241, 0.621, -0.035), (0.241, 0.603, -0.037), "pinky2"),
    "thumb1": ((0.233, 0.726, 0.034), (0.222, 0.7, 0.056), "hand"),
    "thumb2": ((0.222, 0.7, 0.056), (0.213, 0.678, 0.075), "thumb1"),
    "thumb3": ((0.213, 0.678, 0.075), (0.206, 0.661, 0.09), "thumb2"),
}

MAT_BODY, MAT_ACCENT, MAT_GLOW, MAT_VISOR, MAT_HIVIS, MAT_SCREEN = range(6)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mixc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, k):
    return tuple(v * k for v in c)


# The palette (art rules) and the world's wear, sRGB 0..1 (the Deckhand's).
OXIDE = hexc("4F6B5A")
BULKHEAD = hexc("6B716C")
BONE = hexc("C9BFA6")
RUST = hexc("8A4B2A")
HAZARD = hexc("D4A21C")
FREEZER = hexc("6FD3DD")
GLASS = (0.04, 0.08, 0.09)
GUNK = (0.24, 0.25, 0.15)                           # fish gunk
BLOOD = (0.3, 0.08, 0.07)                           # fish blood, dried
SALT = (0.78, 0.76, 0.68)                           # salt tide lines
GRIME = (0.12, 0.11, 0.09)
MUD = (0.26, 0.19, 0.12)
RUST_RUN = (0.42, 0.21, 0.1)                        # rust bleeding down from a bolt
ACCENT = (0.86, 0.85, 0.81)                         # near white: Godot tints it per player
PRIMER = (0.44, 0.44, 0.41)                         # grey primer under chipped paint
MAWCO_RED = (0.5, 0.16, 0.13)                       # the company's red (Warning, faded)
STENCIL = (0.8, 0.77, 0.68)                         # bone stencil paint
TAPE = (0.52, 0.53, 0.49)                           # duct tape
FROST = (0.84, 0.9, 0.92)

# A 3 x 5 pixel font for small stencils (the 5 x 7 one is psx.FONT, the ship's and the hangar's).
FONT3 = {
    "A": ["010", "101", "111", "101", "101"], "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"], "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"], "M": ["101", "111", "111", "101", "101"],
    "N": ["110", "101", "101", "101", "101"], "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "W": ["101", "101", "111", "111", "101"], "Y": ["101", "101", "010", "010", "010"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
    "-": ["000", "000", "111", "000", "000"], "#": ["101", "111", "101", "111", "101"],
    " ": ["000"] * 5,
}


def patch(i):
    """The middle of solid 8x8 patch i (16 a row, from the bottom of the atlas up)."""
    return (4 + 8 * (i % 16), 4 + 8 * (i // 16))


_PATCH_NAMES, _REGIONS = [], {}  # (what the atlas holds where, so the seam check can name a hole's part)


def patches(names):
    _PATCH_NAMES[:] = list(names)
    return {name: patch(i) for i, name in enumerate(names)}


def atlas_label(x, y):
    """The region (or solid patch) at atlas texel (x, y), y from the bottom up."""
    if y < 16:
        i = (y // 8) * 16 + x // 8
        return "patch:" + (_PATCH_NAMES[i] if i < len(_PATCH_NAMES) else str(i))
    for name, (rx, ry, w, h) in _REGIONS.items():
        if rx <= x < rx + w and ry <= y < ry + h:
            return name
    return "?"


def check_regions(regions, patch_rows=2):
    """Every region inside the atlas, none overlapping another or the solid patches' rows."""
    _REGIONS.clear()
    _REGIONS.update(regions)
    taken = np.zeros((TEX, TEX), np.int32)
    taken[:8 * patch_rows, :] = -1
    names = list(regions)
    for i, n in enumerate(names):
        x, y, w, h = regions[n]
        assert x >= 0 and y >= 0 and x + w <= TEX and y + h <= TEX, "%s is off the atlas" % n
        block = taken[y:y + h, x:x + w]
        if (block != 0).any():
            other = int(block[block != 0][0])
            raise AssertionError("%s overlaps %s" % (n, "the patches" if other < 0 else names[other - 1]))
        block[:] = i + 1


# ------------------------------------------------------------------ geometry (Godot frame; Blender is (x, -z, y))
def to_blender(g):
    """Godot rig frame (x, y, z) -> Blender (x, -z, y): a +90 degree turn about X, so winding is kept."""
    return (g[0], -g[2], g[1])


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def add(a, b):
    return [a[i] + b[i] for i in range(3)]


def scale(a, k):
    return [v * k for v in a]


def norm(a):
    ln = math.sqrt(sum(v * v for v in a)) or 1.0
    return [v / ln for v in a]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def lerp(a, b, f):
    return tuple(a[i] + (b[i] - a[i]) * f for i in range(3))


_PARTS = []


class Part:
    """One mesh object: vertices (Godot frame), faces with per-corner UVs and a material, bone weights. Every face is
    turned to face away from `out_from` (a point inside the shape), so no winding has to be worked out by hand."""

    def __init__(self, name):
        _PARTS.append(self)  # (every mesh so far: a piece on one sits on what the others have built there)
        self.name = name
        self.verts = []
        self.godot = []
        self.weights = []
        self.faces = []

    def vert(self, g, weights):
        self.verts.append(to_blender(g))
        self.godot.append(tuple(g))
        self.weights.append(dict(weights))
        return len(self.verts) - 1

    def face(self, idx, uvs, mat, out_from):
        pts = [self.godot[i] for i in idx]
        n = [0.0, 0.0, 0.0]  # Newell's normal (right-handed: counter-clockwise seen from outside)
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            n[0] += (a[1] - b[1]) * (a[2] + b[2])
            n[1] += (a[2] - b[2]) * (a[0] + b[0])
            n[2] += (a[0] - b[0]) * (a[1] + b[1])
        centre = [sum(p[k] for p in pts) / len(pts) for k in range(3)]
        if dot(n, sub(centre, out_from)) < 0.0:
            idx = list(reversed(idx))
            uvs = list(reversed(uvs))
        self.faces.append((list(idx), list(uvs), mat))

    def tris(self):
        return sum(len(f[0]) - 2 for f in self.faces)


def uv_px(x, y):
    return (x / TEX, y / TEX)


def W(**bones):
    return dict(bones)


def _w(w, p, a=0.0):
    return w(p, a) if callable(w) else w


def ring_point(c, r1, r2, a, axis="y"):
    """The tube's ring point at angle a: 0 is the back (-Z), pi/2 the body's left (+X), pi the front (+Z)
    (axis "z": 0 is the top, pi/2 the left)."""
    if axis == "y":
        return (c[0] + r1 * math.sin(a), c[1], c[2] - r2 * math.cos(a))
    return (c[0] + r1 * math.sin(a), c[1] + r2 * math.cos(a), c[2])


def tube(part, rings, sides, bands, cap_top=None, cap_bottom=None, axis="y", turn=0.0, inward=False):
    """Rings in order along the axis: (centre, r1, r2, weights); weights may be a function (point, angle) -> weights
    (a coat split between the thighs). axis "y": rings lie flat, r1 across X, r2 across Z, the seam down the back
    (-Z), the front the middle of each region (the texture runs mirrored to the eye: see Painter.stencil). axis "z":
    rings face forward, r1 across X, r2 across Y. `bands`: one per segment, or a single one spread over the whole
    tube; a band is (region, material) or (region, material, {side: (region, material)}): those sides of that
    segment swapped (a visor's glass in a helmet's band), sides sharing a region laid side by side across it.
    cap_top / cap_bottom: (patch, material) to close an end with a fan, or None (open). inward: the faces turned to
    the inside (a coat's lining, seen from below)."""
    grid = []
    for (c, r1, r2, w) in rings:
        row = []
        for s in range(sides):
            a = 2.0 * math.pi * s / sides + turn
            p = ring_point(c, r1, r2, a, axis)
            row.append(part.vert(p, _w(w, p, a)))
        grid.append(row)
    n = len(rings)
    for r in range(n - 1):
        band = bands[r] if isinstance(bands, list) else bands
        (x0, y0, rw, rh), mat = band[0], band[1]
        swaps = band[2] if len(band) > 2 else {}
        if isinstance(bands, list):
            v0, v1 = y0, y0 + rh
        else:
            v0, v1 = y0 + rh * r / (n - 1), y0 + rh * (r + 1) / (n - 1)
        mid = [(rings[r][0][k] + rings[r + 1][0][k]) / 2.0 for k in range(3)]
        for s in range(sides):
            if s in swaps:
                reg, fmat = swaps[s]
                same = sorted(k for k in swaps if swaps[k][0] == reg)
                i, m = same.index(s), len(same)
                u0, u1 = reg[0] + reg[2] * i / m, reg[0] + reg[2] * (i + 1) / m
                f0, f1 = reg[1], reg[1] + reg[3]
            else:
                fmat = mat
                u0, u1 = x0 + rw * s / sides, x0 + rw * (s + 1) / sides
                f0, f1 = v0, v1
            a, b = grid[r][s], grid[r][(s + 1) % sides]
            c, d = grid[r + 1][(s + 1) % sides], grid[r + 1][s]
            towards = mid
            if inward:
                fc = [sum(part.godot[i][k] for i in (a, b, c, d)) / 4.0 for k in range(3)]
                towards = add(fc, sub(fc, mid))
            part.face([a, b, c, d], [uv_px(u0, f0), uv_px(u1, f0), uv_px(u1, f1), uv_px(u0, f1)], fmat, towards)
    for cap, row_i, inner_i in ((cap_bottom, 0, 1), (cap_top, n - 1, n - 2)):
        if cap is None:
            continue
        (pu, pv), mat = cap
        c, _, _, w = rings[row_i]
        centre = part.vert(c, _w(w, c))
        uv = uv_px(pu, pv)
        for s in range(sides):
            part.face([centre, grid[row_i][s], grid[row_i][(s + 1) % sides]], [uv] * 3, mat, rings[inner_i][0])
    return grid


def sheet(part, rows, region, mat, inner=None, flip_u=False, inside=None, inset=0.004, rims=True):
    """A curved sheet through rows of points (each row [(point, weights), ...], all rows the same length), the region
    stretched over it: u across a row, v from the first row to the last. Faces turned away from `inside` (a point, or
    by default the middle of each face's rows' ends: rows going round something, like a hood or a visor). `inner`:
    (region or patch, material) for a second skin facing the other way (a hood's lining, a brim's underside), `inset`
    metres in from the first (never on it: two skins on one surface fight over every pixel), its open edges closed to
    the first with rims (else you'd see into the gap between them, edge on): rims True for every open edge, or some
    of ("first", "last", "sides") (an edge another piece covers needs none)."""
    n, m = len(rows), len(rows[0])
    x0, y0, w, h = region
    grid = [[part.vert(p, wt) for (p, wt) in row] for row in rows]
    inner_grid = None
    if inner is not None:
        inner_grid = []
        for r, row in enumerate(rows):
            irow = []
            for (p, wt) in row:
                if inside is not None:
                    towards = list(inside)
                else:  # the middle of this row's ends (and the next's): round toward the inside
                    ends = [rows[r][0][0], rows[r][-1][0]]
                    towards = [(ends[0][k] + ends[1][k]) / 2.0 for k in range(3)]
                d = sub(towards, p)
                if dot(d, d) > 1e-10:
                    d = norm(d)
                    p = tuple(p[k] + d[k] * inset for k in range(3))
                irow.append(part.vert(p, wt))
            inner_grid.append(irow)
    for r in range(n - 1):
        for s in range(m - 1):
            ids = [grid[r][s], grid[r][s + 1], grid[r + 1][s + 1], grid[r + 1][s]]
            us = [s, s + 1, s + 1, s]
            if flip_u:
                us = [m - 1 - u for u in us]
            vs = [r, r, r + 1, r + 1]
            uvs = [uv_px(x0 + w * u / (m - 1), y0 + h * v / (n - 1)) for u, v in zip(us, vs)]
            pts = [part.godot[i] for i in ids]
            centre = [sum(p[k] for p in pts) / 4.0 for k in range(3)]
            axis_mid = [(rows[r][0][0][k] + rows[r][-1][0][k] + rows[r + 1][0][0][k] + rows[r + 1][-1][0][k]) / 4.0
                        for k in range(3)]
            # the inside point: toward the middle of the rows' ends (a sheet round something)
            if inside is not None:
                in_pt = list(inside)
            elif dot(sub(centre, axis_mid), sub(centre, axis_mid)) > 1e-8:
                in_pt = axis_mid
            else:
                in_pt = sub(centre, (0, 0, 1))
            part.face(ids, uvs, mat, in_pt)
            if inner_grid is not None:
                ids_in = [inner_grid[r][s], inner_grid[r][s + 1], inner_grid[r + 1][s + 1], inner_grid[r + 1][s]]
                outside = add(centre, sub(centre, in_pt))
                ireg, imat = inner
                if len(ireg) == 2:
                    iuv = [uv_px(*ireg)] * 4
                else:
                    iuv = [uv_px(ireg[0] + ireg[2] * u / (m - 1), ireg[1] + ireg[3] * v / (n - 1))
                           for u, v in zip(us, vs)]
                part.face(ids_in, iuv, imat, outside)
    if inner_grid is not None and rims:
        ireg, imat = inner
        ruv = [uv_px(*ireg)] * 4 if len(ireg) == 2 else [uv_px(ireg[0] + ireg[2] / 2.0, ireg[1] + ireg[3] / 2.0)] * 4

        def mid(a, b):
            return [(part.godot[a][k] + part.godot[b][k]) / 2.0 for k in range(3)]

        edges = ("first", "last", "sides") if rims is True else tuple(rims)
        for r, nxt, edge in ((0, 1, "first"), (n - 1, n - 2, "last")):   # the first and the last row's edges
            if edge not in edges:
                continue
            for s_ in range(m - 1):
                part.face([grid[r][s_], grid[r][s_ + 1], inner_grid[r][s_ + 1], inner_grid[r][s_]], ruv, imat,
                          mid(grid[nxt][s_], grid[nxt][s_ + 1]))
        closed = all(dot(sub(part.godot[row[0]], part.godot[row[-1]]), sub(part.godot[row[0]], part.godot[row[-1]]))
                     < 1e-10 for row in grid)
        if not closed and "sides" in edges:             # and the sides, unless the rows go all the way round
            for s_, nxt in ((0, 1), (m - 1, m - 2)):
                for r in range(n - 1):
                    part.face([grid[r][s_], grid[r + 1][s_], inner_grid[r + 1][s_], inner_grid[r][s_]], ruv, imat,
                              mid(grid[r][nxt], grid[r + 1][nxt]))
    return grid


def ring_row(c, r1, r2, n, w, axis="y", turn=0.0):
    """A closed ring of n + 1 points (the first repeated) for sheet(): a lip or a step between two tubes (the Deckhand
    v2's yoke underside, its boot rim)."""
    return [(ring_point(c, r1, r2, 2.0 * math.pi * i / n + turn, axis), w) for i in range(n + 1)]


def region_band(regions, region, row, rows, mat=MAT_BODY):
    """Rows `row` to `row + rows` of a region, full width, as a tube band: (region, material)."""
    x, y, w, _ = regions[region]
    return ((x, y + row, w, rows), mat)


def solid_region(where, name):
    """The 6 x 6 middle of solid patch `name` (from patches()) as a region: a one-colour band, a sheet's lining."""
    u, v = where[name]
    return (u - 3, v - 3, 6, 6)


def arc_rows(rings, a0, a1, segs, axis="y"):
    """Rows for sheet(): each ring (centre, r1, r2, weights) from angle a0 to a1 (the tube's angles) in segs steps."""
    rows = []
    for (c, r1, r2, w) in rings:
        row = []
        for i in range(segs + 1):
            a = a0 + (a1 - a0) * i / segs
            p = ring_point(c, r1, r2, a, axis)
            row.append((p, _w(w, p, a)))
        rows.append(row)
    return rows


def hexa(part, corners, uv_patch, mat, weights, faces=(0, 1, 2, 3, 4, 5), front=None):
    """A box from 8 corners: the bottom four round, then the top four above them (any shape: a wedge, a plate).
    One colour (a patch), or front = (face index, region) mapped flat across one face. faces: which of the six to
    make (0 bottom, 1 top, 2..5 the sides from corners 0-1, 1-2, 2-3, 3-0)."""
    ids = [part.vert(c, weights) for c in corners]
    centre = [sum(c[k] for c in corners) / 8.0 for k in range(3)]
    quads = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    for fi in faces:
        q = quads[fi]
        if front is not None and front[0] == fi:
            x, y, w, h = front[1]
            uvs = [uv_px(x, y), uv_px(x + w, y), uv_px(x + w, y + h), uv_px(x, y + h)]
        else:
            uvs = [uv_px(*uv_patch)] * 4
        part.face([ids[i] for i in q], uvs, mat, centre)


def plate(part, centre, right, up, w, h, t, weights, uv_patch, mat=MAT_BODY, front=None, back=True):
    """A flat plate: w across `right`, h along `up`, t thick toward right x up (its front). One colour, or front =
    region mapped across the front face (left to right as you look at it, bottom to top)."""
    r, u = norm(right), norm(up)
    n = norm(cross(r, u))
    cs = []
    for dz in (-t / 2.0, t / 2.0):
        for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            cs.append(tuple(centre[k] + r[k] * a * w / 2.0 + u[k] * b * h / 2.0 + n[k] * dz for k in range(3)))
    # corners 0-3 the back face, 4-7 the front: as hexa's "bottom" and "top"
    faces = [1, 2, 3, 4, 5] + ([0] if back else [])
    hexa(part, cs, uv_patch, mat, weights, faces=faces, front=(1, front) if front else None)


def box(part, p0, p1, side_dir, width, thick, weights, uv_patch, mat=MAT_BODY, cap_end=True, cap_start=False):
    """A square rod from p0 to p1 (a finger bone, a housing): `width` across `side_dir`, `thick` across the other way.
    One colour (a patch)."""
    ax = norm(sub(p1, p0))
    sd = list(side_dir)
    d = dot(sd, ax)
    sd = norm([sd[i] - ax[i] * d for i in range(3)])
    nd = cross(ax, sd)
    ring = []
    for base in (p0, p1):
        r = []
        for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            r.append(part.vert(tuple(base[i] + sd[i] * a * width / 2 + nd[i] * b * thick / 2 for i in range(3)),
                               weights))
        ring.append(r)
    uv = uv_px(*uv_patch)
    centre = [(p0[i] + p1[i]) / 2.0 for i in range(3)]
    for s in range(4):
        a, b = ring[0][s], ring[0][(s + 1) % 4]
        c, d = ring[1][(s + 1) % 4], ring[1][s]
        part.face([a, b, c, d], [uv] * 4, mat, centre)
    if cap_end:
        part.face(list(ring[1]), [uv] * 4, mat, centre)
    if cap_start:
        part.face(list(ring[0]), [uv] * 4, mat, centre)


def quad(part, corners, uvs, mat, weights, out_from):
    part.face([part.vert(c, weights) for c in corners], [uv_px(*u) for u in uvs], mat, out_from)


def pipe(part, points, radius, sides, weights, uv_patch, mat=MAT_BODY, shaggy=0.0, seed=0, caps=False):
    """A hose through `points` (open ends), one colour, or a region (x, y, w, h) wrapped round it (u round, v along);
    weights: one for all, or a list (one a point: a hose from the helmet to the chest goes with both). shaggy: each
    vertex's radius off by up to that much (a fur ring's tufts). caps: both ends closed (a hose's end that shows)."""
    rr = np.random.default_rng(seed)
    rings = []
    for i, p in enumerate(points):
        wt = weights[i] if isinstance(weights, list) else weights
        t = norm(sub(points[min(i + 1, len(points) - 1)], points[max(i - 1, 0)]))
        ref = (0.0, 0.0, 1.0) if abs(t[2]) < 0.9 else (1.0, 0.0, 0.0)
        u = norm(cross(t, ref))
        v = cross(t, u)
        row = []
        for s in range(sides):
            a = 2.0 * math.pi * s / sides
            rad = radius * (1.0 + shaggy * (2.0 * rr.random() - 1.0)) if shaggy > 0.0 else radius
            row.append(part.vert(tuple(p[k] + rad * (u[k] * math.cos(a) + v[k] * math.sin(a)) for k in range(3)),
                                 wt))
        rings.append(row)
    n = len(points)
    for i in range(n - 1):
        mid = [(points[i][k] + points[i + 1][k]) / 2.0 for k in range(3)]
        for s in range(sides):
            a, b = rings[i][s], rings[i][(s + 1) % sides]
            c, d = rings[i + 1][(s + 1) % sides], rings[i + 1][s]
            if len(uv_patch) == 4:
                x, y, w, h = uv_patch
                u0, u1 = x + w * s / sides, x + w * (s + 1) / sides
                v0, v1 = y + h * i / (n - 1), y + h * (i + 1) / (n - 1)
                uvs = [uv_px(u0, v0), uv_px(u1, v0), uv_px(u1, v1), uv_px(u0, v1)]
            else:
                uvs = [uv_px(*uv_patch)] * 4
            part.face([a, b, c, d], uvs, mat, mid)
    if caps:
        cu = (uv_patch[0] + uv_patch[2] / 2.0, uv_patch[1] + uv_patch[3] / 2.0) if len(uv_patch) == 4 else uv_patch
        for end, nxt in ((0, 1), (n - 1, n - 2)):
            wt = weights[end] if isinstance(weights, list) else weights
            centre = part.vert(points[end], wt)
            for s in range(sides):
                part.face([centre, rings[end][s], rings[end][(s + 1) % sides]], [uv_px(*cu)] * 3, mat, points[nxt])


def disc(part, centre, normal, up, radius, sides, region, mat, weights, turn=0.0, ry=None):
    """A flat round face (a lens) facing `normal`, mapped round onto `region` (its middle the disc's middle; `up`
    is the region's up). ry: another radius up and down (an oval)."""
    nrm = norm(normal)
    u = norm(sub(up, scale(nrm, dot(up, nrm))))
    r = cross(u, nrm)
    ry = radius if ry is None else ry
    x0, y0, w, h = region
    cu, cv = x0 + w / 2.0, y0 + h / 2.0
    c = part.vert(centre, weights)
    ring = []
    uvs = []
    for s in range(sides):
        a = 2.0 * math.pi * s / sides + turn
        p = tuple(centre[k] + r[k] * radius * math.sin(a) + u[k] * ry * math.cos(a) for k in range(3))
        ring.append(part.vert(p, weights))
        uvs.append(uv_px(cu + math.sin(a) * (w / 2.0 - 0.5), cv + math.cos(a) * (h / 2.0 - 0.5)))
    behind = sub(centre, nrm)
    for s in range(sides):
        part.face([c, ring[s], ring[(s + 1) % sides]], [uv_px(cu, cv), uvs[s], uvs[(s + 1) % sides]], mat, behind)
    return ring


def dent(part, indices, centre, radius, depth, toward):
    """Knocks a dent in: vertices within `radius` of `centre` pushed up to `depth` toward `toward`."""
    for i in indices:
        g = part.godot[i]
        d = math.sqrt(sum((g[k] - centre[k]) ** 2 for k in range(3)))
        if d >= radius:
            continue
        to = norm([toward[k] - g[k] for k in range(3)])
        push = depth * (1.0 - d / radius)
        moved = tuple(g[k] + to[k] * push for k in range(3))
        part.godot[i] = moved
        part.verts[i] = to_blender(moved)


# Bone weights by height, the way the Deckhand splits them (a ring on a joint is half each side's).
def leg_w(side, y):
    thigh, shin, foot = "thigh_" + side, "shin_" + side, "foot_" + side
    if y >= 0.88:
        return {"hips": 0.5, thigh: 0.5}
    if y >= 0.56:
        return {thigh: 1.0}
    if y >= 0.48:
        return {thigh: 0.5, shin: 0.5}
    if y >= 0.14:
        return {shin: 1.0}
    if y >= 0.08:
        return {shin: 0.4, foot: 0.6}
    return {foot: 1.0}


def arm_w(side, y):
    arm, fore = "arm_" + side, "fore_" + side
    if y >= 1.34:
        return {"torso": 0.5, arm: 0.5}
    if y >= 1.04:
        return {arm: 1.0}
    if y >= 0.98:
        return {arm: 0.5, fore: 0.5}
    return {fore: 1.0}


def skirt_w(y_top=0.98):
    """A coat's skirt round both legs: hips at the waist, then each side going with its own thigh (the middle front and
    back half each), so a walk swings it."""
    def w(p, a):
        t = max(0.0, min(1.0, (y_top - p[1]) / 0.3))     # 0 at the waist, 1 a thigh's length down
        side = math.sin(a)                                 # +1 the left, -1 the right
        left = max(0.0, min(1.0, 0.5 + side * 0.9))
        out = {"hips": 1.0 - t * 0.8}
        if t > 0.0:
            out["thigh_l"] = t * 0.8 * left
            out["thigh_r"] = t * 0.8 * (1.0 - left)
        return {k: v for k, v in out.items() if v > 0.01}
    return w


def glove(part, side, x, cuff_region, uv_patch, mat=MAT_BODY, cuff=(0.047, 0.064, 0.065), finger=(0.019, 0.02),
          palm=(0.085, 0.032), thumb=0.022, cap_patch=None, sides=6, knuckle=None):
    """A glove of flat segments, each riding its hand bone: the cuff (a tube from the wrist up over the forearm's end:
    radius at the wrist, at its top, and how far above the cuff bone's head it reaches), the palm, three a finger and
    the thumb. Each finger segment a touch longer than its bone, so the knuckles never open. knuckle: (patch, thick)
    for a plate over the back of the hand."""
    sfx = "_" + side

    def p(v):
        return (v[0] * x, v[1], v[2])

    cuff_head, cuff_tail, _ = HAND["cuff"]
    top = cuff_head[1] + cuff[2]
    lip = (uv_patch[0] - 3, uv_patch[1] - 3, 6, 6)
    tube(part, [
        (p(cuff_tail), cuff[0], cuff[0], W(**{"cuff" + sfx: 1.0})),
        (p((cuff_head[0], top, cuff_head[2])), cuff[1], cuff[1], W(**{"cuff" + sfx: 1.0})),
        (p((cuff_head[0], top + 0.004, cuff_head[2])), cuff[1] - 0.016, cuff[1] - 0.016, W(**{"cuff" + sfx: 1.0})),
    ], sides, [(cuff_region, mat), (lip, mat)], cap_bottom=(cap_patch or uv_patch, mat))
    h0, h1, _ = HAND["hand"]
    box(part, p(h0), p((h1[0], h1[1] - 0.004, h1[2])), (0, 0, 1), palm[0], palm[1], W(**{"hand" + sfx: 1.0}),
        uv_patch, mat, cap_start=True)
    if knuckle is not None:
        kp, kt = knuckle
        # the back of the hand is +X on the left hand (the palm faces -X)
        box(part, p((h0[0] + palm[1] / 2.0 + kt / 2.0, h0[1] - 0.012, h0[2])),
            p((h1[0] + palm[1] / 2.0 + kt / 2.0, h1[1] + 0.004, h1[2])), (0, 0, 1), palm[0] * 0.9, kt,
            W(**{"hand" + sfx: 1.0}), kp, mat, cap_start=True)
    for f in ("index", "middle", "ring", "pinky", "thumb"):
        for j in (1, 2, 3):
            nm = f + str(j)
            a, b, _ = HAND[nm]
            d = [b[i] - a[i] for i in range(3)]
            b2 = tuple(b[i] + d[i] * 0.15 for i in range(3))
            box(part, p(a), p(b2), (0, 0, 1), finger[0], thumb if f == "thumb" else finger[1],
                W(**{nm + sfx: 1.0}), uv_patch, mat, cap_end=(j == 3))


def wrist_screen(part, uv_box, uv_screen, size=(0.055, 0.08), at=(0.298, 0.925, 0.0)):
    """The crew's wrist screen, on the back of the left wrist (you read it in first person): a housing and its glass
    (material crew_screen)."""
    fw = W(fore_l=1.0)
    w, h = size
    x, y, z = at
    box(part, (x, y - h / 2.0, z), (x, y + h / 2.0, z), (0, 0, 1), w, 0.02, fw, uv_box, cap_start=True)
    quad(part, [(x + 0.0105, y - h / 2.0 + 0.007, z - w / 2.0 + 0.007), (x + 0.0105, y - h / 2.0 + 0.007, z + w / 2.0 - 0.007),
                (x + 0.0105, y + h / 2.0 - 0.007, z + w / 2.0 - 0.007), (x + 0.0105, y + h / 2.0 - 0.007, z - w / 2.0 + 0.007)],
         [uv_screen] * 4, MAT_SCREEN, fw, (x - 0.05, y, z))


# ------------------------------------------------------------------ the texture: the game's own crunched photos, worn
class Painter:
    """The colour atlas (A) and the glow map (G, black = no glow), y-up float arrays, and the Deckhand's ways of
    wearing them: photos tinted by their own light and dark, grime from the floor up, rust from bolts, chipped paint,
    blood and gunk, stencils. Regions are (x, y, w, h) in pixels, y up from the bottom."""

    LUM = np.array([0.299, 0.587, 0.114], np.float32)

    def __init__(self):
        self.A = np.zeros((TEX, TEX, 3), np.float32)
        self.G = np.zeros((TEX, TEX, 3), np.float32)

    def photo(self, name):
        return np.ascontiguousarray(psx.load_image(os.path.join(psx.TEXTURES, name + ".png"))[::-1, :, :3])

    def view(self, r, arr=None):
        x, y, w, h = r
        return (self.A if arr is None else arr)[y:y + h, x:x + w]

    @staticmethod
    def noise(w, h, cells, seed, octaves=3):
        return psx.fbm(h, w, cells, octaves, seed)

    def fill(self, r, src, color, amount, sat=1.0, gain=1.0, punch=1.0, offset=(0, 0)):
        """The region tiled with a photo, recoloured toward `color` by its light and dark."""
        x, y, w, h = r
        sh, sw = src.shape[:2]
        tile = src[(np.arange(h) + offset[1]) % sh][:, (np.arange(w) + offset[0]) % sw]
        lum = tile @ self.LUM
        rel = (lum / max(float(lum.mean()), 1e-4)) ** punch
        out = tile * (1.0 - amount) + np.asarray(color, np.float32)[None, None, :] * rel[..., None] * amount
        grey = (out @ self.LUM)[..., None]
        self.A[y:y + h, x:x + w] = np.clip((grey + (out - grey) * sat) * gain, 0.0, 1.0)

    def mix(self, r, mask, color, alpha=1.0, arr=None):
        v = self.view(r, arr)
        m = np.clip(mask * alpha, 0.0, 1.0)[..., None]
        v[:] = v * (1.0 - m) + np.asarray(color, np.float32) * m

    def darken(self, r, k):
        v = self.view(r)
        v[:] = v * k

    def grime(self, r, rows, color, alpha, seed, top=False):
        """Dirt piling up from the bottom `rows` rows (or down from the top), broken up by noise."""
        x, y, w, h = r
        m = np.zeros((h, w), np.float32)
        for i in range(min(rows, h)):
            m[(h - 1 - i) if top else i, :] = (1.0 - i / float(rows)) ** 1.3
        self.mix(r, m * (0.6 + 0.7 * self.noise(w, h, 4, seed)), color, alpha)

    def splats(self, r, n, color, size, alpha, seed, rows=None, cols=None, arr=None):
        """Blobs walked out pixel by pixel (they wrap round the tube, left to right)."""
        x, y, w, h = r
        rr = np.random.default_rng(seed)
        m = np.zeros((h, w), np.float32)
        for _ in range(n):
            cx = int(rr.integers(*cols)) if cols else int(rr.integers(0, w))
            cy = int(rr.integers(*rows)) if rows else int(rr.integers(0, h))
            for _ in range(size):
                m[cy, cx % w] = 1.0
                cx += int(rr.integers(-1, 2))
                cy = min(max(cy + int(rr.integers(-1, 2)), 0), h - 1)
        self.mix(r, m, color, alpha, arr)

    def streaks(self, r, starts, color, length, alpha, seed, width=1):
        """Runs down from each start (region pixels), fading, wandering a little: rust from a bolt, a drip."""
        x, y, w, h = r
        rr = np.random.default_rng(seed)
        m = np.zeros((h, w), np.float32)
        for (sx, sy) in starts:
            run = max(int(length * (0.6 + 0.7 * rr.random())), 2)
            cx = int(sx)
            for k in range(run):
                yy = int(sy) - k
                if yy < 0:
                    break
                if rr.random() < 0.18:
                    cx += int(rr.integers(-1, 2))
                for dx in range(width):
                    xx = (cx + dx) % w
                    m[yy, xx] = max(m[yy, xx], (1.0 - k / run) * (0.55 + 0.45 * rr.random()))
        self.mix(r, m, color, alpha)

    def speckle(self, r, p, color, alpha, seed):
        x, y, w, h = r
        self.mix(r, (np.random.default_rng(seed).random((h, w)) < p).astype(np.float32), color, alpha)

    def chips(self, r, cells, threshold, color, seed, alpha=1.0):
        x, y, w, h = r
        self.mix(r, (self.noise(w, h, cells, seed, 2) > threshold).astype(np.float32), color, alpha)

    def edge_chips(self, r, color, seed, rows=2, edge=0.5, inner=0.8, cells=10, top=True, bottom=True, alpha=1.0):
        """Paint chipped off where plates get knocked: thick along the region's top and bottom `rows` rows (a plate's
        edges), only a few in the middle."""
        x, y, w, h = r
        n = self.noise(w, h, cells, seed, 2)
        yy = np.arange(h)[:, None] * np.ones((1, w))
        near = np.zeros((h, w), bool)
        if bottom:
            near |= yy < rows
        if top:
            near |= yy >= h - rows
        m = np.where(near, n > edge, n > inner).astype(np.float32)
        self.mix(r, m, color, alpha)

    def line(self, x0, y0, x1, y1, color, thick=1, alpha=1.0, arr=None):
        arr = self.A if arr is None else arr
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(steps + 1):
            t = i / steps
            px = int(round(x0 + (x1 - x0) * t))
            py = int(round(y0 + (y1 - y0) * t))
            for dx in range(thick):
                for dy in range(thick):
                    if 0 <= px + dx < TEX and 0 <= py + dy < TEX:
                        arr[py + dy, px + dx] = arr[py + dy, px + dx] * (1 - alpha) + np.asarray(color) * alpha

    def rect(self, x, y, w, h, color, alpha=1.0, arr=None):
        self.mix((x, y, w, h), np.ones((h, w), np.float32), color, alpha, arr)

    def ring(self, cx, cy, r_out, r_in, color, sy=1.0, alpha=1.0, arr=None):
        """A filled ring (r_in 0: a disc); sy stretches it up and down."""
        arr = self.A if arr is None else arr
        for y in range(int(cy - r_out * sy) - 1, int(cy + r_out * sy) + 2):
            for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
                if r_in <= math.hypot(x + 0.5 - cx, (y + 0.5 - cy) / sy) <= r_out and 0 <= x < TEX and 0 <= y < TEX:
                    arr[y, x] = arr[y, x] * (1 - alpha) + np.asarray(color) * alpha

    def stencil(self, r, text, cx, y, color, alpha=1.0, font=None, back=False, along=False, wear=0.0, seed=0,
                mirror=True, size=1):
        """Letters into region r, centred on x = cx with their bottom row at y (region pixels). A tube's texture runs
        the other way round to the eye, so the letters go in mirrored, reading right way round from outside (mirror=
        False for flat faces mapped the right way round). back: centred on the tube's back seam (u = 0, wrapping
        round). along: the word runs up the tube (v) instead of round it, its letters' tops toward +u; then y is where
        the word starts. wear: the paint is gone where the noise is under it. size: each font pixel size x size."""
        x0, y0, w, h = r
        glyphs = font if font is not None else FONT3
        gh, gw = len(glyphs["0"]), len(glyphs["0"][0])
        width = len(text) * (gw + 1) - 1
        g = np.zeros((gh, width), np.float32)                      # the word, rows top to bottom
        for i, ch in enumerate(text.upper()):
            for gr, row in enumerate(glyphs.get(ch, glyphs.get(" "))):
                for gc, bit in enumerate(row):
                    if bit == "1":
                        g[gr, i * (gw + 1) + gc] = 1.0
        if size > 1:
            g = np.repeat(np.repeat(g, size, 0), size, 1)
            gh, width = g.shape
        m = np.zeros((h, w), np.float32)
        if along:
            for gr in range(gh):
                for col in range(width):
                    if g[gr, col] > 0.0 and 0 <= y + col < h:
                        m[y + col, (cx - gh // 2 + (gh - 1 - gr)) % w] = 1.0
        else:
            if mirror:
                g = g[:, ::-1]
            left = (w // 2 if back else cx) - width // 2
            for gr in range(gh):
                yy = y + gh - 1 - gr
                if 0 <= yy < h:
                    for col in range(width):
                        if g[gr, col] > 0.0:
                            m[yy, (left + col) % w] = 1.0
            if back:
                m = np.roll(m, -(w // 2), axis=1)
        if wear > 0.0:
            m *= self.noise(w, h, 7, seed, 2) > wear
        self.mix(r, m, color, alpha)

    def hazard(self, r, color_a=HAZARD, color_b=(0.08, 0.08, 0.07), period=6, slant=1, seed=0, wear=0.0):
        """Diagonal hazard stripes across a region (chipped where the noise is under `wear`)."""
        x, y, w, h = r
        yy, xx = np.mgrid[0:h, 0:w]
        m = (((xx + yy * slant) // (period // 2)) % 2 == 0).astype(np.float32)
        self.mix(r, np.ones((h, w), np.float32), color_b)
        if wear > 0.0:
            m *= self.noise(w, h, 6, seed, 2) > wear
        self.mix(r, m, color_a)

    def rivets(self, r, xs, row, dark=(0.14, 0.12, 0.1), light=(0.5, 0.45, 0.38), rust=0.0, seed=0):
        """A row of rivets (2 x 2, a highlight) at region row `row`, rust bleeding down from them if `rust`."""
        x0, y0, w, h = r
        for x in xs:
            self.rect(x0 + x, y0 + row, 2, 2, dark)
            self.rect(x0 + x, y0 + row + 1, 1, 1, light)
        if rust > 0.0:
            self.streaks(r, [(x, row) for x in xs], RUST_RUN, 5, rust, seed)

    def solid_patches(self, where, colours, glows=None):
        """The solid 8 x 8 patches (caps, fingers, housings): `where` from patches(), name -> colour."""
        for name, c in colours.items():
            u, v = where[name]
            self.rect(u - 4, v - 4, 8, 8, c)
        for name, c in (glows or {}).items():
            u, v = where[name]
            self.rect(u - 4, v - 4, 8, 8, c, arr=self.G)

    def glass(self, r, base=GLASS, seed=0, smears=4, crack=None, rim_dim=0.45, bottom_grime=9, glow_gain=1.0):
        """A face cover's glass: dark, greasy, smeared; its glow bright in the middle, dimmer at the rim, grime along
        the bottom (the fight's light through a dirty window). crack: a list of points (region pixels)."""
        x0, y0, w, h = r
        self.view(r)[:] = base
        self.splats(r, smears, shade(base, 1.6), max(3, min(w, h) // 3), 0.8, seed)
        yy, xx = np.mgrid[0:h, 0:w]
        d = np.hypot((xx + 0.5 - w / 2.0) / (w / 2.0), (yy + 0.5 - h / 2.0) / (h / 2.0))
        glow = np.clip(1.0 - rim_dim * d ** 2, 0.0, 1.0)
        if bottom_grime > 0:
            glow *= 1.0 - 0.6 * np.clip(1.0 - yy / float(bottom_grime), 0.0, 1.0) * (0.6 + 0.6 * self.noise(w, h, 4, seed + 1))
        glow *= 0.75 + 0.25 * self.noise(w, h, 3, seed + 2)
        self.view(r, self.G)[:] = np.clip(glow * glow_gain, 0.0, 1.0)[..., None]
        self.splats(r, smears, (0.35, 0.35, 0.35), max(3, min(w, h) // 3), 1.0, seed, arr=self.G)
        if crack:
            for i in range(len(crack) - 1):
                (ax, ay), (bx, by) = crack[i], crack[i + 1]
                self.line(x0 + ax, y0 + ay, x0 + bx, y0 + by, (0.24, 0.28, 0.28), 1, 1.0)
                self.line(x0 + ax, y0 + ay, x0 + bx, y0 + by, (0.03, 0.03, 0.03), 1, 1.0, self.G)

    def mottle(self, keep_out, seed=131, amount=1.0):
        """A last pass over the whole atlas: mottled dirt, so nothing reads as a clean flat colour (not the patch rows,
        nor the regions in keep_out: glass, screens)."""
        worn = np.full((TEX, TEX), amount, np.float32)
        worn[0:16, :] = 0.0
        for r in keep_out:
            worn[r[1]:r[1] + r[3], r[0]:r[0] + r[2]] = 0.0
        m = 0.8 + 0.28 * psx.fbm(TEX, TEX, 8, 3, seed)
        self.A = self.A * (1.0 - worn[..., None] * (1.0 - m[..., None]))

    def finish(self):
        self.A = psx.quantize(np.concatenate([self.A, np.ones((TEX, TEX, 1), np.float32)], axis=2), n=64,
                              dither=0.015)[..., :3]
        return self.A, self.G


def save_image(arr, path, name):
    """A y-up float array -> a PNG -> a Blender image for the materials."""
    psx.save_png(np.ascontiguousarray(arr[::-1]), path)
    img = bpy.data.images.load(path, check_existing=False)
    img.name = name
    return img


def material(name, img, glow_img=None, strength=1.0):
    """The colour texture; glowing materials also take the glow map as their emission (Godot multiplies it by the
    emission colour, so Lane A's visor colour shines through the glass's cracks and grime)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    # one-sided (glTF doubleSided false): the linings, brims' undersides and hoods' insides are skins of their own
    mat.use_backface_culling = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    tex.location = (-300, 300)
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if glow_img is not None:
        glow = nodes.new("ShaderNodeTexImage")
        glow.image = glow_img
        glow.interpolation = "Closest"
        glow.location = (-300, -100)
        mat.node_tree.links.new(glow.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def _args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def bake_vertex_ao(objs, mats, distance, floor=0.4):
    """Ambient occlusion baked into each mesh's vertex colours at rest (Kevin, 2026-10-15: "baked shading"): the seams
    between layers and the creases darker, as PS2 games baked their light in. Only what's within `distance` (m) counts,
    so an arm hanging by the body doesn't stain it; nothing goes darker than `floor`. The materials multiply their
    texture by it (glTF's COLOR_0), so every look painted for the atlas gets it too."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.device = "CPU"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.light_settings.distance = distance
    scene.render.bake.target = "VERTEX_COLORS"
    for ob in objs:
        col = ob.data.color_attributes.new(name="AO", type="BYTE_COLOR", domain="CORNER")
        ob.data.color_attributes.active_color = col
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
        for d in col.data:
            v = floor + (1.0 - floor) * d.color[0]
            d.color = (v, v, v, 1.0)
    for mat in mats:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        tex = bsdf.inputs["Base Color"].links[0].from_node
        vc = nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "AO"
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        a = [s for s in mix.inputs if s.name == "A" and s.type == "RGBA"][0]
        b = [s for s in mix.inputs if s.name == "B" and s.type == "RGBA"][0]
        out = [s for s in mix.outputs if s.type == "RGBA"][0]
        links.new(tex.outputs["Color"], a)
        links.new(vc.outputs["Color"], b)
        links.new(out, bsdf.inputs["Base Color"])
    print("[ao] baked into %d meshes (distance %.3f m, floor %.2f)" % (len(objs), distance, floor))


def build(sid, parts_fn, paint_fn, looks=None, ao=None):
    """The suit `sid`: the armature, the painted atlas and glow map, the four meshes skinned, exported to
    res://assets/world/crew/suits/<sid>.glb. paint_fn(painter, palette) paints the atlas in one of `looks` (look id ->
    palette; "issue" goes in the model, every other look is the same atlas repainted, saved for the locker to swap in:
    res://assets/world/crew/skins/<sid>_<look>.png). -- --preview <folder>: a sheet of views; -- --seamcheck <folder>:
    every back face that shows from outside, magenta, in a few poses (see seamcheck()), and for a collar variant the
    same with the dome gone (<sid>_popped: as the collar leaves it); -- --neckcheck <folder> (a collar variant): the
    head against the collar in those poses (neckcheck()); -- --out <folder>: the glb, the atlas, the glow map
    and the looks into <folder>, nothing into the game (a trial build: compare it, then build for real). A new glb gets
    the Deckhand v2's import settings (_write_scene_import), before Godot first sees it."""
    args = _args()
    out = args[args.index("--out") + 1] if "--out" in args else None
    if out:
        os.makedirs(out, exist_ok=True)
    looks = looks or {"issue": None}
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    scene = bpy.context.scene
    arm_data = bpy.data.armatures.new("BodyRig")
    arm_obj = bpy.data.objects.new("BodyRig", arm_data)
    scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    arm_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}

    def bone(name, parent, head):
        eb = arm_data.edit_bones.new(name)
        h = to_blender(head)
        eb.head = h
        eb.tail = (h[0], h[1], h[2] + 0.03)  # every bone points up: its rest is unrotated, like BodyRig's
        eb.roll = 0.0
        if parent:
            eb.parent = made[parent]
            eb.use_connect = False
        made[name] = eb

    for name, parent, head in BONES:
        bone(name, parent, head)
    for side, x in (("l", 1.0), ("r", -1.0)):
        for nm, (head, _, parent) in HAND.items():
            bone(nm + "_" + side, (parent + "_" + side) if parent else ("fore_" + side), (head[0] * x, head[1], head[2]))
    bpy.ops.object.mode_set(mode="OBJECT")

    p = Painter()
    paint_fn(p, looks["issue"])
    colour, glow = p.finish()
    img = save_image(colour, os.path.join(out or HERE, sid + "_body.png"), sid + "_body")
    glow_img = save_image(glow, os.path.join(out or HERE, sid + "_glow.png"), sid + "_glow")
    # (indices = MAT_BODY .. MAT_SCREEN; "Visor" and "crew_accent" are the names Lane A's player looks up)
    mats = [material("crew", img), material("crew_accent", img), material("crew_glow", img, glow_img, 2.5),
            material("Visor", img, glow_img, 1.0), material("crew_hivis", img, glow_img, 0.4),
            material("crew_screen", img, glow_img, 1.5)]

    total = 0
    _PARTS.clear()
    parts = parts_fn()
    assert [pt.name for pt in parts] == ["Crew_Head", "Crew_Upper", "Crew_Lower", "Crew_Gloves"], "the four meshes"
    if "--floatcheck" in _args():
        floatcheck(sid, parts)
    for part in parts:
        me = bpy.data.meshes.new(part.name)
        me.from_pydata(part.verts, [], [f[0] for f in part.faces])
        me.update()
        ob = bpy.data.objects.new(part.name, me)
        scene.collection.objects.link(ob)
        used = sorted({f[2] for f in part.faces})
        slot = {}
        for m in used:
            slot[m] = len(me.materials)
            me.materials.append(mats[m])
        uv = me.uv_layers.new(name="UVMap")
        for poly, (_, uvs, mat) in zip(me.polygons, part.faces):
            poly.material_index = slot[mat]
            poly.use_smooth = True
            for corner, li in enumerate(poly.loop_indices):
                uv.data[li].uv = uvs[corner]
        groups = {}
        for vi, weights in enumerate(part.weights):
            assert len(weights) <= 4, "%s vertex %d has more than 4 weights" % (part.name, vi)
            for bone_name, w in weights.items():
                if bone_name not in groups:
                    groups[bone_name] = ob.vertex_groups.new(name=bone_name)
                groups[bone_name].add([vi], w, "REPLACE")
        ob.parent = arm_obj
        mod = ob.modifiers.new(name="Armature", type="ARMATURE")
        mod.object = arm_obj
        tris = sum(len(pl.vertices) - 2 for pl in me.polygons)
        total += tris
        print("[%s] %s: %d triangles, materials %s" % (sid, part.name, tris, [mats[m].name for m in used]))
    print("[%s] the whole suit, gloves included: %d triangles" % (sid, total))
    if ao:  # (ao: the distance for baked shading in the vertex colours, see bake_vertex_ao)
        bake_vertex_ao([bpy.data.objects[pt.name] for pt in parts], mats, ao)

    os.makedirs(out or OUT, exist_ok=True)
    glb = os.path.join(out or OUT, sid + ".glb")
    extra = {"export_vertex_color": "ACTIVE"} if ao else {}
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_skins=True, export_animations=False,
                              export_yup=True, export_materials="EXPORT", export_image_format="AUTO", **extra)
    if not out:
        _write_scene_import(glb)
    print("[%s] wrote %s" % (sid, glb))
    for look, palette in looks.items():
        if look == "issue":
            continue
        q = Painter()
        paint_fn(q, palette)
        path = os.path.join(out or SKINS, "%s_%s.png" % (sid, look))
        if not out:
            _write_texture_import(path)
        psx.save_png(np.ascontiguousarray(q.finish()[0][::-1]), path)
        print("[%s] look %s: %s" % (sid, look, path))
    if "--preview" in args:
        preview(sid, args[args.index("--preview") + 1])
    if "--seamcheck" in args:
        seamcheck(sid, arm_obj, args[args.index("--seamcheck") + 1])
        if collar_on():
            _seamcheck_popped(sid, arm_obj, args[args.index("--seamcheck") + 1])
    if "--neckcheck" in args and collar_on():
        neckcheck(sid, arm_obj, args[args.index("--neckcheck") + 1])


def _seamcheck_popped(sid, arm_obj, folder):
    """The seam check again with the dome gone (Crew_Head hidden, as the collar leaves the body): no holes round the
    neck, the stump closing it (<sid>_popped_seams_<pose>.png)."""
    for ob in bpy.data.objects:
        for sl in ob.material_slots:
            if sl.material is not None:
                sl.material = bpy.data.materials[sl.material.name.split("__")[0]]
    bpy.data.objects["Crew_Head"].hide_render = True
    seamcheck(sid + "_popped", arm_obj, folder)
    bpy.data.objects["Crew_Head"].hide_render = False


def _write_scene_import(glb):
    """A new suit glb imports like deckhand_v2.glb (Kevin's suits: the PSX import script, the images kept embedded so
    nothing is extracted beside it, no LODs, no animation). Written once, before Godot first imports it (it fills in
    the uid and the imported path itself); an existing .import is left as it is."""
    imp = glb + ".import"
    if os.path.exists(imp):
        return
    rel = os.path.relpath(glb, ROOT).replace(os.sep, "/")
    with open(imp, "w") as f:
        f.write('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\n\n'
                'source_file="res://%s"\n\n[params]\n\n' % rel)
        f.write('nodes/root_type=""\nnodes/root_name=""\nnodes/root_script=null\n'
                'mesh_library/use_node_names_as_mesh_names=false\narray_mesh/deduplicate_surfaces=true\n'
                'nodes/apply_root_scale=true\nnodes/root_scale=1.0\nnodes/import_as_skeleton_bones=false\n'
                'nodes/use_name_suffixes=true\nnodes/use_node_type_suffixes=true\nmeshes/ensure_tangents=true\n'
                'meshes/generate_lods=false\nmeshes/create_shadow_meshes=true\nmeshes/light_baking=1\n'
                'meshes/lightmap_texel_size=0.2\nmeshes/force_disable_compression=false\nskins/use_named_skins=true\n'
                'animation/import=false\nanimation/fps=30\nanimation/trimming=false\n'
                'animation/remove_immutable_tracks=true\nanimation/import_rest_as_RESET=false\n'
                'import_script/path="res://assets/world/psx_import.gd"\nmaterials/extract=0\n'
                'materials/extract_format=0\nmaterials/extract_path=""\n_subresources={}\ngltf/naming_version=2\n'
                'gltf/embedded_image_handling=3\ngltf/texture_map_mode=1\n')
    print("[import] wrote %s (deckhand_v2.glb's settings)" % imp)


def _write_texture_import(png):
    """A look's atlas imports like the Deckhand's skins: lossless, mipmapped (the crew's Nearest Mipmap materials)."""
    imp = png + ".import"
    if os.path.exists(imp):
        return
    with open(imp, "w") as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="res://%s"\n\n'
                % os.path.relpath(png, ROOT).replace(os.sep, "/"))
        f.write("[params]\n\ncompress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\n"
                "compress/uastc_level=0\ncompress/rdo_quality_loss=0.0\ncompress/hdr_compression=1\n"
                "compress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=true\nmipmaps/limit=-1\n"
                "roughness/mode=0\nroughness/src_normal=\"\"\nprocess/channel_remap/red=0\n"
                "process/channel_remap/green=1\nprocess/channel_remap/blue=2\nprocess/channel_remap/alpha=3\n"
                "process/fix_alpha_border=false\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\n"
                "process/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\n"
                "detect_3d/compress_to=0\n")


# ------------------------------------------------------------------ preview: Blender views of the suit, one sheet
VIEWS = [
    # name, camera (Blender frame: the suit faces -Y), target, lens (mm) or ("ORTHO", scale)
    ("front", (0.0, -6.0, 0.95), (0.0, 0.0, 0.95), ("ORTHO", 2.05)),
    ("three_quarter", (1.75, -2.25, 1.45), (0.0, 0.0, 0.93), 40.0),
    ("side", (-6.0, 0.0, 0.95), (0.0, 0.0, 0.95), ("ORTHO", 2.05)),
    ("back", (0.0, 6.0, 0.95), (0.0, 0.0, 0.95), ("ORTHO", 2.05)),
    ("face", (0.42, -1.0, 1.72), (0.0, 0.0, 1.63), 50.0),
]


def preview(sid, folder):
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    for light, energy, rot in (("key", 3.2, (50.0, 0.0, -35.0)), ("fill", 1.2, (65.0, 0.0, 140.0)),
                               ("rim", 2.0, (-60.0, 0.0, 180.0))):
        ld = bpy.data.lights.new(light, "SUN")
        ld.energy = energy
        lo = bpy.data.objects.new(light, ld)
        lo.rotation_euler = tuple(math.radians(v) for v in rot)
        scene.collection.objects.link(lo)
    scene.render.resolution_x, scene.render.resolution_y = 360, 480
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 4
    except AttributeError:
        pass
    psx.render_views(VIEWS, folder, res=(360, 480), world=(0.36, 0.37, 0.39), strength=0.9)
    cells = [psx.load_image(os.path.join(folder, v[0] + ".png")) for v in VIEWS]
    h, w = cells[0].shape[:2]
    sheet_img = np.zeros((h, w * len(cells), 4), np.float32)
    for i, c in enumerate(cells):
        sheet_img[:, i * w:(i + 1) * w] = c
    sheet_img[..., 3] = 1.0
    out = os.path.join(folder, sid + "_sheet.png")
    psx.save_png(sheet_img, out)
    for v in VIEWS:
        os.remove(os.path.join(folder, v[0] + ".png"))
    print("[%s] preview sheet: %s" % (sid, out))


# ------------------------------------------------------------------ pieces seated on the body, not floating near it
def _target(part, skip_from=None, skip_to=None, skip_parts=()):
    """A BVH of every mesh's faces so far (Godot frame, all in the rest pose: the knife on the hips sits on the coat
    of the chest's mesh), leaving out the part's own faces made of vertices [skip_from, skip_to) and any mesh named
    in skip_parts."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for pt in _PARTS:
        if pt.name in skip_parts:
            continue
        base = len(verts)
        verts.extend(Vector(g) for g in pt.godot)
        for f in pt.faces:
            if pt is part and skip_from is not None and all(skip_from <= i < skip_to for i in f[0]):
                continue
            polys.append([base + i for i in f[0]])
    return BVHTree.FromPolygons(verts, polys)


def _target_without(part, faces, skip_parts=()):
    """As _target(), leaving out the part's faces numbered in `faces` (one island)."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for pt in _PARTS:
        if pt.name in skip_parts:
            continue
        base = len(verts)
        verts.extend(Vector(g) for g in pt.godot)
        polys.extend([base + i for i in f[0]] for fi, f in enumerate(pt.faces) if not (pt is part and fi in faces))
    return BVHTree.FromPolygons(verts, polys)


def _surface_gap(bvh, p, down, reach=0.08):
    """How far p stands off the surface under it, looking along `down` (a unit vector into the body): the distance
    down to a surface whose outside faces p, or minus the distance up to one if p is under it (inside the body);
    None if neither is within `reach`."""
    from mathutils import Vector
    p, down = Vector(p), Vector(down).normalized()
    e = 0.0005  # (from just off p: a point right on a surface still finds it)
    # under a skin first (a corner sunk into a shell must not read the coat inside the shell as the floor below it)
    loc, nrm, _, d = bvh.ray_cast(p + down * e, -down, reach)
    if loc is not None and nrm.dot(-down) > 0.0:
        return e - d
    loc, nrm, _, d = bvh.ray_cast(p - down * e, down, reach)
    if loc is not None and nrm.dot(down) < 0.0:
        return d - e
    return None


def _set(part, i, g):
    part.godot[i] = tuple(g)
    part.verts[i] = to_blender(part.godot[i])


def seat(part, start, facing, sink=0.0015, turn=True, name=""):
    """Sits a rigid piece (its vertices from `start` on: a pouch, a box with its dial, a bolt) on the body under it:
    turned so its `facing` (the way its front looks) is the body's normal under its middle, then pushed in along
    that normal until no corner of its underside stands off the surface (the worst `sink` into it). Returns move(p):
    the same turn and push for a point that goes with the piece (where a hose plugs into it)."""
    from mathutils import Vector, Matrix
    end = len(part.godot)
    bvh = _target(part, start, end)
    vs = [Vector(part.godot[i]) for i in range(start, end)]
    c = sum(vs, Vector()) / len(vs)
    f = Vector(facing).normalized()
    loc, nrm, _, _ = bvh.ray_cast(c + f * 0.12, -f, 0.3)
    if loc is None or nrm.dot(f) <= 0.0:
        loc, nrm, _, _ = bvh.find_nearest(c, 0.3)
    n = nrm.normalized() if (turn and loc is not None) else f
    rot = f.rotation_difference(n).to_matrix() if turn else Matrix.Identity(3)
    vs = [c + rot @ (v - c) for v in vs]
    # each underside corner's gap to the surface right under it (within 2.5 cm: a ray past the piece's edge finds the
    # body somewhere behind it, not under it), the worst sets the push, never more than 60% of the piece's depth
    gaps = [g for v in vs if (v - c).dot(n) < -1e-5 for g in [_surface_gap(bvh, v, -n, 0.025)] if g is not None]
    depth = max((v - c).dot(n) for v in vs) - min((v - c).dot(n) for v in vs)
    push = min(max(gaps) + sink, 0.6 * depth) if gaps else 0.0
    for i, v in zip(range(start, end), vs):
        _set(part, i, v - n * push)
    if name:  # what it did, and any underside corner still hanging past the surface's edge
        under = [v - n * push for v in vs if (v - c).dot(n) < -1e-5]
        past = [bvh.find_nearest(v, 1.0)[3] for v in under if _surface_gap(bvh, v, -n, 0.025) is None]
        left = [g for v in under for g in [_surface_gap(bvh, v, -n, 0.025)] if g is not None]
        print("[seat] %-14s turned %4.1f deg, pushed %5.1f mm; %d underside corners over the surface (the worst %+.1f "
              "mm off it), %d past its edge%s" % (name, math.degrees(f.angle(n)), push * 1000, len(left),
                                                 max(left) * 1000 if left else 0.0, len(past),
                                                 " (up to %.1f mm off it)" % (max(past) * 1000) if past else ""))
    return lambda p: tuple(c + rot @ (Vector(p) - c) - n * push)


def slab(part, centre, right, up, w, h, t, weights, uv_patch, mat=MAT_BODY, front=None, segs=(1, 1), sink=0.0015):
    """A plate that wraps onto the body under it (a knee patch, a storm flap, a name tape): a grid of segs (across,
    up), each point of its back pushed straight in (against right x up, its front) onto the surface already there,
    `sink` into it, its front t out along the surface's normal at that point. No back face (it's under the
    surface). One colour, or front = a region mapped across the front, as plate()."""
    from mathutils import Vector
    r, u = norm(right), norm(up)
    n = Vector(norm(cross(r, u)))
    nu, nv = segs
    bvh = _target(part)
    back, fr = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            a, b = i / nu - 0.5, j / nv - 0.5
            p = Vector([centre[k] + r[k] * a * w + u[k] * b * h for k in range(3)]) - n * (t / 2.0)
            nn = n
            loc, nrm, _, _ = bvh.ray_cast(p + n * 0.08, -n, 0.25)
            if loc is not None and nrm.dot(n) > 0.0:
                nn = nrm.normalized()
                p = loc - nn * sink
            back.append(p)
            fr.append(p + nn * t)
    ib = [part.vert(tuple(p), weights) for p in back]
    jf = [part.vert(tuple(p), weights) for p in fr]

    def at(i, j):
        return j * (nu + 1) + i

    def inside(i, j):  # the middle of cell (i, j), between back and front
        cs = [at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)]
        return [sum(back[q][k] + fr[q][k] for q in cs) / 8.0 for k in range(3)]
    pu = [uv_px(*uv_patch)] * 4
    for j in range(nv):
        for i in range(nu):
            q = [at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)]
            if front is not None:
                x, y, fw, fh = front
                uvs = [uv_px(x + fw * a / nu, y + fh * b / nv) for (a, b) in ((i, j), (i + 1, j), (i + 1, j + 1),
                                                                              (i, j + 1))]
            else:
                uvs = pu
            part.face([jf[k] for k in q], uvs, mat, inside(i, j))
    for i in range(nu):  # the rim: bottom and top edges, then the sides
        for j, cj in ((0, 0), (nv, nv - 1)):
            part.face([ib[at(i, j)], ib[at(i + 1, j)], jf[at(i + 1, j)], jf[at(i, j)]], pu, mat, inside(i, cj))
    for j in range(nv):
        for i, ci in ((0, 0), (nu, nu - 1)):
            part.face([ib[at(i, j)], ib[at(i, j + 1)], jf[at(i, j + 1)], jf[at(i, j)]], pu, mat, inside(ci, j))


def on_surface(part, p, down, lift):
    """The point on the body's surface under p (looking along `down`), `lift` off it along its normal: where a hose
    lies (p itself if nothing is under it)."""
    from mathutils import Vector
    d = Vector(down).normalized()
    loc, nrm, _, _ = _target(part).ray_cast(Vector(p) - d * 0.15, d, 0.4)
    if loc is None or nrm.dot(d) >= 0.0:
        return tuple(p)
    return tuple(loc + nrm.normalized() * lift)


# ------------------------------------------------------------------ the float check: every piece sits on the body
def floatcheck(sid, parts, limit=0.002, biggest=0.3, near=0.03, skip=("Crew_Gloves",)):
    """Finds the pieces that stand off the body (Kevin, 2026-10-15: the gadgets "arent flush against the body in a lot
    of spots"). Every piece is built apart, so each is its own island of faces; each island no more than `biggest`
    across is measured against everything else in its mesh: of its faces that face the body (within `near` of it,
    turned against the surface under them), how far their corners stand off that surface. Prints the pieces whose
    worst corner is more than `limit` off (a gap you'd see between the piece and the body), worst first."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    found = []
    for pt in parts:
        if pt.name in skip:
            continue
        parent = list(range(len(pt.godot)))

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        for idx, _, _ in pt.faces:
            for j in idx[1:]:
                a, b = find(idx[0]), find(j)
                if a != b:
                    parent[b] = a
        islands = {}
        for fi, (idx, _, _) in enumerate(pt.faces):
            islands.setdefault(find(idx[0]), []).append(fi)
        verts = [Vector(g) for g in pt.godot]
        for root, fis in islands.items():
            vids = sorted({i for fi in fis for i in pt.faces[fi][0]})
            lo = [min(pt.godot[i][k] for i in vids) for k in range(3)]
            hi = [max(pt.godot[i][k] for i in vids) for k in range(3)]
            if math.dist(lo, hi) > biggest:
                continue
            bvh = _target_without(pt, set(fis), skip)
            gap, under = -1.0, 0
            vs = [verts[i] for i in vids]
            c = sum(vs, Vector()) / len(vs)
            loc, nrm, _, dist = bvh.find_nearest(c, 0.08)
            if loc is None:  # nothing under it: not a piece on the body
                continue
            down = -nrm.normalized()  # its support: into the surface nearest its middle
            for fi in fis:
                pts = [verts[i] for i in pt.faces[fi][0]]
                nf = (pts[1] - pts[0]).cross(pts[2] - pts[0])
                if nf.length < 1e-12 or nf.normalized().dot(down) < 0.7:  # not its underside
                    continue
                under += 1
                for p in pts:
                    g = _surface_gap(bvh, p, down, near)
                    if g is None:  # past the surface's edge: how far it is from it
                        g = bvh.find_nearest(p, 1.0)[3] or 0.0
                    gap = max(gap, g)
            if under and gap > limit:
                found.append((gap, pt.name, [(lo[k] + hi[k]) / 2.0 for k in range(3)], math.dist(lo, hi), len(vids)))
    for gap, name, c, size, nv in sorted(found, reverse=True):
        print("[%s] float %-11s at (%5.1f, %5.1f, %5.1f) cm, %4.1f cm across, %3d verts: %4.1f mm off" % (
            sid, name, c[0] * 100, c[1] * 100, c[2] * 100, size * 100, nv, gap * 1000))
    print("[%s] FLOAT %s" % (sid, "CLEAN" if not found else "%d pieces off the body" % len(found)))


# ------------------------------------------------------------------ the seam check: no back face may show from outside
SEAM_POSES = {
    # pose -> {bone: (x, y, z) degrees, in the bone's own frame (every bone points up: x swings it front to back, a
    # minus forward; z swings it out to the side, plus for the left)}
    "rest": {},
    "fishing": {"arm_l": (-70.0, 0.0, 8.0), "fore_l": (-30.0, 0.0, 0.0), "arm_r": (-80.0, 0.0, -8.0),
                "fore_r": (-25.0, 0.0, 0.0), "head": (15.0, 30.0, 0.0), "torso": (8.0, 0.0, 0.0)},
    "reach": {"arm_l": (0.0, 0.0, 95.0), "arm_r": (-165.0, 0.0, 0.0), "head": (-25.0, -35.0, 0.0),
              "torso": (0.0, 15.0, 0.0)},
    "walk": {"thigh_l": (-38.0, 0.0, 0.0), "shin_l": (20.0, 0.0, 0.0), "thigh_r": (28.0, 0.0, 0.0),
             "shin_r": (45.0, 0.0, 0.0), "foot_r": (-15.0, 0.0, 0.0), "arm_l": (25.0, 0.0, 0.0),
             "arm_r": (-25.0, 0.0, 0.0)},
}


def seamcheck(sid, arm_obj, folder, threshold=0.015):
    """Finds every spot you could see through the suit: an open tube end, a gap, a face turned the wrong way. The suit
    is rendered twice from 16 directions (8 round it, 4 from above, 4 from below) in each of SEAM_POSES, each pixel
    the distance to the nearest surface: once with every face drawn, once one-sided as the game draws it. Where the
    one-sided distance is more than `threshold` past the two-sided one, you'd look past a surface into the suit (or
    through it): a hole. (A lining or a brim's underside a few millimetres in is not one: cloth folding over in a
    pose shows its lining, as it should.) Writes <sid>_seams_<pose>.png (the suit flat-lit, holes magenta) and prints
    the holes' pixels per view, and by the part whose inside shows through them (its atlas region)."""
    os.makedirs(folder, exist_ok=True)
    near, far = 0.3, 8.3
    depth_mats, flat_mats, uv_mats = {}, {}, {}
    for mat in list(bpy.data.materials):
        if not mat.use_nodes or mat.name.endswith("__depth"):
            continue
        dm = bpy.data.materials.new(mat.name + "__depth")
        dm.use_nodes = True
        nodes, links = dm.node_tree.nodes, dm.node_tree.links
        for n in list(nodes):
            nodes.remove(n)
        cam = nodes.new("ShaderNodeCameraData")
        rng = nodes.new("ShaderNodeMapRange")
        rng.inputs["From Min"].default_value = near
        rng.inputs["From Max"].default_value = far
        emit = nodes.new("ShaderNodeEmission")
        out = nodes.new("ShaderNodeOutputMaterial")
        links.new(cam.outputs["View Distance"], rng.inputs["Value"])
        links.new(rng.outputs["Result"], emit.inputs["Color"])
        links.new(emit.outputs["Emission"], out.inputs["Surface"])
        depth_mats[mat.name] = dm
        fm = mat.copy()
        fm.name = mat.name + "__flat"
        fnodes, flinks = fm.node_tree.nodes, fm.node_tree.links
        tex = next((n for n in fnodes if n.type == "TEX_IMAGE" and n.image and not n.image.name.endswith("_glow")),
                   None)
        fout = next(n for n in fnodes if n.type == "OUTPUT_MATERIAL")
        femit = fnodes.new("ShaderNodeEmission")
        if tex is not None:
            flinks.new(tex.outputs["Color"], femit.inputs["Color"])
        flinks.new(femit.outputs["Emission"], fout.inputs["Surface"])
        fm.use_backface_culling = True
        flat_mats[mat.name] = fm
        um = bpy.data.materials.new(mat.name + "__uv")
        um.use_nodes = True
        unodes, ulinks = um.node_tree.nodes, um.node_tree.links
        for n in list(unodes):
            unodes.remove(n)
        coord = unodes.new("ShaderNodeTexCoord")
        uemit = unodes.new("ShaderNodeEmission")
        uout = unodes.new("ShaderNodeOutputMaterial")
        ulinks.new(coord.outputs["UV"], uemit.inputs["Color"])
        ulinks.new(uemit.outputs["Emission"], uout.inputs["Surface"])
        uv_mats[mat.name] = um
    meshes = [ob for ob in bpy.data.objects if ob.type == "MESH"]
    originals = {ob.name: [sl.material for sl in ob.material_slots] for ob in meshes}

    def use(kind, two_sided=False):
        for ob in meshes:
            for k, sl in enumerate(ob.material_slots):
                base = originals[ob.name][k]
                m = {"depth": depth_mats, "flat": flat_mats, "uv": uv_mats}[kind][base.name]
                m.use_backface_culling = not two_sided
                sl.material = m

    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 1
    scene.render.filter_size = 0.0
    scene.render.resolution_x, scene.render.resolution_y = 240, 300
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Raw"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_depth = "16"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    cam_data = bpy.data.cameras.new("SeamCam")
    cam_data.lens = 40.0
    cam_data.clip_start = 0.05
    cam_data.clip_end = 100.0
    cam = bpy.data.objects.new("SeamCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = []
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        views.append(("round%d" % i, (3.0 * math.sin(a), -3.0 * math.cos(a), 1.35), (0.0, 0.0, 1.0)))
    for i in range(4):
        a = 2.0 * math.pi * i / 4.0 + math.pi / 4.0
        views.append(("above%d" % i, (1.6 * math.sin(a), -1.6 * math.cos(a), 3.2), (0.0, 0.0, 1.1)))
    for i in range(4):
        a = 2.0 * math.pi * i / 4.0
        views.append(("below%d" % i, (2.2 * math.sin(a), -2.2 * math.cos(a), 0.05), (0.0, 0.0, 1.05)))
    tmp = os.path.join(folder, "_%s_tmp.png" % sid)

    def shot(kind, two_sided, background):
        use(kind, two_sided)
        scene.view_settings.view_transform = "Standard" if kind == "flat" else "Raw"
        bg.inputs["Color"].default_value = (*background, 1.0)
        bg.inputs["Strength"].default_value = 1.0
        scene.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = psx.load_image(tmp)
        return img

    def crops(flat, hole, name):
        """Close-ups of where the holes are (up to three a view: the biggest clumps), four times over."""
        out = []
        ys, xs = np.nonzero(hole)
        taken = np.zeros_like(hole)
        for _ in range(3):
            left = hole & ~taken
            if not left.any():
                break
            ys, xs = np.nonzero(left)
            cy, cx = int(np.median(ys)), int(np.median(xs))
            y0, x0 = max(0, min(cy - 24, flat.shape[0] - 48)), max(0, min(cx - 24, flat.shape[1] - 48))
            c = flat[y0:y0 + 48, x0:x0 + 48].copy()
            taken[y0:y0 + 48, x0:x0 + 48] = True
            out.append(np.repeat(np.repeat(c, 4, 0), 4, 1))
        return out

    total = {}
    closeups = []
    for pose, bones in SEAM_POSES.items():
        for pb in arm_obj.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = tuple(math.radians(v) for v in bones.get(pb.name, (0.0, 0.0, 0.0)))
        bpy.context.view_layer.update()
        cells, counts, parts = [], [], {}
        for (name, loc, target) in views:
            cam.location = loc
            psx.look_at(cam, target)
            both = shot("depth", True, (1.0, 1.0, 1.0))[..., 0] * (far - near) + near
            one = shot("depth", False, (1.0, 1.0, 1.0))[..., 0] * (far - near) + near
            flat = shot("flat", False, (0.32, 0.33, 0.34))
            hole = (one - both) > threshold
            if hole.any():  # the part whose inside you see: the nearest face drawn two-sided, by its atlas texel
                uv = shot("uv", True, (0.0, 0.0, 0.0))
                tx = np.clip((uv[..., 0][hole] * TEX).astype(int), 0, TEX - 1)
                ty = np.clip((uv[..., 1][hole] * TEX).astype(int), 0, TEX - 1)
                for x, y in zip(tx, ty):
                    lab = atlas_label(int(x), int(y))
                    parts[lab] = parts.get(lab, 0) + 1
            flat[hole] = (1.0, 0.0, 1.0, 1.0)
            counts.append(int(hole.sum()))
            cells.append(flat)
            if hole.sum() >= 4:
                closeups.extend(crops(flat, hole, name))
        rows = [np.concatenate(cells[r * 8:(r + 1) * 8], axis=1) for r in range(2)]
        sheet_img = np.concatenate(rows, axis=0)
        sheet_img[..., 3] = 1.0
        psx.save_png(sheet_img, os.path.join(folder, "%s_seams_%s.png" % (sid, pose)))
        total[pose] = sum(counts)
        print("[%s] seams %s: %d px see-through; by view %s" % (sid, pose, total[pose],
                                                               {v[0]: c for v, c in zip(views, counts) if c}))
        if parts:
            print("[%s] seams %s by part: %s" % (sid, pose, dict(sorted(parts.items(), key=lambda kv: -kv[1])[:10])))
    if os.path.exists(tmp):
        os.remove(tmp)
    if closeups:  # every close-up, 8 a row
        closeups = closeups[:48]
        while len(closeups) % 8:
            closeups.append(np.zeros_like(closeups[0]))
        grid = np.concatenate([np.concatenate(closeups[r:r + 8], axis=1) for r in range(0, len(closeups), 8)], axis=0)
        grid[..., 3] = 1.0
        psx.save_png(grid, os.path.join(folder, "%s_holes.png" % sid))
    print("[%s] SEAMS %s" % (sid, "CLEAN" if not any(total.values()) else total))


# ------------------------------------------------------------------ the variants: plain, and with MAWCO's bomb collar
def collar_on():
    """-- --collar: this run builds the suit with MAWCO's bomb collar on (its own glb and looks: variant())."""
    return "--collar" in _args()


def variant(sid):
    """The id this run builds: `sid`, or `sid` + "_collar" with -- --collar (the Deckhand's naming: deckhand_v2.glb,
    deckhand_v2_collar.glb; the game wears the collar one and core/player/player.gd swaps "_collar.glb" for ".glb"
    while the collar intro's arm hasn't fitted it yet)."""
    return sid + "_collar" if collar_on() else sid


def bolt(part, at, normal, weights, uv_patch, size=0.014, t=0.008, up=(0.0, 1.0, 0.0), name=""):
    """A square bolt head (or a rivet, a small boss) at `at` facing `normal`, seated on the body under it (seat()): the
    Deckhand v2's yoke bolts. `up`: the way its sides line up (any direction off the normal). Returns seat()'s move."""
    n = norm(normal)
    if abs(dot(norm(up), n)) > 0.95:
        up = (0.0, 0.0, 1.0) if abs(n[2]) < 0.95 else (1.0, 0.0, 0.0)
    u = norm(sub(up, scale(n, dot(up, n))))
    s0 = len(part.godot)
    plate(part, at, cross(u, n), u, size, size, t, weights, uv_patch)
    return seat(part, s0, n, name=name)


# ------------------------------------------------------------------ the bomb collar: one device on every suit
# MAWCO's collar holds your dome on; when it fires, the dome goes (Kevin, 2026-10-16: "add a visible collar to the
# dechkhand model"; built first in build_deckhand_v2.py, moved here unchanged so every suit wears the same one). A
# heavy band of blackened bare steel clamped over the neck seal, the one unpainted part of any kit (no stripes, no
# lettering): a hinge on the right, a squat lock block at the back, and at the front a small red lens in a little cage,
# where world/ship/collars.gd puts its light (the suit's collar_lens in world/ship/locker_catalog.gd). It's the body's
# (Crew_Upper): off your own camera like your shoulders, and left on the neck, its inside sooted, when the collar goes
# and takes the dome (Crew_Head, the seal with it). Its pieces are swept along the band's facets so they bend with it
# (Kevin, 2026-10-16: "the side pieces, light and backpieces need to bend with the collar instead of being flat"; "the
# inside of the collar you can see through": the inner wall faces in with its own strip); a stump closes the neck.
# The numbers are the Deckhand v2's neck; collar_fit() moves and sizes the whole device onto another suit's neck seal.
COLLAR_LENS = (0.0, 1.477, 0.172)  # the lens's glass on the Deckhand, model space (collars.gd: less the torso's 0.92 y)
BAND_SIDES = 24  # the band round, turned half a side: the back, front and sides are flat facets the pieces sit on
BAND_TURN = math.pi / BAND_SIDES
BAND_STEP = 2.0 * math.pi / BAND_SIDES
FACE_LO = ((0.0, 1.465, 0.009), 0.163, 0.148)  # the band's face, its foot and its top (centre, r1, r2)
FACE_HI = ((0.0, 1.488, 0.014), 0.165, 0.15)
# The ring of the Deckhand's neck seal the band clamps (its seal at y 1.464): collar_fit() maps it onto a suit's own.
COLLAR_SEAT = ((0.0, 1.464, 0.006), 0.147, 0.137)
# What the collar needs in a suit's atlas: these solid patches (add them to patches()) and these regions (w, h) placed
# anywhere free in the suit's R. A v2 suit paints them in BOTH variants, so its plain and collar atlases are the same
# and a look's png dresses either glb (the collar intro wears the plain glb in the collar look's paint).
COLLAR_PATCHES = ["steel", "soot", "lens", "edge"]
COLLAR_REGIONS = {"collar": (48, 8), "collar_in": (16, 8), "stump": (16, 16)}


def _off(p, *terms):
    """p plus each (vector, k) in terms."""
    return tuple(p[i] + sum(v[i] * k for v, k in terms) for i in range(3))


def _facet_point(spec, a):
    """Ring `spec` (centre, r1, r2)'s point at angle a on the band's facets: straight between the band's corners either
    side, so a piece swept with it lies flat on each facet and bends at the band's corners."""
    c, r1, r2 = spec
    f = (a - BAND_TURN) / BAND_STEP
    k = math.floor(f + 1e-9)
    a0 = BAND_TURN + k * BAND_STEP
    return lerp(ring_point(c, r1, r2, a0), ring_point(c, r1, r2, a0 + BAND_STEP), f - k)


def _on_face(d, y):
    """The ring `d` out from the band's face (in: below 0) at height y."""
    (c0, a0, b0), (c1, a1, b1) = FACE_LO, FACE_HI
    f = (y - c0[1]) / (c1[1] - c0[1])
    return (lerp(c0, c1, f), a0 + (a1 - a0) * f + d, b0 + (b1 - b0) * f + d)


def _band_arc(a0, a1, extra=()):
    """The angles a piece from a0 to a1 is swept at: its ends, every band corner between, and `extra`."""
    out = [a0, a1] + list(extra)
    k = math.ceil((a0 - BAND_TURN) / BAND_STEP)
    while BAND_TURN + k * BAND_STEP < a1:
        out.append(BAND_TURN + k * BAND_STEP)
        k += 1
    out.sort()
    return [a for i, a in enumerate(out) if i == 0 or a - out[i - 1] > 1e-6]


def _span(a, s):
    """The angle that goes `s` metres round the band's face at angle a."""
    _, r1, r2 = _on_face(0.0, 1.477)
    return s / math.hypot(r1 * math.cos(a), r2 * math.sin(a))


def _facet_frame(a):
    """The band's face at angle a: (round, the way the angle grows; up, along the face; out), unit vectors."""
    a0 = BAND_TURN + math.floor((a - BAND_TURN) / BAND_STEP + 1e-9) * BAND_STEP
    spec = _on_face(0.0, 1.477)
    rnd = norm(sub(ring_point(*spec, a0 + BAND_STEP), ring_point(*spec, a0)))
    up = norm(sub(_facet_point(FACE_HI, a), _facet_point(FACE_LO, a)))
    return rnd, up, norm(cross(up, rnd))


def _band_sweep(part, section, angles, bands, weights, closed=False, caps=None, skip=()):
    """A cross-section swept round the band's facets. section: ring specs (centre, r1, r2) in order round it, the last
    joining the first; a row of points at each of `angles`. Each face is turned away from the section's middle at its
    angle, so an inner wall faces in and a top faces up. bands: one (region, material) per section edge, u round the
    angles, v from the edge's first point to its next. closed: all the way round (the first angle not repeated); else
    caps: (patch, material) closing the two ends. skip: (edge, angle index) faces left out (a hole). Points are only
    made where a face uses them; returns at(edge point, angle index) -> the vertex."""
    m, ns = len(angles), len(section)
    made = {}

    def at(k, j):
        if (k, j) not in made:
            made[(k, j)] = part.vert(_facet_point(section[k], angles[j]), weights)
        return made[(k, j)]

    mids = [tuple(sum(_facet_point(s, a)[i] for s in section) / ns for i in range(3)) for a in angles]
    total = 2.0 * math.pi if closed else angles[-1] - angles[0]
    for k in range(ns):
        k2 = (k + 1) % ns
        (x0, y0, rw, rh), mat = bands[k]
        for j in range(m if closed else m - 1):
            if (k, j) in skip:
                continue
            j2 = (j + 1) % m
            u0 = x0 + rw * (angles[j] - angles[0]) / total
            u1 = x0 + rw * ((angles[j2] if j2 else angles[0] + 2.0 * math.pi) - angles[0]) / total
            part.face([at(k, j), at(k, j2), at(k2, j2), at(k2, j)],
                      [uv_px(u0, y0), uv_px(u1, y0), uv_px(u1, y0 + rh), uv_px(u0, y0 + rh)], mat,
                      lerp(mids[j], mids[j2], 0.5))
    if caps:
        (pu, pv), mat = caps
        for j, nxt in ((0, 1), (m - 1, m - 2)):
            part.face([at(k, j) for k in range(ns)], [uv_px(pu, pv)] * ns, mat, mids[nxt])
    return at


def collar_fit(seat_centre, seat_r1, seat_r2):
    """The map that puts the Deckhand's collar on another suit's neck: the ring of the Deckhand's seal the band clamps
    (COLLAR_SEAT) onto the suit's own seal ring (centre, r1 across X, r2 across Z) at the height the band should clamp
    it. The band, its pieces, the lens and the stump move up or down with it and scale round the neck by r1 / 0.147
    across and r2 / 0.137 front to back. It's one device: build the suit's neck seal near the Deckhand's numbers (a scale
    of 1 is the Deckhand's collar exactly; past 0.92 to 1.1 it prints a warning)."""
    (c0, a0, b0) = COLLAR_SEAT
    sx, sz = seat_r1 / a0, seat_r2 / b0
    dy, cz = seat_centre[1] - c0[1], seat_centre[2]
    if not (0.92 <= sx <= 1.1 and 0.92 <= sz <= 1.1):
        print("[collar] WARNING: the collar scaled %.2f x %.2f to fit: build the neck seal nearer the Deckhand's "
              "(r %.3f x %.3f)" % (sx, sz, a0, b0))

    def fit(p):
        return (seat_centre[0] + p[0] * sx, p[1] + dy, cz + (p[2] - c0[2]) * sz)
    fit.scale = (sx, sz)
    fit.lift = dy
    return fit


def collar(part, weights, regions, where, fit=None, stump=True):
    """MAWCO's bomb collar on `part` (the suit's Crew_Upper), its pieces weighted `weights` (the torso): the band, the
    lock block, the hinge, the lens in its cage, and the stump closing the neck under the dome. regions / where: the
    suit's R (with COLLAR_REGIONS) and patches (with COLLAR_PATCHES). fit: collar_fit() for another suit's neck (None:
    the Deckhand's neck, exactly). stump: True, the Deckhand's (moved with the fit); or (centre, r1, r2), a disc of the
    suit's own at that height (unfitted), closing its neck under the dome; or None. Returns the lens's glass in model
    space (its collar_lens for world/ship/locker_catalog.gd: y less the torso bone's 0.92)."""
    start = len(part.godot)

    def band(region, row, rows, mat=MAT_BODY):
        return region_band(regions, region, row, rows, mat)

    def solid(name):
        return solid_region(where, name)

    steel, soot = (solid("steel"), MAT_BODY), (solid("soot"), MAT_BODY)
    # the band: its foot sunk in the yoke's neck, a chamfer, the face (leaning forward a little, as the dome does), a
    # chamfer, the top (worn bright), the inside (facing in: its own strip, scorched along the top where the dome blew
    # off) and the underside back to the foot; its middle drifts forward with the dome's
    _band_sweep(part, [((0.0, 1.458, 0.008), 0.157, 0.142), FACE_LO, FACE_HI, ((0.0, 1.494, 0.016), 0.16, 0.146),
                       ((0.0, 1.494, 0.016), 0.15, 0.14), ((0.0, 1.461, 0.008), 0.147, 0.133)],
                [BAND_TURN + BAND_STEP * i for i in range(BAND_SIDES)],
                [steel, band("collar", 0, 8), steel, (solid("edge"), MAT_BODY), band("collar_in", 0, 8), soot], weights,
                closed=True)
    # the pieces wrap the band, each over about three facets, bending at its corners; their insides sunk 7 mm into it
    # the lock block at the back: squat, 2.8 cm proud, chamfered, two bolts and a keyway on its middle facet
    hw = _span(0.0, 0.035)
    _band_sweep(part, [_on_face(-0.007, 1.459), _on_face(0.025, 1.459), _on_face(0.028, 1.462), _on_face(0.028, 1.49),
                       _on_face(0.025, 1.493), _on_face(-0.007, 1.493)], _band_arc(-hw, hw), [steel] * 6, weights,
                caps=(where["steel"], MAT_BODY))
    lf = _facet_point(_on_face(0.028, 1.476), 0.0)
    rnd, up, out = _facet_frame(0.0)
    for bx in (-0.02, 0.02):
        plate(part, _off(lf, (rnd, bx), (out, 0.001)), scale(rnd, -1.0), up, 0.007, 0.007, 0.004, weights,
              where["soot"])
    disc(part, _off(lf, (out, 0.0008)), out, up, 0.008, 8, solid("soot"), MAT_BODY, weights)
    # the hinge on the right: three knuckles on a pin, a curved strap round the band either side
    ah = 1.5 * math.pi
    pin = _facet_point(_on_face(0.0, 1.477), ah)
    hx, hz = pin[0] - 0.0065, pin[2]
    for y0, y1 in ((1.461, 1.4705), (1.4725, 1.4815), (1.4835, 1.493)):
        pipe(part, [(hx, y0, hz), (hx, y1, hz)], 0.0085, 8, weights, where["steel"], caps=True)
    pipe(part, [(hx, 1.493, hz), (hx, 1.4975, hz)], 0.004, 6, weights, where["steel"], caps=True)
    leaf = [_on_face(-0.007, 1.462), _on_face(0.0025, 1.462), _on_face(0.004, 1.4635), _on_face(0.004, 1.4905),
            _on_face(0.0025, 1.492), _on_face(-0.007, 1.492)]
    for s0, s1 in ((-0.027, -0.004), (0.004, 0.027)):
        _band_sweep(part, leaf, _band_arc(ah + _span(ah, s0), ah + _span(ah, s1)), [steel] * 6, weights,
                    caps=(where["steel"], MAT_BODY))
    # the lamp at the front: a curved boss 1.7 cm proud, the lens sunk 4 mm in a bore through its middle facet, two
    # bars and a cross-bar (bending with the boss) over its mouth
    lens_at = COLLAR_LENS
    rnd, up, out = _facet_frame(math.pi)
    s0 = dot(sub(lens_at, _facet_point(_on_face(0.0, lens_at[1]), math.pi)), out)
    s1 = dot(sub(lens_at, _facet_point(_on_face(0.01, lens_at[1]), math.pi)), out)
    df = (-0.004 - s0) / ((s1 - s0) / 0.01)                # the boss's front: the lens 4 mm behind it
    cf = _off(lens_at, (out, 0.004))                       # the bore's mouth
    ym = cf[1]
    hw, q = _span(math.pi, 0.03), BAND_STEP / 4.0
    angles = _band_arc(math.pi - hw, math.pi + hw, (math.pi - q, math.pi, math.pi + q))
    jl, jh = (min(range(len(angles)), key=lambda j: abs(angles[j] - a)) for a in (math.pi - BAND_STEP / 2.0,
                                                                              math.pi + BAND_STEP / 2.0))
    at = _band_sweep(part, [_on_face(-0.007, ym - 0.017), _on_face(df - 0.003, ym - 0.017), _on_face(df, ym - 0.014),
                            _on_face(df, ym), _on_face(df, ym + 0.014), _on_face(df - 0.003, ym + 0.017),
                            _on_face(-0.007, ym + 0.017)], angles, [steel] * 7, weights, caps=(where["steel"], MAT_BODY),
                     skip={(k, j) for k in (2, 3) for j in range(jl, jh)})
    rim = ([at(4, j) for j in range(jl, jh + 1)] + [at(3, jh)] + [at(2, j) for j in range(jh, jl - 1, -1)]
           + [at(3, jl)])
    front = [part.vert(_off(cf, (norm(sub(part.godot[i], cf)), 0.0115)), weights) for i in rim]
    back = [part.vert(_off(part.godot[i], (out, -0.004)), weights) for i in front]
    behind, axis = _off(lens_at, (out, -0.01)), lerp(cf, lens_at, 0.5)
    su, ss, sl = uv_px(*where["steel"]), uv_px(*where["soot"]), uv_px(*where["lens"])
    glass = part.vert(lens_at, weights)
    for i in range(len(rim)):
        i2 = (i + 1) % len(rim)
        part.face([rim[i], rim[i2], front[i2], front[i]], [su] * 4, MAT_BODY, behind)
        bore = [front[i], front[i2], back[i2], back[i]]
        fc = [sum(part.godot[v][k] for v in bore) / 4.0 for k in range(3)]
        part.face(bore, [ss] * 4, MAT_BODY, add(fc, sub(fc, axis)))
        part.face([glass, back[i], back[i2]], [sl] * 3, MAT_BODY, behind)
    for bx in (-0.005, 0.005):
        c = _off(cf, (out, 0.0015), (rnd, bx))
        box(part, _off(c, (up, -0.0135)), _off(c, (up, 0.0135)), rnd, 0.003, 0.003, weights, where["steel"],
            cap_start=True)
    edge = _span(math.pi, 0.002)
    pipe(part, [_facet_point(_on_face(df + 0.0017, ym), a) for a in
                (math.pi - hw + edge, math.pi - BAND_STEP / 2.0, math.pi + BAND_STEP / 2.0, math.pi + hw - edge)],
         0.0016, 6, weights, where["steel"], caps=True)
    # the stump: the neck closed under the dome, just below the yoke's lip; seen only once the collar's taken the dome
    if stump is True:
        disc(part, (0.0, 1.4705, 0.006), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), 0.132, 12, regions["stump"], MAT_BODY,
             weights, ry=0.122)
    if fit is not None:  # (the identity skipped: the Deckhand's collar stays exactly as it was built)
        for i in range(start, len(part.godot)):
            _set(part, i, fit(part.godot[i]))
        lens_at = fit(lens_at)
    if stump not in (True, None, False):
        (sc, sr1, sr2) = stump
        disc(part, sc, (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), sr1, 12, regions["stump"], MAT_BODY, weights, ry=sr2)
    print("[collar] %d triangles; the lens at (%.4f, %.4f, %.4f): collar_lens Vector3(%.3f, %.3f, %.3f)%s" % (
        sum(len(f[0]) - 2 for f in part.faces[_faces_from(part, start):]), lens_at[0], lens_at[1], lens_at[2],
        lens_at[0], lens_at[1] - 0.92, lens_at[2],
        "" if fit is None else "; fitted: scale %.3f x %.3f, %+.1f mm up" % (fit.scale[0], fit.scale[1],
                                                                            fit.lift * 1000)))
    return lens_at


def _band_hit(g):
    """How deep Godot-frame point g (the torso's rest frame) is inside the collar's solid (the band, its lamp boss at
    the front, the lock block at the back, the hinge on the right), in metres; 0 outside."""
    y = g[1]
    if not 1.459 < y < 1.493:
        return 0.0
    f = (y - 1.461) / (1.494 - 1.461)
    i1, i2, iz = 0.147 + 0.003 * f, 0.133 + 0.007 * f, 0.008 + 0.008 * f      # the inner wall
    f = (y - FACE_LO[0][1]) / (FACE_HI[0][1] - FACE_LO[0][1])
    o1 = FACE_LO[1] + (FACE_HI[1] - FACE_LO[1]) * f
    o2 = FACE_LO[2] + (FACE_HI[2] - FACE_LO[2]) * f
    oz = FACE_LO[0][2] + (FACE_HI[0][2] - FACE_LO[0][2]) * f
    x, z = g[0], g[2]
    extra = 0.0
    if abs(x) < 0.03 and z > 0.0:
        extra = 0.018                                                        # the lamp's boss
    elif abs(x) < 0.035 and z < 0.0:
        extra = 0.028                                                        # the lock block
    elif x < -0.1 and abs(z - oz) < 0.027:
        extra = 0.012                                                        # the hinge
    d_in = math.hypot(x / i1, (z - iz) / i2)
    d_out = math.hypot(x / (o1 + extra), (z - oz) / (o2 + extra))
    if d_in <= 1.0 or d_out >= 1.0:
        return 0.0
    return min((d_in - 1.0) * i2, (1.0 - d_out) * (o2 + extra), y - 1.459, 1.493 - y)


def neckcheck(sid, arm_obj, folder, limit=0.003):
    """The collar against what moves above it, in each of SEAM_POSES (Kevin, 2026-10-23: the collar "sits right on the
    neck"): every vertex of Crew_Head that the head bone moves (the dome or helmet, the seal's top, a hose), taken into
    the torso's rest frame (the collar rides the torso), and how deep it goes into the collar's solid (_band_hit).
    Prints the worst and how many go past `limit`, and writes <sid>_neck.png: the neck close up in each pose (a row a
    pose: from the front above, the hinge side, the back above)."""
    from mathutils import Vector
    os.makedirs(folder, exist_ok=True)
    for ob in bpy.data.objects:  # (the seam check may have left its own materials on)
        for sl in ob.material_slots:
            if sl.material is not None:
                sl.material = bpy.data.materials[sl.material.name.split("__")[0]]
    scene = bpy.context.scene
    head = bpy.data.objects["Crew_Head"]
    gi = head.vertex_groups.get("head")
    moved = [v.index for v in head.data.vertices if gi is not None and any(g.group == gi.index and g.weight > 0.01
                                                                          for g in v.groups)]
    torso = arm_obj.pose.bones["torso"]
    cams = [("front", (0.38, -0.62, 1.95), (0.0, 0.0, 1.47)), ("hinge", (-0.75, -0.12, 1.66), (0.0, 0.0, 1.48)),
            ("back", (-0.3, 0.6, 1.95), (0.0, 0.0, 1.47))]
    res = 240
    scene.render.resolution_x, scene.render.resolution_y = res, res
    cells = []
    worst_all = {}
    for pose, bones in SEAM_POSES.items():
        for pb in arm_obj.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = tuple(math.radians(v) for v in bones.get(pb.name, (0.0, 0.0, 0.0)))
        bpy.context.view_layer.update()
        to_rest = (torso.matrix @ torso.bone.matrix_local.inverted()).inverted()
        dg = bpy.context.evaluated_depsgraph_get()
        ev = head.evaluated_get(dg)
        me = ev.to_mesh()
        hits = []
        for i in moved:
            b = to_rest @ (ev.matrix_world @ me.vertices[i].co)
            d = _band_hit((b.x, b.z, -b.y))
            if d > 0.0:
                hits.append(d)
        ev.to_mesh_clear()
        worst = max(hits) if hits else 0.0
        worst_all[pose] = round(worst * 1000, 1)
        print("[%s] neck %s: %d of the head's vertices into the collar, %d past %.0f mm, the worst %.1f mm" % (
            sid, pose, len(hits), sum(1 for d in hits if d > limit), limit * 1000, worst * 1000))
        psx.render_views([("_neck_" + n, loc, tgt, 50.0) for (n, loc, tgt) in cams], folder, res=(res, res),
                         world=(0.5, 0.5, 0.52), strength=1.0)
        row = [psx.load_image(os.path.join(folder, "_neck_%s.png" % n)) for (n, _, _) in cams]
        for (n, _, _) in cams:
            os.remove(os.path.join(folder, "_neck_%s.png" % n))
        cells.append(np.concatenate(row, axis=1))
    for pb in arm_obj.pose.bones:
        pb.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    grid = np.concatenate(cells, axis=0)
    grid[..., 3] = 1.0
    psx.save_png(grid, os.path.join(folder, "%s_neck.png" % sid))
    print("[%s] NECK %s (mm into the collar, the worst a pose; rows of %s_neck.png: %s)" % (
        sid, worst_all, sid, ", ".join(SEAM_POSES)))


def _faces_from(part, start):
    """The first face of `part` made only of vertices from `start` on."""
    for fi, f in enumerate(part.faces):
        if min(f[0]) >= start:
            return fi
    return len(part.faces)


def paint_collar(p, where, regions, rust):
    """The collar's paint, into the suit's atlas (p: the Painter; where / regions: the suit's patches and R; rust: the
    rust_metal photo, p.photo("rust_metal")): blackened bare steel, never painted; worn bright on its edges, rust weeping
    from the hinge and the lock; inside, soot; the lens dark red glass (its light is collars.gd's, at runtime); the
    stump the neck seal's torn rubber round clotted blood."""
    steel = (0.15, 0.145, 0.14)
    p.solid_patches(where, {"steel": steel, "soot": (0.045, 0.04, 0.037), "lens": (0.3, 0.035, 0.03),
                            "edge": shade(steel, 1.6)})
    r = regions["collar"]
    x, y, w, h = r
    p.fill(r, rust, steel, 0.55, sat=0.35, gain=0.9, punch=0.5)
    p.rect(x, y + h - 1, w, 1, shade(steel, 1.9))          # the top edge, worn bright
    p.rect(x, y, w, 1, shade(steel, 0.6))                   # the foot, in the yoke's shadow
    p.streaks(r, [(w // 4, h - 2), (3 * w // 4, h - 2), (2, h - 2), (w - 3, h - 2)], (0.32, 0.15, 0.08), 5, 0.6, 77)
    p.grime(r, 2, GRIME, 0.5, 78)
    # the inside: the same steel, darker, scorched black along its top (row 0) where the dome blew off; no blood (it
    # shows from above while you're alive)
    r = regions["collar_in"]
    p.fill(r, rust, shade(steel, 0.65), 0.6, sat=0.3, gain=0.85, punch=0.5, offset=(11, 3))
    p.grime(r, 4, (0.025, 0.022, 0.02), 0.85, 79)
    # the stump, round: the neck seal's torn rubber at its edge, inside dark clotted blood, a little meat, a few wet
    # glints (the AO bake darkens it under the lip: these are lifted to read after it)
    x, y, w, h = regions["stump"]
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot(xx - (w - 1) / 2.0, yy - (h - 1) / 2.0) / 7.5
    n = p.noise(w, h, 4, 83)
    one = np.ones((h, w), np.float32)
    p.mix(regions["stump"], one, (0.07, 0.066, 0.062))
    p.mix(regions["stump"], (d + 0.25 * (n - 0.5) < 0.78).astype(np.float32), (0.17, 0.04, 0.035))
    p.mix(regions["stump"], ((d < 0.62) & (n > 0.55)).astype(np.float32), (0.09, 0.02, 0.02))
    p.mix(regions["stump"], ((d < 0.55) & (n < 0.3)).astype(np.float32), (0.3, 0.07, 0.06), 0.8)
    for (gx, gy) in ((6, 7), (9, 5), (8, 10)):
        p.rect(x + gx, y + gy, 1, 1, (0.55, 0.2, 0.18))
