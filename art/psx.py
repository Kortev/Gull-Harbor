"""PSX toolkit for Lane B's Blender scripts: crunchy textures, simple meshes, box UVs, export, renders.

Run a script that imports this with:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P <script.py>

Conventions (see the art brief):
- Meters. Blender Z up. Ship nose to Blender +Y (lands at Godot -Z). Props face Blender -Y (Godot +Z).
- Textures: 64 px per meter, 64-256 px square, no smoothing ('Closest'), colors quantized.
- Image arrays here are TOP-DOWN (row 0 = top of the image), RGBA float 0..1, sRGB values.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
DOWNLOADS = os.path.join(HERE, "_downloads")
TEXTURES = os.path.join(HERE, "textures")
RENDERS = os.path.join(HERE, "_renders")
PX_PER_M = 64


# ---------------------------------------------------------------- image io

def load_image(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return buf.reshape(h, w, 4)[::-1].copy()


def save_png(arr, path):
    arr = np.clip(np.asarray(arr, dtype=np.float32), 0.0, 1.0)
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones(arr.shape[:2] + (1,), np.float32)], axis=2)
    h, w = arr.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


def source(name):
    return load_image(os.path.join(DOWNLOADS, name, "diffuse.jpg"))


# ---------------------------------------------------------------- processing

def downsample(arr, size):
    """Area-average down to size x size (source sides must be multiples of size)."""
    h, w, c = arr.shape
    fy, fx = h // size, w // size
    arr = arr[:fy * size, :fx * size]
    return arr.reshape(size, fy, size, fx, c).mean(axis=(1, 3))


def crunch_photo(src, px, tiles=1):
    """A tileable photo -> px x px, repeating it tiles x tiles (keeps it seamless)."""
    small = downsample(src, px // tiles)
    return np.tile(small, (tiles, tiles, 1))


def luminance(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def grade(a, sat=1.0, gain=1.0, gamma=1.0, contrast=1.0, lift=0.0):
    out = a.copy()
    rgb = a[..., :3]
    lum = luminance(a)[..., None]
    rgb = lum + (rgb - lum) * sat
    mean = rgb.mean()
    rgb = (rgb - mean) * contrast + mean
    rgb = np.clip(rgb * gain + lift, 0.0, 1.0) ** gamma
    out[..., :3] = np.clip(rgb, 0.0, 1.0)
    return out


def colorize(a, color, amount=1.0, punch=1.0):
    """Recolor by luminance toward `color` (rgb 0..1). punch > 1 exaggerates light/dark."""
    lum = luminance(a)
    rel = (lum / max(float(lum.mean()), 1e-4)) ** punch
    rec = np.clip(np.asarray(color, np.float32)[None, None, :] * rel[..., None], 0.0, 1.0)
    out = a.copy()
    out[..., :3] = a[..., :3] * (1.0 - amount) + rec * amount
    return out


def hexcol(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 - 0.47


def quantize(a, n=32, dither=0.0, seed=1, iters=10):
    """k-means palette of n colors (PS1 CLUT feel), optional ordered dither."""
    h, w = a.shape[:2]
    rgb = a[..., :3].reshape(-1, 3).astype(np.float32)
    rng = np.random.default_rng(seed)
    n = min(n, len(rgb))
    centers = rgb[rng.choice(len(rgb), n, replace=False)].copy()
    for _ in range(iters):
        lab = ((rgb[:, None, :] - centers[None]) ** 2).sum(-1).argmin(1)
        for k in range(n):
            m = lab == k
            if m.any():
                centers[k] = rgb[m].mean(0)
    src = rgb
    if dither > 0.0:
        bt = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w].reshape(-1, 1)
        src = np.clip(rgb + bt * dither, 0.0, 1.0)
    lab = ((src[:, None, :] - centers[None]) ** 2).sum(-1).argmin(1)
    out = a.copy()
    out[..., :3] = centers[lab].reshape(h, w, 3)
    return out


def value_noise(h, w, cells, seed=0):
    """Tileable smooth noise in 0..1. cells = grid cells across the image."""
    rng = np.random.default_rng(seed)
    gy, gx = cells if isinstance(cells, tuple) else (cells, cells)
    grid = rng.random((gy, gx)).astype(np.float32)
    ys = np.arange(h) / h * gy
    xs = np.arange(w) / w * gx
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    ty = ys - y0
    tx = xs - x0
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)
    y1 = (y0 + 1) % gy
    x1 = (x0 + 1) % gx
    y0 %= gy
    x0 %= gx
    a = grid[y0][:, x0]
    b = grid[y0][:, x1]
    c = grid[y1][:, x0]
    d = grid[y1][:, x1]
    top = a + (b - a) * tx[None, :]
    bot = c + (d - c) * tx[None, :]
    return top + (bot - top) * ty[:, None]


def fbm(h, w, cells=4, octaves=4, seed=0):
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        c = (cells[0] * 2 ** o, cells[1] * 2 ** o) if isinstance(cells, tuple) else cells * (2 ** o)
        out += value_noise(h, w, c, seed + o * 17) * amp
        total += amp
        amp *= 0.5
    return out / total


def solid(px, color, alpha=1.0):
    a = np.zeros((px, px, 4), np.float32)
    a[..., :3] = color
    a[..., 3] = alpha
    return a


def multiply(a, m, strength=1.0):
    """Darken by a 0..1 mask (1 = untouched)."""
    out = a.copy()
    k = 1.0 - (1.0 - m[..., None]) * strength
    out[..., :3] *= k
    return out


def rect(a, x0, y0, x1, y1, color, alpha=1.0):
    a[y0:y1, x0:x1, :3] = color
    a[y0:y1, x0:x1, 3] = alpha


# ---------------------------------------------------------------- pixel font (5x7)

FONT = {
    'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    'B': ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    'C': ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    'D': ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    'E': ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    'F': ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    'G': ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    'H': ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    'I': ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    'J': ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    'K': ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    'M': ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    'N': ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
    'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    'Q': ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    'S': ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    'T': ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    'V': ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    'W': ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    'X': ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    'Y': ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    'Z': ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    '0': ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    '1': ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    '2': ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    '3': ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
    '4': ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    '5': ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    '6': ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    '7': ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    '8': ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    '9': ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    '-': ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    '.': ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ',': ["00000", "00000", "00000", "00000", "01100", "00100", "01000"],
    "'": ["01100", "00100", "01000", "00000", "00000", "00000", "00000"],
    '"': ["01010", "01010", "01010", "00000", "00000", "00000", "00000"],
    '!': ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    '?': ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
    ':': ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    '/': ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    '<': ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
    '>': ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
    '#': ["01010", "01010", "11111", "01010", "11111", "01010", "01010"],
    '+': ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    '&': ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
    ' ': ["00000"] * 7,
}


def text_width(text, scale=1):
    return (len(text) * 6 - 1) * scale


def draw_text(a, text, x, y, color, scale=1, alpha=1.0):
    """Draw text into a top-down RGBA array with its top-left at (x, y). Returns the width."""
    cx = x
    for ch in text.upper():
        rows = FONT.get(ch, FONT['?'])
        for r, row in enumerate(rows):
            for c, bit in enumerate(row):
                if bit == '1':
                    y0 = y + r * scale
                    x0 = cx + c * scale
                    a[y0:y0 + scale, x0:x0 + scale, :3] = color
                    a[y0:y0 + scale, x0:x0 + scale, 3] = alpha
        cx += 6 * scale
    return cx - x - scale


# ---------------------------------------------------------------- materials

_IMAGES = {}


def image(name):
    """A processed texture from textures/<name>.png, loaded once, no smoothing."""
    if name not in _IMAGES:
        img = bpy.data.images.load(os.path.join(TEXTURES, name + ".png"), check_existing=True)
        img.colorspace_settings.name = 'sRGB'
        _IMAGES[name] = img
    return _IMAGES[name]


def painted(name, color, vary=0.1, px=128):
    """A painted surface for the stylized look: `color` with a soft, hand-painted unevenness (low-frequency,
    tileable), as an image packed into the .glb. Brighter and cleaner than a photo, but not flat plastic."""
    key = "paint_" + name
    if key in _IMAGES:
        return _IMAGES[key]
    # (the boats' painted pixel art, art/boat_paint.py, for the materials it knows)
    try:
        import boat_paint
        arr = boat_paint.tile(name, color, px)
    except ImportError:
        arr = None
    if arr is not None:
        rgba = np.concatenate([arr, np.ones((px, px, 1))], axis=2)
        img = bpy.data.images.new(key, px, px, alpha=True)
        img.pixels = rgba[::-1].astype(np.float32).ravel()
        img.pack()
        _IMAGES[key] = img
        return img
    rng = np.random.default_rng(abs(hash(name)) % (2 ** 32))
    noise = np.zeros((px, px))
    for scale, weight in ((4, 0.6), (12, 0.3), (40, 0.1)):
        f = np.fft.fft2(rng.standard_normal((px, px)))
        fy = np.fft.fftfreq(px)[:, None]
        fx = np.fft.fftfreq(px)[None, :]
        f *= np.exp(-(fx ** 2 + fy ** 2) * (px / scale) ** 2)
        layer = np.real(np.fft.ifft2(f))
        noise += weight * layer / (np.abs(layer).max() + 1e-9)
    shade = 1.0 + vary * noise
    rgb = np.clip(np.array(color)[None, None, :] * shade[..., None], 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((px, px, 1))], axis=2)
    img = bpy.data.images.new(key, px, px, alpha=True)
    img.pixels = rgba[::-1].astype(np.float32).ravel()
    img.pack()
    _IMAGES[key] = img
    return img


def make_material(name, tex=None, color=(0.5, 0.5, 0.5), emit=0.0, cutout=False, alpha=None,
                  roughness=0.95, blend_tex=False, paint=None, metal=0.0):
    """Principled material. tex = texture name. emit > 0 glows with the texture/color.
    cutout = alpha clip (exported as glTF MASK). alpha = constant transparency (glTF BLEND).
    blend_tex = transparency from the texture's alpha (glTF BLEND)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metal
    if paint is not None:
        # the stylized look: a painted colour instead of the photo texture
        tex = None
        node = nt.nodes.new('ShaderNodeTexImage')
        node.image = painted(name, paint)
        node.interpolation = 'Linear'
        nt.links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
        col_socket = node.outputs['Color']
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.15
    if paint is None:
        col_socket = None
    if tex:
        node = nt.nodes.new('ShaderNodeTexImage')
        node.image = image(tex)
        node.interpolation = 'Linear'
        nt.links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
        col_socket = node.outputs['Color']
        if blend_tex:
            nt.links.new(node.outputs['Alpha'], bsdf.inputs['Alpha'])
        elif cutout:
            rnd = nt.nodes.new('ShaderNodeMath')
            rnd.operation = 'ROUND'
            nt.links.new(node.outputs['Alpha'], rnd.inputs[0])
            nt.links.new(rnd.outputs['Value'], bsdf.inputs['Alpha'])
    elif paint is None:
        bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    if emit > 0.0:
        if col_socket is not None:
            nt.links.new(col_socket, bsdf.inputs['Emission Color'])
        else:
            bsdf.inputs['Emission Color'].default_value = (*color, 1.0)
        bsdf.inputs['Emission Strength'].default_value = emit
    if alpha is not None:
        bsdf.inputs['Alpha'].default_value = alpha
        mat.surface_render_method = 'BLENDED'
    elif blend_tex:
        mat.surface_render_method = 'BLENDED'
    elif cutout:
        mat.surface_render_method = 'DITHERED'
    mat.use_backface_culling = alpha is None and not blend_tex
    return mat


