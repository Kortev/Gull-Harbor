shader_type spatial;
// The landmarks (sea/landmarks.gd): the coast, the lighthouse, the rig, the buoys. Low poly, a flat facet per
// triangle, coloured by vertex. Far ones are drawn shrunk in toward the camera (far_mul: how many times further off
// they really are), so the haze here goes by where they really are, not where they're drawn: land a few km off
// goes pale blue-grey into the horizon, and in fog it's gone.
render_mode cull_disabled, specular_schlick_ggx, fog_disabled, depth_draw_always;

uniform vec3 haze_color : source_color = vec3(0.6, 0.65, 0.7);
// m: how far you can see (1 - 1/e of the way into the haze at this distance)
uniform float visibility = 8000.0;
instance uniform float far_mul = 1.0;

varying float dist;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	dist = length(w - CAMERA_POSITION_WORLD) * far_mul;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	// (the scene's own fog is off for these: it's far too thick for land a few km off. This haze stands in for it:
	// the land goes the haze's grey-blue as it gets further off, then thins into whatever sky is behind it)
	float h = clamp(1.0 - exp(-dist / visibility), 0.0, 1.0);
	// (the haze is the air between you and it, lit already: it glows its own colour rather than taking the sun again)
	// (a touch under the horizon's own colour, so far hills stay a shade darker than the sky they stand against)
	ALBEDO = COLOR.rgb * (1.0 - h) * (1.0 - h);
	EMISSION = haze_color * h * 0.82;
	ALPHA = 1.0 - smoothstep(0.55, 0.97, h);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
