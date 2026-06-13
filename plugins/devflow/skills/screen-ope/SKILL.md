---
name: screen-ope
argument-hint: "[ベースブランチ（任意）]"
allowed-tools: Bash(git diff:*), Bash(git symbolic-ref:*)
description: |-
  ブランチの変更差分から変更された画面・機能を特定し、テスト計画を作成します。
  オプションでブラウザ操作ツール（Playwright / Puppeteer / 利用可能なMCPなど）を使用し、
  スクリーンショットを取得して視的検証を行います。
  branch-finisher Step 5 で使用します。
  ブラウザテストツールが利用できない環境では、テスト計画の策定のみを行います。
---

# 画面操作検証（スクリーンショット + 視的確認）

ブランチ上の変更された画面・機能に対して、テスト計画を作成し、
オプションでブラウザ操作ツールを用いて実際のスクリーンショットを取得します。
**ブラウザテストツールはオプションです** — 利用できない場合はテスト計画の策定までを行います。

画面操作検証対象: $ARGUMENTS
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
| `{{FRONTEND_FRAMEWORK}}` | フロントエンドフレームワーク | `next.js` |
| `{{FRONTEND_PATH}}` | フロントエンドディレクトリ | `apps/web` |
| `{{DEV_SERVER_COMMAND}}` | 開発サーバー起動コマンド | `pnpm dev` |
| `{{DEV_SERVER_PORT}}` | 開発サーバーポート | `3000` |
| `{{DEV_SERVER_URL}}` | 開発サーバーのベースURL | `http://localhost:3000` |
| `{{E2E_TEST_FRAMEWORK}}` | E2E テストフレームワーク | `playwright` |
| `{{BROWSER_TOOL}}` | ブラウザ操作ツール（利用可能なMCP） | `@playwright/mcp` 等 |
| `{{CACHE_DIR}}` | キャッシュディレクトリ | `.cache` |
| `{{SCREENSHOT_DIR}}` | スクリーンショット保存ディレクトリ | `{{CACHE_DIR}}/screenshots` |
| `{{FRONTEND_ROUTES}}` | フロントエンドルート定義ファイルのパターン | `**/page.tsx, **/route.tsx` |

---

## ファイル構成

```
{{CACHE_DIR}}/screen-ope/
└── {branch-name}/
    ├── changed-pages.txt          # 変更された画面・ページ一覧
    ├── visual-test-plan.md        # 視的検証テスト計画
    ├── screenshots/               # 取得したスクリーンショット（ブラウザツール利用時）
    │   ├── 001-login-page.png
    │   ├── 002-dashboard.png
    │   └── ...
    └── verification-report.md     # 検証結果レポート
```

---

## 実行手順

### Phase 0: 準備

#### 0-1. 変更差分の収集

フロントエンドの変更ファイルを特定:

```bash
# 全変更ファイル一覧
git diff --name-only <base-branch>...HEAD
git diff --name-only
```

#### 0-2. 画面・ページ変更の特定

変更ファイルから、画面に関連するファイルを抽出:

```bash
# ページ・画面関連ファイルのフィルタリング
git diff --name-only <base-branch>...HEAD | grep -E '{{FRONTEND_ROUTES}}' > {{CACHE_DIR}}/screen-ope/{branch-name}/changed-pages.txt

# コンポーネント変更も含める（直接ページでなくとも画面に影響するコンポーネント）
git diff --name-only <base-branch>...HEAD | grep -E 'components/|ui/|features/' >> {{CACHE_DIR}}/screen-ope/{branch-name}/changed-pages.txt
```

#### 0-3. ブラウザツールの利用可能性確認

ブラウザ操作ツールが利用可能か確認:

```bash
# Playwright がインストールされているか
if npx --no-install playwright --version &>/dev/null; then
  echo "playwright: available"
elif [ -n "${BROWSER_TOOL:-}" ]; then  # ブラウザ操作 MCP（Chrome DevTools MCP / Playwright MCP 等）が設定されている場合
  echo "browser-mcp: available"
else
  echo "browser-tool: unavailable"
fi
```

利用不可の場合は Phase 2 へスキップ（テスト計画策定のみ実施）。

---

### Phase 1: ブラウザ操作によるスクリーンショット取得（オプション）

#### 1-1. 開発サーバーの起動

```bash
# バックグラウンドで起動
{{DEV_SERVER_COMMAND}} &
DEV_PID=$!

# 起動を待機
for i in $(seq 1 30); do
  if curl -s -o /dev/null -w "%{http_code}" {{DEV_SERVER_URL}} 2>/dev/null | grep -q 200; then
    echo "Dev server ready"
    break
  fi
  sleep 2
done
```

