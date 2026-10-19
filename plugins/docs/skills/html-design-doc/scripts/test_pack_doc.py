"""Self-check for pack_doc.py. Run: python -I test_pack_doc.py"""
import base64
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REFS = HERE.parent / 'references'
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE))
from pack_doc import strip_bodies  # noqa: E402
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==')
TOKEN = ':root { --iv-accent: #0f766e; }'

DOC_A = f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>A</title>
<link rel="stylesheet" href="style.css">
<style data-tokens>
{TOKEN}
</style>
</head>
<body>
<button type="button" class="toc-toggle" id="toc-toggle" hidden>目次</button>
<nav id="TOC"><ul><li><a href="#s1">一</a></li></ul></nav>
<main><section id="s1"><h2>一</h2><p>本文</p></section></main>
<script>document.getElementById('toc-toggle').hidden = false;</script>
</body>
</html>
"""

DOC_D = """<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>D</title>
<link rel="stylesheet" href="../refs/style.css">
<link rel="stylesheet" href="interactive.css">
</head>
<body>
<script src="interactive.js"></script>
<button type="button" class="toc-toggle" id="toc-toggle" hidden>目次</button>
<nav id="TOC"><ul><li><a href="#s1">一</a></li></ul></nav>
<main>
<section id="s1"><h2>一</h2>
<p>詳細は要件.mdを参照。</p>
<img src="seq.png" alt="図">
<fieldset><legend>案</legend>
<input type="radio" name="案" id="案-a" checked><label for="案-a">A</label>
<input type="radio" name="案" id="案-b"><label for="案-b">B</label>
</fieldset>
<div data-tabs>
<div role="tablist" hidden>
<button role="tab" id="t1" aria-controls="p1">1</button>
<button role="tab" id="t2" aria-controls="p2">2</button>
</div>
<section id="p1" role="tabpanel" aria-labelledby="t1" data-default>
<div data-tabs>
<div role="tablist" hidden><button role="tab" id="t3" aria-controls="p3">3</button></div>
<section id="p3" role="tabpanel" aria-labelledby="t3" data-default>x</section>
</div>
</section>
<section id="p2" role="tabpanel" aria-labelledby="t2">y</section>
</div>
</section>
</main>
<script>document.getElementById('toc-toggle').hidden = false;</script>
</body>
</html>
"""

BROKEN = {
    'C-2': ('href="#s1"', 'href="#nope"'),
    'C-11': ('</main>', '<div></main>'),
    'C-12': (' data-default>x', '>x'),
}


def run(path, *extra):
    r = subprocess.run([sys.executable, '-I', str(HERE / 'pack_doc.py'), str(path), *extra],
                       capture_output=True, text=True, encoding='utf-8')
    return r.returncode, r.stdout + r.stderr


def style_body(html):
    assert len(re.findall(r'<style\b', strip_bodies(html))) == 1, 'exactly one <style>'
    return html.split('<style>', 1)[1].split('</style>', 1)[0]


def no_link_or_src(html):
    bare = strip_bodies(html)
    return '<link' not in bare and '<script src' not in bare


def pack(tmp, name, html, *extra):
    src = tmp / f'{name}.html'
    src.write_text(html, encoding='utf-8')
    code, log = run(src, *extra)
    return code, log, tmp / f'{name}.packed.html'


def check_success(tmp):
    style_css = (REFS / 'style.css').read_text(encoding='utf-8').strip()
    code, log, a = pack(tmp, 'a', DOC_A)
    assert code == 0, log
    out = a.read_text(encoding='utf-8')
    body = style_body(out)
    assert style_css in body and body.rstrip().endswith(TOKEN), 'style.css then token block'
    assert no_link_or_src(out) and 'data-tokens' not in out

    code, log, d = pack(tmp, 'd', DOC_D, '--allow', '要件.md')
    assert code == 0, log
    out = d.read_text(encoding='utf-8')
    body = style_body(out)
    assert style_css in body and (REFS / 'interactive.css').read_text(encoding='utf-8').strip() in body
    assert no_link_or_src(out)
    assert (REFS / 'interactive.js').read_text(encoding='utf-8').strip() in out
    assert '<img src="data:image/png;base64,' in out
    assert (tmp / 'd.html').read_text(encoding='utf-8') == DOC_D, 'source is not rewritten'

    commented = DOC_A.replace('<link', '<!-- <link rel="stylesheet" href="style.css"> -->\n<link', 1)
    code, log, c = pack(tmp, 'comment', commented)
    assert code == 0 and style_css in style_body(c.read_text(encoding='utf-8')), log


def check_templates(tmp):
    for name, extra in (('template', []), ('interactive-template', ['--allow', 'interactive-components.md'])):
        out = tmp / f'{name}.out.html'
        code, log = run(REFS / f'{name}.html', '-o', str(out), *extra)
        assert code == 0, f'{name}: {log}'
        style_body(out.read_text(encoding='utf-8'))


def check_failures(tmp):
    cases = {k: DOC_D.replace(old, new, 1) for k, (old, new) in BROKEN.items()}
    cases['duplicate id'] = DOC_D.replace('</main>', '<p id="s1">dup</p></main>', 1)
    cases['  C-10'] = DOC_D.replace('</main>', '<div style="background:URL(HTTP://x/y.png)"></div></main>', 1)
    cases['must be used together'] = DOC_D.replace('<script src="interactive.js"></script>\n', '', 1)
    for name, html in cases.items():
        want = name if ' ' in name else f'  {name}'
        code, log, out = pack(tmp, f'bad{len(name)}{name[-2:]}', html, '--allow', '要件.md')
        assert code == 1 and want in log and not out.exists(), f'{name}: {code}\n{log}'
    srcset = DOC_A.replace('</main>', '<img src="data:," alt="" srcset="https://x/a.png 2x"></main>', 1)
    code, log, _ = pack(tmp, 'srcset', srcset)
    assert code == 1 and 'https://x/a.png' in log and '  C-3' in log, log
    code, log = run(tmp / 'd.html')                # .md mention without --allow
    assert code == 1 and 'C-5' in log and '要件.md' in log, log


def check_cli(tmp):
    code, log, out = pack(tmp, 'lint', DOC_A, '--lint-only')
    assert code == 0 and not out.exists(), log
    code, log = run(tmp / 'd.html', '-o', str(tmp / 'd.html'))
    assert code == 2, log
    code, log = run(tmp / 'a.html', '-o', str(tmp / 'no-such-dir' / 'x.html'))
    assert code == 2 and 'ERROR' in log and 'Traceback' not in log, log


if __name__ == '__main__':
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        (tmp / 'seq.png').write_bytes(PNG)
        check_success(tmp)
        check_templates(tmp)
        check_failures(tmp)
        check_cli(tmp)
    print('test_pack_doc: all checks passed')
