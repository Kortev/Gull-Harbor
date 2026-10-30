# TODO (in order)

## Next: the world, then hands-on fishing, then the UI (your order, 2026-10-29)

The sea looks like an endless dev test, and too much of the fishing is "hold E". In this order:

1. **The world first.**
   - Landmarks and haze (done, 2026-10-29: `docs/shots/landmarks_*.png`): the coast and the harbour town behind
     where you start, the lighthouse, an oil rig, buoys, all at fixed spots; the haze fades them by the weather.
   - Whales and dolphins: something alive to find, and a lead to fish (they work bait like the birds do).
   - Other boats out working the flocks, with radio chatter.
   - The water and the sky (baseline shots: `docs/shots/sea_before_*.png`).
   - Flocks more common (done: up to 6 at once, a new one every 10-25 s).
2. **Then hands-on fishing.**
   - Hands and a hotbar: carry things (the knife, the gaff, the jig rod, a scoop, a bait), one in your hands.
   - Setting the trolling rods yourself: cast each bait out and drop the rod in its holder, not one press of E.
   - Jigging as a little game with the jig rod (drop, work it, feel the hit), not holding E.
   - Handling the catch: the knife to bleed it, drag it across the deck to the fish box, open the lid, drop it in.
   - Chum: take the scoop, dip it in the bucket, throw it where you want the slick.
