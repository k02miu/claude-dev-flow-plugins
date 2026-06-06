---
name: review-loop
disable-model-invocation: true
description: "ブランチの変更差分（コミット済み + 未コミット）に対して、Agent Teams + マルチ LLM で回帰的にコードレビュー → 修正 → 再レビューを繰り返すスキル。プロジェクト専用のローカル agent（code-architecture-reviewer / security-reviewer / test-coverage-reviewer / infra-reviewer / review-checklist-advisor）を Agent Teams の Teammate として **iteration 1 で 1 回だけ起動し、以降の iteration では SendMessage で再利用する**（解散・再起動は絶対に行わない、コンテキストを引き継ぐ）。さらに Codex / Gemini の独立視点も取り入れる。修正規模が大きい場合は `implement` スキルに委譲し、implement 側のチームも review-loop の全 iteration を通じて再利用する（毎 iteration で立て直さない）。全レビュアーが OK、収束、または 5 反復到達で終了する。**Low (軽微) 指摘も対応対象**であり、軽微だからといって放置しない。コード品質の総点検、PR 提出前の最終確認、リリース前監査など、徹底的にレビューしたい場面で使用すること。"
---

# Regressive Review Loop Skill

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


> **変数の解決（重要）**: 本スキル内の `{{VARIABLE}}` はプラグイン配布時に自動置換されません。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成を調査して値を解決してください。解決できない場合のみユーザーに確認します。

Agent Teams で Claude 専門レビュアーを Teammate として並列起動し、さらに Codex / Gemini の独立視点を
Bash 経由で取り入れることで、ブランチの変更差分に対して **並列レビュー → 修正 → 再レビュー** を最大 5 回ループします。

## 🚨 エージェント再利用の絶対原則 🚨

毎 iteration で Teammate を起動・解散するのは **コンテキスト・キャッシュ・思考の継続性をすべて捨てる完全な無駄** です。
以下を厳守してください:

- **Claude Teammate は iteration 1 で 1 回だけ Task tool で起動する**。iteration 2 以降は **絶対に新規 Task 起動しない**
- **iteration 間で `shutdown_request` も `TeamDelete` も送らない**。Phase 3（最終報告後）まで全 Teammate を在籍させ続ける
- **iteration 2 以降の指示伝達は `SendMessage` のみ**（`instruct.md` を Write で更新 → SendMessage で「iteration N の指示書を Read してください」と通知）
- **最低 3 回はループする前提**で動作する。1 回目で OK が出ても収束確認のため最低 2 回目を回すこと
- **implement スキルを呼ぶ場合も、implement が立てたチームは review-loop の全 iteration を通じて再利用する**。Phase 1-C の 2 回目以降は implement skill を再呼び出しせず、前回 implement で起動した Teammate に直接 SendMessage で追加修正を依頼する

`{{PLUGIN_NAME}}` プラグインの専門エージェントを各 Teammate に割り当てることで、領域特化の品質を確保します。

## 🚨 Low 指摘も必ず対応する 🚨

「Critical/High/Medium がゼロで Low のみ残っている」状態は **Exit 条件ではない**。Low 指摘も等しく対応対象。
ただし「修正コストが効果に見合わないため対応見送り推奨」と判断した Low は、`final-report.html` に
**理由付きで明記**してユーザー判断に委ねる（黙ってスキップしない）。

レビュー対象: $ARGUMENTS
（未指定の場合はブランチとメインブランチ間の全変更差分を対象にします）

**commit & push はユーザーが明示的に指示しない限り絶対に行わないでください。**
**レビューフェーズではコードに手を加えないでください。修正は Phase 1-C でのみ実行します。**

---

## 変数定義

本 SKILL.md では以下の {{VARIABLE}} を使用します。実際のプロジェクトの値に置き換えて使用してください。

| 変数 | 説明 | デフォルト例 |
|------|------|-------------|
| `{{PLUGIN_NAME}}` | プラグイン名 | `devflow` |
| `{{AGENT_CONFIG_DIR}}` | エージェント設定ディレクトリ | `.claude` |
| `{{WORKSPACE_ROOT}}` | ワークスペースルート | `/workspace` |
| `{{CACHE_DIR}}` | キャッシュディレクトリ | `.cache` |
| `{{TASK_SLUG}}` | タスクスラッグ（作業領域名） | `feature-x` |
| `{{PACKAGE_MANAGER}}` | パッケージマネージャ | `pnpm` |
| `{{MONOREPO_FILTER_FLAG}}` | モノレポフィルタフラグ | `--filter` |
| `{{UNIT_TEST_FRAMEWORK}}` | 単体テストフレームワーク | `vitest` |
| `{{E2E_TEST_FRAMEWORK}}` | E2E テストフレームワーク | `playwright` |
| `{{FRONTEND_FRAMEWORK}}` | フロントエンドフレームワーク | `next.js` |
| `{{FRONTEND_PATH}}` | フロントエンドディレクトリ | `apps/web` |
| `{{FRONTEND_CONFIG_PATTERN}}` | フロントエンド設定ファイルパターン | `apps/web/next.config.*` |
| `{{ORM}}` | ORM | `prisma` |
| `{{IAC_TOOL}}` | IaC ツール | `terraform` |
| `{{IAC_PATH}}` | IaC ファイルのパス | `terraform/` |
| `{{IAC_EXT}}` | IaC ファイル拡張子 | `tf` |
| `{{IAC_VARS_EXT}}` | IaC 変数ファイル拡張子 | `tfvars` |
| `{{IAC_SKILL_PREFIX}}` | IaC スキルプレフィックス | `terraform` |
| `{{CLOUD_PROVIDER}}` | クラウドプロバイダ | `gcp` |
| `{{CLOUD_SERVICES}}` | クラウドサービス一覧 | `Cloud Run, Cloud SQL, Cloud Tasks` |
| `{{CLOUD_MCP}}` | クラウド MCP | `google-developer-knowledge mcp, gcloud mcp` |
| `{{CLOUD_PACKAGE_PATH}}` | クラウドパッケージのパス | `packages/cloud/` |
| `{{AUTH_UTILITIES}}` | 認証認可ユーティリティ | `requirePermissions, PermissionGate` |
| `{{REVIEW_CHECKLIST_PATH}}` | レビューチェックリストのパス | `docs/developments/review-check-list.md` |
| `{{REPORT_GENERATOR}}` | HTML レポート生成スクリプト | `report-gen` |
| `{{TEMPLATE_DIR}}` | テンプレートディレクトリ | `.claude/templates` |
| `{{TYPE_CHECK_COMMAND}}` | 型チェックコマンド | `pnpm check-types` |
| `{{LINT_COMMAND}}` | リント・フォーマットコマンド | `pnpm biome:fix` |
| `{{TEST_COMMAND}}` | 単体テストコマンド | `pnpm test` |
| `{{EDITOR_URI_PREFIX}}` | エディタ URI プレフィックス | `vscode://file` |

> 上記のほか、`{{N}}`（iteration 番号）、`{{TASK_SUBJECT}}`、`{{TEAMMATE_NAME}}`、`{{ROLE_SPECIFIC_INSTRUCTIONS}}`、`{{CHANGED_FILES}}`、`{{DIFF_SUMMARY}}`、`{{PREV_FINDINGS}}` は実行時に動的置換されるプレースホルダです。

---

## チーム構成（Agent Teams + マルチ LLM）

### {{PLUGIN_NAME}} 専門レビュアー（Agent Teams の Teammate、常時起動）

| Teammate 名                   | `subagent_type`                                      | 担当領域                                       |
| ----------------------------- | ---------------------------------------------------- | ---------------------------------------------- |
| `code-architecture-reviewer`  | `code-architecture-reviewer`                         | コード品質・可読性・保守性、パフォーマンス（DB/N+1/RSC境界/バンドル）、Clean Arch / DDD / SOLID / レイヤー境界 |
| `security-reviewer`           | `security-reviewer`                                  | OWASP / 認証認可 / STRIDE                      |
| `testing-reviewer`            | `test-coverage-reviewer`                             | テスト網羅性 / 境界値                          |
| `codex-independent-reviewer`  | `codex:codex-rescue`                                 | Codex の独立視点（TS/Node 固有バグ・型安全性） |
| `checklist-advisor`           | `review-checklist-advisor`                           | `{{REVIEW_CHECKLIST_PATH}}` を上から全件走査し、差分が各教訓を遵守しているか点検 |

