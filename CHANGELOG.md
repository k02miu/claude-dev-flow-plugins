# Changelog

## devflow 1.2.0 (2026-06-13)

### Changed
- **サブエージェントの同時起動数を削減（性能は維持）**: `create-feature-issue` / `resolve-issue` で、タスク種別判定の結果を実際の起動に反映。不要と判定した観点は起動・タスク作成しないように変更（従来は全観点を起動して「対象外」報告で完了させていた無駄を解消）。判断に迷う観点は安全側で起動するため網羅性は維持。Phase 1 の同時並列は最大 7 → 6 体、種別により 3〜5 体に
- **テスト設計エージェントの統合**: `unit-test-planner` + `e2e-test-planner` を `test-planner`（`scope` で unit / e2e / both を指定）へ統合。`test-follow-up` は `scope=unit` で起動
- **`implement` の設計レビュー条件化**: owner zone が 1 つ（小〜中規模）の場合は Phase 1-3 の設計レビュー（`code-architecture-reviewer`）をスキップし、複数 zone の大規模時のみ実施
- **`create-pr` / `create-feature-issue` の可読性改善**: 冗長な強調・迂遠な表現・本文の重複を整理。生成する PR / Issue 本文向けに「簡潔・エンジニア向け・絵文字なし・一文を短く」のトーン方針を明示（手順・構造・変数・エージェント名は不変）

### Removed
- エージェント `unit-test-planner` / `e2e-test-planner`（`test-planner` に統合、専門エージェント 17 → 16 体）

## devflow 1.1.0 / devflow-infra-mcp 1.0.0 (2026-06-13)

### Added
- **MCP 同梱（devflow）**: `context7`（ライブラリドキュメント検索）と `serena`（セマンティックコード検索）を `.mcp.json` で同梱。`library-researcher` / `existing-code-reviewer` 等のエージェントが同梱 MCP をデフォルトで参照するように具体化
- **新プラグイン `devflow-infra-mcp`**: AWS / Azure / Google Cloud の知識 MCP サーバーをまとめたオプションプラグイン（インフラ系エージェント向け）
- **`review-loop/scripts/diff-summary.sh`**: 変更差分サマリ（CHANGED_FILES / DIFF_SUMMARY）を決定論的に生成するスクリプト
- 各スキルに `argument-hint` と読み取り専用コマンドの `allowed-tools` を追加

### Changed
- **Progressive Disclosure 化**: `resolve-issue`（1,325→482行）、`review-loop`（1,230→499行）、`implement`（590→475行）、`create-feature-issue`（460→353行）の Teammate instruct テンプレート群を各スキルの `references/` に分離。SKILL.md は全スキル500行以下に
- **エージェントのツール制限**: レビュー・調査・統合系の16エージェントに `disallowedTools: Edit, NotebookEdit` を追加（読み取り専用の宣言を frontmatter で強制）
- `implementer` の git 操作制約を明文化（状態変更系の git コマンドを全面禁止、読み取り系のみ許可）
- スキル description から未置換のテンプレート変数（`{{PR_REVIEWER_MODEL_NAMES}}` 等)を除去し、`review-loop` / `implement` の description をトリガー判定情報に短縮

### Safety
- `pr-review-loop` / `pr-review-respond`: push 前の保護ブランチチェック（デフォルトブランチ・main / master / develop への push を拒否）、rebase コンフリクト時は `git rebase --abort` で復旧して中断、force push 禁止を明文化
- `implement`: DB マイグレーションの自動実行を禁止し、ユーザー確認を必須化

## devflow 1.0.0

- 初回リリース: マーケットプレイス + devflow プラグイン（スキル14個・エージェント17体）
