#!/bin/bash
# Bundles each page (index.html, volcanoes.html, ...) + style.css + fonts/ +
# photos/ into self-contained artifact-*.html files (everything inlined as data
# URIs), for publishing to private Claude Artifact links. The Artifact CSP
# blocks external file loads, so this is the only way to get these pages onto
# that link — the plain .html files + style.css stay the source of truth for
# everything else (GitHub Pages, local viewing, etc).
set -euo pipefail
cd "$(dirname "$0")"

python3 - <<'PY'
import re, base64, pathlib

def b64_file(path):
    return base64.b64encode(pathlib.Path(path).read_bytes()).decode()

base_css = pathlib.Path("style.css").read_text()

pages = {
    "index.html": "artifact.html",
    "volcanoes.html": "artifact-volcanoes.html",
    "maui.html": "artifact-maui.html",
    "ritz.html": "artifact-ritz.html",
    "lahaina.html": "artifact-lahaina.html",
}

for source, output in pages.items():
    if not pathlib.Path(source).exists():
        continue
    html = pathlib.Path(source).read_text()
    css = base_css

    # Fonts are used on every page; always inline them.
    for match in set(re.findall(r'url\("(fonts/[\w-]+\.woff2)"\)', css)):
        css = css.replace(f'url("{match}")', f'url(data:font/woff2;base64,{b64_file(match)})')

    # Only inline photos whose bg-* class is actually referenced in this page's HTML,
    # so each bundle only carries the images it needs.
    used_classes = set(re.findall(r'\b(bg-[\w-]+)\b', html))
    for cls, filename in re.findall(r'\.(bg-[\w-]+)\s*\{\s*background-image:\s*url\("(photos/[\w-]+\.jpg)"\)', css):
        if cls in used_classes:
            css = css.replace(f'url("{filename}")', f'url(data:image/jpeg;base64,{b64_file(filename)})')

    html = html.replace('<link rel="stylesheet" href="style.css">', f"<style>\n{css}\n</style>")
    pathlib.Path(output).write_text(html)
    size = pathlib.Path(output).stat().st_size
    print(f"{output} rebuilt: {size:,} bytes")
PY
