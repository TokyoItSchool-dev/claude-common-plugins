---
name: workshop-slides
description: 研修設計書（generate-design-doc が出力する design-doc-*.md と additional-instructions.md）から、インタラクティブなHTMLスライド（段階表示・クリック強調・回答例のクリック表示・作業タイマー・印刷対応）、手書き用ワークシート（A4横1枚）、ステークホルダー向け概要HTMLを作り、検証して設計書へ反映する。「研修設計書からインタラクティブなHTMLスライド・ワークシート・概要を作る」「スライドを分割して情報量を減らす」「アイコン・イラスト付きスライドにする」「ワークショップのスライドを作り直す」と言われた時に使用。設計書そのものの作成には使用不可 — generate-design-doc を使用すること。読み物のHTML文書（設計書・説明書）には使用不可 — docs:html-design-doc を使用すること。PowerPoint（.pptx）の作成には使用不可 — pptx を使用すること。
---

# workshop-slides

研修設計書を入力に、1ファイルで完結するHTMLスライド、ワークシート、概要を作る。生成は `assets/build.py` に JSON の仕様を渡して行い、検証は `assets/` のスクリプトで行う。最後に、スライドで決めた内容を設計書へ書き戻す。

## 入出力

| 種別 | パス | 備考 |
|------|------|------|
| 入力 | `design-docs/design-doc-*.md` | generate-design-doc の出力 |
| 入力 | `design-docs/additional-instructions.md` | 利用者の追加指示 |
| 出力 | `slides/index.html` | スライド（表紙＋N枚） |
| 出力 | `design-docs/worksheet.html` | 手書き用ワークシート |
| 出力 | `design-docs/overview.html` | 概要（generate-design-doc Step 7 の出力を更新） |
| 作業 | 作業用フォルダの `spec.json` | build.py の入力。成果物フォルダには置かない |

## 手順

### 1. 入力を読む

設計書の「セッション構成」「スライド表現の方向性」「スライド資料化範囲」と、additional-instructions.md の全項目を読む。セッションごとに、部門課題、Before / After、人間の確認、部下への検討指示、問い（Q1〜Q3）、回答例を書き出す。

事例を差し替える場合は、事例の内容を利用者に確認してから進める。業種を問わない事例（問い合わせ対応、報告書作成、会議の記録など）を優先して提案する。

### 2. スライド構成を決める

- 1枚に主メッセージを1つ置き、大きな見出し（`.msg`）にする。
- 情報が多いスライドは詰め込まずに分割する。例: 「部門課題＋Before / After」と「出力例＋人間の確認＋部下への検討指示」の2枚に分ける。
- 表と箇条は3行（3項目）まで、1項目は20字前後の短い句にする。
- ヘッダーのラベル（チップ）と凡例は置かない。操作の案内（`.hint`）はデッキ全体で1か所にする。
- 安全上の要点（出典の確認、人間の確認、承認、判断は人が行う）は短くしても削らない。
- 表紙のタイトルに「ワークショップ前半30分」のような進行上の情報を入れない。
- スライドから外した文は設計書に残し、講師が口頭で補う。

規則の全文と理由は [references/slide-rules.md](references/slide-rules.md)。

### 3. デッキを生成する

1. `assets/example-spec.json` を複製して spec.json を書く。スライドの型は `cover` / `flow` / `q` / `html` の4つ。型の項目は [references/interactions.md](references/interactions.md)。
2. 生成する。

   ```bash
   python ${CLAUDE_PLUGIN_ROOT}/skills/workshop-slides/assets/build.py spec.json slides/index.html design-docs/worksheet.html
   ```

3. 型にない図（比較表、出力例と照合の図など）は `html` 型に直接書く。使えるクラス、アイコン名、イラスト名は slide-rules.md と interactions.md にある。デッキ固有の調整は spec の `css` に書き、`assets/deck.css` は書き換えない。