`codex-independent-reviewer` は **`codex:codex-rescue` agent を Teammate として起動**することで、
他の Claude レビュアーと同じ枠組み（Task tool 起動 → SendMessage で再利用）でコンテキストを引き継ぎます。
Codex CLI 自体はステートレスですが、**Claude ラッパー側に「読んだファイル・前回の分析・指摘の経緯」が残る**ため、
毎 iteration ゼロから始まる無駄を避けられます。
codex CLI が未導入の環境では起動をスキップ（後述の Phase 0-4 でチェック）。

### {{PLUGIN_NAME}} 専門レビュアー（条件付き起動）

| Teammate 名       | `subagent_type`                         | 起動条件                                                     |
| ----------------- | --------------------------------------- | ------------------------------------------------------------ |
| `infra-reviewer`  | `infra-reviewer`                        | 変更差分に {{IAC_TOOL}} / CI/CD / Docker / {{CLOUD_PROVIDER}} 関連ファイルを含む |

### マルチ LLM 独立レビュアー（Bash 経由 / ステートレス）

| ロール名                       | 実行方式                  | 起動条件                  |
| ------------------------------ | ------------------------- | ------------------------- |
| `gemini-independent-reviewer`  | `agy` CLI (Antigravity)   | agy CLI 利用可時          |

Gemini はラッパー agent が存在しないため、毎 iteration `agy -p` を Bash バックグラウンドで起動する
**ステートレス方式**を維持します。コンテキスト継続は prompt.txt 内の `{{PREV_FINDINGS}}` セクション経由。

### infra-reviewer 起動条件の詳細

変更差分に以下のいずれかを含む場合のみ起動:

- `{{IAC_PATH}}/**`, `**/*.{{IAC_EXT}}`, `**/*.{{IAC_VARS_EXT}}`
- `.github/workflows/**`
- `docker-compose*.yml`, `Dockerfile`, `.dockerignore`
- `{{FRONTEND_CONFIG_PATTERN}}`（ランタイム関連設定）
- `{{CLOUD_PACKAGE_PATH}}/**`
- `.env.example` の変更、主要環境変数の追加

該当しない場合は起動せず、`exit-decision.md` にスキップ記録を残します。
判定が曖昧な場合は **起動する側に倒してください**（過剰にレビューしても害がない）。

---

## 参照すべき外部 skill（プロセス知識ベース）

本 SKILL.md は「何をするか」のみを定義します。**「どうやるか」の詳細は以下の skill に委譲**してください。
各フェーズで必要になった時点で該当 skill を Skill ツールで参照すること。

| トピック | 参照先 skill |
|---------|--------------|
| SendMessage の使い分け、anti-pattern | `agent-teams:team-communication-protocols` |
| 複数 reviewer の重複排除・severity較正・統合 | `agent-teams:multi-reviewer-patterns` |
| タスク分解・依存グラフ設計 | `agent-teams:task-coordination-strategies` |
| ADR 形式の最終レポート構造 | `documentation-generation:architecture-decision-records` |
| Clean Arch / DDD / Hexagonal パターン | `backend-development:architecture-patterns` |
| REST/Server Actions 設計観点 | `backend-development:api-design-principles` |
| STRIDE 脅威モデリング | `security-scanning:stride-analysis-patterns` |
| {{IAC_TOOL}} モジュール設計 | `cloud-infrastructure:{{IAC_SKILL_PREFIX}}-module-library` |
| {{CLOUD_PROVIDER}} コスト最適化 | `cloud-infrastructure:cost-optimization` |
| CI/CD パイプライン設計 | `cicd-automation:deployment-pipeline-design` |
| GitHub Actions パターン | `cicd-automation:github-actions-templates` |
| {{UNIT_TEST_FRAMEWORK}} / Testing Library パターン | `javascript-typescript:javascript-testing-patterns` |
| {{E2E_TEST_FRAMEWORK}} E2E パターン | `developer-essentials:e2e-testing-patterns` |
| {{FRONTEND_FRAMEWORK}} コンポーネントパターン | `ui-design:web-component-design` |
| WCAG 2.2 アクセシビリティ | `ui-design:accessibility-compliance` |

**中〜大規模修正が必要になった場合は `implement` スキル**を Skill ツールで起動してください（Phase 1-C で判定）。

---

## ループ構造

```
Phase 0: 準備（ブランチ差分取得、infra 要否判定、タスクスラッグ生成、キャッシュクリーンアップ、チーム作成）
       ↓
   ※ チーム "review-loop" は Phase 0 で 1 回だけ作成し、Phase 3 まで保持する
   ※ Teammate も iteration 1 でだけ Task tool で起動し、以降は SendMessage で再利用する
       ↓
┌──── Phase 1: レビューループ（最大 5 反復） ───────────────────────────┐
│                                                                       │
│   Phase 1-A: レビュー指示伝達                                         │
│     - iteration 1: Claude Teammate (5〜7 種) を Task tool で並列起動  │
│         ※ Codex も `codex:codex-rescue` agent として Teammate 化      │
│     - iteration 2+: 既存 Teammate に SendMessage で再指示             │
│         （instruct.md を更新 → 「iteration N の指示書を Read してね」）│
│     - gemini CLI のみ Bash バックグラウンドで毎 iteration 起動        │
│         （ラッパー agent がないためステートレス方式を維持）           │
│     - 全 Teammate からの SendMessage 通知待ち                         │
│       ↓                                                               │
│   Phase 1-B: 結果集約と Exit 判定                                     │
│     - 全 report.md を Read                                            │
│     - `multi-reviewer-patterns` skill で重複排除・severity較正        │
│     - Exit 条件判定                                                   │
│       ├─ 条件成立 → Phase 2 へ                                        │
│       └─ 未成立 → Phase 1-C へ                                        │
│       ↓                                                               │
│   Phase 1-C: 修正実行                                                 │
│     - 修正規模を判定                                                  │
│       ├─ 軽微（1-2 ファイル、severity ≤ medium）                      │
│       │   → リーダーが直接 Edit で修正                                │
│       └─ 中〜大規模、またはインフラ含む                               │
│           ├─ 初回（implement 未起動）                                 │
│           │   → `implement` スキルを Skill ツールで起動               │
│           │     ※ implement のチームは終了させない                    │
│           └─ 2 回目以降（implement 起動済み）                         │
│               → 前回 implement で起動したチームに SendMessage で      │
│                  追加修正を依頼（implement skill を再呼び出ししない） │
│     - 修正完了後、iteration++ して Phase 1-A へ戻る                   │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
       ↓
Phase 2: 最終報告（ユーザーへ提示）
       ↓
Phase 2.9: レビュー指摘チェックリストの最新化（今ループの findings から教訓を抽出・統合）
       ↓
Phase 3: チーム解散（review-loop チーム + implement チームをまとめて）
```

### Exit 条件（いずれかを満たしたら Phase 2 へ）

1. **全レビュアー OK**: 全ロールが「問題なし」と報告（Critical / High / Medium / Low **すべて 0 件**）
2. **収束判定**: 前 iteration と比較して severity 構成がまったく変わらず、修正しても減らない（技術判断分かれ目で reviewer 間の見解が固定化した状態）
3. **反復上限到達**: iteration が 5 に達した
4. **ユーザーキャンセル**: ユーザーから中断指示

**「Low (軽微) のみ残存」は Exit 条件ではない。** Low severity の指摘も等しく対応対象とする。
ただし、修正コストが効果に見合わないと判断した Low に限り、`final-report.html` に
**「対応見送り推奨（理由: ...）」** として理由付きで明記し、ユーザー判断に委ねること。
**黙ってスキップしたり、軽微を理由にループを早期終了することは禁止。**

