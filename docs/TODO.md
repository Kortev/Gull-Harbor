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
- [ ] **Crew jobs** (the TV-show bluefin boat feel: "FISH ON!"): the captain at the wheel backing down on the fish and keeping the stern on it, the mate wiring the leader, the harpoon ("the stick") from the bow or the cockpit to finish it, hauling it in through the tuna door in the transom.
- [ ] **The tally:** fish on deck and in the hold, weight, money for the trip: sold by the pound, graded on how it was handled (fought fast, bled, iced).
- [ ] **Title screen**, and a day going by (dawn, day, dusk, night) instead of the dev-only `--night`.
- If the router won't open the port (UPnP off, or the internet provider shares one address between homes): a relay. The free way that needs no server of our own is Steam's (both just have Steam open); otherwise Tailscale.
- Later: **VS mode** (two boats on the same sea, the most pounds by the end wins); Steam lobbies and invites; proximity voice; trips cost money; a rounds structure; upgrades.
