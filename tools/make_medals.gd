extends SceneTree
## The achievements' medals (ui/medals.gd draws them, the game draws them the same at run time) written out for
## Steamworks, which wants 64 x 64 at least and a greyed one for each locked:
##   art/achievements/<API>.png          earned, the 32 grid at 2x, nearest
##   art/achievements/<API>_locked.png   locked (a secret one's real picture: Steam hides it itself)
##   art/achievements/sheet.png          all of them, earned over locked, at 2x: to look over
## Run: godot --headless --path . --script res://tools/make_medals.gd

const Medals := preload("res://ui/medals.gd")
const OUT := "res://art/achievements/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var apis := Medals.KIND.keys()        # (core/achievements.gd's LIST, in order: it wants the game's autoloads)
	var n := apis.size()
	var sheet := Image.create(n * 68 + 4, 140, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0a0f16"))
	for i in n:
		var api: String = apis[i]
		var on := _x2(Medals.image(api))
		var off := _x2(_locked(api))
		on.save_png(OUT + api + ".png")
		off.save_png(OUT + api + "_locked.png")
		sheet.blend_rect(on, Rect2i(0, 0, 64, 64), Vector2i(4 + i * 68, 4))
		sheet.blend_rect(_x2(Medals.image(api, true)), Rect2i(0, 0, 64, 64), Vector2i(4 + i * 68, 72))
	sheet.save_png(OUT + "sheet.png")
	print("make_medals: %d medals, earned and locked, in %s" % [n, OUT])
	quit()


## Steam's locked picture: the real one greyed, never the "?" (Steam keeps a hidden one's secret itself).
static func _locked(api: String) -> Image:
	var img := Medals.image(api)
	Medals._grey(img)
	return img


static func _x2(img: Image) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return out
