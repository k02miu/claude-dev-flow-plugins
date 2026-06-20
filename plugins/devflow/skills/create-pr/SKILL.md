---
argument-hint: [対象のissue番号やPRの補足説明（任意）]
name: create-pr
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(git reflog:*), Bash(git merge-base:*), Bash(git remote get-url:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh repo view:*)
description: "PRテンプレートに基づいてPull Requestを作成する"
---

# Pull Request Creator (Generic)

> **名前空間**: agent / skill 名はインストール時に `devflow:` が付く（例 `devflow:architecture-planner`）。本文で `devflow:` を省略した箇所も同様に解釈する。`general-purpose`（ビルトイン）と `codex:*`（別プラグイン）は例外でそのまま。

> **変数**: `{{VARIABLE}}` は配布時に自動置換されない。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成から解決する。解決できないときだけユーザーに確認する。下表は既定値の参考。

## 変数

| Variable | Description | Example |
|-----------------------------|--------------------------------------------------|----------------------------------|
| {{REPO_URL}}                | Git remote URL (auto-detected if git is present) | https://github.com/org/repo.git |
| {{PACKAGE_MANAGER}}             | Package manager used in project                  | npm / yarn / pnpm / bun         |
| {{TYPE_CHECK_COMMAND}}      | Type check command                               | pnpm check-types / tsc --noEmit |
| {{LINT_COMMAND}}            | Lint fix command                                 | pnpm biome:fix / pnpm lint:fix  |
| {{PR_TEMPLATE_PATH}}        | Path to PR template                              | .github/PULL_REQUEST_TEMPLATE/pull_request_template.md |

`gh` が設定済みで `git remote get-url origin` が通れば `{{REPO_URL}}` は自動検出できる。

最初に `gh` の利用可否を確認する。使えなければ設定を促し、「`gh` が利用できないため終了します」と出力して終了する。対象リポジトリは `{{REPO_URL}}`。

補足情報: $ARGUMENTS

## 基本動作

- **引数なし**（`/create-pr`）: 現在のブランチの変更を分析し、PR テンプレートに沿って PR を作成する。
- **引数あり**（`/create-pr 245`、`/create-pr バグ修正の補足`）: 渡された Issue 番号や補足を加味する。

## 前提条件

- 現在のブランチがベースブランチ（`main` / `develop` 等）そのものでないこと。ベースブランチ上では PR を作らない。
- 未コミットの変更があればユーザーに通知し、コミットするか確認する。
- 同一ブランチに Open な PR があればユーザーに通知し、新規作成か既存更新かを確認する。

## 対応手順

### 0. ベースブランチの特定

マージ先のベースブランチを次の優先順で特定する（確定した時点で採用）:

1. `git log --oneline --merges --first-parent HEAD` や `git reflog` で派生元を推測
2. `git branch -a --contains $(git merge-base main HEAD)` で共通祖先から推測
3. ブランチ名から推測（`feature/issue-123` → `main` / `develop`、`hotfix/xxx` → `main`）
4. デフォルトブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）をフォールバック
5. 確信が持てなければユーザーに確認

以降、特定したブランチを `<base-branch>` と呼ぶ。

### 1. ブランチ状態の確認

次を並列で確認する:

- `git status` — 未コミットの変更
- `git branch --show-current` — 現在のブランチ名
- `git log <base-branch>..HEAD --oneline` — ベースからの全コミット
- `git diff <base-branch>...HEAD --stat` — 変更ファイル統計
- `gh pr list --head $(git branch --show-current) --state open` — 既存 PR

### 2. 変更内容の分析

コードベース解析ツール（利用可能な MCP 等）で変更を分析する:

1. `git diff <base-branch>...HEAD` で全差分を確認
2. 変更ファイルの種類（FE / BE / DB / インフラ / テスト）を分類
3. 変更の目的（新機能 / バグ修正 / リファクタ / テスト / ドキュメント）を判定
4. 補足情報があれば加味

### 3. 関連 Issue の特定

次の優先順で Issue 番号を特定する（見つかった時点で採用）:

