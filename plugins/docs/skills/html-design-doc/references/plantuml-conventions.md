# PlantUML 作図ルール（html-design-doc スキル・明示指示時のみ使用）

このファイルは、利用者が **明示的にPlantUMLでの作図を指示した場合のみ**参照する。既定の作図手法はMermaid（`references/mermaid-conventions.md`）であり、PlantUMLは人間の読者向けに画像として確実に見せたい場合の代替手段である。Mermaid経路は追加のセットアップなしにHTML内で直接描画され、Claude Code on the webのサンドボックスでもそのまま動作するが、PlantUMLはローカルの実行環境（後述のjarまたはplantumlコマンド）を必要とするため、そうしたサンドボックスでは利用できない場合がある。

## ハウス skinparam ブロック（改変せず使用）

```plantuml
@startuml
!pragma layout smetana
skinparam defaultFontName "Meiryo"
skinparam defaultFontSize 13
skinparam shadowing false
skinparam rectangle {
  BorderColor #607D8B
  RoundCorner 12
}
skinparam ArrowColor #455A64
skinparam TitleFontSize 18
```

- `!pragma layout smetana`: Graphviz（dot）非依存のPlantUML内蔵レイアウトエンジンを使う指定。Graphvizが未インストールの環境でも描画できる。
- 上記ブロックはそのまま流用し、値を変更しない。

## カラーパレット

| 用途 | 色 | 使用例 |
|:---|:---|:---|
| パッケージ背景 | `#FAFAFA` | `package "..." as X #FAFAFA { ... }` |
| 通常の矩形（背骨系） | `#ECEFF1` | `rectangle "..." as L1 #ECEFF1` |
| 強調矩形（戦略・重点等） | `#FFE0B2` | `rectangle "..." as L2 #FFE0B2` |
| 矩形の枠線 | `#607D8B`（skinparam BorderColor） | 全矩形共通 |
| 矢印線 | `#455A64`（skinparam ArrowColor） | 全矢印共通 |

## jarの入手について

`plantuml.jar` はこのスキルに同梱されていない（マシンごとに用意する必要がある）。実行前に、利用者に配置してもらうか、[PlantUMLの配布元](https://plantuml.com/download)から取得する。

## 実行手順

### 1. PNG生成（.puml → .png）

実行系は次の優先順で解決する。

1. 環境変数 `PLANTUML_JAR` が設定されていれば、そのパスのjarを使う。
2. 未設定なら、PATH上の `plantuml` コマンド（パッケージマネージャ導入時に入る実行スクリプト）を使う。
3. どちらもなければ、`<skill-dir>/scripts/plantuml.jar` を使う。

```bash
# 1. 環境変数優先
if [ -n "$PLANTUML_JAR" ]; then
  java -jar "$PLANTUML_JAR" 図.puml
# 2. PATH上のplantumlコマンド
elif command -v plantuml >/dev/null 2>&1; then
  plantuml 図.puml
# 3. スキル同梱パスへのフォールバック（同梱されていなければここで失敗する）
else
  java -jar "<skill-dir>/scripts/plantuml.jar" 図.puml
fi
```

`<skill-dir>` は本スキルのルート（このスキルのインストール先ディレクトリ）に読み替える。出力PNGは入力の `.puml` と同じディレクトリに、同名で `.png` 拡張子で生成される。上記いずれの経路も使えない場合は、jarが用意されていない旨を利用者に伝えて作図を中断する。

### 2. HTMLへの相対パス埋め込み

生成したPNGを、HTML内に通常の相対パス画像として記述する（この段階ではまだ通常のファイル参照）。

```html
<img src="図.png" alt="図の説明" />
```

### 3. base64埋め込み（スタンドアロン化）

HTMLを配布・保存可能な単一ファイルにするため、`scripts/embed_images.py` を実行して画像をdata URIへ変換する。

```bash
python "<skill-dir>/scripts/embed_images.py" output.html
```

実行後、`output.html` 内の `<img src="図.png">` は `<img src="data:image/png;base64,....">` に書き換えられる。

### 4. ソースの保持

`.puml` ファイルは中間生成物ではなく**恒久的なソース**として、生成したHTMLと同じディレクトリに残しておく。図を修正する際は `.puml` を編集し、手順1〜3を再実行する。

## 注意事項

- PlantUMLはMermaidと異なり、必ず画像化してからHTMLへ埋め込む（HTML内にPlantUML記法をそのまま書いても描画されない）。
- 大量の図を扱う場合も、1回のコマンドで複数の `.puml` を渡せば一括変換できる（`plantuml 図1.puml 図2.puml ...` または `*.puml` のワイルドカード指定）。
