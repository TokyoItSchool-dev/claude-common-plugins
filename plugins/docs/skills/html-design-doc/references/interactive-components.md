# 手順D コンポーネント集

手順D（インタラクティブ・ビジュアル版）で使うコンポーネントの一覧である。
各項目は、用途、貼り付けられるマークアップ、必須属性、JavaScript無効時の挙動、印刷時の挙動、アクセシビリティ上の注意の順で示す。

## 共通の前提

- `references/interactive.css` は `references/style.css` の**直後**に、同一の `<style>` 内へ全文を貼る。style.css は編集しない。
- `references/interactive.js` は `<body>` の**最初の要素の子**として貼る（HTMLコメントが先に来るのは構わない）。文書内の `<script>` はこれと目次開閉の2本のみとする。ただしMermaidを明示指示で使う場合に限り、CDNスクリプトが加わって3本になる。
- スクリプトは読み込み直後に `<body>` へ `js` クラスを、初期化完了後に `iv-ready` クラスを追加する。CSSはこの2つで段階的強化を切り替える。
- 操作要素は**表示の切替だけ**を行う。データの入力・送信・保存は扱わない。
- ホバーでしか読めない情報を作らない。ホバーは色の変化のみに使う。
- `id` は文書内で一意にする。同じ表やタイルを2か所に置く場合は接尾辞（`-a` / `-b`）で分ける。ラジオの `name` も同様に分ける。
- シナリオ切替とフローノード選択は `value` 属性で対応づける。`id` では対応づけない（複製したときに壊れるため）。

## レイアウトパターンの選択

文書全体の骨格は次の3つから**1つだけ**を選ぶ。1つの文書に複数を同居させない。
どれを選ぶかは手順Dの実行時に決め、以降その骨格で全編を書く。

| パターン | 向いている資料 | 読み手の動線 | 弱点 | 選ぶ基準 |
|----------|----------------|--------------|------|----------|
| `dashboard` | 全体像を1画面で見せ、関心のある面だけ深掘りさせる提案書 | 上部のタブで面を切り替える | 面をまたぐ比較がしにくい。タブを開かない面は読まれない | 読み手が忙しく、最初の1画面で結論を求める場合 |
| `narrative` | 前提から結論まで順に納得させたい説明書・設計書 | 上から下へ読み進める。節ナビで戻る | 縦に長く、全体像がつかみにくい | 論証の順序そのものが説得力になる場合 |
| `flow` | 中心となる1つのプロセスやループを軸に各段階を説明する資料 | 中央の図でノードを選び、右のレールで詳細を見る | 図に乗らない話題（体制、価格表など）の置き場所が乏しい | 資料の主題が「流れ」そのものである場合 |

3つとも本文の内容は同じ形式で書ける。違うのは外枠だけなので、途中でパターンを変えたくなった場合は骨格の差し替えで済む。

### `dashboard` の骨格

```html
<main class="main">
<section id="提案タイトル" class="level1">
  <h1>提案タイトル</h1>
  <p class="doc-meta">最終更新: 2026-09-04</p>

  <div class="iv-kpis"> ... KPIタイル4枚 ... </div>

  <div class="iv-tabs" data-tabs>
    <div class="iv-tablist" role="tablist" aria-label="観点の切替" hidden> ... </div>
    <section class="iv-tabpanel" id="面-要点" role="tabpanel" aria-labelledby="タブ-要点" data-default>
      <h2 class="iv-tabpanel-title">要点</h2>
      <div class="iv-dashboard">
        <div class="iv-panel"> ... </div>
        <div class="iv-panel"> ... </div>
        <div class="iv-panel iv-panel--wide"> ... 幅いっぱいに使うパネル ... </div>
      </div>
    </section>
    ...
  </div>
</section>
</main>
```

`.iv-dashboard` は幅60rem以上（screen）で2列になり、幅60rem未満と印刷では既定の1列のまま。2列の幅を占めさせたいパネルには `.iv-panel--wide` を足す。

### `narrative` の骨格

