---
name: test-follow-up
argument-hint: "[ベースブランチ（任意）]"
allowed-tools: Bash(git diff:*), Bash(git symbolic-ref:*)
description: |-
  ブランチの変更差分に対して、不足しているテスト・古くなったテスト・誤ったアサーション・
  孤立したテスト（削除されたコードを参照しているテスト）を検出します。
  branch-finisher Step 3 で使用します。
  Agent Teams で test-coverage-reviewer と test-planner（scope=unit）を起動し、
  テストの網羅性と正確性を総合的に評価します。
---

# テストフォローアップ

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


Agent Teams を利用し、コード変更にテストが適切に追従しているかを検証します。
テストカバレッジの不足、既存テストの陳腐化、アサーションの誤り、
孤立テスト（orphaned tests）を系統的に発見します。

テストフォローアップ対象: $ARGUMENTS
（引数でベースブランチ（親ブランチ）が渡された場合はそれを `<base-branch>`、未指定の場合はリポジトリのデフォルトブランチ（`git symbolic-ref --short refs/remotes/origin/HEAD` で取得、不可なら `main`）を `<base-branch>` として使用します。以降の `<base-branch>...HEAD` は実際のブランチ名に読み替えてください）

**commit & push はユーザーが明示的に指示しない限り絶対に行わないでください。**

---

## 変数定義

本 SKILL.md では以下の {{VARIABLE}} を使用します。実際のプロジェクトの値に置き換えて使用してください。

| 変数 | 説明 | デフォルト例 |
|------|------|-------------|
| `{{PLUGIN_NAME}}` | プラグイン名 | `devflow` |
| `{{AGENT_CONFIG_DIR}}` | エージェント設定ディレクトリ | `.claude` |
| `{{WORKSPACE_ROOT}}` | ワークスペースルート | `/workspace` |
| `{{PACKAGE_MANAGER}}` | パッケージマネージャ | `pnpm` |
| `{{UNIT_TEST_FRAMEWORK}}` | 単体テストフレームワーク | `vitest` |
| `{{E2E_TEST_FRAMEWORK}}` | E2E テストフレームワーク | `playwright` |
| `{{TEST_COMMAND}}` | 単体テストコマンド | `pnpm test` |
| `{{E2E_TEST_COMMAND}}` | E2E テストコマンド | `pnpm test:e2e` |
| `{{COVERAGE_COMMAND}}` | カバレッジコマンド | `pnpm test:coverage` |
| `{{MONOREPO_TOOL}}` | モノレポツール | `turborepo` |
| `{{MONOREPO_FILTER_FLAG}}` | モノレポフィルタフラグ | `--filter` |
| `{{FRONTEND_FRAMEWORK}}` | フロントエンドフレームワーク | `next.js` |
| `{{BACKEND_FRAMEWORK}}` | バックエンドフレームワーク | `hono` |
| `{{CACHE_DIR}}` | キャッシュディレクトリ | `.cache` |
| `{{TEST_FILE_PATTERNS}}` | テストファイルの検出パターン | `**/*.test.*, **/*.spec.*, **/*.test-d.*` |
| `{{COVERAGE_THRESHOLD}}` | 最低カバレッジ閾値 | `80` |

---

## チーム構成

| 役割 | Teammate 名 | `subagent_type` | 担当領域 |
|------|-------------|-----------------|----------|
| リーダー | （メインエージェント） | — | 変更差分収集、テスト一覧取得、最終判断、テスト追加・修正実装 |
| テストカバレッジ評価 | `test-coverage-reviewer` | `test-coverage-reviewer` | 変更コードのテスト網羅性評価、既存テストの陳腐化検出 |
| テスト設計 | `test-planner` | `test-planner` | 不足テストの設計、テストケース立案（scope=unit） |

---

## ファイル構成

```
{{CACHE_DIR}}/test-follow-up/
└── {branch-name}/
    ├── changed-files.txt          # 変更ファイル一覧
    ├── related-test-files.txt     # 関連テストファイル一覧
    ├── test-gap-report.md         # テスト不備レポート（test-coverage-reviewer 出力）
    └── test-plan.md               # 追加・修正テスト設計（test-planner 出力）
```

---

## 参照すべき外部 skill（プロセス知識ベース）

本 SKILL.md は「何をするか」のみを定義します。**「どうやるか」の詳細は以下の skill に委譲**してください。
各フェーズで必要になった時点で該当 skill を Skill ツールで参照すること。

| トピック | 参照先 skill |
|---------|--------------|
| チームコミュニケーション | `agent-teams:team-communication-protocols` |
| コード品質チェック実行 | `{{AGENT_CONFIG_DIR}}/skills/code-finisher/SKILL.md` |

---

## 実行手順

### Phase 0: 準備

#### 0-1. 変更差分の収集

