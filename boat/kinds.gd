extends RefCounted
## The boats, and everything about each that the rest of the game reads (boat/boat.gd builds her from it; the rods,
## the landing, the fish hold, the wake and the helm take their spots and numbers from it). The skipper picks one at the
## dock (ui/menu.gd); everyone aboard gets the same.
##
## All positions are boat-local, Godot's axes: x starboard, y up from her waterline, z aft (her bow is -z).
##   model         the glb her Blender script writes
##   length, beam  m (the sea's cut-out round her hull, and how she sits on the swell)
##   deck          her sole above the waterline; sink: how far below her painted waterline she sits loaded
##   pitch_follow, roll_follow: how much of the sea's slope she follows (a small hull follows it all: she's lively)
##   rods          which of her rod holders fish (art/*.py's holder_<n>), and each one's bait astern and its name
##   stern         where the lines go over the transom
##   rack          where the harpoon lies (its point forward)
##   haul          where you haul a stuck fish aboard, starboard side (port mirrors it): the box you hold E on, its
##                 size, and whether there's a tuna door to draw there (else it comes over the gunwale)
##   fish_water    where a fish lies alongside, starboard side; fish_across: across her stern (else along her side);
##                 fish_aboard: where it comes up to as it's hauled
##   spots         where fish lie on deck, in turn: x, y, z, and w 1 lying across her, 0 along her
##   hold          how many fish her fish box takes iced (one more on deck sells warm)
##   wire          a fish alongside must be wired (someone holding the leader) before it can be stuck: her high
##                 transom (the sportfisher); over the skiff's low gunwale you can reach it with the harpoon as it is
##   ahead, astern m/s flat out; spurt, back: m/s each second getting going ahead, astern; coast: s she carries her way
##   turn          rad/s hard over
##   transom, engines, bow: the wake's spots (wash, engine sound, bow spray)
##   cabin_light   the dim red night light at the helm; crown: her highest point (the lightning goes for it)
##   haul_lift     m the fish is lifted over her gunwale as it's hauled in (0 through a tuna door)
##   chum          where the chum bucket stands (boat/chum.gd); jig: the holder the mackerel jig sits in (boat/jig.gd)
##   price         what she costs to buy at the dock; fuel: what a trip in her costs (taken from the sale)

const DEFAULT := "sportfisher"

const KINDS := {
	"skiff": {
		"name": "the skiff",
		"title": "28 ft center console",
		"blurb": "Quick and handy, one or two can fish her: two rods, the wheel a step from them. No radar, no "
				+ "sonar: you find the birds by eye. Rough in a blow, and her fish box takes two.",
		"model": "res://boat/skiff.glb",
		"length": 8.5, "beam": 2.9, "deck": 0.45, "sink": 0.05,
		"pitch_follow": 1.0, "roll_follow": 1.0,
		"rods": [0, 1],
		"baits": [Vector3(4.0, 0.0, 30.0), Vector3(-4.0, 0.0, 36.0)],
		"rod_names": ["starboard corner", "port corner"],
		"stern": Vector3(0.0, 0.0, 4.3),
		"rack": Vector3(-1.2, 0.85, 1.4),
		"haul": Vector3(1.15, 0.95, 3.0), "haul_box": Vector3(0.55, 0.6, 0.9), "door": false, "haul_lift": 0.9,
		"fish_water": Vector3(1.95, 0.0, 3.0), "fish_across": false, "fish_aboard": Vector3(0.9, 0.85, 3.0),
		"spots": [Vector4(0.95, 0.45, 2.6, 0.0), Vector4(-0.95, 0.45, 2.6, 0.0)],
		"hold": 2, "wire": false,
		"ahead": 11.0, "astern": 2.6, "spurt": 2.4, "back": 3.0, "coast": 4.5, "turn": 0.75,
		"transom": Vector3(0.0, 0.0, 4.9), "engines": Vector3(0.0, 0.9, 4.7), "bow": Vector3(0.5, 0.45, -3.3),
		"cabin_light": Vector3(0.0, 2.3, 0.4), "crown": Vector3(0.0, 2.75, 0.0),
		"chum": Vector3(-0.25, 1.03, 3.92), "jig": 2,
		"price": 0, "fuel": 60,
	},
	"sportfisher": {
		"name": "the sportfisher",
		"title": "46 ft sportfisher",
		"blurb": "Four rods, radar and sonar, the fighting chair, the tower and a big fish hold: the money boat. Slow to turn and stop, "
				+ "and it takes a crew to fish her well.",
		"model": "res://boat/boat.glb",
		"length": 14.0, "beam": 4.8, "deck": 0.55, "sink": 0.12,
		"pitch_follow": 1.0, "roll_follow": 0.85,
		"rods": [6, 7, 0, 1],
		"baits": [Vector3(5.5, 0.0, 39.0), Vector3(-5.5, 0.0, 39.0), Vector3(15.0, 0.0, 53.0),
				Vector3(-15.0, 0.0, 53.0)],
		"rod_names": ["starboard corner", "port corner", "starboard", "port"],
		"stern": Vector3(0.0, 0.0, 7.05),
		"rack": Vector3(-2.02, 1.2, 4.4),
		"haul": Vector3(1.0, 0.95, 6.82), "haul_box": Vector3(0.8, 0.7, 0.35), "door": true,
		"fish_water": Vector3(1.1, 0.0, 7.95), "fish_across": true, "fish_aboard": Vector3(1.0, 0.8, 6.22),
		"spots": [Vector4(0.0, 0.55, 5.75, 1.0), Vector4(0.0, 0.55, 3.45, 1.0), Vector4(0.0, 0.55, 2.55, 1.0),
				Vector4(0.0, 0.55, 1.85, 1.0)],
		"hold": 12, "wire": true,
		"ahead": 10.0, "astern": 2.6, "spurt": 1.4, "back": 2.2, "coast": 9.0, "turn": 0.45,
		"transom": Vector3(0.0, 0.0, 7.3), "engines": Vector3(0.0, 0.3, 3.5), "bow": Vector3(1.7, 0.6, -5.0),
		"cabin_light": Vector3(0.0, 2.45, -1.3), "crown": Vector3(0.0, 7.6, -1.3),
		"chum": Vector3(-0.3, 1.3, 6.6), "jig": 4,
		"price": 20000, "fuel": 400,
	},
}


static func spec(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS[DEFAULT])
