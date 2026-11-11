# Any number of boats (2026-11-11): the contract every piece builds to

Kortev's ask: uneven crews; Rivals with several boats, including 1 v 1 v 1; co-op with several boats. Wanted playable
tonight. Branch `claude/boats-n`; the last known-good build is `export/Bluefin_build15.zip` on
`claude/zealous-mendel-h2udij`.

## What it is

Rivals (`vs/vs.gd`) stops being "A against B" and becomes "N boats on one sea", N = 2, 3 or 4 (there are at most 4
players: `Net.MAX_CREW`). Each boat has whoever is aboard her, any number from 1 up, crews need not be even. The host
picks, in the lobby: how many boats, and whether they fish **against** each other (most pounds wins the day, first to
`MATCH` days wins the match) or **together** (one fleet: the boats' pounds add up, nobody wins or loses, the card
shows the fleet's day). Everything else about a boat (her rods, landing, hold, chum, jig, horn) is already per
`vs/side.gd` and stays so.

## The contract (names other pieces rely on; do not rename)

`vs/vs.gd`:
- `const MAX_BOATS := 4`; `var boats := 2` (how many sides are built); `var together := false`.
- `sides: Array` has `boats` entries while `on`; side `i` is named "A".."D"; `teams: {peer id -> side index}`;
  `my_team`. Every per-boat array (`wins`, `result`, `catches`, `shown`, `home`, `_last`, `_away`, `_late`,
  `_alongside_for`, `_match`) is `boats` long. No `1 - my_team` anywhere: "the others" is every side but yours.
- `host_set_boats(n: int)` and `host_set_together(yes: bool)`: host, at the dock, everyone docked; rebuilds the sides
  and tells every peer (they go in `_switch`'s arguments so a joiner gets them too). Changing the count re-shares the
  crew over the boats (round robin by slot) and moors every boat at her berth.
- `ask_team(t)` accepts any `0 <= t < boats`. `seat_new(id)` puts someone new on the boat with fewest aboard.
- `team_problem(who := 0) -> String`: "" when it can start. It can't when: fewer than 2 people aboard in all, or any
  boat has nobody aboard (say which, and that the host can take a boat away or someone can cross). Uneven is fine.
- `static func boat_name(i: int) -> String` ("A".."D") and `static func boat_colour(i: int) -> Color` (four distinct
  colours that read on the pixel HUD; A and B keep the colours they have now).
- Winner of a day: the boat with the most pounds (rounded); a tie for the most is no winner (-1). `together`: always -1,
  no wins counted, no `RIVALS_DAY`/`RIVALS_MATCH` achievements.
- `_berth(i)`: asks `harbour.call("berth_at", i, half_beam, length)` when the harbour has it (see below), else what
  it does today for 0 and 1.
- The sea parts round every other boat: `ocean.call("set_other_hulls", list)` when the ocean has it (see below), else
  `set_other_hull` for the first other.
- Host fishing for the boats that aren't the sea's own (`_others_fish`): every side but yours, each in turn.
- `spawn_anchor()`: each day the middle of the boats that are out first, then each boat in turn, the order rotated by
  the day so nobody always gets the early school; only round boats out on the grounds.

`vs/card.gd` (the results card) reads `data`: `"boats"` (an Array, one Dictionary a boat: fish, kg, big, money, late,
lb), `"wins"`, `"day_lb"`, `"crewed"` (Arrays, one entry a boat), `"winner"` (index, -1 none), `"decided"`, `"day"`,
and new `"together"` (bool) and `"names"` is not sent: use `Vs.boat_name(i)`. `card.states` is one entry a boat.
It must lay out 2, 3 or 4 boats, yours marked, and in `together` show the fleet's total and no winner.

`sea/harbour.gd`: `func berth_at(i: int, half_beam: float, length: float) -> Vector2` for i = 0..3: 0 and 1 exactly
where `berth()` and vs.gd's mirrored berth put A and B today; 2 and 3 further out along the fish pier's two sides
(or wherever there is room with floats to tie to), with floats, cleats and a way to walk ashore like A's and B's, and
`boat/lines.gd` able to make fast there. `sea/sea.gd` makes one `Tow` a boat (4, not 2).

`sea/ocean.gd` + `sea/ocean.gdshader`: `func set_other_hulls(hulls: Array) -> void`, each entry a Dictionary with what
`set_other_hull` takes today (`xf, length, beam, deck, speed, sheer`), up to 3 of them; `set_other_hull(...)` keeps
working (it is hulls[0]); with none, all off.

`vs/contact.gd`, `vs/horn.gd`: every pair of boats is solid to each other and rocks in each other's wake; a horn
startles every other boat's crew and rods, not "the other one".

`ui/title.gd`: the Rivals lobby gets BOATS (2, 3, 4: the host's), AGAINST / TOGETHER (the host's), and each person's
own CHANGE BOAT (steps to the next boat: `ask_team((my_team + 1) % boats)`), the crew list drawn as one column a
boat in `boat_colour`; START refuses with `team_problem`'s words. The title's wording says what it is now (not "two
boats").

## Rules for whoever builds a piece

- Touch only the files your brief gives you. Do not commit, stash, switch branch, or touch `project.godot` or any
  `.import` file (many show as modified: line endings only; leave them).
- Others are editing other files in this same folder at the same time. If a test fails on a file that is not yours,
  wait a minute and run it again before concluding anything.
- Godot: `G="/c/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"`. A test:
  `"$G" --headless --fixed-fps 30 --path . tests/X.tscn`. Two-player tests: the same with `-- --role=host` in the
  background, `sleep 3`, then `-- --role=join` (one net test at a time: they share a port). Run only the few tests
  that cover your piece; the whole suite is run once at the end by the lead.
- House rules: nothing snaps or teleports; pixel style (the pixel font `ui/pixfont.gd`, nearest filtering); the
  world's rules never depend on how many are aboard; show, don't tell. Comments in the code's own voice (read a few
  first), GDScript typed like the rest.
- Report back: what you changed (files, functions), what you ran and its result, and anything you could not finish
  or are unsure of. Say so plainly if something is not done.
