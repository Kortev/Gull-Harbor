// Fathom's moving fog (sea_fx.gd, a FogVolume over the whole world, on top of the planet's wall of depth fog): banks
// of it and torn cloud racing past downwind at the gale's speed, thicker in a gust, and a layer of spray hanging over
// the sea, deepest at the water (the landing sits in it), a clear pocket round your own eyes. Volumetric: the lamps light it round them and the
// lightning lights all of it. None inside the ship or in a skin round it (the hull mask: hull_mask.gd sets its
// uniforms).
shader_type fog;

#include "res://sea/hull_mask.gdshaderinc"

// seamless 3D noise (sea_fx.gd), the banks' shapes
uniform sampler3D churn : repeat_enable, filter_linear;
// none this close to the hull either (m): volumetric fog is worked out in slices about half a metre to a metre deep at
// the cabin's distances, and fog just past a wall would bleed onto it
uniform float hull_skin = 0.8;
// the fog's thickness between the banks and in them (extinction per m)
uniform float thin = 0.02;
uniform float thick = 0.12;
// how far the fog has blown downwind (world x, z, m) and the wind's way
uniform vec2 drift = vec2(0.0);
uniform vec2 wind = vec2(1.0, 0.0);
// the spray over the sea: the sea's mean level, how thick at the water, how high it reaches (m)
uniform float sea_y = -26.5;
uniform float spray = 0.0;
uniform float spray_height = 6.0;
// lit by the lamps and the lightning (albedo), and glowing with the planet's fog colour (the wall's: sea_fx.gd sets it
// each frame, brighter in a flash), so the banks are the wall's own tone and not darker smears in front of it
uniform vec3 albedo : source_color = vec3(0.35);
uniform vec3 tone : source_color = vec3(0.3, 0.32, 0.35);
// a pocket round your own eyes (sea_fx.gd sets both each frame from this machine's camera): none of it within
// pocket.x m, all of it past pocket.y, so the sea where your line goes still reads through the storm (Kevin,
// 2026-10-17: "you can BARELY see the ocean anymore at the bottom, where the player fishes")
uniform vec3 eye = vec3(0.0);
uniform vec2 pocket = vec2(-1.0, 0.0);

void fog() {
	vec3 p = WORLD_POSITION;
	float k = hull_skin;
	if (in_hull(p) || in_hull(p + vec3(k, 0.0, 0.0)) || in_hull(p - vec3(k, 0.0, 0.0)) || in_hull(p + vec3(0.0, 0.0, k))
			|| in_hull(p - vec3(0.0, 0.0, k)) || in_hull(p + vec3(0.0, k, 0.0)) || in_hull(p - vec3(0.0, k, 0.0))) {
		DENSITY = 0.0;
	} else {
		vec2 wd = normalize(wind);
		vec2 q = p.xz - drift;
		// along the wind, across it: the banks drawn out downwind
		vec2 r = vec2(dot(q, wd), dot(q, vec2(-wd.y, wd.x)));
		float big = texture(churn, vec3(r.x / 46.0, p.y / 17.0, r.y / 24.0)).r;
		float torn = texture(churn, vec3(r.x / 12.0, p.y / 6.0, r.y / 7.0) + 0.37).r;
		float banks = smoothstep(0.38, 0.78, big * 0.72 + torn * 0.42);
		float low = spray * exp(-max(p.y - sea_y, 0.0) / spray_height) * (0.45 + torn);
		DENSITY = (mix(thin, thick, banks) + low) * smoothstep(pocket.x, pocket.y, distance(p, eye));
		ALBEDO = albedo;
		EMISSION = tone;
	}
}
