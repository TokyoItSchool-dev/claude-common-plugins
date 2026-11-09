"""Build a standalone workshop deck (and optionally its A4 worksheet) from a JSON spec.

Usage: python build.py <spec.json> <out/index.html> [<out/worksheet.html>]
Spec format: see references/interactions.md and example-spec.json. Text fields are inserted as HTML (trusted author input).
"""
import json
import math
import pathlib
import sys

D = pathlib.Path(__file__).parent
ROLE_ICON = {'hu': 'user', 'ai': 'bot', 'sys': 'server'}


def ico(n):
    return f'<svg class="ico" aria-hidden="true"><use href="#i-{n}"/></svg>'


def av(n, cls='av'):
    return f'<svg class="{cls}" aria-hidden="true"><use href="#il-{n}"/></svg>'


def ils(names):
    uses = ''.join(f'<use href="#il-{n}" x="{64 * i}" y="0" width="64" height="64"/>' for i, n in enumerate(names))
    return f'<svg class="il il{len(names)}" viewBox="0 0 {64 * len(names)} 64" aria-hidden="true">{uses}</svg>'


def timer(sec):
    return (f'<div class="chips"><button class="timer" type="button" data-sec="{sec}" aria-label="個人ワーク{sec // 60}分のタイマー（クリックで開始・一時停止）">'
            f'{ico("clock")}<span class="tm">{sec // 60}:{sec % 60:02d}</span></button></div>')


def slide(n, title, icon, body, cls='', extra=''):
    return (f'<section class="slide {cls}" data-n="{n}" aria-label="スライド{n} {title}"><div class="stage"><div class="inner">'
            f'<header class="hd"><span class="num">{n}</span><h2>{ico(icon)}{title}</h2>{extra}</header>\n{body}\n</div></div></section>\n')


def octagon(cx, cy, r):
    return ' '.join(f'{cx + r * math.cos(math.radians(22.5 + 45 * k)):.1f},{cy + r * math.sin(math.radians(22.5 + 45 * k)):.1f}' for k in range(8))


def flow(rows, aria, font=26, gap=24, row_gap=20, stop=None):
    """Before/After rows of boxes. step.kind: hu | ai | sys; step.em marks the human check (clickable, highlight key 'hu')."""
    cols = max(len(r['steps']) for r in rows)
    bw = (1200 - (cols - 1) * gap) / cols
    lh = round(font * 1.25)
    out, y, d, em_at = [], 0, 0.0, None
    for r in rows:
        key, label, sub, box_h = r['key'], r['label'], r.get('sub', ''), r.get('box_h', 130)
        sub_x = 16 + round(len(label) * 15.5) + 12
        pill_w = sub_x + len(sub) * 18 + 16
        out.append(f'<g class="hlb" data-hl-btn="{key}" role="button" tabindex="0" aria-pressed="false" aria-label="{label}（{sub}）を強調">'
                   f'<rect class="hlb-bg" x="0" y="{y}" width="{pill_w}" height="42" rx="12"/>'
                   f'<text class="rowl" x="16" y="{y + 31}" font-size="26">{label}</text><text class="rows" x="{sub_x}" y="{y + 30}" font-size="18">{sub}</text></g>')
        label_y = y
        y += 52
        steps = r['steps']
        for i, st in enumerate(steps):
            kind, lines, em, tag = st['kind'], st['lines'], st.get('em', False), st.get('tag', '')
            x = i * (bw + gap)
            attrs = f' data-hl="{key}{" hu" if em else ""}"'
            if em:
                attrs += ' data-hl-btn="hu" role="button" tabindex="0" aria-pressed="false" aria-label="人間（担当者）の確認を強調"'
                em_at = (x + bw / 2, label_y)
            top = y + 34
            ty = top + (box_h - 34 - 8 - len(lines) * lh) / 2 + font * 0.85
            texts = ''.join(f'<text x="{x + bw / 2:.1f}" y="{ty + j * lh:.1f}" font-size="{font}" text-anchor="middle">{ln}</text>' for j, ln in enumerate(lines))
            tag_t = f'<text class="rl" x="{x + 46:.1f}" y="{y + 31}" font-size="20">{tag}</text>' if tag else ''
            out.append(f'<g class="bx bx-{kind} fx-in{" em" if em else ""}" style="--d:{d:.2f}s" data-box{attrs}>'
                       f'<rect x="{x:.1f}" y="{y}" width="{bw:.1f}" height="{box_h}" rx="16"/>'
                       f'<use href="#i-{ROLE_ICON[kind]}" x="{x + 12:.1f}" y="{y + 10}" width="28" height="28" class="bi bi-{kind}"/>{tag_t}{texts}</g>')
            if i < len(steps) - 1:
                ay = y + box_h / 2
                out.append(f'<path data-hl="{key}" class="ar fx-draw" d="M{x + bw + 3:.1f} {ay:.0f} L{x + bw + gap - 4:.1f} {ay:.0f}" pathLength="1" marker-end="url(#ah)" style="--d:{d + .08:.2f}s"/>')
            d += .12
        y += box_h + row_gap
        d += .2
    if stop:
        assert em_at, 'flow.stop needs a step with "em": true'
        cx, ly = em_at
        out.append(f'<g class="stop fx-pulse" style="--d:1.1s" data-hl="after hu"><polygon points="{octagon(cx, ly + 21, 22)}"/>'
                   f'<text x="{cx:.1f}" y="{ly + 27}" font-size="16" text-anchor="middle" class="b">停止</text></g>'
                   f'<text x="{cx - 30:.1f}" y="{ly + 29}" font-size="21" text-anchor="end" class="stoptx fx-in" style="--d:1.1s" data-hl="after hu">{stop}</text>')
    return f'<svg class="fig flow" viewBox="0 0 1200 {y - row_gap}" role="group" aria-label="{aria}">' + ''.join(out) + '</svg>'


