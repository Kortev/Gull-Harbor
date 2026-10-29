// A curtain of rain out in the fog (sea_fx.gd, Fathom's hurricane): a tall band of rain sweeping across the sea
// 20 to 45 m out, a particle quad stood up on the sea and turned round its upright to face the camera, leaning
// with the wind, its rain streaking down through it. Lit, so the lightning shows it up. Fades out as it nears
// you (the gale's streaks take over close in) and in and out over its life.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;

// The curtain's width and height (m) at particle scale 1; it stands on its particle's position minus half the height.
uniform vec2 size = vec2(16.0, 36.0);
uniform vec3 color : source_color = vec3(0.45, 0.49, 0.53);
uniform float alpha = 0.35;
uniform float glow = 0.0;
// fades out this close to the eye (m, across the sea)
uniform vec2 near = vec2(14.0, 24.0);
// the way the wind leans it (world x, z per m up)
uniform vec2 lean = vec2(0.0);
// how fast its streaks run down (m/s)
uniform float fall = 14.0;

varying float fade;
varying float seed;

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.1) * 43758.5453);
}

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = CAMERA_POSITION_WORLD - center;
	vec3 flat_eye = vec3(to_eye.x, 0.0, to_eye.z);
	flat_eye = length(flat_eye) > 1e-4 ? normalize(flat_eye) : vec3(0.0, 0.0, 1.0);
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), flat_eye));
	vec2 local = vec2(UV.x - 0.5, 0.5 - UV.y) * size * scale;
	float up = local.y + size.y * scale * 0.5;
	VERTEX = center + side * local.x + vec3(0.0, local.y, 0.0) + vec3(lean.x, 0.0, lean.y) * up;
	NORMAL = flat_eye;
	fade = smoothstep(near.x, near.y, length(to_eye.xz)) * sin(clamp(INSTANCE_CUSTOM.y, 0.0, 1.0) * PI);
	seed = float(INSTANCE_ID);
}

void fragment() {
	// soft both sides, in bands across it, fading up into the sky
	float across = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	float h = hash(seed);
	float bands = 0.55 + 0.45 * sin(UV.x * (5.0 + 4.0 * h) + h * 20.0);
	float top = smoothstep(0.0, 0.5, UV.y);
	// its streaks: columns of rain running down at a few speeds
	float x = UV.x * 36.0;
	float col = floor(x);
	float c = hash(col + seed * 17.0);
	float run = fract(UV.y * size.y / 5.0 - TIME * fall / 5.0 * (0.8 + 0.4 * c) + c * 9.0);
	float streak = smoothstep(0.4, 1.0, run) * (1.0 - abs(fract(x) * 2.0 - 1.0));
	ALBEDO = color;
	EMISSION = color * glow;
	ALPHA = clamp(alpha * across * bands * top * (0.7 + 0.5 * streak) * fade, 0.0, 1.0);
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
	BACKLIGHT = color * 0.6;
}
