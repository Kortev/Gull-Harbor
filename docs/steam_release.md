# Releasing Bluefin on Steam

What's done in the project, and what only you can do in Steamworks (it needs your account, your money and your
signature). Work down the second list in order; most steps have a wait in them (Valve's reviews), so start early.

## Done in the project

- [x] **Icon**: a pixel bluefin (tools/make_icon.gd draws it): `icon.svg` (the project's), `icon.ico` (16 to
  256 px: the exe's, set in export_presets.cfg and embedded by Godot's own exporter, no rcedit needed), and PNGs
  from 16 to 1024 px in `art/icon/`.
- [x] **Version**: `core/version.gd` (`VERSION`, 1.0.0), shown small in the title's bottom right corner, and the exe's
  file and product version, company and copyright (export_presets.cfg). tests/title_test checks they agree.
- [x] **Achievements**: 16, in core/achievements.gd; set on Steam when it's running, kept in
  `user://achievements.cfg` either way (and handed to Steam next time it's on). A pixel toast when one's earned.
  The list for Steamworks, word for word: docs/steam_achievements.md. tests/achievements_test.
- [x] **Credits** on the title (CREDITS), and `THIRD_PARTY_NOTICES.txt` (every license the game owes a notice to:
  Godot and all its parts, GodotSteam, the Steamworks redistributable, the CC0 sources), written by
  tools/third_party.gd and put beside the exe by tools/release.sh.
- [x] **Without Steam**: the game starts and plays with Steam closed, or not installed (one line in the log, the
  join code instead of Steam lobbies, achievements kept locally).
- [x] **Broken files**: a settings, career or achievements file that won't read, or holds nonsense, is the defaults;
  no crash.
- [x] **The window**: borderless on the whole screen the first time, then whatever was picked in SETTINGS
  (windowed size, borderless, fullscreen, vsync, frame cap), remembered. Alt-tab lets the mouse go and puts up the
  pause card.
- [x] **Release build**: `GODOT=<path to the console exe> tools/release.sh` makes `export/` (Bluefin.exe, the two
  Steam dlls, the notices). That folder is what's uploaded.

## For you to do in Steamworks

### 1. Become a Steamworks partner and pay the app fee
- [ ] Sign up at https://partner.steamgames.com (the company or your own name, bank and tax details; the tax
  interview takes a while to be checked).
- [ ] Pay the Steam Direct fee (US$100 per app, recouped after $1,000 in sales). You get the **App ID**.

### 2. Put the real App ID in the game (replacing 480, Valve's Spacewar test app)
- [ ] `core/steam_link.gd`: `const APP_ID := 480` becomes your App ID.
- [ ] `steam_appid.txt` (the project root, for running from the editor): your App ID in place of 480.
- [ ] `core/steam_link.gd`'s comment about Spacewar and `TAG` (Spacewar's lobbies are shared with every test game;
  yours are only Bluefin's, so the tag stays harmless).
- [ ] Rich presence (optional): the game doesn't set any yet. Steam shows "Playing Bluefin" without it.

### 3. The store page (Store Admin)
- [ ] Description (short and long), tags, genre (Simulation, Sports, Casual; Multiplayer: Online Co-op, Online PvP,
  2-4 players), system requirements (Windows 10+, 64-bit; a GPU with Vulkan; tested on an RX 7600 XT).
- [ ] Graphics, exactly these sizes (all PNG or JPG; keep the pixel look: draw small, scale up nearest):

  | Asset | Size (px) |
  | --- | --- |
  | Header capsule | 920 x 430 |
  | Small capsule | 462 x 174 |
  | Main capsule | 1232 x 706 |
  | Vertical capsule | 748 x 896 |
  | Page background (optional) | 1438 x 810 |
  | Library capsule | 600 x 900 |
  | Library header | 920 x 430 |
  | Library hero | 3840 x 1240 |
  | Library logo | 1280 wide or 720 tall, transparent PNG |
  | Client icon | 32 x 32 (.ico / .jpg: art/icon/icon_32.png) |
  | Community icon | 184 x 184 (art/icon/icon_256.png scaled to fit) |
  | Screenshots | at least 5, 1920 x 1080 |

- [ ] A trailer (strongly recommended).
- [ ] Content survey (mature content: none) and the age ratings questionnaire (IARC, free in Steamworks).
- [ ] Submit the store page for review (a few days). It must be live as "Coming Soon" for at least 2 weeks before
  release.

### 4. Achievements (App Admin > Stats & Achievements)
- [ ] Enter the 16 from docs/steam_achievements.md (API names exactly as written), each with its two 64 x 64 icons.
- [ ] Publish.

### 5. Depots and the build upload
- [ ] App Admin > SteamPipe > Depots: the default Windows depot (note its Depot ID, App ID + 1 usually). Set the
  launch option (Installation > General): executable `Bluefin.exe`, OS Windows.
- [ ] Download the Steamworks SDK (partner site) for `tools/ContentBuilder` and `steamcmd`.
- [ ] Make the build: `GODOT=<path> tools/release.sh`, then copy `export/` into ContentBuilder's `content/`.
- [ ] An `app_build_<AppID>.vdf` pointing at it (the SDK's `scripts/` has a template: AppID, the depot, ContentRoot,
  `"FileMapping" { "LocalPath" "*" "DepotPath" "." "recursive" "1" }`), then:
  `steamcmd +login <your build account> +run_app_build ..\scripts\app_build_<AppID>.vdf +quit`
- [ ] App Admin > SteamPipe > Builds: set the uploaded build live on the `default` branch (or a `beta` branch to
  test first). Install it through Steam on a second machine and play a co-op and a Rivals game over Steam.
- [ ] Bump `core/version.gd` and export_presets.cfg's file/product version for every build after this one.

### 6. Pricing and release
- [ ] Pricing (App Admin > Pricing): your base price; Valve suggests the rest. A launch discount is set up as a
  discount event, not here.
- [ ] Release checklist (the partner site's own): store page approved, build reviewed (submit the build for review:
  a few days), the "Coming Soon" two weeks done.
- [ ] Press **Release**.

## Still worth a look before release

- `audio/fish/*.wav` (the drag, the gulls, the splashes): where they came from isn't written down anywhere. If any
  aren't made here or CC0, credit them in THIRD_PARTY_NOTICES (tools/third_party.gd) and the title's CREDITS.
- The company name on the exe and in the credits is `Kortev` (core/version.gd `STUDIO`, export_presets.cfg
  `company_name` and `copyright`): change it in both if the store lists a studio name.
