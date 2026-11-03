# Bluefin: everything in the game, and what the player needs to know

Every feature, in the player's terms, with the numbers that matter and the tip a player would need. Each section ends
with **Teach it**: what the game tells you today, and what it doesn't yet (the gaps the in-game guide and the
first-time tips must fill). Keep this up to date whenever something changes; it's the source for the in-game field
guide.

Status: everything below is in the code on `claude/zealous-mendel-h2udij`. Most of it has not been run in Godot yet.

---

## The game in a paragraph

A crew of 1 to 4 on a tuna boat, on an endless sea, owing the bank. Each **quota** is a sum to sell within **three
days** (three trips). Each day you run out, **hunt** for bluefin (birds working far off, checked through
binoculars), troll your baits through them, **fight** a fish that can weigh 400 kg, get it **alongside**, wire it,
**harpoon** it, **haul** it aboard, **bleed and ice** it, and head in to **sell**. Make the quota and the next one's
bigger. Miss it and the bank takes the boat, and the run's over.

## Controls

| | |
|---|---|
| W A S D | walk; at the wheel: throttle ahead / astern, steer |
| Mouse | look |
| Shift | sprint |
| Space | jump |
| E | use whatever's under the crosshair (pick up a rod, bait it, the wheel, the harpoon, the tuna door, the fish box lid); hold E for the haul, the wiring |
| 1-5, mouse wheel | what's in your hands: the knife, the gaff, the jig rod, the scoop, a bait (the same key again: empty hands) |
| Left mouse | with a rod: hold to wind up a cast, let go to cast; hold to wind the line in; with a fish on, crank. With the kit: use it (below). The harpoon: throw |
| Mouse, with a fish on | the rod: up and down lifts and drops it, sideways lays it over |
| Right mouse | raise the rod (with a fish on: heave it up, a pump) |
| Scroll, with a fish on | the drag, a notch at a time |
| Q | put the rod (or the harpoon) back |
| F | shove whoever's in front of you |
| Space, walking into the rail | up on it (her gunwale: stand there, walk along it, jump off it); sprinting, straight over: onto a boat lying alongside, or into the sea |
| Esc | the menu: head in and sell, host / join, Steam friends |

**Teach it:** the HUD prompt (an E key cap and a word or two: "Grab it!", "Bleed it") names every action under
the crosshair. Gap: no controls screen; the
binoculars and the pump are only in hints.

---

## The run (the quota)

