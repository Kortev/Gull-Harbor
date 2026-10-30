shader_type spatial;
// Fathom's ocean (world/planets/ocean.gd builds the mesh and sets the waves): a confused sea, two
// swells crossing with chop from all round on top, summed rolling waves (Gerstner: rounded troughs,
// sharp crests). Never tidy: rough patches drift through with the wind (the chop's height comes and
// goes), and a slow warp bends every crest line. On a polar grid that's fine near the rig and coarse
// out to the horizon, where the waves fade out and the sea curves away.
// PS1: a flat facet per triangle, chunky foam. Whitecaps on the crests, foam where the swell breaks
// round the rig's legs, dots where the rain hits, the sky on it at a grazing angle. ocean.gd works
// out the same waves in GDScript (height_at): keep the two in step.
render_mode specular_schlick_ggx, cull_disabled;

// Each wave: direction x, z; wavenumber k; amplitude. Then: angular speed; phase; steepness Q.
uniform vec4 waves[32];
uniform vec4 waves_b[32];
uniform int wave_count = 0;
// The first swell_count waves are the swell; the rest, the chop, come and go in patches.
uniform int swell_count = 5;
// The same noise as `noise`, smooth, for the patches and the warp (ocean.gd samples it the same way).
uniform sampler2D swirl : filter_linear, repeat_enable;
// How far the rough patches have drifted (uv); how far the swell's sets have travelled (ocean.gd's _sets_at).
uniform vec2 group_drift = vec2(0.0);
uniform vec2 sets_drift = vec2(0.0);
// Where the mesh's middle is over the world (x, z): the waves, the foam and the rain are the world's, so they stay put
// while the mesh moves along under the camera (ocean.gd's follow_camera). The fade and the curve stay the mesh's.
uniform vec2 origin = vec2(0.0);
// The same, wrapped every 1000 m (ocean.gd works it out in full precision): for the rain, the grain and the streaks,
// whose patterns repeat within that, so they stay crisp however far she's gone.
uniform vec2 origin_km = vec2(0.0);
uniform float wave_time = 0.0;
// The sum of Q k A over the waves: what a crest's breaking is measured against.
uniform float steep = 0.6;
// Out here the mesh is too coarse for waves: they fade, and the sea curves away like the planets.
uniform float fade_start = 900.0;
uniform float fade_end = 2200.0;
uniform float curve_start = 350.0;
uniform float curve_radius = 12000.0;
// The rig's legs (x, z, radius), where the swell breaks into foam.
uniform vec4 legs[8];
uniform int leg_count = 0;
// A sheltered patch where the sea is nearly still (the moon pool): x, z, half sizes.
uniform vec4 calm_rect = vec4(0.0);
// Crest to trough (m), for the colors; how much the crests break (0..1); how hard it rains.
uniform float swell = 4.0;
uniform float whitecaps = 0.3;
uniform float rain = 0.6;
// how much of the flat per-triangle facet look shows through the smooth shading (1: all facets)
uniform float facets : hint_range(0.0, 1.0) = 0.0;
// Where the wind blows (for the foam streaks a storm lays on the water).
uniform vec2 wind = vec2(0.8, 0.6);
// A hurricane tearing the crests into spray (ocean.gd, more in a gust): the streaks spread, the sea goes white.
uniform float spume = 0.0;
// a hurricane's sea (ocean.gd): white with foam, the crests breaking, streaked, smoking with spray
uniform float white = 0.0;
uniform vec3 deep_color : source_color = vec3(0.02, 0.09, 0.14);
uniform vec3 crest_color : source_color = vec3(0.07, 0.36, 0.4);
// light through the thin top of a crest (the stylized sea's glow: teal-green where the sun shines through a wave)
uniform vec3 glass_color : source_color = vec3(0.1, 0.62, 0.55);
uniform float glass = 0.55;
// A soft light from one side of the sky, so the wave facets read even under an even overcast.
uniform vec3 shade_from = vec3(0.5, 0.7, 0.3);
uniform float shade = 0.7;
uniform vec3 foam_color : source_color = vec3(0.9, 0.95, 0.96);
// The sky it shows at a grazing angle.
uniform vec3 sky_color : source_color = vec3(0.4, 0.45, 0.5);
uniform float reflect = 0.45;
// Something huge glowing under the water (the night's moment): x, z, size, strength; its heading.
uniform vec4 glow_spot = vec4(0.0);
uniform vec2 glow_heading = vec2(1.0, 0.0);
uniform vec3 glow_color : source_color = vec3(0.3, 0.95, 0.8);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
// the boat (ocean.gd's set_hull): her hull pushes the water down, so no crest ever comes up through her deck.
// hull_xf takes her space to this node's, hull_inv back; inside her the sea stays under hull_floor (her space)
uniform bool hull_on = false;
uniform mat4 hull_xf = mat4(1.0);
uniform mat4 hull_inv = mat4(1.0);
uniform float hull_floor = 0.35;
// her length (m) and how much beamier than 4.3 m she is (ocean.gd sets both from boat.gd)
uniform float hull_length = 14.0;
uniform float hull_beam = 1.1163;

