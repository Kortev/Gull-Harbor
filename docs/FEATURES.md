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
| Right mouse | raise the rod |
| Scroll, with a fish on | the drag, a notch at a time |
| Q | put the rod (or the harpoon) back |
| Esc | the menu: head in and sell, host / join, Steam friends |

**Teach it:** the HUD prompt (an E key cap and a word or two: "Grab it!", "Bleed it") names every action under
the crosshair. Gap: no controls screen; the
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

**Teach it:** the dock screen shows QUOTA n: $earned of $quota, Day d of 3, a bar, and "$x more by day 3, or the
bank takes her". At sea, top left: the quota as a bar (what's aboard ghosted on), "$earned / $quota", "Day d/3", and
the fish box as pips (filled once iced, amber for one still on deck).

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
- The light follows: warm at dawn and dusk, the boat's lights on at dark. A word at dusk ("Sun's going down").
- **Head in** whenever (Esc, skipper): the catch sells, fuel and any charter come off, back to the dock. Heading in
  cuts loose anything still on a line or alongside.
- Nothing turns up or bites at the dock.

**Teach it:** the sun is the clock; the dusk note says "Esc to head in".

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

**Teach it:** Dale's first tip ("Tuna feed under birds. Find a flock."). A flock under the crosshair reads one line
over the plotter's spot: far off "Birds   1.4 km off the port bow"; inside 700 m what they're on ("BLUEFIN!", "Tuna
down: wait", "Just gulls", "Scattering: moved on"). The birds themselves show it too: diving and white water, or
sitting.

## Coming up on them

- **Never run over a school fast.** Go through one faster than about **10 knots** (5 m/s) and it **goes down for
  40 s** ("Too fast: they've gone deep"). Come up slow.
- **No bites above about 12 knots** (6 m/s): the baits skip along the top.
- Get within about **160 m** and slow to trolling speed (under 12 knots; a few knots is right), and the school
  **finds your baits** and works round them, following as you troll.
- A feeding bluefin school over a bait eats it now and then (the reel screams). A second fish while one's on is rare
  (a double header).

**Teach it:** Dale's tip as you near birds fast ("Under 10 knots near the birds, or they dive"); the "too fast"
note after the fact.

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

- The reel screams and the line pours off: **anyone grabs the rod** (E). Q puts it back in the holder.
- **A rod in its holder fights on its drag:** the fish takes line on its runs and tires doing it, but nobody wins
  any back. Solo, you drop it in the holder to run to the wheel, then grab it again: the same fight carries on.
- **The mouse is the rod** with a fish on (docs/FIGHT_DESIGN.md: the brainstorm's "Loaded Rod", built 2026-10-30):
  mouse up and down lifts and drops it, side to side lays it over off the line; the camera follows the rod part of
  the way so the line and the water stay in view (push past the rod's stop and the rest turns your look). **Left
  mouse** cranks, **right mouse** raises the rod too, **scroll** steps the drag (free, light, strike, full; a fish
  comes on at strike).
- **One spring between you and the fish, no text:** the line's tension is everything (the rod's bend). The fish
  swimming away, you raising the rod and you winding stretch it; the fish coming at you, you dropping the rod and the
  boat closing on it slacken it. Past the drag the drag slips and pays out line (**the reel screams**); full tension
  for half a second, or a jolt past it, **parts the line**.
  - **Cranking only wins line while the rod isn't loaded:** against a heavy fish the reel **grinds** and wins
    nothing. So you **pump**: lift slow (it hauls the fish toward you), drop and wind the slack.
  - **Hauling it toward you is what tires it**; a slack line lets it get its breath back.
  - **Lay the rod over against the way it's swinging** and it turns slower and gives line; hold it hard and it turns
    its head, comes at you and sulks.
  - **The hook:** jolts (a head shake on a stiff rod, a jump landing on a tight line) and slack while it thrashes
    work it loose. **When it jumps, drop the tip** (a rod held high and cranking throws it).
  - It **runs, sounds, sulks deep, shakes its head, circles, surges, jumps** (the small ones), and beaten, close in,
    goes into its **death spiral** under the boat.
  - A lost fish says how in a few words: "Line parted.", "Hook pulled.", "Thrown on the jump.", "Spooled.",
    "Chafed through on the hull.", "Cut on the props."
- Fought well (the headless test anglers, tests/fight_bot.gd): a schoolie about **40 s**, a 150 kg fish about
  **1.5 min**, a 300 kg giant about **4 min** with a captain, **6 alone**. Pumping beats plain reeling; laying the rod
  over beats not; cranking through the runs breaks them off; doing nothing never lands one.
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
  - The captain gets a plotter of where each fish is (red where its line's on the hull), and at the wheel always
    her knots over a throttle bar (green ahead, amber astern, from the middle).
- **Other lines:** while a fish is on, its runs can cross the other baits and **tangle** them. E on each other rod
  reels it in ("Reel in"). A tangle ("Port line tangled") left alone saws the line through.
- **How you lose one:** the line parted (too much strain), pulled the hook (slack in a headshake), spooled (it took
  all 500 m: don't crank against a run; back down on it), chafed through on the hull, cut by the props, sawed
  through in a tangle. Each loss says why, in a few words ("Line parted: too much strain").
- A big fish alone takes about 10-13 minutes fought right; with a captain a few minutes.

**Teach it:** the word and its colour, the ring, the meter, the captain's word and plotter, loss reasons, Dale's
fight tip. Gap: "anyone can grab it / hand it off" is only in the manual.

## Boatside

- Beaten, the fish comes **alongside** astern.
- **On the sportfisher, wire it first:** someone holds E at the tuna door (grabbing the leader); it stays wired
  **15 s**. The skiff's low enough to reach it as it is.
- **The harpoon** (on the rack along the port side; E takes it, Q puts it back): aim and left click to throw. A
  throw at an unwired fish misses.
- **Haul it aboard:** hold E at the tuna door (or the gunwale). Alone a giant takes about **22 s**; each extra pair
  of hands adds as much again.
- Leave it alongside unstuck **90 s** and the hook pulls.

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
- Solo works: harder, on purpose (the rod in the holder while you steer). No numbers change with crew size; the
  difference is what extra hands can do, and the boats (the skiff for one or two, the sportfisher wants a crew).
- The jobs: captain, angler, line-clearer, spotter (binoculars), wirer, harpooner, haulers, the one who bleeds and
  ices, chum and jig while you wait.

### VS: two boats racing for the same birds (`vs/vs.gd`)

- **Start one:** host a crew (Steam or a join code) and let your friends join. At the dock the skipper presses
  **Two boats: race for the birds**. Everyone's shared out between **Boat A** and **Boat B** (the skipper on A);
  at the dock anyone can press the other boat's button to cross to her. **One boat** goes back to co-op.
  (Dev: `--vs`, and `--team=b` to start on B.)
- **Head out** and both boats leave from the harbour, side by side inside the breakwaters, bows to sea, in the same
  kind of boat (whichever the skipper took). It's about 2 km out past the fairway buoy to open water: a race.
  Each boat has everything of her own: her wheel, rods, harpoon and tuna door, fish box, chum and jig. The other
  boat is right there on the water, her crew aboard her; her fish and her notes are hers.
- **The birds** turn up round one boat, then the other, then between them, in turn, so neither crew gets the
  better water. Any school is fair game for either boat; run through one fast and it goes down for both.
- **The tally**, top right, quiet: your boat's pounds aboard (on deck and iced), and theirs.
- **The end:** at dusk, or when the skipper heads in, both boats come in together and what each has aboard is
  weighed: "You won by 66 lb" (or they did, or dead even), over the dock screen. Both catches are sold as usual
  (boat A's money is the skipper's bank; boat B's is a bank of her own for the match).
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
- **A sea with depth:** a long swell runs with the wind in ridges that crowd together toward the horizon, coming in
  sets (wide bands of bigger swell travelling downwind, then a lull), with the chop short enough to fade into texture
  with distance. Wide rough and smooth stretches and cloud shadows go over the water, so far off it's never one even sheet.
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
