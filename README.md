# docling PDF/HTML → Markdown

Converts PDF and HTML files to Markdown with the `docling` CLI from the
`ghcr.io/docling-project/docling-serve-cpu` image. Models are inside the image;
the run is offline (`HF_HUB_OFFLINE=1`).

## Use

1. Copy PDFs or HTML files into `input/` (other formats are skipped; see
   `--from` in `compose.yaml`).
2. Run:
   ```sh
   ./convert.sh
   ```
   It converts only files that have no `output/<name>.md` yet, or whose `.md`
   is older than the source. Docling itself has no skip option.
3. Read `output/<name>.md`.

To force a re-convert of one file, delete its `.md` or `touch` the source.
To convert everything regardless: `docker compose run --rm docling`.

The first run pulls the image (several GB).

## Variants

One file:
```sh
docker compose run --rm docling /data/input/report.pdf
```

Extra `docling convert` flags go before the path:
```sh
docker compose run --rm docling --no-ocr --image-export-mode placeholder /data/input
```

All flags:
```sh
docker compose run --rm --entrypoint docling docling convert --help
```

## Notes

- Output files are owned by `UID:GID` (default `1000:1000`). Override:
  `UID=$(id -u) GID=$(id -g) docker compose run --rm docling`.
- CPU only.
- `foo.pdf` and `foo.html` both write `output/foo.md`; give sources distinct
  names.