デッキは外部URLを持たない。アイコンとイラストは `assets/sprite.svg` のインラインSVGを `<use>` で参照する。

### 4. 印刷を確認する

`deck.css` の印刷規則（`@page { size: 1280px 720px; margin: 0 }` を `@media print` の内側にも置く、1スライド1ページ、全段階を表示、操作部品を隠す、`print-color-adjust: exact`）を変えない。詳細は [references/print.md](references/print.md)。

### 5. ワークシートを作る

build.py の第3引数で生成する。行は `theme` を持つ `q` スライドから作り、行見出しの Q1・Q2 はスライドの文をそのまま使う。列は spec の `worksheet.cols` で決め、スライドの Q1〜Q3 と同じ文言にする。規則は [references/worksheet.md](references/worksheet.md)。

### 6. 概要を更新する

generate-design-doc Step 7 の overview.html を、docs:html-design-doc の規約で更新する。7章（背景、目的、目標、受講生への価値、企業への価値、研修概要・セッション構成、成果物）を保ち、スライド枚数、主メッセージ、ワークシートの列を新しい内容に合わせる。各章は短くし、イラストはデッキの sprite から再利用する。

### 7. 検証する

次をすべて行い、結果を報告に含める。コマンドは [references/verification.md](references/verification.md)。

1. `check.py`: タグの対応、`node --check`、外部URLなし、禁止語（旧事例の語を含む）なし。
2. `shoot.mjs`: 1280×720 と 1920×1080、`?all` で全スライドを撮影する。`bad` が空、表紙以外で `deadBand` が80px以下、本文が19px以上であることを確かめる。
3. スクリーンショットを全枚数、自分の目で見る。数値が基準内でも、余白の偏りや小さい文字が残ることがある。
4. 操作を実行する（段階表示、強調、Esc、回答例のクリック表示、タイマー、←で戻る）。
5. `pdftest.mjs` を `css` と `default` の2通りで実行し、`pdfinfo.py` で確かめる。デッキは N ページすべて横、ワークシートは1ページ、見出しの文がすべて PDF のテキストに含まれる。

### 8. 設計書へ反映する

設計書と additional-instructions.md を更新する。

- スライドの枚数と番号、各スライドの主メッセージ。
- 問いの文言（デッキ、ワークシート、設計書で同じ文にする）。
- ワークシートの列。
- 「スライド表現の方向性」に、手順2の規則と操作の仕様を書く。
- 新しく決めた事項を additional-instructions.md に番号付きで追記する。
- 設計書の H2 見出しの文、`<!-- SECTION_ID: ... -->`、`<!-- ADVICE: ... -->` は変えない。

### 9. 利用者への印刷の案内

報告に次を含める。

- 印刷先は「PDFに保存」を選ぶ。「Microsoft Print to PDF」はドライバーの縦向きの用紙を使い、内容が回転する。
- 他のプリンターを使う場合は、レイアウトを「横」にする。
- 「背景のグラフィック」をオンにする。

## 教訓

- 業種を限定した事例より、業種を問わない事例のほうが受講者に伝わった。
- 事例を差し替えるときは、利用者に事例を確認してから作る。
- スクリーンショットを自分で見てから報告する。前回は余白の偏りと小さい文字が原因で、レイアウトの修正が2回差し戻された。

## ファイル

- `assets/build.py` — spec.json からデッキとワークシートを生成する（Python 標準ライブラリのみ）。
- `assets/example-spec.json` — 4型を使う最小の例。スキルの自己確認にも使う。
- `assets/deck.css` / `deck.js` / `sprite.svg` / `worksheet.css` — 生成物に埋め込む部品。
- `assets/check.py` / `shoot.mjs` / `pdftest.mjs` / `pdfinfo.py` / `cdp.mjs` — 検証用。Chrome と Node 22 以上、pypdf が必要。

## Origin

user skills directory (workshop-slides)
