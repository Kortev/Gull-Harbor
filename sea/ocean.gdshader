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
// the big Gerstner swells, the first big_count of `waves`: drawn on top of the FFT sea too
uniform int big_count = 0;
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

// The boat's wake, painted on the water (ocean.gd's add_wake: a trail of points she leaves, world x, z, the wave time
// she was there, how hard she was going 0..1): churned white right behind her, two arms of foam spreading out in a
// V at the Kelvin angle, both thinning and tearing up as they age. And splashes (add_splash: x, z, when, how big): a
// ring of foam opening out and a white patch where it went in.
uniform vec4 wake_pts[64];
uniform int wake_count = 0;
uniform vec4 splash_pts[8];
uniform float wake_life = 26.0;
uniform vec3 wake_bound = vec3(0.0, 0.0, -1.0);    // (x, z, radius: nothing of it further out than that)

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
	vec2 k = vec2(mix(0.85, 1.0, smoothstep(0.0, 300.0, d)), mix(0.8, 1.0, smoothstep(0.0, 150.0, d)));
	vec2 e = (p - vec2(0.0, 2170.0)) / vec2(300.0, 150.0);
	float inside = 1.0 - smoothstep(0.75, 1.05, length(e));
	return mix(k, vec2(0.2, 0.45), inside);
}

// The surf (ocean.gd's _surf_at, the same): along the open coast the swell feels the bottom and comes in as lines of
// waves rolling toward the shore, growing and steepening over the last few hundred metres, breaking in sections,
// gone at the water's edge in a wash of foam. Not in the harbour. Returns how far the water's moved (x, y, z) and,
// in w, its phase (cos: 1 on a crest).
uniform float surf_height = 1.0;
const float SURF_K = 6.28318 / 34.0;
const float SURF_Q = 2.5;

float surf_env(vec2 p) {
	float d = shore_z(p.x) - p.y;
	vec2 e = (p - vec2(0.0, 2170.0)) / vec2(300.0, 150.0);
	float outside = smoothstep(0.85, 1.25, length(e));
	// (the sets along the shore: it breaks in sections, bigger here, smaller there)
	float sect = 0.45 + 1.1 * textureLod(swirl, vec2(p.x / 420.0 + 0.17, 0.61), 0.0).g;
	return smoothstep(420.0, 90.0, d) * smoothstep(-1.0, 14.0, d) * outside * sect;
}

// Two trains of surf, never quite in step: the long one, and a shorter one coming in at a slant. Each arrives in
// sets (bigger for a minute or so, then a lull), and the sets run along the shore, so no two stretches match.
const float SURF_K2 = 6.28318 / 23.0;

float surf_set(vec2 p, float t, float period, float salt) {
	return 0.5 + 0.5 * sin(t * 6.28318 / period + p.x / 520.0 + salt);
}

float surf_phase(vec2 p, float t) {
	float d = shore_z(p.x) - p.y;
	return SURF_K * d + sqrt(9.81 * SURF_K) * 0.85 * t + sin(p.x / 160.0) * 2.2;
}

float surf_phase2(vec2 p, float t) {
	float d = shore_z(p.x) - p.y;
	return SURF_K2 * (d + p.x * 0.2) + sqrt(9.81 * SURF_K2) * 0.85 * t + sin(p.x / 97.0 + 1.3) * 1.6;
}

