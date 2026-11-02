# -*- coding: utf-8 -*-
"""構成案パッケージ図（pkgplan）

「1 つの入れ物（教材・モジュール・リポジトリなど）の中身をどう組み替えるか」を
UML パッケージ図の見た目で描く部品。diagsvg.py の上に載る。

2 種類の図を描ける。

- plan_diagram(spec, path)      : 構成案。左に対象パッケージ（部・章 → 節）、右に関係先パッケージ、
                                  間を «move» の破線矢印でつなぐ。節は状態（流用・改写・新規・外す）で塗り分ける。
- migration_diagram(spec, path) : 集約・移行。左に現状のパッケージ群、右に移行先のパッケージ、
                                  間を «move» の破線矢印でつなぐ。

どちらも高さは中身から自動で決まる。矢印は 1 本ごとに縦レーンをずらし、
同じ箱に入る矢印は到着点を分散させるので、重なって読めなくなることがない。

仕様（spec）は dict。キーの説明は references/package-plan.md を参照。
"""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from diagsvg import Doc, INK, TEXT, BAND, BODY, text_width  # noqa: E402

GREY = "#f1f4f8"    # 「外す」「参照のみ」の箱（新しい色はこれだけ。彩度を落とした灰）
MUTED = "#5a6a85"   # 補助文字
W = 1448

# 節の状態 → (塗り, 破線パターン, 文字色, 凡例の文言)
STATUS = {
    "reuse":   (BODY,      None,  TEXT,  "流用"),
    "rewrite": ("#ffffff", "9 6", TEXT,  "改写（書き直す）"),
    "new":     (BAND,      "9 6", TEXT,  "新規"),
    "out":     (GREY,      "3 5", MUTED, "この教材から外す"),
}


def _arrow(d, path):
    d.raw(f'<path d="{path}" fill="none" stroke="{INK}" stroke-width="2.5" '
          f'stroke-dasharray="8 7" marker-end="url(#arrow)"/>', layer="over")


def _legend(d, y, statuses, move_label):
    x = 60
    for key in statuses:
        f, dash, tc, label = STATUS[key]
        d.plain(x, y, 54, 30, rx=6, fill=f, sw=2.5, shadow=False, dash=dash)
        d.text(x + 66, y + 23, label, fs=22, weight=500, fill=TEXT, layer="nodes")
        x += 66 + text_width(label, 22) + 44
    d.edge([(x, y + 15), (x + 70, y + 15)], dash=True, sw=2.5)
    d.text(x + 84, y + 23, move_label, fs=22, weight=500, layer="nodes")


def _fit_note(note, max_w, fs=18):
    """注記が収まらなければ 16px に落とし、それでも無理なら末尾を … で詰める。"""
    if text_width(note, fs) > max_w:
        fs = 16
    while text_width(note, fs) > max_w and len(note) > 4:
        note = note[:-2] + "…"
    return note, fs


def _finalize(d, path, h):
    """高さを後から確定して保存する。"""
    old = d.h
    d.h = int(h)
    d.save(path)
    s = open(path, encoding="utf-8").read()
    s = s.replace(f'viewBox="0 0 {d.w} {old}" width="{d.w}" height="{old}"',
                  f'viewBox="0 0 {d.w} {d.h}" width="{d.w}" height="{d.h}"', 1)
    s = s.replace(f'<rect width="{d.w}" height="{old}" fill="#fff"/>',
                  f'<rect width="{d.w}" height="{d.h}" fill="#fff"/>', 1)
    open(path, "w", encoding="utf-8").write(s)
    return path


