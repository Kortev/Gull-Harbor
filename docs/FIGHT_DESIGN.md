# The fish fight: Bend, Head and Heat

**Status:** design only, nothing built yet. This replaces the earlier "Loaded Rod, Crewed (v2)" design, which is still in git history at 26137ea. Build nothing until the sim tables in "Tuning targets" pass (PASS 0).

**The rules this design is held to:**
1. Gamify the hands and keep the realism in the boat, the crew and the world.
2. Thirty minutes that never go dull.
3. The world's rules never depend on crew size.
4. A two-person boat has two roles plus shared chores.
5. Solo is barely possible, two and three on the skiff work, and the sportfisher needs four.
6. Every station knows something the others don't.
7. Readable in five seconds, pixel style, nothing snaps, done by hand.

---

## 1. Pitch

The rod is a tension game you can read at a glance. A pixel gauge by the reel has one golden band, just under your drag. Ride the gold and he tires and comes to you. Push past the red and the line parts. At the same time you steer: lay the rod against his head until he turns, and for a few seconds he swims to you.

Everything else is real, and it lives on the boat:
- The helm puts her across his line and keeps the stern on him.
- The reel heats, the bilge fills and the other lines tangle.
- The line rubs the hull and the props wait under her.

None of these rules care how many of you are aboard. Alone, you run between all of them and barely make it. On the skiff, two of you are flat out and three are comfortable. The sportfisher makes every chore bigger and further apart: five lines, a helm 8 m forward and blind at her transom, a tower and bigger fish. She pays like a galleon, but only for a crew that talks.

---

## 2. The angler loop

### Inputs (whoever holds the rod, on any boat, any crew size)

| Action | Mouse + keys | Pad | What it does |
|---|---|---|---|
| Wind | Hold LMB (eases 0 to 1 over 0.3 s, back over 0.2 s; taps feather it) | RT, analog | Raises tension toward *his pull + 0.35 x wind*. Tension eases toward that target with a 0.5 s time constant, never a jump. |
| Lay the rod over (steer) | Mouse X | Right stick X | The existing `aim_side` (-0.9..0.9 rad). It lays the rod without turning you. |
| Rod height | Mouse Y | Right stick Y | Tip down bows to a jump, and over the side it dips the line under the keel. Tip high lifts the line off the rail. It **never gains line**. |
| Walk the rod round | WASD | Left stick (50% speed while holding a rod) | Move along the rail. |
| Free look | Hold Alt | R3 | The rod holds its lay. Otherwise the camera follows the line with +-20 degrees of slack. |
| Drag lever | Scroll | D-pad up/down | 0.1 per notch, with a click detent at 0.6. It moves over 0.15 s. |
| Take or hand over the rod | E | A | 1.5 s, hand to hand. |
| Rod in the holder | Q | B | |
| Shout | V (hold for the wheel) | Y (hold for the wheel) | See section 7. |

### The three reads (pixel art, nearest filtered, no text)

**1. The bend gauge.** A 48 px arc by the reel with a needle at the tension T. The bands hang off **the drag S** (S = lever x 0.9), so the gold is always just under your drag, wherever you set it:

| Band | Range | Gain | Tires him |
|---|---|---|---|
| Grey SLACK | 0 to 0.12 | 0 (and the hook works loose) | none |
| Green WORK | 0.12 to 0.8 S | x1.0 | x1.0 |
| **Gold EDGE** | 0.8 S to S | **x1.4** | **x1.6** |
| White tick: PINNED at S (the spool slips, he takes line, the reel screams) | at S | 0 | x1.0 |
| Red line: line strength St | St = 1 - wear, floor 0.5 | | |

- The needle can't pass the white tick unless a kick jolts it, up to **1.6 x S**.
- Anything past St held for 0.25 s parts the line.
- New line sits well above the tick, so the red is a thin cap at the top. As the line wears, the red creeps down the arc, toward the tick and then under it.
- The five-second read: **keep it gold, and watch the red come down to meet you.**
- The lever is the risk dial. At the 0.6 detent (S = 0.54), a full kick tops out at 0.86, so it's safe on new line. On worn line (St under 0.86) the detent can break. A high drag gains faster and turns him harder, but kicks can reach the red.
- Colourblind safety: the red band is hatched, and the needle trembles when it's pinned at the tick.

**2. The head chevron.** One 7 px arrow drawn on the water where the line goes in, clamped to the screen edge. It points the way he's swimming.
- Its **fill** shows the steering: grey means you're not across his head, green means you are and his head is coming round.
- As you win, it visibly rotates toward the boat. When it points at you he's turned: a white wake flip, his flank flashes, a pad thump and a stinger note.
- A 1 px rim shows his freshness in 4 steps (blue-black, slate, steel, bronze). You see the same colour on his flank when he rolls. Freshness is never in the fill.
- When he's deeper than your eye can see (section 7), the arrow dims. It is then worked out from the line's drift: it lags **3.5 s** and points the wrong side 25% of the time. Only an eye that can actually see him shows the truth.

**3. The spool.** The existing 500 m reel art empties as he takes line. The backing colour shows past half, and the last 50 m are red.

**In the world, for the crew:**
- The rod blank has 6 bend frames.
- The line is white, turns gold at the edge and flickers red past St.
- Mates read the edge coarsely. Only the rod sees the exact needle, the tick and the red.

### The tell

Every kick (a surge, a head shake, the bolt of a run) comes 0.7 s after a tell: the tip nods twice, a double thump plays and the pad gives two 60 ms pulses. Inside 30 m of line the lead is 0.5 s.
- Ease off the wind during the tell and the jolt is halved. Wind through it and the jolt lands in full.
- A missed tell costs margin, never the fish by itself. It is not a pass/fail window.

### Each second

- **Gain** = 1.8 m/s x wind x band factor. The factor is x2.5 while his head is turned, x0.3 with spent arms, and x1.25 with the dock's two-speed reel.
- **Kicks** add +0.30..0.55 for 0.3 s, x1.5 inside 60 m of line.
  - Laying hard across his head (|lay| > 0.7) makes him kick x1.5 as often.
  - So steering and tension pull against each other, and you can't max both at once.
