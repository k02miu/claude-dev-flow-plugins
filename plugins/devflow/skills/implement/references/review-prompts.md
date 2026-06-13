# Phase 3-2 並列コードレビュー用プロンプトテンプレ

変更ファイル一覧を確定した後、**同一メッセージ内で 2 つのレビューエージェントを並列起動**する際の Task tool 呼び出しテンプレ。

```
[並列 Task tool 呼び出し × 2]

# Reviewer 1: Security
Task tool:
  subagent_type: "devflow:security-reviewer"
  description: "セキュリティレビュー"
  prompt: |
    Mode B 相当（差分のセキュリティレビュー）。以下の変更ファイルをセキュリティ観点でレビューしてください。
    変更ファイル一覧:
    [report.md から集約したファイルリスト]
    
    観点:
    - 入力検証・サニタイゼーション
    - 認証・認可のバイパス
    - SQL injection, XSS, CSRF
    - 秘密情報の露出
    - {{AUTH_UTILITIES}} の使い方
    
    findings を構造化形式（SEVERITY / Location / Evidence / Impact / Fix）で返してください。

# Reviewer 2: Code Quality + Performance + Architecture
Task tool:
  subagent_type: "devflow:code-architecture-reviewer"
  description: "コード品質・パフォーマンス・アーキ整合性レビュー"
  prompt: |
    Mode R（差分レビュー）で以下の変更ファイルをレビューしてください。
    変更ファイル一覧:
    [report.md から集約したファイルリスト]
    参照: architecture-plan.md
    
    観点（3 観点を漏れなく）:
    - コード品質: 可読性・命名・DRY・YAGNI・エラーハンドリング・デッドコード
    - パフォーマンス: DB クエリ効率（N+1、欠落インデックス、全件スキャン）、メモリ、RSC / Client 境界（不要な "use client"）、キャッシング、バンドルサイズ・遅延ロード、並行処理
    - アーキテクチャ: SOLID / レイヤー境界の遵守、Service 層でのビジネスロジック集約、循環依存の有無、設計書からの乖離
    
    findings を構造化形式（SEVERITY / Category / Location / Evidence / Impact / Fix）で返してください。
```