#### 1-2. 変更画面のスクリーンショット取得

変更された画面・ページに対して、順次アクセスしスクリーンショットを取得:

##### 方法 A: Playwright/ブラウザMCP 利用時

利用可能なブラウザ操作ツールを使用してスクリーンショットを取得:

```
各画面について:
  - ツールを起動して {{DEV_SERVER_URL}}/{route} にアクセス
  - 画面が完全にレンダリングされたことを確認
  - スクリーンショットを {{SCREENSHOT_DIR}}/{branch-name}/{screen-name}.png に保存
```

##### 方法 B: curl 等 HTTP クライアントのみ

```bash
# 画面の HTML が正しく返ることを確認（スクリーンショットは取得不可）
curl -s -o /dev/null -w "%{http_code}" {{DEV_SERVER_URL}}{route}

# key pages returning 200
for route in $(cat changed-pages.txt); do
  status=$(curl -s -o /dev/null -w "%{http_code}" {{DEV_SERVER_URL}}$route)
  echo "$route → $status"
done
```

#### 1-3. 開発サーバーの停止

```bash
kill $DEV_PID 2>/dev/null || true
```

---

### Phase 2: 視的検証テスト計画の策定

#### 2-1. 変更内容の分析

変更ファイルごとに、視的検証が必要な観点を特定:

| 変更種別 | 視的検証観点 |
|---------|-------------|
| 新規ページ追加 | 全画面要素の表示確認、レスポンシブ対応、ローディング状態、エラー状態 |
| 既存ページレイアウト変更 | 変更前後のレイアウト比較、要素の配置・サイズ・色 |
| コンポーネント変更 | 全使用箇所での表示確認、Props バリエーションごとの表示 |
| フォーム・入力系変更 | 入力状態、バリデーション表示、送信前後の状態遷移 |
| アニメーション・遷移 | アニメーションの表示・完了状態 |
| ダークモード・テーマ | 各テーマでの表示確認 |

#### 2-2. テスト計画書の作成

`{{CACHE_DIR}}/screen-ope/{branch-name}/visual-test-plan.md` を作成します。
テンプレートは `${CLAUDE_SKILL_DIR}/references/visual-test-plan-template.md` を Read して使用してください。

---

### Phase 3: 検証結果の記録

#### 3-1. 視的確認の実施

テスト計画に従い、以下のいずれかの方法で確認:

1. **ブラウザツール利用時**: 取得したスクリーンショットを目視確認し、問題点を記録
2. **ブラウザツール未使用時**: コードベースの分析結果から、表示に影響する可能性のある問題をリストアップ

#### 3-2. 検証結果レポートの作成

`{{CACHE_DIR}}/screen-ope/{branch-name}/verification-report.md` を作成します。
テンプレートは `${CLAUDE_SKILL_DIR}/references/verification-report-template.md` を Read して使用してください。

---

### Phase 4: 結果報告

#### 4-1. 報告

```markdown
## 画面操作検証結果

### 検証対象
[N] 画面・ページの変更を検証

### ブラウザツール
- 利用: [はい / いいえ]
- ツール: [ツール名]
- スクリーンショット: [N] 枚取得

### 検証結果
- ✅ 問題なし: [N] 画面
- ⚠️ 軽微な問題: [N] 画面
- ❌ 要修正: [N] 画面

### 問題サマリー
| 重要度 | 件数 | ステータス |
|--------|------|-----------|
| Critical | N | [対応状況] |
| High | N | [対応状況] |
| Medium | N | [対応状況] |
| Low | N | [対応状況] |

### 推奨アクション
[あれば記載]
```

---

## 注意事項

- **ブラウザ操作ツールはオプションです**: 利用できない環境ではテスト計画の策定までで完了とする。スクリーンショットがなくても変更影響の分析は可能。
- 開発サーバーを起動する際は、既存のプロセスとポート競合しないように注意する。必要に応じて環境変数でポートを変更する。
- スクリーンショットはテスト計画の補助手段であり、すべての画面状態を網羅する必要はない。主要な画面遷移と変更箇所にフォーカスする。
- E2E テストフレームワーク（{{E2E_TEST_FRAMEWORK}}）が既存のテストで使用されている場合、その知見をテスト計画に活用する。
- アクセシビリティ観点（Tab 操作、aria-label、コントラスト比）も検証項目に含める。
- すべての検証が完了したら、このレポートを branch-finisher の親プロセスに報告結果として返すこと。
