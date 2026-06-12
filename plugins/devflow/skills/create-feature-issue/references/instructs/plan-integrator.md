# plan-integrator テンプレート

## instruct.md テンプレート

Write 先: `.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/instruct.md`

```markdown
# プラン統合・Issue 作成 指示書

## 指示文

{{INSTRUCTION}}

## 統合対象の report

以下を Read して統合してください:

- `.cache/c-f-i-t/{{TASK_SLUG}}/architecture-planner/report.md`
- `.cache/c-f-i-t/{{TASK_SLUG}}/existing-code-reviewer/report.md`
- `.cache/c-f-i-t/{{TASK_SLUG}}/library-researcher/report.md`
- `.cache/c-f-i-t/{{TASK_SLUG}}/security-reviewer/report.md`
- `.cache/c-f-i-t/{{TASK_SLUG}}/ui-designer/report.md`
- `.cache/c-f-i-t/{{TASK_SLUG}}/unit-test-planner/report.md`
- `.cache/c-f-i-t/{{TASK_SLUG}}/e2e-test-planner/report.md`

## Issue テンプレート

ユーザープロジェクトの `.github/ISSUE_TEMPLATE/feature_request.md` を Read して準拠。存在しない場合は `${CLAUDE_PLUGIN_ROOT}/.github/ISSUE_TEMPLATE/feature_request.md`（本プラグイン同梱サンプル）を参照する。どちらも無ければ一般的な機能要求 Issue 構成（背景・目的 / 受け入れ条件 / 実装方針 / 影響範囲 / リスク）で生成する。

## 出力

統合された Issue ドラフト（マークダウン）を `report.md` に Write。
前提 Issue が必要な場合は同じ report.md に併記。
```

## 起動プロンプト

```
あなたはチーム "feature-plan" の Teammate "plan-integrator" です。

TaskList で自分のタスク「プラン統合・Issue 作成」を TaskUpdate で owner を自分に、
status を in_progress にしてから作業を開始してください。

ファイルパス:
- 指示: `.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/instruct.md`
- 報告: `.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/report.md`
- 質問: `.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/questions.md`
- 回答: `.cache/c-f-i-t/{{TASK_SLUG}}/plan-integrator/answers.md`

system prompt に記載された File-based 起動手順に従ってください。
```
