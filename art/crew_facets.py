"""The crew, modelled the low-poly way with more polygons: every form built from deliberate edge loops and flat
planes (a wedge of a nose, a ledge of a brow, cheekbone planes, a squared jaw, a boot with a toe and a sole), real
proportions, flat shaded, flat colours. Clean quad topology from the start (no retopology needed).

The pieces pivot at the joints, as crew/player.gd expects:
  "torso" (origin at the hips), "head" (at the neck), "arm_l"/"arm_r" (shoulders), "fore_l"/"fore_r" (elbows),
  "leg_l"/"leg_r" (hips), "shin_l"/"shin_r" (knees). The oilskins' material is "oilskin" (white: tinted in game).

Run: "C:/Program Files/Blender Foundation/Blender 4.3/blender.exe" -b --python art/crew_facets.py -- [--out=PATH]
     [--preview=DIR]
Blender: Z up, facing +Y (Godot -Z), the feet on Z = 0."""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

V = Vector
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "crew", "crew.glb")
PREVIEW = None
for a in sys.argv:
    if a.startswith("--out="):
        OUT = a.split("=", 1)[1]
    if a.startswith("--preview="):
        PREVIEW = a.split("=", 1)[1]


# ------------------------------------------------------------------------------------------------ materials

def mat(name, color, rough=0.8, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1.0)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if 'Specular IOR Level' in b.inputs:
        b.inputs['Specular IOR Level'].default_value = 0.25
    nt = m.node_tree
    va = nt.nodes.new('ShaderNodeVertexColor')
    va.layer_name = "Col"
    rgb = nt.nodes.new('ShaderNodeRGB')
    rgb.outputs[0].default_value = (*color, 1.0)
    mx = nt.nodes.new('ShaderNodeMix')
    mx.data_type = 'RGBA'
    mx.blend_type = 'MULTIPLY'
    mx.inputs['Factor'].default_value = 1.0
    nt.links.new(rgb.outputs[0], mx.inputs[6])
    nt.links.new(va.outputs['Color'], mx.inputs[7])
    nt.links.new(mx.outputs[2], b.inputs['Base Color'])
    m["rgb"] = rgb.name
    return m


def materials():
    return dict(
        oilskin=mat("oilskin", (0.92, 0.92, 0.9), 0.45),
        jumper=mat("jumper", (0.13, 0.17, 0.26), 0.95),
        jumper_dark=mat("jumper_dark", (0.09, 0.12, 0.19), 0.95),
        skin=mat("skin", (0.86, 0.6, 0.46), 0.7),
        socket=mat("socket", (0.6, 0.4, 0.34), 0.8),
        skin_warm=mat("skin_warm", (0.86, 0.5, 0.4), 0.7),
        stubble=mat("stubble", (0.5, 0.38, 0.32), 0.85),
        hair=mat("hair", (0.33, 0.21, 0.13), 0.9),
        eye=mat("eye", (0.05, 0.04, 0.04), 0.2),
        beanie=mat("beanie", (0.55, 0.12, 0.08), 0.95),
        glove=mat("glove", (0.85, 0.36, 0.08), 0.5),
        boot=mat("boot", (0.2, 0.17, 0.14), 0.55),
        sole=mat("sole", (0.08, 0.07, 0.06), 0.9),
        metal=mat("metal", (0.6, 0.6, 0.58), 0.35, 0.8),
        strap=mat("strap", (0.72, 0.72, 0.7), 0.5),
        oilskin_patch=mat("oilskin_patch", (0.68, 0.68, 0.66), 0.5),
        reflect=mat("reflect", (0.88, 0.9, 0.86), 0.3),
        eye_white=mat("eye_white", (0.93, 0.9, 0.84), 0.3),
        belt=mat("belt", (0.32, 0.2, 0.11), 0.7),
        rag=mat("rag", (0.78, 0.7, 0.52), 0.95),
        tag=mat("tag", (0.92, 0.86, 0.66), 0.8),
        stripe=mat("stripe", (0.85, 0.82, 0.74), 0.95),
    )


# ------------------------------------------------------------------------------------------------ edge loops

