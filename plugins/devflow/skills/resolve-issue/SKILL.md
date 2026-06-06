---
argument-hint: [issue number]
name: resolve-issue
description: "Agent Teams で多角的に調査・計画し GitHub Issue を解決する"
disable-model-invocation: true
---

# GitHub Issue Resolver (Agent Teams 版) — Generic

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


> **変数の解決（重要）**: 本スキル内の `{{VARIABLE}}` はプラグイン配布時に自動置換されません。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成を調査して値を解決してください。解決できない場合のみユーザーに確認します。以下の「VARIABLES」表は既定値の参考です。

## VARIABLES — Fill these in before first use

| Variable                  | Description                                      | Example                          |
|---------------------------|--------------------------------------------------|----------------------------------|
| {{REPO_URL}}              | Git remote URL (auto-detected if git is present) | https://github.com/org/repo.git |
| {{PACKAGE_MANAGER}}           | Package manager used in project                  | npm / yarn / pnpm / bun         |
| {{FRONTEND_FRAMEWORK}}             | Main web framework                               | Next.js / Nuxt / Remix / Django |
| {{ORM}}                   | ORM / database layer                             | Prisma / Drizzle / TypeORM / SQLAlchemy |
| {{UNIT_TEST_FRAMEWORK}}        | Unit test framework                              | Vitest / Jest / Mocha           |
| {{E2E_TEST_FRAMEWORK}}         | E2E test framework                               | Playwright / Cypress            |
| {{LINTER}}      | Linter / formatter                               | Biome / ESLint / Prettier       |
| {{CSS_FRAMEWORK}}         | CSS framework                                    | Tailwind CSS / UnoCSS           |
| {{UI_LIBRARY}}                | UI component library                             | shadcn/ui / Material UI / Radix |
| {{AUTH_LIBRARY}}          | Authentication library                           | NextAuth / Better Auth / Auth0  |
| {{STATE_MANAGER}}         | State management (if frontend)                   | Zustand / Redux / Pinia         |
| {{IAC_TOOL}}            | Infrastructure as Code tool                      | Terraform / Pulumi / CDK        |
| {{CLOUD_PROVIDER}}        | Cloud provider                                   | GCP / AWS / Azure               |
| {{REPORT_GENERATOR}}      | HTML report generator script (optional)          | report-gen / scripts/gen-report.sh |

> If `gh` CLI is configured and `git remote get-url origin` works, `{{REPO_URL}}` may be auto-detected.

はじめに `gh` が使えるかを確認して下さい。`gh` が使えない場合、ユーザに `gh` の設定を促す応答をして終了してください。
**GitHub を起点として作業を行うため、`gh` が利用できない場合は「`gh` が利用できないため終了します」と出力して終了してください。また、commit & push はユーザーが行うため絶対に行わないでください**。
対象のレポジトリは `{{REPO_URL}}` です。

ISSUE #$ARGUMENTS

**原則コードへの変更はチームによる調査・計画フェーズ完了後に行います。調査フェーズではコードに手を加えないでください。**

## 概要

Agent Teams を使い、**プロジェクト専用のローカルエージェント**（`agents/<name>`）を各役割に割り当てた 9 Teammate を並列起動し、GitHub Issue の実装プランを多角的に調査・設計し、承認後に実装を行います。
あなた（Claude Code）がチームリーダーとして、タスクの作成・割り当て・結果の統合・実装を行います。

**フル版の特徴:**

- 7 つの専門 Teammate が並列に調査（アーキテクチャ＋インフラ、既存コード、ライブラリ、セキュリティ、UI、単体テスト、E2E テスト）
- 各 Teammate はプロジェクトの文脈を内蔵したローカル専用エージェント（`agents/`）
- Phase 2 で全結果を統合し実装プラン（Mermaid 図付き）を自動生成
- Phase 3 で別コンテキストから実装プランをレビュー（MCP で技術的正確性を検証）
- 承認後にチームリーダーが実装を実行

---

## チーム構成（9 Teammate）

| Teammate 名              | subagent_type            | Phase | 役割                                                      |
| ------------------------ | ------------------------ | ----- | --------------------------------------------------------- |
| `architecture-planner`   | `architecture-planner`   | 1     | 実装アーキテクチャ、ファイル構成、データフロー設計、**インフラ要否・IaC（{{IAC_TOOL}}/{{CLOUD_PROVIDER}}）設計** |
| `existing-code-reviewer` | `existing-code-reviewer` | 1     | 既存実装との兼ね合い、再利用可能コード、後方互換性        |
| `library-researcher`     | `library-researcher`     | 1     | 既存ライブラリ調査、車輪の再発明防止                      |
| `security-reviewer`      | `security-reviewer`      | 1     | 認証認可・入力検証・データ保護の設計考慮                  |
| `ui-designer`            | `ui-designer`            | 1     | コンポーネント設計、UI 設計、画面設計                     |
| `unit-test-planner`      | `unit-test-planner`      | 1     | 単体テストの影響分析、新規テストケース設計                |
| `e2e-test-planner`       | `e2e-test-planner`       | 1     | E2E テストシナリオ設計                                    |
| `plan-integrator`        | `plan-integrator`        | 2     | Phase 1 全結果を統合し実装プラン（Mermaid 図付き）を作成  |
| `issue-reviewer`         | `issue-reviewer`         | 3     | 実装プランのレビュー・改善案の提示                        |

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
Phase 2（順次）── plan-integrator            [Task 8] blockedBy: [1,2,3,4,5,6,7]
        ↓
Phase 3（順次）── issue-reviewer             [Task 9] blockedBy: [8]
        ↓
チームリーダーが実装プランをユーザーへ提示 → 確認 → 実装
```

タスク分解・依存グラフの詳細は、plugin が提供する `agent-teams:task-coordination-strategies` 相当の skill を参照。

---

## コンテキスト管理戦略

チームリーダーと Teammate 間の通信はすべて **ファイルベース** で行い、コンテキストウィンドウの圧迫を防ぎます。

### ファイル構造

```
.cache/r-i-t/
└── {task-slug}/              # タスク固有のサブディレクトリ（例: issue-123-cloud-armor）
    ├── architecture-planner/
    │   ├── instruct.md    # リーダー → Teammate: 調査指示
    │   ├── report.md      # Teammate → リーダー: 調査結果
    │   ├── questions.md   # Teammate → リーダー: ユーザーへの質問
    │   └── answers.md     # リーダー → Teammate: ユーザーからの回答
    ├── existing-code-reviewer/
    ├── library-researcher/
    ├── security-reviewer/
    ├── ui-designer/
    ├── unit-test-planner/
    ├── e2e-test-planner/
    ├── plan-integrator/
    └── issue-reviewer/
        └── ...（同構造）