1. 補足情報に Issue 番号があれば使う
2. ブランチ名から推測（`feature/issue-123` → #123）
3. コミットメッセージの `#数字` / `issue-数字` を検索
4. 特定できなければ Issue なしで進める（確認不要、「対応するIssue」欄は空にする）

### 4. PR テンプレートの記入

`{{PR_TEMPLATE_PATH}}` を Read し、そのテンプレートに沿って本文を作成する。

> **テンプレートが無い場合**: `{{PR_TEMPLATE_PATH}}` がユーザープロジェクトに無ければ（プラグインは cache にコピーされ cwd はユーザープロジェクトのため、同梱サンプルは cwd 相対では参照されない）、`${CLAUDE_PLUGIN_ROOT}/.github/PULL_REQUEST_TEMPLATE/pull_request_template.md` を参照するか、下記の見出し構成をそのまま使う。確認は不要。

**本文の書き方**: 読み手はエンジニア（レビュアー）。簡潔・直截に書く。一文に複数の論点を詰め込まず短く分ける。絵文字や装飾見出しは使わない。自明な説明や前置きは省く。強調は本当に重要な1〜2点だけにする。

各セクションの記入指針:

#### 対応するIssue
`Closes #<番号>`。無ければ「なし」。

#### 対応の背景・目的
変更の動機と目的を2〜3文で。Issue があればその要約。

#### 対応概要
変更内容を箇条書きで。技術的な変更点を具体的に。ファイルが多ければカテゴリでグルーピング。

#### 影響範囲
影響するモジュール・画面・API を列挙。後方互換性も記載。

#### 重点的にレビューしてほしい箇所・懸念点
注意して見てほしい箇所をファイルパス付きで。判断に迷った点や代替案がある点。

#### 動作確認方法
前提条件（環境・データ準備）、確認手順（ステップごと）、期待結果、注意点を記載。

#### 確認事項（作成者・エージェント向け）
該当をチェックする:
- `{{TYPE_CHECK_COMMAND}}` でエラーなし
- `{{LINT_COMMAND}}` でエラーなし
- テストの追加/更新
- セキュリティ上の懸念なし

### 5. PR 本文のレビュー

作成した本文をサブエージェントでレビューする:

```md
以下の PR 本文をレビューし、改善点があれば修正案を出してください。観点:
- テンプレートの各セクションが適切に埋まっているか
- 変更内容の説明が具体的で正確か
- 動作確認手順が再現可能か
- 影響範囲に漏れがないか
- レビュアーが読みやすい簡潔な文章か（冗長・絵文字・過剰な強調を避ける）

修正案のみを markdown で出力してください。

## 変更差分の要約
{{git diff の要約をここに挿入}}

## PR 本文
{{作成された PR 本文をここに挿入}}
```

### 6. ユーザー確認

レビューを反映した最終本文をユーザーに提示し、次を確認する:

- PR タイトル（70文字以内、変更を端的に表す）
- PR 本文
- ベースブランチ（ステップ 0 の `<base-branch>`）
- ドラフトにするか

### 7. PR 作成

承認を得たら `gh pr create` で作成する:

```bash
gh pr create --title "<タイトル>" --body "$(cat <<'EOF'
<PR本文>
EOF
)" --base <base-branch>
```

ドラフトは `--draft` を追加する。

### 8. マルチ LLM レビュー依頼（オプション）

作成直後に `pr-request-review` 相当の skill を起動し、複数モデルに並列でレビューを依頼できる:

```
Skill tool:
  skill: "devflow:pr-request-review"
  args: ""   # 引数なし → 直前に作成した PR を自動検出
```

実行結果（成功 / 一部失敗）をそのままユーザーに伝える。

### 9. 完了報告

作成した PR の URL とステップ 8 のレビュー依頼結果を報告する。

## 注意事項

- **Push が先**: リモートに未 push なら、ユーザー確認の上 push してから PR を作る。
- 本文はプロジェクトの言語（日本語など）に合わせる。
- コミットが多ければ重要な変更に絞って概要を書く。
- セキュリティに関わる変更（認証・暗号化・環境変数等）は、影響範囲と懸念点に必ず記載する。