def ring(z, w, df, db=None, n=12, sq=2.0, x0=0.0, y0=0.0):
    """One edge loop at height z: a superellipse w wide (half), df in front and db behind (half), n points,
    point 0 dead ahead (+Y), going round to the left (-X) first... sq > 2 squares it off."""
    db = df if db is None else db
    pts = []
    e = 2.0 / sq
    for i in range(n):
        a = 2 * math.pi * i / n
        s, c = math.sin(a), math.cos(a)
        x = w * math.copysign(abs(s) ** e, s)
        y = (df if c >= 0 else db) * math.copysign(abs(c) ** e, c)
        pts.append(V((x0 + x, y0 + y, z)))
    return pts


class Loft:
    """A form as a stack of edge loops, bottom to top; tweak the vertices (the planes) before building."""

    def __init__(self, rings):
        self.r = [list(r) for r in rings]

    def push(self, ri, idx, d):
        for i in (idx if isinstance(idx, (list, tuple)) else [idx]):
            self.r[ri][i] = self.r[ri][i] + V(d)
        return self

    def scale(self, ri, idx, sx=1.0, sy=1.0):
        for i in (idx if isinstance(idx, (list, tuple)) else [idx]):
            p = self.r[ri][i]
            self.r[ri][i] = V((p.x * sx, p.y * sy, p.z))
        return self

    def build(self, bm, mat_of=None, cap_bottom=True, cap_top=True, default=0):
        """Into bmesh bm: quads between loops, fans to a centre point at the ends. mat_of(face centre) -> slot."""
        verts = [[bm.verts.new(p) for p in r] for r in self.r]
        faces = []
        n = len(self.r[0])
        for k in range(len(verts) - 1):
            a, b = verts[k], verts[k + 1]
            for i in range(n):
                j = (i + 1) % n
                faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
        for which, cap in ((0, cap_bottom), (-1, cap_top)):
            if not cap:
                continue
            loop = verts[which]
            c = sum((v.co for v in loop), V()) / n
            cv = bm.verts.new(c)
            for i in range(n):
                j = (i + 1) % n
                f = bm.faces.new((loop[j], loop[i], cv) if which == 0 else (loop[i], loop[j], cv))
                faces.append(f)
        for f in faces:
            f.material_index = mat_of(f.calc_center_median()) if mat_of else default
        return faces


def strip(bm, path, w, t, slot):
    """A flat strap along a path of points (a brace, a strap): w wide, t thick, lying flat to the body."""
    rings = []
    for k, p in enumerate(path):
        p = V(p)
        d = (V(path[min(k + 1, len(path) - 1)]) - V(path[max(k - 1, 0)])).normalized()
        out = V((0, p.y, 0)).normalized() if abs(p.y) > 1e-4 else V((0, 1, 0))
        side = d.cross(out).normalized()
        out = side.cross(d).normalized()
        rings.append([p + side * w + out * t, p - side * w + out * t, p - side * w - out * t, p + side * w - out * t])
    Loft(rings).build(bm, default=slot)


