# While you were away (newest first)

## Brainstorm: playing with 1, 2 or 4 (your question; nothing built yet, pick what you like)
The rule I'd hold to: **more hands make it easier, but no job is ever required.** Every job has a weaker
fallback, so one or two people can play the whole game.
- **CPU deckhands:** fill any job nobody's doing. Humans can take a job over anytime and the deckhand steps
  aside. They're decent but late, so a friend always does it better. The host sets "Deckhands: 0 to 3". This is
  also your dev test.
- **Orders:** solo, you're the skipper. A few keys shout orders ("Back down!", "Clear the lines!", "Gaff it!") and
  the deckhands do them.
- **Gear instead of people:**
  - An autopilot that holds the stern to the fish, only half as well as a captain.
  - Fighting the fish from the rod holder while you drive.
  - A flying-gaff stand.
  - Solo crews buy these; full crews spend the money elsewhere.
- **One person can do several jobs, worse:** a second set of controls aft in the cockpit (real boats have them), so
  you can run between the wheel and the rod. With 2 players it gets frantic, like Overcooked; with 4 it's calm.
- **The sea scales to the crew:** fewer hands, fewer giants. Solo sees mostly 50 to 200 kg fish; four of you see
  the 400 kg ones.
- **Four players:** two boats, 2 v 2, racing for the biggest catch. Or one boat with more rods out, so a double
  hookup gets more likely with more idle hands.
- **Fallbacks already in:** a big fish slowly tows the stern round to it, and a crewmate can take the rod. But
  right now a lone angler loses every 300 kg fish, so whatever you pick, I'll retune solo.

## Tiring arms and handing off the rod
- **What changed:**
  - Cranking and heaving wear your arms. The heavier the fish, the faster: much faster for a giant.
  - Tired arms crank slower and pump weaker, and spent arms can't heave at all.
  - Easing off rests them a little. Off the rod they come back in about half a minute.
  - Once they start to go, a thin inner ring round the crosshair shows them. At the end the tell says "Your arms
    are gone! Hand it off".
  - A crewmate can press E on the rod in your hands ("Take over the rod") and the fight carries on. Nothing resets:
    the line out, the fish's tiredness, even the line's wear from the hull.
- **Numbers from the fight test,** with a captain:
  - 150 kg: one pair of arms lasts the whole fight.
  - 450 kg: two anglers taking turns land it in about 165 s. One angler takes about 235 s and sometimes loses it.
- **How it was checked:** the fight test (above) and `tools/net_test.sh`, where a joining friend takes over the
  host's fish and both see the same holder. All the other tests pass.

## Question for you: what does a 4th person do during the fight?
You asked this, and it's a fair hit. Right now a fight has two full-time jobs:
- the angler;
- the captain.

A third person has real work, but in bursts: clearing the other lines when it hits, then the leader and the
harpoon at the end. A fourth person mid-fight would mostly be watching. My options, best first:
1. **The tower spotter.** Only someone up the tuna tower can see where the fish and the line are; the captain at
   the wheel sees just the bow. The spotter calls it out over voice ("it's going under the port side!"), and the
   captain's plotter goes away. This one is the most fun with friends talking.
2. **Taking turns on the rod.** Arms tire, and a giant outlasts one angler. Two people share the rod, one resting.
3. **The chair mate.** For a giant, the angler fights from the fighting chair, and someone swings the chair to keep
   it pointed at the line. Turn it wrong and the strain climbs.
4. **Keep fishing.** Someone keeps the other baits out and chums to hold the school; a second fish can bite (still
   rare).

My pick is 1 plus 2, with 3 only for giants. Say which you like. Until you answer, I'll build the angler's tiring
arms (2), since it's in every version.

## The captain at the wheel (and your question about just moving the rod)
- **How it plays:**
  - Press E on the wheel to take it.
  - A/D swing her round. She really turns: the sea, the sky and the baits all swing.
  - Hold S to back down, W to go ahead. E or Q leaves the wheel. The captain can't hold a rod.
  - At the wheel you get a small plotter: her outline, bow up, and each fish on its line from the stern.
- **Why it matters:**
  - **The hull:** let the fish swing forward of her beam and the line lies along the hull and wears through
    ("The line chafed through on the hull!"). Swing the stern to the fish to clear it.
  - **Backing down:** on a fish astern this runs the boat back over it. It wins line, takes the strain off and
    slows a run. It roughly halves the fight and saves you from being spooled.
  - **The props:** back down (or go ahead) while the fish is under the boat and the props cut the line.
  - Left alone, a big fish slowly tows her stern round to it, so a solo angler still has a chance.
