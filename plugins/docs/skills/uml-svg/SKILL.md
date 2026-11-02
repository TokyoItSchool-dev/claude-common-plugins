---
name: uml-svg
description: UML 図（配置・コンポーネント・ステートマシン・アクティビティ・シーケンス・クラス・ユースケース・パッケージの 8 種）を描く依頼があった時だけ自動で使う。編集できて拡大しても劣化しない手書き SVG として作図し、青系フラットの部品ライブラリ diagsvg.py で描いたあと、PNG に描画して見た目を、記法チェックリストで正しさを検証する。「UML図を描いて」「クラス図をSVGで」「シーケンス図を作って」「配置図を作図して」と言われた時に使用。構成案パッケージ図（教材やモジュールの再編を 流用／改写／新規／外す で塗り分ける図）、画像からの SVG 再現、UML 以外の構造図・フロー図（ER 図・クラウド構成図・フローチャート等）にも対応するが、これらはユーザーが `/docs:uml-svg` を明示的に呼んだ時だけ使い、自動では使用しない。HTML 設計書の本文にインライン図を埋め込む場合は使用不可 — `docs:html-design-doc` の SVG 規約に従うこと。PlantUML / Mermaid で描く指示がある場合も使用不可。
---

# 図解をSVGで作図・再現する

図解を、編集できて拡大しても劣化しない手書きSVGとして作るための手順。
入口は2つある。

- **再現**：画像（AI生成画像やスクリーンショット）をそっくりのSVGに起こす。
- **新規作図**：文章で説明された内容から図を起こす。
  - 「構成案」「再編」「集約」「どこへ移すか」を見せる図は、spec（dict）を書くだけで描ける専用部品がある（`references/package-plan.md`）。

どちらの場合も、同じ部品ライブラリで描き、同じ方法で検証する。

## 発動条件

- 自動で使うのは UML 図（8 種）を描く依頼があった時だけ。
- 構成案パッケージ図、画像からの SVG 再現、UML 以外の構造図・フロー図は、ユーザーが `/docs:uml-svg` を明示的に呼んだ時だけ使う。依頼文に「図を描いて」とあるだけでは使わない。
- HTML 設計書の本文に埋め込む図は `docs:html-design-doc` の SVG 規約に従い、このスキルは使わない。PlantUML / Mermaid の指示がある場合も使わない。

## 分野別ルール（必要なものだけ読む）

描き始める前に、図の分野に合うファイルを読む。記法の正しさは分野ごとに違う。

| 分野 | 読むファイル | 内容 |
|---|---|---|
| UML（配置・コンポーネント・ステートマシン・アクティビティ・シーケンス・クラス・ユースケース・パッケージ） | `references/uml.md` | 記法チェックリスト、図種ごとの組み立て方、UML用の部品 |
| 構成案・再編・集約の提案図（教材・モジュール・フォルダの中身をどう組み替えるか。流用／改写／新規／外す の塗り分けと «move» の矢印） | `references/package-plan.md` | 専用部品 `pkgplan.py` の仕様、記法・見た目のチェックリスト、会議資料向けに情報量を減らすコツ |
| 上の表に無い分野（ER図、クラウド構成図、フローチャートなど） | `references/adding-a-domain.md` | 汎用部品だけで描く方法と、検証して分野ファイルを追加する手順 |

## 同梱ファイル