```html
<main class="main">
<section id="提案タイトル" class="level1 iv-narrative">
  <h1>提案タイトル</h1>
  <p class="doc-meta">最終更新: 2026-09-04</p>

  <nav class="iv-secnav" aria-label="節の一覧">
    <a href="#帯-要点">01 要点</a>
    <a href="#帯-価値">02 価値</a>
  </nav>

  <section id="帯-要点" class="level2 iv-band">
    <p class="iv-band-num">01</p>
    <h2>要点</h2>
    <div class="iv-kpis"> ... </div>
  </section>

  <section id="帯-価値" class="level2 iv-band">
    <p class="iv-band-num">02</p>
    <h2>価値</h2>
    <details class="iv-accordion" data-collapsible open> ... </details>
  </section>
</section>
</main>
```

`.iv-band` は偶数番目の背景が変わる。番号は `.iv-band-num` に手で書く（見出しの一部にはしない）。

### `flow` の骨格

```html
<main class="main">
<section id="提案タイトル" class="level1">
  <h1>提案タイトル</h1>

  <div class="iv-flow-grid">
    <div class="iv-switch">
      <figure class="iv-figure"> ... SVG図版 ... </figure>
      <fieldset>
        <legend>フェーズの選択</legend>
        <div class="iv-nodes"> ... ノード（ラジオ＋ラベル） ... </div>
      </fieldset>
      <div class="iv-flow-detail" data-set="a"> ... </div>
      <div class="iv-flow-detail" data-set="b"> ... </div>
    </div>

    <aside class="iv-rail" aria-label="補足">
      <div class="iv-rail-card"> ... </div>
    </aside>
  </div>
</section>
</main>
```

`.iv-nodes` と詳細パネルは同じ `.iv-switch` の中に置く。図版はノードの並びの上に置き、ノードそのものはHTMLで作る（SVG内のクリック領域は作らない）。

## タブセット

**用途**: 同じ主題を複数の観点で見せる。目次開閉を除けば、手順Dのコンポーネントのなかで唯一のJavaScript操作要素である。

```html
<div class="iv-tabs" data-tabs>
  <div class="iv-tablist" role="tablist" aria-label="観点の切替" hidden>
    <button type="button" class="iv-tab" role="tab" id="タブ-要点" aria-controls="面-要点">要点</button>
    <button type="button" class="iv-tab" role="tab" id="タブ-数字" aria-controls="面-数字">数字</button>
  </div>
  <section class="iv-tabpanel" id="面-要点" role="tabpanel" aria-labelledby="タブ-要点" data-default>
    <h2 class="iv-tabpanel-title">要点</h2>
    <p>本文</p>
  </section>
  <section class="iv-tabpanel" id="面-数字" role="tabpanel" aria-labelledby="タブ-数字">
    <h2 class="iv-tabpanel-title">数字</h2>
    <p>本文</p>
  </section>
</div>
```

**必須属性**: 外枠に `data-tabs`。`role="tablist"` の要素にマークアップ上の `hidden`。各タブに `id` と `aria-controls`、各パネルに `id` と `aria-labelledby`。既定で開くパネルに `data-default` を**必ず1つ**付ける。

`data-default` は省略可ではない。スクリプトの初期化が終わるまでの間、CSSは `data-default` の付いていないパネルを隠す。1つも付いていない `[data-tabs]` はその間ずっと中身が消えたまま表示される。1つの `[data-tabs]` に付けるのはちょうど1つとし、2つ以上付けない（先に現れたものが選ばれる）。

`aria-controls` が実在しない `id` を指すタブは、スクリプトが無視する（初期選択にもクリックにも反応しない）。タブとパネルの `id` の対応は必ず確認する。

**JS無効時**: タブ列は `hidden` のまま現れず、全パネルが縦に並ぶ。`.iv-tabpanel-title` が各パネルの見出しとして残るため、どの観点かは読める。

**印刷時**: タブ列が消え、全パネルとパネル見出しが展開される。

**アクセシビリティ**: 選択中のタブだけが `tabindex="0"`、他は `-1`（ローミングtabindex）。左右矢印、Home、Endで移動する。タブの高さは44px以上。パネル外のリンクがパネル内の `id` を指している場合、スクリプトが該当タブを開いてから移動する。タブセットが入れ子になっている場合は外側から順に開く。

## アコーディオン

**用途**: 根拠、前提、未検証事項など、読み飛ばしてよいが省けない情報を畳む。

