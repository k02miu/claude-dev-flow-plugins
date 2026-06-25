---
name: create-feature-issue
argument-hint: [実装したい機能の説明]
description: "Agent Teams で多角的に調査・計画し GitHub Issue を作成する"
disable-model-invocation: true
---

# GitHub Issue Feature Creator (Generic)

> **名前空間**: agent / skill 名はインストール時に `devflow:` が付く（例 `devflow:architecture-planner`）。本文で `devflow:` を省略した箇所も同様に解釈する。`general-purpose`（ビルトイン）と `codex:*`（別プラグイン）は例外でそのまま。

> **変数**: `{{VARIABLE}}` は配布時に自動置換されない。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成から解決する。解決できないときだけユーザーに確認する。下表は既定値の参考。

## 変数

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

`gh` が設定済みで `git remote get-url origin` が通れば `{{REPO_URL}}` は自動検出できる。

最初に `gh` の利用可否を確認する。使えなければ設定を促し、「`gh` が利用できないため終了します」と出力して終了する。対象リポジトリは `{{REPO_URL}}`。

指示文: $ARGUMENTS

調査フェーズではコードを変更しない。変更が必要なら必ずユーザーの許可を得る。

## 概要

Agent Teams で、役割ごとに専門化した Teammate を並列起動し、新機能/修正/削除の実装プランを多角的に調査・設計する。リーダー（Claude Code）がタスクの作成・割り当て・結果の統合・Issue 起票を担う。

各 Teammate は `agents/<name>.md` の専用エージェント。役割・調査手順・出力フォーマット・起動プロトコルは各エージェントの system prompt に内蔵されているため、本コマンドはタスク固有の指示文とパスだけを渡す。

### チーム構成（最大 8 Teammate・起動対象は種別で変動）

| Teammate 名              | subagent_type            | Phase | モード              | 役割                                               |
| ------------------------ | ------------------------ | ----- | ------------------- | -------------------------------------------------- |
| `architecture-planner`   | `architecture-planner`   | 1     | A: Feature Planning | 実装アーキテクチャ、ファイル構成、データフロー設計、**インフラ要否・IaC 設計** |
| `existing-code-reviewer` | `existing-code-reviewer` | 1     | A: Feature Planning | 既存実装との兼ね合い、再利用可能コード、後方互換性 |
| `library-researcher`     | `library-researcher`     | 1     | —                   | 既存ライブラリ調査、車輪の再発明防止               |
| `security-reviewer`      | `security-reviewer`      | 1     | A: Feature Planning | 認証認可・入力検証・データ保護の設計考慮           |
| `ui-designer`            | `ui-designer`            | 1     | A: Feature Planning | コンポーネント設計、UI 設計、画面設計              |
| `test-planner`           | `test-planner`           | 1     | —                   | 単体テスト + E2E テスト設計（scope で範囲指定）    |
| `plan-integrator`        | `plan-integrator`        | 2     | —                   | Phase 1 全結果を統合し Issue ドラフトを作成        |
| `issue-reviewer`         | `issue-reviewer`         | 3     | —                   | Issue ドラフトのレビュー・改善案の提示             |

> インフラ変更の要否・設計は `architecture-planner` が兼任する（専用の infra-reviewer Teammate は廃止）。

### Phase の依存関係

```
Phase 1（並列・起動対象のみ）─┬─ architecture-planner     [Task 1]
                ├─ existing-code-reviewer   [Task 2]
                ├─ library-researcher       [Task 3]
                ├─ security-reviewer        [Task 4]
                ├─ ui-designer              [Task 5]
                └─ test-planner             [Task 6]
        ↓
   リーダー: /compact 実行（instruct.md 書き出し・起動分を圧縮）
        ↓
   Phase 1 Teammate からの通知を待ち受け
        ↓
Phase 2（順次）── plan-integrator            [Task 7]  blockedBy: 起動した Phase 1 タスク
        ↓
Phase 3（順次）── issue-reviewer             [Task 8] blockedBy: [7]
        ↓
リーダーが修正済み Issue ドラフトをユーザーへ提示 → 確認 → 起票
```

---

### コンテキスト管理

ファイルベース通信を使う。

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

#### 通信フロー

1. **指示**: リーダーが `instruct.md` に Write → Teammate は起動後 Read
2. **結果**: Teammate が `report.md` に Write → SendMessage で完了通知
3. **質問**: Teammate が `questions.md` に Write → SendMessage → リーダーが AskUserQuestion → `answers.md` に回答
4. **圧縮**: Phase 1 Teammate を起動した直後に `/compact` を1回実行

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

