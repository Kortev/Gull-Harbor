# Bluefin's music: the design

## The design now (2026-11-04, the rethink): a few songs, the fight, the strike

**Kortev: "I think we kind of need to rethink this system in general... I just want everything to feel very
immersive... especially the strike cue, that was really good, and I think we can make that even better... I want it
to feel like, wow."** Picked: a few whole songs and a fight with layers, three cues. Everything below this section is
the history of the system it replaced: a band reacting to everything (a dozen cues, quick masks, passages chained
part by part on a clock of its own), built and tested without anyone hearing it in the real game (its clock was
broken there until 2026-11-04), and too busy once it worked (a hit and a duck on every flash of a storm's lightning).

What plays:
- **The title's piece** while the title's up (the theme, its layers by the weather on screen); its last chord rings
  on as the song comes in.
- **A song for each weather** (tools/music.py `songs()`): fair, rain, fog, night and the storm, each rendered whole
  (its parts in order, arranged as a band would play them: the intro sparse, a verse's tune and then its
  counter-melody, choruses with the lead up high the last time, a bridge, the outro; a drum fill into each chorus
  and bridge; each part's tail ringing into the next, the last round into the first). Two layers: the band, and the
  run (the drums and the bass pushing, up with her speed). It plays through and round; when the weather turns and
  stays SONG_HOLD (8 s), the new weather's song comes in as the old goes, over SONG_FADE (8 s). Tied up it plays at
  HARBOUR (0.55). A song gone quiet is paused where it was and taken up from there when it's back.
- **The fight** (tools/music.py `fight()`, `fight_intro()`): the strike is one recording, everything at once on the
  reel's scream (the big drum twice, the timpani, the low B, the band's B minor, the cellos digging in, a splash, the
  sub dropping), then two bars of drums alone rising out of its ring, a cymbal rolling up into the fight's first
  downbeat. It's the front of the fight's track (an AudioStreamInteractive: the intro runs on into the loop by
  itself, sample for sample), started from its top the moment a fish takes, the song gone under the hit in
  STRIKE_OUT (0.25 s). Measured on the real sound card: the hit heard 12 ms after the strike.
  The fight's loop has three layers, up and down with how hard he's fighting (audio/music_state.gd's intensity:
  his moves, a run at once, the backing showing, the line near going, the fight building the longer it goes, the
  leader): **pulse** (the dark pad, the bass riff, the heartbeat: always), **drums** (the war drums, boots and
  claps), **full** (the drum section, the fiddle's tune, the line singing, the giant's drum). A layer comes in in
  0.3 s and holds 4 s before it can go, going over 2.5 s: the band joins at once and leaves one by one.
  Boatside, the harpoon: the pulse and a little drums.
- **Landed**: a flourish (the hit, then the theme's opening phrase on the whistle and the fiddle, home on D); the
  fight let go over FIGHT_OUT (2.5 s); the song back over BACK_IN (4 s) once the flourish has rung (AFTER, 3.5 s).
- **Lost**: the fight let go over LOST_OUT (1.2 s), quiet for HUSH (3 s), the song back over BACK_IN.
- **Rivals**: quiet under the countdown and the results card, and their stings.

Nothing else cues anything: the thunder, birds, the leader, boatside, Rivals' lead are the world's own sounds.
Nothing keeps time: the pieces loop and run on by themselves, the fight's intro runs into its loop inside Godot's
mixer, and every change is a fade, so there's no clock to break and nothing to run out. The deck whistle follows the
chords by the playing piece's position (with no sound card, by the game's frames).

The mix is as it was: ducked under the radio and voices (with the pocket), muffled underwater, dulled under the pause
card, a limiter last.

Files: tools/music.py (the composition), tools/sampler.py (the recorded instruments), audio/music_state.gd (the
mind), audio/music.gd (the players), audio/music_hud.gd (`-- --music-hud`). Tests: tests/music_state_test,
tests/music_test, tests/music_fight_test, tests/whistle_test (headless); tests/music_live_test (a window, the real
sound card: tools/music_check.sh).

## History: the reactive system it replaced

## As built (2026-11-04, evening): the song's clock runs in the real game

**Kortev, playing from the editor after the scenic silences were off: "it turned off for me the second i moved the
boat."** Reproduced in a window on the real sound card (every test before ran headless or under the movie maker,
where the clock is the frames'): the music played about 35 s and then never again, and the song's clock (`_t`) never
moved off 0.

- **The clock was empty.** It's a silent looping WAV whose position is the mixer's time, and its data was made with
  `w.data = PackedByteArray()` then `w.data.resize(n)`. `w.data` reads back a copy, so the resize changed the copy,
  the clock had no samples, ended at once, and its position stayed 0. The quiet's clip ("rest") was made the same
  way. Both are built first and then handed over now.
- **So the song never conducted in the real game:** with its time standing still it never asked for a next passage,
  never turned for a strike, and played its cues at once. While the passages looped, one passage repeated forever;
  once they played once with a tail, the music ran out after one.
- **The song can't run out now, whatever the frame rate does:** a passage's end that goes by unasked (a frame
  stalled past its whole last bar) still gets its next, on the tail's next beat (`late:` in the log); and if the bed
  ever stops anyway (Godot's interactive stream stops for good once what's playing ends with nothing after it), it's
  started again and the song asked back in (`_revive()`, `revived` in the log).
- **tests/music_stall_test** (a window, the real sound card; tools/music_check.sh runs it): a 2.6 s frame over a
  passage's end, and the bed stopped outright; the song plays on both times. A drive out of the harbour on the real
  sound card: passages chained on time, never under -60 dB.

## As built (2026-11-04, later): no scenic silences

**Kortev: "i drove out and the music just stopped."** Measured through the real mixer: casting off in fair weather,
the band let the song go over 6 s and there was nothing (-93 dB) for 82 s, till she was 150 m past the harbour mouth.
That was the scenic silence, working as it was built. A long quiet stretch at sea had a 20 s one too. Both are off
(audio/music_state.gd: `SCENIC_MOODS` empty), as the "music always" playtest asked: casting off plays its lead-in
(`away_in`) and the song plays on out of the harbour. tests/music_state_test checks casting off in every weather and
400 s of nothing happening at sea: the band never stops.

## As built (2026-11-04): a real band, tunes from the theme, less at once

**Kortev, after playing it: it still cuts, the cues too; the instruments sound fake; the tunes are forgettable; the
feel's wrong or too busy. Free samples chosen over the synth or composing in FL Studio.**
- **The cues ring on under each other.** Every big cue shared one player (the small ones another), and a player
  given the next cue's stream stops the last at once: the strike's hit was cut off by the fight's drum break a bar
  later, each thunder by the next. Six players now, each cue on a free one (`_voice()`).
- **The fight's masks are played, not switched:** him in the air, the line about to part and the harpoon flying take
  the band down over `MASK_DOWN` (0.25 s) and back over `MASK_UP` (0.5 s), not 0.08 s and 0.2 s. In the air it's down
  to `AIR` (a quarter). A fish lost stops the band over 0.35 s (0.08 s sounded like the music breaking).
- **Recorded instruments** (tools/sampler.py; `python tools/fetch_samples.py` fetches 181 files, 204 MB, into
  tools/samples/, which git ignores; only the rendered music ships). From Versilian Studios' VCSL and VSCO 2 Community
  Edition, both CC0:

  | Synth's name | Now |
  |---|---|
  | `pluck` | the double bass (pizzicato) under D3, the strumstick to B5, the folk harp above |
  | `strumstick` (the picking) | the strumstick, anything lower an octave up |
  | `harp` (night) | the folk harp |
  | `whistle` | a soprano recorder (the synth's whistle under A4) |
  | `reed` | a harmonica |
  | `fiddle` (the darker songs' tune, the climax under the whistle) | a solo violin |
  | `bowed` | the cello section, the violin from E4 |
  | `pad` | the strings holding the chord |
  | `bell` | hand chimes, the glockenspiel up high |
  | the drums | frame drum, a giant hand drum on a mallet (the war drums), the frame drum muted (boots), claps, shaker, a cymbal |

  The heartbeat, the sub swells, the line singing and the wind stay synthesized. Every take was checked: within a
  few cents of its note. VCSL and VSCO's cello and bass call middle C "C3", so their notes sound an octave above
  their names; the violin's names are as they sound. With no samples there, the synth's own instruments play
  (`_*_synth`).
- **Tunes from the theme** (`motif_tune()`): the passages with no tune of their own (fog, night, the storm's way in
  and out) are built from the theme's five little phrases (`MOTIFS`: its opening call, its sigh, coming home, a
  lift, a turn), a motif a bar in two-bar phrases said and answered (`PLANS`), each starting on a chord tone near the
  last, the long notes on the chord, the last bar home. Over a chord with a note D major hasn't got (F# major's A#,
  C, F) the tune walks that chord's own scale (`scale_of()`).
- **The counter-melody is a second part, not a second tune** (`counter()`): long notes on each chord's third or
  fifth, stepping the shortest way, never on the tune's note, now and then passing on to the next chord.
- **Less at once:** in a fight only the one tune (no counter-melody), and the picking steps back to a fifth as the
  drum section comes in; a storm at sea without the fight's deep drone (it doubled the storm's own cello and sub).