```html
<details class="iv-accordion" data-collapsible open>
  <summary>前提と未検証の項目</summary>
  <div class="iv-accordion-body">
    <p>本文</p>
  </div>
</details>
```

**必須属性**: `data-collapsible`（印刷時展開の対象になる）。既定は `open` を付けて開いた状態にする。

**JS無効時**: `<details>` はブラウザの標準機能なので、開閉ともそのまま動く。

**印刷時**: スクリプトが `beforeprint` で閉じているものを開き、`afterprint` で元に戻す。CSSだけでは閉じた `<details>` を開けないため、この処理が必要である。

**アクセシビリティ**: `<summary>` の高さは44px以上。フォーカスリングを出す。開閉状態はブラウザが読み上げる。

**既定の開閉について**: すべての `<details>` に `open` を付けるのは、JavaScript無効時でも本文を読める状態を保つための必須条件である。一方でアコーディオンの数が多いと、全部開いた状態のページが縦に長くなる。1つのグループに置くアコーディオンは6個以下を目安にし、それを超える場合はタブで観点ごとに分けるなどしてグループを分割する。

## KPIタイル

**用途**: 判断の材料になる数値を並べる。**ヘッジ行（`.iv-kpi-hedge`）は必須**とし、その数値が概算か、仮定に依存するか、どの節に根拠があるかを必ず書く。

```html
<div class="iv-kpis">
  <div class="iv-kpi">
    <p class="iv-kpi-label">4ヶ月パッケージ　標準価格</p>
    <p class="iv-kpi-value">200万円</p>
    <p class="iv-kpi-hedge">実装150万円、教育50万円 <a class="ref-chip" href="#価格">詳細 §7</a></p>
  </div>
  <div class="iv-kpi is-conditional">
    <p class="iv-kpi-label">伴走リテイナー</p>
    <p class="iv-kpi-value is-long">月40万円から50万円</p>
    <p class="iv-kpi-hedge">有償リテイナーへ移行した場合に限る（概算） <a class="ref-chip" href="#収支">詳細 §8</a></p>
  </div>
</div>
```

**必須属性**: 3行すべて（ラベル、値、ヘッジ）。条件付きの数値には `is-conditional` を付ける。値が長い場合は `.iv-kpi-value` に `is-long` を足して字送りを落とす。

**JS無効時**: 変化しない。CSSグリッドのみで組む。

**印刷時**: 1列に展開され、`is-conditional` の地色が保持される。地色が条件付きであることの唯一の表現になるため、`print-color-adjust: exact` を当てている。

**アクセシビリティ**: タイルの並び順が読み上げ順になる。数値だけを大きくして意味を持たせない。ラベルとヘッジを必ず添える。

## 詳細リンクチップ

**用途**: 概要側の記述から詳細節へ送る。`詳細 §7` の形で使う。

```html
<a class="ref-chip" href="#価格">詳細 §7</a>
```

同じフォルダに姉妹HTML（例: 核心編に対する詳細編）が存在する場合に限り、そのファイルへのリンクも許可する。

```html
<a class="ref-chip" href="詳細編.html#価格">詳細編 §7</a>
```

**必須属性**: `href` は同一文書内の実在する `id`、または同じフォルダの姉妹HTMLの実在する `id` のどちらかを指す。外部URLには使わない。

**JS無効時**: 通常のページ内リンク、または姉妹HTMLへの通常のリンクとして動く。

**印刷時**: 地色を保持したまま印刷される（紙ではリンクが押せないので、節番号が読めることが条件になる）。

**アクセシビリティ**: インラインのテキストリンクであり、44pxの最小サイズは適用しない。文字色と地色のコントラストはAAを満たす。リンクテキストだけで行き先が分かるよう、節番号を必ず含める。

## シナリオ切替

**用途**: 前提を変えたときの数値の変化を、同じ場所で見比べさせる。JavaScriptは使わない。

```html
<div class="iv-switch">
  <fieldset>
    <legend>助成金の適用</legend>
    <div class="iv-choices">
      <input type="radio" class="iv-radio" name="助成" id="助成-あり" value="a" checked>
      <label class="iv-choice" for="助成-あり">助成あり</label>
      <input type="radio" class="iv-radio" name="助成" id="助成-なし" value="b">
      <label class="iv-choice" for="助成-なし">助成なし</label>
    </div>
  </fieldset>
  <div data-set="a">
    <h4 class="iv-set-title">助成あり</h4>
    <p>本文</p>
  </div>
  <div data-set="b">
    <h4 class="iv-set-title">助成なし</h4>
    <p>本文</p>
  </div>
</div>
```

