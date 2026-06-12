# 変数定義

review-loop SKILL.md / 各テンプレートで使用する {{VARIABLE}} の一覧。実際のプロジェクトの値に置き換えて使用する。

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
