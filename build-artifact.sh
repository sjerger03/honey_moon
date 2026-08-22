#!/bin/bash
# Bundles index.html + style.css + fonts/ + photos/ into a single self-contained
# artifact.html (everything inlined as data URIs), for publishing to a private
# Claude Artifact link. The Artifact CSP blocks external file loads, so this is
# the only way to get this site onto that link — index.html + style.css stay
# the source of truth for everything else (GitHub Pages, local viewing, etc).
set -euo pipefail
cd "$(dirname "$0")"

python3 - <<'PY'
import re, base64, pathlib

root = pathlib.Path(__file__).parent if "__file__" in dir() else pathlib.Path(".")
html = pathlib.Path("index.html").read_text()
css = pathlib.Path("style.css").read_text()

def b64_file(path):
    return base64.b64encode(pathlib.Path(path).read_bytes()).decode()

# Inline fonts as data URIs
css = css.replace(
    'url("fonts/playfair-600.woff2")',
    f'url(data:font/woff2;base64,{b64_file("fonts/playfair-600.woff2")})'
)
css = css.replace(
    'url("fonts/nunitosans-variable.woff2")',
    f'url(data:font/woff2;base64,{b64_file("fonts/nunitosans-variable.woff2")})'
)

# Inline photo backgrounds as data URIs
for name in ["hero", "tilekona", "tileisland", "tileritz", "tilehome", "kihei"]:
    css = css.replace(
        f'url("photos/{name}.jpg")',
        f'url(data:image/jpeg;base64,{b64_file(f"photos/{name}.jpg")})'
    )

# Swap the stylesheet link for an inline <style> block
html = html.replace(
    '<link rel="stylesheet" href="style.css">',
    f"<style>\n{css}\n</style>"
)

# Inline the couple photo
html = html.replace(
    'src="photos/couple.jpg"',
    f'src="data:image/jpeg;base64,{b64_file("photos/couple.jpg")}"'
)

pathlib.Path("artifact.html").write_text(html)
size = pathlib.Path("artifact.html").stat().st_size
print(f"artifact.html rebuilt: {size:,} bytes")
PY
