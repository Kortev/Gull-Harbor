# The fish fight: design from the brainstorm

Winner: **Loaded Rod, Crewed (v2): one spring between your hand and the fish, a camera that keeps the water in frame, a hand on the drag, and a director behind the fish** (boss score 84/100, after three rounds: 76, 79, 84).

Boss's remaining notes: 1) SCOPE IS NOT TWO DAYS. The 2-day plan holds: the fight.gd rewrite, the director, the triggers, hull_wrap.gd plus outlines for both boats, decoupling player.gd's camera from the rod with follow and glance, the rod-weight lease, a host-arbitrated networked lever at 10 Hz, three new audio loops, spool and backing, the wallow animation, a full cues()-only bot rewrite, and a property test. Honestly that is 4-5 days. Draw a hard cut line. Day 1: spring, tension, hook hold, the camera rule, and solo scroll drag, and nothing else. Day 2: HullWrap and the rod/line feel. Day 3 (named as such): the director beats, the mate lever, and the wallow. Each stage has to be shippable alone. 2) LEASE BUG. In Godot, player.gd's _input runs before rods.gd's _process in the same frame. So when mouse motion arrives, rod_load.frame is always the previous frame, and the check frame == Engine.get_process_frames() makes the rod permanently neutral. Accept frame >= get_process_frames() - 1, or have rods.gd pull the mouse delta instead of player.gd pushing weight. 3) THE MATE IS STILL MOSTLY A KNOB-HOLDER standing 1.3 m from the angler, which is borderline busywork for a 5-minute fight. Bring the follow-up 'fend the line off the rail by hand at the via point' into the core: it is the co-op payoff for exactly the wrap the user complained about, and the via point already exists. Also let the mate leave the lever at a setting and walk off to do it. 4) Glance on Alt alone will feel like the camera is taken away. In Sea of Thieves you always own the camera. Make the follow strength a setting (0 = free look, with the rod still following mouse delta), or let large mouse-X beyond the rod's side cap spill into free camera yaw. 5) Too many coupled magic numbers (spring, capstan, hold, breath, side tiring, cushion) to tune in a day. Build the headless bot harness first and tune against it before any feel pass, and state the 3-4 numbers that matter most. 6) Rivals 1v1 has no interaction beyond watching. Fine as a follow-up, but say so plainly. 7) The proposal's 'crewmate gaffs it' isn't delivered: landing.gd is unchanged. Either keep landing as is, or tie the existing harpoon to the lunge-survival moment.

## Pitch

The whole fight is one quantity, line tension, and you feel it in your hand. The fish drags your rod tip down, fights every heave, gives way as you drop and wind, and turns its head when you lay the rod over against it, while the camera stays on the line and the water where the fish shows itself. The mate rides the drag lever at your shoulder, the captain backs down while you wind, and a seeded director gives every fish an arc you never quite memorise: opening run, the grind, a comeback, a giant wallowing at colour, and a lunge at the boat.

## Controls

The angler's controls are built on what exists: player.gd's _yaw/_pitch/look_scale and the _in_hands() call in rods.gd. While a fish is on, the mouse drives the ROD, and the camera FOLLOWS the rod at a fraction, with a cap. This is must-fix 1, solved as a design problem and not as a risk.

ROD AIM, DECOUPLED FROM THE CAMERA (new in player.gd: rod_aim_pitch, rod_aim_side):
- MOUSE Y drives rod_aim_pitch at full ratio over 0.15 rad (tip at the water) to 1.35 rad (near vertical), at 0.0035 rad per pixel, so a full heave is about 340 px. _in_hands() reads rod_aim_pitch instead of _pitch while fighting. The tip travels about 1.7 m along the line.
- MOUSE X drives rod_aim_side at full ratio over -0.9 to +0.9 rad, measured against the line's yaw. That is side pressure. The rod also swings the tip up to 0.8 m outboard, which matters for the hull wrap (see build_plan).
- CAMERA FOLLOW: the camera aims at the line's water entry point, and offsets by the rod at a fraction.
  - Pitch: cam_pitch = entry_pitch + 0.35 * (rod_aim_pitch - 0.75), clamped to entry_pitch -0.12 / +0.28.
  - Yaw: cam_yaw = line_yaw + 0.4 * rod_aim_side.
  - The camera eases toward that target at 6 rad/s.
  - entry_pitch = the pitch from your eye to where the line enters the water, clamped to -0.75 .. 0.05.
