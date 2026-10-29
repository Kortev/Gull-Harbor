"""The small boat: a weathered 28 ft (8.5 m) center console for one or two.

An open fishing skiff: a deep-V glass hull, low sides you can gaff a fish over, a console amidships under a T-top with
the wheel, the sonar and the radar on its aft face (a step from the rods), a leaning post behind it, a raised casting
deck at the bow, twin outboards hung on the transom, four rod holders in the gunwales (the two aft corners fish), a
fish box in the deck forward of the console and a live well in the transom.

Run: cd art && python3 skiff.py  (bpy from pip). Writes ../boat/skiff.glb.

Objects for Godot (boat/boat.gd), as the 46 footer's (art/boat.py):
  "boat"      everything fixed
  "wheel"     the helm wheel (spins about its hub)
  "radar"     the radar's spinning bar
  "collider"  plain walk/bump geometry: Godot makes it a trimesh and hides it
  empties: "spawn_0".."spawn_3", "holder_0".."holder_3" rod holder tubes (+Z out of the tube; 0 and 1 the aft
  corners), "helm" where the skipper stands, "flood_0"/"flood_1" the T-top's spreader lights, "deck_light_0"/
  "deck_light_1" the T-top's cockpit lights (both: -Z is where the light points).

Blender: Z up, bow toward +Y (Godot -Z), starboard toward +X. Origin = the waterline amidships."""
import math
import os
import sys

import bpy  # noqa: F401,E402  (bmesh only exists once bpy is loaded)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import psx  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "boat", "skiff.glb")

L = 8.5                 # 28 ft
Y0 = -L / 2             # transom
DECK = 0.45             # the self-bailing deck above the waterline
CAST = 0.62             # the raised casting deck at the bow
CAST_Y = 2.6            # where it starts
LINER = 0.08            # gunwale thickness (covering board width)
CON_Y0, CON_Y1 = -0.25, 0.85        # the console, aft face to front
CON_W = 0.55                        # its half width
CON_H = DECK + 1.15                 # its top
TOP = DECK + 2.15                   # the T-top's underside
TOP_Y0, TOP_Y1 = -1.05, 1.15        # the T-top fore and aft