```

### 通信フロー（要点）

1. **指示**: リーダーが `instruct.md` に Write → Teammate は起動後 Read
2. **結果**: Teammate が `report.md` に Write → SendMessage で「調査完了」通知
3. **質問**: Teammate が `questions.md` に Write → SendMessage → リーダーが AskUserQuestion → `answers.md` に回答
4. **コンパクション**: Phase 1 Teammate を全て起動した直後に `/compact` を1回実行（通知受信前の圧縮）

> **`{task-slug}`** は Step 1-6 で Issue 番号と内容から生成する kebab-case の短い識別子です。
> 複数のコマンドインスタンスが同時実行されてもディレクトリが競合しないようにするための仕組みです。

---

## 実行手順

### Step 0: キャッシュクリーンアップ

前回の実行結果が残っている場合に備え、今回のタスクスラッグ配下の `*.md` ファイルをすべて削除します。

> **注意**: `{{TASK_SLUG}}` は Step 1-6 で生成します。Step 0 の時点ではまだ未確定のため、Step 1-6 完了後にこのクリーンアップを実行してください。

```bash
find .cache/r-i-t/{{TASK_SLUG}}/ -name "*.md" -type f -delete 2>/dev/null || true
```

---

### Step 1: 事前確認

#### 1-1. CLI 確認

```bash
gh auth status
```

#### 1-2. Issue の確認

Issue の内容をコメントも含めて確認してください。

```bash
gh issue view $ARGUMENTS --comments
```

#### 1-3. 既存 PR の確認

この Issue に対応している PR があるか確認してください。

```bash
gh pr list --state open --limit 50
```

- **既に対応している PR がない場合**: 現在のブランチにて対応を開始する
- **既に対応している PR がある場合**: 既存の PR で対応を開始するか、新しく PR を立てて対応を開始するかユーザーに聞いて対応を開始する。既存の PR から開始する場合は PR の内容も `gh` を利用して対応状況を確認すること

#### 1-4. タスク種別の判定

Issue の内容から以下の種別を判定し、Phase 1 で起動する Teammate を決定してください:

| 種別           | 判定基準                             | 起動する Teammate           |
| -------------- | ------------------------------------ | --------------------------- |
| バックエンド   | API、DB、Service 層の変更            | 1,2,3,4,6,7 (ui: 不要)      |
| フロントエンド | 画面、コンポーネント、状態管理の変更 | 1,2,3,4,5,6,7              |
| フルスタック   | 上記両方                             | 全 Teammate                 |
| インフラ       | {{IAC_TOOL}}、{{CLOUD_PROVIDER}}、CI/CD の変更         | 1,2,4,6,7 (ui: 不要。infra は architecture-planner が兼任) |

**判断に迷う場合は全 Teammate を起動してください。**
該当しない Teammate は「対象外」と報告して完了します。インフラ要否・IaC 設計は `architecture-planner`（Task 1）が兼任します。

#### 1-5. タスクスラッグの生成

Issue 番号と内容から、タスクを一意に識別する短い kebab-case のスラッグ `{{TASK_SLUG}}` を生成してください。

- Issue 番号をプレフィックスに含め、英語の kebab-case で 2〜4 語程度（例: `issue-123-cloud-armor`, `issue-45-user-profile`）
- ディレクトリ名として有効な文字のみ使用（英小文字、数字、ハイフン）
- Issue のタイトルから主要なキーワードを抽出して短縮

生成後、Step 0 のキャッシュクリーンアップを実行してください。

#### 1-6. ユーザーへの事前確認

AskUserQuestion を使って、以下をユーザーに確認してください:

- Issue の内容から判定したタスク種別と、起動する Teammate の一覧
- チーム作成の承認

---

### Step 2: チーム作成とタスク定義

#### 2-1. チーム作成

```
TeamCreate:
  team_name: "resolve-issue"
  description: "Issue #$ARGUMENTS 解決チーム"
```

#### 2-2. タスク作成

以下のタスクを `TaskCreate` で作成し、`TaskUpdate` で依存関係を設定してください。
`{{ISSUE_CONTENT}}` は Issue の内容に置き換えます。
Step 1-4 で不要と判定した Teammate のタスクも作成しますが、プロンプトに「該当しない場合は対象外と報告して完了」と指示してあるため問題ありません。

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

**Phase 2 タスク（Phase 1 完了後）:**

| Task | subject        | activeForm         | blockedBy       |
| ---- | -------------- | ------------------ | --------------- |
| 8    | 実装プラン統合 | 実装プランを統合中 | [1,2,3,4,5,6,7] |

**Phase 3 タスク（Phase 2 完了後）:**

| Task | subject            | activeForm             | blockedBy |
| ---- | ------------------ | ---------------------- | --------- |
| 9    | 実装プランレビュー | 実装プランをレビュー中 | [8]       |

---

## 起動プロンプト共通テンプレ

各 Teammate 共通のテンプレ。`{{TEAMMATE_NAME}}` `{{TASK_SUBJECT}}` `{{TASK_SLUG}}` を置換してください。
各 Teammate 固有の指示（instruct.md の内容、追加指示）は Step 3〜6 で個別に定義します。

```
あなたはチーム "resolve-issue" の Teammate "{{TEAMMATE_NAME}}" です。
TaskList でタスク一覧を確認し、自分のタスク「{{TASK_SUBJECT}}」を TaskUpdate で
owner を自分に設定し、status を in_progress にしてから作業を開始してください。

まず `.cache/r-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/instruct.md` を Read ツールで読み、指示内容を確認してください。
**コードには手を加えないでください。read only で調査・設計のみを行ってください。**

{{ROLE_SPECIFIC_INSTRUCTIONS}}  ← 各 Teammate 固有の追加指示をここに挿入

