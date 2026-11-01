# Steam achievements

The game's 16 achievements, for Steamworks (App Admin, **Stats & Achievements > Achievements**). The game calls
`setAchievement(<API name>)` then `storeStats()` (core/achievements.gd, the list is its `LIST`); the API names must
be entered exactly as below. Everything is earned on the player's own machine; no Steam stats need defining
(A Ton Ashore's kilos are counted by the game itself).

For each: **New Achievement**, then fill in API Name, Display Name and Description as written, Hidden on for
`NIGHT` and `STORM` only (the game's own page keeps those two a surprise too), Set By **Client**, and upload its two
64 x 64 icons from `art/achievements/`: `<API name>.png` (achieved) and `<API name>_locked.png` (the greyed one).
tools/make_medals.gd draws them (ui/medals.gd, the same pictures the game shows); `sheet.png` there is all of them
at once. **Publish** the changes when they're all in.

| API name | Display name | Description | How it's earned in the game |
| --- | --- | --- | --- |
| `FIRST_FISH` | First Bluefin | Land your first bluefin tuna. | A fish comes over the rail onto the deck of the boat you're on. |
| `GIANT` | Giant | Land a bluefin of 300 kg or more. | The same, a fish of 300 kg or more (they run 30 to 400). |
| `ONE_THROW` | One Throw | Stick a bluefin with the harpoon on the first throw. | Your throw sticks a fish nobody has missed yet. |
| `GRADE_ONE` | Number One | Sell a bluefin graded #1. | Heading in, a fish in the sale grades #1 (landed fast, bled and iced quick). |
| `TON` | A Ton Ashore | Sell 1,000 kg of bluefin, all told. | Kilos sold from the boat you're on, added up over every game. |
| `QUOTA` | Paid Up | Make a quota for the bank. | The quota's last day's sale makes it. |
| `THREE_QUOTAS` | Keeping Her | Make three quotas in one run. | The third quota in one run made. |
| `SPORTFISHER` | Bigger Boat | Buy the sportfisher. | Bought at the dock (your own career). |
| `LIVE_BAIT` | Live Bait | Jig a mackerel into the live well. | You jig one and the well takes it. |
| `CREW` | Many Hands | Land a bluefin with a friend aboard. | A fish lands while someone else is aboard your boat (your side, in Rivals). |
| `NIGHT` | After Dark | Land a bluefin after dusk. | A fish lands after the day's dusk. |
| `STORM` | Heavy Weather | Land a bluefin in a storm. | A fish lands while the weather's a storm. |
| `RIVALS_DAY` | Weighed In | Win a day in Rivals. | Your boat has the most pounds at a weigh-in. |
| `RIVALS_MATCH` | Best of Three | Win a Rivals match. | Your boat wins its second day. |
| `BOARDED` | Boarding Party | Leap aboard the rival boat out at sea. | You land on the other crew's deck, out at sea, in Rivals. |
| `OVERBOARD` | Man Overboard | Shove a rival over the side. | Someone on the other crew is in the sea within 2.5 s of your shove landing. |

## Icons

64 x 64 each, pixel style to match the game: draw them at 16 x 16 and scale up 4x, nearest neighbour (no smoothing).
The unachieved icon is the same picture in greys. The game's own icon generator (tools/make_icon.gd) shows the
palette.

## Testing before release

With the real app id in place (docs/steam_release.md), achievements can be cleared for testing from Steamworks
(Stats & Achievements, the test account's **Reset**), or from the Steam console: `steam://open/console`, then
`achievement_clear <appid> <API name>`.
