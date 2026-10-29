"""The Bluefin fisherman (the crew everyone plays), built with the space fishing game's suit kit (art/kit/suit_kit.py,
the user's own: chunky low-poly forms where every detail is a piece with thickness, one 128 px atlas painted from
crunched CC0 photos, worn where work wears it, ambient occlusion baked into the vertex colours). The user's brief: very
low poly and simple, a young guy, a bit cute, better than the space game's suits.

A young deckhand: a face you can see (eyes with a glint, a nose, brows, a smirk, ears, sideburns), a red knit beanie
with a rolled brim, a tag and a pom-pom; a navy fisherman's jumper with a roll neck, its sleeves pushed up over bare
forearms (an anchor inked on them); oilskin bib-and-brace trousers (the player's colour: the kit's accent, painted
near white, tinted in game) with a pocket, braces over the shoulders, buckles, reflective bands, a hem over the boots;
green sea boots, orange rubber gloves.

The kit builds it skinned to the space game's 47-bone rig; then it's cut by bone into the ten pieces Bluefin's crew
swing at the joints (crew/player.gd): "torso" (origin at the hips), "head" (the neck), "arm_l"/"arm_r" (shoulders),
"fore_l"/"fore_r" (elbows, gloves included), "leg_l"/"leg_r" (hips), "shin_l"/"shin_r" (knees, boots included).
The accent material is renamed "oilskin" (crew/player.gd tints it).

Run: "C:/Program Files/Blender Foundation/Blender 4.3/blender.exe" -b --factory-startup -P art/fisherman.py --
     --out <folder> [--preview <folder>] [--game]
     (--out: where the kit writes its skinned glb and atlas; --game: also write crew/crew.glb; --preview: the kit's
     sheet plus docs-style renders of the cut pieces with the oilskin tinted)"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "kit"))
import suit_kit as K  # noqa: E402
from suit_kit import MAT_ACCENT, MAT_BODY, W, Part, arm_w, box, glove, leg_w, pipe, plate, ring_row, sheet, tube  # noqa

SID = "bluefin_fisherman"
GAME_GLB = os.path.normpath(os.path.join(HERE, "..", "crew", "crew.glb"))

R = {
    "jumper": (0, 96, 64, 32),
    "sleeve": (0, 80, 32, 16),
    "roll": (32, 80, 32, 8),
    "arm": (32, 88, 32, 8),
    "collar": (64, 120, 32, 8),
    "beanie": (64, 104, 32, 16),
    "brim": (96, 112, 32, 16),
    "bib": (96, 96, 32, 16),
    "pocket": (64, 96, 16, 8),
    "eye": (80, 96, 8, 8),
    "tag": (88, 96, 8, 8),
    "oil_top": (0, 64, 64, 16),
    "oil_leg": (0, 32, 32, 32),
    "boot": (32, 32, 32, 32),
    "glove": (64, 32, 32, 32),
    "face": (64, 64, 32, 32),
    "face_fx": (96, 32, 32, 32),        # (the face layer's place in the atlas: in game it shows faces.png instead)
}
K.check_regions(R)
P = K.patches(["dark", "skin", "nose", "white", "hair", "mouth", "knit", "knit_dark", "beanie_dark", "accent",
               "accent_dark", "metal", "sole", "glove", "boot", "reflect", "cream", "leather", "fish", "fish_dark"])

S = 12
TURN = math.pi / S
# the face layer: FACE_W x FACE_H metres over the front of the head from FACE_Y0 up, a grid laid on the skin
FACE_W, FACE_H, FACE_Y0, FACE_COLS, FACE_ROWS = 0.16, 0.15, 1.565, 16, 12
# the expressions, left to right along the strip (crew/player.gd's FACE_* match these)
FACES = ["neutral", "blink", "happy", "shocked", "strain", "tired", "angry", "dizzy", "smug", "sad"]
CELL = 64
HEAD_SCALE = 0.88       # (the head built at a size, then made this much smaller about the neck)
HEAD_SINK = 1.465       # (and the neck's foot moved down to here: the head sits down in the roll neck)
NAVY = (0.13, 0.17, 0.3)
RED = (0.66, 0.13, 0.1)
SKIN = (0.92, 0.66, 0.5)
HAIR = (0.3, 0.19, 0.11)
BOOT = (0.17, 0.27, 0.19)
GLOVE = (0.92, 0.42, 0.1)


def band(region, row, rows, mat=MAT_BODY):
    return K.region_band(R, region, row, rows, mat)


def solid(name):
    return K.solid_region(P, name)


def front_u(w, turn=TURN, sides=S):
    return int(round(w * (math.pi - turn) / (2.0 * math.pi))) % w


def parts():
    head, upper, lower, gloves = Part("Crew_Head"), Part("Crew_Upper"), Part("Crew_Lower"), Part("Crew_Gloves")
    tw, hw, hp = W(torso=1.0), W(head=1.0), W(hips=1.0)

    # ================================================================== the head: a young face, the beanie over it
    tube(head, [
        ((0.0, 1.47, 0.02), 0.074, 0.074, W(torso=0.5, head=0.5)),
        ((0.0, 1.512, 0.026), 0.078, 0.08, hw),                # a proper neck, into the jaw
        ((0.0, 1.528, 0.034), 0.084, 0.092, hw),               # under the jaw: a crisp line
        ((0.0, 1.538, 0.05), 0.104, 0.112, hw),                # the jaw: wide and square
        ((0.0, 1.58, 0.048), 0.11, 0.116, hw),                 # the mouth
        ((0.0, 1.612, 0.042), 0.114, 0.12, hw),                # the cheeks
        ((0.0, 1.66, 0.036), 0.117, 0.121, hw),                # the eyes
        ((0.0, 1.70, 0.03), 0.115, 0.119, hw),                 # the brow
        ((0.0, 1.735, 0.026), 0.106, 0.11, hw),
    ], S, (R["face"], MAT_BODY), cap_top=(P["skin"], MAT_BODY), turn=TURN)
    # the face: a layer over the front of the head, painted with the expressions (FACES, below), swapped in game
    # by sliding its texture along the strip (crew/player.gd). Laid on the bare head, before the nose goes on.
    def face_at(x, y, lift):
        return K.on_surface(head, (x, y, 0.3), (0.0, 0.0, -1.0), lift)

    rows = []
    for j in range(FACE_ROWS + 1):
        y = FACE_Y0 + FACE_H * j / FACE_ROWS
        rows.append([(face_at(FACE_W / 2 - FACE_W * i / FACE_COLS, y, 0.0035), hw) for i in range(FACE_COLS + 1)])
    sheet(head, rows, R["face_fx"], K.MAT_VISOR, inside=(0.0, 1.64, 0.0), rims=False)
    # a man's nose: a straight bridge down from the brow to a tip
    # (every point found on the bare face first: a ray that meets the bridge from inside gives up)
    bridge = [face_at(0.0, 1.664, 0.002), face_at(0.0, 1.636, 0.012), face_at(0.0, 1.622, 0.02)]
    tip = [face_at(0.0, 1.627, 0.016), face_at(0.0, 1.62, 0.024)]
    pipe(head, bridge, 0.0105, 6, hw, P["skin"], caps=False)
    pipe(head, tip, 0.0135, 6, hw, P["nose"], caps=True)
    for x in (1.0, -1.0):
        # the ears; sideburns down from under the beanie
        s0 = len(head.godot)
        plate(head, (x * 0.118, 1.637, 0.03), (0.0, 0.0, -x), (0.0, 1.0, 0.0), 0.036, 0.056, 0.02, hw, P["skin"])
        K.seat(head, s0, (x, 0.0, 0.0), sink=0.004, turn=False)
        s0 = len(head.godot)
        plate(head, (x * 0.112, 1.677, 0.075), (0.0, 0.0, -x), (0.0, 1.0, 0.0), 0.024, 0.042, 0.006, hw, P["hair"])
        K.seat(head, s0, (x, 0.0, 0.0))
    # hair at the back of the neck, under the beanie
    s0 = len(head.godot)
    plate(head, (0.0, 1.672, -0.09), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0), 0.15, 0.05, 0.008, hw, P["hair"])
    K.seat(head, s0, (0.0, 0.0, -1.0))

    # the beanie: the crown, a rolled brim standing off it, a leather tag on the front, a pom-pom
    crown = [((0.0, 1.715, 0.026), 0.121, 0.125, hw), ((0.0, 1.76, 0.022), 0.118, 0.122, hw),
             ((0.0, 1.8, 0.018), 0.098, 0.1, hw), ((0.0, 1.826, 0.014), 0.058, 0.06, hw)]
    tube(head, crown, 16, (R["beanie"], MAT_BODY), cap_top=(P["beanie_dark"], MAT_BODY), turn=math.pi / 16)
    brim = [((0.0, 1.688, 0.03), 0.13, 0.134, hw), ((0.0, 1.737, 0.028), 0.132, 0.136, hw)]
    tube(head, brim, 16, (R["brim"], MAT_BODY), turn=math.pi / 16)
    sheet(head, [ring_row((0.0, 1.737, 0.028), 0.132, 0.136, 16, hw, turn=math.pi / 16),
                 ring_row((0.0, 1.737, 0.026), 0.12, 0.124, 16, hw, turn=math.pi / 16)],
          solid("beanie_dark"), MAT_BODY, inside=(0.0, 1.5, 0.0), rims=False)
    sheet(head, [ring_row((0.0, 1.688, 0.03), 0.13, 0.134, 16, hw, turn=math.pi / 16),
                 ring_row((0.0, 1.688, 0.03), 0.115, 0.119, 16, hw, turn=math.pi / 16)],
          solid("beanie_dark"), MAT_BODY, inside=(0.0, 1.9, 0.0), rims=False)
    s0 = len(head.godot)
    plate(head, (0.045, 1.712, 0.165), (1.0, 0.0, -0.3), (0.0, 1.0, 0.0), 0.03, 0.024, 0.004, hw, P["leather"],
          front=R["tag"])
    K.seat(head, s0, (0.3, 0.0, 1.0))
    pipe(head, [(0.0, 1.822, 0.014), (0.0, 1.845, 0.013), (0.0, 1.868, 0.012)], 0.034, 8, hw, P["cream"],
         shaggy=0.3, seed=5, caps=True)

    for i in range(len(head.godot)):
        g = head.godot[i]
        q = (g[0] * HEAD_SCALE, HEAD_SINK + (g[1] - 1.5) * HEAD_SCALE, 0.03 + (g[2] - 0.03) * HEAD_SCALE)
        head.godot[i] = q
        head.verts[i] = K.to_blender(q)

    # ================================================================== the jumper: navy knit, a roll neck
    tube(upper, [
        ((0.0, 0.95, 0.0), 0.165, 0.12, W(hips=0.5, torso=0.5)),
        ((0.0, 1.02, 0.005), 0.168, 0.122, tw),
        ((0.0, 1.12, 0.012), 0.18, 0.13, tw),
        ((0.0, 1.22, 0.014), 0.192, 0.136, tw),
        ((0.0, 1.3, 0.012), 0.212, 0.14, tw),
        ((0.0, 1.38, 0.008), 0.226, 0.136, tw),                # the shoulders: broad and square
        ((0.0, 1.418, 0.004), 0.2, 0.124, tw),
        ((0.0, 1.44, 0.004), 0.13, 0.108, tw),                 # the top of the shoulders, in to the neck
    ], S, (R["jumper"], MAT_BODY), turn=TURN)
    tube(upper, [
        ((0.0, 1.425, 0.006), 0.118, 0.11, tw),
        ((0.0, 1.445, 0.008), 0.124, 0.116, tw),               # a short, fat roll neck
        ((0.0, 1.472, 0.012), 0.116, 0.11, W(torso=0.6, head=0.4)),
        ((0.0, 1.48, 0.014), 0.09, 0.088, W(torso=0.5, head=0.5)),
    ], S, (R["collar"], MAT_BODY), turn=TURN)
    for side, x in (("l", 1.0), ("r", -1.0)):
        arm = "arm_" + side
        tube(upper, [
            ((x * 0.245, 1.0, 0.0), 0.06, 0.06, W(**arm_w(side, 1.0))),
            ((x * 0.245, 1.06, 0.0), 0.064, 0.064, W(**{arm: 1.0})),
            ((x * 0.243, 1.2, 0.0), 0.068, 0.068, W(**{arm: 1.0})),
            ((x * 0.238, 1.3, 0.0), 0.076, 0.076, W(**{arm: 1.0})),
            ((x * 0.236, 1.36, 0.0), 0.084, 0.082, W(**arm_w(side, 1.36))),
            ((x * 0.228, 1.405, 0.0), 0.07, 0.07, W(torso=0.5, **{arm: 0.5})),        # the shoulder's cap
            ((x * 0.215, 1.425, 0.0), 0.04, 0.04, W(torso=0.5, **{arm: 0.5})),
        ], 8, (R["sleeve"], MAT_BODY), cap_top=(P["knit"], MAT_BODY))

    # ================================================================== the bib and braces (the player's colour)
    K.slab(upper, (0.0, 1.13, 0.16), (1.0, 0.0, 0.0), (0.0, 1.0, 0.08), 0.24, 0.26, 0.008, tw, P["accent"],
           mat=MAT_ACCENT, front=R["bib"], segs=(4, 4))
    K.slab(upper, (0.0, 1.15, 0.17), (1.0, 0.0, 0.0), (0.0, 1.0, 0.08), 0.12, 0.08, 0.006, tw, P["accent"],
           mat=MAT_ACCENT, front=R["pocket"], segs=(2, 1))
    # the little touch: a mackerel stuffed head first in the bib pocket, its tail sticking out, a bit bent
    mid = K.on_surface(upper, (0.018, 1.19, 0.3), (0.0, 0.0, -1.0), 0.004)
    pipe(upper, [(mid[0] - 0.004, 1.165, mid[2] - 0.002), (mid[0], 1.195, mid[2] + 0.002),
                 (mid[0] + 0.008, 1.228, mid[2] + 0.008)], 0.016, 6, tw, P["fish"], caps=True)
    pipe(upper, [(mid[0] + 0.008, 1.226, mid[2] + 0.008), (mid[0] + 0.013, 1.248, mid[2] + 0.012)], 0.007, 5, tw,
         P["fish_dark"], caps=True)
    tail = (mid[0] + 0.014, 1.258, mid[2] + 0.013)
    for lean in (-1.0, 1.0):
        plate(upper, (tail[0] + lean * 0.013, tail[1] + 0.01, tail[2]), (1.0, 0.0, 0.0), (lean * 0.8, 1.0, 0.0),
              0.018, 0.036, 0.004, tw, P["fish_dark"])
    K.slab(upper, (0.0, 1.08, -0.15), (-1.0, 0.0, 0.0), (0.0, 1.0, -0.05), 0.2, 0.16, 0.008, tw, P["accent"],
           mat=MAT_ACCENT, front=R["bib"], segs=(4, 3))
    for x in (1.0, -1.0):
        pts = [K.on_surface(upper, (x * 0.085, 1.255, 0.3), (0.0, 0.0, -1.0), 0.006),
               K.on_surface(upper, (x * 0.1, 1.345, 0.3), (0.0, 0.0, -1.0), 0.005),
               K.on_surface(upper, (x * 0.122, 1.47, 0.0), (0.0, -1.0, 0.0), 0.005),
               K.on_surface(upper, (x * 0.1, 1.34, -0.3), (0.0, 0.0, 1.0), 0.005),
               K.on_surface(upper, (x * 0.085, 1.16, -0.3), (0.0, 0.0, 1.0), 0.006)]
        for a, b in zip(pts[:-1], pts[1:]):
            box(upper, a, b, (1.0, 0.0, 0.0), 0.034, 0.006, tw, P["accent"], MAT_ACCENT, cap_end=True,
                cap_start=True)
        s0 = len(upper.godot)
        plate(upper, (x * 0.085, 1.252, 0.17), (1.0, 0.0, 0.0), (0.0, 1.0, 0.08), 0.034, 0.026, 0.007, tw, P["metal"])
        K.seat(upper, s0, (0.0, 0.0, 1.0))

    # ================================================================== the trousers: oilskin over the jumper's foot
    tube(lower, [
        ((0.0, 0.86, 0.0), 0.172, 0.128, hp),
        ((0.0, 0.95, 0.0), 0.176, 0.13, hp),
        ((0.0, 1.035, 0.006), 0.176, 0.13, W(hips=0.5, torso=0.5)),
    ], S, (R["oil_top"], MAT_ACCENT), turn=TURN)
    for side, x in (("l", 1.0), ("r", -1.0)):
        rows = [(0.92, 0.1, 0.108, 0.1), (0.75, 0.098, 0.104, 0.105), (0.56, 0.092, 0.098, 0.11),
                (0.45, 0.09, 0.095, 0.113), (0.38, 0.09, 0.094, 0.115), (0.36, 0.091, 0.095, 0.115),
                (0.338, 0.091, 0.095, 0.115), (0.32, 0.092, 0.096, 0.115), (0.298, 0.093, 0.097, 0.115),
                (0.272, 0.099, 0.101, 0.115), (0.27, 0.08, 0.083, 0.115)]
        rings = [((x * cx, y, 0.004), r1, r2, W(**leg_w(side, y))) for (y, r1, r2, cx) in rows]
        oil = (R["oil_leg"], MAT_ACCENT)
        lx, ly, lw, lh = R["oil_leg"]
        bands = [((lx, ly + 20, lw, 12), MAT_ACCENT), ((lx, ly + 12, lw, 8), MAT_ACCENT), ((lx, ly + 7, lw, 5), MAT_ACCENT),
                 ((lx, ly + 5, lw, 2), MAT_ACCENT), (solid("reflect"), MAT_BODY), ((lx, ly + 4, lw, 1), MAT_ACCENT),
                 (solid("reflect"), MAT_BODY), ((lx, ly + 2, lw, 2), MAT_ACCENT), ((lx, ly, lw, 2), MAT_ACCENT),
                 (solid("accent_dark"), MAT_ACCENT)]
        tube(lower, rings, 10, bands)
        # the knee: a round cap of oilskin on the joint, so a bent leg (sitting, crouching) never opens a gap there
        kx = x * 0.111
        knee = [((kx, 0.52 + 0.065 * math.cos(a), 0.004), 0.004 + 0.094 * math.sin(a), 0.004 + 0.1 * math.sin(a),
                 W(**{"shin_" + side: 1.0})) for a in (0.0, 0.5, 1.0, math.pi / 2, math.pi - 1.0, math.pi - 0.5, math.pi)]
        tube(lower, knee, 10, (R["oil_leg"], MAT_ACCENT))
        del oil
        # ============================================================== a sea boot: green rubber on a black sole
        foot = "foot_" + side
        bt = math.pi / 8.0
        tube(lower, [
            ((x * 0.115, 0.0, 0.046), 0.082, 0.158, W(**{foot: 1.0})),
            ((x * 0.115, 0.026, 0.048), 0.088, 0.164, W(**{foot: 1.0})),
            ((x * 0.115, 0.033, 0.046), 0.081, 0.153, W(**{foot: 1.0})),
            ((x * 0.115, 0.09, 0.036), 0.078, 0.13, W(**leg_w(side, 0.09))),
            ((x * 0.115, 0.15, 0.012), 0.072, 0.09, W(**leg_w(side, 0.15))),
            ((x * 0.115, 0.31, 0.0), 0.08, 0.083, W(**{"shin_" + side: 1.0})),
        ], 8, [band("boot", 0, 3), band("boot", 3, 1), band("boot", 4, 6), band("boot", 10, 6), band("boot", 16, 16)],
            cap_bottom=(P["sole"], MAT_BODY), turn=bt)
        # ============================================================== the forearm: the sleeve rolled up, bare skin
        fw = W(**{"fore_" + side: 1.0})
        tube(lower, [
            ((x * 0.245, 0.998, 0.0), 0.064, 0.064, W(**arm_w(side, 0.998))),
            ((x * 0.245, 0.98, 0.0), 0.074, 0.074, fw),
            ((x * 0.245, 0.948, 0.0), 0.073, 0.073, fw),
            ((x * 0.245, 0.932, 0.0), 0.058, 0.058, fw),
        ], 8, (R["roll"], MAT_BODY))
        tube(lower, [
            ((x * 0.245, 0.94, 0.0), 0.047, 0.048, fw),
            ((x * 0.245, 0.87, 0.0), 0.044, 0.045, fw),
            ((x * 0.245, 0.82, 0.0), 0.04, 0.041, fw),
        ], 8, (R["arm"], MAT_BODY))
        glove(gloves, side, x, R["glove"], P["glove"], cuff=(0.05, 0.07, 0.06), finger=(0.02, 0.021),
              palm=(0.088, 0.034))
    return [head, upper, lower, gloves]


def paint(p, c):
    boot_white, house, rubber = p.photo("boot_white"), p.photo("house_white"), p.photo("rubber")
    blanket, leather = p.photo("blanket"), p.photo("leather_brown")
    p.solid_patches(P, {"dark": (0.06, 0.06, 0.055), "skin": SKIN, "nose": (0.93, 0.56, 0.45), "white": (0.95, 0.94, 0.9),
                        "hair": HAIR, "mouth": (0.35, 0.15, 0.13), "knit": NAVY, "knit_dark": K.shade(NAVY, 0.7),
                        "beanie_dark": K.shade(RED, 0.65), "accent": K.ACCENT, "accent_dark": K.shade(K.ACCENT, 0.6),
                        "metal": (0.62, 0.62, 0.58), "sole": (0.05, 0.05, 0.045), "glove": GLOVE, "boot": BOOT,
                        "reflect": (0.92, 0.93, 0.9), "cream": (0.93, 0.89, 0.8), "leather": (0.42, 0.28, 0.16),
                        "fish": (0.62, 0.72, 0.76), "fish_dark": (0.12, 0.32, 0.48)})

    def knit(r, col, seed, rib=2, cable=False):
        """Wool: the blanket photo's weave tinted, a rib every `rib` columns, a cable down the front."""
        x, y, w, h = r
        p.fill(r, blanket, col, 0.85, sat=0.9, punch=0.5, offset=(seed % 17, seed % 7))
        for xx in range(0, w, rib):
            p.rect(x + xx, y, 1, h, K.shade(col, 0.72), 0.55)
        if cable:
            fu = front_u(w)
            for yy in range(h):
                off = int(round(math.sin(yy * 0.9) * 1.2))
                p.rect(x + (fu + off - 2) % w, y + yy, 1, 1, K.shade(col, 1.35), 0.8)
                p.rect(x + (fu - off + 2) % w, y + yy, 1, 1, K.shade(col, 1.35), 0.8)

    def oilskin(r, seed):
        p.fill(r, house, K.ACCENT, 0.88, punch=0.45, offset=(seed % 13, seed % 5))

    # --- the jumper: navy knit, a cable down the front, worn at the waist
    knit(R["jumper"], NAVY, 1, cable=True)
    p.grime((R["jumper"][0], R["jumper"][1], R["jumper"][2], 6), 4, K.GRIME, 0.3, 2)
    knit(R["sleeve"], NAVY, 3)
    sx, sy, sw, sh = R["roll"]
    knit(R["roll"], K.shade(NAVY, 0.85), 4, rib=3)
    for yy in (1, 4, 6):
        p.rect(sx, sy + yy, sw, 1, K.shade(NAVY, 0.55), 0.7)          # the roll's folds
    knit(R["collar"], NAVY, 5)
    cx, cy, cw, ch = R["collar"]
    p.rect(cx, cy + 4, cw, 1, K.shade(NAVY, 0.55), 0.7)

    # --- the forearms: skin, a few freckles, an anchor inked on the front
    ax, ay, aw, ah = R["arm"]
    p.fill(R["arm"], boot_white, SKIN, 0.95, punch=0.2)
    p.speckle(R["arm"], 0.05, K.shade(SKIN, 0.75), 0.6, 7)
    fu = front_u(aw, turn=0.0, sides=8)
    ink = (0.18, 0.24, 0.4)
    for (dx, dy) in ((0, 6), (0, 5), (0, 4), (0, 3), (0, 2), (-1, 5), (1, 5), (-2, 2), (2, 2), (-1, 1), (1, 1)):
        p.rect(ax + (fu + dx) % aw, ay + dy, 1, 1, ink, 0.8)

    # --- the face: skin; rosy cheeks either side of the front; a young man's scruff on the jaw
    fx, fy, fw, fh = R["face"]
    p.fill(R["face"], boot_white, SKIN, 0.96, punch=0.15)
    fu = front_u(fw)
    for dx in (-5, -4, 4, 5):
        for dy in (14, 15):
            p.rect(fx + (fu + dx) % fw, fy + dy, 1, 1, (0.95, 0.5, 0.42), 0.5)
    for dx in range(-9, 10):
        for dy in range(2, 13):
            if abs(dx) > 7 and dy > 8:
                continue
            p.rect(fx + (fu + dx) % fw, fy + dy, 1, 1, K.shade(SKIN, 0.86), 0.45)
            if dy > 4 and (dx * 7 + dy * 13) % 4 == 0:
                p.rect(fx + (fu + dx) % fw, fy + dy, 1, 1, (0.4, 0.29, 0.24), 0.35)

    # --- the eye: white, a dark pupil looking a touch to one side, a glint, the lid's line
    ex, ey, ew, eh = R["eye"]
    p.rect(ex, ey, ew, eh, (0.09, 0.06, 0.05))                    # a dark eye (the disc is its oval)
    p.rect(ex + 1, ey + 1, ew - 2, eh - 2, (0.16, 0.1, 0.07))
    p.rect(ex + 4, ey + 3, 1, 1, (1.0, 1.0, 0.97))                # its glint
    p.rect(ex, ey + 4, ew, 4, SKIN)                               # a heavy lid, half shut: deadpan
    p.rect(ex, ey + 4, ew, 1, K.shade(SKIN, 0.55))

    # --- the beanie: red knit, ribbed; the brim's folds; the tag
    knit(R["beanie"], RED, 8)
    bx, by, bw, bh = R["brim"]
    knit(R["brim"], K.shade(RED, 0.95), 9)
    p.rect(bx, by + bh // 2, bw, 1, K.shade(RED, 0.6), 0.7)
    tx, ty, tw_, th = R["tag"]
    p.fill(R["tag"], leather, (0.42, 0.28, 0.16), 0.7)
    p.rect(tx + 2, ty + 3, 4, 1, (0.9, 0.85, 0.7))

    # --- the oilskin (painted near white: the player's colour tints it): seams, a stitched bib, a pocket, grime low
    # down, the catch's blood down the front
    for k, r in enumerate((R["bib"], R["pocket"], R["oil_top"], R["oil_leg"])):
        oilskin(r, 11 + k)
    bx, by, bw, bh = R["bib"]
    for xx in range(0, bw, 2):
        p.rect(bx + xx, by + 1, 1, 1, K.shade(K.ACCENT, 0.62))
        p.rect(bx + xx, by + bh - 2, 1, 1, K.shade(K.ACCENT, 0.62))
    for yy in range(0, bh, 2):
        p.rect(bx + 1, by + yy, 1, 1, K.shade(K.ACCENT, 0.62))
        p.rect(bx + bw - 2, by + yy, 1, 1, K.shade(K.ACCENT, 0.62))
    p.splats(R["bib"], 2, K.BLOOD, 4, 0.5, 21)
    qx, qy, qw, qh = R["pocket"]
    p.rect(qx, qy + qh - 3, qw, 1, K.shade(K.ACCENT, 0.55))
    p.rect(qx, qy, qw, 1, K.shade(K.ACCENT, 0.7))
    ox, oy, ow, oh = R["oil_top"]
    for su in (front_u(ow) - ow // 4, front_u(ow) + ow // 4):
        p.rect(ox + su % ow, oy, 1, oh, K.shade(K.ACCENT, 0.66), 0.7)
    lx, ly, lw, lh = R["oil_leg"]
    for su in (lw // 4, 3 * lw // 4):
        p.rect(lx + su, ly, 1, lh, K.shade(K.ACCENT, 0.66), 0.7)
    p.grime(R["oil_leg"], 10, K.GRIME, 0.45, 31)
    p.splats(R["oil_leg"], 2, K.BLOOD, 4, 0.45, 32, rows=(14, 28))
    for i in range(3):
        p.rect(lx, ly + 2 + i, lw, 1, K.SALT, 0.12 + 0.05 * i)

    # --- the boots: a black sole, green rubber, mud up from the sole
    ox, oy, ow, oh = R["boot"]
    p.rect(ox, oy, ow, 4, (0.05, 0.05, 0.045))
    p.rect(ox, oy + 3, ow, 1, (0.14, 0.13, 0.12))
    p.fill((ox, oy + 4, ow, oh - 4), rubber, BOOT, 0.85, punch=0.4)
    p.grime((ox, oy + 3, ow, 18), 9, K.MUD, 0.6, 41)

    # --- the gloves: orange rubber
    p.fill(R["glove"], boot_white, GLOVE, 0.88, punch=0.3)
    p.mottle([R["eye"], R["tag"]], seed=101, amount=0.3)


# ------------------------------------------------------------------ the faces
def faces_strip():
    """The expressions, CELL px each, side by side (y up, as Blender stores pixels), transparent but for the face:
    eyes, brows, mouth, now and then blush, a tear, a drop of sweat. Pixel art, in the atlas's dark ink."""
    import numpy as np
    n = len(FACES)
    img = np.zeros((CELL, CELL * n, 4), np.float32)
    INK, WHITE, BROW = (0.1, 0.07, 0.06), (0.97, 0.96, 0.92), HAIR
    MOUTH, TONGUE, BLUSH = (0.35, 0.1, 0.09), (0.85, 0.38, 0.38), (0.95, 0.5, 0.45)
    SWEAT = (0.6, 0.85, 0.98)

    def px(c, x, y, col):
        if 0 <= x < CELL and 0 <= y < CELL:
            img[y, c * CELL + x] = (*col, 1.0)

    def rect(c, x0, y0, w, h, col):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                px(c, x, y, col)

    def oval(c, cx, cy, rx, ry, col):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0:
                    px(c, x, y, col)

    def line(c, pts, col, th=2):
        for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
            steps = max(abs(x1 - x0), abs(y1 - y0), 1)
            for k in range(steps + 1):
                x = round(x0 + (x1 - x0) * k / steps)
                y = round(y0 + (y1 - y0) * k / steps)
                rect(c, x - th // 2, y - th // 2, th, th, col)

    L, R2 = 18, 46          # the eyes' columns (as you look at him), their row, the brows', the mouth's
    EY, BY, MY = 37, 44, 13

    def eyes(c, glint=True, rx=3, ry=4):
        for x in (L, R2):
            oval(c, x, EY, rx, ry, INK)
            if glint:
                rect(c, x, EY + 1, 2, 2, WHITE)

    def brows(c, left_tilt=0, right_tilt=0, lift=0):
        line(c, [(L - 7, BY + lift - left_tilt), (L + 5, BY + lift + left_tilt)], BROW, 4)
        line(c, [(R2 - 5, BY + lift + right_tilt), (R2 + 7, BY + lift - right_tilt)], BROW, 4)

    def blush(c):
        for x0 in (L - 8, R2 + 2):
            for y in range(26, 30):
                for x in range(x0, x0 + 7):
                    if (x + y) % 2 == 0:
                        px(c, x, y, BLUSH)

    def sweat(c):
        oval(c, R2 + 11, 44, 2, 3, SWEAT)
        px(c, R2 + 11, 48, SWEAT)

    i = FACES.index
    # neutral: relaxed, the corner of the mouth up a touch
    eyes(i("neutral"))
    brows(i("neutral"))
    line(i("neutral"), [(26, MY), (36, MY), (40, MY + 2)], INK)
    # blink: the same, eyes shut
    for x in (L, R2):
        line(i("blink"), [(x - 4, EY), (x + 4, EY)], INK)
    brows(i("blink"))
    line(i("blink"), [(26, MY), (36, MY), (40, MY + 2)], INK)
    # happy: eyes squeezed into arcs, a big open grin, blushing
    c = i("happy")
    for x in (L, R2):
        line(c, [(x - 4, EY - 2), (x, EY + 2), (x + 4, EY - 2)], INK)
    brows(c, lift=3)
    oval(c, 32, MY, 9, 5, MOUTH)
    rect(c, 23, MY, 19, 6, (0, 0, 0))
    img[MY:MY + 6, c * CELL + 23:c * CELL + 42, 3] = 0.0
    rect(c, 25, MY + 1, 15, 2, WHITE)
    oval(c, 32, MY - 3, 4, 2, TONGUE)
    blush(c)
    # shocked: big white eyes, pinprick pupils, brows way up, an O of a mouth
    c = i("shocked")
    for x in (L, R2):
        oval(c, x, EY, 6, 6, INK)
        oval(c, x, EY, 5, 5, WHITE)
        rect(c, x - 1, EY - 1, 2, 2, INK)
    brows(c, 1, 1, lift=7)
    oval(c, 32, MY, 4, 5, INK)
    oval(c, 32, MY, 2, 3, MOUTH)
    # strain: eyes screwed shut (> <), brows down hard, teeth gritted, a drop of sweat
    c = i("strain")
    line(c, [(L - 4, EY + 3), (L + 3, EY), (L - 4, EY - 3)], INK)
    line(c, [(R2 + 4, EY + 3), (R2 - 3, EY), (R2 + 4, EY - 3)], INK)
    brows(c, -3, -3, lift=-1)
    rect(c, 22, MY - 3, 20, 7, INK)
    rect(c, 23, MY - 2, 18, 5, WHITE)
    rect(c, 23, MY, 18, 1, INK)
    for x in (27, 32, 37):
        rect(c, x, MY - 2, 1, 5, INK)
    sweat(c)
    # tired: lids half down, brows sagging out, a wobbly mouth, sweat
    c = i("tired")
    for x in (L, R2):
        oval(c, x, EY - 1, 3, 3, INK)
        rect(c, x - 4, EY, 9, 4, (0, 0, 0))
        img[EY:EY + 4, c * CELL + x - 4:c * CELL + x + 5, 3] = 0.0
        line(c, [(x - 4, EY), (x + 4, EY)], INK)
    brows(c, 2, 2, lift=-2)
    line(c, [(25, MY), (29, MY + 2), (33, MY), (37, MY + 2), (40, MY)], INK)
    sweat(c)
    # angry: brows in a hard V, eyes cut flat on top, a frown
    c = i("angry")
    eyes(c, glint=True)
    for x in (L, R2):
        rect(c, x - 4, EY + 2, 9, 4, (0, 0, 0))
        img[EY + 2:EY + 6, c * CELL + x - 4:c * CELL + x + 5, 3] = 0.0
    brows(c, -4, -4, lift=-2)
    line(c, [(24, MY - 2), (28, MY + 1), (36, MY + 1), (40, MY - 2)], INK)
    # dizzy: X eyes, brows all over, a wobbly open mouth
    c = i("dizzy")
    for x in (L, R2):
        line(c, [(x - 4, EY - 4), (x + 4, EY + 4)], INK)
        line(c, [(x - 4, EY + 4), (x + 4, EY - 4)], INK)
    brows(c, 3, -3, lift=2)
    oval(c, 32, MY, 6, 3, INK)
    oval(c, 33, MY - 1, 3, 1, TONGUE)
    # smug: one lid down, that brow flat, the other way up, the mouth up at one corner
    c = i("smug")
    oval(c, L, EY - 1, 3, 3, INK)
    rect(c, L - 4, EY, 9, 4, (0, 0, 0))
    img[EY:EY + 4, c * CELL + L - 4:c * CELL + L + 5, 3] = 0.0
    line(c, [(L - 4, EY), (L + 4, EY)], INK)
    oval(c, R2, EY, 3, 4, INK)
    rect(c, R2, EY + 1, 2, 2, WHITE)
    brows(c, 0, -2, lift=0)
    line(c, [(R2 - 5, BY + 6), (R2 + 6, BY + 3)], BROW, 3)
    line(c, [(26, MY - 1), (34, MY), (40, MY + 4)], INK)
    # sad: brows up in the middle, glossy eyes, a tear, a little frown
    c = i("sad")
    eyes(c, glint=True, rx=3, ry=4)
    for x in (L, R2):
        rect(c, x - 2, EY - 2, 2, 2, WHITE)
    brows(c, 3, 3, lift=1)
    oval(c, L - 1, EY - 9, 1, 2, SWEAT)
    line(c, [(27, MY - 1), (30, MY + 1), (35, MY + 1), (38, MY - 1)], INK)
    tex = bpy.data.images.new("faces", CELL * n, CELL, alpha=True)
    tex.pixels.foreach_set(img.ravel())
    tex.pack()
    return tex


def face_material():
    """The face layer's material: the expressions strip, crisp pixels, see-through but for the face (alpha clip)."""
    m = bpy.data.materials.new("face")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = faces_strip()
    t.interpolation = "Closest"
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = 0.8
    m.blend_method = "CLIP"
    m.alpha_threshold = 0.5
    return m


# ------------------------------------------------------------------ cut into Bluefin's ten pieces
PIECE = {"hips": "torso", "torso": "torso", "head": "head"}
for _s in ("l", "r"):
    PIECE.update({"arm_" + _s: "arm_" + _s, "fore_" + _s: "fore_" + _s, "thigh_" + _s: "leg_" + _s,
                  "shin_" + _s: "shin_" + _s, "foot_" + _s: "shin_" + _s})
    for _h in K.HAND:
        PIECE[_h + "_" + _s] = "fore_" + _s
JOINT = {"torso": "hips", "head": "head", "arm_l": "arm_l", "arm_r": "arm_r", "fore_l": "fore_l", "fore_r": "fore_r",
         "leg_l": "thigh_l", "leg_r": "thigh_r", "shin_l": "shin_l", "shin_r": "shin_r"}


def cut():
    """The four skinned meshes into ten rigid pieces by bone (each face to the bone most of its weight is on), turned
    to face Blender +Y (Godot -Z, Bluefin's crew), each piece's origin on its joint."""
    import bmesh
    from mathutils import Matrix, Vector
    rest = {name: head for name, _, head in K.BONES}
    meshes = [bpy.data.objects[n] for n in ("Crew_Head", "Crew_Upper", "Crew_Lower", "Crew_Gloves")]
    for ob in meshes:
        for m in list(ob.modifiers):
            ob.modifiers.remove(m)
        ob.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for ob in meshes:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    whole = bpy.context.view_layer.objects.active
    names = {g.index: g.name for g in whole.vertex_groups}
    me = whole.data
    turn = Matrix.Rotation(math.pi, 4, "Z")
    me.transform(turn)
    owner = []
    for poly in me.polygons:
        tot = {}
        for vi in poly.vertices:
            for g in me.vertices[vi].groups:
                b = names[g.group]
                tot[b] = tot.get(b, 0.0) + g.weight
        owner.append(PIECE[max(tot, key=tot.get)] if tot else "torso")
    out = []
    for piece in sorted(set(owner)):
        pme = me.copy()
        ob = bpy.data.objects.new(piece, pme)
        bpy.context.scene.collection.objects.link(ob)
        bm = bmesh.new()
        bm.from_mesh(pme)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if owner[f.index] != piece], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(pme)
        bm.free()
        ob.vertex_groups.clear()
        g = rest[JOINT[piece]]
        origin = turn @ Vector(K.to_blender(g))
        pme.transform(Matrix.Translation(-origin))
        ob.location = origin
        out.append(ob)
    bpy.data.objects.remove(whole, do_unlink=True)
    for ob in list(bpy.data.objects):
        if ob.type == "ARMATURE":
            bpy.data.objects.remove(ob, do_unlink=True)
    acc = bpy.data.materials.get("crew_accent")
    if acc:
        acc.name = "oilskin"
    visor = bpy.data.materials.get("Visor")
    face = face_material()
    rx, ry, rw, rh = R["face_fx"]
    for ob in out:
        me = ob.data
        for k, m in enumerate(me.materials):
            if m is not visor:
                continue
            me.materials[k] = face
            uv = me.uv_layers.active
            for poly in me.polygons:
                if poly.material_index != k:
                    continue
                for li in poly.loop_indices:
                    u, v = uv.data[li].uv
                    uv.data[li].uv = ((u * K.TEX - rx) / rw / len(FACES), (v * K.TEX - ry) / rh)
    print("[%s] cut into %s" % (SID, ", ".join("%s %d" % (o.name, len(o.data.polygons)) for o in out)))
    return out


def renders(objs, folder):
    """The cut pieces under soft light, the oilskin tinted yellow as in game: the whole man and the face."""
    from mathutils import Vector as V
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = sc.render.resolution_y = 900
    sc.view_settings.view_transform = "Standard"
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.68, 0.76, 1)
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    oil = bpy.data.materials["oilskin"]
    nt = oil.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    src = bsdf.inputs["Base Color"].links[0].from_socket
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs[0].default_value = 1.0
    nt.links.new(src, tint.inputs[6])
    tint.inputs[7].default_value = (1.0, 0.8, 0.14, 1.0)
    nt.links.new(tint.outputs[2], bsdf.inputs["Base Color"])
    for nm, e, col, r in (("key", 3.0, (1, 0.95, 0.88), (50, 0, 150)), ("fill", 1.0, (0.75, 0.8, 1), (60, 0, -30))):
        L = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN"))
        L.data.energy, L.data.color = e, col
        L.rotation_euler = [math.radians(a) for a in r]
        sc.collection.objects.link(L)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    os.makedirs(folder, exist_ok=True)
    for name, loc, tgt, lens in (("fisherman_body", (-1.3, 3.3, 1.05), (0, 0, 0.95), 50),
                                 ("fisherman_face", (-0.4, 1.0, 1.66), (0, 0, 1.64), 70),
                                 ("fisherman_back", (1.3, -3.3, 1.05), (0, 0, 0.95), 50)):
        cam.location = loc
        cam.rotation_euler = (V(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        sc.render.filepath = os.path.join(folder, name + ".png")
        bpy.ops.render.render(write_still=True)
    # each expression, the strip slid along as the game does (fisherman_face_<name>.png)
    fm = bpy.data.materials["face"].node_tree
    tex = [n for n in fm.nodes if n.type == "TEX_IMAGE"][0]
    mp = fm.nodes.new("ShaderNodeMapping")
    uvn = fm.nodes.new("ShaderNodeTexCoord")
    fm.links.new(uvn.outputs["UV"], mp.inputs["Vector"])
    fm.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
    cam.location, cam.data.lens = (0.0, 0.75, 1.64), 85
    cam.rotation_euler = (V((0, 0, 1.63)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    for k, name in enumerate(FACES):
        mp.inputs["Location"].default_value[0] = k / len(FACES)
        sc.render.filepath = os.path.join(folder, "fisherman_face_%s.png" % name)
        bpy.ops.render.render(write_still=True)
    fm.nodes.remove(mp)
    fm.nodes.remove(uvn)
    nt.nodes.remove(tint)
    nt.links.new(src, bsdf.inputs["Base Color"])


K.build(SID, parts, paint, {"issue": None}, ao=0.05)
_args = K._args()
pieces = cut()
if "--preview" in _args:
    renders(pieces, _args[_args.index("--preview") + 1])
if "--game" in _args:
    bpy.ops.object.select_all(action="DESELECT")
    for o in pieces:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=GAME_GLB, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_vertex_color="ACTIVE",
                              export_animations=False, export_skins=False)
    print("[%s] wrote %s" % (SID, GAME_GLB))
