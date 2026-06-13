# Phase 1 Teammate 共通テンプレート

## instruct.md 共通テンプレート

各 Teammate の instruct.md は **タスク固有の指示文** だけを記載します（役割・調査手順・出力フォーマットはエージェント側に内蔵済み）。
`{{TEAMMATE_NAME}}` `{{INSTRUCTION}}` を置換して Write してください。

```markdown
# {{TEAMMATE_NAME}} 指示書

## 指示文

{{INSTRUCTION}}

## 特記事項

（必要に応じて、このタスク固有の追加観点・制約をここに記載）
```

## 共通起動プロンプト

`{{TEAMMATE_NAME}}` `{{TASK_SUBJECT}}` `{{TASK_SLUG}}` `{{MODE_HINT}}` を置換して Task tool の prompt に使用してください。
`{{MODE_HINT}}` は Mode A 対応エージェント（architecture-planner / existing-code-reviewer / security-reviewer / ui-designer）には
`Mode A (Feature Planning) で実行してください。` を設定。非対応エージェントは空欄。

```
あなたはチーム "feature-plan" の Teammate "{{TEAMMATE_NAME}}" です。
{{MODE_HINT}}

TaskList でタスク一覧を確認し、自分のタスク「{{TASK_SUBJECT}}」を TaskUpdate で
owner を自分に、status を in_progress に設定してから作業を開始してください。

ファイルパス:
- 指示: `.cache/c-f-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/instruct.md`
- 報告: `.cache/c-f-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/report.md`
- 質問: `.cache/c-f-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/questions.md`
- 回答: `.cache/c-f-i-t/{{TASK_SLUG}}/{{TEAMMATE_NAME}}/answers.md`

system prompt に記載された File-based 起動手順に従ってください。
コードには手を加えず、読み取り専用で調査を行ってください。
```
