extends PanelContainer
## The boat's owner's manual (the Esc menu's "The manual"): everything in docs/FEATURES.md, short, in the voice of a
## manual nobody proofread. Chapters down the left, the page on the right.

const CHAPTERS := [
	["1. Controls", "WASD walk (at the wheel: throttle, steer). Mouse look. Shift sprint, Space jump.\n"
		+ "E: use what's under the crosshair. Hold E to haul, wire, jig.\n"
		+ "Left mouse: crank. Throw the harpoon.\n"
		+ "Fish on: the mouse is the rod. Up and down lifts and drops it, sideways lays it over. Scroll: the drag.\n"
		+ "Q: put the rod or the harpoon back. Esc: the menu.\n"
		+ "F: shove whoever's in front of you. Space into the rail: over it (onto a boat alongside, or into the sea).\n"
		+ "In the sea: WASD swim. Hold E on a boarding ladder to climb out."],
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
	["5. Bait", "Baits wash out in 5 minutes (live ones 10) and get a quarter of the bites. E on the rod for a "
		+ "fresh one.\n\n"
		+ "Live mackerel (the live-bait well, $1,500): half as many bites again. Hold E on the jig rod, slowed "
		+ "right down, for more.\n\n"
		+ "Chum (the transom bucket, 24 scoops a trip): a slick pulls schools from about 450 m and keeps them "
		+ "while you keep it coming, a scoop a minute or so."],
	["6. The fight", "Reel screams: grab the rod (E). Anyone can, and anyone can take over.\n\n"
		+ "Read the rod and the reel:\n"
		+ "- Screaming: it's running on the drag. Hands off the crank.\n"
		+ "- Grinding, winning nothing: pump. Lift slow (mouse up), wind as you drop.\n"
		+ "- Line sweeping round: lay the rod over against it (mouse sideways).\n"
		+ "- It jumps: drop the tip.\n"
		+ "- Rod creaking: about to snap. Ease off, or slack the drag (scroll down).\n\n"
		+ "Alone: rod in its holder (Q) to steer. It fights on its drag; nobody wins line back."],
	["7. Driving during a fight", "Stern to the fish (A/D). Let it swing toward the bow and the line rubs on "
		+ "her and wears through: swing the stern to it, or the angler walks to that corner.\n\n"
		+ "Backing down (S) wins line back fast.\n\n"
		+ "If it goes UNDER her: out of gear. W or S while it's under and the props cut the line. Steering's "
		+ "fine.\n\n"
		+ "Reel the other baits in (E on each rod) or a running fish tangles them."],
	["8. Landing it", "At about 7 m of line it's alongside.\n\n"
		+ "The big boat: wire it first (hold E at the tuna door). Then the harpoon off the port rack: aim, left "
		+ "click. Then hold E at the door to haul; more hands, quicker. The skiff skips the wiring.\n\n"
		+ "Leave it 90 s and the hook pulls."],
	["9. Getting paid", "On deck: E bleeds it, E again ices it. The grade (#1, #2, #3) is speed: landed quick, "
		+ "bled within a minute, iced within three. A #1 pays about twice a warm one.\n\n"
		+ "The fish box (the pips top left) holds 2 (skiff) or 12 (sportfisher). Head in from the menu to sell."],
	["10. Boats and gear", "The skiff: 2 rods, quick, handy alone or with two. Box for 2.\n"
		+ "The sportfisher ($20,000, or $2,500 a day chartered): 4 rods, box for 12, slow to turn, and the tuna "
		+ "door means wiring. She wants a crew. Her fighting chair: E to sit, E or jump to get up.\n\n"
		+ "Gear lasts the run: a two-speed reel (winds a quarter faster), heavier line (rubs the hull longer), the "
		+ "live-bait well."],
]

var _page: Label
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
	for c: Array in CHAPTERS:
		var b := Button.new()
		b.text = str(c[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_color_override("font_color", Color(0.2, 0.25, 0.4))
		b.pressed.connect(func() -> void: _page.text = str(c[1]))
		chapters.add_child(b)
	var again := Button.new()
	again.text = "Dale's tips again"
	again.flat = true
	again.add_theme_color_override("font_color", Color(0.55, 0.2, 0.15))
	again.pressed.connect(func() -> void:
		if _tips:
			_tips.call("reset")
		again.text = "Dale will be in touch")
	chapters.add_child(again)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	_page = Label.new()
	_page.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	_page.text = str(CHAPTERS[0][1])
	scroll.add_child(_page)
