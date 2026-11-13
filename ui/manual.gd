extends PanelContainer
## The boat's owner's manual (the Esc menu's "The manual"): everything in docs/FEATURES.md, short, in the voice of a
## manual nobody proofread. Chapters down the left (the one open yellow, a pointer at it), the page on the right, in the kit's hand
## (ui/kit.gd): type over the menu's flat dim, no panel.

const CHAPTERS := [
	["1. Controls", "WASD walk (at the wheel: throttle, steer). Mouse look. Shift sprint, Space jump.\n"
		+ "E: use what's under the crosshair. Hold E to haul, wire, jig.\n"
		+ "Left mouse: reel. Throw the harpoon.
"
		+ "Q: put the rod or the harpoon back. Esc: the menu.
"
		+ "F: shove whoever's in front of you. Walk into the rail and jump: up on it. Sprint and jump: over it (onto a boat a jump away, or into the sea).
"
		+ "In the sea: WASD swim, Shift sprint, Ctrl dive. E by a boarding ladder: W climbs, S goes down, E lets go.\n\n"
		+ "A pad: left stick walk, right stick look. RT cast and reel (harder pulled, faster), LT heave and aim. "
		+ "A jump, X use, B put back, Y shove, LB/RB what's in your hands, L3 sprint, R3 dive, START the menu. "
		+ "At the wheel the triggers are the throttle too. D-pad up talks, down's the VHF."],
	["2. The loan", "Your boat belongs to First Coastal Savings & Loan.\n\n"
		+ "Every 3 days (3 trips) the bank wants the boat payment, the same every time for the boat you own: "
		+ "$7,000 for the skiff, $13,000 once you've bought the sportfisher (she catches more). It only "
		+ "goes up when you buy a bigger boat. Past two aboard, each extra hand takes a 12% share of every fish sold. "
		+ "Every fish sold counts, and the money's yours to spend too. The bar top left is the payment, and when it's due.\n\n"
		+ "Miss it and the bank takes the boat: the skiff and $1,000 again. Fuel comes off every sale ($60 the "
		+ "skiff, $400 the sportfisher)."],
	["3. Finding tuna", "Bluefin feed under birds: a speck on the horizon, a mile or more off. Crosshair on it "
		+ "for how far and which way. Inside about 700 m you can tell:\n"
		+ "- Birds diving on white water: BLUEFIN.\n"
		+ "- Birds sitting on the water: tuna down. They come up again. Wait.\n"
		+ "- Gulls over little splashes: no tuna. About a third of flocks.\n\n"
		+ "The radar on the dash (2 km out, rings every 500 m) paints birds in the air: a tight return in the same "
		+ "spot every sweep, drifting. Sea clutter round her and rain clutter change every sweep; buoys don't move. "
		+ "It shows birds, never what's under them: go and look, or send someone up the tower (out to 1.8 km, and "
		+ "they'll call it down: BIRDS WORKING, TWO O'CLOCK!).

"
		+ "The plotter beside it (north up) shows her track and marks every flock you've picked out."],
	["4. Working a school", "A school travels its own way and feeds at its head: watch which way the birds go. "
		+ "Only a bait out in front of it gets eaten.\n\n"
		+ "Your baits trail behind you: cut across ahead of it and drag them through its path, run alongside just "
		+ "ahead of it at its pace, or stop in its way and cast. Nothing bites over 12 knots."],
	["5. Bait", "Tuna want A LIVE MACKEREL. No lures. Every boat has a live well, a mackerel in it for every "
		+ "hook and 4 more each trip (8 at most). The hooks go out bare: you bait them.\n\n"
		+ "Open the well (E), E again nets one out. E on a rod with its line in: the hook comes up to it. "
		+ "Click as the point's at its nose, just ahead of the eyes. A bit off and it swims crooked (half the "
		+ "bites); back through the eyes and it's dead. A dead one still gets taken, now and then.\n\n"
		+ "Then send it out: pick the rod up, hold left mouse and let go to cast, or hold right mouse to let it "
		+ "back off the stern (let go to thumb it). Q puts the rod in its holder to troll.\n\n"
		+ "A mackerel tires out in 10 minutes. Wind it in (left mouse, rod in your hands) and put a fresh one on.\n\n"
		+ "The well's water goes stale: one dies every 4 minutes or so unless someone pumps it. Hold E on the "
		+ "pump beside the well. Murky water: pump.\n\n"
		+ "Well empty? Jig more: the jig rod (3), stopped, rod out over the rail. Click to open the spool, click "
		+ "to thumb it: the line's a colour every 10 m, and they're down where the green goes out. Tap to work "
		+ "it, tap on the knock, hold to wind it up, click at the well to swing it in. Full well: it goes on ice "
		+ "for dead bait.\n\n"
		+ "Chum (the transom bucket, 24 scoops a trip): a slick pulls schools from about 450 m and keeps them "
		+ "while you keep it coming, a scoop a minute or so."],
	["6. The fight", "Reel screams: grab the rod (E). Anyone can, and anyone can take over.\n\n"
		+ "The rod's bend is him pulling. Read it, and the reel.\n"
		+ "- Reel screaming: he's taking line off the drag. Hands off the crank (cranking now twists the line).\n"
		+ "- PUMP: lift the rod slow (mouse up) and he comes; drop it winding (left mouse). Lift when the bend "
		+ "eases off, his tired moment; you can't crank a fish that's pulling.\n"
		+ "- THE DRAG: scroll, a notch at a time (the strike detent clicks). Too light, he takes it all. Too "
		+ "heavy, the hook tears out or a kick parts the line. Ease it as the spool empties and close in.\n"
		+ "- The spool: watch it empty. Half gone, the backing shows: the captain backs down on him (S).\n"
		+ "- He jumps: drop the tip. He comes at you: wind like mad, never give him slack.\n"
		+ "- The leader up at the rod tip: he'll go once more. Ease the drag.\n\n"
		+ "A big one takes a long while and your arms go: swap on the rod. Alone: rod in its holder (Q), get on "
		+ "the wheel. It fights on its drag as you left it; nobody wins line back, and on a run he takes it "
		+ "twice as fast with nobody on the rod: put it in between his runs.\n\n"
		+ "Two on at once (a double header: another bait across the same school goes while one's on): one in "
		+ "hands, one in its holder till someone's free. Get the other lines in fast."],
	["7. Driving during a fight", "Stern to the fish (A/D). Let it swing toward the bow and the line rubs on "
		+ "her and wears through: swing the stern to it, or the angler walks to that corner.\n\n"
		+ "Backing down (S) wins line back fast.\n\n"
		+ "If it goes UNDER her: out of gear. W or S while it's under and the props cut the line. Steering's "
		+ "fine.\n\n"
		+ "Get the other baits in (pick each rod up, wind) or a running fish tangles them."],
	["8. Landing it", "At about 7 m of line it's alongside.\n\n"
		+ "The big boat: wire it first (hold E at the tuna door). Then the harpoon off the port rack: hold left "
		+ "mouse to wind up (the dots show where it comes down), let go to throw. It swims while the harpoon "
		+ "flies: lead it. Then E at the door as its tail swings in close: the tail rope over it (out wide, it "
		+ "falls short). Then hold E there to haul; more hands, quicker. The skiff skips the wiring.\n\n"
		+ "EVERY MISS CAN LOSE IT: 25% the first, then 40, 55, 70.\n\n"
		+ "Leave it 90 s and the hook pulls."],
	["9. Getting paid", "On deck it thrashes, and every second of that cooks its meat. The knife (1): hold left "
		+ "mouse on its head just behind the eye to spike it (it shivers and goes still; if it kicks, you missed). "
		+ "Under the pectoral fin to bleed it: hold, let go at the mark on the ring. Empty hands on its tail pump the "
		+ "blood out; on its body a mate pins it down. Along the belly, once it's dead, guts it. Then the gaff (2) to "
		+ "the open fish box, and the scoop (4) on the box packs ice over it.\n\n"
		+ "The grade (#1, #2, #3), and why, is on the slip: quick and clean pays about twice a warm one.\n\n"
		+ "The fish box (the pips top left) holds 2 (skiff) or 12 (sportfisher). Bring her home and tie up alongside the fish pier to sell."],
	["10. Boats and gear", "The skiff: 2 rods, quick, handy alone or with two. Box for 2.\n"
		+ "The sportfisher ($20,000, or $2,500 a day chartered): 5 rods (the shotgun way back off the tower), box for 12, slow to turn, and the tuna "
		+ "door means wiring. She wants a crew. Her fighting chair and seats: E to sit, E or jump to get up. Her tuna "
		+ "tower: E on its ladder to climb; from up there you can tell what birds are on much further off.\n\n"
		+ "Gear lasts the run: a two-speed reel (winds a quarter faster), heavier line (rubs the hull longer)."],
]

