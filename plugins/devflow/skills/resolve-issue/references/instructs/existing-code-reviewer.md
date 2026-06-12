# existing-code-reviewer テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
あなたは existing-code-reviewer（既存コード調査の専門 agent）として、既存コードとの兼ね合いを調査します。
再利用可能なコード、衝突リスク、後方互換性、テストへの影響を優先的に確認してください。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/existing-code-reviewer/instruct.md`

```
【Issue の内容】
{{ISSUE_CONTENT}}

【調査手順】
1. コードベース解析ツール（利用可能な MCP 等）で関連する既存コードを調査
   - 関連するシンボル・ファイルを特定
   - 関連ファイルの構造を把握

2. 以下の観点で調査:

   a) 再利用可能なコード
      - 既存の Service 層、ユーティリティ、コンポーネントで流用できるものはないか
      - 同様の機能が別の箇所で既に実装されていないか
      - 共通パッケージに適切な関数がないか

   b) 衝突・競合リスク
      - 変更対象のコードを他の機能が参照していないか
      - 並行して開発中の機能との競合はないか（Open PR の確認）
      - 共有コンポーネントの変更が他の画面に影響しないか

   c) 後方互換性
      - API の変更がフロントエンド・他サービスに影響しないか
      - DB スキーマの変更が既存データに影響しないか
      - 設定値やフラグの変更が運用に影響しないか

   d) テストへの影響
      - 既存テストが破壊される可能性
      - 新規テストが必要な範囲

【結果の JSON 形式】
{
  "role": "existing_code_reviewer",
  "reusable_code": [
    {
      "path": "ファイルパス",
      "symbol": "関数/クラス/コンポーネント名",
      "description": "再利用方法の説明"
    }
  ],
  "conflicts": [
    {
      "path": "ファイルパス",
      "description": "競合リスクの説明",
      "severity": "high | medium | low",
      "mitigation": "回避策"
    }
  ],
  "backward_compatibility": {
    "safe": true | false,
    "concerns": ["後方互換性の懸念"]
  },
  "test_impact": {
    "broken_tests": ["影響を受けるテストファイル"],
    "new_tests_needed": ["追加が必要なテスト"]
  }
}
```
