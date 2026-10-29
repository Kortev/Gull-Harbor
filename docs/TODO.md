# TODO (in order)

The game: a crew of 1-4 on one tuna boat, endless open sea, sometimes huge waves, catching as many bluefin as
they can. Creepy only from the sea and the weather; mostly action; very atmospheric. Real tuna only. Arcade
rules (physics only for the look). The boat never moves: it sits at the origin and rides the swell.

Each item: build it, check it (screenshots in `docs/shots/`), commit, push (branch `bluefin` of the Gull Harbor
repo until the new repo exists), tick it here.

- [x] **The sea:** Fathom's ocean, weather (calm, sunny, fog, rain, heavy, storm), sky, rain, lightning, the PS1 look.
- [x] **The boat:** a plain, weathered 41 ft tuna boat for four (`art/boat.py` -> `boat/boat.glb`, crunched CC0 photo textures): wheelhouse and hardtop, open cockpit, fighting chair, 8 rod holders, tuna tower, outriggers, floodlights; parked at the origin, heaving, pitching and rolling on the swell (`boat/boat.gd`).
- [ ] **Sea polish:** the small white squares scattered on the water, and the sawtooth facets on big swells in low sun.
- [x] **The crew:** a first-person player (walk, sprint, jump, look, E to interact) on the moving deck: you walk in the boat's still "deck space" and are carried by its pose, so nobody slides or jitters (`crew/player.gd`, `tests/deck_test.gd`).
- [ ] **Green water:** spray over the bow and crests slopping over the rail in a storm; the deck streaming.
- [ ] **Co-op:** host / join (ENet direct, then Steam lobbies), players spawn on deck, everyone sees the same sea.
- [ ] **The bluefin:** a tuna model (Blender), sizes 30-400 kg, how it swims.
- [ ] **Hooking up:** baits out from the stern holders, schools showing (birds, busting water, sonar marks), the reel screams, anyone grabs the rod.
- [ ] **The fight:** the arcade fish-moves fight (from Gull Harbor's fish_fight.gd) with tuna moves: the screaming first run, sounding deep, circling under the boat, the death spiral; pump and reel; big juice (camera, rod, sound).
- [ ] **Crew jobs:** captain at the wheel (keep the stern on the fish, chase it), mate on the leader, gaffer, hauling it over the rail.
- [ ] **The tally:** fish on deck and in the hold, weight, money for the trip.
- [ ] **Title screen and conditions per trip.**
- Later: trips cost money; a rounds structure; upgrades.
