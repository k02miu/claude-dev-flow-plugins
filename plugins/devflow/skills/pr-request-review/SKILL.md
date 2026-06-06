---
name: pr-request-review
description: |
  PR に対して {{PR_REVIEWER_MODEL_NAMES}} の4レビュアーへ並列でレビューを依頼します。
  以下の場合に使用してください:
  - PR 作成直後にマルチ LLM レビューを走らせたいとき
  - 既存 PR に対してレビューの再依頼をしたいとき（差し戻し後の再レビュー含む）
  - Copilot を `--add-reviewer @copilot`、Claude を `ready-for-review` ラベル、Codex/Gemini をコメントメンションで起動する一連の操作を一発で済ませたいとき
---

# PR Multi-Reviewer Request

PR に対して **{{PR_REVIEWER_MODEL_NAMES}}** の4つのレビュアーへ並列でレビュー依頼を投下します。
すでにレビュー済みの PR でも「再レビュー」として再依頼できます。

## 変数定義

本 SKILL.md では以下の {{VARIABLE}} を使用します。実際のプロジェクトの値に置き換えて使用してください。

| 変数 | 説明 | デフォルト例 |
|------|------|-------------|
| `{{PR_REVIEWER_MODEL_NAMES}}` | PR レビュアーモデル名 | `GitHub Copilot / Claude / Codex / Gemini` |

## 引数

- `<PR番号>`: 任意。省略時は現在ブランチに紐づく open PR を自動検出します。
- `--models <list>`: 任意。カンマ区切りで `copilot,claude,codex,gemini` のサブセットを指定。省略時は4モデル全てに依頼。
  - 例: `--models claude,gemini` → Claude と Gemini にだけ再依頼
  - 主に `pr-review-loop` から「アクティブなモデルだけ再依頼する」ために使用

## 前提条件

- `gh` CLI が認証済みであること（未認証なら「`gh` が利用できないため終了します」と出して停止）
- 対象リポジトリで **GitHub Copilot Code Review** が有効化されていること
- リポジトリに `ready-for-review` ラベルが存在すること（無ければ `gh label create` で作成する手順を案内）

## 手順

### 0. PR 番号の特定

引数で PR 番号が渡されていればそれを使う。未指定なら現在ブランチの open PR を取得:

```bash
PR=$(gh pr view --json number -q .number)
```

- `gh pr view` がエラーになる（ブランチが push されていない / PR が無い）場合は、ユーザーに `git push` と PR 作成を案内して停止
- 取得した PR の `state` が `OPEN` でなければ「PR #<番号> は CLOSED/MERGED のためレビュー依頼できません」と報告して停止

```bash
gh pr view "$PR" --json number,state,url,headRefName
```

### 1. レビュー依頼（並列実行）

引数 `--models` で指定された **アクティブモデルのみ** を **並列** で実行する（互いに依存なし）。
未指定なら4モデル全て。1つが失敗しても他は継続し、最後にまとめて報告する。

```bash
# 例: アクティブモデルの判定
ACTIVE_MODELS="${MODELS:-copilot,claude,codex,gemini}"
is_active() { echo ",$ACTIVE_MODELS," | grep -q ",$1,"; }
```

以下、各サブセクションは `is_active <model>` が真の場合のみ実行する。

#### 1-1. GitHub Copilot

```bash
gh pr edit "$PR" --add-reviewer @copilot
```

- Copilot は同じコマンドの再実行で再レビューがトリガーされる（GitHub 側で特別扱い）
- Copilot Code Review が無効な Org では `--add-reviewer @copilot` が無視されるので、結果検証は `gh pr view "$PR" --json reviewRequests` で `@copilot` が含まれるかをチェック

#### 1-2. Claude（`ready-for-review` ラベル経由）

```bash
LABELS=$(gh pr view "$PR" --json labels -q '.labels[].name')
if echo "$LABELS" | grep -qx 'ready-for-review'; then
  gh pr edit "$PR" --remove-label ready-for-review
fi
gh pr edit "$PR" --add-label ready-for-review
```

- ラベルが既に付いている場合は一度外してから付け直すことで、Claude のレビューフックを再トリガーする
- `--add-label` がラベル不在で失敗した場合は、ユーザーに以下を案内:
  ```bash
  gh label create ready-for-review --color "0E8A16" --description "Claude review trigger"
  ```

#### 1-3. Codex

```bash
gh pr comment "$PR" --body "@codex レビューをお願いします。2回目以降の場合は再レビューとして前回の指摘と合わせて確認してください。"
```

#### 1-4. Gemini

```bash
gh pr comment "$PR" --body "@gemini /review 日本語でレビューをお願いします。再レビューの場合は前回の指摘と合わせて確認してください。"
```

**重要**: Codex と Gemini のメンションは **必ず別コメント** に分けること。1コメントに同居させると片方が拾い損ねるリスクがある。

### 2. 結果の報告

各依頼の成否を以下のフォーマットで報告する。

#### 全成功時

```
✅ レビュー依頼完了 (PR #<番号>)

- ✓ GitHub Copilot: レビュアー登録済み
- ✓ Claude: ready-for-review ラベル付与済み
- ✓ Codex: コメント投下済み (<comment URL>)
- ✓ Gemini: コメント投下済み (<comment URL>)

PR URL: <PR URL>
```

#### 一部失敗時

```
⚠️ 一部失敗 (PR #<番号>)

- ✓ GitHub Copilot: OK
- ✗ Claude: ready-for-review ラベルが存在しません
        対処: gh label create ready-for-review --color "0E8A16"
- ✓ Codex: OK
- ✓ Gemini: OK

PR URL: <PR URL>
```

## 注意事項

- **再レビューの挙動**:
  - Copilot は `--add-reviewer @copilot` の再実行で再レビューが走る
  - Claude は `ready-for-review` ラベルを「remove → add」して再トリガー
  - Codex / Gemini はコメント文言に「再レビュー」を明記しているので、過去の指摘も含めて再評価される
- **コメント分離の理由**: 1コメントに `@codex` と `@gemini` を同居させると、片方のボットが反応しない事例があるため、必ず別コメントで投下する
- **権限エラー時**:
  - Copilot レビュアー追加で `Reviewer is not a collaborator` 等が出る → リポジトリで Copilot Code Review が有効か確認
  - ラベル操作で `not found` → 上記 `gh label create` で作成
- **空打ち防止**: PR が既に `MERGED` / `CLOSED` の場合は依頼せず停止する
- **コミットされていない変更がある場合は**: このスキルの責務外。PR 作成側で対応すること
