# Phase 別出力テンプレート集

リーダーが各 Phase で Write するファイル / 送信するメッセージのテンプレート。`{{VARIABLE}}` / `{...}` を実際の値に置換して使用する。

## Phase 1-A-2 Case B: iteration 2 以降の再指示 SendMessage テンプレ

各 Claude Teammate に対して並列に送信する（1 メッセージで複数 SendMessage）。`to` と paths のロール名を各 Teammate に合わせる:

```
SendMessage:
  to: "code-architecture-reviewer"
  message: |
    iteration {{N}} のレビューを開始してください。
    `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/code-architecture-reviewer/instruct.md` を Read で確認し、
    iteration 1 と同じ JSON フォーマットで
    `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/code-architecture-reviewer/report.md` に Write してください。
    完了後 SendMessage で「iteration {{N}} レビュー完了」と通知してください。
```

## Phase 0-1: target-files.md テンプレ

Write 先: `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/target-files.md`

```markdown
# レビュー対象ファイル

## 変更差分
{ファイルパス一覧}

## infra-reviewer 適用可否
- 結果: REQUIRED / NOT_REQUIRED
- 根拠: {マッチしたファイル一覧 or "該当ファイルなし"}

## 変更 diff（要約）
{各ファイルの変更概要、または `git diff --stat` の出力}
```

## Phase 1-B-2: aggregated-findings.md 統合フォーマット（各項目）

```markdown
### [H-1] 問題の端的な説明 | severity: high | 検出: code-architecture-reviewer, security-reviewer

- **場所**: `path/to/file.ext:42`
- **カテゴリ**: code_quality / architecture / security / performance / testing / infra
- **証拠**: {引用（1-3 行）}
- **問題**: {何が問題か}
- **影響**: {対応しない場合のリスク}
- **推奨修正**: {具体的な修正案（コード例あれば併記）}
```

ID 体系:
- `[H-N]` high / critical
- `[M-N]` medium
- `[L-N]` low
- `[C-N]` reviewer 間で矛盾

## Phase 1-B-3: exit-decision.md テンプレ

```markdown
# Exit Decision - Iteration {{N}}

## severity 分布
- Critical: {数}
- High: {数}
- Medium: {数}
- Low: {数}
- 矛盾: {数}

## 前 iteration との比較（2 周目以降）
- Critical 変化: {前→今}
- High 変化: {前→今}
- Medium 変化: {前→今}

## 判定
- [ ] 条件 1: 全レビュアー OK（Critical/High/Medium/Low **すべて 0**）
- [ ] 条件 2: 収束判定（前回との比較で severity 構成が完全に同一、修正してもこれ以上減らない技術判断分かれ目に該当）
- [ ] 条件 3: 反復上限到達（iteration == 5）

**注**: 「Low のみ残存」は Exit 条件ではない。Low 指摘も対応対象。

## スキップされたレビュアー
- infra-reviewer: {REQUIRED / NOT_REQUIRED}
- codex-independent-reviewer: {OK / UNAVAILABLE}
- gemini-independent-reviewer: {OK / UNAVAILABLE}

## 結論
{EXIT | CONTINUE}

## 理由
{判定理由}
```

## Phase 1-C-1: fix-plan.md テンプレ

```markdown
# Fix Plan - Iteration {{N}}

## 対応対象の findings
{H-1, H-2, M-1, ... のリスト（Critical/High を優先、Medium は影響度順）}

## 影響ファイル一覧
- `path/to/file1.ext` - {修正概要}
- `path/to/file2.ext` - {修正概要}
- ...

## 規模判定
- ファイル数: {N}
- 複数ファイルにまたがる機能変更: {Yes/No}
- DB スキーマ変更: {Yes/No}
- インフラ変更: {Yes/No}

## 実行方針
{SMALL_FIX_DIRECT | LARGE_FIX_IMPLEMENT_TEAM}
```

## Phase 1-C-2-B: implement スキル起動引数テンプレ（初回のみ）

