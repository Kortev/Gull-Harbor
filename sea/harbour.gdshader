shader_type spatial;
// The harbour up close (sea/harbour.gd): coloured by vertex, a flat facet per face, and on top of the colour the
// surface's own grain drawn in world space as whole pixels (PX a metre, square, never smoothed) so it sits with the
// pixel look: clapboard courses, cedar shingles, roof courses, deck planks, brick, concrete. Which one is UV.x (the
// KIND_ numbers in harbour.gd). Far off the pattern fades to its average rather than shimmering.
render_mode specular_schlick_ggx;

const float PX = 16.0;

varying vec3 wpos;
varying vec3 wnrm;
varying flat int kind;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	kind = int(UV.x + 0.5);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// how bright this pixel of the surface is (1 = the vertex colour as it is)
float grain(int k, vec3 p, vec3 n) {
	vec3 q = floor(p * PX);
	// (along a wall: x or z, whichever runs across this face)
	float u = abs(n.x) > abs(n.z) ? q.z : q.x;
	float y = q.y;
	if (k == 1) {
		// clapboard: a course every 4 px, the shadow under each lap, the lit lip above it
		float r = mod(y, 4.0);
		float c = floor(y / 4.0);
		return (r == 0.0 ? 0.74 : (r == 3.0 ? 1.06 : 1.0)) * (0.97 + 0.06 * hash(vec2(c, 3.0)));
	}
	if (k == 2) {
		// cedar shingles: 3 px courses, each shingle 2-4 px wide and its own grey-brown, a dark joint between
		float c = floor(y / 3.0);
		float off = floor(hash(vec2(c, 7.0)) * 4.0);
		float s = floor((u + off) / 3.0);
		float j = mod(u + off, 3.0);
		float tone = 0.86 + 0.24 * hash(vec2(s, c));
		return (mod(y, 3.0) == 0.0 ? 0.7 : 1.0) * (j == 0.0 ? 0.8 : 1.0) * tone;
	}
	if (k == 3) {
		// roof courses: a dark line every 3 px up the slope, staggered tabs, the odd lighter one
		float c = floor(y / 2.0);
		float off = mod(c, 2.0) * 3.0;
		float t = floor((u + off) / 6.0);
		float j = mod(u + off, 6.0);
		return (mod(y, 2.0) == 0.0 ? 0.78 : 1.0) * (j == 0.0 ? 0.85 : 1.0) * (0.9 + 0.18 * hash(vec2(t, c)));
	}
	if (k == 4) {
		// deck planks across the pier: one every 5 px of its length, a dark seam, each plank its own weathering,
		// the grain running along it
		float a = abs(n.y) > 0.5 ? q.z : y;
		float b = abs(n.y) > 0.5 ? q.x : u;
		float pl = floor(a / 5.0);
		float seam = mod(a, 5.0) == 0.0 ? 0.45 : 1.0;
		float tone = 0.82 + 0.3 * hash(vec2(pl, 1.0));
		float streak = 0.94 + 0.1 * hash(vec2(pl * 3.0 + mod(a, 5.0), floor(b / 5.0)));
		return seam * tone * streak;
	}
	if (k == 5) {
		// concrete: a speckle, a joint every 3 m
		float joint = (mod(q.x, 48.0) == 0.0 || mod(q.z, 48.0) == 0.0) && abs(n.y) > 0.5 ? 0.8 : 1.0;
		return joint * (0.94 + 0.1 * hash(q.xz + q.y * 0.37));
	}
	if (k == 6) {
		// timber: grain running up it, a split here and there
		float g = hash(vec2(u, floor(y / 6.0)));
		return 0.9 + 0.16 * hash(vec2(u, 2.0)) - (g > 0.93 ? 0.25 : 0.0);
	}
	if (k == 7) {
		// brick: 2 px courses, 4 px bricks, the bond stepping half a brick each course, pale mortar
		float c = floor(y / 2.0);
		float j = mod(u + mod(c, 2.0) * 2.0, 4.0);
		if (mod(y, 2.0) == 0.0 || j == 0.0) {
			return 1.35;
		}
		return 0.85 + 0.25 * hash(vec2(floor((u + mod(c, 2.0) * 2.0) / 4.0), c));
	}
	if (k == 8) {
		// tarmac: a dark speckle
		return 0.9 + 0.15 * hash(q.xz);
	}
	if (k == 9) {
		// louvres (shutters): a slat every 2 px
		return mod(y, 2.0) == 0.0 ? 0.72 : 1.05;
	}
	if (k == 10) {
		// rock: blotches
		return 0.85 + 0.25 * hash(floor(q.xz / 3.0) + floor(q.y / 3.0) * 1.7);
	}
	return 1.0;
}

void fragment() {
	float g = grain(kind, wpos, wnrm);
	// (once a pixel of the pattern is smaller than a screen pixel, it goes to its average: no crawling stripes)
	float foot = length(fwidth(wpos)) * PX;
	g = mix(g, 0.97, smoothstep(0.6, 1.4, foot));
	ALBEDO = COLOR.rgb * g;
	ROUGHNESS = 0.92;
	SPECULAR = 0.3;
}
