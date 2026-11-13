# Menus in the instruments look: the brief (2026-11-12)

The fight screen and the in-play HUD are drawn with `ui/kit.gd` ("INSTRUMENTS AND STAMPS"). The menus are still the
old look: 3 x 5 pixel letters, dark panels with an amber edge, filled buttons. This pass moves them over. The owner's
words on the old look: "shitty pixel text"; on a glass/rounded attempt: "looks AI generated... curved stuff and UI
boxes are very big indicators of AI. It should look really cool and be unique and maybe kind of minimalistic, but
not look AI generated, just look professional." He approved the instruments look on the fight screen.

## Read first

- `ui/kit.gd`, all of its header comment (the eleven rules) and its helpers.
- Two screens already done, to copy the hand from: `ui/fight_arcade_hud.gd`, `ui/hud.gd`.
- Pictures of the target look: `docs/shots/hud5_ride.png`, `docs/shots/hud5_heave.png`, `docs/shots/hud2_bigpull.png`.

## The rules for menus

1. No panels. No `StyleBoxFlat`, no filled rect behind a group of things, no border round a group, no rounded
   corners, no gradient, no drop shadow copy of the text, no amber edge bar. Type and linework straight over the
   world, each stroke keylined by the kit.
2. One exception, menus only: a page that takes the whole screen (settings, achievements, the manual, the results
   card, the pause card) may dim the WHOLE screen with one flat colour, `Color(0.02, 0.03, 0.04, 0.6)`, edge to
   edge. Never a rect smaller than the screen.
3. Three inks: `Kit.PAPER` for nearly everything, `Kit.YELLOW` for the picked thing and for reward, `Kit.ORANGE`
   for a warning or a loss. Dim text is PAPER at alpha 0.6, not grey. One more exception: a boat's own colour
   (`boat_colour`) may appear as a small solid `kit.square()` beside her name, and nowhere else; her name itself is
   PAPER (YELLOW if she's yours).
4. Type: `kit.label()` (small spaced capitals) for labels, hints and headings of columns; `kit.num()` (weight 700)
   for numbers and for a page's title; `kit.text()` for a sentence. All capitals. Sizes times `kit.px`
   (`kit.px = size.y / 1080.0`, set at the top of every draw). Nothing smaller than 15 * px.
5. The parts, so every page is built the same way:
   - A page's title: `kit.num()` about 44 * px at the top left of the page's column, a heavy `kit.rule()` under it
     the width of the column, and a `kit.scale()` of ticks hanging under the first 30% of that rule.
   - A list of choices: one a row, `kit.text` weight 600 about 30 * px. The picked one is YELLOW with a solid
     `kit.tri()` pointing at it from the left; the others PAPER. No bar, no box. What the picked one does goes
     beside or under it as a label at alpha 0.75.
   - A table: a fine rule under the heading row, nothing between the rows, numbers right-aligned or centred in
     their column; the column that's yours marked with `kit.corners()` round it, not a fill.
   - A slider: a `kit.scale()` ruler with a solid `kit.tri()` sitting on the value, and the value as `kit.num()`
     to its right. An on/off: the word ON or OFF (YELLOW when on). A choice of several: the word, with small
     `kit.tri()`s left and right of it when picked.
   - A button: its word, with `kit.corners()` round it; picked: YELLOW and heavy. Never filled.
   - A tab row: labels, the open one YELLOW with a tri under it.
   - A field you type in: a heavy rule under the text and a blinking `kit.bar()` cursor. No box.
   - A grade, a winner, a new record: `kit.stamp()` (the one loud thing; at most one a page).
6. Godot `Label`/`Button` nodes: either draw them yourself instead, or `Kit.style_label()` and
   `StyleBoxEmpty` on every state. The default font is the kit's now (`sea/sea.gd`), so a node with no font
   override is already in the right face.
7. `Kit.old_draw()` / `Kit.old_width()` take the same arguments as `PixFont.draw()` / `PixFont.width()`, for a
   line that only needs its face changed. Prefer the kit's own calls where you're redrawing anyway.
8. Motion: hard and short. A thing is there or it isn't, or it travels at a steady rate. No soft pulses.

## What must not change

- What a screen does: every choice, key, pad button, mouse hit rect (move the rects with what you draw), every
  public function and what the tests ask of it. This is a redraw.
- The screens aboard the boat (the plotter `boat/plotter.gd`, the sounder `tuna/sonar.gd`, the radar, the signs in
  the town `sea/places.gd`, the fuel label in `boat/boat.gd`) stay pixel: they are things in the world.
- `ui/pixfont.gd` stays. `ui/kit.gd`: add a helper only if two pages need it, at the end of the file, and say so
  in your report (other people are editing other files at the same time; only touch the files you were given).
- Never commit, never stash, never `git checkout` anything, never touch `project.godot` or any `.import` file,
  never kill a process you didn't start. Tabs for indentation, typed GDScript, comments in the file's own voice.

## Checking it

- Godot: `G="C:/Users/gamek/Downloads/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"`.
- A test, headless: `"$G" --headless --fixed-fps 30 --path . tests/NAME.tscn 2>&1 | tail -20`.
- Pictures (needs a window, about a minute a part):
  `"$G" --path . --resolution 1600x900 res://tests/ui_shot.tscn -- --part=PART --out=DIR/ --port=PORT`
  with PART one of `menus`, `sea`, `rivals`. Use your own DIR (in the scratchpad you are given) and your own PORT.
  Then LOOK at every picture of your screens with the Read tool, and fix what's off: overlaps, clipped words, text
  too small, anything that still looks like a box. Do this at least twice. Also once at `--resolution 1280x720`.
- Report: what you changed, which pictures you looked at (full paths), which tests you ran with their results, and
  anything you left or weren't sure of.
