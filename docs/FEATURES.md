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
| E | use whatever's under the crosshair (grab a rod, the wheel, the harpoon, the tuna door, a fish on deck, the chum bucket, the jig); hold E for the haul, the wiring, the jig |
| Left mouse | crank the reel; throw the harpoon; through the binoculars: call a flock |
| Right mouse | heave the rod up (a pump is heave, then crank as you drop it) |
| B or middle mouse | binoculars (hold) |
| Q | put the rod (or the harpoon) back |
| Esc | the menu: head in and sell, host / join, Steam friends |

**Teach it:** the HUD prompt ("E: ...") names every action under the crosshair. Gap: no controls screen; the
binoculars and the pump are only in hints.

---

## The run (the quota)

- The bank wants **$5,000** in the first **3 days**. Each quota made, the next is half as much again: $5,000,
  $7,500, $11,000, $17,000, $25,500, ...
- Every fish sold counts toward the quota **and** goes in the bank to spend.
- The quota's settled at the **third day's sale**. Made it: the next quota, three more days. Missed it: **the bank
  takes the boat**. The slip tells the run's story (quotas made, fish, the biggest), and a new run starts with the
  skiff and **$1,000**, no gear.
- The best run (most quotas) is kept.
- Fuel comes off each sale: **$60** the skiff, **$400** the sportfisher. A chartered boat: **$2,500** a day.

**Teach it:** the dock screen shows QUOTA n: $earned of $quota, Day d of 3, a bar; the tally at sea shows it too.
Gap: nothing explains what happens if you miss it until it happens.

## The dock

Where a game starts and every trip ends: the last sale's slip, the quota, the bank, the boats, the chandlery, and
**Head out** (the skipper's button; crewmates see the skipper's choices).

**Boats** (picked at the dock; everyone aboard gets the same):

| | The skiff (28 ft center console) | The sportfisher (46 ft) |
|---|---|---|
| Cost | yours | $20,000, or $2,500 a day chartered |
| Rods | 2 (the aft corners) | 4 |
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

- **Head out** at dawn (5:30 am). The day runs to dusk (7:30 pm) in **20 real minutes**, then it's night.
- The light follows: warm at dawn and dusk, the boat's lights on at dark. A word at dusk and at dark.
- **Head in** whenever (Esc, skipper): the catch sells, fuel and any charter come off, back to the dock. Heading in
  cuts loose anything still on a line or alongside.
- Nothing turns up or bites at the dock.

**Teach it:** the clock is in the tally; the dusk and dark notes. Gap: "Head in" lives only in the Esc menu.

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
- **Left click** (through the binoculars) **calls** the flock: it's **marked on the radar** for the whole crew (a
  blue cross, pinned to the radar's edge if it's further off), and everyone hears "Yellow: Birds! ...". Crew are
  called by their oilskins: Yellow, Orange, Green, Red.
- **The radar** (the dash, heading up, 1.5 km to the edge, rings every 500 m) paints **birds in the air**: blobs that
  glow as the sweep passes. Birds sitting on the water don't paint, and it can't tell gulls from tuna birds.
- **The sonar** (the dash) marks fish right under her.

**Teach it:** the HUD says "Find the birds: hold B for the binoculars..." until you've used them a few times; the
binoculars read each flock. Gap: nothing says decoys exist or that spells come and go, except the binocular text.

## Coming up on them

- **Never run over a school fast.** Go through one faster than about **10 knots** (5 m/s) and it **goes down for
  40 s** ("You ran right over them!"). Come up slow.
- **No bites above about 12 knots** (6 m/s): the baits skip along the top.
- Get within about **160 m** and slow to trolling speed (under 12 knots; a few knots is right), and the school
  **finds your baits** and works round them, following as you troll.
- A feeding bluefin school over a bait eats it now and then (the reel screams). A second fish while one's on is rare
  (a double header).

