# unit-test-planner テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
あなたは unit-test-planner（単体テスト設計の専門 agent）として、{{UNIT_TEST_FRAMEWORK}} の単体テストを設計します。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/unit-test-planner/instruct.md`

```
【Issue の内容】
{{ISSUE_CONTENT}}

【参照ドキュメント】
- プロジェクトのテストガイドライン（docs/ 配下など）

【調査手順】
1. コードベース解析ツールで既存テストの構造を確認
   - 関連するテストファイルを特定
   - 既存テストファイルのテストケース構造を把握
   - 関連する Service 層やユーティリティのテストを確認

2. 以下の観点で設計:

   a) 既存テストへの影響
      - 変更により破壊されるテストの特定
      - テストデータ（モック/フィクスチャ）の更新要否
      - 既存テストヘルパーの再利用可否

   b) 新規テストケースの設計
      - Service 層 / ユーティリティ関数の単体テスト
      - コンポーネントのレンダリングテスト（該当する場合）
      - エッジケース・エラーハンドリングのテスト
      - DB 操作を含む場合のモック戦略

   c) テストカバレッジ方針
      - 正常系・異常系のカバレッジ
      - 境界値テスト
      - 認証・認可のテスト（該当する場合）

【結果の JSON 形式】
{
  "role": "unit_test_planner",
  "affected_tests": [
    {
      "path": "テストファイルパス",
      "impact": "破壊される | 修正が必要 | 影響なし",
      "description": "影響内容"
    }
  ],
  "new_test_cases": [
    {
      "file_path": "新規/既存テストファイルパス",
      "describe": "テストスイート名",
      "cases": [
        {
          "name": "テストケース名",
          "type": "normal | error | edge_case | auth",
          "description": "テスト内容",
          "mock_needed": ["モックが必要な依存"]
        }
      ]
    }
  ],
  "test_helpers": {
    "reusable": ["再利用可能な既存ヘルパー"],
    "new_needed": ["新規に作成が必要なヘルパー"]
  },
  "acceptance_criteria": [
    "単体テストの受け入れ条件"
  ]
}
```
