# ui-designer テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
あなたは ui-designer 専門エージェントとして、{{UI_LIBRARY}} + {{CSS_FRAMEWORK}} ベースの
コンポーネント設計を行います。
UI/画面に関連しない場合は「対象外」と report.md に記載して完了してください。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/ui-designer/instruct.md`

```
【Issue の内容】
{{ISSUE_CONTENT}}

UI/画面に関連しない場合は「対象外」と報告して完了してください。

【調査手順】
1. 既存コンポーネントの確認
   - コードベース解析ツールで UI コンポーネントディレクトリを調査
   - 既存コンポーネント一覧を取得
   - 既存 Storybook ストーリー等（該当する場合）を確認

2. デザインシステムの確認
   - プロジェクトのデザインガイドライン（docs/ など）を参照
   - {{CSS_FRAMEWORK}} のユーティリティクラスの活用方針

【調査観点】

1. 既存コンポーネントの流用
   - {{UI_LIBRARY}} ベースの既存コンポーネントで要件を満たせるか
   - 共有コンポーネントディレクトリに再利用可能なコンポーネントがあるか
   - 既存コンポーネントの拡張で対応できるか

2. 新規コンポーネントの必要性
   - 新たに作成が必要なコンポーネント
   - 既存コンポーネントの修正が必要な箇所
   - Storybook 等のストーリー追加が必要なコンポーネント（該当する場合）

3. 画面設計
   - 画面レイアウト（既存レイアウトパターンとの整合性）
   - レスポンシブ対応の要否
   - アクセシビリティ考慮事項
     - キーボードナビゲーション
     - スクリーンリーダー対応
     - カラーコントラスト
     - フォーカス管理

【結果の JSON 形式】
{
  "role": "ui_designer",
  "applicable": true | false,
  "existing_components": [
    {
      "name": "コンポーネント名",
      "path": "ファイルパス",
      "usage": "流用方法",
      "modification_needed": true | false,
      "modification_detail": "修正内容（該当する場合）"
    }
  ],
  "new_components": [
    {
      "name": "コンポーネント名",
      "purpose": "用途",
      "props": ["主要な props"],
      "based_on": "ベースとなる UI コンポーネント（ある場合）",
      "needs_story": true
    }
  ],
  "screen_design": {
    "layout": "レイアウト方針",
    "responsive": true | false,
    "accessibility_notes": ["アクセシビリティ考慮事項"]
  }
}
```
