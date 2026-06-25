# Claude Code DevFlow Plugin

Claude Code 向けの **マルチエージェント開発ワークフロー・オーケストレーション** プラグインです。

Claude Code の **Agent Teams** 機能を活用し、複数エージェントによる並列の計画・実装・レビュー・PR 管理という一連の開発ワークフローを提供します。

## 必要要件

- **Claude Code**（v2.1.178+） — implicit team モデル（`TeamCreate` 無しで Teammate を起動）に必要。`npm install -g @anthropic-ai/claude-code` 等で導入
- **Agent Teams** — `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` が必要（v2.1.178 時点でも experimental・デフォルト無効）
- **gh CLI**（GitHub CLI） — `gh auth login` で認証済みであること
- **teammateMode**（任意） — 既定 `"in-process"` で任意の端末で動作。Teammate をペイン分割表示したい場合のみ `"tmux"`（tmux / iTerm2 が必要）
- **同梱 MCP のランタイム** — Node.js（`npx` — context7 用）、Python + uv（`uvx` — serena 用）

## リポジトリ構成（マーケットプレイス + プラグイン）

このリポジトリ自体が Claude Code のプラグインマーケットプレイスです。2 つのプラグインをホストします:

```
<repo>/
├── .claude-plugin/
│   └── marketplace.json          # マーケットプレイスカタログ（このリポジトリ）
└── plugins/
    ├── devflow/                  # 本体プラグイン
    │   ├── .claude-plugin/
    │   │   └── plugin.json       # devflow プラグインのマニフェスト
    │   ├── .mcp.json             # 同梱 MCP サーバー（context7 / serena）
    │   ├── agents/               # 専門サブエージェント 16 体
    │   ├── skills/               # スキル 14 個（エントリ 6 + サブ 8）
    │   │   └── <skill>/
    │   │       ├── SKILL.md      # 手順本体（500 行以下）
    │   │       ├── references/   # instruct テンプレート等（実行時に段階的に Read）
    │   │       └── scripts/      # 決定論的な補助スクリプト
    │   └── .github/              # Issue/PR テンプレート見本（プロジェクト側の参考）
    └── devflow-infra-mcp/        # オプション: クラウド知識 MCP（AWS / Azure / GCP）
```

## MCP 統合

`devflow` は以下の MCP サーバーを同梱しており、プラグインを有効化すると自動的に利用可能になります:

| サーバー | 用途 | 主な利用エージェント |
|----------|------|----------------------|
| `context7` | ライブラリ最新ドキュメント検索 | `library-researcher` |
| `serena` | セマンティックコード検索（シンボル・参照関係） | `existing-code-reviewer`, `code-architecture-reviewer`, `architecture-planner` |

インフラ調査を強化したい場合は、オプションプラグイン **`devflow-infra-mcp`** を追加インストールしてください
（AWS / Azure / Google Cloud の知識 MCP。GCP は `GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY` 環境変数が必要）:

```shell
/plugin install devflow-infra-mcp@k02miu-devflow
```

## インストール

### この GitHub マーケットプレイスから
```shell
# 1. マーケットプレイスを登録（owner/repo 短縮形）
/plugin marketplace add k02miu/claude-dev-flow-plugins

# 2. プラグインをインストール
/plugin install devflow@k02miu-devflow
```

> このリポジトリ（`k02miu/claude-dev-flow-plugins`）からインストールされます。`k02miu-devflow` は
> `.claude-plugin/marketplace.json` で宣言されたマーケットプレイス `name` です。

### ローカル検証（公開前）
```shell
# ローカルチェックアウトをマーケットプレイスとして追加してインストール
/plugin marketplace add ./           # リポジトリルートで実行
/plugin install devflow@k02miu-devflow
```

### 共有前の検証
```bash
claude plugin validate .                     # marketplace.json を検証
claude plugin validate ./plugins/devflow     # プラグイン + frontmatter を検証
```

## ワークフロー概要

本プラグインは **6 つの統合ワークフローステージ** を提供します:

| # | ステージ | 概要 |
|---|----------|------|
| 1 | `create-feature-issue` | 最大 8 エージェントチーム → GitHub Issue |
| 2 | `resolve-issue` | 最大 8 エージェントチーム → 実装 |
| 3 | `branch-finisher` | 5 ステップ品質ゲート |
| 4 | `review-loop` | マルチ LLM × 最大 5 反復レビュー |
| 5 | `create-pr` | 自動入力 PR |
| 6 | `pr-review-loop` | 4 LLM 自動修正収束 |