const Kit := preload("res://ui/kit.gd")

var kit := Kit.new()
var _page: Label
var _scroll: ScrollContainer
var _chapters: Array[Button] = []
## The chapter open.
var open := 0
var _tips: Node               # ui/tips.gd


func _init(tips: Node) -> void:
	_tips = tips


## The screen's scale (the HUD's): 1 at 1080p.
func _px() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 1080.0, 0.7, 2.5)


func _ready() -> void:
	var p := _px()
	# (no panel: the menu's one flat dim is behind it, and the type and the linework are on that)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", roundi(10.0 * p))
	add_child(page)
	var head := Label.new()
	head.text = "OWNER'S MANUAL"
	Kit.style_label(head, roundi(44.0 * p), Kit.PAPER, 0.0, 700)
	page.add_child(head)
	# the heavy rule under the title, and the ticks under the first 30% of it
	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 30.0 * p)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func() -> void:
		kit.px = _px()
		var y := 6.0 * kit.px
		kit.defer = true
		kit.rule(rule, Vector2(0, y), Vector2(rule.size.x, y), Kit.PAPER, true)
		kit.scale(rule, Vector2(0, y), Vector2(rule.size.x * 0.3, y), 24, 4, Kit.PAPER, 1.0, -1.0, -1.0, false)
		kit.flush()
		kit.defer = false)
	page.add_child(rule)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", roundi(36.0 * p))
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(cols)
	var chapters := VBoxContainer.new()
	chapters.custom_minimum_size = Vector2(330.0 * p, 0)
	cols.add_child(chapters)
	for i in CHAPTERS.size():
		var b := _link(str(CHAPTERS[i][0]).to_upper(), p)
		b.pressed.connect(turn.bind(i))
		chapters.add_child(b)
		_chapters.append(b)
	var again := _link("DALE'S TIPS AGAIN", p)
	again.pressed.connect(func() -> void:
		if _tips:
			_tips.call("reset")
		again.text = "DALE WILL BE IN TOUCH")
	chapters.add_child(again)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(_scroll)
	_page = Label.new()
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.style_label(_page, roundi(23.0 * p), Kit.PAPER, 0.0, 600)
	_page.add_theme_constant_override("outline_size", 3)
	_page.add_theme_constant_override("line_spacing", roundi(4.0 * p))
	_scroll.add_child(_page)
	turn(0)


