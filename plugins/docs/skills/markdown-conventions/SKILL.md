---
name: markdown-conventions
description: Markdownファイル（.md）を作成・編集するときに必ず適用する記述規範。HTML変換前提の空行ルールなど。ドキュメント、README、CHANGELOG、設計書、研修資料等あらゆるMarkdown出力時に使用。
---

# Markdown 記述規範

MarkdownはHTMLに変換される前提で記述する。

- ブロック要素の境界には空行を入れ、変換器が構文を確実に判別できるようにする。
  - 引用ブロック内で箇条書きを書く場合は、箇条書きの前後に空行（`>` のみの行）を挟んで確実に改行させる。
  - 見出し・表・コードフェンス・リストの前後にも空行を入れる。
- リストのネストはインデントを揃え、変換後に階層が崩れないようにする。

## Origin

user skills directory (markdown-conventions)
