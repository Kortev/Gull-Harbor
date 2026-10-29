"""A stand-up tuna rod: a stout 5'9" (1.75 m) blank on roller guides, a fat lever-drag reel, a gimbal butt.

Run: cd art && python3 rod.py  (bpy from pip). Writes ../rods/rod.glb.

Objects: "butt" (the rigid part: gimbal, butt grip, reel seat and the reel, the foregrip), "blank" (the bending part,
from the foregrip to the tip, with its guides: rods/rod_bend.gdshader bends it by its distance along), "handle" (the
reel's crank, turns about its axle), empties "tip" (where the line leaves) and "reel" (the spool's middle).
Godot axes after export: the butt's end at the origin, the rod along +Z, the reel on top (+Y). Blender: along -Y,
reel +Z. Original work."""
import math
import os
import sys

import bpy  # noqa: F401  (bmesh only exists once bpy is loaded)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import psx  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rods", "rod.glb")

LENGTH = 1.75
BUTT = 0.62             # the butt section (rigid) ends here; the blank bends from here to the tip
TILES = {"blank": (0.5, 0.5), "grip": (0.25, 0.25), "gold": (0.25, 0.25), "black": (0.25, 0.25),
         "steel": (0.25, 0.25), "line": (0.1, 0.1)}


def at(d, up=0.0, side=0.0):
    """A point d along the rod (Blender -Y), `up` above its axis, `side` to its right."""
    return (side, -d, up)


def main():
    psx.clear_scene()
    psx.make_material("blank", color=(0.03, 0.035, 0.04), roughness=0.4)
    psx.make_material("grip", "rubber")
    psx.make_material("gold", color=(0.75, 0.52, 0.12), roughness=0.35)
    psx.make_material("black", color=(0.02, 0.02, 0.02), roughness=0.5)
    psx.make_material("steel", "m_steel")
    psx.make_material("line", color=(0.85, 0.85, 0.7))
    coll = psx.new_collection("rod")

    b = psx.Mesh("butt", TILES)
    # the gimbal: a slotted aluminium cap
    b.cylinder(at(0.0), at(0.05), 0.024, "steel", seg=8)
    b.box((-0.026, -0.012, -0.004), (0.026, 0.0, 0.004), "black")
    # the butt grip and the reel seat
    b.cylinder(at(0.05), at(0.3), 0.021, "grip", seg=8)
    b.cylinder(at(0.3), at(0.44), 0.018, "steel", seg=8)
    # the reel: two gold side plates round a black spool, on a foot over the seat, a lever, the crank
    rc = at(0.37, up=0.085)
    for s in (-1, 1):
        b.cylinder((s * 0.045, rc[1], rc[2]), (s * 0.06, rc[1], rc[2]), 0.068, "gold", seg=10)
    b.cylinder((-0.045, rc[1], rc[2]), (0.045, rc[1], rc[2]), 0.058, "black", seg=10)
    b.cylinder((-0.045, rc[1], rc[2]), (0.045, rc[1], rc[2]), 0.052, "line", seg=10)
    b.box((-0.015, rc[1] - 0.03, 0.018), (0.015, rc[1] + 0.03, rc[2] - 0.05), "gold")
    b.beam((-0.065, rc[1] + 0.01, rc[2] + 0.02), (-0.068, rc[1] - 0.05, rc[2] + 0.075), 0.012, 0.012, "black")
    # the foregrip, up to where the blank comes out
    b.cylinder(at(0.44), at(BUTT), 0.02, "grip", seg=8, r1=0.017)
    butt = b.finish(coll)

    h = psx.Mesh("handle", TILES)
    axle = (0.06, rc[1], rc[2])
    h.cylinder(axle, (0.075, rc[1], rc[2]), 0.008, "steel", seg=6)
    h.beam((0.075, rc[1], rc[2]), (0.075, rc[1], rc[2] - 0.075), 0.014, 0.01, "gold")
    h.cylinder((0.075, rc[1], rc[2] - 0.075), (0.11, rc[1], rc[2] - 0.075), 0.013, "black", seg=6)
    handle = h.finish(coll, origin=axle)

    k = psx.Mesh("blank", TILES)
    k.cylinder(at(BUTT), at(LENGTH), 0.012, "blank", seg=6, r1=0.005)
    # roller guides: a small frame and a roller, smaller toward the tip, the line runs over them (top side)
    for i, d in enumerate((0.78, 0.97, 1.16, 1.34, 1.5, 1.64)):
        r = 0.012 + (0.005 - 0.012) * (d - BUTT) / (LENGTH - BUTT)
        hgt = 0.03 - i * 0.003
        k.box((-0.006, -d - 0.008, r * 0.5), (0.006, -d + 0.008, r + hgt), "steel")
        k.cylinder((-0.008, -d, r + hgt), (0.008, -d, r + hgt), 0.007, "gold", seg=6)
    k.cylinder(at(LENGTH - 0.02), at(LENGTH + 0.01), 0.008, "gold", seg=6)    # the tip top
    blank = k.finish(coll)

    tip = psx.empty("tip", coll, at(LENGTH + 0.01))
    reel = psx.empty("reel", coll, rc)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    psx.export_glb(os.path.abspath(OUT), [butt, handle, blank, tip, reel])
    print("wrote", os.path.abspath(OUT))


main()
