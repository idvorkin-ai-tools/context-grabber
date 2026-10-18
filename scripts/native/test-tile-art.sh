#!/usr/bin/env bash
# #304, #299: compiles the asset catalog with actool, as the build does, and reads the result with assetutil: every
# home tile has its drawn art with no background of its own (so it blends into the tile, light or dark), the dark
# objects carry a dark-mode variant, and the strip's poodle and quill are template images (so they take the item's colour).
set -uo pipefail
out=$(mktemp -d "${TMPDIR:-/tmp}/tile-art.XXXXXX")
trap 'rm -rf "$out"' EXIT
xcrun actool native/App/Assets.xcassets --compile "$out" --platform iphoneos --minimum-deployment-target 17.0 \
  --app-icon AppIcon --output-partial-info-plist "$out/p.plist" >/dev/null || { echo "FAIL tile-art: actool"; exit 1; }
xcrun assetutil --info "$out/Assets.car" | python3 -c '
import json, sys
renditions = {}
for a in json.load(sys.stdin):
    if "Name" in a:
        renditions.setdefault(a["Name"], []).append(a)
assets = {n: r[0] for n, r in renditions.items()}
# The home tiles, Settings included (HomeRow.all minus the daily strip, plus HomeRow.settings).
tiles = "call today gym_timer breathe places think_a_card exercise_analyzer workout_supermix cockpit eulogy_song eulogy recent random report_problem settings inbox".split()
bad = [f"tile-{t}: missing" for t in tiles if f"tile-{t}" not in assets]
for t in tiles:
    a = assets.get(f"tile-{t}")
    if a and (a.get("PixelWidth") != a.get("PixelHeight") or a.get("PixelWidth", 0) < 168):
        w, h = a.get("PixelWidth"), a.get("PixelHeight")
        bad.append(f"tile-{t}: {w}x{h}, not square or under 168 px")
    if any(r.get("Opaque") is not False for r in renditions.get(f"tile-{t}", [])):
        bad.append(f"tile-{t}: opaque, so it carries a background square instead of sitting on the tile")
# Near-black objects vanish on the dark tile, so these carry a light-rimmed dark variant (Codex on #349). Exercise
# Analyzer shows the Exercise Analyzer app icon, teal (#366), which reads on either tile.
for t in ("workout_supermix", "report_problem"):
    if not any(r.get("Appearance") == "UIAppearanceDark" for r in renditions.get(f"tile-{t}", [])):
        bad.append(f"tile-{t}: no dark-mode variant, so the dark object disappears on the dark tile")
for g in ("strip-poodle", "strip-quill"):
    if assets.get(g, {}).get("Template Mode") != "template":
        bad.append(f"{g}: not a template image")
for b in bad: print("FAIL tile-art:", b)
if not bad: print("ok   tile-art: %d transparent tiles (2 with a dark variant) and 2 strip glyphs" % len(tiles))
sys.exit(1 if bad else 0)
'
status=$?
# #354: each tile's object fills its picture (at least 88% of the longer side), so the art fills the tile.
command -v magick >/dev/null || { echo "FAIL tile-art: magick (ImageMagick) not installed"; exit 1; }
for f in native/App/Assets.xcassets/tile-*.imageset/tile-*.png; do
  case $f in *-dark.png) continue ;; esac
  read -r side box < <(magick "$f" -alpha extract -threshold 8% -format "%w %@" info:)
  if [[ ! $side =~ ^[0-9]+$ || ! $box =~ ^[0-9]+x[0-9]+\+ ]]; then
    echo "FAIL tile-art: ${f##*/}: magick could not measure it"; status=1; continue
  fi
  w=${box%%x*}; rest=${box#*x}; h=${rest%%+*}; long=$(( w > h ? w : h ))
  if (( long * 100 < side * 88 )); then
    echo "FAIL tile-art: ${f##*/}: its object spans $long of $side px, so the art leaves the tile empty"; status=1
  fi
done
exit $status
