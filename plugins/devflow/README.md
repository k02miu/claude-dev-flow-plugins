# DevFlow プラグイン

Claude Code 向けのマルチエージェント開発ワークフロー・オーケストレーション。**Agent Teams** を基盤としています。

このディレクトリがインストール対象のプラグイン本体です。完全なドキュメント、ワークフロー概要、変数
リファレンス、エージェント/スキルのカタログは [マーケットプレイスルートの README](../../README.md) を参照してください。

## 構成要素

- **エントリポイントスキル 6 個**: `create-feature-issue`, `resolve-issue`, `branch-finisher`,
  `create-pr`, `review-loop`, `pr-review-loop`
- **サブスキル 8 個**: `implement`, `code-finisher`, `pr-request-review`, `pr-review-respond`,
  `document-follow-up`, `test-follow-up`, `add-storybook`, `screen-ope`
- **エージェント 16 体**（`agents/` 配下）
- **同梱 MCP サーバー 2 個**（`.mcp.json`）: `context7`（ライブラリドキュメント検索 —
  `library-researcher` が使用）、`serena`（セマンティックコード検索 — `existing-code-reviewer` /
  `code-architecture-reviewer` / `architecture-planner` が使用）

各スキルは `SKILL.md`（手順）+ `references/`（Teammate 向け instruct テンプレート等、実行時に必要な
段階で Read される）+ `scripts/`（決定論的な補助スクリプト）で構成されます。

## 前提条件

- Claude Code v2.0+
- Agent Teams 有効化: あなた自身の設定に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
  （+ `teammateMode: "tmux"`） — プラグインがこれらを設定することはできません
- `gh` CLI 認証済み（`gh auth login`）
- 同梱 MCP サーバーのランタイム: Node.js（`npx` — context7 用）、Python + uv（`uvx` — serena 用）。
  無い環境では該当 MCP の起動に失敗しますが、各エージェントは Grep/Glob / WebSearch にフォールバックします

## オプション: devflow-infra-mcp

インフラ系エージェント（`infra-reviewer` / `architecture-planner`）でクラウド公式知識を使いたい場合は、
同じマーケットプレイスの [`devflow-infra-mcp`](../devflow-infra-mcp/README.md)（AWS / Azure / Google Cloud
の知識 MCP）を追加インストールしてください。

## 変数

スキルとエージェントは `{{VARIABLE}}` プレースホルダを使用します。これらはインストール時に自動置換され
**ません**。各スキル/エージェントが実行時に `CLAUDE.md` / `AGENTS.md`（無ければ `package.json` や
リポジトリ調査）から解決します。各ファイルの「変数定義」表はデフォルト例のみを示します。
