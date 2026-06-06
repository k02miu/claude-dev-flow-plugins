# DevFlow プラグイン

Claude Code 向けのマルチエージェント開発ワークフロー・オーケストレーション。**Agent Teams** を基盤としています。

このディレクトリがインストール対象のプラグイン本体です。完全なドキュメント、ワークフロー概要、変数
リファレンス、エージェント/スキルのカタログは [マーケットプレイスルートの README](../../README.md) を参照してください。

## 構成要素

- **エントリポイントスキル 6 個**: `create-feature-issue`, `resolve-issue`, `branch-finisher`,
  `create-pr`, `review-loop`, `pr-review-loop`
- **サブスキル 8 個**: `implement`, `code-finisher`, `pr-request-review`, `pr-review-respond`,
  `document-follow-up`, `test-follow-up`, `add-storybook`, `screen-ope`
- **エージェント 17 体**（`agents/` 配下）

## 前提条件

- Claude Code v2.0+
- Agent Teams 有効化: あなた自身の設定に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
  （+ `teammateMode: "tmux"`） — プラグインがこれらを設定することはできません
- `gh` CLI 認証済み（`gh auth login`）

## 変数

スキルとエージェントは `{{VARIABLE}}` プレースホルダを使用します。これらはインストール時に自動置換され
**ません**。各スキル/エージェントが実行時に `CLAUDE.md` / `AGENTS.md`（無ければ `package.json` や
リポジトリ調査）から解決します。各ファイルの「変数定義」表はデフォルト例のみを示します。
