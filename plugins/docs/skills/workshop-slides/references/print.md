# 印刷の規則

## デッキ（deck.css の要点）

```css
@page { size: 1280px 720px; margin: 0; }
@media print {
  @page { size: 1280px 720px; margin: 0; }
  html, body { width: 1280px; height: auto; overflow: visible; background: #fff; print-color-adjust: exact; }
  .slide { position: relative; display: block !important; width: 1280px; height: 720px; break-after: page; break-inside: avoid; overflow: hidden; }
  .slide:last-child { break-after: auto; }
  .frag { opacity: 1 !important; visibility: visible !important; transform: none !important; }
  .hud, .progress, .hint, .timer { display: none; }
  .dim { opacity: 1; }
}
```

- `@page` を `@media print` の外と内の両方に置く。
- 1スライド1ページ。最後のスライドの後に白紙を出さない。
- 全段階（`.frag`）と回答例を表示する。アニメーションを止める。
- 画面だけの部品（ページ番号、進捗バー、操作の案内、タイマー）を隠す。
- 背景色を印刷するため `print-color-adjust: exact` を付ける。
- 印刷前に `?all` を付けて開くと、画面でも印刷と同じ状態を確認できる。

## ワークシート（worksheet.css）

- `@page { size: A4 landscape; margin: 8mm; }`。
- 画面では灰色の背景に用紙を置き、印刷では背景と「印刷する」ボタンを消す。
- 詳細は [worksheet.md](worksheet.md)。

## 検証での2通りの印刷

| モード | 設定 | 期待する結果 |
|--------|------|--------------|
| `css` | `preferCSSPageSize: true`、背景あり | デッキ: N ページ、すべて横（339×190mm）。ワークシート: 1ページ、A4横 |
| `default` | `preferCSSPageSize: false`、A4縦、余白約10mm、ヘッダーとフッターあり | デッキ: N ページ、すべて横。ワークシート: 1ページ、A4横 |

`default` は印刷ダイアログの既定値に近い条件で、CSS の用紙指定が効くかを確かめる。

## 利用者への案内（報告に含める）

- 印刷先は「PDFに保存」を選ぶ。
- 「Microsoft Print to PDF」は使わない。ドライバーの縦向きの用紙を使うため、内容が回転する。
- 他のプリンターで印刷する場合は、レイアウトを「横」にする。
- 詳細設定の「背景のグラフィック」をオンにする。
