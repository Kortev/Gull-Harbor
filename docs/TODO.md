# TODO (in order)

The game: a homemade take on the TV bluefin shows, for playing with friends (Jack first). A crew of 1-4 on one tuna boat, endless open sea, sometimes huge waves, catching as many bluefin as
they can. Creepy only from the sea and the weather; mostly action; very atmospheric. Real tuna only. Arcade
rules (physics only for the look). The boat never moves: it sits at the origin and rides the swell.

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
- [ ] **Green water:** spray over the bow and crests slopping over the rail in a storm; the deck streaming.
- [x] **The bigger boat:** 46 ft with a wider cockpit, so four of you and the fighting chair have room.
- [ ] **Crew jobs: why it takes a crew.** One person can't land a big bluefin alone; while the fish is on, everyone else has a live job that decides whether you land it, and each can rescue the others' mistakes:
  - **The captain at the wheel** (E on the helm, A/D to turn, S to back down): the tuna swings round the boat; let it get too far off the stern and the line rubs the hull (strain jumps), let it get under the boat and the props cut it. Backing down on the fish wins the angler line back fast and takes the strain off: the rescue when the angler's losing.
  - **The angler tires:** cranking and pumping drain your arms; tired arms crank slower and pump weaker, and a giant outlasts one person, so you hand the rod off mid-fight (anyone grabs it).
  - **Clear the other lines:** when a fish hits, the other baits are still out; a running tuna that crosses one tangles it (lost, or a fight with a tangle). Someone reels them in.
  - **Boatside, everybody:** one keeps the line tight, one grabs the leader (the wire above the hook: "wiring"), one throws the harpoon ("the stick"), then haul it in through the tuna door (a giant takes two or three pulling).
  - **After:** bleed it and ice it fast for a better grade, while the captain runs to the next birds.
  - **Solo** still works: you drop the rod in the holder to run to the wheel. It's meant to feel desperate.
- [ ] **The tally:** fish on deck and in the hold, weight, money for the trip: sold by the pound, graded on how it was handled (fought fast, bled, iced).
- [ ] **Title screen**, and a day going by (dawn, day, dusk, night) instead of the dev-only `--night`.
- [x] **Steam as the main way to play together:** host a friends-only Steam lobby, friends join from the menu's list or an invite, traffic through Steam's relays (`core/steam_link.gd`; needs the GodotSteam add-on from the AssetLib; `tools/steam_test.sh` against a stand-in for Steam). The join code stays as the backup.
- Later: **VS mode** (two boats on the same sea, the most pounds by the end wins); proximity voice; trips cost money; a rounds structure; upgrades.
