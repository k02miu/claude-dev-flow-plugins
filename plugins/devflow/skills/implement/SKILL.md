---
name: implement
description: "MUST USE: 実装フェーズに入る際、以下の条件に1つでも該当すれば必ずこのスキルを起動すること。(1) 複数ファイルにまたがる新機能の実装 (2) フロントエンドとバックエンドの両方に変更が必要 (3) DB スキーマ変更を伴う (4) インフラ変更を伴う (5) 中〜大規模の実装タスク。特にプランモード（EnterPlanMode/ExitPlanMode）から実装に移行する際は、上記条件に該当すれば必ず起動すること。単一ファイルの小規模修正やバグフィックスでは不要。"
---

# Implementation Team Skill

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


Agent Teams でフルスタック実装者チームを編成し、並列に実装を行います。
リーダー（アーキテクチャ兼フルスタックシニアエンジニア = メインエージェント）が設計・調整を行い、実装者は `implementer`（`{{AGENT_CONFIG_DIR}}/agents/implementer.md`）1 定義に集約されており、リーダーが feature / package 単位で **非重複の owner zone** を各 implementer に割り当てて並列起動します。FE / BE / インフラ / テストを各 implementer が自 zone で一括担当します（専用 QA エージェントは廃止し、各 implementer が自 zone のテストを書く）。

実装指示: $ARGUMENTS

**commit & push はユーザーが明示的に指示しない限り絶対に行わないでください。**

---

## 変数定義

本 SKILL.md では以下の {{VARIABLE}} を使用します。実際のプロジェクトの値に置き換えて使用してください。

| 変数 | 説明 | デフォルト例 |
|------|------|-------------|
| `{{PLUGIN_NAME}}` | プラグイン名 | `devflow` |
| `{{PACKAGE_MANAGER}}` | パッケージマネージャ | `pnpm` |
| `{{MONOREPO_TOOL}}` | モノレポツール | `turborepo` |
| `{{MONOREPO_FILTER_FLAG}}` | モノレポフィルタフラグ | `--filter` |
| `{{FRONTEND_FRAMEWORK}}` | フロントエンドフレームワーク | `next.js` |
| `{{ORM}}` | ORM | `prisma` |
| `{{IAC_TOOL}}` | IaC ツール | `terraform` |
| `{{CLOUD_PROVIDER}}` | クラウドプロバイダ | `gcp` |
| `{{CLOUD_SERVICES}}` | クラウドサービス一覧 | `Cloud Run, Cloud SQL, Cloud Tasks` |
| `{{CSS_FRAMEWORK}}` | CSS フレームワーク | `tailwind css` |
| `{{UI_LIBRARY}}` | UI ライブラリ | `shadcn/ui` |
| `{{UNIT_TEST_FRAMEWORK}}` | 単体テストフレームワーク | `vitest` |
| `{{E2E_TEST_FRAMEWORK}}` | E2E テストフレームワーク | `playwright` |
| `{{LINTER}}` | リンター | `biome` |
| `{{CODE_INTELLIGENCE_TOOL}}` | コードインテリジェンスツール | `serena mcp` |
| `{{AUTH_UTILITIES}}` | 認証認可ユーティリティ | `requirePermissions, PermissionGate` |
| `{{CLOUD_MCP}}` | クラウド MCP | `google-developer-knowledge mcp, gcloud mcp` |
| `{{FRAMEWORK_DEVTOOLS}}` | フレームワーク開発ツール MCP | `next-devtools mcp` |
| `{{CACHE_DIR}}` | キャッシュディレクトリ | `.cache` |
| `{{AGENT_CONFIG_DIR}}` | エージェント設定ディレクトリ | `.claude` |
| `{{WORKSPACE_ROOT}}` | ワークスペースルート | `/workspace` |
| `{{DOCS_PATTERN}}` | ドキュメントディレクトリパターン | `docs/developments/` |
| `{{TYPE_CHECK_COMMAND}}` | 型チェックコマンド | `pnpm check-types` |
| `{{LINT_COMMAND}}` | リント・フォーマットコマンド | `pnpm biome:fix` |
| `{{TEST_COMMAND}}` | 単体テストコマンド | `pnpm test` |
| `{{E2E_TEST_COMMAND}}` | E2E テストコマンド | `pnpm test:e2e` |
| `{{DATABASE_PACKAGE}}` | DB パッケージ名 | `@repo/database` |
| `{{REVIEW_CHECKLIST_PATH}}` | レビューチェックリストのパス | `{{DOCS_PATTERN}}review-check-list.md` |
| `{{TEMPLATE_DIR}}` | テンプレートディレクトリ | `{{AGENT_CONFIG_DIR}}/templates` |
| `{{PR_REVIEWER_MODEL_NAMES}}` | PR レビュアーモデル名 | `GitHub Copilot / Claude / Codex / Gemini` |
| `{{IAC_PATH}}` | IaC ファイルのパス | `terraform/` |
| `{{IAC_EXT}}` | IaC ファイル拡張子 | `tf` |
| `{{IAC_VARS_EXT}}` | IaC 変数ファイル拡張子 | `tfvars` |
| `{{IAC_SKILL_PREFIX}}` | IaC スキルプレフィックス | `terraform` |
| `{{CLOUD_PACKAGE_PATH}}` | クラウドパッケージのパス | `packages/cloud/` |
| `{{FRONTEND_CONFIG_PATTERN}}` | フロントエンド設定ファイルパターン | `apps/web/next.config.*` |
| `{{FRONTEND_PATH}}` | フロントエンドディレクトリ | `apps/web` |
| `{{PACKAGES_PATH}}` | パッケージディレクトリ | `packages/` |

