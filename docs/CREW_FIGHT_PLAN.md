# The whole boat in the fight: plan (2026-11-11). Nothing here is built.

Kortev liked the idea and asked for a small plan only, starting with bailing. He is on other projects; do not build
any of this until he says so.

## The one rule

During a fight, jobs turn up around the boat. Each one done makes the angler's game (docs/FIGHT_ARCADE.md) easier;
each one left makes it harder. One person can't do them all: solo is hard, two are busy, three or four cover
everything. The same rule for any crew, so nothing depends on how many are aboard.

Some realism may go for the sake of fun and of three or four playing together on one boat (his words).

## First piece: bailing

What exists (boat/green_water.gd, boat/kinds.gd, boat/helm.gd):
- Seas over the rail put water in her (`water`, 0..1). The skiff takes 0.08 a sea and her own pump clears 0.004 a
  second; the sportfisher 0.01 and 0.03. So the skiff fills in a blow and the sportfisher hardly does.
- Water aboard only makes her heavy and slow, and a note says "She's taking water".
- A hand pump already exists for the live well (boat/live_well.gd: hold E, the handle works up and down, each
  stroke gulps and gushes). The bilge pump can be the same kind of thing.

What to add:
1. **A hand bilge pump on deck** (the skiff first; his earlier decision was skiff only). Worked by hand, a stroke at
   a time, each stroke taking a visible gulp out of her and throwing it over the side. A second person bailing with
   the chum scoop or a bucket counts too, slower.
2. **Water you can see.** It stands on the deck and sloshes with her roll, deeper as `water` rises, so nobody needs
   the note to know. The scuppers already drain green water; this is what's left when they can't keep up.
3. **Water in her matters to the fight**, in three steps:
   - a little: nothing but the look and the sound;
   - ankle deep: she's slow to back down and to turn, so the skipper can't keep the stern on the fish as well, and
     the angler's footing goes (his timing windows a touch tighter);
   - near full: she wallows; a run can pull her stern under and put more in.
4. **The fish makes it worse on purpose.** A run with her stern to a sea, backing down hard, and a fish alongside
   thrashing all put water aboard, so there is bailing to do in calm weather too, not only in storms.
5. **Not a way to lose the boat.** Full of water she is at her worst, not sunk.

Open questions for him:
- The sportfisher too, or the skiff only as decided before? With three or four on the sportfisher there is no
  bailing job unless she gets one (a clogged scupper, a stuck pump to clear, were ideas).
- How much water should a calm-day fight put aboard: enough that someone always has to pump, or only when the
  skipper is rough with her?

Size: one agent, a couple of hours, mostly boat/green_water.gd, a new pump on the skiff's model, the deck water's
look, and a hook into tuna/fight_arcade.gd for the footing.

## The rest, in the order to build (each playable on its own)

1. **The skipper's half.** A cone off her stern: the fish inside it, the angler's bands and windows are wide;
   outside, they shrink and the line rubs. Each move asks something of the boat (chase a run, back down on a sound,
   gun it on a charge, hold the turn inside his circles). Rod and wheel both right is a crew perfect.
2. **Call it.** From the rail or the tower you see his tell a beat before the angler; the right shout gives the
   angler warning. Gives the spotter a job.
3. **The reel's heat.** Long runs heat the drag; water poured on it, or the bands narrow.
4. **The finish.** Leader, harpoon and tail rope as a chain of three timed jobs instead of hold E; fewer people, one
   runs between them and the window is tighter.
5. **Tension back as one gauge** that all of the above push up or down, so a long fight builds.

Also wanted before more is built: his own playtest of the arcade fight as it is (build 20), on Quick.