vec4 surf_at(vec2 p, float t) {
	float a = surf_height * surf_env(p);
	float a1 = a * (0.35 + 0.65 * surf_set(p, t, 70.0, 0.0));
	float a2 = a * 0.55 * (0.3 + 0.7 * surf_set(p, t, 47.0, 2.1));
	float th = surf_phase(p, t);
	float th2 = surf_phase2(p, t);
	// (w: how near the top of the surf it is, both trains together: it breaks only where their crests stack up, so
	// the white comes in ragged sections that never repeat, not lines)
	float y = a1 * cos(th) + a2 * cos(th2);
	return vec4(0.0, y, SURF_Q * (a1 * sin(th) + a2 * 0.6 * sin(th2)), y / max(a * 0.95, 0.001));
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
	// how hard the water's being squeezed sideways here (along x, along z): past -1 the surface would cross itself
	float dxx = 0.0;
	float dzz = 0.0;
	vec2 sh = shelter_at(wq);
	float g = group_at(wq) * sh.y;
	float sw = swell_at(wq) * sh.x;
	if (fft_on) {
		vec3 tg = tile_gain(wq);
		vec4 a0 = textureLod(fft_a0, tile_uv(wq, fft_size.x), 0.0);
		vec4 a1 = textureLod(fft_a1, tile_uv(wq, fft_size.y), 0.0);
		vec4 a2 = textureLod(fft_a2, tile_uv(wq, fft_size.z), 0.0);
		d = tg.x * a0.xzy + tg.y * a1.xzy + tg.z * a2.xzy;
		vec4 b0 = textureLod(fft_b0, tile_uv(wq, fft_size.x), 0.0);
		vec4 b1 = textureLod(fft_b1, tile_uv(wq, fft_size.y), 0.0);
		vec4 b2 = textureLod(fft_b2, tile_uv(wq, fft_size.z), 0.0);
		dxx = tg.x * b0.y + tg.y * b1.y + tg.z * b2.y;
		dzz = tg.x * b0.z + tg.y * b1.z + tg.z * b2.z;
	}
	d += surf_at(wq, wave_time).xyz;
	for (int i = 0; i < 32; i++) {
		if (i >= wave_count || (fft_on && i >= big_count)) {
			break;
		}
		vec4 w = waves[i];
		vec4 b = waves_b[i];
		bool sl = i < swell_count;
		float a = w.w * (sl ? sw : g);
		float th = w.z * dot(w.xy, wq) - b.x * wave_time + b.y;
		d.xz += b.z * a * w.xy * cos(th);
		d.y += a * sin(th);
		float sq = b.z * a * w.z * sin(th);
		dxx -= sq * w.x * w.x;
		dzz -= sq * w.y * w.y;
	}
	// a crest folding over: pinched as far as it'll go but never through itself (it would show its underside, dark);
	// the breaking still shows, in the foam
	float fold = max(-dxx, -dzz);
	if (fold > 0.85) {
		d.xz *= 0.85 / fold;
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
		if (i >= wave_count || (fft_on && i >= big_count)) {
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
	// two layers of scrolling detail on top (normal maps, from the noise): fine ripples sliding over each other in
	// different directions at different speeds, close to only (far off they'd just sparkle)
	vec2 dp = mod(local.xz + origin_km, 1000.0);
	// (gone before a pixel covers more than a few cm: past that it only makes moire)
	float near_d = 1.0 - smoothstep(0.015, 0.08, max(abs(fwidth(q.x)), abs(fwidth(q.y))));
	if (near_d > 0.0) {
		vec2 s1 = vec2(wave_time * 0.011, wave_time * 0.006);
		vec2 s2 = vec2(-wave_time * 0.008, wave_time * 0.015);
		float e = 0.1;
		float h0 = texture(noise, dp * 0.23 + s1).g + 0.6 * texture(noise, dp * 0.52 + s2).b;
		float hx = texture(noise, (dp + vec2(e, 0.0)) * 0.23 + s1).g + 0.6 * texture(noise, (dp + vec2(e, 0.0)) * 0.52 + s2).b;
		float hz = texture(noise, (dp + vec2(0.0, e)) * 0.23 + s1).g + 0.6 * texture(noise, (dp + vec2(0.0, e)) * 0.52 + s2).b;
		slope += vec2(hx - h0, hz - h0) / e * 0.05 * (0.6 + g * 0.5) * near_d;
	}
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
		// (calm water breaks nowhere, only round what's in it: whitecaps come in with the wind)
		foam *= mix(0.55, 0.95, smoothstep(edge, edge + 0.5, crest)) * smoothstep(0.26, 0.5, whitecaps);
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
	// the surf: white along a breaking crest and spilling down its face, a trail of it behind, the wash at the edge
	float sd = shore_z(q.x) - q.y;
	float senv = surf_env(q);
	if (senv > 0.001) {
		float sth = acos(clamp(surf_at(q, wave_time).w, -1.0, 1.0));
		float breaking = smoothstep(260.0, 60.0, sd) * smoothstep(0.25, 0.8, senv);
		// (lace: the noise at two sizes tears it into ragged white, thickest right on the crest)
		float lace = grain * 0.6 + texture(noise, qk * 0.21).r * 0.4;
		// (and peeling: whole stretches of a crest break while the next stretch along doesn't, drifting with the swell)
		float peel = smoothstep(0.38, 0.62, texture(noise, q / 170.0 + vec2(wave_time * 0.004, 0.31)).g);
		float on_crest = smoothstep(0.76, 0.96, cos(sth) + (lace - 0.5) * 0.4) * peel;
		// (the white left behind: where the crest was breaking a second or so ago, torn up and thinning)
		float trail = smoothstep(0.7, 0.95, surf_at(q, wave_time - 1.3).w + (lace - 0.5) * 0.9)
				* smoothstep(0.35, 0.65, lace) * 0.7 * peel;
		foam = max(foam, (on_crest + trail) * breaking * (1.0 - far * 0.6));
	}
	// her wake: for each stretch of the trail, how far this point is from its line and across it
	if (wake_count > 1 && distance(q, wake_bound.xy) < wake_bound.z) {
		float wk = 0.0;
		float lace2 = texture(noise, qk * 0.31 + vec2(0.7, 0.2)).r;
		float lace3 = texture(noise, qk * 0.55 + vec2(0.1, 0.9)).g * 0.5 + texture(noise, qk * 0.19).r * 0.5;
		// the nearest point of her whole trail (not each stretch on its own: no gaps at the joins, no rings round them)
		float best = 1e9;
		float age = 0.0;
		float power = 0.0;
		bool at_end = false;
		for (int i = 0; i < 63; i++) {
			if (i + 1 >= wake_count) {
				break;
			}
			vec4 a = wake_pts[i];
			vec4 b = wake_pts[i + 1];
			vec2 ab = b.xy - a.xy;
			float len2 = max(dot(ab, ab), 0.0001);
			float u = clamp(dot(q - a.xy, ab) / len2, 0.0, 1.0);
			float dist = length(q - (a.xy + ab * u));
			if (dist < best) {
				best = dist;
				age = wave_time - mix(a.z, b.z, u);
				power = mix(a.w, b.w, u);
				at_end = (i + 2 >= wake_count && u > 0.999) || (i == 0 && u < 0.001);
			}
		}
		if (age >= 0.0 && age < wake_life && best < 4.0 + age * 1.6) {
			float fade = 1.0 - smoothstep(0.0, wake_life, age);
			// the churn: her beam wide, solid white for a few seconds, then lace, then gone
			float churn = (1.0 - smoothstep(0.8 + age * 0.08, 1.5 + age * 0.16, best)) * smoothstep(wake_life * 0.4, 0.0, age);
			// (solid only just behind her: from a couple of seconds it tears into lace, thinner and thinner)
			churn *= smoothstep(0.35 + 0.25 * smoothstep(2.0, 10.0, age), 0.62 + 0.25 * smoothstep(2.0, 10.0, age),
					lace3 + 0.5 * (1.0 - smoothstep(0.0, 2.5, age)));
			// the two arms of the V, out at the Kelvin angle (tan 19.5 deg of how far she's gone since): thin, broken
			float arm = 1.4 + age * max(power, 0.2) * 3.4;
			float arms = (1.0 - smoothstep(0.0, 0.35 + age * 0.04, abs(best - arm))) * smoothstep(0.4, 0.75, lace2)
					* smoothstep(0.0, 1.5, age) * (at_end ? 0.0 : 1.0);
			wk = (churn * 0.9 + arms * 0.55) * fade * clamp(power * 1.4, 0.0, 1.0);
		}
		foam = max(foam, wk * (1.0 - far * 0.7));
	}
	// splashes: a ring of foam opening out, a patch of white where it went in
	for (int i = 0; i < 8; i++) {
		vec4 s = splash_pts[i];
		float age = wave_time - s.z;
		if (s.w <= 0.0 || age < 0.0 || age > 7.0) {
			continue;
		}
		float dist = distance(q, s.xy);
		float r = s.w * (0.6 + age * 1.3);
		float ring = 1.0 - smoothstep(0.0, 0.35 + 0.12 * age * s.w, abs(dist - r));
		float patch_ = (1.0 - smoothstep(s.w * 0.4, s.w * (0.9 + age * 0.3), dist)) * (1.0 - smoothstep(0.5, 4.0, age));
		float life = 1.0 - smoothstep(1.5, 7.0, age);
		foam = max(foam, max(ring * 0.8, patch_) * life * smoothstep(0.3, 0.6, grain + 0.25));
	}
	float wash = smoothstep(16.0, 2.0, sd + (grain - 0.5) * 8.0 + sin(wave_time * 0.9 + q.x * 0.05) * 3.0);
	foam = max(foam, wash * 0.85 * smoothstep(-2.0, 1.0, sd));
	// the shallows: the bottom showing through, sandy green, over the last stretch to the shore
	col = mix(col, vec3(0.16, 0.42, 0.38), smoothstep(160.0, 15.0, sd) * smoothstep(-5.0, 5.0, sd) * 0.55);
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
	// (glossy enough for crisp sparkle: the sun's path broken into points by the ripples)
	ROUGHNESS = mix(0.035 + 0.08 * rough, 0.9, foam);
	SPECULAR = 0.6;
	// the sky in it at a grazing angle: only at a grazing angle (water's dark looking into it, not milky)
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 5.0);
	EMISSION = sky_color * fres * reflect * 0.35 * (1.0 - foam) * (1.2 - 0.6 * rough) * (1.0 - 0.45 * cloud);
	// the crests glowing where you look through them toward the light (strongest on the tall thin tops)
	vec3 to_light = normalize((VIEW_MATRIX * vec4(shade_from, 0.0)).xyz);
	float through = pow(clamp(dot(-VIEW, to_light) * 0.5 + 0.5, 0.0, 1.0), 3.0);
	// the wave peak mask (Sea of Thieves' way): where the water's squeezed up into a crest it's thin, so the light
	// comes through it, sub-surface teal, from any side, brightest looking toward the sun
	// (only the thin tops: the squeezed crest, high up, and most of all with the sun behind it)
	float peak = clamp(smoothstep(0.62, 0.95, h) * 0.5 + smoothstep(0.15, 0.8, crest) * 0.8, 0.0, 1.0);
	float thin = peak * (0.3 + 0.7 * pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 1.5));
	EMISSION += glass_color * glass * (0.15 + 0.85 * through) * thin * 1.4 * (1.0 - foam) * (1.0 - far * 0.5);
	// the sea going pale into the distance: the air between you and it, a gradient up to the horizon, where it meets
	// the sky in a blur instead of a ruled line (the sky's own colour at the horizon: sea.gd's set_sky_color)
	// (gentle and late: the water keeps its colour well out, greying only toward the horizon)
	float away = smoothstep(250.0, 2600.0, length(local.xz));
	ALBEDO *= 1.0 - 0.45 * away;
	EMISSION = mix(EMISSION, sky_color * 0.9, 0.55 * away);
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
