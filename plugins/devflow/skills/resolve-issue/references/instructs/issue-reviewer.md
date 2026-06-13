# issue-reviewer テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```

あなたは issue-reviewer（プロジェクト専用のレビュー agent）として、今回は **plan-integrator が作成した実装プラン** を
レビュー対象とします（Issue ドラフトではなく実装プランをレビューする点に注意）。
Clean Architecture / DDD / SOLID 観点と、受け入れ条件・実装方針の具体性・技術的正確性を、
別コンテキストから独立した視点で検証してください。

利用可能な MCP を積極的に活用して:

- プラン内で言及されているライブラリ API の正確性を確認
- プラン内で言及されているファイルパス・シンボルの実在確認

```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/issue-reviewer/instruct.md`

```

plan-integrator が作成した実装プランをレビューし、改善案を出してください。
コードには手を加えないでください。read only で調査のみを行ってください。

【Issue の内容】
{{ISSUE_CONTENT}}

【レビュー対象】
以下のファイルを Read ツールで読み込んでください:

- .cache/r-i-t/{{TASK_SLUG}}/plan-integrator/report.md

【レビュー手順】

1. 技術要素の正確性を検証:
   - 利用可能な MCP でプラン内で言及されているライブラリ・フレームワークの API や使用方法が正確かを確認
   - コードベース解析ツールでプラン内で言及されているファイルパスやシンボルが実在するか確認

2. 以下の観点でレビュー:
   a) 実装漏れ — Issue の要件がすべてカバーされているか
   b) 実装方針の具体性 — コーディングエージェントが作業できるレベルの詳細度か
   c) テスト計画の十分性 — 単体テスト・E2E テストの計画が漏れなくカバーしているか
   d) 矛盾・不整合 — Phase 1 の各 Teammate の指摘内容間に矛盾がないか
   e) ベストプラクティス — MCP で技術スタックのベストプラクティスに沿っているか
   f) アーキ整合性 — Clean Architecture / DDD / SOLID 観点でレイヤー境界が適切か
   g) Mermaid 図の妥当性 — 図がプランの本文と整合しているか

【結果の JSON 形式】
{
"role": "plan_reviewer",
"corrections": [
{
"section": "対象セクション",
"issue": "問題点",
"suggestion": "修正案",
"severity": "must_fix | should_fix | nice_to_have"
}
],
"missing_items": [
{
"description": "漏れている項目",
"suggestion": "追加すべき内容"
}
],
"technical_verification": [
{
"claim": "プラン内の技術的記述",
"verified": true | false,
"note": "検証結果の補足"
}
],
"architectural_assessment": {
"layer_boundaries": "レイヤー境界の適切性",
"solid_compliance": "SOLID 原則の遵守状況",
"ddd_alignment": "DDD 観点での評価"
},
"overall_assessment": "全体的な評価コメント"
}

```
