# 検証のコマンド

すべて行い、結果を報告に含める。`S=${CLAUDE_PLUGIN_ROOT}/skills/workshop-slides/assets`、`OUT` は作業用フォルダ（成果物フォルダの外）とする。Python には `C:/...` 形式のパスを渡す（Git Bash の `/c/...` は Python が開けない）。

必要なもの: Python 3、Node 22 以上（`fetch` と `WebSocket` を使う）、Chrome（既定は `C:/Program Files/Google/Chrome/Application/chrome.exe`。環境変数 `CHROME` で変えられる）、pypdf。

## 1. 静的検査

```bash
python $S/check.py slides/index.html forbidden.txt
python $S/check.py design-docs/worksheet.html forbidden.txt
```

- タグの対応（閉じ忘れ、入れ子の誤り）、インラインの `<script>` ごとの `node --check`、外部URLの有無、禁止語を調べる。失敗すると終了コード 1。
- forbidden.txt には1行に1語を書く。設計書の「避けたい表現」の語と、差し替えた旧事例の語（業種名、旧事例の固有の語）を入れる。

## 2. スクリーンショットと配置の計測

```bash
node $S/shoot.mjs slides/index.html 1280 720 '?all' all $OUT
node $S/shoot.mjs slides/index.html 1920 1080 '?all' all $OUT
```

スライドごとに1行の JSON を出し、`$OUT/s<n>_<幅>.png` を保存する。

| 項目 | 基準 |
|------|------|
| `bad` | 空（舞台の外にはみ出た要素なし）。空でなければ終了コード 1 |
| `deadBand` | 表紙以外で 80 以下（中身の下に残る空白の高さ、1280 基準の px） |
| `minFont` | 本文は 19 以上。ラベル（`dt`、`.sublead`）が 16〜18 になるのは許容する。SVG 内の文字、`.tag`、`.hint`、`.qt`、`.timer` は計測しない |

そのあと、全スライドの画像を Read で開いて自分で見る。見るのは、余白の偏り、文字の重なり、小さい文字、1枚に要素が多すぎないか。

## 3. 操作の確認

第7引数の JS を、撮影の前に表示中のスライドで実行する。`?all` を付けずに開く。

```bash
X='(() => { const s=document.querySelector(".slide.active"); const k=e=>document.dispatchEvent(new KeyboardEvent("keydown",{key:e,bubbles:true}));
  const r={}; r.f0=s.querySelectorAll(".frag.shown").length; k("ArrowRight"); r.f1=s.querySelectorAll(".frag.shown").length;
  s.querySelector(".ans").click(); r.ans=s.querySelector(".ans").classList.contains("shown");
  const t=s.querySelector(".timer"); t.click(); r.timer=t.classList.contains("run"); t.click();
  k("ArrowLeft"); r.back=s.querySelectorAll(".frag.shown").length; return r; })()'
node $S/shoot.mjs slides/index.html 1280 720 '' 5 $OUT "$X"

X2='(() => { const s=document.querySelector(".slide.active"); s.querySelector("[data-hl-btn=\"hu\"]").dispatchEvent(new MouseEvent("click",{bubbles:true}));
  const r={on:s.dataset.hlOn, lit:s.querySelectorAll(".lit").length, dim:s.querySelectorAll(".dim").length};
  document.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape"})); r.esc=s.dataset.hlOn===undefined; return r; })()'
node $S/shoot.mjs slides/index.html 1280 720 '' 3 $OUT "$X2"
```

- 期待: `f1 = f0 + 1`、`ans: true`、`timer: true`、`back` が1減る、`on: "hu"`、`lit` が 1 以上、`esc: true`。`dim` は他に `data-hl` を持つ要素があるスライド（`flow` 型など）で 1 以上になる。
- SVG の要素には `.click()` が無いため、`dispatchEvent(new MouseEvent("click", {bubbles: true}))` を使う。
- `_x.png` の画像で、強調と回答例の見た目も確かめる。

## 4. PDF

```bash
node $S/pdftest.mjs "slides/index.html?all" $OUT/deck-css.pdf css
node $S/pdftest.mjs "slides/index.html?all" $OUT/deck-def.pdf default
node $S/pdftest.mjs design-docs/worksheet.html $OUT/ws-css.pdf css
node $S/pdftest.mjs design-docs/worksheet.html $OUT/ws-def.pdf default
python $S/pdfinfo.py $OUT/deck-css.pdf headers.txt
```

- headers.txt にはスライドの見出しと問いの文を1行ずつ書く。
- 期待: デッキは表紙を含む枚数と同じページ数で `landscape True`、ワークシートは `pages 1` で `landscape True`、`missing []`。

## 5. スキル自体の確認

スキルを変更したら、例の spec で一通り動くことを確かめる。

```bash
python $S/build.py $S/example-spec.json $OUT/index.html $OUT/worksheet.html
python $S/check.py $OUT/index.html && python $S/check.py $OUT/worksheet.html
node $S/shoot.mjs $OUT/index.html 1280 720 '?all' all $OUT
```
