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
}
K.check_regions(R)
P = K.patches(["dark", "skin", "nose", "white", "hair", "mouth", "knit", "knit_dark", "beanie_dark", "accent",
               "accent_dark", "metal", "sole", "glove", "boot", "reflect", "cream", "leather"])

S = 12
TURN = math.pi / S
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
        ((0.0, 1.47, 0.02), 0.055, 0.055, W(torso=0.5, head=0.5)),
        ((0.0, 1.515, 0.025), 0.058, 0.06, hw),
        ((0.0, 1.552, 0.042), 0.09, 0.095, hw),                # under the jaw
        ((0.0, 1.58, 0.046), 0.108, 0.114, hw),                # the jaw and the mouth
        ((0.0, 1.612, 0.042), 0.114, 0.12, hw),                # the cheeks
        ((0.0, 1.66, 0.036), 0.117, 0.121, hw),                # the eyes
        ((0.0, 1.70, 0.03), 0.115, 0.119, hw),                 # the brow
        ((0.0, 1.735, 0.026), 0.106, 0.11, hw),
    ], S, (R["face"], MAT_BODY), cap_top=(P["skin"], MAT_BODY), turn=TURN)
    # the face, kept small and simple: two dark oval eyes with a glint, thin brows, a soft little nose, a small smile
    def face_at(x, y, lift):
        return K.on_surface(head, (x, y, 0.3), (0.0, 0.0, -1.0), lift)

    for x in (1.0, -1.0):
        c = face_at(x * 0.04, 1.652, 0.0015)
        K.disc(head, c, (x * 0.3, 0.0, 1.0), (0.0, 1.0, 0.0), 0.0105, 10, R["eye"], MAT_BODY, hw, ry=0.0145)
        # the brows: thin, close over the eyes, the left one cocked up a touch
        up = 0.004 if x > 0 else 0.0
        a, b = face_at(x * 0.023, 1.677 + up * 0.3, 0.003), face_at(x * 0.056, 1.679 + up, 0.003)
        box(head, a, b, (0.0, 1.0, 0.0), 0.006, 0.005, hw, P["hair"], cap_end=True, cap_start=True)
    nose = [face_at(0.0, 1.642, 0.004), face_at(0.0, 1.626, 0.016)]
    pipe(head, nose, 0.011, 6, hw, P["nose"], caps=True)
    for x in (1.0, -1.0):
        # the ears; sideburns down from under the beanie
        s0 = len(head.godot)
        plate(head, (x * 0.118, 1.637, 0.03), (0.0, 0.0, -x), (0.0, 1.0, 0.0), 0.036, 0.056, 0.02, hw, P["skin"])
        K.seat(head, s0, (x, 0.0, 0.0), sink=0.004)
        s0 = len(head.godot)
        plate(head, (x * 0.112, 1.677, 0.075), (0.0, 0.0, -x), (0.0, 1.0, 0.0), 0.024, 0.042, 0.006, hw, P["hair"])
        K.seat(head, s0, (x, 0.0, 0.0))
    # the mouth: a small smile, a touch higher on one side
    smile = [face_at(-0.019, 1.6, 0.002), face_at(-0.004, 1.594, 0.002), face_at(0.01, 1.595, 0.002),
             face_at(0.022, 1.602, 0.002)]
    for a, b in zip(smile[:-1], smile[1:]):
        box(head, a, b, (0.0, 1.0, 0.0), 0.005, 0.004, hw, P["mouth"], cap_end=True, cap_start=True)
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

    # ================================================================== the jumper: navy knit, a roll neck
    tube(upper, [
        ((0.0, 0.95, 0.0), 0.165, 0.12, W(hips=0.5, torso=0.5)),
        ((0.0, 1.02, 0.005), 0.168, 0.122, tw),
        ((0.0, 1.12, 0.012), 0.18, 0.13, tw),
        ((0.0, 1.22, 0.014), 0.192, 0.136, tw),
        ((0.0, 1.3, 0.012), 0.2, 0.138, tw),
        ((0.0, 1.37, 0.006), 0.19, 0.132, tw),
        ((0.0, 1.42, 0.004), 0.15, 0.12, tw),
        ((0.0, 1.445, 0.006), 0.1, 0.095, tw),
    ], S, (R["jumper"], MAT_BODY), turn=TURN)
    tube(upper, [
        ((0.0, 1.43, 0.006), 0.098, 0.093, tw),
        ((0.0, 1.448, 0.008), 0.106, 0.1, tw),
        ((0.0, 1.49, 0.012), 0.088, 0.085, W(torso=0.6, head=0.4)),
        ((0.0, 1.502, 0.012), 0.072, 0.07, W(torso=0.5, head=0.5)),
    ], S, (R["collar"], MAT_BODY), turn=TURN)
    for side, x in (("l", 1.0), ("r", -1.0)):
        arm = "arm_" + side
        tube(upper, [
            ((x * 0.245, 1.0, 0.0), 0.06, 0.06, W(**arm_w(side, 1.0))),
            ((x * 0.245, 1.06, 0.0), 0.064, 0.064, W(**{arm: 1.0})),
            ((x * 0.243, 1.2, 0.0), 0.068, 0.068, W(**{arm: 1.0})),
            ((x * 0.238, 1.3, 0.0), 0.074, 0.074, W(**{arm: 1.0})),
            ((x * 0.232, 1.37, 0.0), 0.075, 0.075, W(**arm_w(side, 1.37))),
        ], 8, (R["sleeve"], MAT_BODY), cap_top=(P["knit"], MAT_BODY))

    # ================================================================== the bib and braces (the player's colour)
    K.slab(upper, (0.0, 1.13, 0.16), (1.0, 0.0, 0.0), (0.0, 1.0, 0.08), 0.24, 0.26, 0.008, tw, P["accent"],
           mat=MAT_ACCENT, front=R["bib"], segs=(4, 4))
    K.slab(upper, (0.0, 1.15, 0.17), (1.0, 0.0, 0.0), (0.0, 1.0, 0.08), 0.12, 0.08, 0.006, tw, P["accent"],
           mat=MAT_ACCENT, front=R["pocket"], segs=(2, 1))
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
                        "reflect": (0.92, 0.93, 0.9), "cream": (0.93, 0.89, 0.8), "leather": (0.42, 0.28, 0.16)})

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
    for dx in range(-6, 7):
        for dy in range(6, 11):
            if (dx * 7 + dy * 13) % 3 == 0:
                p.rect(fx + (fu + dx) % fw, fy + dy, 1, 1, K.shade(SKIN, 0.68), 0.55)

    # --- the eye: white, a dark pupil looking a touch to one side, a glint, the lid's line
    ex, ey, ew, eh = R["eye"]
    p.rect(ex, ey, ew, eh, (0.09, 0.06, 0.05))                    # a dark eye (the disc is its oval)
    p.rect(ex + 1, ey + 1, ew - 2, eh - 2, (0.16, 0.1, 0.07))
    p.rect(ex + 4, ey + 5, 2, 2, (1.0, 1.0, 0.97))                # its glint
    p.rect(ex + 3, ey + 2, 1, 1, (0.55, 0.45, 0.4))

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
