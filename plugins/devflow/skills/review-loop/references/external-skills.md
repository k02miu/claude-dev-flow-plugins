# 参照すべき外部 skill（プロセス知識ベース）

SKILL.md は「何をするか」のみを定義し、**「どうやるか」の詳細は以下の skill に委譲**する。
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