- **Your question: can't the angler just move the rod?** Partly, and that's in too.
  - Stand out at the corner the fish is on and the line clears the hull a bit longer.
  - But a rod only reaches over the side, so once the fish goes forward of the beam only turning the boat
    fixes it.
- **Numbers from the fight test,** played perfectly:

  | Fish | Alone | With a captain |
  | --- | --- | --- |
  | 150 kg | 17 of 20 landed | 20 of 20, twice as fast |
  | 300 kg | 13 of 20 | 20 of 20 |
  | 450 kg | 4 of 20 | 20 of 20 |
- **How it was checked:**
  - `tests/helm_test.tscn`: take the wheel, steer, the fish swings, back down, leave the wheel.
  - `tools/net_test.sh`: your friend steers and you see the same heading.
  - All the other tests pass too.
  - Screenshot: `docs/shots/captain_at_the_wheel.png`.

## A bigger boat: 46 ft
- She's 14 m long and 4.8 m across (was 12.5 by 4.3), so the cockpit is about 0.75 m longer and half a metre wider.
  That's room for four of you round the fighting chair.
  - The wheelhouse is wider too.
  - The rod holders, the chair, the cleats, the outriggers, the bow rail and the spawn spots all moved out to suit.
  - The baits stream a little further back.
- The sea still stays out of her: the water's hull cut-out now reads her length and beam from the boat, so the next
  resize is one number.
- **How it was checked:**
  - The hull test (green water over the rail in a storm) and the deck test (walk to the transom) pass.
  - The rods, strike, fight, look and net tests pass.
  - Screenshots: `docs/shots/boat46_outside.png` and `docs/shots/boat46_cockpit.png`.
- **Next:** crew jobs, starting with the captain at the wheel.

## Your answers (thanks!)
- Steam's relay: yes, as the main way to play together (the join code stays as the backup). In progress.
- The boat: my call. She's 46 ft now (below).
- `main` is now the tuna game; the old Gull Harbor game is gone from it. A leftover `bluefin` branch (an older
  copy of the tuna game) is still there: I wasn't allowed to delete branches from here, so delete it on
  GitHub (Branches, the trash icon) whenever.

## Playing over Steam (the main way now)
- **What changed:**
  - The Esc menu now starts with **Host on Steam**. Your friend opens their Esc menu and sees **Join Graeham's
    boat** (any Steam friend with a boat out is listed), or you press **Invite a Steam friend**.
  - No ports, no codes: the game's traffic goes through Steam's relays, so it works whatever your routers do.
  - The join code is still there underneath, as the backup without Steam.
- **One-time setup (you, in the Godot editor):** I couldn't download the Steam plugin from here, so:
  1. Open the AssetLib tab at the top of the editor.
  2. Search **GodotSteam** and pick the **GDExtension** one (not "Server").
  3. Download, then Install. It lands in `addons/godotsteam`.
  4. Restart the editor.

  The Steam buttons then appear by themselves when Steam is running. It uses Valve's free test app (480,
  "Spacewar"), so Steam shows you both as playing Spacewar. That's normal, and fine for friends.
  - **Both of you start the game first**, then invite or join. On the test app an invite can't launch the game
    for you.
  - Commit the `addons/godotsteam` folder so Jack gets it too, or send Jack a build.
- **How it was checked:** I can't run Steam here. `tools/steam_test.sh` runs two copies against a stand-in for
  Steam: one hosts a lobby, the other sees "Jack" with a boat out in its friends list and joins. Both see two
  crew, the host's storm, and the same sea clock. Your first real test is the first real Steam check, so tell
  me what the menu says if it doesn't work.
- **Also:** a second fish while one's already on is now rare, instead of a coin flip.