**必須属性**: 外枠に `iv-switch`。ラジオの `value` は `a` から `f` のいずれかとし、対応するパネルの `data-set` と一致させる。各パネルに `.iv-set-title`（常時表示）。ラジオの `name` は文書内で一意にする。`.iv-switch` を入れ子にしない。

**JS無効時**: ラジオもCSSの `:has()` もJavaScriptを必要としないため、そのまま動く。

**印刷時**: 選択肢の列が消え、全パネルが展開される。`.iv-set-title` があるのでどの前提の数値かが読める。

**アクセシビリティ**: ラジオは視覚的に隠すだけで、フォーカス可能なまま残す（`clip-path` で隠し、`display:none` にはしない）。ラベルの高さは44px以上。矢印キーでの選択肢移動はブラウザの標準動作である。`:has()` に未対応のブラウザでは選択肢の列自体が消え、全パネルが並ぶ。

## フローノード選択

**用途**: 中心の図に対応する段階を選び、詳細を切り替える。シナリオ切替と同じ仕組みで、見た目だけが異なる。

```html
<div class="iv-switch">
  <figure class="iv-figure"> ... SVG図版 ... </figure>
  <fieldset>
    <legend>フェーズの選択</legend>
    <div class="iv-nodes">
      <input type="radio" class="iv-radio" name="フェーズ" id="フェーズ-0" value="a" checked>
      <label class="iv-node" for="フェーズ-0">
        <span class="iv-node-title">Phase 0 診断</span>
        <span class="iv-node-meta">2週間</span>
      </label>
      <input type="radio" class="iv-radio" name="フェーズ" id="フェーズ-1" value="b">
      <label class="iv-node" for="フェーズ-1">
        <span class="iv-node-title">Phase 1 実装</span>
        <span class="iv-node-meta">3ヶ月</span>
      </label>
    </div>
  </fieldset>
  <div class="iv-flow-detail" data-set="a">
    <h4 class="iv-set-title">Phase 0 診断</h4>
    <p>本文</p>
  </div>
  <div class="iv-flow-detail" data-set="b">
    <h4 class="iv-set-title">Phase 1 実装</h4>
    <p>本文</p>
  </div>
</div>
```

**必須属性**: シナリオ切替と同じ。ノードは `<label>` で作り、SVG内にクリック領域を作らない。SVGは図として静的に描き、ノードの並びと同じ順序・同じ語で描く。

**JS無効時**: 動く（JavaScriptを使っていない）。

**印刷時**: ノードの列が消え、全詳細パネルが展開される。

**アクセシビリティ**: ラジオを隠す方法と最小サイズはシナリオ切替と同じ。ノードの見出しとSVG内のラベルを同じ文言にして、図と操作の対応を明示する。

## 比較表

**用途**: 競合や選択肢の横並び比較。style.css の表スタイルを土台にして、自社列の強調と横スクロールだけを足す。

```html
<div class="iv-table-scroll">
  <table class="iv-compare">
    <caption>比較（2026年9月調査時点の公開情報）</caption>
    <thead>
      <tr><th scope="col">比較項目</th><th scope="col">A社</th><th scope="col" class="iv-col-self">本サービス</th></tr>
    </thead>
    <tbody>
      <tr><th scope="row">価格</th><td>非公開</td><td class="iv-col-self">4ヶ月200万円</td></tr>
    </tbody>
  </table>
</div>
```

**必須属性**: 外枠の `.iv-table-scroll`（幅の広い表がページを横スクロールさせないため）。自社列のセルすべてに `iv-col-self`。行見出しは `<th scope="row">`。

**JS無効時**: 変化しない。

**印刷時**: 自社列の地色が保持される。表全体はページをまたがないよう `break-inside: avoid` が当たる。

**アクセシビリティ**: `scope` を列・行の両方に付ける。強調は色だけに頼らず、見出しの語（本サービス）でも分かるようにする。

## ロードマップ timeline