- Credited on the title's credits page and in THIRD_PARTY_NOTICES.txt.

## As built (2026-11-03, night): no more cuts between passages; quicker to answer

**Kortev: "the music still cuts pretty poorly when changing songs or is delayed from when stuff happens. really bad
cuts happen throughout."** Measured in a scratch project through the real mixer (AudioStreamInteractive, as the game
builds it), there were two cuts:
- **Every join (every 17 s):** each passage was rendered as a loop, its tail (its last chord ringing, its room)
  wrapped round onto its own start. Chained into a *different* passage, that meant:
  - its own last chord sounded over its first downbeat;
  - the passage going out was looped back to its start for the half-beat crossfade, so its first strum leaked over
    the new downbeat (78% in the first eighth of a second);
  - the new passage faded in, so the downbeat was soft (25%).
- **Every repeat** (rain's verse into verse, chorus into chorus; fog's verse into verse): Godot's interactive
  stream asked to switch a clip into itself goes **silent** from the ask until the bar line. The ask is made in the
  last bar, so that's nearly a bar (about 2 s) of nothing.

The fix:
- **Passages aren't loops** (tools/music.py: `TAIL`). Each is its bars, then 3 s of what still rings, faded at the
  last; the Oggs don't loop. Godot plays past a clip's `beat_count` as its tail when a transition fades it out
  (measured: a non-looping clip's tail rings under the next; a looping one jumps back to its start instead).
- **One passage into the next:** the next comes in full on its downbeat (`FADE_OUT`, not a crossfade), and the last
  one's tail dies away under it over `TAIL` beats. A jump on a bar inside a passage (the strike's turn, the theme for
  the leader or for landing him) lets the one going out go over `JUMP` beat, under its cue's hit. Each switch sets
  its own pair in the bed's transitions just before it's asked for (`_fade_into()`).
- **No part straight after itself:** rain is `in v ch v br ch v ch out`, fog `in v br v out`, and `_pick_sea()` steps
  past a repeat if one ever comes up. tests/music_test checks every song.
- **The fight's own passages by name** (`FIGHT_PARTS`: f1, f2, f3). They were found by their first letter, so once
  the weather's songs came in, every fair and fog part played the fight's driving bass riff and was played in fights.
  The strike's turn now always picks one of the three (`_pick_fight()`), even when it lands on a passage's end or
  after another switch.
- **The song never runs out under a waiting jump:** a passage's next is asked in its last bar even with a jump
  pending, by `CHAIN_LATE` s before its end at the latest (a non-looping passage left alone would end in silence).

Quicker to answer what happens:
- **The weather turning:** the new weather's song comes in from its top as the passage playing ends (at most 17 s),
  instead of after the old song's outro too (up to 34 s, with the fair song carrying no rain layer meanwhile).