## The fight
- **What changed:** hooked bluefin now fight. Every fish opens with the screaming run, then plays moves. Each
  move shows a hint under the crosshair, and each wants one answer:
  - **The run** ("It's running! Let it go"): don't crank. The drag tires it. Crank against a big fish's run and
    the line parts.
  - **Sounding deep** ("It's sounding! Pump it up"): hold right mouse to heave the rod up, then crank as it
    comes back down. Cranking alone gains next to nothing on a deep fish.
  - **Head shakes** ("Keep it tight"): keep cranking or lifting, or the hook pulls.
  - **Circling under the boat** (as it tires): pump.
  - **Resting:** crank.
  - **The death spiral** when it's beat: crank it up alongside.

  A ring round the crosshair fills and reddens with the strain; hold it full too long and the line breaks.
  - **Fight lengths:** a 35 kg schoolie takes about a minute, 150 kg about two, a 400 kg giant about four.
  - **Swapping:** anyone can take over. Q puts the rod back in the holder with the fish still on, and someone
    else grabs it; the fish stays as tired as it was. Leave the rod in the holder and the fish strips the reel
    in about half a minute.
  - **Juice:** the rod bends and bucks, the drag screams, the reel whirs when you crank, the line sings when
    it's bar-tight, and your view shakes with the pull.
  - **Boatside:** the fish ends up alongside. The harpoon and the tuna door come with the crew jobs, which are
    next.
  - **Co-op:** the fight runs on the machine of whoever holds the rod, so it feels instant; the others see
    the line and the rod moving, and the host calls lost or landed.
- **Birds and busting:** schools now feed most of the time near the boat. The birds are bigger, darker
  shearwaters lower over the water, and the splashes are bigger.
- **How it was checked:**
  - Shots: `docs/shots/fight_running.png` (the tell and the ring), `school_busting.png` and
    `school_birds.png` (the shearwaters, the busting water, a tuna clearing it).
  - `tests/fight_test.tscn` fights 160 fish headless. Fought right, every size comes boatside. Just cranking
    breaks the 150 and 400 kg ones every time. Doing nothing never lands one.
  - `tests/strike_test.tscn`: a school bites, the drag screams, the test grabs the rod and fights it right. A
    181 kg bluefin came boatside in 151 s, through every move.
- **Try it:** F5 and wait by the rods for "FISH ON!" (or start with `-- --strike=0 --hold=0` for a fish on
  in your hands).

## Fixes from your first playtest
- **Mouse look works again.** The crosshair dot sat exactly where the captured mouse lives (the middle of
  the screen) and swallowed every mouse movement. `tests/look_test.tscn` now checks it.
- **Nobody picks the weather.** It comes and goes by itself: about five minutes of one kind, then a minute
  and a half turning into the next. It wanders (calm can cloud over to rain and build into a storm, a storm
  blows through and clears) rather than jumping, and sometimes it's sunny. Everyone aboard sees the same
  sky: it comes from the shared clock and a seed the host hands out. The menu's weather buttons are gone.
  (`--weather=storm` still pins it for testing.)
- **The sea is rebuilt:**
  - **No more pattern.** It used to be a dozen tidy waves added up, which looked even and repeated. Now it's
    28 waves of scattered lengths and directions, so the swell comes in sets and the chop never repeats.
  - **The boat rides it.** She's fitted to the water under her whole hull and follows the swell fully. The
    storm keeps its big 12 m swell (long waves she climbs and drops off) but lost most of the short,
    boat-sized chop that used to bury her.
  - **No hole in the sea.** The old trick cut the water away inside the boat, so a crest climbing the hull
    showed its open underside. Now the hull pushes the water down where it meets her: no hole, no underside.
  - The storm's foam streaks are thinner and softer (wide hard-edged ones read as zebra stripes on a big
    swell). Shots: `docs/shots/storm_cockpit_dry.png`, `storm_boat_rides_swell.png`,
    `sea_spectrum_rain.png`, `sea_spectrum_sunny.png`.
  - `tests/hull_test.tscn` measures it over a minute: in a storm water reaches the rail 1.7% of the time (a
    slap over the transom, 0.35 m at worst); in heavy weather under 2%; in rain never.
- **Hosting without port forwarding.** Host now asks your router to open the port by itself (UPnP, on by
  default on most home routers) and shows a **join code** with a Copy button. Your friend pastes it in and
  presses Join; joining never needs anything opened. If your router says no, the menu says so: the code then
  works on your own Wi-Fi only (see the TODO for the fallback).
- **Try it:** F5. Esc, Host a crew, copy the code and send it to Jack; Jack pastes it and presses Join.

## The bluefin
- **What changed:** a real-looking Atlantic bluefin, low-poly and crunchy like the rest of the game:
  - the body: a torpedo shape, navy-black back with a blue sheen, silver flanks with rows of pale spots, a
    white belly;
  - the fins: short pectorals, a low dark first dorsal, a sickle second dorsal, yellow finlets, a tall
    crescent tail.
  - **Sizes:** 30 to 400 kg, which works out to 1.25 to 2.96 m from the real weight-to-length curve.
  - **Swimming:** it swims like a tuna. The body stays stiff and only the tail stalk and tail sweep, beating
    faster the faster it goes and harder when it's working (on the line). It banks into turns.
