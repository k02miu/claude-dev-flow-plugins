---
name: branch-finisher
argument-hint: parent_branch
allowed-tools: Bash(git status:*), Bash(git diff:*)
description: "ブランチの仕上げを一括実行する（ドキュメント同期・ストーリー追加・テスト同期・品質チェック・画面動作確認）"
disable-model-invocation: true
---

# Branch Finisher (Generic)

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


> **変数の解決（重要）**: 本スキル内の `{{VARIABLE}}` はプラグイン配布時に自動置換されません。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成を調査して値を解決してください。解決できない場合のみユーザーに確認します。以下の「VARIABLES」表は既定値の参考です。

## VARIABLES — Fill these in before first use

| Variable                 | Description                                      | Example                          |
|--------------------------|--------------------------------------------------|----------------------------------|
| {{PACKAGE_MANAGER}}          | Package manager used in project                  | npm / yarn / pnpm / bun         |
| {{FRONTEND_FRAMEWORK}}            | Main web framework                               | Next.js / Nuxt / Remix / Django |
| {{UNIT_TEST_FRAMEWORK}}       | Unit test framework                              | Vitest / Jest / Mocha           |
| {{E2E_TEST_FRAMEWORK}}        | E2E test framework                               | Playwright / Cypress            |
| {{LINTER}}     | Linter / formatter                               | Biome / ESLint / Prettier       |
| {{TYPE_CHECK_COMMAND}}   | Type check command                               | pnpm check-types / pnpm vue-tsc |
| {{LINT_COMMAND}}         | Lint fix command                                 | pnpm biome:fix / pnpm lint:fix  |
| {{DEV_SERVER_COMMAND}}   | Dev server start command                         | pnpm dev / npm run dev          |
| {{REPORT_GENERATOR}}     | HTML report generator script (optional)          | report-gen / scripts/gen-report.sh |

**ブランチの変更をリリース可能な状態に仕上げるための統合コマンド**

原則コードには手を加えないでください。各フェーズの調査結果に基づく修正が必要な場合は、修正内容を判断し実行してよいですが、その判断内容と根拠をすべてレポートに記録してください。commit & push はユーザーが行うため絶対に行わないでください。

## 概要

以下の 5 ステップを **すべて直列** で順次実行し、ブランチの品質を包括的に確認・改善します。

```
Step 1: document-follow-up（ドキュメント同期）
  ↓
Step 2: add-storybook（UI ストーリー追加）
  ↓
Step 3: test-follow-up（テスト同期）
  ↓
Step 4: code-finisher（品質チェック）
  ↓
Step 5: screen-ope（画面動作確認）
```

## 自律判断ルール

通常、各サブコマンドはユーザーへのフィードバック・確認を挟みますが、本コマンドではそれらを **自律的に判断** して実行してください。

### 判断基準

1. **安全側に倒す**: 迷った場合はより安全な選択肢（修正する / テストを追加する / ドキュメントを更新する）を選ぶ
2. **既存の慣習に従う**: プロジェクトの既存パターン・コーディング規約に沿った判断をする
3. **スコープを守る**: ブランチの変更差分に関連する範囲のみ対応し、無関係な改善は行わない
4. **破壊的変更は避ける**: 既存の動作を壊す可能性がある変更は行わず、レポートに記録して最終報告時にユーザーに判断を委ねる

### 判断を委ねるケース

以下の場合は自律判断せず、レポートに「要ユーザー判断」として記録し、最終報告時にまとめて確認します：

- ビジネスロジックの正誤が不明な場合（ドキュメントが正 vs ソースが正の判断）
- 権限設計・ロール設計に関わる変更
- 新規ドキュメントの作成要否（既存ドキュメントの更新は自律判断可）
- severity: high 以上のセキュリティ指摘への対応

## レポートファイル

すべての判断は **MD で逐次記録**し、Step 6 で 1 回だけ HTML に変換します（トークン節約）。

