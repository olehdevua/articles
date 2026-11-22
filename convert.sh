#!/usr/bin/env bash
# Convert only new or changed files in input/ (no .md in output/, or .md older
# than the source). docling itself has no skip-existing option.
set -euo pipefail
cd "$(dirname "$0")"
shopt -s nullglob

todo=()
for f in input/*.pdf input/*.html; do
  md="output/$(basename "${f%.*}").md"
  [[ -e "$md" && "$md" -nt "$f" ]] || todo+=("/data/$f")
done

(( ${#todo[@]} )) || { echo "nothing to convert"; exit 0; }
printf 'converting: %s\n' "${todo[@]#/data/input/}"
docker compose run --rm -T docling "${todo[@]}"
