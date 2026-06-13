---
name: document-follow-up
argument-hint: "[ベースブランチ（任意）]"
allowed-tools: Bash(git diff:*), Bash(git symbolic-ref:*), Bash(find:*)
description: |-
  ブランチの変更差分（未コミット + コミット済み）と既存ドキュメントを比較し、乖離を検出・修正します。
  branch-finisher Step 1 で使用します。
  設計書・API仕様・DBスキーマ・アーキテクチャ文書など、コード変更に伴って
  追従が必要なドキュメントを特定し、乖離レポートを生成 → 自動修正まで行います。
---

# ドキュメントフォローアップ

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


Agent Teams を利用し、`docs-synthesizer` エージェントにコード変更とドキュメントの比較を委譲します。
ドキュメントは「変更されたコードから導出可能な情報」についてはスキップし、
**「コードだけからは読み取れない設計意図・アーキテクチャ判断・トレードオフの記録」**
に修正を集中します。

ドキュメントフォローアップ対象: $ARGUMENTS
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
| `{{DOCS_PATTERN}}` | ドキュメントディレクトリパターン | `docs/developments/` |
| `{{PACKAGE_MANAGER}}` | パッケージマネージャ | `pnpm` |
| `{{FRONTEND_FRAMEWORK}}` | フロントエンドフレームワーク | `next.js` |
| `{{BACKEND_FRAMEWORK}}` | バックエンドフレームワーク | `hono` |
| `{{ORM}}` | ORM | `prisma` |
| `{{DATABASE_PACKAGE}}` | DB パッケージ名 | `@repo/database` |
| `{{REVIEW_CHECKLIST_PATH}}` | レビューチェックリストのパス | `{{DOCS_PATTERN}}review-check-list.md` |
| `{{CACHE_DIR}}` | キャッシュディレクトリ | `.cache` |

---

## チーム構成

| 役割 | Teammate 名 | `subagent_type` | 担当領域 |
|------|-------------|-----------------|----------|
| リーダー | （メインエージェント） | — | 差分収集、タスク設計、最終判断、ドキュメント修正 |
| ドキュメント比較・修正 | `docs-synthesizer` | `docs-synthesizer` | コード差分と既存ドキュメントの比較、乖離検出、修正文案作成 |

---

## ファイル構成

```
{{CACHE_DIR}}/document-follow-up/
└── {branch-name}/
    ├── diff-files.txt           # 変更ファイル一覧
    ├── doc-code-discrepancies.md # 乖離レポート（docs-synthesizer 出力）
    └── updated-docs-list.md     # 修正したドキュメント一覧
```

---

## 参照すべき外部 skill（プロセス知識ベース）

本 SKILL.md は「何をするか」のみを定義します。**「どうやるか」の詳細は以下の skill に委譲**してください。
各フェーズで必要になった時点で該当 skill を Skill ツールで参照すること。

| トピック | 参照先 skill |
|---------|--------------|
| ドキュメント生成・ADR フォーマット | `documentation-generation:architecture-decision-records` |
| チームコミュニケーション | `agent-teams:team-communication-protocols` |

---

## 実行手順

### Phase 0: 準備

#### 0-1. 変更差分の収集

ブランチの変更ファイル一覧を取得:

```bash
# 未コミット差分も含む
git diff --name-only <base-branch>...HEAD
git diff --name-only
```

合わせて `git diff <base-branch>...HEAD` の内容も取得し、変更の実態を把握しておく。

#### 0-2. ドキュメントファイル一覧の取得

ドキュメントディレクトリ内のファイル一覧を取得:

```bash
find {{DOCS_PATTERN}} -name "*.md" -type f 2>/dev/null | sort
```

#### 0-3. キャッシュディレクトリの初期化

```bash
mkdir -p {{CACHE_DIR}}/document-follow-up/{branch-name}
```

---

### Phase 1: 比較対象の特定

#### 1-1. 変更ファイルとドキュメントの対応マッピング

変更ファイル一覧から、以下のルールで影響を受けるドキュメントを推定:

| 変更対象 | 影響を受けるドキュメント |
|---------|------------------------|
| API ルート・ハンドラ | `{{DOCS_PATTERN}}endpoints.md` |
| DB スキーマ・モデル | `{{DOCS_PATTERN}}database-schema.md` |
| コンポーネント・ページ | `{{DOCS_PATTERN}}design.md` |
| 認証認可ロジック | `{{DOCS_PATTERN}}authorization.md` |
| アーキテクチャ全体 | `{{DOCS_PATTERN}}architecture.md` |
| テストコード | `{{DOCS_PATTERN}}unittest.md`, `{{DOCS_PATTERN}}e2e.md` |
| 環境変数・設定 | `.env.example`, `{{DOCS_PATTERN}}setup.md` |

#### 1-2. 影響ドキュメントの評価

各影響候補ドキュメントについて:

