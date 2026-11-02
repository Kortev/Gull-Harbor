shader_type spatial;
// Fishing line (rods/line_look.gd): thin monofilament. Drawn as one-pixel lines, which would be far too bold at a
// distance (a real line half a millimetre across is a fraction of a pixel past a few metres), so it fades with
// distance to a faint thread: clear up close (you see your line's angle into the water), a ghost out at the
// outrigger clip, all but gone at the baits fifty metres back. Light grey and blended, it shows as a pale thread
// on dark water and hardly at all against a bright sky, like the real thing. The vertex colour is its colour (the
// line's grey; pure white is the spray where it cuts the water, which shows further) and its alpha scales how much
// shows. Lit by whatever light there is from any side (a line's round: some of it always faces the light), so it
// doesn't glow in the dark: at night it shows only where the floods catch it.
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled;

// alpha right at the eye, how far (m) it stays that clear, and the least it fades to (a taut line catches the light)
uniform float near_alpha = 0.85;
uniform float clear_to = 3.0;
uniform float floor_alpha = 0.03;

void fragment() {
	float d = length(VERTEX);
	// (falling off faster than the line's apparent width alone: past a few metres a 1 px line is already far wider
	// than the real thing, so it has to thin out in brightness instead)
	float a = pow(clamp(clear_to / max(d, 0.01), 0.0, 1.0), 1.5);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	// (pure white is spray, not line: white water shows a long way further than the line that threw it)
	float spray = step(0.995, min(COLOR.r, min(COLOR.g, COLOR.b)));
	float line_a = max(a * near_alpha, floor_alpha);
	float spray_a = clamp(14.0 / max(d, 0.01), 0.3, 1.0);
	ALPHA = clamp(mix(line_a, spray_a, spray) * COLOR.a, 0.0, 1.0);
}

void light() {
	// (round: lit about as well from any side, by the sun, the floods, a lamp, as far as each reaches)
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.14;     // (LIGHT_COLOR has pi in it: about half lambert)
}
