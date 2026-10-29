// The rod's blank bending under load: rod.gd sets `bend`, where the tip has gone (rod-local x, y, metres), and the
// blank follows it in a curve, stiff at the butt, most at the tip. The rod runs along +Z from the butt's end.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform float roughness = 0.6;
uniform float butt_len = 0.62;
uniform float rod_len = 1.76;
instance uniform vec2 bend = vec2(0.0);

void vertex() {
	float s = clamp((VERTEX.z - butt_len) / (rod_len - butt_len), 0.0, 1.0);
	VERTEX.xy += bend * s * s;
	// the tip comes back a little as it bends (the blank doesn't stretch)
	VERTEX.z -= length(bend) * s * s * s * 0.35;
}

void fragment() {
	vec3 c = albedo_color.rgb;
	if (use_texture) {
		c *= texture(albedo_texture, UV).rgb;
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	SPECULAR = 0.4;
}