// The FFT sea (sea/ocean_fft.gd): three tiles of the spectrum, each two textures (a: sideways x, z, height, slope x;
// b: slope z, the squeeze dDx/dx, dDz/dz, dDx/dz), each tile's size (m) and how high (its significant height, m).
// Off (no RenderingDevice): the rolling waves above, which are this same sea's biggest waves.
uniform bool fft_on = false;
uniform sampler2D fft_a0 : filter_linear, repeat_enable;
uniform sampler2D fft_a1 : filter_linear, repeat_enable;
uniform sampler2D fft_a2 : filter_linear, repeat_enable;
uniform sampler2D fft_b0 : filter_linear, repeat_enable;
uniform sampler2D fft_b1 : filter_linear, repeat_enable;
uniform sampler2D fft_b2 : filter_linear, repeat_enable;
uniform vec3 fft_size = vec3(1100.0, 233.0, 47.0);
uniform vec3 fft_gain = vec3(1.0);
uniform float fft_n = 256.0;
uniform float fft_crest = 1.3;

varying vec3 local;
varying vec3 moved;

float calm_at(vec2 p) {
	if (calm_rect.z <= 0.0) {
		return 1.0;
	}
	vec2 d = abs(p - calm_rect.xy) - calm_rect.zw;
	return mix(0.08, 1.0, smoothstep(-2.0, 1.0, max(d.x, d.y)));
}

// The coast (sea/landmarks.gd's shore_z, the same sum): where the water's edge is at world x.
float shore_z(float x) {
	float z = 1900.0 + 140.0 * sin(x / 1100.0 + 0.5) + 50.0 * sin(x / 370.0 + 2.0);
	z += 220.0 * exp(-(x * x) / (2.0 * 260.0 * 260.0));
	z -= 330.0 * exp(-((x - 1150.0) * (x - 1150.0)) / (2.0 * 240.0 * 240.0));
	return z;
}

// How much of the open sea gets here (x the swell, y the chop): all of it offshore; the swell dying away in the
// shallows over the last few hundred metres to the shore; next to nothing inside the harbour's breakwaters
// (ocean.gd's _shelter_at, the same).
vec2 shelter_at(vec2 p) {
	float d = shore_z(p.x) - p.y;
	vec2 k = vec2(mix(0.35, 1.0, smoothstep(20.0, 700.0, d)), mix(0.6, 1.0, smoothstep(0.0, 250.0, d)));
	vec2 e = (p - vec2(0.0, 2170.0)) / vec2(300.0, 150.0);
	float inside = 1.0 - smoothstep(0.75, 1.05, length(e));
	return mix(k, vec2(0.04, 0.2), inside);
}

// how rough the chop is here (patches drifting with the wind), how strong the swell, how bent
// (and wider stretches of rougher and smoother water, ocean.gd's STRETCH_SCALE)
float group_at(vec2 p) {
	return (0.35 + 1.3 * textureLod(swirl, p / 70.0 - group_drift, 0.0).r)
			* (0.45 + 1.1 * textureLod(swirl, p / 640.0 + vec2(0.53, 0.19) - group_drift * (70.0 / 640.0), 0.0).g);
}

// (the swell in sets: bands a few hundred m wide where it's bigger, travelling with the wind, ocean.gd's SETS_SCALE)
float swell_at(vec2 p) {
	return (0.85 + 0.3 * textureLod(swirl, p / 180.0 + vec2(0.31, 0.77), 0.0).g)
			* (0.3 + 1.4 * textureLod(swirl, p / 520.0 + vec2(0.71, 0.43) - sets_drift, 0.0).r);
}

float warp_at(vec2 p) {
	return (textureLod(swirl, p / 120.0 + vec2(0.37, 0.11), 0.0).r - 0.5) * 3.8;
}