- **Losses** (kept from today's code):
  - past St for 0.25 s: the line parts
  - under 0.12 for SLACK_LOOSE: the hook works loose
  - over 0.5 for HELD_T: the hook tears (HOOK_T)
  - a tight line on a jump: the hook is thrown (JUMP_T)

### Steering (continuous)

- **His heading curves continuously** toward a target that changes every 6-12 s while he's fresh and every 4-7 s under 40%. Far out, the interval stretches by max(1, line_out / 80). So you track an angle, not just a sign.
- **The effective lay blends the rod and the boat:**
  `eff_lay = w x (rod_side / 0.9) x (1 - 0.5 x tip_high) + (1 - w) x boat_cross`, with `w = clamp(80 / line_out_m, 0.35, 1.0)`.
  - **boat_cross** is where the boat sits off his **run line**: his heading averaged over 30 s, -1..1. The helm chases his run, not every wiggle.
  - Far out, putting the boat across his line does most of the turning, but the rod always counts for at least 35%. Inside 80 m it's all the rod.
  - Tip high halves the rod's side pressure. Height is a real trade: steer, or protect the line.
- **The head meter** is hidden and shown only by the chevron's rotation.
  - It fills at 0.25/s x |eff_lay| x T/0.5 while eff_lay opposes his heading and T > 0.25.
  - Laid with him, it drains at 0.5/s and he gains an angle on you. If that angle points under her, the line heads for the hull.
- **THE GIFT:** when the meter is full, his head is turned for 4-6 s.
  - He swims toward the boat at no more than 3.5 m/s and pulls 40% less.
  - You gain x2.5 and he tires x2.
  - There's a 1.5 s slack grace, so a GIFT can't trap a mouse player into a loose hook.
  - The director's committed-move queue pauses during a GIFT and resumes in order, which keeps it deterministic.

### Jumps

The line lifts and sheds drops, a bulge shows on the water and the chevron lifts. Tip down within 0.5 s, or a tight line throws the hook.

**The hands play two games at once:**
- **Tension:** ride the gold, ease on the tells, notch the drag to where the gold is reachable.
- **Steering:** lay against him, together with the boat.

Everything else is on the other stations.

---

## 3. The universal mechanics

Every row runs identically for 1, 2, 3 or 4 players. "Who" means who *can* do it. Nobody is assigned anything.

| Mechanic | What it does | Who can handle it | Cost if ignored |
|---|---|---|---|
| **Bend and drag** | The gauge above. Kicks come 0.7 s after a tell and jolt up to 1.6 S. Near the arbor the drag doubles (spool_gain kept). On long runs the line's belly adds load (BELLY kept). | The rod. Mates see the line colour and the rod's bend. | Breaks, pulled hooks and shaken hooks. |
| **Head (steering)** | The blended steering above. Each GIFT gives x2.5 gain and x2 tiring. A fish nobody steers drifts toward one side of the boat every 30-50 s, or every 10-15 s if the rod is in a holder. | The rod always. The helm far out. A high eye calls his turns. | About 2x longer fights, and he keeps getting an angle under her, which brings chafe and the props. |
| **Stern angle** | Tiring x1.0 within 0.6 rad of dead astern, falling to x0.35 by 1.9 rad (SQUARE, WIDE and STEEP kept). The helm's compass shows a green arc astern and a tick at the line. The angler sees it only roughly, over the transom. | The helm. | Up to 3x longer fights. |
| **Planing** | Slow ahead at 1-2 m/s with a deep fish astern drains him x1.3. It raises chafe and prop risk, and his circle crosses the stern every lap. | The helm, with someone at the corner to fend. | The grind runs longer. |
| **Spool** | 500 m. The backing shows past half, and he spools you at empty. Back down to close the gap (skiff 1.8 m/s, sportfisher 3.2 m/s), or run up on him at a slant. | The rod reads it. The helm can't see it and must be told. | Spooled on the first or second run. |
| **Reel heat** | heat += 0.0045 x S x slip speed (m/s) per second, and it cools 0.004/s by itself. Over 0.7 the drag fades (S x0.7) and steam shows. At 1.0 a rising squeal warns 1.0 s ahead, then the drag **grabs** at 0.95 until heat falls under 0.6, and a kick while it's grabbed parts the line. A bucket of sea water takes off 0.35. | Anyone, with the deck bucket on its lanyard: dip at the rail 1.2 s, carry at 70% walking speed, pour at the reel 1.5 s. If your hands are on the rod, it goes in the holder first. | A grab in the third run, and the next kick breaks the line. |
| **Water aboard** | Green seas (existing), plus backing down. Over 0.6 the boat goes astern at half speed. At 1.0 the engine drowns, and restarting it takes holding E for 3 s. Pumps per boat (section 4). | Anyone pumps or clears. Only the helm sees the level. | A boat that can't back down, then a dead engine as he runs. |
| **The other lines (tangles)** | Every line still out gets the sweep-scaled tangle check (TANGLE_EVERY/CHANCE/GRACE kept). A tangle **knots** the two lines: the tangled rod's drag adds to the fish rod's T until someone winds it in (2.5 m/s) or cuts it with the knife, which loses that rig and its cost. Outrigger lines need their halyard clip popped first (1 s). | Anyone free. | A real snap risk: about 35% per uncleared line over a first run on the sportfisher, about 20% on the skiff. |
| **Line wear** | One damage number, St, which the red shows eating the gauge. What wears it: hull or rail rub (CHAFE_LIFE 14 s of full rub parts new line), the keel (x1.6), a tangle sawing, a prop nick you survive (-0.15), a tail wrap on a jump (-0.1). A frayed puff shows on the line within 3 m. | The rod (tip high, walk it round), anyone free (a gloved hand fends: x0.2, up to 6 s at a time), the helm (put the stern back on him). | broke_rail or chafed, and less margin for the rest of the fight. |
| **Props and keel** | Line under her with a screw turning is cut after PROP_GRACE 2.5 s. Neutral stops the screws in 0.5 s. She keeps coasting (skiff 4.5 s, sportfisher 9 s), and a coasting hull rides over the line, which is keel chafe x1.6, not a cut. The skiff's outboard can be tilted (2 s at her stern, no drive while tilted). The rod can dip its tip (over the side, pitch 0.15). | The helm (gear), anyone at the skiff's stern (tilt), the rod (dip). | Instant loss. |
| **Arms** | They drain only while the rod is in gold or pinned at the tick: ARM_LIFE about 4 min of gold, ARM_REST 40 s, ARM_HOLDER 30 s. Spent arms wind x0.3 and the rod sways 1-2 px. A swap takes 1.5 s, hand to hand. | The rod, a mate who takes it, or the holder. | Gain falls to a third late in the fight. |
| **Rod holder** | A parked rod fights on its drag only: no gain, no steering, drain x0.2, unsteered drift every 10-15 s, and slipping heats the reel as normal. | Anyone. | The fish rests and wanders. Parking is a cost, never a free machine. |
| **Fighting chair** (sportfisher) | Seated arms last 2x, but the lay is capped at 0.5 and counts only along the chair's facing. Seated, A/D turns it at 0.2 rad/s. Someone behind the chair (E + A/D) turns it at 0.8 rad/s. Or fight stand-up at a corner, with full lay. | The rod, and anyone behind the chair. | Facing wrong, the steering is lost. |
| **Eye height** | The director commits each move 2.5 s ahead. An eye h metres above the water sees his shadow and true heading down to 7h m deep and out to 60h m, plus a fin flare before each move at lead = clamp(0.3 + 0.3h, 0.7, 2.2) s. Glare and dusk halve the depth. | Whoever stands there (section 4). | Deep, the chevron is late and sometimes wrong. |
| **Unheld things keep their setting** | The helm holds its throttle and wheel, a parked rod holds its drag, and the bilge keeps filling. Nothing works by itself, and nothing stops by itself. | Everyone. | The angle drifts and the water rises. |
| **Boatside** (kept from tuna/landing.gd) | The leader at 16 m with one last run. Alongside at 7 m he has to be held (a parked rod sheers every 9 s). Then the wire (sportfisher, 15 s), the harpoon, the tail rope and a haul where every hand on the rope speeds it, inside the 90 s hook clock. Spike, bleed, pump, gut and ice set the grade. | Any hands. | Lost at the boat. |

---

## 4. Skiff vs sportfisher

Every rule above runs on both boats. The boat changes only the numbers, the distances and which stations exist, all in `boat/kinds.gd`.

| | **Skiff** (8.5 m, open, outboard) | **Sportfisher** (14 m, twin screws, self-bailing) |
|---|---|---|
| Lines | 2 rods, 1 other line to clear (16 s) | 5 rods, 4 to clear (about 107 s plus walking). The shotgun is wound in from its centre holder, off a high clip, so nobody climbs. |
| Raising fish | | The teaser effect: 2 lines out raise about 25% as many fish as 5. Fishing short-handed with a small spread is allowed, but it starves her. |
| Distances | The wheel is 1.5 m from the rods. The bucket is 1 m from rod 1. The hand pump is at the console foot. The stern (tilt, restart) is 2 m aft. | The cockpit helm is 8 m forward of the corners, with a 6 m blind spot behind the transom. The bucket is 3.5 m from the chair. The engine hatch is mid-cockpit. The tower is 4 s up and 3 s down. |
| Eyes | The leaning post is **at the helm** (2.4 m: 1.0 s lead, 17 m deep), so whoever drives is also the spotter. Standing on deck is 1.7 m. | The tower (5.5 m: 1.95 s lead, 38 m deep, every line in the water) and the bridge (3.5 m). |
| Helm | The console has the stern-angle compass and the sight glass. She coasts 4.5 s, turns at 0.75 rad/s, and the outboard can be tilted. | The cockpit helm has the compass, the bilge light and sonar (depth and range). **The tower helm** has throttle and wheel only, but sees his flank far out. Close in, the skipper has to come down to the cockpit helm, which sees the transom better. She coasts 9 s, turns at 0.45 rad/s, and her twin screws spin her on the spot. |
| Water | She backs at 1.8 m/s and ships 0.006/s doing it. Green water adds about 0.08 a sea. A **hand pump only** (LMB stroke every 0.6 s, -0.012 a stroke, no strainer). Today's automatic 0.004 pump is removed (see open questions). | Self-bailing. Backing harder than 2.5 m/s in a sea ships 0.006/s over the transom, and less than that ships nothing. Electric pump, 0.03/s. Its strainer clogs from **debris**: in a weedline or after a debris minor (section 6), after 0.25 of water pumped. Clearing it takes the hatch (1 s) plus holding E for 3 s, and the open hatch slows everyone walking past. Only the helm's light shows a clog. |
| Chair | None. Stand-up only. | The chair (and the swivel chore), or stand-up at a corner. |
| Boatside | No wire. A 0.9 m lift over the gunwale: 40 s for one person, 18 s for two, 13 s for three. The box holds 2 fish. | The wire is required (high transom). The tuna door means no lift. |
| Fish | Her range keeps her inshore: 150-350 kg. | She reaches the shelf: 350-600 kg, so longer fights and more set pieces. |
| Calls | Everyone is within 4 m. | A shout from the cockpit reaches the helm at 35% in gear and 70% out of gear. Down from the tower it's clear. |
| Doubles | | About 3x as many. |

**Four people on the skiff find the same small chores and idle. A bigger crew pays only on the boat that makes bigger work.**

---

## 5. Crew walkthroughs

The same seeded 300 kg runner every time, on the same director timeline:
- a green-water spell at about minute 6
- an under-the-boat dive at about 11
- a second wind at about 12
- a jump series at about 14
- a shark pass at about 9 (the one deferred major brought forward, section 6)

Moderate sea. Good players.

### Solo, skiff: about 20% landed, 28-34 min. Never idle, always behind.

**The strike**
- **0:00** Rod 1 goes. You're at the wheel. Neutral (0.5 s to stop the screws), 1.5 s to the rod, drag eased to 0.5 on the first tell.
- **0:25** He's run 190 m. Heat 0.35.
- **0:27** Into the holder, which costs you: he drifts and takes line on its drag. You wind the port line in (16 s).
- **0:45** Back on the rod at 210 m. w = 0.38, so your lay barely turns him. The boat has to be across his line, and only you can drive it.

**The middle, a 45-60 s cycle**
- Holder (he rests and drifts), then 20 s at the wheel running up on a slant and parking her off his run line. You also get the post's 1.0 s eye while you're there.
- Back on the rod: ride the gold, steer.
- Every 4-5 min the reel steams: holder, bucket (5 s).
- After each back-down, 15 strokes at the pump.
- **6:00** Green water while you're on the rod. You see the glass only when you next reach the wheel.
- **9:00** The shark pass: the fish bolts, you have no free hand for the harpoon, and you can only drop the drag and hope.
- **11:00** He dives under her. You're already in neutral (the solo habit), so you dip the tip and walk the rod round the console.
- **12:00** Second wind: the rim flashes back to blue-black. A false finish.

**The leader**
- **26:00** Leader up. His last run takes 40 m, with nobody at the wheel.

**Boatside**
- **28:00** Holder, harpoon between sheers, tail rope, a 40 s haul alone.

**Where it fails:** one slip in the order. A late bucket, the gear left in, or a jump while you're at the wheel.

### Two on the skiff: about 75%, 17-19 min. A on the rod, B skipper. Both busy throughout.

**The strike**
- **0:00** B goes neutral. A takes the rod and eases the drag on the tell.
- **0:02** B squares the stern, steps 2 m to the port rod and winds it in until 0:20. The knot risk is ticking.
- **0:18** A shouts *HALF SPOOL!* and notches down.
- **0:22** B is back at the wheel, runs up on a slant and parks her off his run line. At 220 m the boat does about 60% of the turning. From the post B sees the fin flare 1.0 s early and calls *LEFT!*.

**The middle**
- **1:00-10:00** A has a tell every 4-15 s, a lay correction every couple of seconds and a drag notch every 30-60 s. B moves the boat every 40-90 s and is the only one who sees the angle and the water. B also pours when he sees steam (about 4:10 and 8:20).
- **6:00** *WATER!* B pumps 12 strokes while A holds on a heavier drag.
- **8:30** A's arms are going (about 4 min of gold so far). They swap in 1.5 s and A takes the wheel.
- **9:00** Shark: B (now on the rod) drops the drag. A leaves the wheel 2 s to harpoon-scare it off the rail. A gamble: the angle drifts.
- **10:00-14:00** The grind. He circles deep. B planes her slow ahead (x1.3 drain), so every lap crosses the stern and A, at the wheel, keeps him off the corners. B winds on his up-swing for a GIFT each lap.
- **11:00** Under her: A goes neutral and tilts the leg. B dips and walks the rod.
- **14:00** Jumps: A, on the post, sees the bulge first and shouts. B bows.

**The leader**
- **16:30** Leader up. *BACK DOWN!*, 15 s.

**Boatside**
- **17:10** B holds the rod, A harpoons, and both haul (18 s).

About three peaks where both are maxed (heat + water + a run). Nobody idle.

### Three on the skiff: about 85%, 15-16 min. A rod, B skipper and spotter, C free hands.

- **0:00** C winds the port line in, so B steers from second 1 and the run stops at about 170 m.
- C's chores: pours (3x), pumps (5x), fends every planing lap at the corner, works the tilt at 11:00, takes the harpoon on the shark at 9:00 so nobody leaves the wheel, and takes the rod at about 8:00.
- C is idle about 25% of the time. That's the honest price of three on a small boat: "feasible and comfortable". The gamble that fills it is putting the port line back out for a double.
- **15:00** C harpoons, A holds, three haul (13 s).
- The skiff has no more work to give a fourth.

### Two on the sportfisher: about 35%, 22-26 min. The boat is a crew short.

**The strike**
- **0:00** The starboard rigger goes. B is at the cockpit helm, 8 m forward. A fights stand-up, because nobody is free to swivel the chair.
- B goes neutral and clears four lines: port rigger (1 s + 21 s), corners (2 x 16 s), the shotgun from its centre holder (31 s). About 110 s with the fish running unsteered and the knot rolls ticking. About 30% of the time they lose him here.
- *(If they had fished only two lines, there would have been less to clear, but about a quarter as many bites.)*
- **1:55** B back at the helm, 340 m out. Backing hard at 3.2 m/s in the sea ships water over the transom.

**The middle**
- **4:00-20:00** B shuttles between the cockpit and tower helms: the tower to see his flank far out, the cockpit to see the transom close in. B also runs 8 m for the bucket and clears the strainer when they cross a weedline.
- In-game shouts reach the cockpit helm at 35% in gear, so they rely on the icons, voice, or B easing out of gear to listen.
- Nobody stands in the tower while B drives from the cockpit, so deep, the chevron is late and sometimes wrong. Head turned about 25%.
- **9:00** Shark: nobody can harpoon. A drops the drag.
- **11:00** Under her: inside the blind spot, so A has to call it, and 9 s of coast rides her over the line (keel chafe).

**The leader and boatside**
- **21:00** Leader up.
- **22:00** B wires. A parks the rod and throws inside 15 s. Miss, and B re-wires.

Both are overloaded half the time.

### Four on the sportfisher: about 85%, 15-17 min at 300 kg (22-25 at 450, 28-32 at 600). A rod, B skipper, C and D free hands.

**The strike**
- **0:00** The shotgun goes. A takes it into the chair (3 s).
- C clears the port rigger and corner (38 s). D clears the starboard pair (40 s). All clear by about 0:42.
- B spins her on twin screws, squares the stern by 0:06 and backs on *HALF SPOOL*.

**The middle**
- **0:45** D goes up the tower (4 s). B takes the tower helm far out while w is low, with D beside him calling turns 1.95 s early. C swivels the chair on each call.
- **3:00** At about 120 m, B comes down to the cockpit helm. D stays up as the eye.
- C pours (3:30, 7:00, 10:00) and clears the strainer on *STRAINER!* when they cross a weedline at about 8:00.
- **9:00** Shark: D comes down, harpoons and scares it off. The tower is empty for 40 s.
- **10:00-14:00** Planing: B slow ahead, C fends at the corners, D calls the laps.
- **11:00** Under her: D sees it first (*UNDER! STARBOARD!*). B goes neutral, C fends, A dips.
- **12:00** Swap: C takes the rod, so D comes down to swivel and the tower is empty for 90 s. A trade-off.

**The leader and boatside**
- **15:00** D: *COLOUR!*
- **15:30** C wires, D harpoons, A holds and B keeps her square. Through the door (12 s).

Nobody idle. On her usual 450-600 kg shelf fish the director's majors stack up, and the weedline and strainer come round 2-3 times.

---

## 6. Keeping 30 minutes gripping

**The fight director** (new `tuna/fight_director.gd`):
- It is seeded from the fish's seed plus the world: weather, region and time of day. **It never reads crew size.**
- Nearby boats affect only *which* major is picked (later, a crossing boat), never energy or cadence. In the invariance test they are an explicit, logged input.
- It commits every move 2.5 s ahead and syncs it as "move X at sea time t". One schedule feeds the rod's tell, the eyes' fin flares and the network.

**Three clocks**, so the rod is never just holding a button:
- A tell every 4-15 s.
- A heading target every 6-12 s (4-7 s tired), with the heading curving continuously in between.
- A set piece: a minor every 60-90 s, a major every 4-6 min, never two fish majors at once, and forced after 90 s with none.

**Each major belongs to a different pair of hands**, so the spotlight goes round the boat:

| Major | Whose moment |
|---|---|
| A run | The helm and the spool |
| Sounding | The eye and the sonar, and the helm planes him |
| Under the boat | The helm's gear, the rail's fend, the rod's dip |
| A jump series | The rod |
| A sweep across the spread | Free hands winding lines |
| A green-water spell | Whoever pumps (from the weather) |
| **A shark pass** (brought forward to PASS 1) | The harpoon hand at the rail. The rod must drop the drag or he's bitten off. |

Minors include a debris patch or weedline, which is what feeds the sportfisher's strainer.

**The station chores come from the world, not a timer:** heat from slipping, water from backing and seas, the strainer from debris. They drift out of step with the fish's set pieces and sometimes pile up ("steam + water + he's running"). Those are the stories people tell after.

**The acts of a 450 kg shelf fish (about 23 min for a good crew):**
1. **The strike (0-2):** the burst run, the spread to clear, drag and heat. w is low, so it's the helm's game.
2. **The legs (2-10):** runs and soundings by nature, and full-strength head battles. The boat and the rod share the steering as the line shortens.
3. **The grind (10-18):** he circles deep (STEEP). Planing, wind on the up-swing for a GIFT each lap, eyes matter most, wear builds and swaps come due. The shark lives here. QUIET 22 s is kept.
4. **Second wind (one per 150 kg, at 60% and 35% energy):** the rim flashes back and the cadence goes "fresh" for 60 s. The false finish.
5. **The spiral (under 25%):** w = 1, so it's all the rod. Kicks hit x1.5 on the short line, the tell lead drops to 0.5 s, and you'll be notching the drag down to keep the gold within reach.
6. **The end (the last 3 min):** the last run, the wire, the harpoon, the 90 s hook clock, the door. Every hand at once.

**Escalation, all from the world:**
- The red comes down the gauge (permanent wear).
- Heat carries over from run to run.
- The spool's drag rises as it empties.
- Arms run down.
- The short line sharpens everything.
- The sea builds over the hours.
- In Rivals, the other boat may be on the same water.

**Lactic build-up** keeps the long end from sagging: drain x (1 + t / 20 min). No fight runs longer than 45 min.

**The readable ending** is his colour stepping from blue-black to bronze, with no bar.

**Deliberately left out:** a meat-burn clock (it punishes the 30-minute fight).

**Still deferred:** the squall and crossing-boat majors.

---

## 7. Information asymmetry

**Where your body is decides what you know. Roles have nothing to do with it.** Anyone standing at a spot gets what that spot knows, solo included.

| Spot | Knows | Doesn't know |
|---|---|---|
| **The rod** | The exact needle, the drag tick and the red. The 0.7 s tell. The spool. His head within the angler's own eye depth. His own arms. | The water, the depth, the strainer, a clog, anything early, or the line under her near the transom. |
| **The helm** | The precise stern angle (compass). Gear, throttle and coast. The water (sight glass or bilge light). Sonar depth and range (sportfisher cockpit helm). | On the sportfisher, the 6 m behind her transom. The spool. |
| **High eyes** (sportfisher tower 5.5 m and bridge 3.5 m, skiff post 2.4 m, which is at the skiff's helm) | His true heading and depth to 7h. His next move up to 1.95 s early. Every line in the water (tower). The line under her. The rival boat. | The gauge. |
| **The rail / door** | The line at the transom, fray puffs (within 3 m), his condition alongside, the wire's pull. | |

**Not counted as asymmetry** (the angler can see these in first person): the reel's steam and the rough line angle over the transom. These still cost the angler, because their hands are busy, and a pour means parking the rod.

**The Shout key** (V or pad Y). Your character barks the most urgent thing only *your* spot knows right now. A pixel icon (arrow, spool, drop, steam, prop, colour) pops over your head for 2.6 s with a voice bark. Hold the key for a 6-way wheel.
- **At the rod:** *HALF SPOOL! BACK DOWN!*, *ARMS!*
- **At the helm:** *OFF THE PORT QUARTER*, *WATER!*, *STRAINER!*, *HE'S DEEP*
- **From an eye:** *LEFT / RIGHT / UNDER / HE'S GONNA GO*
- **From the rail:** *STEAM!*, *RUBBING!*

The bark is heard by proximity, with the engine duck. The icon shows at any range, but **only to your own boat**. Rivals hear only the proximity bark.

**Today's auto-calls go.** `rods/fight_calls.gd` currently shouts the fight to everyone whenever `crew_n > 1`. That is crew-size-gated, which breaks rule 3. Calls now fire only from the Shout key. Dale's first-time VHF lines stay as the tutor.

---

## 8. Sloppy vs good crews

**The core idea:** fish are lost at decisive moments, where one spot had to act on what only another spot knew. The **boat** sets how many of those moments there are.

- **Skiff, about 7 per 300 kg fight:** 1 line, the spool, under the hull once, heat about 3x, water about 4x, the shark, boatside. Everyone is within 4 m.
- **Sportfisher, about 14 (recounted honestly):**
  - 4 lines, each a knot roll that adds drag
  - the helm 8 m away, muffled and blind at her transom
  - the tower-to-cockpit helm change
  - 9 s of coast
  - the strainer, only in debris
  - the chair's facing
  - the wire's 15 s window between two people
  - bigger fish with more majors
  - a tower worth nothing if it's empty or silent
  - 3x the doubles, which split the crew
  - the far-out blend, where the helm and an eye must talk to put her on his flank

**Why sloppy big does worse:**
- A sloppy player fails each moment 25-35% of the time, and each failure is about 15-40% of a loss. Seven moments leaves a sloppy skiff duo at about 35%. Fourteen leaves a sloppy quad at about 25%.
- An uncoordinated sportfisher fight also runs about 50% longer (head turned about 15%, angle 0.7), which means more majors and more heat.
- Cheating the moment count by fishing a 2-line spread starves her of bites (the teaser effect).
- Taking her inshore for small fish still costs her $13k payment.
- "Sloppy" is modelled as **missed or late calls**, not unheard ones, so a Discord crew isn't let off. No sim gate leans on the in-game muffle.

**Why a good small crew can beat a sloppy big one:**
- A good skiff duo lands about 75% of 150-350 kg fish in about 17 min, about 2 fish a trip, about +$5k net.
- A sloppy quad nets about $0.
- A good quad (85%, 450-600 kg, doubles) nets +$10-15k. That's the galleon payoff, earned only by coordinating.

**Money and crew size:** the current `SHARE` cut (`boat/fish_hold.gd:66`, applied at `:624`) scales with the players aboard, which breaks rule 3. The proposed replacement is **berth wages per boat**, a per-trip crew cost in `kinds.gd` paid whoever fills the berths. Re-run trip_sim with it before deciding (open question 1).

---

## 9. Tuning targets

### Fight constants (starting values, tuned in fight_sim)

**Fish**
- Energy E = 5 x kg^0.9.
- Drain per second = (T/0.5) x band (EDGE 1.6, else 1.0) x GIFT 2.0 x angle 0.35..1.0 x planing 1.3 x lactic (1 + t/20 min), and x0.2 in the holder.
- Recovery: +0.3/s x his pull's share while T < 0.2.

**Gain**
- 1.8 m/s x wind x band (SLACK 0, WORK 1.0, EDGE 1.4, pinned 0).
- x2.5 in a GIFT, x0.3 with spent arms, x1.25 with the two-speed reel.

**Tension**
- Target = pull + 0.35 x wind, eased with tau 0.5 s.
- SLACK < 0.12, WORK to 0.8 S, EDGE to S, red at St.
- Past St for 0.25 s parts the line. St floor 0.5.
- S = lever x 0.9, notches 0.1, detent 0.6. The kick cap is 1.6 S.

**Kicks**
- +0.30..0.55 for 0.3 s.
- x1.5 inside 60 m. x0.5 if you ease during the tell. x1.5 as often when |lay| > 0.7.
- Tell lead 0.7 s, 0.5 s inside 30 m.

**Head**
- Fills 0.25/s x |eff_lay| x T/0.5 (T > 0.25). Drains 0.5/s the wrong way.
- w = clamp(80/line_out, 0.35, 1). Rod side normalised by /0.9. Tip high x0.5 on the rod's part.
- boat_cross is measured against a 30 s run line.
- GIFT 4-6 s, with an approach cap of 3.5 m/s and a 1.5 s slack grace.
- Heading target every 6-12 s fresh, 4-7 s under 40%, x max(1, line_out/80).

**Eyes**
- Depth 7h, range 60h, lead clamp(0.3 + 0.3h, 0.7, 2.2).
- Out of sight, the chevron lags 3.5 s and is 25% wrong-side.

**Heat**
- +0.0045 x S x slip per second (raise to 0.006 if good crews never reach the fade), -0.004/s by itself.
- Fade at 0.7. At 1.0: squeal 1 s, then a grab at 0.95 until heat < 0.6. A bucket takes off 0.35.

**Water**
- Skiff: ships 0.006/s backing, hand pump -0.012 a stroke.
- Sportfisher: ships 0.006/s backing faster than 2.5 m/s in a sea. Electric pump 0.03/s. In debris it clogs after 0.25 +-0.08 pumped, and clearing takes 4 s.
- Over 0.6 the boat goes astern at half speed. At 1.0 the engine drowns, and restarting takes 3 s.

**Arms**
- Drain only in gold or pinned: about 4 min of gold. Rest 40 s, holder 30 s.
- Chair: arms last x2, lay cap 0.5, swivel 0.2/0.8 rad/s.

**Kept:** CHAFE_LIFE 14 s, fend x0.2 (6 s holds), PROP_GRACE 2.5 s, tilt 2 s, neutral 0.5 s.

**Director**
- A minor every 60-90 s, a major every 4-6 min, forced after 90 s without one.
- One second wind per 150 kg.
- The queue pauses during a GIFT.

### Landing targets (good / sloppy players: landed %, median minutes)

| Fish and boat | Solo | Duo | Trio | Quad |
|---|---|---|---|---|
| 300 kg, skiff | 20% / 3%, 31 / 38 | 75% / 35%, 18 / 25 | 85% / 45%, 15 / 21 | about the trio's |
| 300 kg, sportfisher | 6% / 1% | 35% / 8%, 24 / 32 | 65% / 20%, 19 / 27 | 85% / 25%, 16 / 23 |
| 450 kg, sportfisher | | | | 80% / 18%, 23 / 33 |
| 600 kg, sportfisher | | | | 70% / 10%, 30 / 40 |
| Rivals ledge fish (120-200 kg), skiff | 40-55% | | | |

By weight, a skiff duo takes about 9 min on 150 kg and about 21 min on 350 kg.

### Sim gates (all must pass before any feel pass)

**Landing and balance**
- Every cell is within +-8 points of its target.
- The sloppy sportfisher quad is at least 8 points below the sloppy skiff duo, including when the quad fishes a 2-line spread.
- The good skiff duo beats the sloppy quad in fish per hour.
- A skilled solo skiff lands 15-25%.
- A holder-heavy solo bot lands fewer fish than a rod-heavy solo bot.
- A mouse-binary bot reaches at least 85% of an analog bot's gold time.
- Heat reaches its fade (0.7) at least once per 300 kg fight for good crews.

**Pace and busyness**
- The rod gets a decision every 8 s on average, and never goes 20 s without one.
- Never 90 s without a set piece. No fight runs longer than 45 min.
- The skiff duo's skipper is busy at least 70% of the time, including in the grind.
- The sportfisher quad's least busy station is busy at least 60%.

**Invariance**
- CREW INVARIANCE: one recorded input trace, replayed with 1-4 peers connected (the extras idle elsewhere), gives an identical director timeline and fish path.

### Money (trip_sim, $18/kg, with berth wages instead of SHARE)

- Good skiff duo: about +$5k a trip.
- Sloppy sportfisher quad: about $0, and negative inshore or on a 2-line spread.
- Good sportfisher quad: +$10-15k.

---

## 10. Build plan

Build in passes and re-run the sims between each one. **No feel pass until PASS 0's tables and gates are green.**

**PASS 0: the sims and the guards**
- `tests/fight_sim.gd`: station bots (rod, helm, deck, eye) with good / sloppy / distracted profiles.
  - Reaction: 0.3 / 1.2 / 3 s.
  - Missed or late calls: 10% / 35% / 60%.
  - Plus a mouse-binary rod bot and a holder-heavy solo bot.
  - Runs boat x crew 1-4 x skill against every target and gate above.
- New `tests/crew_invariance_test.gd`: the recorded-trace replay with 1-4 peers.
- `tests/trip_sim.gd`: money per trip, including the inshore sportfisher cell and the 2-line spread cell.

**PASS 1: `tuna/fight.gd` and the director**
- **Keep:**
  - the spring and tension, the drag lever, the spool and backing, spool_gain, BELLY
  - natures, MOVES and phases
  - HOOK_T/HELD_T, JUMP_T, SLACK_LOOSE
  - the chafe outline, WORN_K, PROP_GRACE
  - SQUARE/WIDE/STEEP
  - ARM_*, the holder, BOATSIDE and LEADER, the signals
  - the "every loss is something somebody could have done" contract
- **Replace:**
  - the ROD_LEVER lift-gain and CRANK_MAX grind, with the band gain
  - the line-relative bands, with drag-relative bands
  - STATIC 1.2, with a kick cap of 1.6 S
- **Add:**
  - the eased tension target
  - the head meter and the GIFT with the w blend: `step(crank, rod_pitch, side, drag)` gains a `boat_cross` argument
  - St as the one wear number
  - heat (fade, squeal, grab, cool)
  - the drain formula with planing and lactic build-up
  - the colour steps
  - second winds
  - knotted tangles with knife cuts
  - the holder costs
  - arms that drain only in gold
- **New `tuna/fight_director.gd`:**
  - acts, minors and majors, including the **shark pass** and the debris minor
  - the 2.5 s committed queue, which pauses during a GIFT
  - inputs: seed, weather, clock, region, and nearby boats for major choice only
  - no crew input

**PASS 2: the hands and the HUD**
- `rods/rods.gd`:
  - the wind ease, rod_pitch for bow/dip/lift only, the pad remap (left stick walks at 50%, right stick lays and sets height, R3 frees the look)
  - the 1.5 s handover
  - the bucket, fend and knife hooks
  - rod-holder authority: the peer holding the rod owns T, wind and lay. The host owns the director, the fish path and line_out, and reconciles at 10 Hz. A handover carries T, heat, the head meter and any tell in progress.
  - remove the crew_n plumbing at `rods.gd:1502-1505`
- `ui/fight_hud.gd`: the 48 px drag-relative gauge with the hatched red, the chevron (grey/green fill, freshness rim, rotation), the spool art. No in-fight text.
- New `rods/fight_fx.gd`: line colour by band, rod bend frames, steam, fray puffs, the wake flip.

**PASS 3: the boat stations**
- `boat/kinds.gd` gets new per-boat fields:
  - bucket position
  - pump (hand or electric, rate, debris clog)
  - astern shipping
  - tilt
  - sonar
  - helm_hear
  - helm_blind
  - eye spots
  - chair
  - the tower helm
  - teaser factor by spread size
  - berth wages
- The skiff's automatic `bilge` 0.004 (kinds.gd:78) is removed.
- `boat/green_water.gd`: backing inflow, hand strokes, the debris clog, the drowned engine.
- New `boat/bucket.gd` and `boat/bilge_pump.gd`, modelled on `boat/live_well.gd`'s pump.
- `boat/helm.gd`: the compass, the glass or light, the tilt, holding its last setting, and the sportfisher's tower helm (throttle and wheel only).
- `crew/spotter.gd`: the eye-height shadow, fin flares and the line view, drawn only for that viewer.

**PASS 4: calls and the crew-size cleanup (rule 3)**
- `rods/fight_calls.gd`: `tick()` drops `crew_n`. Calls fire only from the Shout key, using the shouter's spot. They're heard by proximity, and the icons show to your own boat only.
- `ui/fight_tutor.gd:186/197/201` and `tuna/landing.gd:719/807`: key the prompts off world state ("is the rod held by someone else", "is anyone in earshot") instead of `_crew_aboard()`.
- SHARE (`boat/fish_hold.gd:66/624`, `trip_sim.gd:134`, `tests/shares_test.gd`): swap it for berth wages **only after the user signs off**.

**PASS 5: Rivals**
- An inshore ledge region with 120-200 kg fish.
- Scoring is weight landed plus colour steps reached on a fish still on at the horn.
- Shout icons are hidden from the rival boat.

**PASS 6 (deferred until the tables pass):** the squall and crossing-boat majors.

**Leave alone:** `schools.gd`, `live_well.gd`, landing.gd's boatside, and handling.gd's processing.

---

## 11. The critique: what was changed and what was rejected

All 33 points were reviewed.

**Accepted as written:**
1. Bands relative to the drag, the kick cap at 1.6 S, the wind target pull + 0.35 x wind.
2. Holder drain x0.2, faster drift, holder heat and the bot gate.
3. Tip high halves the side pressure.
4. The teaser effect and the 2-line gate.
5. The inshore sportfisher cell in trip_sim.
6. Knotted tangles, with wind or knife.
7. The crew-size gates in the calls and prompts are removed.
11. The rod holder's peer is authoritative.
12. The recorded-trace invariance test and the GIFT pausing the queue.
13. Planing, laps across the stern, winding on the up-swing in the grind.
15. The dim chevron lags 3.5 s and is 25% wrong-side.
16. The tower helm.
17. Arms drain only in gold.
18. Lactic build-up, E = 5 x kg^0.9, and the 45 min cap.
19. Continuous heading and the kick risk from a hard lay.
20. The 30 s run line and the stretched intervals.
21. The /0.9 normalisation.
22. The GIFT speed cap and slack grace.
23. Neutral stops the screws in 0.5 s, and the coast rides over the line.
24. The pad and mouse remap.
25. The chevron's fill and rim split.
26. The tau 0.5 s ease, the wider gold and the mouse gate.
27. Steam and the rough angle are not counted as asymmetry.
28. Icons only to your own boat.
29. Sloppy means late, not unheard.
30. Nearby boats pick majors only.
31. Solo at 15-25%.
32. The heat check.

**Accepted with a choice made:**
- **8:** berth wages per boat replace SHARE, pending the user's sign-off.
- **9:** the ledge region and progress scoring. The round cap is left to the user.
- **10:** the strainer is kept but clogs from debris. The sportfisher ships water when backing hard in a sea. Her moment count is re-done honestly (16 down to 14).
- **14:** the skiff's post eye belongs to whoever drives, which makes the skiff skipper the spotter. The skiff trio's C idles about 25%, and that's stated rather than hidden.
- **33:** only the shark is pulled forward, because it gives the grind a harpoon-hand moment cheaply. The squall and the crossing boat stay deferred, to protect scope.

**Rejected:**
- **10's other option, dropping the strainer.** It is the sportfisher's one chore that only the helm can see and only a free hand can fix, which is exactly rule 6. It just needed a better trigger.
- **27's implication that the compass adds nothing.** The angler sees the angle only roughly. The compass's precise green arc still matters when the angler is deciding to plane or square up, so it stays a helm instrument. It just isn't counted as hidden information.

---

## 12. Open questions for you

1. **Replace the per-player SHARE cut with per-boat berth wages?** SHARE scales with players, which breaks rule 3.
   *Recommended:* yes. About $300 a trip on the skiff and $1,800 on the sportfisher, paid whoever's aboard, with the numbers set by trip_sim.
2. **Remove the skiff's automatic bilge pump, so she has a hand pump only?**
   *Recommended:* yes. The water becomes a real chore you do by hand, and it's the main thing that makes solo barely possible.
3. **Rivals 1v1: fish an inshore ledge (120-200 kg) and score weight plus colour progress at the horn?**
   *Recommended:* yes, with a 20-minute round and the rival's fish colour shown on their boat. That makes your 1v1 with your buddy fun instead of 30-minute losses.
4. **In Rivals, do teams pick their boat, instead of the boat being assigned by crew size?**
   *Recommended:* yes, a free pick. The boat's demands do the balancing, and a good duo choosing the sportfisher is a fair gamble.
5. **Remove today's automatic fight calls entirely, leaving the Shout key and Dale's VHF tutor lines?**
   *Recommended:* yes. Dale's tutor carries the first three fights, and the Shout wheel is taught on the first strike.
6. **Is about 16-18 min for a 300 kg fish (good crew) right, with the full 30 minutes reserved for 600 kg shelf fish?**
   *Recommended:* yes. The 30-minute fight is the trophy, everyday fish stay a bit over 15 min, and nothing passes 45.

---

## Decisions (the user, 2026-11-03)

1. **Crew pay:** none. The whole crew shares one wallet: the boat's money. No per-player shares or wages. (This replaces both the 12% share and the wages idea.)
2. **Skiff bilge:** hand pump only. No automatic pump.
3. **Rivals 1v1:** yes, as proposed. An inshore ledge, 120–200 kg fish, 20-minute rounds, scored on weight plus how beaten your hooked fish is at the horn.
4. **Rivals boats:** any team may choose a bigger boat, but every boat has a player cap. A team of 4 can't take a two-person boat. The skiff's cap is **2**, so three or more need the sportfisher. The walkthroughs that put three on the skiff are void; the sportfisher's balance must work for 3 and 4.
5. **Fight calls:** the Shout key only, plus Dale's tips. No automatic crew shouts.
6. **Fight length:** about 16–18 min for a 300 kg fish, and about 30 min for rare 600 kg trophies.