- **Landing him:** the hit on the next beat (was the next downbeat, up to 2 s), the theme on the bar after it.
- **Lead-ins** (the birds' bells, casting off, the race called) end on the next downbeat *or the bar's middle*
  (`LEAD_GRID`), so they start within half a bar of what they're for.
- **The leader:** if it comes too late in a bar for its fill, the theme comes in on the bar line anyway, without
  waiting a bar for the fill.

## As built (2026-11-03, later): the weather's songs, and the fight's own

This builds on "one song" below: still one band in D / B minor at 112, still one Interactive stream, every passage
with every layer, so a strike can turn anything into the fight on the beat. What changed:
- **Each weather has its own song, played through in its form** (`SONGS` and `STYLE` in tools/music.py; the cues'
  `songs` entry carries each form):
  - fair: intro, two verses, the theme (`sea_t1`, `sea_t2`), a verse, a bridge, the theme again, the outro;
  - rain: a reed song, the guitar muted, the patter in;
  - fog: almost still, a far whistle, bells for the guitar;
  - night: a lullaby on the bells, a harp of high plucks;
  - storm: its way in, the storm's three grinding passages (`sea_s1`..`s3`) twice, its way out.

  Each part's melody or its counter-melody is written from its chords by `tune()` (chord tones on the strong beats,
  steps between, a two-bar rhythm said and answered, home on the root). Each passage's role (intro, verse, chorus,
  bridge, outro) comes from its name.
- **The band rearranges each part each time round** (`_arrange()` in audio/music.gd): the intro sparse; a verse's tune,
  then its counter-melody (`alt`) the next time, now and then an instrumental or the guitar out; the last chorus with
  the lead up high; the bridge the counter-melody alone; the outro winding down.
- **The weather turning:** the band heads for the song's outro, and the next song is the new weather's, so the
  weather changes as one song ends and the next begins. (Not yet: changing on the bar *before* a front arrives. That
  needs the weather to say what's coming and when, e.g. `next_kind` and `eta`; the sky work was asked for it.)
- **The fight has its own passages** (`sea_f1`..`f3`: a chord every bar over a driving bass riff), played only in a
  fight and nearly always in one until he tires. On the bar after the strike's hit the song turns into one, with a
  two-bar drum break (`fight_in`) driving in. Out of the fight, the weather's song picks up from its first verse.
- **The band plays harder** by the state's `heat` (a fish on 1, tiring 0.9, boatside 0.7, landed 0.6, the hunt 0.15,
  the race home's end, a storm): the whole song up to 5 dB louder, up in under a second, down over six.
- **The fight builds the longer it goes:** the drums never right down after 20–40 s, the drum section (`pound`) in
  from one to two minutes, the tension never off from 90 s to 2:30. Sounding deep it backs off, and his next run after
  it hits with everything.
- **The music on screen** (`-- --music-hud`, audio/music_hud.gd): what's happening, the passage, chord, bar and beat,
  the heat, the fight's time, the danger, each layer's level as a bar, and the cues as they're played. For videos of
  it working, and for tuning.
- **Rendered:** 50 cues, 29 passages (the five songs' parts, the storm's three, the fight's three, the theme's two),
  each passage's stems summing back to the whole within -22 dB. The old shuffled passages `sea_a`..`sea_j` are
  retired and their files deleted. `music/` is 57 MB. The render takes about 6 minutes.

## As built (2026-11-03): one song

**It's one song now (Kortev: "the same song, reacting to what's happening, playing certain sounds on different
beats, instead of changing the song").** This supersedes the sections in the plan below and the notes after this
one.
- **After the title, everything is one endless song:** fourteen 8-bar passages (`sea_a`..`sea_j`, the theme's
  halves `sea_t1`/`sea_t2`) in D / B minor at 112. Each passage has the same 17 layers on its own chords, so any
  state is just a mix:
  - pad, bass, guitar pick, lead, and high (the climax);
  - rain, storm and night (the weather);
  - run (her speed), and a fill into the next passage;
  - pulse and glint (birds working);
  - beat (the heartbeat), drive (the war drums), tension, deep and heavy (a fish on).
- **What's happening only moves the layers** (`music_state.gd`'s `_wants()`), and how bright a passage comes next
  (dark in a fight, the weather's own otherwise). The sections (sea, harbour, hunt, fight, tired, leader, gaff,
  afterglow, race) are mixes, not songs.
