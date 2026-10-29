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
    lm = landmarks(obj, eyes)
    lm["hair"] = helper_part(obj, "helper-hair", "hair_cap")
    lm["tights"] = helper_part(obj, "helper-tights", "tights")
    # drop the helper geometry (MPFB's mask): only the body
    for m in list(obj.modifiers):
        if m.type == 'MASK':
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=m.name)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj, eyes, lm


def helper_part(obj, group, name):
    """A copy of one of MakeHuman's fitting helpers (the hair cap, the tights) as its own mesh: it already fits this
    body, so it's the start of the hair and the clothes."""
    import bmesh
    me = obj.data.copy()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = obj.matrix_world
    gi = obj.vertex_groups[group].index
    keep = {v.index for v in obj.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)}
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context='VERTS')
    bm.to_mesh(me)
    bm.free()
    o.shape_key_clear() if o.data.shape_keys else None
    for p in me.polygons:
        p.use_smooth = True
    return o


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


def centroid(obj, group):
    gi = obj.vertex_groups[group].index
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
    return sum(pts, V()) / len(pts) if pts else None


def landmarks(obj, eyes):
    """Where the features are on this body (for painting): the nose's tip, the lips, the cheeks, the ears, the chin."""
    neck = centroid(obj, "joint-neck")
    head = [obj.matrix_world @ v.co for v in obj.data.vertices if (obj.matrix_world @ v.co).z > neck.z + 0.05]
    tip = min((p for p in head if abs(p.x) < 0.015), key=lambda p: p.y)
    lips = centroid(obj, "lips")
    gi = obj.vertex_groups["ears"].index
    ears = [obj.matrix_world @ v.co for v in obj.data.vertices if any(g.group == gi for g in v.groups)]
    left = [p for p in ears if p.x > 0]
    right = [p for p in ears if p.x < 0]
    ear_l = sum(left, V()) / max(1, len(left))
    ear_r = sum(right, V()) / max(1, len(right))
    (el, _), (er, _) = eyes
    if el.x < er.x:
        el, er = er, el
    return dict(tip=tip, lips=lips, ear_l=ear_l, ear_r=ear_r, cheek_l=el + V((0.012, -0.004, -0.035)),
                cheek_r=er + V((-0.012, -0.004, -0.035)), chin=V((0.0, lips.y + 0.01, lips.z - 0.045)), neck=neck,
                brow_l=el + V((0.004, 0.0, 0.0165)), brow_r=er + V((-0.004, 0.0, 0.0165)))


SKIN = (0.92, 0.62, 0.47)
SHADOW = (0.42, 0.34, 0.52)


class Nodes:
    """A little helper for writing paint shaders."""

    def __init__(self, m):
        self.nt = m.node_tree
        self.nt.nodes.clear()
        self.geo = self.new('ShaderNodeNewGeometry')

    def new(self, kind):
        return self.nt.nodes.new(kind)

    def link(self, a, b):
        self.nt.links.new(a, b)

    def rgb(self, c):
        n = self.new('ShaderNodeRGB')
        n.outputs[0].default_value = (*c, 1)
        return n.outputs[0]

    def mix(self, a, b, f, mode='MIX'):
        n = self.new('ShaderNodeMix')
        n.data_type = 'RGBA'
        n.blend_type = mode
        if isinstance(f, float):
            n.inputs['Factor'].default_value = f
        else:
            self.link(f, n.inputs['Factor'])
        self.link(a, n.inputs[6])
        self.link(b, n.inputs[7])
        return n.outputs[2]

    def range(self, src, a, b, c, d):
        n = self.new('ShaderNodeMapRange')
        self.link(src, n.inputs['Value'])
        n.inputs[1].default_value, n.inputs[2].default_value = a, b
        n.inputs[3].default_value, n.inputs[4].default_value = c, d
        return n.outputs['Result']

    def spot(self, pt, r, scale=(1, 1, 1)):
        """1 at the point, fading to 0 at radius r (scale squashes it per axis)."""
        mp = self.new('ShaderNodeMapping')
        self.link(self.geo.outputs['Position'], mp.inputs[0])
        mp.inputs['Location'].default_value = (-pt.x / scale[0], -pt.y / scale[1], -pt.z / scale[2])
        mp.inputs['Scale'].default_value = (1 / scale[0], 1 / scale[1], 1 / scale[2])
        ln = self.new('ShaderNodeVectorMath')
        ln.operation = 'LENGTH'
        self.link(mp.outputs[0], ln.inputs[0])
        return self.range(ln.outputs['Value'], r * 0.2, r, 1.0, 0.0)

    def noise(self, scale, w=0.0, detail=3.0):
        n = self.new('ShaderNodeTexNoise')
        n.noise_dimensions = '4D'
        n.inputs['W'].default_value = w
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        self.link(self.geo.outputs['Position'], n.inputs['Vector'])
        return n.outputs['Fac']

    def mul(self, a, b):
        n = self.new('ShaderNodeMath')
        n.operation = 'MULTIPLY'
        self.link(a, n.inputs[0])
        if isinstance(b, float):
            n.inputs[1].default_value = b
        else:
            self.link(b, n.inputs[1])
        return n.outputs[0]

    def light(self, col, ao_dist=0.03):
        """Painted light: lighter on top, a cool purple-grey in the hollows."""
        sep = self.new('ShaderNodeSeparateXYZ')
        self.link(self.geo.outputs['Position'], sep.inputs[0])
        top = self.range(sep.outputs['Z'], 0.0, 1.85, 0.88, 1.04)
        tc = self.new('ShaderNodeCombineColor')
        for i in range(3):
            self.link(top, tc.inputs[i])
        col = self.mix(col, tc.outputs[0], 1.0, 'MULTIPLY')
        ao = self.new('ShaderNodeAmbientOcclusion')
        ao.samples = 16
        ao.inputs['Distance'].default_value = ao_dist
        self.link(col, ao.inputs['Color'])
        shadow = self.mix(col, self.rgb(SHADOW), 0.6, 'MULTIPLY')
        return self.mix(shadow, col, self.range(ao.outputs['AO'], 0.4, 1.0, 0.0, 1.0))

    def emit(self, col):
        out = self.new('ShaderNodeOutputMaterial')
        em = self.new('ShaderNodeEmission')
        self.link(em.outputs[0], out.inputs['Surface'])
        self.link(col, em.inputs['Color'])


