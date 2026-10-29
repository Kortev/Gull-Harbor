"""The crew: a deckhand in oilskins, stylized (Sea of Thieves-ish): chunky cartoon proportions, soft rounded shapes.

Yellow bib-and-brace oilskin trousers over a navy hoodie, a knit beanie, orange rubber gloves, white deck boots, a
weathered face with a stubbly jaw. About 1.78 m. Built in pieces that pivot at the joints, so Godot can swing them
(crew/player.gd: legs and arms as you walk, arms out to the rod or the wheel, the head with your look):

  "torso"             hips to neck (origin at the hips, 0.95 m up)
  "head"              origin at the neck
  "arm_l", "arm_r"    the upper arms, origins at the shoulders (hanging straight down)
  "fore_l", "fore_r"  the forearms and gloves, origins at the elbows
  "leg_l", "leg_r"    the thighs, origins at the hips (standing straight)
  "shin_l", "shin_r"  the shins and boots, origins at the knees

All in the same space (Godot parents them: head and arms on the torso, forearms on the arms, shins on the thighs).

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
SHOULDER = Vector((0.29, 0.0, 1.42))
ELBOW = 1.12
KNEE = 0.5
LEG_X = 0.11

TILES = {k: (1.0, 1.0) for k in ("oilskin", "hoodie", "skin", "glove", "boot", "beanie", "dark", "strap", "sole",
                                  "beard", "eye")}


def materials():
    m = psx.make_material
    m("oilskin", color=(0.85, 0.62, 0.08), roughness=0.45)
    m("hoodie", color=(0.12, 0.17, 0.28), roughness=0.9)
    m("skin", color=(0.86, 0.6, 0.46), roughness=0.7)
    m("glove", color=(0.95, 0.4, 0.1), roughness=0.5)
    m("boot", color=(0.9, 0.88, 0.82), roughness=0.55)
    m("sole", color=(0.22, 0.19, 0.17), roughness=0.8)
    m("beanie", color=(0.72, 0.13, 0.1), roughness=0.95)
    m("dark", color=(0.07, 0.06, 0.06), roughness=0.6)
    m("beard", color=(0.32, 0.2, 0.12), roughness=0.95)
    m("eye", color=(0.95, 0.94, 0.9), roughness=0.3)
    m("strap", color=(0.6, 0.44, 0.06), roughness=0.5)


# The stylized finish: every piece's edges rounded and softened, smooth-shaded (psx.Mesh.finish).
SOFT = dict(bevel=0.04, subdiv=2)


def tapered(mesh, z0, z1, w0, d0, w1, d1, mat, x=0.0, y=0.0):
    """A box from z0 (w0 wide, d0 deep) to z1 (w1, d1), centred on x, y: a limb or a body piece."""
    a = [(x - w0 / 2, y - d0 / 2, z0), (x + w0 / 2, y - d0 / 2, z0), (x + w0 / 2, y + d0 / 2, z0),
         (x - w0 / 2, y + d0 / 2, z0)]
    b = [(x - w1 / 2, y - d1 / 2, z1), (x + w1 / 2, y - d1 / 2, z1), (x + w1 / 2, y + d1 / 2, z1),
         (x - w1 / 2, y + d1 / 2, z1)]
    mesh.prism(a, b, mat)


def torso(coll):
    """A barrel of a chest in a hoodie, the oilskin bib over it, braces over the shoulders."""
    t = psx.Mesh("torso", TILES)
    tapered(t, HIP - 0.06, HIP + 0.2, 0.4, 0.27, 0.44, 0.3, "oilskin")
    tapered(t, HIP + 0.2, 1.32, 0.44, 0.3, 0.5, 0.31, "hoodie")
    t.box((-0.17, -0.165, HIP + 0.18), (0.17, -0.14, 1.28), "oilskin")              # the bib's front
    t.box((-0.17, 0.14, HIP + 0.18), (0.17, 0.165, 1.2), "oilskin")                 # and back
    tapered(t, 1.32, NECK - 0.03, 0.5, 0.31, 0.34, 0.24, "hoodie")
    for sx in (1, -1):                                                              # the braces
        t.box((sx * 0.11 - 0.028, -0.17, 1.26), (sx * 0.11 + 0.028, -0.15, 1.46), "strap")
        t.box((sx * 0.11 - 0.028, 0.15, 1.18), (sx * 0.11 + 0.028, 0.17, 1.46), "strap")
    t.box((-0.1, -0.15, NECK - 0.09), (0.1, 0.1, NECK + 0.01), "hoodie")             # the hood bunched up
    return t.finish(coll, origin=(0, 0, HIP), **SOFT)


def head(coll):
    """A big friendly head: a bulb of a nose, eyes with brows, a scruffy beard, the beanie rolled up."""
    h = psx.Mesh("head", TILES)
    tapered(h, NECK - 0.02, NECK + 0.07, 0.13, 0.13, 0.13, 0.13, "skin")            # the neck
    tapered(h, NECK + 0.05, NECK + 0.35, 0.26, 0.27, 0.27, 0.28, "skin")
    for sx in (1, -1):
        h.box((sx * 0.065 - 0.03, 0.125, NECK + 0.21), (sx * 0.065 + 0.03, 0.142, NECK + 0.255), "eye")
        h.box((sx * 0.065 - 0.014, 0.138, NECK + 0.217), (sx * 0.065 + 0.014, 0.15, NECK + 0.248), "dark")
        h.box((sx * 0.065 - 0.04, 0.13, NECK + 0.268), (sx * 0.065 + 0.04, 0.152, NECK + 0.285), "beard")
        h.box((sx * 0.14 - 0.012, -0.03, NECK + 0.15), (sx * 0.14 + 0.012, 0.03, NECK + 0.23), "skin")  # ears
    h.box((-0.032, 0.13, NECK + 0.14), (0.032, 0.185, NECK + 0.205), "skin")          # the nose
    h.box((-0.13, -0.04, NECK + 0.04), (0.13, 0.15, NECK + 0.15), "beard")           # the beard
    h.box((-0.045, 0.14, NECK + 0.105), (0.045, 0.16, NECK + 0.12), "dark")          # the mouth in it
    tapered(h, NECK + 0.3, NECK + 0.45, 0.29, 0.3, 0.22, 0.23, "beanie")             # the beanie
    h.box((-0.15, -0.155, NECK + 0.29), (0.15, 0.155, NECK + 0.35), "beanie")         # its roll
    return h.finish(coll, origin=(0, 0, NECK), **SOFT)


def arm(coll, side):
    """The upper arm (shoulder to elbow) and the forearm with a big rubber glove (elbow down), apart so the elbow
    bends."""
    x = side * SHOULDER.x
    a = psx.Mesh("arm_l" if side < 0 else "arm_r", TILES)
    tapered(a, ELBOW - 0.03, SHOULDER.z + 0.05, 0.12, 0.13, 0.15, 0.16, "hoodie", x=x)
    upper = a.finish(coll, origin=(x, 0, SHOULDER.z), **SOFT)
    f = psx.Mesh("fore_l" if side < 0 else "fore_r", TILES)
    tapered(f, 0.88, ELBOW + 0.03, 0.11, 0.11, 0.12, 0.13, "hoodie", x=x)
    tapered(f, 0.78, 0.9, 0.13, 0.13, 0.15, 0.15, "glove", x=x)                     # the cuff
    f.box((x - 0.075, -0.07, 0.66), (x + 0.075, 0.08, 0.8), "glove")                # the big glove
    f.box((x - side * 0.075 - 0.03, 0.0, 0.72), (x - side * 0.075 + 0.03, 0.07, 0.8), "glove")   # its thumb
    fore = f.finish(coll, origin=(x, 0, ELBOW), **SOFT)
    return [upper, fore]


def leg(coll, side):
    """The thigh (hip to knee) and the shin with a big deck boot (knee down), apart so the knee bends."""
    x = side * LEG_X
    g = psx.Mesh("leg_l" if side < 0 else "leg_r", TILES)
    tapered(g, KNEE - 0.03, HIP, 0.17, 0.19, 0.2, 0.22, "oilskin", x=x)
    thigh = g.finish(coll, origin=(x, 0, HIP), **SOFT)
    s = psx.Mesh("shin_l" if side < 0 else "shin_r", TILES)
    tapered(s, 0.3, KNEE + 0.03, 0.16, 0.17, 0.17, 0.19, "oilskin", x=x)            # over the boot
    tapered(s, 0.05, 0.34, 0.17, 0.19, 0.16, 0.18, "boot", x=x)                     # the boot
    s.box((x - 0.085, -0.1, 0.0), (x + 0.085, 0.2, 0.14), "boot")                   # its foot
    s.box((x - 0.09, -0.105, 0.0), (x + 0.09, 0.205, 0.03), "sole")
    shin = s.finish(coll, origin=(x, 0, KNEE), **SOFT)
    return [thigh, shin]


def main():
    psx.clear_scene()
    materials()
    coll = psx.new_collection("crew")
    objs = [torso(coll), head(coll)] + arm(coll, -1) + arm(coll, 1) + leg(coll, -1) + leg(coll, 1)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    psx.export_glb(os.path.abspath(OUT), objs)
    print("wrote", os.path.abspath(OUT), sum(len(o.data.polygons) for o in objs), "faces")


main()
