# SVG 作図ルール（html-design-doc スキル）

このスキルで生成するHTMLドキュメントにおける、作図の既定手法（インラインSVGの直書き）のルールをまとめる。手順Aと手順Dの両方に適用する。手順D固有の規則（`.iv-figure` / `.iv-svg`、`--iv-svg-min`、文字サイズの計算）は `references/interactive-components.md` の「SVG図版」に従い、ここでは繰り返さない。

## 基本方針

- 図は `<svg>` をHTML本文に直接書く。外部参照・画像化・JavaScriptは使わない。
- Mermaid は利用者が明示的に指示した場合のみ使う（`references/mermaid-conventions.md`）。PlantUML も同様に明示指示時のみ使う（`references/plantuml-conventions.md`）。
- 図だけで完結させず、同じ結論を本文にも書く。

## 骨格

```html
<figure>
<svg viewBox="0 0 800 140" width="100%" role="img" aria-labelledby="図1-題 図1-説">
<title id="図1-題">処理の流れ</title>
<desc id="図1-説">flowchart LR
  A[入力] --&gt; B[処理]
  B --&gt; C[出力]</desc>
...
</svg>
<figcaption>図1　処理の流れ</figcaption>
</figure>
```

- `<figure>` で包み、`<figcaption>` に「図N　…」の図題を書く。
- `<svg>` には `viewBox`、`width="100%"`、`role="img"`、`aria-labelledby` を付ける。`height` 属性は付けない（高さは `viewBox` の縦横比で決まる）。
- `aria-labelledby` で `<title>` と `<desc>` の両方の `id` を参照する。`pack_doc.py` は参照先の `id` の実在を検査する。
- `<desc>` にはMermaid相当のソースを書き、機械可読性をここで担保する。`>` は `&gt;` と書く（`-->` は `--&gt;`）。
- `xmlns` 属性は書かない。HTMLに直接書くSVGでは不要であり、`xmlns="http://www.w3.org/2000/svg"` は `pack_doc.py` の外部参照検査（`http` で始まる属性値）でエラーになる。
- `id`（`<title>`・`<desc>`・`<marker>`）は文書全体で一意にする。インラインSVGの `id` はHTML本文と同じ名前空間に入る。

## 大きさ

- 手順Aでは `width="100%"` で本文幅（約860px）に合わせて拡大縮小する。`viewBox` の幅を800前後にすると、`font-size` 属性値がほぼそのまま表示pxになる。
- 横に短い図を本文幅まで広げたくない場合は、`style="max-width: <viewBox幅>px"` を付けて等倍以上に広げない。
- 文字は表示上11px以上にする。`viewBox` 幅800前後なら `font-size` 属性値は12〜14を使う。
- 印刷時は `style.css` の `svg[role="img"]` の規則で高さが最大230mmに縮み、途中で改ページしない。この規則は `role="img"` で当たるため、`role="img"` を省かない。
- 手順Dでは `class="iv-svg"` を付けて `width` 属性を書かず、`interactive-components.md` の「SVG図版」の大きさの規則に従う。

## 色と書体

- `fill` / `stroke` は16進の値で直書きする（プレゼンテーション属性では `var()` を使わない）。使ってよい値は `interactive-components.md` の「SVG図版」の色対応表の9色に限る。手順Aで対応する `style.css` のトークンは次のとおり。

  | 値 | `style.css` のトークン | 図中の用途 |
  |----|------------------------|------------|
  | `#14508f` | `--accent-dark` | ノードの見出し文字 |
  | `#1f2328` | `--fg` | 本文相当のラベル |
  | `#5a6472` | `--fg-muted` | 補足・注記のラベル |
  | `#f6f8fa` | `--surface` | ノードの地色 |
  | `#ffffff` | `--bg` | 抜きのノードの地色 |
  | `#b8c1cc` | `--border-strong` | 枠線・矢印 |
  | `#fff7e6` | `--warn-bg` | 条件付きノードの地色 |
  | `#e0a02a` | `--warn-border` | 条件付きノードの枠線 |
  | `#8a5300` | `--warn-fg` | 条件付きノードの文字 |

