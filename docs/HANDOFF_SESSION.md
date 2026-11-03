# Handoff: where Bluefin stands (2026-11-03)

For a Claude picking this up with the repo but none of the memory. Read this first, then `docs/FIGHT_DESIGN.md`, `docs/MUSIC_SYSTEM.md` and `docs/gaps_audit.md`.

## The project

Bluefin is a first-person bluefin tuna fishing game in Godot 4.7.2, in this repo (Gull-Harbor). It has three modes:
- **Solo**
- **Co-op**: up to 4 crew, as a career with a boat payment every 3 trips.
- **Rivals**: two boats against each other, even teams, best of 3 days.

The owner is Kortev (the git name), and they're also the studio name in credits. Nobody else works on it.

- **Branch:** `claude/zealous-mendel-h2udij`, pushed to origin. All work lands here. `main` is old.
- **Godot:** `C:/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`, plus the non-console exe beside it for windowed shots.
- **Tests:** headless, e.g. `$G --headless --fixed-fps 30 --path . tests/X.tscn`. Net tests run as two processes: `-- --role=host` in the background, `sleep 3`, then `-- --role=join`. Each test has a fixed port, so don't run two net tests at once.
- **Builds:** `$G --headless --path . --export-release "Windows" export/Bluefin.exe`, then zip Bluefin.exe, steam_appid.txt and the *.dll files into `export/Bluefin_buildN.zip`. Only build when the user asks.
- **Show-off clip:** `CLIP_ARGS="--cond=rain" bash tools/promo.sh export/bluefin_clip.mp4`. It needs `pip install imageio-ffmpeg`, which is already installed.

### The local quirks

- **`project.godot`:** the user has an uncommitted change that removes the `[rendering]` vulkan driver section. Never commit it and never revert it. When merging, use `git stash push -q -m bluefin-pg-keep project.godot`, merge, then `git stash apply <that stash's sha>` and drop it by its tag. Never pop a bare stash, because the stash stack is shared with GitHub Desktop.
- **`.import` files:** many show as modified, but only their line endings differ. Leave them alone, and never run a broad `git checkout -- .`.
- **Merges:** merge other branches with `git merge --no-edit refs/heads/<branch>`.

## How the user wants things done (standing rules)

- **Quality:** release quality, even though it won't go on Steam. They won't pay the $100. Steam app id 480 stays and achievements also work in-game. Never treat "it's just for my buddy" as a lower bar.
- **Hands-on:** the player does the work by hand, and every action is animated. Never automate what a person would do, and don't make one press do everything.
- **No snapping:** nothing snaps or teleports. Everything moves continuously.
- **Physics, not modes:** like Sea of Thieves. You sprint and jump off the boat and physics takes over, with no "press Space to get on the rail".
- **Show, don't tell:** the game teaches itself, with no walls of text.
- **Pixel style everywhere:** low-res, nearest filtering, and the pixel font `ui/pixfont.gd`.
- **Fair Rivals.** The two boats never share one school.
- **Realistic but fun.** The user corrected over-realism: realism goes in the world, boat and crew, while the hands get gamified.
- **Hunt for fakes yourself:** find things that are physically right but look fake (e.g. fishing lines drawn as thick white triangles) and fix them without being asked.
- **Merge everything, commit and push as you go.** Don't publish anything externally without asking. Ask before downloading anything, giving the filename, source and size.
- **Short answers while the user playtests.**

## Decisions that shape everything now

- **Crew-size rule (hard):** the world's rules never depend on crew size. Every mechanic exists the same for 1–4 players, and crew size only changes how many hands there are. Bigger crews stay busy because of the boat they pick: more rods, the tower, a longer deck, a bigger bilge. Never use a mechanic that switches on with more players.
- **Difficulty:** solo is very hard, barely possible. Two on the skiff are feasible with both busy the whole time. The sportfisher needs 3–4 working together. Like Sea of Thieves sloop vs galleon: a good small crew can beat a sloppy big one.
- **Crew caps:** the skiff takes 2 at most and the sportfisher 4. Rivals teams may choose any boat within its cap.
- **Money:** one shared crew wallet with no crew pay. The career's pressure is a flat boat payment every 3 trips (skiff $7k, sportfisher $13k). It doesn't rise; it only goes up if you choose a bigger boat. A missed payment is currently "the bank takes the boat". The plan is a funny playable grocery-store shift instead, then a partial restart (not built).
- **The fight:** being rebuilt to `docs/FIGHT_DESIGN.md`, "Bend, Head and Heat". The "Decisions" section at its end overrides earlier text. In short:
  - a bend gauge with a gold band just under the drag, plus a red line-wear line;
  - steering his head;
  - a hand bilge pump only on the skiff;
  - only the Shout key plus Dale's tips, with no automatic crew calls;
  - a 300 kg fish takes about 16–18 min, and rare 600 kg trophies about 30 min.

  It must stay gripping for 30 min.
- **Rivals 1v1:** an inshore ledge, 120–200 kg fish, 20-minute rounds, scored on weight plus how beaten your hooked fish is at the horn.
- **Leaps between boats in heavy seas** stay realistically hard: the boats ride the water's orbital motion.