【質問エスカレーション】
調査中にユーザーへの確認が必要な質問が生じた場合:
1. 質問内容を `.cache/r-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/questions.md` に Write
2. SendMessage でチームリーダーに「質問があります」と通知
3. `.cache/r-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/answers.md` にリーダーが回答を保存するので、Read で確認してから作業を続行

SendMessage の使い分けはプラグインの `agent-teams:team-communication-protocols` 相当 skill を参照。

【結果の保存】
調査完了後:
1. 結果を instruct.md に記載された JSON 形式（または指定された形式）でまとめる
2. `.cache/r-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/report.md` に Write
3. SendMessage でチームリーダーに「調査完了」と通知
4. TaskUpdate でタスクを completed にする
```

---

### Step 3: Phase 1 ─ Teammate 起動と並列調査

#### Step 3-0: 指示ファイルの準備

Phase 1 の Teammate を起動する **前に**、リーダーが各 Teammate の `instruct.md` を Write ツールで作成してください。
以下の 3-1 〜 3-7 に記載された「instruct.md の内容」を、それぞれ対応するパスに書き出します。

```
.cache/r-i-t/{{TASK_SLUG}}/architecture-planner/instruct.md
.cache/r-i-t/{{TASK_SLUG}}/existing-code-reviewer/instruct.md
.cache/r-i-t/{{TASK_SLUG}}/library-researcher/instruct.md
.cache/r-i-t/{{TASK_SLUG}}/security-reviewer/instruct.md
.cache/r-i-t/{{TASK_SLUG}}/ui-designer/instruct.md
.cache/r-i-t/{{TASK_SLUG}}/unit-test-planner/instruct.md
.cache/r-i-t/{{TASK_SLUG}}/e2e-test-planner/instruct.md
```

`{{ISSUE_CONTENT}}` は Issue の実際の内容に置き換えてください。

**Phase 1 の Teammate を Task tool で並列起動してください（1 メッセージで複数の Task 呼び出し）。**
各 Teammate には `team_name: "resolve-issue"` と `name`、そして役割表で指定された `subagent_type` を指定してください。
起動プロンプトは本ファイル「起動プロンプト共通テンプレ」節 + 各 Teammate 固有の追加指示を使用します。

いずれかの Teammate がエラーになった場合は、残りの Teammate の結果で調査を継続してください。

**重要: Teammate を全て起動したら、通知の待ち受けを開始する前に `/compact` を実行してください。**
instruct.md の書き出し（7ファイル）と Task tool の起動呼び出し（7回）でコンテキストが大きく膨らんでいるため、
Teammate からの通知を受け取る前に圧縮しないと、通知受信中にコンテキストサイズを超過するリスクがあります。

**質問対応**: Teammate から SendMessage で「質問があります」と通知が来た場合:

1. `.cache/r-i-t/{{TASK_SLUG}}/{teammate-name}/questions.md` を Read
2. AskUserQuestion でユーザーに確認する
3. 回答を `.cache/r-i-t/{{TASK_SLUG}}/{teammate-name}/answers.md` に Write
4. SendMessage で Teammate に「回答しました」と通知

---

#### 3-1. architecture-planner

**Task tool パラメータ:**

```
subagent_type: "devflow:architecture-planner"
team_name: "resolve-issue"
name: "architecture-planner"
description: "アーキテクチャ・インフラ設計"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
Issue の要件を満たす実装アーキテクチャを設計します。あわせてインフラ要否・IaC（{{IAC_TOOL}}/{{CLOUD_PROVIDER}}）設計・環境変数注入先・CI/CD 影響・コスト影響も判定してください（専用の infra-reviewer は廃止し、本ロールが兼任します）。
{{CLOUD_PROVIDER}} リソース・サービス仕様・制約・料金は推測せず、利用可能な MCP（公式ドキュメント検索）と読み取り系 CLI で裏取りしてください。
```

**instruct.md の内容** (`.cache/r-i-t/{{TASK_SLUG}}/architecture-planner/instruct.md`):

```
【Issue の内容】
{{ISSUE_CONTENT}}

【このプロジェクトの構成】
（プロジェクトのディレクトリ構成をここに記述。例: apps/web, packages/database, packages/domain 等）
- フロントエンドレイヤー:
- バックエンド/API レイヤー:
- データベース/ORM レイヤー:
- ドメインロジック:
- インフラレイヤー:

【調査手順】
1. コードベース解析ツール（利用可能な MCP 等）で既存のアーキテクチャを確認
   - 関連するファイル・クラス・関数を特定
   - プロジェクトのアーキテクチャドキュメントを参照（docs/ 配下など）
   - API エンドポイント定義を参照
   - DB スキーマ定義を参照

2. 以下の観点で設計を行う:
   - 変更/追加するファイル一覧（パスと役割）
   - データフロー（入力 → 処理 → 出力）
   - レイヤー構成（API Route → Service → Database）
   - DB スキーマ変更の有無（変更がある場合はマイグレーション方針も）
   - 後方互換性への影響
   - Clean Architecture / DDD 観点でのレイヤー境界の妥当性（該当する場合）

3. DB 変更がある場合:
   - ORM スキーマファイルを確認
   - 既存データのマイグレーション戦略
   - 後方互換性を保てるか（破壊的変更の有無）

4. インフラ要否・IaC 設計:
   - クラウドリソース変更の要否（新規サービス利用・既存設定変更・IAM/ネットワーク・非同期キュー/ジョブ追加）
   - {{IAC_TOOL}} 等の IaC 変更（インフラディレクトリのファイルを Read）
   - 環境変数の追加と全実行サービスへの注入先
   - CI/CD 影響・概算コスト影響
   - クラウド仕様確認は利用可能な MCP、現行リソース確認は読み取り系 CLI で裏取り（書き込み系は実行しない）
   - インフラ変更が不要なら `infra.needed: false` と明記

