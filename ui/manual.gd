extends PanelContainer
## The boat's owner's manual (the Esc menu's "The manual"): everything in docs/FEATURES.md, short, in the voice of a
## manual nobody proofread. Chapters down the left, the page on the right.

const CHAPTERS := [
	["1. Controls", "WASD walk (at the wheel: throttle and steer). Mouse look. Shift sprint, Space jump.\n"
		+ "E: use whatever's under the crosshair. Hold E to haul, wire, jig.\n"
		+ "Left mouse: crank the reel. Throw the harpoon. A flock under the crosshair: call it.\n"
		+ "Right mouse: heave the rod up (a pump is heave, then crank on the way down).\n"
		+ "Q: put the rod or the harpoon back. Esc: this menu."],
	["2. The loan", "Congratulations on your boat, which belongs to First Coastal Savings & Loan.\n\n"
		+ "Every 3 days (3 trips) the bank wants a payment: the quota. $5,000 first, then half as much again "
		+ "each time. Every fish you sell counts toward it, and the money's yours to spend at the dock too.\n\n"
		+ "Make it by the third day's sale and the next one's bigger. Miss it and the bank takes the boat, and "
		+ "you start again with the skiff and $1,000. Fuel comes off every sale ($60 the skiff, $400 the "
		+ "sportfisher)."],
	["3. Finding tuna", "Bluefin feed under birds. Flocks turn up a mile or more off, and from the deck they're a "
		+ "speck on the horizon.\n\n"
		+ "Get within about 700 m and you can tell what a flock is (crosshair on it):\n"
		+ "- Birds diving on white water: BLUEFIN. Go.\n"
		+ "- Birds sitting on the water: the tuna are down. They come up again in a minute or so. Wait.\n"
		+ "- Gulls over little splashes: no tuna. About a third of flocks are just gulls.\n\n"
		+ "Left click on a flock calls it: a cross on the radar for everyone. The radar shows "
		+ "birds in the air out to 1.5 km, but it can't tell gulls from tuna birds."],
	["4. Coming up on them", "DO NOT RUN OVER THE FISH. Faster than about 10 knots through a school and it dives "
		+ "for 40 seconds.\n\n"
		+ "Get within about 150 m, slow to trolling speed (a few knots), and the school finds your baits. "
		+ "Nothing bites above about 12 knots: the baits skip along the top."],
	["5. Bait", "Baits wash out in about 5 minutes (live ones 10) and get a quarter of the bites. The HUD tells "
		+ "you; E on the rod puts a fresh one out.\n\n"
		+ "Live mackerel (the live-bait well, $1,500): half as many bites again. The well starts each trip with 4. "
		+ "Hold E on the jig rod, slowed right down, for more.\n\n"
		+ "Chum (the bucket on the transom, 24 scoops a trip): E throws a scoop. The slick pulls schools from "
		+ "about 450 m and keeps them there while you keep it coming, a scoop a minute or so."],
	["6. The fight", "Reel screams: grab the rod (E). Anyone can, and anyone can take it over mid-fight.\n\n"
		+ "The line under the crosshair says what the fish is doing:\n"
		+ "- Running: let it go. Cranking against it strains the line.\n"
		+ "- Resting: crank (left mouse).\n"
		+ "- Sounding or circling: pump. Heave up (right mouse), crank as you drop.\n"
		+ "- Head shakes: keep it tight, keep cranking or heaving.\n"
		+ "- Death spiral (the last 30 m): it circles under the boat. Coming up, crank. Going under, ease off.\n\n"
		+ "The ring round the crosshair is how wrong you're doing it. Red too long and the line snaps.\n\n"
		+ "Alone: put the rod in its holder (Q) to steer. It fights on its drag; nobody wins line back."],
	["7. Driving during a fight", "Keep the stern pointed at the fish (A/D). If it swings forward of the beam, "
		+ "the line rubs the hull and wears through: swing the stern to it, or the angler walks to that corner.\n\n"
		+ "Backing down (S) on the fish wins line back fast.\n\n"
		+ "If it goes UNDER the boat: hands off the throttle. The props cut the line only if you're in gear (W or "
		+ "S) while it's under her, after a second and a half's warning. Steering alone is fine.\n\n"
		+ "Other baits still out can tangle in a running fish: E on each other rod to reel it in."],
	["8. Landing it", "At about 7 m of line it's beaten and alongside.\n\n"
		+ "The big boat: someone wires it first (hold E at the tuna door). Then the harpoon (the rack along the "
		+ "port side): aim, left click. Then hold E at the door to haul it in; every extra pair of hands makes it "
		+ "quicker. The skiff's low enough to skip the wiring.\n\n"
		+ "Leave it alongside 90 seconds and the hook pulls."],
	["9. Getting paid", "On deck: E on the fish bleeds it, E again ices it. The grade (#1, #2, #3) is all in "
		+ "speed: landed quick, bled within a minute, iced within three. A #1 pays about twice a warm one.\n\n"
		+ "The fish box holds 2 (skiff) or 12 (sportfisher). Head in from this menu to sell."],
	["10. Boats and gear", "The skiff: 2 rods, quick, handy alone or with two. Her fish box takes 2.\n"
		+ "The sportfisher ($20,000, or $2,500 a day chartered): 4 rods, a fish box for 12, slow to turn and "
		+ "stop, and the tuna door means wiring. She wants a crew. Her fighting chair: E to sit (E or jump to get "
		+ "up). It swivels where you look. Fight from it if you like, or just sit in it and watch the sea.\n\n"
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
	again.text = "Have Dale explain it all again"
	again.flat = true
	again.add_theme_color_override("font_color", Color(0.55, 0.2, 0.15))
	again.pressed.connect(func() -> void:
		if _tips:
			_tips.call("reset")
		again.text = "Dale will be in touch.")
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
