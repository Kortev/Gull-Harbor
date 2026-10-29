// The inside of the Mudskipper's hull, world space (the ship's parked at the origin): written by
// world/dev/hull_inside_fit.gd (a 0.25 m flood fill, 3371 columns); don't edit by hand, run it again.
// hull_inside.res: a texel per column of the grid, red = its first inside cell, green = one past its last.
// world/planets/hull_mask.gd adds this to the planets' effects and sets the uniforms; in_hull(a world
// position) is true inside the ship (a fragment there: discard).

const vec3 HULL_LO = vec3(-5.8500, -0.2500, -15.4900);
const float HULL_CELL = 0.2500;
const vec3 HULL_DIMS = vec3(47.0, 39.0, 112.0);
uniform sampler2D hull_cells : filter_nearest, repeat_disable;
uniform bool hull_on = false;

bool in_hull(vec3 p) {
	vec3 u = (p - HULL_LO) / HULL_CELL;
	if (!hull_on || any(lessThan(u, vec3(0.0))) || any(greaterThanEqual(u, HULL_DIMS))) {
		return false;
	}
	vec2 c = round(texelFetch(hull_cells, ivec2(u.xz), 0).rg * 255.0);
	return u.y >= c.r && u.y < c.g;
}