【結果の JSON 形式】
{
  "role": "architecture_planner",
  "design": {
    "overview": "アーキテクチャ概要",
    "affected_files": [
      {
        "path": "ファイルパス",
        "action": "create | modify | delete",
        "description": "変更内容"
      }
    ],
    "data_flow": "データフローの説明",
    "layer_design": "レイヤー構成の説明",
    "db_changes": {
      "needed": true | false,
      "migrations": ["マイグレーション内容"],
      "backward_compatible": true | false,
      "breaking_changes": ["破壊的変更の説明（ある場合）"]
    },
    "infra": {
      "needed": true | false,
      "cloud_changes": [
        { "service": "サービス名", "action": "create | modify | delete", "description": "変更内容", "cost_impact": "概算コスト影響" }
      ],
      "iac_changes": [
        { "resource": "リソース名", "action": "create | modify | delete", "description": "変更内容", "file": "対象ファイル" }
      ],
      "env_vars": [
        { "name": "環境変数名", "action": "add | modify | delete", "description": "用途", "injection_targets": ["注入先ファイル/サービス"] }
      ],
      "cicd_changes": ["CI/CD 変更内容"]
    },
    "estimated_complexity": "small | medium | large",
    "risks": ["リスク・懸念事項"]
  }
}
```

---

#### 3-2. existing-code-reviewer

**Task tool パラメータ:**

```
subagent_type: "devflow:existing-code-reviewer"
team_name: "resolve-issue"
name: "existing-code-reviewer"
description: "既存コード調査"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
あなたは existing-code-reviewer（既存コード調査の専門 agent）として、既存コードとの兼ね合いを調査します。
再利用可能なコード、衝突リスク、後方互換性、テストへの影響を優先的に確認してください。
```

**instruct.md の内容** (`.cache/r-i-t/{{TASK_SLUG}}/existing-code-reviewer/instruct.md`):

```
【Issue の内容】
{{ISSUE_CONTENT}}

【調査手順】
1. コードベース解析ツール（利用可能な MCP 等）で関連する既存コードを調査
   - 関連するシンボル・ファイルを特定
   - 関連ファイルの構造を把握

2. 以下の観点で調査:

   a) 再利用可能なコード
      - 既存の Service 層、ユーティリティ、コンポーネントで流用できるものはないか
      - 同様の機能が別の箇所で既に実装されていないか
      - 共通パッケージに適切な関数がないか

   b) 衝突・競合リスク
      - 変更対象のコードを他の機能が参照していないか
      - 並行して開発中の機能との競合はないか（Open PR の確認）
      - 共有コンポーネントの変更が他の画面に影響しないか

   c) 後方互換性
      - API の変更がフロントエンド・他サービスに影響しないか
      - DB スキーマの変更が既存データに影響しないか
      - 設定値やフラグの変更が運用に影響しないか

   d) テストへの影響
      - 既存テストが破壊される可能性
      - 新規テストが必要な範囲

【結果の JSON 形式】
{
  "role": "existing_code_reviewer",
  "reusable_code": [
    {
      "path": "ファイルパス",
      "symbol": "関数/クラス/コンポーネント名",
      "description": "再利用方法の説明"
    }
  ],
  "conflicts": [
    {
      "path": "ファイルパス",
      "description": "競合リスクの説明",
      "severity": "high | medium | low",
      "mitigation": "回避策"
    }
  ],
  "backward_compatibility": {
    "safe": true | false,
    "concerns": ["後方互換性の懸念"]
  },
  "test_impact": {
    "broken_tests": ["影響を受けるテストファイル"],
    "new_tests_needed": ["追加が必要なテスト"]
  }
}
```

---

#### 3-3. library-researcher

**Task tool パラメータ:**

```
subagent_type: "devflow:library-researcher"
team_name: "resolve-issue"
name: "library-researcher"
description: "ライブラリ調査"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
利用可能な MCP 検索ツールを主体に、関連ライブラリのドキュメントを検索して調査を行ってください。
既存技術スタックでの実現可能性を最優先に考え、新規ライブラリ導入は慎重に判断すること。
```

**instruct.md の内容** (`.cache/r-i-t/{{TASK_SLUG}}/library-researcher/instruct.md`):

```
【Issue の内容】
{{ISSUE_CONTENT}}

【現在の主要技術スタック】
- {{FRONTEND_FRAMEWORK}}
- {{ORM}} + Database
- {{UI_LIBRARY}} + {{CSS_FRAMEWORK}}
- {{STATE_MANAGER}}（状態管理、該当する場合）
- {{AUTH_LIBRARY}}（認証）
- {{E2E_TEST_FRAMEWORK}}（E2E）/ {{UNIT_TEST_FRAMEWORK}}（Unit）
- {{CLOUD_PROVIDER}}
- その他プロジェクト固有の主要ライブラリ

【調査手順】
1. 利用可能な MCP を使って関連ライブラリのドキュメントを検索
   - ライブラリ ID で候補を特定
   - 具体的な使用方法を確認

2. 以下の観点で調査:

   a) 既存技術スタックで実現可能か
      - 現在使用中のライブラリの機能で実現できないか
      - {{UI_LIBRARY}} のコンポーネントで UI 要件を満たせないか

   b) 新規ライブラリの候補
      - Issue の要件を効率的に実現できるライブラリ
      - パッケージレジストリでのダウンロード数、メンテナンス状況、ライセンス
      - フレームワークとの互換性

   c) 導入コスト vs 自前実装コスト
      - ライブラリ導入のメリット・デメリット
      - バンドルサイズへの影響
      - 学習コスト

ライブラリの調査が不要な場合（純粋なビジネスロジック変更など）は、
その旨を報告して完了してください。

【結果の JSON 形式】
{
  "role": "library_researcher",
  "applicable": true | false,
  "existing_stack_solutions": [
    {
      "library": "ライブラリ名",
      "feature": "活用できる機能",
      "usage": "使用方法の概要",
      "doc_url": "ドキュメント URL（MCP で取得した場合）"
    }
  ],
  "new_library_candidates": [
    {
      "name": "ライブラリ名",
      "purpose": "導入目的",
      "pros": ["メリット"],
      "cons": ["デメリット"],
      "bundle_impact": "バンドルサイズへの影響",
      "compatibility": "フレームワークとの互換性",
      "recommendation": "推奨 | 検討 | 非推奨"
    }
  ],
  "recommendation": "最終的な推奨方針"
}
```

---

#### 3-4. security-reviewer

**Task tool パラメータ:**

```
subagent_type: "devflow:security-reviewer"
team_name: "resolve-issue"
name: "security-reviewer"
description: "セキュリティ調査"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
あなたは security-reviewer（セキュリティ専門 agent）として、OWASP Top 10 / 認証認可 / データ保護の観点で
セキュリティ要件を設計します。
```

**instruct.md の内容** (`.cache/r-i-t/{{TASK_SLUG}}/security-reviewer/instruct.md`):

```
【Issue の内容】
{{ISSUE_CONTENT}}

