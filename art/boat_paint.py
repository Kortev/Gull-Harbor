"""The boats' paint, in the crew's style (art/fisherman.py, the space fishing game's suit kit): each material a small
tiling pixel-art texture painted from the kit's crunched CC0 photos (art/kit/textures), worn the way work wears a
boat: gelcoat scuffed and chipped, the non-skid deck's pattern with dirt and fish scales in it, antifouling mottled
with barnacles, teak in planks, canvas woven and sun-faded, rope twisted, rubber scuffed, steel brushed.

art/psx.py's painted() asks tile(name, colour, px) for a material's texture (rows top to bottom, RGB 0..1) and
falls back to its old soft paint for a name this file doesn't know."""
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PHOTOS = os.path.join(HERE, "kit", "textures")
LUM = np.array([0.299, 0.587, 0.114])
_photos = {}


def photo(name, px):
    """A kit photo, tiled up or cropped to px x px (rows top to bottom)."""
    key = (name, px)
    if key not in _photos:
        import bpy
        img = bpy.data.images.load(os.path.join(PHOTOS, name + ".png"), check_existing=True)
        w, h = img.size
        a = np.array(img.pixels[:], np.float32).reshape(h, w, 4)[::-1, :, :3]
        ys = np.arange(px) % h
        xs = np.arange(px) % w
        _photos[key] = a[ys][:, xs]
    return _photos[key]


def rng(name, salt=0):
    return np.random.default_rng((abs(hash(name)) + salt) % (2 ** 32))


def noise(px, cells, seed, octaves=3):
    """Tileable value noise 0..1."""
    r = np.random.default_rng(seed)
    out = np.zeros((px, px))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = cells * 2 ** o
        g = r.random((c, c))
        t = np.arange(px) * c / px
        i0 = np.floor(t).astype(int)
        f = t - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % c
        a = g[i0][:, i0] * (1 - f[None, :]) + g[i0][:, i1] * f[None, :]
        b = g[i1][:, i0] * (1 - f[None, :]) + g[i1][:, i1] * f[None, :]
        out += amp * (a * (1 - f[:, None]) + b * f[:, None])
        tot += amp
        amp *= 0.5
    return out / tot


def tint(src, colour, amount=0.85, punch=0.5):
    """The photo recoloured toward `colour` by its own light and dark (the kit's Painter.fill)."""
    lum = src @ LUM
    rel = (lum / max(float(lum.mean()), 1e-4)) ** punch
    return np.clip(src * (1 - amount) + np.asarray(colour)[None, None, :] * rel[..., None] * amount, 0, 1)


def mix(img, mask, colour, alpha=1.0):
    m = np.clip(mask * alpha, 0, 1)[..., None]
    return img * (1 - m) + np.asarray(colour) * m


def specks(px, n, seed, size=1):
    r = np.random.default_rng(seed)
    m = np.zeros((px, px))
    for _ in range(n):
        y, x = r.integers(0, px, 2)
        m[y:y + size, x:x + size] = 1.0
    return m


