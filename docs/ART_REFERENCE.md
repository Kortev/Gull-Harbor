# Art reference: what the user wants it to look like

The user sent four Sea of Thieves images as the target look (2026-10-29). The images themselves stayed in the chat;
this is a close reading of each, so a session without them can work from it. The user's own words: cartoony but
slightly realistic, "similar to Sea of Thieves", detailed, "it needs to feel like there's life"; not low poly, not
square, no weird shaders. You can pick your own style, a little, inside that.

## 1. A pirate, full body (the character standard)

- **Silhouette and proportion:** lanky and tall, a long narrow head on a thick neck, broad rounded shoulders,
  a lean muscular torso, long arms ending in big, fully modelled hands (fingers, knuckles, a thumb wrapped round a
  blunderbuss). Long legs in a slightly bow-legged, weight-on-one-hip stance. Nothing is a box: every form is a
  smooth sculpted curve.
- **The face:** caricature. A long face, a heavy, low brow, a big long nose, sunken cheeks, a sneer showing teeth,
  small eyes under the brow, a scar across the forehead, a dark smear of war paint across the eyes. A spiky
  mohawk, hair as chunky painted clumps.
- **Painted surfaces that tell a story:** skin with soft painted shading (no photo detail), blue-black tattoos
  (skulls, crossbones, symbols) on chest and arms, red scars. Bandage wraps on the forearms, frayed. Dark trousers
  torn at the knee, the patch underneath showing. Brown leather boots, folded over at the top, with straps, buckles
  and rivets, scuffed lighter at the toes and edges.
- **Light and colour:** soft studio light from the front left, gentle shadow, a cool purple-grey in the shadows,
  warm skin; the palette slightly muted, browns and dusty purples, with the skin as the warm note.

## 2. The body-types sheet (variety is the point)

Ten figures side by side in plain underclothes: very fat, stocky, average, lanky, thin, muscular; men and women.
All share one face language (big noses, strong brows, characterful) and the same smooth, sculpted, slightly
caricatured anatomy: big hands, big feet, round bellies, skinny necks on the thin ones. Bandaged wrists, bare feet.
Lesson: **players should look different from each other**, comically so. For Bluefin: several body types and faces
in oilskins, each crew member's oilskins their own colour.

## 3. A ship at sea (the world standard)

- **Silhouette:** dramatic and readable from far off: a hull shaped like a dragon's jaw with teeth along the
  bow, tattered red sails cut into points, a tall flag streaming, a lantern burning at the masthead.
- **Detail:** rigging lines everywhere, carved wood, glowing fire inside the jaw (warm orange light spilling out),
  lanterns; the hull's dark wood picked out with lighter edges where it's worn.
- **The sea:** big rolling waves, turquoise and teal where the light comes through the crests, deep blue in the
  troughs, white foam lacing the crests and the bow wave; the water reads as translucent.
- **The sky:** bright saturated blue with big, soft, fluffy white clouds; strong sunlight.
- For Bluefin: our boats should have that readability (a distinct silhouette for each), lived-in detail (rope
  coils, rod holders full of rods, a cooler, buckets, a radio aerial, lights), and wear painted in.

## 4. A megalodon (the creature standard; the bluefin and birds follow it)

- **Silhouette:** chunky and exaggerated: a huge head, a heavy jaw open wide, oversized jagged teeth, small
  glowing yellow eyes, a thick body tapering to a big forked tail, fins with ragged edges.
- **Painted texture:** a dark navy-blue back fading to a pale blue-white belly (countershading), a pattern of
  painted scales, scratches and scars, darker speckles; a deep red mouth.
