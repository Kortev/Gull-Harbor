"""The boat: a weathered 46 ft (14 m) tuna boat for a crew of four.

A plain working sportfisher, nothing fancy: a white glass hull gone grey and rust-streaked, a green boot stripe
and red bottom paint, teak covering boards, an open-backed wheelhouse forward under a hardtop that runs aft over
the front of the cockpit, and a big open cockpit aft with a fighting chair, rod holders in the gunwales, a fish
box and a live well in the transom. A tuna tower over the hardtop, outriggers, a radar dome, floodlights.

Run: cd art && python3 boat.py  (bpy from pip). Writes ../boat/boat.glb.

Objects for Godot (boat/boat.gd):
  "boat"      everything fixed
  "chair"     the fighting chair (swivels about its pedestal)
  "wheel"     the helm wheel (spins about its hub)
  "radar"     the radar's spinning bar
  "collider"  plain walk/bump geometry: Godot makes it a trimesh and hides it
  empties: "spawn_0".."spawn_3" crew spawn points, "holder_0".."holder_7" rod holder tubes (+Z out of the
  tube), "helm" where the skipper stands, "flood_0"/"flood_1" tower floodlights, "deck_light_0"/"deck_light_1"
  the cockpit lights under the hardtop (both: -Z is where the light points).

Blender: Z up, bow toward +Y (Godot -Z), starboard toward +X. Origin = the waterline amidships."""
import math
import os
import sys

import bpy  # noqa: F401,E402  (bmesh only exists once bpy is loaded)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import psx  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "boat", "boat.glb")

L = 14.0                # 46 ft
Y0 = -L / 2             # transom
DECK = 0.55             # cockpit sole above the waterline
FORE = 1.7              # foredeck over the cuddy
HOUSE_FRONT = 3.0       # the wheelhouse front / cuddy bulkhead (y)
HOUSE_BACK = -0.4       # where the wheelhouse side walls end (y)
HOUSE_W = 1.95          # wheelhouse half width
ROOF = DECK + 2.05      # hardtop underside
ROOF_AFT = -2.0         # hardtop's aft edge (y)
LINER = 0.1             # bulwark thickness (covering board width)