```bash
# 全変更ファイル一覧
git diff --name-only <base-branch>...HEAD > {{CACHE_DIR}}/test-follow-up/{branch-name}/changed-files.txt
git diff --name-only >> {{CACHE_DIR}}/test-follow-up/{branch-name}/changed-files.txt
```

#### 0-2. テストファイルの特定

変更ファイルに対応するテストファイルを特定:

```bash
# 各変更ファイルについて、対応するテストファイルが存在するか確認
# 例: src/user/service.ts → src/user/service.test.ts
for f in $(cat {{CACHE_DIR}}/test-follow-up/{branch-name}/changed-files.txt); do
  dir=$(dirname "$f")
  base=$(basename "$f" | sed 's/\.[^.]*$//')
  for ext in .test.ts .test.tsx .spec.ts .spec.tsx .test-d.ts; do
    if [ -f "$dir/$base$ext" ]; then
      echo "$dir/$base$ext"
    fi
  done
done > {{CACHE_DIR}}/test-follow-up/{branch-name}/related-test-files.txt
```

#### 0-3. 孤立テストの初期スキャン

削除されたコードを参照しているテストファイルがないか、変更ファイル一覧と突き合わせて調査:

```bash
# 削除されたファイルの一覧
git diff --diff-filter=D --name-only <base-branch>...HEAD

# 削除されたシンボルを参照するテストがないか確認
# （具体的な確認方法はプロジェクトのテスト構成に依存）
```

#### 0-4. キャッシュディレクトリの初期化

```bash
mkdir -p {{CACHE_DIR}}/test-follow-up/{branch-name}
```

---

### Phase 1: 変更コードとテストのマッピング

#### 1-1. 変更の種類分類

各変更ファイルについて、変更の種類を分類:

| 変更種別 | 説明 | テスト影響 |
|---------|------|-----------|
| 新規ファイル追加 | 新しい機能・モジュール | 新規テストが必要 |
| 既存ロジック修正 | バグ修正・リファクタリング | 既存テストの更新・追加が必要 |
| インターフェース変更 | 型・API レスポンス・引数変更 | 既存テストのアサーション更新必須 |
| 削除 | ファイル・機能の削除 | 対応テストの削除（孤立テスト防止） |
| 設定のみ | 設定ファイル・環境変数の変更 | テスト不要（ただし設定テストがあれば更新） |
| ドキュメントのみ | コメント・ドキュメント | テスト不要 |

#### 1-2. テスト影響スコアの算出

変更ファイル数と影響範囲からテストフォローアップの深度を決定:

| スコア | 条件 | 対応深度 |
|--------|------|---------|
| Low | 設定・ドキュメントのみの変更 | 全テストパス確認のみ |
| Medium | 小規模ロジック修正（1〜3 ファイル） | 既存テスト更新確認 + 不足テスト検出 |
| High | 新規機能・大規模リファクタリング | フル: 網羅性評価 + テスト設計 + 実装 |
| Critical | コアロジック・DB スキーマ・API 変更 | フル + E2E テスト影響評価 |

---

### Phase 2: Agent Teams によるテスト評価

#### 2-1. Test-Coverage-Reviewer の起動

変更コードのテスト網羅性評価と、既存テストの陳腐化検出を行います:

```
Task tool:
  subagent_type: "devflow:test-coverage-reviewer"
  description: "テスト網羅性評価と陳腐化検出"
  prompt: |
    あなたは test-coverage-reviewer です。
    以下の情報に基づき、テストの不備を検出してください。

    ## 変更ファイル一覧
    [changed-files.txt の内容]

    ## 変更差分（git diff）
    [git diff <base-branch>...HEAD の内容]

    ## 関連テストファイル
    [related-test-files.txt にリストされたテストファイルの内容]

    ## 診断項目

    以下の 4 つの観点で評価してください:

    1. **不足テスト (Missing Tests)**
       - 新規追加されたロジックにテストが存在しない
       - 変更されたロジックにテストが不足している（Happy path / Error path / Edge case）
       - カバレッジが {{COVERAGE_THRESHOLD}}% を下回る箇所

    2. **陳腐化テスト (Outdated Tests)**
       - 変更された関数・モジュールのテストが変更前の動作をテストしている
       - テスト名と実際のアサーションが乖離している
       - モックの対象・戻り値が実際のコードと合っていない

    3. **誤ったアサーション (Wrong Assertions)**
       - 変更後の期待値と一致しないアサーション
       - テスト自体は pass するが、実装変更を正しく検証できていない
       - 弱すぎるアサーション（`toBeTruthy` ですべきアサーションを雑に流している等）

    4. **孤立テスト (Orphaned Tests)**
       - 削除された関数・モジュールを参照しているテスト
       - 削除されたファイルに対応するテストファイルが残っている
       - 参照しているシンボルが存在しない

    ## 出力フォーマット
    結果を `{{CACHE_DIR}}/test-follow-up/{branch-name}/test-gap-report.md` に以下の形式で出力してください:

    ```markdown
    # テスト不備レポート

    ## サマリー
    - 不足テスト: [N]
    - 陳腐化テスト: [N]
    - 誤ったアサーション: [N]
    - 孤立テスト: [N]

    ## 詳細
    ### [カテゴリ名] #001: [タイトル]
    - **対象ファイル**: [path]
    - **変更内容**: [変更の説明]
    - **問題点**: [具体的な問題]
    - **推奨アクション**: [修正方法]
    - **優先度**: High / Medium / Low
    ```

    ## ガイドライン
    - テストが「ある」ことと「正しい」ことは別。pass するテストでもアサーションが不適切なら報告する。
    - 不足テストは具体的なテストケース（正常系 / 異常系 / 境界値）まで含めて提案する。
    - E2E テストの影響が疑われる場合はその旨を明記する。
```

