#!/usr/bin/env python3
import html
import json
from pathlib import Path
import sys

review = Path(sys.argv[1])
manifest = json.loads((review / "attachments" / "manifest.json").read_text())
figures = []
for test in manifest:
    for attachment in test["attachments"]:
        filename = attachment["exportedFileName"]
        if not filename.endswith(".png"):
            continue
        name = attachment["suggestedHumanReadableName"]
        source = "Window capture" if "-screen" in name else "AppKit rendering"
        label = name.split("-appkit")[0].split("-screen")[0]
        destination = review / f"{label}.png"
        destination.write_bytes((review / "attachments" / filename).read_bytes())
        figures.append((label, f'<figure id="{html.escape(label)}"><figcaption>{html.escape(label)} <span>{source}</span></figcaption>'
                        f'<a href="{html.escape(destination.name)}"><img src="{html.escape(destination.name)}" alt="{html.escape(label)}"></a></figure>'))
figures.sort()
body = "\n".join(figure for _, figure in figures)
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Editor visual review</title><style>
:root { --bg:#141416; --ink:#eeeef0; --muted:#aaaab1; --line:#34343a; --font:system-ui,sans-serif; --radius:12px; }
* { box-sizing:border-box; } body { margin:32px auto; padding:0 24px; max-width:1200px; background:var(--bg); color:var(--ink); font:15px/1.5 var(--font); }
h1 { font-size:26px; } p,span { color:var(--muted); } figure { margin:32px 0 56px; } figcaption { margin-bottom:12px; } span { margin-left:12px; font-size:12px; }
img { display:block; max-width:100%; height:auto; border:1px solid var(--line); border-radius:var(--radius); } a { color:inherit; }
</style><h1>Editor visual review</h1><p>Native editor states at fixed sizes, using a deterministic fixture. Click an image for full resolution.</p>
<p>AppKit rendering works without Screen Recording permission. It verifies layout, but does not reproduce every WindowServer blur or shadow. Window capture is used when permission is already available.</p>
'''
(review / "index.html").write_text(page + body + "</html>\n")
print(f"{len(figures)} screenshots: {review / 'index.html'}")
if not figures:
    raise SystemExit("No screenshots were exported")
