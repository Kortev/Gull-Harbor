extends RefCounted
## The sea on the GPU (Tessendorf's FFT ocean): each frame, for each of ocean_spectrum.gd's tiles, every wave moved on
## to now (spectrum pass), then summed into the water's shape by an inverse FFT across the rows and down the columns
## (fft pass, one row per workgroup in shared memory). What comes out, per tile, is two textures the ocean shader
## reads (Texture2DRD, no copying):
##   a: (x, z) how far the water's moved sideways, (y) how high, (w) its slope along x
##   b: (x) its slope along z, (y, z, w) how it's stretched or squeezed sideways (dDx/dx, dDz/dz, dDx/dz): where it's
##      squeezed hardest the crest's breaking (the foam)
## On the main RenderingDevice, run on the render thread. No RenderingDevice (headless, the Compatibility renderer):
## ok() is false and the shader keeps its rolling waves.

const Spectrum := preload("res://sea/ocean_spectrum.gd")

const SPECTRUM_GLSL := """
#version 450
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D h0;
layout(rgba32f, set = 0, binding = 1) uniform restrict writeonly image2D out_a;
layout(rgba32f, set = 0, binding = 2) uniform restrict writeonly image2D out_b;
layout(push_constant, std430) uniform Params {
	float time;
	float size;
	float chop;
	float pace;
	uint n;
	uint pad0;
	uint pad1;
	uint pad2;
} pc;

vec2 cmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 times_i(vec2 a) {
	return vec2(-a.y, a.x);
}

void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	int n = int(pc.n);
	float kx = float(id.x < n / 2 ? id.x : id.x - n) * 6.28318530718 / pc.size;
	float kz = float(id.y < n / 2 ? id.y : id.y - n) * 6.28318530718 / pc.size;
	float k = max(length(vec2(kx, kz)), 1e-6);
	float w = sqrt(9.81 * k) * pc.pace * pc.time;
	vec4 h = imageLoad(h0, id);
	vec2 H = cmul(h.xy, vec2(cos(w), sin(w))) + cmul(h.zw, vec2(cos(w), -sin(w)));
	vec2 iH = times_i(H);
	// sideways: toward the crest ahead and behind (sharp crests, wide troughs), x chop
	vec2 dx = iH * (kx / k) * pc.chop;
	vec2 dz = iH * (kz / k) * pc.chop;
	vec2 dydx = iH * kx;
	vec2 dydz = iH * kz;
	vec2 dxdx = -H * (kx * kx / k) * pc.chop;
	vec2 dzdz = -H * (kz * kz / k) * pc.chop;
	vec2 dxdz = -H * (kx * kz / k) * pc.chop;
	// two real answers to one complex transform each: p + i q
	imageStore(out_a, id, vec4(dx + times_i(dz), H + times_i(dydx)));
	imageStore(out_b, id, vec4(dydz + times_i(dxdx), dzdz + times_i(dxdz)));
}
"""

const FFT_GLSL := """
#version 450
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
layout(rgba32f, set = 0, binding = 0) uniform restrict image2D data;
layout(push_constant, std430) uniform Params {
	uint down;
	uint log_n;
	uint pad0;
	uint pad1;
} pc;

shared vec4 buf[2][256];

vec2 cmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void main() {
	uint i = gl_LocalInvocationID.x;
	uint line = gl_WorkGroupID.x;
	uint n = 1u << pc.log_n;
	uint r = bitfieldReverse(i) >> (32u - pc.log_n);
	buf[0][i] = imageLoad(data, pc.down == 1u ? ivec2(line, r) : ivec2(r, line));
	memoryBarrierShared();
	barrier();
	uint s = 0u;
	for (uint h = 1u; h < n; h <<= 1u) {
		uint k = i % (2u * h);
		uint kk = k % h;
		uint j = i - k;
		vec4 e = buf[s][j + kk];
		vec4 o = buf[s][j + kk + h];
		float ang = 3.14159265359 * float(kk) / float(h);
		vec2 w = vec2(cos(ang), sin(ang));
		vec4 wo = vec4(cmul(w, o.xy), cmul(w, o.zw));
		buf[1u - s][i] = k < h ? e + wo : e - wo;
		s = 1u - s;
		memoryBarrierShared();
		barrier();
	}
	imageStore(data, pc.down == 1u ? ivec2(line, i) : ivec2(i, line), buf[s][i]);
}
"""

var spectrum: Spectrum
## Per tile: what the shader samples.
var tex_a: Array[Texture2DRD] = []
var tex_b: Array[Texture2DRD] = []
## How sideways-sharp each tile's crests are (the swell's and the chop's the same as ocean.gd's rolling waves': the
## CPU's waves are this sea's biggest).
var chops := PackedFloat32Array([1.0, 1.0, 1.0])
var pace := 0.85