```
以下の指摘事項を修正してください。これは review-loop の iteration {{N}} からの修正依頼です。

## 対応すべき findings
{aggregated-findings.md の Critical / High / Medium / Low 項目をそのまま貼付}

## 影響ファイル
{fix-plan.md の影響ファイル一覧}

## 制約
- 既存の機能を壊さないこと
- 各 finding の「推奨修正」に従うこと
- commit & push は絶対に行わないこと（review-loop 側で継続するため）
- **作業完了後、Teammate を解散しないこと**（review-loop が後続 iteration で再利用するため、`shutdown_request` を打たない）
```

## Phase 1-C-2-B: implement チームへの追加修正依頼テンプレ（2 回目以降）

```
SendMessage:
  to: "implementer-leader"   # implement skill が立てたリーダー teammate の name
  message: |
    iteration {{N}} の追加修正依頼です。
    `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/aggregated-findings.md` を Read で確認し、
    Critical / High / Medium / Low の各指摘に対して修正を行ってください。
    制約は前回と同じ（commit & push しない、Teammate 解散しない）。
    完了後 SendMessage で「追加修正完了」と通知してください。
```

## Phase 2-1-c: final-report.html フォールバック構造（リーダーが直接 HTML 生成する場合）

1. `{{TEMPLATE_DIR}}/report-template.html` を Read
2. プレースホルダを置換し、final-report.md を以下の構造で HTML 化:
   - 概要 → `<section id="summary">`
   - 反復サマリー → `<section id="iterations">` + `<table>`
   - 最終反復の残存指摘 → `<section id="remaining">` (severity ごとに `<span class="badge badge-{high|medium|low}">`)
   - 反復中に解消した指摘 → `<section id="resolved">`
   - Reviewer 別所感 → `<section id="reviewers">` + `<table>` (OK=`badge-ok`, 残存=`badge-ng`, SKIPPED=`badge-info`)
   - 推奨次アクション → `<section id="next-actions">` (パターンに応じ `<div class="callout callout-{info|todo|warn}">`)
   - ファイル構成 → `<section id="artifacts">` + `<pre><code>`
3. HTML 特殊文字（`<`, `>`, `&`, `"`, `'`）は必ずエスケープ
4. 完成した HTML を Write で出力

## Phase 2-1-a: final-report.md（MD ソース）テンプレ

````markdown
# Review Loop Final Report - {{TASK_SLUG}}

## 概要
- **対象**: {対象ファイル数 / ブランチ名}
- **反復回数**: {N}
- **終了理由**: {Exit Decision の理由}

## 反復サマリー

| Iteration | Critical | High | Medium | Low | 修正方針 |
|-----------|----------|------|--------|-----|---------|
| 1         |          |      |        |     | SMALL / LARGE / - |
| ...       |          |      |        |     |                   |

## 最終反復の残存指摘

### 残存 Critical / High
{該当なし の場合はその旨を明記}

### 残存 Medium
{項目の列挙}

### 残存 Low（軽微）
{項目の列挙、対応見送り推奨の場合はその旨と理由を明記}

## 反復中に解消した主な指摘
{iteration 1 〜 N-1 で修正完了した findings の要約}

## Reviewer 別所感

| Reviewer | 最終状態 | 総評 |
|----------|---------|------|
| code-architecture-reviewer | OK / 残存 | {所感} |
| security-reviewer     | OK / 残存 | {所感} |
| testing-reviewer      | OK / 残存 | {所感} |
| infra-reviewer        | OK / 残存 / SKIPPED | {所感} |
| codex-independent-reviewer  | OK / 残存 / SKIPPED | {所感} |
| gemini-independent-reviewer | OK / 残存 / SKIPPED | {所感} |

## 推奨次アクション

{以下のパターン A〜D から該当するもの 1 つを選択して記述}

- A: 全レビュアー OK → 品質チェック完了。PR 提出可能。`{{TYPE_CHECK_COMMAND}} && {{LINT_COMMAND}} && {{TEST_COMMAND}}` で最終確認後、commit & push
- B: 反復上限到達で Critical/High 残存 → 人間判断が必要な項目を列挙し、推奨対応方針を併記
- C: 収束判定 → 設計判断が必要な項目を列挙
- D: Low のみ「対応見送り推奨」 → 各 Low に対応見送り理由を明記

## ファイル構成（実行ログ）

```
{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/
├── target-files.md
├── iteration-01/ ... iteration-{N}/
├── final-report.md
└── final-report.html
```
````
