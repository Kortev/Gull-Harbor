# Wicked Catch

A co-op tuna fishing game: you and up to three friends on one boat, endless open sea, sometimes huge waves,
catching as many bluefin as you can. Creepy only because of the sea and the weather; mostly action. Real tuna,
nothing supernatural.

Godot 4.7, GDScript. Run: open the project in Godot and press F5 (main scene `sea/sea.tscn`).

## Where things come from
The ocean (`sea/ocean.gd`, `sea/ocean.gdshader`), the weather effects (`sea/sea_fx.gd`, rain, fog, lightning,
`sea/visor_rain.gd`), the sky shader, the sound bank and the late-PS1 screen look (`screen/`) are taken from the
owner's other game (spacefishingconcept, Fathom's ocean). Its asset credits are in
`docs/CREDITS_from_space_fishing.md` (CC0 sources).

## Layout
- `sea/`: the ocean, sky, weather, and `sea.gd`, the main scene
- `boat/`: the tuna boat
- `crew/`: the first-person player
- `tuna/`: the fish and the fight
- `core/`: networking and settings
- `ui/`, `audio/`, `screen/`
