// A rain streak (or a gust's grey sheet of rain) for particles with align_y (their y along their velocity): a quad
// stretched along the way it's flying and turned to face the camera round that line, so rain blown sideways reads
// as slanted streaks (a fixed-y billboard keeps it upright). Lit, so it catches the lamps. sea_fx.gd, rig.gd.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;

// The streak's width and length (m) at particle scale 1.
uniform vec2 size = vec2(0.035, 1.0);
// Longer the faster it flies (a gust stretches them).
uniform float stretch = 1.0;
uniform vec3 color : source_color = vec3(0.75, 0.8, 0.86);
uniform float alpha = 0.32;
// a little light of its own, so it reads against a dark storm sky (turned down at night)
uniform float glow = 0.0;
// fades out this close to the eye (m): a streak across the lens reads as warp speed, not rain
uniform vec2 near = vec2(1.5, 5.0);

varying float fade;
// A soft sheet's texture (white for a plain streak).
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap;

void vertex() {
	vec3 along = MODEL_MATRIX[1].xyz;
	float scale = length(along);
	vec3 center = MODEL_MATRIX[3].xyz;
	// (a particle that's gone has a zero transform: leave it a dot)
	vec3 a = scale > 1e-5 ? along / scale : vec3(0.0, 1.0, 0.0);
	vec3 to_eye = CAMERA_POSITION_WORLD - center;
	fade = smoothstep(near.x, near.y, length(to_eye));
	vec3 side = cross(a, to_eye);
	side = length(side) > 1e-5 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	vec2 local = vec2(UV.x - 0.5, 0.5 - UV.y) * size * scale;
	VERTEX = center + side * local.x + a * local.y * stretch;
	NORMAL = normalize(to_eye);
}

void fragment() {
	// tapered at both ends, soft across
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float ends = sin(UV.y * PI);
	ALBEDO = color;
	EMISSION = color * glow;
	ALPHA = alpha * across * ends * fade * texture(tex, UV).a;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
	// lit from behind too: rain shows up against a lamp
	BACKLIGHT = color * 0.7;
}
