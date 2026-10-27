# Mermaid 作図ルール（html-design-doc スキル）

このファイルは、利用者が **明示的にMermaidでの作図を指示した場合のみ**参照する（手順B-2）。既定の作図手法はSVG直書き（`references/svg-conventions.md`）である。

## 基本方針

- Mermaidのソースコードは、画像化せず **HTML内に `<pre class="mermaid">` として直接記述**する。
- 描画はページ読み込み時に jsdelivr CDN 経由でMermaid本体を読み込んで行う（ネットワーク接続がある環境でのみ図として描画される）。

## 埋め込みパターン

`<pre class="mermaid">` ブロックを本文中の該当箇所に記述し、`</body>` の直前に描画スクリプトを1回だけ挿入する。

```html
<pre class="mermaid">
flowchart TD
    A[M1: 価値主義のOS] --> B[M2: 単元A]
    B --> C[M3: 単元B]
    C --> D[M4: 単元C]
</pre>
```

`</body>` 直前（1ドキュメントにつき1回のみ）:

```html
<script type="module">import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs'; mermaid.initialize({ startOnLoad: true });</script>
</body>
</html>
```

実際のドキュメントでは、次節のテーマ設定を適用した形で記述する。

## デザイントークンに合わせたテーマ設定

図の見た目を `references/style.css` のデザイントークン（`--surface: #f6f8fa`、`--accent: #1b6ac9`、`--fg: #1f2328`、`--fg-muted: #5a6472`、`--font-body`）に揃えるため、`mermaid.initialize()` の `themeVariables` で以下のように指定する。

```html
<script type="module">
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
mermaid.initialize({
  startOnLoad: true,
  theme: 'base',
  themeVariables: {
    primaryColor: '#f6f8fa',
    primaryBorderColor: '#1b6ac9',
    primaryTextColor: '#1f2328',
    lineColor: '#5a6472',
    fontFamily: '"Segoe UI", "Hiragino Sans", "Yu Gothic UI", Meiryo, sans-serif',
    fontSize: '14px'
  }
});
</script>
```

図ごとに個別のスタイルを当てたい場合は、ドキュメント全体のスクリプトを変更せず、その図の `<pre class="mermaid">` 内側の先頭に `%%{init}%%` ディレクティブを1行加える方法でもよい。

```
%%{init: {'themeVariables': {'primaryColor': '#f6f8fa', 'primaryBorderColor': '#1b6ac9', 'lineColor': '#5a6472'}}}%%
flowchart TD
    A[入力] --> B[処理]
    B --> C[出力]
```

## オフライン時の挙動について

- CDNへ接続できない環境（オフライン、社内ネットワーク制限等）で開いた場合、Mermaidスクリプトが読み込まれず、`<pre class="mermaid">` の中身がプレーンテキストとしてそのまま表示される。
- これは **想定内の劣化であり、問題ではない**。ソースコードがそのまま読めるため、AIや人間の読者はテキストとして図の内容を理解できる（AI可読性を優先する設計）。
- オフラインでも図として見せる必要がある場合は、Mermaid ではなく既定の SVG 直書き（`svg-conventions.md`）を使う。

## 図の複雑さについて

- 可能な限り `flowchart TD`（またはシンプルな `graph TD`）を優先する。
- 1つの図に詰め込みすぎず、複数の小さな図に分割する方が、テキストとして読んだ際にも理解しやすい。
- シーケンス図・ガントチャート等が必要な場合も、Mermaid記法内で完結させ、外部画像化はしない。