## What's done (all on the branch)

- **Movement:** walkable harbour and pier, real dock lines, hand selling on the buyer's scale, a tow launch instead of fades, and hands-on prep with a per-mode setting.
- **Fish handling:** rope the tail, spike, bleed, pump, gut and ice, all graded with reasons on the slip.
- **Gear:**
  - baiting by hand
  - jigging with the line paying out
  - reeling animations
  - free-spool let-back
  - lines that are thin, sagging and fading, with outrigger clips
- **Water and the boat:**
  - real buoyancy (`boat/buoyancy.gd`): 21 cells with mass and damping, never under a crest or over air
  - near-sea waves matched to what she floats on
  - the hull hold that never walls water at her rail
  - green water draining out the scuppers
  - storms about 5.4 m
  - orbital carry
  - a bow wave
  - a smooth wake
  - foam that lingers
- **Balance (current fight):**
  - doubles about 1 in 5
  - a fifth "shotgun" rod off the sportfisher tower
  - a live-well pump chore
  - tower spotting to 1.8 km, while the radar shows birds only
  - the sportfisher at 26 kn with a shelf-edge ground 3.6 km out with bigger fish
  - the skiff fills with water in heavy weather
  - good solo lands about 65% of 300–400 kg fish, and a good crew lands all of them
- **Fight readability:** a big FISH ON for everyone, a rod marker, a bigger reel inset and a coach. This is being replaced by the rebuild.
- **The rest:**
  - gamepad support
  - rejoin after a drop
  - achievements page (16 pixel medals)
  - UI passes
  - a visual-realism sweep
  - adaptive music and environmental sounds, with a loudness-matched mix
  - a show-off clip tool

## In flight right now (agents in their own git worktrees, each on its own branch)

They report back to the session that started them. If that session is gone, find their branches with `git branch --list "worktree-agent-*"`. Check what each has committed and merge the finished ones into `claude/zealous-mendel-h2udij`. Each was told to run the full suite and not push.

| What | Branch | Notes |
|---|---|---|
| The new fight (sims first, then code) | `worktree-agent-aecd4caa5adf2f77a` | Must keep feeding the music: `Fight.cues()` keys `tension, spool, line_out, depth, move, slack, airborne, surging, kg, contact, props, tangled` (see `audio/music.gd _fight_of`, `audio/music_state.gd feel`). Run `music_test` and `music_fight`. |
| Shared wallet, boat caps, Rivals 1v1 | `worktree-agent-a9a39ad2237b3f4eb` | Removes the 12% crew shares. Skiff cap 2, sportfisher 4. |
| Light, sky and watchable weather | `worktree-agent-af88260d61e7cb425` | Golden hours, sun shafts, moving clouds, night sky and bioluminescence, visible squall lines, fog banks, rainbows. **Weather must expose what's coming and when (e.g. `next_kind`, `eta`) so the music can change on the bar before a front arrives.** It must not edit `audio/music*.gd`. |
| Life at sea | `worktree-agent-a4822440bf9e3bb84` | Diving birds, tuna busting from the real schools, dolphins at the bow, whale spouts, flying fish, a distant fleet. |
| Harbour mood | `worktree-agent-a5c0b78c3a08cc5d7` | Dawn mist, lit windows, smoke, a lighthouse beam (shared clock), a bell buoy, gulls on the pilings, townsfolk, boats on moorings. |
| Harbour leftovers (older, may have died) | `worktree-agent-a95b0193705fc0997` | A reliable gunwale vault at variable fps, the pier ladder, boat B's davit/pump/ice, tow state for late joiners, ice in the scoop. Check whether it committed anything past `cc2a9d8`. |

**The other session: the music.** Its title is "Plan a dynamic music system for Bluefin". It works directly in the main checkout (not a worktree) on `audio/music*.gd`, `music/`, `tools/music*.py` and `tests/music_*`, and it commits and pushes to the branch itself. Its design is `docs/MUSIC_SYSTEM.md`. It is now rendering per-weather songs and fight music: the strike turns the song, the band plays harder and the fight builds. A child session of it, "More environmental sounds", built the ambience (`audio/`, tools/loudness.py). If its files are dirty in the checkout, merges fail; ask it to commit first.

## Known issues and next up

- **Flaky tests under load** (they pass when re-run alone): leap_moving, doubles, voice (friend side), tower, harbour_walk, vs_net "lines still out".
- **Rain clip:** at the very start, big white blobs show right by the camera (raindrops or spray drawn too close).
- **Deck floods** at night make the water glow too much.
- **Planned, not built:**
  - Rivals 3v3/4v4 on a bigger "yacht"
  - a spectator/ref role for odd numbers
  - per-mode match settings
  - the grocery-store shift
  - the rest of `docs/gaps_audit.md`, ranked: hand docking and selling are done, while helm levers, NPC life, other boats, progression, footsteps, real SFX, accessibility, graphics presets and more remain
- **Never verified by hand:** almost none of the recent work has been played with a real mouse, pad or second machine. The user's playtests are the truth: ask what felt bad and fix that first.
