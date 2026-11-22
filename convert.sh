#!/usr/bin/env bash
# Convert only new or changed files in input/ (no .md in output/, or .md older
# than the source). docling itself has no skip-existing option.
set -euo pipefail
cd "$(dirname "$0")"
shopt -s nullglob

todo=()
mds=()
for f in input/*.pdf input/*.html; do
  md="output/$(basename "${f%.*}").md"
  [[ -e "$md" && "$md" -nt "$f" ]] && continue
  todo+=("/data/$f")
  mds+=("$md")
done

(( ${#todo[@]} )) || { echo "nothing to convert"; exit 0; }
printf 'converting: %s\n' "${todo[@]#/data/input/}"
docker compose run --rm -T docling "${todo[@]}"

# Point table-of-contents links at in-document headings.
# A list item "N. [Title](<anything>#frag)" whose Title is a heading in the same
# file becomes "N. [Title](#Title-Slug)": case kept, punctuation dropped,
# whitespace -> "-". Saved web pages link the TOC to the site URL instead.
for md in "${mds[@]}"; do
  [[ -e "$md" ]] || continue
  perl -CSD -0777 -i -pe '
    my %heading;
    $heading{$1} = 1 while /^#{1,6}[ \t]+(.+?)[ \t]*$/mg;
    s{^([ \t]*\d+\.[ \t]+\[([^\]\n]+)\])\([^)\s#]*#[^)\s]*\)[ \t]*$}{
      my ($item, $title) = ($1, $2);
      if ($heading{$title}) {
        (my $slug = $title) =~ s/[^\w\s-]//g;
        $slug =~ s/\s+/-/g;
        "$item(#$slug)";
      } else { $& }
    }mge;
  ' "$md"
done
