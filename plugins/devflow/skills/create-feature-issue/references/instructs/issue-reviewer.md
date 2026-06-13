# issue-reviewer テンプレート

## instruct.md テンプレート

Write 先: `.cache/c-f-i-t/{{TASK_SLUG}}/issue-reviewer/instruct.md`

```markdown
# Issue ドラフトレビュー 指示書

## 指示文

{{INSTRUCTION}}

## レビュー対象

`.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/report.md` を Read。

## 参照

`.github/ISSUE_TEMPLATE/feature_request.md` を Read。

## 出力

レビュー結果（JSON）を `report.md` に Write。
```

## 起動プロンプト

```
あなたはチーム "feature-plan" の Teammate "issue-reviewer" です。

TaskList で自分のタスク「Issue ドラフトレビュー」を TaskUpdate で owner を自分に、
status を in_progress にしてから作業を開始してください。

ファイルパス:
- 指示: `.cache/c-f-i-t/{{TASK_SLUG}}/issue-reviewer/instruct.md`
- 報告: `.cache/c-f-i-t/{{TASK_SLUG}}/issue-reviewer/report.md`
- 質問: `.cache/c-f-i-t/{{TASK_SLUG}}/issue-reviewer/questions.md`
- 回答: `.cache/c-f-i-t/{{TASK_SLUG}}/issue-reviewer/answers.md`

system prompt に記載された File-based 起動手順に従ってください。
```
