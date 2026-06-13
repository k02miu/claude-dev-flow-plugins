---
name: add-storybook
argument-hint: "[ベースブランチ（任意）]"
allowed-tools: Bash(git diff:*), Bash(git symbolic-ref:*), Bash(grep:*)
description: |-
  ブランチの変更差分から UI コンポーネントの変更を検出し、Storybook（または同等の
  コンポーネントカタログツール）用のストーリー/ドキュメントを追加・更新します。
  branch-finisher Step 2 で使用します。
  新規コンポーネントのストーリー追加、変更コンポーネントのストーリー更新、
  不要になったストーリーの削除を自動判定します。
  Storybook が導入されていないプロジェクトではスキップします。
---

# ストーリー/ドキュメント追加

ブランチ上の UI コンポーネント変更に対して、Storybook（または同等のフロントエンド
コンポーネントカタログツール）用のストーリーファイルを追加・更新します。

ストーリー追加対象: $ARGUMENTS
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
| `{{STORYBOOK_COMMAND}}` | Storybook 起動コマンド | `pnpm storybook` |
| `{{STORYBOOK_BUILD_COMMAND}}` | Storybook ビルドコマンド | `pnpm build-storybook` |
| `{{STORYBOOK_CONFIG_DIR}}` | Storybook 設定ディレクトリ | `.storybook` |
| `{{STORY_PATTERN}}` | ストーリーファイルパターン | `**/*.stories.tsx` |
| `{{COMPONENT_PATTERN}}` | コンポーネントファイルパターン | `**/*.tsx` |
| `{{UI_COMPONENT_DIRS}}` | UI コンポーネントディレクトリ | `src/components/, src/ui/, src/features/` |
| `{{COMPONENT_TOOL_NAME}}` | コンポーネントカタログツール名 | `Storybook` |
| `{{CACHE_DIR}}` | キャッシュディレクトリ | `.cache` |

---

## 参照すべき外部 skill（プロセス知識ベース）

本 SKILL.md は「何をするか」のみを定義します。**「どうやるか」の詳細は以下の skill に委譲**してください。
各フェーズで必要になった時点で該当 skill を Skill ツールで参照すること。

| トピック | 参照先 skill |
|---------|--------------|
| チームコミュニケーション | `agent-teams:team-communication-protocols` |
| {{COMPONENT_TOOL_NAME}} ストーリー記述ガイドライン | プロジェクト別ドキュメント（存在すれば） |

---

## ファイル構成

```
{{CACHE_DIR}}/add-storybook/
└── {branch-name}/
    ├── changed-components.txt      # 変更されたコンポーネント一覧
    ├── story-impact-report.md      # ストーリー影響分析レポート
    └── updated-stories-list.md     # 追加・更新したストーリー一覧
```

---

## 実行手順

### Phase 0: 準備

#### 0-1. {{COMPONENT_TOOL_NAME}} の導入確認

プロジェクトに {{COMPONENT_TOOL_NAME}}（または同等のコンポーネントカタログツール）が導入されているか確認:

```bash
# 設定ディレクトリの存在確認
if [ -d "{{STORYBOOK_CONFIG_DIR}}" ]; then
  echo "{{COMPONENT_TOOL_NAME}}: installed"
elif grep -q '"storybook"' package.json 2>/dev/null; then
  echo "{{COMPONENT_TOOL_NAME}}: detected in package.json"
else
  echo "{{COMPONENT_TOOL_NAME}}: not installed"
fi
```

未導入の場合は **中断** し、その旨を報告して終了する。

#### 0-2. 変更コンポーネントの収集

UI コンポーネントの変更を抽出:

```bash
# 変更ファイル一覧から UI コンポーネントのみ抽出
git diff --name-only <base-branch>...HEAD | grep -E '{{UI_COMPONENT_DIRS}}' | grep -E '\.tsx$' > {{CACHE_DIR}}/add-storybook/{branch-name}/changed-components.txt
git diff --name-only | grep -E '{{UI_COMPONENT_DIRS}}' | grep -E '\.tsx$' >> {{CACHE_DIR}}/add-storybook/{branch-name}/changed-components.txt

# 新規ファイル（Added）と変更ファイル（Modified）を区別
git diff --diff-filter=A --name-only <base-branch>...HEAD | grep -E '{{UI_COMPONENT_DIRS}}' | grep -E '\.tsx$' > /tmp/new-components.txt
git diff --diff-filter=M --name-only <base-branch>...HEAD | grep -E '{{UI_COMPONENT_DIRS}}' | grep -E '\.tsx$' > /tmp/modified-components.txt
```

