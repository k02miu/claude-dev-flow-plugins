# architecture-planner テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
Issue の要件を満たす実装アーキテクチャを設計します。あわせてインフラ要否・IaC（{{IAC_TOOL}}/{{CLOUD_PROVIDER}}）設計・環境変数注入先・CI/CD 影響・コスト影響も判定してください（専用の infra-reviewer は廃止し、本ロールが兼任します）。
{{CLOUD_PROVIDER}} リソース・サービス仕様・制約・料金は推測せず、利用可能な MCP（公式ドキュメント検索）と読み取り系 CLI で裏取りしてください。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/architecture-planner/instruct.md`

```
【Issue の内容】
{{ISSUE_CONTENT}}

【このプロジェクトの構成】
（プロジェクトのディレクトリ構成をここに記述。例: apps/web, packages/database, packages/domain 等）
- フロントエンドレイヤー:
- バックエンド/API レイヤー:
- データベース/ORM レイヤー:
- ドメインロジック:
- インフラレイヤー:

【調査手順】
1. コードベース解析ツール（利用可能な MCP 等）で既存のアーキテクチャを確認
   - 関連するファイル・クラス・関数を特定
   - プロジェクトのアーキテクチャドキュメントを参照（docs/ 配下など）
   - API エンドポイント定義を参照
   - DB スキーマ定義を参照

2. 以下の観点で設計を行う:
   - 変更/追加するファイル一覧（パスと役割）
   - データフロー（入力 → 処理 → 出力）
   - レイヤー構成（API Route → Service → Database）
   - DB スキーマ変更の有無（変更がある場合はマイグレーション方針も）
   - 後方互換性への影響
   - Clean Architecture / DDD 観点でのレイヤー境界の妥当性（該当する場合）

3. DB 変更がある場合:
   - ORM スキーマファイルを確認
   - 既存データのマイグレーション戦略
   - 後方互換性を保てるか（破壊的変更の有無）

4. インフラ要否・IaC 設計:
   - クラウドリソース変更の要否（新規サービス利用・既存設定変更・IAM/ネットワーク・非同期キュー/ジョブ追加）
   - {{IAC_TOOL}} 等の IaC 変更（インフラディレクトリのファイルを Read）
   - 環境変数の追加と全実行サービスへの注入先
   - CI/CD 影響・概算コスト影響
   - クラウド仕様確認は利用可能な MCP、現行リソース確認は読み取り系 CLI で裏取り（書き込み系は実行しない）
   - インフラ変更が不要なら `infra.needed: false` と明記

【結果の JSON 形式】
{
  "role": "architecture_planner",
  "design": {
    "overview": "アーキテクチャ概要",
    "affected_files": [
      {
        "path": "ファイルパス",
        "action": "create | modify | delete",
        "description": "変更内容"
      }
    ],
    "data_flow": "データフローの説明",
    "layer_design": "レイヤー構成の説明",
    "db_changes": {
      "needed": true | false,
      "migrations": ["マイグレーション内容"],
      "backward_compatible": true | false,
      "breaking_changes": ["破壊的変更の説明（ある場合）"]
    },
    "infra": {
      "needed": true | false,
      "cloud_changes": [
        { "service": "サービス名", "action": "create | modify | delete", "description": "変更内容", "cost_impact": "概算コスト影響" }
      ],
      "iac_changes": [
        { "resource": "リソース名", "action": "create | modify | delete", "description": "変更内容", "file": "対象ファイル" }
      ],
      "env_vars": [
        { "name": "環境変数名", "action": "add | modify | delete", "description": "用途", "injection_targets": ["注入先ファイル/サービス"] }
      ],
      "cicd_changes": ["CI/CD 変更内容"]
    },
    "estimated_complexity": "small | medium | large",
    "risks": ["リスク・懸念事項"]
  }
}
```