- The bank wants **$12,000** in the first **3 days**, a sum sized for **two** aboard (the same alone: no discount;
  alone it's a stretch). Each quota made, the next is **1.4 times** as much: $12,000, $17,000, $23,500, $33,000, ...
- Every fish sold counts toward the quota **and** goes in the bank to spend.
- **Crew shares:** each crewmate aboard **past the second** takes **12% of the gross** of every fish sold, a
  "Share, <name>" line on the slip (the third and fourth aboard, by when they came aboard). Two keep it all; four
  catch more, but give a quarter of it away (`boat/fish_hold.gd`'s SHARE).
- The quota's settled at the **third day's sale**. Made it: the next quota, three more days. Missed it: **the bank
  takes the boat**. The slip tells the run's story (quotas made, fish, the biggest), and a new run starts with the
  skiff and **$1,000**, no gear.
- The best run (most quotas) is kept.
- Fuel comes off each sale: **$60** the skiff, **$400** the sportfisher. A chartered boat: **$2,500** a day.

**Teach it:** the dock screen shows QUOTA n: $earned of $quota, Day d of 3, a bar, and "$x more by day 3, or the
bank takes her". At sea, top left: the quota as a bar (what's aboard ghosted on), "$earned / $quota", "Day d/3", and
the fish box as pips (filled once iced, amber for one still on deck).

## The dock

**Gull Harbor** (sea/harbour.gd), 2.2 km astern of the grounds behind its two breakwaters: the quay, the **fish pier**
with the fish buyer's shed (GULL HARBOR FISH CO., its scale on a gantry), lamps along the pier (lit after dark), a
finger pier with three other boats on it bobbing, gulls on the pilings, lobster pots and fish totes on the quay. The
water inside the breakwaters is **still**; the swell dies away in the shallows along the coast (sea/ocean.gd's
shelter, the same in the shader and for everything riding the water).

- A game starts, and every trip ends, **tied up alongside the fish pier** at dawn, lines in.
- The menu, down the left with the harbour beside it: the last sale's slip, the quota, **Cast off** (the
  skipper's: the trip starts and you're at the wheel; take her out through the harbour mouth yourself), then the
  boats, the chandlery.
- **Coming in:** bring her back alongside her berth and stop: after 2 s she's tied up and the catch sells there.
  Or **Head in** from the menu anywhere: the screen cuts to black and fades up on her alongside the pier.
- The piers and the breakwaters are solid: into the pier is a bump; the breakwaters and the shore put her aground.

**Boats** (picked at the dock; everyone aboard gets the same):

| | The skiff (28 ft center console) | The sportfisher (46 ft) |
|---|---|---|
| Cost | yours | $20,000, or $2,500 a day chartered |
| Rods | 2 (the aft corners) | 5: two corners, two off the outriggers, the shotgun way back down the middle off a clip high on the tower |
| Fish box | 2 iced | 12 iced |
| Speed / handling | about 21 knots, turns quick, stops short | about 19 knots, slow to turn, carries her way |
| Landing | over the low gunwale: no wiring | through the tuna door: must be wired first |
| Lively in a sea | very | less |
| Fuel | $60 a trip | $400 a trip |

**Gear** (the chandlery; once each, for the run):

| | | |
|---|---|---|
| A two-speed reel | winds in a quarter faster | $3,000 |
| Heavier line | half as much again before the hull wears it through, and longer at full strain | $2,000 |
| A live-bait well | 4 live mackerel aboard each trip (up to 8), and keeps the ones you jig | $1,500 |

**Teach it:** each boat and item has a one-line blurb. Gap: the skiff vs sportfisher trade-off (crew size) isn't
said anywhere in game.

## A day out

- **Cast off** at dawn (5:30 am). The day runs to dusk (7:30 pm) in **20 real minutes**, then it's night.
- The light follows: warm at dawn and dusk, the boat's lights on at dark. A word at dusk ("Sun's going down").
- **Head in** whenever (Esc, skipper), or bring her alongside the fish pier: the catch sells, fuel and any charter
  come off. Heading in cuts loose anything still on a line or alongside.
- Nothing turns up or bites at the dock.

**Teach it:** the sun is the clock; a word at dusk ("Sun's going down").

---

## The hunt: finding bluefin

- **Flocks** turn up **0.8 to 2.6 km** off (the first a bit closer), up to 4 at a time, a new one every 30 s to a
  minute or so, each working for **6 to 12 minutes** before the birds lift and scatter.
- From far off a flock is a **speck on the horizon**. **Binoculars** (hold B) tell you what it is:
  - **Birds diving, white water busting under them: BLUEFIN** (they're up and feeding).
  - **Birds sitting on the water: the tuna are down.** They come up and go down in spells of about **40 s**:
    wait nearby and they'll come up again.
  - **Gulls picking at little bait, no big splashes: not tuna.** About **a third** of flocks are only gulls.
    Don't waste the run (and fuel's money).
  - Birds circling high: the tuna went down because someone ran over them.
  - Birds lifting and scattering: it's over, they've moved on.
- Through the binoculars you also get **how far and which way** ("about 1.4 km off the port bow").
- **The tower spotter** (the sportfisher): from the deck you can tell what a flock's on inside about **700 m**; up
  the tower, out to about **1.8 km**. And up there, crosshair on birds working over bluefin, you **shout it down**
  to the crew by the clock off her bow: "**BIRDS WORKING, TWO O'CLOCK!**" (once a flock; everyone aboard that boat
  hears it, and sees it under the crosshair). Where she goes is the spotter's call: the radar can't tell you.
- **Picking a flock out** (crosshair on it) puts a **mark on the chart plotter** where it is right then, for everyone
  aboard. The mark's on the dash. (Only the tower spotter calls flocks, above.)
- **The radar** (every boat: on the dash beside the plotter, a bar going round on her roof; `tuna/radar.gd`). Heading
  up, **2 km** to the edge, **rings every 500 m**, the sweep going round and each part of the screen holding what it
  last painted. Made honest, so reading it is a skill:
  - **Birds in the air** over a flock: a **tight return that holds steady sweep after sweep**, drifting slowly as the
    flock travels. **It shows birds, never what's under them**: gulls over little bait paint exactly like birds over
    bluefin. You still go and look, or send someone up the tower.
  - Birds **rafted on the water** (tuna down) and the odd **gull raft** with nothing under it: weak, coming and going.
  - **Buoys**: small steady returns that don't drift. **The land, the breakwaters and the rig**: solid. In VS, the
    other boat.
  - **Sea clutter**: speckle close round her, different every sweep, wider and thicker the rougher the sea (a few
    hundred metres on a sunny day, most of the screen's middle in a storm).
  - **Rain clutter** in rain, heavy and storm: patchy smears drifting down the wind, and the rain dims what's
    behind it. A flock still shows as the one spot that's there every sweep.
  - Strength reads as colour: green weak, yellow, orange strong.
- **The chart plotter** (every boat, beside the radar; `boat/plotter.gd`): **north up, centred on her**, 3 km to the
  top edge, a grid every km. The coast, Gull Harbor (an anchor at its mouth), the breakwaters and the fish pier, the
  lighthouse, the buoys and the rig; **her track this trip** as a red line; **a yellow mark wherever a flock was
  picked out** (where the birds were then: they move on; marks over 5 minutes old fade, and one off the chart sits
  at its edge). A new trip starts a clean chart.
- Everyone aboard sees the same screens: they're painted from the sea's shared state (the clock, the weather, the
  synced schools, the fixed landmarks), never dice. Both screens are big enough to read from the wheel.
- **The sonar** (the sportfisher's dash) marks fish right under her.
- **At the wheel running faster than about 12 knots you can't pick birds out** (eyes on the water ahead): whoever's
  on deck reads them and tells the captain. Ease her down to look for yourself.

**Teach it:** Dale's first tip ("Tuna feed under birds. Find a flock."). A flock under the crosshair reads one line
over the plotter's spot: far off "Birds   1.4 km off the port bow"; inside 700 m what they're on ("BLUEFIN!", "Tuna
down: wait", "Just gulls", "Scattering: moved on"). The birds themselves show it too: diving and white water, or
sitting.

## Working a school

- **A school travels its own way** (watch which way the birds go) **and feeds at its head**: only a bait out in front
  of it (from just behind its middle to about 35 m ahead of its edge, within about 16 m of its width) gets eaten. Your
  baits don't draw it to them; chum does (below).
- **Your baits trail behind you:** cut across ahead of it and drag the baits
  through its path, run alongside just ahead of it at its pace, or stop in its way and cast, and let it swim into
  them. Setting up the pass is the captain's job.
- **No bites above about 12 knots** (6 m/s): the baits skip along the top.
- A feeding bluefin school with a bait at its head eats it now and then (the reel screams). **Double headers:** with
  a fish on, another bait across the **same feeding school** still goes, at about **a quarter** of the usual rate,
  till the other lines are in (a stray loner hardly ever: 1.5%). Two fish on at once: one in someone's hands, the
  other fighting on its drag in its holder till a pair of hands is free for it.
- Working a chum slick (going nowhere) a school eats all round.

**Teach it:** Dale, as you near birds fast ("Ease her down to troll... drag your baits across their nose"); the manual's "Working a school".

## Baits

- Each rod's line runs back to a **lure** on the water (a live mackerel shows dark). Baits are **towed**: dragged
  along behind the rod tip, held out wide while she's moving, swinging round her turns, dropping back with the line
  slack when she stops, skipping along the top at speed.
- **You cast them** (rods/rods.gd). She heads out with every line in and a dead bait on each hook. E picks a rod
  up; **hold left mouse to wind up** (about a second for everything; a bar over the hotbar fills) and **let go to
  cast**: the bait flies out where you're looking, in an arc, **10 to 55 m** by how far you wound it, and lands with
  a splash. Then **Q** puts the rod back in its holder and it trolls from there, swinging in behind her as she goes
  (or keep it in your hands). Nothing bites in the air. With its line out, **holding left mouse winds it back in**
  (about 1.5 s).
- **A fish takes the bait.** After a fish (landed or lost) its line comes in with a **bare hook**: nothing bites
  that. **A bait in your hands (key 5), E on a rod** in its holder: its line comes in and a fresh bait goes on (a
  live mackerel while the well has one, else dead); then cast it.
- **Every bait out is a live mackerel** out of the well (a dead one off the ice when it's empty: a poor bait).
- **The well's pump** (beside the well, every boat): the well's water goes stale, and **a mackerel dies every 4
  minutes or so** (onto the ice) unless someone pumps fresh water in: **hold E on the pump**, its handle going up and
  down, a gush of water into the well each stroke. The water shows it: clear and dark fresh, murky green going
  stale. A job for the quiet stretches (the run out, the icing).
- **Baits go off:** a dead bait's washed out after about **5 minutes**, a live one **10**. A washed-out bait gets a
  **quarter** of the bites. You see it: the lure's colour goes. Rebait it as above.
- **Live bait** (with the live-bait well): **half as many bites again**, and lasts twice as long.
- **The jig** (the jig rod, key 3, slowed right down, under about 3 knots), at the rail with the rod out over the
  water: **left mouse** lets the jig go and it sinks; **taps** work it; a **knock** on the fall jerks the tip down
  and your view with it: **tap again within half a second** to set the hook, or it's gone; **hold left mouse** to
  wind it up, and a mackerel on comes up wriggling into the well (needs the well; it takes 8; without one it goes
  back).
- **Chum** (the bucket on her transom, **24 scoops** a trip): the scoop (key 4), **left mouse on the bucket** dips it
  full; **hold to wind up, let go to throw** (4 to 22 m, where you look; one every 1.5 s at most). The slick lays
  **where it lands**: put it among your baits. A school within about **450 m** smells it, comes up it and **stays
  on it, working, as long as you keep the chum coming** (a scoop every minute or so). New schools turn up near a
  fresh slick too.

**Teach it:** shown, not told: the lures on the water (bare, washed out, live), the hotbar's pictures, the wind-up
bar, the rod tip's knock. Gap: nothing says the kit is on 1-5 but the hotbar itself.

---

## The hookup and the fight

Rebuilt 2026-11-01 on how big-game tackle really works (tuna/fight.gd): it's tense every time because several things
press at once, and every one of them is read off the rod, the reel and the line, not a meter.

- **The strike:** the reel screams and the line pours off; the rod's slammed over in its holder, a hit-stop, the
  white water. **Anyone grabs the rod** (E); Q puts it back in its holder.
- **The rod's bend is the line's tension.** A strike drag is already a deep bend; past that it's the **creak** of the
  blank, the **line singing** higher and the **tip shivering** that say how near it is to going, and the screen's
  edges pulse red right at the edge. Slack, the rod springs straight and the line droops on the water.
- **The drag is a lever you set by hand:** scroll (pad: the bumpers), a notch at a time; it clicks, the strike
  detent clunks, the red-knobbed lever on the reel moves, and the little reel in the corner shows it on its quadrant
  (free, strike, full). A fish comes on at strike.
  - Too light and he takes everything. Too heavy and the hook tears out (hold him hard too long) or a kick of his
    tail parts the line (it sticks before it slips, and a short line has no stretch to soften it).
  - **It climbs by itself as the spool empties** (the line coming off a smaller spool), and a long fast run drags
    line through the water that pulls at his end too: on a long run, ease it off. At the leader, ease it off.
- **Line capacity:** 500 m. On a run the spool visibly empties (the line, then the white backing past half, then
  the bare metal arbor), the clicker ticks faster and the reel's note climbs. The crew shout "HALF THE SPOOL'S GONE!",
  "HE'S SPOOLING US! BACK DOWN!". The skipper has to **chase** (back down on him, S) or he spools you.
- **Pump and wind:** the reel can't wind against a fish that's pulling (it grinds). **Lift the rod slow** (mouse up,
  or right mouse) and he comes toward you, then **drop it winding** (left mouse) and the reel spins on the light line.
  Lift on **his tired moments** (the bend eases off, he's stopped pulling) and you move him; lift into his run and
  the drag just slips. **Winding against a run** gains nothing and **twists the line**: it parts later on a hard pull.
- **His nature and his phases:** a runner, a sounder (deep, long, the line going straight down), a bulldog (heavy,
  head-shaking) or a jumper (schoolies). The **first run** off the strike is blistering (a giant's takes a good part
  of the spool). Fresh, he runs, sounds, dogs and shakes his head; tiring, he circles deep, then close in his **death
  spiral** under the boat (wind as he comes up, hold as he goes down; kept tight, his laps come round off the stern);
  near the boat **sudden surges**; and when the **leader** comes up to the rod tip ("LEADER!"), **one last run**.
- **The hook:** held too hard too long it tears out; a **head shake on a slack line** shakes it out (never give him
  slack: wind when he comes at you, when she backs down on him); **tight while he jumps** throws it (drop the tip).
- **Hit and moment:** every time he takes off again, a beat of hit-stop, the rod slammed over, your view kicked
  (harder close in); the spray off the line where it slices the water, the line hissing; the fish rolling up on his
  side close in ("COLOUR!"). Lost: the line cracks (parted) or just goes light (the hook out), the reel goes dead
  quiet, the rod springs straight, the line falls slack, and the music drops away.
- **Your arms:** winding against a load, lifting and just holding a heavy fish take them; going, the rod **shakes in
  your hands** and you wind and lift slow. A giant spends a fresh pair: **swap on the rod** (E on a mate's rod takes
  it, fresh arms). Alone, **rest it in the holder** (Q): it fights on its drag as you left the lever, and nobody
  winds or wins line back; and with nobody on the rod, **on his runs he takes line nearly twice as fast** (the rod
  just bows to him: `tuna/fight.gd`'s HOLDER_RUN). Put it in between his runs, not during one.
- **The captain** (E on the wheel; A/D steer, W/S throttle) has a real job:
  - **Back down on him** when he's taken line (S): she closes on him, the line goes light and the angler winds like
    mad (back down too hard and it's slack: a head shake and he's off).
  - **Keep the stern on him.** Off the stern your pressure's sideways and moves him less; forward of her beam the line
    lies along her side and over her house or bow and **chafes through** (worn line is weaker, and parts on the next
    pull: "Line parted on the rail."). Swing her stern to him, or the angler walks the rod round to that corner.
  - **Under the boat:** out of gear. Touch W or S while he's under her and the props cut the line in 2.5 s.
  - The captain's plotter shows where each fish is (red where its line's on the hull).
- **Other lines:** while a fish is on, REEL THE OTHER LINES IN!; heading for one still out the warning names it;
  across it 3 s it tangles and saws his line through in 20 s unless someone winds that line in.
- **Taught in the moment, never frozen:** no cards over the fight. Dale on the VHF says each thing the first time it
  comes up (the bend, the drag slipping, cranking against him, half the spool gone, a jump, holding him too hard, the
  leader, tired arms), and the crew shout what's happening as it happens (rods/fight_calls.gd: every peer works it
  out from the rods' synced state, so everyone aboard hears it). A loss says why and what would have saved it.
- **How long, and how often you lose one** (tests/fight_sim.tscn, headless test anglers that read only the rod, the
  reel and the line; see its output for the full table): fought well with a captain who backs down and swaps on the
  rod, a schoolie about 1.5 min, 150 kg about 4, 300 kg about 8, 400 kg about 9 and nearly all landed; alone a giant
  takes 12+ min and you lose a fair share of the biggest.

**Teach it:** the rod, the reel and the line; Dale's lines and the crew's shouts in the moment; the loss reasons with
what would have saved each; the field guide's section 6.

## Boatside

- Beaten, the fish comes **alongside** astern.
- **On the sportfisher, wire it first:** someone holds E at the tuna door (grabbing the leader); it stays wired
  **15 s**. The skiff's low enough to reach it as it is.
- **The harpoon** (on the rack along the port side; E takes it, Q puts it back): aim and left click to throw. A
  throw at an unwired fish misses.
- **Haul it aboard:** hold E at the tuna door (or the gunwale). Alone a giant takes about **22 s**; each extra pair
  of hands adds as much again.
- Leave it alongside unstuck **90 s** and the hook pulls.
- **Someone has to hold it there:** the angler keeps the rod (E on a rod whose fish is alongside: "Hold it"), or on
  the sportfisher the wire does. On a rod in its holder it isn't held: every **9 s** it kicks, sheers off and goes
  down out of the harpoon's reach for about **4 s** (the rod bending over in its holder), then comes back up. Two
  aboard: one holds it, the other sticks it. Alone: rod back, and throw between kicks.

**Teach it:** "Boatside!  219 kg" at the top, then a word at a time under the crosshair ("Harpoon it",
"Click to throw", "Stuck: haul it in"); the door's prompt counts the haul ("Hold to haul  40%").

## On deck, and the sale

- **Bleed it:** the knife (key 1), left mouse on the fish. It bleeds out on the deck.
- **Ice it:** E on the **fish box lid** (a hatch in her sole: forward of the skiff's console, mid-cockpit on the
  sportfisher) opens it: ice inside, a tail up out of it for each fish down there. The **gaff** (key 2), left mouse
  on the fish hooks it; **drag it** across the deck (a giant slows you to a crawl) and **let go over the open box**:
  it drops in on the ice. Let go anywhere else and it lies there. The box holds the boat's number iced; more sells
  warm off the deck.
- **The grade** (#1, #2, #3) is all in how it was handled: **landed fast** for its size, **bled within a minute**,
  **iced within 3 minutes**. Left warm on deck costs more.
- **Price:** about $18/kg times 0.35 to 1.25 by quality. A #1 200 kg fish is around $4,000.

**Teach it:** the fish lying there, its blood, the lid; the HUD only says when the box is full. Gap: the grade
rules.

---

## The crew and playing together

- 1 to 4 aboard; each in their own oilskins colour. Everyone sees the same sea, birds, fish and weather.
- **Host** (Esc): a join code (no port forwarding: the router's asked to open the port). **Join** with the code.
  **Steam**: a friends-only lobby, join from the friends list or an invite (needs the GodotSteam add-on; each
  player on their own Steam account).
- Solo works: harder, on purpose (the rod in the holder while you steer, and he runs faster off a rod nobody's
  on). No numbers change with crew size; the difference is what extra hands can do, and the boats (the skiff for
  one or two, the sportfisher wants a crew: five lines to clear, doubles to fight, the well to pump, the tower to
  spot from), and the shares past the second.
- **Quiet stretches:** the run out and the icing are rests; only the fight and boatside need everyone.
- The jobs: captain, angler, line-clearer, spotter (binoculars), wirer, harpooner, haulers, the one who bleeds and
  ices, chum and jig while you wait.
- **Over the side** (`crew/player.gd`): no mode, just her rail. Walk into it and jump and your legs get you up
  onto her gunwale (stand there for a harpoon shot, walk along it, step or jump off it; a big sea can throw you
  off); sprint and jump and you're straight over it, into the sea with a splash. Another boat within a jump (about
  3 m past the rail) and you leap the gap onto her deck instead: clear of your boat you're in the world's frame,
  in over hers you're in hers, still falling, riding her from then on. Whatever you had hold of is let go: a rod
  goes back in its holder, fish and all.
- **Swimming:** you float at the real waves' height (the height the boats ride), your eyes at the waterline, lifted
  by each swell a beat late and drifting down wind, a wave washing over the lens now and then. WASD swims in strokes
  (a pull that surges you on, a glide, your head rising with each pull, a slap of water); Shift sprints (quicker
  strokes, blowing hard); Ctrl or C held dives you under into the murk. Sprinting and diving share your breath
  (about 8 s of sprint, 5 s under): run it out and you're winded till it's back. Go in hard and you go right under
  and come up gasping. A boat's four times faster than a sprint: a swim's for her ladder, not a chase.
- **The boarding ladder** (`boat/ladder.gd`) hooked over every boat's transom, beside the engines: swim up to its
  foot and E (no need to find it with the crosshair). W climbs a step at a time, S goes back down (at the foot,
  back into the water), neither and you hang there, E lets go; at the top you're over the cap and onto her deck.
  From her deck, E at the top of it (facing aft) takes you over the cap and onto it, going down.
- **Shoving** (F, either mode): arms back and a grunt first (0.4 s: everyone sees it coming and can step aside),
  then both hands out. Whoever's in front then staggers off across the deck; into the rail hard and they're over
  it. Braced (a fish on the rod in your hands, the wheel, the chair) you go half as far. One shove every 6 s, never
  from the water or the ladder. The host decides every push.

### VS: two boats racing for the same birds (`vs/vs.gd`)

- **Start one:** host a crew (Steam or a join code) and let your friends join. At the dock the skipper presses
  **Two boats: race for the birds**. Everyone's shared out between **Boat A** and **Boat B** (the skipper on A).
  **Always even: 1 v 1 or 2 v 2** (3 v 3 and 4 v 4 later, with bigger boats): the lobby won't START with uneven
  teams and says why on everyone's screen, the odd one out told to wait (or leave) for a fourth;
  at the dock anyone can press the other boat's button to cross to her. **One boat** goes back to co-op.
  (Dev: `--vs`, and `--team=b` to start on B.)
- **Head out** and both boats leave from the harbour, side by side inside the breakwaters, bows to sea, in the same
  kind of boat (whichever the skipper took). It's about 2 km out past the fairway buoy to open water: a race.
  Each boat has everything of her own: her wheel, rods, harpoon and tuna door, fish box, chum and jig. The other
  boat is right there on the water, her crew aboard her; her fish and her notes are hers.
- **The birds** turn up round one boat, then the other, then between them, in turn, so neither crew gets the
  better water.
- **The boats are solid to each other** (`vs/contact.gd`): no passing through. Run into her and it's a thud where
  the hulls meet, both boats heel over and rock back, both are shoved apart by how fast they met (some of it on
  her way, some sideways, a slew round if she's hit off her middle), and anyone standing on deck staggers in a hard
  one. Whoever's machine sees it first shoves both, so it's the same bump on every screen.
- **Wakes:** cross the other boat's wake (or let it come to you) and she rocks: a roll crossing it side on, a pitch
  head on, a slap at the bow, as big as she was going fast and fading as it ages; two arms, two knocks. (Only the
  boat you're on paints her wake on the water: the sea draws one trail.)
- **The wake bomb:** a hull throws her biggest wake ploughing along at 10 to 14 knots, not up on the plane flat out,
  so slowing down to bury the other boat costs you time. Taken beam on and close, it's a hard roll: the sea slops
  in over her transom, everyone standing staggers and their view jolts. Her captain turning her bow into it takes
  it as a pitch, softer.
- **The air horn** (`vs/horn.gd`), on the dash beside each wheel (E): a twin-tone blast heard a mile off. Within
  about 120 m of the other boat it rattles her crew's view and jerks any fish on her lines (the rod tip snaps, a
  little shock in the fight, never enough on its own to lose it). One blast every couple of seconds.
- **Boarding her:** within a jump (alongside, or up to about 3 m off), up on your rail and a leap, or a sprint and a jump, and you're over both
  onto her deck, riding her; or up her ladder from the sea. Her wheel and rods aren't yours to take, but you can shove her crew about, and over.
  The cost: your own boat's a hand short while you're over there.
- **No cutting her off:** running across her stern doesn't part her lines (it used to, and two boats could cut each
  other off till nobody had a fish).
- **The tally**, top left under your own: a bar and the pounds aboard for each boat (yours on top, each in its
  boat's colour, amber A, blue B), a pip for each day won, and a red dot blinking by theirs while they've a fish on.
  When they hook up, your VHF squelch breaks.
- **The end:** at dusk, or when the skipper heads in, both boats come in alongside the fish pier (the screen fades
  up on them, A on its west side, B on its east), and the weigh-in: A's fish read off one at a time with the
  scale's chain and clank, her total stamped, then B's, then who won and by how much ("You won by 66 lb"). Both
  catches are sold as usual (boat A's money is the skipper's bank; boat B's is a bank of her own for the match).
- **Best of three:** each day won is a pip; first to two wins the match ("The match: yours, 2-1").
- **The results card** (`vs/card.gd`): a moment after each weigh-in it comes up on every screen at once (the host's
  word), the mouse freed: both boats side by side, days won, fish, total kg, biggest, the money, the late cut and the
  pounds weighed, tallying up row by row, then a stamp lands on the winner (DAY WON, WINNER for the match, TIE when
  dead even). NEXT DAY (REMATCH once the match is won) needs everyone; under each boat, whether her crew have
  pressed. Then a fade to black, both boats back at their berths, fresh weather from the host, and the countdown.
  BACK TO THE TITLE leaves. If the other crew leave (or the host goes), the card says so and only the title's left.
  A boat towed in late sells for half as well as weighing half.
- Limits: one chum slick on the sea at a time (whichever boat scooped last); the host runs both boats, so the host's
  machine works a little harder.
- **Teach it:** the buttons say it all; nothing else on screen.

## The sea

- Weather comes and goes on its own: calm, sunny, fog, rain, heavy, storm (the fog closing to a wall, lightning
  going for her tower or T-top).
- The boat really moves through a fixed world: up to about 20 knots, twin screws, a wake, spray, the sea slopping
  in over the transom backing down hard.
- **Landmarks** (sea/landmarks.gd, at fixed spots: everyone sees the same): the coast about 2 km astern of where you
  start, with hills, the town round its harbour, the breakwaters and their lights, and the lighthouse on its
  headland (its beam goes round after dark); an oil rig about 2.6 km out to the north-west, its flare always
  burning; the fairway buoy, the channel buoys in, a cardinal off the headland and a yellow weather buoy offshore,
  riding the swell and blinking after dark.
- **Whales and dolphins:** some schools have a whale feeding on the same bait (up three times a breath apart, a
  tall blow you can see from far off, then flukes up and down for over a minute) or a pod of dolphins leaping
  through (only close enough to see the splashes). A lead to bait, not a promise of bluefin: bait-only flocks have
  them too. The spotter names what you're looking at.
- **A real sea (an FFT ocean, the way Sea of Thieves makes its sea):** a wave spectrum, the long swell down to the
  ripples, in three tiles of 256 x 256 waves each (1,100 m, 233 m and 47 m, so no tile's repeat ever shows), summed
  on the GPU every frame (sea/ocean_spectrum.gd, sea/ocean_fft.gd). Sharp crests and wide troughs; **whitecaps** where
  the chop's crests are squeezed till they fold over, lacy and thinning down the face, a few flecks on a sunny day,
  breaking crests everywhere in heavy weather. The swell still comes in sets; wide rough and smooth stretches and
  cloud shadows go over the water. The boat, the fish and the lines ride the same sea: its 72 biggest waves worked
  out on the CPU (everything but the centimetre ripples). Without a GPU sea (headless), the shader draws those.
- **Haze:** the land fades into the sky with distance and with the weather: clear on a sunny day, greyed back in
  rain, gone in fog (its lights carry further than the land does).
- **The shore and the rig stop the boat** ("Aground! Back her off (S)"). Schools never turn up on land.

---

## Teaching plan (from the gaps above)

1. **First-time tips** (each once per player, saved): heading out ("Find the birds: B for binoculars"); the first
   flock in sight; nearing birds fast ("Slow under 10 knots or they'll dive"); the first bite ("Grab the rod: E");
   the first fight's moves one by one; the first fish alongside; the first fish on deck; the quota on the first
   dock screen; the first stale bait; the first chum and jig.
2. **The field guide** in the Esc menu: this document's sections, short, in game.
3. **The dock screen** spells out the stakes: "Make $5,000 by the end of day 3, or the bank takes the boat."