# ---------------------------------------------------------------- 構成案
def plan_diagram(spec, path):
    """構成案パッケージ図を描いて path に保存する。

    spec = {
      "title": "006 プログラムとアルゴリズム入門",   # ヘッダー（空白の前がアクセント色）
      "subtitle": "部・節の構成案",
      "package": "006 プログラムとアルゴリズム入門 [IIT006]",  # 左の大きなパッケージ名
      "groups": [ ("第1部 …", [ (id, label, status, note), ... ]), ... ],
      "boxes":  [ (id, title, [lines], kind) ],   # 右の関係先。kind は "pkg"（青）か "ref"（灰）
      "arrows": [ (item_id, box_id, "out"|"in") ], # out: 節→箱（送り出す）、in: 箱→節（受け入れる）
      "notes":  ["脚注", ...],                      # 省略可
      "legend": ["reuse","rewrite","new","out"],   # 省略可。凡例に出す状態
      "move_label": "移動（«move»）",              # 省略可
    }
    """
    groups = spec["groups"]; boxes = spec.get("boxes", []); arrows = spec.get("arrows", [])
    notes = spec.get("notes") or []
    legend_keys = spec.get("legend") or ["reuse", "rewrite", "new", "out"]
    ROW, GPAD, TOP = 50, 18, 200
    h_left = 56 + 22 + sum(40 + GPAD + len(it) * ROW + 4 + 22 for _, it in groups) \
        + (len(notes) * 28 + 12 if notes else 0) + 10
    total = TOP + h_left + 210
    d = Doc(spec["title"], w=W, h=int(total), subtitle=spec.get("subtitle", "構成案"), title_fs=56)
    LX, LW = 50, 900
    RX, RW = 1000, 398

    d.folder(LX, TOP, LW, h_left, title=spec["package"], tab=(140, 24), band=56, fs=30, fill="#f8fbff")
    cy = TOP + 56 + 22
    item_pos = {}
    for gtitle, items in groups:
        gx, gw = LX + 28, LW - 56
        gh = 40 + GPAD + len(items) * ROW + 4
        d.folder(gx, cy, gw, gh, title=gtitle, tab=(90, 18), band=40, fs=24, fill="#ffffff")
        iy = cy + 40 + GPAD
        for (iid, label, status, note) in items:
            f, dash, tc, _ = STATUS[status]
            ix, iw = gx + 22, gw - 44
            d.plain(ix, iy, iw, 40, rx=8, fill=f, sw=2.2, shadow=(status != "out"), dash=dash)
            d.text(ix + 18, iy + 28, label, fs=23, weight=700 if status != "out" else 500, fill=tc, layer="nodes")
            if note:
                lx = ix + 18 + text_width(label, 23) + 22
                note, nfs = _fit_note(note, ix + iw - 12 - lx)
                d.text(lx, iy + 27, note, fs=nfs, weight=500, fill=MUTED, layer="nodes")
            item_pos[iid] = (ix + iw, iy + 20)
            iy += ROW
        cy += gh + 22
    for line in notes:
        d.text(LX + 30, cy + 10, line, fs=20, weight=500, fill=MUTED, layer="nodes")
        cy += 28

    # 矢印の正規化: (節, 箱, 向き) に揃える（箱と節が逆に書かれていても受ける）
    box_ids = {b[0] for b in boxes}
    norm = []
    for (a, b, direction) in arrows:
        if a in box_ids and b in item_pos:
            a, b = b, a
        if a not in item_pos or b not in box_ids:
            raise KeyError(f"arrow {(a, b)}: 節 id か箱 id が見つからない")
        norm.append((a, b, direction))

    # 右の箱: つながる節の高さの平均に置く。重なれば下にずらす
    want = []
    for (bid, btitle, lines, kind) in boxes:
        ys = [item_pos[a][1] for (a, b, _) in norm if b == bid]
        bh = 56 + len(lines) * 30 + 18
        want.append(((sum(ys) / len(ys)) if ys else TOP + 20 + bh / 2, bid, btitle, lines, kind, bh))
    want.sort(key=lambda t: t[0])
    box_pos = {}
    prev_bottom = TOP + 10
    for (cy_want, bid, btitle, lines, kind, bh) in want:
        by = max(cy_want - bh / 2, prev_bottom + 24)
        d.folder(RX, by, RW, bh, title=btitle, tab=(90, 18), band=48, fs=20, fill=GREY if kind == "ref" else BODY)
        ly = by + 48 + 30
        for ln in lines:
            d.text(RX + 22, ly, ln, fs=19, weight=500, fill=MUTED if kind == "ref" else TEXT, layer="nodes")
            ly += 30
        box_pos[bid] = (RX, by, bh)
        prev_bottom = by + bh

    # «move» 矢印: 1 本ごとに縦レーンを 7px ずらし、同じ箱への到着 y を分散させる
    per_box = {}
    for (a, b, _) in norm:
        per_box.setdefault(b, []).append(a)
    lane_x = RX - 46
    for (a, b, direction) in norm:
        (ix, iy) = item_pos[a]; (bx, by0, bh) = box_pos[b]
        sibl = per_box[b]; k = sibl.index(a); n = len(sibl)
        ay = by0 + bh / 2 + (k - (n - 1) / 2) * 22
        if abs(ay - iy) < 3:
            p = f"M{ix},{iy} H{bx-3}" if direction == "out" else f"M{bx},{ay:.0f} H{ix+3}"
        elif direction == "out":
            p = f"M{ix},{iy} H{lane_x} V{ay:.0f} H{bx-3}"
        else:
            p = f"M{bx},{ay:.0f} H{lane_x} V{iy} H{ix+3}"
        _arrow(d, p)
        lane_x += 7

    ly = max(cy + 30, prev_bottom + 10)
    _legend(d, ly, legend_keys, spec.get("move_label", "移動（«move»）"))
    return _finalize(d, path, ly + 54)


