---
argument-hint: [対象のissue番号やPRの補足説明（任意）]
name: create-pr
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(git reflog:*), Bash(git merge-base:*), Bash(git remote get-url:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh repo view:*)
description: "PRテンプレートに基づいてPull Requestを作成する"
disable-model-invocation: true
---

# Pull Request Creator (Generic)

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


> **変数の解決（重要）**: 本スキル内の `{{VARIABLE}}` はプラグイン配布時に自動置換されません。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成を調査して値を解決してください。解決できない場合のみユーザーに確認します。以下の「VARIABLES」表は既定値の参考です。

## VARIABLES — Fill these in before first use

| Variable                    | Description                                      | Example                          |
|-----------------------------|--------------------------------------------------|----------------------------------|
| {{REPO_URL}}                | Git remote URL (auto-detected if git is present) | https://github.com/org/repo.git |
| {{PACKAGE_MANAGER}}             | Package manager used in project                  | npm / yarn / pnpm / bun         |
| {{TYPE_CHECK_COMMAND}}      | Type check command                               | pnpm check-types / tsc --noEmit |
| {{LINT_COMMAND}}            | Lint fix command                                 | pnpm biome:fix / pnpm lint:fix  |
| {{PR_TEMPLATE_PATH}}        | Path to PR template                              | .github/PULL_REQUEST_TEMPLATE/pull_request_template.md |

> If `gh` CLI is configured and `git remote get-url origin` works, `{{REPO_URL}}` may be auto-detected.

はじめに `gh` が使えるかを確認して下さい。`gh` が使えない場合、ユーザに `gh` の設定を促す応答をして終了してください。
**GitHub を起点として作業を行うため、`gh` が利用できない場合は「`gh` が利用できないため終了します」と出力して終了してください**。
対象のレポジトリは `{{REPO_URL}}` です。

補足情報: $ARGUMENTS

## 基本動作

- **引数なし（`/create-pr`）**: 現在のブランチの変更内容を自動分析し、PRテンプレートに基づいてPRを作成します
- **引数あり（`/create-pr 245` や `/create-pr バグ修正の補足説明`）**: 指定された Issue 番号や補足情報を加味してPRを作成します

## 前提条件

- 現在のブランチが `main` や `develop` 等のベースブランチそのものでないことを確認してください。ベースブランチ上では PR を作成しません。
- 未コミットの変更がある場合はユーザーに通知し、コミットするか確認してください。
- 既に同一ブランチで Open な PR が存在する場合はユーザーに通知し、新規作成するか既存を更新するか確認してください。

## 対応手順

### 0. ベースブランチ（派生元ブランチ）の特定

PR のマージ先となるベースブランチを以下の優先順位で特定してください。いずれかで確定した時点でそれを採用します:

1. `git log --oneline --merges --first-parent HEAD` や `git reflog` を参考に、現在のブランチがどのブランチから派生したかを推測する
2. `git branch -a --contains $(git merge-base main HEAD)` などで共通の祖先から派生元を推測する
3. ブランチ名の命名規則から推測する（例: `feature/issue-123` → `main` や `develop`、`hotfix/xxx` → `main`）
4. リポジトリのデフォルトブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）をフォールバックとする
5. 上記で確信が持てない場合は、**ユーザーに確認してください**（例: 「ベースブランチは `main` で合っていますか？」）

以降の手順では、特定したベースブランチを `<base-branch>` として参照します。

### 1. 現在のブランチ状態を確認

以下を並列で確認してください:

- `git status` で未コミットの変更を確認
- `git branch --show-current` で現在のブランチ名を取得
- `git log <base-branch>..HEAD --oneline` でベースブランチからの全コミットを確認
- `git diff <base-branch>...HEAD --stat` で変更ファイルの統計を確認
- `gh pr list --head $(git branch --show-current) --state open` で既存PRの有無を確認

### 2. 変更内容の分析

コードベース解析ツール（利用可能な MCP 等）を活用して変更内容を分析してください:

1. `git diff <base-branch>...HEAD` で全変更差分を確認
2. 変更されたファイルの種類（フロントエンド/バックエンド/DB/インフラ/テスト）を分類
3. 変更の目的（新機能/バグ修正/リファクタリング/テスト追加/ドキュメント更新）を判定
4. `補足情報` が提供されている場合はその内容も加味する

### 3. 関連 Issue の特定

以下の優先順位で Issue 番号を特定してください。いずれかで見つかった時点でそれを採用します:

