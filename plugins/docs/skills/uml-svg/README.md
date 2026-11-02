# uml-svg

図解を、編集可能な手書きSVGとして作るスキルです。画像の忠実な再現と、文章からの新規作図の両方に対応しています。
描いたあとは、見た目と、分野ごとの記法の正しさを検証して修正します。

現在、詳しい分野ルールを収録しているのはUML（8種類の図について検証済み）と、構成案パッケージ図（再編・集約の提案図。研修教材 6 冊の再編で検証済み）です。
ほかの分野は汎用の手順で描けます。分野のルールを追加する手順も同梱しています。

## 構成

```
uml-svg/
├── SKILL.md                    汎用の手順・レイアウト・描く順番・ハマりどころ
├── references/
│   ├── uml.md                  UMLの記法チェックリストと図種ごとの組み立て方
│   ├── package-plan.md         構成案・再編・集約の提案図（pkgplan.py の使い方とチェックリスト）
│   └── adding-a-domain.md      分野ファイルが無い図の描き方と、分野の追加手順
├── scripts/
│   ├── diagsvg.py              部品ライブラリ（汎用部品とUML部品）
│   ├── pkgplan.py              構成案パッケージ図（plan_diagram / migration_diagram）
│   ├── compare.py              元画像との比較画像を作る
│   └── montage.py              一覧画像を作る
├── examples/uml/
│   ├── diagrams.py             UML図8種の生成例
│   ├── UML_review.md           レビュー記録の例
│   ├── montage.png             完成見本の一覧
│   └── out/*.svg               完成見本
└── examples/package-plan/
    ├── diagrams.py             構成案・集約の生成例
    ├── package-plan_review.md  レビュー記録
    └── out/*.svg               完成見本
```

SKILL.md は毎回読み込まれます。`references/` 以下は、必要な分野のときだけ読み込まれます。

## 導入

このスキルは `mori-claude-tools` マーケットプレイスの `docs` プラグインに含まれています。`docs` プラグインを導入すると `docs:uml-svg` として使えるようになります。

```
claude plugin install docs@mori-claude-tools
```

呼び出し方は2通りです。

- 自動：「〜の図をSVGで作って」と頼むと、Claudeが判断して使います。
- 明示：`/uml-svg 会員登録のシーケンス図を作って` のように指定します。

## 動作に必要なもの

- Python 3
- `cairosvg` と `Pillow`（`pip install cairosvg pillow`）
- 日本語フォント（Noto Sans CJK JP を推奨）

## 試し方

```
python examples/uml/diagrams.py                     # examples/uml/out/ に8枚のSVGを生成
python scripts/montage.py check.png examples/uml/out/*.svg
python examples/package-plan/diagrams.py            # examples/package-plan/out/ に構成案・集約の2枚を生成
```

## 更新履歴

- 2026-11-02: 構成案パッケージ図（`scripts/pkgplan.py`、`references/package-plan.md`、`examples/package-plan/`）を追加。
- 2026-10: 初版（UML 8 種）。
