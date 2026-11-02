"""diagsvg — 「青系フラット」の図解をSVGで描くための部品ライブラリ。

前半（ヘッダー/フッター/箱/線/アイコン）は図の分野を問わず使える汎用部品。
「UML固有の記号」の節（socket, diamond_end, artifact, component_box, node3d, classbox,
lollipop, start/final, badge など）は references/uml.md の記法ルールと対で使う。

使い方:
    d = Doc("UML 配置図")          # 1448x1086 キャンバス、ヘッダー付き
    d.box(...); d.edge([...]); d.icon("gear", x, y)
    d.footer("説明文。")
    d.save("out.svg")

レイヤー順: bg（枠・帯・フッター） → edges → nodes → over（ラベル・接続点など線の上に乗るもの）
"""
import math
from xml.sax.saxutils import escape

INK = "#13294b"      # 線・文字
TEXT = "#1b2a44"
BAND = "#a9d3fb"     # 見出し帯
BODY = "#eef6ff"     # 箱の本体
SOFT = "#dcecfd"     # 立体の側面・上面
ACCENT = "#0b6fd8"   # UMLロゴ・番号
RULE = "#2a8cf0"
FOOT = "#e6f1fd"
FONT = '"Noto Sans CJK JP","Noto Sans JP","Hiragino Sans","Yu Gothic",sans-serif'


def text_width(s, fs):
    """日本語混じり文字列の幅をざっくり見積もる（中央寄せ用）。"""
    w = 0.0
    for ch in s:
        if ch == " ":
            w += 0.3
        elif ord(ch) < 0x2E80:
            w += 0.6
        else:
            w += 1.0
    return w * fs