def skin_material(lm):
    """The skin's paint (baked): warm with a soft mottle, ruddy cheeks, nose and ears, darker lips, a stubble shadow
    on the jaw, painted light."""
    m = bpy.data.materials.new("skin_paint")
    m.use_nodes = True
    n = Nodes(m)
    col = n.rgb(SKIN)
    col = n.mix(col, n.rgb((0.78, 0.5, 0.42)), n.range(n.noise(9.0, 1.0), 0.35, 0.65, 0.0, 0.35))
    ruddy = n.rgb((0.88, 0.38, 0.32))
    col = n.mix(col, ruddy, n.mul(n.spot(lm["tip"], 0.035), 0.7))
    for k in ("cheek_l", "cheek_r"):
        col = n.mix(col, ruddy, n.mul(n.spot(lm[k], 0.035, (1.0, 0.6, 0.8)), 0.6))
    for k in ("ear_l", "ear_r"):
        col = n.mix(col, ruddy, n.mul(n.spot(lm[k], 0.04), 0.65))
    col = n.mix(col, n.rgb((0.7, 0.38, 0.36)), n.mul(n.spot(lm["lips"], 0.03, (1.0, 0.35, 0.35)), 0.8))
    jaw = n.spot(lm["chin"] + V((0, 0.035, 0.012)), 0.075, (1.0, 0.8, 0.7))
    dots = n.range(n.noise(400.0, 3.0, 1.0), 0.45, 0.6, 0.0, 1.0)
    col = n.mix(col, n.rgb((0.32, 0.24, 0.22)), n.mul(n.mul(jaw, dots), 0.5))
    col = n.mix(col, n.rgb((0.64, 0.5, 0.48)), n.mul(jaw, 0.22))
    col = n.mix(col, n.rgb((0.7, 0.38, 0.36)), n.mul(n.spot(lm["lips"], 0.022, (1.0, 0.35, 0.35)), 0.8))
    # thick eyebrows: a squashed spot over each eye, broken into strokes
    strokes = n.range(n.noise(220.0, 7.0, 1.0), 0.25, 0.5, 0.7, 1.0)
    for k, tilt in (("brow_l", 1.0), ("brow_r", -1.0)):
        brow = n.spot(lm[k], 0.03, (0.9, 4.0, 0.33))
        col = n.mix(col, n.rgb((0.2, 0.13, 0.09)), n.mul(n.range(brow, 0.25, 0.6, 0.0, 1.0), strokes))
    n.emit(n.light(col))
    return m


def bake(obj, paint, name, size=2048):
    """Bakes a paint material into the object's UVs; returns the image."""
    obj.data.materials.clear()
    obj.data.materials.append(paint)
    img = bpy.data.images.new(name, size, size)
    t = paint.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = img
    paint.node_tree.nodes.active = t
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 16
    sc.render.bake.margin = 8
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type='EMIT')
    img.pack()
    return img


def shows(img, name, rough=0.5, sss=0.0):
    """A plain material showing a baked texture."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    tx = m.node_tree.nodes.new('ShaderNodeTexImage')
    tx.image = img
    m.node_tree.links.new(tx.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = rough
    if sss > 0 and 'Subsurface Weight' in b.inputs:
        b.inputs['Subsurface Weight'].default_value = sss
        b.inputs['Subsurface Radius'].default_value = (1.0, 0.35, 0.2)
    if 'Specular IOR Level' in b.inputs:
        b.inputs['Specular IOR Level'].default_value = 0.35
    return m


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
    sc.view_settings.view_transform = 'Standard'
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
    body, eyes, lm = human()
    img = bake(body, skin_material(lm), "fisherman_skin")
    body.data.materials.clear()
    body.data.materials.append(shows(img, "skin", 0.5, 0.08))
    parts = [body]
    for c, r in eyes:
        parts += eyeball(c, r, (0.32, 0.45, 0.42))
    hair = lm["hair"]
    hm = bpy.data.materials.new("hair")
    hm.use_nodes = True
    hm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.25, 0.15, 0.09, 1)
    hair.data.materials.append(hm)
    hair.hide_render = True                 # (MakeHuman's long-hair stand-in: not ours)
    lm["tights"].hide_render = True
    dims = body.dimensions
    print("body: %d verts, %.2f m tall, faces -Y? bbox y %.2f..%.2f" % (
        len(body.data.vertices), dims.z, min(v.co.y for v in body.data.vertices), max(v.co.y for v in body.data.vertices)))
    if PREVIEW:
        preview(parts, "human")


main()
