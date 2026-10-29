# While you were away (newest first)

## The boat
- **What changed:** a normal 41 ft tuna boat for a crew of four, built by a Blender script (`art/boat.py`)
  with the space game's crunched photo textures (none of its decals or branding). It has:
  - a weathered white hull, a green boot stripe and red bottom paint;
  - a wheelhouse with a hardtop over the front of the cockpit, a helm with sonar and radar screens;
  - the open cockpit: fighting chair, 8 rod holders, a fish box, a live well, a cooler, buoys;
  - a tuna tower, outriggers and a radar;
  - floodlights and cockpit lights that come on at night, in fog and in storms.

  She never moves: she sits at the origin and heaves, pitches and rolls on the swell. The sea isn't drawn
  inside the hull, but big crests still tower over the rail.
- **How it was checked:** screenshots in `docs/shots/`:
  - `boat_sunny.png`
  - `boat_rain_night.png`
  - `boat_storm_night.png` (from the cockpit, with the floodlights on the rain)
  - `boat_cockpit_heavy.png`
- **Try it:** F5. For now the camera stands in the cockpit looking aft. Next: walking around on her.

## The fresh start: the sea
- **What changed:** a new, clean Godot project built only for the tuna game. The ocean, the storm (wind, rain,
  spray, lightning, the fog wall), the sky and the gritty PS1 screen look come straight from your space fishing
  game's Fathom. Six conditions: calm, sunny, fog, rain, heavy, storm, day or night.
- **How it was checked:** screenshots `docs/shots/sea_rain.png` and `docs/shots/sea_storm.png` (a 10 m swell
  over the camera in the storm).
- **Try it:** this lives on the `bluefin` branch of the Gull Harbor repo for now. Open the project folder in
  Godot, press F5. Next up: the boat and walking around on it.
