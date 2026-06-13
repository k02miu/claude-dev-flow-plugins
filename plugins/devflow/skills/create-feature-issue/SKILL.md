---
name: create-feature-issue
argument-hint: [実装したい機能の説明]
description: "Agent Teams で多角的に調査・計画し GitHub Issue を作成する"
disable-model-invocation: true
---

# GitHub Issue Feature Creator (Generic)

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


> **変数の解決（重要）**: 本スキル内の `{{VARIABLE}}` はプラグイン配布時に自動置換されません。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成を調査して値を解決してください。解決できない場合のみユーザーに確認します。以下の「VARIABLES」表は既定値の参考です。

## VARIABLES — Fill these in before first use
| Variable               | Description                                      | Example                          |
|------------------------|--------------------------------------------------|----------------------------------|
| {{REPO_URL}}           | Git remote URL (auto-detected if git is present) | https://github.com/org/repo.git |
| {{PACKAGE_MANAGER}}        | Package manager used in project                  | npm / yarn / pnpm / bun         |
| {{FRONTEND_FRAMEWORK}}          | Main web framework                               | Next.js / Nuxt / Remix / Django |
| {{ORM}}                | ORM / database layer                             | Prisma / Drizzle / TypeORM      |
| {{UNIT_TEST_FRAMEWORK}}    | Unit test framework                              | Vitest / Jest / Mocha           |
| {{E2E_TEST_FRAMEWORK}}     | E2E test framework                               | Playwright / Cypress            |
| {{LINTER}}  | Linter / formatter                               | Biome / ESLint / Prettier       |
| {{CSS_FRAMEWORK}}     | CSS framework                                    | Tailwind CSS / UnoCSS           |
| {{UI_LIBRARY}}            | UI component library                             | shadcn/ui / Material UI / Radix |

> If `gh` CLI is configured and `git remote get-url origin` works, {{REPO_URL}} may be auto-detected.

はじめに `gh` が使えるかを確認して下さい。`gh` が使えない場合、ユーザに `gh` の設定を促す応答をして終了してください。
**GitHub を起点として作業を行うため、`gh` が利用できない場合は「`gh` が利用できないため終了します」と出力して終了してください**。
対象のレポジトリは `{{REPO_URL}}` です。

指示文: $ARGUMENTS

**原則コードには手を加えないでください。もし調査に際して手を加える必要がある場合はユーザに尋ねて許可を必ずとってください。**

## 概要

Agent Teams を使い、役割ごとに専門化した Teammate を並列起動して、新機能/修正/削除の実装プランを多角的に調査・設計します。
あなた（Claude Code）がチームリーダーとして、タスクの作成・割り当て・結果の統合・Issue 起票を行います。

各 Teammate は `agents/<name>.md` に定義された専用エージェントです。役割・調査手順・出力 JSON フォーマット・起動プロトコルは各エージェントの system prompt に内蔵されており、本コマンドはタスク固有の指示文・パスのみを渡します。

### チーム構成（9 Teammate）

| Teammate 名              | subagent_type            | Phase | モード              | 役割                                               |
| ------------------------ | ------------------------ | ----- | ------------------- | -------------------------------------------------- |
| `architecture-planner`   | `architecture-planner`   | 1     | A: Feature Planning | 実装アーキテクチャ、ファイル構成、データフロー設計、**インフラ要否・IaC 設計** |
| `existing-code-reviewer` | `existing-code-reviewer` | 1     | A: Feature Planning | 既存実装との兼ね合い、再利用可能コード、後方互換性 |
| `library-researcher`     | `library-researcher`     | 1     | —                   | 既存ライブラリ調査、車輪の再発明防止               |
| `security-reviewer`      | `security-reviewer`      | 1     | A: Feature Planning | 認証認可・入力検証・データ保護の設計考慮           |
| `ui-designer`            | `ui-designer`            | 1     | A: Feature Planning | コンポーネント設計、UI 設計、画面設計              |
| `unit-test-planner`      | `unit-test-planner`      | 1     | —                   | 単体テストの影響分析、新規テストケース設計         |
| `e2e-test-planner`       | `e2e-test-planner`       | 1     | —                   | E2E テストシナリオ設計                             |
| `plan-integrator`        | `plan-integrator`        | 2     | —                   | Phase 1 全結果を統合し Issue ドラフトを作成        |
| `issue-reviewer`         | `issue-reviewer`         | 3     | —                   | Issue ドラフトのレビュー・改善案の提示             |