# ---------------------------------------------------------------- mesh building

class Mesh:
    """Builds one mesh in WORLD coordinates with bmesh. Faces get a material by name; UVs are
    box-projected per face at the material's tile size unless given explicitly."""

    def __init__(self, name, tiles):
        self.name = name
        self.tiles = tiles  # material name -> (tile_u_m, tile_v_m) or callable(face) -> uvs
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.locked = self.bm.faces.layers.int.new("uvlock")
        self.mats = []

    def _mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, pts, mat, uvs=None):
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self._mi(mat)
        if uvs is not None:
            for loop, uv in zip(f.loops, uvs):
                loop[self.uv].uv = uv
            f[self.locked] = 1
        return f

    def bisect(self, co, no):
        """Cut every face crossing the plane (so materials can change along it)."""
        geom = self.bm.verts[:] + self.bm.edges[:] + self.bm.faces[:]
        bmesh.ops.bisect_plane(self.bm, geom=geom, plane_co=co, plane_no=no)

    def recolor(self, fn):
        """fn(face, current material name) -> new material name or None."""
        self.bm.normal_update()
        for f in self.bm.faces:
            name = fn(f, self.mats[f.material_index])
            if name:
                f.material_index = self._mi(name)

    def box(self, lo, hi, mat, skip=(), mats=None):
        """Axis-aligned box from corner lo to hi. skip: sides to leave open ('-x','+x','-y','+y',
        '-z','+z'). mats: per-side material overrides."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        sides = {
            '-x': [(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)],
            '+x': [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
            '-y': [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
            '+y': [(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)],
            '-z': [(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)],
            '+z': [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        }
        for s, pts in sides.items():
            if s in skip:
                continue
            self.face(pts, (mats or {}).get(s, mat))

    def prism(self, ring_a, ring_b, mat, cap_a=True, cap_b=True, mats=None):
        """Loft two closed rings (same count) into a tube; caps optional. Rings wind CCW seen
        from outside cap_a."""
        n = len(ring_a)
        for i in range(n):
            j = (i + 1) % n
            self.face([ring_a[i], ring_a[j], ring_b[j], ring_b[i]], (mats or {}).get('side', mat))
        if cap_a:
            self.face(list(reversed(ring_a)), (mats or {}).get('cap_a', mat))
        if cap_b:
            self.face(list(ring_b), (mats or {}).get('cap_b', mat))

    def loft(self, rings, mat_fn, cap_start=True, cap_end=True, cap_mat=None):
        """Loft a list of closed rings. mat_fn(i, k, quad_pts) -> material name."""
        n = len(rings[0])
        for s in range(len(rings) - 1):
            a, b = rings[s], rings[s + 1]
            for k in range(n):
                k2 = (k + 1) % n
                pts = [a[k], a[k2], b[k2], b[k]]
                if (Vector(pts[0]) - Vector(pts[1])).length < 1e-6 and (Vector(pts[2]) - Vector(pts[3])).length < 1e-6:
                    continue
                self.face(pts, mat_fn(s, k, pts))
        if cap_start:
            self.face(list(reversed(rings[0])), cap_mat or mat_fn(0, -1, rings[0]))
        if cap_end:
            self.face(list(rings[-1]), cap_mat or mat_fn(len(rings) - 1, -1, rings[-1]))

    def cylinder(self, p0, p1, r, mat, seg=8, caps=True, r1=None, rot=0.0, cap_mat=None):
        """Cylinder (or cone with r1) from p0 to p1."""
        p0, p1 = Vector(p0), Vector(p1)
        axis = (p1 - p0).normalized()
        ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        u = axis.cross(ref).normalized()
        v = axis.cross(u).normalized()
        r1 = r if r1 is None else r1
        ra, rb = [], []
        for i in range(seg):
            t = rot + 2 * math.pi * i / seg
            d = u * math.cos(t) + v * math.sin(t)
            ra.append(tuple(p0 + d * r))
            rb.append(tuple(p1 + d * r1))
        self.prism(ra, rb, mat, cap_a=caps, cap_b=caps, mats={'cap_a': cap_mat or mat, 'cap_b': cap_mat or mat} if caps else None)

    def beam(self, p0, p1, w, h, mat, up=(0, 0, 1)):
        """Rectangular beam (w wide, h tall) from p0 to p1."""
        p0, p1 = Vector(p0), Vector(p1)
        axis = (p1 - p0).normalized()
        up = Vector(up)
        if abs(axis.dot(up)) > 0.95:
            up = Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))
        side = axis.cross(up).normalized() * (w / 2)
        top = side.cross(axis).normalized() * (h / 2)
        ring = lambda p: [tuple(p - side - top), tuple(p + side - top), tuple(p + side + top), tuple(p - side + top)]
        self.prism(ring(p0), ring(p1), mat)

    def torus(self, center, axis, R, r, mat, seg=10, rseg=4):
        center, axis = Vector(center), Vector(axis).normalized()
        ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        u = axis.cross(ref).normalized()
        v = axis.cross(u).normalized()
        rings = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            d = u * math.cos(t) + v * math.sin(t)
            c = center + d * R
            ring = []
            for j in range(rseg):
                s = 2 * math.pi * j / rseg + math.pi / rseg
                ring.append(tuple(c + d * (r * math.cos(s)) + axis * (r * math.sin(s))))
            rings.append(ring)
        for i in range(seg):
            a, b = rings[i], rings[(i + 1) % seg]
            for j in range(rseg):
                j2 = (j + 1) % rseg
                self.face([a[j], b[j], b[j2], a[j2]], mat)

    def sphere(self, center, r, mat, seg=8, rings=5, squash=(1.0, 1.0, 1.0)):
        """Low-poly UV sphere with longitude/latitude UVs."""
        c = Vector(center)
        pts = {}
        for j in range(rings + 1):
            phi = math.pi * j / rings
            for i in range(seg + 1):
                th = 2 * math.pi * i / seg
                d = Vector((math.sin(phi) * math.cos(th) * squash[0], math.sin(phi) * math.sin(th) * squash[1], math.cos(phi) * squash[2]))
                pts[(i, j)] = (tuple(c + d * r), (i / seg, 1.0 - j / rings))
        for j in range(rings):
            for i in range(seg):
                quad = [pts[(i, j + 1)], pts[(i + 1, j + 1)], pts[(i + 1, j)], pts[(i, j)]]
                if j == 0:
                    quad = [quad[0], quad[1], quad[2]]
                elif j == rings - 1:
                    quad = [quad[0], quad[2], quad[3]]
                self.face([q[0] for q in quad], mat, uvs=[q[1] for q in quad])

    def finish(self, collection, origin=None, smooth=False, weld=True, bevel=0.0, subdiv=0):
        """`bevel` (m) rounds every hard edge, `subdiv` Catmull-Clark levels soften it further (the stylized look:
        chunky, soft-edged, smooth-shaded; both applied on export)."""
        bm = self.bm
        if weld:
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        _box_uvs(bm, self.uv, self.locked, self.mats, self.tiles)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(bpy.data.materials[m])
        soft = bevel > 0.0 or subdiv > 0
        for p in me.polygons:
            p.use_smooth = smooth or soft
        obj = bpy.data.objects.new(self.name, me)
        collection.objects.link(obj)
        if bevel > 0.0:
            bv = obj.modifiers.new("bevel", 'BEVEL')
            bv.width = bevel
            bv.segments = 1 if subdiv > 0 else 3
            bv.limit_method = 'ANGLE'
            bv.angle_limit = math.radians(35.0)
            bv.miter_outer = 'MITER_ARC'
        if subdiv > 0:
            sd = obj.modifiers.new("soften", 'SUBSURF')
            sd.levels = subdiv
            sd.render_levels = subdiv
        if soft:
            wn = obj.modifiers.new("normals", 'WEIGHTED_NORMAL')
            wn.keep_sharp = True
        if origin is not None:
            set_origin(obj, origin)
        return obj


def _box_uvs(bm, uv, locked, mats, tiles):
    for f in bm.faces:
        if f[locked]:
            continue
        mat = mats[f.material_index]
        tile = tiles.get(mat, (2.0, 2.0))
        if callable(tile):
            uvs = tile(f)
            for loop, t in zip(f.loops, uvs):
                loop[uv].uv = t
            continue
        tu, tv = tile[0], tile[1]
        voff = tile[2] if len(tile) > 2 else 0.0
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            p = loop.vert.co
            # u runs to the right of someone looking at the face, so text reads correctly
            if az >= ax and az >= ay:
                u, v = p.x, p.y if n.z > 0 else -p.y
            elif ax >= ay:
                u, v = (p.y if n.x > 0 else -p.y), p.z - voff
            else:
                u, v = (-p.x if n.y > 0 else p.x), p.z - voff
            loop[uv].uv = (u / tu, v / tv)


def set_origin(obj, origin):
    """Move obj's origin to a world point without moving its geometry."""
    origin = Vector(origin)
    obj.data.transform(Matrix.Translation(-origin))
    obj.location = origin