def block(bm, lo, hi, slot, taper=1.0):
    """A small box (a buckle, an eye, a pocket), lo..hi; taper < 1 narrows its top (a wedge)."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    r0 = [V((cx + sx * hx, cy + sy * hy, z0)) for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    r1 = [V((cx + sx * hx * taper, cy + sy * hy * taper, z1)) for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    Loft([r0, r1]).build(bm, default=slot)


# ------------------------------------------------------------------------------------------------ the pieces

SLOTS = ["oilskin", "jumper", "jumper_dark", "skin", "socket", "skin_warm", "stubble", "hair", "eye", "beanie", "glove",
         "boot", "sole", "metal", "strap", "oilskin_patch", "reflect", "eye_white", "belt", "rag", "tag", "stripe"]
S = {n: i for i, n in enumerate(SLOTS)}

# the joints (a 1.80 m man, real proportions)
HIP, NECK = 0.95, 1.52
SH = V((0.19, 0.0, 1.43))
ELBOW, WRIST, KNEE = 1.12, 0.86, 0.5
LEG_X = 0.095


def torso(bm):
    """The jumper, the oilskin bib-and-brace over it, braces and buckles."""
    rings = [
        ring(HIP - 0.03, 0.165, 0.11, 0.12, 16, 2.4),
        ring(HIP + 0.04, 0.17, 0.115, 0.125, 16, 2.4),
        ring(HIP + 0.13, 0.162, 0.135, 0.112, 16, 2.4),       # the waist, a bit of a belly
        ring(HIP + 0.24, 0.168, 0.138, 0.112, 16, 2.6),
        ring(HIP + 0.34, 0.18, 0.13, 0.118, 16, 2.8),         # the chest
        ring(HIP + 0.385, 0.188, 0.126, 0.118, 16, 2.9),      # a stripe across the chest
        ring(HIP + 0.415, 0.194, 0.122, 0.118, 16, 3.0),
        ring(SH.z + 0.005, 0.2, 0.09, 0.1, 16, 2.7),           # the shoulders, sloping
        ring(NECK - 0.03, 0.095, 0.072, 0.075, 16, 2.6),       # the trapezius sloping up to the neck
        ring(NECK + 0.02, 0.072, 0.074, 0.072, 16, 2.2),       # a roll-neck collar
        ring(NECK + 0.05, 0.068, 0.07, 0.068, 16, 2.2),
    ]
    L = Loft(rings)
    # pecs and shoulder blades: planes, not bulges
    L.push(4, [1, 2, 14, 15], (0, 0.008, 0)).push(5, [2, 3, 13, 14], (0, 0.006, 0))
    L.push(6, [6, 7, 9, 10], (0, -0.006, 0))
    L.push(7, [3, 4, 5, 11, 12, 13], (0, 0, -0.012))                            # the shoulders slope off

    def which(c):
        if c.z < HIP + 0.18:
            return S["oilskin"]                                                 # the trousers' top
        if c.y > 0 and abs(c.x) < 0.125 and c.z < HIP + 0.36:
            return S["oilskin"]                                                 # the bib
        if c.y < 0 and abs(c.x) < 0.11 and c.z < HIP + 0.3:
            return S["oilskin"]                                                 # its back
        if c.z > NECK - 0.02:
            return S["jumper_dark"]                                             # the collar
        if HIP + 0.385 < c.z < HIP + 0.415:
            return S["stripe"]
        return S["jumper"]
    L.build(bm, which)
    # the braces, over the shoulders, and their buckles
    for sx in (1, -1):
        strip(bm, [(sx * 0.085, 0.132, HIP + 0.34), (sx * 0.095, 0.128, HIP + 0.42), (sx * 0.11, 0.08, SH.z + 0.02),
                   (sx * 0.115, 0.0, SH.z + 0.035), (sx * 0.11, -0.08, SH.z + 0.02), (sx * 0.09, -0.124, HIP + 0.38),
                   (sx * 0.08, -0.122, HIP + 0.3)], 0.017, 0.006, S["strap"])
        block(bm, (sx * 0.085 - 0.02, 0.128, HIP + 0.325), (sx * 0.085 + 0.02, 0.146, HIP + 0.36), S["metal"])
    # a bib pocket, a flat panel with a darker flap, and the bib's stitched top hem
    block(bm, (-0.065, 0.142, HIP + 0.22), (0.065, 0.15, HIP + 0.3), S["oilskin"])
    block(bm, (-0.068, 0.146, HIP + 0.285), (0.068, 0.156, HIP + 0.31), S["oilskin_patch"])
    strip(bm, [(-0.125, 0.128, HIP + 0.35), (0.0, 0.133, HIP + 0.355), (0.125, 0.128, HIP + 0.35)], 0.008, 0.005,
          S["oilskin_patch"])
    # a belt round the waist, its buckle, a knife in a sheath on the hip, a rag hanging from the back
    belt = [ring(HIP + 0.0, 0.178, 0.14, 0.135, 16, 2.4), ring(HIP + 0.045, 0.178, 0.142, 0.136, 16, 2.4)]
    Loft(belt).build(bm, default=S["belt"], cap_bottom=False, cap_top=False)
    block(bm, (-0.025, 0.14, HIP + 0.005), (0.025, 0.152, HIP + 0.04), S["metal"])
    block(bm, (0.165, 0.0, HIP - 0.13), (0.195, 0.045, HIP + 0.03), S["belt"], 0.8)
    block(bm, (0.17, 0.008, HIP + 0.03), (0.19, 0.035, HIP + 0.1), S["sole"], 0.85)
    strip(bm, [(-0.09, -0.142, HIP + 0.03), (-0.095, -0.15, HIP - 0.05), (-0.1, -0.148, HIP - 0.14),
               (-0.108, -0.142, HIP - 0.19)], 0.035, 0.004, S["rag"])


def head(bm):
    """A real head in planes: neck, the jaw squared off, the chin, a wedge of a nose with its underside, a brow
    ledge over sunken eyes, cheekbones, ears; a beanie with its rolled brim; stubble and eyebrows."""
    z = NECK
    n = 16
    rows = [  # (z above the neck, half width, front, back, squareness)
        (-0.02, 0.058, 0.062, 0.06, 2.0),      # 0 the neck, into the collar
        (0.06, 0.06, 0.065, 0.058, 2.0),       # 1
        (0.1, 0.055, 0.075, 0.05, 2.2),        # 2 under the chin
        (0.125, 0.07, 0.098, 0.07, 2.8),       # 3 the jaw line
        (0.155, 0.077, 0.105, 0.085, 2.6),     # 4 the mouth
        (0.178, 0.08, 0.103, 0.095, 2.4),      # 5 under the nose
        (0.2, 0.082, 0.1, 0.1, 2.3),           # 6 the nose's base, cheekbones
        (0.228, 0.084, 0.097, 0.104, 2.3),     # 7 the eyes
        (0.255, 0.084, 0.1, 0.105, 2.3),       # 8 the brow
        (0.285, 0.082, 0.092, 0.104, 2.2),     # 9 the forehead
        (0.315, 0.074, 0.078, 0.095, 2.1),     # 10
        (0.342, 0.055, 0.055, 0.072, 2.0),     # 11
        (0.358, 0.03, 0.03, 0.04, 2.0),        # 12 the crown
    ]
    L = Loft([ring(z + r[0], r[1], r[2], r[3], n, r[4]) for r in rows])
    # the chin: a squared jut, and a cleft of a plane under the lip
    L.push(3, [0], (0, 0.012, -0.004)).push(3, [1, 15], (0, 0.006, 0))
    L.push(2, [0, 1, 15], (0, 0.008, 0))
    L.push(4, [0], (0, -0.004, 0))                                             # the mouth set back under the nose
    # the nose: a wedge. Its tip and underside (row 5), its bridge up to the brow
    L.push(5, [0], (0, 0.03, 0.006)).push(5, [1, 15], (0, 0.012, 0.002))
    L.push(6, [0], (0, 0.034, 0)).push(6, [1, 15], (0, 0.008, 0))
    L.push(7, [0], (0, 0.016, 0))
    # sunken eyes under a brow ledge; the cheekbones out
    L.push(7, [2, 14], (0, -0.012, 0)).push(7, [3, 13], (0, -0.008, 0))
    L.push(8, [0, 1, 15], (0, 0.004, 0)).push(8, [2, 14], (0, 0.008, 0))
    L.scale(6, [3, 13], 1.06, 1.0).push(6, [2, 14], (0, 0.004, 0))
    L.scale(4, [3, 4, 12, 13], 1.04, 1.0)                                       # the jaw's corners

    def which(c):
        rel = c.z - z
        if rel < 0.03:
            return S["skin"]
        if 0.215 < rel < 0.245 and c.y > 0.06 and 0.015 < abs(c.x) < 0.065:
            return S["socket"]                                                 # the shadowed eye sockets
        if abs(c.x) < 0.02 and 0.17 < rel < 0.23 and c.y > 0.09:
            return S["skin_warm"]                                              # the nose, ruddy
        return S["skin"]
    L.build(bm, which)
    # ears: flat wedges
    for sx in (1, -1):
        x = sx * 0.084
        r0 = [V((x, -0.005, z + 0.19)), V((x + sx * 0.018, -0.012, z + 0.2)), V((x + sx * 0.012, -0.03, z + 0.2)),
              V((x, -0.025, z + 0.19))]
        r1 = [V((x, 0.0, z + 0.25)), V((x + sx * 0.022, -0.01, z + 0.26)), V((x + sx * 0.016, -0.035, z + 0.255)),
              V((x, -0.03, z + 0.25))]
        Loft([r0, r1]).build(bm, default=S["skin_warm"])
        # the eye, set in under the brow, and the eyebrow over it
        ex = sx * 0.036
        block(bm, (ex - 0.014, 0.082, z + 0.222), (ex + 0.014, 0.089, z + 0.238), S["eye_white"], 0.75)
        block(bm, (ex - 0.006 + sx * 0.002, 0.088, z + 0.225), (ex + 0.006 + sx * 0.002, 0.092, z + 0.236), S["eye"],
              0.7)
        # the brows: the left one scowling down at the middle, the right one cocked up
        up = 0.008 if sx > 0 else 0.0
        iz = z + 0.25 + up * 0.5 - (0.004 if sx < 0 else 0.0)
        oz = z + 0.256 + up
        ix, ox = ex - sx * 0.022, ex + sx * 0.024
        br0 = [V((ix, 0.1, iz)), V((ix, 0.1, iz + 0.01)), V((ix, 0.092, iz + 0.01)), V((ix, 0.092, iz))]
        br1 = [V((ox, 0.094, oz)), V((ox, 0.094, oz + 0.008)), V((ox, 0.086, oz + 0.008)), V((ox, 0.086, oz))]
        Loft([br0, br1]).build(bm, default=S["hair"])
        # sideburns under the beanie
        block(bm, (sx * 0.083 - 0.006, -0.01, z + 0.2), (sx * 0.083 + 0.006, 0.035, z + 0.275), S["hair"])
    # a short beard, faceted: a shell over the jaw and chin, open at the mouth, and a moustache over it
    br = []
    for k, r in enumerate(rows[1:6]):
        rr = ring(z + r[0], r[1] + 0.008, r[2] + 0.012, r[3], n, r[4])
        br.append(rr)
    B = Loft(br)
    B.push(1, [0], (0, 0.016, -0.004)).push(1, [1, 15], (0, 0.01, 0))
    B.push(2, [0, 1, 15], (0, 0.012, -0.006)).push(2, [2, 14], (0, 0.006, 0))
    beard_faces = B.build(bm, default=S["hair"], cap_bottom=False, cap_top=False)
    for f in beard_faces:                       # only the front half: the jaw, chin and cheeks, not round the neck
        c = f.calc_center_median()
        if c.y < 0.01 or c.z - z < 0.112 or (c.z - z > 0.155 and abs(c.x) < 0.03):
            bm.faces.remove(f)
    for sx in (1, -1):
        r0 = [V((sx * 0.004, 0.106, z + 0.172)), V((sx * 0.004, 0.096, z + 0.18)), V((sx * 0.004, 0.09, z + 0.172)),
              V((sx * 0.004, 0.1, z + 0.162))]
        r1 = [V((sx * 0.045, 0.084, z + 0.155)), V((sx * 0.045, 0.078, z + 0.165)), V((sx * 0.045, 0.07, z + 0.158)),
              V((sx * 0.045, 0.078, z + 0.145))]
        Loft([r0, r1]).build(bm, default=S["hair"])
    # the mouth: a dark line between the moustache and the beard
    m0 = [V((-0.022, 0.1, z + 0.152)), V((-0.022, 0.1, z + 0.157)), V((-0.022, 0.095, z + 0.157)),
          V((-0.022, 0.095, z + 0.152))]
    m1 = [V((0.0, 0.104, z + 0.153)), V((0.0, 0.104, z + 0.158)), V((0.0, 0.098, z + 0.158)),
          V((0.0, 0.098, z + 0.153))]
    m2 = [V((0.024, 0.098, z + 0.16)), V((0.024, 0.098, z + 0.165)), V((0.024, 0.093, z + 0.165)),
          V((0.024, 0.093, z + 0.16))]
    Loft([m0, m1, m2]).build(bm, default=S["eye"])                      # the mouth: a smirk up on one side
    # the beanie: a shell over the skull, and its rolled brim
    b = [ring(z + r[0] + 0.004, r[1] + 0.008, r[2] + 0.006, r[3] + 0.008, n, r[4]) for r in rows[9:]]
    b[-1] = ring(z + 0.368, 0.05, 0.05, 0.06, n, 2.2)
    b.append(ring(z + 0.375, 0.02, 0.02, 0.025, n))
    Loft(b).build(bm, default=S["beanie"], cap_bottom=False)
    brim = [ring(z + 0.272, 0.094, 0.104, 0.114, n, 2.2), ring(z + 0.31, 0.093, 0.1, 0.112, n, 2.2)]
    Loft(brim).build(bm, default=S["beanie"])
    block(bm, (0.03, 0.098, z + 0.278), (0.058, 0.106, z + 0.3), S["tag"])               # the beanie's tag


def arm(bm, side):
    """The upper arm: a jumper sleeve with the deltoid's plane."""
    x = side * SH.x
    rows = [(SH.z + 0.035, 0.04, 0.045), (SH.z, 0.058, 0.058), (SH.z - 0.08, 0.052, 0.054),
            (SH.z - 0.18, 0.046, 0.048), (ELBOW + 0.01, 0.042, 0.044)]
    L = Loft([ring(r[0], r[1], r[2], None, 10, 2.3, x0=x) for r in rows])
    L.build(bm, default=S["jumper"])


