extends RefCounted
## How fishing line and thin cord are drawn (rods/line.gdshader): one-pixel lines that fade with distance, so a
## line reads up close and goes to a faint thread far off instead of a bold white stroke across the sea.
##   LineLook.material()          the usual line (mono: clear near, a ghost at fifty metres)
##   LineLook.material(0.3, 6.0)  a heavier or more important one (a taut fight line, a harpoon's rope)

const SHADER := preload("res://rods/line.gdshader")
## Monofilament's colour: a pale grey-green, a touch darker than the sky so it never glows against it.
const MONO := Color(0.74, 0.77, 0.74)


static func material(floor_alpha := 0.03, clear_to := 3.0, near_alpha := 0.85) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("floor_alpha", floor_alpha)
	m.set_shader_parameter("clear_to", clear_to)
	m.set_shader_parameter("near_alpha", near_alpha)
	return m
