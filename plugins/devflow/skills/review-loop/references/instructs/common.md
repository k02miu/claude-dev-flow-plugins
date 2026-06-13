# instruct.md 共通テンプレート（全ロール共通）

各ロールの instruct.md は「冒頭共通部分」+「ロール固有の観点（`references/instructs/<role>.md`）」+「末尾共通部分（出力フォーマット）」を連結して生成する。
`{{TASK_SLUG}}`, `{{N}}`, `{{CHANGED_FILES}}`, `{{DIFF_SUMMARY}}`, `{{PREV_FINDINGS}}`（2 周目以降のみ）を置換すること。

## 共通部分（instruct.md の冒頭）

```markdown
# {ロール名} レビュー指示書 (iteration {{N}})

## レビュー対象

- ブランチ差分ファイル: `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/target-files.md` を Read で確認
- 具体的な diff: 必要に応じて `git diff` コマンドで確認

### 変更ファイル一覧

{{CHANGED_FILES}}

### 変更 diff 要約

{{DIFF_SUMMARY}}

## レビューの原則

- **コードには絶対に手を加えないでください。read only で調査のみを行ってください。**
- 指摘の根拠はファイルパス + 行番号で具体的に示してください。
- 「推奨修正」にはコード例があれば必ず併記してください。

## 前回反復での指摘（2 周目以降のみ）

{{PREV_FINDINGS}}

同じ指摘を繰り返さないでください。前回対応済みと思われる箇所は確認し、まだ問題があれば「未解消」としてマークしてください。
```

## 全ロール共通（instruct.md の末尾）

```markdown
## 出力フォーマット

以下の JSON 形式で結果を `{{CACHE_DIR}}/review-loop/{{TASK_SLUG}}/iteration-{{N}}/{ロール名}/report.md` に Write で保存してください:

{
  "reviewer": "{ロール名}",
  "iteration": {{N}},
  "overall_status": "ok | needs_fix",
  "findings": [
    {
      "id": "{連番（例: code-1, arch-1, sec-1, perf-1, test-1, infra-1）}",
      "severity": "critical | high | medium | low",
      "location": "ファイルパス:行番号",
      "category": "{領域内のサブカテゴリ}",
      "evidence": "問題のある記述の引用（1-3 行）",
      "issue": "何が問題か（1-2 行）",
      "impact": "対応しない場合の影響（1-2 行）",
      "recommendation": "具体的な修正提案（コード例推奨）"
    }
  ],
  "notes": "全体的なコメント（任意）"
}
```