#### 0-3. 既存ストーリーファイルの特定

各変更コンポーネントに対応する既存ストーリーファイルを確認:

```bash
for component in $(cat {{CACHE_DIR}}/add-storybook/{branch-name}/changed-components.txt); do
  # コンポーネント名を取得
  name=$(basename "$component" .tsx)
  dir=$(dirname "$component")

  # ストーリーファイル検索（複数パターン）
  for story_pattern in "$dir/$name.stories.tsx" "$dir/$name.stories.ts" "$dir/$name.stories.mdx"; do
    if [ -f "$story_pattern" ]; then
      echo "$component → $story_pattern"
    fi
  done
done
```

#### 0-4. キャッシュディレクトリの初期化

```bash
mkdir -p {{CACHE_DIR}}/add-storybook/{branch-name}
```

---

### Phase 1: ストーリー影響分析

#### 1-1. コンポーネント変更の分類

各変更コンポーネントを以下のカテゴリに分類:

| カテゴリ | 条件 | 対応 |
|---------|------|------|
| **新規コンポーネント** | 新規追加された .tsx ファイル | 新規ストーリーが必要 |
| **Props 変更あり** | 既存コンポーネントの Props インターフェースが変更された | 既存ストーリーの更新が必要 |
| **内部実装のみ変更** | Props 変更なし、見た目に影響しない変更 | ストーリー更新不要（ただしドキュメント更新は任意） |
| **削除コンポーネント** | 削除された .tsx ファイル | 対応ストーリーの削除が必要 |
| **リネーム** | ファイル名変更 | ストーリーファイルのリネーム・更新 |

#### 1-2. ストーリー影響レポートの作成

`{{CACHE_DIR}}/add-storybook/{branch-name}/story-impact-report.md` を作成:

```markdown
# ストーリー影響分析レポート

## サマリー
- 新規コンポーネント（ストーリー追加が必要）: [N]
- Props 変更あり（ストーリー更新が必要）: [N]
- 内部実装のみ変更（ストーリー不要）: [N]
- 削除コンポーネント（ストーリー削除が必要）: [N]
- 既存ストーリーとの対応: [N] ファイル一致 / [N] ファイル不一致

## 詳細

### 新規コンポーネント（ストーリー追加）
| # | コンポーネント | ファイルパス | Props概要 | 備考 |
|---|--------------|-------------|----------|------|
| 1 | Button | src/ui/Button.tsx | variant, size, disabled, onClick | 基本ストーリー + バリエーション |
| 2 | ... | ... | ... | ... |

### Props 変更あり（ストーリー更新）
| # | コンポーネント | ファイルパス | 変更内容 | 既存ストーリーパス |
|---|--------------|-------------|---------|------------------|
| 1 | Card | src/components/Card.tsx | `isLoading` prop 追加 | src/components/Card.stories.tsx |

### 削除コンポーネント（ストーリー削除）
| # | コンポーネント | 削除ファイル | 対応ストーリー |
|---|--------------|-------------|---------------|
| 1 | OldWidget | src/features/OldWidget.tsx | src/features/OldWidget.stories.tsx |
```

---

### Phase 2: ストーリーの追加・更新

#### 2-1. 新規ストーリーの作成

新規コンポーネントに対して、{{COMPONENT_TOOL_NAME}} のストーリーファイルを作成します。
各コンポーネントのストーリー作成ガイドラインに従ってください。

**基本的なストーリーファイル構造（{{COMPONENT_TOOL_NAME}}）:**

```tsx
// {component-path}.stories.tsx
import type { Meta, StoryObj } from '{{COMPONENT_TOOL_NAME}}';
import { ComponentName } from './ComponentName';

const meta: Meta<typeof ComponentName> = {
  title: '{Category}/{ComponentName}',
  component: ComponentName,
  tags: ['autodocs'],
  argTypes: {
    // Props の型から自動生成されるが、必要に応じてカスタマイズ
  },
};

export default meta;
type Story = StoryObj<typeof ComponentName>;

// 基本表示
export const Default: Story = {
  args: {
    // デフォルト値
  },
};

// バリエーション（props の組み合わせごと）
export const VariantName: Story = {
  args: {
    // バリエーション固有の値
  },
};
```

**ストーリー作成ガイドライン:**

