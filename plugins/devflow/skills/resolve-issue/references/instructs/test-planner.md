# test-planner テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
あなたは test-planner（テスト設計の専門 agent）として、instruct.md の scope で指定された範囲のテストを設計します。
単体テストは {{UNIT_TEST_FRAMEWORK}}、E2E テストは {{E2E_TEST_FRAMEWORK}} を使用します。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/test-planner/instruct.md`

```
【scope】
both   # unit（単体のみ）/ e2e（E2E のみ）/ both（両方）。リーダーが Issue 種別に応じて指定。

【Issue の内容】
{{ISSUE_CONTENT}}

【参照ドキュメント】
- プロジェクトの単体テストガイドライン（docs/ 配下など）
- プロジェクトの E2E テストガイドライン（docs/ 配下など）

【調査手順】
scope に含まれる範囲についてのみ設計してください。

■ 単体テスト（scope: unit / both）
1. コードベース解析ツールで既存テストの構造を確認
   - 関連テストファイル・テストケース構造・関連 Service / ユーティリティのテスト
2. 設計観点:
   a) 既存テストへの影響（破壊されるテスト、モック/フィクスチャ更新要否、ヘルパー再利用可否）
   b) 新規テストケース（Service/ユーティリティ、レンダリング、エッジケース、DB モック戦略）
   c) カバレッジ方針（正常系・異常系、境界値、認証認可）

■ E2E テスト（scope: e2e / both）
1. コードベース解析ツールで既存 E2E テストの構造を確認
   - 関連テストファイル・シナリオ構造・Page Object / ヘルパー
2. 設計観点:
   a) 既存 E2E テストへの影響（破壊されるシナリオ、データセットアップ変更要否、Page Object 修正要否）
   b) 新規シナリオ（ユーザーフロー、正常系ハッピーパス、異常系、各ロール動作）
   c) ブラウザ拡張等の手動確認項目（自動テスト不可領域）

【結果の JSON 形式】
{
  "role": "test_planner",
  "scope": "unit | e2e | both",
  "unit": {
    "affected_tests": [
      { "path": "テストファイルパス", "impact": "破壊される | 修正が必要 | 影響なし", "description": "影響内容" }
    ],
    "new_test_cases": [
      {
        "file_path": "新規/既存テストファイルパス",
        "describe": "テストスイート名",
        "cases": [
          { "name": "テストケース名", "type": "normal | error | edge_case | auth", "description": "テスト内容", "mock_needed": ["モックが必要な依存"] }
        ]
      }
    ],
    "test_helpers": { "reusable": ["再利用可能な既存ヘルパー"], "new_needed": ["新規に作成が必要なヘルパー"] }
  },
  "e2e": {
    "affected_tests": [
      { "path": "テストファイルパス", "impact": "破壊される | 修正が必要 | 影響なし", "description": "影響内容" }
    ],
    "new_scenarios": [
      {
        "file_path": "新規/既存テストファイルパス",
        "scenario": "シナリオ名",
        "user_flow": ["ステップ 1: ...", "ステップ 2: ..."],
        "type": "happy_path | error | permission",
        "roles": ["テスト対象のロール"],
        "assertions": ["確認すべきアサーション"]
      }
    ],
    "page_objects": { "reusable": ["再利用可能な既存 Page Object"], "new_needed": ["新規作成が必要な Page Object"], "modifications": ["修正が必要な既存 Page Object"] },
    "manual_checks": [
      { "description": "手動確認項目", "steps": ["確認手順"], "expected": "期待される動作" }
    ]
  },
  "acceptance_criteria": ["テストの受け入れ条件（単体・E2E 共通）"]
}

scope 外のセクションは空配列・空オブジェクトにする。
```