- **What happens is a cue over it on the grid:**
  - the strike's hit on the next beat;
  - the birds' bells (`hunt_in`), casting off (`away_in`) and the race called (`race_in`), as lead-ins ending on the
    downbeat;
  - boatside (`boatside_end`) and home made (`race_end`), as hits;
  - for the leader, a fill ending on the bar and a jump to the theme (`sea_t1`) on it;
  - for landing him, the `landed` hit on the downbeat and the theme (unless it's playing already).
- **Passages join on the bar with a half-beat crossfade at most** (JOIN). There are no section switches left to
  smear.
- **The "music cuts off while driving" report:** the old hunt section (no tune, a thin pulse) took over whenever
  birds came near. That's gone: birds only add their layers to the song.
- **The title** is its own piece in ten stems, following the weather on screen:
  - fair: whistle and band;
  - rain: the patter, and a softer whistle;
  - storm: no whistle, the theme low on the bow over the storm's drums;
  - night: the bells;
  - fog: a far whistle.

  Its last chord rings into the song (`title_end`).
- The harbour waltz and the race jig are retired. The dock is the same song played quietly, and the race home is
  its drive and run layers building against the clock.

## As built (2026-11-02)

**Bluefin's theme (Kortev: "at least one really recognisable tune that's beautiful").** `THEME` in tools/music.py
is sixteen bars in D at 112. It opens on a rising A–D–F♯, climbs to its high B in bar 13, and comes home. It's
woven through everything:
- the title plays it whole (whistle, then concertina and drums);
- at sea, its two halves are passages (`sea_t1`, always followed by `sea_t2`);
- the hunt's bells ring its first three notes;
- the leader is its second half, soaring;
- the afterglow when he's landed is its first half coming home;
- the Rivals win sting is its opening.

**And then:**
- **Her speed:** a `run` stem at sea (drums' eighths, the bass pushing) rises from 25% to 80% of her top speed.
- **His size:** a `heavy` stem in the fight (the bow an octave down, the biggest drum, the sub) comes in from 120 to
  320 kg.
- **The sea:** twelve passages now (four more), plus a drum-fill stem locked to each passage's last two beats. It
  opens into the next passage 20–50% of the time (more when running).
- **The race home** is rewritten in the sea's bar (a jig in E dorian, 12/8 at 112), so the sea goes into it on the
  bar.
- **The deck tin whistle** (slot 6, `crew/hands.gd`): hold left mouse and look up or down. Every note is one of the
  band's current chord (each section's chords are in audio/music_cues.gd; `Music.whistle_note()`), and it starts on
  the music's next eighth (`Music.next_tick()`). Everyone aboard hears it. The third-person arm doesn't yet raise to
  the lips (that's the player's arm poses, crew/player.gd); the whistle tips up toward the face instead.
- **A real game's recording can be checked:** run with `-- --music-log=<file>` and tools/music_check.py reads what
  played, and when it was meant to be still, beside the movie maker's audio.


**Changed after a playtest (Kortev): music always, an endless soundtrack in sync with the game.** The quiet at sea
(a phrase now and then, long silences) is gone, along with its one-shot phrases (calm, fog, rain, storm, night,
dawn). Principle 1 ("silence is the default") no longer holds. In its place:
- **The sea is an endless song.** Six 8-bar passages (`sea_a`..`sea_f`: three bright, three dark) at 112 bpm in
  B minor / D, the hunt's and the fight's own tempo and key. Each next passage is picked as the last one's final bar
  begins: never the same twice running, weighted bright or dark by the weather and the hour (dusk darker, the
  first light bright). It joins on the passage's end with a one-beat crossfade. Birds → hunt → strike → fight is
  one piece getting more intense, on the beat.
- **The weather plays the sea's stems, eased over several seconds rather than switched:**
  - pad and bass always;
  - guitar picking and the lead in fair weather;
  - the rain's patter;
  - the storm's half-time war drums, bowed drone and sub (no tune);
  - the night's bells;
  - fog is sparse and far.
- **The harbour follows the weather too:** guitar alone in rain, the concertina far off in fog, soft at night.
  In a storm or downpour the dock plays the sea's storm instead of the waltz.
- **The only silences:** the hush after a fish is lost (6 s, then the sea fades back in), him in the air, the
  harpoon flying, and under Rivals' countdown and card.
- **Clock drift fixed.** Godot takes each grid switch 0–4 ms early (1.8 ms on average), and the next switch counts
  from where it really landed. Endless chaining made our estimate drift: 20 ms late by the second fish, and growing.
  `EARLY` takes the average off at each grid switch, which held every switch within ±2 ms over 146 s.
- **The strike's hit now waits for the fight to be asked for**, so it always lands with the fight, even when a
  switch was already under way.
- **The drums stay up while he circles at the end** (0.6, was 0.4). The balance pass's shorter fights had pulled
  the drive under a third of big fights.
- Measured: switches within ±2 ms; stings within about 10 ms (they start from a frame, so they can be off by a mix
  block); no clicks; never quiet outside the deliberate silences (`tools/music_check.py`'s new check). The music is
  15 MB. Demos (not committed): `export/music_demo_fish.ogg` and `export/music_demo_sea.ogg` (the sea through fair,
  rain, storm, night, fog and a sunny dusk).

### First build

Built and pushed on `claude/zealous-mendel-h2udij`. Below is what changed from the plan, and why. The rest of this
document is the plan as approved.

- **Files:**
  - `audio/music_state.gd`: the pure state, game picture in, section/stems/events out.
  - `audio/music.gd`: the conductor.
  - `audio/music_cues.gd`: the manifest, written by `tools/music.py`. It's a script rather than JSON so it goes into
    the export with no filter change.
  - `music/*.ogg`: 63 files, 13 MB, up from 3.8 MB. Stems are encoded a little lower than the full cues.
- **Measured in the real mixer** (`tools/music_check.sh`: movie-maker render, then `tools/music_check.py`):
  - every switch lands within 4 ms of the grid of the clip before it;
  - stings land within 3 ms;
  - no clicks at any switch, sting or loop seam;
  - the line about to part is 6.5 dB thinner than a run, and him in the air is 19 dB down;
  - a loss is true silence.
- **No filler clips.** Godot doesn't fade from a filler into the next clip, and a loop's first sample is its tail
  wrapped round, so the leader came in with a click. The leader's drum fill is now a sting timed to *end* on a bar
  line: it plays over beats 3–4 and the leader enters on the downbeat with a 0.1-beat fade (`ENTER`). The same
  0.1-beat fade covers the strike's entry from the quiet.
- **Stings have 60 ms of silent pre-roll** (`PRE` in tools/music.py). The conductor starts them a frame early and
  seeks into the silence by the remainder, allowing for the mixer's next block, so a 30 fps frame no longer moves a
  hit by up to 33 ms.
- **The clock:** a silent looping player's position (the mixer's time) on a sound card, and game time headless or
  under the movie maker (the Dummy driver). `AudioStreamPlaybackInteractive` reports no playback position, so where
  each clip started is worked out from the grid it was asked on. Godot lands each switch 0–4 ms early, so the
  estimate can drift by that much per chained switch. It re-anchors every time the music returns to the quiet.
- **Danger retuned to the real fight.** Bot-played fights (`tests/music_fight_test`) sit at a median bend of about
  0.1 of breaking strain, 0.3 at the 90th percentile, and rarely above 0.45 (the drag tops out at 0.55, and the
  hook tears past 0.5). The tension stem now rises with a loaded rod (0.18 → 0.4: in for 25–50% of every fight).
  "About to part" is past the hook's tearing point (0.4 → 0.6). It shows 0.1–0.3% of the time, which keeps it a rare,
  real moment. Every fight peaks the drive at least twice and keeps it up 31–59% of the time, in flat calm.
- **The race home yields to a fish on.** Before, the race beat the fight. Now a fish on during the race home plays
  the fight.
- **No edits outside audio/.** The world is read with `get()`: `landing._flight` (the harpoon flying), the local
  player's `_under` (underwater), each school's `feeding()`/`center()` (birds). rods.gd's old `hush(3.5)` call is
  harmless (the state detects a loss for itself), so it stays.
- **Not made:** the grocery-shift muzak, because the shift isn't in the game yet.
- **Tests:**
  - `tests/music_state_test` (around 50 cases, including the hold-is-never-heard fairness check);
  - `tests/music_test` (against the real sea);
  - `tests/music_fight_test` (the music over bot fights);
  - `tools/music_check.sh` (the real mixer; opens a window for about 2 minutes).

## The one-line pitch

A fish-shed folk band that is mostly **silent**. It plays like a live band watching the water over your shoulder.
It hums when the sea is empty. It leans in when the birds work. When the reel screams, it hits with you. It plays
the fish's moves as they happen: running, sounding, circling, coming up on the leader. Over a line about to part it
drops to a heartbeat and one shaking note. When the fish is lost it stops dead. When the fish is landed it sings.

## What there is now (audio/music.gd, tools/music.py, tests/music_test)

- **The cues** are rendered by the Python synth into `music/*.ogg`: title (6/8 D), calm_1–4 (one-shot phrases),
  fish_on (4/4 B minor at 112 bpm, one loop), race_a/b/c (6/8 jig stems played through an `AudioStreamSynchronized`),
  countdown, and win/lose/tie.
- **The logic** polls the sea each frame and picks a bed: title, calm, race or quiet. It layers fish_on over calm
  whenever `rods.fighting()` is true. Every layer fades over fixed times (FADES). It ducks to 0.55 when the Radio or
  Voice bus peaks above -42 dB. `hush(3.5)` comes from rods.gd when a fish is lost. The countdown sting starts at
  whatever offset the countdown has reached.
- **What's good and stays:** the long calm silences, nothing ever cutting at full volume, the countdown landing on
  GO, the seamless loops (tails wrap round, filters run twice), the lo-fi warm master, and the loss hush.
- **What's missing:**
  1. **No musical clock.** Nothing is quantised, so fades start on any frame, off the beat.
  2. **The fight is one on/off loop.** It never hears the drag, the spool, the moves, the leader or the danger, so
     a fight at minute 4 sounds exactly like the first second.
  3. **No strike or landed moment**, and nothing for the harpoon.
  4. **The weather, night, dawn and harbour don't change the music at all.** A storm plays the same calm phrases.
  5. **Rivals has no music between the countdown and the card** apart from the race jig. Lead changes and the
     other boat hooking up are silent.
  6. **The duck misses the VoiceRadio bus** and is a flat level drop.
  7. **No underwater muffle** for swimming or boarding.

## Principles (the rules the system obeys)

1. **Silence is the default.** At sea the music is off more than it is on. It earns every entry.
2. **The music never tells you what you couldn't feel.** It reads only what the player can sense: the rod's bend,
   the reel, the spool, the line in the water, the fish's moves. That is `Fight.cues()` and the synced rod fields.
   It never reads the hook's hidden `hold` or the fish's `energy`. A good player can play by ear, and the music never
   gives anything away (show, don't tell).
3. **Every fight is stressful, whatever the weather.** Calm weather lowers the ambient music, never the fight floor.
   The fight always has a pulse.
4. **Nothing snaps.** Every change lands on the beat or the bar, or is a fade of at least one beat. There are two
   exceptions, and both come from a physical event: the strike (the music's downbeat is the hookup) and the loss
   (an 80 ms fade to nothing, which is too fast to read as a fade and slow enough not to click).
5. **The music reads and is never called.** It polls synced state and detects edges itself. Game code never has to
   remember to tell it something. That also makes it the same on every peer for free.
6. **Pixel style in sound:** 32 kHz, tape wow, a low-pass around 8 kHz, warm saturation, a small band. Lo-fi but
   real, never chiptune.

## Architecture

```
 game state (sea, rods, fish_hold, landing, schools, vs, crew)
        │  polled each frame, read-only
        ▼
 audio/music_state.gd   (RefCounted, pure: no nodes, no audio. Headless-testable)
        │  -> Snapshot { section, stem_targets{}, mood, events[] }
        ▼
 audio/music.gd  (the autoload "Music": the conductor)
        │  - the musical clock (bar/beat from the playing stream's own position)
        │  - transition queue: now / next beat / next bar / next 4-bar phrase / segment end
        │  - stem gain smoothing (attack/release/hold, entry gates)
        │  - stingers scheduled onto the grid
        │  - mix: duck, voice pocket, muffle, pause
        ▼
 AudioStreamPlayer "Bed"  -> AudioStreamInteractive (one clip per section)
                               each clip = AudioStreamSynchronized (its stems)
 AudioStreamPlayer "Sting" (+ "Sting2" for overlaps)
 AudioStreamPlayer "Phrase" (the one-shot ambient phrases, as now)
        ▼
 Music bus: [EQ "pocket"] -> [LowPass "muffle"] -> [Limiter]
```

### Why `AudioStreamInteractive` + `AudioStreamSynchronized`

Godot (4.3+, so 4.7.2) has both built in, and they run on the **mixer thread**, so they are sample-accurate:

- **`AudioStreamSynchronized`** plays up to 32 streams locked to the sample, each with its own live volume. These
  are the vertical layers. The race home already uses one, so this is proven in this project.
- **`AudioStreamInteractive`** holds clips (the sections) and a transition table. Each transition says when to leave
  (immediately, next beat, next bar, or end of clip), how to fade (in, out, cross, or none) over N beats, whether to
  restart or sync position, and optionally a filler clip in between. That covers horizontal re-sequencing, and the
  filler clips give **sample-accurate transition stingers** (fight → `landed_hit` → afterglow).
- The beat grid comes from each Ogg stream's `bpm`, `beat_count` and `bar_beats`. music.gd sets these at load from
  the manifest (below), so they never drift from what the synth wrote.

**Risk:** I haven't yet proven three things in this project: an Interactive clip that *is* a Synchronized stream,
live stem volumes on it, and the playback-position API. Step 0 is a short spike to prove them. **The fallback** if
any of it misbehaves is two crossfading `AudioStreamPlayer`s, each with a Synchronized stream, plus our own clock
from `get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()`. That
gives frame-accurate rather than sample-accurate transitions, which is still inside a 16 ms window.

### The musical clock

- `beat_now()`, `bar_now()`, `phrase_now()` and `to_next(grid)` come from the bed's playback position and the
  current section's tempo and meter.
- **Overlay stingers** (lead change, "their fish on", leader) can't be Interactive fillers because the bed keeps
  playing under them. They play on the Sting player at the next grid point. The game thread schedules them
  one frame early and starts them with `play(from = overshoot)`, so the error is under one mix block (about 10 ms).
  A test measures this.
- When nothing rhythmic is playing (ambient, silence), there is no grid and stingers play immediately.

### The manifest: one source of truth for timing

`tools/music.py` writes `music/cues.json` next to the Oggs:

```json
{"fight": {"bpm": 112, "meter": [4, 4], "bars": 32, "key": "Bm", "loop": true,
           "stems": ["bed", "pulse", "drive", "tension", "deep", "tune"],
           "sections": {"fresh": [0, 16], "tired": [16, 28], "leader": [28, 32]}},
 "strike": {"bpm": 112, "hit": 0.0, "length": 2.14},
 "countdown": {"hit": 10.0}}
```

music.gd reads it at load. The Python side asserts that every stem of a cue has an identical sample length. A Godot
test asserts that the manifest, the files and the stream lengths agree.

## Game state → music

### The sections (horizontal)

| Section | When (read from) | Music | Tempo / key |
|---|---|---|---|
| **title** | `title.busy()` | the existing 6/8 shanty | 66 dotted, D |
| **harbour** | `fish_hold.docked`, not title | a low, slow fish-shed loop (guitar plus a far concertina, 2 stems), quiet; the quay's gulls on top | 84, G |
| **drift** | at sea, nothing on | the existing one-shot phrase system, **by mood** (below), long silences | free |
| **hunt** | a school with birds working within view, or marks on the sonar, and no fish on | a muted bass ostinato plus ticking shaker, low and anticipatory. The first two bars of the fight's world | 112, Bm |
| **fight / fresh** | a fish on, his fresh moves (run, sound, dog, shake, jump, surge, charge) | 6 stems, vertical (below) | 112, Bm |
| **fight / tired** | his circle and spiral moves | the same stems, harmony turning toward D (hope), and the tune stem allowed | 112, Bm→D |
| **fight / leader** | `cues().leader` (line_out < LEADER) and `leader_up` | an 8-bar climax loop: everything, plus the tune doubled | 112, D |
| **gaff** | boatside (`r.alongside`), the harpoon in hand | the bed drops to heartbeat plus drone; a riser follows `landing.draw`; dead quiet while the harpoon flies | 112 |
| **afterglow** | landed (catch count up) | 8–16 bars of the hook theme resolving in D, then out to drift with a long silence | 112, D |
| **race home** | dusk, still out (as now) | the existing jig, 3 stems by time left, **plus your standing in Rivals** | 104 dotted, Dm |
| **rivals count** | `vs.count_end ≥ 0` | the existing countdown sting, the bed quiet | |
| **card** | results card up | the existing win/lose/tie stings, nothing else | |
| **shift** | the grocery-shift penalty (when built) | supermarket muzak: a comic, too-cheerful bossa on a cheap organ, with a **ducking "attention shoppers" pause** | 120, F |

Transitions between sections (the Interactive table):

| From → to | When | How |
|---|---|---|
| drift → hunt | next beat (drift has no grid, so immediately) | hunt fades in over 4 beats from nothing |
| hunt → fight | **next beat** (≤ 0.54 s) | the `strike` filler clip, then fight bar 1 |
| drift/harbour → fight | **immediately**: the strike is the downbeat | the `strike` filler, then fight bar 1 |
| fight/fresh ↔ tired | next bar, a 2-bar hold before going back | sync position, fade 1 beat |
| any fight → leader | next beat | the `leader` filler (2 beats: drum fill plus the "LEADER!" hit) |
| leader → gaff | next bar | fade 2 beats; sync |
| gaff → afterglow | next beat after the harpoon hits | the `landed_hit` filler |
| gaff → fight | the fish broke free, back to fighting | next bar, fade 1 beat |
| any fight → *lost* | immediately | an 80 ms fade to silence (the hush), then nothing for 6 s, then the sea alone; no drift phrase for ≥ 60 s |
| afterglow → drift | end of clip | drift's phrase timer starts at 45–90 s |
| any → race home | next bar (or immediately from drift) | crossfade 4 beats |
| any → title / card / countdown | immediately | fade 2 beats (the card and countdown stings carry their own entry) |

### The fight's stems (vertical layering)

There is one 32-bar loop, B minor at 112, rendered as six synced stems. Every stem plays all the time, and their
volumes move.

| Stem | What it is | Up when |
|---|---|---|
| **bed** | dark pad plus a low drone | always under a fight (the floor; never below 0.6) |
| **pulse** | the heartbeat kick plus the muted bass ostinato | always, except a **gap on slack line** (`cues().slack` while he shakes): the floor drops out of the music |
| **drive** | frame drum rolls plus sixteenth shakers | his fast moves: run, surge, charge (`cues().surging`, `paying` > 0, the reel screaming) |
| **tension** | ukulele tremolo on a dissonant note plus a high "line singing" harmonic | **danger** (below) |
| **deep** | a low bowed/reed drone moving down, sub swells | sounding and dogging deep (depth > 40 m, `move` in sound/dog) |
| **tune** | the fight theme (concertina, whistle doubling at the leader) | only in tired/leader, only entering on a 4-bar boundary |

**Danger** is one 0–1 number made only from what you can feel or see:

```
danger = max( smoothstep(0.55, 0.95, tension / line strength),     # the bend near breaking
              smoothstep(0.5, 0.9,  spool),                        # the backing showing, the arbor coming
              smoothstep(0.4, 0.9,  contact),                      # the line on the hull
              props / PROP_GRACE,                                  # under her with the props turning
              tangled ? 0.7 : 0 )
```

- **Danger ≥ 0.85, "about to part":** the music **holds its breath**. Drive, deep and tune fall to nothing over one
  beat. The bed thins to 0.3. Only the pulse and a single trembling high note remain, the tension stem at full. When
  the danger passes, the band comes back on the next bar. This is the most stressful moment in the game, so it is
  the barest.
- **Jump (`cues().airborne`):** everything drops to about 15% for as long as he's in the air, then back at full the
  moment he lands. No grid is needed, because it's a volume change and not a timing change.
- **Spool past half:** the drive stem stays up even through a sound, and the tension stem's note climbs (its stem
  has two pitches, crossfaded).
- **Calm weather doesn't lower any of this.** A storm adds rumble to the deep stem. Calm is where the music has to
  carry the dread.

Smoothing, so nothing flaps:

- each stem has an attack (0.25–1 beat) and a release (2–8 beats);
- a stem that came in **holds for at least 2 bars**;
- the melodic stems (tune) only **enter** on a 4-bar boundary, but can leave on any beat.

### Mood: the weather, night and dawn (drift and harbour)

These pick *which* phrases play and how often; they don't touch the fight floor.

| Mood | Read from | Drift phrases | Gap between |
|---|---|---|---|
| calm / sunny | `sea.condition` | the existing warm major phrases (calm_1–4) + 2 new | 30–75 s |
| fog | `condition == "fog"` | a far concertina drone, almost nothing else (the foghorn is the music) | 90–180 s |
| rain / heavy | | minor, lower; a muffled guitar under the rain | 45–100 s |
| storm | | **no melody**: only a low drone swell now and then (the storm is loud enough) | 120 s+ |
| night | `sea.night` / `fish_hold.daylight()` < 0.2 | sparse: high harmonics, a soft pad, a slow lap of the bass | 60–120 s |
| dawn | `day_fraction()` crossing the first light | **once a trip**: a "first light" phrase as the sun comes up | (once) |

The fight inherits a tint from the mood. Night swaps the shaker in the drive stem for a rim click, and a storm adds
thunder-low swells to the deep stem. That's 2 extra stems, picked up front, not crossfaded.

### Rivals

- **Countdown, card:** as now.
- **Out fishing:** the same as career. Your boat's fights only.
- **Their fish on** (`vs._hooked` up for the other team): a two-note low menace sting on the next beat, quiet,
  under whatever's playing. It plays once per hookup.
- **Lead change** (the leader in `vs.shown` pounds flips): a one-bar sting on the next bar. It is bright if you took
  the lead and sour if you lost it, with no more than one every 30 s.
- **Race home:** the existing time-left build, plus **trailing at under 90 s left** brings the urgency stem up early
  and adds a **"last chance" stem** (doubled drum). **Leading** keeps the tune stem up, which feels triumphant but
  not safe.
- **Spectator/ref:** follows the boat they're watching.

### Co-op and Rivals networking

Each peer computes the music locally from the **already-synced** state. No new RPCs.

- Fights: every peer has each rod's `hooked`, `alongside`, `line_out`, `strain`, `move`, `depth`, `stretch`,
  `wear` and `drag` (`_fight_state` / `_holder_state` in rods/rods.gd). The holder reads its own `Fight.cues()`
  directly, so it hears the music with zero lag. The music follows **the worst fight aboard your boat**: the
  highest danger, with ties broken by the most recent hookup.
- Discrete events (strike, loss, boatside, landed) are reliable RPCs everyone receives, and the state machine sees
  their edges.
- The peers' bar positions are **not** aligned with each other, and don't need to be. Nobody hears another machine's
  music (voice chat carries no music: it's on the Voice bus and the mic picks up the player, not the game). Only the
  *section* needs to agree, and it does because it comes from the same synced state.
- When the rod changes hands mid-fight, the music stays on the same fight and doesn't restart.

### The mix

- **The duck** (kept as a polled level so tests can read `duck()`): it adds **VoiceRadio** to `DUCK_BUSES` (which
  currently misses it) and sets the depth by who's speaking: radio (Dale) -5 dB, crew voice chat -3 dB, the fight's
  shouts -2 dB.
- **The voice pocket:** an EQ on the Music bus dips 1–3 kHz by up to -6 dB under voice, *instead* of dropping
  everything. The fight keeps its weight and the words come through. The duck depth halves when the pocket is in.
- **Underwater** (swimming, boarding from the water): a low-pass at 600 Hz on the Music bus, eased in and out over
  0.3 s.
- **Paused:** as now (0.4), plus a gentle 2.5 kHz low-pass.
- **A limiter** at the end of the Music bus so stacked stingers never clip.
- **Against the effects:** the reel scream and the strike sting share the frequency range. The strike sting is
  rendered with its weight in the low end (drum plus bass hit) and leaves 2–5 kHz to the reel.

### Silence (a summary of the rules)

- Drift: silent ≥ 60% of the time (the existing gaps, longer in fog, storm and night).
- After landed: 45–90 s before the first drift phrase.
- After lost: hard silence for 6 s, no drift phrase for ≥ 60 s. **No loss sting**: the silence is the sting.
- No new drift phrase starts while the radio or a voice is on.
- Storm: no melody at all.
- The line about to part: the barest music in the game (heartbeat plus one note).
- The fish in the air: near-silence until he lands.
- The harpoon in flight: silence until it hits or misses.
- The results card: only its sting.

## Content pipeline

### Option A: extend the Python synth (recommended to start)

This needs no downloads and is deterministic, and it already fits the lo-fi palette. The work:

- Restructure `tools/music.py` around a `Cue` spec (tempo, meter, bars, key, stems). Every stem is a separate
  `Track` of identical length, mastered with **the same** reverb, wow and saturation settings. Saturation is
  nonlinear, so stems are mastered separately and their sum is **checked against** a mastered full mix: they must
  agree within -30 dB, or the drive is lowered.
- **New instruments**, all sums of sines and noise like the rest:
  - a **bowed drone** (saw-ish partials, slow attack, formant low-pass, bow noise) for the deep stem;
  - a **low tom/war drum** (a bigger, lower frame drum) for drive;
  - a **line-singing harmonic** (a thin sine with a slow vibrato and a beating second partial);
  - a **reverse swell** and a **sub drop** for the strike and danger;
  - **stomp + clap**;
  - a **cheap organ** for the grocery muzak.
- `write_manifest()` writes `music/cues.json`.
- Rendering grows from about 1 minute to about 3–4. The music folder grows by about 3–4 MB (32 kHz Vorbis q0.62,
  about 450 KB per 30-second stereo stem). About 40 new stems and stingers in all.
- **Limits of A:** bowed strings and anything vocal (gang "HEY"s) will sound synthetic. Plucks, drums, reeds,
  whistle and pads are already convincing.

### Option B: CC0 samples played by the same Python sequencer

Keep the composition in code and swap the weakest synth voices (fiddle, cello, big drums) for real samples. The
candidate is **VCSL, the Versilian Community Sample Library** (CC0, on GitHub, roughly 1–2 GB in full; only a few
instruments would be taken, a few tens of MB). **I haven't downloaded anything.** I'd ask first with the exact file
names and sizes. Licence notes would go in `docs/CREDITS…`.

### Option C: Kortev composes or records

If you'd rather write or play it yourself (FL Studio or anything else), the manifest is the contract: export each
section as stems of identical length at the given tempo, with a loop point on the bar. The game picks them up with no
code change. The synth stays as the placeholder until then.

## Implementation plan

Each step is a commit, tested, and pushed once approved.

| # | Step | Files | Proved by |
|---|---|---|---|
| 0 | **Spike:** Interactive with Synchronized clips, live stem volume, bar-quantised switch, filler clip, movie-maker audio capture works | scratch scene only | a throwaway test; decides native vs fallback |
| 1 | **Synth restructure + manifest**; re-render the existing cues the same way (one-shot wrap, stems of equal length) | tools/music.py, music/cues.json | the Python asserts (stem lengths, loop seam, peak, no DC) |
| 2 | **MusicState**: a pure snapshot from game state, edge events, danger, mood | audio/music_state.gd | `tests/music_state_test`: a table of states → expected section and stems, with no audio at all |
| 3 | **Conductor**: the clock, the Interactive bed, the transition table, smoothing, stingers | audio/music.gd | `tests/music_test` extended: transitions land on the grid, stems hold ≥ 2 bars, the old checks still pass |
| 4 | **Fight content**: 6 stems × 32 bars, strike, leader, landed_hit, gaff riser, night/storm variants | tools/music.py | render check plus fight sim (below) |
| 5 | **Drift moods + hunt + harbour + dawn** | tools/music.py, music_state | music_state_test cases per weather |
| 6 | **Rivals**: their-fish-on, lead change, race by standing | music_state, music.gd | vs cases in music_test |
| 7 | **Mix**: VoiceRadio duck, voice pocket EQ, underwater muffle, limiter | music.gd (bus effects set up in code, as radio.gd does) | music_test: the duck and pocket levels |
| 8 | **The render test** (below) and a tuning pass in a real playtest | tests/music_render.tscn, tools/music_check.py | the checks below |

**Touch points outside audio/** are read-only accessors only, each a few lines:

- `schools.birds_near(at, r)`;
- `landing.drawing()` / `landing.flying()`;
- `vs.leader_team()`;
- `crew.underwater()`;
- and rods.gd's existing `music.call("hush")` removed, because the state machine detects the loss itself.

These are the only edits to files the other session may be touching, so they're kept tiny and go in last.

### The tests that prove it

- **State → music, headless** (`tests/music_state_test`): around 40 table cases, for example:
  - a fresh runner at 0.6 tension → fresh, with pulse and drive up and tension low;
  - tension 0.92 → bed thinned, drive/deep/tune at 0, tension at full;
  - airborne → everything at 0.15;
  - slack while shaking → pulse gap;
  - a storm with no fish → drift with no melody;
  - the other boat hooking up → one `their_on` event;
  - and a check that **hook `hold` never changes the output** (fairness).
- **Fight sim tie-in:** run `tests/fight_sim`'s bots through 20 fights per nature and log the music state each frame.
  It asserts that:
  - every fight reaches drive ≥ 0.8 at least twice, *in calm weather too* (stressful every time);
  - the about-to-part state only shows when tension/strength > 0.85;
  - no stem changes direction more than once per 2 bars (no flapping);
  - the tired/leader sections only come after the fish has tired.
- **Sync and grid, in the real mixer** (`tests/music_render.tscn` under `--write-movie`, as tools/promo.sh does):
  a scripted scenario (drift → hunt → strike → run → sound → about to part → spiral → leader → gaff → landed; a
  second one ends lost) renders the Music bus to a WAV. `tools/music_check.py` then checks:
  1. **Transitions land on the grid:** onset detection at each scripted transition, within ±10 ms of a bar or beat
     line.
  2. **Stems stay in sync:** each stem rendered solo in a second pass is cross-correlated against the full render,
     and the lag must be 0 samples.
  3. **No clicks:** no sample-to-sample jump > 0.1 at any transition, loop seam or stinger start/end, and no
     broadband energy spike over 3.5× the local median within 20 ms of any event.
  4. **The loss is silent:** RMS < -60 dBFS for 6 s after the loss.
  5. **The overall level:** integrated loudness per section within its target (drift -26 LUFS, fight -18,
     leader -15, stings ≤ -12 peak).
- **The Python side:** loop seams (the end-to-start jump is under 1.5× the median jump), equal stem lengths, the
  sum-of-stems vs full mix within -30 dB.
- **The existing `music_test`** keeps passing, updated for the new names.

### Cost

| Step | Size |
|---|---|
| 0 spike | small (a short session) |
| 1 synth + manifest | medium |
| 2 MusicState + tests | medium |
| 3 conductor | medium–large (the heart of it) |
| 4 fight content | large (composition is the long pole) |
| 5 moods/hunt/harbour/dawn | medium |
| 6 Rivals | small–medium |
| 7 mix | small |
| 8 render test + tuning | medium |

In all it's about **6–9 focused sessions**. CPU cost in game: one Interactive player with up to 6 Vorbis decodes at
once during a fight, about the same as six looping sound effects (negligible next to the ocean). The repo grows
about 4 MB. Steps 1–3 can land with the *existing* music re-wired (no new content), so the system is proven before
any composition is spent.

## Open questions for Kortev

1. **Style.** (a) **Folk-noir**: the band you have, darker and heavier, with bodhrán war drums, a drone and a bowed
   line (recommended: it matches the title and the race). (b) **Cinematic hybrid**: big taiko-style drums and
   ostinato strings, more blockbuster, less "fish shed". (c) **Shanty-rock**: stomps, claps, driving strums, louder
   and rowdier.
2. **How intense.** At the about-to-part moment: (a) **strip to a heartbeat** (the dread version, recommended), or
   (b) **go all-in**, loudest at the worst moment.
3. **Synth vs samples.** (a) **Pure synth** (no downloads; strings and voices sound synthetic). (b) **Synth plus a
   few CC0 VCSL samples** for fiddle, cello and big drums. I'd list exact files and sizes before downloading.
   (c) **You compose or record** to the manifest spec.
4. **The loss.** Pure silence (recommended), or a soft low phrase after the silence for a big fish (> 200 kg)?
5. **The hunt layer.** Should birds working on the horizon bring music in at all? That is a hint, so it slightly
   bends "show, don't tell". The alternative is to only start the hunt layer once the lures are out and the school
   is close.