1. `補足情報` に Issue 番号が含まれている場合はそれを使用
2. ブランチ名から Issue 番号を推測（例: `feature/issue-123` → #123, `fix/issue-456` → #456）
3. コミットメッセージから `#数字` や `issue-数字` のパターンを検索
4. 上記で特定できない場合は、Issue なしとして進める（ユーザーに確認は不要、PR本文の「対応するIssue」欄は空欄にする）

### 4. PR テンプレートの記入

ユーザープロジェクトの `{{PR_TEMPLATE_PATH}}` を Read し、そのテンプレートに基づいて PR 本文を作成してください。

> **テンプレート未配置時のフォールバック**: `{{PR_TEMPLATE_PATH}}` がユーザープロジェクトに存在しない場合（本プラグインは cache にコピーされ cwd はユーザープロジェクトのため、同梱サンプル `.github/PULL_REQUEST_TEMPLATE/` は cwd 相対では参照されません）、`${CLAUDE_PLUGIN_ROOT}/.github/PULL_REQUEST_TEMPLATE/pull_request_template.md` のサンプルを参照するか、下記「各セクションの記入ガイドライン」の見出し構成をそのままテンプレートとして本文を生成してください。ユーザーへの確認は不要です。

各セクションの記入ガイドライン:

#### 対応するIssue
- `Closes #<番号>` の形式で記載
- 関連する Issue がない場合は「なし」と記載

#### 対応の背景・目的
- 変更の動機と目的を簡潔に記載（2-3文程度）
- Issue がある場合はその内容を要約

#### 対応概要
- 変更内容を箇条書きで記載
- 技術的な変更点を具体的に記述
- 変更ファイル数が多い場合はカテゴリごとにグルーピング

#### 影響範囲
- 変更が影響するモジュール・画面・API を列挙
- 後方互換性に関する情報も記載

#### 重点的にレビューしてほしい箇所・懸念点
- 特に注意深くレビューしてほしい箇所をファイルパス付きで記載
- 技術的に判断に迷った箇所や代替案がある箇所

#### 動作確認方法
- **前提条件**: 必要な環境設定やデータ準備
- **確認手順**: ステップバイステップで具体的に記載
- **期待される動作**: 各手順の期待結果
- **注意事項**: テスト時の注意点

#### 確認事項（作成者・エージェント向け）
- 以下をチェックし、該当するものにチェックを入れる:
  - `{{TYPE_CHECK_COMMAND}}` でエラーがないか
  - `{{LINT_COMMAND}}` でエラーがないか
  - テストが追加/更新されているか
  - セキュリティ的な懸念がないか

### 5. PR 本文のレビュー

作成した PR 本文をサブエージェントでレビューしてください:

```md
以下のPR本文をレビューし、改善点があれば修正案を出してください。
特に以下の観点でチェックしてください:
- テンプレートの各セクションが適切に記入されているか
- 変更内容の説明が具体的で正確か
- 動作確認手順が再現可能な形で書かれているか
- 影響範囲の記載に漏れがないか
- レビュアーにとって理解しやすい文章になっているか

出力は修正案のみを markdown 形式で出力してください。

## 変更差分の要約
{{git diff の要約をここに挿入}}

## 作成された PR 本文
{{作成された PR 本文をここに挿入}}
```

### 6. ユーザー確認

レビュー結果を反映した最終的な PR 本文をユーザーに提示し、以下を確認してください:

- PR のタイトル（70文字以内、変更内容を端的に表すもの）
- PR の本文
- ベースブランチ（ステップ 0 で特定した `<base-branch>`）
- ドラフト PR にするかどうか

### 7. PR 作成

ユーザーの承認を得たら `gh pr create` で PR を作成してください:

```bash
gh pr create --title "<タイトル>" --body "$(cat <<'EOF'
<PR本文>
EOF
)" --base <base-branch>
```

ドラフトの場合は `--draft` フラグを追加してください。

### 8. マルチ LLM レビュー依頼（オプション）

PR 作成直後に `pr-request-review` 相当の skill を起動して、複数の AI モデルに並列でレビューを依頼できます。

```
Skill tool:
  skill: "devflow:pr-request-review"
  args: ""   # 引数なし → 直前に作成した PR を自動検出
```

スキルの実行結果（成功/一部失敗）をそのままユーザーに伝えてください。

### 9. 完了報告

作成した PR の URL と、ステップ 8 のレビュー依頼結果をユーザーに報告してください。

## 注意事項

- **Push は PR 作成前に必要です**: リモートにブランチが push されていない場合は、ユーザーに確認の上 push してください
- PR 本文はプロジェクトの言語に合わせて作成してください（日本語など）
- コミット履歴が多い場合は、重要な変更に絞って概要を記述してください
- セキュリティに関わる変更（認証、暗号化、環境変数等）がある場合は、影響範囲と懸念点に必ず記載してください