【参照ドキュメント】
- docs/（プロジェクトのアーキテクチャ・認証認可ドキュメントがあれば記載）

【調査観点】

1. 認証・認可
   - 新しいエンドポイント/画面に必要な権限レベル
   - 権限チェックの適用方針
   - {{AUTH_LIBRARY}} との連携方針

2. 入力バリデーション
   - ユーザー入力のバリデーション要件
   - API エンドポイントの入力スキーマ
   - ファイルアップロードの制約（該当する場合）

3. データ保護
   - 機密データの暗号化要件
   - 個人情報の取り扱い
   - ログ出力時のマスキング要件

4. 外部連携セキュリティ
   - 外部 API 呼び出しの認証方式
   - CORS 設定
   - Rate Limiting の要否

5. STRIDE 脅威モデリング
   - Spoofing / Tampering / Repudiation / Information Disclosure / Denial of Service / Elevation of Privilege
   - 変更対象コンポーネントに対して該当する脅威を洗い出す

6. 受け入れ条件への追加
   - セキュリティテストとして含めるべき項目

【結果の JSON 形式】
{
  "role": "security_reviewer",
  "requirements": [
    {
      "category": "auth | validation | data_protection | external_api | rate_limiting",
      "description": "セキュリティ要件の説明",
      "priority": "must | should | nice_to_have",
      "implementation_note": "実装時の注意点"
    }
  ],
  "stride_analysis": [
    {
      "threat_type": "Spoofing | Tampering | Repudiation | InformationDisclosure | DoS | ElevationOfPrivilege",
      "component": "対象コンポーネント",
      "threat": "具体的な脅威の説明",
      "mitigation": "緩和策"
    }
  ],
  "acceptance_criteria": [
    "セキュリティ受け入れ条件として追加すべき項目"
  ],
  "risks": [
    {
      "description": "セキュリティリスクの説明",
      "severity": "critical | high | medium | low",
      "mitigation": "リスク軽減策"
    }
  ]
}
```

---

#### 3-5. ui-designer

**Task tool パラメータ:**

```
subagent_type: "devflow:ui-designer"
team_name: "resolve-issue"
name: "ui-designer"
description: "UI・コンポーネント設計"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
あなたは ui-designer 専門エージェントとして、{{UI_LIBRARY}} + {{CSS_FRAMEWORK}} ベースの
コンポーネント設計を行います。
UI/画面に関連しない場合は「対象外」と report.md に記載して完了してください。
```

**instruct.md の内容** (`.cache/r-i-t/{{TASK_SLUG}}/ui-designer/instruct.md`):

```
【Issue の内容】
{{ISSUE_CONTENT}}

UI/画面に関連しない場合は「対象外」と報告して完了してください。

【調査手順】
1. 既存コンポーネントの確認
   - コードベース解析ツールで UI コンポーネントディレクトリを調査
   - 既存コンポーネント一覧を取得
   - 既存 Storybook ストーリー等（該当する場合）を確認

2. デザインシステムの確認
   - プロジェクトのデザインガイドライン（docs/ など）を参照
   - {{CSS_FRAMEWORK}} のユーティリティクラスの活用方針

【調査観点】

1. 既存コンポーネントの流用
   - {{UI_LIBRARY}} ベースの既存コンポーネントで要件を満たせるか
   - 共有コンポーネントディレクトリに再利用可能なコンポーネントがあるか
   - 既存コンポーネントの拡張で対応できるか

2. 新規コンポーネントの必要性
   - 新たに作成が必要なコンポーネント
   - 既存コンポーネントの修正が必要な箇所
   - Storybook 等のストーリー追加が必要なコンポーネント（該当する場合）

3. 画面設計
   - 画面レイアウト（既存レイアウトパターンとの整合性）
   - レスポンシブ対応の要否
   - アクセシビリティ考慮事項
     - キーボードナビゲーション
     - スクリーンリーダー対応
     - カラーコントラスト
     - フォーカス管理

【結果の JSON 形式】
{
  "role": "ui_designer",
  "applicable": true | false,
  "existing_components": [
    {
      "name": "コンポーネント名",
      "path": "ファイルパス",
      "usage": "流用方法",
      "modification_needed": true | false,
      "modification_detail": "修正内容（該当する場合）"
    }
  ],
  "new_components": [
    {
      "name": "コンポーネント名",
      "purpose": "用途",
      "props": ["主要な props"],
      "based_on": "ベースとなる UI コンポーネント（ある場合）",
      "needs_story": true
    }
  ],
  "screen_design": {
    "layout": "レイアウト方針",
    "responsive": true | false,
    "accessibility_notes": ["アクセシビリティ考慮事項"]
  }
}
```

---

#### 3-6. unit-test-planner

**Task tool パラメータ:**

```
subagent_type: "devflow:unit-test-planner"
team_name: "resolve-issue"
name: "unit-test-planner"
description: "単体テスト設計"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
あなたは unit-test-planner（単体テスト設計の専門 agent）として、{{UNIT_TEST_FRAMEWORK}} の単体テストを設計します。
```

**instruct.md の内容** (`.cache/r-i-t/{{TASK_SLUG}}/unit-test-planner/instruct.md`):

```
【Issue の内容】
{{ISSUE_CONTENT}}

【参照ドキュメント】
- プロジェクトのテストガイドライン（docs/ 配下など）

【調査手順】
1. コードベース解析ツールで既存テストの構造を確認
   - 関連するテストファイルを特定
   - 既存テストファイルのテストケース構造を把握
   - 関連する Service 層やユーティリティのテストを確認

2. 以下の観点で設計:

   a) 既存テストへの影響
      - 変更により破壊されるテストの特定
      - テストデータ（モック/フィクスチャ）の更新要否
      - 既存テストヘルパーの再利用可否

   b) 新規テストケースの設計
      - Service 層 / ユーティリティ関数の単体テスト
      - コンポーネントのレンダリングテスト（該当する場合）
      - エッジケース・エラーハンドリングのテスト
      - DB 操作を含む場合のモック戦略

   c) テストカバレッジ方針
      - 正常系・異常系のカバレッジ
      - 境界値テスト
      - 認証・認可のテスト（該当する場合）

