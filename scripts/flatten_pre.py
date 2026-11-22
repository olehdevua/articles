"""Replace the content of every <pre> with its plain text.

docling's HTML backend joins the text of each child tag of a <pre> with spaces
and strips it, so syntax-highlighted code (<span>s + <br>) loses indentation and
blank lines and gains spaces between tokens. A <pre> that holds plain text with
real newlines is kept as is.

The text is also dedented: docling strips the block, which removes the first
line's indentation only, and excerpts from inside a function start indented.

Usage: python flatten_pre.py OUT_DIR SRC.html [SRC.html ...]
Writes OUT_DIR/<same file name> for each source.
"""

import sys
import textwrap
from pathlib import Path

from bs4 import BeautifulSoup


def flatten(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for pre in soup.find_all("pre"):
        for br in pre.find_all("br"):
            br.replace_with("\n")
        pre.string = textwrap.dedent(pre.get_text())
    return str(soup)


def main() -> None:
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    for src in map(Path, sys.argv[2:]):
        (out_dir / src.name).write_text(
            flatten(src.read_text(encoding="utf-8")), encoding="utf-8"
        )


if __name__ == "__main__":
    main()