def fore(bm, side):
    """The forearm, the glove's cuff, and the glove: a flat hand, the fingers together, a thumb."""
    x = side * SH.x
    rows = [(ELBOW + 0.02, 0.042, 0.044), (ELBOW - 0.03, 0.05, 0.052), (ELBOW - 0.07, 0.05, 0.052),
            (ELBOW - 0.08, 0.036, 0.038)]
    Loft([ring(r[0], r[1], r[2], None, 10, 2.3, x0=x) for r in rows]).build(bm, default=S["jumper_dark"])
    rows = [(ELBOW - 0.06, 0.04, 0.042), (ELBOW - 0.12, 0.041, 0.043), (WRIST + 0.06, 0.032, 0.034),
            (WRIST + 0.035, 0.03, 0.032)]
    Loft([ring(r[0], r[1], r[2], None, 10, 2.3, x0=x) for r in rows]).build(bm, default=S["skin"])
    cuff = [ring(WRIST + 0.045, 0.043, 0.045, None, 10, 2.4, x0=x), ring(WRIST - 0.005, 0.04, 0.042, None, 10, 2.4, x0=x)]
    Loft(cuff).build(bm, default=S["glove"])
    # the hand hangs with its palm to the thigh: thin across (x), broad front to back (y)
    hand = [ring(WRIST, 0.028, 0.036, 0.034, 10, 2.6, x0=x), ring(WRIST - 0.06, 0.027, 0.062, 0.05, 10, 3.0, x0=x),
            ring(WRIST - 0.12, 0.024, 0.06, 0.05, 10, 3.0, x0=x), ring(WRIST - 0.18, 0.019, 0.05, 0.04, 10, 2.6, x0=x),
            ring(WRIST - 0.21, 0.012, 0.032, 0.025, 10, 2.2, x0=x)]
    L = Loft(hand)
    L.push(3, [0, 1, 9], (0, 0.0, 0.01)).push(4, [0], (0, -0.006, 0.008))      # the fingertips curling in
    L.build(bm, default=S["glove"])
    t0 = V((x - side * 0.012, 0.035, WRIST - 0.04))
    thumb = [[t0 + V(p) for p in ((0.012, 0, 0.012), (-0.012, 0, 0.012), (-0.012, 0, -0.012), (0.012, 0, -0.012))],
             [t0 + V(p) for p in ((0.01, 0.03, -0.02), (-0.01, 0.03, -0.02), (-0.01, 0.024, -0.04),
                                  (0.01, 0.024, -0.04))],
             [t0 + V(p) for p in ((0.006, 0.042, -0.05), (-0.006, 0.042, -0.05), (-0.006, 0.036, -0.06),
                                  (0.006, 0.036, -0.06))]]
    Loft(thumb).build(bm, default=S["glove"])