### 1. `/create-feature-issue <説明>`
複数エージェントによる調査を伴って GitHub Issue を作成します:
- **Phase 1**（並列・該当観点のみ）: 最大 6 体の専門エージェントがアーキテクチャ・既存コード・ライブラリ・セキュリティ・UI・テスト（単体 + E2E）を調査
- **Phase 2**: 調査結果を Issue ドラフトに統合
- **Phase 3**: Issue ドラフトのレビュー
- **出力**: 包括的な実装プランを含む GitHub Issue

### 2. `/resolve-issue <issue 番号>`
Agent Teams を使って GitHub Issue を解決します:
- create-feature-issue と同じ 3 フェーズ構造
- **Phase 1**: 最大 6 エージェントによる並列調査（該当観点のみ起動）
- **Phase 2**: Mermaid 図を含む実装プラン
- **Phase 3**: プランレビュー
- **Phase 4**: 自律的な実装
- **出力**: 現在のブランチへのコード変更

### 3. `/branch-finisher [親ブランチ]`
PR 作成前のブランチ品質ゲート:
1. **document-follow-up**: ドキュメントをコード変更に同期
2. **add-storybook**: 変更コンポーネントの Storybook ストーリーを追加
3. **test-follow-up**: テストをコード変更に同期
4. **code-finisher**: 型チェック・Lint・テスト実行
5. **screen-ope**: 画面/動作の目視確認

### 4. `/review-loop [スコープ]`
回帰的なマルチ LLM コードレビューループ:
- **最大 5 反復** のレビュー → 修正 → 再レビュー
- **専門レビュアー**（ローカルエージェント。1 度だけ起動し反復間で再利用）: `code-architecture-reviewer`, `security-reviewer`, `test-coverage-reviewer`, `review-checklist-advisor`, `infra-reviewer`（インフラ/IaC 変更時のみ）
- **マルチ LLM**: Claude + Codex + Gemini の独立した視点
- **Low（軽微）指摘も対応** — 黙ってスキップしない
- **終了条件**: 全 OK・収束・最大反復到達

### 5. `/create-pr [issue 番号または説明]`
以下を行って Pull Request を作成します:
- ブランチの自動分析とベースブランチ検出
- 関連 Issue の検出
- PR テンプレートの記入
- サブエージェントによる PR 本文レビュー
- 作成後の **マルチ LLM レビュー依頼**

### 6. `/pr-review-loop [PR 番号]`
PR レビューの自動収束ループ:
- **マルチ LLM レビュー**: Copilot, Claude, Codex, Gemini
- **自動修正**: 各ラウンドで自律的に commit & push
- **収束**: 有意な指摘を出さなくなったモデルをループから除外
- **安全策**: 最大 10 反復・タイムアウトガード

## プロジェクト / ユーザー設定