#### 2-3. Test-Planner の起動（不足テストが多い場合のみ）

`test-coverage-reviewer` のレポートで不足テストが多数検出された場合、
`test-planner`（scope=unit）を起動して具体的なテスト設計を行います:

```
Task tool:
  subagent_type: "devflow:test-planner"
  description: "不足テストの設計"
  prompt: |
    あなたは test-planner です。scope は unit（単体テスト）です。
    以下のテスト不備レポートに基づき、不足している単体テストの具体的な設計を行ってください。

    ## テスト不備レポート
    [test-gap-report.md の内容]

    ## 変更差分
    [git diff <base-branch>...HEAD の内容]

    ## 出力フォーマット
    結果を `{{CACHE_DIR}}/test-follow-up/{branch-name}/test-plan.md` に以下の形式で出力してください:

    ```markdown
    # テスト追加計画

    ## テストケース一覧

    ### TC-{N}: [テストタイトル]
    - **対象ファイル**: [path]
    - **テスト種別**: 単体テスト / E2Eテスト
    - **テストカテゴリ**: 正常系 / 異常系 / 境界値
    - **前提条件**: [セットアップ手順]
    - **入力**: [テスト入力]
    - **期待結果**: [アサーション内容]
    - **実装の目安**: [実装難易度と方針]
    ```
```

---

### Phase 3: テスト修正の実施

#### 3-1. レポート確認と修正優先順位の決定

`test-gap-report.md` を確認し、修正優先度を決定:

| 優先度 | 対応方針 |
|--------|---------|
| High（孤立テスト・誤アサーション） | 必ず修正する |
| High（不足テスト・陳腐化） | 必ず追加・修正する |
| Medium | 基本対応。工数が大きい場合はスキップ判断可 |
| Low | 対応任意。スキップ理由を記録 |

#### 3-2. テスト修正の実施

1. **孤立テストの削除**: 削除されたコードに対応するテストファイルを削除
2. **陳腐化テストの更新**: 変更後のコードに合わせてテストを修正
3. **誤ったアサーションの修正**: 期待値を変更後の仕様に合わせて修正
4. **不足テストの追加**: `test-plan.md` に従ってテストケースを実装

#### 3-3. テスト実行確認

```bash
# テストが通ることを確認
{{TEST_COMMAND}}

# E2E テストが影響を受ける場合
{{E2E_TEST_COMMAND}}
```

---

### Phase 4: シャットダウンと報告

#### 4-1. Teammate のシャットダウン

各 Teammate に `SendMessage` の `shutdown_request` を送信する（チームは implicit のため解体操作は不要）。

#### 4-2. 結果報告

```markdown
## テストフォローアップ結果

### 変更ファイル数
[N] ファイル

### 評価サマリー
- 不足テスト: [N] → [N] 追加
- 陳腐化テスト: [N] → [N] 修正
- 誤ったアサーション: [N] → [N] 修正
- 孤立テスト: [N] → [N] 削除

### テスト実行結果
- 単体テスト: [passed / failed]
- E2E テスト: [passed / failed / 未実施]

### 未対応の課題
[スキップした不備と理由]
```

---

## 注意事項

- **テストの存在 ≠ 品質**: pass するテストでもアサーションが不適切な場合は修正対象とする。
- **孤立テスト（orphaned tests）は必ず削除する**: 削除されたコードを参照するテストは CI で誤った安心感を与える。
- E2E テストへの影響も評価対象とする。ただし E2E テストの修正は影響範囲が大きいため、テスト計画で明示的に判断する。
- テストフレームワーク固有の設定（{{UNIT_TEST_FRAMEWORK}}、{{E2E_TEST_FRAMEWORK}}）に依存する判断は各 Teammate に委譲する。
- すべての修正が完了したら、このレポートを branch-finisher の親プロセスに報告結果として返すこと。