def ss(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def u_of(y):
    return (y - Y0) / L


def s_half(u):
    """Half-beam at the sheer: 2.9 m (9.5 ft) at the widest."""
    if u < 0.35:
        return 1.36 + 0.09 * ss(0.0, 0.35, u)
    if u < 0.55:
        return 1.45
    t = (u - 0.55) / 0.45
    return 0.05 + 1.40 * max(0.0, 1.0 - t ** 2.0) ** 0.55


def wl_half(u):
    """Half-beam at the waterline."""
    if u < 0.5:
        return 1.15 + 0.08 * ss(0.0, 0.4, u)
    t = (u - 0.5) / 0.47
    return 0.03 + 1.2 * max(0.0, 1.0 - t ** 1.8) ** 0.8 if t < 1.0 else 0.03


def z_sheer(u):
    return 1.15 + 0.5 * ss(0.45, 1.0, u) ** 1.3


def z_keel(u):
    return -0.42 - 0.08 * ss(0.0, 0.25, u) + 0.75 * ss(0.7, 1.0, u)


def deck_z(y):
    return CAST if y >= CAST_Y else DECK


def section(y):
    """One side's section (x >= 0) from the keel, up the outside, over the gunwale, down the liner to the deck; and
    the band material between consecutive points (as art/boat.py's)."""
    u = u_of(y)
    s, w = s_half(u), min(wl_half(u), s_half(u) - 0.02)
    zk, zs = z_keel(u), z_sheer(u)
    inner = max(s - LINER, 0.0)
    pts = [
        (0.03, zk),
        (0.5 * w, zk * 0.45),
        (0.88 * w, zk * 0.1),
        (w, 0.0),
        (w + (s - w) * 0.15, 0.2),
        (s + 0.04, zs - 0.18),
        (s + 0.04, zs - 0.1),
        (s, zs),
        (inner, zs),
        (inner, min(deck_z(y), zs)),
    ]
    mats = ["bottom", "bottom", "bottom", "boot", "topsides", "rubrail", "topsides", "cap", "liner"]
    return pts, mats


TILES = {
    "bottom": (2.0, 2.0), "boot": (2.0, 0.5), "topsides": (2.0, 2.0), "rubrail": (1.0, 1.0),
    "cap": (1.0, 1.0), "liner": (2.0, 2.0), "deck": (2.0, 2.0), "house": (2.0, 2.0), "inside": (2.0, 2.0),
    "dash": (1.0, 1.0), "glass": (1.0, 1.0), "steel": (1.0, 1.0), "rubber": (1.0, 1.0), "hatch": (1.0, 1.0),
    "lamp": (0.5, 0.5), "sonar": (1.0, 1.0), "radar_scope": (1.0, 1.0), "gauge": (1.0, 1.0),
    "rope": (0.5, 0.5), "buoy": (1.0, 1.0), "wood": (1.0, 1.0), "canvas": (1.0, 1.0), "motor": (1.0, 1.0),
    "collider": (4.0, 4.0),
}


def materials():
    m = psx.make_material
    m("bottom", "hull_bottom")
    m("boot", "hull_green")
    m("topsides", "house_white")
    m("rubrail", "rubber")
    m("cap", "boot_white")
    m("liner", "boot_white")
    m("deck", "m_canvas")
    m("house", "house_white")
    m("inside", "boot_white")
    m("dash", "m_dash")
    m("glass", "glass_dirty", alpha=0.35)
    m("steel", "m_steel")
    m("rubber", "rubber")
    m("hatch", "floor_plate")
    m("lamp", "lamp_warm", emit=1.6)
    m("sonar", "sonar", emit=1.2)
    m("radar_scope", "radar_scope", emit=1.2)
    m("gauge", "gauge", emit=0.4)
    m("rope", "m_yellow")
    m("buoy", color=(0.85, 0.32, 0.08))
    m("wood", "wood")
    m("canvas", color=(0.16, 0.24, 0.32))            # the T-top's navy canvas
    m("motor", "m_gunmetal")
    m("red_light", color=(1.0, 0.1, 0.05), emit=3.0)
    m("green_light", color=(0.1, 1.0, 0.2), emit=3.0)
    m("collider", color=(1.0, 0.0, 1.0))


def newell(pts):
    n = Vector((0.0, 0.0, 0.0))
    for i in range(len(pts)):
        a, b = Vector(pts[i]), Vector(pts[(i + 1) % len(pts)])
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


def face(mesh, pts, mat, want):
    """A face wound so its normal points along `want` (skips slivers)."""
    n = newell(pts)
    if n.length < 1e-6:
        return
    if n.dot(Vector(want)) < 0.0:
        pts = list(reversed(pts))
    mesh.face(pts, mat)


def cyl(mesh, p0, p1, r, mat, seg=6, r1=None):
    mesh.cylinder(p0, p1, r, mat, seg=seg, r1=r1)


# ------------------------------------------------------------------------------------------ the hull

def hull(m, col):
    ys = [Y0, Y0 + 0.3] + [Y0 + f * L for f in (0.12, 0.22, 0.32, 0.42, 0.52, 0.6)] \
        + [CAST_Y - 0.001, CAST_Y] + [Y0 + f * L for f in (0.8, 0.85, 0.89, 0.925, 0.952, 0.972, 0.987, 0.996, 1.0)]
    ys = sorted(set(round(y, 4) for y in ys))
    rows = [(y, *section(y)) for y in ys]
    for (ya, pa, bands), (yb, pb, _) in zip(rows, rows[1:]):
        for side in (1, -1):
            for k, band in enumerate(bands):
                q = [(side * pa[k][0], ya, pa[k][1]), (side * pa[k + 1][0], ya, pa[k + 1][1]),
                     (side * pb[k + 1][0], yb, pb[k + 1][1]), (side * pb[k][0], yb, pb[k][1])]
                mid = sum((Vector(p) for p in q), Vector()) / 4
                if band == "cap":
                    want = (0, 0, 1)
                elif band == "liner":
                    want = (-side, 0, 0)
                else:
                    want = (side, 0, -0.6 if mid.z < 0 else 0.0)
                face(m, q, band, want)
                if band == "liner":
                    # the collider's gunwale: raised so no one walks off her (it's low: about knee high)
                    face(col, [(side * pa[k][0], ya, pa[k][1] + 0.6), (side * pa[k + 1][0], ya, pa[k + 1][1]),
                               (side * pb[k + 1][0], yb, pb[k + 1][1]), (side * pb[k][0], yb, pb[k][1] + 0.6)],
                         "collider", (-side, 0, 0))
        q = [(-pa[-1][0], ya, pa[-1][1]), (pa[-1][0], ya, pa[-1][1]), (pb[-1][0], yb, pb[-1][1]),
             (-pb[-1][0], yb, pb[-1][1])]
        if abs(pa[-1][1] - pb[-1][1]) < 1e-3:
            face(m, q, "deck", (0, 0, 1))
            face(col, q, "collider", (0, 0, 1))
    # the transom outside
    y, p, bands = rows[0]
    for k, band in enumerate(bands[:7]):
        face(m, [(-p[k][0], y, p[k][1]), (p[k][0], y, p[k][1]), (p[k + 1][0], y, p[k + 1][1]),
                 (-p[k + 1][0], y, p[k + 1][1])], band, (0, -1, 0))
    # the transom inside and its cap
    yi = Y0 + LINER
    inner = p[8][0]
    zs = p[7][1]
    face(m, [(-inner, yi, DECK), (inner, yi, DECK), (inner, yi, zs), (-inner, yi, zs)], "liner", (0, 1, 0))
    face(m, [(-inner, Y0, zs), (inner, Y0, zs), (inner, yi, zs), (-inner, yi, zs)], "cap", (0, 0, 1))
    face(col, [(-inner, yi, DECK), (inner, yi, DECK), (inner, yi, zs + 0.6), (-inner, yi, zs + 0.6)],
         "collider", (0, 1, 0))
    # the stem
    y, p, bands = rows[-1]
    for k, band in enumerate(bands[:7]):
        face(m, [(-p[k][0], y, p[k][1]), (p[k][0], y, p[k][1]), (p[k + 1][0], y, p[k + 1][1]),
                 (-p[k + 1][0], y, p[k + 1][1])], band, (0, 1, 0))
    face(m, [(-p[7][0], y, p[7][1]), (p[7][0], y, p[7][1]), (p[8][0], y, p[8][1]), (-p[8][0], y, p[8][1])],
         "cap", (0, 0, 1))
    # the step up to the casting deck
    inner = s_half(u_of(CAST_Y)) - LINER
    face(m, [(-inner, CAST_Y, DECK), (inner, CAST_Y, DECK), (inner, CAST_Y, CAST), (-inner, CAST_Y, CAST)],
         "inside", (0, -1, 0))
    face(col, [(-inner, CAST_Y, DECK), (inner, CAST_Y, DECK), (inner, CAST_Y, CAST), (-inner, CAST_Y, CAST)],
         "collider", (0, -1, 0))


# ------------------------------------------------------------------------------------------ the console

def console(m, col):
    y0, y1, w = CON_Y0, CON_Y1, CON_W
    # the box, its front raked forward, a step at its base
    m.box((-w, y0, DECK), (w, y1 - 0.25, CON_H), "house", mats={"-y": "inside"})
    face(m, [(-w, y1 - 0.25, CON_H), (w, y1 - 0.25, CON_H), (w, y1, DECK + 0.4), (-w, y1, DECK + 0.4)], "house",
         (0, 1, 0.5))
    face(m, [(-w, y1 - 0.25, DECK), (w, y1 - 0.25, DECK), (w, y1, DECK), (w, y1, DECK + 0.4), (-w, y1, DECK + 0.4),
             (-w, y1, DECK)], "house", (0, 1, 0))
    for sx in (1, -1):
        face(m, [(sx * w, y1 - 0.25, DECK), (sx * w, y1, DECK), (sx * w, y1, DECK + 0.4), (sx * w, y1 - 0.25, CON_H)],
             "house", (sx, 0, 0))
    col.box((-w, y0, DECK), (w, y1, CON_H), "collider")
    # the windscreen on top, raked aft
    face(m, [(-w, y1 - 0.3, CON_H), (w, y1 - 0.3, CON_H), (w, y1 - 0.55, CON_H + 0.45), (-w, y1 - 0.55, CON_H + 0.45)],
         "glass", (0, 1, 0.5))
    # the dash: the aft face's top, sloped back toward the skipper, the sonar and the radar side by side
    dz0, dz1 = CON_H - 0.42, CON_H
    face(m, [(-w, y0, dz0), (w, y0, dz0), (w, y0 + 0.28, dz1), (-w, y0 + 0.28, dz1)], "dash", (0, -1, 1))
    for (x0, x1), mat in (((-0.48, -0.04), "sonar"), ((0.04, 0.48), "radar_scope")):
        lift = Vector((0, -0.7, 0.7)) * 0.004
        a = Vector((x0, y0 + 0.04, dz0 + 0.06)) + lift
        b = Vector((x1, y0 + 0.04, dz0 + 0.06)) + lift
        c = Vector((x1, y0 + 0.24, dz1 - 0.06)) + lift
        d = Vector((x0, y0 + 0.24, dz1 - 0.06)) + lift
        m.face([tuple(a), tuple(b), tuple(c), tuple(d)], mat, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for x in (-0.42, -0.2):
        m.face([(x, y0 - 0.002, DECK + 0.55), (x + 0.16, y0 - 0.002, DECK + 0.55), (x + 0.16, y0 - 0.002, DECK + 0.71),
                (x, y0 - 0.002, DECK + 0.71)], "gauge", uvs=[(1, 0), (0, 0), (0, 1), (1, 1)])
    # the throttles, starboard of the wheel
    m.box((0.32, y0 - 0.12, DECK + 0.78), (0.42, y0, DECK + 0.86), "steel")
    for x in (0.34, 0.39):
        cyl(m, (x, y0 - 0.06, DECK + 0.86), (x, y0 - 0.1, DECK + 1.02), 0.012, "steel", seg=4)
    # a cooler seat in front of it
    m.box((-0.45, y1 + 0.1, DECK), (0.45, y1 + 0.6, DECK + 0.48), "inside")
    m.box((-0.47, y1 + 0.08, DECK + 0.48), (0.47, y1 + 0.62, DECK + 0.54), "rubber")
    col.box((-0.47, y1 + 0.08, DECK), (0.47, y1 + 0.62, DECK + 0.54), "collider")
    # the leaning post behind the skipper, a rocket launcher of rod tubes on its back
    lp = -1.4
    m.box((-0.45, lp - 0.25, DECK), (0.45, lp + 0.15, DECK + 0.45), "inside")
    m.box((-0.47, lp - 0.27, DECK + 0.45), (0.47, lp + 0.17, DECK + 0.5), "hatch")
    for sx in (1, -1):
        cyl(m, (sx * 0.38, lp, DECK + 0.5), (sx * 0.38, lp, DECK + 1.0), 0.025, "steel")
    m.box((-0.45, lp - 0.05, DECK + 0.9), (0.45, lp + 0.08, DECK + 1.1), "rubber")
    for i in range(4):
        x = -0.3 + i * 0.2
        cyl(m, (x, lp - 0.22, DECK + 0.6), (x, lp - 0.3, DECK + 1.3), 0.03, "steel", seg=6)
    col.box((-0.47, lp - 0.3, DECK), (0.47, lp + 0.17, DECK + 1.1), "collider")
    # the T-top: four posts, a frame and a navy canvas, lights under its aft edge, the radar on top
    for sx in (1, -1):
        for y in (TOP_Y0 + 0.1, TOP_Y1 - 0.15):
            cyl(m, (sx * 0.6, y, DECK if y > 0 else DECK + 0.5), (sx * 0.75, y, TOP), 0.03, "steel")
        cyl(m, (sx * 0.75, TOP_Y0 + 0.1, TOP), (sx * 0.75, TOP_Y1 - 0.15, TOP), 0.03, "steel", seg=5)
        col.box((sx * 0.6 - 0.05, TOP_Y1 - 0.2, DECK), (sx * 0.6 + 0.05, TOP_Y1 - 0.1, TOP), "collider")
    m.box((-0.95, TOP_Y0, TOP), (0.95, TOP_Y1, TOP + 0.08), "canvas", mats={"-z": "inside"})
    # nav lights on the console's flanks
    for sx, mat in ((1, "green_light"), (-1, "red_light")):
        m.box((sx * CON_W - 0.02 * sx, 0.35, CON_H - 0.2), (sx * CON_W + 0.04 * sx, 0.5, CON_H - 0.12), mat)


def wheel_obj(coll):
    w = psx.Mesh("wheel", TILES)
    hub = Vector((-0.02, CON_Y0 - 0.1, DECK + 0.95))
    axis = Vector((0, 1, 0.55)).normalized()
    w.torus(hub, axis, 0.2, 0.02, "rubber", seg=12, rseg=4)
    up = axis.cross(Vector((1, 0, 0))).normalized()
    side = axis.cross(up).normalized()
    for d in (up, -up, side, -side):
        w.cylinder(tuple(hub), tuple(hub + d * 0.19), 0.011, "steel", seg=4)
    w.cylinder(tuple(hub - axis * 0.02), tuple(hub + axis * 0.12), 0.03, "steel", seg=6)
    return w.finish(coll, origin=tuple(hub))


# ------------------------------------------------------------------------------------------ the deck and the stern

def fittings(m, col):
    # the fish box forward of the console, flush in the deck
    m.box((-0.6, 1.55, DECK), (0.6, 2.35, DECK + 0.03), "hatch")
    m.box((-0.1, 2.2, DECK + 0.03), (0.1, 2.25, DECK + 0.05), "steel")
    # the live well in the transom, lid on top
    yi = Y0 + LINER
    m.box((-0.5, yi, DECK), (0.5, yi + 0.5, DECK + 0.55), "liner")
    m.box((-0.46, yi + 0.03, DECK + 0.55), (0.46, yi + 0.47, DECK + 0.58), "inside")
    col.box((-0.5, yi, DECK), (0.5, yi + 0.5, DECK + 0.58), "collider")
    # twin outboards hung on the transom: the cowl, the leg, the cavitation plate (props under the water)
    for sx in (0.55, -0.55):
        y = Y0 - 0.12
        m.box((sx - 0.24, y - 0.62, 0.55), (sx + 0.24, y - 0.02, 1.25), "motor")
        m.box((sx - 0.2, y - 0.58, 1.25), (sx + 0.2, y - 0.06, 1.38), "motor")
        m.box((sx - 0.09, y - 0.45, -0.45), (sx + 0.09, y - 0.2, 0.55), "motor")
        m.box((sx - 0.2, y - 0.5, -0.12), (sx + 0.2, y - 0.1, -0.08), "motor")
        cyl(m, (sx, y - 0.48, -0.36), (sx, y - 0.62, -0.36), 0.14, "steel", seg=6)
        m.box((sx - 0.12, y - 0.04, 0.6), (sx + 0.12, Y0 + 0.01, 0.95), "steel")      # the bracket
    # cleats on the gunwales, aft and at the bow
    for y in (Y0 + 0.4, 2.9):
        for sx in (1, -1):
            s, zs = s_half(u_of(y)), z_sheer(u_of(y))
            m.box((sx * (s - 0.05) - 0.02, y - 0.1, zs), (sx * (s - 0.05) + 0.02, y + 0.1, zs + 0.05), "steel")
    # a coil of line and a buoy tied to the leaning post
    for i in range(3):
        m.torus((-0.9, -2.9, DECK + 0.03 + i * 0.04), (0, 0, 1), 0.22 - i * 0.02, 0.022, "rope", seg=12, rseg=4)
    m.sphere((0.95, -1.9, DECK + 0.22), 0.22, "buoy", seg=8, rings=6)
    # the bow rail
    pts = []
    for y in (2.9, 3.4, 3.8, 4.1):
        u = u_of(y)
        pts.append((s_half(u) - 0.05, y, z_sheer(u)))
    for sx in (1, -1):
        prev = None
        for x, y, z in pts:
            p = (sx * x, y, z + 0.5)
            cyl(m, (sx * x, y, z), p, 0.018, "steel", seg=5)
            if prev:
                cyl(m, prev, p, 0.02, "steel", seg=5)
            prev = p
    cyl(m, (pts[-1][0], pts[-1][1], pts[-1][2] + 0.5), (-pts[-1][0], pts[-1][1], pts[-1][2] + 0.5), 0.02,
        "steel", seg=5)


def holders(m, coll):
    """Rod holders in the gunwales: the two aft corners first (they fish), then a pair amidships."""
    spots = [(1, Y0 + 0.35, Vector((0.45, -0.6, 1.0))), (-1, Y0 + 0.35, Vector((-0.45, -0.6, 1.0))),
             (1, -1.9, Vector((0.25, -0.35, 1.0))), (-1, -1.9, Vector((-0.25, -0.35, 1.0)))]
    out = []
    for i, (sx, y, d) in enumerate(spots):
        u = u_of(y)
        x = sx * (s_half(u) - LINER * 0.5)
        zs = z_sheer(u)
        d = d.normalized()
        rim = Vector((x, y, zs + 0.03))
        m.cylinder(tuple(rim - d * 0.3), tuple(rim), 0.035, "steel", seg=6)
        m.cylinder(tuple(rim - d * 0.01), tuple(rim), 0.05, "steel", seg=6)
        e = psx.empty("holder_%d" % i, coll, tuple(rim))
        e.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
        out.append(e)
    return out


def lights(m, coll):
    out = []
    # spreader lights on the T-top's aft corners, aimed down aft into the cockpit and over the stern
    for i, sx in enumerate((1, -1)):
        p = Vector((sx * 0.85, TOP_Y0 + 0.05, TOP - 0.03))
        m.box(tuple(p - Vector((0.1, 0.06, 0.06))), tuple(p + Vector((0.1, 0.06, 0.04))), "steel")
        m.face([tuple(p + Vector((-0.08, -0.062, -0.05))), tuple(p + Vector((0.08, -0.062, -0.05))),
                tuple(p + Vector((0.08, -0.062, 0.03))), tuple(p + Vector((-0.08, -0.062, 0.03)))], "lamp",
               uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        e = psx.empty("flood_%d" % i, coll, tuple(p + Vector((0, -0.1, -0.05))))
        aim = (Vector((sx * 0.5, Y0 - 1.0, 0.0)) - e.location).normalized()
        e.rotation_euler = (-aim).to_track_quat('Z', 'Y').to_euler()
        out.append(e)
    # two small lights under the canvas over the helm
    for i, sx in enumerate((1, -1)):
        p = Vector((sx * 0.4, TOP_Y0 + 0.4, TOP - 0.01))
        m.box(tuple(p - Vector((0.08, 0.05, 0.03))), tuple(p + Vector((0.08, 0.05, 0.0))), "steel")
        m.face([tuple(p + Vector((-0.07, 0.04, -0.032))), tuple(p + Vector((0.07, 0.04, -0.032))),
                tuple(p + Vector((0.07, -0.04, -0.032))), tuple(p + Vector((-0.07, -0.04, -0.032)))], "lamp",
               uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        e = psx.empty("deck_light_%d" % i, coll, tuple(p - Vector((0, 0, 0.05))))
        e.rotation_euler = (-0.25, 0.0, 0.0)
        out.append(e)
    # the radar: a small open array on the T-top
    cyl(m, (0, 0.3, TOP + 0.08), (0, 0.3, TOP + 0.3), 0.06, "steel")
    r = psx.Mesh("radar", TILES)
    rz = TOP + 0.3
    r.box((-0.4, 0.22, rz), (0.4, 0.38, rz + 0.1), "house")
    radar = r.finish(coll, origin=(0, 0.3, rz))
    return out, radar


def main():
    psx.clear_scene()
    materials()
    coll = psx.new_collection("boat")
    m = psx.Mesh("boat", TILES)
    col = psx.Mesh("collider", TILES)
    hull(m, col)
    console(m, col)
    fittings(m, col)
    hs = holders(m, coll)
    floods, radar = lights(m, coll)
    wheel = wheel_obj(coll)
    boat = m.finish(coll)
    collider = col.finish(coll)
    spawns = []
    for i, (x, y) in enumerate(((0.7, -2.3), (-0.7, -2.3), (0.8, -3.3), (-0.8, -3.3))):
        spawns.append(psx.empty("spawn_%d" % i, coll, (x, y, DECK), rot_z_deg=180.0))
    helm = psx.empty("helm", coll, (-0.02, CON_Y0 - 0.65, DECK), rot_z_deg=0.0)
    objs = [boat, wheel, radar, collider, helm] + hs + floods + spawns
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    psx.export_glb(os.path.abspath(OUT), objs)
    print("wrote", os.path.abspath(OUT), len(boat.data.polygons), "faces")


main()
