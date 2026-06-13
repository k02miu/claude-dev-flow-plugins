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

Agent Teams を使い、**プロジェクト専用のローカルエージェント**（`agents/<name>`）を各役割に割り当てた Teammate（最大 8、起動対象は Issue 種別で変動）を並列起動し、GitHub Issue の実装プランを多角的に調査・設計し、承認後に実装を行います。
あなた（Claude Code）がチームリーダーとして、タスクの作成・割り当て・結果の統合・実装を行います。

**フル版の特徴:**

- 専門 Teammate が並列に調査（アーキテクチャ＋インフラ、既存コード、ライブラリ、セキュリティ、UI、テスト〔単体 + E2E〕）。起動対象は Issue 種別で変動
- 各 Teammate はプロジェクトの文脈を内蔵したローカル専用エージェント（`agents/`）
- Phase 2 で全結果を統合し実装プラン（Mermaid 図付き）を自動生成
- Phase 3 で別コンテキストから実装プランをレビュー（MCP で技術的正確性を検証）
- 承認後にチームリーダーが実装を実行

---

## チーム構成（最大 8 Teammate・起動対象は種別で変動）

| Teammate 名              | subagent_type            | Phase | 役割                                                      |
| ------------------------ | ------------------------ | ----- | --------------------------------------------------------- |
| `architecture-planner`   | `architecture-planner`   | 1     | 実装アーキテクチャ、ファイル構成、データフロー設計、**インフラ要否・IaC（{{IAC_TOOL}}/{{CLOUD_PROVIDER}}）設計** |
| `existing-code-reviewer` | `existing-code-reviewer` | 1     | 既存実装との兼ね合い、再利用可能コード、後方互換性        |
| `library-researcher`     | `library-researcher`     | 1     | 既存ライブラリ調査、車輪の再発明防止                      |
| `security-reviewer`      | `security-reviewer`      | 1     | 認証認可・入力検証・データ保護の設計考慮                  |
| `ui-designer`            | `ui-designer`            | 1     | コンポーネント設計、UI 設計、画面設計                     |
| `test-planner`           | `test-planner`           | 1     | 単体テスト + E2E テスト設計（scope で範囲指定）           |
| `plan-integrator`        | `plan-integrator`        | 2     | Phase 1 全結果を統合し実装プラン（Mermaid 図付き）を作成  |
| `issue-reviewer`         | `issue-reviewer`         | 3     | 実装プランのレビュー・改善案の提示                        |

> インフラ変更の要否・インフラ設計は `architecture-planner` が兼任する（専用の infra-reviewer Teammate は廃止）。

### Phase の依存関係

