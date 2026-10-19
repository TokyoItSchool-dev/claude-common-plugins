---
name: html-design-doc
description: 設計書・説明書・俯瞰資料などのスタンドアロンHTMLドキュメントを、読みやすさ優先のシンプルなデザイン（左サイドバー目次＋本文1カラム）で直接生成する。ユーザーが明示的に「HTMLで作成」「HTML版がほしい」等とHTML出力を指示した時のみ使用。通常のドキュメントはMarkdownが既定。加えて「インタラクティブ版」「ビジュアル版」「経営層向けに動く資料」等の指示がある場合のみ手順D（KPIタイル・タブ・シナリオ切替などの表示切替を持つビジュアル版）を使い、指示がなければ既定は手順A。pandoc不使用。作図は既定でMermaidをHTMLに直接記述（CDN描画・AI可読）、明示指示時のみPlantUMLでPNG画像化しbase64埋め込み。手順DではSVG直書きが既定。講義資料としてブラウザからPDF保存する用途にも使う（改ページ・冒頭目次・画像縮小の印刷規則を内蔵）。データの入力・送信・保存を伴うUI（Webアプリ・管理画面等）には使用不可。
---

# html-design-doc

設計書・仕様書・俯瞰資料などのドキュメントを、**Claudeが直接記述する**スタンドアロンHTMLとして出力するスキル。デザインは人間の可読性を最優先した簡素なもので、左に固定表示の目次、右に読みやすい幅の本文を置く2カラム構成をとる。pandocは使用しない。

## 適用条件

- **利用者が明示的にHTML出力を指示した場合のみ**使用する（例:「HTMLで作成して」「HTML版もほしい」）。指示がない場合、ドキュメントの既定形式はMarkdownのまま。
- 対象は設計書・説明書・俯瞰資料等の**読み物ドキュメント**。**データの入力・送信・保存を伴うUI**（Webアプリ・管理画面など）には使用しない。
- 手順Dの操作要素も**表示の切替だけ**を行う。状態の保存も、サーバへの送信も、フォームによる入力も扱わない。
- 出力は外部ビルドツールに依存しない、単一HTMLファイルとして完結させる（pandoc不使用）。完結するのは `scripts/pack_doc.py` が書き出す `.packed.html`（手順C）で、共有・納品するのはこのファイルだけとする。許可される外部参照は、Mermaid使用時のCDNスクリプト1本（手順B）と、手順Dで採用したデザインが表示書体を要求する場合に限る `fonts.googleapis.com` への `<link>` 1本（手順D）だけであり、それ以外の外部参照は許可しない。

## 手順A: HTML本文作成

本文執筆前に `docs:cognitive-rhythm-writing` スキル（併読指定の `docs:japanese-tech-writing` を含む）を読み、その規範に従って本文を書く。

1. `references/template.html` を骨格として複製し、対象ドキュメントの内容に置き換える。

2. `<head>` 内に `<link rel="stylesheet" href="style.css">` を置く（`style.css` は原稿と同じフォルダに置くか、`references/style.css` を指す。貼り付けない）。デザイントークン（`:root` のCSS変数）を調整する場合は、`<link>` の後ろに別の `<style data-tokens>:root{--…}</style>` を置いてそこにだけ書く。変更する場合は文書全体で一貫させる。`pack_doc.py` が `<link>` と `data-tokens` をまとめて、トークンを最後に置いた1つの `<style>` に変換する。

3. 全体構造は次のとおり。目次の開閉ボタンは `<div class="layout">` の外（`<body>` 直下の先頭）に置く。

   ```html
   <body>
   <button type="button" class="toc-toggle" id="toc-toggle" hidden aria-controls="TOC" aria-expanded="true">☰ 目次</button>
   <div class="layout">
     <nav id="TOC" role="doc-toc" aria-label="目次"> ... </nav>
     <main class="main"> ... </main>
   </div>
   </body>
   ```

   開閉の実体は `</div>` の後ろに置く次のインラインスクリプト（これ以外のJavaScriptは追加しない。`pack_doc.py` はこのスクリプトに触れず、そのままインラインで残る）。ボタンはマークアップ上 `hidden` で、このスクリプトが表示に切り替える。したがってJavaScriptが無効な環境ではボタンが現れず、目次は開いたままになる（graceful degradation）。

   ```html
   <script>
   var tocBtn = document.getElementById('toc-toggle');
   tocBtn.hidden = false;
   tocBtn.addEventListener('click', function () {
     var collapsed = document.body.classList.toggle('toc-collapsed');
     tocBtn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
   });
   </script>
   ```

   スクリプトがするのは `<body>` への `toc-collapsed` クラスの付け外しだけで、折りたたみの見た目・アニメーション・本文カラムの拡張はすべてCSS側（`body.toc-collapsed` の各ルール）で処理する。既定はデスクトップで目次が開いた状態。

