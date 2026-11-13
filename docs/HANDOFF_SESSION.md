# Handoff: where Bluefin stands (2026-11-13)

For a Claude picking this up with the repo but none of the conversation. Read this first. Then, as the work needs
them: `docs/FIGHT_ARCADE.md` (the minigame fight), `docs/UI_MENUS_BRIEF.md` (the UI rules), `docs/VISION.md`,
`docs/FEATURES.md`, `docs/gaps_audit.md`, `docs/MUSIC_SYSTEM.md`.

**What the owner wants next: bigger-picture work.** Their words on 2026-11-13: "I want to take a bigger picture
stuff. I don't really care if there's a few like small stuff." Don't open with the small-fix list at the bottom of
this page. Ask what the bigger piece is, or propose from "Bigger pieces" below.

## The project

Bluefin is a first-person bluefin tuna fishing game in Godot 4.7.2, in this repo (Gull-Harbor). Three modes: Solo;
Co-op (up to 4 crew, a career with a boat payment every 3 trips); Rivals (two boats against each other, even teams,
best of 3 days). The owner is Kortev (the git name). Nobody else works on it. It is being readied for playtests
with friends.

- **Branch:** `claude/boats-n`, pushed to origin. All work lands here. `main` is old. Last commit: `40af1a5`.
- **Godot:** `G="C:/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"`.
- **A test, headless:** `"$G" --headless --fixed-fps 30 --path . tests/X.tscn`. Net tests run as two processes
  (`-- --role=host` in the background, wait 3 s, then `-- --role=join`); each has a fixed port, so never two net
  tests at once.
- **UI pictures (needs a window):**
  `"$G" --path . --resolution 1600x900 res://tests/ui_shot.tscn -- --part=menus|sea|rivals --out=DIR/ [--port=N]`
  (add `--fight=classic` for the classic fight's HUD).
- **Minigame pictures:** `tests/fight_arcade_shot.tscn -- --only=<ids> --prefix=<name> --weather=sunny`, saved as
  `docs/shots/<prefix>_<id>.png`. Look at the pictures; a passing test doesn't mean the screen is right.
- **A build:** `"$G" --headless --path . --export-release "Windows" export/Bluefin.exe`, then zip `Bluefin.exe`,
  `steam_appid.txt`, `libgodotsteam.windows.template_release.x86_64.dll` and `steam_api64.dll` into
  `export/Bluefin_buildN.zip` (PowerShell `Compress-Archive`), then start it once with `./Bluefin.exe --headless`
  and count script errors. **Only build when asked or when the owner is about to play.** The latest is build 25.
- **Commits** end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. Commit messages are written as
  plain sentences about what changed in the game (see `git log`). Commit and push when asked.

### Local quirks: get these wrong and you break the owner's checkout

- **`project.godot`** has an uncommitted change of the owner's. Never commit it, never revert it.
- **`.import` files:** many show as modified; only line endings differ. Leave them. Never a broad
  `git checkout -- .`.
- **Never pop a bare stash:** the stash stack is shared with GitHub Desktop. Stash by tag, apply by sha.
- The many untracked `*.gd.uid` files and `docs/shots/play/` are not mine to add; leave them.
- Old worktree agents (`worktree-agent-*` branches) are stopped. Don't resume them or merge their branches without
  asking.
- Ask before downloading anything (filename, source, size). Publish nothing outside without asking. The owner's
  email and personal details never go to an outside service.

## How the owner wants things done (standing rules)

- **Quality:** release quality though it won't go on Steam (no $100 fee; app id 480 stays; achievements work
  in-game). "It's just for my buddy" is never a lower bar. The goal: small, but feels huge and full.
- **Hands-on:** the player does the work by hand and every action is animated. Never one press that does it all.
- **No snapping:** nothing teleports. Everything moves continuously (the fish is reeled the whole way in).
- **Physics, not modes** (Sea of Thieves): you run and jump off the boat and physics takes over.
- **The game explains itself:** the menu and the first minutes must be understood without anybody telling you.
- **Fair Rivals:** the two boats never share one school.
- **Realism in the world, the boat and the crew; the hands are gamified.**
- **The fight must be stressful,** even in calm weather.
- **No demo videos.** The owner plays and reports back; their playtest is the truth, simulations are not.
- **The UI look was reversed on 2026-11-12:** HUD and menus are clean, not pixel. See the next section. Screens
  that are objects in the world (plotter, sounder, radar, town signs, the fuel label) stay pixel.

## Decisions that still shape everything

- **Crew-size rule (hard):** the world's rules never depend on crew size. Bigger crews are kept busy by the boat
  they pick (more rods, the tower, a longer deck, a bigger bilge), never by a mechanic that switches on.
- **Difficulty:** solo barely doable; two on the skiff both busy the whole time; the sportfisher wants 3 or 4.
- **Crew caps:** skiff 2, sportfisher 4.
- **Money:** one shared crew wallet. A flat boat payment every 3 trips; it rises only if you choose a bigger boat.
  Losing it is meant to become a funny playable grocery-store shift, then a partial restart (not built).
