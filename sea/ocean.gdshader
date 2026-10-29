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
// How far the rough patches have drifted (uv).
uniform vec2 group_drift = vec2(0.0);
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
uniform float facets : hint_range(0.0, 1.0) = 0.15;
// Where the wind blows (for the foam streaks a storm lays on the water).
uniform vec2 wind = vec2(0.8, 0.6);
// A hurricane tearing the crests into spray (ocean.gd, more in a gust): the streaks spread, the sea goes white.
uniform float spume = 0.0;
// a hurricane's sea (ocean.gd): white with foam, the crests breaking, streaked, smoking with spray
uniform float white = 0.0;
uniform vec3 deep_color : source_color = vec3(0.04, 0.08, 0.1);
uniform vec3 crest_color : source_color = vec3(0.17, 0.26, 0.29);
// A soft light from one side of the sky, so the wave facets read even under an even overcast.
uniform vec3 shade_from = vec3(0.5, 0.7, 0.3);
uniform float shade = 0.7;
uniform vec3 foam_color : source_color = vec3(0.72, 0.78, 0.8);
// The sky it shows at a grazing angle.
uniform vec3 sky_color : source_color = vec3(0.4, 0.45, 0.5);
uniform float reflect = 0.45;
// Something huge glowing under the water (the night's moment): x, z, size, strength; its heading.
uniform vec4 glow_spot = vec4(0.0);
uniform vec2 glow_heading = vec2(1.0, 0.0);
uniform vec3 glow_color : source_color = vec3(0.3, 0.95, 0.8);
uniform sampler2D noise : filter_nearest_mipmap, repeat_enable;
// the boat (ocean.gd's set_hull): her hull pushes the water down, so no crest ever comes up through her deck.
// hull_xf takes her space to this node's, hull_inv back; inside her the sea stays under hull_floor (her space)
uniform bool hull_on = false;
uniform mat4 hull_xf = mat4(1.0);
uniform mat4 hull_inv = mat4(1.0);
uniform float hull_floor = 0.35;
// her length (m) and how much beamier than 4.3 m she is (ocean.gd sets both from boat.gd)
uniform float hull_length = 14.0;
uniform float hull_beam = 1.1163;

varying vec3 local;
varying vec3 moved;

float calm_at(vec2 p) {
	if (calm_rect.z <= 0.0) {
		return 1.0;
	}
	vec2 d = abs(p - calm_rect.xy) - calm_rect.zw;
	return mix(0.08, 1.0, smoothstep(-2.0, 1.0, max(d.x, d.y)));
}

// how rough the chop is here (patches drifting with the wind), how strong the swell, how bent
float group_at(vec2 p) {
	return 0.35 + 1.3 * textureLod(swirl, p / 70.0 - group_drift, 0.0).r;
}

float swell_at(vec2 p) {
	return 0.85 + 0.3 * textureLod(swirl, p / 180.0 + vec2(0.31, 0.77), 0.0).g;
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

void vertex() {
	vec3 p = VERTEX;
	local = p;
	float r = length(p.xz);
	float k = (1.0 - smoothstep(fade_start, fade_end, r)) * calm_at(p.xz);
	vec3 d = vec3(0.0);
	float g = group_at(p.xz);
	float sw = swell_at(p.xz);
	float wp = warp_at(p.xz);
	for (int i = 0; i < 32; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 w = waves[i];
		vec4 b = waves_b[i];
		bool sl = i < swell_count;
		float a = w.w * (sl ? sw : g);
		float th = w.z * dot(w.xy, p.xz) - b.x * wave_time + b.y + wp * (sl ? 1.0 : 0.5);
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
	vec2 q = local.xz;
	float k = (1.0 - smoothstep(fade_start, fade_end, length(q))) * calm_at(q);
	float y = 0.0;
	float jac = 0.0;
	vec2 slope = vec2(0.0);
	float g = group_at(q);
	float sw = swell_at(q);
	float wp = warp_at(q);
	for (int i = 0; i < 32; i++) {
		if (i >= wave_count) {
			break;
		}
		vec4 w = waves[i];
		vec4 b = waves_b[i];
		bool sl = i < swell_count;
		float a = w.w * (sl ? sw : g);
		float th = w.z * dot(w.xy, q) - b.x * wave_time + b.y + wp * (sl ? 1.0 : 0.5);
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
	float grain = texture(noise, q * 0.045 + vec2(wave_time * 0.01, 0.0)).g;
	// whitecaps on the crests
	float edge = 1.0 - 0.55 * whitecaps - 0.12 * spume - 0.2 * white;
	float foam = mix(step(edge, crest + (grain - 0.5) * 0.3), smoothstep(edge - 0.1, edge + 0.2, crest) * 0.6, far)
		* step(0.01, whitecaps);
	// in a blow, streaks of foam laid along the wind
	vec2 wd = normalize(wind);
	vec2 along = vec2(dot(q, wd), dot(q, vec2(-wd.y, wd.x)));
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
	vec2 rq = q * 3.0;
	vec2 cell = floor(rq);
	float phase = wave_time * 2.5 + hash(cell) * 7.0;
	float slot = floor(phase);
	float age = fract(phase);
	float hit = step(1.0 - 0.06 * rain, hash(cell + slot * 0.37));
	vec2 at = vec2(hash(cell + slot), hash(cell - slot)) * 0.5 + 0.25;
	float ring = 1.0 - smoothstep(0.0, 0.035, abs(length(fract(rq) - at) - (0.04 + age * 0.22)));
	float drop = hit * ring * (1.0 - age) * (1.0 - smoothstep(0.02, 0.06, length(fwidth(q))));
	col = mix(col, mix(col, foam_color, 0.4), drop);
	col = mix(col, foam_color, foam);
	ALBEDO = col;
	ROUGHNESS = mix(0.4, 0.95, foam);
	SPECULAR = 0.3;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 4.0);
	EMISSION = sky_color * fres * reflect * (1.0 - foam);
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
