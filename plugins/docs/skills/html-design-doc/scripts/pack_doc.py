#!/usr/bin/env python3
"""Pack an html-design-doc source page into one standalone HTML file.

Usage:
    python pack_doc.py SOURCE.html [-o OUT.html] [--lint-only] [--allow NAME ...]

Steps: embed local <img> files as data: URIs, lint against 手順C items 1-5 and
10-12, inline style.css / interactive.css / interactive.js from ../references
together with the optional <style data-tokens> block, assert the output, write
<stem>.packed.html next to the source (or -o). The source is never rewritten.
Exit 0: written (or clean with --lint-only). Exit 1: lint or pack error,
nothing written. Exit 2: usage or I/O error.
"""
import argparse
import base64
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote

REFS = Path(__file__).resolve().parent.parent / 'references'
MERMAID = 'https://cdn.jsdelivr.net/npm/mermaid@11/'
FONTS = 'https://fonts.googleapis.com/'
EXTERNAL = ('http:', 'https:', '//')
SKIP_REF = EXTERNAL + ('mailto:', 'tel:')
SKILL_CSS = {'style.css', 'interactive.css'}
MIME = {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
        '.gif': 'image/gif', '.svg': 'image/svg+xml'}
VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link',
        'meta', 'source', 'track', 'wbr'}
OPTIONAL_END = {'p', 'li', 'dt', 'dd', 'tr', 'td', 'th', 'thead', 'tbody',
                'tfoot', 'option'}
IMG_SRC = re.compile(r'(<img\b[^>]*?\ssrc=")([^"]*)(")', re.I)
TOKENS = re.compile(r'<style\b[^>]*\bdata-tokens\b[^>]*>(.*?)</style>[ \t]*\r?\n?', re.I | re.S)
LINK = re.compile(r'<link\b[^>]*\bhref="(?:[^"]*/)?(style|interactive)\.css"[^>]*>[ \t]*\r?\n?', re.I)
SCRIPT_JS = re.compile(r'<script\b[^>]*\bsrc="(?:[^"]*/)?interactive\.js"[^>]*>\s*</script>', re.I)
MODULE_IMPORT = re.compile(r'(?:\bfrom|\bimport)\s*\(?\s*["\']([^"\']+)')
MD_EXT = re.compile(r'\.md(?![A-Za-z0-9])', re.I)


class Doc(HTMLParser):
    """Element tree (dicts with a parent link), ids, CSS text, body text."""

    def __init__(self):
        super().__init__()
        self.elements, self.stack, self.scripts = [], [], []
        self.ids, self.dup_ids = {}, []
        self.css, self.text = [], []          # (line, text)

    def handle_starttag(self, tag, attrs):
        line = self.getpos()[0]
        el = {'tag': tag, 'attrs': dict(attrs), 'line': line, 'body': '',
              'parent': self.stack[-1] if self.stack else None}
        self.elements.append(el)
        i = el['attrs'].get('id')
        if i is not None and i in self.ids:
            self.dup_ids.append((i, self.ids[i]['line'], line))
        elif i is not None:
            self.ids[i] = el
        if el['attrs'].get('style'):
            self.css.append((line, el['attrs']['style']))
        if tag == 'script':
            self.scripts.append(el)
        if tag not in VOID:
            self.stack.append(el)

    def handle_endtag(self, tag):
        for k in range(len(self.stack) - 1, -1, -1):
            if self.stack[k]['tag'] == tag:
                del self.stack[k:]
                return

    def handle_data(self, data):
        cur = self.stack[-1] if self.stack else {'tag': ''}
        if cur['tag'] == 'script':
            cur['body'] += data
        elif cur['tag'] == 'style':
            self.css.append((self.getpos()[0], data))
        else:
            self.text.append((self.getpos()[0], data))


