The project is set up and works: put PDFs in `input/`, run `docker compose run --rm docling`, and the Markdown appears in `output/`.

Files:
- `compose.yaml`: uses the `ghcr.io/docling-project/docling-serve-cpu:latest` image only for the `docling` command-line tool and the models already inside it. No server runs.
- `README.md`: how to use it, plus variants for converting one file or passing extra flags.
- `.gitignore`, `input/.gitkeep`, `output/.gitkeep`.

One assumption from my plan was wrong. This docling version needs a `convert` subcommand (`docling --help` lists `convert`, `options`, `convert-remote`), so the compose file uses `docling convert ...`.

**Test run:**
```sh
cp /usr/share/doc/shared-mime-info/shared-mime-info-spec.pdf input/sample.pdf
time docker compose run --rm -T docling
```
```
INFO	docling.document_converter: Finished converting document sample.pdf in 12.13 sec.
real	0m19.348s
```
- `output/sample.md` (39554 bytes) contained correct headings and text, and was owned by `oleh-deb-wl`.
- The run had `HF_HUB_OFFLINE=1` set, which confirms the models come from the image and nothing is downloaded.
- I deleted the sample PDF and the `.md` afterwards.

**Not tested:**
- The one-file form: `docker compose run --rm docling /data/input/report.pdf`.
- The extra-flags form: `docker compose run --rm docling --no-ocr /data/input`.

Both just pass arguments after the fixed `docling convert` options, so they should work, but run one of them to confirm.

Output files belong to user 1000:1000 unless you set `UID`/`GID`. That matches your user on this machine.