- What that means on screen: at full heave the camera rises only about 0.2 rad, so the line, the water and the fish stay in frame. The rod butt and the curve of the bend stay in frame too. The very tip leaves the top of the frame above about 1.15 rad, which reads as "high" and is fine, because you read the line and the water and not the tip. At full side pressure the camera is turned 0.36 rad and the line is still well inside the 0.9 rad horizontal half-FOV.
- GLANCE (hold Alt, or the left bumper on a gamepad) is OPTIONAL, never required (must-fix 4). The rod freezes, the camera turns freely, and on release the camera eases back over 0.25 s to the rod's frame. Nothing in the fight needs it: the mate stands at your shoulder inside the camera's normal frame, and the crew's information reaches you by voice. It exists only to look at your friends.

THE PUMP:
- LEFT MOUSE (hold) cranks at CRANK 2.4 m/s (x crank_mul). Line actually gained = CRANK * clamp(1.25 - T/drag, 0, 1). With the rod loaded the handle grinds. With the tip dropped it whirs free.
- A good pump: mouse up over 0.6-1.2 s to heave the fish about 1.5 m with the reel silent, then mouse down while holding LMB to wind it back.
- Use short fast strokes on a steep, deep line and long slow sweeps on a fish that is up.
- RIGHT MOUSE (hold) raises the rod at 0.9 rad/s, an accessibility alias for trackpads.

DRAG, SOLO (must-fix 6): the SCROLL WHEEL nudges the lever one detent per notch, with the rod still live.
- The detents are FREE 0.0, LIGHT 0.45, STRIKE 0.72, FULL 0.95, each with a click.
- Rate limit: one notch per 0.2 s. So dumping from FULL to LIGHT takes two notches and 0.2 s. That is fast enough for a lunge if you see it coming, and slow if you don't.
- The old R-freezes-the-rod lever is deleted, so solo players are no longer pushed into leaving it at STRIKE forever.
- Solo drag is detents only.

ROD WEIGHT, through a lease so it can never stick:
- rods.gd writes player.rod_load = {up_scale, drift, yaw_drag, frame} every frame you fight.
- player.gd applies it only if frame == Engine.get_process_frames(), else it is neutral that same frame.
- The values:
  - up_scale = 1 - 0.55 * T * weight_setting, applied to the upward rod_aim delta only.
  - drift: the rod sinks toward the line at up to 0.35*T rad/s.
  - yaw_drag: on a run, rod_aim_side is pulled 0.08 rad/s toward the fish.
- So every exit path (Q, a handover, loss, landing, falling, disconnect, pause, death) restores a neutral mouse that frame, and rod_aim stops being read.
- A "Rod weight" slider runs 0-100% (default 100).

Q puts the rod in its holder and E takes it, as now. The holder pins the rod at pitch 0.6 and side 0, with no crank, and the drag stays where it was left.

MATE (any crewmate not on the rod or the wheel):
- Stand within 1.3 m of the angler, look at the reel and press E to take the lever.
- MOUSE Y moves it CONTINUOUSLY (0.0-1.0, with soft detent clicks felt as a slight sticky zone of ±0.03).
- So the mate can sit between detents, for example 0.85 in a dog: the sweet spot solo scroll cannot reach, and that is the mate's mechanical edge over solo.
- E again, or walking away, lets go. The solo scroll is locked out while a mate holds the lever.

CAPTAIN: helm as now (throttle, wheel, backing down). There is no fight UI.

## Fish Behaviour

The fish has INTENTS, not answers. Each move shapes only thrust (0..1), heading relative to the line, turn rate and goal depth. In fight.gd's MOVES, "answer" is replaced by thrust/jitter/tag.

MOVES:

| Move | Thrust | Duration | Tag | Notes |
|---|---|---|---|---|
| RUN | 1.0 | 5-12 s | PEAK | Away from the boat, 20 m deep. |
| SOUND | 0.8 | 6-10 s | PEAK | Down to 110 m. |
| DOG | 0.45 | 4-8 s | VALLEY | Sulks deep. "rest" is kept as an alias for rod sync and carry_on. |
| SHAKE | 0.3-0.9 oscillating at 3-4 Hz | 1.5-2.5 s | PEAK | |
| CIRCLE | 0.6 | 6-10 s | VALLEY | Sideways at its turn rate. |
| SURGE | 1.0 | 1-2 s | PEAK | |
| JUMP | | | PEAK | Under 60 kg weight 1.2, 60-150 kg weight 0.4, giants 0, near the surface only. |
| WALLOW | | | PEAK | New, see below. |
| SPIRAL | | | | The finale, geometry kept as now. |

