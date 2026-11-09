"""Usage: python check.py <file.html> [forbidden.txt]
Static checks: unclosed/misnested tags (html.parser), node --check on every inline <script>,
no external URLs, no forbidden terms (one term per line in forbidden.txt). Exit 1 on any failure."""
import os
import re
import subprocess
import sys
import tempfile
from html.parser import HTMLParser

# HTML void elements plus SVG elements that the generator always writes empty
VOID = {'meta', 'br', 'hr', 'img', 'input', 'link', 'source', 'area', 'base', 'col', 'embed', 'wbr',
        'use', 'path', 'rect', 'circle', 'ellipse', 'line', 'polygon', 'polyline', 'stop'}


class Tags(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack, self.err = [], []

    def handle_starttag(self, tag, attrs):
        if tag not in VOID:
            self.stack.append((tag, self.getpos()))

    def handle_startendtag(self, tag, attrs):
        pass

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if self.stack and self.stack[-1][0] == tag:
            self.stack.pop()
        else:
            self.err.append((tag, self.getpos(), self.stack[-1] if self.stack else None))


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    src = open(sys.argv[1], encoding='utf-8').read()
    p = Tags()
    p.feed(src)
    p.close()
    ok = not p.err and not p.stack
    print('tags', 'ok' if ok else f'errors={p.err[:5]} unclosed={p.stack[:5]}')

    urls = [u for u in re.findall(r'(?:https?:)?//[\w.-]+\.[a-z]{2,}[^\s"\')<]*', src) if 'www.w3.org' not in u]
    print('external urls', urls[:5] or 'none')
    ok &= not urls

    for k, js in enumerate(re.findall(r'<script>(.*?)</script>', src, re.S)):
        with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as f:
            f.write(js)
        r = subprocess.run(['node', '--check', f.name], capture_output=True, text=True)
        os.unlink(f.name)
        print(f'script{k} node --check', 'ok' if r.returncode == 0 else r.stderr.strip())
        ok &= r.returncode == 0

    if len(sys.argv) == 3:
        text = re.sub(r'<[^>]+>', '', src)
        terms = [w.strip() for w in open(sys.argv[2], encoding='utf-8').read().split('\n') if w.strip()]
        hits = {w: text.count(w) for w in terms if w in text}
        print('forbidden terms', hits or 'none')
        ok &= not hits
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
