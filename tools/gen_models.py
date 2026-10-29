"""Generates the game's characters (and the bluefin) with Meshy's API, from the art direction in
docs/ART_REFERENCE.md: stylized realism (a believable human with real anatomy, but clean, smooth, slightly plastic
surfaces and painted colour; not a cartoon).

For each model: text-to-3D preview (the shape) -> refine (the paint) -> for people, auto-rigging (a skeleton,
plus walking and running clips). Everything lands in art/generated/<name>/ (the GLBs and a thumbnail), and the
task ids are kept in art/generated/state.json, so a run can stop and pick up where it left off without paying
twice.

Needs a Meshy API key in the environment: MESHY_API_KEY (never pass it on the command line or commit it).

Run:  python tools/gen_models.py              (everything not yet done)
      python tools/gen_models.py crew_yellow  (one)
      python tools/gen_models.py --dry        (print what would be sent, no key needed)"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "art", "generated")
STATE = os.path.join(OUT, "state.json")
API = "https://api.meshy.ai"

STYLE = ("Stylized realism, like a high-end animated adventure game: a believable adult human with real anatomy and "
         "proportions, only slightly exaggerated, with clean smooth sculpted forms and crisp planes on the face and "
         "body. Not a cartoon, not chibi, no oversized head. Standing in an A-pose, facing forward, full body, feet "
         "flat. ")
PAINT = ("Hand-painted look: soft painted light and shadow following the forms, cool purple-grey in the "
         "shadows, warm ruddy skin, clean smooth surfaces with a slight sheen, no photographic noise or pores. "
         "Lived-in wear: scuffs on the boots, a few fish-blood smudges and salt marks on the oilskins. ")

# The crew: one person per crew slot, each in their own oilskins (crew/player.gd's OILSKINS order: yellow, orange,
# green, red), different bodies and faces, comically different from each other but all believable.
MODELS = {
    "crew_yellow": dict(rig=True, height=1.8, prompt=STYLE + (
        "A weathered stocky fisherman in his fifties with a barrel chest and a round belly. Long face, heavy "
        "brow, big broken nose, short grey-brown scruffy beard. Bright yellow oilskin bib-and-brace fishing "
        "trousers with braces over a navy wool fisherman's jumper with the sleeves pushed up, a red knit watch "
        "cap, orange rubber gloves, dark green rubber deck boots, a knife on his belt."),
        texture=PAINT + "Bright yellow oilskins, navy jumper, red knit cap, orange gloves, dark green boots."),
    "crew_orange": dict(rig=True, height=1.92, prompt=STYLE + (
        "A tall, lanky, wiry young deckhand with long arms and big hands, a long narrow face, a hooked nose, a "
        "thin moustache, messy dark hair under a sou'wester rain hat. Orange oilskin jacket open over a grey "
        "hoodie, orange oilskin bib trousers, yellow rubber gloves tucked in the jacket pocket, white rubber "
        "deck boots."),
        texture=PAINT + "Orange oilskins and sou'wester, grey hoodie, white boots, yellow gloves."),
    "crew_green": dict(rig=True, height=1.84, prompt=STYLE + (
        "A broad, muscular fisherman with huge forearms covered in faded sailor tattoos, a shaved head, a square "
        "stubbled jaw and a flat nose. Green oilskin bib-and-brace trousers over a white vest, a towel around "
        "his neck, blue rubber gloves, black rubber deck boots."),
        texture=PAINT + "Green oilskins, white vest, faded blue-black tattoos on the forearms, blue gloves, black "
                        "boots."),
    "crew_red": dict(rig=True, height=1.64, prompt=STYLE + (
        "A short, sturdy woman in her forties, a fisher, with a round freckled face, rosy cheeks, an upturned "
        "nose and ginger hair in a messy bun under a backwards navy baseball cap. Red oilskin bib-and-brace "
        "trousers over a cream cable-knit jumper, orange rubber gloves, white rubber deck boots."),
        texture=PAINT + "Red oilskins, cream jumper, navy cap, ginger hair, orange gloves, white boots."),
    # the fish: a beautiful, real Atlantic bluefin, painted, only a touch exaggerated (no rig: it swims by shader)
    "bluefin": dict(rig=False, prompt=(
        "A single Atlantic bluefin tuna, side on, mouth closed, in a stylized-realistic game style: the real "
        "torpedo shape, the crescent tail, the row of small yellow finlets behind the dorsal and anal fins, the "
        "pectoral fins short. Clean smooth sculpted forms, slightly exaggerated, not a cartoon."),
        texture=("Hand-painted: a deep metallic navy-blue back fading to a bright silver belly, faint silver "
                 "vertical bars on the flanks, yellow finlets edged black, a dark glossy eye with a bright "
                 "highlight, a soft painted sheen."), polycount=12000),
}


def key():
    k = os.environ.get("MESHY_API_KEY", "").strip()
    if not k and os.name == "nt":
        # (set with setx after this shell started: read it from the user's environment directly)
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as reg:
                k = str(winreg.QueryValueEx(reg, "MESHY_API_KEY")[0]).strip()
        except OSError:
            k = ""
    if not k:
        sys.exit("Set MESHY_API_KEY in your environment first (Meshy dashboard, API keys).")
    return k


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        sys.exit("Meshy %s %s: HTTP %d %s" % (method, path, e.code, e.read().decode()[:400]))


def wait(path, task):
    while True:
        t = call("GET", "%s/%s" % (path, task))
        print("   %s %s %s%%" % (path.rsplit("/", 1)[-1], t.get("status"), t.get("progress")), flush=True)
        if t.get("status") == "SUCCEEDED":
            return t
        if t.get("status") in ("FAILED", "CANCELED"):
            sys.exit("   failed: %s" % t.get("task_error"))
        time.sleep(15)


def fetch(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as r, open(path, "wb") as f:
        f.write(r.read())
    print("   saved", os.path.relpath(path, ROOT))


def load_state():
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}


def save_state(st):
    os.makedirs(OUT, exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(st, f, indent=1)


def make(name, spec, st, dry):
    s = st.setdefault(name, {})
    preview = dict(mode="preview", prompt=spec["prompt"][:800], ai_model="latest", should_remesh=True,
                   topology="quad", target_polycount=spec.get("polycount", 24000))
    if spec["rig"]:
        preview["pose_mode"] = "a-pose"
    refine = dict(mode="refine", enable_pbr=True, texture_prompt=spec["texture"][:800])
    if dry:
        print(name, json.dumps(preview, indent=1), json.dumps(refine, indent=1), sep="\n")
        return
    d = os.path.join(OUT, name)
    print(name)
    if "preview" not in s:
        s["preview"] = call("POST", "/openapi/v2/text-to-3d", preview)["result"]
        save_state(st)
    wait("/openapi/v2/text-to-3d", s["preview"])
    if "refine" not in s:
        refine["preview_task_id"] = s["preview"]
        s["refine"] = call("POST", "/openapi/v2/text-to-3d", refine)["result"]
        save_state(st)
    t = wait("/openapi/v2/text-to-3d", s["refine"])
    fetch(t["model_urls"]["glb"], os.path.join(d, name + ".glb"))
    if t.get("thumbnail_url"):
        fetch(t["thumbnail_url"], os.path.join(d, "thumb.png"))
    if spec["rig"]:
        if "rig" not in s:
            s["rig"] = call("POST", "/openapi/v1/rigging",
                            dict(input_task_id=s["refine"], height_meters=spec["height"]))["result"]
            save_state(st)
        r = wait("/openapi/v1/rigging", s["rig"])["result"]
        fetch(r["rigged_character_glb_url"], os.path.join(d, name + "_rigged.glb"))
        anims = r.get("basic_animations") or {}
        for clip in ("walking", "running"):
            if anims.get(clip + "_glb_url"):
                fetch(anims[clip + "_glb_url"], os.path.join(d, "%s_%s.glb" % (name, clip)))
    s["done"] = True
    save_state(st)


def main():
    dry = "--dry" in sys.argv
    names = [a for a in sys.argv[1:] if not a.startswith("--")] or list(MODELS)
    st = load_state()
    for n in names:
        if n not in MODELS:
            sys.exit("unknown model %s (have: %s)" % (n, ", ".join(MODELS)))
        if st.get(n, {}).get("done") and not dry:
            print(n, "already done")
            continue
        make(n, MODELS[n], st, dry)


if __name__ == "__main__":
    main()