class TagBalance(HTMLParser):
    def __init__(self):
        super().__init__()
        self.open, self.errors = [], []

    def handle_starttag(self, tag, attrs):
        if tag not in VOID:
            self.open.append((tag, self.getpos()[0]))

    def handle_startendtag(self, tag, attrs):    # <img … />: opened and closed at once
        pass

    def handle_endtag(self, tag):
        if tag not in [t for t, _ in self.open]:
            self.errors.append((self.getpos()[0], f'</{tag}> closes nothing open'))
            return
        while self.open[-1][0] != tag:           # HTML closes these implicitly
            t, ln = self.open.pop()
            if t not in OPTIONAL_END:
                self.errors.append((ln, f'<{t}> is not closed before </{tag}>'))
        self.open.pop()

    def close(self):
        super().close()
        self.errors += [(ln, f'<{t}> is not closed') for t, ln in self.open
                        if t not in OPTIONAL_END]


def parse(text):
    doc = Doc()
    doc.feed(text)
    doc.close()
    return doc


def basename(url):
    return url.split('?')[0].split('#')[0].rsplit('/', 1)[-1].lower()


def closest(el, pred):
    while el is not None and not pred(el):
        el = el['parent']
    return el


def line_at(line, text, pos):
    return line + text.count('\n', 0, pos)


def is_external(url):
    return url.lower().startswith(EXTERNAL)


def embed_images(src, base_dir):
    """Return (src with local images as data: URIs, embedded paths)."""
    embedded = []

    def repl(m):
        path = m[2]
        mime = MIME.get(Path(path).suffix.lower())
        file = base_dir / unquote(path)
        if path.startswith('data:') or is_external(path) or not mime or not file.is_file():
            return m[0]                       # check_images reports what is left
        embedded.append(path)
        data = base64.b64encode(file.read_bytes()).decode('ascii')
        return f'{m[1]}data:{mime};base64,{data}{m[3]}'
    return IMG_SRC.sub(repl, src), embedded


def check_toc(doc):
    nav = doc.ids.get('TOC')
    if nav is None or nav['tag'] != 'nav':
        return [('ERROR', 1, 'no <nav id="TOC">', 'C-2')]
    sections = {i for i, el in doc.ids.items() if el['tag'] == 'section'}
    return [('ERROR', el['line'], f'TOC link {el["attrs"]["href"]}: no <section> with that id', 'C-2')
            for el in doc.elements
            if (el['attrs'].get('href') or '').startswith('#')
            and closest(el, lambda e: e is nav)
            and unquote(el['attrs']['href'][1:]) not in sections]


def check_css(line, text, item):
    text = re.sub(r'/\*.*?\*/', lambda m: '\n' * m[0].count('\n'), text, flags=re.S)
    out = [('ERROR', line_at(line, text, m.start()), f'{m[0].strip()}: @import is not allowed', item)
           for m in re.finditer(r'@import\b[^;]*', text, re.I)]
    for m in re.finditer(r'url\(\s*["\']?([^"\')\s]*)', text, re.I):
        if not m[1].lower().startswith(('#', 'data:')):
            out.append(('ERROR', line_at(line, text, m.start()), f'url({m[1]}): only #id or data:', item))
    return out


def check_modules(doc, item):
    out = []
    for el in doc.scripts:
        if (el['attrs'].get('type') or '').lower() != 'module':
            continue
        for m in MODULE_IMPORT.finditer(el['body']):
            if not m[1].startswith(MERMAID):
                out.append(('ERROR', line_at(el['line'], el['body'], m.start()),
                            f'module script imports {m[1]}; only {MERMAID} is allowed', item))
    return out


def external_urls(attrs):
    out = []
    for name, value in attrs.items():
        value = value or ''
        parts = ([p.split()[0] for p in value.split(',') if p.split()] if name == 'srcset'
                 else [value.strip()])
        out += [(name, url) for url in parts if is_external(url)]
    return out


