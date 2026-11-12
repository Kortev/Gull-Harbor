# The arcade fight

A game in a game. The world stays real (the fish, the line, the boat, the sea); the hands are gamified. It replaces
the simulation-leaning fight ("Bend, Head and Heat", docs/FIGHT_DESIGN.md) for whoever holds the rod, and is
switchable: `Fight.arcade` (on by default; the host's F1 dev panel row "FIGHT: ARCADE / CLASSIC" flips it for
everyone; `-- --fight=classic` starts with it off).

## The idea

Two buttons, nothing else: **A winds** (left mouse / RT) and **B leans back on him** (right mouse / LT). The fish
does one thing at a time, and each thing he does is its own little challenge with its own shape on screen. A fight is
a run of them, chained by what he does, and a long fight is a long run of varied ones, never a wait.

| He does | You see | You do |
|---|---|---|
| **Runs / surges** | a bar: his green band sliding about, your needle | hold B to lift the needle, let go to drop it: keep it in the green. Under it he pours line off; over it the line frays |
| **Shakes his head** | beats sliding down a lane to a gold box | tap B on each beat. A miss works the hook loose |
| **Jumps** | his arc over the water, red at first, a green ring where he lands | hands off both while it's red (bow to him), tap A as he lands |
| **Sounds** | a tall meter, gold at the top | hold B to lift into the gold, then hold A to wind down. Every stroke is line |
| **Dogs** | the same meter, flaring amber then red | the same pump, but let go of B while he kicks or he rips the rod down |
| **Charges the boat** | the line sagging between the boat and him | hammer A to keep it tight |
| **Circles / spirals** (the end game) | a ring: green toward you, red away | hold A through the green, hold B through the red. On to A right at the gold mark for more |

## What makes it a game

- **Grades and the streak.** Each piece ends with PERFECT, GOOD, OK or MISS. Perfect and good build a streak; each
  step of it is 10% more tiring for him and 5% more line for you (to x2 and x1.5). A miss breaks it.
- **Mistakes cost, they don't end it.** They cost line (he takes it), the hook's hold (five pips), or the line's wear
  (it frays). Only running out of one of those loses him: spooled, shaken / pulled / thrown, or parted.
- **Progress you can see.** His energy is a bar cut into stages (2 for a schoolie, 7 for a giant); each one cleared
  is a step up: a flash, a little of the hook back, some line. The line from the boat to him is drawn over the top.
- **Rising stakes.** Bigger fish and later stages make the band narrower and quicker, the beats syncopated, the laps
  faster, the kicks closer together. The leader coming up sets off his last run.
- **Length.** About 2 minutes for 60 kg, 9 for 300 kg played well; a first-timer takes a third longer. The
  host's fight length (`Fight.pace`) scales it.
- **Fair.** The pieces come out of a shuffled bag by how tired he is and how far off; nothing random decides a fight.

## The rest of the boat

The skipper still matters exactly as before: off the stern everything the angler does counts for less, backing down
wins line, the hull rubs the line and the props cut it. A rod left in its holder plays him on its drag: he takes line
but the hook isn't worked, so alone you can go to the wheel. A rod handed over carries the streak.

## Where it lives

`tuna/fight_arcade.gd` (extends `tuna/fight.gd`: same fields, signals and `cues()`, so the rod, the fish, the sounds,
the music and the network sync are untouched), `ui/fight_arcade_hud.gd`, hooks in `rods/rods.gd`,
`tests/fight_arcade_test.tscn` (and `tests/fight_arcade_sim.tscn` for a table of how fights go,
`tests/fight_arcade_shot.tscn` for screenshots; `-- --piece=shake` forces one set-piece).
