---
name: anydoc
description: Officeファイル（xlsx/docx/pptx/pdf/ods等）をMarkdownに変換するRust製CLI「anydoc」（firecrawl/anydoc）のインストールと使用方法。「Officeファイルをmdに変換」「xlsxをMarkdown化」「anydocで変換」と言われた時、またはExcel/Word/PowerPointの内容をテキスト比較・LLM解析したい時に使用。閲覧のみで変換不要な場合は使用不可 — officecli を使用すること。
---

# anydoc — Office→Markdown変換CLI

Firecrawl製のRust製ドキュメント変換CLI。Officeファイルを単体のMarkdownに変換する。xlsxはシートごとに見出し＋Markdown表として出力されるため、**ブック同士のテキスト差分比較（diff）やLLMへの入力に適する**。

- リポジトリ: <https://github.com/firecrawl/anydoc>（crates.io のクレート名は `anydoc`）
- 対応入力: `doc, docx, odt, pdf, ppt, pptx, rtf, epub, xlsx, ods, odp, csv`
- 形式判定はファイル内容ベース（拡張子はフォールバック）

## インストール

推奨は npm 経由（初回実行時にプラットフォーム別のprebuiltバイナリを取得する。実体はRustバイナリでNode依存は配布のみ）。

```powershell
npm install -g @firecrawl/anydoc   # 恒久インストール（anydoc コマンドが使えるようになる）
anydoc --version                    # 動作確認（例: 0.1.8）
```

インストールせず単発利用する場合:

```powershell
npx @firecrawl/anydoc report.docx
```

Rustツールチェーンがある環境なら cargo でも導入できる:

```powershell
cargo install anydoc
```

## 基本使用方法

```powershell
anydoc input.xlsx                    # Markdownをstdoutへ
anydoc input.xlsx -o output.md       # ファイルへ出力
anydoc - --format csv < data.csv     # stdinから読み、--formatで形式指定
anydoc input.bin --format docx -o out.md   # 拡張子が無い/偽装されている場合の明示指定
anydoc --help                        # 全オプション
```

## バッチ変換（ディレクトリ一括）

`--output-dir` や再帰変換オプションは**存在しない**。1ファイル1起動でループする。元フォルダを汚さないよう、出力は必ず専用フォルダにミラーする。

Git Bash（相対パス構造を保って一括変換。日本語・スペース入りファイル名対応）:

```bash
SRC="/path/to/source_dir"; DST="/path/to/md_out"
(cd "$SRC" && find . -type f \( -iname '*.xlsx' -o -iname '*.docx' -o -iname '*.pptx' \)) \
  | sed 's/^\.\///' | while IFS= read -r rel; do
    mkdir -p "$DST/$(dirname "$rel")"
    anydoc "$SRC/$rel" -o "$DST/$rel.md" || echo "FAIL: $rel" >> "$DST/_errors.log"
  done
```

PowerShell:

```powershell
Get-ChildItem $src -Recurse -Include *.xlsx,*.docx,*.pptx | ForEach-Object {
  $rel = $_.FullName.Substring($src.Length + 1)
  $out = Join-Path $dst ($rel + ".md")
  New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
  anydoc $_.FullName -o $out
}
```

## 注意事項

- 出力mdのファイル名は「元ファイル名 + `.md`」とし（拡張子を置換しない）、元の拡張子情報を保持すると突合が楽になる。
- 変換元ファイルは読み取りのみ。**出力先を変換元フォルダ内にしない**こと。
- xlsxのふりがな（PHONETIC）データは出力に混入することがある。diff目的では両側とも同条件で変換すれば実害はない。
- ファイル名に末尾スペースや日本語が含まれていてもCLIは処理できるが、シェルのクォートを厳密に行うこと（`while IFS= read -r` パターン推奨）。
- 図形・画像内テキストや複雑な結合セルのレイアウトは失われることがある。差分の「有無」の検出には十分だが、レイアウト再現には使わない。
- 失敗ファイルは `_errors.log` 等に記録し、変換後に件数を元ファイル数と突合して欠落を検出する。

## サンドボックスでの利用可否

anydocはネイティブCLIバイナリのインストール・実行を要する。バイナリの導入や実行が許可されないサンドボックス環境（Claude Code on the web等）では、インストールに失敗する、またはコマンドが利用できないことがある。その場合は迂回策を試みず、この環境ではanydocを実行できない旨を利用者に伝えて中断する。

## Origin

user skills directory (anydoc)