def check_local(el, item):
    tag, a, line = el['tag'], el['attrs'], el['line']
    href, src = a.get('href') or '', a.get('src') or ''
    if tag == 'link' and href and not is_external(href) and basename(href) not in SKILL_CSS:
        return [('ERROR', line, f'<link href="{href}">: only style.css and interactive.css', item)]
    if tag == 'script' and src and not is_external(src) and basename(src) != 'interactive.js':
        return [('ERROR', line, f'<script src="{src}">: only interactive.js', item)]
    return []


def check_external(doc, d_mode):
    item, out, fonts = ('C-10' if d_mode else 'C-3'), [], 0
    for el in doc.elements:
        tag, line = el['tag'], el['line']
        for name, url in external_urls(el['attrs']):
            if tag == 'link' and name == 'href' and d_mode and url.lower().startswith(FONTS):
                fonts += 1
                if fonts > 1:
                    out.append(('ERROR', line, 'more than one fonts.googleapis.com <link>', item))
            elif tag == 'a' and name == 'href':
                out.append(('WARN', line, f'external hyperlink {url}', item))
            else:
                out.append(('ERROR', line, f'external {url} in {name}=', item))
        out += check_local(el, item)
    for line, text in doc.css:
        out += check_css(line, text, item)
    return out + check_modules(doc, item)


def check_scripts(doc, d_mode):
    n = len(doc.scripts)
    module = any((s['attrs'].get('type') or '').lower() == 'module' for s in doc.scripts)
    want = 2 + module if d_mode else 2
    if n > want or (d_mode and n < want):
        line = doc.scripts[-1]['line'] if doc.scripts else 1
        mode = 'D' if d_mode else 'A'
        return [('ERROR', line, f'{n} <script> elements; 手順{mode} allows {want}', 'C-10' if d_mode else 'C-3')]
    return []


def check_pairing(doc, d_mode):
    links = [(basename(e['attrs'].get('href') or ''), e['line'])
             for e in doc.elements if e['tag'] == 'link']
    first = {}
    for name, line in links:
        first.setdefault(name, line)
    out = []
    if ('interactive.css' in first) != d_mode:
        out.append(('ERROR', first.get('interactive.css', 1),
                    'interactive.css and <script src="interactive.js"> must be used together', 'C-1'))
    if 'interactive.css' in first and first.get('style.css', sys.maxsize) > first['interactive.css']:
        out.append(('ERROR', first['interactive.css'],
                    'interactive.css is linked before (or without) style.css', 'C-1'))
    return out


def check_images(doc):
    return [('ERROR', el['line'], f'<img src="{(el["attrs"].get("src") or "")[:60]}"> is not a data: URI', 'C-4')
            for el in doc.elements
            if el['tag'] == 'img' and not (el['attrs'].get('src') or '').startswith('data:')]


def md_names(text):
    """(offset, name) per .md mention: the ASCII file name before .md, else the word run (Japanese names)."""
    out, prev = [], 0
    for m in MD_EXT.finditer(text):
        before = text[prev:m.start()]
        stem = re.search(r'[A-Za-z0-9_./-]*$', before)[0] or re.search(r'\w*$', before)[0]
        prev = m.end()
        if stem:
            out.append((m.start() - len(stem), stem + m[0]))
    return out


def check_md(doc, allow):
    hits = [(line_at(line, text, pos), name)
            for line, text in doc.text for pos, name in md_names(text)]
    hits += [(el['line'], basename(el['attrs']['href'])) for el in doc.elements
             if basename(el['attrs'].get('href') or '').endswith('.md')]
    return [('ERROR', line, f'body names {name}', 'C-5') for line, name in hits
            if not any(name.lower().endswith(a.lower()) for a in allow)]


def sister_ids(path, page, cache):
    """ids of a sister page, or an error message string."""
    if path not in cache:
        try:
            cache[path] = parse(path.read_text(encoding='utf-8')).ids
        except FileNotFoundError:
            cache[path] = f'file {page} not found next to the source'
        except (OSError, UnicodeDecodeError) as e:
            cache[path] = f'cannot read {page}: {e.__class__.__name__}'
    return cache[path]


