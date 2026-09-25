---
name: changelog-commit
description: CHANGELOG 更新・バージョンバンプ・コミット・タグ・push を一括実行する（原則 main ブランチ専用）。「リリースして」「CHANGELOG を更新してコミットして」「バージョンを上げて」と明示的に言われた時に使用。引数は `[major|minor|build] [説明(任意)]`。通常のコミットには使用不可 — `core-dev:git-workflow` を使用すること。他の作業の流れで暗黙に発動させない。
argument-hint: "[major|minor|build] [説明(任意)]"
---

# changelog-commit スキル

git履歴から変更内容を収集し、機能単位でまとめた`docs/CHANGELOG.md`エントリを作成し、バージョンを更新して自動的にコミットする。明確にスキルを呼び出したときのみ実行する。

**原則mainブランチ専用。** main以外のブランチでは、ユーザーが明示的にこのスキルを呼び出した場合を除き実行しない（他の処理の流れで暗黙に発動させない）。

| モード | 発動条件 | 動作 |
|--------|---------|------|
| **mainモード（既定）** | mainブランチ | 実行時点までの未記録の変更（マージ済みブランチの変更を含む）を取り込み、CHANGELOG作成・バージョンバンプ（既定build）・コミット・タグ・push |
| **ブランチモード** | main以外＋明示的な呼び出し | ユーザーに確認のうえ、(a) mainへマージして恒例のmainモード処理（CHANGELOG作成等）を実行、または (b) PR作成のみ（CHANGELOG処理なし） |

## 呼び出し方

```
/core-dev:changelog-commit              # 既定バンプは build
/core-dev:changelog-commit minor        # minorバージョンをバンプ
/core-dev:changelog-commit build        # buildバージョンをバンプ
/core-dev:changelog-commit major "説明"  # majorバンプ + 説明付き
```

---

## 実行手順

### Step 0: VCS判定とブランチ判定

まずjjが利用可能か確認する:

```bash
jj root --ignore-working-copy
```

- **exit 0** → jjモードで実行（colocated運用が一般的）
- **exit非0 / コマンドなし** → gitモードで実行

履歴参照系コマンド（`git log`、`git branch --show-current`）はcolocatedリポジトリでもgitのまま使用する。書き込み系操作（ステージング・コミット・タグ・push）のみjjモードで切り替える。

続いてブランチを判定する:

```bash
git branch --show-current
```

jjモードでこれが空文字を返す場合（detached HEAD）は、`jj log --no-graph -r @ -T 'bookmarks'` でbookmarkからブランチを特定するか、ユーザーに確認する。

- **main** → mainモードで実行（Step 1 へ）
- **main以外** → ユーザーが明示的に本スキルを呼び出した場合のみブランチモードへ（次節へ）。暗黙の呼び出しであれば「mainブランチ以外では実行しません」と報告して終了する

---

## ブランチモード（main以外・明示呼び出し時のみ）

CHANGELOG作成は行わず、mainへの取り込み方法をユーザーに確認する:

```
main以外のブランチです。どちらを実行しますか？
  1. mainへマージし、続けてCHANGELOG作成等のmainモード処理を実行
  2. PRを作成する（PR作成のみ。CHANGELOG処理は行わない）
```

### 選択1: mainへマージ

未コミットの変更があれば先にコミットするようユーザーに確認する。その後:

```bash
git switch main
git pull
git merge {ブランチ名}
```

コンフリクトが発生した場合は解消をユーザーと相談する。マージ完了後、**mainモード（Step 1）へ進み**、恒例どおりCHANGELOG作成〜タグ・pushまで実行する。

jjモードではbookmark運用に応じて `jj new main {ブランチ名}` 等で統合し、mainのbookmarkを進める。

### 選択2: PR作成

PRを作成して終了する（CHANGELOG・バージョン・タグの処理は一切行わない）:

```bash
git push -u origin {ブランチ名}
gh pr create --base main
```

PRタイトル・本文はブランチのコミット履歴から要約して生成する。作成したPRのURLを報告して終了する。

---

## mainモード

実行時点までの未記録の変更（直接コミット・マージ済みブランチの変更を含む）をすべて取り込んで記録する。

