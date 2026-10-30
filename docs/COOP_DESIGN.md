# Two aboard: making co-op beat solo (2026-10-30)

The ask: a two-player trip in the skiff should be clearly more fun than solo, and neither of you should be stuck
with nothing to do. Your rules still hold: no tiredness, no binoculars or calling flocks out in game, show don't tell,
nothing snaps, not too gamey, no radar or sonar on the skiff, and solo must still work.

## How the good co-op games do it

- **Sea of Thieves:** the ship needs more stations than one person has hands, at the same moment (helm, sails,
  bailing, cannons), and the crow's nest sees what the helmsman can't. You talk because you have to.
- **Overcooked:** one job blocks another unless someone else is doing it; the fun is the hand-off.
- **A real sportfishing crew:** the angler fights the fish while the captain backs down on it; at the boat, the
  angler keeps the fish's head up while the mate wires and gaffs it. Neither can do the other's job at the same time.

The pattern: **two pairs of hands needed at once**, **one player knows what the other needs**, and **something goes
wrong unless someone's watching it**.

## Where the two of you were before

Phase by phase on a skiff trip, with A at the wheel and B on deck:

| Phase | A (wheel) | B (deck) | Solo just as good? |
|---|---|---|---|
| Leaving the harbour (2 km) | drives | **nothing** | yes |
| Searching for birds | drives, reads the birds himself | **looks at the same birds A can already read** | yes |
| Trolling | steers through the school | casts, chums, rebaits | nearly (cast both, then drive) |
| The bite | can't grab a rod from the wheel | grabs it | no: two is quicker |
| The fight | plotter, swing the stern, back down, out of gear when it's under her | fights it | no: about 4 min against 6 for a giant |
| Boatside | harpoons it | **holds a rod that does nothing; told to put it back** | yes, just a slower haul |
| On deck | bleeds and ices | rebaits and casts | nearly (one after the other) |
| Heading in | drives | **nothing once it's iced** | yes |

Dead spots: B on the way out and on the search; B at the boat (the rod in his hands meant nothing); B on the way in.
The fight is already the best two-player moment.

## The fixes, best for the effort

1. **Hold it alongside (built).** A fish up alongside has to be held there: someone on its rod (or, on the
   sportfisher, on the leader). Left on a rod in its holder it isn't: every 9 s it kicks, sheers off from her and goes
   down out of the harpoon's reach for about 4 s, the rod in the holder bending over, then wallows back up. So the
   angler keeps the rod ("Hold it there") while the other sticks it: two pairs of hands at once, the real boatside.
   Alone you put the rod back and time your throw between kicks: slower, never blocked. (`tuna/landing.gd`.)
2. **The mate's eyes (built).** At the wheel with her running faster than trolling (about 12 knots), the captain
   can't pick birds out: his eyes are on the water ahead. The one on deck reads them ("BLUEFIN!", "Just gulls",
   "1.4 km off the port bow") and tells him by voice. Ease her down and the captain can look for himself, so solo
   works, just slower. Nothing new on screen: the existing read is just not the captain's while he's running.
   (`crew/spotter.gd`.) This is talking, not an in-game call-out; easy to take out if it isn't your taste.
3. **Next (not built): doubles.** A feeding school on the spread should often take both baits within a few seconds
   (real bluefin do). Two aboard: both fighting, nobody at the wheel, and you have to decide who lets go of his rod
   to back her down. Solo: one fish on its drag in the holder while you fight the other. A small change to the strike
   odds in `tuna/schools.gd`; it wants playing first to tune.

Heading in stays a short quiet stretch on purpose (ice the fish, rebait, talk); it's under two minutes.

## Now

| Phase | A (wheel) | B (deck) |
|---|---|---|
| Leaving the harbour | drives | **picks out birds as they show up** |
| Searching | drives where B says | **reads the birds: which way, how far, tuna or gulls** |
| Trolling | steers through the school | casts, chums, rebaits |
| The bite | stays on the wheel | grabs the rod |
| The fight | plotter, stern, backing down | fights it |
| Boatside | **leaves the wheel and harpoons it** | **holds it up alongside on the rod** |
| On deck | bleeds and ices | rebaits and casts |
| Heading in | drives | ices, rebaits |

Tests: `tests/coop_test.tscn` (headless) and `tests/coop_net_test.tscn` (two processes, host then join).
