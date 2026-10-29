shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The whole-screen late PS1 / early PS2 look (world/screen/screen_look.gd drives it): reads the
// finished 3D frame, redraws it on a coarse grid of square pixels, crushes the colour to a few bits
// a channel with a 4x4 ordered dither, then optional CRT extras. No vertex snapping or wobble.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

// Low-res rows on screen (360 = 640x360 at 16:9). 0 = no pixelation.
uniform float target_height = 360.0;
// Whole screen pixels per low-res pixel, so every pixel is the same size (the row count drifts a
// little with the window size).
uniform bool snap_integer = true;
// Bits per colour channel (the PS1 drew 5: 15-bit colour). 8 = no crush.
uniform float color_bits = 5.0;
// Ordered dither, in colour steps: 0 = hard banding, 1 = the PS1's full stipple.
uniform float dither : hint_range(0.0, 1.5) = 0.6;
// 0 = each low-res pixel takes the colour at its centre (a true low-res render, crisp, shimmers);
// 1 = the average of its block (calmer, softer edges, thin text survives better).
uniform float average : hint_range(0.0, 1.0) = 1.0;
// Extras, off at 0.
uniform float softness : hint_range(0.0, 1.0) = 0.0;   // CRT: neighbours bleed sideways
uniform float scanlines : hint_range(0.0, 1.0) = 0.0;  // dark gaps between low-res rows
uniform float vignette : hint_range(0.0, 1.0) = 0.0;   // darker corners

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);


float block_size(vec2 screen_px) {
	if (target_height <= 0.0) {
		return 1.0;
	}
	float px = max(screen_px.y / target_height, 1.0);
	return snap_integer ? max(floor(px + 0.5), 1.0) : px;
}


// The crushed, dithered colour of one low-res pixel.
vec3 low_res(vec2 cell, float px, vec2 pixel_size) {
	vec2 centre = (cell + 0.5) * px;
	vec3 c = texture(screen_tex, centre * pixel_size).rgb;
	if (average > 0.0 && px >= 2.0) {
		float q = px * 0.25;
		vec3 avg = (texture(screen_tex, (centre + vec2(-q, -q)) * pixel_size).rgb
			+ texture(screen_tex, (centre + vec2(q, -q)) * pixel_size).rgb
			+ texture(screen_tex, (centre + vec2(-q, q)) * pixel_size).rgb
			+ texture(screen_tex, (centre + vec2(q, q)) * pixel_size).rgb) * 0.25;
		c = mix(c, avg, average);
	}
	if (color_bits < 8.0) {
		float levels = exp2(color_bits) - 1.0;
		ivec2 b = ivec2(mod(cell, 4.0));
		float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0 - 0.5;
		c = floor(clamp(c, 0.0, 1.0) * levels + 0.5 + threshold * dither) / levels;
	}
	return clamp(c, 0.0, 1.0);
}


void fragment() {
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	float px = block_size(screen_px);
	vec2 cell = floor(FRAGCOORD.xy / px);
	vec3 c = low_res(cell, px, SCREEN_PIXEL_SIZE);
	vec2 sub = fract(FRAGCOORD.xy / px) - 0.5;
	if (softness > 0.0) {
		vec3 side = low_res(cell + vec2(sub.x < 0.0 ? -1.0 : 1.0, 0.0), px, SCREEN_PIXEL_SIZE);
		c = mix(c, side, softness * abs(sub.x));
	}
	if (scanlines > 0.0) {
		c *= 1.0 - scanlines * 0.5 * (1.0 - cos(sub.y * 6.2831853)) * 0.5;
	}
	if (vignette > 0.0) {
		vec2 d = (FRAGCOORD.xy * SCREEN_PIXEL_SIZE - 0.5) * vec2(screen_px.x / screen_px.y, 1.0);
		c *= 1.0 - vignette * smoothstep(0.35, 1.0, length(d));
	}
	COLOR = vec4(c, 1.0);
}