### Step 1: ベースラインを特定

1. `package.json` から現バージョンを取得する
2. `docs/CHANGELOG.md` の最初の `## [x.y.z]` ヘッダーから最終記録バージョンを確認する
3. そのバージョンエントリを作成したコミット（CHANGELOGへの更新コミット）以降を対象とする
   - CHANGELOGが未記録の場合: 直近50コミットを対象にするかユーザーに確認する

### Step 2: コミット履歴を収集

```bash
git log {BASE}..HEAD --format="%H|%s" --no-merges
```

マージコミット自体は除外するが、マージで取り込まれたブランチ側のコミットは上記範囲に含まれるためそのまま対象とする。

各コミットメッセージを正規表現 `【([^】]+)】([^【]*)` で解析してタグと説明を抽出する。
既知のtypo: `【chenge】` は `【change】` として扱う。
複数タグのコミット（例: `【add】機能A【fix】修正B`）は、タグ境界で分割して別エントリとして扱う。

**タグ → セクション マッピング（表示順）:**

| コミットタグ | CHANGELOGセクション |
|---|---|
| `【add】` | ### 追加 |
| `【update】` | ### 改善 |
| `【fix】` | ### 修正 |
| `【change】` | ### 変更 |
| `【remove】` | ### 削除 |
| `【clean】` `【disable】` | ### その他 |
| タグなし / `feat:` | → 内容から推定して分類（スキップしない） |

### Step 3: 機能単位でグルーピングしてユーザーに提示

収集した変更を**機能レベル**でまとめてユーザーに提示する。

**グルーピングルール:**
- 同一機能に関する複数コミットは1エントリに集約する
- 同日の連続コミットで同一機能・同一目的のものは必ず集約する
- 追加後に削除された機能（対象範囲内で追加→削除）はエントリから除外する

**記載ルール:**
- 簡潔に、ユーザーに必要な情報のみを記述する
- コードの変更内容・ファイル名などの実装詳細、詳細すぎる変更内容、変更に至った細かな経緯や背景は記載しない（ユーザーが読んでも理解できないため）
- 「何が変わったか（機能・挙動）」を人間が読みやすい形で記述する

良い例:
```
### 追加
- サーバータイムアウト処理とリクエスト中断ハンドリング
```

悪い例:
```
### 追加
- server/narrationRoutes.ts にタイムアウトミドルウェアを追加
```

悪い例（詳細・経緯が多すぎる）:
```
### 追加
- 当初はクライアント側でタイムアウトを検知していたが再現性が低かったため、
  サーバー側のExpressミドルウェアでリクエストごとにタイマーを設定し、
  30秒経過でAbortControllerを発火させる方式に変更してタイムアウト処理を実装
```

提示後、記載内容に修正が必要かユーザーに確認する。

### Step 4: バージョンバンプ

**デフォルトは `build` (Z+1)。** 引数や指示で明示的に指定されない限り `minor` / `major` にバンプしない。

引数で指定がない場合、以下を確認する:
```
バージョンバンプの種類を選択してください:
  build: X.Y.Z → X.Y.(Z+1)  ★デフォルト
  minor: X.Y.Z → X.(Y+1).0
  major: X.Y.Z → (X+1).0.0
```

**minor/major提案タイミング（提案のみ・自動適用しない）:**
- 大きな機能追加を含む統合リリースではminorを提案してよい
- 破壊的変更（既存APIの削除・非互換変更）が含まれる場合はmajorを提案する

### Step 5: ファイルを更新

アンカーコメント `<!-- 新しいエントリはこの行の直下に追加 -->` の直下に新エントリを挿入する。

```markdown
## [X.Y.Z] - YYYY-MM-DD

### 追加
- ...

```

`package.json` の `"version"` フィールドも更新する。

---

## Step 6: コミットと結果報告

### 6-1: 変更をステージング

gitモードの場合:
```bash
git add .
```

jjモードの場合、working copyは自動追跡されるためステージングは不要（スキップ）。

### 6-2: コミット