4. 目次は手書きで作成する。`<p class="toc-title">目次</p>` に続けて見出し構造に合わせた `<ul>` をネストし、各項目は `<a href="#<section-id>">見出しテキスト</a>` の形式にする。階層のインデント・ホバー・アクティブ表示はCSS側で処理されるため、追加のクラスは不要。

5. 本文は `<main class="main">` の中に `<section id="<section-id>" class="level1|level2|level3">` を見出しレベルに応じてネストして書く。`section-id` は見出しテキストをスラッグ化したもの（日本語はそのまま使ってよい。空白や記号はハイフンに変換する程度でよい）。見出しは `<h1>`（文書タイトル）／`<h2>`（章）／`<h3>`・`<h4>`（節・小見出し）を階層どおりに使う。

6. 主要コンポーネントの書き方。

   | 用途 | マークアップ |
   |------|--------------|
   | 注釈（情報） | `<div class="callout note"><span class="callout-label">NOTE</span><p>…</p></div>` |
   | 注釈（警告） | `<div class="callout warn"><span class="callout-label">WARN</span><p>…</p></div>` |
   | 注釈（助言） | `<div class="callout tip"><span class="callout-label">TIP</span><p>…</p></div>` |
   | コードブロック | `<pre><code>…</code></pre>`（横スクロール対応済み） |
   | インラインコード | `<code>…</code>` |
   | ファイル名の強調 | `<span class="file">…</span>` |
   | 文書のメタ情報 | `<p class="doc-meta">最終更新: … </p>`（h1 直後に置く） |
   | 付録セクション | `<section id="付録" class="level1 appendix">` |

7. 表は `<thead>` と `<tbody>` を明示する。列幅はCSSが自動調整するため、`<colgroup>` による幅指定は不要（どうしても必要な場合のみ使う）。ヘッダ行の書式・ゼブラ縞はCSS側で当たる。

8. 講義資料・PDF保存向けの書き方。印刷規則は `style.css` の `@media print` に入っているため、マークアップを次のとおりにすれば追加のCSSは不要。
   - 印刷では、左の目次がPDFの1ページ目になる。リンクはPDF内でも機能する。画面用の目次とは別に目次を書かない。手順Dの文書も同じく目次が1ページ目になる。
   - 講義資料では `<body class="lecture">` とする。印刷時に2章目以降の章（`section.level2`）の前で自動的に改ページする。画面の表示は変わらない。設計書ではこのクラスを付けない（改ページは目次の後と、2つ目以降の `section.level1` の前だけになる）。
   - それ以外の位置で改ページしたい場合は `<div class="page-break"></div>` を置く。この要素は画面では何も表示しない。
   - 画像は `<figure><img src="…" alt="…"><figcaption>図N　…</figcaption></figure>` で書く。印刷時は画像の高さを最大230mmに縮め、画像と図題を同じページに置く。Mermaid の図とインラインSVG（`role="img"`）にも同じ上限がかかる。
   - 表・コールアウト・図は途中で改ページしない。表は行単位で分かれ、各ページにヘッダ行が付く。
   - 残りのページに収まらない図・表の行・コードブロックは、まとめて次のページに送られる。そのため直前の短い段落の後に余白が残ることがあるが、これは想定どおりの動作である。
   - `<pre>` は印刷時に折り返す。横スクロールで隠れる部分はない。
   - 外部リンク（`http` で始まる `href`）は、印刷時にリンク文字列の後ろにURLを括弧書きで出す。出典一覧のようにリンク文字列がURLそのものの場合は、URLが二重に出ないよう `<a>` に `class="plain-url"` を付ける。
   - ページ番号は未対応（Chrome はCSSのページマージン領域に対応していない）。
   - 保存時の推奨設定は、用紙サイズA4、「ヘッダーとフッター」オフ。

## 手順B: 作図（既定＝Mermaid）