> インフラ変更の要否・インフラ設計は `architecture-planner` が兼任する（専用の infra-reviewer Teammate は廃止）。

### Phase の依存関係

```
Phase 1（並列）─┬─ architecture-planner     [Task 1]
                ├─ existing-code-reviewer   [Task 2]
                ├─ library-researcher       [Task 3]
                ├─ security-reviewer        [Task 4]
                ├─ ui-designer              [Task 5]
                ├─ unit-test-planner        [Task 6]
                └─ e2e-test-planner         [Task 7]
        ↓
   リーダー: /compact 実行（instruct.md 書き出し・起動呼び出し分を圧縮）
        ↓
   Phase 1 Teammate からの通知を待ち受け
        ↓
Phase 2（順次）── plan-integrator            [Task 8]  blockedBy: [1..7]
        ↓
Phase 3（順次）── issue-reviewer             [Task 9] blockedBy: [8]
        ↓
チームリーダーが修正済み Issue ドラフトをユーザーへ提示 → 確認 → 起票
```

---

### コンテキスト管理戦略

ファイルベース通信パターンを使用します。

#### ファイル構成

```
.cache/c-f-i-t/
└── {task-slug}/              # タスク固有のサブディレクトリ
    ├── {teammate-name}/
    │   ├── instruct.md    # リーダー → Teammate: 調査指示（タスク固有部のみ）
    │   ├── report.md      # Teammate → リーダー: 調査結果
    │   ├── questions.md   # Teammate → リーダー: ユーザーへの質問
    │   └── answers.md     # リーダー → Teammate: ユーザーからの回答
```

#### 通信フロー（要点）

1. **指示**: リーダーが `instruct.md` に Write → Teammate は起動後 Read
2. **結果**: Teammate が `report.md` に Write → SendMessage で「調査完了」通知
3. **質問**: Teammate が `questions.md` に Write → SendMessage → リーダーが AskUserQuestion → `answers.md` に回答
4. **コンパクション**: Phase 1 Teammate を全て起動した直後に `/compact` を1回実行

---

## 実行手順

### Step 1: 事前確認

#### 1-1. CLI 確認

```bash
gh auth status
```

#### 1-2. 既存 Issue の確認

```bash
gh issue list --state open --limit 50
```

類似 Issue がある場合はユーザー確認。重複なら終了。

#### 1-3. 指示文の確認

指示文が不十分な場合は AskUserQuestion で **Why / What / How の方向性** を明確化。

#### 1-4. タスク種別の判定

指示文から以下の種別を判定し、Phase 1 で起動する Teammate を決定:

| 種別           | 判定基準                             | 起動する Teammate            |
| -------------- | ------------------------------------ | ---------------------------- |
| バックエンド   | API、DB、Service 層の変更            | 1,2,3,4,6,7（ui: 不要）      |
| フロントエンド | 画面、コンポーネント、状態管理の変更 | 1,2,3,4,5,6,7               |
| フルスタック   | 上記両方                             | 全 Teammate                  |
| インフラ       | Terraform、IaC、CI/CD の変更         | 1,2,4,6,7（ui: 不要。infra は architecture-planner が兼任） |

判断に迷う場合は全 Teammate を起動。該当しない Teammate は「対象外」報告で完了する。インフラ要否・IaC 設計は `architecture-planner`（Task 1）が兼任する。

#### 1-5. タスクスラッグの生成

指示文から `{{TASK_SLUG}}` を kebab-case で生成（英小文字・数字・ハイフンのみ、2〜4 語）。例: `cloud-armor-waf`, `user-profile-edit`。

生成後、タスク固有ディレクトリをクリーンアップ:

```bash
find .cache/c-f-i-t/{{TASK_SLUG}}/ -name "*.md" -type f -delete 2>/dev/null || true
```

---

### Step 2: チーム作成とタスク定義

#### 2-1. チーム作成

```
TeamCreate:
  team_name: "feature-plan"
  description: "機能実装プラン調査チーム"
```

#### 2-2. タスク作成

`TaskCreate` + `TaskUpdate` で以下を作成。

**Phase 1 タスク（並列、依存なし）:**

| Task | subject                | activeForm                           |
| ---- | ---------------------- | ------------------------------------ |
| 1    | アーキテクチャ設計     | アーキテクチャ・インフラを設計中     |
| 2    | 既存コード調査         | 既存コードとの兼ね合いを調査中       |
| 3    | ライブラリ調査         | 活用可能なライブラリを調査中         |
| 4    | セキュリティ調査       | セキュリティ要件を調査中             |
| 5    | UI・コンポーネント設計 | UI・コンポーネントを設計中           |
| 6    | 単体テスト設計         | 単体テストの影響と新規ケースを設計中 |
| 7    | E2E テスト設計         | E2E テストシナリオを設計中           |

**Phase 2 タスク:**

| Task | subject                | activeForm                    | blockedBy |
| ---- | ---------------------- | ----------------------------- | --------- |
| 8    | プラン統合・Issue 作成 | プランを統合し Issue を作成中 | [1..7]    |

**Phase 3 タスク:**

| Task | subject                | activeForm                 | blockedBy |
| ---- | ---------------------- | -------------------------- | --------- |
| 9    | Issue ドラフトレビュー | Issue ドラフトをレビュー中 | [8]       |

---

### Step 3: Phase 1 ─ Teammate 起動と並列調査

#### 3-0. instruct.md の準備

`${CLAUDE_SKILL_DIR}/references/instructs/common.md` を Read し、「instruct.md 共通テンプレート」の
`{{TEAMMATE_NAME}}` `{{INSTRUCTION}}` を置換して、Phase 1 の各 Teammate（architecture-planner / existing-code-reviewer /
library-researcher / security-reviewer / ui-designer / unit-test-planner / e2e-test-planner）の
`.cache/c-f-i-t/{{TASK_SLUG}}/<role>/instruct.md` に Write してください。

特定 Teammate に追加観点が必要な場合（例: UI 設計者に「前提 Issue の要否を必ず判定すること」を追記するなど）、`## 特記事項` に記載する。architecture-planner の `## 特記事項` には「インフラ要否・IaC 設計・環境変数注入先も判定すること」を明記する。

#### 3-1. Phase 1 Teammate の並列起動

instruct.md を全て書き出した後、**7 つの Teammate を 1 メッセージで並列起動してください。**

Mode A（Feature Planning）対応エージェント（architecture-planner / existing-code-reviewer / security-reviewer / ui-designer）には Mode A 指定を含める。モード分岐がないエージェントは素直に File-based 起動するだけで良い。

起動プロンプトは `${CLAUDE_SKILL_DIR}/references/instructs/common.md` の「共通起動プロンプト」を使用し、
`{{TEAMMATE_NAME}}` `{{TASK_SUBJECT}}` `{{TASK_SLUG}}` `{{MODE_HINT}}` を置換して生成します
（`{{MODE_HINT}}` の設定ルールも同ファイルに記載）。

Task tool 呼び出し例:

```
Task tool:
  subagent_type: "devflow:architecture-planner"
  team_name: "feature-plan"
  name: "architecture-planner"
  description: "アーキテクチャ設計"
  prompt: |
    （共通起動プロンプト。{{MODE_HINT}} = "Mode A (Feature Planning) で実行してください。"）
```

7 つの Teammate を同時起動したら、通知待ち受け前に `/compact` を 1 回実行してください。

#### 3-2. 質問対応

Teammate から SendMessage で「質問があります」を受けたら:

1. `.cache/c-f-i-t/{{TASK_SLUG}}/{teammate-name}/questions.md` を Read
2. AskUserQuestion でユーザー確認
3. 回答を `.cache/c-f-i-t/{{TASK_SLUG}}/{teammate-name}/answers.md` に Write
4. SendMessage で Teammate に「回答を保存しました」と通知

---

### Step 4: Phase 1 結果の収集

全 Phase 1 タスクが `completed` になるまで通知を待ち受け。Teammate がエラーで失敗した場合、その旨を記録して残りの結果で継続。

---

### Step 5: Phase 2 ─ プラン統合

#### 5-1. plan-integrator の instruct.md を Write

`${CLAUDE_SKILL_DIR}/references/instructs/plan-integrator.md` を Read し、「instruct.md テンプレート」の
`{{INSTRUCTION}}` `{{TASK_SLUG}}` を置換して `.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/instruct.md` に Write してください。

#### 5-2. plan-integrator の起動

```
Task tool:
  subagent_type: "devflow:plan-integrator"
  team_name: "feature-plan"
  name: "plan-integrator"
  description: "プラン統合・Issue 作成"
  prompt: |
    （references/instructs/plan-integrator.md の「起動プロンプト」を {{TASK_SLUG}} 置換して使用）
```

---

### Step 6: Phase 3 ─ Issue ドラフトレビュー

#### 6-1. issue-reviewer の instruct.md を Write

`${CLAUDE_SKILL_DIR}/references/instructs/issue-reviewer.md` を Read し、「instruct.md テンプレート」の
`{{INSTRUCTION}}` `{{TASK_SLUG}}` を置換して `.cache/c-f-i-t/{{TASK_SLUG}}/issue-reviewer/instruct.md` に Write してください。

#### 6-2. issue-reviewer の起動

```
Task tool:
  subagent_type: "devflow:issue-reviewer"
  team_name: "feature-plan"
  name: "issue-reviewer"
  description: "Issue ドラフトレビュー"
  prompt: |
    （references/instructs/issue-reviewer.md の「起動プロンプト」を {{TASK_SLUG}} 置換して使用）
```

#### 6-3. レビュー結果の反映

1. `issue-reviewer/report.md` を Read
2. `plan-integrator/report.md` を Read
3. レビュー結果に基づいて Issue ドラフトに修正を加える

---

### Step 7: ユーザー確認

レビュー修正済みの Issue ドラフトをユーザーに提示し、以下を確認:

1. **実装方針は正しいか**
2. **受け入れ条件は十分か**
3. **DB 変更がある場合、後方互換性の方針は正しいか**
4. **前提 Issue の要否**
5. **修正すべき点がないか**

---

### Step 8: 前提 Issue の起票（該当する場合）

ui-designer が `prerequisite_issue_needed: true` と報告した場合、UI コンポーネント作成の前提 Issue を先に起票:

```bash
gh issue create --title "enhancement: {{コンポーネント名}} の作成" --body "$(cat <<'EOF'
{{前提 Issue のドラフト}}
EOF
)"
```

URL をメモし、本体 Issue の「依存関係 / 前提」に記載。

---

### Step 9: 本体 Issue の起票

ユーザーの最終許可を得た後、本体 Issue を起票:

```bash
gh issue create --title "enhancement: {{案件名}}" --body "$(cat <<'EOF'
{{最終的な Issue ドラフト}}
EOF
)"
```

Issue URL をユーザーに報告。

---

### Step 10: チーム解散

全作業完了後、各 Teammate に `SendMessage` で `shutdown_request` を送信し、全員シャットダウン後に `TeamDelete` でチーム解散。

---

## 注意事項

- いずれかの Teammate がエラーになった場合は残りの結果で継続
- Phase 2, 3 は前 Phase の結果に依存するため必ず順次実行
- Teammate が idle になるのは正常動作
- DB 変更を伴う場合は後方互換性を必ず確認しユーザー判断を仰ぐ
- 前提 Issue は本体 Issue より先に起票
- **Phase 1 Teammate を全て起動した直後に `/compact` を1回実行すること**
- 各 Teammate の役割・調査手順・出力フォーマットは `agents/<name>.md` を参照（本コマンドでは重複記載しない）
