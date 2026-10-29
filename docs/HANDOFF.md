# Handoff: Bluefin, from the cloud session to a local one

Read this first, then `docs/ART_REFERENCE.md` (what the art should look like), `docs/VISION.md` (the user's words on what the game is), `docs/FEATURES.md` (every
feature in player terms, and what the player must be taught), `docs/TODO.md` (the plan), and
`docs/WHILE_YOU_WERE_AWAY.md` (a newest-first log of every change).

## Where things are

- Repo `kortev/gull-harbor`, branch **`claude/zealous-mendel-h2udij`** (not merged to `main`; no PR open).
- Godot **4.7**, GDScript, Forward+. The main scene is `sea/sea.tscn` (`sea/sea.gd` builds everything).
- **Almost nothing since the moving-boat work has been run in Godot.** The cloud session couldn't download Godot.
  The only checks were: a GDScript syntax parser (gdtoolkit's `gdparse`), Python copies of the fight for balance,
  four independent code reviews (all findings fixed), and Blender renders of the models. **First job in a local
  session: open the project, let it import, run every test, play a trip, and fix what's broken.**
- The user has played older builds. They caught a fish once, then found the end of the fight confusing (now
  explained on screen), saw no birds (they were sub-pixel far off: fixed), and kept running over schools (now a
  warning, and a tip).

### Tests (headless): `godot --headless --path . res://tests/<name>.tscn`

`fight_test`, `strike_test`, `rods_test`, `landing_test`, `wait_test` (chum, baits, jig, the quota), `sail_test`
(the moving boat), `helm_test`, `deck_test`, `hull_test`, `look_test`, `weather_test`, `code_test`,
`steam_test` (+ `tools/steam_test.sh`), and `tools/net_test.sh` (two instances over ENet). Each prints PASSED or
FAILED lines. Tests use their own save (`user://bluefin_test.cfg`), never the player's.

## The user (how to work with them)

- Their friend Jack is the first co-player. They'll test when there's a new version: **commit and push
  continuously, and say plainly what changed and what to try.** They're often away (studying); they may answer
  questions but don't want to be asked much.
- Commit messages end with the `Co-Authored-By` and `Claude-Session` lines. Never push to `main` without asking;
  no PRs unless asked.
- **Their rules (decided, don't relitigate):**
  - Realistic tuna fishing; no nerfs for fishing alone; **no numbers that change with crew size**. Solo must be
    possible and fun but harder than with friends; the difference comes from boats and money.
  - Tired arms only slow your reeling. No lockout.
  - A fixed world, the boat moves through it. Birds anywhere (no fishing grounds for now).
  - No autopilot. A CPU crew member would be a hired person (a deckhand on a share), not a bot.
  - Finding the tuna should take a while and be its own mission; fights can be long (even longer), as long as
    they're fun while they last. It's about being fun moment to moment (Sea of Thieves sailing), not shorter.
  - **A friendslop game, very funny** (Lethal Company's quota, a GTA heist's crew). Teaching is **shown, not
    read** (Dale from the bank on the radio, the owner's manual). Failing should be funny (their idea: work a crap
    job at a parody supermarket or coffee shop to earn back a boat; made-up brands).
  - **No new features now** (except maybe VS and better co-op): polish what's here until it's beautiful.
  - **The art must change** (below).

## Art direction (the big open job)

The user's verdict on the current look: "hyper low poly", "square", "zero life", "the ugliest thing". It started
as a PS1 look (screen pixelation, crunched photo textures, boxy models built by Python in Blender). In this
session: the PS1 screen filter is off (`--screen=psx_360` brings it back), textures filter smoothly, the
environment is ACES with saturation, bloom and SSAO, the water is teal with crests glowing where the light comes
through, the boats are repainted in clean colours (`psx.painted`), and the crew model has bevels, a face and
cartoon proportions. **It's still boxy and still not what they want.** Procedural box modelling can't get there.

### What they want, from their reference screenshots (Sea of Thieves)

They sent four images (described in full in `docs/ART_REFERENCE.md`; the images themselves stayed in the chat):
1. **A pirate character**, full body. Lanky, exaggerated anatomy: a long face, a heavy brow, a big nose, a sneer,
   a mohawk; muscular shoulders, long arms with real hands and fingers. Hand-painted skin with tattoos and scars;
   torn trousers, wrapped bandages, worn leather boots with straps and buckles. Soft studio light, a slightly
   purple-brown palette.
2. **The body-types sheet**: ten bodies from very fat to very thin, men and women, all smooth sculpted forms with
   the same stylized face language. Variety and caricature are the point.
3. **A ship at sea**: a dramatic silhouette (a dragon-jawed hull, glowing fire inside, tattered red sails),
   rigging, lanterns; a bright saturated blue sky with fluffy clouds; turquoise water, translucent at the crests,
   white foam, big rolling waves.
4. **A megalodon**: a chunky exaggerated silhouette, a dark navy top fading to a pale belly, a painted texture with
   scale patterns, scratches and scars, glowing yellow eyes, oversized teeth, a red mouth.

What makes it read as "alive": **exaggerated silhouettes and proportions**, **smooth organic sculpted forms**
(no boxes), **hand-painted textures that tell a story** (wear, scratches, stitching, dirt, gradients dark on top
and light below), **lots of secondary detail** (ropes, buckles, lanterns, folds), and **saturated, warm,
soft lighting** with translucent stylized water.

### Recommended pipeline (needs a local machine)

- **Characters:** don't box-model. Get proper stylized meshes: generate them with an image/text-to-3D tool (Meshy,
  Tripo or Rodin; prompt e.g. "stylized Sea of Thieves style fisherman, yellow oilskin bib overalls, beanie,
  big beard, rubber boots, exaggerated proportions"), or buy a stylized character pack, or commission an artist.
  Clean up in Blender, rig with Mixamo (auto-rigger) or Rigify, and use Mixamo animations plus custom ones. Then
  replace `crew/player.gd`'s piece-posing (`_pose_body`) with a `Skeleton3D` and an `AnimationTree`: the pose
  logic there (rod: brace, crank, pump; wheel; harpoon and throw; binoculars; haul; jig; scoop; bleed; stumble;
  walk and run) is the list of animation states, and `act` plus `gesture()` already sync what each player is
  doing. Several body types and colours of oilskins, to match the friendslop variety.
- **Boats:** model them properly (subdivision modelling, beveled planks, cleats, rope coils, lanterns, rod
  holders) and texture them by hand (Blender texture paint, ArmorPaint or Substance), or use trim sheets. Keep the
  node names the code expects (see `art/boat.py` and `art/skiff.py`'s docstrings: `boat`, `wheel`, `radar`,
  `collider`, `chair`, empties `spawn_*`, `holder_*`, `helm`, `flood_*`, `deck_light_*`) and the spots in
  `boat/kinds.gd`.
- **The bluefin, birds, the harpoon, the rod:** the same: sculpted or generated, painted. The bluefin's swim is a
  vertex shader (`tuna/tuna_swim.gdshader`): the new mesh needs its length along -Z.
- **Water:** `sea/ocean.gdshader` has the start of it (teal, crest glow, glossy, soft foam). Push toward Sea of
  Thieves: stronger subsurface teal, foam trails on the wave faces and the wake, a brighter, cloudier sky
  (`sea/sky.gdshader`).
- `art/psx.py` is the old toolkit; its `painted()` and `finish(bevel=, subdiv=)` are this session's stopgaps.
  `core/psx_import.gd` is the glb import script (it now keeps smooth filtering and each material's roughness).

### Chekhov's gun: an audit of what's on the boats (the user's rule, docs/VISION.md)

Everything big enough to look usable must be usable, or go. Today:

| Thing | Usable now? | Do |
|---|---|---|
| The fighting chair (sportfisher) | **yes** (boat/chair.gd, tests/chair_test.tscn) | Done: E sits you in it, E or a jump gets you up; it swivels where you look; a fish fought from it tires your arms 0.6x; sitting with no fish your arms come back twice as fast. |
| The tuna tower (sportfisher) | no | Climb it: see further (the binoculars from up there spot flocks the deck can't). |
| The leaning post / skipper's seat / bench | no | Sit or lean (E), just to chill. |
| The cooler (sportfisher), the live well, the fish box | the box takes fish (as a whole: E on the fish) | Cooler: grab a drink (funny; maybe a little arm rest). Live well: see the mackerel in it. Fish box: the lid opens as fish go in. |
| The radio on the dash | Dale talks on it (as a HUD card) | Make the voice come from it; maybe music (a toy). |
| Rod holders that never fish (sportfisher's 2-5, skiff's 2-3) | the jig uses one | Spare rods, or take the empty holders out of the model. |
| Outriggers (sportfisher) | no | Run the corner baits from them, or take them off. |
| Floodlights, buoys, rope coils, cleats | lights come on at dark | Fine as set dressing. |

## The game, in one breath

A crew of 1-4 owes the bank. Quota every 3 days (one trip a day, 20 real minutes dawn to dusk). Head out, hunt
birds far off with binoculars (a third are gulls with no tuna; tuna come up and go down in 40 s spells), call
them onto the radar, come up slow (over 10 knots and they dive), the school finds your towed baits, fight the
fish (moves with tells: run, sound, shakes, circle, rest, the death spiral), the captain keeps the stern on it
(the props cut the line if in gear while it's under her), clear the other lines, wire it (big boat), harpoon it,
haul it, bleed and ice it, sell it. While waiting: chum, rebait stale baits, jig mackerel for the live well.
Two boats (the skiff, the 46 ft sportfisher), gear, Dale from the bank on the VHF teaching each thing once, the
owner's manual in the Esc menu. Co-op over Steam (GodotSteam add-on, app 480) or a join code.

## The code map

| | |
|---|---|
| `sea/sea.gd` | builds the world and every system; light, weather, the day's look |
| `sea/ocean.gd`, `ocean.gdshader` | the world-anchored sea following the boat; `height_at()` |
| `boat/boat.gd`, `helm.gd`, `kinds.gd`, `wake.gd` | the boat (by kind), her helm and motion, the two kinds' data, wake and engines |
| `boat/fish_hold.gd` | the trip, the day, the catch, grading, selling, the quota run, the bank, gear, the save |
| `boat/chum.gd`, `jig.gd` | chum slick, mackerel jig |
| `rods/rods.gd`, `rod.gd` | the spread, bites, holders, hand-offs, towed baits, tangles, the hooked fish seen |
| `tuna/fight.gd` | the fight (moves, strain, arms, the captain's effects) |
| `tuna/landing.gd` | alongside, wiring, the harpoon, hauling aboard |
| `tuna/schools.gd`, `radar.gd`, `sonar.gd` | flocks and tuna, the hunt, call-outs, chum and bait drawing |
| `crew/player.gd`, `crew.gd`, `binoculars.gd` | first person on the moving deck, the body's poses, the roster |
| `ui/hud.gd`, `menu.gd`, `tips.gd`, `manual.gd` | HUD, the dock and Esc menu, Dale's radio tips, the manual |
| `core/net.gd`, `steam_link.gd` | networking (host authority; clients ask with rpc_id(1, ...)) |

## Next, in order

1. **Run it.** Open in Godot 4.7, run every test, play a solo trip start to finish (head out, find birds, hook,
   fight, land, sell), then two players over ENet. Fix everything that breaks. Screenshot it.
2. **The art direction** above: characters first (most visible), then the boats, the water and sky, the fish.
   Do the Chekhov's gun audit as each model is redone (the fighting chair first: it's the sportfisher's centre).
3. The rest of the polish plan in `docs/TODO.md` (feel and sound, the HUD's look, co-op polish), two independent
   reviews.
4. Parked until the user says so: the crap-job fail state, overboard, night danger, events, sea life, VS mode,
   proximity voice.