- 図は既定で **Mermaidをそのまま `<pre class="mermaid">` としてHTML内に直接記述**する（画像化しない）。
- `</body>` 直前に、CDN経由でMermaidを読み込み描画する `<script type="module">` を1つだけ挿入する。
- 詳細なテーマ設定（本スキルのデザイントークンに合わせた色・フォント指定）、具体例、オフライン時の劣化挙動については `references/mermaid-conventions.md` を参照する。
- オフライン環境では図がプレーンテキストとして表示されるが、これは想定内でありAI可読性の観点から問題ない。

## 手順B': PlantUML（明示指示時のみ）

- 利用者が**明示的にPlantUMLでの作図を指示した場合のみ**この手順を使う。
- 詳細な手順・ハウス skinparam・カラーパレットは `references/plantuml-conventions.md` を参照する。
- 概要フロー: `.puml` を作成 → jarの実行系を `PLANTUML_JAR` 環境変数 → PATH上の `plantuml` コマンド → `<skill-dir>/scripts/plantuml.jar` の優先順で解決してPNG生成（jarはこのスキルに同梱されておらずマシンごとに用意が必要。詳細は `references/plantuml-conventions.md`）→ HTML内に相対パスで `<img src="図.png">` を記述 → 手順Cの `pack_doc.py` がdata URIへ変換する（別コマンドは不要）→ `.puml` ソースは生成後も残しておく。Mermaid経路は追加セットアップ不要でClaude Code on the webでもそのまま動作するが、PlantUMLはローカル実行系が必要なためそうしたサンドボックスでは使えないことがある。

## 手順D: インタラクティブ・ビジュアル版（明示指示時のみ）

利用者が**HTML出力を指示し、かつ「インタラクティブ版」「ビジュアル版」「経営層向けに動く資料」等を指示した場合のみ**この手順を使う。どちらか一方しか指示がなければ手順Aを使う。操作要素は表示の切替だけで、データの入力・送信・保存は扱わない。

手順Aの1〜7を土台に、以下を上書き・追加する。

### D-1 レイアウトパターンの選択（必須）

執筆を始める前に、AskUserQuestion で次の3つを1問として提示し、1つだけ選ばせる（利用者が既にパターン名を挙げている場合はこの確認を省く）。**1文書につき1パターン**とし、文書内にパターンの切替UIは置かない。

| 選択肢ラベル | パターン | 向いている資料 |
|--------------|----------|----------------|
| ダッシュボード型 | `dashboard` | 全体像を1画面で見せ、関心のある面だけ深掘りさせる提案書 |
| スクロール物語型 | `narrative` | 前提から結論まで順に納得させたい説明書・設計書 |
| フロー中心型 | `flow` | 中心となる1つのプロセスやループを軸に各段階を説明する資料 |

読み手の動線・弱点・選ぶ基準は `references/interactive-components.md` の比較表を参照する。

### D-2 組み立て

1. 骨格は `references/interactive-template.html` を複製し、**選ばなかった2つのパターン節**（`id="パターン-…"`）と、それに対応する目次の `<li>` を削除する。
2. `<head>` に `<link rel="stylesheet" href="style.css">` と `<link rel="stylesheet" href="interactive.css">` をこの順で置く（貼り付けない。どちらも編集しない）。
3. 方向（配色・書体・余白）の調整は、`<link>` の後ろの `<style data-tokens>:root{--iv-*: …}</style>` の中だけで行う（interactive.css のテキストは編集しない）。方向依存の値を他の箇所に書かない。
4. `<script>` は出力で2本のみ。1本目は `<script src="interactive.js"></script>` を `<body>` の**最初の要素の子**として置く（先行するHTMLコメントは構わない。`pack_doc.py` がインライン化する）、2本目は手順A-3の目次開閉スクリプトを `</div>` の後ろに置く。
5. コンポーネント（KPIタイル、タブセット、アコーディオン、シナリオ切替、フローノード選択、比較表、ロードマップ timeline、リソーススタック、SVG図版、詳細リンクチップ）のマークアップ・必須属性・クラス名は `references/interactive-components.md` に従う。

### D-3 段階的強化と印刷