def cover(s):
    il = ''
    if s.get('il'):
        uses = ''.join(f'<use href="#il-{n}" x="{150 * i}" y="10" width="130" height="130"/>' for i, n in enumerate(s['il'][:2]))
        il = f'<svg class="cover-il fx-in" style="--d:.3s" viewBox="0 0 280 140" aria-hidden="true">{uses}</svg>\n'
    return (f'<section class="slide title" data-n="0" aria-label="表紙"><div class="stage"><div class="inner">\n{il}<div class="title-wrap">'
            f'<h1 class="fx-in">{s["title"]}</h1><p class="sub fx-in" style="--d:.15s">{s.get("sub", "")}</p>{s.get("body", "")}</div></div></div></section>\n')


def flow_slide(n, s):
    iss = s['issue']
    issue = f'<p class="issue fx-in">{ils(iss["il"])}<span><span class="tag tag-is">{ico("alert")}{iss.get("tag", "部門課題")}</span>{iss["text"]}</span></p>'
    fig = flow(s['rows'], s['aria'], s.get('font', 26), s.get('gap', 24), stop=s.get('stop'))
    return slide(n, s['title'], s['icon'], issue + '\n' + fig + s.get('after', ''), 'split-a')


def q_slide(n, s):
    times = s.get('times', ['2分', '2分', '1分'])
    icons = s.get('qicons', ['pin', 'repeat', 'trend'])
    qhtml = ''.join(f'<li class="frag"><span class="qb">{ico(icons[k])}Q{k + 1}</span><span class="qx">{q}</span><span class="qt">{ico("clock")}{times[k]}</span></li>'
                    for k, q in enumerate(s['qs']))
    last = len(s['ans']) - 1
    dl = ''.join(f'<div class="{"hl" if k == last else ""}"><dt>{dt}</dt><dd>{dd}</dd></div>' for k, (dt, dd) in enumerate(s['ans']))
    adds = ''.join(f'<li>{a}</li>' for a in s['adds'])
    closing = f'<div class="closing frag"><p class="ask">{s["closing"]}</p></div>' if s.get('closing') else ''
    body = (f'<p class="sublead">{s.get("sublead", "個人ワーク5分（Q1〜Q3）→ 共有2分")}</p>\n<ol class="qs big">{qhtml}</ol>\n'
            f'<div class="qgrid">\n<section class="ans frag"><h3>{ico("bulb")}回答例</h3><dl class="ws-dl one">{dl}</dl></section>\n'
            f'<div class="rcol"><section class="rw frag"><h3>{ico("pencil")}書き直し</h3><div class="bad"><b>{ico("x")}悪い例</b><span>{s["bad"]}</span></div>'
            f'<div class="down" aria-hidden="true">▼</div><div class="add"><b>{ico("plus")}書き足す</b><ul>{adds}</ul></div></section>{closing}</div>\n</div>')
    return slide(n, s['title'], s['icon'], body, 'qslide', timer(s.get('timer', 300)))


def build_deck(spec):
    out = []
    for n, s in enumerate(spec['slides']):
        t = s['type']
        if t == 'cover':
            assert n == 0, 'cover must be the first slide'
            out.append(cover(s))
        elif t == 'flow':
            out.append(flow_slide(n, s))
        elif t == 'q':
            out.append(q_slide(n, s))
        elif t == 'html':
            out.append(slide(n, s['title'], s['icon'], s['body'], s.get('cls', ''), s.get('extra', '')))
        else:
            raise ValueError(f'slide {n}: unknown type {t!r}')
    css = (D / 'deck.css').read_text(encoding='utf-8') + spec.get('css', '')
    js = (D / 'deck.js').read_text(encoding='utf-8')
    sprite = (D / 'sprite.svg').read_text(encoding='utf-8')
    return f'''<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{spec['title']}</title>
<style>
{css}</style>
</head>
<body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
{sprite}</defs></svg>
<main id="deck">
{''.join(out)}</main>
<div class="hud" id="counter" aria-live="polite"></div>
<div class="progress" id="progress"></div>
<script>
{js}</script>
</body>
</html>
'''


