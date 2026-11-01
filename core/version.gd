extends RefCounted
## The game's version, the one place it's kept: shown small in the title's corner (ui/title.gd), and the same in the
## exe's file and product version (export_presets.cfg's application/file_version and product_version, with a fourth
## ".0": tests/title_test.tscn checks they agree). Bump it here and there for each build uploaded to Steam.

const VERSION := "1.0.0"
## Who made it: the exe's company name and copyright, and the credits (ui/title.gd).
const STUDIO := "Kortev"
const YEAR := "2026"
