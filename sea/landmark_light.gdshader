shader_type spatial;
// A light on a landmark (sea/landmarks.gd): the lighthouse's lamp, the rig's flare and deck lights, the buoys' lights,
// the town's windows. A soft glowing dot that always faces you, kept a few pixels across however far off it is, dimmed
// by the haze (it carries further than the land does).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float visibility = 8000.0;
instance uniform vec4 tint = vec4(1.0, 0.85, 0.5, 1.0);
instance uniform float glow = 1.0;
instance uniform float far_mul = 1.0;
// m across up close
instance uniform float size = 1.0;

varying float fade;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(centre - CAMERA_POSITION_WORLD);
	// grows with distance so it stays a dot you can see, never smaller than ~0.15% of the way to it
	float s = max(size, d * 0.0035);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 w = centre + (right * VERTEX.x + up * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	fade = exp(-d * far_mul / (visibility * 2.5));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	ALBEDO = tint.rgb * a * glow * fade * 2.0;
}
