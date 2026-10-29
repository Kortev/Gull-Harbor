"""The fisherman, from scratch on a real human: MakeHuman's CC0 base body (through the MPFB 2 Blender extension),
shaped into one weathered, stocky fisherman in his fifties, then stylized a little the Sea of Thieves way (a long
face, a big nose, a heavy brow, big hands and feet) and kept believable: "a real person, but also not like it's real
life" (docs/ART_REFERENCE.md).

Run: "C:/Program Files/Blender Foundation/Blender 4.3/blender.exe" -b --python art/crew_human.py -- --preview=DIR
Needs the MPFB extension installed in Blender (extensions.blender.org/add-ons/mpfb)."""
import math
import os
import sys

import bpy
from mathutils import Vector

from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.targetservice import TargetService

V = Vector
PREVIEW = None
for a in sys.argv:
    if a.startswith("--preview="):
        PREVIEW = a.split("=", 1)[1]

# The body: a young man (mid twenties, like the people playing it), fit, average height, mixed heritage.
MACRO = dict(gender=1.0, age=0.5, muscle=0.62, weight=0.55, proportions=0.65, height=0.55, cupsize=0.5,
             firmness=0.5, race=dict(asian=0.15, caucasian=0.7, african=0.15))

# The character: each target and how hard (0..1). The exaggeration lives here.
SHAPE = {
    # the head: long, squared, a strong brow and chin
    "head-rectangular": 0.5, "head-scale-vert-incr": 0.35,
    "forehead-trans-forward": 0.3, "eyebrows-trans-forward": 0.7, "eyebrows-trans-down": 0.25,
    "chin-prominent-incr": 0.7, "chin-width-incr": 0.4, "chin-bones-incr": 0.5, "chin-height-incr": 0.3,
    # a big nose with a bump in it
    "nose-scale-vert-incr": 0.7, "nose-scale-depth-incr": 0.8, "nose-scale-horiz-incr": 0.25,
    "nose-hump-incr": 0.4, "nose-point-width-incr": 0.7, "nose-volume-incr": 0.6, "nose-point-down": 0.2,
    "nose-flaring-incr": 0.3,
    # cheekbones, eyes a little deep-set
    "l-cheek-bones-incr": 0.7, "r-cheek-bones-incr": 0.7,
    "l-eye-scale-decr": 0.15, "r-eye-scale-decr": 0.15,
    "l-eye-push1-in": 0.2, "r-eye-push1-in": 0.2,
    # a wide mouth, a hint of a smirk
    "mouth-scale-horiz-incr": 0.25, "mouth-angles-up": 0.2,
    # big-ish ears, a strong neck
    "l-ear-scale-incr": 0.25, "r-ear-scale-incr": 0.25, "l-ear-flap-incr": 0.3, "r-ear-flap-incr": 0.3,
    "measure-neck-circ-incr": 0.4,
    # the body: broad shoulders; big working hands and feet
    "measure-shoulder-dist-incr": 0.5, "torso-vshape-incr": 0.3,
    "l-hand-scale-incr": 1.0, "r-hand-scale-incr": 1.0, "l-hand-fingers-diameter-incr": 0.6,
    "r-hand-fingers-diameter-incr": 0.6, "l-foot-scale-incr": 0.4, "r-foot-scale-incr": 0.4,
}


def human():
    obj = HumanService.create_human(mask_helpers=True, detailed_helpers=True, extra_vertex_groups=True,
                                    feet_on_ground=True, scale=0.1, macro_detail_dict=MACRO)
    missing = []
    for name, val in SHAPE.items():
        path = TargetService.target_full_path(name)
        if path is None:
            missing.append(name)
            continue
        TargetService.load_target(obj, path, weight=val, name=name)
    if missing:
        print("missing targets:", missing)
    TargetService.bake_targets(obj)
    eyes = []
    for side in ("l", "r"):
        gi = obj.vertex_groups["helper-%s-eye" % side].index
        pts = [obj.matrix_world @ v.co for v in obj.data.vertices if any(g.group == gi for g in v.groups)]
        c = sum(pts, V()) / len(pts)
        r = sum((q - c).length for q in pts) / len(pts)
        eyes.append((c, r))
    # drop the helper geometry (MPFB's mask): only the body
    for m in list(obj.modifiers):
        if m.type == 'MASK':
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=m.name)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj, eyes


def eyeball(c, r, iris_col):
    """An eyeball looking ahead (-Y): the white, a coloured iris, a black pupil, all glossy."""
    out = []
    for name, rad, off, sq, col, rough in (("white", r, 0.0, 1.0, (0.93, 0.9, 0.86), 0.12),
                                           ("iris", r * 0.52, r * 0.82, 0.35, iris_col, 0.1),
                                           ("pupil", r * 0.26, r * 0.95, 0.3, (0.02, 0.02, 0.03), 0.05)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=rad, location=c + V((0, -off, 0)))
        o = bpy.context.active_object
        o.scale.y = sq
        bpy.ops.object.transform_apply(scale=True)
        for p in o.data.polygons:
            p.use_smooth = True
        m = bpy.data.materials.new("eye_" + name)
        m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*col, 1)
        b.inputs['Roughness'].default_value = rough
        o.data.materials.append(m)
        out.append(o)
    return out


def clay():
    m = bpy.data.materials.new("clay")
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (0.75, 0.62, 0.55, 1)
    b.inputs['Roughness'].default_value = 0.45
    return m


def preview(objs, tag):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    sc.render.resolution_x, sc.render.resolution_y = 1000, 1000
    sc.view_settings.view_transform = 'AgX'
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.6, 0.65, 0.72, 1)
    bg.inputs['Strength'].default_value = 0.6
    for nm, e, c, r in (("key", 3.2, (1, 0.94, 0.85), (55, 0, -40)), ("fill", 0.8, (0.7, 0.75, 1), (65, 0, 140)),
                        ("rim", 2.0, (1, 0.95, 0.9), (110, 0, 170))):
        L = bpy.data.objects.new(nm, bpy.data.lights.new(nm, 'SUN'))
        L.data.energy, L.data.color = e, c
        L.rotation_euler = [math.radians(a) for a in r]
        sc.collection.objects.link(L)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    top = max((o.matrix_world @ V(c)).z for o in objs for c in o.bound_box)
    os.makedirs(PREVIEW, exist_ok=True)
    head = top - 0.12
    for name, loc, tgt, lens in (("body", (1.3, -3.4, top * 0.55), (0, 0, top * 0.5), 50),
                                 ("face", (0.28, -0.75, head), (0, 0, head - 0.02), 85),
                                 ("profile", (0.8, -0.05, head), (0, 0, head - 0.02), 85)):
        cam.location = loc
        cam.rotation_euler = (V(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam.data.lens = lens
        sc.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (tag, name))
        bpy.ops.render.render(write_still=True)


def main():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.materials):
        for x in list(coll):
            coll.remove(x)
    body, eyes = human()
    body.data.materials.clear()
    body.data.materials.append(clay())
    parts = [body]
    for c, r in eyes:
        parts += eyeball(c, r, (0.32, 0.45, 0.42))
    dims = body.dimensions
    print("body: %d verts, %.2f m tall, faces -Y? bbox y %.2f..%.2f" % (
        len(body.data.vertices), dims.z, min(v.co.y for v in body.data.vertices), max(v.co.y for v in body.data.vertices)))
    if PREVIEW:
        preview(parts, "human")


main()