CHANGELOGに記録した変更内容を短く要約したコミットメッセージを生成する。
バージョン番号を末尾に付記する。

メッセージ例:
- `TTS前処理のLLM除去、ボイス設定追加 (v2.1.1)`
- `設計書テンプレート拡張、ページ数指定UI追加 (v2.2.0)`
- `カウンター助数詞の読み上げ修正 (v2.1.2)`

gitモードの場合:
```bash
git commit -m "{変更内容の要約} (vA.B.C)"
```

jjモードの場合:
```bash
jj commit -m "{変更内容の要約} (vA.B.C)"
```

### 6-3: タグ付け（必須）

タグ付けはリリース版を確定させる必須ステップである。省略しない。軽量タグではなく注釈付きタグを作成する。jjにネイティブなtagコマンドはないため、colocatedリポジトリではjjモードでもgitのままタグを作成する:
```bash
git tag -a vA.B.C -m "{コミットメッセージと同じ要約}"
```

タグをpushすると、リポジトリに `.github/workflows/release.yml` が存在する場合はGitHub Actionsのリリースワークフローが起動し、`docs/CHANGELOG.md` からGitHub Releaseを作成する（通知連携の有無はワークフローの内容による）。該当ワークフローがないリポジトリではタグのpushのみが行われる。

#### タグを push できない環境（Claude Code クラウドセッション等）

Claude Code クラウドセッション（Claude Code on the web）ではブランチのpushはできるが、タグのpushはできない。`git push origin vA.B.C` は git-receive-pack から `HTTP 403` で拒否され、GitHub REST API の `git/refs` 書き込みもセッションのプロキシで拒否される。

**判定方法:** 次のいずれかに該当する場合、この手順に切り替える。

- 環境変数 `CLAUDE_CODE_REMOTE=true` が設定されている
- ブランチ（main）のpushは成功したが、`git push origin vA.B.C` が git-receive-pack から `HTTP 403` を返した

**前提条件:** リポジトリの `.github/workflows/release.yml` が、workflow_dispatch でのタグ作成に対応していること。具体的には次を満たす。

- `workflow_dispatch` の入力に `version` を持つ
- Actions 内で `GITHUB_TOKEN` を使って注釈付きタグ `v<version>` を作成するジョブ（tag ジョブ）がある
- tag ジョブが、`package.json` と `docs/CHANGELOG.md` に当該バージョンが記載済みであること、および同名タグが未作成であることを検証する
- GitHub Release の作成とビルドを同じ run 内で実行する（`GITHUB_TOKEN` でpushしたタグは `on: push` を起動しないため）

SlideGen_AI はこの構成を実装済みである（tag ジョブあり。既存タグのビルドを再実行する `rebuild` 入力あり）。

`release.yml` が上記に対応していない場合は、タグ作成を行わずに終了し、ローカル環境から次のコマンドでタグをpushするようユーザーに案内する（`<sha>` はpush済みのリリースコミット）:

```bash
git fetch origin main
git tag -a vA.B.C <sha> -m "{コミットメッセージと同じ要約}"
git push origin vA.B.C
```

**手順:**

1. コミットは 6-4 と同じ手順でmainへpushする
2. タグはローカルで作成しない。403 で判定した場合など、ローカルに作成済みのタグは `git tag -d vA.B.C` で削除する
3. リポジトリの Release ワークフローを workflow_dispatch で `version=A.B.C` を指定して起動する

   GitHub MCP ツールを使う場合は `actions_run_trigger` を次の引数で呼び出す:

   ```text
   method: run_workflow
   workflow_id: release.yml
   ref: main
   inputs: {version: "A.B.C"}
   ```

   `gh` が利用できる環境では次のコマンドで起動する:

   ```bash
   gh workflow run release.yml -f version=A.B.C
   ```

4. run の完了を待ち、run の結論（conclusion）が `success` であることを確認する
5. 次のコマンドでタグがリモートに存在することを確認する:

   ```bash
   git ls-remote --tags origin vA.B.C
   ```

run が失敗した場合はエラーとしてログを確認し、ユーザーに報告する。空コミットのpushや、同じ version での再 dispatch による再試行は行わない（tag ジョブは既存タグを拒否する）。既存タグの成果物を再ビルドする必要がある場合に限り、リポジトリが `rebuild` 入力を提供していればそれを使う。