類似 Issue があればユーザーに確認する。重複なら終了。

#### 1-3. 指示文の確認

指示文が不十分なら、AskUserQuestion で Why / What / How の方向性を明確化する。

#### 1-4. タスク種別の判定

指示文から種別を判定し、起動する Teammate を決める:

| 種別           | 判定基準                             | 起動する Teammate            |
| -------------- | ------------------------------------ | ---------------------------- |
| バックエンド   | API、DB、Service 層の変更            | 1,2,3,4,6（ui: 不要）        |
| フロントエンド | 画面、コンポーネント、状態管理の変更 | 1,2,3,4,5,6                 |
| フルスタック   | 上記両方                             | 全 Teammate                  |
| インフラ       | Terraform、IaC、CI/CD の変更         | 1,2,4,6（ui: 不要。infra は architecture-planner が兼任） |

**判定で起動対象とした Teammate のみ起動**し、不要な観点は起動しない（タスク・instruct.md も作成しない）。判断に迷う観点は安全側で起動する。インフラ要否・IaC 設計は `architecture-planner`（Task 1）が兼任する。

#### 1-5. タスクスラッグの生成

指示文から `{{TASK_SLUG}}` を kebab-case で生成する（英小文字・数字・ハイフン、2〜4 語）。例: `cloud-armor-waf`, `user-profile-edit`。

生成後、タスク固有ディレクトリをクリーンアップ:

```bash
find .cache/c-f-i-t/{{TASK_SLUG}}/ -name "*.md" -type f -delete 2>/dev/null || true
```

---

### Step 2: タスク定義

#### 2-1. タスク作成

Step 1-4 で起動対象とした観点のみ `TaskCreate` + `TaskUpdate` で作成する（番号は下表に従う。起動しない観点は欠番でよい）。

**Phase 1 タスク（並列、依存なし）:**

| Task | subject                | activeForm                           |
| ---- | ---------------------- | ------------------------------------ |
| 1    | アーキテクチャ設計     | アーキテクチャ・インフラを設計中     |
| 2    | 既存コード調査         | 既存コードとの兼ね合いを調査中       |
| 3    | ライブラリ調査         | 活用可能なライブラリを調査中         |
| 4    | セキュリティ調査       | セキュリティ要件を調査中             |
| 5    | UI・コンポーネント設計 | UI・コンポーネントを設計中           |
| 6    | テスト設計             | テスト（単体 + E2E）を設計中         |

**Phase 2 タスク:**

| Task | subject                | activeForm                    | blockedBy |
| ---- | ---------------------- | ----------------------------- | --------- |
| 7    | プラン統合・Issue 作成 | プランを統合し Issue を作成中 | 起動した Phase 1 タスク |

**Phase 3 タスク:**

| Task | subject                | activeForm                 | blockedBy |
| ---- | ---------------------- | -------------------------- | --------- |
| 8    | Issue ドラフトレビュー | Issue ドラフトをレビュー中 | [7]       |

---

### Step 3: Phase 1 ─ Teammate 起動と並列調査

#### 3-0. instruct.md の準備

`${CLAUDE_SKILL_DIR}/references/instructs/common.md` を Read し、「instruct.md 共通テンプレート」の `{{TEAMMATE_NAME}}` `{{INSTRUCTION}}` を置換して、Step 1-4 で起動対象とした各 Teammate（architecture-planner / existing-code-reviewer / library-researcher / security-reviewer / ui-designer / test-planner のうち該当するもの）の `.cache/c-f-i-t/{{TASK_SLUG}}/<role>/instruct.md` に Write する。

特定の Teammate に追加観点が必要なら `## 特記事項` に記載する。architecture-planner には「インフラ要否・IaC 設計・環境変数注入先も判定する」を明記する。test-planner の instruct には `scope`（unit / e2e / both）を必ず指定する（UI・画面の変更を含むなら both、バックエンド/インフラ中心なら unit を目安）。

#### 3-1. Phase 1 Teammate の並列起動

instruct.md を書き出したら、**Step 1-4 で起動対象とした Teammate を 1 メッセージで並列起動する**（最大 6、種別により 3〜6 体）。

Mode A（Feature Planning）対応エージェント（architecture-planner / existing-code-reviewer / security-reviewer / ui-designer）には Mode A 指定を含める。モード分岐がないエージェントはそのまま File-based 起動でよい。

起動プロンプトは `${CLAUDE_SKILL_DIR}/references/instructs/common.md` の「共通起動プロンプト」を使い、`{{TEAMMATE_NAME}}` `{{TASK_SUBJECT}}` `{{TASK_SLUG}}` `{{MODE_HINT}}` を置換する（`{{MODE_HINT}}` の設定ルールも同ファイルに記載）。