## A chapter's name in the list: type only, the open one yellow with a pointer at its left (drawn in turn()).
func _link(text: String, p: float) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var fs := roundi(24.0 * p)
	b.add_theme_font_override("font", Kit.font(600))
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = Vector2(0, 38.0 * p)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 30.0 * p
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, pad)
	b.add_theme_color_override("font_outline_color", Color(0.03, 0.035, 0.04, 0.88))
	b.add_theme_constant_override("outline_size", maxi(roundi(fs * 0.2), 3))
	b.draw.connect(func() -> void:
		kit.px = _px()
		if b.is_hovered() or b.has_focus() or b.has_meta("open"):
			kit.tri(b, Vector2(22.0 * kit.px, b.size.y * 0.5), 15.0 * kit.px, Vector2.RIGHT, Kit.YELLOW))
	return b


## Open at chapter i: its page from the top, its name lit in the list.
func turn(i: int) -> void:
	open = i
	_page.text = str(CHAPTERS[i][1]).to_upper()
	_scroll.scroll_vertical = 0
	for j in _chapters.size():
		var b := _chapters[j]
		var on := j == i
		if on:
			b.set_meta("open", true)
		else:
			b.remove_meta("open")
		b.queue_redraw()
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Kit.YELLOW if (on or c == "font_hover_color") else Kit.PAPER)