- `:root` のトークンを差し替えてもSVGの色は変わらない。配色を変える場合はSVGの値も検索置換で揃える。
- `font-family` 属性は書かない。`<text>` は本文の書体（`--font-body`）を継承する。
- 日本語ラベルは自動で折り返されないため、長い文言は `<tspan>` で行を分ける。

## 矢印

矢印の先端は `<marker>` で定義し、線に `marker-end="url(#…)"` を付ける。マーカーの `id` は図ごとに一意な半角英数字にする（例: `fig1-arrow`）。

## 例1: 横並びのフロー

```html
<figure>
<svg viewBox="0 0 800 110" width="100%" role="img" aria-labelledby="図1-題 図1-説">
<title id="図1-題">文書生成の流れ</title>
<desc id="図1-説">flowchart LR
  A[素材の整理] --&gt; B[HTML本文の記述]
  B --&gt; C[pack_doc.py で検証]</desc>
<defs>
<marker id="fig1-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
<path d="M 0 0 L 10 5 L 0 10 Z" fill="#b8c1cc"></path>
</marker>
</defs>
<rect x="10" y="25" width="220" height="60" rx="6" fill="#f6f8fa" stroke="#b8c1cc"></rect>
<text x="120" y="61" text-anchor="middle" font-size="14" font-weight="700" fill="#14508f">素材の整理</text>
<rect x="290" y="25" width="220" height="60" rx="6" fill="#f6f8fa" stroke="#b8c1cc"></rect>
<text x="400" y="61" text-anchor="middle" font-size="14" font-weight="700" fill="#14508f">HTML本文の記述</text>
<rect x="570" y="25" width="220" height="60" rx="6" fill="#f6f8fa" stroke="#b8c1cc"></rect>
<text x="680" y="61" text-anchor="middle" font-size="14" font-weight="700" fill="#14508f">pack_doc.py で検証</text>
<line x1="230" y1="55" x2="288" y2="55" stroke="#b8c1cc" stroke-width="1.5" marker-end="url(#fig1-arrow)"></line>
<line x1="510" y1="55" x2="568" y2="55" stroke="#b8c1cc" stroke-width="1.5" marker-end="url(#fig1-arrow)"></line>
</svg>
<figcaption>図1　文書生成の流れ</figcaption>
</figure>
```

## 例2: 分岐と条件付きノード

```html
<figure>
<svg viewBox="0 0 800 200" width="100%" role="img" aria-labelledby="図2-題 図2-説">
<title id="図2-題">検証結果による分岐</title>
<desc id="図2-説">flowchart LR
  A[pack_doc.py 実行] --&gt;|エラー0件| B[packed.html を共有]
  A --&gt;|エラーあり| C[原稿を修正]</desc>
<defs>
<marker id="fig2-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
<path d="M 0 0 L 10 5 L 0 10 Z" fill="#b8c1cc"></path>
</marker>
</defs>
<rect x="10" y="70" width="220" height="60" rx="6" fill="#f6f8fa" stroke="#b8c1cc"></rect>
<text x="120" y="106" text-anchor="middle" font-size="14" font-weight="700" fill="#14508f">pack_doc.py 実行</text>
<rect x="520" y="10" width="270" height="60" rx="6" fill="#ffffff" stroke="#b8c1cc"></rect>
<text x="655" y="46" text-anchor="middle" font-size="14" fill="#1f2328">packed.html を共有</text>
<rect x="520" y="130" width="270" height="60" rx="6" fill="#fff7e6" stroke="#e0a02a" stroke-dasharray="5 4"></rect>
<text x="655" y="166" text-anchor="middle" font-size="14" fill="#8a5300">原稿を修正</text>
<path d="M 230 90 L 518 40" fill="none" stroke="#b8c1cc" stroke-width="1.5" marker-end="url(#fig2-arrow)"></path>
<path d="M 230 110 L 518 160" fill="none" stroke="#b8c1cc" stroke-width="1.5" marker-end="url(#fig2-arrow)"></path>
<text x="370" y="50" text-anchor="middle" font-size="12" fill="#5a6472">エラー0件</text>
<text x="370" y="160" text-anchor="middle" font-size="12" fill="#5a6472">エラーあり</text>
</svg>
<figcaption>図2　検証結果による分岐</figcaption>
</figure>
```
