@tool
extends EditorScenePostImport
## The post-import script for the Blender models (boat.glb, ...), copied from the space fishing game, to the art brief:
## every material gets Nearest filtering with mipmaps, roughness 1, metallic 0 and a low specular, while
## transparency (cutouts, glass) and glow stay as imported. Embedded textures get mipmaps so far floors don't
## shimmer, except cutouts (railings, grates, nets), which keep none so they don't fade out with distance.
## Meshes whose names start with one of NO_SHADOW cast no shadows. Materials named "shader__<name>"
## become the shader assets/world/shaders/<name>.gdshader (light beams, runway lights, ...), and names
## ending in "__wet" or "__sheen" get a glossier finish (see FINISHES). A surface that carries vertex colours
## (baked shading: the Deckhand v2's ambient occlusion) has them multiplied into its colour, as glTF means them.
##
## Use it from a .glb's import settings: Import Script = this file (import_script/path), and
## glTF > Embedded Image Handling = Embed as Uncompressed (gltf/embedded_image_handling=3), so the
## textures stay crisp instead of being extracted and VRAM-compressed.

const NO_SHADOW: Array[String] = ["Glass", "Lights", "EngineGlow", "ForceField", "FloorPaint", "Beam"]
const SPECULAR := 0.35
## A material named "shader__<name>" is swapped for res://boat/shaders/<name>.gdshader, its
## base color and texture passed in as albedo_color / albedo_texture (if the shader has them).
const SHADER_PREFIX := "shader__"
const SHADER_DIR := "res://boat/shaders/"
## Name suffixes that loosen the roughness-1 rule, [roughness, specular]: "__wet" for puddles and oil
## (sharp reflections), "__sheen" for a satin floor that catches the lamps.
const FINISHES := {"__wet": [0.12, 0.6], "__sheen": [0.55, 0.3]}

var _done_materials: Dictionary = {}
var _done_textures: Dictionary = {}


func _post_import(scene: Node) -> Object:
	_done_materials.clear()
	_done_textures.clear()
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for prefix: String in NO_SHADOW:
			if String(mesh_node.name).begins_with(prefix):
				mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_node.mesh == null:
			continue
		for i: int in mesh_node.mesh.get_surface_count():
			var mat := mesh_node.mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			if not _done_materials.has(mat):
				_done_materials[mat] = _shader_material(mat) if mat.resource_name.begins_with(SHADER_PREFIX) else mat
				if _done_materials[mat] == mat:
					_crunch(mat)
			mesh_node.mesh.surface_set_material(i, _done_materials[mat] as Material)
			# Godot's glTF import leaves this off on some materials (the suits' "crew", shared by four meshes)
			var arrays := mesh_node.mesh as ArrayMesh
			if arrays != null and arrays.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR \
					and _done_materials[mat] is BaseMaterial3D:
				(_done_materials[mat] as BaseMaterial3D).vertex_color_use_as_albedo = true
	return scene


func _shader_material(mat: BaseMaterial3D) -> Material:
	var path := SHADER_DIR + mat.resource_name.trim_prefix(SHADER_PREFIX) + ".gdshader"
	if not ResourceLoader.exists(path):
		push_warning("psx_import: no shader %s for material %s" % [path, mat.resource_name])
		return mat
	var out := ShaderMaterial.new()
	out.resource_name = mat.resource_name
	out.shader = load(path) as Shader
	for uniform: Dictionary in out.shader.get_shader_uniform_list():
		match String(uniform["name"]):
			"albedo_color":
				out.set_shader_parameter("albedo_color", mat.albedo_color)
			"albedo_texture":
				out.set_shader_parameter("albedo_texture", mat.albedo_texture)
	return out


func _crunch(mat: BaseMaterial3D) -> void:
	# (the stylized look: smooth filtering, and each material's own roughness from Blender, not a flat 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC  # (crisp pixel art, as the crew)
	mat.roughness = clampf(mat.roughness, 0.35, 1.0)
	mat.metallic = minf(mat.metallic, 0.6)
	mat.metallic_specular = SPECULAR
	for suffix: String in FINISHES:
		if mat.resource_name.ends_with(suffix):
			var finish: Array = FINISHES[suffix]
			mat.roughness = finish[0]
			mat.metallic_specular = finish[1]
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		_mipmap(mat, BaseMaterial3D.TEXTURE_ALBEDO)
		_mipmap(mat, BaseMaterial3D.TEXTURE_EMISSION)


## Swaps an embedded texture for a copy with mipmaps (once per texture, shared by its materials).
func _mipmap(mat: BaseMaterial3D, slot: BaseMaterial3D.TextureParam) -> void:
	var tex := mat.get_texture(slot) as ImageTexture
	if tex == null:
		return
	if not _done_textures.has(tex):
		var img := tex.get_image()
		if img == null or img.has_mipmaps() or img.is_compressed():
			_done_textures[tex] = tex
		else:
			img.generate_mipmaps()
			var out := ImageTexture.create_from_image(img)
			out.resource_name = tex.resource_name
			_done_textures[tex] = out
	mat.set_texture(slot, _done_textures[tex] as ImageTexture)