- MD ソース: `.cache/branch-finisher-report.md`（各 Step 完了時に Edit / Write で逐次更新）
- 最終 HTML: `.cache/branch-finisher-report.html`（Step 6 で MD から 1 回だけ生成）

### MD レポートフォーマット

レポートのテンプレートは `${CLAUDE_SKILL_DIR}/references/report-format.md` を Read して使用してください（Step 0-4 の初期化時にこの構造で `.cache/branch-finisher-report.md` を Write する）。

---

## 実行手順

### Step 0: 事前準備

#### 0-1. 引数の確認

$ARGUMENTS が指定されている場合は親ブランチとして使用し、未指定の場合はユーザーに入力を求めます。

#### 0-2. ブランチ状態の確認

```bash
git status
git diff --stat
```

未コミットの変更がある場合は、ユーザーに続行可否を確認してください。

#### 0-3. 変更差分の取得

```bash
git diff --name-only origin/${parent_branch}...HEAD
```

変更差分がない場合は、ユーザーに通知して処理を終了してください。

#### 0-4. レポートファイルの初期化

`.cache/branch-finisher-report.md` を Write してください（実行情報セクションと、各 Step の見出しを含む空テンプレート）。
各 Step 完了時にそのセクションを Edit で更新します。

HTML 変換は Step 6 で 1 回だけ実施します。

#### 0-5. キャッシュクリーンアップ

各サブスキル（document-follow-up, test-follow-up）はブランチ名ベースのサブディレクトリを使用するため、スキル内で独自にクリーンアップを行います。ここでの一括削除は不要です。

---

### Step 1: ドキュメント同期（document-follow-up）

プラグインが提供する `document-follow-up` 相当の skill を起動してください。

```
Skill tool:
  skill: "devflow:document-follow-up"
```

このスキルが Agent Teams を構成し、ドキュメントと実装の乖離を多角的に調査します。
スキルが展開する手順（Task 作成 → Teammate 起動 → Phase 1〜3 → レポート作成）をそのまま実行してください。

**自律判断のポイント（スキル内のユーザー確認ステップで適用）:**

- ドキュメント乖離調査の結果、`doc_outdated` タイプの乖離は自律的にドキュメントを更新する
- `doc_missing`（新規ドキュメント作成が必要）は「要ユーザー判断」としてレポートに記録する
- `code_wrong`（ソースコードが誤り）は「要ユーザー判断」としてレポートに記録する
- `doc_wrong`（ドキュメントの誤り）は自律的にドキュメントを修正する
- `feature_removed`（機能削除後のドキュメント残存）は自律的にドキュメントを削除/更新する
- severity: low の指摘は対応見送りとしてレポートに記録する（理由付き）

スキル内のユーザー確認ステップでは、上記の判断基準に従い自律的に処理を進めてください。
すべての判断を `.cache/branch-finisher-report.md` の Step 1 セクションのテーブルに記録してください。

**スキルの全手順が完了してから Step 2 に進んでください。**

---

### Step 2: UI ストーリー追加（add-storybook）

プラグインが提供する `add-storybook` 相当の skill を起動してください。

```
Skill tool:
  skill: "devflow:add-storybook"
```

このスキルが変更されたコンポーネントを検出し、ストーリー（Storybook 等）の追加手順を展開します。
スキルが展開する手順をそのまま実行してください。

**自律判断のポイント（スキル内のユーザー確認ステップで適用）:**

- 対象コンポーネントの特定・ストーリー有無確認は自律的に実施する
- ストーリーの追加可否はすべて「追加する」と判断する（対象外のコンポーネントを除く）
- バリエーションは既存ストーリーのパターンに従い、Default + 主要な状態変化を含める
- サーバーコンポーネントや外部依存が強いものはスキップし、レポートに記録する

すべての判断を `.cache/branch-finisher-report.md` の Step 2 セクションのテーブルに記録してください。

**スキルの全手順が完了してから Step 3 に進んでください。**

---

### Step 3: テスト同期（test-follow-up）