**用途**: 年度や段階の並びを、順序が意味を持つものとして示す。

```html
<ol class="iv-timeline">
  <li>
    <p class="iv-timeline-title">2027年度　FDE 2名</p>
    <p class="iv-timeline-meta">売上 約980万円 ／ 売上総利益 約▲1,080万円（概算）</p>
  </li>
  <li>
    <p class="iv-timeline-title">2028年度　FDE 4名</p>
    <p class="iv-timeline-meta">売上 約4,740万円 ／ 売上総利益 約240万円（概算）</p>
  </li>
</ol>
```

**必須属性**: `<ol>`（順序に意味があるため `<ul>` は使わない）。番号はCSSの `counter()` が描くので手で書かない。

**JS無効時**: 変化しない。

**印刷時**: 番号の地色が保持される。

**アクセシビリティ**: 番号は装飾（`::before`）なので読み上げられない。年度など識別に必要な情報は `.iv-timeline-title` の本文に書く。

## リソーススタック

**用途**: 稼働日数などの配分を、幅の比で見せる。

```html
<ul class="iv-stack">
  <li class="iv-stack-seg" style="--iv-days: 8">
    <span class="iv-stack-name">実装枠1　8日</span>
    <span class="iv-stack-note">月8日（週2日）、同時1社</span>
  </li>
  <li class="iv-stack-seg" style="--iv-days: 8">
    <span class="iv-stack-name">リテイナー2社　8日</span>
    <span class="iv-stack-note">1社あたり月4日</span>
  </li>
  <li class="iv-stack-seg is-internal" style="--iv-days: 4">
    <span class="iv-stack-name">社内活動　4日</span>
    <span class="iv-stack-note">対象外</span>
  </li>
</ul>
```

**必須属性**: 各項目に `style="--iv-days: N"`（幅の比になる）と、日数を含む `.iv-stack-name`。幅は目安であり、数値は必ず文字でも書く。

**JS無効時**: 変化しない。

**印刷時**: 地色が保持される。狭い紙幅では折り返して縦に並ぶ。

**アクセシビリティ**: リストとして読み上げられ、各項目の文字に日数が含まれるので、幅が読めなくても情報は欠けない。

## SVG図版

**用途**: 図は手順DではSVGで直接描く（外部参照ゼロ）。Mermaidは明示指示があるときだけ使う。

```html
<figure class="iv-figure">
  <svg class="iv-svg" style="--iv-svg-min: 800px" viewBox="0 0 800 200" role="img" aria-labelledby="図1-題 図1-説">
    <title id="図1-題">4ヶ月パッケージの流れ</title>
    <desc id="図1-説">flowchart LR
  P0[Phase 0 診断] --&gt; P1[Phase 1 実装]
  P1 --&gt; P2[Phase 2 教育]
  P2 --&gt; P3[Phase 3 伴走]</desc>
    <rect x="10" y="30" width="180" height="70" fill="#f6f8fa" stroke="#b8c1cc"></rect>
    <text x="100" y="60" text-anchor="middle" font-size="14" font-weight="700" fill="#14508f">Phase 0 診断</text>
    <text x="100" y="82" text-anchor="middle" font-size="12" fill="#1f2328">2週間</text>
  </svg>
  <figcaption>図1　4ヶ月パッケージの流れ</figcaption>
</figure>
```

**必須属性**: `viewBox` と `role="img"`、`aria-labelledby` で `<title>` と `<desc>` の両方を参照する。`<desc>` にはMermaid相当のソースを書く（機械可読性をここで担保する）。`width` / `height` 属性は付けず、CSSで幅100%にする。`viewBox` の幅が448px（幅640px以下の画面での表示幅の下限28rem）を超える場合は、`style="--iv-svg-min: <viewBox幅>px"` を付けて表示幅の下限を `viewBox` の幅に合わせる。

**文字サイズの計算**: 表示px＝`font-size` 属性値 × 表示幅 ÷ `viewBox` 幅。表示幅が `viewBox` 幅と同じなら属性値がそのまま表示pxになる。上の `--iv-svg-min` を付けておけば表示幅は常に `viewBox` 幅以上になるので、`font-size` 属性値を11以上にすれば表示11px以上が保証される。`--iv-svg-min` を付けない場合は、下限448pxで計算して `font-size` 属性値 ≧ 11 × `viewBox`幅 ÷ 448 を満たすこと。はみ出した分は `.iv-figure` が横スクロールする。印刷時は `min-width` が外れ、紙幅に合わせて縮む。

