# -*- coding: utf-8 -*-
"""構成案パッケージ図の生成例（架空の研修教材「Web開発入門」の再編）。

python3 diagrams.py  → out/plan.svg, out/migration.svg
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "scripts"))
from pkgplan import plan_diagram, migration_diagram  # noqa: E402

OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)

# ---- 構成案: 1 教材の部・節をどう組み替えるか ----
plan = {
    "title": "003 Web開発入門",
    "subtitle": "部・節の構成案",
    "package": "003 Web開発入門 [WEB003]",
    "groups": [
        ("はじめに", [
            ("p0", "目的、この教材の読み方", "rewrite", "← 旧 第1章"),
        ]),
        ("第1部 Web の仕組み", [
            ("p11", "1-1 ブラウザとサーバー", "reuse", ""),
            ("p12", "1-2 URL とリクエストの流れ", "reuse", ""),
            ("p13", "1-3 HTML の骨組み", "rewrite", "← 旧 2-1〜2-3 を 1 節に"),
            ("p14", "1-4 ワーク: 自己紹介ページを作る", "new", "【提案】"),
            ("p15", "旧 1-5 サーバーの設置場所", "out", "→ 004 インフラ入門へ"),
        ]),
        ("第2部 動きを付ける", [
            ("p21", "2-1 CSS で飾る", "reuse", ""),
            ("p22", "2-2 JavaScript で動かす", "rewrite", "← 旧 第3章（例を差し替え）"),
            ("p23", "2-3 ワーク: ボタンで色を変える", "new", ""),
            ("p24", "旧 2-6 SQL との接続", "out", "→ 005 DB入門へ"),
        ]),
        ("付録・巻末", [
            ("a1", "A タグ早見表", "reuse", "← 旧 付録 A"),
            ("a2", "B ショートカット集", "out", "→ 002 PC操作基礎へ"),
            ("q", "確認クイズ 10問", "new", ""),
        ]),
    ],
    "boxes": [
        ("b004", "→ 004 インフラ入門", ["サーバーとデータセンター"], "pkg"),
        ("b005", "→ 005 DB入門", ["SQL の基本"], "pkg"),
        ("b002", "→ 002 PC操作基礎", ["付録 ショートカット"], "pkg"),
        ("bold", "← 旧 Web開発入門 v1", ["第1〜3章、付録 A"], "ref"),
    ],
    "arrows": [
        ("p15", "b004", "out"), ("p24", "b005", "out"), ("a2", "b002", "out"),
        ("p0", "bold", "in"), ("p13", "bold", "in"), ("p22", "bold", "in"),
    ],
    "notes": ["旧 第4章（デプロイ）は本教材から外し、研修後半の演習で扱う。"],
}
plan_diagram(plan, os.path.join(OUT, "plan.svg"))

# ---- 集約・移行: ばらばらのフォルダを 1 か所にまとめる ----
mig = {
    "title": "020_Web入門 への集約",
    "subtitle": "元教材のフォルダから新フォルダへ（案 1）",
    "left_title": "リポジトリの現状",
    "left": [
        ("080_基礎", ["005_Webアプリケーション基礎 [STD005]"], "pkg"),
        ("230_業務", ["001_PC操作テクニック [BIZ001]", "003_コンピューターの基礎 [BIZ003]"], "pkg"),
        ("020_Web入門（既存）", ["002_HTML入門 [WEB002]", "004_CSS入門 [WEB004]", "005_旧版（空）"], "ref"),
    ],
    "right_title": "02_個別研修教材/020_Web入門（案 1）",
    "right": ["001_コンピューターの基礎 [WEB001]", "002_PC操作基礎 [WEB002]",
              "003_Web開発入門 [WEB003]", "004_インフラ入門 [WEB004]"],
    "right_notes": ["番号は実施順に振り直し。ID はフォルダ番号に合わせる",
                    "既存の 002・004 は 003 に取り込み、旧フォルダは退役"],
    "moves": [(0, 0, 2), (1, 0, 1), (1, 1, 0, "第1〜3章"), (2, 0, 2), (2, 1, 2)],
    "footer": "破線の矢印は «move»（移動）。BIZ003 第4章（情報セキュリティ）は別教材へ。",
}
migration_diagram(mig, os.path.join(OUT, "migration.svg"))
print("ok")
