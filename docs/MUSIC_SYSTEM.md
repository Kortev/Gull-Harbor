# Bluefin's adaptive music: the design

Status: **approved 2026-11-02, being built** with the recommended answers: folk-noir, strip to a heartbeat at the
about-to-part moment, pure synth, pure silence on a loss, and the hunt layer on birds you can see (they are on
screen anyway, so it tells you nothing the sea doesn't). Written 2026-11-02 against `claude/zealous-mendel-h2udij` at a416062.

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