プラグインは環境変数や `teammateMode` をあなたの代わりに設定できません。これらは **あなた自身の**
`~/.claude/settings.json`（ユーザースコープ）またはプロジェクトの `.claude/settings.json` に記述する必要があります。
必須は `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` のみ。`teammateMode` は任意で、既定の `"in-process"` なら追加ツール不要です:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "in-process"
}
```

### チーム開発での推奨: settings.json をリポジトリにコミット

チーム開発（特に devcontainer 運用）では、各メンバーが `/plugin install` を打つ必要がないよう、
プロジェクトの `.claude/settings.json` をリポジトリにコミットして配布するのが推奨です。
フォルダを信頼した時点でマーケットプレイス登録とプラグイン有効化が自動で行われます:

```json
{
  "extraKnownMarketplaces": {
    "k02miu-devflow": {
      "source": { "source": "github", "repo": "k02miu/claude-dev-flow-plugins" }
    }
  },
  "enabledPlugins": {
    "devflow@k02miu-devflow": true,
    "devflow-infra-mcp@k02miu-devflow": true
  }
}
```

- `enabledPlugins` のキーは `プラグイン名@マーケットプレイス名` 形式（マーケットプレイス名は
  `marketplace.json` の `name` = `k02miu-devflow`。GitHub のリポジトリパスではありません)
- クラウドインフラを扱わないプロジェクトでは `devflow-infra-mcp` の行を省きます
- 完全な見本: [`plugins/devflow/.github/example-project-settings.json`](plugins/devflow/.github/example-project-settings.json)

### devcontainer での注意点

- コンテナイメージに以下を含めてください: **Node.js**（`npx` — context7 / Azure MCP 用）、
  **uv**（`uvx` — serena / AWS MCP 用）、**gh CLI**。**tmux** は任意（`teammateMode: "tmux"` でペイン分割する場合のみ）
- `GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY` などのシークレットは settings.json にコミットせず、
  devcontainer の `remoteEnv` / secrets 機構やホスト側の環境変数で注入してください

### 併用: Agent Teams ヘルパースキル

すべてのワークフローは **Agent Teams** を基盤とし、`agent-teams:*` 名前空間のヘルパースキル
（例: `agent-teams:team-communication-protocols`, `agent-teams:task-coordination-strategies`）を参照します。
これらの参照は存在しなくても緩やかに劣化します（「… 相当の skill を参照」）が、完全な動作のためには
該当スキルを提供する Agent Teams プラグイン/機能を導入してください。DevFlow はこれに対する厳密な
`dependencies` を宣言していないため、当該プラグインが無くてもインストールが失敗することはありません。

## カスタマイズ

本プラグインはエージェント間で `.cache/` ディレクトリを介した **ファイルベースの通信** を行います。
各ワークフローステージは独自の名前空間を作成します:

| ワークフロー | キャッシュパス |
|--------------|----------------|
| create-feature-issue | `.cache/c-f-i-t/{{TASK_SLUG}}/` |
| resolve-issue | `.cache/r-i-t/{{TASK_SLUG}}/` |
| branch-finisher | `.cache/branch-finisher-report.md` |
| review-loop | `.cache/review-loop/{{TASK_SLUG}}/` |

### テンプレート変数

コマンド・スキル・エージェントは `{{VARIABLE}}` プレースホルダを使用し、任意の技術スタックに適応できます。
プロジェクトに合わせて（`CLAUDE.md` / `AGENTS.md` あるいは置換で）値を埋めてください。各コマンド/スキル/
エージェントのファイルにも、使用する変数のサブセットを `## 変数定義` の表として記載しています。

**プロジェクト & ツール**

| 変数 | 説明 | デフォルト例 |
|------|------|--------------|
| `{{PLUGIN_NAME}}` | プラグイン名 | `devflow` |
| `{{REPO_URL}}` | GitHub リポジトリ URL（`gh` で自動検出） | `https://github.com/org/repo.git` |
| `{{PACKAGE_MANAGER}}` | パッケージマネージャ | `pnpm` |
| `{{MONOREPO_TOOL}}` / `{{MONOREPO_FILTER_FLAG}}` | モノレポツール / フィルタフラグ | `turborepo` / `--filter` |
| `{{AGENT_CONFIG_DIR}}` | エージェント設定ディレクトリ | `.claude` |
| `{{CACHE_DIR}}` | エージェント間キャッシュディレクトリ | `.cache` |
| `{{WORKSPACE_ROOT}}` | ワークスペースルート | `/workspace` |

**フレームワーク & ライブラリ**

| 変数 | 説明 | デフォルト例 |
|------|------|--------------|
| `{{FRONTEND_FRAMEWORK}}` | 主要な Web/フロントエンドフレームワーク | `next.js` |
| `{{BACKEND_FRAMEWORK}}` | バックエンドフレームワーク | `hono` |
| `{{ORM}}` | ORM / DB レイヤー | `prisma` |
| `{{CSS_FRAMEWORK}}` | CSS フレームワーク | `tailwind css` |
| `{{UI_LIBRARY}}` | UI コンポーネントライブラリ | `shadcn/ui` |
| `{{COMPONENT_CATALOG}}` | コンポーネントカタログツール | `storybook` |

**テスト & 品質コマンド**

| 変数 | 説明 | デフォルト例 |
|------|------|--------------|
| `{{UNIT_TEST_FRAMEWORK}}` | 単体テストフレームワーク | `vitest` |
| `{{E2E_TEST_FRAMEWORK}}` | E2E テストフレームワーク | `playwright` |
| `{{LINTER}}` | リンター / フォーマッタ | `biome` |
| `{{TYPE_CHECK_COMMAND}}` / `{{LINT_COMMAND}}` | 型チェック / Lint コマンド | `pnpm check-types` / `pnpm biome:fix` |
| `{{TEST_COMMAND}}` / `{{E2E_TEST_COMMAND}}` | 単体 / E2E テストコマンド | `pnpm test` / `pnpm test:e2e` |
| `{{REPORT_GENERATOR}}` | HTML レポート生成スクリプト（任意） | `report-gen` |
| `{{REVIEW_CHECKLIST_PATH}}` | レビューチェックリストのパス | `docs/developments/review-check-list.md` |

