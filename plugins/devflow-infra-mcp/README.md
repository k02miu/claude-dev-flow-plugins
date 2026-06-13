# DevFlow Infra MCP

DevFlow のインフラ系エージェント（`infra-reviewer` / `architecture-planner`）向けの
**クラウド知識 MCP サーバー** をまとめたオプションプラグインです。

クラウドインフラを扱わないプロジェクトでは不要なため、devflow 本体とは分離しています。
必要なユーザーだけがインストールしてください。

## 同梱 MCP サーバー

| サーバー | 提供元 | 用途 | ランタイム要件 |
|----------|--------|------|----------------|
| `google-developer-knowledge` | Google（HTTP） | GCP 公式ドキュメント・ベストプラクティス検索 | なし（HTTP）。API キー必須（下記） |
| `azure` | Microsoft（`@azure/mcp`） | Azure リソース・ドキュメント操作 | Node.js（`npx`） |
| `aws` | AWS（`mcp-proxy-for-aws`） | AWS MCP（マネージドエンドポイント）への接続 | Python（`uvx`）、AWS 認証情報 |

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
| `AWS_REGION` | 任意 | AWS MCP のメタデータに使用（未設定時 `us-west-2`） |

AWS サーバーは実行環境の AWS 認証情報（`aws configure` / SSO 等）を使用します。

## DevFlow との関係

devflow 本体のエージェントは `{{MCP_DOC_SEARCH}}` / `{{MCP_CLOUD_CLI}}` という抽象参照で
クラウド知識 MCP を「あれば使う」設計になっています。本プラグインを導入すると、
これらのツールが `mcp__plugin_devflow-infra-mcp_*` 名前空間で利用可能になり、
infra-reviewer が公式ドキュメントの裏取りと実環境の読み取り確認を行えるようになります。

## ライセンス

MIT