- 該当ドキュメントが存在するか
- 存在する場合、変更内容を反映する必要があるか
- **「コードだけから自明な実装詳細」をドキュメントに書く必要はない**という原則に照らし、真に追従すべき内容か判断する

判断基準: ドキュメントに書く価値があるのは以下のいずれか:
1. 設計意図・なぜその方式を選んだか（トレードオフを含む）
2. アーキテクチャ上の制約・前提条件
3. コードだけからは読み取れないビジネスルール
4. 過去の ADR と矛盾する変更

---

### Phase 2: Docs-Synthesizer による乖離検出

#### 2-1. チーム作成

```
TeamCreate:
  team_name: "document-follow-up"
  description: "ドキュメントフォローアップチーム"
```

#### 2-2. Docs-Synthesizer の起動

`docs-synthesizer` を 1 体起動し、変更差分と既存ドキュメントの比較を依頼:

```
Task tool:
  subagent_type: "devflow:docs-synthesizer"
  description: "ドキュメントとコードの乖離検出"
  prompt: |
    あなたは docs-synthesizer です。
    以下の変更差分と既存ドキュメントを比較し、乖離（discrepancy）を検出してください。

    ## 変更ファイル一覧
    [diff-files.txt の内容]

    ## 変更差分
    [git diff <base-branch>...HEAD の内容]

    ## 既存ドキュメント一覧
    [影響を受けるドキュメントの内容]

    ## 出力フォーマット
    以下の形式で乖離レポートを作成してください。
    `{{CACHE_DIR}}/document-follow-up/{branch-name}/doc-code-discrepancies.md` に出力すること。

    ```markdown
    # ドキュメント-コード乖離レポート

    ## 概要
    [検出された乖離の総数と重大度サマリー]

    ## 乖離一覧

    ### 乖離001: [タイトル]
    - **ドキュメント**: [ファイルパス]:[該当セクション]
    - **乖離種別**: 未更新 / 誤記 / 欠落 / 矛盾
    - **現状の記述**: [抜粋]
    - **実際のコード**: [抜粋 or 説明]
    - **修正方針**: [具体的な修正案]
    - **優先度**: High / Medium / Low

    ### 乖離002: ...
    ```

    ## ガイドライン

    - **コードから自明な実装詳細**（関数シグネチャ、引数の型、戻り値など）をドキュメント化する必要はない方針です。乖離として報告するのは「コードだけからは読み取れない設計情報」が欠落・誤っている場合に限ってください。
    - 「ドキュメントに書かれていないこと」がすべて乖離とは限りません。書くべき設計情報が欠けている場合のみ乖離としてカウントしてください。
    - 各乖離には具体的な修正文案を添えてください。
```

---

### Phase 3: 乖離レポートの確認と修正

#### 3-1. 乖離レポートの確認

`{{CACHE_DIR}}/document-follow-up/{branch-name}/doc-code-discrepancies.md` を読み、内容を確認:

- 優先度 High の乖離は必ず修正する
- Medium / Low はリーダー判断で修正またはスキップ（スキップ理由はレポートに追記）

#### 3-2. ドキュメント修正

乖離に対応するドキュメント修正を実施:

1. 各乖離について修正文案を適用
2. 修正後、該当ドキュメントの整合性を確認
3. 1 つのドキュメントに複数の乖離がある場合は一括修正

#### 3-3. 修正結果の記録

修正したドキュメント一覧を `{{CACHE_DIR}}/document-follow-up/{branch-name}/updated-docs-list.md` に記録:

```markdown
# 更新ドキュメント一覧

| ファイル | 修正内容 | 乖離番号 |
|---------|---------|---------|
| [path] | [概要] | 乖離001 |
```

---

### Phase 4: チーム解散と報告

#### 4-1. Docs-Synthesizer のシャットダウン

`docs-synthesizer` に `SendMessage` の `shutdown_request` を送信する。

#### 4-2. チーム解散

```
TeamDelete:
  team_name: "document-follow-up"
```

#### 4-3. 結果報告

```markdown
## ドキュメントフォローアップ結果

### 変更ファイル数
[N] ファイル

### 影響ドキュメント数
[N] ファイル（[うち新規 / 更新 / 不要]）

### 検出乖離数
- High: [N]
- Medium: [N]
- Low: [N]

### 修正対応
- 修正したドキュメント: [一覧]
- スキップした乖離（理由付き）: [一覧]

### 未対応の課題
[あれば記載]
```

---

## 注意事項

- **ドキュメントの過剰生成を避ける**: コードから自明な情報をわざわざドキュメントに書かない。ドキュメントは「設計意図の記録」に徹する。
- **ドキュメントとコードの齟齬は将来の混乱要因**: 乖離を見つけたら放置せず必ず修正する。
- **ADR (Architecture Decision Records)**: 重要な設計判断は `{{DOCS_PATTERN}}` 配下の ADR に記録する。ADR フォーマットの詳細は `documentation-generation:architecture-decision-records` skill を参照。
- すべての修正が完了したら、このレポートを branch-finisher の親プロセスに報告結果として返すこと。
