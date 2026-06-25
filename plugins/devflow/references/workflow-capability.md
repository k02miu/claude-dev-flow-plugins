# Workflow capability 判定と経路分岐（共有）

オーケストレーション skill（`review-loop` / 今後の `resolve-issue` / `pr-review-loop`）が冒頭で参照する共通ロジック。
**主経路 = dynamic Workflow**、**副経路 = Agent Teams**。各 skill はこのファイルの判定に従って分岐する。

参照: `${CLAUDE_PLUGIN_ROOT}/references/workflow-capability.md`

---

## 1. 判定（各 skill の Phase 0 冒頭で 1 回）

bash で検出可能な無効シグナルを確認する:

```bash
# 1. 明示無効化フラグ
echo "DISABLE_ENV=${CLAUDE_CODE_DISABLE_WORKFLOWS:-unset}"
# 2. settings の disableWorkflows（読める範囲のみ。組織のマージ結果は確実には読めない）
grep -rsh '"disableWorkflows"[[:space:]]*:[[:space:]]*true' \
  "$HOME/.claude/settings.json" .claude/settings.json .claude/settings.local.json 2>/dev/null \
  && echo "DISABLE_SETTING=true" || echo "DISABLE_SETTING=unset"
# 3. バージョン（>= 2.1.154 が必須）
claude --version 2>/dev/null || echo "VERSION_UNKNOWN"
```

判定:

- 次のいずれかに該当 → **`WORKFLOW_UNAVAILABLE`**（副経路へ直行）
  - `CLAUDE_CODE_DISABLE_WORKFLOWS=1`
  - settings に `"disableWorkflows": true`
  - version < 2.1.154
- いずれにも該当しない → **`WORKFLOW_CANDIDATE`**（主経路を試行）

注意: **プラン種別（Pro/Max/Team/Enterprise）と `/config` の Dynamic workflows 有効状態は実行時に検出できない。** よって `WORKFLOW_CANDIDATE` は「使える保証」ではなく「試す価値あり」を意味する。最終的な可否はツール呼び出しの結果で確定する（次節）。

---

## 2. 主経路の試行とフォールバック

`WORKFLOW_CANDIDATE` の場合:

1. 各 skill の「Workflow 仕様」節に従って Workflow ツールでスクリプトを authoring・起動する。
2. **Workflow ツールが利用不可（ツールが存在しない / 呼び出しがエラーを返す / 即座に失敗）の場合は、その時点で副経路（Agent Teams）に切り替える。** 失敗の検出はリーダー（あなた）がツール結果を観察して行う。standard な自動 graceful fallback は文書化されていないため、リーダーの観察による分岐が唯一確実な手段。
3. partial に実行された痕跡（scratchpad 上のファイル）が残った場合は、副経路でやり直す前にそれを確認し、二重実行・破壊が起きないことを確かめる。
4. workflow が正常完了 → その O 契約出力（`${CLAUDE_PLUGIN_ROOT}/references/o-contract.md`）を最終報告にそのまま使う。

`WORKFLOW_UNAVAILABLE` の場合は主経路を試行せず、副経路の手順に直行する。

---

## 3. allowlist 制約（不可逆操作の構造的封じ込め）

workflow の subagent は **acceptEdits モード**で動き、**親セッションの tool allowlist を完全に継承**する。これを踏まえ:

- `git push` / 破壊的 DB マイグレーション等の**不可逆操作は allowlist に追加しない**（agent がそもそも呼べない状態を維持する）。封じ込めはツール除外で構造的に行い、人間ゲートに頼らない。
- allowlist 外のコマンド（型チェック・lint・テスト等）は long run の途中で permission prompt を誘発する（中断ではなく当該 call だけ deny）。長 run 前に必要コマンドを allowlist に追加するか、prompt が出る前提で設計する。
- **commit & push は明示指示が無い限り行わない**（既存ポリシー）。主経路・副経路の両方で同一に維持する。

---

## 4. 両経路で共有する不変条件

workflow のデフォルト（全中間結果を最終 answer に畳む）に逆らって、以下は主経路・副経路の両方で同一に満たす:

- **意思決定 report の人間可読出力**（`o-contract.md` の `criticalDecisions`）。ブロッキングではなく、ディスクに materialize する出力アーティファクトとして。
- **Input pre-stage の十全性投資**: 主経路では最初の stage（安価モデル）、副経路では teammate 起動前の `instruct.md` 生成として実装する。
- **不可逆操作の allowlist 封じ込め**（本ファイル §3）。