def leg(bm, side):
    """The thigh, in baggy oilskin trousers."""
    x = side * LEG_X
    rows = [(HIP + 0.05, 0.09, 0.1), (HIP - 0.08, 0.088, 0.095), (HIP - 0.25, 0.078, 0.082),
            (KNEE + 0.1, 0.07, 0.074), (KNEE + 0.02, 0.068, 0.072), (KNEE - 0.01, 0.066, 0.07)]
    L = Loft([ring(r[0], r[1], r[2], None, 12, 2.3, x0=x) for r in rows])
    L.push(2, [2, 3], (0, -0.01, 0)).push(3, [9, 10], (0, -0.006, 0.0))           # creases in the cloth
    L.build(bm, lambda c: S["oilskin_patch"] if c.z < KNEE + 0.1 and c.y > 0.03 else S["oilskin"])


def shin(bm, side):
    """The shin in oilskin, tucked into a rubber boot with its top folded down, a toe, a heel and a sole."""
    x = side * LEG_X
    # the trousers down over the boot: a knee patch, two reflective bands, a hem flaring over the boot
    rows = [(KNEE + 0.02, 0.066, 0.07, 0.07), (KNEE - 0.08, 0.064, 0.066, 0.076), (0.38, 0.062, 0.064, 0.07),
            (0.36, 0.062, 0.065, 0.07), (0.33, 0.063, 0.066, 0.07), (0.31, 0.064, 0.067, 0.071),
            (0.24, 0.07, 0.074, 0.074), (0.225, 0.066, 0.07, 0.07)]
    L = Loft([ring(r[0], r[1], r[2], r[3], 12, 2.3, x0=x) for r in rows])
    L.push(1, [3, 9], (0, 0.0, -0.01))

    def which(c):
        if 0.36 < c.z < 0.38 or 0.31 < c.z < 0.33:
            return S["reflect"]
        if c.z > KNEE - 0.08 and c.y > 0.03:
            return S["oilskin_patch"]
        return S["oilskin"]
    L.build(bm, which, cap_top=False)
    boot = [ring(0.26, 0.054, 0.058, 0.058, 12, 2.4, x0=x), ring(0.2, 0.05, 0.055, 0.055, 12, 2.4, x0=x),
            ring(0.11, 0.054, 0.085, 0.062, 12, 2.6, x0=x), ring(0.06, 0.06, 0.15, 0.068, 12, 2.8, x0=x),
            ring(0.03, 0.062, 0.18, 0.07, 12, 3.0, x0=x)]
    L = Loft(boot)
    L.push(3, [0], (0, 0.01, -0.01)).push(4, [0, 1, 11], (0, 0.004, 0))        # the toe's slope
    L.build(bm, default=S["boot"], cap_bottom=False)
    sole = [ring(0.0, 0.065, 0.188, 0.074, 12, 3.0, x0=x), ring(0.031, 0.065, 0.186, 0.074, 12, 3.0, x0=x)]
    Loft(sole).build(bm, default=S["sole"])


