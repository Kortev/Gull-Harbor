extends PanelContainer
## The boat's owner's manual (the Esc menu's "The manual"): everything in docs/FEATURES.md, short, in the voice of a
## manual nobody proofread. Chapters down the left (the one open lit, the numbers lined up), the page on the right.

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
		+ "Every 3 days (3 trips) the bank wants a payment: the quota. $5,000, then half as much again each time. "
		+ "Every fish sold counts, and the money's yours to spend too. The bar top left is the quota.\n\n"
		+ "Miss it and the bank takes the boat: the skiff and $1,000 again. Fuel comes off every sale ($60 the "
		+ "skiff, $400 the sportfisher)."],
	["3. Finding tuna", "Bluefin feed under birds: a speck on the horizon, a mile or more off. Crosshair on it "
		+ "for how far and which way. Inside about 700 m you can tell:\n"
		+ "- Birds diving on white water: BLUEFIN.\n"
		+ "- Birds sitting on the water: tuna down. They come up again. Wait.\n"
		+ "- Gulls over little splashes: no tuna. About a third of flocks.\n\n"
		+ "The radar on the dash (2 km out, rings every 500 m) paints birds in the air: a tight return in the same "
		+ "spot every sweep, drifting. Sea clutter round her and rain clutter change every sweep; buoys don't move. "
		+ "It can't tell gulls from tuna birds: go and look.

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
		+ "Well empty? Jig more: the jig rod (3), stopped, rod out over the rail. Click to open the spool, click "
		+ "to thumb it: the line's a colour every 10 m, and they're down where the green goes out. Tap to work "
		+ "it, tap on the knock, hold to wind it up, click at the well to swing it in. Full well: it goes on ice "
		+ "for dead bait.\n\n"
		+ "Chum (the transom bucket, 24 scoops a trip): a slick pulls schools from about 450 m and keeps them "
		+ "while you keep it coming, a scoop a minute or so."],
	["6. The fight", "Reel screams: grab the rod (E). Anyone can, and anyone can take over.\n\n"
		+ "One rule: KEEP THE NEEDLE IN THE GREEN. Hold left mouse to reel and it climbs; let go and it falls.\n"
		+ "- In the green while you reel: you win line and he tires.\n"
		+ "- Too slack too long: the hook falls out. Reel.\n"
		+ "- In the red too long: the line snaps. Let go.\n"
		+ "- He runs or jumps: let go.\n\n"
		+ "A big one takes a few minutes. Alone: rod in its holder (Q) to steer. It fights on its drag; nobody "
		+ "wins line back."],
	["7. Driving during a fight", "Stern to the fish (A/D). Let it swing toward the bow and the line rubs on "
		+ "her and wears through: swing the stern to it, or the angler walks to that corner.\n\n"
		+ "Backing down (S) wins line back fast.\n\n"
		+ "If it goes UNDER her: out of gear. W or S while it's under and the props cut the line. Steering's "
		+ "fine.\n\n"
		+ "Get the other baits in (pick each rod up, wind) or a running fish tangles them."],
	["8. Landing it", "At about 7 m of line it's alongside.\n\n"
		+ "The big boat: wire it first (hold E at the tuna door). Then the harpoon off the port rack: hold left "
		+ "mouse to wind up (the dots show where it comes down), let go to throw. It swims while the harpoon "
		+ "flies: lead it. Then hold E at the door to haul; more hands, quicker. The skiff skips the wiring.\n\n"
		+ "EVERY MISS CAN LOSE IT: 25% the first, then 40, 55, 70.\n\n"
		+ "Leave it 90 s and the hook pulls."],
	["9. Getting paid", "On deck: E bleeds it, E again ices it. The grade (#1, #2, #3) is speed: landed quick, "
		+ "bled within a minute, iced within three. A #1 pays about twice a warm one.\n\n"
		+ "The fish box (the pips top left) holds 2 (skiff) or 12 (sportfisher). Bring her home and tie up alongside the fish pier to sell."],
	["10. Boats and gear", "The skiff: 2 rods, quick, handy alone or with two. Box for 2.\n"
		+ "The sportfisher ($20,000, or $2,500 a day chartered): 4 rods, box for 12, slow to turn, and the tuna "
		+ "door means wiring. She wants a crew. Her fighting chair and seats: E to sit, E or jump to get up. Her tuna "
		+ "tower: E on its ladder to climb; from up there you can tell what birds are on much further off.\n\n"
		+ "Gear lasts the run: a two-speed reel (winds a quarter faster), heavier line (rubs the hull longer)."],
]

const INK := Color(0.12, 0.1, 0.08)
const BLUE := Color(0.2, 0.25, 0.4)

var _page: Label
var _scroll: ScrollContainer
var _chapters: Array[Button] = []
## The chapter open.
var open := 0
var _tips: Node               # ui/tips.gd


func _init(tips: Node) -> void:
	_tips = tips


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.93, 0.9, 0.8)
	box.set_content_margin_all(16)
	add_theme_stylebox_override("panel", box)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	add_child(cols)
	var chapters := VBoxContainer.new()
	chapters.custom_minimum_size = Vector2(170, 0)
	cols.add_child(chapters)
	var head := Label.new()
	head.text = "OWNER'S MANUAL"
	head.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1))
	head.add_theme_font_size_override("font_size", 16)
	chapters.add_child(head)
	for i in CHAPTERS.size():
		var b := Button.new()
		var name := str(CHAPTERS[i][0])
		b.text = (" " if name.find(".") == 1 else "") + name        # (1. under 10.: the numbers lined up)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(turn.bind(i))
		chapters.add_child(b)
		_chapters.append(b)
	var again := Button.new()
	again.text = "   Dale's tips again"         # (under the chapters' names)
	again.alignment = HORIZONTAL_ALIGNMENT_LEFT
	again.flat = true
	again.add_theme_color_override("font_color", Color(0.55, 0.2, 0.15))
	again.pressed.connect(func() -> void:
		if _tips:
			_tips.call("reset")
		again.text = "Dale will be in touch")
	chapters.add_child(again)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(_scroll)
	_page = Label.new()
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_color_override("font_color", INK)
	_page.add_theme_constant_override("line_spacing", 2)
	_scroll.add_child(_page)
	turn(0)


## Open at chapter i: its page from the top, its name lit in the list.
func turn(i: int) -> void:
	open = i
	_page.text = str(CHAPTERS[i][1])
	_scroll.scroll_vertical = 0
	for j in _chapters.size():
		var b := _chapters[j]
		var on := j == i
		for st: String in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(BLUE, 0.16 if on else (0.08 if st == "hover" else 0.0))
			if st == "focus":
				box.bg_color = Color(0, 0, 0, 0)
				box.border_color = Color(BLUE, 0.8)
				box.set_border_width_all(2)
			box.content_margin_left = 6
			box.content_margin_right = 6
			box.content_margin_top = 2
			box.content_margin_bottom = 2
			b.add_theme_stylebox_override(st, box)
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, INK if on else BLUE)