Within a move, thrust gets ±0.15 of smoothed noise.

TENSION (the core, unchanged from the scored design):
- stretch += (fish_v_away + tip_v_toward_you + crank_eff - boat_closing) * dt
- SPRING = 0.8 + 0.012*line_out, and T = stretch/SPRING.
- The drag slips when T > drag: line pays out and the reel screams.
- T = min(T, drag) + 0.45*crank*slipping + shock*(1.3 - cushion), where cushion = clamp((rod_pitch - line_pitch)/0.9, 0.2, 1).
- At a hull contact, T_fish = T * exp(0.25*wrap_angle). The line breaks when T_fish >= 1.0 for 0.3 s.
- The fish swims away while pull = thrust*e*size exceeds T. Otherwise it comes in at (T - pull)*3 m/s.
- Tiring: energy -= T*thrust*e*dt/_goal_s.
- Breath back: with T < 0.2 for over 1 s it regains 0.012/s (giant) or 0.02/s (schoolie). That is what punishes slack and the holder.

SIDE PRESSURE, WITH TEETH (must-fix 3):
- side_eff = rod_aim_side * clamp(T/0.6, 0, 1) * cushion. Side pressure needs load; a slack rod laid over does nothing.
- AGAINST its turn (sign(side) == -turn_sign, i.e. the rod held to the side opposite where its head is going):
  - Turn rate x (1 - 0.7*|side_eff|). At full effect it barely swings round the boat.
  - In a CIRCLE, move_t advances x (1 + 1.5*|side_eff|), so held well a circle ends up to 2.5x sooner.
  - Extra tiring: energy -= 0.5*|side_eff|*thrust*e*dt/_goal_s (it fights the turn).
  - TURNING THE HEAD: |side_eff| > 0.5 held for 2.0 s in a circle or a dog ends the move. turn_sign flips, and the fish swims 2 s TOWARD the boat (pull-in +1.5 m/s). That is the payoff, worth about 6-10 m of line.
  - On a RUN, side pressure against it cuts the remaining run time by 30% and bends the bearing 0.08 rad/s toward the rod side, so the captain chases less.
- WITH its turn: turn rate x (1 + 0.3*|side|) and no extra tiring. A mistake, but a gentle one.
- What you SEE: bearing's rate of change is the line sweeping across the stern. You watch the sweep slow, stop, and the line swing back the other way as its head comes round. On the head-turn the fish's boil and silhouette (under 30 m) visibly change direction, and the rod's bend unloads for half a second as the fish comes toward you.
- The verb is "steer the head", and it is the main way to SHORTEN a circle or a dog. Bot target: a pumper using side pressure lands giants at least 15% faster than a plain pumper.

