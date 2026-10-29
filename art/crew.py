"""The crew: a deckhand in oilskins, low and chunky like the rest of the game (PS1).

Yellow bib-and-brace oilskin trousers over a navy hoodie, a knit beanie, orange rubber gloves, white deck boots, a
weathered face with a stubbly jaw. About 1.78 m. Built in pieces that pivot at the joints, so Godot can swing them
(crew/player.gd: legs and arms as you walk, arms out to the rod or the wheel, the head with your look):

  "torso"           hips to neck (origin at the hips, 0.95 m up)
  "head"            origin at the neck
  "arm_l", "arm_r"  origins at the shoulders (hanging straight down)
  "leg_l", "leg_r"  origins at the hips (standing straight)

The oilskins' material is called "oilskin" so each crew member can wear their own colour (crew/player.gd).

Run: cd art && python3 crew.py  (bpy from pip). Writes ../crew/crew.glb.

Blender: Z up, facing +Y (Godot -Z), the feet on Z = 0."""
import os
import sys

import bpy  # noqa: F401,E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import psx  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "crew", "crew.glb")

HIP = 0.95
NECK = 1.5
SHOULDER = Vector((0.24, 0.0, 1.42))
LEG_X = 0.11

TILES = {k: (1.0, 1.0) for k in ("oilskin", "hoodie", "skin", "glove", "boot", "beanie", "dark", "strap", "sole")}


def materials():
    m = psx.make_material
    m("oilskin", color=(0.85, 0.62, 0.08), roughness=0.55)
    m("hoodie", color=(0.1, 0.13, 0.2))
    m("skin", color=(0.72, 0.52, 0.4))
    m("glove", color=(0.92, 0.36, 0.08), roughness=0.5)
    m("boot", color=(0.86, 0.85, 0.8), roughness=0.6)
    m("sole", color=(0.25, 0.22, 0.2))
    m("beanie", color=(0.62, 0.1, 0.08))
    m("dark", color=(0.07, 0.06, 0.06))
    m("strap", color=(0.55, 0.4, 0.06), roughness=0.55)


def tapered(mesh, z0, z1, w0, d0, w1, d1, mat, x=0.0, y=0.0):
    """A box from z0 (w0 wide, d0 deep) to z1 (w1, d1), centred on x, y: a limb or a body piece."""
    a = [(x - w0 / 2, y - d0 / 2, z0), (x + w0 / 2, y - d0 / 2, z0), (x + w0 / 2, y + d0 / 2, z0),
         (x - w0 / 2, y + d0 / 2, z0)]
    b = [(x - w1 / 2, y - d1 / 2, z1), (x + w1 / 2, y - d1 / 2, z1), (x + w1 / 2, y + d1 / 2, z1),
         (x - w1 / 2, y + d1 / 2, z1)]
    mesh.prism(a, b, mat)


def torso(coll):
    t = psx.Mesh("torso", TILES)
    # the oilskin bib up to the chest, the hoodie's shoulders and arms' tops above it
    tapered(t, HIP - 0.05, HIP + 0.18, 0.36, 0.24, 0.38, 0.25, "oilskin")
    tapered(t, HIP + 0.18, 1.3, 0.38, 0.25, 0.4, 0.24, "hoodie")
    t.box((-0.15, -0.135, HIP + 0.18), (0.15, -0.12, 1.3), "oilskin")              # the bib's front
    t.box((-0.15, 0.12, HIP + 0.18), (0.15, 0.135, 1.22), "oilskin")               # and back
    tapered(t, 1.3, NECK - 0.04, 0.4, 0.24, 0.3, 0.2, "hoodie")
    for sx in (1, -1):                                                              # the braces over the shoulders
        t.box((sx * 0.1 - 0.025, -0.13, 1.28), (sx * 0.1 + 0.025, -0.115, 1.46), "strap")
        t.box((sx * 0.1 - 0.025, 0.115, 1.2), (sx * 0.1 + 0.025, 0.13, 1.46), "strap")
    t.box((-0.07, -0.13, NECK - 0.08), (0.07, 0.07, NECK), "hoodie")               # the hood bunched at the neck
    return t.finish(coll, origin=(0, 0, HIP))


def head(coll):
    h = psx.Mesh("head", TILES)
    tapered(h, NECK, NECK + 0.06, 0.1, 0.1, 0.1, 0.1, "skin")                       # the neck
    tapered(h, NECK + 0.06, NECK + 0.27, 0.19, 0.21, 0.2, 0.22, "skin")
    h.box((-0.085, 0.105, NECK + 0.17), (0.085, 0.112, NECK + 0.2), "dark")         # the eyes' shadow
    h.box((-0.02, 0.11, NECK + 0.12), (0.02, 0.135, NECK + 0.18), "skin")           # the nose
    h.box((-0.09, 0.0, NECK + 0.06), (0.09, 0.113, NECK + 0.12), "dark")            # the stubbly jaw
    tapered(h, NECK + 0.25, NECK + 0.36, 0.21, 0.23, 0.17, 0.19, "beanie")          # the beanie, its turn-up
    h.box((-0.106, -0.116, NECK + 0.24), (0.106, 0.116, NECK + 0.29), "beanie")
    return h.finish(coll, origin=(0, 0, NECK))


def arm(coll, side):
    name = "arm_l" if side < 0 else "arm_r"
    a = psx.Mesh(name, TILES)
    x = side * SHOULDER.x
    tapered(a, 1.12, SHOULDER.z + 0.04, 0.1, 0.11, 0.12, 0.13, "hoodie", x=x)      # the upper arm
    tapered(a, 0.86, 1.12, 0.085, 0.09, 0.1, 0.11, "hoodie", x=x)                   # the forearm
    tapered(a, 0.72, 0.86, 0.09, 0.07, 0.1, 0.1, "glove", x=x)                      # the glove, its cuff
    a.box((x - 0.06, -0.06, 0.82), (x + 0.06, 0.06, 0.88), "glove")
    return a.finish(coll, origin=(x, 0, SHOULDER.z))


def leg(coll, side):
    name = "leg_l" if side < 0 else "leg_r"
    g = psx.Mesh(name, TILES)
    x = side * LEG_X
    tapered(g, 0.5, HIP, 0.15, 0.17, 0.17, 0.2, "oilskin", x=x)                     # the thigh
    tapered(g, 0.3, 0.5, 0.14, 0.15, 0.15, 0.17, "oilskin", x=x)                    # the shin, over the boot
    tapered(g, 0.04, 0.32, 0.13, 0.15, 0.12, 0.14, "boot", x=x)                     # the boot
    g.box((x - 0.065, -0.08, 0.0), (x + 0.065, 0.16, 0.12), "boot")                 # its foot
    g.box((x - 0.07, -0.085, 0.0), (x + 0.07, 0.165, 0.025), "sole")
    return g.finish(coll, origin=(x, 0, HIP))


def main():
    psx.clear_scene()
    materials()
    coll = psx.new_collection("crew")
    objs = [torso(coll), head(coll), arm(coll, -1), arm(coll, 1), leg(coll, -1), leg(coll, 1)]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    psx.export_glb(os.path.abspath(OUT), objs)
    print("wrote", os.path.abspath(OUT), sum(len(o.data.polygons) for o in objs), "faces")


main()