- JavaScriptが無効でも全内容が読める状態を保つ。タブは `role="tablist"` の要素がマークアップ上 `hidden` なので列が現れず全パネルが縦に並び、アコーディオンは `<details open>` で開いたまま、シナリオ切替とフローノード選択はラジオとCSSの `:has()` だけで動く。
- 印刷時は全パネル・全アコーディオンが展開される状態にする。ホバーでしか読めない情報を作らない（ホバーは色の変化のみに使う）。動きの抑制は interactive.css が `prefers-reduced-motion` で処理するため、追加の指定は不要。

### D-4 数値のヘッジと詳細への送り

- KPIタイルは `.iv-kpi-hedge` の行を必ず伴う。その数値が概算か、どの仮定に依存するか、未検証かを**原稿の記述から書き写す**。原稿に根拠のない数値は書かず、必要な場合は「未算定」と書く。
- 概要側から詳細へ送るときは詳細リンクチップ（`.ref-chip`、`詳細 §7` の形）を使う。`href` は**同一文書内の実在する `id`**を指す。同じフォルダに姉妹HTML（例: 核心編に対する詳細編）が存在する場合に限り、`href="詳細編.html#id"` の形でその姉妹HTMLの実在する `id` を指してよい。姉妹HTMLが存在しない場合はリンクにせず、本文の言葉でその資料名を示す。外部URLには使わない。

### D-5 作図と書体

- 手順Dでは手順Bの既定（Mermaid直書き）に代えて、**SVGを直接書く**（外部参照ゼロ）。`role="img"` と `<title>`・`<desc>` を付け、`<desc>` にMermaid相当のソースを入れて機械可読性を担保する。
- Mermaidは利用者が明示的に指示した場合のみ使い、そのときに限り `<script>` が3本になる。
- 外部フォントは既定で不許可。採用したデザインが表示書体を要求する場合に限り、`fonts.googleapis.com` への `<link>` 1本を例外として許可し、`:root` の `--iv-font-figure`（KPIの数値・帯番号・timelineの番号）にだけ当てる。本文とSVG図版のラベルはシステム書体のままとし、フォールバック表示を正とする。

## 手順C: 検証

公開・共有前に、`python "<skill-dir>/scripts/pack_doc.py" 設計書.html` を実行する。`<link>`・`<script src>` のインライン化と画像のdata URI化を行い、`設計書.packed.html` を同じフォルダに書き出す（`-o PATH` で出力先を変更。入力は書き換えない）。`--lint-only` は書き出さずに検査だけを行う。`--allow` は繰り返し指定できる。終了コードは 0=エラーなし、1=エラーあり（何も書き出さない）、2=使い方の誤り（入出力の読み書きの失敗も2で、ERROR 行が出る）。共有・納品するのは `.packed.html` だけである。

1. `pack_doc.py` を実行し、エラー0件であること（警告は内容を確認する）。読者が実際に受け取る別ファイル（例: 講義資料docx）への言及は `--allow 名前` で許可する。

   pack_doc.py が検査する内容。
   - `<nav id="TOC">` があり、目次の `href="#x"` ごとに `<section id="x">` があること。
   - ローカルの `<link>` は `style.css` / `interactive.css` のみ、ローカルの `<script src>` は `interactive.js` のみ許可し、それ以外はエラーになる。`style.css` の `<link>` は必須。
   - `interactive.css` と `<script src="interactive.js">` は両方そろえて使い、`interactive.css` は `style.css` より後に置く。
   - 属性値が `http`・`https`・`//` で始まる参照（`srcset` を含む）、`@import`、`#` と `data:` 以外の `url(` はエラーになる。許可は `https://cdn.jsdelivr.net/npm/mermaid@11/` のMermaid import と、手順Dのみ `fonts.googleapis.com` の `<link>` 1本。外部への `<a href>` は警告になる。
   - `<script>` の本数は、手順Aで2本以下、手順Dでちょうど2本（Mermaid使用時は3本）。`<script src="interactive.js">` の有無で手順Dと判定する。
   - 埋め込み後のすべての `<img src>` が `data:` URIであること。画像ファイルが見つからない場合もここで報告される。
   - 本文または `href` に `.md` への言及がないこと（`--allow 名前` は末尾一致・大文字小文字無視）。
   - 開始タグと終了タグの対応。`id` の重複、`href="#"`、実在しない `#id`（複数 `id` を持つ `aria-controls` / `aria-labelledby` を含む）、姉妹リンク `別紙.html#id` の姉妹ファイル側の `id`、2つの `<fieldset>` にまたがるラジオの `name` の共有、`[data-tabs]` ごとの `data-default` パネルがちょうど1つであること。`<fieldset>` の外のラジオは警告になる。
   - 出力の `<style>` はちょうど1つで、空の `<style data-tokens>` は除かれる。