PACING DIRECTOR (about 70 lines, deterministic from the fish's seed):
- At hookup it builds a beat queue tagged PEAK or VALLEY.
- Rules:
  - At least 12 s between peak starts (8 s for a schoolie).
  - Never two runs in a row.
  - A valley lasts at least 6 s.
  - Peak intensity is scaled by energy, except the guaranteed beats.
  - A valley over 15 s gets a SHAKE dropped into it.
- The fill between beats comes from the existing _pick() weighting, filtered by those rules.

GUARANTEED BEATS, jittered from day one (must-fix 5). Every trigger is rolled from the seed at hookup:
1. OPENING RUN at the strike: 8-20 s for a giant, 4-8 s for a schoolie. Its direction is seeded: off the quarter, straight astern, or across the bow.
2. SECOND WIND, giants only: at energy 0.55 ± 0.08, a full-strength peak of 8-12 s. 70% a run, 30% a sound to 120 m.
3. COMEBACK, every fish over 100 kg: at line_out 40 ± 8 m.
   - 60% a RUN taking 30-60 m back at 0.8 of fresh speed.
   - 40% a hard SOUND straight down to 70-100 m under the boat. The line goes vertical off the transom; it needs short pumps and the captain clear of it.
   - So you know something is coming around 32-48 m, never exactly what or exactly when.
4. WALLOW at colour, new for giants and 50% of 60-150 kg fish (must-fix 7). See below.
5. BOAT-SHY LUNGE, every fish over 100 kg: at line_out 15 ± 4 m, 2-3 s of thrust 1.0.
   - Seeded direction: straight down, under the hull (toward the props, where the existing prop-cut check gets teeth), or along the side.
   - Schoolies get a 0.7-thrust lunge 50% of the time.
- One authored CIRCLE TOWARD THE BOW per fight, on boats with 2+ crew, placed in the first-half grind at a seeded time. It is the wrap set piece.

WALLOW (the giant's visual peak):
- It triggers when the fish is first in the spiral under 30 ± 5 m. The giant comes up and rolls on the surface for 3-4 s.
- The Tuna node rises to depth 0.3. Its sickle tail and back break the water. It makes 2-3 TAIL SLAPS (seeded timing, 0.9-1.4 s apart): white fountains, a hard slap SFX, and its flank flashing silver.
- Each slap is a shock spike of 1.6 * size_factor * (1.3 - cushion) through the spring. A slack line during the roll wears hook hold at head_motion 2.0.
- The right play is the same physics as a jump: a bent, cushioned rod (tip up and to the side, not pointed), the line kept tight but not cranked, and the drag down a touch.
- It is the moment the whole crew stops and looks: the fish people care about finally shows itself before the lunge.

HOOK HOLD (one emergent rule):
- hold starts at 1.0 and the hook tears at 0.
- It wears two ways:
  - Shock over the top: hold -= max(0, T_peak - 0.9)*2.0 per spike.
  - Slack while the head moves: hold -= head_motion*(T < 0.12)*dt*0.8, where head_motion is 1.0 in a shake, surge or wallow, 0.4 otherwise, and 2.5 airborne.
- It heals 0.05/s while 0.25 < T < 0.8.

JUMPS are physics, not checks:
- The rise flattens the line and the tension goes away under your hand.
- 0.7 s airborne: the body swing is a shock of 2.5x its weight factor, at head_motion 2.5.
- Re-entry shock = 0.6*size*(rod_pitch/1.35)*(1.3 - cushion).
- So dropping the tip ("bow to the king") is simply the low-shock choice, and half-right play is half-safe.

SCHOOLIE (20-40 kg):
- Its pull never beats STRIKE drag.
- It is lost through hook hold (2-4 jumps, shakes twice as often).
- Turn rate x1.6, so side pressure is the main tool.
- 60-90 s.

GIANT (250-400 kg):
- Pull 1.4 against a drag of 0.72, so it takes line on every run.
- It sounds to 110 m and dogs deep.
- It has the second wind, the comeback (run or sound), the wallow and the lunge.
- 4-6 min played well.

## How You Read It

No fight text at all. hud.fight() gets an empty tell, the strain ring is removed, and the HUD plot overlay is removed. Everything below is in the world, and the camera rule (rod-follow at 0.35x, aimed at the line's water entry) guarantees the line and the water are always on screen to read.

ROD:
- The bend is driven by T, and it now bends TOWARD THE VIA POINT when the line is on the hull, not toward the fish.
- The blank quivers at 23 Hz from T 0.85.
- A creak from T 0.92, its pitch rising with T. Your one warning.
- When the hook pulls, the rod springs straight with a soft whip and the line floats slack.
- When the line breaks, a sharp PING plays and the line snaps back in a coil.
- Two different sounds and two different pictures.

LINE:
- Dead straight above T 0.5, sagging below 0.2 (the existing sag code, fed T).
- Thrums above 0.8 (0.01-0.03 m vertex jitter).
- The angle into the water is the depth: steep means sounding (and the comeback-sound goes vertical off the transom), flat and rising means coming up.
- SWEEP across the stern is the fish's turn. Side pressure shows as the sweep slowing, stopping, and swinging back.
- At a hull contact it is drawn as two segments bent over the rail at the real via point, with a fleck of spray and a squeal whose pitch is the slide speed. It shows nothing when the line does not actually touch, which fixes the user's complaint.

REEL (the fight's main sound):
- The drag scream's pitch is the run's speed.
- A free whir on the drop.
- A GRIND loop when crank_eff < 0.3 (stop cranking, pump).
- A slow tick-tick when it barely slips.
- A detent click on each lever notch, audible to anyone near, so the angler hears the mate's changes.

SPOOL:
- A cylinder shrinks with line_out/500.
- The last 100 m is WHITE BACKING.
- Bare metal shows at 15%.

HAND: the rod weight on the mouse (heavier upward and sinking toward the line under load). On a jump's rise the weight falls away under your hand. me.shake is fed by shock, so headshakes and tail slaps knock the view.

WATER:
- A boil on runs and slaps on shakes (as now).
- Jumps: the fish clears the water for 0.7 s.
- The silhouette shows under 30 m of line (_show_fish keyed on line_out), brightening as it shallows, and turning visibly on a head-turn or a lunge.
- The spiral's side flash going up and its dark back going under.
- The WALLOW: back, tail and fountains on the surface, the giant's visual peak.

CAPTAIN: reads the line angle and sweep off the stern, the bend, the hull squeal and spray, and the line slicing under the transom when the fish goes for the props. There is no instrument on either boat in the core (the sportfisher plotter is a follow-up).

INFORMATION ASYMMETRY (why the crew talks):
- The angler feels the weight but can't see the contact behind their shoulder.
- The mate sees the spool, the lever and the contact.
- The captain sees the line and sweep from above and behind.
- Proximity voice carries it, and the game never says it for them.

AFTER A LOSS ONLY: one small 3 s caption ("Line parted on the gunwale", "Hook pulled: slack in a headshake", "Hook thrown on the jump", "Spooled", "Cut on the props"), passed from _end_mine.

Bots read only Fight.cues(): rod_bend, line_pitch, line_sweep, reel_state, spool, contact_angle, fish_visible_depth.

## Lose And Win

LOSING, always visible and caused by play:

| Loss | Trigger | Causes | What you see |
|---|---|---|---|
| BROKE | T_fish >= 1.0 for 0.3 s | Cranking into a run; FULL drag on the lunge; a pointed rod through a shake or a wallow slap (no cushion); a wrap adding capstan tension | Ping and a coil |
| PULLED | Hook hold reaches 0 | Slack while the head works; shock spikes; a tight line with the tip high through a jump; the captain backing down while nobody winds | The rod springs straight |
| SPOOLED | 500 m out | | The white backing warned you |
| CHAFED | Wear at the real contact only | | |
| CUT (props) and TANGLE | Kept from today | | |

Chafe wear = slide_speed * wrap_angle * T * dt / (CHAFE_LIFE * chafe_mul). A line resting on the rail wears slowly and a line sawing across it on a run wears fast.

LANDING:
- Boatside means energy < 0.15 and line_out <= 7 m, after the boat-shy lunge has been survived for fish over 100 kg.
- landing.gd (wire, harpoon, haul) is UNCHANGED in the core. The lunge-timed harpoon window is a follow-up.

SKILL AGAINST LUCK:
- The only randomness is the fish: the seeded queue, the jittered triggers, the run-or-sound comeback, the lunge direction, durations, thrust noise and slap timing.
- There are no dice in tension or hook hold, so the same seed with the same play gives the same result.
- The guaranteed beats always happen, but you can't predict their exact moment or form.

BOT TARGETS (fight_test.gd rewritten; bots read cues() only):

| Bot | Target |
|---|---|
| PUMPER + MATE (continuous drag) | Lands a 300 kg giant in 200-360 s on at least 85% of seeds, and a schoolie in 45-120 s on at least 90% |
| PUMPER SOLO (scroll detents) | Lands at least 65% of giants, at most 35% slower than with a mate |
| PUMPER + SIDE PRESSURE | At least 15% faster than a plain pumper on giants; mean circle length at least 40% shorter |
| STATUE | Never takes energy below 0.35 |
| CONSTANT CRANKER | Breaks at least 70% of giants |
| HIGH-TIP-ON-JUMP | Loses at least 40% of schoolies |
| HALF-BOW | Loses about 20% of schoolies |
| POINTED-ROD-ON-WALLOW | Loses at least 35% of giants at the wallow |
| FULL-DRAG-ON-LUNGE | Breaks at least 50% of giants |
| Every fish over 100 kg | Exactly one comeback and one lunge |
| Director | Over 500 seeds: peak spacing respected, and comeback trigger spread across 32-48 m |

## Crew Roles

Everyone works the same spring, and nobody spectates.

ANGLER:
- Pumps and winds, steers the head with side pressure, sets tip height on jumps and wallows, and drops the tip and stops cranking on the lunge.
- Can nudge the drag solo with the scroll wheel (detents only).
- Walks round the cockpit and swings the tip outboard to lift a wrapped line off the rail. The wrap model uses the real tip position, so where you stand and how you hold the rod matters.

MATE (the second hand), on the DRAG LEVER, at the angler's shoulder and inside their view:
- Continuous control between detents, which is the mechanical edge over solo: the sweet spot in a dog is about 0.85, and only a hand on the lever gets there.
- Their job is anticipation, reading what the angler can't:
  - Spool and backing: "you're on the white".
  - The contact: "it's on the rail, walk aft".
  - The scream pitch: LIGHT for the opening run, up toward FULL in the dogs, down for the comeback, and DUMP the instant the lunge kicks.
- Done well it is worth 25-35% off a giant's time and most of the lunge survivals. Done badly it breaks fish.
- After the fight they wire, throw the harpoon and haul (landing.gd as now).

CAPTAIN:
- Keeps the fish astern for a straight line.
- On the authored bow-circle wrap, swings the stern so the line comes off the rail.
- Backs down on runs. That cuts fish_v_away and T, so the angler must wind or the slack wears the hook: "backing!", "winding!".
- Chases a spooling fish.
- Keeps the props clear when the comeback is a sound or the lunge goes under the hull.
- Out of gear on the spiral.

TWO PLAYERS:
- The angler can drop the rod in its holder to drive or gaff, at a real cost: breath regain and no gain.
- Otherwise the second player is captain AND mate, shuttling between the wheel and the lever. That shuttle is the two-player tension, and the director's spacing (at least 12 s between peaks) is what makes it possible.

RIVALS 1v1: each fights solo on their own boat with the scroll drag. The decisions are the holder (drive or fight) and how hard to work side pressure. Bend, splashes, leaps, wallows and lunges sync, so you watch the rival's rod load across the water. Rival spooking is a follow-up.

## Pacing

THE ARC OF A GIANT (about 5 min), with every trigger jittered:

1. STRIKE (0-3 s): the rod slams down, the weight lands in your hand, the camera tips to the line's entry point. The mate grabs the lever and sets LIGHT.
2. OPENING RUN (8-20 s, seeded direction): the scream. Cranking grinds and creaks. The captain backs down while the angler winds the slack.
3. FIRST GRIND (about 90 s):
   - Pump cycles in dogs and circles. Side pressure turns its head and cuts circles short: the line swings back across the stern.
   - Peaks every 12-40 s.
   - The mate rides the drag up in the valleys and down for the peaks.
   - On crewed boats, the BOW-CIRCLE WRAP: the line goes over the rail with a real bend and squeal, the angler walks aft with the tip outboard, and the captain swings the stern.
4. SECOND WIND (energy 0.55 ± 0.08): a run, or a deep sound. Proof it isn't over.
5. SECOND GRIND (60-90 s): shorter, weaker peaks.
6. COMEBACK (32-48 m): a run that takes 30-60 m back, or a sound straight down under the transom. You know it's coming, not what.
7. COLOUR and the WALLOW (25-35 m): the pale shape rises and the giant rolls out on the surface. Back and tail show, with 2-3 tail-slap fountains. Keep the rod bent and to the side, and don't point it. Then the spiral: crank as it flashes up, ease as it goes dark under.
8. BOAT-SHY LUNGE (11-19 m, seeded direction): the stiffest line of the fight. Drop the tip, dump the drag, nobody cranks, and the captain watches the props.
9. BOATSIDE: wire, harpoon, haul, as now.

QUIET MOMENTS are 6-20 s valleys (a shake is forced into anything longer), where rhythm, side pressure and drag set the speed and the crew talks. PEAKS never stack.

LENGTHS played well:

| Fish | Length | Beats |
|---|---|---|
| Schoolie | 1-1.5 min | Opening run, 2-4 jumps, head-steering circles |
| 100-150 kg | 2-3 min | Comeback, 50% a wallow, lunge |
| Giant | 4-6 min | All of it |

Sloppy play runs longer, because slack lets it breathe. The fights aren't shorter, they are shaped.

## Build Plan

A REAL 2-DAY CORE (must-fix 2). Each half-day leaves the game playable.

DAY 1, MORNING: tuna/fight.gd core (about 220 of 467 lines change).
- New signature: step(dt, crank: float, rod_pitch: float, side: float, drag: float, contact: Dictionary).
- New vars: stretch, shock, slipping, hold, _thrust, _breath_t, _air_t, drag, _side_t, _beats (the queue), _trig (the jittered triggers: second_wind_e, comeback_m, comeback_kind, wallow_m, lunge_m, lunge_dir).
- Keep the `strain` name for T, so rods.gd and its rpcs keep working.
- Consts: SPRING_BASE 0.8, SPRING_PER_M 0.012, PULL_IN 3.0, REGAIN 0.012, BREAK_T 0.3, CAPSTAN_MU 0.25, DETENTS [0, 0.45, 0.72, 0.95], SIDE_TURN 0.7, SIDE_TIRE 0.5, HEAD_TURN_T 2.0.
- DELETE: answer(), tell(), TELLS, _pump/_lift_low, the per-answer strain targets, arms/ARMS_*, STRAIN_GRACE, SLACK_GRACE/_slack_t, Fight.rub(), RUB_ALL, HULL_MARGIN. Also player.gd's `arms` and its REST regen (lines 46-47 and 544).
- MOVES gain thrust/jitter/tag. Add surge, jump, dog and wallow; "rest" stays as an alias for dog.
- The director: _build_queue(kg, crew_n) in _init(), plus _next_move() consuming it with the spacing rules, falling back to _pick(). Beat triggers are checked in step().
- Side-pressure maths in the existing bearing/turn code.
- cues() -> Dictionary.
- KEPT: boat backing and chasing math (it feeds boat_closing), props/cut, tangle, spool, spiral geometry, the boatside signal.

DAY 1, AFTERNOON: the user's line-contact fix, as a new tuna/hull_wrap.gd (static, about 100 lines, no physics in gameplay).
- WHY TODAY'S TUG IS WRONG: rods.gd rub_on_hull() casts the straight tip-to-fish segment against the hull. It casts 3 more copies offset by HULL_MARGIN 0.5 m sideways and down, and adds +0.25 for any hit. So a line passing NEAR the bow rubs, and a straight segment to a deep fish that cuts through the hull's underwater volume (where a real line would hang clear or bend at the chine) rubs at full. It is a proximity test, not contact.
- NEW MODEL:
  - Each kind in boat/kinds.gd gets `wrap_hull`:
    - a convex deck outline (6-8 boat-local x/z points, from the existing half-beam, house, bow and transom numbers),
    - gunwale_y,
    - a keel outline (the deck outline inset 0.6 m) at keel_y,
    - the house's top-edge rectangle.
  - HullWrap.wrap(tip, fish, hull) -> {touching, via, angle}:
    - If the tip-to-fish segment doesn't pass through the prism (its vertical extent is gunwale_y to keel_y), the result is no contact. There are no margins.
    - If it does, find the point P that minimises |tip-P| + |P-fish| over three candidate edge loops: the gunwale (the line over the rail), the keel (the line under the bottom) and the house top. Sample 32 points per loop, then golden-section refine on the best edge, about 40 evaluations.
    - via = P, and angle = the angle between (P - tip) and (fish - P).
    - Hysteresis: contact releases only when the segment clears by 0.05 m, so the bend doesn't flicker in the swell.
  - Everything is computed in the boat frame, so hull roll is ignored.
  - One via point. A double wrap takes the larger-angle edge, which is acceptable at this scale.
- fight.gd receives contact = {angle, slide}, where slide = |d line_out/dt| + |d via/dt| in the boat frame. That gives T_fish = T*exp(0.25*angle) and the wear formula.
- rod.gd _draw_line takes the optional via and draws two segments; the bend aims at via.
- The squeal and spray are placed at via.
- On the user's raycasting idea: rays stay ONLY in a RUB_DEBUG overlay, drawing the prism and the old ray result side by side, to tune the outline against the art. That replaces the fragile .glb mesh-vertex test.
- No line physics needed: a taut line wrapping a convex hull is the shortest path, which this computes exactly.

DAY 2, MORNING: rods.gd (about 130 lines) and crew/player.gd (about 50 lines).
- player.gd:
  - rod_aim_pitch and rod_aim_side, which take mouse input while the rod_load lease is fresh.
  - The camera-follow rule (entry_pitch from a rods.gd-provided entry point, 0.35x/0.4x follow, caps, 6 rad/s ease).
  - Optional Alt glance with the 0.25 s ease-back.
  - The lease (neutral unless stamped this frame).
  - The Rod weight setting.
- rods.gd _in_hands(p, lift): reads p.rod_aim_pitch and rod_aim_side while fighting, else _pitch as now.
- rods.gd _fight_mine:
  - Calls step(dt, crank, rod_aim_pitch, rod_aim_side, r.drag, contact), with contact from HullWrap.wrap(r.tip_position(), fish_point(r, boat), spec.wrap_hull).
  - Writes the lease every frame.
  - Scroll notches change r.drag when nobody holds the lever, rate-limited to 0.2 s.
  - Deletes me.arms plumbing and fight.answer().
- rods.gd _fight_holder: step(dt, 0, 0.6, 0, r.drag, contact).
- THE DRAG LEVER: r.drag is a synced float on Rod, and lever_holder is host-arbitrated with the same ask/grant rpc pattern as _ask_grab/_host_set (or helm.gd). The holder sends mouse-Y values at 10 Hz to the rod holder's peer, where the fight runs.
- _fight_state/_holder_state gain stretch, hold, drag and via, and carry_on gets stretch and hold.
- A 0.5 s handover grace (shock ignored, hold frozen).
- HUD: the tell is cleared, the hud "plot" call is deleted, and _end_mine sends the reason to a 3 s caption.

DAY 2, AFTERNOON: the rod/rod.gd feel pass (about 90 lines) and tests.
- Bend, quiver and sag from T; thrum jitter.
- Creak, grind and detent-click AudioStreamPlayer3Ds, made like _scream.
- The ping-and-coil against the spring-straight.
- The spool cylinder with white backing.
- The wallow in tuna.gd/_show_fish (rise to 0.3 m, roll, 2-3 Splash.gd slaps on the seeded times) and the silhouette at line_out < 30.
- tests/fight_test.gd rewritten with the cues()-only bots and the director property test.
- tests/hull_wrap_test.gd:
  - no contact for a fish dead astern,
  - contact with angle > 0.3 for a fish ahead of the beam,
  - NO contact for a line 0.4 m clear of the rail (today's false positive),
  - keel contact for a fish under the hull,
  - the tip swung outboard aft clears a shallow wrap.
- ui/manual.gd and ui/tips.gd: one line per role.

FOLLOW-UP (stated, not in the 2 days):
- the mate fending the line by hand and the burnt hand,
- the sportfisher's physical SubViewport plotter,
- the lunge-timed harpoon flash window (with its 18 m resume),
- double headers on 3+ crew with inside/outside deadlines on the crossing check,
- rival engine spooking,
- a lever animation polish pass.

## Risks

- CAMERA FOLLOW FEELS FLOATY OR SICKENING. The rod moves at 1:1 while the camera moves at 0.35x, which could read as lag. Mitigations: the camera is anchored to the line's entry point (a stable world target, not the mouse), its range is capped at -0.12/+0.28 rad, and a 6 rad/s ease with no overshoot. Tune it with the swell's camera bob. Fallback: drop the follow to 0.2x.
- THE ROD TIP LEAVES THE TOP OF FRAME on a full heave. That is intended (the bend and the line read the load), but test whether players heave less because they lose the tip. If so, widen the FOV 4 degrees with T, or raise the pitch cap to +0.32.
- MOUSE WEIGHT AS LAG. It applies only upward, capped drift, with a slider down to 0, and the lease makes a stuck-heavy mouse impossible. Add a test that drops the rod and asserts neutral scale on the next process frame.
- SIDE PRESSURE TOO STRONG OR TOO WEAK. The bot band (at least 15% faster, circles at least 40% shorter) is the harness. Watch that the 2 s head-turn hold isn't a spam trick: it requires T above 0.3 through the cushion term.
- SCROLL DRAG MAKES THE MATE REDUNDANT. The mate's edges are continuous values between detents and no rate limit, plus their attention. The target is solo at least 65% and at most 35% slower. Tune with the solo bot first, since rivals is solo.
- DIRECTOR READS AS A SCRIPT. The triggers are jittered from day one, the comeback is a run or a sound, the lunge direction is seeded, and the wallow's slap timing is seeded. Watch playtests past fish 5.
- HULL OUTLINE DRIFT. The analytic prism can disagree with the art. The RUB_DEBUG overlay shows prism against rays, and the outlines are about 8 numbers per boat in kinds.gd. Hull roll is ignored.
- TUNING INTERACTIONS between the spring, capstan, hold and side pressure. Iterate headless with the bots before hand-tuning.
- NETWORK. The lever arrives at 10 Hz (about 100 ms). The detent margins absorb it, the wrap is computed on the rod holder's machine, via syncs at 10 Hz for visuals only, and the handover grace prevents unfair breaks.
- SCOPE. If day 2 runs over, cut the wallow's roll animation to splashes only and the spool backing material swap. Never cut the camera rule or the hull wrap.