# ------------------------------------------------------------------------------------------------ out

SUBD = 2


def paint_forms(me):
    """The light painted into the forms (vertex colours): darker and cooler in the hollows, lighter on the edges
    that stick out, a touch darker low down and underneath."""
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    col = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    shadow = Vector((0.7, 0.62, 0.86))
    for v in bm.verts:
        if not v.link_edges:
            col.data[v.index].color = (1, 1, 1, 1)
            continue
        nb = [e.other_vert(v).co for e in v.link_edges]
        avg = sum(nb, Vector()) / len(nb)
        span = sum((q - v.co).length for q in nb) / len(nb) + 1e-6
        conc = (avg - v.co).dot(v.normal) / span          # + in a hollow, - on a ridge
        hollow = min(max(conc * 4.0, 0.0), 1.0)
        ridge = min(max(-conc * 4.0, 0.0), 1.0)
        g = 0.84 + 0.16 * min(max(v.co.z / 1.8, 0.0), 1.0)
        under = 1.0 - 0.18 * min(max(-v.normal.z, 0.0), 1.0)
        k = g * under * (1.0 + 0.12 * ridge)
        c = Vector((k, k, k)).lerp(Vector((k * shadow.x, k * shadow.y, k * shadow.z)), hollow * 0.8)
        col.data[v.index].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
    bm.free()