def ss(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def u_of(y):
    return (y - Y0) / L


BW = 2.4 / 2.15          # the beam: 4.8 m (16 ft) at the widest, a 46 ft sportfisher's


def s_half(u):
    """Half-beam at the sheer."""
    if u < 0.3:
        return BW * (1.98 + 0.17 * ss(0.0, 0.3, u))
    if u < 0.55:
        return BW * 2.15
    t = (u - 0.55) / 0.45
    return BW * (0.07 + 2.08 * max(0.0, 1.0 - t ** 2.2) ** 0.55)


def wl_half(u):
    """Half-beam at the waterline."""
    if u < 0.5:
        return BW * (1.85 + 0.1 * ss(0.0, 0.4, u))
    t = (u - 0.5) / 0.47
    return BW * (0.03 + 1.92 * max(0.0, 1.0 - t ** 1.8) ** 0.8 if t < 1.0 else 0.03)


def z_sheer(u):
    return 1.45 + 0.95 * ss(0.5, 1.0, u) ** 1.4


def z_keel(u):
    return -0.4 - 0.55 * ss(0.0, 0.25, u) + 0.85 * ss(0.72, 1.0, u)


def deck_z(y):
    return FORE if y >= HOUSE_FRONT else DECK


def section(y):
    """One side's section (x >= 0) from the keel, up the outside, over the covering board, down the liner to
    the deck; and the band material between consecutive points."""
    u = u_of(y)
    s, w = s_half(u), min(wl_half(u), s_half(u) - 0.02)
    zk, zs = z_keel(u), z_sheer(u)
    inner = max(s - LINER, 0.0)
    pts = [
        (0.04, zk),
        (0.5 * w, zk * 0.5),
        (0.9 * w, zk * 0.14),
        (w, 0.0),
        (w + (s - w) * 0.12, 0.22),
        (s + 0.06, zs - 0.3),
        (s + 0.06, zs - 0.18),
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
    "rope": (0.5, 0.5), "buoy": (1.0, 1.0), "wood": (1.0, 1.0), "collider": (4.0, 4.0),
}


def materials():
    """The stylized look: clean, rich painted colours (psx.painted), the screens and gauges still textures. Her hull
    dark navy (a proper sportfisher), a teal boot stripe, teak covering boards."""
    m = psx.make_material
    m("bottom", paint=(0.6, 0.13, 0.08), roughness=0.7)              # antifouling red
    m("boot", paint=(0.04, 0.4, 0.36), roughness=0.4)                # teal boot stripe
    m("topsides", paint=(0.08, 0.14, 0.26), roughness=0.3)           # navy topsides
    m("rubrail", paint=(0.85, 0.86, 0.88), roughness=0.3, metal=0.5) # a stainless rubrail
    m("cap", paint=(0.58, 0.35, 0.17), roughness=0.5)                # teak covering boards
    m("liner", paint=(0.93, 0.92, 0.87), roughness=0.45)
    m("deck", paint=(0.82, 0.8, 0.74), roughness=0.85)               # non-skid
    m("house", paint=(0.95, 0.94, 0.9), roughness=0.35)
    m("inside", paint=(0.86, 0.86, 0.83), roughness=0.55)
    m("dash", "m_dash")
    m("glass", "glass_dirty", alpha=0.35)
    m("steel", paint=(0.78, 0.8, 0.83), roughness=0.3, metal=0.6)
    m("rubber", paint=(0.1, 0.1, 0.11), roughness=0.7)
    m("hatch", paint=(0.88, 0.87, 0.82), roughness=0.6)
    m("lamp", "lamp_warm", emit=1.6)
    m("sonar", "sonar", emit=1.2)
    m("radar_scope", "radar_scope", emit=1.2)
    m("gauge", "gauge", emit=0.4)
    m("rope", paint=(0.92, 0.76, 0.28), roughness=0.9)
    m("buoy", paint=(0.95, 0.35, 0.08), roughness=0.5)
    m("wood", paint=(0.55, 0.32, 0.15), roughness=0.6)
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
    # stations along her: even in the cockpit, closer together toward the bow (as fractions of her length)
    ys = [Y0, Y0 + 0.4] + [Y0 + f * L for f in (0.1, 0.18, 0.26, 0.34, 0.42, 0.5, 0.58, 0.66)] \
        + [HOUSE_FRONT - 0.001, HOUSE_FRONT] + [Y0 + f * L for f in (0.788, 0.836, 0.876, 0.912, 0.94, 0.964,
                                                                      0.98, 0.992, 1.0)]
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
                    # the collider's bulwark: the liner raised half a metre so no one falls over the side
                    face(col, [(side * pa[k][0], ya, pa[k][1] + 0.5), (side * pa[k + 1][0], ya, pa[k + 1][1]),
                               (side * pb[k + 1][0], yb, pb[k + 1][1]), (side * pb[k][0], yb, pb[k][1] + 0.5)],
                         "collider", (-side, 0, 0))
        # the deck between the liners
        q = [(-pa[-1][0], ya, pa[-1][1]), (pa[-1][0], ya, pa[-1][1]), (pb[-1][0], yb, pb[-1][1]),
             (-pb[-1][0], yb, pb[-1][1])]
        if abs(pa[-1][1] - pb[-1][1]) < 1e-3:
            face(m, q, "deck", (0, 0, 1))
            face(col, q, "collider", (0, 0, 1))
    # the transom outside, as strips between port and starboard (each convex)
    y, p, bands = rows[0]
    for k, band in enumerate(bands[:7]):
        face(m, [(-p[k][0], y, p[k][1]), (p[k][0], y, p[k][1]), (p[k + 1][0], y, p[k + 1][1]),
                 (-p[k + 1][0], y, p[k + 1][1])], band, (0, -1, 0))
    # the transom inside: the liner across the stern, and its covering board
    yi = Y0 + LINER
    inner = p[8][0]
    zs = p[7][1]
    face(m, [(-inner, yi, DECK), (inner, yi, DECK), (inner, yi, zs), (-inner, yi, zs)], "liner", (0, 1, 0))
    face(m, [(-inner, Y0, zs), (inner, Y0, zs), (inner, yi, zs), (-inner, yi, zs)], "cap", (0, 0, 1))
    face(col, [(-inner, yi, DECK), (inner, yi, DECK), (inner, yi, zs + 0.5), (-inner, yi, zs + 0.5)],
         "collider", (0, 1, 0))
    # the stem
    y, p, bands = rows[-1]
    for k, band in enumerate(bands[:7]):
        face(m, [(-p[k][0], y, p[k][1]), (p[k][0], y, p[k][1]), (p[k + 1][0], y, p[k + 1][1]),
                 (-p[k + 1][0], y, p[k + 1][1])], band, (0, 1, 0))
    face(m, [(-p[7][0], y, p[7][1]), (p[7][0], y, p[7][1]), (p[8][0], y, p[8][1]), (-p[8][0], y, p[8][1])],
         "cap", (0, 0, 1))
    # the cuddy bulkhead: the step up from the cockpit sole to the foredeck
    u = u_of(HOUSE_FRONT)
    inner = s_half(u) - LINER
    face(m, [(-inner, HOUSE_FRONT, DECK), (inner, HOUSE_FRONT, DECK), (inner, HOUSE_FRONT, FORE),
             (-inner, HOUSE_FRONT, FORE)], "inside", (0, -1, 0))
    face(col, [(-inner, HOUSE_FRONT, DECK), (inner, HOUSE_FRONT, DECK), (inner, HOUSE_FRONT, FORE),
               (-inner, HOUSE_FRONT, FORE)], "collider", (0, -1, 0))


# ------------------------------------------------------------------------------------------ the wheelhouse

def wall_x(m, x, y0, y1, z0, z1, outside, t=0.06):
    """A side wall panel at x (outer face toward sign(x)), t thick."""
    sx = 1 if x > 0 else -1
    xo, xi = x, x - sx * t
    face(m, [(xo, y0, z0), (xo, y1, z0), (xo, y1, z1), (xo, y0, z1)], outside, (sx, 0, 0))
    face(m, [(xi, y0, z0), (xi, y1, z0), (xi, y1, z1), (xi, y0, z1)], "inside", (-sx, 0, 0))
    face(m, [(xo, y0, z1), (xo, y1, z1), (xi, y1, z1), (xi, y0, z1)], outside, (0, 0, 1))
    face(m, [(xo, y0, z0), (xo, y1, z0), (xi, y1, z0), (xi, y0, z0)], outside, (0, 0, -1))
    face(m, [(xo, y0, z0), (xi, y0, z0), (xi, y0, z1), (xo, y0, z1)], outside, (0, -1, 0))
    face(m, [(xo, y1, z0), (xi, y1, z0), (xi, y1, z1), (xo, y1, z1)], outside, (0, 1, 0))


def house(m, col):
    sill, head = DECK + 1.0, ROOF - 0.28
    for sx in (1, -1):
        x = sx * HOUSE_W
        wall_x(m, x, HOUSE_BACK, HOUSE_FRONT - 0.4, DECK, sill, "house")
        wall_x(m, x, HOUSE_BACK, HOUSE_FRONT - 0.4, head, ROOF, "house")
        # posts between the side windows
        for y0 in (HOUSE_BACK, 0.75, 1.75):
            wall_x(m, x, y0, y0 + 0.12, sill, head, "house")
        face(m, [(x - sx * 0.03, HOUSE_BACK + 0.12, sill), (x - sx * 0.03, HOUSE_FRONT - 0.4, sill),
                 (x - sx * 0.03, HOUSE_FRONT - 0.4, head), (x - sx * 0.03, HOUSE_BACK + 0.12, head)],
             "glass", (sx, 0, 0))
        # the raked corner up to the windshield
        wall_x(m, x, HOUSE_FRONT - 0.4, HOUSE_FRONT, DECK, FORE + 0.1, "house")
        wall_x(m, x, HOUSE_FRONT - 0.52, HOUSE_FRONT - 0.4, FORE + 0.1, ROOF, "house")
        col.box((min(x, x - sx * 0.08), HOUSE_BACK, DECK), (max(x, x - sx * 0.08), HOUSE_FRONT, ROOF), "collider")
    # the windshield: raked back from the foredeck to the hardtop, three panes
    yb, yt = HOUSE_FRONT, HOUSE_FRONT - 0.4
    zb, zt = FORE + 0.1, ROOF
    face(m, [(-HOUSE_W, yb, FORE), (HOUSE_W, yb, FORE), (HOUSE_W, yb, zb), (-HOUSE_W, yb, zb)], "house", (0, 1, 0))
    face(m, [(-HOUSE_W, yb, zb), (HOUSE_W, yb, zb), (HOUSE_W, yt, zt), (-HOUSE_W, yt, zt)], "glass", (0, 1, 0.4))
    for x in (-0.6, 0.6):
        m.beam((x, yb + 0.02, zb), (x, yt + 0.02, zt), 0.1, 0.06, "house")
    col.box((-HOUSE_W, HOUSE_FRONT - 0.1, DECK), (HOUSE_W, HOUSE_FRONT + 0.1, ROOF), "collider")
    # the hardtop: over the wheelhouse and aft over the front of the cockpit, posts at its aft corners
    ro = 0.12
    m.box((-HOUSE_W - ro, ROOF_AFT, ROOF), (HOUSE_W + ro, HOUSE_FRONT + 0.05, ROOF + 0.12), "house",
          mats={"-z": "inside"})
    for sx in (1, -1):
        cyl(m, (sx * (HOUSE_W - 0.05), ROOF_AFT + 0.12, DECK), (sx * (HOUSE_W - 0.05), ROOF_AFT + 0.12, ROOF),
            0.045, "steel")
        col.box((sx * (HOUSE_W - 0.05) - 0.06, ROOF_AFT + 0.06, DECK), (sx * (HOUSE_W - 0.05) + 0.06,
                ROOF_AFT + 0.18, ROOF), "collider")
    # the dash across the front, helm to starboard
    dash_y = HOUSE_FRONT - 0.65
    m.box((-HOUSE_W + 0.06, dash_y, DECK), (HOUSE_W - 0.06, HOUSE_FRONT - 0.1, DECK + 0.95), "dash")
    col.box((-HOUSE_W, dash_y, DECK), (HOUSE_W, HOUSE_FRONT, DECK + 0.95), "collider")
    # a sloped instrument panel on top, with the sonar and the radar
    zt0, zt1 = DECK + 0.95, DECK + 1.25
    face(m, [(0.05, dash_y, zt0), (HOUSE_W - 0.06, dash_y, zt0), (HOUSE_W - 0.06, dash_y + 0.35, zt1),
             (0.05, dash_y + 0.35, zt1)], "dash", (0, -1, 1))
    face(m, [(0.05, dash_y, zt0), (0.05, dash_y + 0.35, zt1), (0.05, dash_y + 0.35, zt0)], "dash", (-1, 0, 0))
    face(m, [(HOUSE_W - 0.06, dash_y, zt0), (HOUSE_W - 0.06, dash_y + 0.35, zt1),
             (HOUSE_W - 0.06, dash_y + 0.35, zt0)], "dash", (1, 0, 0))
    face(m, [(0.05, dash_y + 0.35, zt0), (HOUSE_W - 0.06, dash_y + 0.35, zt0), (HOUSE_W - 0.06, dash_y + 0.35, zt1),
             (0.05, dash_y + 0.35, zt1)], "dash", (0, 1, 0))
    for (x0, x1), mat in (((0.2, 0.75), "sonar"), ((0.85, 1.4), "radar_scope")):
        lift = Vector((0, -0.7, 0.7)) * 0.004
        a = Vector((x0, dash_y + 0.05, zt0 + 0.043)) + lift
        b = Vector((x1, dash_y + 0.05, zt0 + 0.043)) + lift
        c = Vector((x1, dash_y + 0.3, zt1 - 0.043)) + lift
        d = Vector((x0, dash_y + 0.3, zt1 - 0.043)) + lift
        m.face([tuple(a), tuple(b), tuple(c), tuple(d)], mat, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for i, x in enumerate((-1.2, -0.95)):
        m.face([(x, dash_y - 0.002, DECK + 0.7), (x + 0.2, dash_y - 0.002, DECK + 0.7),
                (x + 0.2, dash_y - 0.002, DECK + 0.9), (x, dash_y - 0.002, DECK + 0.9)], "gauge",
               uvs=[(1, 0), (0, 0), (0, 1), (1, 1)])
    # the skipper's seat, and a bench to port
    cyl(m, (0.9, 1.45, DECK), (0.9, 1.45, DECK + 0.55), 0.06, "steel")
    m.box((0.65, 1.25, DECK + 0.55), (1.15, 1.7, DECK + 0.68), "rubber")
    m.box((0.65, 1.62, DECK + 0.68), (1.15, 1.72, DECK + 1.15), "rubber")
    col.box((0.8, 1.35, DECK), (1.0, 1.55, DECK + 0.6), "collider")
    m.box((-HOUSE_W + 0.06, 0.1, DECK), (-HOUSE_W + 0.55, 1.9, DECK + 0.45), "inside")
    m.box((-HOUSE_W + 0.06, 0.1, DECK + 0.45), (-HOUSE_W + 0.55, 1.9, DECK + 0.55), "rubber")
    col.box((-HOUSE_W, 0.1, DECK), (-HOUSE_W + 0.55, 1.9, DECK + 0.55), "collider")
    # the cuddy door, under the dash to port
    face(m, [(-1.05, dash_y - 0.003, DECK + 0.02), (-0.45, dash_y - 0.003, DECK + 0.02),
             (-0.45, dash_y - 0.003, DECK + 0.6), (-1.05, dash_y - 0.003, DECK + 0.6)], "wood", (0, -1, 0))
    # nav lights on the house sides
    for sx, mat in ((1, "green_light"), (-1, "red_light")):
        m.box((sx * HOUSE_W - 0.02, HOUSE_FRONT - 0.3, ROOF - 0.2), (sx * HOUSE_W + sx * 0.08 + 0.02 * -sx,
              HOUSE_FRONT - 0.15, ROOF - 0.1), mat)


def wheel_obj(coll):
    w = psx.Mesh("wheel", TILES)
    hub = Vector((0.9, HOUSE_FRONT - 0.78, DECK + 1.05))
    axis = Vector((0, 1, 0.55)).normalized()
    w.torus(hub, axis, 0.22, 0.022, "rubber", seg=12, rseg=4)
    up = axis.cross(Vector((1, 0, 0))).normalized()
    side = axis.cross(up).normalized()
    for d in (up, -up, side, -side):
        w.cylinder(tuple(hub), tuple(hub + d * 0.21), 0.012, "steel", seg=4)
    w.cylinder(tuple(hub - axis * 0.02), tuple(hub + axis * 0.15), 0.035, "steel", seg=6)
    return w.finish(coll, origin=tuple(hub))


# ------------------------------------------------------------------------------------------ the cockpit

def cockpit(m, col, coll):
    # the fish box: a hatch flush in the sole with a lifting handle
    m.box((-0.65, -2.95, DECK), (0.65, -2.05, DECK + 0.03), "hatch")
    m.box((-0.12, -2.15, DECK + 0.03), (0.12, -2.1, DECK + 0.05), "steel")
    # the live well built into the transom, with a lid
    yi = Y0 + LINER
    m.box((-0.55, yi, DECK), (0.55, yi + 0.6, DECK + 0.72), "liner")
    m.box((-0.5, yi + 0.03, DECK + 0.72), (0.5, yi + 0.57, DECK + 0.75), "inside")
    col.box((-0.55, yi, DECK), (0.55, yi + 0.6, DECK + 0.75), "collider")
    # a cooler and a coil of rope, buoys tied off by the house
    m.box((-1.75, -1.6, DECK), (-1.05, -1.15, DECK + 0.5), "inside")
    m.box((-1.77, -1.62, DECK + 0.5), (-1.03, -1.13, DECK + 0.56), "liner")
    col.box((-1.77, -1.62, DECK), (-1.03, -1.13, DECK + 0.56), "collider")
    for i in range(3):
        m.torus((1.65, -6.1, DECK + 0.03 + i * 0.045), (0, 0, 1), 0.26 - i * 0.02, 0.025, "rope", seg=12, rseg=4)
    for x, y in ((-1.65, -0.8), (-1.65, -0.35)):
        m.sphere((x, y, DECK + 0.25), 0.25, "buoy", seg=8, rings=6)
    # cleats on the covering boards
    for y in (-6.3, -0.5):
        for sx in (1, -1):
            s, zs = s_half(u_of(y)), z_sheer(u_of(y))
            m.box((sx * (s - 0.07) - 0.025, y - 0.12, zs), (sx * (s - 0.07) + 0.025, y + 0.12, zs + 0.06), "steel")
    # the fighting chair, on its own object so it can swivel
    ch = psx.Mesh("chair", TILES)
    cy = -4.4
    ch.cylinder((0, cy, DECK), (0, cy, DECK + 0.42), 0.11, "steel", seg=8)
    ch.cylinder((0, cy, DECK), (0, cy, DECK + 0.03), 0.3, "steel", seg=8)
    ch.box((-0.32, cy - 0.3, DECK + 0.42), (0.32, cy + 0.3, DECK + 0.55), "liner")
    ch.box((-0.3, cy + 0.2, DECK + 0.58), (0.3, cy + 0.28, DECK + 1.12), "liner")
    ch.box((-0.34, cy + 0.28, DECK + 0.5), (0.34, cy + 0.36, DECK + 1.2), "wood")
    for sx in (1, -1):
        ch.box((sx * 0.38 - 0.04, cy - 0.25, DECK + 0.55), (sx * 0.38 + 0.04, cy + 0.28, DECK + 0.72), "wood")
    ch.beam((0, cy - 0.3, DECK + 0.48), (0, cy - 0.85, DECK + 0.25), 0.05, 0.05, "steel")
    ch.cylinder((-0.3, cy - 0.85, DECK + 0.25), (0.3, cy - 0.85, DECK + 0.25), 0.025, "steel", seg=6)
    ch.cylinder((0, cy - 0.3, DECK + 0.5), (0, cy - 0.3, DECK + 0.6), 0.03, "steel", seg=6)  # the gimbal
    chair = ch.finish(coll, origin=(0, cy, DECK))
    col.box((-0.15, cy - 0.15, DECK), (0.15, cy + 0.15, DECK + 0.5), "collider")
    return chair


def holders(m, coll):
    """Rod holders in the covering boards: three a side and two in the transom corners."""
    spots = []
    for y in (-6.0, -4.7, -3.4):
        for sx in (1, -1):
            spots.append((sx, y, Vector((sx * 0.25, -0.35, 1.0))))
    for sx in (1, -1):
        spots.append((sx, Y0 + 0.05, Vector((sx * 0.45, -0.6, 1.0))))
    out = []
    for i, (sx, y, d) in enumerate(spots):
        u = u_of(y)
        x = sx * (s_half(u) - LINER * 0.5) if y > Y0 + 0.2 else sx * 1.75
        zs = z_sheer(u) if y > Y0 + 0.2 else z_sheer(0.0)
        if y <= Y0 + 0.2:
            y = Y0 + LINER * 0.5
        d = d.normalized()
        rim = Vector((x, y, zs + 0.03))
        m.cylinder(tuple(rim - d * 0.3), tuple(rim), 0.035, "steel", seg=6)
        m.cylinder(tuple(rim - d * 0.01), tuple(rim), 0.05, "steel", seg=6)
        e = psx.empty("holder_%d" % i, coll, tuple(rim))
        e.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
        out.append(e)
    return out


# ------------------------------------------------------------------------------------------ up top

def rigging(m, coll):
    top = ROOF + 0.12
    # the tuna tower: four legs leaning in to a small platform, a rail round it
    plat = 5.4
    feet = [(1.7, -1.7), (-1.7, -1.7), (1.7, 2.5), (-1.7, 2.5)]
    heads = [(0.7, 0.35), (-0.7, 0.35), (0.7, 1.45), (-0.7, 1.45)]
    for (fx, fy), (hx, hy) in zip(feet, heads):
        cyl(m, (fx, fy, top), (hx, hy, plat + 0.95), 0.04, "steel")
    for lvl in (top + 1.1, top + 2.2):
        t = (lvl - top) / (plat + 0.95 - top)
        ring = [(fx + (hx - fx) * t, fy + (hy - fy) * t) for (fx, fy), (hx, hy) in zip(feet, heads)]
        for a, b in ((0, 1), (2, 3), (0, 2), (1, 3)):
            cyl(m, (*ring[a], lvl), (*ring[b], lvl), 0.025, "steel", seg=5)
    m.box((-0.75, 0.3, plat), (0.75, 1.5, plat + 0.06), "house")
    for a, b in ((0, 1), (2, 3), (0, 2), (1, 3)):
        cyl(m, (*heads[a], plat + 0.95), (*heads[b], plat + 0.95), 0.03, "steel", seg=5)
    m.box((-0.5, 1.2, plat + 0.06), (0.5, 1.45, plat + 0.8), "house")   # the tower helm
    # floodlights at the tower's aft corners, aimed down into the cockpit
    floods = []
    for i, sx in enumerate((1, -1)):
        p = Vector((sx * 0.78, 0.25, plat + 0.85))
        m.box(tuple(p - Vector((0.13, 0.08, 0.1))), tuple(p + Vector((0.13, 0.08, 0.1))), "steel")
        m.face([tuple(p + Vector((-0.11, -0.082, -0.08))), tuple(p + Vector((0.11, -0.082, -0.08))),
                tuple(p + Vector((0.11, -0.082, 0.08))), tuple(p + Vector((-0.11, -0.082, 0.08)))], "lamp",
               uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        e = psx.empty("flood_%d" % i, coll, tuple(p + Vector((0, -0.1, 0))))
        aim = (Vector((sx * 0.6, -4.5, DECK)) - e.location).normalized()
        e.rotation_euler = (-aim).to_track_quat('Z', 'Y').to_euler()
        floods.append(e)
    # cockpit lights under the hardtop's aft edge
    for i, sx in enumerate((1, -1)):
        p = Vector((sx * 1.0, ROOF_AFT + 0.25, ROOF - 0.02))
        m.box(tuple(p - Vector((0.15, 0.08, 0.04))), tuple(p + Vector((0.15, 0.08, 0.0))), "steel")
        m.face([tuple(p + Vector((-0.13, 0.07, -0.042))), tuple(p + Vector((0.13, 0.07, -0.042))),
                tuple(p + Vector((0.13, -0.07, -0.042))), tuple(p + Vector((-0.13, -0.07, -0.042)))], "lamp",
               uvs=[(0, 0), (1, 0), (1, 1), (0, 1)])
        e = psx.empty("deck_light_%d" % i, coll, tuple(p - Vector((0, 0, 0.06))))
        e.rotation_euler = (-0.35, 0.0, 0.0)  # -Z down and a little aft
        floods.append(e)
    # outriggers: bases on the hardtop's sides, long poles spread out and up over the water
    for sx in (1, -1):
        base = Vector((sx * (HOUSE_W + 0.1), 1.2, top - 0.05))
        tip = Vector((sx * 7.2, -5.3, 8.8))
        m.box(tuple(base - Vector((0.08, 0.12, 0.1))), tuple(base + Vector((0.08, 0.12, 0.1))), "steel")
        cyl(m, tuple(base), tuple(tip), 0.045, "steel", r1=0.016)
        cyl(m, tuple(base + Vector((0, 0, 0.1))), tuple(base.lerp(tip, 0.55)), 0.01, "steel", seg=4)
    # the radar dome's pedestal and the whip antennas
    cyl(m, (0, 2.2, top), (0, 2.2, top + 0.25), 0.08, "steel")
    for sx in (1, -1):
        cyl(m, (sx * 1.6, 2.8, top), (sx * 1.9, 2.6, top + 3.2), 0.02, "house", seg=4, r1=0.008)
    # the bow rail
    pts = []
    for y in (3.6, 4.6, 5.5, 6.2, 6.75):
        u = u_of(y)
        pts.append((s_half(u) - 0.06, y, z_sheer(u)))
    for sx in (1, -1):
        prev = None
        for x, y, z in pts:
            p = (sx * x, y, z + 0.6)
            cyl(m, (sx * x, y, z), p, 0.02, "steel", seg=5)
            if prev:
                cyl(m, prev, p, 0.022, "steel", seg=5)
            prev = p
    cyl(m, (pts[-1][0], pts[-1][1], pts[-1][2] + 0.6), (-pts[-1][0], pts[-1][1], pts[-1][2] + 0.6), 0.022,
        "steel", seg=5)
    # the radar's spinning bar
    r = psx.Mesh("radar", TILES)
    rz = top + 0.25
    r.box((-0.55, 2.1, rz), (0.55, 2.3, rz + 0.12), "house")
    radar = r.finish(coll, origin=(0, 2.2, rz))
    return floods, radar


def main():
    psx.clear_scene()
    materials()
    coll = psx.new_collection("boat")
    m = psx.Mesh("boat", TILES)
    col = psx.Mesh("collider", TILES)
    hull(m, col)
    house(m, col)
    chair = cockpit(m, col, coll)
    hs = holders(m, coll)
    floods, radar = rigging(m, coll)
    wheel = wheel_obj(coll)
    boat = m.finish(coll, bevel=0.012)
    collider = col.finish(coll)
    spawns = []
    for i, (x, y) in enumerate(((1.0, -1.4), (-1.0, -1.4), (1.3, -3.4), (-1.3, -3.4))):
        spawns.append(psx.empty("spawn_%d" % i, coll, (x, y, DECK), rot_z_deg=180.0))
    helm = psx.empty("helm", coll, (0.9, 1.55, DECK), rot_z_deg=0.0)
    objs = [boat, chair, wheel, radar, collider, helm] + hs + floods + spawns
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    psx.export_glb(os.path.abspath(OUT), objs, ao=True)
    print("wrote", os.path.abspath(OUT), len(boat.data.polygons), "faces")


main()
