# 実装タスク用 instruct.md テンプレート

Phase 2-3 で各 zone の instruct.md を作成する際、このテンプレートの `{zone}` 等を置換して
`{{CACHE_DIR}}/implements/{{TASK_SLUG}}/{zone}/instruct.md` に Write する。

```markdown
# 実装指示 - {zone}

## オーナーシップ範囲
- {zone} が担当するファイル一覧（絶対パスで明記）

## 実装内容
{具体的な実装要件}

## インターフェース契約
{共有型定義・API コントラクト}

## よくある指摘（チェックリスト由来）
{Phase 1-1.5 で転記した教訓}

## 制約
- 担当範囲外のファイルは絶対に編集しないこと
- 既存の機能を壊さないこと
- commit & push は絶対に行わないこと
- 自 zone のテストを必ず作成すること
```
