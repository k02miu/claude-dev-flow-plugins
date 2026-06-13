# DevFlow Infra MCP

DevFlow のインフラ系エージェント（`infra-reviewer` / `architecture-planner`）向けの
**クラウド知識 MCP サーバー** をまとめたオプションプラグインです。

クラウドインフラを扱わないプロジェクトでは不要なため、devflow 本体とは分離しています。
必要なユーザーだけがインストールしてください。

## 同梱 MCP サーバー

| サーバー | 提供元 | 用途 | ランタイム要件 |
|----------|--------|------|----------------|
| `google-developer-knowledge` | Google（HTTP） | GCP 公式ドキュメント・ベストプラクティス検索 | なし（HTTP）。API キー必須（下記） |
| `azure` | Microsoft（`@azure/mcp`） | Azure リソース・ドキュメント操作 | Node.js（`npx`）、`az login` |
| `aws-knowledge` | AWS（HTTP） | AWS 公式ドキュメント・API リファレンス検索（[AWS Knowledge MCP Server](https://awslabs.github.io/mcp/servers/aws-knowledge-mcp-server)） | なし（HTTP）。認証不要 |

> **AWS は「知識系」の Knowledge MCP Server を採用しています。** 認証不要・AWS アカウント不要で
> 公式ドキュメントを検索できます（レート制限あり）。実リソースの状態確認（`describe` / `list` 等）まで
> 行いたい場合は、AWS 認証情報が必要な操作系 MCP（`mcp-proxy-for-aws`）に各自で差し替えてください。
>
> Terraform（HashiCorp 公式 `terraform-mcp-server`）は Docker またはバイナリ導入が必要なため
> 現時点では同梱していません。必要な場合はプロジェクト側の `.mcp.json` に追加してください。

## インストール

```shell
/plugin marketplace add k02miu/claude-dev-flow-plugins
/plugin install devflow-infra-mcp@k02miu-devflow
```

## 必要な環境変数

| 変数 | 必須 | 説明 |
|------|------|------|
| `GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY` | GCP 検索を使う場合 | Google Developer Knowledge API のキー |

`aws-knowledge` は認証不要です。`azure` は実行環境の Azure 認証情報（`az login`）を使用します。

## DevFlow との関係

devflow 本体のエージェントは `{{MCP_DOC_SEARCH}}` / `{{MCP_CLOUD_CLI}}` という抽象参照で
クラウド知識 MCP を「あれば使う」設計になっています。本プラグインを導入すると、
これらのツールが `mcp__plugin_devflow-infra-mcp_*` 名前空間で利用可能になり、
infra-reviewer がクラウド公式ドキュメントで仕様・制約・ベストプラクティスの裏取りを行えるようになります。

## ライセンス

MIT