---

## コンテキスト管理戦略

Claude Code（リーダー）と Teammate 間の通信は **すべてファイルベース** で行い、コンテキストウィンドウの圧迫を防ぎます。
SendMessage の使い分け・anti-pattern は `agent-teams:team-communication-protocols` skill を参照。

### ファイル構成

```
{{CACHE_DIR}}/review-loop/
└── {task-slug}/
    ├── target-files.md                          # Phase 0 で生成: レビュー対象ファイル + infra 判定結果
    ├── iteration-01/
    │   ├── code-architecture-reviewer/
    │   │   ├── instruct.md                      # リーダー → Teammate: 調査指示
    │   │   ├── report.md                        # Teammate → リーダー: 指摘
    │   │   ├── questions.md                     # Teammate → リーダー: ユーザーへの質問
    │   │   └── answers.md                       # リーダー → Teammate: 回答
    │   ├── security-reviewer/
    │   ├── testing-reviewer/
    │   ├── infra-reviewer/                      # INFRA_REQUIRED=true のときのみ
    │   ├── codex-independent-reviewer/          # codex:codex-rescue Teammate (Claude ラッパー経由)
    │   │   ├── instruct.md                      # 他の Claude Teammate と同じ枠組み
    │   │   ├── report.md                        # Teammate からの出力
    │   │   ├── questions.md                     # 質問エスカレーション用
    │   │   └── answers.md                       # 質問への回答用
    │   ├── gemini-independent-reviewer/         # gemini CLI (Bash 経由、ステートレス)
    │   │   ├── prompt.txt                       # gemini CLI に渡すプロンプト
    │   │   └── report.md                        # gemini CLI の出力
    │   ├── aggregated-findings.md               # Phase 1-B で生成: 統合済み findings
    │   ├── exit-decision.md                     # Phase 1-B で生成: Exit 判定結果
    │   └── fix-plan.md                          # Phase 1-C で生成: 修正計画（継続時のみ）
    ├── iteration-02/
    │   └── ...
    └── final-report.html                        # Phase 2 で生成: ユーザー向け最終レポート（単一HTML、インラインCSS）
```

### 通信フロー（要点）

1. **指示の受け渡し**: リーダーが `instruct.md` に Write → Teammate は起動後 Read
2. **結果の報告**: Teammate が `report.md` に Write → SendMessage で「レビュー完了」と通知
3. **質問エスカレーション**: Teammate が `questions.md` に Write → SendMessage → リーダーが AskUserQuestion → `answers.md` に回答

---

## 実行手順

### Phase 0: 準備

#### 0-1. レビュー対象の特定 & infra 要否判定

引数があればそれを優先。未指定の場合は `git diff` で変更差分を取得:

```bash
# コミット済みの変更
git diff --name-only origin/main...HEAD

# 未コミットの変更（staged + unstaged）
git diff --name-only --cached
git diff --name-only
```

対象を重複排除した一覧を作成し、**infra-reviewer 適用可否判定**を行います。
以下のパターンで 1 件でもマッチすれば `INFRA_REQUIRED=true`:

```
{{IAC_PATH}}/**, **/*.{{IAC_EXT}}, **/*.{{IAC_VARS_EXT}}
.github/workflows/**
docker-compose*.yml, **/Dockerfile, .dockerignore
{{FRONTEND_CONFIG_PATTERN}}
{{CLOUD_PACKAGE_PATH}}/**
.env.example
```

結果を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/target-files.md` に Write:

```markdown
# レビュー対象ファイル

## 変更差分
{ファイルパス一覧}

## infra-reviewer 適用可否
- 結果: REQUIRED / NOT_REQUIRED
- 根拠: {マッチしたファイル一覧 or "該当ファイルなし"}