## チーム構成（専門エージェント割当）

| 役割 | Teammate 名 | `subagent_type` | `model` | 担当領域 |
|------|-------------|-----------------|---------|----------|
| リーダー | （メインエージェント） | — | (親継承) | 設計、タスク分割、owner zone 割当、調整、最終決定 |
| 実装者 ×N | `implementer-{zone}` | `implementer` | `sonnet` | 割り当てられた owner zone の FE / BE / インフラ実装 + 自 zone のテスト |

**モデル指定方針**: 実装 Teammate（implementer）は `model: "sonnet"` を Task tool 呼び出し時に**必ず指定**すること。リーダー（メインエージェント）と Phase 1/3 のレビュー agent は指定なし（親継承）。

**設計・レビュー用（Phase1, Phase3 で使用）:**

| 用途 | `subagent_type` | 起動フェーズ |
|------|-----------------|-------------|
| 設計レビュー（コード品質 + アーキテクチャ + API 契約を一体で） | `code-architecture-reviewer` | Phase 1-2.5 |
| セキュリティレビュー | `security-reviewer` | Phase 3-2 |
| コード品質・アーキ整合性レビュー（パフォーマンス含む） | `code-architecture-reviewer` | Phase 3-2 |

**{{PLUGIN_NAME}} の共通エージェント（`{{AGENT_CONFIG_DIR}}/agents/` 配下、任意使用）:**

