# The arcade fight

A game in a game. The world stays real (the fish, the line, the boat, the sea); your hands play a run of little
**minigames** on two buttons, **A** (left mouse / RT) and **B** (right mouse / LT), never the same one twice
running. It replaces the simulation-leaning fight (docs/FIGHT_DESIGN.md) for whoever holds the rod, and is
switchable: `Fight.arcade` (on by default; the host's F1 dev panel row "FIGHT: ARCADE / CLASSIC" flips it for
everyone; `-- --fight=classic` starts with it off).

## How to add a minigame

1. Copy a small one: `tuna/minigames/spool.gd` (single timed presses), `ride.gd` (a held one) or `mimic.gd`
   (rounds). Rules and drawing live in the one file; it extends `tuna/minigames/minigame.gd`, whose header says
   what every field means.
2. In `_init()` say what it is: `id`, `title` (two or three words), `moves` (which of the fish's moves it suits:
   run, surge, sound, dog, shake, circle, spiral; `[]` for any), `from` (how far through the fight, 0..1, before it
   may come up), `length` (3 to 7 s), and if it wants them `can_boss`, `boss`, `only`, `hitstop = false`.
3. `_begin()`: set up a round from `tier` (0 easy .. 1 hard) and `rng` (nothing else random: the same seed must
   play the same game). Honour the variant flags you can: `mirror`, `fast`, `twist`, `big` (a boss: longer).
4. `_step(dt, a, b, a_hit, b_hit)`: the rules. Every frame set what it's doing to the fish, all normalised:
   `gain` (-1 he takes line .. 1 you win it), `tire` (0..1), `tension` (0..1, the rod's bend; over 0.9 reads as
   danger), `pose` (0..1, rod low .. high), and when it's hurting, `hook` and `fray` (0..1). Call `_hit(2)` (perfect),
   `_hit(1)` (good), `_miss()` for single moments; keep `_pts` / `_max` (the score is their ratio); set `done`.
5. `cue()`: what each button's asked to do now, `[A, B]` of `Kit.NONE / HOLD / TAP / MASH / RELEASE / OFF`: the
   HUD's button glyphs act it out, so nobody reads a rule. `hint()`: what a perfect player holds right now (tests).
6. `draw(ci, rect, kit, time)`: draw it in `rect` with `ui/kit.gd`, as a ship's instrument: the rules are the
   DRAWING A GAME section at the top of that file (no panels; three inks, `Kit.PAPER`, `Kit.YELLOW` reward,
   `Kit.ORANGE` danger and the fish; `kit.scale`, `kit.span` + `kit.hatch`, `kit.tri` / `square` / `diamond`).
   Copy `ride.gd`, `beats.gd`, `spool.gd` or `lanes.gd`.
7. Add its line to `tuna/minigames/all.gd`. That's all: the fight deals it out, and
   `tests/fight_arcade_test.tscn` plays it (by its hint with a high score, hands off with a low one, the same again
   from the same seed, drawn at three tiers). Look at it: `tests/fight_arcade_shot.tscn -- --only=<id>` saves
   `docs/shots/minigame_<id>.png`; in the game `-- --piece=<id>` plays nothing else.

## The games

| Game | He's... | You |
|---|---|---|
| `ride` Ride the run | running | hold B to lift the needle, let go to drop it: keep it in his moving green band |
| `spool` Thumb the spool | running, sounding | tap A to stop the spinning mark on the gold tooth |
| `tug` Tug of war | running, circling | A, B, A, B, hand over hand, to haul the knot over your line |
| `pump` Pump and wind | sounding | hold B to lift into the gold, then hold A to wind down |
| `dog` He's dogging | dogging | the pump, but let go of B when he kicks (the meter flares) |
| `heave` Heave | sounding, dogging | hold B as the power winds up, let go in the gold |
| `steady` Steady the tip | sounding, circling | tap A to knock the tip left, B right: keep it in the green |
| `beats` Head shakes | shaking his head | tap B as each shake crosses the ring |
| `lanes` On the beat | shaking, circling | two lanes in time with the music: A's notes on the left, B's on the right |
| `duel` Wait for it | holding, sulking | wait... tap A the instant he turns (NOW) |
| `mimic` Follow his lead | any | watch his darts left and right, then repeat them: A left, B right |
| `laps` Wind him round | circling, spiralling | hold A on the green of the ring, B on the red |
| `jump` He's jumping | jumping (only then) | hands off while he's in the air, tap A as he lands |
| `charge` He's coming | charging (only then) | hammer A to keep the line tight |
| `twohands` Both hands | (boss) | two at once: tap A on his shakes while B holds the needle in the band |

## How a fight goes

- **Sets.** The fish does one thing at a time (the world shows it), and each thing is a set of 2 to 4 games
  with a breath (0.4 s) between. They come out of a shuffled bag: never the same twice running, none again till
  the bag has gone round, ones that suit his move first. A game past 9 s is swapped out, scored on what was done.
  The second time a game's seen it may be mirrored, 20% faster, or with its twist.
- **Grades.** Each game ends PERFECT (score 0.88+), GREAT (0.62+), OK (0.34+) or MISS.
- **The combo.** Great and perfect each add one; a miss halves it. Each step is 4% more tiring for him and 2% more
  line for you, up to x20 (so x1.8 and x1.4).
- **The BIG PULL.** At every fifth step of the combo (x5, x10, x15...): one press of either button, impossible to
  fail (left alone it goes off by itself after 1.6 s). 14 m of line for the first, 4 m more each time up to 30 m,
  hauled in at 18 m/s (fast, never a jump), and 4 s of tiring. He takes nothing while it's on.
- **Stages and bosses.** His energy is cut into stages (2 for a schoolie, 7 for a giant). Near the end of each
  comes a boss: `twohands`, or a longer, harder one of the others. Won (GREAT or better), it takes a third of a
  stage out of him. A stage cleared gives a little of the hook back and 4 m of line.
- **Mistakes cost, they don't end it.** They cost line (he takes it), the hook's hold, or the line's wear. Only
  running out of one of those loses him: spooled, shaken / pulled / thrown, or parted.
- **Length.** About 2.5 minutes for 60 kg and 9 for 300 kg played well; a sloppy angler takes about twice that.
  The host's fight length (`Fight.pace`) scales it.

## The rest of the boat

The skipper still matters exactly as before: off the stern everything the angler does counts for less, backing
down wins line, the hull rubs the line and the props cut it. A rod left in its holder plays him on its drag (no
games: he takes line, the hook isn't worked), so alone you can go to the wheel. A rod handed over carries the
combo and where the fight was.

## Where it lives

- `tuna/minigames/minigame.gd` the base class, `all.gd` the registry, one file a game, `pull.gd` the BIG PULL.
- `tuna/fight_arcade.gd` the sequencer (extends `tuna/fight.gd`: same fields, signals and `cues()`, so the rod, the
  fish, the sounds, the music and the network sync are untouched).
- `ui/kit.gd` the drawing kit ("instruments and stamps": inks, keylined lines, scales, hatching, markers, the
  stamps, the button glyphs, easing),
  `ui/fight_arcade_hud.gd` the fight's HUD on it, `ui/juice.gd` the sounds, hit-stop, rod kick and rumble.
- `tests/fight_arcade_test.tscn` (the test), `tests/fight_arcade_sim.tscn` (a table of how fights go),
  `tests/fight_arcade_shot.tscn` (screenshots), `tests/fight_arcade_bot.gd` (the test angler).