```
Phase 1（並列・起動対象のみ）─┬─ architecture-planner     [Task 1]
                ├─ existing-code-reviewer   [Task 2]
                ├─ library-researcher       [Task 3]
                ├─ security-reviewer        [Task 4]
                ├─ ui-designer              [Task 5]
                └─ test-planner             [Task 6]
        ↓
リーダー: /compact 実行（instruct.md 書き出し・起動呼び出し分を圧縮）
        ↓
Phase 1 Teammate からの通知を待ち受け
        ↓
Phase 2（順次）── plan-integrator            [Task 7] blockedBy: 起動した Phase 1 タスク
        ↓
Phase 3（順次）── issue-reviewer             [Task 8] blockedBy: [7]
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
    ├── test-planner/
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
| バックエンド   | API、DB、Service 層の変更            | 1,2,3,4,6 (ui: 不要)        |
| フロントエンド | 画面、コンポーネント、状態管理の変更 | 1,2,3,4,5,6              |
| フルスタック   | 上記両方                             | 全 Teammate                 |
| インフラ       | {{IAC_TOOL}}、{{CLOUD_PROVIDER}}、CI/CD の変更         | 1,2,4,6 (ui: 不要。infra は architecture-planner が兼任) |

**判定で起動対象とした Teammate のみ起動**してください（不要な観点はタスク・instruct.md も作成しない）。判断に迷う観点は安全側で起動します。インフラ要否・IaC 設計は `architecture-planner`（Task 1）が兼任します。

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
Step 1-4 で起動対象とした Teammate のタスクのみ作成してください（番号は下表に従う。起動しない観点は欠番でよい）。plan-integrator（Task 7）の blockedBy は実際に作成した Phase 1 タスクを指定します。

**Phase 1 タスク（並列、依存なし）:**

| Task | subject                | activeForm                           |
| ---- | ---------------------- | ------------------------------------ |
| 1    | アーキテクチャ設計     | アーキテクチャ・インフラを設計中     |
| 2    | 既存コード調査         | 既存コードとの兼ね合いを調査中       |
| 3    | ライブラリ調査         | 活用可能なライブラリを調査中         |
| 4    | セキュリティ調査       | セキュリティ要件を調査中             |
| 5    | UI・コンポーネント設計 | UI・コンポーネントを設計中           |
| 6    | テスト設計             | テスト（単体 + E2E）を設計中         |

**Phase 2 タスク（Phase 1 完了後）:**

| Task | subject        | activeForm         | blockedBy       |
| ---- | -------------- | ------------------ | --------------- |
| 7    | 実装プラン統合 | 実装プランを統合中 | 起動した Phase 1 タスク |

**Phase 3 タスク（Phase 2 完了後）:**

| Task | subject            | activeForm             | blockedBy |
| ---- | ------------------ | ---------------------- | --------- |
| 8    | 実装プランレビュー | 実装プランをレビュー中 | [7]       |

---

## 起動プロンプト共通テンプレ

各 Teammate 共通の起動プロンプトテンプレートは `${CLAUDE_SKILL_DIR}/references/teammate-launch-prompt.md` に分離してあります。
Teammate 起動時にこのファイルを Read し、`{{TEAMMATE_NAME}}` `{{TASK_SUBJECT}}` `{{TASK_SLUG}}` を置換して使用してください。
`{{ROLE_SPECIFIC_INSTRUCTIONS}}` には、各 Teammate に対応する `${CLAUDE_SKILL_DIR}/references/instructs/<role>.md` の
「起動プロンプト追加指示」節の内容を挿入します。

---

### Step 3: Phase 1 ─ Teammate 起動と並列調査

#### Step 3-0: 指示ファイルの準備

Phase 1 の Teammate を起動する **前に**、リーダーが各 Teammate の `instruct.md` を作成してください。
Step 1-4 で決定した各ロールについて:

1. `${CLAUDE_SKILL_DIR}/references/instructs/<role>.md` を Read する
2. 「instruct.md テンプレート」節の内容を取り出し、`{{ISSUE_CONTENT}}` を Issue の実際の内容に、`{{TASK_SLUG}}` 等の変数を実際の値に置換する
3. `.cache/r-i-t/{{TASK_SLUG}}/<role>/instruct.md` に Write する（test-planner の場合は `scope`〔unit / e2e / both〕を Issue 種別に応じて指定。UI・画面変更を含むなら both、バックエンド/インフラ中心なら unit を目安）

#### Step 3-1: Teammate の並列起動

**Step 1-4 で起動対象とした Phase 1 Teammate を Task tool で並列起動してください（1 メッセージで複数の Task 呼び出し。最大 6、種別により 3〜6 体）。**
各 Teammate の Task tool パラメータは全ロール共通形式です:

```
subagent_type: "devflow:<role>"   ← チーム構成表の subagent_type に devflow: を付与
team_name: "resolve-issue"
name: "<role>"
description: "<下表の説明>"
```

| role | description |
| ---- | ----------- |
| `architecture-planner` | アーキテクチャ・インフラ設計 |
| `existing-code-reviewer` | 既存コード調査 |
| `library-researcher` | ライブラリ調査 |
| `security-reviewer` | セキュリティ調査 |
| `ui-designer` | UI・コンポーネント設計 |
| `test-planner` | テスト設計（単体 + E2E、scope 指定） |

起動プロンプトは「起動プロンプト共通テンプレ」（`${CLAUDE_SKILL_DIR}/references/teammate-launch-prompt.md`）の
`{{ROLE_SPECIFIC_INSTRUCTIONS}}` に、各ロールの `references/instructs/<role>.md` の「起動プロンプト追加指示」を挿入して生成します。

いずれかの Teammate がエラーになった場合は、残りの Teammate の結果で調査を継続してください。

**重要: Teammate を全て起動したら、通知の待ち受けを開始する前に `/compact` を実行してください。**
instruct.md の書き出しと Task tool の起動呼び出し（起動対象のぶん）でコンテキストが大きく膨らんでいるため、
Teammate からの通知を受け取る前に圧縮しないと、通知受信中にコンテキストサイズを超過するリスクがあります。

**質問対応**: Teammate から SendMessage で「質問があります」と通知が来た場合:

1. `.cache/r-i-t/{{TASK_SLUG}}/{teammate-name}/questions.md` を Read
2. AskUserQuestion でユーザーに確認する
3. 回答を `.cache/r-i-t/{{TASK_SLUG}}/{teammate-name}/answers.md` に Write
4. SendMessage で Teammate に「回答しました」と通知

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

#### Step 5-1: instruct.md の作成

`${CLAUDE_SKILL_DIR}/references/instructs/plan-integrator.md` を Read し、「instruct.md テンプレート」節の内容の
`{{ISSUE_CONTENT}}` `{{TASK_SLUG}}` 等を置換して `.cache/r-i-t/{{TASK_SLUG}}/plan-integrator/instruct.md` に Write してください。

#### Step 5-2: plan-integrator 起動

起動プロンプトは共通テンプレ + `references/instructs/plan-integrator.md` の「起動プロンプト追加指示」を使用してください。
`{{TEAMMATE_NAME}}` = `plan-integrator`、`{{TASK_SUBJECT}}` = "実装プラン統合"。

**補足**: plan-integrator は Phase 1 の report.md をすべて Read してから統合する必要があるため、
共通テンプレの【結果の保存】部分を `references/instructs/plan-integrator.md` の「【結果の保存】差し替え」節の内容に差し替えてください。

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

#### Step 6-1: instruct.md の作成

`${CLAUDE_SKILL_DIR}/references/instructs/issue-reviewer.md` を Read し、「instruct.md テンプレート」節の内容の
`{{ISSUE_CONTENT}}` `{{TASK_SLUG}}` 等を置換して `.cache/r-i-t/{{TASK_SLUG}}/issue-reviewer/instruct.md` に Write してください。

#### Step 6-2: issue-reviewer 起動

起動プロンプトは共通テンプレ + `references/instructs/issue-reviewer.md` の「起動プロンプト追加指示」を使用してください。
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
- **Phase 1 の Teammate を起動した直後に `/compact` を1回実行すること（通知受信前に圧縮する）**
- **共通テンプレを重複して書き出さない**: 各 Teammate の起動プロンプトは `${CLAUDE_SKILL_DIR}/references/teammate-launch-prompt.md` を参照して生成すること
- **専門エージェントの強みを活かす**: 各 Teammate はプロジェクト専用のローカル agent（`agents/`）を使用しているため、instruct.md に具体的な調査観点を含めることで領域知識を最大限活用すること