### 6-4: push

先にコミットをpushし、次にタグを反映し、最後にタグのリモート到達を確認する。

gitモードの場合、まずコミットをpushする:

```bash
git push
```

コミットのpush後、タグも必ず反映する。通常の環境では次のコマンドでタグをpushする。タグをpushできない環境（6-3「タグを push できない環境」参照）では、代わりに Release ワークフローを workflow_dispatch で起動してタグを作成する:

```bash
git push origin vA.B.C
```

タグの反映後は以下でリモートへの到達を確認する。見つからない場合はエラーとして報告する:

```bash
git ls-remote --tags origin vA.B.C
```

jjモードの場合、bookmarkが新しいコミットを指すよう必要に応じて更新してからコミットをpushする:

```bash
jj bookmark set main -r @-
jj git push
```

コミットのpush後、タグも必ず反映する。通常の環境では `git push origin vA.B.C` でpushし、タグをpushできない環境では 6-3 の workflow_dispatch の手順でタグを作成する。いずれの場合も最後に `git ls-remote --tags origin vA.B.C` でリモート到達を確認する。見つからない場合はエラーとして報告する。

リモートが未設定の場合はpushをスキップし、結果報告にその旨を記載する。

### 6-5: 結果を報告

```
## 完了

- モード: main / ブランチ（マージ後にmain処理） / ブランチ（PR作成のみ）
- VCS: git / jj
- バージョン: X.Y.Z → A.B.C
- 更新ファイル: docs/CHANGELOG.md, package.json
- 対象コミット数: N件
- コミット: 完了 ✓
- push: 完了 ✓ / スキップ（リモートなし）
- タグ: vA.B.C（push済み・リモート到達確認済み） / vA.B.C（Actions の Release ワークフローで作成・run URL・リモート到達確認済み）
- リリース: タグpushによりGitHub ActionsのリリースワークフローがRelease作成を実行（該当ワークフローがある場合） / workflow_dispatch で起動した Release ワークフローの同一 run 内でRelease作成・ビルドを実行（run URL・結論 success）
- PR: {URL}（PR作成のみの場合）
```

---

## `docs/CHANGELOG.md` 新規作成時のテンプレート

```markdown
# 変更履歴 (CHANGELOG)

本ドキュメントは本プロジェクトの変更履歴を記録します。

<!-- 新しいエントリはこの行の直下に追加 -->

## [{初回バージョン}] - {日付}

初回CHANGELOG作成。これ以前の変更履歴はgitログを参照してください。
```

---

## エッジケース対応

| ケース | 対応 |
|---|---|
| BASEが特定できない | 直近50コミットを対象にするかユーザー確認 |
| 変更コミットが0件 | 「記録すべき変更がありません」として終了 |
| CHANGELOGのアンカーコメントがない | 最初の `## [` 行の直前に挿入 |
| package.jsonにversionがない | エラーで終了、ユーザーに手動設定を案内 |
| `feat:` 形式のコミット | タグなしとして内容から推定して分類 |
| タグなしコミット | コミットメッセージの内容から適切なセクションを推定（スキップしない） |
| `【chenge】` typo | `【change】` として扱う |
| main以外で暗黙に呼び出された | 実行せず「mainブランチ以外では実行しません」と報告して終了 |
| マージでコンフリクト発生 | 解消方法をユーザーと相談。自動で強行しない |
| PR作成時にgh CLIが未認証 | `gh auth login` を案内して終了 |
| jjモードでブランチ名が取得できない（detached HEAD） | bookmarkから特定するかユーザーに確認 |
| タグの push が 403 で拒否される（クラウドセッション） | Release ワークフローの workflow_dispatch でタグを作成（6-3 参照） |
| release.yml が dispatch でのタグ作成に未対応 | ローカルからタグを push するよう案内して終了（6-3 のコマンドを提示） |
| dispatch した run が失敗 | ログを確認して報告。同じ version で再 dispatch しない（既存タグは拒否される） |