3. **Then the UI, many passes** (it's "uglier than a bag of rocks"): the HUD, the menus, the dock, the manual.

Done in this stretch: no tired arms (the chair is just for sitting), no binoculars (flocks by eye), no calling
flocks, the skiff a bare boat (no radar or sonar), the line rubs only where it really runs over her house and bow.

## Now: no new features. Make what's here good (your call, 2026-10-29)

The base idea's in (`docs/FEATURES.md` lists every feature and what a player needs to know). Before anything new
(except maybe VS and better co-op), polish it till it's beautiful:

1. **Teach the player** (`docs/FEATURES.md`'s teaching plan): first-time tips, each once (slow down near birds,
   grab the rod, each fight move the first time, wiring, the harpoon, bleed and ice, the quota's stakes); the field
   guide in the Esc menu; the dock spelling out the quota.
2. **Animation** (the art pass's biggest part):
   - the crew: a real walk and run, idle sway with the sea, reeling (the crank arm going round), pumping (lean back,
     drop and wind), bracing against a run, steering, throwing the harpoon, hauling, holding binoculars, scooping
     chum, jigging, bleeding a fish, stumbling when she slams a wave;
   - the tuna: jumping and thrashing on the surface in the fight (you see it), the last circles under the boat,
     thrashing alongside, kicking on deck;
   - the birds: flapping and gliding, folding to dive, sitting and lifting off the water;
   - the boat: the wheel, the throttles, rods bending and the reels' handles, the harpoon's line, the door.
3. **Visual polish:** light at dawn and dusk, the water (foam, the wake, spray, the slick), the boats' detail, the
   dock itself, the HUD (cleaner, readable, styled), screen transitions.
4. **Feel and sound:** the camera (sea legs, the slam of a wave), feedback when things go right (the fish showing,
   the stick, the haul, the sale), the music and the sea's sound.
5. **Co-op polish:** what you see of crewmates (their animations, what they're doing), shouting/calls, joining mid
   trip, the host leaving.
6. **Chekhov's gun** (your rule): everything big enough to look usable is usable, or it goes (the fighting chair:
   sit in it and fight from it; the tower: climb it to spot; seats: sit and chill). The audit's in `docs/HANDOFF.md`.
7. **Two independent reviews**, then fix.

Parked (features, later): overboard and the life ring, night danger, events (storms rolling in, the giant,
something in the fog), sea life to spot, the horn and radio, sharks in the fight, VS mode.

## Done before (the history)

The game: a homemade take on the TV bluefin shows, for playing with friends (Jack first). A crew of 1-4 on one tuna boat, endless open sea, sometimes huge waves, catching as many bluefin as
they can. Creepy only from the sea and the weather; mostly action; very atmospheric. Real tuna only. Arcade
rules (physics only for the look). A set world with waves, fish and fishing grounds; the boat moves through it.

Each item: build it, check it (screenshots in `docs/shots/`), commit, push (the Gull Harbor
repo, now `main`), tick it here.

- [x] **The sea:** Fathom's ocean, weather (calm, sunny, fog, rain, heavy, storm), sky, rain, lightning, the PS1 look.
- [x] **The boat:** a plain, weathered 41 ft tuna boat for four (`art/boat.py` -> `boat/boat.glb`, crunched CC0 photo textures): wheelhouse and hardtop, open cockpit, fighting chair, 8 rod holders, tuna tower, outriggers, floodlights; parked at the origin, heaving, pitching and rolling on the swell (`boat/boat.gd`).
- [x] **Sea polish:** the white squares on the water are now little rain rings; big swells are shaded smooth with a hint of the PS1 facets (`facets` in ocean.gdshader), no more sawtooth.
- [x] **The crew:** a first-person player (walk, sprint, jump, look, E to interact) on the moving deck: you walk in the boat's still "deck space" and are carried by its pose, so nobody slides or jitters (`crew/player.gd`, `tests/deck_test.tscn`).
- [x] **Co-op:** host / join over ENet (Esc menu, or `--host` / `--join=<code or address>`), up to four on deck, everyone on the host's sea clock (ping/pong sync, 1 ms apart in `tools/net_test.sh`) and weather.
- [x] **Fixes from the first playtest:** mouse look (the HUD dot ate the mouse); the weather is nobody's choice now (it comes and goes on its own, `sea/weather.gd`); the sea rebuilt so the boat rides it (a wave spectrum instead of a few tidy waves, the boat fitted to the water under her whole hull, the hull pushing the water down instead of a hole cut in it: `tests/hull_test.tscn`); hosting without port forwarding (the router is asked to open the port by itself, UPnP, and the host gets a join code: `tests/code_test.tscn`).
- [x] **The bluefin:** a PS1-style bluefin (`art/bluefin.py` -> `tuna/bluefin.glb`), 30-400 kg (1.25-2.96 m, from the real weight-length curve), swimming like a tuna: stiff body, the tail stalk and crescent tail beating faster as it speeds up, banking into turns (`tuna/tuna.gd`, `tuna/tuna_swim.gdshader`). The lab: `tuna/tuna_lab.tscn` (F6).
- [x] **Hooking up:** baits out from the stern holders, schools showing (birds, busting water, leaping tuna, sonar marks: `docs/shots/school_*.png`), the reel screams, anyone grabs the rod (`tests/strike_test.tscn`).
- [x] **The fight:** the arcade fish-moves fight (from Gull Harbor's fish_fight.gd) with tuna moves: the screaming first run, sounding deep, head shakes, circling under the boat, the death spiral; left mouse cranks, right mouse heaves (pump); a strain ring and the move's tell under the crosshair; juice: the rod bucking, the drag screaming, the reel whirring, the line singing, your view shaking (`tuna/fight.gd`, `tests/fight_test.tscn`, `tests/strike_test.tscn`).
- [x] **A real world, and she really moves** (your call: "like any other game"). Not yet played in Godot.
  - The sea's waves belong to the world; its mesh follows the camera, so there's always water under her
    (`sea/ocean.gd`, `sea/ocean.gdshader`).
  - She has a real position and speed (`boat/helm.gd`): hold W to run her ahead (up to about 20 knots), S backs
    her down (a few knots), let go and she carries her way (about 80 m from flat out). A/D steer; twin screws spin
    her on the spot too. Her bow lifts under way and her stern digs in backing down (`boat/boat.gd`). Knots and
    throttle at the bottom of the screen while you're at the wheel.
  - Feel (`boat/wake.gd`): the engines' sound with the throttle, a wake, white water boiling astern when the screws
    bite, spray off her bow at speed, the sea slopping over the transom backing down hard.
  - Birds anywhere (`tuna/schools.gd`): up to four schools turn up round her, 250 m to 1.1 km off (the first one
    close), cruise, feed on and off for 3 to 6 minutes, then the birds lift and scatter. No bites above 12 knots
    (the baits skip); run through a school fast and it goes down for 40 s. The dash radar paints the birds out to
    1.5 km (`tuna/radar.gd`); the sonar marks what's under her.
  - The fight uses where she really is: backing down closes on the fish, running away pays out line.
  - With two boats (VS, later): birds should turn up fairly round both, and some between them, for both crews
    to race to. Grounds can come later, on top, once fuel and trip length make "where do we go today" a choice.
- [x] **Two boats, picked by the host at the dock** (`boat/kinds.gd`, `art/skiff.py`; not yet played) (like Sea of Thieves' sloop and galleon; same tuna on both):
  - [ ] **The small boat (the default, for 1-2):** about 28 ft, an open center console, so the wheel is a few
    steps from the rods. Two rods out, low sides (one person can gaff a fish), turns fast and follows a fish
    easily. Rough in a storm, and holds only one or two fish before you head in. Alone, you put the rod in the
    holder, run to the wheel, then grab it back.
  - [ ] **The big boat (the 46 ft, for 4) is stronger but harder:**
    - Stronger: 4 rods (about 1.5-2x the bites), the tower to spot schools far off, heavy tackle and the fighting
      chair, powerful backing down, a fish hold that keeps them fresh.
    - Harder: slow to turn and to stop (she carries on after you let go); the captain can't see the fish (no
      plotter; someone calls it); a long hull and twin props; more lines to tangle; boatside needs three hands
      at once.
- [x] **Waiting for the tuna, the crew's busy** (chum, baits going off, the jig and the live well; not yet played) (all of it feeds the tuna fishing; skip it and you still get
  bites, just fewer):
  - [x] **Catch bait:** a small rod with a string of little hooks catches mackerel (quick, easy, chill), into the
    live well.
  - [x] **Tend the baits:** baits go stale, wash out, or get stolen; swap in fresh live mackerel (more bites than
    dead bait).
  - [x] **Chum:** throw cut bait over the side; the slick pulls a school to the boat and keeps it there.
  - [ ] **Spot:** up the tower you see birds and schools far off; call them to the captain.
  - [ ] Maybe: a blue shark now and then steals a bait (cut it loose); a mako, very rarely.
- [ ] **Green water:** spray over the bow and crests slopping over the rail in a storm; the deck streaming.
- [x] **The bigger boat:** 46 ft with a wider cockpit, so four of you and the fighting chair have room.
- [ ] **Crew jobs: why it takes a crew.** One person can't land a big bluefin alone; while the fish is on, everyone else has a live job that decides whether you land it, and each can rescue the others' mistakes:
  - [x] **The captain at the wheel** (E on the helm, A/D to turn, S to back down): the tuna swings round the boat; let it get too far off the stern and the line rubs the hull (strain jumps), let it get under the boat and the props cut it. Backing down on the fish wins the angler line back fast and takes the strain off: the rescue when the angler's losing.
  - [x] **The angler tires:** cranking and pumping drain your arms; tired arms crank slower and pump weaker, and a giant outlasts one person, so you hand the rod off mid-fight (anyone grabs it).
  - [x] **Clear the other lines:** when a fish hits, the other baits are still out; a running tuna that crosses one tangles it (lost, or a fight with a tangle). Someone reels them in.
  - [x] **Boatside:** the beaten fish lies astern; someone grabs the harpoon (along the port side) and sticks it,
    then it's hauled in through a tuna door in the transom (hold E; alone a giant takes about 20 s, two or three
    make it quick). Leave it unstuck for 90 s and the hook pulls (`tuna/landing.gd`, `tests/landing_test.tscn`).
    Not yet played in Godot.
  - [x] **Boatside, wiring:** one keeps the line tight while one grabs the leader (the wire above the hook:
    "wiring") before the stick, so it really takes three hands on the big boat.
  - [x] **After:** bleed it and ice it (E on the fish on deck, then E again into the fish box) for a better grade
    (`boat/fish_hold.gd`).
  - [x] **The rod in the holder fights on its drag** (the fish takes line only on its runs, nobody wins any back),
    a hooked fish never gets its strength back, the boat out-turns a circling fish, picking the rod up carries on
    the same fight, the angler's corner keeps the line off the hull, and the HUD shows the line out and whether
    you're gaining. Not yet played in Godot.
  - **Solo** works: you drop the rod in the holder to run to the wheel. It's meant to feel desperate, and a giant
    alone takes about twelve minutes (see the table in WHILE_YOU_WERE_AWAY).
  - **Your rules for crew size** (2026-10-29): solo must be possible and fun, but harder than with friends. No
    numbers that change with how many are aboard (arms don't tire slower alone, fish don't shrink). The
    differences come from the game itself: the small boat (easier alone, less money: fewer rods, a small hold)
    against the big one (more money, needs hands), and what each extra pair of hands can do. A CPU crew member,
    if we add one, is a person, not an autopilot: maybe a deckhand you hire for a share of the catch.
- [x] **The tally:** top left, the hold, the deck, the weight, what it's worth and the bank. Esc, "Head in and sell
  the catch" sells it by the kilo at its grade (#1, #2, #3: landed fast, bled soon, iced soon), shows the slip,
  and banks the money (kept between games); "Head back out" starts the next trip (`boat/fish_hold.gd`,
  `ui/menu.gd`). Not yet played in Godot. Later: a real trip (the run out and back, fuel, a hold that fills).
- [x] **The dock** (where a game starts: the slip, the bank, the boats, the gear, Head out) and **a day going by** (dawn, day, dusk, night). Not yet played.
- [x] **Steam as the main way to play together:** host a friends-only Steam lobby, friends join from the menu's list or an invite, traffic through Steam's relays (`core/steam_link.gd`; needs the GodotSteam add-on from the AssetLib; `tools/steam_test.sh` against a stand-in for Steam). The join code stays as the backup.
- Later: **longer fights.** Real ones on heavy tackle run twenty minutes to over an hour for a giant; ours are a
  few. Raise the tiring time (`_goal_s` in `tuna/fight.gd`) once the crew has enough to do during one.
- Later: **VS mode** (two boats on the same sea, the most pounds by the end wins); proximity voice; trips cost money; a rounds structure; upgrades.