def empty(name, collection, loc, rot_z_deg=0.0, size=0.4):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'ARROWS'
    e.empty_display_size = size
    e.location = loc
    e.rotation_euler = (0.0, 0.0, math.radians(rot_z_deg))
    collection.objects.link(e)
    return e


def apply_boolean(obj, operand, operation='DIFFERENCE'):
    """Apply an exact boolean against an object or a collection; materials and UVs transfer."""
    mod = obj.modifiers.new("bool", 'BOOLEAN')
    mod.operation = operation
    mod.solver = 'EXACT'
    if hasattr(mod, 'material_mode'):
        mod.material_mode = 'TRANSFER'
    if isinstance(operand, bpy.types.Collection):
        mod.operand_type = 'COLLECTION'
        mod.collection = operand
    else:
        mod.object = operand
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    obj.modifiers.remove(mod)
    old = obj.data
    obj.data = me
    bpy.data.meshes.remove(old)


def new_collection(name, parent=None, hide=False):
    col = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(col)
    if hide:
        col.hide_render = True
        col.hide_viewport = True
    return col


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)


# ---------------------------------------------------------------- export and renders

def export_glb(path, objects, ao=False):
    """ao: bake ambient occlusion into the vertex colours first (art/boat_paint.py; Godot multiplies them in)."""
    extra = {}
    if ao:
        import boat_paint
        boat_paint.bake_ao(objects)
        extra["export_vertex_color"] = "ACTIVE"
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True, export_apply=True,
        export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT',
        export_image_format='AUTO', export_cameras=False, export_lights=False,
        export_extras=False, export_animations=False, **extra)


def look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def render_views(views, out_dir, res=(960, 540), world=(0.05, 0.06, 0.08), strength=0.6):
    """views: list of (name, location, target, lens_mm or ('ORTHO', scale))."""
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Standard'
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (*world, 1.0)
    bg.inputs['Strength'].default_value = strength
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, loc, target, lens in views:
        cam.location = loc
        look_at(cam, target)
        if isinstance(lens, tuple):
            cam_data.type = 'ORTHO'
            cam_data.ortho_scale = lens[1]
        else:
            cam_data.type = 'PERSP'
            cam_data.lens = lens
        cam_data.clip_start = 0.05
        cam_data.clip_end = 500
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