def ref_error(attr, ref, ids, base_dir, cache):
    if attr != 'href':
        return None if ref in ids else f'{attr}="{ref}" points at no id'
    if ref == '#':
        return 'href="#" points nowhere'
    if not ref or ref.lower().startswith(SKIP_REF) or '#' not in ref:
        return None
    page, frag = ref.split('#', 1)
    frag = unquote(frag)
    if not page:
        return None if frag in ids else f'href="{ref}" points at no id'
    if not page.lower().endswith('.html'):
        return None
    found = sister_ids(base_dir / unquote(page), page, cache)
    if isinstance(found, str):
        return f'href="{ref}": {found}'
    return None if frag in found else f'href="{ref}": no id "{frag}" in {page}'


def check_refs(doc, base_dir):
    out, cache = [], {}
    for el in doc.elements:
        for attr in ('aria-controls', 'aria-labelledby', 'href'):
            value = el['attrs'].get(attr)
            if value is None:
                continue
            for ref in (value.split() if attr != 'href' else [value.strip()]):
                msg = ref_error(attr, ref, doc.ids, base_dir, cache)
                if msg:
                    out.append(('ERROR', el['line'], msg, 'C-12'))
    return out + [('ERROR', again, f'duplicate id "{i}", first at line {first}', 'C-12')
                  for i, first, again in doc.dup_ids]


def check_tabs(doc):
    def is_group(e):
        return 'data-tabs' in e['attrs']
    out = []
    for group in filter(is_group, doc.elements):
        tabs = [t for t in doc.elements
                if t['attrs'].get('role') == 'tab' and closest(t, is_group) is group]
        panels = [doc.ids[i] for t in tabs
                  for i in (t['attrs'].get('aria-controls') or '').split() if i in doc.ids]
        n = sum('data-default' in p['attrs'] for p in panels)
        if n != 1:
            out.append(('ERROR', group['line'], f'data-tabs: {n} default panels', 'C-12'))
    return out


def check_radios(doc):
    owner, reported, loose, out = {}, set(), None, []
    for r in doc.elements:
        a = r['attrs']
        if r['tag'] != 'input' or (a.get('type') or '').lower() != 'radio' or not a.get('name'):
            continue
        fs = closest(r, lambda e: e['tag'] == 'fieldset')
        if fs is None and loose is None:
            loose = r['line']
        name = a['name']
        owner.setdefault(name, fs)
        if owner[name] is not fs and name not in reported:
            reported.add(name)
            out.append(('ERROR', r['line'], f'radio name "{name}" is used by two groups', 'C-12'))
    if loose is not None:
        out.append(('WARN', loose, 'radio outside a <fieldset>: its name group is not checked', 'C-12'))
    return out


def lint(src, base_dir, allow):
    doc = parse(src)
    d_mode = any(basename(s['attrs'].get('src') or '') == 'interactive.js' for s in doc.scripts)
    balance = TagBalance()
    balance.feed(src)
    balance.close()
    findings = (check_toc(doc) + check_external(doc, d_mode) + check_scripts(doc, d_mode)
                + check_pairing(doc, d_mode) + check_images(doc) + check_md(doc, allow)
                + [('ERROR', ln, msg, 'C-11') for ln, msg in balance.errors]
                + check_refs(doc, base_dir) + check_tabs(doc) + check_radios(doc))
    return sorted(findings, key=lambda f: f[1])


def read_ref(name):
    return (REFS / name).read_text(encoding='utf-8')


def mask_comments(text):
    """Same length as text, with every <!--…--> turned into spaces."""
    return re.sub(r'<!--.*?-->', lambda m: ' ' * len(m[0]), text, flags=re.S)


