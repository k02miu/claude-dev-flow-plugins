# library-researcher テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
利用可能な MCP 検索ツールを主体に、関連ライブラリのドキュメントを検索して調査を行ってください。
既存技術スタックでの実現可能性を最優先に考え、新規ライブラリ導入は慎重に判断すること。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/library-researcher/instruct.md`

```
【Issue の内容】
{{ISSUE_CONTENT}}

【現在の主要技術スタック】
- {{FRONTEND_FRAMEWORK}}
- {{ORM}} + Database
- {{UI_LIBRARY}} + {{CSS_FRAMEWORK}}
- {{STATE_MANAGER}}（状態管理、該当する場合）
- {{AUTH_LIBRARY}}（認証）
- {{E2E_TEST_FRAMEWORK}}（E2E）/ {{UNIT_TEST_FRAMEWORK}}（Unit）
- {{CLOUD_PROVIDER}}
- その他プロジェクト固有の主要ライブラリ

【調査手順】
1. 利用可能な MCP を使って関連ライブラリのドキュメントを検索
   - ライブラリ ID で候補を特定
   - 具体的な使用方法を確認

2. 以下の観点で調査:

   a) 既存技術スタックで実現可能か
      - 現在使用中のライブラリの機能で実現できないか
      - {{UI_LIBRARY}} のコンポーネントで UI 要件を満たせないか

   b) 新規ライブラリの候補
      - Issue の要件を効率的に実現できるライブラリ
      - パッケージレジストリでのダウンロード数、メンテナンス状況、ライセンス
      - フレームワークとの互換性

   c) 導入コスト vs 自前実装コスト
      - ライブラリ導入のメリット・デメリット
      - バンドルサイズへの影響
      - 学習コスト

ライブラリの調査が不要な場合（純粋なビジネスロジック変更など）は、
その旨を報告して完了してください。

【結果の JSON 形式】
{
  "role": "library_researcher",
  "applicable": true | false,
  "existing_stack_solutions": [
    {
      "library": "ライブラリ名",
      "feature": "活用できる機能",
      "usage": "使用方法の概要",
      "doc_url": "ドキュメント URL（MCP で取得した場合）"
    }
  ],
  "new_library_candidates": [
    {
      "name": "ライブラリ名",
      "purpose": "導入目的",
      "pros": ["メリット"],
      "cons": ["デメリット"],
      "bundle_impact": "バンドルサイズへの影響",
      "compatibility": "フレームワークとの互換性",
      "recommendation": "推奨 | 検討 | 非推奨"
    }
  ],
  "recommendation": "最終的な推奨方針"
}
```