## 変更 diff（要約）
{各ファイルの変更概要、または `git diff --stat` の出力}
```

**重要**: 変更差分がない場合は、ユーザーに通知して終了してください。

#### 0-2. タスクスラッグの生成

ブランチ名または引数内容から kebab-case のスラッグ `{{TASK_SLUG}}` を生成:

- 英小文字・数字・ハイフンのみ、2〜4 語程度
- 例: `sprint-8-review`, `feat-cloud-armor-review`

#### 0-3. キャッシュクリーンアップ

```bash
find {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/ -name "*.md" -type f -delete 2>/dev/null || true
mkdir -p {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}
```

#### 0-4. CLI 可用性チェック

```bash
which codex || echo "CODEX_UNAVAILABLE"
which agy   || echo "GEMINI_UNAVAILABLE"
```

判定の意味:

- **codex CLI 利用不可、または `codex` プラグイン（`codex:codex-rescue` agent）未導入** → `codex-independent-reviewer` Teammate の起動をスキップ。`codex` は本プラグインのハード依存ではない（`plugin.json` の `dependencies` に宣言していない）ため、未導入環境でも review-loop 全体は成立する。判定は次の両方を確認すること:
  - `which codex`（CLI バイナリ）が存在するか
  - `codex:codex-rescue` agent が解決できるか（`codex` プラグインがインストール済みか）。`/agents` 等で `codex:` 名前空間の agent が見当たらない、または Task 起動が解決失敗する場合は `CODEX_UNAVAILABLE` 扱いとし、Codex ロールを丸ごとスキップする
- **agy CLI 利用不可** → `gemini-independent-reviewer` の Bash 起動をスキップ
- 利用不可のロールは `exit-decision.md` にスキップ記録を残す
- 両方とも利用不可でも Claude 専門レビュアーのみで継続可能

#### 0-5. チーム作成

```
TeamCreate:
  team_name: "review-loop"
  description: "回帰的レビューチーム"
```

#### 0-6. iteration カウンタ初期化

`iteration = 1` でループを開始します。以降 Phase 1 のたびに +1。

---

### Phase 1: レビューループ

以下を iteration が 5 に達するまで、または Exit 条件が成立するまで繰り返します。

#### Phase 1-A: レビュー指示伝達（iteration ごとに実施）

##### 1-A-0. サブディレクトリの作成

```bash
mkdir -p {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{code-architecture-reviewer,security-reviewer,testing-reviewer,codex-independent-reviewer,gemini-independent-reviewer,checklist-advisor}
# INFRA_REQUIRED=true のときのみ
mkdir -p {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/infra-reviewer
```

##### 1-A-1. 各 Teammate の instruct.md を準備

以下の各セクション（1-A-5 以降）に記載された「instruct.md の内容」を、
それぞれ `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{teammate-name}/instruct.md` に Write で保存してください。

**全ファイルの保存が完了してから、Phase 1-A-2 に進みます。**

**重要**: 2 周目以降（iteration ≥ 2）は、instruct.md の「前回反復での指摘」セクションに
前 iteration の `aggregated-findings.md` を要約して含めること。これにより同じ指摘を繰り返す無限ループを防ぎます。

##### 1-A-2. Teammate の起動 / 再利用（Claude）

**iteration の値で動作を分岐させる。**

###### Case A: `iteration == 1` の場合（初回のみ：並列起動）

Claude Teammate を **1 メッセージで並列に** Task tool で起動してください
（常時 3 ロール + checklist-advisor 1 ロール + Codex 1 ロール + 条件付き infra 1 ロール、合計最大 6 ロール）:

```
# 例: code-architecture-reviewer（他のロールも同様に同一メッセージ内で並列起動）
Task tool:
  subagent_type: "devflow:code-architecture-reviewer"
  team_name: "review-loop"
  name: "code-architecture-reviewer"
  description: "コード品質・アーキテクチャレビュー (iteration N)"
  prompt: "{下記の起動プロンプトテンプレ}"
```

**Codex は他のレビュアーと同じ並列起動の中に含めてください**:

```
Task tool:
  subagent_type: "codex:codex-rescue"
  team_name: "review-loop"
  name: "codex-independent-reviewer"
  description: "Codex 独立レビュー (iteration N)"
  prompt: "{下記の起動プロンプトテンプレ + Codex 用追加指示}"
```

各 Teammate には `team_name: "review-loop"` と `name` を指定し、チームに参加させてください。
起動プロンプトは本 SKILL.md 末尾の「起動プロンプトテンプレ」節を参照してください。

**起動プロンプト内で「あなたはこの後 iteration 2, 3, ... と繰り返し指示を受ける可能性があります。
SendMessage で『iteration N の指示書を Read してください』と通知された場合、
新しい instruct.md を読み込み、同じ JSON フォーマットで report.md に結果を Write してください」と明記すること。**

###### Case B: `iteration >= 2` の場合（既存 Teammate を再利用）

**🚨 絶対に Task tool で再起動しない。** iteration 1 で起動した Teammate は team "review-loop" に在籍したまま、
次の指示を待っています。SendMessage のみで再指示してください:

```
# 各 Teammate に対して並列に SendMessage（1 メッセージで複数 SendMessage を送る）
SendMessage:
  to: "code-architecture-reviewer"
  message: |
    iteration {{N}} のレビューを開始してください。
    `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/code-architecture-reviewer/instruct.md` を Read で確認し、
    iteration 1 と同じ JSON フォーマットで
    `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/code-architecture-reviewer/report.md` に Write してください。
    完了後 SendMessage で「iteration {{N}} レビュー完了」と通知してください。
```

同様に他の全 Claude Teammate（security-reviewer / testing-reviewer / **checklist-advisor** / **codex-independent-reviewer** / 該当時のみ infra-reviewer）にも並列で SendMessage します。

`codex-independent-reviewer` も Claude ラッパー (`codex:codex-rescue`) であるため、他のレビュアーと
同じ手順で SendMessage で再指示できます。前 iteration で読んだファイル・前回の指摘の経緯はラッパー側に保持されます。

**禁止事項**:
- iteration 2 以降で同名の Teammate を Task tool で再起動すること（`Cannot spawn duplicate name` エラーまたは context 破棄が発生）
- iteration 間で `shutdown_request` を送ること
- iteration 間で `TeamDelete` を呼ぶこと

これらの操作はコンテキスト・キャッシュ・思考過程をすべて捨てるため、ループ継続の意義が失われる。

##### 1-A-3. Gemini CLI を Bash でバックグラウンド起動

Codex は Phase 1-A-2 で Teammate として既に起動・指示済みなのでここでは扱いません。
Gemini のみ毎 iteration、Bash tool の `run_in_background: true` で起動:

```bash
# Gemini = agy (利用可能時のみ)
agy --dangerously-skip-permissions -p \
  "$(cat {{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/gemini-independent-reviewer/prompt.txt)" \
  > "{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/gemini-independent-reviewer/report.md" \
  2>&1 &
```

Gemini 用の prompt.txt は後述の「Gemini 用 prompt.txt テンプレ」節を参照。
`report.md` が作成されたら完了とみなします（ポーリング判定）。

##### 1-A-4. 完了通知の待ち受けと質問対応

- Claude Teammate（codex-independent-reviewer 含む）からの SendMessage（「レビュー完了」通知）を待ち受け
- Gemini は `report.md` の出現をチェック

**質問対応**: Teammate から SendMessage で「質問があります」と通知を受けた場合:

1. `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{teammate-name}/questions.md` を Read
2. AskUserQuestion でユーザーに確認
3. 回答を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{teammate-name}/answers.md` に Write
4. SendMessage で Teammate に「回答しました」と通知

---

#### 1-A-5. 各 Teammate の instruct.md テンプレート

各ロール固有の指示を `instruct.md` に書き出します。`{{TASK_SLUG}}`, `{{N}}`, `{{CHANGED_FILES}}`, `{{DIFF_SUMMARY}}`,
`{{PREV_FINDINGS}}`（2 周目以降のみ）を置換してください。

##### 共通部分（全ロール共通、instruct.md の冒頭）

```markdown
# {ロール名} レビュー指示書 (iteration {{N}})

## レビュー対象

- ブランチ差分ファイル: `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/target-files.md` を Read で確認
- 具体的な diff: 必要に応じて `git diff` コマンドで確認

### 変更ファイル一覧

{{CHANGED_FILES}}

### 変更 diff 要約

{{DIFF_SUMMARY}}

## レビューの原則

- **コードには絶対に手を加えないでください。read only で調査のみを行ってください。**
- 指摘の根拠はファイルパス + 行番号で具体的に示してください。
- 「推奨修正」にはコード例があれば必ず併記してください。

## 前回反復での指摘（2 周目以降のみ）

{{PREV_FINDINGS}}

同じ指摘を繰り返さないでください。前回対応済みと思われる箇所は確認し、まだ問題があれば「未解消」としてマークしてください。
```

##### ロール固有の観点（各 instruct.md の続き）

**code-architecture-reviewer** 固有観点:
```markdown
## レビュー観点

以下の skill を必ず参照してください:
- `backend-development:architecture-patterns` — Clean Architecture / DDD / Hexagonal
- `backend-development:api-design-principles` — REST/Server Actions 設計

### コード品質
- 可読性、命名規則、コードの意図の明瞭さ
- DRY / YAGNI 原則
- コメントの過不足（冗長なコメント、自明なコメント、必要な説明の欠如）
- エラーハンドリングの適切性
- マジックナンバー、ハードコードされた値
- デッドコード、未使用 import

### パフォーマンス
- DB クエリ効率（N+1、欠落インデックス、全件スキャン）、メモリリーク
- RSC / Client Components の境界（不要な "use client"）
- キャッシング戦略と無効化、バンドルサイズ・遅延ロードの機会
- async / 並行処理の正しさ（競合状態・レース・順序保証）

### アーキテクチャ
- Clean Architecture / DDD / SOLID の観点
- レイヤー境界の侵害（api → lib → database の方向が守られているか）
- 循環依存の兆候
- Service 層でのビジネスロジック集約の妥当性
- API エンドポイントの設計粒度、エラーレスポンス統一性
```

**security-reviewer** 固有観点:
```markdown
## レビュー観点

以下の skill を必ず参照してください:
- `security-scanning:stride-analysis-patterns` — STRIDE 脅威モデリング

- OWASP Top 10
- 認証・認可のバイパス（{{AUTH_UTILITIES}} の漏れ）
- SQL injection, XSS, CSRF
- 秘密情報の露出（ログ出力、レスポンス、Git 管理）
- 入力検証・サニタイゼーション
- STRIDE 脅威モデリング（Spoofing / Tampering / Repudiation / Info Disclosure / DoS / Elevation）
```

**testing-reviewer** 固有観点:
```markdown
## レビュー観点（テストカバレッジ）

以下の skill を必ず参照してください:
- `javascript-typescript:javascript-testing-patterns` — {{UNIT_TEST_FRAMEWORK}} / Testing Library
- `developer-essentials:e2e-testing-patterns` — {{E2E_TEST_FRAMEWORK}}

- テスト網羅性（重要なパス、境界値、エラーパス）
- モック戦略の妥当性（型安全モックファクトリの使用）
- テストの独立性、決定性
- アサーションの品質、特異性
- E2E はハッピーパス限定（エラー系はコンポーネントテストに）
```

**codex-independent-reviewer** 固有観点:
```markdown
## レビュー観点（Codex 独立視点）

あなたは `codex:codex-rescue` agent として Codex CLI を内部的に呼び出します。
他のレビュアー（Claude 専門エージェント、Gemini）の意見に影響されず、
**Codex 自身の判断**でコードレビューを行ってください。

特に以下のような Claude 専門エージェントが見落としやすい点に重点を置いてください:
- TypeScript 固有の微妙なバグ（型推論の死角、union narrowing の落とし穴など）
- TypeScript の型安全性の抜け（`any` の暗黙発生、`unknown` の取り回し、`satisfies` 漏れ）
- Node.js の非同期処理の落とし穴（Promise の未 await、event loop ブロッキング、unhandled rejection）
- ESM / CJS 境界での挙動差異
- {{ORM}} の使い方の癖（接続プール、トランザクション境界）

**Codex CLI 呼び出しの注意**:
- 呼び出すたびに Codex 側のコンテキストはリセットされるが、
  あなた（Claude ラッパー）側に「前回 iteration で何を読み、何を指摘したか」が残るので、
  iteration を跨ぐと前回の文脈を Codex に再提示できる
- 1 iteration 内で複数回 Codex を呼んでも構わない（広い観点と深い観点の両方を取りに行く）
```

**checklist-advisor** 固有観点:
```markdown
## レビュー観点（チェックリスト準拠の網羅点検）

あなたは「監査役」です。`{{REVIEW_CHECKLIST_PATH}}` を **上から全件 Read し、各エントリを順に評価**してください。
他のレビュアーのように自由な観点で探すのではなく、決まったチェックリストを 1 項目ずつ漏れなく照合します。

各エントリについて:
1. **該当するか**: その `trigger`・本文が示す状況に、今回の変更差分が触れているか。
2. 該当する場合、**遵守できているか**を確認:
   - 守れている → `compliant`（OK）
   - 守れていない／疑わしい → `violation` または `needs_check` として finding に上げる
3. 該当しない → スキップ。

- **全エントリを必ず一度は評価すること**（件数上限を設けず、該当の取りこぼしを最優先で避ける）。
- diff だけで遵守を判断できない該当は、実コードを Read して確認する。判断に迷う該当は握りつぶさず `needs_check` に倒す。
- 各 finding の `evidence` に、根拠とした **チェックリストのエントリのタイトル**（`###` 見出し）を含めること。
- 出力 JSON には `checklist_total` / `checklist_evaluated` を含め、**全件評価したことを示す**こと（両者は一致させる）。
- 該当が 1 件も無ければ `overall_status: ok`、findings 空、notes に「該当する既知の指摘なし」と明記。
```

**infra-reviewer** 固有観点（INFRA_REQUIRED=true のときのみ）:
```markdown
## レビュー観点

以下の skill を必ず参照してください:
- `cloud-infrastructure:{{IAC_SKILL_PREFIX}}-module-library` — {{IAC_TOOL}} モジュール設計
- `cloud-infrastructure:cost-optimization` — コスト影響評価
- `cicd-automation:github-actions-templates` — GitHub Actions パターン
- `cicd-automation:secrets-management` — シークレット管理

- {{IAC_TOOL}} ベストプラクティス
- {{CLOUD_PROVIDER}} IAM 最小権限
- {{CLOUD_SERVICES}}
- 環境変数注入漏れ
- CI/CD ワークフロー、シークレット漏れ
- コスト影響、予期しないリソース破棄（{{IAC_TOOL}} plan 観点）
```

##### 全ロール共通（instruct.md の末尾）

```markdown
## 出力フォーマット

以下の JSON 形式で結果を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{ロール名}/report.md` に Write で保存してください:

{
  "reviewer": "{ロール名}",
  "iteration": {{N}},
  "overall_status": "ok | needs_fix",
  "findings": [
    {
      "id": "{連番（例: code-1, arch-1, sec-1, perf-1, test-1, infra-1）}",
      "severity": "critical | high | medium | low",
      "location": "ファイルパス:行番号",
      "category": "{領域内のサブカテゴリ}",
      "evidence": "問題のある記述の引用（1-3 行）",
      "issue": "何が問題か（1-2 行）",
      "impact": "対応しない場合の影響（1-2 行）",
      "recommendation": "具体的な修正提案（コード例推奨）"
    }
  ],
  "notes": "全体的なコメント（任意）"
}
```

---

#### 1-A-6. Gemini 用 prompt.txt テンプレ

Codex は Phase 1-A-2 で他の Claude Teammate と同じ枠組みで Task tool 起動するため、
**専用の instruct.md を 1-A-5 と同じ場所に Write**してください（Codex 固有観点は下記「ロール固有の観点」節を参照）。

Gemini は Agent Teams の外で動くため、引き続き独立したプロンプトを prompt.txt に Write します。

**gemini-independent-reviewer/prompt.txt**:
```
あなたは Google Gemini の独立したレビュアーです。他のレビュアー（Claude、Codex）の意見に
影響されず、純粋に Gemini 自身の判断でコードレビューを行ってください。特に以下の観点を重視してください:
- アルゴリズム的正確性
- 並行性・スレッドセーフティ
- エッジケースの見落とし
- ドキュメントとコードの乖離

【レビュー対象】
以下のファイル差分をレビューしてください。

変更ファイル一覧:
{{CHANGED_FILES}}

変更 diff 要約:
{{DIFF_SUMMARY}}

【前回反復での指摘（2 周目以降のみ）】
{{PREV_FINDINGS}}

同じ指摘を繰り返さないでください。

【出力フォーマット】
以下の JSON 形式で結果を標準出力に出力してください:

{
  "reviewer": "gemini-independent-reviewer",
  "iteration": {{N}},
  "overall_status": "ok | needs_fix",
  "findings": [
    {
      "id": "gemini-{連番}",
      "severity": "critical | high | medium | low",
      "location": "ファイルパス:行番号",
      "category": "{サブカテゴリ}",
      "evidence": "問題のある記述の引用",
      "issue": "何が問題か",
      "impact": "対応しない場合の影響",
      "recommendation": "具体的な修正提案"
    }
  ],
  "notes": "全体的なコメント"
}

コードには絶対に手を加えないでください。read only で調査のみを行ってください。
```

---

#### Phase 1-B: 結果集約と Exit 判定

##### 1-B-1. 全 report.md を Read

以下を全て Read で読み込みます（INFRA_REQUIRED / CODEX_UNAVAILABLE / GEMINI_UNAVAILABLE に応じて数が変動）:

- `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/code-architecture-reviewer/report.md`
- `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/security-reviewer/report.md`
- `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/testing-reviewer/report.md`
- `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/checklist-advisor/report.md`
- （条件付き）`infra-reviewer/report.md`
- （条件付き）`codex-independent-reviewer/report.md`
- （条件付き）`gemini-independent-reviewer/report.md`

##### 1-B-2. findings の統合

`agent-teams:multi-reviewer-patterns` skill を Skill ツールで参照し、以下を実施:

- **重複排除**: 同一箇所への同一指摘を統合（reviewer 名を複数明記）
- **severity 較正**: 過大/過小評価の補正
- **矛盾検出**: reviewer 間で判断が分かれる箇所の明確化
- **見落とし検出**: 対象ファイルに対する調査カバレッジの評価

結果を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/aggregated-findings.md` に Write。

統合フォーマット（各項目）:

```markdown
### [H-1] 問題の端的な説明 | severity: high | 検出: code-architecture-reviewer, security-reviewer

- **場所**: `path/to/file.ext:42`
- **カテゴリ**: code_quality / architecture / security / performance / testing / infra
- **証拠**: {引用（1-3 行）}
- **問題**: {何が問題か}
- **影響**: {対応しない場合のリスク}
- **推奨修正**: {具体的な修正案（コード例あれば併記）}
```

ID 体系:
- `[H-N]` high / critical
- `[M-N]` medium
- `[L-N]` low
- `[C-N]` reviewer 間で矛盾

##### 1-B-3. Exit 判定

以下の条件を評価し、`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/exit-decision.md` に Write:

```markdown
# Exit Decision - Iteration {{N}}

## severity 分布
- Critical: {数}
- High: {数}
- Medium: {数}
- Low: {数}
- 矛盾: {数}

## 前 iteration との比較（2 周目以降）
- Critical 変化: {前→今}
- High 変化: {前→今}
- Medium 変化: {前→今}

## 判定
- [ ] 条件 1: 全レビュアー OK（Critical/High/Medium/Low **すべて 0**）
- [ ] 条件 2: 収束判定（前回との比較で severity 構成が完全に同一、修正してもこれ以上減らない技術判断分かれ目に該当）
- [ ] 条件 3: 反復上限到達（iteration == 5）

**注**: 「Low のみ残存」は Exit 条件ではない。Low 指摘も対応対象。

## スキップされたレビュアー
- infra-reviewer: {REQUIRED / NOT_REQUIRED}
- codex-independent-reviewer: {OK / UNAVAILABLE}
- gemini-independent-reviewer: {OK / UNAVAILABLE}

## 結論
{EXIT | CONTINUE}

## 理由
{判定理由}
```

- いずれかの条件成立 → **Phase 2 へ進む**（Phase 1-C はスキップ）
- どの条件も不成立 → **Phase 1-C へ**

---

#### Phase 1-C: 修正実行

**Exit 判定で CONTINUE だった場合のみ実施。**

##### 1-C-1. 修正規模の判定

`aggregated-findings.md` から修正計画を作成し、`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/fix-plan.md` に Write:

```markdown
# Fix Plan - Iteration {{N}}

## 対応対象の findings
{H-1, H-2, M-1, ... のリスト（Critical/High を優先、Medium は影響度順）}

## 影響ファイル一覧
- `path/to/file1.ext` - {修正概要}
- `path/to/file2.ext` - {修正概要}
- ...

## 規模判定
- ファイル数: {N}
- 複数ファイルにまたがる機能変更: {Yes/No}
- DB スキーマ変更: {Yes/No}
- インフラ変更: {Yes/No}

## 実行方針
{SMALL_FIX_DIRECT | LARGE_FIX_IMPLEMENT_TEAM}
```

**判定ルール**:

| 条件 | 実行方針 |
|------|---------|
| ファイル 1-2 かつ severity ≤ medium かつ機能変更なし | `SMALL_FIX_DIRECT`（リーダーが直接修正） |
| ファイル 3 以上 / severity ≥ high の構造変更 / DB・インフラ変更を含む | `LARGE_FIX_IMPLEMENT`（implement スキル起動 or 既存 implement チーム再利用） |

**Low 指摘も修正対象**: ファイル数が少なく軽微な Low なら SMALL_FIX_DIRECT で対応する。
「対応見送り推奨」と判断した Low のみ、`fix-plan.md` に理由付きで明記して残す（黙って無視しない）。

##### 1-C-2-A. SMALL_FIX_DIRECT の場合

リーダー自身が Edit ツールで対象ファイルを修正します:

1. Critical → High → Medium → Low の順
2. 各修正後、コード全体の整合性を簡易確認
3. 修正内容を `fix-plan.md` の末尾に追記（どの finding をどう修正したか）

修正完了後、iteration++ して Phase 1-A に戻ります（iteration が 6 になったら Phase 2 へ）。

##### 1-C-2-B. LARGE_FIX_IMPLEMENT の場合

**初回（implement チーム未起動の場合）**: `implement` スキルを Skill ツールで起動します。引数には以下を渡してください:

```
以下の指摘事項を修正してください。これは review-loop の iteration {{N}} からの修正依頼です。

## 対応すべき findings
{aggregated-findings.md の Critical / High / Medium / Low 項目をそのまま貼付}

## 影響ファイル
{fix-plan.md の影響ファイル一覧}

## 制約
- 既存の機能を壊さないこと
- 各 finding の「推奨修正」に従うこと
- commit & push は絶対に行わないこと（review-loop 側で継続するため）
- **作業完了後、Teammate を解散しないこと**（review-loop が後続 iteration で再利用するため、`shutdown_request` / `TeamDelete` を打たない）
```

**🚨 implement チーム再利用の原則 🚨**

implement スキルが立ち上げた Teammate（implementer-leader / frontend / backend / infra / qa など）も、
review-loop の **全 iteration を通じて再利用**します。**毎 iteration で立て直さない**。

**2 回目以降の LARGE_FIX_IMPLEMENT（implement チーム起動済み）**: implement skill を再呼び出しせず、
前回 implement で起動した Teammate に **直接 SendMessage で追加修正を依頼**してください:

```
SendMessage:
  to: "implementer-leader"   # implement skill が立てたリーダー teammate の name
  message: |
    iteration {{N}} の追加修正依頼です。
    `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/aggregated-findings.md` を Read で確認し、
    Critical / High / Medium / Low の各指摘に対して修正を行ってください。
    制約は前回と同じ（commit & push しない、Teammate 解散しない）。
    完了後 SendMessage で「追加修正完了」と通知してください。
```

implement チームの Teammate name は initial 起動時に確認しておき、`{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/implement-team-roster.md` に記録しておくこと。

implement 関連の作業完了後、iteration++ して Phase 1-A に戻ります（iteration が 6 になったら Phase 2 へ）。

**注意**: implement の Teammate を解散させると、review-loop の次 iteration でまたゼロから設計理解
し直す無駄が発生する。**Phase 3 まで全 implement Teammate を在籍させ続けること。**

---

### Phase 2: 最終報告

ループを抜けたら、最終レポートを作成してユーザーに提示します。

#### 2-1. final-report.html の生成

**Step 2-1-a: final-report.md（MD ソース）を Write**

トークン節約のため、リーダーはまず **コンパクトな Markdown** で内容を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.md` に Write します。HTML 化は後段の {{REPORT_GENERATOR}} に委譲します。

MD テンプレ:

```markdown
# Review Loop Final Report - {{TASK_SLUG}}

## 概要
- **対象**: {対象ファイル数 / ブランチ名}
- **反復回数**: {N}
- **終了理由**: {Exit Decision の理由}

## 反復サマリー

| Iteration | Critical | High | Medium | Low | 修正方針 |
|-----------|----------|------|--------|-----|---------|
| 1         |          |      |        |     | SMALL / LARGE / - |
| ...       |          |      |        |     |                   |

## 最終反復の残存指摘

### 残存 Critical / High
{該当なし の場合はその旨を明記}

### 残存 Medium
{項目の列挙}

### 残存 Low（軽微）
{項目の列挙、対応見送り推奨の場合はその旨と理由を明記}

## 反復中に解消した主な指摘
{iteration 1 〜 N-1 で修正完了した findings の要約}

## Reviewer 別所感

| Reviewer | 最終状態 | 総評 |
|----------|---------|------|
| code-architecture-reviewer | OK / 残存 | {所感} |
| security-reviewer     | OK / 残存 | {所感} |
| testing-reviewer      | OK / 残存 | {所感} |
| infra-reviewer        | OK / 残存 / SKIPPED | {所感} |
| codex-independent-reviewer  | OK / 残存 / SKIPPED | {所感} |
| gemini-independent-reviewer | OK / 残存 / SKIPPED | {所感} |

## 推奨次アクション

{以下のパターン A〜D から該当するもの 1 つを選択して記述}

- A: 全レビュアー OK → 品質チェック完了。PR 提出可能。`{{TYPE_CHECK_COMMAND}} && {{LINT_COMMAND}} && {{TEST_COMMAND}}` で最終確認後、commit & push
- B: 反復上限到達で Critical/High 残存 → 人間判断が必要な項目を列挙し、推奨対応方針を併記
- C: 収束判定 → 設計判断が必要な項目を列挙
- D: Low のみ「対応見送り推奨」 → 各 Low に対応見送り理由を明記

## ファイル構成（実行ログ）

```
{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/
├── target-files.md
├── iteration-01/ ... iteration-{N}/
├── final-report.md
└── final-report.html
```
```

**Step 2-1-b: {{REPORT_GENERATOR}} 委譲で HTML 生成を試みる**

```bash
bash {{TEMPLATE_DIR}}/generate-report-with-{{REPORT_GENERATOR}}.sh \
  --source-md   "{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.md" \
  --output-html "{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.html" \
  --title       "Review Loop 最終レポート - {{TASK_SLUG}}" \
  --context     "対象: {対象ファイル数} ファイル / ブランチ: {ブランチ名} / 反復: {N} 回"
```

スクリプト終了コード:
- **0**: {{REPORT_GENERATOR}} が HTML 生成に成功 → Step 2-2 へ
- **1**: {{REPORT_GENERATOR}} CLI 未インストール → Step 2-1-c にフォールバック
- **2**: {{REPORT_GENERATOR}} 実行失敗 → ログ確認後 Step 2-1-c にフォールバック

**Step 2-1-c: フォールバック（リーダーが直接 HTML 生成）**

{{REPORT_GENERATOR}} が利用できない場合のみ実施:

1. `{{TEMPLATE_DIR}}/report-template.html` を Read
2. プレースホルダを置換し、Step 2-1-a の MD を以下の構造で HTML 化:
   - 概要 → `<section id="summary">`
   - 反復サマリー → `<section id="iterations">` + `<table>`
   - 最終反復の残存指摘 → `<section id="remaining">` (severity ごとに `<span class="badge badge-{high|medium|low}">`)
   - 反復中に解消した指摘 → `<section id="resolved">`
   - Reviewer 別所感 → `<section id="reviewers">` + `<table>` (OK=`badge-ok`, 残存=`badge-ng`, SKIPPED=`badge-info`)
   - 推奨次アクション → `<section id="next-actions">` (パターンに応じ `<div class="callout callout-{info|todo|warn}">`)
   - ファイル構成 → `<section id="artifacts">` + `<pre><code>`
3. HTML 特殊文字（`<`, `>`, `&`, `"`, `'`）は必ずエスケープ
4. 完成した HTML を Write で出力

#### 2-2. ユーザーへの提示

リーダーは `final-report.html` の内容を要約してユーザーに報告してください。
レポート全文を貼り付けるのではなく、**以下の要点を抜き出してコンパクトに提示**:

1. **終了理由**（Exit Decision）
2. **反復サマリー表**
3. **残存指摘**（Critical / High / Medium のみ、Low は件数のみ）
4. **推奨次アクション**
5. **🔗 詳細レポート**: `[最終レポートを開く]({{EDITOR_URI_PREFIX}}{{WORKSPACE_ROOT}}/{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/final-report.html)` の形式で Markdown リンクとして提示。
   （クリックでエディタに HTML が開く。エディタ右上の **「Show Preview」ボタン**（Live Preview 拡張）でレンダリング表示できる旨を併記すること）

#### 2-3. commit 提案はしない

review-loop スキル自体は commit しません。ユーザーが明示的に指示した場合のみ commit 操作を行ってください。

---

### Phase 2.9: レビュー指摘チェックリストの最新化

最終報告後、**今回のループで蓄積した findings から再利用可能な教訓を抽出し**、
`{{REVIEW_CHECKLIST_PATH}}` に反映します。これにより、本ループの指摘が将来の実装・レビューに活きます。

#### 2-9-1. 教訓の抽出元

各 iteration の `aggregated-findings.md`（特に複数 reviewer が一致した指摘、繰り返し出た指摘）を教訓の源とします。
**1 回限りのこの差分でしか通用しない指摘は対象外**。汎用的に再利用できる教訓のみ拾います。

#### 2-9-2. 抽象化と統合

`review-checklist-update` スキルの **Phase 3（抽象化）と Phase 4（既存との突合・統合）のロジックを適用**してください
（本ループの findings を「指摘」の入力源として扱う）。要点:

- `{{REVIEW_CHECKLIST_PATH}}` 冒頭の「設計方針」を Read して厳守（一過性情報を書かない / 類似は新規追加せず既存更新 / ライブラリ固有情報は残す）。
- カテゴリ判定 → 既存と類似なら更新（`updated` を今日に）、新規なら該当カテゴリ末尾に追記。
- 抽象化できない指摘は不採用。

#### 2-9-3. 反映（commit しない）

review-loop は **commit / push を行わない**スキルなので、ここでも `{{REVIEW_CHECKLIST_PATH}}` の
**ローカル編集のみ**を行い、変更点を Phase 2 の報告に「チェックリスト更新」として併記してください。
commit はユーザーが明示的に指示した場合のみ。

該当する教訓が無ければ「チェックリスト更新: なし」と報告してスキップします。

---

### Phase 3: チーム解散（review-loop の最終段階でのみ実施）

**🚨 Phase 2 の最終報告まで完了してから、はじめて解散する。** 途中の iteration では絶対に解散しない。

最終報告後、以下の順序で解散します:

1. **review-loop チーム**（レビュアー Teammate 全員）に `SendMessage` の `shutdown_request` を送信し、
   全員のシャットダウンを確認した後 `TeamDelete` でチームを削除
2. **implement チーム**（implement skill が立てた Teammate がいる場合）にも同様に `shutdown_request` → `TeamDelete`

**または** `agent-teams:team-shutdown` コマンドが利用可能な場合、そちらを優先して使用すること
（cleanup 漏れ防止のため）。implement チームについては、implement skill 側のシャットダウン手順に従うこと。

---

## 起動プロンプトテンプレ（Claude Teammate 共通）

各 Teammate 共通のテンプレ。`{{TEAMMATE_NAME}}` `{{TASK_SUBJECT}}` `{{TASK_SLUG}}` `{{N}}` を置換してください。

```
あなたはチーム "review-loop" の Teammate "{{TEAMMATE_NAME}}" です。
{{TASK_SUBJECT}} として、ブランチ変更差分のコードレビューを担当します。

【🚨 反復レビュー前提 🚨】
このタスクは複数 iteration で繰り返し実行されます（最大 5 回）。
あなたはチーム解散まで在籍し続け、iteration ごとに新しい指示を受け取ります。

- 1 回目の指示書は `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-1/{{TEAMMATE_NAME}}/instruct.md` です
- 2 回目以降は、リーダーから SendMessage で「iteration N の指示書を Read してください」と通知が来ます
  - 通知を受けたら `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-N/{{TEAMMATE_NAME}}/instruct.md` を Read し
  - 同じ JSON フォーマットで `iteration-N/{{TEAMMATE_NAME}}/report.md` に Write してください
- **shutdown_request を受け取るまでチームに留まり続けてください**（途中で勝手に終了しない）
- 各 iteration の前回レビュー観点・ファイル理解・コードベース知識をそのまま引き継いで効率化してください

TaskList でタスク一覧を確認し、自分のタスクを TaskUpdate で
owner を自分に設定し、status を in_progress にしてから作業を開始してください。

まず `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{{TEAMMATE_NAME}}/instruct.md` を Read ツールで読み、
指示内容を確認してください。

**コードには絶対に手を加えないでください。read only で調査のみを行ってください。**
**テストの実行も不要です。**

{{ROLE_SPECIFIC_INSTRUCTIONS}}  ← 下記の「役割別の追加指示」節から挿入

【質問エスカレーション】
レビュー中にユーザーへの確認が必要な質問が生じた場合:
1. 質問内容を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{{TEAMMATE_NAME}}/questions.md` に Write
2. SendMessage でチームリーダーに「質問があります」と通知
3. `answers.md` にリーダーが回答を保存するので、Read で確認してからレビューを続行

SendMessage の使い分けは `agent-teams:team-communication-protocols` skill を参照。

【結果の保存】
レビュー完了後:
1. 結果を instruct.md に記載された JSON 形式でまとめる
2. `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{{TEAMMATE_NAME}}/report.md` に Write
3. SendMessage でチームリーダーに「レビュー完了」と通知
4. TaskUpdate でタスクを completed にする
5. **チームから離脱せずに、次 iteration の SendMessage 通知を待機してください**
```

### 役割別の追加指示

**code-architecture-reviewer 向け追加指示:**
```
あなたは code-architecture-reviewer（コード品質・パフォーマンス・アーキテクチャを一体でレビューするローカル agent）です。
以下の 3 観点を漏れなくレビューしてください:
- コード品質: 可読性・命名・DRY・YAGNI・コメント過不足・エラーハンドリング・デッドコード
- パフォーマンス: DB クエリ効率・N+1・RSC/Client 境界・キャッシング・バンドルサイズ・並行処理
- アーキテクチャ: Clean Architecture / DDD / SOLID / レイヤー境界 / 循環依存 / API 設計粒度
以下の skill を必ず参照してください:
- `backend-development:architecture-patterns`
- `backend-development:api-design-principles`
```

**security-reviewer 向け追加指示:**
```
あなたは security-reviewer（ローカルのセキュリティ専門 agent）として、OWASP Top 10 観点でレビューします。
`security-scanning:stride-analysis-patterns` skill を必ず参照し、STRIDE 脅威モデリングで
体系的に脅威を洗い出してください。
```

**testing-reviewer 向け追加指示:**
```
あなたは test-coverage-reviewer（ローカルのテスト観点レビュー agent）です。
以下の skill を必ず参照してください:
- `javascript-typescript:javascript-testing-patterns`
- `developer-essentials:e2e-testing-patterns`
テスト網羅性、モック戦略、境界値、E2E のハッピーパス限定ルールを重点的に確認してください。
```

**codex-independent-reviewer 向け追加指示:**
```
あなたは `codex:codex-rescue` agent として、Codex CLI を内部で呼び出し、
他のレビュアー（Claude 専門エージェント、Gemini）の意見に影響されない独立視点を提供します。

Codex 呼び出しのコツは以下の skill を必ず参照:
- `codex:codex-cli-runtime` — codex-companion runtime の呼び出し契約
- `codex:gpt-5-4-prompting` — Codex / GPT-5.4 プロンプト構成法
- `codex:codex-result-handling` — Codex 出力の解釈と整形

TypeScript の型安全性の抜け、Node.js の非同期処理の落とし穴、ESM/CJS 境界、{{ORM}} の癖など、
Claude が見落としやすい点に重点を置いてください。

iteration を跨いで再指示を受けた際は、前回 Codex に何を読ませたか・どう指摘したかを
踏まえて、重複を避けつつ未踏領域を Codex に渡してください。
```

**checklist-advisor 向け追加指示:**
```
あなたは review-checklist-advisor エージェント（チェックリスト監査役）です。
`{{REVIEW_CHECKLIST_PATH}}` を上から全件 Read し、各エントリを順に評価して、
今回の変更差分が各教訓を遵守できているかを 1 項目ずつ点検します。
- 必ず全エントリを一度は評価すること（該当の取りこぼしを最優先で避ける。件数上限なし）
- 該当するエントリについて、守れていれば compliant、守れていなければ violation/needs_check として指摘
- diff だけで判断できない該当は実コードを Read して確認する
- 各 finding には根拠としたエントリのタイトルを含め、出力に checklist_total / checklist_evaluated を入れて全件評価を示す
- 新規の独自観点出しは他レビュアーに任せ、あなたはチェックリスト準拠の網羅点検に専念する
```

**infra-reviewer 向け追加指示（INFRA_REQUIRED=true のときのみ）:**
```
あなたは infra-reviewer（ローカルのインフラ・IaC 専門 agent）として、{{IAC_TOOL}} / {{CLOUD_PROVIDER}} / CI/CD をレビューします。
{{CLOUD_PROVIDER}} 仕様は {{CLOUD_MCP}} の読み取り系で裏取りしてください。
以下の skill を必ず参照してください:
- `cloud-infrastructure:{{IAC_SKILL_PREFIX}}-module-library`
- `cloud-infrastructure:cost-optimization`
- `cicd-automation:github-actions-templates`
- `cicd-automation:secrets-management`
{{IAC_TOOL}} ベストプラクティス、IAM 最小権限、環境変数注入漏れ、コスト影響、
{{IAC_TOOL}} plan で予期しないリソース破棄が発生しないかを重点的に確認してください。
```

---

## 注意事項

- **🚨 cwd をワークスペースルート (`{{WORKSPACE_ROOT}}`) から動かさない**: 設定系ファイル（`{{AGENT_CONFIG_DIR}}/settings.json`、hooks、tool 許可ルール、CLAUDE.md、AGENTS.md など）は**ワークスペースルートにしか存在しない**。サブエージェントや Codex/agy (Gemini) CLI は**起動時の cwd に基づいて設定を探索する**ため、cwd がサブディレクトリ等に汚染された状態でチームを起動すると、settings が読まれず tool 許可・hooks が全て無効化されユーザー運用負荷が激増する。必ず以下を守ること:
  - Phase 1-A で Agent tool / codex / agy を起動する直前に `pwd` で cwd を確認し、`{{WORKSPACE_ROOT}}` 以外なら `cd {{WORKSPACE_ROOT}}` で戻してから起動する
  - Bash 内で `cd apps/web && ...` のような書き方をしない。代わりに `{{PACKAGE_MANAGER}} {{MONOREPO_FILTER_FLAG}} <pkg> ...` を使う（cd 汚染の根本原因を排除）
  - codex CLI は `codex exec --cd {{WORKSPACE_ROOT}} ...` で明示的に cwd 指定する
  - 違反の典型例: iteration の途中で `cd {{FRONTEND_PATH}} && {{TYPE_CHECK_COMMAND}}` を実行 → shell cwd が {{FRONTEND_PATH}} のまま → 次の iteration の Agent tool / codex が {{FRONTEND_PATH}} で起動し settings 無効化
- **🚨 Teammate は iteration を跨いで再利用する**:
  - iteration 1 で Task tool 起動 → iteration 2 以降は SendMessage のみ
  - iteration 間で `Task tool 再起動` / `shutdown_request` / `TeamDelete` を打たない
  - これに違反するとコンテキスト・キャッシュ・ファイル理解がすべてリセットされ、ループ継続の意味が失われる
- **🚨 implement のチームも iteration を跨いで再利用する**:
  - 初回 LARGE_FIX で implement skill を呼んだら、以降の LARGE_FIX は前回の implement Teammate に直接 SendMessage で追加修正依頼
  - implement skill を 2 回以上呼び出さない（毎回新しいチームができてしまう）
  - implement Teammate も Phase 3 まで在籍させ続ける
- **🚨 Low (軽微) 指摘も対応対象**:
  - 「Critical/High/Medium が 0 で Low のみ残存」は **Exit 条件ではない**
  - Low も SMALL_FIX_DIRECT で対応する。対応見送りする場合は理由付きで `final-report.html` に明記する
- **レビューフェーズでは絶対にコードに手を加えない**: Phase 1-A, 1-B は read-only
- **修正はリーダー（Edit）または implement チーム（既存または新規）に限定**: Teammate（レビュアー）には書き込みを行わせない
- **iteration 上限は厳守**: 5 反復に達したら無条件で Phase 2 へ。無限ループ防止
- **収束判定**: 同じ severity 構成が 2 iteration 連続で続き、修正してもこれ以上減らない場合に Phase 2 へ
- **Codex は Teammate として再利用、Gemini はステートレス**:
  - **Codex** は `codex:codex-rescue` agent でラップして Teammate 化したため、他の Claude Teammate と同じく
    iteration 1 で Task tool 起動 → 2+ で SendMessage 再利用。ラッパー側にコンテキストが残る
  - **Gemini** はラッパー agent がないため、毎 iteration `agy -p` を Bash バックグラウンドで再起動
    （prompt.txt 内の `{{PREV_FINDINGS}}` で文脈を運ぶ）
- **CLI 不在時の挙動**: Phase 0-4 で `which codex` / `which agy` を確認し、不在なら該当ロールをスキップ
- **infra-reviewer は条件付き起動**: Phase 0-1 で判定。判定が曖昧なら起動する側に倒す
  - infra-reviewer も他の Claude Teammate と同様、初回起動以降は SendMessage で再利用する
- **修正後の再レビューは必須**: Phase 1-C で修正したら iteration++ で必ず Phase 1-A に戻る
- **commit & push は明示的にユーザーから指示がない限り行わないこと**
- **implement を呼ぶ際の注意**: implement は独自の Phase を持つため、review-loop の iteration が長引く可能性がある。implement 完了後は必ず review-loop 側に戻って再レビューすること。**implement の Teammate を解散させない**
- **対象差分が大きい場合**: 変更差分が 50 ファイル超になる場合は、レビュー対象をサブディレクトリ単位で分割して複数回 review-loop を実行することを検討
- **指示は `instruct.md` 経由、結果は `report.md` 経由でファイルベース通信を行うこと**
- **Teammate 間の直接通信は禁止**: すべてリーダーが仲介
- **Teammate からのメッセージは自動配信**されるため、手動ポーリング不要
- **Teammate が idle になるのは正常な動作**（メッセージ送信後の待機状態。次 iteration の SendMessage を待っている）