よりプロジェクトの文脈（認証認可ロール、packages/* 構成、docs/ 参照慣習など）に沿ったレビューが必要な場合、以下のカスタムエージェントも使用可能。上記プラグイン版と併用しても良い。

| 用途 | `subagent_type` |
|------|-----------------|
| セキュリティ要件・妥当性評価（Mode A/B） | `security-reviewer` |
| アーキテクチャ設計・妥当性評価（Mode A/B） | `architecture-planner` |
| 既存コード整合性・再利用可否（Mode A/B） | `existing-code-reviewer` |
| UI・コンポーネント設計（Mode A/B） | `ui-designer` |
| ライブラリ調査 | `library-researcher` |
| インフラ・IaC 調査 | `infra-reviewer` |
| 単体テスト設計 | `unit-test-planner` |
| E2E テスト設計 | `e2e-test-planner` |

これらは `create-feature-issue` / `pr-review-respond` / `document-follow-up` と共通で使えるエージェント。File-based / Inline どちらの起動形式にも対応。

---

## 参照すべき外部 skill（プロセス知識ベース）

本 SKILL.md は「何をするか」のみを定義します。**「どうやるか」の詳細は以下の skill に委譲**してください。
各フェーズで必要になった時点で該当 skill を Skill ツールで参照すること。

| トピック | 参照先 skill |
|---------|--------------|
| ファイルオーナーシップ戦略、競合回避 | `agent-teams:parallel-feature-development` |
| SendMessage の使い分け、anti-pattern | `agent-teams:team-communication-protocols` |
| 並列レビューの重複排除・severity較正 | `agent-teams:multi-reviewer-patterns` |
| タスク分解・依存グラフ設計 | `agent-teams:task-coordination-strategies` |
| ADR 記述フォーマット | `documentation-generation:architecture-decision-records` |
| FE/BE 間の interface contract 設計 | `backend-development:api-design-principles` |
| 全体アーキテクチャパターン | `backend-development:architecture-patterns` |

---

## ファイル構成

```
{{CACHE_DIR}}/implements/
└── {task-slug}/
    ├── whiteboard.md            # ADR 形式のチーム意思決定ログ
    ├── architecture-plan.md     # リーダーが作成するアーキテクチャ設計
    ├── architect-review.md      # architect-review からのレビュー結果
    ├── review-findings.md       # Phase3 の並列レビュー集約
    ├── implementer-{zone-a}/    # 例: implementer-candidate-ui
    │   ├── instruct.md
    │   ├── report.md
    │   ├── questions.md
    │   └── answers.md
    ├── implementer-{zone-b}/    # 例: implementer-evaluation-api
    │   └── ...（同構造）
    └── implementer-{zone-c}/    # 必要な数だけ（feature/package 単位）
        └── ...（同構造）
```

## ファイルオーナーシップ境界（owner zone）

実装は役割（FE/BE/infra/qa）ではなく **feature / package 単位の owner zone** で分割します。各 implementer は割り当てられた zone の中で FE・BE・インフラ・テストを一括で担当します。詳細な決定プロセスは `agent-teams:parallel-feature-development` skill を参照してください。

リーダーは Phase 0-4 で、実装対象を **互いに重複しない owner zone** に分割し、各 zone を 1 体の implementer に割り当てます（zone 名は `implementer-{zone}` の形で命名）。zone は機能スライスや package 境界で切るのが基本です。例:

- `implementer-feature-a`: `{{FRONTEND_PATH}}/app/feature-a/`、関連 `{{FRONTEND_PATH}}/components/`、当該機能のテスト
- `implementer-api-service`: `{{FRONTEND_PATH}}/lib/service-a/`、`{{PACKAGES_PATH}}/domain/` のロジック、当該 API のテスト
- `implementer-infra`: `{{IAC_PATH}}/`、`.env*`、CI/CD 設定（インフラ変更がまとまっている場合のみ独立 zone 化）

**zone は必ず非重複にすること（同一ファイルへの並行書き込み = 衝突）。共有ファイル（型定義、定数、スキーマなど）は必ずリーダーが担当 zone を 1 つに決め、instruct.md に明記する。** 規模が小さい場合は implementer 1 体に全 zone を割り当てて構わない。

---

## 実行手順

### Phase 0: 準備

#### 0-1. 実装指示の確認

`実装指示` の内容を確認し、仕様が不十分・不明瞭な場合は AskUserQuestion でユーザーに質問してください。
特に以下を明確にすること:

- **What**: 何を実装するか（対象の画面/機能/モジュール）
- **Why**: なぜ実装するか（背景・目的）
- **Scope**: 実装範囲（フロントのみ / バックのみ / フルスタック / インフラ含む）。これは owner zone の切り方と implementer の体数を決める材料にする

#### 0-2. タスクスラッグの生成

実装指示の内容から kebab-case のスラッグ `{{TASK_SLUG}}` を生成してください。
- 英小文字・数字・ハイフンのみ、2〜4 語程度（例: `cloud-armor-waf`, `user-profile-edit`）

#### 0-3. キャッシュクリーンアップ

`{{TASK_SLUG}}` 確定後、該当ディレクトリの `*.md` を削除してクリーンスタート:

```bash
find {{CACHE_DIR}}/implements/{{TASK_SLUG}}/ -name "*.md" -type f -delete 2>/dev/null || true
```

#### 0-4. owner zone 分割と implementer 体数の判定

実装対象を **非重複の owner zone** に分割し、起動する implementer の体数を決めます。

| 規模 | 目安 | owner zone の切り方 |
|------|------|---------------------|
| 小〜中 | 単一機能・少数ファイル | implementer 1 体に全範囲を割り当て |
| 大規模 | 複数機能・複数 package にまたがる | feature / package 単位で 2〜N 個の zone に分割し、各 zone に 1 体 |

- 各 implementer は自 zone の FE・BE・インフラ・**テスト**を一括で担当する（専用 QA は無い）。
- インフラ変更がまとまっている場合は `implementer-infra` のような独立 zone に切り出してよい。
- **判断に迷う場合は zone を細かく切りすぎず、まず 1〜2 体から始める**（zone 重複による衝突を避けることを最優先）。

---

### Phase 1: アーキテクチャ設計（リーダー + 設計レビュー）

#### 1-1. コードベース調査

{{CODE_INTELLIGENCE_TOOL}} で関連コードを調査してください:

1. `find_symbol` / `get_symbols_overview` で関連ファイルの構造を把握
2. `find_referencing_symbols` で影響範囲を特定
3. 以下のドキュメントを必要に応じて参照:
   - `{{DOCS_PATTERN}}architecture.md`
   - `{{DOCS_PATTERN}}endpoints.md`
   - `{{DOCS_PATTERN}}database-schema.md`
   - `{{DOCS_PATTERN}}design.md`
   - `{{DOCS_PATTERN}}authorization.md`
   - `{{DOCS_PATTERN}}unittest.md`
   - `{{DOCS_PATTERN}}e2e.md`

#### 1-1.5. レビュー指摘チェックリストの参照（よくある指摘の注意喚起）

設計に入る前に、リーダー自身が `{{REVIEW_CHECKLIST_PATH}}` を **参照**し、過去 PR で繰り返し指摘された教訓を設計に織り込みます。

**`review-checklist-advisor` エージェントは起動しません。** implement ではチェックリストを「参照するだけ」です
（チェックリストを上から全件走査して遵守を点検する監査は `review-loop` 側の責務であり、advisor はそこで動きます）。

- Phase 1-1 で把握した実装対象のレイヤー・ファイル種別から、関連しそうなカテゴリ（テスト / ライブラリ / 型安全性 / アーキテクチャ / セキュリティ / エラー処理 / 規約 / インフラ 等）に当たりを付け、該当エントリを Read で確認する。
- 関連する教訓を①設計書（次の 1-2）の「リスク・懸念事項」②各 Teammate の `instruct.md` の「## よくある指摘（チェックリスト由来）」セクションに転記する。
- これにより実装者が手戻りしやすい観点を最初から意識した状態で実装できる。関連が無ければ何もせず次へ進む。

#### 1-2. アーキテクチャ設計書ドラフト作成

`{{CACHE_DIR}}/implements/{{TASK_SLUG}}/architecture-plan.md` を以下の形式で作成:

```markdown
# アーキテクチャ設計

## 概要
[実装の全体像を 1-2 文で説明]

## 変更対象ファイル一覧

### owner zone 別（implementer-{zone} ごとに記載）
| zone | パス | 操作 | 説明 |
|------|------|------|------|

## データフロー
[入力 → 処理 → 出力のフロー]

## インターフェース契約
[FE/BE 間で共有する型定義・API 仕様。`backend-development:api-design-principles` に準拠]

## DB スキーマ変更（該当する場合）
[{{ORM}} スキーマの変更内容、マイグレーション方針]

## 依存関係と実装順序
## リスク・懸念事項
```

#### 1-3. 設計レビュー

ドラフト作成後、`code-architecture-reviewer` を 1 体起動し、設計をクロスチェックしてください。コード品質・アーキテクチャ・API 契約を一体でレビューします。

```
Task tool:
  subagent_type: "devflow:code-architecture-reviewer"
  description: "実装計画の設計レビュー（アーキ + API 契約）"
  prompt: |
    以下のアーキテクチャ設計書を Mode A（設計・実装プランのレビュー）でレビューしてください。

    [architecture-plan.md の内容をインライン貼付]

    観点:
    - Clean Architecture / DDD / SOLID、レイヤー境界の侵害、循環依存の兆候、スケーラビリティ・保守性
    - FE/BE 間の interface contract と API エンドポイント仕様（REST/Server Actions の設計粒度、型安全性、エラーレスポンス設計、認証認可の組み込み位置、ページネーション・フィルタ・バッチ操作の妥当性）

    findings を構造化して返してください（file:line 指摘は不要、設計上の論点のみ）。
```

レビュー結果を `{{CACHE_DIR}}/implements/{{TASK_SLUG}}/architect-review.md` に集約し、
**重大な指摘があれば architecture-plan.md を修正してから Phase 2 に進むこと**。

#### 1-4. Whiteboard 初期化

`{{CACHE_DIR}}/implements/{{TASK_SLUG}}/whiteboard.md` を作成し、最初の ADR を記録:

```markdown
# Implementation Whiteboard

## ADR-001: アーキテクチャ方針決定

- **日時**: [YYYY-MM-DD HH:MM]
- **起案者**: leader
- **ステータス**: 承認（code-architecture-reviewer のレビュー通過）
- **コンテキスト**: [実装指示の要約]
- **決定**: [アーキテクチャの要点]
- **理由**: [なぜこの方針か、レビューでの論点と結論]
- **影響**: [各 Teammate への影響]
```

ADR フォーマットの詳細は `documentation-generation:architecture-decision-records` skill を参照。

---

### Phase 2: 並列実装

#### 2-1. チーム作成

```
TeamCreate:
  team_name: "implement"
  description: "実装チーム"
```

#### 2-2. タスク作成

Phase 0-4 で決めた owner zone に応じて、implementer 1 体につき 1 タスクを作成。各 implementer は自 zone の実装 + テストを 1 タスク内で完結させます（テストは別タスクにしない）。タスク分解・依存グラフ設計の詳細は `agent-teams:task-coordination-strategies` skill を参照。

**実装タスク（並列、依存なし）:** zone ごとに 1 タスク

| Task | subject | owner |
|------|---------|-------|
| 1 | {zone-a} の実装 + テスト | implementer-{zone-a} |
| 2 | {zone-b} の実装 + テスト | implementer-{zone-b} |
| … | …（zone の数だけ） | implementer-{zone-n} |

> zone 間に実装順序の依存がある場合のみ blockedBy を設定する。テストは各 implementer が自タスク内で書くため、独立した QA タスクは作らない（テスト品質は Phase 3-2 のレビューで担保）。

#### 2-3. instruct.md の作成

各 Teammate の `instruct.md` をリーダーが書き出してください。テンプレートは `${CLAUDE_SKILL_DIR}/references/instruct-template.md` を Read して使用すること。

#### 2-4. Teammate 並列起動

instruct.md 書き出し後、各 zone の implementer を **1 メッセージで並列に** Task tool で起動してください。

```
Task tool:
  subagent_type: "devflow:implementer"
  model: "sonnet"                      ← implementer は必ず指定
  team_name: "implement"
  name: "implementer-{zone}"           ← 例: "implementer-candidate-ui"
  description: "{zone の概要}"
  prompt: "{起動プロンプトテンプレ}"
```

各 Teammate の起動プロンプトは `${CLAUDE_SKILL_DIR}/references/teammate-launch-prompt.md` を Read し、
「implementer 向けの追加指示」（自 zone が含む領域に応じて該当部分のみ残す）と合わせて生成してください。

#### 2-5. 質問対応と意思決定仲介

Teammate から SendMessage で「質問があります」と通知を受けた場合:

1. `{{CACHE_DIR}}/implements/{{TASK_SLUG}}/{teammate名}/questions.md` を Read
2. 質問内容に応じて:
   - **仕様に関する質問**: AskUserQuestion でユーザーに確認
   - **技術的な判断**: リーダーがベストプラクティスに基づき決定
   - **他の Teammate との調整が必要**: 関係する Teammate の instruct.md / report.md を確認し決定
3. 回答を `{teammate名}/answers.md` に Write
4. SendMessage で Teammate に「回答しました」と通知
5. **重要な決定は whiteboard.md に ADR エントリとして追記**

SendMessage の使い分け・anti-pattern は `agent-teams:team-communication-protocols` skill を参照。

---

### Phase 3: 統合・品質チェック（並列レビュー強化版）

#### 3-1. 実装結果の確認

全 Teammate のタスクが completed になったら:

1. 各 `report.md` を Read で確認
2. 実装内容に矛盾や競合がないか検証
3. 共有インターフェース（型定義、API 仕様）の整合性を確認

#### 3-2. 並列コードレビュー（多次元）

変更ファイル一覧を確定した後、**同一メッセージ内で 2 つのレビューエージェントを並列起動**してください。
パフォーマンス観点は `code-architecture-reviewer` がコード品質・アーキテクチャと一体で担当するため、専用 dimension は設けません。

レビュー集約・重複排除・severity 較正の詳細は `agent-teams:multi-reviewer-patterns` skill を参照。

Task tool 呼び出しのプロンプトテンプレ（Reviewer 1: Security = `devflow:security-reviewer`、
Reviewer 2: Code Quality + Performance + Architecture = `devflow:code-architecture-reviewer`）は
`${CLAUDE_SKILL_DIR}/references/review-prompts.md` を Read し、変更ファイルリスト等を埋めて使用してください。

#### 3-3. レビュー結果の集約と修正

1. 2 つの reviewer からの findings を `{{CACHE_DIR}}/implements/{{TASK_SLUG}}/review-findings.md` に集約
2. Critical / High severity の findings はリーダー自身が修正
3. Medium / Low は whiteboard.md に記録し、ユーザーに報告時に明示
4. 重大な設計変更があった場合は whiteboard.md に ADR エントリを追記

#### 3-4. 機械的品質チェック

`code-finisher` スキルを **Task tool 経由で sonnet サブエージェントに委譲**して実行:

```
Task tool:
  subagent_type: "general-purpose"
  model: "sonnet"
  description: "コード品質チェック"
  prompt: "`{{AGENT_CONFIG_DIR}}/skills/code-finisher/SKILL.md` の手順に従ってコード品質チェック（型チェック、リント、単体テスト、E2Eテスト）を実行し、失敗した場合は詳細を含めて報告してください。"
```

実行内容:

1. 型チェック: `{{TYPE_CHECK_COMMAND}}`
2. リント & フォーマット: `{{LINT_COMMAND}}`
3. 単体テスト: `{{TEST_COMMAND}}`
4. E2E テスト: `{{E2E_TEST_COMMAND}}`（該当する場合）

問題が見つかった場合はリーダーが修正。
**メインエージェントのコンテキスト節約のため、`Skill` tool での in-context 起動は行わないこと。**

#### 3-5. ユーザーへの報告

```markdown
# 実装完了

## 変更サマリー
[各 implementer（zone）の実装内容を要約]

## 変更ファイル一覧
[全 implementer の report.md から集約]

## 設計レビュー結果（Phase 1-3）
- code-architecture-reviewer: [要点 / 対応済み]

## テスト結果
[各 implementer の report.md から自 zone のテスト pass/fail 結果を集約]

## コードレビュー結果（Phase 3-2）
### Critical / High（対応済み）
[findings と対応内容]
### Medium / Low（残課題）
[findings と判断理由]

## 品質チェック結果
[code-finisher の結果]

## 意思決定ログ
[whiteboard.md の ADR エントリ一覧]

※ commit & push はユーザーの指示をお待ちしています
```

---

### Phase 4: チーム解散

報告完了後、各 Teammate に `SendMessage` の `shutdown_request` を送信し、
全員がシャットダウンした後 `TeamDelete` でチームを解散してください。

**または** `agent-teams:team-shutdown` コマンドが利用可能な場合、そちらを優先して使用すること
（cleanup 漏れ防止のため）。

---

## 起動プロンプトと instruct.md のテンプレート

テンプレート本文は `references/` に分離しています。実行時に Read して使用してください:

- **実装タスク用 instruct.md テンプレート**: `${CLAUDE_SKILL_DIR}/references/instruct-template.md`
  - Phase 2-3 で各 zone の instruct.md を作成する際、このテンプレートを Read し、`{zone}` 等を置換して `{{CACHE_DIR}}/implements/{{TASK_SLUG}}/{zone}/instruct.md` に Write する
- **Teammate 起動プロンプトテンプレ**: `${CLAUDE_SKILL_DIR}/references/teammate-launch-prompt.md`
  - Phase 2-4 で implementer を起動する際、このテンプレートを Read し、`{{ROLE}}` `{{TEAMMATE_NAME}}` `{{TASK_SUBJECT}}` `{{TASK_SLUG}}` を置換して Task tool の prompt に使用する
  - 同ファイルの「implementer 向けの追加指示」を、自 zone が含む領域（FE/BE/インフラ/テスト）に応じて該当部分のみ残して付加する
- **Phase 3-2 並列レビュー用プロンプト**: `${CLAUDE_SKILL_DIR}/references/review-prompts.md`

---

## 注意事項

- **コードへの変更は Phase 2 以降に限定**: Phase 1 はリーダーの調査・設計・レビューのみ
- **commit & push は明示的にユーザーから指示がない限り行わないこと**
- **🚨 DB マイグレーション（`db:migrate` 系コマンド）は自動実行しない**: 実行前に必ず AskUserQuestion 等でユーザーに確認し、承認を得てから実行すること（implementer から実行要求が上がった場合も、リーダーが AskUserQuestion でユーザー承認を取ってから許可する）
- いずれかの Teammate がエラーになった場合は、残りの Teammate の結果で継続
- Teammate からのメッセージは自動配信されるため、手動ポーリング不要
- Teammate が idle になるのは正常な動作（メッセージ送信後の待機状態）
- **Teammate 間の直接通信は禁止**: すべてリーダーが仲介
- **ベストプラクティスに基づく最終決定**: Teammate 間で意見が分かれた場合、リーダーが全体最適で判断
- **owner zone は非重複に**: 各 implementer は自 zone のみ変更。テストも各 implementer が自 zone 分を書く（独立 QA タスクは作らない）
- **Phase 1-3（設計レビュー）と Phase 3-2（並列コードレビュー）は省略しないこと**: ここが品質担保の要。implementer がテストを内包する分、Phase 3-2 のレビューでテスト品質も点検する