【結果の JSON 形式】
{
  "role": "unit_test_planner",
  "affected_tests": [
    {
      "path": "テストファイルパス",
      "impact": "破壊される | 修正が必要 | 影響なし",
      "description": "影響内容"
    }
  ],
  "new_test_cases": [
    {
      "file_path": "新規/既存テストファイルパス",
      "describe": "テストスイート名",
      "cases": [
        {
          "name": "テストケース名",
          "type": "normal | error | edge_case | auth",
          "description": "テスト内容",
          "mock_needed": ["モックが必要な依存"]
        }
      ]
    }
  ],
  "test_helpers": {
    "reusable": ["再利用可能な既存ヘルパー"],
    "new_needed": ["新規に作成が必要なヘルパー"]
  },
  "acceptance_criteria": [
    "単体テストの受け入れ条件"
  ]
}
```

---

#### 3-7. e2e-test-planner

**Task tool パラメータ:**

```
subagent_type: "devflow:e2e-test-planner"
team_name: "resolve-issue"
name: "e2e-test-planner"
description: "E2E テスト設計"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
あなたは e2e-test-planner（E2E テスト設計の専門 agent）として、{{E2E_TEST_FRAMEWORK}} の E2E テストを設計します。
```

**instruct.md の内容** (`.cache/r-i-t/{{TASK_SLUG}}/e2e-test-planner/instruct.md`):

```
【Issue の内容】
{{ISSUE_CONTENT}}

【参照ドキュメント】
- プロジェクトの E2E テストガイドライン（docs/ 配下など）

【調査手順】
1. コードベース解析ツールで既存 E2E テストの構造を確認
   - 関連するテストファイルを特定
   - 既存テストシナリオの構造を把握
   - 既存の Page Object / テストヘルパーを確認

2. 以下の観点で設計:

   a) 既存 E2E テストへの影響
      - 変更により破壊されるシナリオの特定
      - テストデータのセットアップ変更要否
      - 既存の Page Object の修正要否

   b) 新規 E2E シナリオの設計
      - ユーザーフロー（画面遷移、操作手順）
      - 正常系フロー（主要なハッピーパス）
      - 異常系フロー（バリデーションエラー、権限エラー）
      - 各ロールでの動作確認（該当する場合）

   c) ブラウザ拡張機能等の手動確認（該当する場合）
      - 自動テストが行えない箇所の手動確認項目リストアップ

【結果の JSON 形式】
{
  "role": "e2e_test_planner",
  "affected_tests": [
    {
      "path": "テストファイルパス",
      "impact": "破壊される | 修正が必要 | 影響なし",
      "description": "影響内容"
    }
  ],
  "new_scenarios": [
    {
      "file_path": "新規/既存テストファイルパス",
      "scenario": "シナリオ名",
      "user_flow": [
        "ステップ 1: ...",
        "ステップ 2: ..."
      ],
      "type": "happy_path | error | permission",
      "roles": ["テスト対象のロール"],
      "assertions": ["確認すべきアサーション"]
    }
  ],
  "page_objects": {
    "reusable": ["再利用可能な既存 Page Object"],
    "new_needed": ["新規に作成が必要な Page Object"],
    "modifications": ["修正が必要な既存 Page Object"]
  },
  "manual_checks": [
    {
      "description": "手動確認項目",
      "steps": ["確認手順"],
      "expected": "期待される動作"
    }
  ],
  "acceptance_criteria": [
    "E2E テストの受け入れ条件"
  ]
}
```

---

### Step 4: Phase 1 結果の収集

Phase 1 の Teammate からの SendMessage を待ち受けてください。
各 Teammate は調査完了後、`report.md` に結果を保存し、チームリーダーに「調査完了」と通知します。

- Teammate がエラーで失敗した場合は、その旨を記録し、残りの結果で継続
- 全 Phase 1 タスクの完了を TaskList で確認
- **Teammate から「質問があります」と通知が来た場合**: 該当 Teammate の `questions.md` を Read し、AskUserQuestion でユーザーに確認し、`answers.md` に Write 後、SendMessage で Teammate に「回答しました」と通知する

---

### Step 5: Phase 2 ─ 実装プラン統合

Phase 1 の全タスクが completed になったら、`plan-integrator` の `instruct.md` を作成し起動します。

#### Step 5-0: Task tool パラメータ

```
subagent_type: "devflow:plan-integrator"
team_name: "resolve-issue"
name: "plan-integrator"
description: "実装プラン統合"
```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```
あなたは plan-integrator（調査結果統合の専門 agent）として、Phase 1 の 7 つの調査結果を統合した
最終実装プランを作成します。あなたの強みはコードベース解析から構造化技術ドキュメントを生成することです。

【重要】実装プランには必ず Mermaid 図（シーケンス図・コンポーネント図・データフロー図）を含めて、
視覚的に理解できる形にしてください。
```

#### Step 5-1: instruct.md の内容

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/plan-integrator/instruct.md`

```
Phase 1 の 7 つの Teammate が行った調査結果を統合し、
具体的な実装プランを作成してください。
コードには手を加えないでください。

【Issue の内容】
{{ISSUE_CONTENT}}

【Phase 1 の調査結果ファイル】
以下のファイルを Read ツールで読み込んでください:
- .cache/r-i-t/{{TASK_SLUG}}/architecture-planner/report.md   # アーキテクチャ + インフラ要否・IaC 設計
- .cache/r-i-t/{{TASK_SLUG}}/existing-code-reviewer/report.md
- .cache/r-i-t/{{TASK_SLUG}}/library-researcher/report.md
- .cache/r-i-t/{{TASK_SLUG}}/security-reviewer/report.md
- .cache/r-i-t/{{TASK_SLUG}}/ui-designer/report.md
- .cache/r-i-t/{{TASK_SLUG}}/unit-test-planner/report.md
- .cache/r-i-t/{{TASK_SLUG}}/e2e-test-planner/report.md

【実装プランの構成】
以下の構成で実装プランをマークダウン形式で作成してください:

## 実装概要
Issue の要件を一言で要約。

## アーキテクチャ決定記録（ADR）
主要な技術的決定について「Context（背景）→ Decision（決定）→ Consequences（影響）」の構造で記述してください。
主要な決定が複数ある場合は、ADR-1, ADR-2, ... と連番を振ってください。

## 実装アーキテクチャ
architecture-planner の設計を反映。変更/追加するファイル一覧を含む。

### アーキテクチャ図（Mermaid）
以下のいずれか（または複数）の Mermaid 図を必ず含めてください:
- **コンポーネント図**: 新規/既存コンポーネントの関係
- **シーケンス図**: ユーザー操作 → API → DB のフロー
- **データフロー図**: データの変換・保存パイプライン
- **ER 図**: DB スキーマ変更がある場合

例:
```mermaid
sequenceDiagram
    User->>Frontend: クリック
    Frontend->>API: POST /api/foo
    API->>Service: foo.create()
    Service->>DB: INSERT
    DB-->>Service: OK
    Service-->>API: Created
    API-->>Frontend: 201
    Frontend-->>User: 成功表示