def paint_faces(me):
    """Painted variation: each face a touch lighter or darker, warmer or cooler, darker low down and underneath
    (vertex colours, multiplied into the flat colours)."""
    import random
    col = me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
    for p in me.polygons:
        rnd = random.Random(p.index * 7919 + len(me.polygons))
        v = 1.0 + rnd.uniform(-0.05, 0.05)
        warm = rnd.uniform(-0.02, 0.02)
        g = 0.86 + 0.14 * min(max(p.center.z / 1.8, 0.0), 1.0)
        under = 0.8 if p.normal.z < -0.45 else 1.0
        k = v * g * under
        c = (min(k * (1 + warm), 1.0), min(k, 1.0), min(k * (1 - warm), 1.0), 1.0)
        for li in p.loop_indices:
            col.data[li].color = c


def make(name, fn, origin, mats, *args):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    fn(bm, *args)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # the planes that meet sharply keep a crisp (creased) edge once it's smoothed; gentle ones melt together
    cl = bm.edges.layers.float.get('crease_edge') or bm.edges.layers.float.new('crease_edge')
    for e in bm.edges:
        if len(e.link_faces) != 2:
            e[cl] = 1.0
            continue
        a = e.calc_face_angle(0.0)
        e[cl] = min(max((a - 0.5) / 0.7, 0.0), 1.0) * 0.9
    bm.to_mesh(me)
    bm.free()
    ob_tmp = bpy.data.objects.new("tmp", me)
    bpy.context.scene.collection.objects.link(ob_tmp)
    m = ob_tmp.modifiers.new("subd", 'SUBSURF')
    m.levels = SUBD
    m.render_levels = SUBD
    m.boundary_smooth = 'PRESERVE_CORNERS'
    bpy.context.view_layer.objects.active = ob_tmp
    bpy.ops.object.select_all(action='DESELECT')
    ob_tmp.select_set(True)
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(ob_tmp, do_unlink=True)
    paint_forms(me)
    for s in SLOTS:
        me.materials.append(mats[s])
    for p in me.polygons:
        p.use_smooth = SUBD > 0
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.transform(Matrix.Translation(-V(origin)))
    ob.location = V(origin)
    return ob