Task tool 呼び出し例:

```
Task tool:
  subagent_type: "devflow:architecture-planner"
  name: "architecture-planner"
  description: "アーキテクチャ設計"
  prompt: |
    （共通起動プロンプト。{{MODE_HINT}} = "Mode A (Feature Planning) で実行してください。"）
```

起動したら、通知の待ち受け前に `/compact` を1回実行する。

#### 3-2. 質問対応

Teammate から SendMessage で「質問があります」を受けたら:

1. `.cache/c-f-i-t/{{TASK_SLUG}}/{teammate-name}/questions.md` を Read
2. AskUserQuestion でユーザーに確認
3. 回答を `.cache/c-f-i-t/{{TASK_SLUG}}/{teammate-name}/answers.md` に Write
4. SendMessage で「回答を保存した」と通知

---

### Step 4: Phase 1 結果の収集

全 Phase 1 タスクが `completed` になるまで通知を待ち受ける。Teammate がエラーで失敗したら、その旨を記録して残りの結果で継続する。

---

### Step 5: Phase 2 ─ プラン統合

#### 5-1. plan-integrator の instruct.md を Write

`${CLAUDE_SKILL_DIR}/references/instructs/plan-integrator.md` を Read し、「instruct.md テンプレート」の `{{INSTRUCTION}}` `{{TASK_SLUG}}` を置換して `.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/instruct.md` に Write する。

#### 5-2. plan-integrator の起動

```
Task tool:
  subagent_type: "devflow:plan-integrator"
  name: "plan-integrator"
  description: "プラン統合・Issue 作成"
  prompt: |
    （references/instructs/plan-integrator.md の「起動プロンプト」を {{TASK_SLUG}} 置換して使用）
```

---

### Step 6: Phase 3 ─ Issue ドラフトレビュー

#### 6-1. issue-reviewer の instruct.md を Write

`${CLAUDE_SKILL_DIR}/references/instructs/issue-reviewer.md` を Read し、「instruct.md テンプレート」の `{{INSTRUCTION}}` `{{TASK_SLUG}}` を置換して `.cache/c-f-i-t/{{TASK_SLUG}}/issue-reviewer/instruct.md` に Write する。

#### 6-2. issue-reviewer の起動

```
Task tool:
  subagent_type: "devflow:issue-reviewer"
  name: "issue-reviewer"
  description: "Issue ドラフトレビュー"
  prompt: |
    （references/instructs/issue-reviewer.md の「起動プロンプト」を {{TASK_SLUG}} 置換して使用）
```

#### 6-3. レビュー結果の反映

1. `issue-reviewer/report.md` を Read
2. `plan-integrator/report.md` を Read
3. レビュー結果に基づいて Issue ドラフトを修正する

---

### Step 7: ユーザー確認

修正済みの Issue ドラフトをユーザーに提示し、次を確認する:

1. 実装方針は正しいか
2. 受け入れ条件は十分か
3. DB 変更がある場合、後方互換性の方針は正しいか
4. 前提 Issue の要否
5. 修正すべき点はないか

---

### Step 8: 前提 Issue の起票（該当する場合）

ui-designer が `prerequisite_issue_needed: true` と報告したら、UI コンポーネント作成の前提 Issue を先に起票する:

```bash
gh issue create --title "enhancement: {{コンポーネント名}} の作成" --body "$(cat <<'EOF'
{{前提 Issue のドラフト}}
EOF
)"
```

URL をメモし、本体 Issue の「依存関係 / 前提」に記載する。

---

### Step 9: 本体 Issue の起票

ユーザーの最終許可を得たら、本体 Issue を起票する:

```bash
gh issue create --title "enhancement: {{案件名}}" --body "$(cat <<'EOF'
{{最終的な Issue ドラフト}}
EOF
)"
```

Issue URL をユーザーに報告する。

---

### Step 10: Teammate のシャットダウン

全作業の完了後、各 Teammate に `SendMessage` で `shutdown_request` を送る（チームは implicit のため解体操作は不要）。

---

## 注意事項

- Teammate がエラーになったら、残りの結果で継続する。
- Phase 2, 3 は前 Phase の結果に依存するため順次実行する。
- Teammate が idle になるのは正常な動作（メッセージ送信後の待機）。
- DB 変更を伴う場合は後方互換性を確認し、ユーザー判断を仰ぐ。
- 前提 Issue は本体 Issue より先に起票する。
- 各 Teammate の役割・調査手順・出力フォーマットは `agents/<name>.md` を参照する（本コマンドでは重複記載しない）。