- **How it was checked:** `docs/shots/bluefin_sizes.png` (30, 150 and 400 kg side by side) and
  `bluefin_laps.png`.
- **Try it:** open `tuna/tuna_lab.tscn` and press F6. Three tuna swim laps; Minus makes them sprint.

## Co-op
- **What changed:** up to four of you on one boat:
  - Press Esc for the menu. **Host a crew** there, and friends **Join** with your address on port 7777.
  - Everyone stands on deck, sees each other walk around, and sees the exact same sea: the waves and the
    boat's rolling are on the host's clock.
  - If the host leaves, you're put back on your own boat.

  Crewmates are yellow placeholder figures until the crew model exists. Steam lobbies and invites come later.
- **How it was checked:**
  - `tools/net_test.sh` runs a host and a client on this machine. Both see two crew and the host's storm, and
    their sea clocks are 0.001 s apart.
  - `docs/shots/coop_client_sees_host.png` is from the client's eyes, looking at the host on deck.
- **Try it on one computer:** in Godot, Debug > Customize Run Instances > 2 instances, then F5. In one window
  press Esc and Host; in the other press Esc, type 127.0.0.1, and Join.

## Sea polish
- **What changed:**
  - The white squares all over the water in the rain were the ocean's raindrop dots. They're now little
    rings that open and fade.
  - Big swells in low light had a sawtooth look from long, thin triangles. They're now shaded smooth, with
    only a hint of the PS1 facets left.
  - Fixed: the wheelhouse night light never turned on.
- **How it was checked:** `docs/shots/sea_rain_rings.png` and `sea_heavy_smooth.png` (a heavy sea from the
  cockpit, a swell towering over the rail).

## Walking around on the boat
- **What changed:** you're one of the crew now, in first person:
  - WASD, mouse look, Shift sprints, Space jumps, E uses things.
  - Esc frees the mouse, and a click takes it back.

  Movement is calm, with no slipping. You walk in the boat's own still frame (the space game's "the ship never
  moves" trick), so the deck is solid under your feet even in a storm, and you can't fall over the rail. Your
  view leans with the deck but keeps the horizon about half level, so you feel the sea without getting sick.
  At night there's a dim red light in the wheelhouse.
- **How it was checked:** `tests/deck_test.tscn` stands you in a storm for 10 s. You drifted 0.000 m and your
  feet stayed exactly on deck. It then walks you to the transom and jumps you, and you land back on deck. The
  screenshots `docs/shots/crew_heavy.png` and `crew_storm_night_helm.png` are from the crew's eyes.
- **Try it:** F5.

## The boat
- **What changed:** a normal 41 ft tuna boat for a crew of four, built by a Blender script (`art/boat.py`)
  with the space game's crunched photo textures (none of its decals or branding). It has:
  - a weathered white hull, a green boot stripe and red bottom paint;
  - a wheelhouse with a hardtop over the front of the cockpit, a helm with sonar and radar screens;
  - the open cockpit: fighting chair, 8 rod holders, a fish box, a live well, a cooler, buoys;
  - a tuna tower, outriggers and a radar;
  - floodlights and cockpit lights that come on at night, in fog and in storms.

  She never moves: she sits at the origin and heaves, pitches and rolls on the swell. The sea isn't drawn
  inside the hull, but big crests still tower over the rail.
- **How it was checked:** screenshots in `docs/shots/`:
  - `boat_sunny.png`
  - `boat_rain_night.png`
  - `boat_storm_night.png` (from the cockpit, with the floodlights on the rain)
  - `boat_cockpit_heavy.png`
- **Try it:** F5. For now the camera stands in the cockpit looking aft. Next: walking around on her.

## The fresh start: the sea
- **What changed:** a new, clean Godot project built only for the tuna game. The ocean, the storm (wind, rain,
  spray, lightning, the fog wall), the sky and the gritty PS1 screen look come straight from your space fishing
  game's Fathom. Six conditions: calm, sunny, fog, rain, heavy, storm, day or night.
- **How it was checked:** screenshots `docs/shots/sea_rain.png` and `docs/shots/sea_storm.png` (a 10 m swell
  over the camera in the storm).
- **Try it:** this lives on the `bluefin` branch of the Gull Harbor repo for now. Open the project folder in
  Godot, press F5. Next up: the boat and walking around on it.
