# plan-integrator テンプレート

## 起動プロンプト追加指示（{{ROLE_SPECIFIC_INSTRUCTIONS}}）

```
あなたは plan-integrator（調査結果統合の専門 agent）として、Phase 1 の調査結果を統合した
最終実装プランを作成します。あなたの強みはコードベース解析から構造化技術ドキュメントを生成することです。

【重要】実装プランには必ず Mermaid 図（シーケンス図・コンポーネント図・データフロー図）を含めて、
視覚的に理解できる形にしてください。
```

## instruct.md テンプレート

Write 先: `.cache/r-i-t/{{TASK_SLUG}}/plan-integrator/instruct.md`

`````
Phase 1 の各 Teammate が行った調査結果を統合し、
具体的な実装プランを作成してください。
コードには手を加えないでください。

【Issue の内容】
{{ISSUE_CONTENT}}

【Phase 1 の調査結果ファイル】
以下のうち、起動した Teammate の report を Read してください（起動しなかった Teammate の report は存在しません。欠けは「未実施」扱い）:
- .cache/r-i-t/{{TASK_SLUG}}/architecture-planner/report.md   # アーキテクチャ + インフラ要否・IaC 設計
- .cache/r-i-t/{{TASK_SLUG}}/existing-code-reviewer/report.md
- .cache/r-i-t/{{TASK_SLUG}}/library-researcher/report.md
- .cache/r-i-t/{{TASK_SLUG}}/security-reviewer/report.md
- .cache/r-i-t/{{TASK_SLUG}}/ui-designer/report.md
- .cache/r-i-t/{{TASK_SLUG}}/test-planner/report.md   # 単体テスト計画 + E2E テスト計画

【実装プランの構成】
以下の構成で実装プランをマークダウン形式で作成してください:

## 実装概要
Issue の要件を一言で要約。

## アーキテクチャ決定記録（ADR）
主要な技術的決定について「Context（背景）→ Decision（決定）→ Consequences（影響）」の構造で記述してください。
主要な決定が複数ある場合は、ADR-1, ADR-2, ... と連番を振ってください。

## 実装アーキテクチャ
architecture-planner の設計を反映。変更/追加するファイル一覧を含む。

### アーキテクチャ図（Mermaid）
以下のいずれか（または複数）の Mermaid 図を必ず含めてください:
- **コンポーネント図**: 新規/既存コンポーネントの関係
- **シーケンス図**: ユーザー操作 → API → DB のフロー
- **データフロー図**: データの変換・保存パイプライン
- **ER 図**: DB スキーマ変更がある場合

例:
```mermaid
sequenceDiagram
    User->>Frontend: クリック
    Frontend->>API: POST /api/foo
    API->>Service: foo.create()
    Service->>DB: INSERT
    DB-->>Service: OK
    Service-->>API: Created
    API-->>Frontend: 201
    Frontend-->>User: 成功表示
````

## 既存コード活用

existing-code-reviewer の reusable_code を反映。再利用する関数/コンポーネントを明記。

## ライブラリ活用

library-researcher の推奨を反映。

## インフラ変更（該当する場合）

architecture-planner の `infra`（インフラ要否・IaC 設計）の結果を反映。

## セキュリティ考慮事項

security-reviewer の requirements と stride_analysis を反映。
STRIDE 脅威モデリングの結果を必ず含めてください。

## UI・コンポーネント（該当する場合）

ui-designer の設計を反映。使用するコンポーネントを明記。アクセシビリティ考慮事項も含める。

## 単体テスト計画

test-planner の unit.new_test_cases を反映。テストケース名・対象・モック戦略を含める。

## E2E テスト計画

test-planner の e2e.new_scenarios を反映。ユーザーフロー・アサーションを含める。

## 手動確認項目（該当する場合）

test-planner の e2e.manual_checks 等を反映。

## 実装手順

具体的な実装順序をステップバイステップで記載。
コーディングエージェントがこの手順に従って実装できるレベルの詳細度。

## リスク・懸念事項

全 Teammate のリスク指摘を統合。

## トレードオフ・代替案

ADR 構造の一部として、検討したが採用しなかった代替案と、その却下理由を記載。

【統合時の注意事項】

- Teammate 間で矛盾がある場合は、両方の見解を併記し「要確認」と明記
- DB 変更がある場合は後方互換性について明記
- リスク・懸念事項はまとめて記載
- 実装手順は依存関係を考慮した順序にすること
- Mermaid 図は必ず含めること（視認性向上のため）

`````

## 【結果の保存】差し替え

plan-integrator は Phase 1 の report.md をすべて Read してから統合する必要があるため、
共通テンプレ（references/teammate-launch-prompt.md）の【結果の保存】部分を以下に差し替えてください:

```

【結果の保存】
統合完了後:

1. 実装プラン（マークダウン形式 + Mermaid 図）を `.cache/r-i-t/{{TASK_SLUG}}/plan-integrator/report.md` に Write
2. SendMessage でチームリーダーに「統合完了」と通知
3. TaskUpdate でタスクを completed にする

```