**色の扱い（例外）**: SVGの `fill` / `stroke` は直書きとし、`--iv-*` 変数を使わない。したがって `:root` の `--iv-*` を差し替えても**SVGの色は変わらない**。方向（配色）を変える場合はSVGも編集する。差し替えを検索置換で行えるよう、直書きしてよい値と対応するトークンを次に限定する。

| 直書きする値 | 対応するトークン | 図中の用途 |
|--------------|------------------|------------|
| `#14508f` | `--iv-accent-dark` | ノードの見出し文字 |
| `#1f2328` | `--iv-fg` | 本文相当のラベル |
| `#5a6472` | `--iv-fg-muted` | 補足・注記のラベル |
| `#f6f8fa` | `--iv-panel-alt` | ノードの地色 |
| `#ffffff` | `--iv-panel` | 抜きのノードの地色 |
| `#b8c1cc` | `--iv-border-strong` | 枠線・矢印 |
| `#fff7e6` | `--iv-hedge-bg` | 条件付きノードの地色 |
| `#e0a02a` | `--iv-hedge-border` | 条件付きノードの枠線 |
| `#8a5300` | `--iv-hedge-fg` | 条件付きノードの文字 |

この表にない色をSVGに書かない。

**JS無効時**: 変化しない。

**印刷時**: そのまま印刷される。`min-width` が外れて紙幅に収まる。

**アクセシビリティ**: 日本語ラベルは自動折り返しされないため、長い文言は `<tspan>` で手で分ける。文字サイズは**表示上**11px以上にする。この11pxは `font-size` 属性の値ではなく、縮尺されたあとの見た目のサイズを指す（上の「文字サイズの計算」を満たすこと）。図だけで完結させず、同じ結論を本文にも書く。

## 検証

手順Dの文書は、手順Cの1から6に加えて次を確認する。

1. JavaScriptを無効にして開き、全パネル・全シナリオ・全ノードの内容が読めること。
2. 印刷プレビューで、タブ列・節ナビ・選択肢の列が消え、全パネルとアコーディオンが展開されていること。地色が付いた条件付きの箇所が白く抜けていないこと。
3. 本文中の数値が元の原稿と双方向で一致すること（原稿→HTML、HTML→原稿の両方向で照合する）。KPIタイルにはヘッジ行があること。
4. 外部参照がゼロであること。`http`、`@import`、`url(`、`src=` をグレップし、ルールを説明したコメント以外に出現しないこと。`@import` と `url(` は style.css と interactive.css のヘッダコメントからそれぞれ1件ずつ、合計2件ヒットするのが正常なベースラインである（このコメント以外に出現しないことを確認する）。`<script>` は2本のみであること（Mermaidを明示指示された場合のみCDNスクリプトが加わって3本）。
5. タグの整合が取れていること（開始タグと終了タグの対応をパーサで確認する）。
6. すべての `aria-controls`、`aria-labelledby`、`href="#…"` が実在する `id` を指すこと。同一文書内を指す `href="#id"` は本文中に `id="id"` を持つ要素があることをグレップで突合する。姉妹HTML（`詳細編.html#id` の形）を指す場合は、リンク先の姉妹HTMLファイルを別途グレップし、その `id` が実在することを確認する。
7. 同じ内容を複数箇所に置いた場合、`id` とラジオの `name` が重複していないこと。
8. `.iv-kpi-hedge` の出現数を数える場合は `<body>` 以下（本文）のみを対象にする。`<style>` 側のCSSには `.iv-kpi-hedge` セレクタが2つ含まれるため、文書全体をグレップすると本文のタイル数と一致しない。
9. すべての `[data-tabs]` に `data-default` の付いたパネルがちょうど1つあること（0個でも2個以上でも不可）。
10. `viewBox` の幅が448pxを超えるSVGに `style="--iv-svg-min: <viewBox幅>px"` が付いており、`font-size` 属性値が11以上であること。
11. SVGの `fill` / `stroke` の値が「SVG図版」の色対応表にある9色だけであること。
