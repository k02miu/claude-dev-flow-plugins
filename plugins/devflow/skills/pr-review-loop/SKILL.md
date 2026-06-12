---
name: pr-review-loop
disable-model-invocation: true
argument-hint: "[PR番号（任意） --max-iter N]"
allowed-tools: Bash(git branch:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(date:*)
description: |
  PR に対して `pr-request-review` → 待機 → `pr-review-respond --auto` をループ実行し、
  設定されたマルチ LLM レビュアー（例: GitHub Copilot / Claude / Codex / Gemini の4レビュアー）から
  まともな指摘が出なくなるまで自律的にレビュー → 修正 → 再レビューを繰り返します。
  以下の場面で使用:
  - PR 作成後、Mergeable な状態に持っていくまで自動でレビュー対応を回したいとき
  - レビュー差し戻し後、人間が介入せずに収束させたいとき
---

# PR Review Loop（マルチ LLM レビュー収束）

> **プラグイン名前空間**: 本プラグインが提供する agent / skill はインストール時に `devflow:` で名前空間化されます。`subagent_type` や Skill tool に渡す名前は `devflow:<name>`（例 `devflow:architecture-planner` / `devflow:document-follow-up`）を使用してください。本文中の例で `devflow:` が付いていない箇所も同様に解釈すること。例外: `general-purpose`（ビルトイン）と `codex:*`（別プラグイン）はそのまま使用。


> **変数の解決（重要）**: 本スキル内の `{{VARIABLE}}` はプラグイン配布時に自動置換されません。実行時に `CLAUDE.md` / `AGENTS.md`、無ければ `package.json`・設定ファイル・リポジトリ構成を調査して値を解決してください。解決できない場合のみユーザーに確認します。

PR に対して **`pr-request-review` → 待機 → `pr-review-respond --auto`** をサイクル実行し、
4モデル（{{PR_REVIEWER_MODEL_NAMES}}）からまともな指摘が出なくなるまで自律的にレビュー＆修正を繰り返します。

## 変数定義

本 SKILL.md では以下の {{VARIABLE}} を使用します。実際のプロジェクトの値に置き換えて使用してください。

| 変数 | 説明 | デフォルト例 |
|------|------|-------------|
| `{{PR_REVIEWER_MODEL_NAMES}}` | PR レビュアーモデル名 | `GitHub Copilot / Claude / Codex / Gemini` |

## 引数

- `<PR番号>`: 任意。省略時は現在ブランチに紐づく open PR を自動検出。
- `--max-iter <N>`: 任意（デフォルト `10`）。安全装置としての最大反復回数。
- `--wait-max <分>`: 任意（デフォルト `15`）。各ラウンドのレビュー待機タイムアウト。
- `--poll-interval <秒>`: 任意（デフォルト `60`）。レビュー完了確認のポーリング間隔。

## 前提条件

- `gh` CLI が認証済み
- `pr-request-review` / `pr-review-respond` が利用可能
- `pr-review-respond` の `--auto` フラグがサポートされていること（自律的に commit & push まで実行する）

## グローバル状態

ループ全体を通じて以下のステートを保持する（メイン会話のメモ上で管理）:

```
PR              = <PR番号>
ITER            = 0
MAX_ITER        = 10
ACTIVE_MODELS   = {copilot, claude, codex, gemini}   # 初期値
INACTIVE_REASON = {}                                 # モデル → 停止理由（"timeout" / "no-meaningful" / "explicit-approve"）
HISTORY         = []                                 # 各ラウンドの結果サマリ
```

## 手順

### 0. 初期化

1. PR 番号を確定（引数 or `gh pr view --json number -q .number`）
2. PR が `OPEN` か確認。`MERGED` / `CLOSED` なら即終了
3. **保護ブランチチェック**: 本ループは各ラウンドで commit & push を自律実行するため、開始前に1回、現在のブランチが保護ブランチでないことを確認する:

   ```bash
   CURRENT_BRANCH=$(git branch --show-current)
   DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
   ```

   `CURRENT_BRANCH` が `DEFAULT_BRANCH` または `main` / `master` / `develop` のいずれかに一致する場合は、**push せずループを開始しないで停止**し、保護ブランチ上では実行できない旨をユーザーに報告する。
4. 引数を `MAX_ITER` / `WAIT_MAX` / `POLL_INTERVAL` に反映
5. `ACTIVE_MODELS = {copilot, claude, codex, gemini}` で初期化

### 1. メインループ

`ACTIVE_MODELS` が空 or `ITER >= MAX_ITER` まで以下を繰り返す。

#### 1-1. ラウンド開始

```bash
ITER=$((ITER + 1))
T_REQUEST=$(date -u +%FT%TZ)   # このラウンドのリクエスト時刻（UTC ISO）
echo "=== Round $ITER === active=[$ACTIVE_MODELS]"
```

#### 1-2. レビュー依頼

`pr-request-review` をアクティブモデルだけ指定して起動:

```
Skill tool:
  skill: "devflow:pr-request-review"
  args: "<PR> --models <ACTIVE_MODELS をカンマ区切り>"
```

エラーで返ってきた場合、原因を判断:
- 全部失敗 → ループ終了（要因を報告）
- 一部失敗 → 失敗したモデルは `INACTIVE_REASON[model] = "request-failed"` で除外して継続

#### 1-3. レビュー待機（ポーリング）

`POLL_INTERVAL` 秒ごとに、以下を `WAIT_MAX` 分まで繰り返す:

```bash
# T_REQUEST 以降の新規 review/comment を取得
NEW_REVIEWS=$(gh api "repos/{owner}/{repo}/pulls/$PR/reviews" \
  --jq ".[] | select(.submitted_at > \"$T_REQUEST\") | {user: .user.login, body: .body, state: .state}")
NEW_COMMENTS=$(gh api "repos/{owner}/{repo}/issues/$PR/comments" \
  --jq ".[] | select(.created_at > \"$T_REQUEST\") | {user: .user.login, body: .body}")
NEW_REVIEW_COMMENTS=$(gh api "repos/{owner}/{repo}/pulls/$PR/comments" \
  --jq ".[] | select(.created_at > \"$T_REQUEST\") | {user: .user.login, body: .body, path: .path, line: .line}")
```

**author login → モデル判定（部分一致 / 大文字小文字無視）:**

| モデル | login パターン例 |
|--------|------------------|
| copilot | `Copilot`, `github-copilot[bot]`, `copilot-pull-request-reviewer` |
| claude  | `claude[bot]`, `anthropic-claude-bot[bot]`, `claude-code[bot]` |
| codex   | `codex[bot]`, `chatgpt-codex-connector[bot]` |
| gemini  | `gemini-code-assist[bot]`, `gemini[bot]` |

**マッチング**: `login` を小文字化し、上記キーワード（`copilot` / `claude` / `codex` / `gemini`）が含まれているかで判定。複数一致した場合はより限定的なものを優先。

各 ACTIVE_MODEL について、新規 review/comment が1件以上検出できれば `RESPONDED[model] = [<該当 body 群>]` に記録。

**終了条件**:
- 全 ACTIVE_MODEL が応答した → 即座にループ抜け
- WAIT_MAX 経過 → 未応答モデルを `INACTIVE_REASON[model] = "timeout"` で除外し、応答済みのみで継続
- 応答 0 のままタイムアウト → ループ全体を終了

#### 1-4. 「まとも判定」

各応答モデルの `body` を結合し、以下のフィルタを適用:

**Step 1: キーワードフィルタ（軽量）**

以下のいずれかにマッチし、かつ本文が短い（200 文字未満）場合は「実質的指摘なし」と判定:

```
正規表現（i フラグ）:
  /\b(LGTM|looks good|no issues|approved|nothing to add)\b/i
  /(問題ありません|指摘ありません|指摘なし|特に問題なし|承認します|問題なさそう)/
```

加えて、Copilot review で `state == "APPROVED"` かつ body が空 or 上記キーワードのみ → 実質的指摘なし。

**Step 2: LLM 判定（Step 1 で確定しなかった場合）**

応答本文を読み、メインエージェントが判断:

> 以下の PR レビューコメントには、コード修正・議論・反論のいずれかを要する **実質的な指摘** が含まれているか判定してください。
> 「LGTM」「問題ありません」のような承認のみ、あるいは雑談・お礼・短い感想のみは「実質的指摘なし」とします。
> 出力は `meaningful` か `no-meaningful` の1単語のみ。

「実質的指摘なし」と判定された モデルは `INACTIVE_REASON[model] = "no-meaningful"` で次ラウンド以降の対象から除外。

#### 1-5. 終了判定（修正前）

「実質的指摘あり」のモデルが **0** の場合 → 全モデル収束したのでループ終了（成功）。

#### 1-6. 修正対応（`pr-review-respond --auto`）

「実質的指摘あり」のモデルがいる場合、以下を起動:

```
SlashCommand: /pr-review-respond <PR> --auto
```

`pr-review-respond --auto` は:
- 並列で専門エージェントによる分析 → opinion-integrator で対応方針策定
- ユーザー確認をスキップしてそのままコード修正・コメント返答を実施
- 完了後に自動 `git add . && git commit && git push`

戻り値で「対応コメント数」「commit SHA」「対応サマリ」を取得し `HISTORY` に記録。

エラーで返ってきた場合:
- 修正中に未解決のコンフリクト等 → ループを中断してユーザー報告
- 一部コメントだけ未対応 → 警告を残して継続

#### 1-7. ラウンド完了

```
HISTORY[$ITER] = {
  active_at_start: <list>,
  responded: <list>,
  meaningful: <list>,
  newly_inactive: <list>,
  commit_sha: <SHA or null>,
  comment_count: <int>
}
ACTIVE_MODELS = ACTIVE_MODELS - newly_inactive
```

次ラウンドへ。

### 2. 終了処理

ループを抜けたら、最終レポートを出力:

```
🏁 PR Review Loop 完了 (PR #<番号>)

総ラウンド数: <ITER>
終了理由: <"全モデル収束" | "MAX_ITER 到達" | "依頼失敗" | "ユーザー中断">

各モデルの停止ラウンド:
- Copilot: round <N> (理由: <reason>)
- Claude:  round <N> (理由: <reason>)
- Codex:   round <N> (理由: <reason>)
- Gemini:  round <N> (理由: <reason>)

総 commit 数: <count>
最終 PR 状態: <gh pr view の state/mergeable>
PR URL: <URL>
```

## 注意事項

- **暴走防止**: `MAX_ITER` (デフォルト10) に達したら終了。長時間ジョブなのでバックグラウンド実行も検討
- **コミット衝突**: 各ラウンドで `pr-review-respond --auto` が push する間に、レビュアー bot からの更新が無いことを前提とする。push が rejected になった場合は `git pull --rebase` を試み、それでもダメならループ中断。`git pull --rebase` がコンフリクトで失敗した場合は、**必ず `git rebase --abort` で作業ツリーを安全な状態に戻してから**ループを中断し、状況（コンフリクトしたファイル・原因）をユーザーに報告する（コンフリクト状態のまま放置しない）。**force push（`git push --force` / `--force-with-lease`）は決して行わない**
- **コスト**: 各ラウンドでマルチ LLM レビュー＋専門エージェント分析が走るため、課金が積み上がる。デフォルトの `--max-iter 10` は安全側のキャップ。実運用では 3〜5 程度で収束することを期待
- **モデル login パターンの確認**: 各 bot の実際の login はリポジトリ設定で異なる可能性がある。空打ち（応答ゼロ）が続いて全モデル `timeout` で停止する場合、login パターンの誤判定を疑い、`gh api ... | jq '.[].user.login'` で実際の値を確認してパターン表を更新する
- **手動中断時の再開**: ループの途中で停止した場合、PR の現状を見て次ラウンドから再開可能（このスキルは冪等）
- **「実質的指摘なし」の連続性**: 一度 `no-meaningful` と判定したモデルでも、後続ラウンドで他モデル指摘に応じた修正が入った後に再度依頼したくなる可能性はある。本ループでは **一度 inactive になったモデルは再度 active 化しない**（収束を保証するため）。再依頼したい場合は、ループ終了後に手動で `pr-request-review --models <model>` を実行する