- For Bluefin: the bluefin itself should be a beautiful version of a real one (it's realistic where it counts):
  a deep metallic navy back fading to a silver belly, the yellow finlets, the crescent tail; painted, a little
  exaggerated in shape, with life in the eye. The birds the same way.

## 5. Sea of Thieves' fish (the fishing chart; a reference, but the bluefin is less cartoony)

The user sent the Sea of Thieves fishing chart and several of its fish (Splashtail, Devilfish, Wildsplash, and
others) on 2026-10-29, saying: "The fish shouldn't be this cartoony, but I think it's still a decent reference."

- **Form:** chunky, big-headed bodies. The heads are broad, heavy-jawed planes with thick pouty lips and an
  underbite. The bodies are smooth but have a few crisp, chiselled planes (a sculpted, carved feel, not low poly).
  They taper hard to a narrow tail stalk.
- **Fins:** ragged, cut into points and notches, with spines showing through. They're usually a contrasting
  colour (red or purple on grey, green or blue bodies) and slightly translucent at the edges.
- **Paint:** one strong body colour, with painted stripes, bars or blotches that follow the form. The back is
  darker and the belly paler. The lips and belly are lighter, and the paint is glossy with a soft sheen.
- **Eye:** small, round, dark and glossy, with a bright highlight. It is set high, under a heavy brow ridge that
  gives each fish a mood (grumpy, gormless).
- **For the bluefin:** keep its real shape and colours (a navy back, a silver belly, the yellow finlets, the
  crescent tail). Take from these the chunky sculpted head, the crisp planes over smooth forms, the painted
  stripes and sheen, the slightly ragged fins, and the life in the eye. Exaggerate it a little, not to the point
  of a cartoon.

## What "life" means here (the checklist)

1. **Exaggerated silhouettes and proportions:** big hands and feet, characterful faces, readable shapes.
2. **Smooth sculpted forms:** no boxes, no visible flat facets on organic things.
3. **Hand-painted textures that tell a story:** wear on edges, scratches, scars, tattoos, stitching, dirt,
   torn cloth; colour gradients (dark on top, light below).
4. **Lots of secondary detail:** straps, buckles, rope, lanterns, folds in cloth.
5. **Light:** saturated, warm, soft, a bit of glow (lanterns, fire, sun on the water), translucent teal water.
6. **Everything there has a use** (the user's Chekhov's gun rule, `docs/VISION.md`).

## How to get there (see docs/HANDOFF.md)

Procedural box modelling can't. Generate or source proper stylized models (Meshy, Tripo or Rodin from these
descriptions, a stylized asset pack, or an artist), clean them up in Blender, rig with Mixamo or Rigify, paint the
textures (Blender texture paint, ArmorPaint, Substance), and keep the node names and spots the code expects.

## What makes these characters good (research, 2026-10-29)

The user's verdict on the first attempts: the metaball crew was too cartoony and blobby, and the plain faceted one was
empty. They want Sea of Thieves' *craft*, a little less exaggerated than its pirates.

- **Angular planes on smooth, polished forms.** A Rare character artist describes the style as "angular, sharp
  edges on forms like the chest, arms and faces", with every form smooth and polished and no grunge or pore detail:
  "there's nowhere to hide with this sort of style"
  ([ZBrushCentral](https://www.zbrushcentral.com/t/sea-of-thieves-character-art/208371)). So: a planar cage,
  subdivided, with creases where planes meet (the jaw, the brow, the nose's bridge, the collarbones, a boot's sole).
- **A few simple rules, applied everywhere** (Rare's art director, GDC 2018,
  [GDC Vault](https://gdcvault.com/play/1025015/Visual-Adventures-on-Sea-of)).
- **Variety by generator.** Their Infinite Pirate Generator randomises body shape, face, age and "wonkiness"
  (asymmetry) from a few base bodies. For us: one well-built base, varied by body type, face and kit.
- **Silhouette first, then colour blocks, then detail** (a common rule:
  [RocketBrush](https://rocketbrush.com/blog/shape-language-in-game-character-design-how-to-make-characters-readable-and-consistent)).
  Exaggerate a few things (hands, feet, the face's length, the nose), keep the rest believable.
- **Paint the light into the texture** (most hand-painted workflows,
  [80.lv](https://80.lv/articles/ares-from-hades-recreated-in-stunning-hand-painted-3d)): soft value shifts that
  follow the forms, darker and cooler in the crevices, lighter on top edges, not noise.
