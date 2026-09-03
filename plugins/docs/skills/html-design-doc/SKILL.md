---
name: html-design-doc
description: 設計書・説明書・俯瞰資料などのスタンドアロンHTMLドキュメントを、読みやすさ優先のシンプルなデザイン（左サイドバー目次＋本文1カラム）で直接生成する。ユーザーが明示的に「HTMLで作成」「HTML版がほしい」等とHTML出力を指示した時のみ使用。通常のドキュメントはMarkdownが既定。pandoc不使用。作図は既定でMermaidをHTMLに直接記述（CDN描画・AI可読）、明示指示時のみPlantUMLでPNG画像化しbase64埋め込み。WebアプリなどのUI用HTMLには使用不可。
---

# html-design-doc

設計書・仕様書・俯瞰資料などのドキュメントを、**Claudeが直接記述する**スタンドアロンHTMLとして出力するスキル。デザインは人間の可読性を最優先した簡素なもので、左に固定表示の目次、右に読みやすい幅の本文を置く2カラム構成をとる。pandocは使用しない。

## 適用条件

- **利用者が明示的にHTML出力を指示した場合のみ**使用する（例:「HTMLで作成して」「HTML版もほしい」）。指示がない場合、ドキュメントの既定形式はMarkdownのまま。
- 対象は設計書・説明書・俯瞰資料等の**読み物ドキュメント**。Webアプリ・管理画面などの**UI用HTML**には使用しない。
- 出力は外部ビルドツールに依存しない、単一HTMLファイルとして完結させる（pandoc不使用。Mermaid使用時のみ1本のCDNスクリプト参照が例外的に許可される）。

## 手順A: HTML本文作成

本文執筆前に `docs:cognitive-rhythm-writing` スキル（併読指定の `docs:japanese-tech-writing` を含む）を読み、その規範に従って本文を書く。

1. `references/template.html` を骨格として複製し、対象ドキュメントの内容に置き換える。

2. `<head>` 内の `<style>` タグの中身は、`references/style.css` の**全文をそのままコピーして入れる**（整形済みのまま。minifyしない）。スタイルは1つの `<style>` タグにまとめる。デザイントークン（`:root` のCSS変数）は必要に応じて調整してよいが、変更する場合は文書全体で一貫させる。

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

   開閉の実体は `</div>` の後ろに置く次のインラインスクリプト（これ以外のJavaScriptは追加しない）。ボタンはマークアップ上 `hidden` で、このスクリプトが表示に切り替える。したがってJavaScriptが無効な環境ではボタンが現れず、目次は開いたままになる（graceful degradation）。

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

## 手順B: 作図（既定＝Mermaid）

- 図は既定で **Mermaidをそのまま `<pre class="mermaid">` としてHTML内に直接記述**する（画像化しない）。
- `</body>` 直前に、CDN経由でMermaidを読み込み描画する `<script type="module">` を1つだけ挿入する。
- 詳細なテーマ設定（本スキルのデザイントークンに合わせた色・フォント指定）、具体例、オフライン時の劣化挙動については `references/mermaid-conventions.md` を参照する。
- オフライン環境では図がプレーンテキストとして表示されるが、これは想定内でありAI可読性の観点から問題ない。

## 手順B': PlantUML（明示指示時のみ）

- 利用者が**明示的にPlantUMLでの作図を指示した場合のみ**この手順を使う。
- 詳細な手順・ハウス skinparam・カラーパレットは `references/plantuml-conventions.md` を参照する。
- 概要フロー: `.puml` を作成 → jarの実行系を `PLANTUML_JAR` 環境変数 → PATH上の `plantuml` コマンド → `<skill-dir>/scripts/plantuml.jar` の優先順で解決してPNG生成（jarはこのスキルに同梱されておらずマシンごとに用意が必要。詳細は `references/plantuml-conventions.md`）→ HTML内に相対パスで `<img src="図.png">` を記述 → `python "<skill-dir>/scripts/embed_images.py" output.html` を実行しdata URIへ変換 → `.puml` ソースは生成後も残しておく。Mermaid経路は追加セットアップ不要でClaude Code on the webでもそのまま動作するが、PlantUMLはローカル実行系が必要なためそうしたサンドボックスでは使えないことがある。

## 手順C: 検証

完成したHTMLについて、公開・共有前に以下を確認する。

1. `<style>` の中身が `references/style.css` の内容と一致していること（意図的にトークンを調整した場合を除き、差分がないこと）。
2. `<nav id="TOC">` 内の全 `href="#x"` が、本文中の `id="x"` を持つ `<section>` と一致していること（グレップ等で突合する）。
3. ドキュメント内で許可される唯一の外部参照は、Mermaid使用時のCDNスクリプト1本のみであること。`http`・`@import`・`url(` をグレップし、外部CSS・外部フォント・外部画像の参照が残っていないことを確認する。JavaScriptは目次開閉のインラインスクリプトとMermaid CDNスクリプトの2本のみで、`<script>` タグが3本以上ないこと。
4. PlantUMLを使用した場合、すべての `<img>` の `src` が `data:` URIになっている（相対パスの画像参照が残っていない）こと。
5. 本文中で元のMarkdownファイル（`*.md`）やその置き場所（フォルダ名・リポジトリパス）に言及していないこと。生成されたHTMLは単独で（元mdと切り離して）配布されうるため、「〜.mdを参照」「このフォルダの〜」のような分割前提の表現は使わず、該当箇所へのページ内リンク（`<a href="#id">`）または「本資料の「〜」」の言い回しに置き換える。複数mdを1つのHTMLに統合した場合は、章をまたぐ相互参照もすべてページ内アンカーに変換する。出力HTMLを `\.md` や元フォルダ名でグレップし、0件であることを確認する（読者が実際に受け取る別ファイル、例えば講義資料docxへの言及は例外）。
6. ブラウザで実際に開き、以下を目視確認する。
   - フルHD（1920×1080）で目次が左に固定表示され、本文が読みやすい幅に収まっていること。
   - 目次が長い場合に目次だけが独立してスクロールすること。
   - 左上のボタンで目次が滑らかに開閉し、閉じたときに本文カラムが空いた幅の一部まで広がること。
   - 目次リンクのジャンプ先で見出しが画面上端に張り付いていないこと。
   - 印刷プレビュー（Ctrl+P）で目次と開閉ボタンが消え、1カラムで本文全幅になり（目次を閉じた状態で印刷しても同じ）、見出し・表ヘッダ・コールアウトの色が保持されていること。
   - 文字化け・レイアウト崩れ・図の描画（Mermaidはオンライン時、PlantUMLは常時）に問題がないこと。

## 禁止事項

- pandocを使用しない（Claudeが直接HTMLを記述する）。
- JavaScriptは次の2本のみとし、それ以外は追加しない: 目次開閉のインラインスクリプト（手順A-3の数行）と、Mermaid使用時のCDNスクリプト1本。ライブラリは一切読み込まない。
- 外部CSS・外部フォント・外部画像を参照しない（`@import` および外部 `url()` を含む）。
- ダークモード対応を追加しない（共有・印刷を前提としたライトモード固定のデザイン）。

## Origin

user skills directory (html-design-doc)