def build_worksheet(spec):
    """Rows = q slides with a 'theme'; the Q1/Q2 texts in each row header are the slide texts verbatim."""
    ws = spec['worksheet']
    sprite = (D / 'sprite.svg').read_text(encoding='utf-8')
    cols = ws['cols']
    total = sum(c['w'] for c in cols) + ws.get('row_w', 17) + ws.get('pick_w', 4.5)
    pct = lambda w: f'{w / total * 100:.2f}%'
    colgroup = f'<col style="width:{pct(ws.get("row_w", 17))}">' + ''.join(f'<col style="width:{pct(c["w"])}">' for c in cols) + f'<col style="width:{pct(ws.get("pick_w", 4.5))}">'

    def head(c):
        icon = f'<svg class="wi" aria-hidden="true"><use href="#i-{c["icon"]}"/></svg>' if c.get('icon') else ''
        q = f'<span class="qn">{c["q"]}</span>' if c.get('q') else ''
        small = f'<small>{c["small"]}</small>' if c.get('small') else ''
        return icon + q + c['head'] + small

    top, sub, i = [], [], 0
    while i < len(cols):
        g = cols[i].get('group')
        if g:
            k = 0
            while i + k < len(cols) and cols[i + k].get('group') == g:
                k += 1
            top.append(f'<th colspan="{k}">{g}</th>')
            sub.extend(f'<th>{head(c)}</th>' for c in cols[i:i + k])
            i += k
        else:
            top.append(f'<th rowspan="2">{head(cols[i])}</th>')
            i += 1
    two = bool(sub)
    rs = ' rowspan="2"' if two else ''
    thead = (f'<tr><th{rs}>テーマ<small>（各行の Q1・Q2 の問い）</small></th>' + ''.join(t if two else t.replace(' rowspan="2"', '') for t in top)
             + f'<th{rs}>選んだ<br>1件</th></tr>' + (f'<tr>{"".join(sub)}</tr>' if two else ''))
    rows = ''
    for s in spec['slides']:
        th = s.get('theme')
        if s['type'] != 'q' or not th:
            continue
        qs = ''.join(f'<small class="tq"><b>Q{k + 1}</b> {q}</small>' for k, q in enumerate(s['qs'][:2]))
        rows += (f'<tr><th class="rowh"><svg class="ti" aria-hidden="true"><use href="#i-{th["icon"]}"/></svg><b>{th["label"]}</b><small>{th.get("sub", "")}</small>{qs}</th>'
                 + '<td class="w"></td>' * len(cols) + '<td class="pick">○</td></tr>\n')
    check = ''.join(f'<li>{c}</li>' for c in ws['check'])
    fair = ''.join(f'<div class="l"><b>{f}</b></div>' for f in ws.get('fair', ['誰に', '何を', 'いつまでに']))
    css = (D / 'worksheet.css').read_text(encoding='utf-8')
    return f'''<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{ws['title']}</title>
<style>
{css}</style>
</head>
<body>
<svg class="sprite" aria-hidden="true" focusable="false"><defs>{sprite}</defs></svg>
<button class="print-btn" onclick="window.print()">印刷する</button>
<main class="sheet">
  <header>
    <div>
      <h1><svg class="hi" aria-hidden="true"><use href="#i-pencil"/></svg>{ws['title']}</h1>
      <p class="inst">{ws['inst']}</p>
    </div>
    <div class="who">氏名<span></span>所属<span></span></div>
  </header>
  <table>
    <colgroup>{colgroup}</colgroup>
    <thead>{thead}</thead>
    <tbody>
{rows}    </tbody>
  </table>
  <div class="lower">
    <section class="box check"><h2><svg class="wi" aria-hidden="true"><use href="#i-check"/></svg>{ws.get('check_title', '自己点検（選んだ1行）')}</h2><ul>{check}</ul></section>
    <section class="box instr"><h2><svg class="wi" aria-hidden="true"><use href="#i-flag"/></svg>{ws.get('fair_title', '部下への検討指示（清書）')}</h2>{fair}</section>
  </div>
  <footer>{ws.get('footer', '')}</footer>
</main>
</body>
</html>
'''


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    spec = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
    html = build_deck(spec)
    pathlib.Path(sys.argv[2]).write_text(html, encoding='utf-8', newline='\n')
    print('deck', sys.argv[2], 'slides', len(spec['slides']))
    if len(sys.argv) == 4:
        assert 'worksheet' in spec, 'spec has no "worksheet" section'
        pathlib.Path(sys.argv[3]).write_text(build_worksheet(spec), encoding='utf-8', newline='\n')
        print('worksheet', sys.argv[3])


if __name__ == '__main__':
    main()