# ---------------------------------------------------------------- 集約・移行
def migration_diagram(spec, path):
    """集約・移行パッケージ図を描いて path に保存する。

    spec = {
      "title": "025_IT入門 への集約", "subtitle": "元フォルダから新フォルダへ（案 1）",
      "left_title": "リポジトリの現状",
      "left": [ (group_title, [line, ...], kind) ],      # kind: "pkg"（白）か "ref"（灰）
      "right_title": "02_個別研修教材/025_IT入門（案 1）",
      "right": [ "001_…", "002_…", ... ],                 # 移行先の箱（上から順）
      "right_notes": ["脚注", ...],                       # 省略可
      "moves": [ (left_group_index, left_line_index, right_index, label) ],  # 0 始まり。label 省略可（None）
      "footer": "破線の矢印は «move»（移動）。",          # 省略可
    }
    """
    left = spec["left"]; right = spec["right"]; moves = spec.get("moves", [])
    rnotes = spec.get("right_notes") or []
    TOP = 230
    LX, LW = 50, 640
    RX, RW = 760, 638
    # 左右の高さを見積もる
    lh = 70 + sum(40 + 12 + len(lines) * 30 + 20 + 20 for _, lines, _ in left) + 10
    rh = 70 + len(right) * 60 + (len(rnotes) * 24 + 20 if rnotes else 0) + 10
    H = max(lh, rh)
    d = Doc(spec["title"], w=W, h=TOP + H + 160, subtitle=spec.get("subtitle", ""), title_fs=56)

    d.folder(LX, TOP, LW, H, title=spec.get("left_title", "現状"), tab=(130, 22), band=50, fs=26, fill="#f8fbff")
    src = {}
    y = TOP + 70
    for gi, (gtitle, lines, kind) in enumerate(left):
        gh = 40 + 12 + len(lines) * 30 + 20
        d.folder(LX + 24, y, LW - 48, gh, title=gtitle, tab=(90, 18), band=40, fs=22, fill=GREY if kind == "ref" else "#ffffff")
        ly = y + 40 + 32
        for li, ln in enumerate(lines):
            d.text(LX + 44, ly, ln, fs=20, weight=600, fill=TEXT, layer="nodes")
            src[(gi, li)] = ly - 8
            ly += 30
        y += gh + 20

    d.folder(RX, TOP, RW, H, title=spec.get("right_title", "移行先"), tab=(150, 22), band=50, fs=26, fill="#f8fbff")
    tgt = {}
    ny = TOP + 70
    for i, n in enumerate(right):
        d.plain(RX + 24, ny, RW - 48, 48, rx=8, fill=BODY, sw=2.5)
        d.text(RX + 44, ny + 32, n, fs=22, layer="nodes")
        tgt[i] = ny + 24
        ny += 60
    for i, n in enumerate(rnotes):
        d.text(RX + 24, ny + 20 + i * 24, n, fs=17, weight=500, fill=MUTED, layer="nodes")

    lane = 0
    for mv in moves:
        gi, li, ri = mv[:3]
        label = mv[3] if len(mv) > 3 else None
        y_from, y_to = src[(gi, li)], tgt[ri]
        lx = LX + LW + 10 + lane * 8
        lane += 1
        _arrow(d, f"M{LX+LW-24},{y_from} H{lx} V{y_to} H{RX+21}")
        if label:
            d.text(lx - 6, (y_from + y_to) / 2 + 6, label, fs=15, weight=500, fill=MUTED, anchor="end", layer="over", bg=True)

    fy = TOP + H + 20
    if spec.get("footer"):
        d.footer(spec["footer"], y=fy, h=52)
        fy += 52
    return _finalize(d, path, fy + 40)