````

## 既存コード活用

existing-code-reviewer の reusable_code を反映。再利用する関数/コンポーネントを明記。

## ライブラリ活用

library-researcher の推奨を反映。

## インフラ変更（該当する場合）

architecture-planner の `infra`（インフラ要否・IaC 設計）の結果を反映。

## セキュリティ考慮事項

security-reviewer の requirements と stride_analysis を反映。
STRIDE 脅威モデリングの結果を必ず含めてください。

## UI・コンポーネント（該当する場合）

ui-designer の設計を反映。使用するコンポーネントを明記。アクセシビリティ考慮事項も含める。

## 単体テスト計画

unit-test-planner の new_test_cases を反映。テストケース名・対象・モック戦略を含める。

## E2E テスト計画

e2e-test-planner の new_scenarios を反映。ユーザーフロー・アサーションを含める。

## 手動確認項目（該当する場合）

e2e-test-planner の manual_checks 等を反映。

## 実装手順

具体的な実装順序をステップバイステップで記載。
コーディングエージェントがこの手順に従って実装できるレベルの詳細度。

## リスク・懸念事項

全 Teammate のリスク指摘を統合。

## トレードオフ・代替案

ADR 構造の一部として、検討したが採用しなかった代替案と、その却下理由を記載。

【統合時の注意事項】

- Teammate 間で矛盾がある場合は、両方の見解を併記し「要確認」と明記
- DB 変更がある場合は後方互換性について明記
- リスク・懸念事項はまとめて記載
- 実装手順は依存関係を考慮した順序にすること
- Mermaid 図は必ず含めること（視認性向上のため）

```

#### Step 5-2: plan-integrator 起動

起動プロンプトは共通テンプレ + 「Step 5-0 の ROLE_SPECIFIC_INSTRUCTIONS」を使用してください。
`{{TEAMMATE_NAME}}` = `plan-integrator`、`{{TASK_SUBJECT}}` = "実装プラン統合"。

**補足**: plan-integrator は Phase 1 の report.md をすべて Read してから統合する必要があるため、
共通テンプレの【結果の保存】部分を以下に差し替えてください:

```

【結果の保存】
統合完了後:

1. 実装プラン（マークダウン形式 + Mermaid 図）を `.cache/r-i-t/{{TASK_SLUG}}/plan-integrator/report.md` に Write
2. SendMessage でチームリーダーに「統合完了」と通知
3. TaskUpdate でタスクを completed にする

```

---

### Step 6: Phase 3 ─ 実装プランレビュー

`plan-integrator` の結果を受け取ったら、`issue-reviewer` の `instruct.md` を作成し起動します。

#### Step 6-0: Task tool パラメータ

```

subagent_type: "devflow:issue-reviewer"
team_name: "resolve-issue"
name: "issue-reviewer"
description: "実装プランレビュー"

```

**起動プロンプトの `{{ROLE_SPECIFIC_INSTRUCTIONS}}` に追加する内容:**

```

あなたは issue-reviewer（プロジェクト専用のレビュー agent）として、今回は **plan-integrator が作成した実装プラン** を
レビュー対象とします（Issue ドラフトではなく実装プランをレビューする点に注意）。
Clean Architecture / DDD / SOLID 観点と、受け入れ条件・実装方針の具体性・技術的正確性を、
別コンテキストから独立した視点で検証してください。

利用可能な MCP を積極的に活用して:

- プラン内で言及されているライブラリ API の正確性を確認
- プラン内で言及されているファイルパス・シンボルの実在確認

```

#### Step 6-1: instruct.md の内容

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/issue-reviewer/instruct.md`

```

plan-integrator が作成した実装プランをレビューし、改善案を出してください。
コードには手を加えないでください。read only で調査のみを行ってください。

【Issue の内容】
{{ISSUE_CONTENT}}

【レビュー対象】
以下のファイルを Read ツールで読み込んでください:

- .cache/r-i-t/{{TASK_SLUG}}/plan-integrator/report.md

【レビュー手順】

1. 技術要素の正確性を検証:
   - 利用可能な MCP でプラン内で言及されているライブラリ・フレームワークの API や使用方法が正確かを確認
   - コードベース解析ツールでプラン内で言及されているファイルパスやシンボルが実在するか確認

2. 以下の観点でレビュー:
   a) 実装漏れ — Issue の要件がすべてカバーされているか
   b) 実装方針の具体性 — コーディングエージェントが作業できるレベルの詳細度か
   c) テスト計画の十分性 — 単体テスト・E2E テストの計画が漏れなくカバーしているか
   d) 矛盾・不整合 — Phase 1 の各 Teammate の指摘内容間に矛盾がないか
   e) ベストプラクティス — MCP で技術スタックのベストプラクティスに沿っているか
   f) アーキ整合性 — Clean Architecture / DDD / SOLID 観点でレイヤー境界が適切か
   g) Mermaid 図の妥当性 — 図がプランの本文と整合しているか

【結果の JSON 形式】
{
"role": "plan_reviewer",
"corrections": [
{
"section": "対象セクション",
"issue": "問題点",
"suggestion": "修正案",
"severity": "must_fix | should_fix | nice_to_have"
}
],
"missing_items": [
{
"description": "漏れている項目",
"suggestion": "追加すべき内容"
}
],
"technical_verification": [
{
"claim": "プラン内の技術的記述",
"verified": true | false,
"note": "検証結果の補足"
}
],
"architectural_assessment": {
"layer_boundaries": "レイヤー境界の適切性",
"solid_compliance": "SOLID 原則の遵守状況",
"ddd_alignment": "DDD 観点での評価"
},
"overall_assessment": "全体的な評価コメント"
}

```

