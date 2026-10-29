# Lane B asset credits

All third-party sources are CC0 (public domain). Everything else in `assets/world/` was made for this
game: the models by Python scripts in `assets/world/blender/` and `assets/world/hangar/`, and the
signs, stencils, pixel font and patterns procedurally.

## Photo textures (Poly Haven, CC0, https://polyhaven.com/license)

Crunched to 64-256 px by `assets/world/blender/make_textures.py` into `assets/world/blender/textures/`.
Fetch the originals with `assets/world/blender/fetch_textures.sh`.

| Poly Haven asset | Used for |
| --- | --- |
| green_metal_rust | hull green, house white |
| rusty_painted_metal | red bottom paint |
| leather_white | boot stripe, the Falcon wall padding |
| metal_plate_02 | deck steel |
| metal_plate | cockpit and cabin floor plate |
| metal_grate_rusty | hold floor |
| blue_metal_plate | kick plates |
| painted_metal_shutter | ceilings |
| worn_corrugated_iron | hold walls |
| rust_coarse_01 | rusty metal |
| rusty_metal_04 | machinery |
| rusty_metal_03 | yellow rusty steel (gantry, landing gear) |
| rusty_corrugated_iron | funnel |
| rubber_tiles | rubber |
| fabric_leather_02 | booth and chair leather |
| container_side | downloaded, not used yet |

## Planets (`assets/world/planets/`)

Built by `assets/world/blender/planets/build.py`. Ground, grass, stone, pine, bark, snow, ice, salt,
planks, water, signs and the pad marking are painted procedurally. These Poly Haven photos (CC0,
authors below) are shrunk to 128 px and color-limited; the shrunk copies are in
`assets/world/blender/planets/photo/`.

| Poly Haven asset | Author | Used for |
| --- | --- | --- |
| rusty_painted_metal | Amal Kumar | trawler wreck hulls, their name boards |
| rust_coarse_01 | Dimitrios Savva, Rico Cilliers | wreck bottoms, barrels, Glimmer's sign |
| rusty_metal_04 | Amal Kumar | wreck gantries, masts, rails; Brine's sign |
| green_metal_rust | Rob Tuytel | wreck wheelhouses, the TR-0212 bow |
| rusty_corrugated_iron | Charlotte Baglioni | ice hut roofs |
| worn_corrugated_iron | Jenelle van Heerden, Dimitrios Savva | ice hut roofs |
| metal_plate | Rob Tuytel | posts, stovepipes, beacons |
| rusty_metal_03 | Amal Kumar | the ice crawler's rust |
| container_side | Dimitrios Savva | the containers on MAWCO PLENTY's deck |

## Hangar (`assets/world/hangar/`)

Built by `assets/world/hangar/build_hangar.py`. Walls, pipes, lamps, the neon sign, signs, posters,
decals, props and the station's outside are painted procedurally in the script; all lettering is the
pixel font from `assets/world/blender/psx.py`. The floor, kick plates, ceiling, ribs, hazard stripes,
grates, yellow steel, crates and rubber reuse the crunched Poly Haven textures in the first table.

## Crew (`assets/world/crew/`)

The Deckhand (`crew.glb`, the player's body, built by `assets/world/blender/crew/build_deckhand.py`) is painted over the
crunched Poly Haven textures in the first table (suit, boot_white, rubber, rust_metal, yellow_rust, house_white,
leather_brown); the wear, the stencils and the glow map are painted procedurally in the script.

## Collar death (`assets/world/textures/death/`)

`blood.png` (the blood on the glass when your bomb collar goes) is baked by `world/dev/bake_collar_blood.gd` from:

| Source | Author | License | Used for |
| --- | --- | --- | --- |
| "Bloody Background" (`deadCover.png`), opengameart.org | Opengameart.org | CC0 | the smears |
| Splat Pack (splat02, splat10, splat19, splat28), www.kenney.nl | Kenney | CC0 | the flecks |

## Sounds (`assets/world/sounds/bank/`)

Cut, levelled and made mono by `assets/world/sounds/build_sounds.py`; the source of every file is listed in
`docs/lane-b/sound-picks.md`.

| Source | Author | License | Used for |
| --- | --- | --- | --- |
| Interface Sounds, UI Audio, Digital Audio, RPG Audio, Impact Sounds, Music Jingles, www.kenney.nl | Kenney | CC0 | the menu clicks, ticks and chimes (`u_*`); the beeps and tones of the PA, the collars, Dock 07 and the kit |
| BigSoundBank, https://bigsoundbank.com (each sound's number is in `docs/lane-b/sound-picks.md`) | Joseph Sardin | CC0 | the CRT, the tray drops, the locker glass, the START horn; the ship, the trip, the PA, the collars, Dock 07, Glimmer, Brine, Fathom (`a_*`, `b_*`, `c_*`, `d_*`, `f_*`, `g_*`, `k_*`, `s_*`, `t_*`) |
| Made here: `assets/world/intro/build_holo_sounds.py` (synthesized, no samples) | this project | CC0 | the collar intro's hologram show: the projector, the jingle, the mascot's babble, the beeps, pop, rewind, ding and coins (`assets/world/intro/sounds/holo_*.wav`) |