2. 本文中で元のMarkdownファイル（`*.md`）やその置き場所（フォルダ名・リポジトリパス）に言及していないこと。生成されたHTMLは単独で（元mdと切り離して）配布されうるため、「〜.mdを参照」「このフォルダの〜」のような分割前提の表現は使わず、該当箇所へのページ内リンク（`<a href="#id">`）または「本資料の「〜」」の言い回しに置き換える。複数mdを1つのHTMLに統合した場合は、章をまたぐ相互参照もすべてページ内アンカーに変換する。
3. ブラウザで実際に開き、以下を目視確認する。
   - フルHD（1920×1080）で目次が左に固定表示され、本文が読みやすい幅に収まっていること。
   - 目次が長い場合に目次だけが独立してスクロールすること。
   - 左上のボタンで目次が滑らかに開閉し、閉じたときに本文カラムが空いた幅の一部まで広がること。
   - 目次リンクのジャンプ先で見出しが画面上端に張り付いていないこと。
   - 印刷プレビュー（Ctrl+P）で、目次が1ページ目に全項目そろって出てリンクが機能すること（目次を閉じた状態で印刷しても同じ）。開閉ボタンが消え、本文が1カラム全幅になり、章ごとに改ページされること（章の区切りは手順A-8のとおり）。画像・表の行・コールアウトがページをまたいで切れていないこと。Mermaid の図が描画されていること（ネットワーク接続が必要）。見出し・表ヘッダ・コールアウトの色が保持されていること。手順Dの文書も目次が1ページ目になる。
   - PDFの出力はヘッドレスChromeで再現できる。`--virtual-time-budget` は、Mermaid の描画が終わるまで待ってから出力させるための指定である。

     ```
     "C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=10000 --print-to-pdf="out.pdf" "file:///C:/path/to/x.packed.html"
     ```
   - 文字化け・レイアウト崩れ・図の描画（Mermaidはオンライン時、PlantUMLは常時）に問題がないこと。

手順Dで作成した場合は、自動検査の部分に追加はない。以下の目視・照合の項目だけが加わる。

4. JavaScriptを無効にして開き、全パネル・全シナリオ・全ノードの内容が読めること。
5. 印刷プレビューで、タブ列・節ナビ・選択肢の列が消え、全パネルとアコーディオンが展開されていること。地色が付いた条件付きの箇所が白く抜けていないこと。
6. 本文中の数値が元の原稿と双方向で一致すること（原稿→HTML、HTML→原稿の両方向で照合する）。すべてのKPIタイルに `.iv-kpi-hedge` の行があり、概算・仮定・未検証の別が書かれていること。

## 禁止事項

- pandocを使用しない（Claudeが直接HTMLを記述する）。
- JavaScriptは次のものだけとし、それ以外は追加しない: 目次開閉のインラインスクリプト（手順A-3の数行）、Mermaid使用時のCDNスクリプト1本、手順Dのインタラクションスクリプト1本（`references/interactive.js` のインライン化）。出力の `<script>` は手順Dで2本（Mermaid明示指示時のみ3本）。ライブラリの読み込みは使わない。
- 外部CSS・外部フォント・外部画像を参照しない（`@import` および外部 `url()` を含む）。手順Dで採用デザインが表示書体を要求する場合に限り、`fonts.googleapis.com` への `<link>` 1本を例外として許可し、`--iv-font-figure` で数値表示（KPIの数値・帯番号・timelineの番号）にのみ使用する。本文とSVG図版のラベルには使わない。
- `<link rel="stylesheet">` と `src` 付き `<script>` を書いてよいのは、原稿の `style.css` / `interactive.css` / `interactive.js` に限る。`pack_doc.py` がこれらを除去してインライン化し、`.packed.html` には `<link>`（手順Dの `fonts.googleapis.com` を除く）と `src` 付き `<script>`（Mermaid CDNを除く）を残さない。
- ホバーでしか読めない情報を作らない。印刷したときに隠れたままになる内容を残さない。
- ダークモード対応を追加しない（共有・印刷を前提としたライトモード固定のデザイン）。

## Origin

user skills directory (html-design-doc)
