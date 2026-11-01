# Gap audit (2026-11-01, at 33f7651)

What's missing before Bluefin is complete, judged against the house rules: hands on, not automated; everything
animated; physics, not modes; the fight stressful every time; show, don't tell; pixel style; lived in; Rivals fair.
Ranked by how much each one makes the game feel full.

## Top gaps

1. **The harbour is a backdrop with a menu over it.** The pier isn't walkable, and the shops (sea/harbour.gd:366-395) are only facades. Buying, picking a boat and casting off are all buttons (ui/menu.gd:336-495). → A walkable pier and quay, with the menu turned into places: the chandlery counter, the broker's board, the buyer's shed.
2. **Selling happens by itself on tying up** (boat/fish_hold.gd:621-637). → Hoist each fish onto the buyer's scale by hand; the buyer cores it, grades it and calls the price aloud.
3. **Docking is automatic.** The boat eases onto the berth (sea/sea.gd:279-317) and there are no lines. → Throw the dock lines and make them fast on cleats; cast off by hand.
4. **Two things teleport.** The menu's "head in" cuts to black at the berth (sea.gd:348-370), and so do Rivals' next day and the late tow. → A real run home, or a visible tow.
5. **Dock prep is automatic.** The slip says "FUELLED, BAITED, READY". → A short hands-on loadout: shovel ice, run the fuel hose, load the bait totes. It's per mode, set in the match settings.
6. **The helm is a mode.** Holding W/S works the throttle and it springs back when let go (boat/helm.gd:2-7). → Throttle levers that stay where they're set, a key start, a fuel gauge, and the wheel turned with the mouse.
7. **Nobody lives in town.** There are no people, no boats coming and going, and no harbour sounds. → NPCs, boat traffic, and a harbour sound bed (bell buoy, halyards).
8. **No other boats at sea.** → An AI fleet working the flocks, with VHF chatter.
9. **Progression runs out early.** There are two gear items and two boats. → Gear tiers, paint and boat names, and later boats.
10. **No footsteps or body sounds.** → Footsteps for each surface (deck, teak, pier), creaks, and a sound when you land.
11. **Sound effects are borrowed from a space game.** The harpoon uses "brine.gust" (tuna/landing.gd:823), and "dock.slap" is used for everything. → Real gaff, knife, harpoon, cast, line and lid sounds.
12. **Landing is still hold-E**, and the harpoon goes back to its rack by itself (landing.gd:4-16). → Wrap the wire hand over hand, pull in the harpoon line, and haul the fish aboard in rhythm.
13. **Lights switch themselves, and the radar and plotter have no knobs.** → Dash switches, plus range and gain knobs.
14. **Night has nothing to do.** → Night bites, squid under the floods, fog, and other boats' lights.
15. **Fish sizes are flat and the fish have no personality** (tuna/schools.gd:366). → A realistic size curve with rare giants, and fish temperaments (jumper, sounder, bulldog).
16. **The crew have no skeleton, emotes or customisation.** → A rigged character, emotes (wave, point, cheer, facepalm), and looks to pick.
17. **No crew call-outs** (crew/voice.gd only has gasp, grunt and blow). → Barked calls like "FISH ON!" and "GAFF!".
18. **No comfort or accessibility settings.** → Camera sway and shake reduction, a colourblind palette, text scale, and hold-or-toggle choices.
19. **No graphics quality presets or min-spec.** → Low, medium and high presets, measured with tools/perf_probe.gd.
20. **Teaching relies on text.** The manual is ten chapters, and the fight tutor freezes the fish. → Dale and the world teach instead; the manual becomes a book you can pick up.
21. **No sharks or bycatch.** → Rare shark hits during the fight, and blue sharks stealing baits.
22. **No weather forecast and no weather events.** → A dawn forecast on the VHF, and squall lines and fog banks that roll in.
23. **Few ways for things to go wrong.** → A life ring for man overboard, engine trouble, running aground, running out of fuel.
24. **Rivals fairness holes.** There's only one chum slick, so one boat's scooping erases the other's slick. Schools spawn on alternating timing. → A slick per boat, schools spawning symmetrically, and a latency check.
25. **Co-op days end flat.** → A co-op day card: the biggest fish, who fought it, who stuck it.

## Features to round out the game

1. A walkable Gull Harbor, with the buyer's auction on the scale.
2. A logbook and a trophy wall of record fish in the diner.
3. The 90s training tape playing on the shack TV, skippable.
4. A hired deckhand who takes a crew share and acts like a person.
5. Naming and painting the boat, with your gear visible on it.
6. An AI fleet, VHF chatter, and the coastguard.
7. The giant: a rare named fish, rumoured on the radio.
8. A man-overboard drill with the life ring.
9. A photo with the catch before the sale.
10. Seasons: a spring run of smaller fish, a fall run of giants.
