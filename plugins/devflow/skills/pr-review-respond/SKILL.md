---
name: pr-review-respond
description: |
  PR レビューコメントを分析し、修正して返信します。
  以下の場合に使用してください:
  - マルチ LLM レビュー（{{PR_REVIEWER_MODEL_NAMES}}）の指摘に一括対応したいとき
  - レビュー差し戻し後、コメントごとに「修正 / 議論 / 反論」を判断して対応したいとき
  - `pr-review-loop` から `--auto` 付きで呼び出され、ユーザー確認なしに修正 → commit & push まで自律実行したいとき
  Agent Teams で architecture-planner / existing-code-reviewer / security-reviewer / ui-designer を
  並列起動してコメントを多角的に分析し、opinion-integrator で対応方針を統合します。
---

# PR Review Respond（レビューコメント対応）

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


PR に付いたレビューコメントを取得・分析し、コメントごとに **修正 / 議論 / 反論** を判断して、
コード修正とレビュアーへの返信までを実施します。複数レビュアー（人間 + マルチ LLM）の意見は
`opinion-integrator` agent で統合します。

`pr-review-loop` が各ラウンドの修正フェーズで `/pr-review-respond <PR> --auto` として呼び出す前提で設計しています。

## 引数

- `<PR番号>`: 任意。省略時は現在ブランチに紐づく open PR を自動検出。
- `--auto`: 任意。指定時は **ユーザー確認をスキップ**し、修正・返信・`commit & push` までを自律実行する。
  - 省略時（対話モード）は、対応方針をユーザーに提示して承認を得てから修正に入り、`commit & push` は行わない。
- `--since <ISO8601>`: 任意。指定時刻より後に投稿された review / comment のみを対象にする（再レビューの差分対応用。`pr-review-loop` がラウンド開始時刻を渡す）。

## 変数定義

本 SKILL.md では以下の {{VARIABLE}} を使用します。実際のプロジェクトの値に置き換えて使用してください。

| 変数 | 説明 | デフォルト例 |
|------|------|-------------|
| `{{PLUGIN_NAME}}` | プラグイン名 | `devflow` |
| `{{AGENT_CONFIG_DIR}}` | エージェント設定ディレクトリ | `.claude` |
| `{{CACHE_DIR}}` | キャッシュディレクトリ | `.cache` |
| `{{TASK_SLUG}}` | タスクスラッグ（PR 単位の作業領域名） | `pr-123` |
| `{{PR_REVIEWER_MODEL_NAMES}}` | PR レビュアーモデル名 | `GitHub Copilot / Claude / Codex / Gemini` |
| `{{PACKAGE_MANAGER}}` | パッケージマネージャ | `pnpm` |
| `{{TYPE_CHECK_COMMAND}}` | 型チェックコマンド | `pnpm check-types` |
| `{{LINT_COMMAND}}` | リント・フォーマットコマンド | `pnpm biome:fix` |
| `{{TEST_COMMAND}}` | 単体テストコマンド | `pnpm test` |

## 前提条件

- `gh` CLI が認証済みであること（未認証なら「`gh` が利用できないため終了します」と出して停止）
- 対象ブランチが PR として push 済みであること
- `--auto` 時は `commit & push` を自律実行するため、作業ツリーが対象 PR ブランチであることを確認すること

## チーム構成

| 役割 | Teammate 名 | `subagent_type` | 担当 |
|------|-------------|-----------------|------|
| リーダー | （メインエージェント） | — | コメント取得、チーム編成、コード修正、コメント返信、commit & push |
| アーキテクチャ分析 | `architecture-planner` | `architecture-planner` | 設計・データフロー観点でのコメント妥当性分析 |
| 既存コード整合性 | `existing-code-reviewer` | `existing-code-reviewer` | 既存パターン・後方互換性観点での分析 |
| セキュリティ分析 | `security-reviewer` | `security-reviewer` | セキュリティ観点での分析 |
| UI/UX 分析（条件付き） | `ui-designer` | `ui-designer` | UI 関連コメントがある場合のみ起動 |
| 意見統合 | `opinion-integrator` | `opinion-integrator` | 各分析を統合し、コメント別の対応方針（修正/議論/反論）を策定 |

各専門 agent は **Mode B: PR Comment Analysis** で起動する（`pr_comment_analysis` の JSON を出力）。

## 手順

### 0. 初期化

1. PR 番号を確定（引数 or `gh pr view --json number -q .number`）。取得できなければユーザーに `git push` と PR 作成を案内して停止。
2. `state` が `OPEN` でなければ「PR #<番号> は CLOSED/MERGED のため対応できません」と報告して停止。
3. 引数 `--auto` / `--since` を解釈。`{{TASK_SLUG}}` を `pr-<PR番号>` として作業領域 `{{CACHE_DIR}}/pr-review-respond/{{TASK_SLUG}}/` を用意。

### 1. レビューコメント取得

`gh api` で 3 種のコメントを取得する（`--since` 指定時は `submitted_at` / `created_at` でフィルタ）:

```bash
# レビュー（APPROVE / REQUEST_CHANGES / COMMENT 本文）
gh api "repos/{owner}/{repo}/pulls/$PR/reviews" \
  --jq '.[] | {id, user: .user.login, state, body, submitted_at}'
# Issue コメント（PR 会話タブ）
gh api "repos/{owner}/{repo}/issues/$PR/comments" \
  --jq '.[] | {id, user: .user.login, body, created_at}'
# Review コメント（コード行に紐づくインラインコメント）
gh api "repos/{owner}/{repo}/pulls/$PR/comments" \
  --jq '.[] | {id, user: .user.login, body, path, line, created_at}'
```

