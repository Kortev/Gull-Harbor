// Rain on the visor (world/planets/visor_rain.gd): drops landing on the glass and drying off, and some running
// down it, each bending and blurring what's behind it like a little lens. Drawn over the 3D view, under the HUD.
// In the hurricane the runs blow across the glass (`slant`) and race (`flow_time`, faster in a gust), and in a gust
// the whole view shakes (`shake`, the whole screen drawn again, a little off).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// 0 dry .. 1 pouring
uniform float amount : hint_range(0.0, 1.5) = 1.0;
// how far a run drifts sideways per screen height it falls (+ = to the right)
uniform float slant = 0.0;
// the runs' clock (s): visor_rain.gd runs it faster in a gust (a rate uniform on TIME would jump)
uniform float flow_time = 0.0;
// the view's shake now (screen uv), and 1 while it's shaking (the whole screen drawn, not only the wet)
uniform vec2 shake = vec2(0.0);
uniform float shaking = 0.0;
// a sheet of water over the glass (spray, the sea: visor_rain.gd's `splash`), 0..1: it drains off top first
uniform float splash = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Drops landing in a grid of `cells` across the screen's height (`share` of the cells at full rain), each living a
// few seconds and drying off. xy: how far it bends the view, z: how much of the pixel is drop.
vec3 drops(vec2 uv, float cells, float seed, float share) {
	vec2 g = uv * cells;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float n = hash(id + seed);
	float life = 1.5 + n * 3.5;
	float clock = TIME / life + n;
	float epoch = floor(clock);
	float age = fract(clock);
	if (hash(id + epoch * 1.7 + seed) > amount * share) {
		return vec3(0.0);
	}
	vec2 c = (vec2(hash(id + epoch * 7.13), hash(id + epoch * 3.71 + 1.0)) - 0.5) * 0.6;
	float r = mix(0.1, 0.3, hash(id + epoch + seed * 3.1)) * (1.0 - age * 0.4);
	vec2 d = f - c;
	d.y *= 1.0 + d.y * 0.6;  // a little heavier at the bottom
	float m = smoothstep(r, r * 0.6, length(d)) * smoothstep(1.0, 0.7, age) * smoothstep(0.0, 0.03, age);
	return vec3(-d / cells * 1.6, m);
}

// Drops running down the glass in columns, wobbling, each with a thin wet trail above it.
vec3 runs(vec2 uv, float cols) {
	float x = uv.x * cols;
	float id = floor(x);
	float n = hash(vec2(id, 3.7));
	if (hash(vec2(id, floor(TIME * 0.2 + n) + 9.1)) > amount * 0.3) {
		return vec3(0.0);
	}
	float speed = 0.18 + n * 0.35;
	float head = fract(flow_time * speed + n) * 1.3 - 0.15;
	float wobble = sin(uv.y * 23.0 + n * 6.3) * 0.12 + sin(uv.y * 57.0 + n * 2.1) * 0.05;
	float fx = fract(x) - 0.5 - wobble;
	vec2 d = vec2(fx / cols, (uv.y - head) * 0.9);
	float rh = 0.32 / cols;
	float body = smoothstep(rh, rh * 0.6, length(d));
	float behind = head - uv.y;
	float trail = smoothstep(0.1, 0.03, abs(fx)) * step(0.0, behind) * smoothstep(0.25, 0.0, behind) * 0.6;
	return vec3(-d * 1.4 * body + vec2(-fx / cols * 0.4 * trail, 0.0), max(body, trail));
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = vec2(SCREEN_UV.x * aspect, SCREEN_UV.y);
	vec3 a = drops(uv, 9.0, 0.0, 0.18);
	vec3 b = drops(uv + 0.37, 19.0, 4.2, 0.22);
	vec3 r = runs(vec2(uv.x - uv.y * slant, uv.y), 13.0 * aspect);
	vec2 bend = a.xy * a.z + b.xy * b.z + r.xy;
	float wet = clamp(a.z + b.z + r.z, 0.0, 1.0);
	// the sheet: covering the glass below a ragged line that runs down it as it drains
	float sheet = 0.0;
	if (splash > 0.001) {
		float line = 1.0 - splash * 1.3 + sin(uv.x * 17.0 + flow_time * 3.0) * 0.04 + sin(uv.x * 43.0 - flow_time) * 0.02;
		sheet = smoothstep(line - 0.06, line + 0.1, SCREEN_UV.y) * min(splash * 2.0, 1.0);
	}
	if (wet < 0.01 && shaking < 0.5 && sheet < 0.01) {
		discard;
	}
	vec2 at = SCREEN_UV + shake + vec2(bend.x / aspect, bend.y);
	vec3 seen = textureLod(screen, at, 1.0).rgb;
	// a faint cold glint on the drop's top edge
	float glint = smoothstep(0.0, -0.01, bend.y) * wet * 0.05;
	if (shaking < 0.5 && sheet < 0.01) {
		COLOR = vec4(seen + glint, wet * 0.85);
	} else {
		vec3 shaken = textureLod(screen, SCREEN_UV + shake, 0.0).rgb;
		vec3 col = mix(shaken, seen + glint, wet * 0.85);
		if (sheet > 0.0) {
			// blurred and wavering behind the water, whitened with spray, in streaks running down
			vec2 wob = vec2(sin(SCREEN_UV.y * 31.0 + flow_time * 6.0 + SCREEN_UV.x * 9.0),
				sin(SCREEN_UV.x * 27.0 - flow_time * 4.0)) * 0.014;
			vec3 under = textureLod(screen, SCREEN_UV + shake + wob, 3.5).rgb;
			float streak = 0.5 + 0.5 * sin(uv.x * 140.0 + sin(SCREEN_UV.y * 7.0 + flow_time) * 3.0);
			vec3 water = mix(under, vec3(0.78, 0.82, 0.85), (0.3 + 0.25 * streak) * min(splash * 1.5, 1.0));
			col = mix(col, water, sheet);
		}
		COLOR = vec4(col, 1.0);
	}
}
