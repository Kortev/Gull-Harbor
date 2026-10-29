// How a tuna swims (thunniform): the body stays stiff and only the tail stalk and the crescent tail sweep from side
// to side, the head barely nodding against it. tuna.gd drives the per-fish numbers: swim_phase (radians, advanced
// with the tail beat), swim_amp (how wide the tail sweeps, in body lengths) and bend (a turn curving the body,
// + to the fish's right). The model is unit length: snout at z = -0.5, tail tips at +0.5.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform float roughness = 0.6;
uniform float specular = 0.35;
instance uniform float swim_phase = 0.0;
instance uniform float swim_amp = 0.05;
instance uniform float bend = 0.0;

void vertex() {
	float z = VERTEX.z;
	// 0 ahead of the middle, rising to 1 over the stalk and tail
	float s = smoothstep(-0.05, 0.42, z);
	float sway = swim_amp * s * s * sin(swim_phase - z * 4.0);
	// the head answers the tail a little, the other way
	sway -= swim_amp * 0.15 * (1.0 - s) * sin(swim_phase);
	float curve = bend * (z + 0.5) * (z + 0.5);
	VERTEX.x += sway + curve;
	// the tail fin turns with the stalk (so it slices, not slides)
	float yaw = swim_amp * 3.0 * s * cos(swim_phase - z * 4.0);
	if (z > 0.36) {
		VERTEX.x += yaw * (z - 0.36) * 0.4;
	}
}

void fragment() {
	vec3 c = albedo_color.rgb;
	if (use_texture) {
		c *= texture(albedo_texture, UV).rgb;
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