Step 1・2 の完了後に実行します。ドキュメントやコンポーネントに変更が加わっている可能性があるため、
最新のコード状態に基づいてテスト調査を行います。

プラグインが提供する `test-follow-up` 相当の skill を起動してください。引数に親ブランチ名を渡してください。

```
Skill tool:
  skill: "devflow:test-follow-up"
  args: "${parent_branch}"
```

このスキルが Agent Teams を構成し、テストの漏れ・乖離を多角的に調査します。
スキルが展開する手順（Task 作成 → Teammate 起動 → Phase 1〜3 → レポート作成）をそのまま実行してください。

**自律判断のポイント（スキル内のユーザー確認ステップで適用）:**

- `missing_test`（テスト未追加）: severity: high/medium は自律的にテストを追加する、low はレポートに記録
- `outdated_test`（テスト未追従）: 自律的にテストを更新する
- `wrong_test`（テストの期待値が間違い）: 実装を正として自律的にテストを修正する（ただしビジネスロジックの正誤が不明な場合は「要ユーザー判断」）
- `orphan_test`（孤立テスト）: 自律的にテストを削除する
- セキュリティ指摘（SEC-*）: risk_level: critical/high は「要ユーザー判断」、medium/low は自律的に対応
- アーキテクチャ指摘（ARCH-*）: レポートに記録し、severity: high のみ「要ユーザー判断」

スキル内のユーザー確認ステップでは、上記の判断基準に従い自律的に処理を進めてください。
すべての判断を `.cache/branch-finisher-report.md` の Step 3 セクションのテーブルに記録してください。

**スキルの全手順が完了してから Step 4 に進んでください。**

---

### Step 4: 品質チェック（code-finisher）

Step 1〜3 で加わった変更を含めた品質チェックを実施します。

プラグインが提供する `code-finisher` 相当の skill を起動してください。

```
Skill tool:
  skill: "devflow:code-finisher"
```

このスキルが型チェック、Lint、テスト実行を行います。
スキルが展開する手順をそのまま実行してください。

実施内容（プロジェクトのコマンドに合わせて調整）:

- 型チェック（`{{TYPE_CHECK_COMMAND}}`）
- Lint チェック（`{{LINT_COMMAND}}`）
- ユニットテスト実行（変更に関連するテスト）
- E2E テスト実行（変更に関連するテスト）

**自律判断のポイント:**

- 型エラー: 自律的に修正する（Step 1〜3 の変更で発生したものは特に優先）
- Lint エラー: 自律的に修正する
- テスト失敗: 失敗原因を分析し、テスト側の問題であれば自律的に修正する。実装側の問題であれば「要ユーザー判断」

すべての判断を `.cache/branch-finisher-report.md` の Step 4 セクションのテーブルに記録してください。

**スキルの全手順が完了してから Step 5 に進んでください。**

---

### Step 5: 画面動作確認（screen-ope）

全ステップの変更を含めた最終的な画面動作確認を実施します。

プラグインが提供する `screen-ope` 相当の skill を起動してください。

```
Skill tool:
  skill: "devflow:screen-ope"
```

このスキルが変更差分の分析、試験リスト作成、ブラウザ操作ツール（Chrome DevTools MCP 等）による画面操作、スクリーンショット保存を行います。
スキルが展開する手順をそのまま実行してください。

**自律判断のポイント（スキル内のユーザー確認ステップで適用）:**

- 試験リストの作成: 変更差分に基づき自律的に作成する（ユーザー承認ステップはスキップ）
- テスト実施: 全項目を順次実行する
- NG 項目: レポートに記録し、明らかな表示崩れやエラーは「要ユーザー判断」として記録する
- 開発サーバーが起動していない場合: ユーザーに起動を依頼する（これは自律判断できない）

すべての判断を `.cache/branch-finisher-report.md` の Step 5 セクションのテーブルに記録してください。

**スキルの全手順が完了してから Step 6（最終報告）に進んでください。**

---

### Step 6: 最終報告

#### 6-1. レポートの仕上げ

`.cache/branch-finisher-report.md` の最終サマリーセクションを完成させてください:

1. **実施した変更一覧**: 全ステップで実施した変更をファイル単位で列挙
2. **要ユーザー判断（全ステップ統合）**: 全ステップの「要ユーザー判断」項目を優先度順に集約
3. **検出された問題（未対応）**: 自律判断の範囲外で対応できなかった問題の一覧

#### 6-2. HTML レポート生成

外部スクリプトまたはリーダーが直接 HTML を生成します。

**Step 6-2-a: 外部スクリプト委譲で HTML 生成を試みる（トークン節約のため）**

```bash
{{REPORT_GENERATOR}} \
  --source-md   ".cache/branch-finisher-report.md" \
  --output-html ".cache/branch-finisher-report.html" \
  --title       "Branch Finisher レポート" \
  --context     "ブランチ: {current_branch} / 親ブランチ: {parent_branch}"
```

スクリプト終了コード:
- **0**: HTML 生成に成功 → Step 6-3 へ
- **1**: CLI 未インストール → Step 6-2-b にフォールバック
- **2**: 実行失敗 → ログ確認後 Step 6-2-b にフォールバック

**Step 6-2-b: フォールバック（リーダーが直接 HTML 生成）**

外部スクリプトが利用できない場合のみ実施:

1. プロジェクトの HTML テンプレートがあれば Read（なければ基本的な HTML 構造で生成）
2. プレースホルダを置換:
   - `{{REPORT_TITLE}}` → `Branch Finisher レポート`
   - `{{GENERATED_AT}}` → 現在日時（ISO 8601）
   - `{{CONTEXT_LINE}}` → `ブランチ: {current_branch} / 親ブランチ: {parent_branch}`
   - `{{TOC_ITEMS}}` → Step 1〜5 + 最終サマリーへのアンカーリンク
   - `{{MAIN_CONTENT}}` → 各 Step を `<section id="step1">` ... `<section id="step5">` + `<section id="summary">`
3. 変換指針:
   - 自律判断ログのテーブルは `<table>`
   - 「要ユーザー判断」は `<ul>` 内で重要度バッジ `<span class="badge badge-{high|medium|low}">` を併用
   - ファイルパスは `<code>`
   - HTML 特殊文字は必ずエスケープ
4. 完成した HTML を `.cache/branch-finisher-report.html` に Write

#### 6-3. ユーザーへの報告

レポートの最終サマリーを要約してユーザーに報告してください。報告には以下を含めること:

1. **各ステップの実行結果サマリ**（成功/失敗、主な対応件数）
2. **要ユーザー判断項目**（優先度順に提示、AskUserQuestion で確認）
3. **🔗 詳細レポートへのリンク**: `[Branch Finisher レポートを開く](vscode://file/${CLAUDE_PROJECT_DIR}/.cache/branch-finisher-report.html)`
   （クリックで VS Code エディタに HTML が開く。エディタ右上の **「Show Preview」ボタン**（Live Preview 拡張）でレンダリング表示できる旨を併記すること）

要ユーザー判断項目がある場合は、AskUserQuestion でまとめて確認してください。
ユーザーの回答に基づき追加対応が必要な場合は、対応を実行しレポートを更新してください。

---

## 注意事項

- **commit & push は絶対に行わない** — ユーザーが行う
- 各ステップのサブコマンドがエラーになった場合は、残りのステップを継続し、レポートにエラーを記録する
- ステップ間の実行順序は厳守する（Step 1 → 2 → 3 → 4 → 5 の順序）
- MD レポート（`.cache/branch-finisher-report.md`）は各ステップ完了時に逐次更新する（最後にまとめて書くのではなく）
- HTML への変換は Step 6 で 1 回だけ実施（毎ステップ HTML を再生成しない、トークン節約）
- `.cache/branch-finisher-report.md` / `.html` は次回実行時に上書きされる想定
- 開発サーバー（`{{DEV_SERVER_COMMAND}}`）が必要な Step 5 の screen-ope 実行前に、サーバー状態を確認すること