| ファイル | 用途 |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts/diagsvg.py` | 部品ライブラリ。汎用部品とUML部品を収録 |
| `${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts/pkgplan.py` | 構成案パッケージ図の部品。`plan_diagram(spec, path)`（構成案）と `migration_diagram(spec, path)`（集約・移行）。高さ自動、矢印のレーン分け付き |
| `${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts/compare.py` | 元画像との4分割比較（再現のときだけ使う）。`python3 "${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts/compare.py" out.svg original.png cmp.png` |
| `${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts/montage.py` | 複数のSVGを1枚の一覧画像にする。`python3 "${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts/montage.py" montage.png out/*.svg` |
| `examples/uml/` | UML図8種の生成コード、レビュー記録、完成見本 |
| `examples/package-plan/` | 構成案パッケージ図 2 種の生成コード、レビュー記録、完成見本 |

## 手順

1. **準備**
   - 日本語フォントが使えることを確認する（Linux: `fc-list :lang=ja`、Windows: メイリオ / 游ゴシックが通常入っている。Noto Sans CJK JP を推奨）。
   - `pip install cairosvg pillow` でレンダラを入れる。`--break-system-packages` は、それを要求する Linux ディストリビューションでのみ付ける。
   - Windows では cairosvg に cairo のランタイム DLL が必要。`import cairosvg` が失敗する場合は、利用できる別のレンダラ（`rsvg-convert`、Inkscape CLI の `inkscape --export-type=png`、ヘッドレスブラウザなど）で SVG を PNG に変換する。`compare.py` と `montage.py` は cairosvg が必要。
   - `${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts/diagsvg.py` を作業ディレクトリへコピーするか、`${CLAUDE_PLUGIN_ROOT}/skills/uml-svg/scripts` を `sys.path` に追加する。
2. **分野ファイルを読む**：上の表に従う。
3. **配置を決める**
   - **再現の場合**：キャンバスを元画像と同じピクセルサイズにする。元画像から、各要素の位置・大きさ・線の折れ点を読み取ってそのまま使う。
   - **新規作図の場合**：下の「レイアウトの目安」に沿って座標を設計する。似た図が `examples/` にあれば、その座標から始める。
4. **描く**：図ごとに関数を1つ書き、`Doc` に部品を並べる。1図あたり30〜60行が目安。
5. **見た目を検証する**
   - PNGにして必ず目で見る。
   - 再現の場合は `compare.py` で元画像と重ねる。
   - 複数枚なら `montage.py` で一覧にして、統一感を確認する。
   - 文字のはみ出しや重なりが疑わしい箇所は、切り抜いて拡大して確認する。
6. **記法を検証する**
   - 分野ファイルのチェックリストを図ごとに当てる。
   - 問題は【記法】と【意味】に分けて `*_review.md` に記録する。
   - 再現の元画像がAI生成の場合、記法の誤りはほぼ必ず含まれている。見た目より正しさを優先して直す。
7. **直して再検証する**：手順5と6を、問題が無くなるまで繰り返す。通常は2〜3周で収まる。
8. **渡す**：SVG一式、生成スクリプト、レビュー記録をまとめて渡す。スクリプトがあれば、受け取った人が文言や配置を1行単位で直せる。

## レイアウトの目安（1448×1086、新規作図のとき）

- **ヘッダー**：y=0〜161。`Doc("UML 配置図")` のように空白で区切ると、前半がアクセント色になる。空白が無ければタイトル全体が通常色になる。
- **本文**：y≈180〜1000、x≈50〜1400。
- **フッター**：y≈1007〜1073。`footer("説明文。")` で置く。
- **箱の大きさ**：幅220〜390、高さ100〜120。横の間隔は40px以上あける。
- **線**：直角に折る（`M x,y H x V y`）。線のラベルは線から10〜15px離す。
- **余白**：要素が多いときは、文字を小さくするより先に箱を減らすか、図を分ける。

## 描く順番（レイヤー）

`bg → edges → nodes → over` の順に描く。

| レイヤー | 入れるもの |
|---|---|
| `bg` | 外枠、スイムレーン、境界、フッター |
| `edges` | 線 |
| `nodes` | 箱、箱の中の文字 |
| `over` | 線上のラベル、接続記号、アイコン |

- 大きな背景の枠を `nodes` に入れると、線がすべて隠れて消える。
- 線は箱より先に描くので、線の端は箱の縁にきれいに隠れる。そのため、端点はおおよその位置で足りる。

## 汎用部品（diagsvg.py）

| 部品 | 用途 |
|---|---|
| `Doc(title, subtitle=..., title_fs=72)` | キャンバスとヘッダー |
| `footer(note)` | 説明帯 |
| `box(x,y,w,h, label, band=32)` | 上部に水色の帯がある角丸の箱 |
| `plain(x,y,w,h)` | 帯の無い箱 |
| `folder(...)` | 左上にタブのある箱 |
| `ellipse(...)` | 楕円 |
| `diamond(cx,cy)` | ひし形（分岐） |
| `edge(pts or path, arrow=True/"filled"/False, dash=False)` | 線。既定は開いた矢じり。`"filled"` で塗りつぶしの三角 |
| `text(x,y,s, fs, weight, anchor, layer, bg=False)` | 文字。`bg=True` で白い下地を敷く |
| `stereo(x,y,s)` | «…» 表記 |
| `dot(x,y)` | 黒丸 |
| `icon(name, cx, cy, s)` | アイコン（56px基準） |
| `raw(svg, layer=...)` | 任意のSVGを直接入れる |

アイコンは次の種類がある：globe, gear, db, card, component, artifact, person, users, doc, cube, book, cart, window, search, check, mail, warn, actor。

## 配色

部品はすべて次の配色で描かれる。新しい部品を作るときも、この定数を使う。

| 定数 | 色 | 用途 |
|---|---|---|
| INK | `#13294b` | 線・文字 |
| BAND | `#a9d3fb` | 帯 |
| BODY | `#eef6ff` | 箱の本体 |
| ACCENT | `#0b6fd8` | ロゴ・番号・強調 |
| RULE | `#2a8cf0` | 罫線 |
| FOOT | `#e6f1fd` | フッター |

文字は Noto Sans CJK の太字だと横幅が広い。

- 箱の中のラベル：25〜27px
- 線のラベル：20〜23px
- ステレオタイプ：15〜19px

## ハマりどころ

| 症状 | 原因 | 対処 |
|---|---|---|
| 線がすべて消える | 背景の枠を、線より後のレイヤーに入れている | 背景の枠は `bg` に入れる |
| グラデーションや帯が出ない | CSSクラスの `fill` が、要素の fill 属性より優先される | クラスに fill を書かない |
| 日本語が豆腐（□）になる | cairosvg が font-family の先頭しか見ない | インストール済みのフォントを先頭に書く |
| 線上のラベルが消える | `paint-order` が効かない処理系がある | `text(bg=True)` で白い下地を敷く |
| `duplicate attribute` エラー | 共通の属性文字列と個別の指定が重複している | 個別に指定するときは共通文字列を使わない |
| 文字が箱からはみ出す | 和文の太字は横幅が広い | 文字を小さくする。メッセージ名なら引数を省略する |
| タイトルがサブタイトルに重なる | `title_fs` が大きすぎる | 72〜76 にする |
| 中身が外枠からはみ出す | 高さを先に決め打ちしている | 中身の行数から高さを見積もり、`save` の前に `d.h` を確定する（`pkgplan.py` の `_finalize` が例） |
| 矢印が重なって読めない | 複数の矢印が同じ x を通っている | 矢印ごとに縦レーンを 7〜8px ずらし、同じ箱への到着点も分散させる |

## Origin

Cowork 配下のプロトタイプ作成プロジェクト（diagram-svg として作成、取り込み時に uml-svg へ改名）
