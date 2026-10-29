# While you were away (newest first)

## Your answers (thanks!)
- Steam's relay: yes, as the main way to play together (the join code stays as the backup). In progress.
- The boat: my call. Stretching it to about 46 ft with a wider cockpit. In progress.
- `main` is now the tuna game; the old Gull Harbor game is gone from it. A leftover `bluefin` branch (an older
  copy of the tuna game) is still there: I wasn't allowed to delete branches from here, so delete it on
  GitHub (Branches, the trash icon) whenever.

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