// her half-beam at the rail, at z along her (art/boat.py's s_half: bow toward -z; boat.gd's LENGTH, and her beam
// as a scale of the 41 footer's 4.3 m)
float hull_half(float z) {
	float u = (hull_length * 0.5 - z) / hull_length;
	if (u < 0.0 || u > 1.0) {
		return -1.0;
	}
	if (u < 0.3) {
		return hull_beam * (1.98 + 0.17 * smoothstep(0.0, 0.3, u));
	}
	if (u < 0.55) {
		return hull_beam * 2.15;
	}
	float t = (u - 0.55) / 0.45;
	return hull_beam * (0.07 + 2.08 * pow(max(0.0, 1.0 - pow(t, 2.2)), 0.55));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// How much of each tile's sea is here: the swell's sets and the chop's rough patches, the shelter of the coast.
vec3 tile_gain(vec2 q) {
	vec2 sh = shelter_at(q);
	float g = group_at(q) * sh.y;
	return vec3(swell_at(q) * sh.x * fft_gain.x, g * fft_gain.y, g * fft_gain.z);
}

vec2 tile_uv(vec2 q, float size) {
	return q / size + 0.5 / fft_n;
}

void vertex() {
	vec3 p = VERTEX;
	local = p;
	float r = length(p.xz);
	vec2 wq = p.xz + origin;
	float k = (1.0 - smoothstep(fade_start, fade_end, r)) * calm_at(wq);
	vec3 d = vec3(0.0);
	vec2 sh = shelter_at(wq);
	float g = group_at(wq) * sh.y;
	float sw = swell_at(wq) * sh.x;
	if (fft_on) {
		vec3 tg = tile_gain(wq);
		vec4 a0 = textureLod(fft_a0, tile_uv(wq, fft_size.x), 0.0);
		vec4 a1 = textureLod(fft_a1, tile_uv(wq, fft_size.y), 0.0);
		vec4 a2 = textureLod(fft_a2, tile_uv(wq, fft_size.z), 0.0);
		d = tg.x * a0.xzy + tg.y * a1.xzy + tg.z * a2.xzy;
	}
	for (int i = 0; i < 32; i++) {
		if (i >= wave_count || fft_on) {
			break;
		}
		vec4 w = waves[i];
		vec4 b = waves_b[i];
		bool sl = i < swell_count;
		float a = w.w * (sl ? sw : g);
		float th = w.z * dot(w.xy, wq) - b.x * wave_time + b.y;
		d.xz += b.z * a * w.xy * cos(th);
		d.y += a * sin(th);
	}
	d *= k;
	VERTEX = p + d;
	if (hull_on) {
		// inside her bulwarks all the way down to hull_floor, easing off to nothing at her side and transom
		vec3 b = (hull_inv * vec4(VERTEX, 1.0)).xyz;
		if (b.y > hull_floor) {
			float hh = hull_half(b.z);
			float hl = hull_length * 0.5;
			float in_k = smoothstep(hh + 0.02, hh - 0.18, abs(b.x)) * smoothstep(hl + 0.15, hl - 0.1, b.z) * smoothstep(-hl - 0.15, -hl + 0.25, b.z);
			if (in_k > 0.0) {
				b.y = mix(b.y, hull_floor, in_k);
				VERTEX = (hull_xf * vec4(b, 1.0)).xyz;
			}
		}
	}
	moved = VERTEX;
	VERTEX.y -= pow(max(r - curve_start, 0.0), 2.0) / (2.0 * curve_radius);
}

void fragment() {
	// a flat facet per triangle
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	// the height and the breaking worked out here, per pixel, so the far coarse mesh doesn't show
	vec2 q = local.xz + origin;
	float k = (1.0 - smoothstep(fade_start, fade_end, length(local.xz))) * calm_at(q);
	float y = 0.0;
	float jac = 0.0;
	vec2 slope = vec2(0.0);
	vec2 sh = shelter_at(q);
	float g = group_at(q) * sh.y;
	float sw = swell_at(q) * sh.x;
	if (fft_on) {
		// every wave there is, per pixel: the height, the slope, and how squeezed the water is (1 - the Jacobian:
		// where it's squeezed to nothing the crest is breaking)
		vec3 tg = tile_gain(q);
		// (the small tiles fade out where a pixel covers more than they can show: no sparkle far off)
		float fw = length(fwidth(q));
		tg.z *= 1.0 - smoothstep(0.08, 0.5, fw);
		tg.y *= 1.0 - smoothstep(0.6, 3.0, fw);
		vec4 a0 = texture(fft_a0, tile_uv(q, fft_size.x));
		vec4 a1 = texture(fft_a1, tile_uv(q, fft_size.y));
		vec4 a2 = texture(fft_a2, tile_uv(q, fft_size.z));
		vec4 b0 = texture(fft_b0, tile_uv(q, fft_size.x));
		vec4 b1 = texture(fft_b1, tile_uv(q, fft_size.y));
		vec4 b2 = texture(fft_b2, tile_uv(q, fft_size.z));
		y = tg.x * a0.z + tg.y * a1.z + tg.z * a2.z;
		slope = vec2(tg.x * a0.w + tg.y * a1.w + tg.z * a2.w, tg.x * b0.x + tg.y * b1.x + tg.z * b2.x);
		// the chop's crests break (thin, lacy, where they're squeezed hardest); the swell's broad tops only help them
		float jxx = 1.0 + tg.y * b1.y + tg.z * b2.y;
		float jzz = 1.0 + tg.y * b1.z + tg.z * b2.z;
		float jxz = tg.y * b1.w + tg.z * b2.w;
		float swell_squeeze = -tg.x * (b0.y + b0.z);
		// (scaled to read like the rolling waves' crest measure: where the tiles' crests line up it goes past 1)
		jac = (1.0 - (jxx * jzz - jxz * jxz) + 0.45 * swell_squeeze) * fft_crest;
	}
	for (int i = 0; i < 32; i++) {
		if (i >= wave_count || fft_on) {
			break;
		}
		vec4 w = waves[i];
		vec4 b = waves_b[i];
		bool sl = i < swell_count;
		float a = w.w * (sl ? sw : g);
		float th = w.z * dot(w.xy, q) - b.x * wave_time + b.y;
		float s = sin(th);
		y += a * s;
		jac += b.z * w.z * a * s;
		slope += a * w.z * cos(th) * w.xy;
	}
	// the smooth surface's normal, blended with the flat facet: the PS1 facets stay, the sawtooth of long thin
	// triangles on a big swell in low sun goes
	vec3 smooth_n = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(-slope.x * k, 1.0, -slope.y * k, 0.0)).xyz);
	if (dot(smooth_n, VIEW) < 0.0) {
		smooth_n = -smooth_n;
	}
	n = normalize(mix(smooth_n, n, facets));
	NORMAL = n;
	float crest = jac * k / max(steep, 0.001);
	float h = clamp(y * k / max(swell, 0.5) + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color, crest_color, h);
	float lit = max(dot(n, normalize((VIEW_MATRIX * vec4(shade_from, 0.0)).xyz)), 0.0);
	col *= 1.0 - shade * 0.5 + shade * lit;
	// fine detail fades out far off, where it would only sparkle
	float far = smoothstep(0.08, 0.6, length(fwidth(q)));
	vec2 qk = mod(local.xz + origin_km, 1000.0);
	float grain = texture(noise, qk * 0.045 + vec2(wave_time * 0.01, 0.0)).g;
	// whitecaps on the crests
	float edge = 1.0 - 0.55 * whitecaps - 0.12 * spume - 0.2 * white;
	// (soft-edged, a little lacy: painted foam, not hard pixels)
	// (on the FFT sea, broken up more: lace, thick on the very crest and thinning down its face)
	float lace = fft_on ? 0.75 : 0.3;
	float foam = mix(smoothstep(edge - 0.06, edge + 0.06, crest + (grain - 0.5) * lace),
			smoothstep(edge - 0.1, edge + 0.2, crest) * 0.6, far) * step(0.01, whitecaps);
	if (fft_on) {
		foam *= mix(0.55, 0.95, smoothstep(edge, edge + 0.5, crest));
	}
	// in a blow, streaks of foam laid along the wind
	vec2 wd = normalize(wind);
	vec2 along = vec2(dot(qk, wd), dot(qk, vec2(-wd.y, wd.x)));
	float streak = texture(noise, vec2(along.y * 0.05, along.x * 0.008)).b;
	// (thin and soft: wide hard-edged ones read as zebra stripes down a big swell's face)
	float streaks = 0.08 * smoothstep(0.55, 1.0, whitecaps) + 0.08 * spume + 0.08 * white;
	foam = max(foam, smoothstep(1.0 - streaks, 1.0 - streaks * 0.4, streak * (0.6 + 0.6 * grain)) * 0.8 * (1.0 - far));
	// the spindrift: a white haze blown off the whole sea, thicker downwind of the crests
	foam = max(foam, (spume + 0.6 * white) * (0.16 + 0.3 * smoothstep(0.3, 0.9, crest)) * (0.6 + 0.8 * grain));
	// and a hurricane's: whole slopes downwind of the crests gone white, in drifting patches
	float patch = texture(noise, vec2(along.x * 0.004, along.y * 0.012) + vec2(wave_time * 0.006, 0.0)).r;
	foam = max(foam, white * smoothstep(0.35, 0.75, patch + h * 0.35) * smoothstep(0.15, 0.6, crest + grain * 0.4));
	// the swell breaking round the legs
	for (int i = 0; i < 8; i++) {
		if (i >= leg_count) {
			break;
		}
		float dl = distance(q, legs[i].xy) - legs[i].z;
		float ring = 1.0 - smoothstep(0.0, 1.5 + 2.5 * whitecaps + 0.15 * swell, dl);
		foam = max(foam, step(0.45, ring * (0.55 + 0.6 * grain) + h * 0.2));
	}
	// rain hitting the water: little rings that open and fade (one chance per 33 cm cell per drop slot)
	vec2 rq = qk * 3.0;
	vec2 cell = floor(rq);
	float phase = wave_time * 2.5 + hash(cell) * 7.0;
	float slot = floor(phase);
	float age = fract(phase);
	float hit = step(1.0 - 0.06 * rain, hash(cell + slot * 0.37));
	vec2 at = vec2(hash(cell + slot), hash(cell - slot)) * 0.5 + 0.25;
	float ring = 1.0 - smoothstep(0.0, 0.035, abs(length(fract(rq) - at) - (0.04 + age * 0.22)));
	float drop = hit * ring * (1.0 - age) * (1.0 - smoothstep(0.02, 0.06, length(fwidth(q))));
	// far out, where the waves are too small to see, the sea still isn't one even sheet: the shadows of the clouds
	// going over, and wind on the water (rougher stretches darker and duller, smooth ones shining with the sky).
	// Squashed thinner toward the horizon, they show how far it goes.
	// (clouds a km or so across, going over at 8 m/s; the noise repeats every 1500 m, so wrapped at 3000 for precision)
	float cloud = smoothstep(0.42, 0.7, texture(noise, mod(q, 3000.0) / 1500.0 - normalize(wind) * mod(wave_time * 8.0, 1500.0) / 1500.0).r);
	float rough = clamp((g - 0.35) / 1.4, 0.0, 1.0);
	col *= (1.0 - 0.38 * cloud) * (1.08 - 0.22 * rough);
	col = mix(col, mix(col, foam_color, 0.4), drop);
	col = mix(col, foam_color, foam);
	ALBEDO = col;
	// glossy water (the sun glints on it), matte foam
	ROUGHNESS = mix(0.08 + 0.12 * rough, 0.9, foam);
	SPECULAR = 0.5;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 4.0);
	EMISSION = sky_color * fres * reflect * (1.0 - foam) * (1.35 - 0.6 * rough) * (1.0 - 0.45 * cloud);
	// the crests glowing where you look through them toward the light (strongest on the tall thin tops)
	vec3 to_light = normalize((VIEW_MATRIX * vec4(shade_from, 0.0)).xyz);
	float through = pow(clamp(dot(-VIEW, to_light) * 0.5 + 0.5, 0.0, 1.0), 3.0);
	float thin = smoothstep(0.45, 1.0, h) * (0.4 + 0.6 * pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 1.5));
	EMISSION += glass_color * glass * through * thin * (1.0 - foam) * (1.0 - far * 0.5);
	// the sea going pale into the distance: the air between you and it, a gradient up to the horizon, where it meets
	// the sky in a blur instead of a ruled line (the sky's own colour at the horizon: sea.gd's set_sky_color)
	float away = smoothstep(20.0, 520.0, length(local.xz));
	ALBEDO *= 1.0 - 0.7 * away;
	EMISSION = mix(EMISSION, sky_color * 0.95, 0.75 * away);
	if (glow_spot.w > 0.001) {
		// long and slow, a body with a glow round it, under the waves
		vec2 dv = q - glow_spot.xy;
		vec2 hd = normalize(glow_heading);
		vec2 lc = vec2(dot(dv, hd), dot(dv, vec2(-hd.y, hd.x)));
		float body = 1.0 - smoothstep(0.3, 1.0, length(lc / vec2(glow_spot.z, glow_spot.z * 0.38)));
		float halo = 1.0 - smoothstep(0.0, 1.0, length(lc / vec2(glow_spot.z * 1.8, glow_spot.z * 1.1)));
		float pulse = 0.75 + 0.25 * sin(wave_time * 1.3 - lc.x * 0.15);
		EMISSION += glow_color * glow_spot.w * (body * 1.6 + halo * 0.35) * pulse * (0.7 + 0.5 * grain) * (1.0 - foam * 0.6);
	}
}
