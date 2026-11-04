extends CanvasLayer
## The music as it plays, on screen (run the game with -- --music-hud: for tuning it): where the music is, the song,
## the bar and the chord, how hard he's fighting, each piece's fade and each layer as a bar (as loud as it is), and the
## cues as they're played. Not part of the game.

const PIECES := ["title", "song_fair", "song_rain", "song_fog", "song_night", "song_storm", "fight"]
const LAYERS := ["run", "hit", "pulse", "drums", "full"]
const W := 300.0
const ROW := 13.0
const CUE_KEEP := 6.0

var music: Node
var _panel: Control
var _cues: Array = []       # [[time it showed, text]]
var _seen := 0
var _t := 0.0


func _ready() -> void:
	layer = 120
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-W - 12.0, 12.0)
	_panel.size = Vector2(W, 400.0)
	_panel.draw.connect(_draw)
	add_child(_panel)


func _process(delta: float) -> void:
	_t += delta
	var played: Array = music.get("played")
	var total := int(music.get("played_n"))
	for i in range(maxi(_seen, total - played.size()), total):
		var p: Array = played[played.size() - (total - i)]
		if not str(p[1]).begins_with("still:"):
			_cues.append([_t, str(p[1])])
	_seen = total
	while not _cues.is_empty() and _t - float(_cues[0][0]) > CUE_KEEP:
		_cues.pop_front()
	_panel.queue_redraw()


func _draw() -> void:
	var state: RefCounted = music.get("state")
	var f := ThemeDB.fallback_font
	var y := 0.0
	var rows := PIECES.size() + LAYERS.size()
	var h := 70.0 + rows * ROW + 12.0 + _cues.size() * 14.0
	_panel.draw_rect(Rect2(0, 0, W, h), Color(0.02, 0.04, 0.06, 0.78))
	_panel.draw_rect(Rect2(0, 0, W, h), Color(0.4, 0.7, 0.9, 0.6), false, 1.0)
	var bb: Vector2 = music.call("bar_beat")
	var head := [
		"MUSIC  %s   song %s%s" % [str(state.get("place")).to_upper(), str(state.get("song")),
				"  (tied up)" if bool(state.get("docked")) else ""],
		"%s   chord %s   bar %d beat %d" % [str(music.get("cue")), str(music.call("chord_now")), int(bb.x) + 1,
				int(bb.y) + 1],
		"fight %ds   intensity %d%%   danger %d%%" % [roundi(float(state.get("fight_t"))),
				roundi(float(state.get("intensity")) * 100.0), roundi(float(state.get("danger")) * 100.0)],
	]
	for line: String in head:
		y += 16.0
		_panel.draw_string(f, Vector2(8, y), line, HORIZONTAL_ALIGNMENT_LEFT, W - 16.0, 12, Color(0.85, 0.93, 1.0))
	y += 10.0
	for k: String in PIECES + LAYERS:
		var v := clampf(float(music.call("level", k)), 0.0, 1.0)
		_panel.draw_string(f, Vector2(8, y + ROW - 2.0), k, HORIZONTAL_ALIGNMENT_LEFT, 80.0, 11, Color(0.7, 0.8, 0.88))
		_panel.draw_rect(Rect2(90, y + 3.0, W - 102.0, ROW - 5.0), Color(1, 1, 1, 0.08))
		var c := Color(0.6, 0.55, 0.95) if k in PIECES else Color(0.35, 0.75, 1.0).lerp(Color(1.0, 0.45, 0.25), v)
		_panel.draw_rect(Rect2(90, y + 3.0, (W - 102.0) * v, ROW - 5.0), c)
		y += ROW
	y += 6.0
	for c: Array in _cues:
		y += 14.0
		var age := _t - float(c[0])
		_panel.draw_string(f, Vector2(8, y), str(c[1]), HORIZONTAL_ALIGNMENT_LEFT, W - 16.0, 12,
				Color(1.0, 0.85, 0.4, clampf(1.5 - age / CUE_KEEP, 0.2, 1.0)))