def inline_assets(src):
    masked = mask_comments(src)
    m = TOKENS.search(masked)
    tokens = src[m.start(1):m.end(1)].strip('\r\n') if m else ''
    if not re.sub(r':root\s*\{\s*\}|/\*.*?\*/|\s', '', tokens, flags=re.S):
        tokens = ''                           # an empty token block is dropped
    links = list(LINK.finditer(masked))       # the font <link> does not match
    if not links:
        raise ValueError('no <link href="style.css"> in the source')
    parts = [read_ref(k[1].lower() + '.css').rstrip('\n') for k in links] + ([tokens] if tokens else [])
    style = '<style>\n' + '\n'.join(parts) + '\n</style>\n'
    script = '<script>\n' + read_ref('interactive.js') + '</' 'script>'
    edits = [(k.start(), k.end(), style if i == 0 else '') for i, k in enumerate(links)]
    edits += [(k.start(), k.end(), script) for k in SCRIPT_JS.finditer(masked)]
    edits += [(m.start(), m.end(), '')] if m else []
    pieces, pos = [], 0
    for start, end, text in sorted(edits):
        pieces += [src[pos:start], text]
        pos = end
    out = ''.join(pieces) + src[pos:]
    assert_output(out)
    return out


def strip_bodies(html):
    """html without comments and without the text inside <script> and <style>."""
    bare = re.sub(r'<!--.*?-->', '', html, flags=re.S)
    return re.sub(r'(<(script|style)\b[^>]*>).*?</\2>', r'\1', bare, flags=re.S | re.I)


def assert_output(out):
    bare = strip_bodies(out)
    if re.search(r'<script\b[^>]*\ssrc\s*=', bare, re.I):
        raise ValueError('a <script src> is left in the output')
    links = re.findall(r'<link\b[^>]*>', bare, re.I)
    font = re.compile(r'\bhref\s*=\s*["\']' + re.escape(FONTS), re.I)
    if len(links) > 1 or any(not font.search(k) for k in links):
        raise ValueError('only one fonts.googleapis.com <link> may stay in the output')
    if len(re.findall(r'<style\b', bare, re.I)) != 1:
        raise ValueError('the output must have exactly one <style>')


def parse_args(argv):
    p = argparse.ArgumentParser(description='Pack an html-design-doc source page.')
    p.add_argument('source', type=Path)
    p.add_argument('-o', dest='out', type=Path, help='output path (default: <stem>.packed.html)')
    p.add_argument('--lint-only', action='store_true', help='run the checks, write nothing')
    p.add_argument('--allow', action='append', default=None, metavar='NAME',
                   help='a .md file name the body may mention (repeatable)')
    return p.parse_args(argv)


def write_output(src, out_path, embedded):
    try:
        out = inline_assets(src)
    except (ValueError, OSError) as e:
        print(f'ERROR  {e}  C-1')
        return 1
    try:
        with open(out_path, 'w', encoding='utf-8', newline='') as f:
            f.write(out)
    except OSError as e:
        print(f'ERROR  cannot write {out_path}: {e}', file=sys.stderr)
        return 2
    for path in embedded:
        print(f'embedded {path}')
    print(out_path)
    return 0


def main(argv=None):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    args = parse_args(argv)
    src_path = args.source.resolve()
    out_path = (args.out or src_path.with_name(src_path.stem + '.packed.html')).resolve()
    if out_path == src_path:
        print('ERROR  the output path equals the source; pass another -o', file=sys.stderr)
        return 2
    try:
        with open(src_path, encoding='utf-8', newline='') as f:
            src, embedded = embed_images(f.read(), src_path.parent)
    except (OSError, UnicodeDecodeError) as e:
        print(f'ERROR  cannot read {src_path}: {e}', file=sys.stderr)
        return 2
    findings = lint(src, src_path.parent, args.allow or [])
    for level, line, msg, item in findings:
        print(f'{level} line {line}  {msg}  {item}')
    errors = sum(f[0] == 'ERROR' for f in findings)
    if errors:
        print(f'{errors} error(s); nothing written')
        return 1
    return 0 if args.lint_only else write_output(src, out_path, embedded)


if __name__ == '__main__':
    sys.exit(main())