- **Rivals:** playable 1v1 first; even teams up to 4v4 on bigger boats, a spectator/ref for odd numbers, per-mode
  prep settings (planned, not built). Voice: proximity plus radio.

## What this last session built (2026-11-12 and 13)

### The arcade fight: a game inside the game

`tuna/fight_arcade.gd` runs a sequence of small button games (`tuna/minigames/*.gd`, 15 of them plus the BIG PULL
and the save game). Two buttons only: A = left click / RT (`use_primary`), B = right click / LT (`use_secondary`).
Combos build to a BIG PULL. `Fight.arcade` switches it on; the classic fight (`tuna/fight.gd`, HUD
`ui/fight_hud.gd`) is still there. The arcade HUD is `ui/fight_arcade_hud.gd`. The test bot that plays it is
`tests/fight_arcade_bot.gd`.

Added after the owner's and a friend's playtests:

- **A friend lost 4 fish close to the boat with no warning.** Now nothing is lost silently there: the HUD says
  what's coming (line under her, line on the hull with a gauge, his last run, still fresh, off the stern), and a
  line worn through or in the props starts a save game, WORK IT CLEAR (`tuna/minigames/clear.gd`, alternate A and
  B, 8 taps in 4.2 s). Win it and the fight goes on.
- **Hull rub is physical.** `rods/rods.gd line_on_hull()` ray-casts the real line against the real hull, finds
  where it bends over her edge, and the line is drawn bent there (`rods/rod.gd line_via`). Rub counts only where
  the line truly lies on her. The old direction-only guess (`side_rub()`) is used only in headless sims.
- **The owner played 10 minutes and gained no line, not knowing the games.** Now: each game shows one line of
  instruction under its frame naming the real buttons (`Minigame.HOW` in `tuna/minigames/minigame.gd`); the first
  go at each game is practice with the fight held 3.2 s and nothing to lose; misses raise an `assist` that makes
  the next games easier and cuts line lost and hook damage by up to 60%; any button use tires the fish at a floor
  rate; doing nothing outside his runs no longer loses line.

### The UI: "INSTRUMENTS AND STAMPS"

The owner rejected the pixel text ("shitty pixel text") and a glass/rounded try ("looks AI generated... curved
stuff and UI boxes are very big indicators of AI"). Approved: type and linework drawn straight over the world, no
panels, no boxes, no rounded corners; three inks (paper, yellow, orange); rulers, ticks, corner marks, one loud
stamp a page. The kit is `ui/kit.gd`; the rules are in its header and in `docs/UI_MENUS_BRIEF.md`. Done in this
look: every minigame, the play HUD, title, lobby, settings, achievements, pause, the dock board, the results
card, the Rivals tally, the classic fight's HUD, the manual, the dev panel.

## What is and isn't verified

- **Passing on the last commit:** fight_arcade, rods, strike, coop, vs, tutor, fight (and, one commit earlier,
  title, settings, achievements, dev_panel, card_n, boats_n, hands, radio, pad, bait).
- **Not run on builds 23 to 25:** the full suite, and the three-player network test. Steam with three is untested.
- **Build 25 has not been played by anyone.** Its balance is from the bot: a player who knows half the games
  lands a 60 kg fish in about 6 min; a good player lands 150 kg in under 5 min; hands off still loses. Whether a
  person can follow the instruction lines is a guess. The first-time practice pause has not been looked at on
  screen.
- Known flaky under load (pass alone): leap_moving, doubles, voice (friend side), tower, harbour_walk, vs_net
  "lines still out".
- The state of the separate music session's work (`audio/music*.gd`, `docs/MUSIC_SYSTEM.md`) was not looked at in
  this session.

## Bigger pieces (where to go next)

Waiting on the owner's word (they set these aside; don't start without it):

- Crew roles and the bailing plan (`docs/CREW_FIGHT_PLAN.md`).
- The finish at the boat as a minigame (it is still the old harpoon throw).
- The spotter/radar patch.
- Mackerel (bait) feedback.

Planned, never built:

- Rivals 3v3/4v4 on a bigger boat, the spectator/ref, per-mode match settings.
- The grocery-store shift for a lost boat payment.
- Proximity and radio voice, the playful Rivals tricks.
- The rest of `docs/gaps_audit.md`: helm levers, NPC life, other boats, progression, footsteps, real SFX,
  accessibility, graphics presets.
- Onboarding as a whole: the menu and the first trip explaining themselves, beyond the fight.

## Small things left (the owner said these can wait)

- What you've practised isn't saved: every launch re-teaches each game (`known` is a static in
  `tuna/fight_arcade.gd`).
- The plotter's red rub arc still shows the old direction-based zone.
- The classic fight has the physical rub but no save game or new warnings.
- The pause menu shows the fight HUD through it; the voice marker overlaps the Rivals tally.
- The dock board is the weakest restyled page; achievement medals are still pixel icons.
- The line passes through the hull below the waterline when the fish is under her.