class Doc:
    def __init__(self, title, w=1448, h=1086, subtitle="オンライン書店システム例", title_fs=72):
        self.w, self.h = w, h
        self.bg, self.edges, self.nodes, self.over = [], [], [], []
        self._header(title, subtitle, title_fs)

    # ---------- 低レベル ----------
    def raw(self, s, layer="nodes"):
        getattr(self, layer).append(s)

    def text(self, x, y, s, fs=24, weight=700, anchor="start", fill=TEXT, layer="over", bg=False):
        if bg:  # 線の上のラベルは白い下地を敷く（paint-order は効かない処理系がある）
            tw = text_width(s, fs)
            x0 = {"start": x, "middle": x - tw / 2, "end": x - tw}[anchor]
            getattr(self, layer).append(
                f'<rect x="{x0-6:.0f}" y="{y-fs*0.95:.0f}" width="{tw+12:.0f}" height="{fs*1.3:.0f}" fill="#fff"/>')
        getattr(self, layer).append(
            f'<text x="{x}" y="{y}" font-size="{fs}" font-weight="{weight}" text-anchor="{anchor}" '
            f'fill="{fill}">{escape(s)}</text>')

    # ---------- ヘッダー / フッター ----------
    def _header(self, title, subtitle, fs=72):
        # 「UML 配置図」のように空白で区切ると、前半をアクセント色で表示する
        lead, rest = title.split(" ", 1) if " " in title else ("", title)
        tw = (text_width(lead, fs) * 1.05 + 20 if lead else 0) + text_width(rest, fs)
        total = 80 + 22 + tw
        x0 = (self.w - total) / 2
        self.nodes.append(f'<use href="#logo" x="{x0:.0f}" y="16" width="80" height="90"/>')
        head = f'<tspan fill="{ACCENT}">{escape(lead)}</tspan> ' if lead else ""
        self.nodes.append(
            f'<text x="{x0+102:.0f}" y="{16+fs*0.98:.0f}" font-size="{fs}" font-weight="900" fill="{TEXT}">'
            f'{head}{escape(rest)}</text>')
        self.text(self.w / 2, 148, subtitle, fs=42, anchor="middle", fill="#2b3446", layer="nodes")
        self.nodes.append(f'<line x1="90" y1="161" x2="{self.w-90}" y2="161" stroke="{RULE}" stroke-width="3"/>')

    def footer(self, note, y=1007, h=66):
        self.bg.append(f'<rect x="50" y="{y}" width="{self.w-100}" height="{h}" rx="22" fill="{FOOT}"/>')
        tw = text_width(note, 27)
        total = 50 + 30 + tw
        x0 = (self.w - total) / 2
        cy = y + h / 2
        self.bg.append(f'<use href="#bulb" x="{x0:.0f}" y="{cy-24:.0f}" width="48" height="48"/>')
        self.bg.append(f'<line x1="{x0+66:.0f}" y1="{cy-16}" x2="{x0+66:.0f}" y2="{cy+16}" stroke="#9aa8bb" stroke-width="2"/>')
        self.text(x0 + 90, cy + 10, note, fs=27, weight=500, layer="bg")

    # ---------- 箱 ----------
    def box(self, x, y, w, h, label=None, band=32, rx=14, fs=28, sw=3, shadow=True):
        """上部に水色帯を持つ角丸箱（状態・クラス見出し等）。"""
        f = ' filter="url(#shadow)"' if shadow else ""
        self.nodes.append(
            f'<g{f}><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{BODY}"/>'
            f'<path d="M{x},{y+band} V{y+rx} a{rx},{rx} 0 0 1 {rx},-{rx} H{x+w-rx} a{rx},{rx} 0 0 1 {rx},{rx} V{y+band} Z" fill="{BAND}"/>'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="none" stroke="{INK}" stroke-width="{sw}"/></g>')
        if label:
            self.text(x + w / 2, y + band + (h - band) / 2 + fs * 0.36, label, fs=fs, anchor="middle", layer="nodes")

    def plain(self, x, y, w, h, rx=10, fill=BODY, sw=3, shadow=True, dash=None):
        f = ' filter="url(#shadow)"' if shadow else ""
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.nodes.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{INK}" stroke-width="{sw}"{f}{d}/>')

    def folder(self, x, y, w, h, label=None, icon=None, tab=(96, 22), fs=30, sw=3, band=0, title=None,
               icon_dx=None, label_dx=None, fill=BODY):
        """左上にタブを持つ箱（パッケージ・コンポーネント・成果物）。"""
        tw, th = tab
        self.nodes.append(
            f'<g filter="url(#shadow)"><path d="M{x},{y} V{y-th+4} a4,4 0 0 1 4,-4 H{x+tw-4} a4,4 0 0 1 4,4 V{y} Z" '
            f'fill="{BAND}" stroke="{INK}" stroke-width="{sw*0.7:.1f}"/>'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="5" fill="{fill}" stroke="{INK}" stroke-width="{sw}"/></g>')
        if band:
            self.nodes.append(f'<rect x="{x+sw/2}" y="{y+sw/2}" width="{w-sw}" height="{band}" fill="{BAND}" opacity="0.45"/>')
        if title:
            self.text(x + 30, y + band * 0.68, title, fs=fs, layer="nodes")
        cy = y + h / 2
        if icon:
            ix = x + (icon_dx if icon_dx is not None else 70)
            self.icon(icon, ix, cy, s=1.0)
        if label:
            lx = x + (label_dx if label_dx is not None else 120)
            self.text(lx, cy + fs * 0.36, label, fs=fs, layer="nodes")

    def node3d(self, x, y, w, h, title, d=28, band=70, fs=28, stereotype=None):
        """UML配置図のノード（立方体）。前面+上面+側面の3枚。"""
        self.nodes.append(
            f'<g filter="url(#shadow)">'
            f'<polygon points="{x},{y} {x+d},{y-36} {x+w+d},{y-36} {x+w},{y}" fill="{BAND}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
            f'<polygon points="{x+w},{y} {x+w+d},{y-36} {x+w+d},{y+h-36} {x+w},{y+h}" fill="{BAND}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#fff" stroke="{INK}" stroke-width="3"/>'
            f'<rect x="{x+1.5}" y="{y+1.5}" width="{w-3}" height="{band}" fill="{BODY}"/></g>')
        if stereotype:
            self.stereo(x + w / 2, y + 26, stereotype, fs=18)
            self.text(x + w / 2, y + 58, title, fs=fs, anchor="middle", layer="nodes")
        else:
            self.text(x + w / 2, y + band / 2 + fs * 0.36, title, fs=fs, anchor="middle", layer="nodes")

    def classbox(self, x, y, w, name, attrs, ops, head=46, row=30, pad=14, fs=22):
        """クラス：名前・属性・操作の3区画。高さは行数から自動計算。"""
        ha = pad * 2 + row * len(attrs) - 8
        ho = pad * 2 + row * len(ops) - 8
        h = head + ha + ho
        self.box(x, y, w, h, band=head, rx=6, fs=28)
        self.text(x + w / 2, y + head * 0.72, name, fs=28, anchor="middle", layer="nodes")
        self.nodes.append(f'<line x1="{x}" y1="{y+head+ha}" x2="{x+w}" y2="{y+head+ha}" stroke="{INK}" stroke-width="2"/>')
        self.nodes.append(f'<line x1="{x}" y1="{y+head}" x2="{x+w}" y2="{y+head}" stroke="{INK}" stroke-width="2"/>')
        for i, a in enumerate(attrs):
            self.text(x + 20, y + head + pad + 16 + i * row, a, fs=fs, weight=400, layer="nodes")
        for i, o in enumerate(ops):
            self.text(x + 20, y + head + ha + pad + 16 + i * row, o, fs=fs, weight=400, layer="nodes")
        return h

    def ellipse(self, cx, cy, rx, ry, label, fs=26):
        self.nodes.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{BODY}" stroke="{ACCENT}" stroke-width="3" filter="url(#shadow)"/>')
        self.text(cx, cy + fs * 0.36, label, fs=fs, anchor="middle", layer="nodes")

    # ---------- 線 ----------
    def edge(self, pts, arrow=True, dash=False, sw=3, start_dot=False, end_dot=False, r=7):
        """pts: [(x,y),...] または 'M.. H.. V..' のパス文字列。直角折れは H/V で。
        arrow: True/"open"=開いた矢じり（遷移・制御フロー・依存・誘導可能性・応答）
               "filled"=塗り三角（シーケンス図の同期メッセージ専用） / False=なし"""
        d = pts if isinstance(pts, str) else "M" + " L".join(f"{x},{y}" for x, y in pts)
        m = {"filled": ' marker-end="url(#arrowf)"', False: "", None: ""}.get(arrow, ' marker-end="url(#arrow)"')
        da = ' stroke-dasharray="8 7"' if dash else ""
        self.edges.append(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{sw}"{m}{da}/>')
        if not isinstance(pts, str):
            if start_dot:
                self.dot(*pts[0], r=r)
            if end_dot:
                self.dot(*pts[-1], r=r)

    def dot(self, x, y, r=7, fill=INK):
        self.over.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>')

    def lollipop(self, x, y, r=13):
        """提供インターフェース（白丸）。線の上に乗せる。"""
        self.over.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" stroke="{INK}" stroke-width="3"/>')

    def head(self, x, y, angle=0, s=14):
        """線の途中に置く矢じり（関連の誘導可能性など）。angle: 0=右,90=下"""
        self.over.append(f'<path d="M{s/2},0 L{-s/2},{-s*0.5} L{-s/2},{s*0.5} Z" fill="{INK}" transform="translate({x},{y}) rotate({angle})"/>')

    def start(self, x, y, r=27):
        self.over.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{INK}"/>')

    def final(self, x, y, r=33):
        self.over.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" stroke="{INK}" stroke-width="3"/><circle cx="{x}" cy="{y}" r="{r-8}" fill="{INK}"/>')

    def diamond(self, cx, cy, w=64, h=46):
        self.nodes.append(f'<polygon points="{cx},{cy-h/2} {cx+w/2},{cy} {cx},{cy+h/2} {cx-w/2},{cy}" fill="{BAND}" stroke="{ACCENT}" stroke-width="3" stroke-linejoin="round"/>')

    def badge(self, x, y, n, r=16):
        """シーケンス図の番号丸。"""
        self.over.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{ACCENT}"/>')
        self.text(x, y + (8 if n < 10 else 6), str(n), fs=22 if n < 10 else 17, anchor="middle", fill="#fff")

    def icon(self, name, cx, cy, s=1.0, layer="over"):
        sz = 56 * s
        getattr(self, layer).append(f'<use href="#i-{name}" x="{cx-sz/2:.1f}" y="{cy-sz/2:.1f}" width="{sz:.1f}" height="{sz:.1f}"/>')


    # ---------- UML固有の記号 ----------
    def socket(self, x, y, toward="right", r=21, sw=3):
        """要求インターフェースの受け口（半円）。toward=開口が向く方向（提供側の白丸の方）。"""
        rot = {"right": 0, "down": 90, "left": 180, "up": 270}[toward]
        self.over.append(f'<path d="M0,{-r} A{r},{r} 0 0 0 0,{r}" fill="none" stroke="{INK}" stroke-width="{sw}" '
                         f'transform="translate({x},{y}) rotate({rot})"/>')

    def diamond_end(self, x, y, angle=0, filled=True, s=26):
        """関連端のひし形（filled=コンポジション / False=集約）。(x,y)=ひし形の先端、angle=線が伸びる向き。"""
        f = INK if filled else "#fff"
        self.over.append(f'<path d="M0,0 L{s/2},{-s*0.32} L{s},0 L{s/2},{s*0.32} Z" fill="{f}" stroke="{INK}" stroke-width="2.5" '
                         f'transform="translate({x},{y}) rotate({angle})"/>')

    def stereo(self, x, y, s, fs=19, anchor="middle", layer="nodes"):
        """ステレオタイプ «…»（ギュメ）を小さめの文字で。"""
        self.text(x, y, f"«{s}»", fs=fs, weight=500, anchor=anchor, fill="#3a4a66", layer=layer)

    def artifact(self, x, y, w, h, label, stereotype="artifact", icon=None, fs=26, sfs=18, tdx=96, idx=50):
        """配置図の成果物／実行環境：矩形＋ステレオタイプ＋右上に成果物アイコン。"""
        self.plain(x, y, w, h, rx=6, sw=2.5)
        if stereotype == "artifact":
            self.icon("artifact", x + w - 22, y + 22, s=0.5, layer="nodes")
        tx = x + (tdx if icon else w / 2)
        anchor = "start" if icon else "middle"
        self.stereo(tx, y + h / 2 - 8, stereotype, fs=sfs, anchor=anchor)
        if icon:
            self.icon(icon, x + idx, y + h / 2, s=0.95 if idx >= 50 else 0.75, layer="nodes")
        self.text(tx, y + h / 2 + 24, label, fs=fs, anchor=anchor, layer="nodes")

    def component_box(self, x, y, w, h, label, stereotype=None, icon="component", fs=26):
        """コンポーネント：タブの無い矩形＋右上のコンポーネントアイコン（«component» の代わり）。"""
        self.plain(x, y, w, h, rx=6, sw=3)
        self.nodes.append(f'<rect x="{x+1.5}" y="{y+1.5}" width="{w-3}" height="10" fill="{BAND}"/>')
        if icon:
            self.icon(icon, x + w - 30, y + 34, s=0.62, layer="nodes")
        cy = y + h / 2 + 6
        if stereotype:
            self.stereo(x + (w - 30) / 2, cy - 14, stereotype, fs=18)
            self.text(x + (w - 30) / 2, cy + 18, label, fs=fs, anchor="middle", layer="nodes")
        else:
            self.text(x + (w - 30) / 2, cy + 9, label, fs=fs, anchor="middle", layer="nodes")

    # ---------- 出力 ----------
    def save(self, path):
        body = "\n".join(self.bg + self.edges + self.nodes + self.over)
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" width="{self.w}" height="{self.h}">
<defs>
<style>text{{font-family:{FONT};}}</style>
<marker id="arrow" viewBox="0 0 14 14" refX="13" refY="7" markerWidth="16" markerHeight="16" markerUnits="userSpaceOnUse" orient="auto"><path d="M1,1 L13,7 L1,13" fill="none" stroke="{INK}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></marker>
<marker id="arrowf" viewBox="0 0 12 12" refX="11" refY="6" markerWidth="13" markerHeight="13" markerUnits="userSpaceOnUse" orient="auto"><path d="M0,0 L12,6 L0,12 Z" fill="{INK}"/></marker>
<filter id="shadow" x="-10%" y="-10%" width="120%" height="140%"><feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="{INK}" flood-opacity="0.12"/></filter>
{ICONS}
</defs>
<rect width="{self.w}" height="{self.h}" fill="#fff"/>
{body}
</svg>'''
        open(path, "w", encoding="utf-8").write(svg)


def _gear():
    pts = []
    for i in range(16):
        a = math.pi * 2 * i / 16
        r = 25 if (i // 1) % 2 == 0 else 19
        for da in (-0.13, 0.13):
            pts.append(f"{28+r*math.cos(a+da):.1f},{28+r*math.sin(a+da):.1f}")
    return f'<polygon points="{" ".join(pts)}" fill="{INK}"/><circle cx="28" cy="28" r="7.5" fill="#fff"/>'


S = f'fill="none" stroke="{INK}" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"'
ICONS = "\n".join([
    # ロゴ（青い立方体）
    f'<symbol id="logo" viewBox="0 0 80 90"><path d="M40 5 L74 24 L74 66 L40 85 L6 66 L6 24 Z" fill="#cfe6ff" stroke="{ACCENT}" stroke-width="7" stroke-linejoin="round"/><path d="M6 24 L40 43 L74 24 M40 43 L40 85" fill="none" stroke="{ACCENT}" stroke-width="7" stroke-linejoin="round"/></symbol>',
    f'<symbol id="bulb" viewBox="0 0 48 48"><g fill="none" stroke="{RULE}" stroke-width="2.6" stroke-linecap="round"><path d="M17,30 a11,11 0 1 1 14,0 v5 h-14 z"/><path d="M19,39 h10 M21,43 h6 M24,4 v4 M9,10 l3,3 M39,10 l-3,3 M4,22 h4 M40,22 h4"/></g></symbol>',
    f'<symbol id="i-globe" viewBox="0 0 56 56"><g {S}><circle cx="28" cy="28" r="22"/><ellipse cx="28" cy="28" rx="9" ry="22"/><path d="M6,28 H50 M10,17 H46 M10,39 H46"/></g></symbol>',
    f'<symbol id="i-gear" viewBox="0 0 56 56">{_gear()}</symbol>',
    f'<symbol id="i-db" viewBox="0 0 56 56"><g {S}><ellipse cx="28" cy="12" rx="18" ry="7"/><path d="M10,12 V44 a18,7 0 0 0 36,0 V12 M10,23 a18,7 0 0 0 36,0 M10,34 a18,7 0 0 0 36,0"/></g></symbol>',
    f'<symbol id="i-card" viewBox="0 0 56 56"><g {S}><rect x="5" y="11" width="46" height="34" rx="4"/><path d="M5,22 H51" stroke-width="7"/><path d="M12,36 H24"/></g></symbol>',
    f'<symbol id="i-component" viewBox="0 0 56 56"><g fill="none" stroke="#1d4f91" stroke-width="3.5" stroke-linejoin="round"><rect x="16" y="5" width="32" height="46" rx="3" fill="{SOFT}"/><rect x="7" y="13" width="17" height="10" rx="2" fill="#fff"/><rect x="7" y="33" width="17" height="10" rx="2" fill="#fff"/></g></symbol>',
    f'<symbol id="i-person" viewBox="0 0 56 56"><circle cx="28" cy="16" r="10" fill="{INK}"/><path d="M8,50 a20,18 0 0 1 40,0 Z" fill="{INK}"/></symbol>',
    f'<symbol id="i-users" viewBox="0 0 56 56"><g fill="{INK}"><circle cx="28" cy="17" r="7.5"/><path d="M15,44 a13,12 0 0 1 26,0 Z"/><circle cx="12" cy="21" r="5.5"/><path d="M2,42 a10,9 0 0 1 16,-6 a16,14 0 0 0 -4,6 Z"/><circle cx="44" cy="21" r="5.5"/><path d="M54,42 a10,9 0 0 0 -16,-6 a16,14 0 0 1 4,6 Z"/></g></symbol>',
    f'<symbol id="i-doc" viewBox="0 0 56 56"><g {S}><path d="M13,5 H35 L45,15 V51 H13 Z"/><path d="M35,5 V15 H45 M20,25 H38 M20,33 H38 M20,41 H32"/></g></symbol>',
    f'<symbol id="i-cube" viewBox="0 0 56 56"><g {S}><path d="M28 6 L48 17 L48 39 L28 50 L8 39 L8 17 Z M8 17 L28 28 L48 17 M28 28 V50"/></g></symbol>',
    f'<symbol id="i-book" viewBox="0 0 56 56"><g {S}><path d="M28,14 C22,9 12,9 5,11 V46 C12,44 22,44 28,49 C34,44 44,44 51,46 V11 C44,9 34,9 28,14 Z M28,14 V49"/></g></symbol>',
    f'<symbol id="i-cart" viewBox="0 0 56 56"><g {S}><path d="M4,8 H11 L17,38 H45 L50,17 H14"/><circle cx="20" cy="47" r="3.5" fill="{INK}"/><circle cx="42" cy="47" r="3.5" fill="{INK}"/></g></symbol>',
    f'<symbol id="i-window" viewBox="0 0 56 56"><g {S}><rect x="5" y="8" width="46" height="40" rx="4"/><path d="M5,18 H51" stroke-width="5"/></g><g fill="#fff"><circle cx="11" cy="13" r="1.6"/><circle cx="16" cy="13" r="1.6"/><circle cx="21" cy="13" r="1.6"/></g></symbol>',
    f'<symbol id="i-search" viewBox="0 0 56 56"><g fill="none" stroke="{INK}" stroke-width="4.5" stroke-linecap="round"><circle cx="23" cy="23" r="14"/><path d="M33,33 L48,48"/></g></symbol>',
    f'<symbol id="i-check" viewBox="0 0 56 56"><circle cx="28" cy="28" r="22" fill="{INK}"/><path d="M17,29 L25,37 L40,20" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></symbol>',
    f'<symbol id="i-mail" viewBox="0 0 56 56"><g {S}><rect x="5" y="11" width="46" height="34" rx="4"/><path d="M6,13 L28,31 L50,13"/></g></symbol>',
    f'<symbol id="i-warn" viewBox="0 0 56 56"><g {S}><path d="M28,6 L52,48 H4 Z"/><path d="M28,21 V34"/></g><circle cx="28" cy="41" r="2.6" fill="{INK}"/></symbol>',
    f'<symbol id="i-artifact" viewBox="0 0 56 56"><g {S}><path d="M12,4 H34 L46,16 V52 H12 Z"/><path d="M34,4 V16 H46"/></g></symbol>',
    f'<symbol id="i-actor" viewBox="0 0 80 112"><g fill="#a9d3fb" stroke="{INK}" stroke-width="4"><circle cx="40" cy="28" r="22"/><path d="M4,108 V84 a36,30 0 0 1 72,0 V108 Z" stroke-linejoin="round"/></g></symbol>',
])