def main():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials):
        for x in list(coll):
            coll.remove(x)
    mats = materials()
    objs = [make("torso", torso, (0, 0, HIP), mats), make("head", head, (0, 0, NECK), mats)]
    for side, sfx in ((-1, "l"), (1, "r")):
        objs.append(make("arm_" + sfx, arm, (side * SH.x, 0, SH.z), mats, side))
        objs.append(make("fore_" + sfx, fore, (side * SH.x, 0, ELBOW), mats, side))
        objs.append(make("leg_" + sfx, leg, (side * LEG_X, 0, HIP), mats, side))
        objs.append(make("shin_" + sfx, shin, (side * LEG_X, 0, KNEE), mats, side))
    print("faces:", sum(len(o.data.polygons) for o in objs))
    if PREVIEW:
        preview(objs)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_normals=True, export_materials='EXPORT', export_vertex_color='ACTIVE',
                              export_cameras=False, export_lights=False, export_animations=False)
    print("wrote", os.path.abspath(OUT))


def preview(objs):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x, sc.render.resolution_y = 1200, 1200
    sc.view_settings.view_transform = 'Standard'
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.55, 0.62, 0.72, 1)
    bg.inputs['Strength'].default_value = 0.7
    om = bpy.data.materials["oilskin"]
    tint = om.node_tree.nodes[om["rgb"]].outputs[0]
    old = tuple(tint.default_value)
    tint.default_value = (0.95, 0.7, 0.08, 1)
    for nm, e, c, r in (("key", 3.5, (1, 0.93, 0.82), (50, 0, -35)), ("fill", 1.0, (0.7, 0.75, 1), (60, 0, 150))):
        L = bpy.data.objects.new(nm, bpy.data.lights.new(nm, 'SUN'))
        L.data.energy, L.data.color = e, c
        L.rotation_euler = [math.radians(a) for a in r]
        sc.collection.objects.link(L)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    os.makedirs(PREVIEW, exist_ok=True)
    for name, loc, tgt, lens in (("body", (1.4, 3.2, 1.2), (0, 0, 0.92), 50), ("face", (0.35, 0.75, 1.75), (0, 0, 1.73), 70),
                                 ("face_side", (0.8, 0.3, 1.75), (0, 0.02, 1.73), 70)):
        cam.location = loc
        cam.rotation_euler = (V(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam.data.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "facets_%s.png" % name)
        bpy.ops.render.render(write_still=True)
    tint.default_value = old


main()