- 各コンポーネントの Props のバリエーションを網羅する（必須 props / 任意 props / 未指定時）
- ローディング状態、エラー状態、空状態がある場合はそれらのストーリーも作成
- アクセシビリティに関する情報（aria 属性、role など）を含める
- インタラクション・テスト（クリック、入力など）が必要な場合は `play` 関数を追加
- ストーリーのタイトルはコンポーネントの階層構造を反映した命名にする

#### 2-2. 既存ストーリーの更新

Props 変更があったコンポーネントのストーリーを更新:

| 変更種別 | ストーリー更新内容 |
|---------|------------------|
| Props 追加（任意） | 新しい Props のストーリーバリエーションを追加 |
| Props 追加（必須） | 既存ストーリーに新しい必須 Props を追加し、既存 args を更新 |
| Props 削除 | 削除された Props を args から除去 |
| Props 名変更 | args のキー名を変更 |
| Props 型変更 | args の値を新しい型に合わせて更新 |
| コンポーネント名変更 | ストーリーの import とタイトルを更新 |

#### 2-3. 不要ストーリーの削除

削除されたコンポーネントに対応するストーリーファイルを削除:

```bash
# 該当ストーリーファイルを削除
rm {path-to-story-file}
```

#### 2-4. {{COMPONENT_TOOL_NAME}} のビルド確認

ストーリー追加・更新後、ビルドが通ることを確認:

```bash
{{STORYBOOK_BUILD_COMMAND}}
```

**ビルドエラーが発生した場合:**
- エラーメッセージを確認し、ストーリーファイルの構文ミス・インポートミスを修正
- 修正後、再度ビルドを実行
- それでも解決しない場合は問題のあるストーリーファイルを特定して修正

---

### Phase 3: 結果報告

#### 3-1. 更新ストーリー一覧の作成

`{{CACHE_DIR}}/add-storybook/{branch-name}/updated-stories-list.md` を作成:

```markdown
# ストーリー更新一覧

## 追加したストーリー
| # | コンポーネント | ストーリーファイル | ストーリー数 | 備考 |
|---|--------------|------------------|-------------|------|
| 1 | Button | src/ui/Button.stories.tsx | 4 (Default, Primary, Disabled, Loading) | |
| 2 | ... | ... | ... | |

## 更新したストーリー
| # | コンポーネント | ストーリーファイル | 更新内容 |
|---|--------------|------------------|---------|
| 1 | Card | src/components/Card.stories.tsx | isLoading バリエーション追加 |

## 削除したストーリー
| # | 削除したストーリーファイル | 理由 |
|---|-------------------------|------|
| 1 | src/features/OldWidget.stories.tsx | コンポーネント削除に伴う |
```

#### 3-2. 報告

```markdown
## ストーリー追加結果

### {{COMPONENT_TOOL_NAME}} の状態
- {{COMPONENT_TOOL_NAME}}: 導入済み / 未導入
- 設定ディレクトリ: {{STORYBOOK_CONFIG_DIR}}

### 変更コンポーネント数
[N] ファイル

### ストーリー操作サマリー
- 追加: [N] ファイル（[N] ストーリー）
- 更新: [N] ファイル
- 削除: [N] ファイル
- 影響なし（内部実装のみ）: [N] ファイル

### ビルド結果
- {{STORYBOOK_BUILD_COMMAND}}: ✅ / ❌
- [失敗時] エラー内容と対応状況

### 未対応の課題
[あれば記載]
```

---

## 注意事項

- {{COMPONENT_TOOL_NAME}} が導入されていないプロジェクトでは**何もせずスキップ**する。ストーリー追加を強行しない。
- コンポーネントカタログツールのバージョンや設定によってストーリーファイルの形式が異なる場合がある。プロジェクトの既存ストーリーファイルを参考に、同じスタイル・パターンに従うこと。
- **ストーリーはドキュメントでありテストでもある**: コンポーネントの全 Props バリエーションを網羅することを目標とするが、過剰なバリエーション（些細な色違いなど）は避ける。
- ストーリー追加後は必ずビルドを通し、構文エラー・インポートエラーがないことを確認する。
- `autodocs` タグが有効な場合、ストーリーから自動生成されるドキュメントページの品質も確認する。
- Props の JSDoc コメントがストーリーのドキュメントに反映される場合があるため、コンポーネント側に適切なコメントがあるか確認する（不足していれば追加を推奨）。
- すべての更新が完了したら、このレポートを branch-finisher の親プロセスに報告結果として返すこと。
