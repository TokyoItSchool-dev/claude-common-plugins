#!/usr/bin/env python3
"""Embed local image files referenced in an HTML file as base64 data URIs.

Usage:
    python embed_images.py <path-to-html-file>

Scans the given HTML file for src="..." attributes pointing to local
image files (png/jpg/jpeg/gif/svg), resolves them relative to the HTML
file's own directory, base64-encodes each one, and rewrites the file in
place with data: URIs. Already-embedded data: URIs are left untouched.
Fails loudly (nonzero exit) if any referenced image file is missing.
"""
import base64
import re
import sys
from pathlib import Path

MIME_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
}

SRC_PATTERN = re.compile(r'src="([^"]+\.(?:png|jpg|jpeg|gif|svg))"', re.IGNORECASE)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python embed_images.py <path-to-html-file>", file=sys.stderr)
        return 1

    html_path = Path(sys.argv[1]).resolve()
    if not html_path.is_file():
        print(f"ERROR: HTML file not found: {html_path}", file=sys.stderr)
        return 1

    base_dir = html_path.parent
    with open(html_path, "rb") as f:
        content = f.read().decode("utf-8")

    missing = []
    replacements = {}

    for match in SRC_PATTERN.finditer(content):
        rel_path = match.group(1)
        if rel_path.startswith("data:"):
            continue
        if rel_path in replacements:
            continue
        img_path = (base_dir / rel_path).resolve()
        if not img_path.is_file():
            missing.append(rel_path)
            continue
        ext = img_path.suffix.lower()
        mime = MIME_TYPES.get(ext, "application/octet-stream")
        size_before = img_path.stat().st_size
        with open(img_path, "rb") as img_f:
            encoded = base64.b64encode(img_f.read()).decode("ascii")
        data_uri = f"data:{mime};base64,{encoded}"
        replacements[rel_path] = data_uri
        print(f"embedded: {rel_path}  ({size_before} bytes -> {len(encoded)} b64 chars, {mime})")

    if missing:
        print("ERROR: missing image file(s) referenced in HTML:", file=sys.stderr)
        for rel_path in missing:
            print(f"  - {rel_path}", file=sys.stderr)
        return 1

    for rel_path, data_uri in replacements.items():
        content = content.replace(f'src="{rel_path}"', f'src="{data_uri}"')

    with open(html_path, "w", encoding="utf-8", newline="") as f:
        f.write(content)

    print(f"done: {len(replacements)} image(s) embedded into {html_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
