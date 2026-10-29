shader_type sky;
// A planet's sky, PS1-style: a gradient seen through chunky cells of direction, a blocky sun, the
// sister planet (lit from the sun's side, so it shows a phase), stars that come out at night with a
// milky band, an aurora, drifting clouds and the weather far off (rain curtains, snow squalls,
// lightning in a dust storm). world/planets/planet.gd drives the uniforms as the night goes on.
// The radiance (ambient light) pass draws only the gradient and the sun's glow.

uniform vec3 sky_top : source_color = vec3(0.12, 0.3, 0.62);
uniform vec3 sky_horizon : source_color = vec3(0.8, 0.8, 0.7);
uniform vec3 ground_horizon : source_color = vec3(0.6, 0.6, 0.55);
uniform vec3 ground_bottom : source_color = vec3(0.18, 0.22, 0.16);
uniform float sky_curve = 0.12;
// Directions snap to cells this many per radian: the sky's "resolution".
uniform float pixels = 220.0;

// Toward the sun (also when it's below the horizon: it still lights the sister planet).
uniform vec3 sun_dir = vec3(0.0, 0.4, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float sun_energy = 1.0;
// Degrees (radius).
uniform float sun_size = 1.4;

uniform vec3 body_dir = vec3(0.0, 0.5, -1.0);
// Degrees (radius); 0 = no sister planet in this sky.
uniform float body_size = 0.0;
uniform vec3 body_color : source_color = vec3(0.8, 0.5, 0.3);

uniform float stars = 0.0;
uniform float milky = 0.0;
// The milky band is the great circle around this axis.
uniform vec3 milky_axis = vec3(0.35, 0.25, 0.9);
uniform float aurora = 0.0;
// Degrees: where the aurora hangs (0 = +Z, the ship's ramp side).
uniform float aurora_azimuth = 0.0;
uniform vec3 aurora_low : source_color = vec3(0.2, 1.0, 0.55);
uniform vec3 aurora_high : source_color = vec3(0.75, 0.3, 0.9);
// A storm front (Brine's dust storm): a wall of dust on the horizon, taller as it rolls in.
uniform float storm = 0.0;
// Degrees: where the storm comes from (0 = +Z).
uniform float storm_azimuth = -40.0;
uniform vec3 storm_color : source_color = vec3(0.62, 0.4, 0.26);

// Clouds: a flat layer overhead, seen in perspective, so they bunch up toward the horizon.
// cloud_noise: R big puffs, G finer detail, B vertical streaks (sky_noise.png).
uniform sampler2D cloud_noise : filter_nearest_mipmap, repeat_enable;
// 0..1: how much of the sky they cover.
uniform float clouds = 0.0;
// How far the wind has moved them (planet.gd adds to it every frame).
uniform vec2 cloud_drift = vec2(0.0);
// 0 = high fair-weather puffs, 1 = a low, heavy deck (bigger, darker underneath).
uniform float cloud_low = 0.0;
uniform vec3 cloud_tint : source_color = vec3(1.0);
// The weather far off: curtains hanging under the clouds near the horizon, here and there.
uniform float curtains = 0.0;
// Degrees: how high they reach.
uniform float curtain_top = 9.0;
// 0 = dark rain shafts, 1 = white snow squalls.
uniform float curtain_light = 0.0;
// 1 = streaky (rain), 0 = soft (snow).
uniform float curtain_streaks = 1.0;
// How fast the streaks fall, and how fast the curtains travel around the horizon (turns / s).
uniform float curtain_fall = 0.6;
uniform float curtain_sweep = 0.002;
// 0..1: the sky melts into the fog toward the horizon (Fathom: the sea has no visible end).
uniform float horizon_haze = 0.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 snap(vec3 d) {
	return normalize(floor(d * pixels) + 0.5);
}

vec3 gradient(vec3 d) {
	float v = acos(clamp(d.y, -1.0, 1.0));
	if (d.y >= 0.0) {
		float c = 1.0 - v / (PI * 0.5);
		return mix(sky_horizon, sky_top, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	}
	float c = (v - PI * 0.5) / (PI * 0.5);
	return mix(ground_horizon, ground_bottom, clamp(1.0 - pow(1.0 - c, 1.0 / 0.06), 0.0, 1.0));
}

void sky() {
	vec3 d = snap(EYEDIR);
	vec3 sd = normalize(sun_dir);
	vec3 col = gradient(d);
	if (AT_CUBEMAP_PASS) {
		col += sun_color * sun_energy * 0.12 * pow(max(dot(EYEDIR, sd), 0.0), 6.0);
		COLOR = col;
	} else {
		// Things in the sky sink into the haze at the horizon.
		float up = clamp(d.y * 10.0 + 0.1, 0.0, 1.0);
		if (stars > 0.001) {
			float band = milky * exp(-pow(dot(EYEDIR, normalize(milky_axis)) / 0.2, 2.0));
			float h = hash13(floor(EYEDIR * 380.0));
			if (h > 1.0 - 0.0028 * (1.0 + band * 7.0)) {
				float bright = 0.35 + 0.65 * fract(h * 91.7);
				float twinkle = 0.75 + 0.25 * sin(TIME * (1.5 + fract(h * 13.0) * 4.0) + h * 60.0);
				col += vec3(0.9, 0.95, 1.0) * bright * twinkle * stars * up * 1.8;
			}
			float lumps = 0.5 * hash13(floor(EYEDIR * 70.0)) + 0.3 * hash13(floor(EYEDIR * 140.0)) + 0.2;
			col += vec3(0.07, 0.07, 0.12) * band * stars * up * lumps;
		}
		if (aurora > 0.001 && d.y > 0.0) {
			// A ribbon hanging over the horizon: its foot wanders up and down and folds, its rays
			// are uneven and drift, and it's brighter in some stretches than others.
			float az = atan(d.x, d.z) - radians(aurora_azimuth);
			az = atan(sin(az), cos(az));
			float el = asin(d.y);
			float x = az * 2.2;
			float foot = radians(12.0) + radians(7.0) * (sin(x * 1.7 + TIME * 0.05) * 0.6 + sin(x * 4.1 - TIME * 0.08) * 0.4);
			float h = el - foot;
			float curtain = smoothstep(-0.004, 0.02, h) * exp(-max(h, 0.0) * 6.5);
			float ray_id = floor(x * 16.0 + sin(TIME * 0.07 + x * 3.0) * 1.5);
			float rays = 0.3 + 0.7 * hash13(vec3(ray_id, 7.0, 3.0)) * (0.7 + 0.3 * sin(TIME * 0.5 + ray_id));
			float stretch = 0.35 + 0.65 * smoothstep(0.25, 0.85, 0.5 + 0.5 * sin(x * 0.8 + TIME * 0.03));
			float side = smoothstep(1.3, 0.35, abs(az));
			vec3 tint = mix(aurora_low, aurora_high, clamp(h * 2.5, 0.0, 1.0));
			col += tint * curtain * rays * stretch * side * aurora * 0.8;
		}
		if (body_size > 0.0) {
			vec3 bd = normalize(body_dir);
			float r = radians(body_size);
			if (acos(clamp(dot(d, bd), -1.0, 1.0)) < r) {
				vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), bd));
				vec3 upv = cross(bd, right);
				vec2 p = vec2(dot(d, right), dot(d, upv)) / sin(r);
				float z = sqrt(max(1.0 - dot(p, p), 0.0));
				vec3 n = normalize(right * p.x + upv * p.y - bd * z);
				float lit = clamp(dot(n, sd), 0.0, 1.0);
				float bands = 0.8 + 0.2 * sin(p.y * 9.0 + p.x * 2.0);
				vec3 body = body_color * (0.05 + 1.3 * lit) * bands;
				// In daylight the sky's own light washes it out to a pale ghost.
				float daylight = smoothstep(-0.1, 0.3, sd.y);
				body = mix(body, col + body_color * lit * 0.25, daylight * 0.7);
				col = mix(col, body, clamp(up * 2.0, 0.0, 1.0));
			}
		}
		float disc = step(acos(clamp(dot(d, sd), -1.0, 1.0)), radians(sun_size)) * step(-0.01, d.y);
		col = mix(col, sun_color * 6.0, disc * clamp(sun_energy, 0.0, 1.0));
		col += sun_color * sun_energy * 0.3 * pow(max(dot(EYEDIR, sd), 0.0), 24.0);
		// Cloud colors: the sky's own light plus the sun's (orange at sunset, gone at night, when
		// they're dark shapes against the stars), darker underneath.
		float sun_up = clamp(sun_energy, 0.0, 1.5) * smoothstep(-0.12, 0.08, sd.y);
		vec3 sky_light = mix(sky_horizon, sky_top, 0.35);
		vec3 lit = (sky_light * 0.75 + sun_color * sun_up * 0.45 + vec3(0.02, 0.025, 0.04)) * cloud_tint;
		vec3 shade = (sky_light * mix(0.62, 0.45, cloud_low) + sun_color * sun_up * 0.08) * cloud_tint;
		// a dust storm turns them into dust, the color of its wall
		float lum = dot(sky_horizon, vec3(0.299, 0.587, 0.114));
		float dust = clamp(storm * 1.4, 0.0, 1.0);
		lit = mix(lit, storm_color * (0.2 + lum) * 1.3 + sun_color * sun_up * 0.08, dust);
		shade = mix(shade, storm_color * (0.2 + lum) * 0.8, dust);
		if (clouds > 0.001 && d.y > 0.0) {
			// onto the layer: a low deck is closer, so its puffs look bigger
			float scale = mix(0.75, 0.42, cloud_low);
			float lift = d.y + 0.05;
			vec2 p = d.xz / lift * scale - cloud_drift;
			// texels per cell of sky: blur the far, squashed layer instead of letting it sparkle
			float lod = log2(max(scale / (lift * lift) / pixels * 128.0, 1.0));
			float n = textureLod(cloud_noise, p, lod).r * 0.7 + textureLod(cloud_noise, p * 3.1 + 0.37, lod + 1.6).g * 0.3;
			float th = mix(0.72, 0.28, clouds);
			float c = smoothstep(th, th + 0.04, n);
			// thicker = darker underneath, in a few flat steps
			float thick = floor(smoothstep(th, th + 0.24, n) * 3.0) / 3.0;
			vec3 cc = mix(lit, shade, thick);
			// a bright edge on the ones in front of the sun
			cc += sun_color * sun_up * 0.4 * pow(max(dot(EYEDIR, sd), 0.0), 8.0) * (1.0 - thick);
			// far off they run together into a band along the horizon
			float far = smoothstep(0.3, 0.02, d.y);
			c = mix(c, clamp(clouds * 1.1, 0.0, 1.0) * 0.9, far);
			cc = mix(cc, mix(lit, shade, 0.4), far);
			col = mix(col, cc, c);
		}
		if (curtains > 0.001 && d.y > -0.04) {
			// rain or snow hanging under the clouds far off, in a few places round the horizon
			float u = atan(d.x, d.z) / TAU + TIME * curtain_sweep;
			float el = asin(clamp(d.y, -1.0, 1.0));
			// (two lookups that repeat 2 and 3 times round: together they don't)
			float cover = 0.6 - 0.12 * curtains;
			float patches = textureLod(cloud_noise, vec2(u * 2.0, 0.21), 0.0).r * 0.6 + textureLod(cloud_noise, vec2(u * 3.0, 0.57), 0.0).g * 0.4;
			float where = smoothstep(cover, cover + 0.07, patches);
			float top = radians(curtain_top) * (0.7 + 0.6 * textureLod(cloud_noise, vec2(u * 5.0, 0.63), 0.0).g);
			float hang = (1.0 - smoothstep(top * 0.6, top, el)) * smoothstep(-0.04, 0.0, el);
			float streak = textureLod(cloud_noise, vec2(u * 6.0, el * 1.5 + TIME * curtain_fall), 0.0).b;
			float k = where * hang * mix(1.0, 0.45 + 0.9 * streak, curtain_streaks) * min(curtains * 2.0, 1.0);
			vec3 veil = mix(shade * 0.72, lit * 1.05, curtain_light);
			col = mix(col, veil, clamp(k, 0.0, 1.0) * 0.88);
		}
		if (storm > 0.001) {
			float az = atan(d.x, d.z) - radians(storm_azimuth);
			az = atan(sin(az), cos(az));
			float el = asin(clamp(d.y, -1.0, 1.0));
			float side = smoothstep(2.0, 1.0, abs(az));
			float lumps = 0.75 + 0.2 * sin(az * 7.0 + TIME * 0.04) + 0.08 * sin(az * 23.0 + 1.3) + 0.05 * sin(az * 41.0);
			float top = radians(3.0 + 30.0 * storm) * lumps * side;
			float wall = (1.0 - smoothstep(top * 0.75, top, el)) * side;
			vec3 wall_col = storm_color * (0.2 + lum) * (0.75 + 0.25 * smoothstep(top, 0.0, el));
			col = mix(col, wall_col, clamp(wall, 0.0, 1.0) * 0.92);
			// lightning deep in the dust: every few seconds a patch of the wall flickers
			float slot = floor(TIME * 0.45);
			float into = fract(TIME * 0.45) / 0.45;
			float start = hash13(vec3(slot, 1.7, 9.1)) * 1.6;
			if (hash13(vec3(slot, 5.3, 2.9)) > 0.3 && into > start && into < start + 0.55) {
				float f_az = (hash13(vec3(slot, 8.1, 4.2)) - 0.5) * 2.4;
				float f_el = top * (0.2 + 0.45 * hash13(vec3(slot, 2.2, 7.7)));
				float dist = length(vec2(az - f_az, (el - f_el) * 1.8));
				float flicker = step(0.4, hash13(vec3(floor(TIME * 16.0), slot, 3.3)));
				// the dust glows round it, brightest in the middle
				float glow = exp(-dist * dist / 0.01) * 0.7 + exp(-dist * dist / 0.0012);
				float flash = glow * flicker * smoothstep(0.25, 0.6, storm);
				vec3 bolt = mix(storm_color * 2.2, vec3(1.0, 0.92, 0.8), 0.35);
				col += bolt * flash * clamp(wall, 0.0, 1.0) * (0.45 + lum);
			}
		}
		if (horizon_haze > 0.001) {
			col = mix(col, ground_horizon, horizon_haze * (1.0 - smoothstep(0.0, 0.22, d.y)));
		}
		COLOR = col;
	}
}
