---
name: code-finisher
description: |
  コード品質チェック（型チェック、リント、単体テスト、E2Eテスト）を実行します。
  以下の場合に使用してください：
  - 複数ファイルにまたがるコード変更の完了後
  - プルリクエスト作成前
  - バグ修正後のリグレッション確認
  - 重要なビジネスロジックに触れる機能の統合後
  - リファクタリング後のテスト確認
---

# コード品質チェック

実装完了後の品質検証を順番に実行し、失敗したら停止して報告します。

## 変数定義

本 SKILL.md では以下の {{VARIABLE}} を使用します。実際のプロジェクトの値に置き換えて使用してください。

| 変数 | 説明 | デフォルト例 |
|------|------|-------------|
| `{{PACKAGE_MANAGER}}` | パッケージマネージャ | `pnpm` |
| `{{TYPE_CHECK_COMMAND}}` | 型チェックコマンド | `pnpm check-types` |
| `{{LINT_COMMAND}}` | リント・フォーマットコマンド | `pnpm biome:fix` |
| `{{TEST_COMMAND}}` | 単体テストコマンド | `pnpm test` |
| `{{E2E_TEST_COMMAND}}` | E2E テストコマンド | `pnpm test:e2e` |
| `{{DATABASE_PACKAGE}}` | DB パッケージ名 | `@repo/database` |
| `{{DB_MIGRATE_TEST_COMMAND}}` | DB テストマイグレーションコマンド | `pnpm --filter @repo/database db:migrate:test` |
| `{{E2E_SERIAL_COMMAND}}` | E2E 直列実行コマンド | `pnpm --filter web test:e2e:serial --` |
| `{{AGENT_CONFIG_DIR}}` | エージェント設定ディレクトリ | `.claude` |

## 起動方法（重要）

このスキルは**サブエージェント経由で起動すること**。Task tool 呼び出し時は以下を必ず指定:

```
Task tool:
  subagent_type: "general-purpose"  ← または用途に応じて適切なエージェント
  model: "sonnet"                   ← 必ず sonnet 固定
  description: "コード品質チェック"
  prompt: "`{{AGENT_CONFIG_DIR}}/skills/code-finisher/SKILL.md` の手順に従ってコード品質チェックを実行し、結果を報告してください。"
```

**メインエージェントのコンテキストを節約するため、`Skill` tool による in-context 起動ではなく、必ず Task tool 経由で sonnet サブエージェントに委譲すること。**

## 実行順序

### 1. コード簡素化

`/simplify` スキルを実行し、変更されたコードの重複・冗長性・効率性をレビューして改善します。

### 2. 型チェック

```bash
{{TYPE_CHECK_COMMAND}}
```

**確認事項:**

- `any`, `unknown`, `object`, `{}` の不適切な使用
- 型アサーション (`as`) の妥当性
- `@ts-ignore`, `@ts-expect-error` をはじめとするエスケープハッチ使用の正当性
- dynamic import の使用の妥当性

### 3. リント & フォーマット

```bash
{{LINT_COMMAND}}
```

**確認事項:**

- 未使用のインポート・変数
- セキュリティ脆弱性（XSS, SQL Injection）
- コードスタイルの一貫性

### 4. 単体テスト

```bash
{{TEST_COMMAND}}
```

**確認事項:**

- テストの pass/fail 数
- カバレッジ基準
- 新規追加コードのテスト有無

### 5. E2E テスト

```bash
{{E2E_TEST_COMMAND}}
```

**DB 関連エラー時:**

```bash
{{DB_MIGRATE_TEST_COMMAND}}
```

**個別ファイル実行（問題特定用）:**

```bash
{{E2E_SERIAL_COMMAND}}
```

## 報告フォーマット

### 成功時

```
✅ 全チェック完了

✓ コード簡素化: 完了
✓ 型チェック: エラーなし
✓ リント: クリーン
✓ 単体テスト: X/Y passed
✓ E2Eテスト: X/Y passed

✨ PRの準備ができました！
```

### 失敗時

```
❌ [チェック名] 失敗

ファイル: [path]:[line]
問題: [詳細]
修正案: [提案]

再現コマンド: [command]
```

## 注意事項

- **E2E テストの実行で失敗する場合、画面の構成を確認する**
- 最初の失敗で停止し、詳細を報告
- `.skip` 付きテストは報告するが失敗扱いにしない
- AI 依存テストはタイムアウトに注意
- 修正後は再度品質チェックを実行