#### Step 6-2: issue-reviewer 起動

起動プロンプトは共通テンプレ + 「Step 6-0 の ROLE_SPECIFIC_INSTRUCTIONS」を使用してください。
`{{TEAMMATE_NAME}}` = `issue-reviewer`、`{{TASK_SUBJECT}}` = "実装プランレビュー"。

`issue-reviewer` のレビュー結果（`.cache/r-i-t/{{TASK_SLUG}}/issue-reviewer/report.md`）に基づき、
チームリーダーが実装プランに必要な修正を加えてください。

---

### Step 7: ユーザー確認

#### Step 7-0: ユーザー向け HTML 最終レポートの生成

`plan-integrator` と `issue-reviewer` の MD レポート 2 つから、
ユーザー向け HTML 最終レポート `.cache/r-i-t/{{TASK_SLUG}}/final-report.html` を生成します。

**Step 7-0-a: 2 つの MD を 1 つに統合**

HTML 生成ツールは 1 つの MD ソースのみ受け取る場合があるため、まず統合 MD を作成:

```bash
mkdir -p ".cache/r-i-t/{{TASK_SLUG}}"
{
  echo "# Issue 実装プラン"
  echo
  echo "## plan-integrator の実装プラン"
  echo
  cat ".cache/r-i-t/{{TASK_SLUG}}/plan-integrator/report.md"
  echo
  echo "## issue-reviewer のレビュー結果と対応"
  echo
  cat ".cache/r-i-t/{{TASK_SLUG}}/issue-reviewer/report.md"
} > ".cache/r-i-t/{{TASK_SLUG}}/final-report.md"
```

**Step 7-0-b: HTML 生成を試みる（外部スクリプトがあれば委譲、なければリーダーが直接生成）**

外部スクリプトが利用できる場合:

```bash
{{REPORT_GENERATOR}} \
  --source-md   ".cache/r-i-t/{{TASK_SLUG}}/final-report.md" \
  --output-html ".cache/r-i-t/{{TASK_SLUG}}/final-report.html" \
  --title       "Issue 実装プラン - {{TASK_SLUG}}" \
  --context     "Issue: #{issue_number} / ブランチ: {branch}"
```

スクリプトが利用できない場合、リーダーが直接 HTML を生成する（フォールバック）:

1. プロジェクトの HTML テンプレートがあれば Read（なければ基本的な構造で生成）
2. Mermaid 図は `<pre><code class="language-mermaid">{Mermaid ソース}</code></pre>` として原文を保持
3. 実装手順は番号付きリスト `<ol>`
4. ファイルパス・関数名は `<code>`
5. レビュー指摘の severity は `<span class="badge badge-{high|medium|low}">`
6. リスク・後方互換性の重要事項は `<div class="callout callout-warn">`
7. HTML 特殊文字（`<`, `>`, `&`, `"`, `'`）は必ずエスケープ

#### Step 7-1: ユーザーへの提示

修正済みの実装プランをユーザーに提示し、以下を確認：

1. **実装方針は正しいか**
2. **テスト計画は十分か**
3. **DB 変更がある場合、後方互換性の方針は正しいか**
4. **Mermaid 図がプランの意図を正しく表現しているか**
5. **修正すべき点がないか**
6. **Issue の更新が必要か**（実装プランの内容を Issue に反映する場合）

提示時には **HTML 最終レポートへのリンクを必ず Markdown 形式で含める**:

```
🔗 詳細プラン: [Issue 実装プランを開く](vscode://file/${CLAUDE_PROJECT_DIR}/.cache/r-i-t/{{TASK_SLUG}}/final-report.html)
（クリックで VS Code エディタに開きます。右上の「Show Preview」ボタンで Live Preview レンダリング表示）
```

ユーザーのフィードバックに基づき、必要な修正を加えてください（その際は `final-report.html` も再生成すること）。
Issue の更新はユーザーに Before/After を提示して確認を取ってから行ってください。

### Step 8: 実装

ユーザーの承認後、チームリーダーが実装プランに従って実装を行います。

1. `.cache/r-i-t/{{TASK_SLUG}}/plan-integrator/report.md` の「実装手順」に従い、ステップバイステップで実装
2. 必要に応じて {{UNIT_TEST_FRAMEWORK}}、{{E2E_TEST_FRAMEWORK}} のテストも更新・追加
3. ブラウザ拡張機能等の自動テストが行えない対象については PR の説明に手動確認項目を列挙

ISSUE によっては対応範囲や記述の内容が膨大になることがあるが、コードベース解析ツールの機能を適切に用いてタスクをきちんと組み立てて対応を行うこと。

**対応までに留め、Push や Commit は明示的にユーザから指示がない限り行わないでください。**

### Step 9: チーム解散

実装が完了したら、各 Teammate に `SendMessage` の `shutdown_request` を送信し、
全員がシャットダウンした後 `TeamDelete` でチームを解散してください。

---

## 注意事項

- いずれかの Teammate がエラーになった場合は、残りの Teammate の結果で調査を継続
- Phase 2, 3 は前の Phase の結果に依存するため、必ず順次実行すること
- Teammate からのメッセージは自動配信されるため、手動でのポーリングは不要
- Teammate が idle になるのは正常な動作（メッセージ送信後の待機状態）
- DB の変更を伴う場合は後方互換性を必ず確認し、ユーザーに判断を仰ぐ
- Issue の内容が不十分な場合は Phase 1 開始前にユーザーに質問する
- **Push や Commit は明示的にユーザから指示がない限り行わないこと**
- **Teammate への指示は instruct.md 経由で行い、起動プロンプトにはインライン指示を含めないこと**
- **Teammate の結果は report.md 経由で受け取り、SendMessage にはインラインデータを含めないこと**
- **Phase 1 の Teammate を全て起動した直後に `/compact` を1回実行すること（通知受信前に圧縮する）**
- **共通テンプレを重複して書き出さない**: 各 Teammate の起動プロンプトは本ファイル「起動プロンプト共通テンプレ」節を参照して生成すること
- **専門エージェントの強みを活かす**: 各 Teammate はプロジェクト専用のローカル agent（`agents/`）を使用しているため、instruct.md に具体的な調査観点を含めることで領域知識を最大限活用すること
