# e2e-test-planner テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
あなたは e2e-test-planner（E2E テスト設計の専門 agent）として、{{E2E_TEST_FRAMEWORK}} の E2E テストを設計します。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/e2e-test-planner/instruct.md`

```
【Issue の内容】
{{ISSUE_CONTENT}}

【参照ドキュメント】
- プロジェクトの E2E テストガイドライン（docs/ 配下など）

【調査手順】
1. コードベース解析ツールで既存 E2E テストの構造を確認
   - 関連するテストファイルを特定
   - 既存テストシナリオの構造を把握
   - 既存の Page Object / テストヘルパーを確認

2. 以下の観点で設計:

   a) 既存 E2E テストへの影響
      - 変更により破壊されるシナリオの特定
      - テストデータのセットアップ変更要否
      - 既存の Page Object の修正要否

   b) 新規 E2E シナリオの設計
      - ユーザーフロー（画面遷移、操作手順）
      - 正常系フロー（主要なハッピーパス）
      - 異常系フロー（バリデーションエラー、権限エラー）
      - 各ロールでの動作確認（該当する場合）

   c) ブラウザ拡張機能等の手動確認（該当する場合）
      - 自動テストが行えない箇所の手動確認項目リストアップ

【結果の JSON 形式】
{
  "role": "e2e_test_planner",
  "affected_tests": [
    {
      "path": "テストファイルパス",
      "impact": "破壊される | 修正が必要 | 影響なし",
      "description": "影響内容"
    }
  ],
  "new_scenarios": [
    {
      "file_path": "新規/既存テストファイルパス",
      "scenario": "シナリオ名",
      "user_flow": [
        "ステップ 1: ...",
        "ステップ 2: ..."
      ],
      "type": "happy_path | error | permission",
      "roles": ["テスト対象のロール"],
      "assertions": ["確認すべきアサーション"]
    }
  ],
  "page_objects": {
    "reusable": ["再利用可能な既存 Page Object"],
    "new_needed": ["新規に作成が必要な Page Object"],
    "modifications": ["修正が必要な既存 Page Object"]
  },
  "manual_checks": [
    {
      "description": "手動確認項目",
      "steps": ["確認手順"],
      "expected": "期待される動作"
    }
  ],
  "acceptance_criteria": [
    "E2E テストの受け入れ条件"
  ]
}
```