**Teach it:** the "ran right over them" note, after the fact. Gap: say it before: a first-time tip as you near
your first flock ("Slow down under 10 knots near the birds").

## Baits

- Each rod's line runs back to a **lure** on the water (a live mackerel shows dark). Baits are **towed**: dragged
  along behind the rod tip, held out wide while she's moving, swinging round her turns, dropping back with the line
  slack when she stops, skipping along the top at speed.
- **Baits go off:** a dead bait's washed out after about **5 minutes**, a live one **10**. A washed-out bait gets a
  **quarter** of the bites. The HUD says when one has ("The port corner bait's washed out: E on that rod to
  rebait"); E on it reels it in and a fresh one goes out **4 s** later.
- **Live bait** (with the live-bait well): baits go out live while there's a mackerel in the well: **half as many
  bites again**, and they last twice as long. E on a dead-baited rod while there are mackerel swaps it for a live
  one.
- **The jig** (a light rod in a gunwale holder): **hold E** on it, slowed right down (under about 3 knots), and a
  mackerel comes up every few seconds into the well (needs the well; it takes 8).
- **Chum** (the bucket on her transom, **24 scoops** a trip): E throws a scoop (one every 1.5 s at most). It lays a
  slick back through the baits; a school within about **450 m** smells it, comes up it and **stays on it, working,
  as long as you keep the chum coming** (a scoop every minute or so). New schools turn up near a fresh slick too.
- After a fish, the crew put the baits back out on their own after 20 s of quiet.

**Teach it:** rod and bucket and jig prompts; the stale-bait hint. Gap: why chum and live bait matter.

---

## The hookup and the fight

- The reel screams and the line pours off: **anyone grabs the rod** (E). Q puts it back in the holder.
- **A rod in its holder fights on its drag:** the fish takes line on its runs and tires doing it, but nobody wins
  any back. Solo, you drop it in the holder to run to the wheel, then grab it again: the same fight carries on.
- **Crank** (hold left mouse) winds line in; **pump** (hold right mouse to heave the rod up, then crank as you drop
  it) wins line a heavy fish won't give to cranking alone.
- The fish plays **moves**, each with a **tell** under the crosshair and **one right answer**:

| Move | Tell | Do |
|---|---|---|
| Run | "It's running! Let it go" | nothing: let the drag tire it (cranking against it strains the line) |
| Sounding | "It's sounding deep! Pump: heave, then crank down" | pump |
| Head shakes | "Head shakes! Keep it tight" | keep cranking or heaving, or the hook pulls |
| Circling | "It's circling! Pump" | pump |
| Resting | "It's resting! Crank" | crank |
| Death spiral | "Death spiral! Crank, it's coming up" / "Ease off, it's going under her" | crank as it comes up, ease off as it goes under |

- **The strain ring** round the crosshair shows how wrong you're fighting it. Red for **1.2 s** and the line
  parts.
- **The line readout:** metres out, gaining or losing, how fresh the fish is, how worn the line is.
- **No tiredness:** your arms never tire (removed 2026-10-29). Hand the rod to a crewmate (they E on it) and the
  fight carries on.
- **The captain** (E on the wheel; A/D steer, W/S throttle): the tuna swings round the boat.
  - **Keep the stern on it.** Let it swing round toward her bow so the line runs over her house or bow and **the
    line rubs** and wears through ("Swing her stern to it", or the angler takes it to that **corner**). Over the
    open cockpit, or off your own corner going away from her, it never rubs. It's the real line against her real
    hull (ray-cast against her shape): it rubs only where it truly lies over her console, house or bow, so fight
    from the stern, not up by the console. The line's drawn straight from the rod tip toward the fish, going in
    where that line meets the water.
  - **Backing down** (S) on the fish wins line back fast and eases the strain.
  - **Under the boat:** if the fish goes under her, **no throttle**: steer her stern round with A/D only. Touch W
    or S while it's under her and the props cut the line after **1.5 s** ("OUT OF GEAR!").
  - The captain gets a plotter of where each fish is.
- **Other lines:** while a fish is on, its runs can cross the other baits and **tangle** them. E on each other rod
  reels it in ("clear the lines"). A tangle left alone saws the line through.
- **How you lose one:** the line parted (too much strain), pulled the hook (slack in a headshake), spooled (it took
  all 500 m: don't crank against a run; back down on it), chafed through on the hull, cut by the props, sawed
  through in a tangle. Each loss says why.
- A big fish alone takes about 10-13 minutes fought right; with a captain a few minutes.

**Teach it:** tells, ring, readout, captain hints, loss reasons. Gap: the first fight needs a walkthrough, and
"anyone can grab it / hand it off" isn't said.

## Boatside

- Beaten, the fish comes **alongside** astern.
- **On the sportfisher, wire it first:** someone holds E at the tuna door (grabbing the leader); it stays wired
  **15 s**. The skiff's low enough to reach it as it is.
- **The harpoon** (on the rack along the port side; E takes it, Q puts it back): aim and left click to throw. A
  throw at an unwired fish misses.
- **Haul it aboard:** hold E at the tuna door (or the gunwale). Alone a giant takes about **22 s**; each extra pair
  of hands adds as much again.
- Leave it alongside unstuck **90 s** and the hook pulls.

**Teach it:** door and rack prompts and the hint walk you through it.

## On deck, and the sale

- **Bleed it** (E on the fish), then **ice it** (E again: into the fish box). The box holds the boat's number iced;
  more sells warm off the deck.
- **The grade** (#1, #2, #3) is all in how it was handled: **landed fast** for its size, **bled within a minute**,
  **iced within 3 minutes**. Left warm on deck costs more.
- **Price:** about $18/kg times 0.35 to 1.25 by quality. A #1 200 kg fish is around $4,000.

**Teach it:** the hints ("A fish on deck: bleed it, the sooner the better"). Gap: the grade rules.

---

## The crew and playing together

- 1 to 4 aboard; each in their own oilskins colour. Everyone sees the same sea, birds, fish and weather.
- **Host** (Esc): a join code (no port forwarding: the router's asked to open the port). **Join** with the code.
  **Steam**: a friends-only lobby, join from the friends list or an invite (needs the GodotSteam add-on; each
  player on their own Steam account).
- Solo works: harder, on purpose (the rod in the holder while you steer). No numbers change with crew size; the
  difference is what extra hands can do, and the boats (the skiff for one or two, the sportfisher wants a crew).
- The jobs: captain, angler, line-clearer, spotter (binoculars), wirer, harpooner, haulers, the one who bleeds and
  ices, chum and jig while you wait.

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
- **A sea with depth:** a long swell runs with the wind in ridges that crowd together toward the horizon, coming in
  sets (wide bands of bigger swell travelling downwind, then a lull), with the chop short enough to fade into texture
  with distance. Wide rough and smooth stretches and cloud shadows go over the water, so far off it's never one even sheet.
- **Haze:** the land fades into the sky with distance and with the weather: clear on a sunny day, greyed back in
  rain, gone in fog (its lights carry further than the land does).
- **The shore and the rig stop the boat** ("She's touched bottom! Back her off"). Schools never turn up on land.

---

## Teaching plan (from the gaps above)

1. **First-time tips** (each once per player, saved): heading out ("Find the birds: B for binoculars"); the first
   flock in sight; nearing birds fast ("Slow under 10 knots or they'll dive"); the first bite ("Grab the rod: E");
   the first fight's moves one by one; the first fish alongside; the first fish on deck; the quota on the first
   dock screen; the first stale bait; the first chum and jig.
2. **The field guide** in the Esc menu: this document's sections, short, in game.
3. **The dock screen** spells out the stakes: "Make $5,000 by the end of day 3, or the bank takes the boat."