**インフラ & クラウド**

| 変数 | 説明 | デフォルト例 |
|------|------|--------------|
| `{{IAC_TOOL}}` | Infrastructure as Code ツール | `terraform` |
| `{{IAC_PATH}}` / `{{IAC_EXT}}` / `{{IAC_VARS_EXT}}` | IaC ディレクトリ / 拡張子 / vars 拡張子 | `terraform/` / `tf` / `tfvars` |
| `{{CLOUD_PROVIDER}}` | クラウドプロバイダ | `gcp` |
| `{{CLOUD_SERVICES}}` | 利用中のクラウドサービス | `Cloud Run, Cloud SQL, Cloud Tasks` |

**MCP 連携（任意）**

| 変数 | 説明 | デフォルト例 |
|------|------|--------------|
| `{{MCP_CODE_SEARCH}}` | コード検索 / インテリジェンス MCP | `serena mcp` |
| `{{MCP_LIBRARY_DOCS}}` | ライブラリドキュメント検索 MCP | `context7 mcp` |
| `{{MCP_DOC_SEARCH}}` | クラウドドキュメント検索 MCP | `google-developer-knowledge mcp` |
| `{{MCP_CLOUD_CLI}}` | クラウド CLI MCP（読み取り専用） | `gcloud mcp` |
| `{{MCP_FRONTEND_TOOLS}}` | フロントエンド devtools MCP | `next-devtools mcp` |

**レビューモデル**

| 変数 | 説明 | デフォルト例 |
|------|------|--------------|
| `{{PR_REVIEWER_MODEL_NAMES}}` | PR レビュアーのモデル名 | `GitHub Copilot / Claude / Codex / Gemini` |

## エージェント

本プラグインは **16 体の専門エージェント** を含みます:

| エージェント | 役割 |
|--------------|------|
| `architecture-planner` | アーキテクチャ設計、データフロー、レイヤー設計、インフラ/IaC |
| `business-requirement-reviewer` | ビジネス要件分析 *（単独利用 — ワークフローには自動接続されない。`devflow:business-requirement-reviewer` として手動起動）* |
| `code-architecture-reviewer` | コード品質、パフォーマンス、アーキテクチャレビュー |
| `docs-synthesizer` | ドキュメント生成 |
| `existing-code-reviewer` | 再利用可能コード、コンフリクトリスク、後方互換性 |
| `implementer` | 複数ファイル実装オーケストレータ |
| `infra-reviewer` | Terraform、CI/CD、Docker、クラウドインフラ |
| `issue-reviewer` | Issue/プランドラフトのレビュー |
| `library-researcher` | ライブラリ調査 |
| `opinion-integrator` | 複数レビュアーの意見統合 |
| `plan-integrator` | 複数エージェントのプラン集約 |
| `review-checklist-advisor` | レビューチェックリスト検証 |
| `security-reviewer` | OWASP、STRIDE、セキュリティレビュー |
| `test-coverage-reviewer` | テストカバレッジ分析 |
| `test-planner` | テスト設計（単体 + E2E、scope 指定） |
| `ui-designer` | UI コンポーネント設計 |

## スキル

本プラグインは以下の **スキル** を含みます（Skill ツールまたはコマンドから起動）:

| スキル | 役割 |
|--------|------|
| `implement` | 複数ファイルのフルスタック実装チーム（`implementer` を並列ゾーンで起動） |
| `code-finisher` | 品質ゲート: 型チェック、Lint、単体/E2E テスト実行 |
| `review-loop` | 回帰的なマルチ LLM コードレビュー → 修正 → 再レビューループ |
| `pr-request-review` | PR に対し 4 つの LLM レビュアーへ並列レビューを依頼 |
| `pr-review-respond` | PR レビューコメントを分析・修正・返信（`opinion-integrator` を統合） |
| `pr-review-loop` | PR レビュー → 修正 → 再レビューの自動収束ループ |
| `document-follow-up` | コード変更とドキュメントの乖離を検出・修正 |
| `test-follow-up` | ブランチ変更に対する不足/陳腐化/孤立テストを検出 |
| `add-storybook` | 変更 UI コンポーネントの Storybook ストーリーを追加/更新 |
| `screen-ope` | 変更画面の特定、テスト計画作成、任意のブラウザ検証 |

## ライセンス

MIT
