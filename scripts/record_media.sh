#!/usr/bin/env bash
# Renders the README/website GIFs from the example app.
#
# Frames are rendered by Flutter's test renderer from the real example code
# at a fixed 25 fps (frame-accurate, no screen-recorder drops), then encoded
# to optimized GIFs with ffmpeg. Output: screenshots/*.gif
source "$(dirname "$0")/lib/common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: ./scripts/record_media.sh   (requires ffmpeg)"
  exit 0
fi

require flutter ffmpeg
FLUTTER_ROOT="$(cd "$(dirname "$(command -v flutter)")/.." && pwd -P)"
fonts="$FLUTTER_ROOT/bin/cache/artifacts/material_fonts"
[[ -f "$fonts/Roboto-Regular.ttf" ]] || fail "Roboto fonts not found in $fonts"

frames="$(mktemp -d "${TMPDIR:-/tmp}/expandable_animation_media.XXXXXX")"
trap 'rm -rf "$frames"' EXIT
out="$REPO_ROOT/screenshots"
mkdir -p "$out"

step "Rendering frames"
(cd "$EXAMPLE_DIR" && MEDIA_OUTPUT_DIR="$frames" MEDIA_FONTS_DIR="$fonts" \
  run flutter test test/media/record_media_test.dart)

step "Encoding GIFs"
for dir in "$frames"/*/; do
  name="$(basename "$dir")"
  ffmpeg -v error -y -framerate 25 -i "$dir/%04d.png" \
    -vf "fps=16,scale=320:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$out/$name.gif"
  info "$(du -h "$out/$name.gif" | cut -f1)  screenshots/$name.gif"
done
ok "GIFs written to screenshots/"