取得したコメントを正規化し、`{{CACHE_DIR}}/pr-review-respond/{{TASK_SLUG}}/comments.json` に保存する。
各コメントに `comment_id` / `reviewer`（login）/ `file` / `line` / `body` / `kind`（review | issue_comment | review_comment）を付与する。

自分（PR author）自身のコメント・bot の起動メンション（`@codex` 等）・実質的指摘のない承認コメントは対象から除外する。
**対応すべきコメントが 0 件**なら「対応対象のコメントはありません」と報告して終了。

### 2. 並列分析（Phase 1）

Agent Teams を構成し、専門 agent を **File-based 起動** で並列に動かす:

1. 各 agent 用に `instruct.md` を Write（対象 PR の概要、`comments.json` のパス、Mode B 指定を含める）
   - 配置: `{{CACHE_DIR}}/pr-review-respond/{{TASK_SLUG}}/<agent>/instruct.md`
2. `architecture-planner` / `existing-code-reviewer` / `security-reviewer` を起動。
   コメントに UI / 画面 / コンポーネント関連が含まれる場合のみ `ui-designer` も起動。
3. 各 agent は `pr_comment_analysis` の JSON を `report.md` に Write し、`SendMessage` で完了通知。
4. 全 agent の完了を待つ。専門領域外のコメントは各 agent が `out_of_scope` と判定する。

### 3. 意見統合（Phase 2）

`opinion-integrator` を起動し、Phase 1 の全 `report.md` を統合させる:

1. `opinion-integrator` 用 `instruct.md` に各 agent の `report.md` パスを列挙して Write。
2. `opinion-integrator` はコメント別に **修正する / 議論する / 反論する** の対応方針と返答案をまとめた
   マークダウンを `{{CACHE_DIR}}/pr-review-respond/{{TASK_SLUG}}/integration.md` に Write。
3. 統合ルール（多数決でなく根拠の強さ、対応先送り禁止の原則）は `opinion-integrator` の定義に従う。

### 4. 承認ゲート

- **`--auto` 指定時**: ユーザー確認をスキップし、そのまま Step 5 へ進む。
- **対話モード（`--auto` なし）**: `integration.md` の対応方針サマリ（修正 X 件 / 議論 X 件 / 反論 X 件）を
  `AskUserQuestion` で提示し、承認・修正方針の調整を得てから Step 5 へ進む。議論・反論コメントの返答文案も提示する。

### 5. コード修正

`integration.md` で **修正する** と決まったコメントに対応する:

1. 修正規模が大きい（複数ファイル横断・新機能級）の場合は `implement` スキルに委譲する。
   小規模修正はリーダーが直接 `Edit` / `Write` で対応する。
2. 修正後、品質ゲートを実行:
   - 型チェック: `{{TYPE_CHECK_COMMAND}}`
   - Lint / フォーマット: `{{LINT_COMMAND}}`
   - 関連単体テスト: `{{TEST_COMMAND}}`
3. 各修正の対象ファイル・対応内容を記録する。

### 6. コメント返信

各コメントに `gh` で返信する（`integration.md` の返答案を使用。敬意ある建設的な表現を厳守）:

```bash
# インライン review コメントへの返信
gh api "repos/{owner}/{repo}/pulls/$PR/comments/<comment_id>/replies" -f body="<返答>"
# 会話タブ（issue comment）への返信
gh pr comment "$PR" --body "<返答>"
```

- **修正した**コメント: 「ご指摘ありがとうございます。<コミット参照> で修正しました」と修正内容を添えて返信。
- **議論する**コメント: 論点を整理し、両論併記でレビュアーの判断を仰ぐ返信。
- **反論する**コメント: 根拠（既存パターン・仕様・公式ドキュメント）を引用した建設的な反論を返信。

### 7. commit & push（`--auto` 時のみ）

**`--auto` 指定時のみ**、修正をコミットして push する:

```bash
git add -A
git commit -m "fix: PR レビュー指摘対応 (#$PR)"
git push
```

- コンフリクト等で push に失敗した場合は中断し、ユーザーに状況を報告する。
- 対話モード（`--auto` なし）では **commit & push は絶対に行わない**（ユーザーが行う）。

### 8. 結果報告

`pr-review-loop` が結果を利用できるよう、以下を構造化して報告する:

```
✅ PR レビュー対応完了 (PR #<番号>)

- 対応コメント数: <修正 X / 議論 X / 反論 X> 件
- commit SHA: <SHA or "未コミット（対話モード）">
- 主な修正: <ファイル単位の要約>
- 要ユーザー判断: <議論コメント等で判断を仰ぐ項目>

詳細: {{CACHE_DIR}}/pr-review-respond/{{TASK_SLUG}}/integration.md
```

## 注意事項

- **`--auto` の責務境界**: `--auto` は「ユーザー確認のスキップ + commit & push」を意味する。これ以外（破壊的変更・権限設計の変更）は `--auto` でも勝手に進めず、要ユーザー判断として返却する。
- **返答の品質**: レビュアー（人間・LLM 問わず）への返答は常に敬意ある建設的な表現にする。反論であっても感情的にならない。
- **対応先送り禁止**: レビュー指摘は原則 PR 内で完結させる。別 PR / Issue への先送りは例外とし、理由を明記する。
- **再レビュー対応**: `--since` が渡された場合は、その時刻以降の新規コメントのみを対象にする（過去ラウンドで対応済みのコメントを二重対応しない）。
- **エージェント再利用**: `pr-review-loop` から複数ラウンド呼ばれる場合、可能なら Teammate を再利用してコンテキストを引き継ぐ（毎ラウンド解散・再起動しない）。
