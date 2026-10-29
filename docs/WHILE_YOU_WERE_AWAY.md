# While you were away (newest first)

## Question for you (blocking one TODO item)

**Should the big boat's captain lose the fish plotter?** The TODO says her captain "can't see the fish (no
plotter; someone calls it)". Right now, at the wheel with a fish on, both boats show a little plotter: the fish
round her and "Keep the stern on it!". Taking it off the big boat makes calling the fish ("it's off the port
corner!") a real job for the crew. Alone in the big boat, though, you'd be steering blind. My pick: keep it on the
skiff and take it off the big boat. Say yes and I'll do it, or say keep it.

## The live well and the fish box open

- **What:** both boats' fish box hatches and live well lids are their own hinged pieces now. The box lid swings
  up as a fish goes in, then shuts. The well lid opens whenever a mackerel goes in or comes out, and when you
  press E on it ("Look in the live well (5 mackerel)"). Inside it, dark water with the mackerel slowly circling,
  one for each you have. The chum bucket moved off the well lid (it'd fall off) onto the deck beside it.
- **Checked:** `tests/lids_test.tscn`, on both boats:
  - both lids are there, and the box lid opens and shuts around a fish going in;
  - the well lid opens on a new mackerel, and the right number swim in it;
  - the prompt and crosshair work, and the free edge swings up, not down;
  - the chum bucket sits on the deck within reach.

  All the other tests still pass. Screenshot: `docs/shots/live_well.png` (the skiff's well, open).
- **Try:** jig a few mackerel and watch the well; ice a tuna and watch the hatch.

## The outriggers fish now (the big boat)

- **What:** the sportfisher's two wide lines run from the rod tips up to a release clip near each outrigger's
  end, then out to the baits, held wide of the wake, like a real one. When a fish hits one, the line pops out of
  the clip with a snap and comes straight to the rod. The spare rod holders stay: they're small, and real boats
  have empty ones.
- **Checked:** `tests/rods_test.tscn` (the wide lines go through the clips, high and out to the sides; a strike
  pops one out). Screenshot: `docs/shots/outriggers.png` (from astern).
- **Try:** watch the wide baits from the cockpit, and listen for the pop on a strike.

## Dale talks on the radio now

- **What:** when Dale from the bank calls with a tip, you now *hear* him, from the radio on the dash by the
  wheel: a crackle of static as he keys the mike, then a man's voice talking over VHF hiss, then static as he
  lets go. It's a made-up voice (buzzing vowels, his pitch wandering, phrase by phrase): you can't make out the
  words, just like a real boat radio, and the card on screen still says what he said. Further from the dash he's
  quieter. It's made as it plays (no recordings), and costs about 2% of a CPU while he talks.
- **Checked:** `tests/radio_test.tscn`:
  - the tip's voice comes from the dash by the wheel;
  - 20 words take about 8 s to say;
  - there's static, talking and breaths between phrases;
  - it's fast enough.

  Listen to a sample: `docs/sounds/dale_on_the_radio.wav`.
- **Try:** Esc menu, "Have Dale explain it all again", and stand by the wheel. If the voice sounds bad, say so: it's
  easy to change (or to swap in real recorded lines later).

## Grab a drink from the cooler (the big boat)

- **What:** E on the cooler by the sportfisher's wheelhouse. You crack a can and take a long swig (your crew see
  you tip it back), and the screen says what you got, e.g. "Bilge Brew Root Beer. You don't want to know where
  it's made." There are 8 made-up drinks. It's just for fun and does nothing to the fishing. Not with a rod or
  the harpoon in your hands. (The skiff's cooler is the seat in front of her console.)
- **Checked:** `tests/chair_test.tscn`:
  - you can see the cooler from the cockpit;
  - E plays the swig and shows one of the drinks;
  - there's no prompt with a rod in your hands.
- **Try:** offer your friend a Sea Mist mid-fight.

## Sit down: every seat on both boats works

- **What:** press E on a seat to sit and watch the baits; E or Q gets you up. Your crew see you sitting.
  - **Skiff:** the cooler seat in front of the console, and the leaning post behind the wheel (you lean on it).
  - **Sportfisher:** the skipper's seat and the bench to port, two places on it.

  It uses the same code as the fighting chair. Only the chair has a gimbal, so only the chair spares your arms
  in a fight.
- **Checked:** `tests/chair_test.tscn` now covers every seat on both boats. For each: you can see it from a step
  away, E sits you, E gets you up and you can walk off. The skipper's seat doesn't hide the big boat's wheel from
  the cockpit. Every other test passes. Screenshot: `docs/shots/bench.png` (from the bench).
- **Try:** sit on the bench with a friend at the wheel while you wait for a bite.

## The fighting chair works (the big boat)

- **What:** E on the fighting chair in the sportfisher's cockpit sits you down. With a fish on, take the rod first,
  then E on the chair ("Fight it from the chair"). The rod's butt goes in the gimbal, and you crank and pump as
  usual. Your legs and back take the weight, so your arms tire half as fast. The catch: you're stuck on her
  centreline and can't walk the rod to a corner to keep the line off the hull, so the captain has to keep the
  stern on the fish. The chair turns with your look, and you sit lower. Without a rod it's just a seat, to watch
  the baits. E or Q gets you up (the rod stays in your hands). Your crew see you sitting.
- **Checked:** `tests/chair_test.tscn`:
  - you can look at the chair from the cockpit, sit, can't walk, the chair turns with you, and you get up again;
  - with a fish on, you fight from the chair with the rod in the gimbal;
  - the same 10 s of cranking a giant costs 13% of your arms standing and 6% in the chair;
  - the skiff has no chair.

  All the other tests pass, including the network test. Screenshot: `docs/shots/chair.png`.
- **Also fixed:** a check I added to the landing test last run only worked if the fish came up on the starboard side.
- **Try:** in the sportfisher, hook one, grab the rod, sit in the chair and fight it while a friend drives.

## Green water: big seas come aboard in a storm

- **What:** in heavy weather or a storm, a crest now and then tops her rail. Where it does, a sheet of white water
  bursts in over the rail with a crash (the wave and spray sounds), and the deck streams with foam running aft
  for a few seconds. Both boats; the skiff's rail is lower, so she takes more of it.
- **Checked:**
  - `hull_test` now also checks that a sea comes aboard whenever one really tops her rail, and never otherwise.
    In a test minute that was 2 times in a storm, once in heavy weather and never when sunny.
  - Screenshot: `docs/shots/green_water.png` (forced with the new dev flag `--green`).
- **Also:** on the big boat, the "find the birds" tip now says to climb the tower. It was too long and ran off
  the screen; that's fixed too.
- **Try:** wait for (or Esc-menu into) a storm and stand at the rail.

## Climb the tuna tower (the big boat)

The tower on the sportfisher was just scenery; now you can climb it.
- **How:** walk to the ladder at the back edge of the roof over the wheel and press E. You're up top, about 5.5 m
  over the water. You can look round but not walk. E or Q climbs back down. Not with a rod or the harpoon in
  your hands.
- **Why go up:** through the binoculars you see what the birds are doing at any distance, but you can only see
  *what's under them* (bluefin busting, or gulls on little bait) when you're close enough. That depends on how
  high your eyes are, like the horizon: about 1.2 km from the deck, about 2 km from the tower. Further off it
  says "Birds diving on something, too far off to see what's under them". So on the big boat someone up the tower
  can tell the captain which flock is worth the run. The skiff has no tower, so you get closer instead.
- **Checked:** `tests/tower_test.tscn` (the ladder in reach from the cockpit, up, can't walk off, the reading
  distances, down again, not with a rod in hand, no tower on the skiff). Every other test still passes.
  Screenshots: `docs/shots/tower_ladder.png`, `docs/shots/tower_view.png`.
- **Try:** buy the sportfisher, head out, climb the ladder, hold B and sweep the horizon.

## The small boat works, start to finish (tested in Godot)

The skiff had never been fished from. Now the tests run a whole fish on her, and it all works:
- **Fight:** a 161 kg fish fought up alongside from her in about 2.5 minutes (`strike_test -- --boat=skiff`).
- **Boatside:** no wiring over her low side, so the first good harpoon throw sticks. You haul it up over the
  gunwale (about 10 s alone), it lands on her deck, and you bleed it and ice it (`landing_test`).
- **Alone:** with a fish on, you put the rod in its holder. The wheel is within reach of the rod corner, she turns
  fast (about 1 rad in 1.5 s), and it's 1.5 s back to pick the rod up again, fish still on (`helm_test`).
- Screenshots of how it looks now are in `docs/shots/now_start.png` and `docs/shots/now_outside.png` (both on the
  skiff).

## It runs: the first time in Godot since the moving boat
The last session couldn't run Godot, so a lot was "not run yet". This session can, so:
- **Everything imports and every test passes:** fight, strike, rods, landing, wait (chum, baits, jig, the quota),
  sail (the moving boat), helm, deck, hull, look, weather, codes, Steam, and the two-copy network test (including
  the rod hand-off). No script errors anywhere.
- **One real bug fixed: the tuna door.** Holding E on the door stopped the haul after half a second, because the
  deck's roll slid your crosshair off the door's edge. Now you keep hauling while you hold E, stay near the door
  and roughly face it.
- **Tests brought up to the rules:**
  - The strike test clears the other lines before fighting (a running fish tangles them now).
  - Alone, a giant only has to be harder, not hopeless.
  - The hand-off test checks the skiff's second rod.
  - In the hull test, a storm crest now slops up to 0.67 m over the sportfisher's rail for a second. The limit
    was 0.5 m; I raised it to 0.75. The sea's clock starts somewhere else now, so the test catches a bigger crest.
    That's green water, which is meant to happen in a storm.
- Screenshots of how it looks now: `docs/shots/now_*.png`.

## A first step off the PS1 look, and the handoff to a local session
**Not run in Godot yet. Read `docs/HANDOFF.md`.**
- The PS1 screen filter's off (pass `--screen=psx_360` for it back), textures filter smoothly, the light's ACES
  with more colour, bloom and ambient occlusion, the sky's smooth, the water's teal with crests that glow where the
  light comes through, glossy, with soft foam.
- The boats are repainted in clean rich colours (the skiff cream with a teal stripe and a navy T-top; the
  sportfisher a navy hull, teal stripe, teak trim), edges rounded; the deckhand has a face (eyes, brows, a big
  nose, a beard), cartoon proportions, rounded pieces; the bluefin is smooth-shaded.
- **Still not the look you want** (it's still built from boxes). The handoff explains the way there: proper
  sculpted or generated models, hand-painted textures, a rigged crew; and your Chekhov's gun rule (the chair).

## Animation: the crew move like people, and you see the fish
**Not run in Godot yet.** Open the editor once first: `crew/crew.glb` changed (re-import).
- **The crew have elbows and knees now** (`art/crew.py`: forearms and shins are their own pieces) and a proper pose
  for everything, seen by everyone: walking and running (knees bending, a bob, the torso twisting), standing easy
  (breathing, knees soft), a rod in your hands (leaning back into it, braced, the reel arm going round while you
  crank, rocking back and dropping as you pump), at the wheel (hands working it as she turns), the harpoon cocked
  over your shoulder and the throw whipping through, binoculars up with elbows out, hauling (leaning back, hand
  over hand), working the jig, a scoop of chum flung over the side, down on a knee to bleed a fish, reaching for a
  rod, and losing your feet when a big sea throws the deck about.
- **The fish you're fighting shows:** the strike's an explosion of white water at the bait, it boils the surface
  when it takes off on a run, slaps it in a head shake, and in the death spiral it's right up under the surface,
  circling, its back and tail breaking the water. A fish alongside still kicks, thrashing the water now and then
  till it's stuck.

## Dale from the bank, the owner's manual, and a clearer end of the fight
**Not run in Godot yet.**
- **Dale** (the bank's loan officer) comes on the VHF the first time each thing happens: heading out, your first
  flock in the binoculars, coming up on birds too fast, the first bite, the first fight, fishing alone, at the wheel,
  the other lines, the death spiral, the fish alongside, on deck, a washed-out bait, a long quiet spell. Once each,
  remembered on your machine (`ui/tips.gd`).
- **The owner's manual** (Esc, "The owner's manual"): every rule in ten short chapters, and a button to have Dale
  explain it all again (`ui/manual.gd`). `docs/FEATURES.md` has the full list; `docs/VISION.md` keeps your words on
  what the game's meant to be.
- **The end of the fight:** the death spiral's two halves are spelled out and coloured: green "it's coming up.
  CRANK!", amber "it's going under her. EASE OFF". Inside 40 m the readout counts the metres to boatside. Danger
  lines (under the boat, out of gear) are red.
- **The dock** says the stakes plainly: "Sell $X more by the end of day 3, or the bank takes the boat."

## The hunt, the baits on the water, and the quota
**Not run in Godot yet.** `tests/wait_test.tscn` covers the new rules.
- **The quota** (Lethal Company's): the bank wants a sum within three trips (one a day). Every fish you sell counts
  toward it and goes in the bank to spend. Make it on the third day's sale and the next one is half as much again
  ($5,000, $7,500, $11,000, ...). Miss it and the bank takes the boat: the slip tells the run's story and you start
  over with the skiff and $1,000. The tally out there shows the day, the quota and what's aboard. The sportfisher's
  $20,000 now (a mid-run upgrade).
- **Finding them is a hunt now.** Flocks turn up 0.8 to 2.6 km off, and you can actually see them: a far flock is
  drawn as a speck you can pick out on the horizon (it was smaller than a pixel before; that's why you saw none).
  **Hold B (or the middle mouse) for the binoculars:** put a flock in the middle and you see what it is. About a
  third are only gulls over little bait, no tuna (don't waste the run). Bluefin come up and go down in spells of
  about 40 s at a time: birds diving on white water means they're up; birds sitting on the water means they're down,
  wait. **Left click calls it:** a mark on the radar for everyone and "Yellow: Birds! about 1.4 km off the port
  bow". The radar now only paints birds in the air (sitting birds don't show) and can't tell gulls from tuna birds.
- **Coming up on them:** run over a school faster than about 10 knots and it goes down (now you're told: "You ran
  right over them!"). Get within about 160 m, slow to trolling speed, and the school finds your baits and works
  round them, following as you troll.
- **Baits on the water:** each line now ends in a lure you can see (a live mackerel's dark). They're towed for real:
  dragged along behind the rod tip, held out to the side while she's moving, swinging wide round her turns,
  carrying on and dropping back when she stops (the line goes slack and droops), riding the swell, skipping along
  the top at speed. Lines droop a little always and a lot when slack.

## Things to do while you wait, crew jobs, sounds, and fixes
**Not run in Godot yet.** New test: `tests/wait_test.tscn`.
- **Chum** (`boat/chum.gd`): a bucket on her transom (24 scoops a trip). E throws a scoop: a splash astern and a
  brown slick spreading on the water. The slick sinks back through the baits, and a school within about 450 m of
  it comes up it and stays there working while you keep the chum coming (a scoop a minute or so); new schools turn
  up nearer it too. So you can sit on a spot and bring them to you instead of chasing birds.
- **Baits go off:** a dead bait's no good after about 5 minutes (a live one 10); a washed-out bait gets a quarter
  of the bites. The HUD tells you when one's gone ("The port corner bait's washed out"); E on that rod reels it in
  and puts a fresh one out a few seconds later (E on a fresh one still picks the rod up).
- **Live bait and the jig** (`boat/jig.gd`): the live-bait well now holds mackerel: four aboard each trip, up to
  eight. Baits go out live while there are any (half as many bites again, and they last twice as long). Run low?
  Hold E on the light jig rod in the gunwale (slowed right down) and a mackerel comes up every few seconds, into
  the well. The tally shows the chum and live bait left.
- **Crew jobs:** while a fish is on, the other lines can tangle in it (a running fish crossing one): E on each other
  rod reels it in ("clear the lines"); a tangle left alone saws the line through. On the sportfisher a fish
  alongside must be wired (someone holds E at the tuna door: grab the leader) before the harpoon will stick it; the
  skiff's low enough to reach it as it is.
- **Sounds:** the harpoon's throw and stick, wiring, the fish coming aboard, bleeding (a wet slap), the fish box
  lid, the till at the sale, the chandlery, lines reeled in and out, tangles, chum, mackerel.
- **Fixes from a review:** nothing bites at the dock any more (fish were biting while you sat on the dock screen);
  heading in cuts loose whatever's on and the baits go fresh when you head out; a friend joining no longer loses
  track of who has the wheel; leaving a crew puts you at the dock on your own boat with the mouse free; tests use
  their own save, never yours; the net test works on the skiff; the skiff's fish is lifted over the gunwale (it
  went through the hull), and lightning goes for her T-top.

## The skiff, the dock and the day, gear, and a real crew
**Not run in Godot yet.** Open the project in the editor once before running anything: it has two new models to
import (`boat/skiff.glb`, `crew/crew.glb`). Blender works in this session now (its Python module, rendering on the
CPU), so the new art was checked in renders before it went in.
- **The skiff** (`art/skiff.py`): a 28 ft center console for one or two. Two rods in the aft corners, the wheel on
  the console a step away, quick and nimble (she turns 0.75 rad/s and stops short), lively in a sea. A stuck fish
  comes aboard over the gunwale at her stern quarter instead of through a tuna door; her fish box takes two iced.
- **The dock:** a game starts there (the menu). The last trip's slip, the bank, the boats (the skiff's yours; the
  sportfisher is $30,000, or $2,500 a day to charter), the chandlery, and Head out. Picking a boat puts her in the
  water right there. Crewmates see the skipper's choices.
- **The day:** dawn to dusk in 20 minutes, then night. The light and the sun go with it (warm at dawn and dusk), the
  boat's lights come on at dark, the clock's top left, and you get a word at dusk and at dark. Head in whenever
  (Esc): the catch sells, fuel comes off ($60 the skiff, $400 the sportfisher) and any charter, back to the dock.
- **Gear** (the chandlery, once each, kept): a two-speed reel (winds a quarter faster, $3,000), heavier line (half
  again on the hull and longer at full strain, $2,000), a live-bait well (live mackerel: see above, $1,500), a
  fighting harness (arms tire a third slower, $2,500).
- **The crew** (`art/crew.py`): a deckhand in oilskins, a navy hoodie, a red beanie, shades and stubble, orange
  gloves, white deck boots, each crew member's oilskins their own colour (yellow, orange, green, red). Legs and
  arms swing as you walk, arms out to the rod or the wheel, the throwing arm up with the harpoon, the head with
  your look.
- **Boats as kinds** (`boat/kinds.gd`): everything about each boat in one place (her model, size, rods and baits,
  the harpoon, where fish come aboard and lie, her fish box, her handling, fuel and price), so a third boat is one
  more entry and a Blender script.

## Tired arms that don't stop you, and the fish under the boat
**Not run in Godot yet.**
- **Tired arms only slow you down now.** They used to stop you pumping at all, so alone you had to stand and wait.
  Now tired arms reel slower and pump weaker, but always work. And they tire mostly from fighting it wrong:
  cranking against a run costs about four times what cranking a resting fish does, and pumping a deep fish
  properly costs little. Fight it right and you barely notice them. Nothing changes with how many are aboard.
- **Solo is possible now without breathers** (the Python copy, fought right, from the middle of the cockpit):
  300 kg, 18 of 20 landed in about 10 minutes; 450 kg, 13 of 20 in about 13. With a captain it's still 2 to 3
  minutes, so a crew is much easier.
- **The fish under the boat:** the moment it goes under her, the hint says "It's under the boat! No throttle:
  steer her stern round to it (A/D)", and the captain sees "It's under her! Out of gear: steer her stern round to
  it, A/D only". Steering never cuts the line; only the throttle does. If anyone touches W or S while it's under
  her, everyone gets "OUT OF GEAR! It's under the props!" and has a second and a half to let go (was half a
  second).
- `tests/fight_test.tscn`: "two anglers taking turns beat one" is now "taking turns is never slower" (fought right,
  arms barely tire any more).

## She really moves, and birds anywhere
**Not run in Godot yet** (same as below). Pull the branch and try `tests/sail_test.tscn` too.
- **Driving her:** take the wheel (E). Hold W and she gets going, about 20 knots flat out; let go and she carries
  her way and slows; hold S to back down; A/D steer. The bottom of the screen shows knots and the throttle.
- **The sea stays put,** she moves across it. The ocean's mesh follows you so there's always water, but every wave
  belongs to the world, so two boats will share one sea (the VS mode needs that).
- **You can feel it:** the engines rise with the throttle, she leaves a wake, white water boils astern when the
  screws bite, her bow lifts and throws spray at speed, and backing down hard the sea slops over the transom.
- **Finding fish:** birds turn up anywhere round her, up to four schools at once, from a couple of hundred metres
  to about a kilometre off. Each feeds on and off for a few minutes, then the birds lift and scatter. The dash
  radar shows them as blips out to 1.5 km. Run to them, slow down under 12 knots so the baits swim, and troll
  through. Run straight through a school fast and it goes down for 40 s.
- **In a fight,** her real motion counts: backing down onto a fish closes on it, running away pays out line.

## Why you lost that fish at 30 m (and how the game tells you now)
- It almost certainly wore the line through on the hull: when the fish swings forward of her side, the line lies
  along the hull and wears every second. The game only warned you once it was rubbing hard, never showed how
  worn the line was, and the message didn't say what to do.
- **Now:** an earlier warning, "The line's rubbing the hull! Take it to the port corner, or swing her stern to it";
  the line's wear under the hint ("line 40% worn", red past half); and every way of losing a fish says why and
  how to avoid it ("...It swung forward of her side: take it to that corner, or swing her stern to it.").

## The whole loop: hooked, fought, stuck, aboard, sold
**Not run in Godot yet.** This session couldn't get Godot (its download sites are blocked here). Every script was
checked with a GDScript parser (gdtoolkit), the fight rules in a Python copy of `tuna/fight.gd`, and the code by two
independent reviews. It's on the `claude/zealous-mendel-h2udij` branch, not `main`. Run the tests below once in
Godot before merging.

**How a catch goes now:**
1. **A bite, the fight** as before, until the fish is beaten and close.
2. **Boatside:** it lies on the surface just astern. "Boatside! Stick it: the harpoon's along the port side."
3. **The stick:** E on the harpoon lying along the inside of the port side. Look at the fish and left-click to
   throw. A miss comes back to its rack on its line; try again. Q puts it back. You can't hold a rod and the
   harpoon at once, and the captain can't take it.
4. **The haul:** hold E on the tuna door in the transom (on the fish's side of the live well). Alone, a 100 kg
   fish takes 7 s and a 400 kg giant about 22 s; each extra pair of hands adds the same again. It comes up through
   the door as you haul.
5. **On deck:** it lies across the cockpit. E bleeds it (a pool of blood under it), E again ices it into the fish
   box.
6. **Sell:** Esc, "Head in and sell the catch". The slip lists each fish, its grade and price, the total and the
   bank. "Head back out" starts the next trip.
- **Don't dawdle:** leave a fish alongside unstuck for 90 s and the hook pulls.
- **Grades:** a fish is graded #1, #2 or #3 from how fast it was landed for its size, how soon it was bled and
  how soon it was iced. One still on deck when you head in sells warm, for less. A #1 200 kg fish fetches about
  $4,500; a #3, slow and left warm, about $2,550.
- **The tally,** top left: the hold, the deck, the weight, what it's worth now, and the bank. The bank is saved
  between games (the host's).

**Fixes from a review of the fight changes:**
- A fight that ended just as the rod changed hands was ignored by the host, so the host and that player disagreed
  for good. It now counts from whoever held it last.
- A fish in the holder lost the hook whenever she backed down at all; now only when she backs down onto that fish.
- Backing down won line on a rod nobody held (nobody's winding in the slack), so a fish in the holder could come
  boatside on its own. Not any more. And in the holder only its runs tire it.
- The drag scream stuttered on a crewmate's machine (their updates come ten times a second); it's smoothed.
- Handing the rod off reset the strain and the break timer (a cheap escape) and could turn a spiral the other way
  round; both carry over now.
- In the spiral, the "line's on the hull" warning hid the crank and ease hints a third of every lap, and wore the
  line through. Deep under her the line goes down steep and only brushes the hull now. The captain sees the spiral
  hint first.
- The strike test's angler never rested, so with spent arms it could never pump a far-off beaten fish in; it takes
  breathers now, like the hint tells you to.

**Fixes from a second review, of the landing and the catch:**
- Leaving a crew kept the host's bank, and your next sale saved it over your own. Now leaving (or the host going)
  puts you back on your own boat with your own bank. A host who leaves keeps their own fish; only crewmates' hands
  come off the rods, the harpoon and the door.
- When the host dropped, a fish alongside left your rod dead for good. Your rods are cleared now.
- With the rod still in your hands, the harpoon rack did nothing and didn't say why. It now says "Put the rod back
  first (Q)", and so does the hint.
- The harpoon holder could take the wheel and keep the harpoon there. Not any more.
- A rod whose last fish is still astern on the harpoon can't take another bite till that one's aboard (it used to
  wipe out the stuck fish).
- Fish on deck no longer lie through the live well or in front of the tuna doors; a fifth goes on the pile.
- The "Sold" note now shows for the skipper too; late joiners don't get old "Boatside!" notes again.

**Tests to run in Godot:**
- `tests/landing_test.tscn` (new): alongside, the harpoon rules, a miss and a hit, that you can put the crosshair
  on the rack, the tuna door and a fish on deck from the cockpit, that holding E hauls and letting go stops, the
  haul's time, bleed, ice, sell, the slip, back out, the grades, and the hook pulling. It keeps its bank in a test
  file, not yours.
- `tests/strike_test.tscn`: now fights to "alongside, ready for the harpoon".
- `tests/fight_test.tscn`, `tests/rods_test.tscn`, `tests/helm_test.tscn`, `tools/net_test.sh`.

## The death spiral, only close in (from your third playtest)
**Not run in Godot yet** (same as below: checked in a Python copy of the fight; on the working branch, not `main`).
- **Why you spiralled from 60 m out, from halfway through:** a fish is tired out about halfway through the fight's
  time, usually long before you've won the line back, and from then on nearly every move it picked was a spiral,
  however far off it was.
- **Now a beaten fish far off stops running and circles slow and wide** ("It's circling! Pump"), with rests
  ("Crank"), giving line to the pump. It only goes into its death spiral within 30 m.
- **The spiral is the real thing:** deep under her, the same way round lap after lap, coming up as you win line.
  The hint follows the lap: "Crank, it's coming up" while it's astern, "Ease off, it's going under her" while it's
  forward (cranking then strains it and wins next to nothing). The line still rubs the hull on the pass under her,
  so the corner and the stern still matter. Whoever's at the wheel sees "Death spiral! Out of gear: it's going
  under her": in gear with it under her, the props cut it.
- **Alone with a giant your arms go,** and spent arms can't heave, so you can't pump. Ease off for half a minute
  and they come back; a hooked fish can't recover meanwhile, so a breather costs only time. The hint says so now.
- **How long it takes now** (the Python copy, 20 fights each, fought right, taking breathers when the arms go):

  | Alone | 150 kg | 200 kg | 300 kg | 400 kg |
  | --- | --- | --- | --- | --- |
  | From the middle of the cockpit | 20, 3.5 min | 20, 6 min | 15, 12 min | 11, 23 min |
  | From the fish's corner | 20, 3.5 min | 20, 6 min | 19, 12 min | 15, 22 min |
  | Corner, and running to the wheel when it rubs | 20, 4 min | 19, 6 min | 20, 12 min | 20, 22 min |

  With a captain: 150 kg about 1 minute, 300 kg about 2, 450 kg about 4. Alone a giant is a long, real fight
  now; a crew makes it quick.
- **Tests:** `tests/fight_test.tscn` adds a patient angler (breathers), checks that alone from the corner you land
  most giants and more than from the middle, and that no spiral starts further out than 30 m.

## The rod in the holder, the corner, and seeing your progress (from your playtest)
**Not run in Godot yet:** this session had no Godot (its downloads were blocked), so the fight rules were checked in
a Python copy of `tuna/fight.gd` and the GDScript only by reading it. It's on the `claude/zealous-mendel-h2udij`
branch, not `main`; play it once before merging.
- **A rod in its holder keeps fighting the fish on its drag.** It used to pour off 16 m of line a second nonstop, so
  every trip to the wheel lost a minute or more of cranking. Now the fish does what it does in your hands: it takes
  line on its runs (and tires doing it) and none between them. The host plays it and tells everyone.
- **A hooked fish never gets its strength back** (your second playtest: "that doesn't make sense"). With the line
  tight, in your hands or in the holder, doing nothing just doesn't tire it; only fighting it does.
- **The boat out-turns the fish** (also your playtest: the fish circled as fast as she turned, so you could never
  catch it up). A circling fish swung round her at up to 10 m/s; now about 5 m/s, a real circling giant's pace, and
  she spins half again as fast (twin screws, one ahead and one astern). A captain hard over always gains on it.
- **Picking the rod back up carries on the same fight:** the same move the fish was on (no more "always circling"
  when you come back), and your arms as tired as you left them (they used to reset every time you grabbed it).
- **The corner works:** stand aft at the rail on the side the fish is on and the line stays off the hull longer.
  The note further down said this was in, but nothing ever set it. When the line's on the hull the hint now says
  which corner to take it to.
- **Backing down actually works in the game.** The captain's throttle never reached the fight (only the test set
  it), so backing down did nothing while you played.
- **You can see progress:** under the hint, "84 m out · gaining · fish tiring", green while you're winning line, red
  while it takes it.
- **Pump hints:** "Pump it up" and "Pump" were the same thing; both now say "Pump: heave, then crank down".
- **Fixed:** "FISH ON! The port corner rod!" named the wrong side (rod 0 is on the starboard corner).
- **What it does for solo** (the Python copy, 20 fights each, fought right; landed, and the usual time):

  | Alone | 150 kg | 300 kg | 400-450 kg |
  | --- | --- | --- | --- |
  | Before all this, any way | 20 of 20, 2.5 min | 0 | 0 |
  | Now, from the middle of the cockpit | 20, 2.5 min | 11, 7 min | 11, 12.5 min |
  | Now, from the fish's corner | 20 | 14, 7 min | 13, 11.5 min |
  | Now, corner, and running to the wheel when it rubs | 20 | 20, 7.5 min | 20, 12 min |

  With a captain: 300 kg in about 2 minutes, 450 kg in about 4. So alone you can land a giant now, but it takes
  the corner and runs to the wheel, and it's a long fight; a crew makes it quick.
- **Tests:** `tests/fight_test.tscn` now also checks that a fish in the holder takes no line between its runs and is
  still on after 30 s, that the corner lands more giants alone, and that a picked-up fight carries on its move. Two
  old checks were loosened to match: "alone, a giant gets away" now only for 400 kg and up, and the props check runs
  40 blind fights instead of 20.

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
