# スライドの規則

## 目次

- 認知負荷を下げる規則
- レイアウトと文字の大きさ
- 図とイラスト
- SlideGen_AI アニメーションモードの規則（適用したもの）
- SlideGen_AI アニメーションモードの規則（適用しないもの）
- 使えるクラス

## 認知負荷を下げる規則

- 1枚に主メッセージを1つ置く。`<p class="msg">` で大きな見出しにし、要点の語を `<b>` で色付けする。
- 情報が多いスライドは分割する。事例のスライドは「部門課題＋Before / After」（`flow` 型、`split-a`）と「出力例＋人間の確認＋部下への検討指示」（`html` 型、`split-b`）の2枚にする。
- 表と箇条は3行（3項目）まで。1項目は20字前後の短い句にする。
- ヘッダーのチップ（「テーマ1」などのラベル）と凡例は置かない。役割は色とアイコン（人＝橙、AI＝青）で示す。
- 操作の案内（`.hint`）は、強調できる要素を最初に置いたスライドに1回だけ書く。
- 安全上の要点（出典の確認、人間の確認、承認、判断は人が行う）は短くしても削らない。
- 表紙に進行上の情報（「ワークショップ前半30分」など）を書かない。
- スライドから外した文（主眼、限界、補足、出典）は設計書に残し、講師が口頭で補う。

## レイアウトと文字の大きさ

- 舞台は 1280×720 を基準にし、`--u`（舞台幅 / 1280）で寸法を書く。`deck.css` の `.inner` が設定する。
- 本文は舞台上で19px以上。ラベル（`dt`、`.sublead`、表の見出し）は16px以上。
- 縦の余白が一か所に80pxを超えて残らないようにする。`split-a` は図を `margin-block: auto` で中央に置き、`split-b` は上下の要素を `margin-top: auto` / `margin-bottom: auto` で配分する。
- すべての要素を舞台（`.stage`）の内側に収める。`shoot.mjs` の `bad` で確かめる。

## 図とイラスト

- アイコンは 24×24 の線画（`stroke: currentColor`、塗りなし）。`<svg class="ico"><use href="#i-名前"/></svg>`。
- イラストは 64×64 の角を丸めた絵（人物、ロボット、書類など）で、明るい差し色を使う。`<svg class="av"><use href="#il-名前"/></svg>`。
- 文字のコントラストは WCAG AA（通常文字 4.5:1）以上。
- 外部URL、画像ファイル、Webフォントを使わない。
- 新しいアイコンやイラストを足す場合は `sprite.svg` に `<symbol id="i-…" viewBox="0 0 24 24">` / `<symbol id="il-…" viewBox="0 0 64 64">` で追加する。

アイコン: search camera bot user usercheck brief target alert clock bulb pencil x check plus lock file chat server flag shield repeat pin trend eye list pointer swap columns

イラスト: staff boss robot docs mail system binder inspect checklist quote

## SlideGen_AI アニメーションモードの規則（適用したもの）

出典は `SlideGen_AI/python_backend/app/services/ai/animated_slides.py` の `build_system_prompt`。

| 規則 | デッキでの実装 |
|------|----------------|
| アニメーションの無い状態でも完成した絵にする | `.fx-in` などは `.slide.active` の時だけ keyframes を当て、基本の状態を最終状態にする |
| 文字を読めなくする強調をしない。薄くする場合も opacity 0.4 以上 | 強調時の非対象は `.dim { opacity: .4 }` |
| 強調は拡大、枠線、光彩の色の変化で行う | `.lit` に枠線の太さと影、`litGlow` / `litPop` |
| SVG 要素を transform で動かす時は `transform-box: fill-box; transform-origin: center` | `.fig .fx-in, .fig .fx-pop, .fig .fx-pulse` に指定済み |
| SVG に `viewBox` を付け、幅は 100% で拡大縮小する | `.fig { width: 100%; height: auto }` |
| 外部ライブラリ、画像URL、`@import`、`url()` を使わない | sprite をインラインで埋め込む。`check.py` で外部URLを検査 |
| 動きを減らす設定を尊重する | `@media (prefers-reduced-motion: reduce)` でアニメーションと遷移を止める |

一つだけ意図して外した点がある。段階表示の `.frag` は表示前に opacity 0 と visibility hidden を使う。講師の操作で順に出すための仕組みであり、`?all` と印刷ではすべて表示する。

## SlideGen_AI アニメーションモードの規則（適用しないもの）

SlideGen_AI は、ホストのテンプレートに1ページ分の断片を埋め込み、フレーム送りで動画に収録する。単独で開くデッキにはその前提がないため、次の規則は使わない。

| 規則 | 使わない理由 |
|------|--------------|
| `html.js-anim` 配下にだけアニメーションを書く | ホストがクラスを付ける仕組みが無い。代わりに `.slide.active` を起点にする |
| 無限ループ、keyframes の 0% と 100% を同じ値にする、周期を loopSeconds の約数にする | 収録用のループ。デッキは表示時に1回だけ入場アニメーションを再生する |
| `data-anim-group` を付ける | 書き出しHTMLのホバー再生用 |
| `setInterval` などのタイマーを使わない | フレーム送りでは再現できないための規則。デッキの5分タイマーには必要 |
| `position: fixed` を使わない | 断片をテンプレートの枠に入れるための規則。デッキはスライドを fixed で重ねる |
| `var(--font-sans)` だけを使う、ページ固有の接頭辞をクラスに付ける | ホストのテンプレートと衝突させないための規則 |
| JS でレイアウトを計測しない | 書き出し時に非表示ページの値が 0 になるための規則。デッキの JS は計測しない（検証用の shoot.mjs だけが計測する） |

## 使えるクラス

| クラス | 用途 |
|--------|------|
| `.msg` | 主メッセージ（大見出し） |
| `.issue` + `.tag-is` | 部門課題の帯（`flow` 型が生成） |
| `.two` | 2列（`split-b` では 1.3fr / 1fr） |
| `.card-hu` / `.card-pa` | 人間（担当者）の確認 / 部下への検討指示の例 |
| `.ct` | 3行の比較表（`th.ag` / `td.ag` で右列を強調） |
| `.rt` | 出力例の表（`tr.hu-row` で確認する行を枠で示す） |
| `.st` | 状態ごとの処理の表（`tr.hot` で人が引き継ぐ行を示す） |
| `.t7` / `.t8` | 表と図の2列（`.t7-main` + `.t7-side`、`.t8-main` + `.side`） |
| `.themes` + `.theme` | テーマのカード3枚 |
| `.tbar` | 時間配分の帯 |
| `.notes.ic.big` | アイコン付きの短い箇条 |
| `.callout.big` / `.band-pa` | 注意の一文 / 判断者向けの一文 |
| `.tag-fic` | 「教材用の架空例」の印 |
| `.r-ai` / `.r-hu` | 表の中の役割の印 |
| `.hint` | 操作の案内（舞台の右下に固定） |
