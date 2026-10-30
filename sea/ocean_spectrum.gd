extends RefCounted
## The sea as a spectrum: tens of thousands of waves, the way a real sea is made (and the way Sea of Thieves makes
## its sea: Tessendorf's FFT ocean). Three tiles (CASCADES) of N x N waves each, from the long swell down to the
## ripples, each tile a band of wavelengths so none is counted twice, at sizes that never line up so no tile's
## repeat ever shows. Made once from SEA_SEED: every peer gets the same sea.
##
## h0 is each wave's height and phase at time 0, as the GPU wants it (sea/ocean_fft.gd turns it into the sea every
## frame). waves() is the biggest of them as plain rolling waves, for ocean.gd's height_at: the boat, the fish and
## the line ride the same swell the GPU draws; only the little ones (centimetres) are left out.
##
## A wave at grid point (n, m) of tile c: k = 2 pi (n', m') / L_c (n' = n, or n - N past the middle), its height
## 2 |h0| cos(k.x + w t + arg h0) with w = sqrt(g k) * PACE, travelling toward -k.

const N := 256
## Each tile: its size (m), the band of wavelengths it holds (longest, shortest, m), where its hump is (m), how wide
## the hump is (ln units), how tightly its waves follow the wind (cos^2s spreading), and how much of it runs back up
## into the wind (a second lobe, that share of the first). Short waves go every way, mostly with the wind: met
## head-on by others coming back, they rise and fall where they are instead of all streaming downwind together (the
## chop's pattern drifts at 2 m/s and the ripples' at 0.3, not 3.5 and 0.9, which read as a boat under way when she's
## still). The swell all goes one way.
const CASCADES := [
	{"size": 1100.0, "band": Vector2(1100.0, 32.0), "peak": 75.0, "width": 0.4, "spread": 14.0, "back": 0.0},
	{"size": 233.0, "band": Vector2(32.0, 9.0), "peak": 16.0, "width": 0.6, "spread": 4.0, "back": 0.3},
	{"size": 47.0, "band": Vector2(9.0, 0.35), "peak": 3.0, "width": 0.9, "spread": 1.0, "back": 0.5},
]
const G := 9.81

## Per tile: the h0 image (RGBA32F: rg = h0(k), ba = conj(h0(-k))), each tile scaled to 1 m significant height.
var images: Array[Image] = []
## Per tile: every wave as [amplitude (of the cosine, m at 1 m Hs), kx, kz, phase], biggest first, the top few.
var biggest: Array = []
## Per tile: how steep its water is on average (the RMS of k x amplitude over every wave, at 1 m Hs): ocean.gd sets
## how sharp its crests are from it, so the odd crest where many waves line up folds over and breaks.
var steepness := PackedFloat32Array()


## `wind`: where the wind goes (world x, z); `keep`: how many of each tile's biggest to keep for waves().
func _init(seed_value: int, wind: Vector2, keep: PackedInt32Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var away := atan2(-wind.y, -wind.x)        # (waves go toward -k: k points into the wind)
	for c in CASCADES.size():
		var spec: Dictionary = CASCADES[c]
		var size := float(spec["size"])
		var k_lo := TAU / (spec["band"] as Vector2).x
		var k_hi := TAU / (spec["band"] as Vector2).y
		var k_peak := TAU / float(spec["peak"])
		var width := float(spec["width"])
		var s := float(spec["spread"])
		var back := float(spec["back"])
		var dk := TAU / size
		var amp := PackedFloat32Array()
		var phase := PackedFloat32Array()
		amp.resize(N * N)
		phase.resize(N * N)
		var total := 0.0
		for m in N:
			var mz := m if m < N / 2 else m - N
			for n in N:
				var nx := n if n < N / 2 else n - N
				var kx := nx * dk
				var kz := mz * dk
				var k := sqrt(kx * kx + kz * kz)
				# (the random draws happen for every point, kept or not, so the sea doesn't hang on the band)
				var g1 := rng.randfn()
				var g2 := rng.randfn()
				if k < k_lo or k > k_hi or k <= 0.0:
					continue
				var hump := exp(-pow(log(k / k_peak), 2.0) / (2.0 * width * width))
				var turn := wrapf(atan2(kz, kx) - away, -PI, PI)
				var dir := pow(maxf(cos(turn * 0.5), 0.0), 2.0 * s) + back * pow(absf(sin(turn * 0.5)), 2.0 * s)
				# (a density in k-space: the k^-2 keeps the energy right as the grid's points spread out)
				var e := hump * dir / (k * k) * dk * dk
				var a := sqrt(e) * sqrt(g1 * g1 + g2 * g2) * 0.7071
				amp[m * N + n] = a
				phase[m * N + n] = atan2(g2, g1)
				total += 2.0 * a * a
		# scaled to 1 m significant height: Hs = 4 sigma, sigma^2 = sum of each cosine's (2a)^2 / 2
		var scale := 0.25 / sqrt(maxf(total, 1e-12))
		var data := PackedFloat32Array()
		data.resize(N * N * 4)
		var list := []
		var steep := 0.0
		for m in N:
			var mz := m if m < N / 2 else m - N
			for n in N:
				var i := m * N + n
				var a := amp[i] * scale
				amp[i] = a
				if a > 0.0:
					list.append([a, i])
					var nx := n if n < N / 2 else n - N
					var ka := 2.0 * a * dk * sqrt(float(nx * nx + mz * mz))
					steep += ka * ka * 0.5
		steepness.append(sqrt(steep))
		for m in N:
			for n in N:
				var i := m * N + n
				var a := amp[i]
				var p := phase[i]
				var j := ((N - m) % N) * N + ((N - n) % N)        # (-k)
				data[i * 4] = a * cos(p)
				data[i * 4 + 1] = a * sin(p)
				data[i * 4 + 2] = amp[j] * cos(phase[j])
				data[i * 4 + 3] = -amp[j] * sin(phase[j])
		images.append(Image.create_from_data(N, N, false, Image.FORMAT_RGBAF, data.to_byte_array()))
		list.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		var top := []
		for t in mini(keep[c] if c < keep.size() else 0, list.size()):
			var i: int = list[t][1]
			var n := i % N
			var m := i / N
			var nx := n if n < N / 2 else n - N
			var mz := m if m < N / 2 else m - N
			top.append([2.0 * amp[i], nx * dk, mz * dk, phase[i]])
		biggest.append(top)