def scratches(px, n, seed, length=10):
    """Short straight scratches, wrapping."""
    r = np.random.default_rng(seed)
    m = np.zeros((px, px))
    for _ in range(n):
        y, x = r.integers(0, px, 2)
        dx, dy = r.choice([(1, 0), (1, 1), (1, -1), (2, 1)])
        for k in range(int(length * (0.5 + r.random()))):
            m[(y + dy * k // 2) % px, (x + dx * k) % px] = 1.0
    return m


def shade(c, k):
    return tuple(min(1.0, v * k) for v in c)


# ------------------------------------------------------------------ the surfaces

def gelcoat(name, colour, px, grime=0.25):
    img = tint(photo("boot_white", px), colour, 0.9, 0.35)
    img = img * (0.95 + 0.08 * noise(px, 3, 1))[..., None]
    img = mix(img, scratches(px, 10, 2, 12), shade(colour, 0.82), 0.6)
    img = mix(img, scratches(px, 6, 3, 8), shade(colour, 1.08), 0.7)
    img = mix(img, specks(px, 8, 4, 2), (0.55, 0.52, 0.46), 0.6)                     # chips
    img = mix(img, np.clip((noise(px, 5, 5) - 0.6) * 3, 0, 1), (0.42, 0.38, 0.3), grime)
    return img


def hatch(name, colour, px):
    img = gelcoat(name, colour, px, 0.15)
    edge = np.zeros((px, px))
    edge[:2, :] = edge[-2:, :] = edge[:, :2] = edge[:, -2:] = 1.0
    img = mix(img, edge, shade(colour, 0.45), 0.9)                                   # the gutter round it
    for y, x in ((px // 2, 6), (px // 2, px - 8)):
        img[y - 2:y + 2, x - 2:x + 2] = (0.6, 0.6, 0.58)                             # the hinges
    return img


def nonskid(name, colour, px):
    img = tint(photo("boot_white", px), colour, 0.9, 0.3)
    yy, xx = np.mgrid[0:px, 0:px]
    dots = ((yy % 4 < 2) & (xx % 4 < 2) & ((yy // 4 + xx // 4) % 2 == 0))
    img = mix(img, dots.astype(float), shade(colour, 0.84), 0.8)
    img = mix(img, np.clip((noise(px, 4, 11) - 0.55) * 2.5, 0, 1), (0.38, 0.34, 0.28), 0.35)   # dirt
    img = mix(img, specks(px, 14, 12), (0.92, 0.94, 0.96), 0.9)                   # fish scales
    img = mix(img, specks(px, 4, 13, 2), (0.36, 0.07, 0.06), 0.7)                # blood
    return img


def antifouling(name, colour, px):
    img = tint(photo("rust_metal", px), colour, 0.8, 0.5)
    img = img * (0.88 + 0.2 * noise(px, 4, 21))[..., None]
    img = mix(img, specks(px, 40, 22), (0.72, 0.7, 0.62), 0.8)                    # barnacles
    img = mix(img, np.clip((noise(px, 6, 23) - 0.6) * 3, 0, 1), (0.2, 0.3, 0.16), 0.5)   # weed
    return img


def stripe(name, colour, px):
    img = tint(photo("boot_white", px), colour, 0.92, 0.3)
    return mix(img, scratches(px, 8, 31, 10), shade(colour, 1.4), 0.6)


def rubber(name, colour, px):
    img = tint(photo("rubber", px), colour, 0.85, 0.5)
    return mix(img, scratches(px, 14, 41, 8), shade(colour, 2.4), 0.5)


def canvas(name, colour, px):
    img = tint(photo("m_canvas", px), colour, 0.85, 0.5)
    yy, xx = np.mgrid[0:px, 0:px]
    img = img * (1.0 - 0.06 * ((yy + xx) % 2))[..., None]                         # the weave
    seam = (xx % 64 < 1).astype(float)
    img = mix(img, seam, shade(colour, 0.6), 0.8)
    stitch = ((xx % 64 == 3) & (yy % 4 < 2)).astype(float)
    img = mix(img, stitch, shade(colour, 1.5), 0.6)
    img = img * (1.0 + 0.12 * (1 - yy / px))[..., None]                           # faded by the sun on top
    return np.clip(img, 0, 1)


def teak(name, colour, px):
    img = tint(photo("wood", px), colour, 0.8, 0.6)
    yy, xx = np.mgrid[0:px, 0:px]
    plank = yy // 16
    grain = np.sin((xx + plank * 37) * 0.35 + noise(px, 4, 51) * 6) * 0.5 + 0.5
    img = img * (0.88 + 0.16 * grain)[..., None]
    img = mix(img, (yy % 16 == 0).astype(float), (0.12, 0.08, 0.05), 0.85)       # the caulked seams
    ends = ((xx + plank * 45) % 96 == 0).astype(float)
    img = mix(img, ends, (0.2, 0.13, 0.08), 0.7)
    img = mix(img, np.clip((noise(px, 5, 52) - 0.55) * 3, 0, 1), (0.6, 0.55, 0.48), 0.35)    # silvered by the sun
    return img


def steel(name, colour, px):
    img = np.ones((px, px, 3)) * np.asarray(colour)
    r = rng(name, 61)
    streak = r.random((px, 1)) * np.ones((1, px))
    img = img * (0.88 + 0.2 * streak)[..., None]
    return mix(img, specks(px, 6, 62), (0.45, 0.25, 0.12), 0.6)                   # a little rust


def rope(name, colour, px):
    img = np.ones((px, px, 3)) * np.asarray(colour)
    yy, xx = np.mgrid[0:px, 0:px]
    strand = ((xx + yy) % 8) / 8.0
    img = img * (0.7 + 0.45 * np.sin(strand * np.pi))[..., None]
    return mix(img, np.clip((noise(px, 4, 71) - 0.5) * 2, 0, 1), (0.4, 0.35, 0.25), 0.4)


def gloss(name, colour, px):
    img = tint(photo("rubber", px), colour, 0.9, 0.3)
    yy, _ = np.mgrid[0:px, 0:px]
    img = mix(img, ((yy > px * 0.62) & (yy < px * 0.66)).astype(float), (0.85, 0.85, 0.82), 0.9)   # a pin stripe
    return mix(img, scratches(px, 12, 81, 6), (0.45, 0.45, 0.45), 0.6)


PAINTERS = {
    "topsides": gelcoat, "cap": gelcoat, "liner": gelcoat, "house": gelcoat, "inside": gelcoat,
    "hatch": hatch, "deck": nonskid, "bottom": antifouling, "boot": stripe, "rubrail": rubber, "rubber": rubber,
    "canvas": canvas, "wood": teak, "steel": steel, "rope": rope, "motor": gloss, "buoy": gelcoat,
}


def tile(name, colour, px):
    """The texture for material `name`, or None for one this file doesn't paint."""
    fn = PAINTERS.get(name)
    if fn is None:
        return None
    return np.clip(fn(name, tuple(colour), px), 0.0, 1.0)


def bake_ao(objects, distance=0.25, floor=0.45):
    """Ambient occlusion into each mesh's vertex colours (the kit's way: the crevices and the corners under things
    darker, never below `floor`); Godot multiplies them in (core/psx_import.gd)."""
    import bpy
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.cycles.device = "CPU"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.light_settings.distance = distance
    sc.render.bake.target = "VERTEX_COLORS"
    for ob in objects:
        if ob.type != "MESH" or ob.name == "collider" or not ob.data.polygons:
            continue
        col = ob.data.color_attributes.new(name="AO", type="BYTE_COLOR", domain="CORNER")
        ob.data.color_attributes.active_color = col
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
        for d in col.data:
            v = floor + (1.0 - floor) * d.color[0]
            d.color = (v, v, v, 1.0)
        print("[ao] %s" % ob.name)