var _rd: RenderingDevice
var _spec_shader: RID
var _spec_pipe: RID
var _fft_shader: RID
var _fft_pipe: RID
var _h0: Array[RID] = []
var _a: Array[RID] = []
var _b: Array[RID] = []
var _spec_sets: Array[RID] = []
var _fft_sets: Array[RID] = []
var _ready := false


func _init(s: Spectrum) -> void:
	spectrum = s
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	for c in s.images.size():
		tex_a.append(Texture2DRD.new())
		tex_b.append(Texture2DRD.new())
	RenderingServer.call_on_render_thread(_setup)


## Whether the GPU sea's running (a RenderingDevice to run it on).
func ok() -> bool:
	return _rd != null


func _compile(code: String) -> RID:
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = code
	var spirv := _rd.shader_compile_spirv_from_source(src)
	if not spirv.compile_error_compute.is_empty():
		push_error("ocean_fft: " + spirv.compile_error_compute)
		return RID()
	return _rd.shader_create_from_spirv(spirv)


func _setup() -> void:
	_spec_shader = _compile(SPECTRUM_GLSL)
	_fft_shader = _compile(FFT_GLSL)
	if not _spec_shader.is_valid() or not _fft_shader.is_valid():
		_rd = null
		return
	_spec_pipe = _rd.compute_pipeline_create(_spec_shader)
	_fft_pipe = _rd.compute_pipeline_create(_fft_shader)
	var n := Spectrum.N
	for c in spectrum.images.size():
		var fmt := RDTextureFormat.new()
		fmt.width = n
		fmt.height = n
		fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
		fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
				| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		var h0 := _rd.texture_create(fmt, RDTextureView.new(), [spectrum.images[c].get_data()])
		var a := _rd.texture_create(fmt, RDTextureView.new())
		var b := _rd.texture_create(fmt, RDTextureView.new())
		_h0.append(h0)
		_a.append(a)
		_b.append(b)
		_spec_sets.append(_rd.uniform_set_create([_image(0, h0), _image(1, a), _image(2, b)], _spec_shader, 0))
		_fft_sets.append(_rd.uniform_set_create([_image(0, a)], _fft_shader, 0))
		_fft_sets.append(_rd.uniform_set_create([_image(0, b)], _fft_shader, 0))
		tex_a[c].texture_rd_rid = a
		tex_b[c].texture_rd_rid = b
	_ready = true


func _image(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u


## The sea at wave time `t` (from the main thread, once a frame).
func update(t: float) -> void:
	if _rd == null:
		return
	RenderingServer.call_on_render_thread(_run.bind(t, chops.duplicate(), pace))


func _run(t: float, ch: PackedFloat32Array, pc: float) -> void:
	if not _ready:
		return
	var n := Spectrum.N
	var log_n := int(round(log(float(n)) / log(2.0)))
	var list := _rd.compute_list_begin()
	for c in _h0.size():
		var size := float(Spectrum.CASCADES[c]["size"])
		var p := PackedFloat32Array([t, size, ch[c], pc]).to_byte_array()
		p.append_array(PackedInt32Array([n, 0, 0, 0]).to_byte_array())
		_rd.compute_list_bind_compute_pipeline(list, _spec_pipe)
		_rd.compute_list_bind_uniform_set(list, _spec_sets[c], 0)
		_rd.compute_list_set_push_constant(list, p, p.size())
		_rd.compute_list_dispatch(list, n / 16, n / 16, 1)
		_rd.compute_list_add_barrier(list)
		_rd.compute_list_bind_compute_pipeline(list, _fft_pipe)
		for down in 2:
			var q := PackedInt32Array([down, log_n, 0, 0]).to_byte_array()
			for k in 2:
				_rd.compute_list_bind_uniform_set(list, _fft_sets[c * 2 + k], 0)
				_rd.compute_list_set_push_constant(list, q, q.size())
				_rd.compute_list_dispatch(list, n, 1, 1)
			_rd.compute_list_add_barrier(list)
	_rd.compute_list_end()


func free_all() -> void:
	if _rd == null:
		return
	RenderingServer.call_on_render_thread(func() -> void:
		for r: RID in _spec_sets + _fft_sets + _h0 + _a + _b:
			if r.is_valid():
				_rd.free_rid(r)
		for r: RID in [_spec_pipe, _fft_pipe, _spec_shader, _fft_shader]:
			if r.is_valid():
				_rd.free_rid(r))
